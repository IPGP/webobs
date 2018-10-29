function DOUT=sismocp(mat,tlim,OPT,nograph)
%SISMOCP Graphes de la sismicité continue Courte-Période OVSG.
%       SISMOCP sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       SISMOCP(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
%           MAT = 1 (défaut) utilise la sauvegarde Matlab (+ rapide);
%           MAT = 0 force l'importation de toutes les données anciennes à
%               partir des fichiers FTP et recréé la sauvegarde Matlab.
%           TLIM = DT ou [T1;T2] trace un graphe spécifique ('_xxx') sur 
%               les DT derniers jours, ou entre les dates T1 et T2, au format 
%               vectoriel [YYYY MM DD] ou [YYYY MM DD hh mm ss].
%           TLIM = 'all' trace un graphe de toutes les données ('_all').
%           OPT.fmt = format de date (voir DATETICK).
%           OPT.mks = taille des marqueurs.
%           OPT.cum = période de cumul pour les histogrammes (en jour).
%           OPT.dec = décimation des données (en nombre d'échantillons).
%           NOGRAPH = 1 (optionnel) ne trace pas les graphes.
%
%       DOUT = SISMOCP(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code station
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - lecture des fichiers binaires SUDS *.GUA grace à la fonction "readsuds.m"
%           - état des stations sismiques par calcul du bruit et de l'offset
%           - graphe des 15 derniers fichiers 2 mn (signaux bruts pleine échelle)
%           - tambour 24 h par station (signaux amplifiés et corrigés de l'offset)
%           - sauvegarde Matlab spécifique pour le SEFRAM
%
%   Auteurs: F. Beauducel + A. Nercessian + C. Anténor, OVSG-IPGP
%   Création : 2003-02-24
%   Mise à jour : 2013-10-03

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 4, nograph = 0; end


rcode = 'SISMOCP';
timelog(rcode,1)
stype = 'T';

G = readgr(rcode);
tnow = datevec(G.now);
ST = readst(G.cod,G.obs);

G.sta = {rcode};
G.ali = {rcode};

% Initialisation des variables
fhz = 100;                                  % fréquence d'échantillonnage (Hz)
samp = 1/(86400*fhz);                       % pas d'échantillonnage des données (en jour)
vmm = 400;                                  % offset max
vsn = 1;                                    % bruit min
vsm = 200;                                  % bruit max (pour échelle tambour uniquement)
vsy = 100;                                  % anti-symétrie max
nbf = 15;                                   % nombre de fichiers
st3 = {'TAGZ','DEGZ','LKGZ','SCGZ','HMGZ','CDSZ'};        % stations 3 composantes (Z+E+N)
suv = {'Z','NS','EW'};                      % nom des 3 composantes
gris = .8*[1,1,1];                          % couleur grise

tlim = 1;                                   % tampon données (en jour)
dec = 10;                                   % décimation des données (ATTENTION: définit la taille du tampon)
sz = round(tlim/samp/dec);                  % taille du tampon
nbv = 45;                                   % nombre de voies par défaut
dt = 15/1440;                               % largeur des tambours (et arrondi)

sname = G.nom;
G.cpr = 'OVSG-IPGP';
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
pdon = X.RACINE_SIGNAUX_SISMO;
convert = X.PRGM_CONVERT;

% Définit l'heure TU à partir de l'heure du serveur (locale = GMT-4)
stitre = sprintf('%s: %s',upper(rcode),sname);

% Importation des stations sismiques
scod = char(ST.cod);
% dans le fichier GUA les noms de stations sont en 4 lettres et terminent par un Z
% le code "DATA_FILE" des fiches de station est en 3 lettres: on ajoute ici le Z...
for i = 1:length(ST.dat)
   if length(ST.dat{i}) == 3
	   ST.dat{i} = [ST.dat{i},'Z'];
   end
end
sdat = char(ST.dat);

% Chargement des voies du Sefram
%[sfr,sfg] = textread('data/Voies_Sefram.txt','%s%n','commentstyle','shell');

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
if mat & exist(f_save,'file')
    fprintf('File: %s import...\n',f_save)
    load(f_save,'t','d','vn','f','tf');
    disp(sprintf('Fichier: %s importé.',f_save))
    % date dernier événement sauvé
    tdeb = max(t);
    % effacement des données anciennes
    k = find(t > tdeb | t < (datenum(tnow) - tlim));
    %k = find(t > tdeb | t < ceil((datenum(tnow) - tlim)/dt)*dt);
    t(k) = NaN;
    d(k,:) = NaN;
    ki = find(tf < (datenum(tnow) - tlim));
    if ~isempty(ki)
        f(ki) = [];
        tf(ki) = [];
    end
else
    disp('Pas de sauvegarde Matlab. Chargement de toutes les données...');
    tdeb = datenum(tnow) - tlim;
    t = NaN*zeros(sz,1);
    d = NaN*zeros(sz,nbv);
    f = [];  tf = [];
end

nb_traites_max=str2num(X.SISMOCP_MAX_TRAITES);
flag = 0;
% Importation des fichiers de données SUDS principaux (.GUA)
[tt,dd,ss,ff,ii,nb_traites] = readsuds(tdeb,dec,sprintf('%s/%s',pdon,X.PATH_SOURCE_SISMO_GUA));
% essai avec les derniers séismes dépouillés
%[t,d,st,f,it] = readsuds(dec,15,sprintf('%s/Seisme%d',pftp,tnow(1)));
% remplit la matrice tampon d avec les données...
if ~isempty(tt)
    flag = 1;
    k = floor(mod(tt,1)/samp/dec) + 1;
    t(k) = tt;
    d(k,:) = dd;
    vn = ss
    f = [f;ff];
    tf = [tf;tt(ii)];
    %it = [it;(floor(mod(tt(ii),1)/samp/dec) + 1)];
    tdeb = tt(end);
end

if nb_traites < nb_traites_max
	% Importation des fichiers de données SUDS secondaires (.GUX)
	if isempty(tt) | tt(end) < (datenum(tnow) - G.lst)
	    disp('Pas de .GUA à jour. Importation des GUX...')
	    [tt,dd,ss,ff,ii,nb_traites] = readsuds(tdeb,dec,sprintf('%s/%s',pdon,X.PATH_SOURCE_SISMO_GUX));
	    if ~isempty(tt)
		flag = 1;
		k = floor(mod(tt,1)/samp/dec) + 1;
		t(k) = tt;
		% reconnaissance des voies ss (GUX) dans vn (GUA)
		for i = 1:length(ss)
		    kk = find(strcmp(ss(i),vn));
		    if ~isempty(kk)
			d(k,kk) = dd(:,i);
		    end
		end
		f = [f;ff];
		tf = [tf;tt(ii)];
		%it = [it;(floor(mod(tt(ii),1)/samp/dec) + 1)];
	    else
		disp('Pas de .GUX à jour non plus !!')
	    end
	end
else
	disp(sprintf('Limite de %d .GUA atteinte. On ne traite pas les GUX.',nb_traites_max))
end

% Sauvegarde Matlab
if flag
    f_tmp = sprintf('/tmp/%s.tmp',rcode);
    save(f_tmp);
    system(sprintf('mv -f %s %s',f_tmp,f_save));
    disp(sprintf('Fichier: %s créé.',f_save))
end

% Sauvegarde Matlab SEFRAM
%f_sefr = 'data/SEFRAM_past.mat';
%for i = 1:length(sfr)
%    isfr(i) = find(strcmp(sfr(i),vn));
%end
%ds = d(:,isfr);
%save(f_sefr,'t','ds','f','tf','tlim','dec','sz','ST','dt','sfr','sfg');
%disp(sprintf('Fichier: %s créé.',f_sefr))
%clear ds

ns = length(vn);
tn = min(t);
tm = max(t);

k = find(t > (tm - G.lst));
ik = find(tf > (tm - G.lst));
if ~isempty(ik)
    fk = f(ik);
    itk = (tf(ik) - tf(ik(1)))/samp/dec + 1;
end

% Calcul d'offset, de bruit et de symétrie
mx = minmax(d(k,:));
moy = mean(d(k,:));
%ety = std(diff(d(k,:)));
ety = rstd(d(k,:));
for i = 1:size(d,2)
    ets(i) = rstd(d(k(find(d(k,i)-moy(i) >= 0)),i)) - rstd(d(k(find(d(k,i)-moy(i) <= 0)),i));
end
eac = tm > (datenum(tnow)-G.lst);
%eta = (abs(moy) <= vmm) & (ety <= vsm) & (ety >= vsn) & (abs(ets) <= vsy);
eta = abs(moy) <= vmm & ety >= vsn & ety <= 2*vsm & abs(ets) <= vsy;


% Etat des stations
etats = zeros(length(ST.cod),1);
acquis = zeros(length(ST.cod),1);
nbst = zeros(length(ST.cod),1);
for i = 1:length(etats)
    kk = find(strcmp(ST.dat(i),vn) & ST.ope(i) == 1);
    if ~isempty(kk)
        etats(i) = 100*eta(kk);
        acquis(i) = 100;
        nbst(i) = kk - 1;
        sd{i} = sprintf('Z %1.0f ± %1.1f (%1.0f)',moy(kk),ety(kk),ets(kk));
    else
        sd{i} = '';
    end
    disp(sprintf('scod=%s ST.dat=%s ST.ope=%d sd=',char(scod(i)),char(ST.dat(i)),ST.ope(i),sd{i}));
    % stations 3 composantes ZNE
    if find(strcmp(ST.cod(i),st3))
        kk = find(strcmp([sdat(i,1:3),'N'],vn));
        if ~isempty(kk)
            etats(i) = etats(i) + 100*eta(kk);
            sd{i} = sprintf('%s, N %1.0f ± %1.1f (%1.0f)',sd{i},moy(kk),ety(kk),ets(kk));
        end
        kk = find(strcmp([sdat(i,1:3),'E'],vn));
        if ~isempty(kk)
            etats(i) = etats(i) + 100*eta(kk);
            sd{i} = sprintf('%s, E %1.0f ± %1.1f (%1.0f)',sd{i},moy(kk),ety(kk),ets(kk));
        end
        etats(i) = round(etats(i)/3);
    end
    if mat ~= -1 & acquis(i)
	    mketat(etats(i),tm,sd{i},lower(deblank(scod(i,:))),G.utc,acquis(i))
    else
	    disp(sprintf('Pas de mketat pour la station %s',char(ST.dat(i))));
    end
end

% état du réseau (stations acquises seulement)
kx = find(acquis);
etat = mean(etats(kx))*eac;
acqui = 100*length(find(~isnan(t)))/sz;
nx = length(kx);
if mat ~= -1
    mketat(eac*100,tm,stype,'gszacq0',G.utc,acqui)
    mketat(etat,tm,sprintf('%s %d %s',stype,nx,G.snm),rcode,G.utc,acqui)
end

% ====================================================================================================
% Graphe des derniers fichiers continus
if mat ~= -1
    figure(1), clf, orient tall
    
    stitre = sprintf('%s: %s',rcode,sname);
    G.tit = gtitle(stitre,'24h');
	G.eta = [max(t),etat,acqui];
	
    subplot(10,1,1:10), extaxes
    hold on
    for i = 1:ns
        yl = i*diff(mx);
        plot(d(:,i) - yl,'-k');
        text(0,-yl,sprintf('%s %02d ',vn{i},i-1),'FontSize',6,'FontWeight','bold','HorizontalAlignment','right','VerticalAlignment','middle')
    end
    hold off
    set(gca,'XLim',[0 length(d)],'YLim',[-(ns+1)*diff(mx),0])
    set(gca,'YTick',[],'XTick',[])
    tlabel([t(k(1)),tm],G.utc)
    pos = get(gca,'position');
    %set(gca,'position',[pos(1) pos(2)-.05 pos(3:4)])
    title(sprintf('Offset max = {\\bf\\pm%d} - Bruit min = {\\bf%d}, max = {\\bf%d} - Antisymétrie max = {\\bf%d} - Décimation = {\\bf%d} échantillons',vmm,vsn,2*vsm,vsy,dec),'Fontsize',8)
    
    G.inf = {'Dernière mesure:',sprintf('{\\bf%s} {\\it%+d}',datestr(tm),G.utc)};
    
    mkgraph(sprintf('%s_%s',rcode,G.ext{1}),G)
end

t2 = ceil(datenum(tnow)/dt)*dt;
t1 = t2 - tlim - dt;
scd = (4096/dt)/20;
rsx = dt/samp/dec;
itnow = floor(mod(t2,1)/samp/dec) + 1;
%kt = [(itnow + 1):sz,(1:itnow)]';
kt = mod((1:sz)' + itnow,sz) + 1;


% ====================================================================================================
% Graphes des tambours 24 h
switch mat
    case -1, tamb = 1;
    case -2, tamb = 0;
    otherwise, tamb = length(kx);
end
tt = reshape(t(kt),[rsx sz/rsx])';
ttt = (t1:dt:t2)';
%ttt(end) = [];
rcol = [0,0,0;1,0,0;0,0,.8;0,.6,0];
for st = 1:tamb
    ix = nbst(kx(st)) + 1;
    stn = deblank(scod(kx(st),:));
    san = deblank(sdat(kx(st),:));
    nuv = 1;
    if ~isempty(find(strcmp(san,st3)))
        nuv = 3;
    end
    for iv = 0:(nuv-1)
        dd = reshape(d(kt,ix + iv),[rsx sz/rsx])';
        irig = reshape(d(kt,end),[rsx sz/rsx])';
        bruit = rstd(dd(:));
        scdd = scd;
        % force l'échelle 1/5 pour MLGT et 1/1 pour les autres
        if strcmp(san,'MLGZ')
        %if bruit > vsm | strcmp(stn,'MLGZ')
            scdd = scd*5;
        end
        figure(1), clf, orient tall

        stitre = sprintf('%s\\_%d: %s %s',ST.ali{kx(st)},iv,ST.nom{kx(st)},suv{iv+1});
        G.tit = gtitle(stitre,'24h');
        G.eta = [t2,100*eta(ix+iv),acqui];
        k = find(d(:,end) == 0);
        if ~isempty(k)
            co = sprintf('{\\bfHorloge:} Problème IRIG (%d%%) !',round(100*length(k)/length(t)));
        else
            co = ' ';
        end
        G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(tm),G.utc), ...
                sprintf('Bruit total = {\\bf\\pm%1.1f}',bruit), ...
                sprintf('Echelle = {\\bf1/%g}',scdd/scd), ...
                co, ...
                sprintf('Offset signal = {\\bf%+1.1f}',moy(ix+iv)), ...
                sprintf('Bruit signal = {\\bf\\pm%1.1f}',ety(ix+iv)), ...
                sprintf('Asymétrie signal = {\\bf%+1.1f}',ets(ix+iv)), ...
            };
    
        subplot(8,1,1:8), extaxes
        pos = get(gca,'position');
		set(gca,'Position',[pos(1)-.01,pos(2)-.01,pos(3:4)])
        i5 = (1:14)'/(samp*dec*1440);
        plot([i5,i5]',[t1*ones(size(i5)),t2*ones(size(i5))]','Color',gris,'LineWidth',1)
        hold on
        for i = 1:(length(ttt) - 1)
            c = rcol(mod(floor(ttt(i)/dt),4)+1,:);
            if i == 1, ii = size(tt,1); else ii = i - 1; end
            if find(irig(ii,:) == 0), c = gris; end
            ddd = NaN*dd(ii,:);
            k = find(tt(ii,:) > ttt(i) & tt(ii,:) < ttt(i+1));
            if ~isempty(k)
                ddd(k) = dd(ii,k);
                plot(ddd/scdd + ttt(i) - rmean(ddd)/scdd,'Color',c)
            end
        end
        hold off
        box on
        set(gca,'YLim',[t1-dt t2],'FontSize',8)
        set(gca,'XLim',[0 rsx],'XTick',0:(1/(samp*dec*1440)):sz,'XTickLabel',num2str((0:15)'))
        datetick('y',15,'keeplimits')
        tlabel([t1,t2],G.utc)
        h1 = gca;
        ytl = get(h1,'YTickLabel');
        if size(ytl,2) == 5, ytl(:,4:5) = repmat('15',length(ytl),1); end
        h2 = axes('Position',get(h1,'Position'));
        set(h2,'YLim',get(h1,'YLim'),'Color','none','Layer','top')
        set(h2,'XLim',get(h1,'XLim'),'XTick',get(h1,'XTick'),'XTickLabel',get(h1,'XTickLabel'),'XAxisLocation','top')
        set(h2,'YTick',get(h1,'YTick'),'YTickLabel',ytl,'YAxisLocation','right')
        set(h2,'FontSize',7)
    
        mkgraph(sprintf('%s_%d_24h',lower(stn),iv),G)
        G.sta = [G.sta;{sprintf('%s_%d',lower(stn),iv)}];
        G.ali = [G.ali;{sprintf('%s_%s',san,suv{iv+1})}];

        % Copie des images pour gravure quotidienne (jour courant)
	thier = datevec(datenum(tnow)-1);
        rep_tambours = sprintf('%s/graphes/tambours/%4d%02d%02d',pdon,thier(1:3));
        if ~exist(rep_tambours,'dir')
            unix(sprintf('mkdir -p %s',rep_tambours));
	end
        f = sprintf('%s/%4d%02d%02d_%s_%d_24h.png',rep_tambours,thier(1:3),lower(stn),iv);
        if ~exist(f,'file')
            unix(sprintf('cp -fpu %s/%s/%s_%d_24h.png %s',pftp,X.MKGRAPH_PATH_FTP,lower(stn),iv,f));
            disp(sprintf('Graphe: %s archivé pour gravure.',f));
        end
    end
end
close

G.ext = [{'ico'};G.ext];
htmgraph(G);

timelog(rcode,2)
