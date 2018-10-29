function DOUT=meteo(mat,tlim,OPT,nograph,dirspec)
%METEO  Tracé des graphes du réseau de station météo.
%       METEO sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       METEO(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = METEO(...) renvoie une structure DOUT contenant toutes les 
%       données des stations i :
%           DOUT(i).code = code station
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement (HOUY0):
%           - fichiers mensuels binaires (format Davis, voir rdpclink.m)
%           - fichier de calibration (.CLB) pour la conversion en valeurs 
%             physiques et le filtrage des données suivant des bornes
%
%       Spécificités du traitement (SOUY0):
%           - fichiers journaliers à partir de mai 2000 (MTO*.DAT)
%           - les données sont en heure TU mais les graphes sont en local
%           - fichier de calibration (.CLB) pour la conversion en valeurs 
%             physiques et le filtrage des données suivant des bornes
%           - copie des fichiers images dans le répertoire public
%           - ajout d'un graphe de pluie cumulée MétéoFrance ('1an' et 'all')
%           - *** ENVOI E-MAIL ALERTE EN CAS DE FORTE PLUIE ***
%
%   Auteurs: F. Beauducel + S. Acounis, OVSG-IPGP
%   Création : 2001-07-04
%   Mise à jour : 2010-07-28

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end
if nargout > 0, nograph = 1; end

rcode = 'METEO';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);

G.dsp = dirspec;
ST = readst(G.cod,G.obs);
%ist = [find(strcmp(ST.dat,'HOUELMONT')),find(strcmp(ST.dat,'SANNER'))];
ist = [find(strcmp(ST.dat,'SANNER'))];

if length(ist) > 1
% ===============================================================
% Station observatoire HOUY0

st = ist(1);
scode = ST.cod{st};
alias = ST.ali{st};
sdata = ST.dat{st};
sname = ST.nom{st};
stitre = sprintf('%s : %s',alias,sname);
stype = 'A';

% Initialisation des variables
samp = 15/1440;  % pas d'échantillonnage des données (en jour)
last = 2/24;     % délai d'estimation pour l'état de la station (en jour)

G.cpr = 'OVSG-IPGP';

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

t = [];
d = [];

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,lower(scode));
if mat & exist(f_save,'file')
    load(f_save,'t','d');
    disp(sprintf('File: %s imported.',f_save))
    tdeb = datevec(t(end)-samp);
    ydeb = tdeb(1);
    mdeb = tdeb(2)+1;
    if ydeb==tnow(1) & mdeb==tnow(2)
        flag = 1;
    else
        flag = 0;
    end
else
    disp('No temporary data backup or rebuild forced (MAT=0). Loading all available data.');
    flag = 0;
    ydeb = 2001;
    mdeb = 8;
end

% Chargement des fichiers mensuels (YYYY-MM.HOU)
for annee = ydeb:tnow(1)
    p = sprintf('%s/%s/%4d',pftp,sdata,annee);
    if exist(p,'dir')
        if annee==ydeb, mm = mdeb; else mm = 1; end
        for m = mm:12
            % Sauvegarde Matlab des données "anciennes"
            if ~flag & annee==tnow(1) & m==tnow(2)
                save(f_save);
                disp(sprintf('File: %s created.',f_save))
                flag = 1;
            end
            f = sprintf('%s/%04d-%02d.HOU',p,annee,m);
            if exist(f,'file')
                [tt,dd] = rdpclink(f);
                disp(sprintf('File: %s imported.',f))
                t = [t;tt];
                d = [d;dd(:,[3 5 6])];
            end
        end
    end
end    


% Calibration et filtres
[d,C] = calib(t,d,ST.clb(st));
nx = ST.clb(st).nx;
so = 1:nx;

tlast(st) = t(end);

% Interprétation des arguments d'entrée de la fonction
%	- t1 = temps min
%	- t2 = temps max
%	- structure G = paramètres de chaque graphe
%		.ext = type de graphe (durée) "station_EXT.png"
%		.lim = vecteur [tmin tmax]
%		.fmt = numéro format de date (fonction DATESTR) pour les XTick
%		.cum = durée cumulée pour les histogrammes (en jour)
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
        G.cum{ivg} = OPT.cum;
    end
    if ~nograph
        f = sprintf('%s/%s/%s_xxx.txt',X.RACINE_WEB,dirspec,scode);
        k = find(t>=G.lim{ivg}(1) & t<=G.lim{ivg}(2));
        tt = datevec(t(k));
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s: Météorologie\r\n',alias);
        fprintf(fid, '# SAMP: %d\r\n',samp*86400);
        fprintf(fid, '# CHAN: YYYY MM DD HH NN %s_(%s) %s_(%s) %s_(%s)\r\n',C.nm{1},C.un{1},C.nm{2},C.un{2},C.nm{3},C.un{3});
        fprintf(fid, '%4d-%02d-%02d %02d:%02d %0.2f %0.2f %0.2f\r\n',[tt(:,1:5),d(k,:)]');
        fclose(fid);
        disp(sprintf('File: %s exported.',f))
    end
end

% Renvoi des données dans DOUT, sur la période de temps G.lim(end)
if nargout > 0
    k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
    DOUT(1).code = scode;
    DOUT(1).time = t(k);
    DOUT(1).data = d(k,:);
    DOUT(1).chan = C.nm;
    DOUT(1).unit = C.un;
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% ===================== Tracé des graphes

for ig = ivg

    figure, clf
    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if isempty(k)
        ke = [];
    else
        ke = k(end);
    end

    % Etat de la station
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    if t(ke) >= G.lim{ig}(2)-last
        etat = 0;
        for i = 1:nx
            if ~isnan(d(ke,i))
                etat = etat+1;
            end
        end
        etat = 100*etat/nx;
    else
        etat = 0;
    end
    
    % Titre et informations
    subplot(4,1,1)
    axis([0 1 0 1]);
    etat100(etat,acqui,stype,samp)
    if ig == 1
        etats(st) = etat;
        acquis(st) = acqui;
        sd = '';
        for i = 1:nx
            sd = [sd sprintf(', %1.1f %s', d(end,i),C.un{i})];
        end
        mketat(etat,tlast(st),sd(3:end),lower(scode),G.utc,acqui)
    end

    gtitle(stitre,G.ext{ig})
    text(0,.9,sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc),'FontSize',10)
    text(.05,.8,{ ...
            sprintf('1. %s = {\\bf%1.1f %s}',C.nm{1},d(ke,1),C.un{1}), ...
            sprintf('2. %s = {\\bf%1.1f %s}',C.nm{2},d(ke,2),C.un{2}), ...
            sprintf('3. %s = {\\bf%1.1f %s}',C.nm{3},d(ke,3),C.un{3}), ...
            },'FontSize',8,'VerticalAlignment','top')

    % Capteurs
    ic = 1:3;
    for ii = 1:length(ic)
        g = ic(ii);
        subplot(4,1,1+ii)
        plot(t(k),d(k,so(g)),'.','MarkerSize',G.mks{ig})
        set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('%s (%s)',C.nm{so(g)},C.un{so(g)}))
        if length(find(~isnan(d(k,so(g)))))==0, nodata(G.lim{ig}), end
    end

    tlabel(G.lim{ig},G.utc)
    
    mkgraph(sprintf('%s_%s',lower(scode),G.ext{ig}),G,OPT)
    close
end
end


% ==========================================================================================================
% ===============================================================
% Station sommet SANNER

st = ist(1);
scode = ST.cod{st};
alias = ST.ali{st};
sdata = ST.dat{st};
sname = ST.nom{st};
stitre = sprintf('%s : %s',alias,sname);
stype = 'T';

% Initialisation des variables
samp = 1/144;   % pas d'échantillonnage des données (en jour)
last = 2/24;    % délai d'estimation pour l'état de la station (en jour)
s_ap = str2double(X.PLUIE_ALERTE_SEUIL);	% seuil de quantitié de pluie (mm)
i_ap = str2double(X.PLUIE_ALERTE_INTERVAL);	% interval temporel du seuil (jour)
j_ap = str2double(X.PLUIE_ALERTE_DELAI);	% délai (jour)

G.cpr = 'OVSG-IPGP';

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
pmeteo = sprintf('%s/meteo/public',X.RACINE_WEB);
ftxt = 'meteosouf.txt';
dt_data = 60;		% nombre de jours de donnÃ©es exportÃ©es en fichier

% Définit l'heure TU à partir de l'heure du serveur (locale = GMT-4)
tsta = datevec(now - str2double(X.MATLAB_SERVER_UTC)/24);
jnow = floor(datenum(tsta)-datenum(tsta(1),1,0));
%tnow = [2001 5 19 21 20 15];
t = [];
d = [];

% Année de début des données existantes
ydeb = 2000;


% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,lower(scode));
if mat & exist(f_save,'file')
    load(f_save,'t','d');
    disp(sprintf('File: %s imported.',f_save))
    tdeb = datevec(t(end));
    ydeb = tdeb(1);
    jdeb = min([jnow,floor(t(end)-datenum(ydeb,1,0)) + 1]);
    if ydeb==tsta(1) & jdeb==jnow
        flag = 1;
    else
        flag = 0;
    end
else
    disp('No temporary data backup or rebuild forced (MAT=0). Loading all available data...');
    flag = 0;
    ydeb = 2000;
    jdeb = 141;
end

% Chargement des fichiers journaliers (MTO*.DAT)
for annee = ydeb:tsta(1)
    %p = sprintf('%s/Annee%d',pftp,annee);
    p = sprintf('%s/%s/%d',pftp,sdata,annee);
    if exist(p,'dir')
        if annee==ydeb, jj = jdeb; else jj = 1; end
        for j = jj:366
            % Sauvegarde Matlab des données "anciennes"
            if ~flag & annee==tsta(1) & j==jnow
                % nettoie les données aberrantes avant de sauver...
                k = find(t < datenum(2000,1,1));
                t(k) = [];
                d(k,:) = [];
                save(sprintf('%s.part',f_save));
		unix(sprintf('mv %s.part %s',f_save,f_save));
                disp(sprintf('File: %s updated.',f_save))
            end
            f = sprintf('%s/MTO%02d%03d.DAT',p,mod(annee,100),j);
            if exist(f,'file')
                x = dlmread(f,',');
                disp(sprintf('File: %s imported.',f))
                nc = ST.clb(st).nx + 4;
				if size(x,2) >= nc
					x = x(:,1:nc);
					sz = [size(x,1),1];
					t = [t;datenum(x(:,2),ones(sz),ones(sz),floor(x(:,4)/100),mod(x(:,4),100),zeros(sz))+x(:,3)-1];
					d = [d;x(:,5:12)];
				end
            end
        end
    end
end    

% Repasse en heure locale (GMT-4)
t = t + G.utc/24;

% Elimine les dates aberrantes et les redondances et trie en ordre chronologique (!!! TRES IMPORTANT POUR LE TRAITEMENT DE L'ALERTE)
k = find(t<datenum(2000,1,1) | t>datenum(tnow));
t(k) = [];  d(k,:) = [];
[t,i] = sort(t);
d = d(i,:);
k = find(diff(t)==0);
t(k) = [];
d(k,:) = [];

% Calibration et filtres
[d,C] = calib(t,d,ST.clb(st));
nx = ST.clb(st).nx;
so = [1 2 7 6 5 4 3 8];

% Irradiation: remplace les valeurs négatives par 0
k = find(d(:,3) < 0);
d(k,3) = zeros(size(k));

% --- ancien code obsolete: corrections maintenant effectuees avec le fichier de calibration
%
%   6. girouette: corrige l'offset de 38° avant 2002-02-28 13:00 locales
%                 force NaN pour les dates entre 2003-02-13 12:10 et 2003-04-16 14:00 locales
%                 corrige l'offset de 10° entre 2003-04-16 et 2003-07-15 10:55 locales
%k = find(t <= datenum(2002,2,28,13,0,0));
%d(k,4) = mod(d(k,4) - 38,360);
%k = find(t > datenum(2003,2,13,12,10,0) & t < datenum(2003,4,16,14,0,0));
%d(k,4) = NaN;
%k = find(t > datenum(2003,4,16,14,0,0) & t < datenum(2003,7,15,10,55,0));
%d(k,4) = mod(d(k,4) - 10,360);
%k = find(t > datenum(2005,2,2,9,10,0));
%d(k,4) = NaN;
%
%   7. anémomètre: force NaN pour les dates entre 2002-09-23 12:00 et 2003-04-16 14:00 locales
%k = find(t > datenum(2002,9,12,12,0,0) & t < datenum(2003,4,16,14,0,0));
%d(k,5) = NaN;
%
%   8. pluviomètre: force NaN pour les dates entre 2003-05-23 12:00 et 2003-06-11 10:00 locales
%k = find(t > datenum(2003,5,23,12,0,0) & t < datenum(2003,6,11,10,0,0));
%d(k,6) = NaN;


% 9. Ajoute une 9ème colonne avec la pluie en continue sur i_ap jours (en mm/j)
d(:,9) = diffn(rcumsum(d(:,6)),round(i_ap/samp));

% 10-12. Ajoute 3 colonnes avec la pluie cumulee continue
d(:,10) = diffn(rcumsum(d(:,6)),round(1/24/samp));	% horaire
d(:,11) = diffn(rcumsum(d(:,6)),round(1/samp));		% diurne
d(:,12) = diffn(rcumsum(d(:,6)),round(30/samp));	% mensuel



% ===========================================================================
% Traitement de l'alerte forte pluie (coll. BRGM)
% => calcul de la pluie cumulée sur 24h : si >= 50 mm, danger d'instabilité de terrain pendant 3 jours.

if 0
%if isempty(tlim)
	k = find(t >= datenum(tnow)-j_ap);
	d_ap = d(k,9);
	k_ap = find(d_ap>=s_ap);
msg = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.PLUIE_ALERTE_NOTES);
	if ~isempty(k_ap)
		t_ap = t(k(k_ap(end)));
		m_ap = d_ap([k_ap(end),end]);
	else
		t_ap = t(k(1))-1;
		m_ap = [0,0];
	end
	if exist(X.PLUIE_ALERTE_TMP,'file')
		n_ap = load(X.PLUIE_ALERTE_TMP);
		if (t_ap+j_ap)	<= datenum(tnow)
			alerte(sprintf('LEVEE ALERTE PLUIE SOUFRIERE %s (%d j)',datestr(t_ap),j_ap),X.PLUIE_ALERTE_EMAIL);
			delete(X.PLUIE_ALERTE_TMP);
			m_ap = [0,0];
		else
			save(X.PLUIE_ALERTE_TMP,'m_ap','-ascii');
			disp(sprintf('*** ALERTE PLUIE EN COURS... %s = %g mm - %s = %g mm en %g j',datestr(t_ap),m_ap(1),datestr(t(end)),m_ap(2),i_ap));
		end
	else
		n_ap = [0,0];
	end
	if (~isempty(k_ap) & ((m_ap(1) > n_ap(1) & m_ap(1) > s_ap) | ~exist(X.PLUIE_ALERTE_TMP,'file')))
		save(X.PLUIE_ALERTE_TMP,'m_ap','-ascii');
		alerte(sprintf('ALERTE PLUIE SOUFRIERE: %s = %g mm en %g j',datestr(t_ap),m_ap(1),i_ap),X.PLUIE_ALERTE_EMAIL,msg);
	end
end

% ===========================================================================


tt = datevec(t);

    f = sprintf('%s/%s',pmeteo,ftxt);
    % Sélection des données des 60 derniers jours
    k = find(t >= datenum(tnow)-dt_data);
    fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\n', datestr(now));
        fprintf(fid, '# TITL: %s\n',stitre);
        fprintf(fid, '# SAMP: %d\n',round(samp*60*60*24));
        fprintf(fid, '# CHAN: YYYY MM DD HH NN');
        fmt = '%4d-%02d-%02d %02d:%02d';
        for i = 1:nx
            fprintf(fid, ' %s_(%s)',C.nm{i},C.un{i});
            fmt = [fmt ' %0.2f'];
        end
        fprintf(fid,'\n');
        fmt = [fmt '\n'];
        fprintf(fid,fmt,[tt(k,1:5),d(k,1:nx)]');
    fclose(fid);
    disp(sprintf('File: %s created.',f))

clear tt
tlast(st) = t(end);

if ~nograph
    % Chargement des données du pluvio "MétéoFrance" SANNER
    f = sprintf('%s/Pluvio/GMYSOU1.DAT',X.RACINE_FTP);
    [yy,mm,dd,d0,d1] = textread(f,'%n-%n-%n|%n|%n','commentstyle','shell');
    t0 = datenum(yy,mm,dd);
    disp(sprintf('File: %s imported.',f));
end

% Interprétation des arguments d'entrée de la fonction
%	- t1 = temps min
%	- t2 = temps max
%	- structure G = paramètres de chaque graphe
%		.ext = type de graphe (durée) "station_EXT.png"
%		.lim = vecteur [tmin tmax]
%		.fmt = numéro format de date (fonction DATESTR) pour les XTick
%		.cum = durée cumulée pour les histogrammes (en jour)
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
        G.cum{ivg} = OPT.cum;
    end
    if ~nograph
        f = sprintf('%s/%s/%s_xxx.txt',X.RACINE_WEB,dirspec,scode);
        k = find(t>=G.lim{ivg}(1) & t<=G.lim{ivg}(2));
        tt = datevec(t(k));
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s: Météorologie\r\n',alias);
        fprintf(fid, '# SAMP: %d\r\n',samp*86400);
        fprintf(fid, '# CHAN: YYYY MM DD HH NN');
        fmt = '%4d-%02d-%02d %02d:%02d';
        for i = 1:nx
            fprintf(fid, ' %s_(%s)',C.nm{i},C.un{i});
            fmt = [fmt ' %0.2f'];
        end
        fprintf(fid,'\r\n');
        fmt = [fmt '\r\n'];
        fprintf(fid,fmt,[tt(:,1:5),d(k,1:nx)]');
        fclose(fid);
        disp(sprintf('File: %s created.',f))
    end
end

% Renvoi des données dans DOUT, sur la période de temps G.lim(end)
if nargout > 0
    k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
    DOUT(2).code = scode;
    DOUT(2).time = t(k);
    DOUT(2).data = d(k,:);
    DOUT(2).chan = [C.nm,{'Pluie-Cumulee-Alerte','Pluie-Horaire','Pluie-Diurne','Pluie-Mensuelle'}];
    DOUT(2).unit = [C.un,{'mm','mm/h','mm/j','mm/mois'}];
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% ===================== Tracé des graphes

for ig = ivg

    figure, clf, orient tall

    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if isempty(k)
        ke = [];
    else
        ke = k(end);
    end

    % Etat de la station
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    if t(ke) >= G.lim{ig}(2)-last
        etat = 0;
        for i = 1:nx
            if ~isnan(d(ke,i))
                etat = etat+1;
            end
        end
        etat = 100*etat/nx;
    else
        etat = 0;
    end
    
    % Titre et informations
    G.tit = gtitle(stitre,G.ext{ig});
    G.eta = [G.lim{ig}(2),etat,acqui];
    if ig == 1
        etats(st) = etat;
        acquis(st) = acqui;
        sd = '';
        for i = 1:nx
            sd = [sd sprintf(', %1.1f %s', d(end,i),C.un{i})];
        end
        mketat(etat,tlast(st),sd(3:end),lower(scode),G.utc,acqui)
    end

    if ~isempty(k)
		G.inf = {'Dernière mesure:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc),'(min|moy/cum|max)',' ', ...
            sprintf('1. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{1},d(ke,1),C.un{1},rmin(d(k,1)),rmean(d(k,1)),rmax(d(k,1))) ...
            sprintf('2. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{2},d(ke,2),C.un{2},rmin(d(k,2)),rmean(d(k,2)),rmax(d(k,2))), ...
            sprintf('3. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{3},d(ke,3),C.un{3},rmin(d(k,3)),rmean(d(k,3)),rmax(d(k,3))), ...
            sprintf('4. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{4},d(ke,4),C.un{4},rmin(d(k,4)),rmean(d(k,4)),rmax(d(k,4))), ...
            sprintf('5. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{5},d(ke,5),C.un{5},rmin(d(k,5)),rmean(d(k,5)),rmax(d(k,5))), ...
            sprintf('6. %s = {\\bf%1.1f %s} (%1.1f | %1.1f / %1.1f | %1.1f)',C.nm{6},d(ke,6),C.un{6},rmin(d(k,6)),rmean(d(k,6)),rsum(d(k,6)),rmax(d(k,6))), ...
            sprintf('7. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{7},d(ke,7),C.un{7},rmin(d(k,7)),rmean(d(k,7)),rmax(d(k,7))), ...
            sprintf('8. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{8},d(ke,8),C.un{8},rmin(d(k,8)),rmean(d(k,8)),rmax(d(k,8))), ...
		};

        % Soleil (batterie / irradiation)
        h = subplot(12,3,[3 6]); extaxes
        ph = get(h,'position');
        set(h,'position',[ph(1)+.6,ph(2)+.01,ph(3)-.6,ph(4)-.01])
        plot(d(k,so(7)),d(k,so(8)),'.','MarkerSize',G.mks{ig})
        hold on, plot(d(k(end),so(7)),d(k(end),so(8)),'om','LineWidth',2), hold off
        set(gca,'XLim',[0 Inf],'FontSize',8)
	grid on
        xlabel(sprintf('%s (%s)',C.nm{so(7)},C.un{so(7)}))
        ylabel(sprintf('%s (%s)',C.nm{so(8)},C.un{so(8)}))
   
        % Pluie (journalière / horaire)
        subplot(11,1,3:4), extaxes
        g = 4;
        switch G.cum{ig}
		case 1
       		hcum = 'journalière';
		gp = 11;
        	case 30
		hcum = 'mensuelle';
		gp = 12;
		otherwise
        	hcum = 'horaire';
		gp = 10;
        end
        [ax,h1,h2] = plotyy(t(k),d(k,gp),t(k),rcumsum(d(k,so(g))),'area','plot');
	colormap([0,1,1;0,1,1]), grid on
	ylim = get(ax(1),'YLim');
        set(ax(1),'XLim',G.lim{ig},'FontSize',8)
	ylim = get(ax(2),'YLim');
        set(ax(2),'XLim',G.lim{ig},'FontSize',8,'XTick',[])
	set(h2,'LineWidth',2)
        datetick2('x',G.fmt{ig},'keeplimits')
        %if max(t0) > G.lim{ig}(1)
        %    k0 = find(t0>=G.lim{ig}(1) & t0<=G.lim{ig}(2));
        %    d0c = rcumsum(d0(k0));
	    %    axes(ax(2)), hold on
		%    plot(t0(k0),d0c,'-r')
	    %    hold off
	    %    legend(hcum,sprintf(' MétéoFrance (cumul = {\\bf%g mm})',d0c(end)),2)	
	    %    ylabel(sprintf('%s (%s)',C.nm{so(g)},C.un{so(g)}))
        %else
		ylabel(sprintf('%s %s (%s)',C.nm{so(g)},hcum,C.un{so(g)}))
        %end
		
		% -- tracé des fonds "alerte pluie" (calculé sur toutes les données...)
		vp = [diff(d(:,9)>=s_ap);-1];
		kp0 = find(vp==1);
		kp1 = find(vp==-1);
		if ~isempty(kp0)
			ylim = get(gca,'YLim');
			hold on
			for i = 1:length(kp0)
				if t(kp0(i)) >= G.lim{ig}(1) | t(kp1(i)) <= G.lim{ig}(2)
					h = fill3([t(kp0(i))*[1,1],t(kp1(i))*[1,1]],ylim([1,2,2,1]),-1*[1,1,1,1],[1,.3,.3]);
					set(h,'EdgeColor','none');
					h = fill3([t(kp1(i))*[1,1],(t(kp1(i))+j_ap)*[1,1]],ylim([1,2,2,1]),-1*[1,1,1,1],[1,.6,.6]);
					set(h,'EdgeColor','none');
				end
			end
			hold off
		end

        % Rose des vents (histogramme des directions)
        h = subplot(12,3,[1 4]);
        ph = get(h,'position');
        set(h,'position',[ph(1)-.1,ph(2)-.04,ph(3)+.04,ph(4)+.04])
        sa = 10;    % pas de l'histogramme (en degré)
        [th,rh] = rose(pi/2-d(k,so(6))*pi/180,360/sa);
        rosace(th,100*rh/length(k),'-')
        set(gca,'FontSize',8), grid on
        h = title('Rose des Vents');
        pt = get(h,'position');
        set(h,'position',[pt(1) pt(2)*1.3 pt(3)])

        % Vent (vitesse / direction)
        h = subplot(12,3,[2 5]);
        ph = get(h,'position');
        set(h,'position',[ph(1)-.1,ph(2)-.04,ph(3)+.04,ph(4)+.04])
        rosace(pi/2-d(k,so(6))*pi/180,d(k,so(5)),'.',G.mks{ig})
        [xe,ye] = pol2cart(pi/2-d(k(end),so(6))*pi/180,d(k(end),so(5)));
        hold on, plot(xe,ye,'om','LineWidth',2), hold off
        set(gca,'FontSize',8), grid on
        h = title(sprintf('Vitesse du Vent (max = {\\bf%1.1f %s})',max(d(k,so(5))),C.un{so(5)}));
        pt = get(h,'position');
        set(h,'position',[pt(1) pt(2)*1.3 pt(3)])

        % Autres capteurs
        ic = [1 2 3 5 6 7 8];
        for ii = 1:length(ic)
            g = ic(ii);
            subplot(11,1,4+ii), extaxes
            plot(t(k),d(k,so(g)),'.','MarkerSize',G.mks{ig}), grid on
            set(gca,'XLim',G.lim{ig},'FontSize',8)
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel(sprintf('%s (%s)',C.nm{so(g)},C.un{so(g)}))
            if length(find(~isnan(d(k,so(g)))))==0, nodata(G.lim{ig}), end
        end

        tlabel(G.lim{ig},G.utc)
    end
    
    f = sprintf('%s_%s',lower(scode),G.ext{ig});
    mkgraph(f,G,OPT)
    unix(sprintf('cp -f %s/%s/%s.png %s/.',pftp,X.MKGRAPH_PATH_FTP,f,pmeteo));
    close

    if ig == 1
        mketat(mean(etats),max(tlast),sprintf('%s %d stations',stype,length(etats)),rcode,G.utc,mean(acquis))
        G.sta = lower(ST.cod(ist));
        G.ali = ST.ali(ist);
        G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
        htmgraph(G);
    end
    
end

timelog(rcode,2)
