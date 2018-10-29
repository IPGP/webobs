function DOUT=sismohyp(mat,tlim,OPT,nograph,dirspec)
%SISMOHYP Graphes des Hypocentres Sismicité OVSG.
%       SISMOHYP sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       SISMOHYP(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = SISMOHYP(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code 5 caractères
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 2 fichiers de localisation (HYPOOVSG.TXT et HYPOOVSG0.TXT) lus avec "readhyp.m"
%           - interprétation des codes pour les statistiques (type de séisme)
%           - pas d'état de station
%           - graphe supplémentaire "10 derniers événements"

%   Auteurs: F. Beauducel + C. Anténor, OVSG-IPGP
%   Création : 2001-08-07
%   Mise à jour : 2013-10-23

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3
    OPT = struct('tu',0,'fmt',1,'mks',4,'cum',1,'dec',1,'exp',1, ...
        'hmmx',9,'hmmn',0.1,'hpmx',200,'hpmn',-2,'hmsk',1,'hgap',360,'hrms',0.5,'herz',100,'herh',100,'hqm','D','hfil',0, ...
        'htit','Archipel Guadeloupe','hloo',-61.7,'hloe',-60.9,'hlas',15.7,'hlan',16.5, ...
        'hcaz',68,'hcpr',200,'hcsp',0,'hanc',1,'hsta',1);
end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

% Initialisation des variables

rcode = 'SISMOHYP';
timelog(rcode,1)

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);

tu = G.utc;        % temps station (en heure TU)

sname = G.nom;
G.cpr = 'OVSG-IPGP';
pftp = sprintf('%s/%s',X.RACINE_FTP,X.SISMOHYP_PATH_FTP);
fhyp = sprintf('%s/past/HYPO_past.mat',X.RACINE_OUTPUT_MATLAB);
fdata = {'hypoovsg0.trie.txt','hypoovsg.trie.txt'};

% charge les codes de séismes
CS = codeseisme;
typeseisme = flipud(unique(CS.typ));	% liste des types de séismes (statistiques)
if nargin < 3
	OPT.htyp = CS.cde(find(CS.sel));	% liste des séismes à afficher (par défaut)
end
	
% charge les infos sur les îles
NI = readia;

C = struct('name',{'Latitude','Longitude','Profondeur','Magnitude','Phases'}, ...
    'unit',{'°N','°W','km','',''});
sgra = {sprintf('%s-ANT',rcode),sprintf('%s-GUA',rcode),sprintf('%s-SOU',rcode),sprintf('%s-DOM',rcode),sprintf('%s-XXX',rcode)};
sgrn = {'Antilles','Guadeloupe','Soufrière','Dôme',''};
sali = {'Antilles','Guadeloupe','Soufrière','Dôme','Spec'};
mlim = [-64 -59 13.5 18.5;
        -62 -60 15.5 17.334;
        -61.72 -61.60 15.99 16.11;
        -61.66997 -61.6579 16.03749 16.0493];       % limites Lon-Lat cartes
azsub = 68;                                         % azimuth perpendiculaire subduction (degrés N)
proz = [-62.0643 16.2782 (90-azsub)*pi/180 2 3 100];% projection Z [lat0 lon0 angle longW longE dist]
degkm = 6370*pi/180;                                % valeur du degré (en km)
blim = [-64 -53 12 19];                             % limites bathy 2° (Smith & Sandwell) et cotes
rprs = 2.35;                                        % rapport de taille étoile ressenti
rmks = [1 1 2 3 1];                                 % facteur de taille magnitudes
mag0 = 1;                                           % magnitude séismes mag = 0 ou NaN
%simg = [670 1003;688 1003;715 1003];		        % tailles images PNG (en pixels)
colab = .0*[1 1 1];                                 % couleur traits coupe A-B
colcn = .7*[1 1 1];                                 % couleur courbes niveau
colfa = .5*[1 1 1];                                 % couleur failles
colas = .5*[1 1 1];                                 % couleur anciens séismes
noir = [0 0 0];
stsz = 5;					    % station marker size
colst = [0 0 .7];                                 % station color

t = [];     % vecteur temps
d = [];     % matrice données
hyp = [];   % ligne hypo complète
cse = [];   % codes séismes
qml = [];   % qualité localisation
mks = [];   % matrice taille des séismes
i = 0;

% Chargement des informations pour carte spécifique
%f_spec = sprintf('%s/SISMOHYP_Spec.dat',X.RACINE_DATA_MATLAB);
%as = textread(f_spec,'%q','headerlines',1);
%GS.titre = as{1};
%gs = str2double(as(2:5));
%GS.lim = [min(gs(1:2)),max(gs(1:2)),min(gs(3:4)),max(gs(3:4))];
%GS.cpv = str2double(as(6:7));
f_spec = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.MKSPEC_FILE_SISMOHYP);
[sm_r,sm_t,sm_w,sm_e,sm_s,sm_n,sm_a,sm_d] = textread(f_spec,'%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','commentstyle','shell');
% ne garde que la première ligne où R=1
k = find(str2double(sm_r));
if ~isempty(k)
	k = k(1);
	GS.titre = sm_t{k};
	gs = str2double([sm_w(k),sm_e(k),sm_s(k),sm_n(k)]);
	GS.lim = [min(gs(1:2)),max(gs(1:2)),min(gs(3:4)),max(gs(3:4))];
	GS.cpv = str2double([sm_a(k),sm_d(k)]);
else
	GS.titre = '';
	GS.lim = [0,1,0,1];
	GS.cpv = [0,1];
end
disp(sprintf('File: %s imported.',f_spec));

% Chargement des failles
f = sprintf('%s/failles.bln',X.RACINE_DATA_MATLAB);
c_fai = ibln(f);
disp(sprintf('File: %s imported.',f))

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
if mat & exist(f_save,'file')
    load(f_save,'c_pta','c_fai','prx','pry','prz','lat2','lon2','z2','lat50','lon50','z50','lon1','lat1','bat1','t','d','hyp','cse','qml');
    i = length(t);
    disp(sprintf('File: %s imported.',f_save))
    ffi = 2;
else
    disp('WEBOBS: no Matlab backup. Reload all data...');
    f = sprintf('%s/antille2.bln',X.RACINE_DATA_MATLAB);
    c_ant = ibln(f);
    disp(sprintf('File: %s imported.',f))
    c_pta = econtour(c_ant,[],blim);
    f = sprintf('%s/mnt_guad.mat',X.RACINE_DATA_MATLAB);
    load(f);
    disp(sprintf('File: %s imported.',f))
    [im,vlat,vlon] = mygrid_sand([12 19 -64 -53],1);
    lon1 = blim(1):1/60:blim(2);
    lat1 = blim(3):1/60:blim(4);
    [xi,yi] = meshgrid(lon1,lat1);
    bat1 = griddata(vlon - 360,vlat,im,xi,yi);
    clear xi yi
    disp(sprintf('Bathymetry imported [%g %g %g %g] and interpolated at 1°',blim))
    ffi = 1;
end

% Importation des données
for nf = ffi:2
    f = sprintf('%s/%s',pftp,fdata{nf});
    DH = readhyp(f);
    t = [t;DH.tps];
    d = [d;[DH.lat,DH.lon,DH.dep,DH.mag,DH.erh,DH.msk,DH.typ,DH.gap,DH.rms,DH.erz]];
    hyp = [hyp;DH.hyp];
    cse = [cse;DH.cod];
    qml = [qml;DH.qml];
    if nf == 1 & ffi == 1
        save(f_save);
        disp(sprintf('File: %s created.',f_save))
    end
end


% Traitement des données:

%   1. range les données en ordre chronologique; **** PAS NECESSAIRE : hypoovsg.trie est déjà en ordre chronologique.
%[t,i] = sort(t);
%d = d(i,:);  cse = cse(i);

%   2. sélectionne les séismes à afficher (suivant OPT.htyp, OPT.hmmn, OPT.hmmx et OPT.hmsk)
k = find(~ismember(CS.cde(d(:,7)),OPT.htyp) ...
	| d(:,3) < OPT.hpmn | d(:,3) > OPT.hpmx | isnan(d(:,4)) | d(:,4) < OPT.hmmn | d(:,4) > OPT.hmmx ...
	| (d(:,6) > 0 & d(:,6) < OPT.hmsk) ...
	);
t(k,:) = [];  d(k,:) = [];  hyp(k) = [];  cse(k) = [];  qml(k) = [];

%   3. calcule le filtre de qualité sur les événements suivant les critères d'option OPT
k = find(isnan(d(:,8)) | d(:,8) >= OPT.hgap | (OPT.hgap ~= 0 & d(:,8) == 0) ...
          | isnan(d(:,9)) | d(:,9) >= OPT.hrms | (OPT.hrms ~= 0 & d(:,9) == 0) ...
          | isnan(d(:,5)) | d(:,5) >= OPT.herh | (OPT.herh ~= 0 & d(:,5) == 0) ...
          | isnan(d(:,10)) | d(:,10) >= OPT.herz | (OPT.herz ~= 0 & d(:,10) == 0) ...
	  | char(qml) >= OPT.hqm ...
	  );
d(:,11) = 1;	% ajoute une dernière colonne contenant le filtre

tfiltre = sprintf('Filtres:  {\\bf%g} > Md > {\\bf%g}  |  {\\bf%g km} > Prof > {\\bf%g km}  |  MSK \\geq {\\bf%s}  |  ERH < {\\bf%g km}  |  ERZ < {\\bf%g km}  |  Gap < {\\bf%g °}  |  RMS < {\\bf%g s}  |  QM \\geq {\\bf%s}',OPT.hmmx,OPT.hmmn,OPT.hpmx,OPT.hpmn,romanx(OPT.hmsk),OPT.herh,OPT.herz,OPT.hgap,OPT.hrms,OPT.hqm);

if OPT.hfil == 1	% en cas d'application du filtre, élimination pure et simple des données concernées
    t(k,:) = [];  d(k,:) = [];  hyp(k) = [];  cse(k) = [];  qml(k) = [];
else
    d(k,11) = 0;
end

tt = datevec(t);

% La matrice de données contient :
%   1 = latitude (degrés décimaux)
%   2 = longitude (degrés décimaux)
%   3 = profondeur (km)
%   4 = magnitude
%   5 = erreur horizontale (km)
%   6 = intensité (1 = non ressenti)
%   7 = type de séisme (voir "codeseisme.m")
%   8 = filtre ON/OFF (1 = OK, 0 = afficher en clair)
%   9 = gap (°)
%  10 = RMS (s)
%  11 = erreur verticale (km)

if isempty(tlim)
    ivg = 1:(length(G.ext)-2);
    if strcmp(G.ext(1),'10l')
        % Définition des temps min et max pour les 1à derniers événements
        G.lim{1} = [floor(t(end-9)) ceil(t(end))];
    end
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
    if nargin >= 3
        G.fmt{ivg} = OPT.fmt;
        %G.mks{ivg} = OPT.mks;
        G.cum{ivg} = OPT.cum;
        GS.titre = OPT.htit;
        GS.lim = [OPT.hloo,OPT.hloe,OPT.hlas,OPT.hlan];
        GS.cpv = [OPT.hcaz,OPT.hcpr];
    end
end

% Exportation des fichiers
if ivg(1) == 1
    %   1. fichier séismes ressentis
    f = sprintf('%s/Ressentis/hypo_ress.dat',pftp);
    k = find(d(:,6) > 1);
    fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s ressentie\r\n',sname);
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# CHAN: YYYY MM DD HH NN Latitude_(°) Longitude_(°) Profondeur_(km) Magnitude Intensité_(MSK) Type\r\n');
        fprintf(fid, '%4d-%02d-%02d %02d:%02d %1.5f %1.5f %3.0f %1.2f %d %d\r\n',[tt(k,1:5),d(k,[1:4 6 7])]');
    fclose(fid);
    disp(sprintf('File: %s created.',f))
    %   2. fichier matlab pour RAP
    save(fhyp)
    disp(sprintf('File: %s created.',fhyp));
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
    DOUT.code = rcode;
    DOUT.time = t(k);
    DOUT.data = d(k,:);
end

% Si nograph==1, quitte la routine sans production de graphes
if nargin > 3
    if nograph == 1, G = []; end
end


sgrn{end} = GS.titre;

% ===================== Tracé des graphes

for ig = ivg

    % ==============================================================================================
    % ======= Carte ANTILLES
    st = 1;
    figure(1), clf, orient tall
    k = find(d(:,2)>=mlim(st,1) & d(:,2)<=mlim(st,2) & d(:,1)>=mlim(st,3) & d(:,1)<=mlim(st,4));
    k_all = k;
    if G.ext{ig}(3)=='l' & ~strcmp(G.ext{ig},'all')
        G.lim{ig} = [t(k(end+1-str2num(G.ext{ig}(1:2)))),t(k(end))];
    end
    kk = find(t(k)>=G.lim{ig}(1) & t(k)<=G.lim{ig}(2));
    if ~isempty(kk)
        k = k(kk);
        ke = k(end);
    else
        k = [];
        ke = [];    
    end
    
    % --- Titre et statistiques
    subplot(12,1,1)
    axis([0 1 0 1]);
    axis off
    gtitle(sprintf('%s: %s %s',rcode,sname,sgrn{st}),G.ext{ig})
    if ~isempty(k)
        text(0,.4,{ ...
            'Dernier événement:', ...
            sprintf('   Date: {\\bf%s} {\\it%+d}',datestr(t(ke)),tu), ...
            sprintf('   Lat = {\\bf%s}, Lon = {\\bf%s}',ll2dms(d(ke,1),'lat'),ll2dms(d(ke,2),'lon')), ...
            sprintf('   Prof = {\\bf%g %s}, Md = {\\bf%1.1f %s}',d(ke,3),C(3).unit,d(ke,4),C(4).unit), ...
            sprintf('   Type = {\\bf%s (%s)}',CS.nom{d(ke,7)},deblank(cse{ke})), ...
            },'FontSize',8)
    end
    tstat = {sprintf('Du: {\\bf%s} {\\it%+d} au {\\bf%s} {\\it%+d}',datestr(G.lim{ig}(1),1),tu,datestr(G.lim{ig}(2),1),tu)};
    for i = 1:length(typeseisme)
        ss = sprintf('   %s = {\\bf%d}',typeseisme{i},length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}))));
	nsr = length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1));
	if nsr > 0, ssr = sprintf(' (dont {\\bf%d} ressentis)',length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1)));
	else ssr = '';
	end
	tstat = [tstat,{[ss,ssr]}];
    end
    if ~isempty(k)
    	tstat = [tstat,{sprintf('   Magnitude max. = {\\bf%1.1f}, Intensité max. = {\\bf%s}',max(d(k,4)),romanx(max(d(k,6))))}];
    end
    text(.5,.4,tstat,'FontSize',8);
    text(.5,-.5,tfiltre,'HorizontalAlignment','center','FontSize',7)
    
    % --- Carte
    subplot(18,1,3:14)
    mpc = flipud(jet(256));
    mpc(1:30,:) = [];
    % Dessin de la bathy et des cotes
    pcontour(c_pta,[],.8*[1 1 1]), axis(mlim(st,:));
    dd2dms(gca,1), hold on
    [cc,h] = contour(lon1,lat1,bat1,-7000:500:-500);
    set(h,'EdgeColor',colcn)
    %pcolor(lon1,lat1,bat1), shading flat, colormap(bone)
    % Dessin des failles principales (1.5 à 2.5)
    plotbln(c_fai,'k');
    % Noms des iles (sauf iles Guadeloupe)
    for i = 1:length(NI)
        if NI(i).cde==0
            text(NI(i).lon,NI(i).lat,NI(i).nom, ...
                'HorizontalAlignment',NI(i).hal,'VerticalAlignment',NI(i).val, ...
                'FontWeight',NI(i).fwt,'FontAngle',NI(i).fag,'FontSize',NI(i).fsz)
        end
    end
    % Stations
    if OPT.hsta
	    plot(ST.geo(:,2),ST.geo(:,1),'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
    end
    % Ligne coupe A-B
    lproz = [proz(1)+cos(proz(3))*[-proz(4) proz(5)],proz(2)+sin(proz(3))*[-proz(4) proz(5)]];
    plot(lproz(1:2),lproz(3:4),'-.','Color',colab)
    plot(proz(1),proz(2),'o','MarkerSize',2,'Color',colab)
    plot(lproz(1:2),lproz(3:4)+proz(6)/degkm,':','Color',colab)
    plot(lproz(1:2),lproz(3:4)-proz(6)/degkm,':','Color',colab)
    text(lproz(1:2),lproz(3:4),['A';'B'],'FontSize',12,'FontWeight','bold','Color',colab)
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    % Séismes période
    xy0 = zeros(length(k),2);
    for i = 1:length(k)
        ki = k(i);
        if isnan(d(ki,4))
            mks(i) = round(((mag0*G.mks{ig})^2)*rmks(1)*OPT.mks/4) + 1;
        else
            mks(i) = round(((d(ki,4)*G.mks{ig})^2)*rmks(1)*OPT.mks/4) + 1;
        end
	impc = round(d(ki,3));
	if impc < 1, impc = 1; end
	if impc > length(mpc), impc = length(mpc); end
        xy0(i,:) = [d(ki,2),d(ki,1)];
        plot(d(ki,2),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(impc,:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    set(gca,'FontSize',8);
    axpos0 = get(gca,'position');
    box on

    % Légende
    xy = [mlim(st,1)+[.1 1.3] mlim(st,3)+[.1 1.8]];
    rectangle('position',[xy([1 3]) diff(xy(1:2)) diff(xy(3:4))],'FaceColor','w')
    text(mean(xy(1:2)),xy(4),'Légende', ...
        'VerticalAlignment','top','HorizontalAlignment','center','FontSize',12,'FontWeight','bold')
    text(xy(1),xy(4)-.25,'  Magnitudes','FontSize',8)
    for i = 1:6
        plot(xy(1) + .2,xy(3) + .5 + .015*(i + 1)^2,'ok','MarkerSize',(i*G.mks{ig})^2*rmks(1)*OPT.mks/4 + 1)
        text(xy(1) + .4,xy(3) + .5 + .015*(i + 1)^2,sprintf('%d',i),'FontWeight','bold','FontSize',8)
    end
    text(xy(2),xy(4)-.25,'Profondeurs  ','HorizontalAlignment','right','FontSize',8)
    %fill(xy(2) - .2 + .1*[0 1 1 0],xy(3) + .5 + .8*[0 0 1 1],'w')
    for i = 1:length(mpc)
        plot(xy(2) - .2 + .1*[0 1],xy(3) + .5 + .8*[1 1]*(i-1)/length(mpc),'Color',mpc(length(mpc) - i + 1,:))
    end
    for i = 0:50:200
        text(xy(2) - .2,xy(3) + 1.3 - i*.8/200,sprintf('%d km  ',i), ...
            'HorizontalAlignment','right','FontSize',8)
    end
    plot(xy(1) + .2,xy(3) + .3,'pk','Markersize',15)
    text(xy(1) + .2,xy(3) + .3,'      Séisme ressenti','FontSize',8)
    if OPT.hsta
	    plot(xy(1) + .2,xy(3) + .1,'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    text(xy(1) + .2,xy(3) + .1,'      Stations','FontSize',8)
    end
    
    hold off
    
    % --- Coupe projection verticale sur plan A-B
    h = subplot(18,1,16:18);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)-.04 ph(3) ph(4)+.06])
    % Tracé profil Guadeloupe (MNT)
    plot(degkm*[-proz(4) proz(5)],[0 0],'-k')
    hold on
    kk = find(prz==-50);
    prz(kk) = prz(kk)*0;
    fill(max(prx),-max(prz)*20/1000,.8*[1 1 1])
    text(50,-15,'Guadeloupe (altitudes x 20)','FontSize',8)
    oxy = [d(:,2)' - proz(1);d(:,1)' - proz(2)];
    pxy = degkm*[cos(proz(3)) sin(proz(3));-sin(proz(3)) cos(proz(3))]*oxy;
    % Séismes anciens
    if OPT.hanc == 1 & ~strcmp(G.ext{ig},'all')
        kk = find(abs(pxy(2,k_all))<=proz(6));
        plot(pxy(1,k_all(kk))',d(k_all(kk),3),'.','MarkerSize',.1,'Color',colas);
    end
    j = 0;  kxy1 = [];
    for i = 1:length(k)
        ki = k(i);
        % Changement de repère (translation + rotation)
        if abs(pxy(2,ki))<=proz(6)
            j = j + 1;
            kxy1(j,:) = [i,pxy(1,ki),-d(ki,3)];
            plot(pxy(1,ki),d(ki,3), ...
            'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3))]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
            if d(ki,6) > 1
                plot(pxy(1,ki),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
            end
        end
    end
    hold off
    set(gca,'XLim',degkm*[-proz(4) proz(5)],'Ylim',[-30 200])
    mlim1 = [get(gca,'XLim'),-fliplr(get(gca,'YLim'))];
    set(gca,'YDir','reverse','FontSize',8)
    axpos1 = get(gca,'position');
    xlabel(sprintf('Projection sur coupe A-B (km) distances \\leq %g km',proz(6)))
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    
    f = sprintf('%s_%s',sgra{st},G.ext{ig});
    mkgraph(f,G,OPT)
    mkimap(f,G,t(k),d(k,:),cse(k),mks,[find(k),xy0],mlim(st,:),axpos0,kxy1,mlim1,axpos1);
    if OPT.exp
	    mkxhyp(f,G,hyp(k));
    end

    % ==============================================================================================
    % ======= Carte GUADELOUPE
    st = 2;
    figure(1), clf, orient tall
    k = find(d(:,2)>=mlim(st,1) & d(:,2)<=mlim(st,2) & d(:,1)>=mlim(st,3) & d(:,1)<=mlim(st,4));
    k_all = k;
    if G.ext{ig}(3)=='l' & ~strcmp(G.ext{ig},'all')
        G.lim{ig} = [t(k(end+1-str2num(G.ext{ig}(1:2)))),t(k(end))];
    end
    kk = find(t(k)>=G.lim{ig}(1) & t(k)<=G.lim{ig}(2));
    if ~isempty(kk)
        k = k(kk);
        ke = k(end);
    else
        k = [];
        ke = [];    
    end
    
    % --- Titre et statistiques
    subplot(12,1,1)
    axis([0 1 0 1]);
    axis off
    gtitle(sprintf('%s: %s %s',rcode,sname,sgrn{st}),G.ext{ig})
    if ~isempty(k)
        text(0,.4,{ ...
            'Dernier événement:', ...
            sprintf('   Date: {\\bf%s} {\\it%+d}',datestr(t(ke)),tu), ...
            sprintf('   Lat = {\\bf%s}, Lon = {\\bf%s}',ll2dms(d(ke,1),'lat'),ll2dms(d(ke,2),'lon')), ...
            sprintf('   Prof = {\\bf%g %s}, Md = {\\bf%1.1f %s}',d(ke,3),C(3).unit,d(ke,4),C(4).unit), ...
            sprintf('   Type = {\\bf%s (%s)}',CS.nom{d(ke,7)},deblank(cse{ke})), ...
            },'FontSize',8)
    end
    tstat = {sprintf('Du: {\\bf%s} {\\it%+d} au {\\bf%s} {\\it%+d}',datestr(G.lim{ig}(1),1),tu,datestr(G.lim{ig}(2),1),tu)};
    for i = 1:length(typeseisme)
        ss = sprintf('   %s = {\\bf%d}',typeseisme{i},length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}))));
	nsr = length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1));
	if nsr > 0, ssr = sprintf(' (dont {\\bf%d} ressentis)',length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1)));
	else ssr = '';
	end
	tstat = [tstat,{[ss,ssr]}];
    end
    if ~isempty(k)
    	tstat = [tstat,{sprintf('   Magnitude max. = {\\bf%1.1f}, Intensité max. = {\\bf%s}',max(d(k,4)),romanx(max(d(k,6))))}];
    end
    text(.5,.4,tstat,'FontSize',8);
    text(.5,-.5,tfiltre,'HorizontalAlignment','center','FontSize',7)
    
    % --- Carte
    pros = [mean(mlim(st,1:2)),mean(mlim(st,3:4)),(90-azsub)*pi/180];
    raz2 = max([diff(mlim(st,1:2)),diff(mlim(st,1:2))])/sqrt(2);
    subplot(18,1,3:14)
    mpc = flipud(jet(256));
    mpc(1:30,:) = [];
    % Dessin des cotes
    pcontour(c_pta,[],.8*[1 1 1]), axis(mlim(st,:));
    dd2dms(gca,1), hold on
    [cc,h] = contour(lon1,lat1,bat1,-7000:500:-500);
    set(h,'EdgeColor',colcn)
    % Dessin des failles principales (1 à 2.5)
    plotbln(c_fai,'k');
    % Trait de coupe
    plot(pros(1),pros(2),'ok','MarkerSize',3)
    plot(pros(1) + cos(pros(3))*raz2*[-1 1],pros(2) + sin(pros(3))*raz2*[-1 1],'-.k')
    % Noms des iles et villes
    for i = 1:length(NI)
        if NI(i).cde==1
            text(NI(i).lon,NI(i).lat,NI(i).nom, ...
                'HorizontalAlignment',NI(i).hal,'VerticalAlignment',NI(i).val, ...
                'FontWeight',NI(i).fwt,'FontAngle',NI(i).fag,'FontSize',NI(i).fsz)
        end
        if NI(i).cde==2
            plot(NI(i).lon,NI(i).lat,'sk','MarkerFaceColor','k','MarkerSize',5)
            text(NI(i).lon,NI(i).lat,[' ' NI(i).nom '  '], ...
                'HorizontalAlignment',NI(i).hal,'VerticalAlignment',NI(i).val, ...
                'FontWeight',NI(i).fwt,'FontAngle',NI(i).fag,'FontSize',NI(i).fsz)
        end
    end
    % Stations
    if OPT.hsta
	    plot(ST.geo(:,2),ST.geo(:,1),'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
    end
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    % Séismes
    xy0 = zeros(length(k),2);
    for i = 1:length(k)
        ki = k(i);
        if isnan(d(ki,4))
            mks(i) = round(((mag0*G.mks{ig})^2)*rmks(2)*OPT.mks/4) + 1;
        else
            mks(i) = round(((d(ki,4)*G.mks{ig})^2)*rmks(2)*OPT.mks/4) + 1;
        end
        xy0(i,:) = [d(ki,2),d(ki,1)];
        plot(d(ki,2),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3))]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    set(gca,'FontSize',8);
    box on
    xtickvalue = get(gca,'XTick');
    xticklabel = get(gca,'XTickLabel');
    axpos0 = get(gca,'position');
    
    % --- Coupe projection verticale 
    h = subplot(6,4,21:23);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)-.04 ph(3)+.05 ph(4)+.08])
    hold on
    oxy = [d(:,2)' - pros(1);d(:,1)' - pros(2)];
    pxy = degkm*[cos(pros(3)) sin(pros(3));-sin(pros(3)) cos(pros(3))]*oxy;
    % Séismes anciens
    if OPT.hanc == 1 & ~strcmp(G.ext{ig},'all')
        plot(pxy(1,k_all)',d(k_all,3),'.','MarkerSize',.1,'Color',colas);
    end
    kxy1 = zeros(size(k,1),3);
    for i = 1:length(k)
        ki = k(i);
        % projection suivant azimuth azsub
        kxy1(i,:) = [i,pxy(1,ki),-d(ki,3)];
        plot(pxy(1,ki),d(ki,3),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3))]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(pxy(1,ki),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    lmax = degkm*sqrt(diff(mlim(st,1:2))^2 + diff(mlim(st,3:4))^2)/2;
    set(gca,'XLim',lmax*[-1 1],'Ylim',[0 200])
    set(gca,'YDir','reverse','FontSize',8)
    mlim1 = [get(gca,'XLim'),-fliplr(get(gca,'YLim'))];
    axpos1 = get(gca,'position');
    box on
    xlabel(sprintf('Projection sur coupe verticale azimuth N%g° (%s): ditance relative (km)',azsub,char(az2comp(azsub))))
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    

    % Légende
    h = subplot(6,4,24);
    ph = get(h,'position');
    set(h,'position',[ph(1)+.02 ph(2)-.035 ph(3)+.025 ph(4)+.09])
    axis off
    hold on
    xy = [0 1.4 0 2.3];
    rectangle('position',[xy([1 3]) diff(xy(1:2)) diff(xy(3:4))],'FaceColor','w')
    text(mean(xy(1:2)),xy(4),'Légende', ...
        'VerticalAlignment','top','HorizontalAlignment','center','FontSize',12,'FontWeight','bold')
    text(xy(1),xy(4)-.25,'  Magnitudes','FontSize',8)
    for i = 1:6
        plot(xy(1) + .2,xy(3) + .5 + .02*(i + 1)^2,'ok','MarkerSize',(i*G.mks{ig})^2*rmks(1)*OPT.mks/4 + 1)
        text(xy(1) + .4,xy(3) + .5 + .02*(i + 1)^2,sprintf('%d',i),'FontWeight','bold','FontSize',8)
    end
    text(xy(2),xy(4)-.25,'Profondeurs  ','HorizontalAlignment','right','FontSize',8)
    %fill(xy(2) - .2 + .1*[0 1 1 0],xy(3) + .5 + .8*[0 0 1 1],[200 200 0 0])
    for i = 1:length(mpc)
        plot(xy(2) - .2 + .1*[0 1],xy(3) + .5 + [1 1]*(i-1)/length(mpc),'Color',mpc(length(mpc) - i + 1,:))
    end
    for i = 0:50:200
        text(xy(2) - .2,xy(3) + 1.5 - i/200,sprintf('%d km  ',i), ...
            'HorizontalAlignment','right','FontSize',8)
    end
    plot(xy(1) + .2,xy(3) + .3,'pk','Markersize',15)
    text(xy(1) + .2,xy(3) + .3,'      Séisme ressenti','FontSize',8)
    if OPT.hsta
	    plot(xy(1) + .2,xy(3) + .1,'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    text(xy(1) + .2,xy(3) + .1,'      Stations','FontSize',8)
    end
    f = sprintf('%s_%s',sgra{st},G.ext{ig});
    mkgraph(f,G,OPT)
    mkimap(f,G,t(k),d(k,:),cse(k),mks,[find(k),xy0],mlim(st,:),axpos0,kxy1,mlim1,axpos1);
    if OPT.exp
	    mkxhyp(f,G,hyp(k));
    end
    

    % ==============================================================================================
    % ======= Carte SOUFRIERE
    st = 3;
    figure(1), clf, orient tall
    pmax = 10;  % profondeur max
    k = find(d(:,3)<=pmax & d(:,2)>=mlim(st,1) & d(:,2)<=mlim(st,2) & d(:,1)>=mlim(st,3) & d(:,1)<=mlim(st,4));
    k_all = k;
    if G.ext{ig}(3)=='l' & ~strcmp(G.ext{ig},'all')
        G.lim{ig} = [t(k(end+1-str2num(G.ext{ig}(1:2)))),t(k(end))];
    end
    kk = find(t(k)>=G.lim{ig}(1) & t(k)<=G.lim{ig}(2));
    if ~isempty(kk)
        k = k(kk);
        ke = k(end);
    else
        k = [];
        ke = [];    
    end
    
    % --- Titre et statistiques
    subplot(12,1,1)
    axis([0 1 0 1]);
    axis off
    gtitle(sprintf('%s: %s %s',rcode,sname,sgrn{st}),G.ext{ig})
    if ~isempty(k)
        text(0,.4,{ ...
            'Dernier événement:', ...
            sprintf('   Date: {\\bf%s} {\\it%+d}',datestr(t(ke)),tu), ...
            sprintf('   Lat = {\\bf%s}, Lon = {\\bf%s}',ll2dms(d(ke,1),'lat'),ll2dms(d(ke,2),'lon')), ...
            sprintf('   Prof = {\\bf%g %s}, Md = {\\bf%1.1f %s}',d(ke,3),C(3).unit,d(ke,4),C(4).unit), ...
            sprintf('   Type = {\\bf%s (%s)}',CS.nom{d(ke,7)},deblank(cse{ke})), ...
            },'FontSize',8);
    end
    tstat = {sprintf('Du: {\\bf%s} {\\it%+d} au {\\bf%s} {\\it%+d}',datestr(G.lim{ig}(1),1),tu,datestr(G.lim{ig}(2),1),tu)};
    for i = 1:length(typeseisme)
        ss = sprintf('   %s = {\\bf%d}',typeseisme{i},length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}))));
	nsr = length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1));
	if nsr > 0, ssr = sprintf(' (dont {\\bf%d} ressentis)',length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1)));
	else ssr = '';
	end
	tstat = [tstat,{[ss,ssr]}];
    end
    if ~isempty(k)
    	tstat = [tstat,{sprintf('   Magnitude max. = {\\bf%1.1f}, Intensité max. = {\\bf%s}',max(d(k,4)),romanx(max(d(k,6))))}];
    end
    text(.5,.4,tstat,'FontSize',8);
    text(.5,-.5,tfiltre,'HorizontalAlignment','center','FontSize',7)
    
    % --- Carte
    subplot(10,3,[4 5 7 8 10 11 13 14 16 17])
    mpc = flipud(jet(256));
    mpc(1:30,:) = [];
    % Dessin des courbes de niveau
    [cc,h] = contour(lon50,lat50,z50,0:100:1500);
    set(h,'EdgeColor',colcn)
    % Dessin des failles
    plotbln(c_fai,'k');
    axis(mlim(st,:)), dd2dms(gca,1), hold on
    % Noms des villes
    for i = 1:length(NI)
        if NI(i).cde==3
            plot(NI(i).lon,NI(i).lat,'sk','MarkerFaceColor','k')
            text(NI(i).lon,NI(i).lat,[' ' NI(i).nom '  '], ...
                'HorizontalAlignment',NI(i).hal,'VerticalAlignment',NI(i).val, ...
                'FontWeight',NI(i).fwt,'FontAngle',NI(i).fag,'FontSize',NI(i).fsz)
        end
    end
    % Stations
    if OPT.hsta
	    plot(ST.geo(:,2),ST.geo(:,1),'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    %plot(ST.geo(:,2)+0.00391,ST.geo(:,1)+0.00253,'^')   % correction pour Ste-Anne (temporaire !!)
    end
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    % Séismes
    xy0 = zeros(length(k),2);
    for i = 1:length(k)
        ki = k(i);
        if isnan(d(ki,4))
            mks(i) = round(((mag0*G.mks{ig})^2)*rmks(3)*OPT.mks/4) + 1;
        else
            mks(i) = round(((d(ki,4)*G.mks{ig})^2)*rmks(3)*OPT.mks/4) + 1;
        end
        xy0(i,:) = [d(ki,2),d(ki,1)];
        plot(d(ki,2),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    set(gca,'FontSize',8);
    ph = get(gca,'position');
    set(gca,'position',[ph(1) ph(2)-.01 ph(3) ph(4)])
    box on
    xtickvalue = get(gca,'XTick');
    xticklabel = get(gca,'XTickLabel');
    ytickvalue = get(gca,'YTick');
    yticklabel = get(gca,'YTickLabel');
    axpos0 = get(gca,'position');
    
    % --- Coupe projection verticale Est-Ouest
    h = subplot(10,3,[22 23 25 26]);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)+.01 ph(3) ph(4)+.06])
    % Tracé profil massif (MNT)
    plot(mlim(st,1:2),[0 0],'-k')
    hold on
    pz50 = -max(z50)/1000;
    fill(lon50,pz50,.8*[1 1 1])
    %text(50,-15,'Guadeloupe (altitudes x 20)','FontSize',8)
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,3),'.','MarkerSize',.1,'Color',colas);
    end
    kxy1 = zeros(size(k,1),3);
    for i = 1:length(k)
        ki = k(i);
        kxy1(i,:) = [i,d(ki,2),-d(ki,3)];
        plot(d(ki,2),d(ki,3),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    set(gca,'XLim',mlim(st,1:2),'Ylim',[-1.5 pmax])
    set(gca,'YDir','reverse','FontSize',8)
    set(gca,'XTick',xtickvalue,'XTickLabel',xticklabel);
    mlim1 = [get(gca,'XLim'),-fliplr(get(gca,'YLim'))];
    axpos1 = get(gca,'position');
    box on
    xlabel('Projection verticale Ouest-Est')
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    
    % --- Coupe projection verticale Nord-Sud
    h = subplot(10,3,6:3:18);
    ph = get(h,'position');
    set(h,'position',[ph(1)-.04 ph(2)-.01 ph(3)+.06 ph(4)])
    % Tracé profil massif (MNT)
    plot([0 0],mlim(st,3:4),'-k')
    hold on
    pz50 = -max(z50')/1000;
    pz50(1) = 0;
    fill(pz50,lat50,.8*[1 1 1])
    %text(50,-15,'Guadeloupe (altitudes x 20)','FontSize',8)
    % Séismes anciens
    if OPT.hanc == 1 & ~strcmp(G.ext{ig},'all')
        plot(d(k_all,3),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    kxy2 = zeros(size(k,1),3);
    for i = 1:length(k)
        ki = k(i);
        kxy2(i,:) = [i,d(ki,3),d(ki,1)];
        plot(d(ki,3),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,3),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    set(gca,'YLim',mlim(st,3:4),'Xlim',[-1.5 pmax])
    set(gca,'FontSize',8)
    set(gca,'YAxisLocation','right','YTick',ytickvalue,'YTickLabel','')
    mlim2 = [get(gca,'XLim'),get(gca,'YLim')];
    axpos2 = get(gca,'position');
    %set(gca,'YTickLabel',yticklabel);
    box on
    ylabel('Projection verticale Nord-Sud')
    xlabel(sprintf('%s (%s)',C(3).name,C(3).unit))

    % Légende
    h = subplot(10,3,[24 27]);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2) ph(3) ph(4)+.06])
    axis off
    hold on
    xy = [0 1.4 0 2.3];
    rectangle('position',[xy([1 3]) diff(xy(1:2)) diff(xy(3:4))],'FaceColor','w')
    text(mean(xy(1:2)),xy(4),'Légende', ...
        'VerticalAlignment','top','HorizontalAlignment','center','FontSize',12,'FontWeight','bold')
    text(xy(1),xy(4)-.3,'  Magnitudes','FontSize',8)
    for i = 1:4
        plot(xy(1) + .2,xy(3) + .5 + .02*rmks(3)*OPT.mks/4*(i + 1)^2,'ok','MarkerSize',round((i*G.mks{ig})^2*rmks(3)*OPT.mks/4)+1)
        text(xy(1) + .4,xy(3) + .5 + .02*rmks(3)*OPT.mks/4*(i + 1)^2,sprintf('%d',i),'FontWeight','bold','FontSize',8)
    end
    text(xy(2),xy(4)-.3,'Profondeurs  ','HorizontalAlignment','right','FontSize',8)
    %fill(xy(2) - .2 + .1*[0 1 1 0],xy(3) + .5 + .8*[0 0 1 1],[pmax pmax 0 0])
    for i = 1:length(mpc)
        plot(xy(2) - .2 + .1*[0 1],xy(3) + .5 + [1 1]*(i-1)/length(mpc),'Color',mpc(length(mpc) - i + 1,:))
    end
    for i = 0:2:pmax
        text(xy(2) - .2,xy(3) + 1.5 - i/pmax,sprintf('%d km  ',i), ...
            'HorizontalAlignment','right','FontSize',8)
    end
    plot(xy(1) + .2,xy(3) + .3,'pk','Markersize',15)
    text(xy(1) + .2,xy(3) + .3,'      Séisme ressenti','FontSize',8)
    if OPT.hsta
	    plot(xy(1) + .2,xy(3) + .1,'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    text(xy(1) + .2,xy(3) + .1,'      Stations','FontSize',8)
    end
    hold off
    
    % --- Profondeurs en fonction du temps
    h = subplot(10,3,28:30);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)-.05 ph(3) ph(4)+.05])
    plot(G.lim{ig},[0 0],'-k')
    hold on
    for i = 1:length(k)
        ki = k(i);
        plot(t(ki),d(ki,3),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(t(ki),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    set(gca,'XLim',G.lim{ig},'Ylim',[-1.5 pmax])
    set(gca,'YDir','reverse','FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    tlabel(G.lim{ig},tu)
    box on

    ploterup;
    f = sprintf('%s_%s',sgra{st},G.ext{ig});
    mkgraph(f,G,OPT)
    mkimap(f,G,t(k),d(k,:),cse(k),mks,[find(k),xy0],mlim(st,:),axpos0,kxy1,mlim1,axpos1,kxy2,mlim2,axpos2);
    if OPT.exp
	    mkxhyp(f,G,hyp(k));
    end
    

    % ==============================================================================================
    % ======= Carte DOME
    st = 4;
    figure(1), clf, orient tall
    pmax = 1;  % profondeur max
    k = find(d(:,3)<=pmax & d(:,2)>=mlim(st,1) & d(:,2)<=mlim(st,2) & d(:,1)>=mlim(st,3) & d(:,1)<=mlim(st,4));
    k_all = k;
    if G.ext{ig}(3)=='l' & ~strcmp(G.ext{ig},'all')
        G.lim{ig} = [t(k(end+1-str2num(G.ext{ig}(1:2)))),t(k(end))];
    end
    kk = find(t(k)>=G.lim{ig}(1) & t(k)<=G.lim{ig}(2));
    if ~isempty(kk)
        k = k(kk);
        ke = k(end);
    else
        k = [];
        ke = [];    
    end
    
    % --- Titre et statistiques
    subplot(12,1,1)
    axis([0 1 0 1]);
    axis off
    gtitle(sprintf('%s: %s %s',rcode,sname,sgrn{st}),G.ext{ig})
    if ~isempty(k)
        text(0,.4,{ ...
            'Dernier événement:', ...
            sprintf('   Date: {\\bf%s} {\\it%+d}',datestr(t(ke)),tu), ...
            sprintf('   Lat = {\\bf%s}, Lon = {\\bf%s}',ll2dms(d(ke,1),'lat'),ll2dms(d(ke,2),'lon')), ...
            sprintf('   Prof = {\\bf%g %s}, Md = {\\bf%1.1f %s}',d(ke,3),C(3).unit,d(ke,4),C(4).unit), ...
            sprintf('   Type = {\\bf%s (%s)}',CS.nom{d(ke,7)},deblank(cse{ke})), ...
            },'FontSize',8)
    end
    tstat = {sprintf('Du: {\\bf%s} {\\it%+d} au {\\bf%s} {\\it%+d}',datestr(G.lim{ig}(1),1),tu,datestr(G.lim{ig}(2),1),tu)};
    for i = 1:length(typeseisme)
        ss = sprintf('   %s = {\\bf%d}',typeseisme{i},length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}))));
	nsr = length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1));
	if nsr > 0, ssr = sprintf(' (dont {\\bf%d} ressentis)',length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1)));
	else ssr = '';
	end
	tstat = [tstat,{[ss,ssr]}];
    end
    if ~isempty(k)
    	tstat = [tstat,{sprintf('   Magnitude max. = {\\bf%1.1f}, Intensité max. = {\\bf%s}',max(d(k,4)),romanx(max(d(k,6))))}];
    end
    text(.5,.4,tstat,'FontSize',8);
    text(.5,-.5,tfiltre,'HorizontalAlignment','center','FontSize',7)
    
    % --- Carte
    subplot(10,3,[4 5 7 8 10 11 13 14 16 17])
    mpc = flipud(jet(256));
    mpc(1:30,:) = [];
    % Dessin des courbes de niveau
    [cc,h] = contour(lon2,lat2,z2,1000:10:1500);
    set(h,'EdgeColor',colcn)
    % Dessin des failles (0.1 et 1 uniquement)
    plotbln(c_fai,'k',[.1,1]);
    axis(mlim(st,:)), dd2dms(gca,1), hold on
    % Stations
    if OPT.hsta
	    plot(ST.geo(:,2),ST.geo(:,1),'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    %plot(ST.geo(:,2)+0.00391,ST.geo(:,1)+0.00253,'^')   % correction pour Ste-Anne (temporaire !!)
    end
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    % Séismes
    xy0 = zeros(length(k),2);
    for i = 1:length(k)
        ki = k(i);
        if isnan(d(ki,4))
            mks(i) = round(((mag0 + 1)*rmks(5)*OPT.mks/4)^2*G.mks{ig}) + 1;
        else
            mks(i) = round(((d(ki,4) + 1)*rmks(5)*OPT.mks/4)^2*G.mks{ig}) + 1;
        end
        xy0(i,:) = [d(ki,2),d(ki,1)];
        plot(d(ki,2),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    set(gca,'FontSize',8);
    ph = get(gca,'position');
    set(gca,'position',[ph(1) ph(2)-.01 ph(3) ph(4)])
    box on
    xtickvalue = get(gca,'XTick');
    xticklabel = get(gca,'XTickLabel');
    ytickvalue = get(gca,'YTick');
    yticklabel = get(gca,'YTickLabel');
    axpos0 = get(gca,'position');
    
    % --- Coupe projection verticale Est-Ouest
    h = subplot(10,3,[22 23 25 26]);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)+.01 ph(3) ph(4)+.06])
    % Tracé profil massif (MNT)
    plot(mlim(st,1:2),[0 0],'-k')
    hold on
    pz2 = -max(z2)/1000;
    fill([lon2(1),lon2,lon2(end)],[0,pz2,0],.8*[1 1 1])
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,3),'.','MarkerSize',.1,'Color',colas);
    end
    kxy1 = zeros(size(k,1),3);
    for i = 1:length(k)
        ki = k(i);
        kxy1(i,:) = [i,d(ki,2),-d(ki,3)];
        plot(d(ki,2),d(ki,3),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    set(gca,'XLim',mlim(st,1:2),'Ylim',[-1.5 pmax])
    set(gca,'YDir','reverse','FontSize',8)
    set(gca,'XTick',xtickvalue,'XTickLabel',xticklabel);
    mlim1 = [get(gca,'XLim'),-fliplr(get(gca,'YLim'))];
    axpos1 = get(gca,'position');
    box on
    xlabel('Projection verticale Ouest-Est')
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    
    % --- Coupe projection verticale Nord-Sud
    h = subplot(10,3,6:3:18);
    ph = get(h,'position');
    set(h,'position',[ph(1)-.04 ph(2)-.01 ph(3)+.06 ph(4)])
    % Tracé profil massif (MNT)
    plot([0 0],mlim(st,3:4),'-k')
    hold on
    pz2 = -max(z2')/1000;
    fill([0,pz2,0],[lat2(1);lat2;lat2(end)],.8*[1 1 1])
    % Séismes anciens
    if OPT.hanc == 1 & ~strcmp(G.ext{ig},'all')
        plot(d(k_all,3),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    kxy2 = zeros(size(k,1),3);
    for i = 1:length(k)
        ki = k(i);
        kxy2(i,:) = [i,d(ki,3),d(ki,1)];
        plot(d(ki,3),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,3),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    set(gca,'YLim',mlim(st,3:4),'Xlim',[-1.5 pmax])
    set(gca,'FontSize',8)
    set(gca,'YAxisLocation','right','YTick',ytickvalue,'YTickLabel','')
    mlim2 = [get(gca,'XLim'),get(gca,'YLim')];
    axpos2 = get(gca,'position');
    %set(gca,'YTickLabel',yticklabel);
    box on
    ylabel('Projection verticale Nord-Sud')
    xlabel(sprintf('%s (%s)',C(3).name,C(3).unit))

    % Légende
    h = subplot(10,3,[24 27]);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2) ph(3) ph(4)+.06])
    axis off
    hold on
    xy = [0 1.4 0 2.3];
    rectangle('position',[xy([1 3]) diff(xy(1:2)) diff(xy(3:4))],'FaceColor','w')
    text(mean(xy(1:2)),xy(4),'Légende', ...
        'VerticalAlignment','top','HorizontalAlignment','center','FontSize',12,'FontWeight','bold')
    text(xy(1),xy(4)-.3,'  Magnitudes','FontSize',8)
    for i = [.1,.5,1,2];
        plot(xy(1) + .2,xy(3) + .5 + .15*rmks(3)*i*OPT.mks/4,'ok','MarkerSize',1 + round(((i + 1)*rmks(5)*OPT.mks/4)^2*G.mks{ig}))
        text(xy(1) + .4,xy(3) + .5 + .15*rmks(3)*i*OPT.mks/4,sprintf('%g',i),'FontWeight','bold','FontSize',8)
    end
    text(xy(2),xy(4)-.3,'Profondeurs  ','HorizontalAlignment','right','FontSize',8)
    %fill(xy(2) - .2 + .1*[0 1 1 0],xy(3) + .5 + .8*[0 0 1 1],[pmax pmax 0 0])
    for i = 1:length(mpc)
        plot(xy(2) - .2 + .1*[0 1],xy(3) + .5 + [1 1]*(i-1)/length(mpc),'Color',mpc(length(mpc) - i + 1,:))
    end
    for i = 0:pmax
        text(xy(2) - .2,xy(3) + 1.5 - i/pmax,sprintf('%d km  ',i), ...
            'HorizontalAlignment','right','FontSize',8)
    end
    plot(xy(1) + .2,xy(3) + .3,'pk','Markersize',15)
    text(xy(1) + .2,xy(3) + .3,'      Séisme ressenti','FontSize',8)
    if OPT.hsta
	    plot(xy(1) + .2,xy(3) + .1,'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    text(xy(1) + .2,xy(3) + .1,'      Stations','FontSize',8)
    end
    hold off
    
    % --- Profondeurs en fonction du temps
    h = subplot(10,3,28:30);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)-.05 ph(3) ph(4)+.05])
    plot(G.lim{ig},[0 0],'-k')
    hold on
    for i = 1:length(k)
        ki = k(i);
        plot(t(ki),d(ki,3),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(t(ki),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    set(gca,'XLim',G.lim{ig},'Ylim',[-1.5 pmax])
    set(gca,'YDir','reverse','FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    tlabel(G.lim{ig},tu)
    box on

    ploterup;
    f = sprintf('%s_%s',sgra{st},G.ext{ig});
    mkgraph(f,G,OPT)
    mkimap(f,G,t(k),d(k,:),cse(k),mks,[find(k),xy0],mlim(st,:),axpos0,kxy1,mlim1,axpos1,kxy2,mlim2,axpos2);
    if OPT.exp
	    mkxhyp(f,G,hyp(k));
    end

    
    % ==============================================================================================
    % ======= Carte SPECIFIQUE
    st = 5;
    figure(1), clf, orient tall
    pmax = GS.cpv(2);  % profondeur max
    k = find(d(:,3)<=pmax & d(:,2)>=GS.lim(1) & d(:,2)<=GS.lim(2) & d(:,1)>=GS.lim(3) & d(:,1)<=GS.lim(4));
    k_all = k;
    if G.ext{ig}(3)=='l' & ~strcmp(G.ext{ig},'all')
        G.lim{ig} = [t(k(end+1-str2num(G.ext{ig}(1:2)))),t(k(end))];
    end
    kk = find(t(k)>=G.lim{ig}(1) & t(k)<=G.lim{ig}(2));
    if ~isempty(kk)
        k = k(kk);
        ke = k(end);
    else
        k = [];
        ke = [];    
    end
    
    % --- Titre et statistiques
    subplot(12,1,1)
    axis([0 1 0 1]);
    axis off
    gtitle(sprintf('%s: %s %s',rcode,sname,sgrn{st}),G.ext{ig})
    if ~isempty(k)
        text(0,.4,{ ...
            'Dernier événement:', ...
            sprintf('   Date: {\\bf%s} {\\it%+d}',datestr(t(ke)),tu), ...
            sprintf('   Lat = {\\bf%s}, Lon = {\\bf%s}',ll2dms(d(ke,1),'lat'),ll2dms(d(ke,2),'lon')), ...
            sprintf('   Prof = {\\bf%g %s}, Md = {\\bf%1.1f %s}',d(ke,3),C(3).unit,d(ke,4),C(4).unit), ...
            sprintf('   Type = {\\bf%s (%s)}',CS.nom{d(ke,7)},deblank(cse{ke})), ...
            },'FontSize',8)
    end
    tstat = {sprintf('Du: {\\bf%s} {\\it%+d} au {\\bf%s} {\\it%+d}',datestr(G.lim{ig}(1),1),tu,datestr(G.lim{ig}(2),1),tu)};
    for i = 1:length(typeseisme)
        ss = sprintf('   %s = {\\bf%d}',typeseisme{i},length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}))));
	nsr = length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1));
	if nsr > 0, ssr = sprintf(' (dont {\\bf%d} ressentis)',length(find(strcmp(CS.typ(d(k,7)),typeseisme{i}) & d(k,6)>1)));
	else ssr = '';
	end
	tstat = [tstat,{[ss,ssr]}];
    end
    if ~isempty(k)
    	tstat = [tstat,{sprintf('   Magnitude max. = {\\bf%1.1f}, Intensité max. = {\\bf%s}',max(d(k,4)),romanx(max(d(k,6))))}];
    end
    text(.5,.4,tstat,'FontSize',8);
    text(.5,-.5,tfiltre,'HorizontalAlignment','center','FontSize',7)
    
    % --- Carte
    pros = [mean(GS.lim(1:2)),mean(GS.lim(3:4)),(90-GS.cpv(1))*pi/180];
    raz2 = max([diff(GS.lim(1:2)),diff(GS.lim(3:4))])/sqrt(2);
    subplot(18,1,3:14)
    mpc = flipud(jet(256));
    mpc(1:30,:) = [];
    % Dessin des cotes
    pcontour(c_pta,[],.8*[1 1 1]), axis(GS.lim(1:4));
    dd2dms(gca,1), hold on
    [cc,h] = contour(lon1,lat1,bat1,-7000:500:-500);
    set(h,'EdgeColor',colcn)
    % Dessin des failles
    plotbln(c_fai,'k');
    % Trait de coupe
    plot(pros(1),pros(2),'ok','MarkerSize',3)
    plot(pros(1) + cos(pros(3))*raz2*[-1 1],pros(2) + sin(pros(3))*raz2*[-1 1],'-.k')
    % Noms des iles et villes
    for i = 1:length(NI)
        if NI(i).lon>=GS.lim(1) & NI(i).lon<=GS.lim(2) & NI(i).lat>=GS.lim(3) & NI(i).lat<=GS.lim(4)
            if NI(i).cde==1
                text(NI(i).lon,NI(i).lat,NI(i).nom, ...
                    'HorizontalAlignment',NI(i).hal,'VerticalAlignment',NI(i).val, ...
                    'FontWeight',NI(i).fwt,'FontAngle',NI(i).fag,'FontSize',NI(i).fsz)
            end
            if NI(i).cde==2
                plot(NI(i).lon,NI(i).lat,'sk','MarkerFaceColor','k')
                text(NI(i).lon,NI(i).lat,[' ' NI(i).nom '  '], ...
                    'HorizontalAlignment',NI(i).hal,'VerticalAlignment',NI(i).val, ...
                    'FontWeight',NI(i).fwt,'FontAngle',NI(i).fag,'FontSize',NI(i).fsz)
            end
        end
    end
    % Stations
    if OPT.hsta
	    plot(ST.geo(:,2),ST.geo(:,1),'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
    end
    % Séismes anciens
    if OPT.hanc == 1
        plot(d(k_all,2),d(k_all,1),'.','MarkerSize',.1,'Color',colas);
    end
    % Séismes
    xy0 = zeros(length(k),2);
    for i = 1:length(k)
        ki = k(i);
        if isnan(d(ki,4))
            mks(i) = round(((mag0*G.mks{ig})^2)*rmks(5)*OPT.mks/4) + 1;
        else
            mks(i) = round(((d(ki,4)*G.mks{ig})^2)*rmks(5)*OPT.mks/4) + 1;
        end
        xy0(i,:) = [d(ki,2),d(ki,1)];
        plot(d(ki,2),d(ki,1),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(d(ki,2),d(ki,1),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    set(gca,'FontSize',8);
    box on
    xtickvalue = get(gca,'XTick');
    xticklabel = get(gca,'XTickLabel');
    axpos0 = get(gca,'position');
    
    % --- Coupe projection avec paramètres GS.cpv
    h = subplot(6,4,21:23);
    ph = get(h,'position');
    set(h,'position',[ph(1) ph(2)-.04 ph(3)+.05 ph(4)+.08])
    hold on
    oxy = [d(:,2)' - pros(1);d(:,1)' - pros(2)];
    pxy = degkm*[cos(pros(3)) sin(pros(3));-sin(pros(3)) cos(pros(3))]*oxy;
    % Séismes anciens
    if OPT.hanc == 1 & ~strcmp(G.ext{ig},'all')
        plot(pxy(1,k_all)',d(k_all,3),'.','MarkerSize',.1,'Color',colas);
    end
    kxy1 = zeros(size(k,1),3);
    for i = 1:length(k)
        ki = k(i);
        % projection suivant azimuth GS.cpv(1)
        kxy1(i,:) = [i,pxy(1,ki),-d(ki,3)];
        plot(pxy(1,ki),d(ki,3),'Marker',CS.mks{d(ki,7)},'MarkerFaceColor',filtre(mpc(max([1 round(d(ki,3)*length(mpc)/pmax)]),:),d(ki,end)),'Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i))
        if d(ki,6) > 1
            plot(pxy(1,ki),d(ki,3),'p','Color',filtre(noir,d(ki,end)),'MarkerSize',mks(i)*rprs)
        end
    end
    hold off
    lmax = degkm*sqrt(diff(GS.lim(1:2))^2 + diff(GS.lim(3:4))^2)/2;
    set(gca,'XLim',lmax*[-1 1],'Ylim',[0 GS.cpv(2)])
    set(gca,'YDir','reverse','FontSize',8)
    mlim1 = [get(gca,'XLim'),-fliplr(get(gca,'YLim'))];
    axpos1 = get(gca,'position');
    box on
    xlabel(sprintf('Projection sur coupe verticale azimuth N%g° (%s) : distance relative (km)',GS.cpv(1),char(az2comp(GS.cpv(1)))))
    ylabel(sprintf('%s (%s)',C(3).name,C(3).unit))
    

    % Légende
    h = subplot(6,4,24);
    ph = get(h,'position');
    set(h,'position',[ph(1)+.02 ph(2)-.035 ph(3)+.025 ph(4)+.09])
    %set(h,'position',[ph(1)+.02 ph(2)-.03 ph(3)+.025 ph(4)+0.06])
    axis off
    hold on
    xy = [0 1.4 0 2.3];
    rectangle('position',[xy([1 3]) diff(xy(1:2)) diff(xy(3:4))],'FaceColor','w')
    text(mean(xy(1:2)),xy(4),'Légende', ...
        'VerticalAlignment','top','HorizontalAlignment','center','FontSize',12,'FontWeight','bold')
    text(xy(1),xy(4)-.25,'  Magnitudes','FontSize',8)
    for i = 1:6
        plot(xy(1) + .2,xy(3) + .5 + .02*(i + 1)^2,'ok','MarkerSize',((i*G.mks{ig})^2)*rmks(5)*OPT.mks/4 + 1)
        text(xy(1) + .4,xy(3) + .5 + .02*(i + 1)^2,sprintf('%d',i),'FontWeight','bold','FontSize',8)
    end
    text(xy(2),xy(4)-.25,'Profondeurs  ','HorizontalAlignment','right','FontSize',8)
    %fill(xy(2) - .2 + .1*[0 1 1 0],xy(3) + .5 + .8*[0 0 1 1],[200 200 0 0])
    for i = 1:length(mpc)
        plot(xy(2) - .2 + .1*[0 1],xy(3) + .5 + [1 1]*(i-1)/length(mpc),'Color',mpc(length(mpc) - i + 1,:))
    end
    for i = [0,pmax]
        text(xy(2) - .2,xy(3) + 1.5 - i/pmax,sprintf('%d km  ',i), ...
            'HorizontalAlignment','right','FontSize',8)
    end
    plot(xy(1) + .2,xy(3) + .3,'pk','Markersize',15)
    text(xy(1) + .2,xy(3) + .3,'      Séisme ressenti','FontSize',8)
    if OPT.hsta
	    plot(xy(1) + .2,xy(3) + .1,'^','MarkerSize',stsz,'Color',colst,'MarkerFaceColor',colst)
	    text(xy(1) + .2,xy(3) + .1,'      Stations','FontSize',8)
    end
    hold off

    f = sprintf('%s_%s',sgra{st},G.ext{ig});
    mkgraph(f,G,OPT)
    mkimap(f,G,t(k),d(k,:),cse(k),mks,[find(k),xy0],GS.lim(1:4),axpos0,kxy1,mlim1,axpos1);
    if OPT.exp
	    mkxhyp(f,G,hyp(k));
    end
    
end
close

if ivg(1) == 1
    G.sta = sgra;
    G.ali = sali;
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fonction d'éclaircissement des couleurs RVB
function y=filtre(x,f)
z = 2;
if f == 1
    y = x;
else
    y = (x/z + 1 - 1/z);
end

