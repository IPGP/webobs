function DOUT=magn(mat,tlim,OPT,nograph,dirspec)
%MAGN Tracé des graphes du réseau magnétisme.
%       MAGN sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       MAGN(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = MAGN(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code 5 caractères
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Spécificités:
%           - jusqu'au 2000-12-08 (342) : 5 stations dans fichiers "Syy-jjj.DAT"
%           - à partir de 2000-12-23 (357) : 6 stations dans fichiers "R1yy-jjj.DAT"
%           - toutes les stations sont stockées dans un fichier unique binaire:
%               . en-tete 64 octets, dont le 18e = nombre de stations;
%               . 3 octets = donnée + 1 octet = numéro de station (poids fort);
%           - tous les fichiers contiennent des données de 00:00 à 23:59 (avec des 
%             caractères nuls pour les données non acquises).
%           - calcul des différences avec CAGM et LGTM.
%           - décimation des données (horaire ou journalier)

%   Auteurs: F. Beauducel + C. Anténor, OVSG-IPGP
%   Création : 2001-07-30
%   Mise à jour : 2009-10-06

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'MAGN';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);
ist = find(~strcmp(ST.ali,'-'));
nx = length(ist);

stype = 'T';

% Initialisation des variables
samp = 1/1440;  % pas d'échantillonnage des données (en jour)
last = 1/24;    % délai d'estimation pour l'état de la station (en jour)
iref = [1 6];   % indices stations de référence (CAGM & LGTM)

G.cpr = 'OVSG-IPGP';
G.lg2 = 'logo_umr6524.jpg';

pftp = sprintf('%s/%s',X.RACINE_FTP,X.MAGN_PATH_FTP);
pdon = sprintf('%s/%s',X.RACINE_DATA,X.MAGN_PATH_DATA);
pwww = X.RACINE_WEB;

sgra = {rcode,sprintf('%s-DIF',rcode)};
sgrn = {G.nom,sprintf('%s Différentiel',G.nom)};

% Récupère l'heure du serveur (locale = GMT-4)
tnow = datevec(now);
jnow = floor(datenum(tnow)-datenum(tnow(1),1,0));
t = [];
d = [];

% Année de début des données existantes
ydeb = 1993;
jdeb = 304;

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
if mat & exist(f_save,'file')
    load(f_save,'t','d');
    disp(sprintf('Fichier: %s importé.',f_save))
    tdeb = datevec(t(end));
    ydeb = tdeb(1);
    jdeb = floor(t(end)-datenum(ydeb,1,0))+1;
    if ydeb==tnow(1) & jdeb==jnow
        flag = 1;
    else
        flag = 0;
    end
else
    disp('Pas de sauvegarde Matlab. Chargement de toutes les données...');
    flag = 0;
end

% Chargement des fichiers journaliers (S*.DAT ou R1*.DAT)
for annee = ydeb:tnow(1)
    p = sprintf('%s/%d',pftp,annee);
    if exist(p,'dir')
        if annee==ydeb, jj = jdeb; else jj = 1; end
        for j = jj:366
            % Sauvegarde Matlab des données "anciennes"
            if ~flag & annee==tnow(1) & j==jnow
                save(f_save);
                disp(sprintf('Fichier: %s créé.',f_save))
            end
            if annee < 2001 & j < 357
                f = sprintf('%s/S%02d-%03d.DAT',p,mod(annee,100),j);
            else
                f = sprintf('%s/R1%02d-%03d.DAT',p,mod(annee,100),j);
            end
            t0 = datenum(annee,1,0) + j;
            if exist(f,'file')
                fid = fopen(f);
                hd = fread(fid,64,'uchar');
                % Extrait le nombre de stations
                ns = double(hd(18));
                % Lit les données et masque le numéro de station (1er octet)
                x = bitand(fread(fid,[ns Inf],'uint32')',hex2dec('FFFFFF'));
                if ns < nx
                    x = [x zeros([size(x,1) nx-ns])];
                end
                fclose(fid);
                disp(sprintf('Fichier: %s importé.',f))
                t = [t;linspace(t0,t0 + 1 - samp,size(x,1))'];
                d = [d;x];
            end
        end
    end
end    

% Elimine les lignes de zéros;
k = find(all(d'==0))';
t(k) = [];
d(k,:) = [];

% Calibration et filtres
sname = G.nom;
[d,C] = calib(t,d,ST.clb(ist));
so = 1:nx;

tlast = t(end);

% Interprétation des arguments d'entrée de la fonction
%	- t1 = temps min
%	- t2 = temps max
%	- structure G = paramètres de chaque graphe
%		.ext = type de graphe (durée) "station_EXT.png"
%		.lim = vecteur [tmin tmax]
%		.fmt = numéro format de date (fonction DATESTR) pour les XTick
%		.dec = décimation des données (en nombre d'échantillons)
%		.mks = taille des points de données (fonction PLOT)

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
    if nargin > 2
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
        G.dec{ivg} = OPT.dec;
    else
        dtemps = abs(diff([t1 t2]));
        OPT.dec = 1;
        if dtemps > 15, OPT.dec = 60; end
        if dtemps > 180, OPT.dec = 1440; end
        OPT.exp = 0;
    end
end


% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
    DOUT.code = rcode;
    DOUT.time = t(k);
    DOUT.data = d(k,:);
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% Exportation des données en fichier (sur requete)
if strcmp(G.ext{ivg(1)},'xxx') & OPT.exp
    k = find(t >= G.lim{ivg(1)}(1) & t <= G.lim{ivg(1)}(2));
    tv = datevec(t(k));
    f = sprintf('%s/%s/%s.dat',pwww,dirspec,rcode);
    fid = fopen(f,'wt');
    fprintf(fid, '# DATE: %s\r\n', datestr(now));
    fprintf(fid, '# TITL: %s %s - données du %s au %s\r\n',upper(rcode),sname,datestr(G.lim{ivg(1)}(1)),datestr(G.lim{ivg(1)}(2)));
    fprintf(fid, '# SAMP: %g min\r\n',samp*1440);
    fprintf(fid, '# CHAN: YYYY-MM-DD HH:NN');
    for i = 1:nx
        fprintf(fid,' %s_(%s)',C.nm{i},C.un{i});
    end
    fprintf(fid,'\r\n');
    sfmt = '%4d-%02d-%02d %02d:%02d';
    for i = 1:nx
        sfmt = [sfmt,'\t%g'];
    end
    sfmt = [sfmt,' \r\n'];
    fprintf(fid,sfmt,[tv(:,1:5),d(k,:)]');
    fclose(fid);
    disp(sprintf('Fichier: %s créé.',f))
end

% ===================== Tracé des graphes

for ig = ivg

    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if G.dec{ig} == 1 | isempty(k)
        tk = t(k);
        dk = d(k,:);
    else
        tk = rdecim(t(k),G.dec{ig});
        dk = rdecim(d(k,:),G.dec{ig});
    end

    % ---- Graphe valeurs champs bruts
    figure(1), clf, orient tall
    
    % Etat des stations
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    ke = find(t >= G.lim{ig}(2)-last);
    etats = zeros([nx 1]);
    if ~isempty(ke)
        etat = 0;
        for i = 1:nx
            if ~isempty(find(~isnan(d(ke,i))))
                etat = etat+1;
                etats(i) = 100;
            end
        end
        etat = 100*etat/length(so);
    else
        etat = 0;
    end
    
    % Titre et informations
    G.tit = gtitle(sprintf('%s: %s',sgra{1},sgrn{1}),G.ext{ig});
	G.eta = [G.lim{ig}(2),etat,acqui];

    if ig == 1
        for i = 1:nx
            ke = find(~isnan(d(:,i)));
            ks = find(strcmp(ST.ali,C.nm{i}));
            if isempty(ke), ke = 1; end
            mketat(etats(i),t(ke(end)),sprintf('%1.1f %s',d(ke(end),i),C.un{i}),lower(ST.cod{ks}),G.utc,acqui)
        end
        mketat(etat,tlast,sprintf('%s %d stations',stype,nx),rcode,G.utc,acqui)
    end

    if ~isempty(k)
        G.inf = {'Dernière mesure:', ...
     		sprintf('{\\bf%s} {\\it%+d}',datestr(t(k(end))),G.utc),' ',' ', ...
            sprintf('%d. %s = {\\bf%1.1f %s}',so(1),C.nm{so(1)},d(k(end),so(1)),C.un{so(1)}), ...
            sprintf('%d. %s = {\\bf%1.1f %s}',so(3),C.nm{so(3)},d(k(end),so(3)),C.un{so(3)}), ...
            sprintf('%d. %s = {\\bf%1.1f %s}',so(5),C.nm{so(5)},d(k(end),so(5)),C.un{so(5)}), ...
            sprintf('%d. %s = {\\bf%1.1f %s}',so(2),C.nm{so(2)},d(k(end),so(2)),C.un{so(2)}), ...
            sprintf('%d. %s = {\\bf%1.1f %s}',so(4),C.nm{so(4)},d(k(end),so(4)),C.un{so(4)}), ...
            sprintf('%d. %s = {\\bf%1.1f %s}',so(6),C.nm{so(6)},d(k(end),so(6)),C.un{so(6)}), ...
            };
	else
	    G.inf = {''};
    end
    
    % Magnétomètres
    ic = 1:nx;
    for ii = 1:length(ic)
        g = ic(ii);
        subplot(6,1,ii), extaxes
        %plot(tk,dk(:,so(g)),'.','MarkerSize',G(ig).mks,'Color',scolor(g))
        plot(tk,dk(:,so(g)),'-','LineWidth',.1,'Color',scolor(g))
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        % Force les Y-Tick-Labels à 5 chiffres significatifs: PROBLEME = le nombre de ticks
        % change au moment de la fabrication du .PS d'où des erreurs.
        %yl = get(gca,'YTick');
        %set(gca,'YTickLabel',reshape(sprintf('%05.f',yl),[5 size(yl,2)])')
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('%s (%s)',C.nm{so(g)},C.un{so(g)}))
        if length(find(~isnan(d(k,so(g)))))==0, nodata(G.lim{ig}), end
		if ii == 1 & G.dec{ig} ~= 1
			title(sprintf('Moyenne %s',adjtemps(samp*G.dec{ig})),'FontSize',8)
		end
    end

    tlabel(G.lim{ig},G.utc)
    
    mkgraph(sprintf('%s_%s',sgra{1},G.ext{ig}),G,OPT)
    
    
    % ---- Graphe valeurs différentielles
    figure(1), clf, orient tall
    
    % Titre et informations
    G.tit = gtitle(sprintf('%s: %s',sgra{2},sgrn{2}),G.ext{ig});
	G.eta = [G.lim{ig}(2),etat,acqui];

    if ~isempty(k)
        G.inf = {'Dernière mesure:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(k(end))),G.utc),' ',' '};
        hold on
        for i = 1:nx
            xl = .05 + .3*(i > 3);
            yl = .8 - .15*(mod(i-1,3)+1);
            G.inf = [G.inf,{sprintf('%d. %s = {\\bf%1.1f %s}',i,C.nm{i},d(k(end),i),C.un{i})}];
        end
        hold off
    end

    for ir = 1:length(iref)
        ic = find((1:nx) ~= iref(ir));

        % Différences temporelles
        subplot(6,1,[1:3]+(ir-1)*3)
        for ii = 1:length(ic)
            g = ic(ii);
            dm = dk(:,so(g))-dk(:,iref(ir));
            %plot(tk,dm-rmean(dm)+(3-ii)*20,'.','MarkerSize',G(ig).mks,'Color',scolor(g))
            plot(tk,dm-rmean(dm)+(3-ii)*20,'-','LineWidth',.1,'Color',scolor(g))
            hold on
        end
        hold off
        set(gca,'XLim',G.lim{ig},'YLim',[-50 50],'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('Différences %s (%s)',C.nm{iref(ir)},C.un{iref(ir)}))
		legend(C.nm(so(ic)),2)
        if ir==1 & G.dec{ig} ~= 1
            title(sprintf('Moyenne %s',adjtemps(samp*G.dec{ig})),'HorizontalAlignment','center','FontSize',8)
        end
    end

    tlabel(G.lim{ig},G.utc)
    
    mkgraph(sprintf('%s_%s',sgra{2},G.ext{ig}),G,OPT)
    
end
close

if ivg(1) == 1
    G.sta = sgra;
    G.ali = sgrn;
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)
