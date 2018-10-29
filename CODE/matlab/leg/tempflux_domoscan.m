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
% =============== Station TASW (e.reader 2008)
st = find(strcmp(ST.dat,'TASW'));
ist = [ist,st];
scode = lower(ST.cod{st});
alias = ST.ali{st};
sdata = ST.dat{st};
sname = ST.nom{st};
stype = 'T';

% Initialisation des variables
samp = 10/86400; % pas d'échantillonnage des données (en jour)
last = 2/24;    % délai d'estimation pour l'état de la station (en jour)
NFilter = 20;   % length of filtering in mn, let = 0 for no filtering
NUnits = 60;    % Number of seconds in one minute
dt = 2;         % sampling interval in seconds

% fichier d'etalonnage des 2 sondes CTN (2008 à 2009-05-14)
ctn = load(sprintf('%s/TASW/CTN2008_etal.dat',pftp));

% fichier d'etalonnage des 4 sondes CTN 2k (2009-05-14)
ctn2 = load(sprintf('%s/TASW/CTN2009_etal.dat',pftp));
tmod_ctn2 = datenum(2009,5,14,11,0,0);

% fichier d'etalonnage des 4 sondes CTN 5k (2009-05-29)
ctn5 = load(sprintf('%s/TASW/CTN2009_etal5k.dat',pftp));
tmod_ctn5 = datenum(2009,5,29,10,0,0);

G.cpr = 'OVSG-IPGP';
if isfield(G,'lg2')
	rmfield(G,'lg2');
end
stitre = sprintf('%s: %s',alias,sname);
pdat = sprintf('%s/%s/e.reader',pftp,sdata);

% Importation des anciennes données manuelles
f = sprintf('%s/%s/%s_MAN.TXT',pftp,sdata,sdata);
if exist(f,'file')
    [y,m,j,d0,d1] = textread(f,'%d-%d-%d %n%n%*[^\n]','commentstyle','shell');
    fprintf('File: %s imported.\n',f)
    t0 = datenum(y,m,j);
else
    t0 = [];
    d0 = [];
end


% Modifications pas d'échantillonnage et voies de mesures
tmod_acq10s = datenum(2009,5,14,10,11,30);
tmod_11voies = datenum(2009,5,18,15,55,0);
tmod_8voies = datenum(2009,5,22,16,2,10);

% Chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,scode);
if mat & exist(f_save,'file')
    load(f_save,'t','d','old_files');
    fprintf('File: %s imported.\n',f_save)
else
    disp('No temporary data backup or rebuild forced (MAT=0). Loading all available data...');
    t = [];
    d = [];
    old_files = '';
end

% Chargement des fichiers e.reader (*.dat)
[s,w] = unix(sprintf('find %s -type f -name ''*.dat''|sort',pdat));
files = strread(w,'%s');
new_files = setdiff(files,old_files);

for i = 1:length(new_files)
	D = readudbf(new_files{i});
	if D.time(1) < tmod_acq10s
     		D.time = rdecim(D.time,5);
		D.data = rdecim(D.data,5);
	end
	if D.time(1) < tmod_11voies
		D.data = [D.data,NaN*zeros(size(D.data,1),3)];
	end
	if size(D.data,2) ~= 11
		D.data = [D.data,NaN*zeros(size(D.data,1),11-size(D.data,2))];
	end
	t = [t;D.time];
	d = [d;D.data];
	fprintf('File: %s imported.\n',new_files{i})
end

% Tri des donnees
[t,i] = sort(t);
d = d(i,:);

old_files = files;

% sauvegarde Matlab en 2 temps pour éviter les fichiers corrompus
if length(new_files)
	f = sprintf('%s.part',f_save);
	save(f)
	unix(sprintf('mv -f %s %s',f,f_save));
	fprintf('File: temporary backup %s updated.\n',f_save)
end

% le fichier .clb applique le filtre min-max et l'historique des offsets
% mais reste en unités mA (avant SDI12) et kOhm
[d,C] = calib(t,d,ST.clb(st));
nx = ST.clb(st).nx;
tlast(2) = t(end);

% Rétablit l'ordre des colonnes dans la matrice de données :
%   1 = Niveau du lac (mA ou m)
%   2 = Température fond CTN 1 (kOhm)
%   3 = Température fond CTN 2 (kOhm)
%   4 = Température fond CTN 3 (kOhm)
%   5 = Température fond CTN 4 (kOhm)
%   6 = Pression (mbar)
%   7 = Température OTT (C)

k = find(t >= tmod_11voies & t < tmod_8voies);
d(k,1:7) = d(k,[9,1,2,3,4,10,11]);

k = find(t >= tmod_8voies);
d(k,1:5) = d(k,[5,1,2,3,4]);

C.nm(1:7) = C.nm([9,1,2,3,4,10,11]);
C.un(1:7) = C.un([9,1,2,3,4,10,11]);

% efface les colonnes inutiles
d(:,6:end) = [];
nx = 5;

% calibration du niveau (en m)
k = find(t < tmod_11voies | t >= tmod_8voies);
d(k,1) = (d(k,1)-4)*30/16;
C.un{1} = 'm';

% calibration des sondes CTN (en °C)
k = find(t < tmod_ctn2);
d(k,2) = interp1(ctn(:,1),ctn(:,2),d(k,2));
d(k,3) = interp1(ctn(:,1),ctn(:,2),d(k,3));
k = find(t >= tmod_ctn2 & t < tmod_ctn5);
d(k,2) = interp1(ctn2(:,1),ctn2(:,2),d(k,2));
d(k,3) = interp1(ctn2(:,1),ctn2(:,2),d(k,3));
d(k,4) = interp1(ctn2(:,1),ctn2(:,2),d(k,4));
d(k,5) = interp1(ctn2(:,1),ctn2(:,2),d(k,5));

% calibration avec formule théorique et coefficient B25/100 EPCOS = 3497
k = find(t >= tmod_ctn5);
d(k,2:5) = 1./(log((d(k,2:5)-0.012)/5)/3497 + 1/(25+273.15)) - 273.15;

C.un{2} = 'C';
C.un{3} = 'C';
C.un{4} = 'C';
C.un{5} = 'C';

% sauvegarde des donnees pour traitements complementaires
f = sprintf('%s/past/MONITAR.mat',X.RACINE_OUTPUT_MATLAB);
save(sprintf('%s.part',f),'t','d','C','METEO','G');
unix(sprintf('mv -f %s.part %s',f,f));
fprintf('File: %s saved.\n',f);

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
    if nargin > 2
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
        G.cum{ivg} = OPT.cum;
        G.dec{ivg} = OPT.dec;
    else    
        dtemps = abs(diff([t1 t2]));
        OPT.dec = 1;
        if dtemps > 15, OPT.dec = 6; end
        if dtemps > 180, OPT.dec = 144; end
        OPT.exp = 0;
    end
end


% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{end}(1) & t<=G.lim{end}(2));
    DOUT(3).code = scode;
    DOUT(3).time = t(k);
    DOUT(3).data = d(k,:);
    DOUT(3).chan = C.nm;
    DOUT(3).unit = C.un;
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% Exportation des données en fichier (sur requete)
if ivg == length(G.ext) & OPT.exp
    k = find(t >= G.lim{ivg}(1) & t <= G.lim{ivg}(2));
    tv = datevec(t(k));
    f = sprintf('%s/%s/%s.dat',pwww,dirspec,scode);
    fid = fopen(f,'wt');
    fprintf(fid, '# DATE: %s\r\n', datestr(now));
    fprintf(fid, '# TITL: %s %s - data from %s to %s\r\n',upper(scode),sname,datestr(G.lim{ivg}(1)),datestr(G.lim{ivg}(2)));
    fprintf(fid, '# SAMP: %g s\r\n',samp*86400);
    fprintf(fid, '# CHAN: YYYY-MM-DD HH:NN:SS');
    for i = 1:nx
        fprintf(fid,' %s_(%s)',C.nm{i},C.un{i});
    end
    fprintf(fid,'\r\n');
    sfmt = '%4d-%02d-%02d %02d:%02d:%02.0f';
    for i = 1:nx
        sfmt = [sfmt,'\t%g'];
    end
    sfmt = [sfmt,' \r\n'];
    fprintf(fid,sfmt,[tv(:,1:6),d(k,:)]');
    fclose(fid);
    fprintf('File: %s created.\n',f)
end

% ----------------------- Tracé des graphes

for ig = ivg

    figure(1), clf, orient tall
    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    k0 = find(t0>=G.lim{ig}(1) & t0<=G.lim{ig}(2) & d0~=-1);

    % Etat de la station
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    ke = find(t >= (G.lim{ig}(2)-last));
    if ~isempty(ke) & ~isempty(k)
        etat = 0;
        for i = 1:nx
            if any(~isnan(d(ke,i)))
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
        etats(3) = etat;
        acquis(3) = acqui;
        sd = sprintf('%1.2f %s',d(end,1),C.un{1});
        for ii = 2:nx
            sd = [sd,sprintf(', %1.2f %s',d(end,ii),C.un{ii})];
        end
        mketat(etat,tlast(2),sd,scode,tu,acqui)
    end

    if ~isempty(k)
        ke = k(end);

        G.inf = {'Dernière mesure:', sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),tu),' ',' ', ...
				' ', ...
                sprintf('01. %s = {\\bf%1.2f %s}',C.nm{1},d(ke,1),C.un{1}), ...
                sprintf('02. %s = {\\bf%1.2f %s}',C.nm{2},d(ke,2),C.un{2}), ...
                sprintf('03. %s = {\\bf%1.2f %s}',C.nm{3},d(ke,3),C.un{3}), ...
                sprintf('04. %s = {\\bf%1.2f %s}',C.nm{4},d(ke,4),C.un{4}), ...
                sprintf('05. %s = {\\bf%1.2f %s}',C.nm{5},d(ke,5),C.un{5}), ...
             };
	else
	    G.inf = {''};
    end

    if ig==1
    
        if length(k) > NFilter    
		% filtrage des donnees
		[df,kf] = MA_Filter(d(k,1:5),NFilter,NUnits,dt,'triangular');
	else
		df = d(k,1:5)*NaN;
		kf = 1:length(k);
	end	
    end

    % Plot Niveau (brut et filtre)
    g = 1;
    subplot(7,1,3:5), extaxes
    %plot(t(k),d(k,g),'.','MarkerSize',G.mks{ig})
    plot(t(k),d(k,g))
    %if ig==1
    %	hold on
    %	plot(t(k(kf)),df(kf,g),'k','LineWidth',2)
    %	hold off
    %end
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('%s (%s)',C.nm{g},C.un{g}))
    if ~any(~isnan(d(k,g))), nodata(G.lim{ig}), end
    grid on

    % Plot températures fond + filtrées + température manuelle
    g = 2:5;
    
    subplot(7,1,1:2), extaxes
    if ~isempty(k)
        %plot(t(k),d(k,g),'.','MarkerSize',G.mks{ig})
        plot(t(k),d(k,g),'.','MarkerSize',2)
	ddd = d(k,g);
	kk = find(~isnan(ddd));
	xx = mean(median(ddd(kk)));
	ss = mean(std(ddd(kk)));
	set(gca,'Ylim',xx+2*ss*[-1,1])
    end
    if ~isempty(k0)
        hold on
        plot(t0(k0),d0(k0),'d','Color',[0 .7 0],'Markersize',2)
        hold off
    end
    ylim = get(gca,'YLim');
    set(gca,'XLim',G.lim{ig},'YLim',ylim,'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Températures CTN (%s)',C.un{g(1)}))
    if ~any(~isnan(d(k,g))), nodata(G.lim{ig}), end
    grid on
    if ig==1
    	if ~isempty(k0)
        	[h,ho] = legend(C.nm{g(1)},C.nm{g(2)},C.nm{g(3)},C.nm{g(4)},'Mesures manuelles',0);
    	else
        	[h,ho] = legend(C.nm{g(1)},C.nm{g(2)},C.nm{g(3)},C.nm{g(4)},0);
    	end
    else
    	if ~isempty(k0)
        	[h,ho] = legend(C.nm{g(1)},C.nm{g(2)},C.nm{g(3)},C.nm{g(4)},'Mesures manuelles',0);
    	else
        	[h,ho] = legend(C.nm{g(1)},C.nm{g(2)},C.nm{g(3)},C.nm{g(4)},0);
    	end
    end
    set(findobj(ho,'Type','line'),'MarkerSize',20);

    % Pluie SANNER (histogrammes glissants horaire / diurne / mensuel)
    subplot(7,1,6:7), extaxes
    kimp = find(METEO(2).time>=G.lim{ig}(1) & METEO(2).time<=G.lim{ig}(2));
    dtemps = diff(G.lim{ig});
    if dtemps < 100
        area(METEO(2).time(kimp),METEO(2).data(kimp,[10,11]))
        h = legend('Hist. glissant horaire (mm/h)','Hist. glissant diurne (mm/j)',0);
    else
        area(METEO(2).time(kimp),METEO(2).data(kimp,[11,12]))
        h = legend('Hist. glissant diurne (mm/j)','Hist. glissant mensuel (mm/30j)',0);
    end
    colormap([0,1,0;0,1,1]), grid on
    set(h,'FontSize',8)
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Pluie SANNER (mm)'))

    tlabel(G.lim{ig},tu)

    mkgraph(sprintf('%s_%s',scode,G.ext{ig}),G,OPT)
    
end
close


% ===================================================================
% =============== Station CRAW (e.reader 2009)
st = find(strcmp(ST.dat,'CRAW'));
ist = [ist,st];
scode = lower(ST.cod{st});
alias = ST.ali{st};
sdata = ST.dat{st};
sname = ST.nom{st};
stype = 'T';

% Initialisation des variables
samp = 10/86400; % pas d'échantillonnage des données (en jour)
last = 2/24;    % délai d'estimation pour l'état de la station (en jour)
tdeb = datenum(2009,5,24,16,0,0);	% début de l'acquisition des données

G.cpr = 'OVSG-IPGP';
if isfield(G,'lg2')
	rmfield(G,'lg2');
end
stitre = sprintf('%s: %s',alias,sname);
pdat = sprintf('%s/%s/e.reader',pftp,sdata);

% Chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,scode);
if mat & exist(f_save,'file')
    load(f_save,'t','d','old_files');
    fprintf('File: %s imported.\n',f_save)
else
    disp('No temporary data backup or rebuild forced (MAT=0). Loading all available data...');
    t = [];
    d = [];
    old_files = '';
end

% Chargement des fichiers e.reader (*.dat)
[s,w] = unix(sprintf('find %s -type f -name ''*.dat''|sort',pdat));
files = strread(w,'%s');
new_files = setdiff(files,old_files);

for i = 1:length(new_files)
	D = readudbf(new_files{i});
	fprintf('File: %s read. ',new_files{i})

	% Inversion MELIMELO pour retrouver les 16 mesures de résistances
	if ~isempty(D.data) & D.StartTime >= tdeb
		R = reversemelimelo(D);
	
		t = [t;R.time];
		d = [d;R.data];
		fprintf('Reversemelimelo done!\n')
	else
		fprintf('No valid data. File not imported.\n')
	end
end

% Tri des donnees
[t,i] = sort(t);
d = d(i,:);

old_files = files;
% sauvegarde Matlab en 2 temps pour éviter les fichiers corrompus
f = sprintf('%s.part',f_save);
save(f)
unix(sprintf('mv -f %s %s',f,f_save));
fprintf('File: temporary backup %s updated.\n',f_save)
	
% le fichier .clb applique le filtre min-max et l'historique des offsets
% mais reste en unités kOhm
[d,C] = calib(t,d,ST.clb(st));
nx = ST.clb(st).nx;
tlast(2) = t(end);

% Calibration des sondes CTN avec formule théorique et coefficient B25/100 EPCOS = 3436 (2k) et 3497 (5k)
i2 = [1:6,8:16];	% les sondes 2k
d(:,i2) = 1./(log((d(:,i2))/2)/3436 + 1/(25+273.15)) - 273.15;
i5 = 7;			% la sonde 5k
d(:,i5) = 1./(log((d(:,i5))/5)/3497 + 1/(25+273.15)) - 273.15;

for i = 1:16
	C.un{i} = 'C';
end

% sauvegarde des donnees pour traitements complementaires
f = sprintf('%s/past/MONICRA.mat',X.RACINE_OUTPUT_MATLAB);
save(sprintf('%s.part',f),'t','d','C','METEO','G');
unix(sprintf('mv -f %s.part %s',f,f));
fprintf('File: %s saved.\n',f);

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
        G.dec{ivg} = OPT.dec;
    else    
        dtemps = abs(diff([t1 t2]));
        OPT.dec = 1;
        if dtemps > 15, OPT.dec = 6; end
        if dtemps > 180, OPT.dec = 144; end
        OPT.exp = 0;
    end
end


% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{end}(1) & t<=G.lim{end}(2));
    DOUT(3).code = scode;
    DOUT(3).time = t(k);
    DOUT(3).data = d(k,:);
    DOUT(3).chan = C.nm;
    DOUT(3).unit = C.un;
end

% Si nograph==1, quitte la routine sans production de graphes
if nograph == 1, ivg = []; end

% Exportation des données en fichier (sur requete)
if ivg == length(G.ext) & OPT.exp
    k = find(t >= G.lim{ivg}(1) & t <= G.lim{ivg}(2));
    tv = datevec(t(k));
    f = sprintf('%s/%s/%s.dat',pwww,dirspec,scode);
    fid = fopen(f,'wt');
    fprintf(fid, '# DATE: %s\r\n', datestr(now));
    fprintf(fid, '# TITL: %s %s - data from %s to %s\r\n',upper(scode),sname,datestr(G.lim{ivg}(1)),datestr(G.lim{ivg}(2)));
    fprintf(fid, '# SAMP: %g s\r\n',samp*86400);
    fprintf(fid, '# CHAN: YYYY-MM-DD HH:NN:SS');
    for i = 1:nx
        fprintf(fid,' %s_(%s)',C.nm{i},C.un{i});
    end
    fprintf(fid,'\r\n');
    sfmt = '%4d-%02d-%02d %02d:%02d:%02.0f';
    for i = 1:nx
        sfmt = [sfmt,'\t%g'];
    end
    sfmt = [sfmt,' \r\n'];
    fprintf(fid,sfmt,[tv(:,1:6),d(k,:)]');
    fclose(fid);
    fprintf('File: %s created.\n',f)
end

% ----------------------- Tracé des graphes

for ig = ivg

    figure(1), clf, orient tall
    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    k0 = find(t0>=G.lim{ig}(1) & t0<=G.lim{ig}(2) & d0~=-1);

    % Etat de la station
    acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
    ke = find(t >= (G.lim{ig}(2)-last));
    if ~isempty(ke) & ~isempty(k)
        etat = 0;
        for i = 1:nx
            if any(~isnan(d(ke,i)))
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
        etats(3) = etat;
        acquis(3) = acqui;
        sd = sprintf('%1.2f %s',d(end,1),C.un{1});
        for ii = 2:nx
            sd = [sd,sprintf(', %1.2f %s',d(end,ii),C.un{ii})];
        end
        mketat(etat,tlast(2),sd,scode,tu,acqui)
    end

    if ~isempty(k)
        ke = k(end);

        G.inf = {'Dernière mesure:', sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),tu),' ',' '};
	for i = 1:16
		G.inf = [G.inf,{sprintf('%02d. %s = {\\bf%1.2f %s}',i,C.nm{i},d(ke,i),C.un{i})}];
	end
    else
	    G.inf = {''};
    end

    % Plot sondes fumerolle CSN
    g = 8:9;
    subplot(7,1,1:2), extaxes
    %plot(t(k),d(k,g),'.','MarkerSize',G.mks{ig})
    plot(t(k),d(k,g),'.','MarkerSize',.1)
    grid on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Températures CTN (%s)',C.un{1}))
    if ~any(~isnan(d(k,g))), nodata(G.lim{ig}), end
    grid on
    [h,ho] = legend('R8','R9',0);
    set(findobj(ho,'Type','line'),'MarkerSize',20);


    % Plot sondes profil
    g = [1:6,11:16];
    subplot(7,1,3:5), extaxes
    %plot(t(k),d(k,g),'.','MarkerSize',G.mks{ig})
    plot(t(k),d(k,g),'.','MarkerSize',.1)
    grid on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Températures CTN (%s)',C.un{1}))
    if ~any(~isnan(d(k,g))), nodata(G.lim{ig}), end
    grid on
    [h,ho] = legend('R1','R2','R3','R4','R5','R6','R11','R12','R13','R14','R15','R16',0);
    set(findobj(ho,'Type','line'),'MarkerSize',20);


    % Pluie SANNER (histogrammes glissants horaire / diurne / mensuel)
    subplot(7,1,6:7), extaxes
    kimp = find(METEO(2).time>=G.lim{ig}(1) & METEO(2).time<=G.lim{ig}(2));
    dtemps = diff(G.lim{ig});
    if dtemps < 100
        area(METEO(2).time(kimp),METEO(2).data(kimp,[10,11]))
        h = legend('Hist. glissant horaire (mm/h)','Hist. glissant diurne (mm/j)',0);
    else
        area(METEO(2).time(kimp),METEO(2).data(kimp,[11,12]))
        h = legend('Hist. glissant diurne (mm/j)','Hist. glissant mensuel (mm/30j)',0);
    end
    colormap([0,1,0;0,1,1]), grid on
    set(h,'FontSize',8)
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Pluie SANNER (mm)'))

    tlabel(G.lim{ig},tu)

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
