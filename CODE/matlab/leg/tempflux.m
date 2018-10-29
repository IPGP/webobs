function DOUT=tempflux(mat,tlim,OPT,nograph,dirspec)
%TEMPFLUX Graphes des données de temperatures et flux OVSG (ex forages).
%       TEMPFLUX sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       TEMPFLUX(MAT,TLIM,JCUM,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = TEMPFLUX(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code 5 caractères
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement pour CDEW:
%           - fichier de mesures manuelles 1968-1994 ('_MAN.TXT') où -1 = NaN
%           - fichiers journaliers en mV à partir de décembre 1994 (.MV)
%           - fichier de calibration (.CLB) pour la convertion en valeurs physique et 
%             le filtrage des données suivant des bornes
%           - affichage température: échelle Y = min 3 °C (pour voir le diurne)
%
%       Spécificités du traitement pour SAVW:
%           - fichier de mesures manuelles 1968-2001 ('_MAN.TXT') où -1 = NaN
%           - fichiers Campbell journaliers (SAMyyjjj.DAT)
%           - fichiers Nimbus manuels (Nimbus/DD-MM-YY.TXT)
%           - à partir du 23/05/2003 à 20:00 TU, la station est en TU (à cause de la 
%             mise à l'heure automatique depuis acqmtogps)
%           - fichier de calibration (.CLB) pour la convertion en valeurs physique et 
%             le filtrage des données suivant des bornes
%           - définition des capteurs et traitements : (c) Jean Vandemeulebrouck
%
%   Authors: F. Beauducel, OVSG-IPGP
%   Created : 2001-05-01
%   Updated : 2009-10-06

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'TEMPFLUX';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
tu = G.utc;        % temps réseau

G.dsp = dirspec;
ST = readst(G.cod,G.obs,-1);
% recuperation des indices par les codes 'DATA' de chaque station
ist = [];

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
pdon = sprintf('%s/%s',X.RACINE_DATA,G.don);
pwww = X.RACINE_WEB;
cinterv = .7*[1 1 1];

jnow = floor(datenum(tnow)-datenum(tnow(1),1,0));

% Importation de toutes les donn?es m?t?o SANNER depuis 2005
if ~nograph
	METEO = meteo(1,[2005,1,1,0,0,0;tnow]);
end
      

% ===================================================================
% =============== Station CDEW
st = find(strcmp(ST.dat,'CDEW'));
ist = [ist,st];

scode = lower(ST.cod{st});
alias = ST.ali{st};
sdata = ST.dat{st};
sname = ST.nom{st};
stitre = sprintf('%s : %s',alias,sname);
stype = 'T';

% Initialisation des variables
samp = 10/1440; % pas d'échantillonnage des données (en jour)
last = 2/24;    % délai d'estimation pour l'état de la station (en jour)

G.cpr = 'OVSG-IPGP';

% Importation des anciennes données manuelles
f = sprintf('%s/%s/%s_MAN.TXT',pftp,sdata,sdata);
if exist(f,'file')
    [y,m,j,d0,d1,d2,d3] = textread(f,'%d-%d-%d %n %n %n %n','headerlines',4);
    fprintf('File: %s imported.\n',f)
    t0 = datenum(y,m,j);
else
    t0 = [];
    d0 = [];
end

t = [];
d = [];

% Année et jour de début des données télémétrées
ydeb = 1994;
jdeb = 355;

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,scode);
if mat & exist(f_save,'file')
    fprintf('File: %s import...\n',f_save)
    load(f_save,'t','d');
    fprintf('File: %s imported.\n',f_save)
    tdeb = datevec(t(end));
    ydeb = tdeb(1);
    jdeb = floor(t(end)-datenum(ydeb,1,0))+1;
    if ydeb==tnow(1) & jdeb==jnow
        flag = 1;
    else
        flag = 0;
    end
else
    disp('No temporary data backup or rebuild forced (MAT=0). Loading all available data...');
    flag = 0;
end

% Chargement des fichiers journaliers (*.MV)
for annee = ydeb:tnow(1)
    p = sprintf('%s/%s/%d',pftp,sdata,annee);
    if exist(p,'dir')
        if annee==ydeb, jj = jdeb; else jj = 1; end
        for j = jj:366
            % Sauvegarde Matlab des données "anciennes"
            if (~flag & annee==tnow(1) & j==jnow) | j == 1
	        f = sprintf('%s.part',f_save);
                save(f);
		unix(sprintf('mv -f %s %s',f,f_save));
                fprintf('File: %s updated.\n',f_save)
            end
            f = sprintf('%s/%s%1d%03d.MV',p,sdata,mod(annee,10),j);
            if exist(f,'file')
		    fprintf('File: %s import...\n',f_save)
                x = load(f);
                if ~isempty(x)
                    fprintf('File: %s imported.\n',f)
                    t = [t;datenum(annee,1,0) + j + x(:,1)/24 + x(:,2)/1440];
                    d = [d;x(:,3:end)];
                end
            end
        end
    end
end    

% Calibration et filtres
dmv = d(end,:);
[d,C] = calib(t,d,ST.clb(st));
nx = ST.clb(st).nx;

so = [1,2,4];

tn = min([t0;t]);
tm = datenum(tnow);
tlast(1) = t(end);

% Décodage de l'argument TLIM
if isempty(tlim)
    ivg = 1:(length(G.ext)-2);
end
if ~isempty(tlim) & strcmp(tlim,'all')
    ivg = length(G.ext)-1;
    G.lim{ivg}(1) = min([t0;t]);
end
if ~isempty(tlim) & ~ischar(tlim)
    if size(tlim,1) == 2
        t1 = datenum(tlim(1,:));
        t2 = datenum(tlim(2,:));
    else
        t2 = datenum(tnow);
        t1 = t2 - tlim;
    end
    ivg = length(G.ext);
    G.lim{ivg} = minmax([t1 t2]);
    dtemps = abs(diff([t1 t2]));
    if nargin > 2
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
        G.cum{ivg} = OPT.cum;
        G.dec{ivg} = OPT.dec;
    else
        OPT.dec = 1;
        if dtemps > 15, OPT.dec = 6; end
        if dtemps > 180, OPT.dec = 144; end
        OPT.exp = 0;
    end
    if ~nograph
        f = sprintf('%s/%s/%s_xxx.txt',X.RACINE_WEB,dirspec,scode);
        k = find(t>=G.lim{ivg}(1) & t<=G.lim{ivg}(2));
        tt = datevec(t(k));
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s\r\n',stitre);
        fprintf(fid, '# SAMP: %d\r\n',samp*86400);
        fprintf(fid, '# CHAN: YYYY MM DD HH NN');
        fmt = '%4d-%02d-%02d %02d:%02d';
        for i = 1:nx
            fprintf(fid, ' %s_(%s)',C.nm{i},C.un{i});
            fmt = [fmt ' %0.2f'];
        end
        fprintf(fid,'\r\n');
        fmt = [fmt '\r\n'];
        fprintf(fid,fmt,[tt(:,1:5),d(k,:)]');
        fclose(fid);
        fprintf('File: %s created.\n',f)
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{end}(1) & t<=G.lim{end}(2));
    DOUT(1).code = scode;
    DOUT(1).time = t(k);
    DOUT(1).data = d(k,:);
    DOUT(1).chan = C.nm;
    DOUT(1).unit = C.un;
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% ----------------------- Tracé des graphes

for ig = ivg

    figure(1), clf
    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    k0 = find(t0>=G.lim{ig}(1) & t0<=G.lim{ig}(2) & d0~=-1);

    if G.dec{ig} == 1 | isempty(k)
        tk = t(k);
        dk = d(k,:);
    else
        tk = rdecim(t(k),G.dec{ig});
        dk = rdecim(d(k,:),G.dec{ig});
    end

    % Etat de la station
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    ke = find(t >= G.lim{ig}(2)-last);
    if ~isempty(ke)
      etat = 0;
        for i = 1:length(so)
            if any(~isnan(d(ke,so(i))))
                etat = etat+1;
            end
        end
        etat = 100*etat/length(so);
    else
        etat = 0;
    end
    
    % Titre et informations
    G.tit = gtitle(stitre,G.ext{ig});
    G.eta = [G.lim{ig}(2),etat,acqui];
	
    if ig == 1
        etats(1) = etat;
        acquis(1) = acqui;
        sd = sprintf('%0.2f %s, %0.2f %s, %0.2f %s, %0.2f %s', ...
            d(end,1),C.un{1},d(end,2),C.un{2},d(end,3),C.un{3},d(end,4),C.un{4});
        mketat(etat,tlast(1),sd,scode,tu,acqui)
    end
    
    % Calculs moyenne, différence et régression linéaire
    dmo = [d0(k0);rmean(dk(:,1:2)')'];
    if ~isempty(dmo)
        dml = dmo(end);
        dmm = rmean(dmo);
        ddf = diff(dmo([1 end]));
        drl = polyfit(([t0(k0);tk]-tk(1))/365,dmo,1);
    else
        dml = NaN;  dmm = NaN;  ddf = NaN;  drl = [NaN,NaN];
    end

    if ~isempty(k)
	    G.inf = {'Dernière mesure:', ...
		        sprintf('{\\bf%s} {\\it%+d}',datestr(t(k(end))),tu), ...
				' ',' ', ...
                sprintf('1. %s = {\\bf%1.2f %s} (%+d mV)',C.nm{1},d(k(end),1),C.un{1},dmv(1)), ...
                sprintf('2. %s = {\\bf%1.2f %s} (%+d mV)',C.nm{2},d(k(end),2),C.un{2},dmv(2)), ...
                sprintf('3. %s = {\\bf%1.2f %s} (%+d mV)',C.nm{3},d(k(end),3),C.un{3},dmv(3)), ...
                sprintf('4. %s = {\\bf%1.2f %s} (%+d mV)',C.nm{4},d(k(end),4),C.un{4},dmv(4)), ...
                sprintf('Dernière moyenne = {\\bf%1.2f %s}',dml,C.un{1}), ...
                sprintf('Moyenne totale = {\\bf%1.2f %s}',dmm,C.un{1}), ...
                sprintf('Variation = {\\bf%+1.2f %s}',ddf,C.un{1}), ...
                sprintf('Régression linéaire = {\\bf%+1.2f %s/an}',drl(1),C.un{1}), ...
         };
	else
	    G.inf = {''};
    end
	
    % Plot sondes 1 & 2
    subplot(14,1,2:9), extaxes
    plot(tk,dk(:,1),'.r',tk,dk(:,2),'.b','Markersize',G.mks{ig})
    hold on
    if ~isempty(k0)
        plot(t0(k0),d0(k0),'d','Color',[0 .7 0],'Markersize',2)
    end
    v = axis;
    ylim = v(3:4);
    if diff(ylim)<3
        ylim = [min([ylim(1) floor(mean(ylim)-1.5)]) max([ylim(2) ceil(mean(ylim)+1.5)])];
    end
    hold off
    set(gca,'XLim',G.lim{ig},'YLim',ylim,'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Température Fond de Forage (%s)',C.un{1}))
    if G.dec{ig} ~= 1
        title(sprintf('Moyenne %s',adjtemps(samp*G.dec{ig})),'HorizontalAlignment','center','FontSize',8)
    end
    if ~isempty(k0)
        h = legend(C.nm{1},C.nm{2},'Manuel');
    else
        h = legend(C.nm{1},C.nm{2});
    end

    % Plot tension batterie & température ambiante
    subplot(14,1,11:13), extaxes
    plot(tk,dk(:,4),'.m','Markersize',G.mks{ig})
    hold on
    plot(tk,dk(:,3),'.','Markersize',G.mks{ig},'Color',[0,.7,0])
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    ylim = get(gca,'YLim');
    datetick2('x',G.fmt{ig},'keeplimits')
    hold off
    ylabel(sprintf('%s (%s)',C.nm{4},C.un{4}))

    tlabel(G.lim{ig},tu)

    ploterup;
    mkgraph(sprintf('%s_%s',scode,G.ext{ig}),G,OPT)
end
close


% ===================================================================
% =============== Station GAL
st = find(strcmp(ST.dat,'GAL'));
ist = [ist,st];
scode = lower(ST.cod{st});
alias = ST.ali{st};
sdata = ST.dat{st};
sname = ST.nom{st};
stitre = sprintf('%s : %s',alias,sname);
stype = 'T';

% Initialisation des variables
samp = 1/1440; % pas d'échantillonnage des données (en jour)
last = 2/24;    % délai d'estimation pour l'état de la station (en jour)

G.cpr = 'OVSG-IPGP';

t = [];
d = [];

% Année et jour de début des données télémétrées
ydeb = 2006;
jdeb = 299;

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,scode);
if mat & exist(f_save,'file')
    fprintf('File: %s import...\n',f_save)
    load(f_save,'t','d');
    fprintf('File: %s imported.\n',f_save)
    tdeb = datevec(t(end));
    ydeb = tdeb(1);
    jdeb = floor(t(end)-datenum(ydeb,1,0))+1;
    if ydeb==tnow(1) & jdeb==jnow
        flag = 1;
    else
        flag = 0;
    end
else
    disp('No temporary data backup or rebuild forced (MAT=0). Loading all available data...');
    flag = 0;
end

% Chargement des fichiers journaliers (*.dat)
for annee = ydeb:tnow(1)
    p = sprintf('%s/%s/%d',pftp,sdata,annee);
    if exist(p,'dir')
        if annee==ydeb, jj = jdeb; else jj = 1; end
        for j = jj:366
            % Sauvegarde Matlab des données "anciennes"
            if ~flag & annee==tnow(1) & j==jnow
                save(f_save);
                fprintf('File: %s created.\n',f_save)
            end
            f = sprintf('%s/%s%02d%03d.dat',p,sdata,mod(annee,100),j);
            if exist(f,'file')
                [dd] = textread(f,'%q','delimiter',',','bufsize',8191);
                if ~isempty(dd)
			if size(dd)/18 ~= floor(size(dd)/18)
				fprintf('** Warning: file %s has not 18 columns. Not imported.\n',f)
			else
				dd = reshape(dd,[18,size(dd,1)/18])';
                    		t = [t;isodatenum(dd(:,1))];
                    		d = [d;str2double(dd(:,3:end))];
                    		fprintf('File: %s imported.\n',f)
			end
                end
            end
        end
    end
end    

% Passage en heure réseau
t = t + tu/24;
    
% Calibration et filtres
[d,C] = calib(t,d,ST.clb(st));
nx = ST.clb(st).nx;

% Definition des voies affichees
so = [1,5,9,10,11,13,16];

tn = min(t);
tm = datenum(tnow);
tlast(1) = t(end);

% Décodage de l'argument TLIM
if isempty(tlim)
    ivg = 1:(length(G.ext)-2);
end
if ~isempty(tlim) & strcmp(tlim,'all')
    ivg = length(G.ext)-1;
    G.lim{ivg}(1) = min(t);
end
if ~isempty(tlim) & ~ischar(tlim)
    if size(tlim,1) == 2
        t1 = datenum(tlim(1,:));
        t2 = datenum(tlim(2,:));
    else
        t2 = datenum(tnow);
        t1 = t2 - tlim;
    end
    ivg = length(G.ext);
    G.lim{ivg} = minmax([t1 t2]);
    dtemps = abs(diff([t1 t2]));
    if nargin > 2
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
        G.cum{ivg} = OPT.cum;
        G.dec{ivg} = OPT.dec;
    else
        G.dec{ivg} = 1;
        if dtemps > 15, G.dec{ivg} = 60; end
        if dtemps > 180, G.dec{ivg} = 1440; end
        OPT.exp = 1;
    end
    if ~nograph & OPT.exp
        f = sprintf('%s/%s/%s_xxx.txt',X.RACINE_WEB,dirspec,scode);
        k = find(t>=G.lim{ivg}(1) & t<=G.lim{ivg}(2));
        tt = datevec(t(k));
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s\r\n',stitre);
        fprintf(fid, '# SAMP: %d\r\n',samp*86400);
        fprintf(fid, '# CHAN: YYYY MM DD HH NN');
        fmt = '%4d-%02d-%02d %02d:%02d:%02.0f';
        for i = 1:nx
            fprintf(fid, ' %s_(%s)',C.nm{i},C.un{i});
            fmt = [fmt ' %0.2f'];
        end
        fprintf(fid,'\r\n');
        fmt = [fmt '\r\n'];
        fprintf(fid,fmt,[tt(:,1:6),d(k,:)]');
        fclose(fid);
        fprintf('File: %s created.\n',f)
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{end}(1) & t<=G.lim{end}(2));
    DOUT(1).code = scode;
    DOUT(1).time = t(k);
    DOUT(1).data = d(k,:);
    DOUT(1).chan = C.nm;
    DOUT(1).unit = C.un;
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% ----------------------- Tracé des graphes

for ig = ivg

    figure(1), orient tall, clf
    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));

    if G.dec{ig} == 1
        tk = t(k);
        dk = d(k,:);
    else
	fprintf('Decimation: original data are resampled by a factor of %d ...\n',G.dec{ig})
        tk = rdecim(t(k),G.dec{ig});
        dk = rdecim(d(k,:),G.dec{ig});
    end

    % Etat de la station
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    ke = find(t >= G.lim{ig}(2)-last);
    if ~isempty(ke)
      etat = 0;
        for i = 1:length(so)
            if any(~isnan(d(ke,so(i))))
                etat = etat+1;
            end
        end
        etat = 100*etat/length(so);
    else
        etat = 0;
    end
    
    % Titre et informations
    G.tit = gtitle(stitre,G.ext{ig});
    G.eta = [G.lim{ig}(2),etat,acqui];
	
    if ig == 1
        etats(1) = etat;
        acquis(1) = acqui;
	sd = [];
	for i = 1:nx
        	sd = [sd,sprintf('%0.2f %s, ', d(end,i),C.un{i})];
	end
        mketat(etat,tlast(1),sd,scode,tu,acqui)
    end
    
    if ~isempty(k)
	    G.inf = {'Dernière mesure:', ...
		        sprintf('{\\bf%s} {\\it%+d}',datestr(t(k(end))),tu), ...
				'(min|moy|max)',' '};
	    for i = 1:length(so)
	        G.inf = [G.inf,{sprintf('%d. %s = {\\bf%1.2f %s} (%1.1f|%1.1f|%1.1f)', ...
			so(i),C.nm{so(i)},d(k(end),so(i)),C.un{so(i)},rmin(d(k,so(i))),rmean(d(k,so(i))),rmax(d(k,so(i))))}];
	    end
	else
	    G.inf = {''};
    end
	
    % Temperatures: eau, cond (avg)
    subplot(7,1,1:2), extaxes
    plot(tk,dk(:,so(2)),'.b','Markersize',G.mks{ig})
    hold on
    plot(tk,dk(:,so(6)),'.r','Markersize',G.mks{ig})
    hold off
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Températures (%s)',C.un{so(2)}))
    if G.dec{ig} ~= 1
        title(sprintf('Moyenne %s',adjtemps(samp*G.dec{ig})),'HorizontalAlignment','center','FontSize',8)
    end
    h = legend(C.nm{so(2)},C.nm{so(6)},0);

    % Temperature air (avg))
    subplot(7,1,3), extaxes
    plot(tk,dk(:,so(3)),'.b','Markersize',G.mks{ig})
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylim = get(gca,'YLim');
    ylabel(sprintf('Temp. air (%s)',C.un{so(4)}))

    % ConductivitÃ©(2 sondes ?)
    subplot(7,1,4), extaxes
    plot(tk,dk(:,so(4)),'.b',tk,dk(:,so(5)),'.r','Markersize',G.mks{ig})
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylim = get(gca,'YLim');
    ylabel(sprintf('Conductivite (%s)',C.un{so(4)}))
    h = legend(C.nm{so(4)},C.nm{so(5)},0);

    % Debit
    subplot(7,1,5), extaxes
    plot(tk,dk(:,so(7)),'.b','Markersize',G.mks{ig})
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylim = get(gca,'YLim');
    ylabel(sprintf('%s (%s)',C.nm{so(7)},C.un{so(7)}))

    % Tension batterie
    subplot(7,1,6), extaxes
    plot(tk,dk(:,so(1)),'.m','Markersize',G.mks{ig})
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    ylim = get(gca,'YLim');
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('%s (%s)',C.nm{so(1)},C.un{so(1)}))

    % Pluie SANNER (histogrammes glissants horaire / diurne / mensuel)
    subplot(7,1,7), extaxes
    kimp = find(METEO(2).time>=G.lim{ig}(1) & METEO(2).time<=G.lim{ig}(2));
    dtemps = diff(G.lim{ig});
    if dtemps < 100
    	area(METEO(2).time(kimp),METEO(2).data(kimp,[10,11]))
    	h = legend('Hist. glissant horaire (mm/h)','Hist. glissant diurne (mm/j)',0);
    else
    	area(METEO(2).time(kimp),METEO(2).data(kimp,[11,12]))
    	h = legend('Hist. glissant diurne (mm/j)','Hist. glissant mensuel (mm/30j)',0);
    end
    colormap([0,1,0;0,1,1])
    set(h,'FontSize',8)
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Pluie SANNER (mm)'))
							
    tlabel(G.lim{ig},tu)

    mkgraph(sprintf('%s_%s',scode,G.ext{ig}),G,OPT)
    
   if ig == 1
        mketat(mean(etats),max(tlast),sprintf('%s %d stations',stype,length(etats)),rcode,tu,mean(acquis))
    end

end
close


G.sta = lower(ST.cod(ist));
G.ali = ST.ali(ist);
G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
htmgraph(G);

timelog(rcode,2)
