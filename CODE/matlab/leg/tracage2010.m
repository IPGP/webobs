function DOUT = tracage2010(mat,tlim,OPT,nograph,dirspec)
%TRACAGE2010 Graphes du traçage 2010.
%       TRACAGE2010 sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       TRACAGE2010(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = TRACAGE2010(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%   Auteurs: F. Beauducel + C. Dessert + O. Crispi, OVSG-IPGP
%   Création : 2010-02-23
%   Mise à jour : 2010-03-11

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT.ppi = 100; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'TRACAGE2010';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);

stype = 'M';

% types d'échantillonnage et marqueurs associés (voir fonction PLOTMARK)
f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.EAUX_FILE_TYPE);
[tcod,tstr] = textread(f,'%s%s','delimiter','|','whitespace','','commentstyle','shell');
tmkt = {'.','v','^','s','p'};
tmks = 3;

% ==== Initialisation des variables
samp = 2;     % pas d'échantillonnage des données (en jour)
last = 15;     % délai d'estimation pour l'état de la station (en jour)
ydeb = 2007;	% début de la ligne de base pour le traçage
t0 = datenum(2010,2,18,12,30,0);	% date et heure du traçage
sites = {'TA','BJB/BJ','PR','GA','GAB','RM3','BCM/EV','CC'};

sname = G.nom;
G.cpr = 'OVSG-IPGP';
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
pdat = sprintf('/cgi-bin/%s?unite=mmol&site=',X.CGI_AFFICHE_EAUX);
G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};

% ==== Importation du fichier de données des eaux (créé par le formulaire WEB)
%f = sprintf('%s/%s.DAT',pftp,rcode);
f = sprintf('%s/Eaux/EAUX.DAT',X.RACINE_FTP);
[id,dd,hh,si,ty,ta,ts,ph,db,cd,nv,li,na,ki,mg,ca,fi,cl,br,no3,so4,hco3,io,d13c,d18o,dde,co]=textread(f,'%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','headerlines',1);
disp(sprintf('File: %s imported.',f))

t = NaN*ones(size(dd,1),1);
x = char(dd);
% remplace les heures manquantes dans hh par '00:00'
k = find(strcmp(hh,''));
hh(k) = cellstr(char(ones(size(k))*'00:00'));
y = char(hh);
z0 = zeros([size(x,1) 1]);
% traite 2 formats de dates : "yyyy-mm-dd" ou "dd/mm/yyyy"
k = find(x(:,5)=='-' & x(:,8)=='-');
t(k) = datenum([str2double([cellstr(x(k,1:4)) cellstr(x(k,6:7)) cellstr(x(k,9:10)) cellstr(y(k,1:2)) cellstr(y(k,4:5))]) z0(k)]);
d = [str2double([ty,ta,ts,ph,db,cd,nv,li,na,ki,mg,ca,fi,cl,br,no3,so4,hco3,io,d13c,d18o,dde]),NaN*[z0,z0,z0,z0]];

% Remplit la matrice de données avec :
%   1 = type de prélèvement (remplace les codes par un chiffre)
i_ty = 1;
for i = 1:length(tcod)
	k = find(strcmp(ty,tcod(i)));
	d(k,i_ty) = i;
end

%   2 = température air (°C)
i_ta = 2;
%   3 = température source (°C)
i_ts = 3;
%   4 = pH
i_ph = 4;
%   5 = débit (l/mn)
i_db = 5;
%   6 = conductivité (µS)
i_cd = 6;
%   7 = niveau (m)
i_nv = 7;
%   8-18 = concentrations en ppm = mg/l, à convertir en mmol/l
%   8-12 = anions Li+, Na+, K+, Mg++, Ca++ (mmol/l)
i_li = 8;
d(:,i_li) = d(:,i_li)/str2double(X.GMOL_Li);
i_na = 9;
d(:,i_na) = d(:,i_na)/str2double(X.GMOL_Na);
i_ki = 10;
d(:,i_ki) = d(:,i_ki)/str2double(X.GMOL_K);
i_mg = 11;
d(:,i_mg) = d(:,i_mg)/str2double(X.GMOL_Mg);
i_ca = 12;
d(:,i_ca) = d(:,i_ca)/str2double(X.GMOL_Ca);
%   13-18 = cations F-,Cl-,Br-,NO3-,SO4--,HCO3- (mmol/l)
i_fi = 13;
d(:,i_fi) = d(:,i_fi)/str2double(X.GMOL_F);
i_cl = 14;
d(:,i_cl) = d(:,i_cl)/str2double(X.GMOL_Cl);
i_br = 15;
d(:,i_br) = d(:,i_br)/str2double(X.GMOL_Br);
i_no3 = 16;
d(:,i_no3) = d(:,i_no3)/str2double(X.GMOL_NO3);
i_so4 = 17;
d(:,i_so4) = d(:,i_so4)/str2double(X.GMOL_SO4);
i_hco3 = 18;
d(:,i_hco3) = d(:,i_hco3)/str2double(X.GMOL_HCO3);
i_i = 19;
d(:,i_i) = 1e-3*d(:,i_i)/str2double(X.GMOL_I);
%   20-22 = isotopes d13C, d18O,dD
%   23 = rapport Cl-/SO4-- (calculé)
d(:,23) = d(:,i_cl)./d(:,i_so4);
%   24 = rapport HCO3-/SO4-- (calculé)
d(:,24) = d(:,i_hco3)./d(:,i_so4);
%   25 = rapport Mg++/Cl- (calculé)
d(:,25) = d(:,i_mg)./d(:,i_cl);
%   26 = conductivité à 25°C
d(:,26) = d(:,i_cd)./(1+.02*(d(:,i_ts)-25));
%   27 = bilan ionique (calculé): Attention: valeurs doublées pour Mg++, Ca++ et SO4--
i_bi = 27;
cations = rsum(d(:,[i_li,i_na,i_ki,i_mg,i_mg,i_ca,i_ca])');
anions = rsum(d(:,[i_fi,i_cl,i_br,i_no3,i_so4,i_so4,i_hco3])');
d(:,i_bi) = 100*((cations - anions)./(cations + anions))';


% ==== Traitement des données:
%   1. range les données en ordre chronologique;

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:);
si = si(k);
co = co(k);

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(sites,ST.ali(i)));
    if ~isempty(k)
        so = [so i];
    end
end
nx = length(so);


% Décodage de l'argument TLIM
if isempty(tlim)
    ivg = 1:(length(G.ext)-2);
end
if ~isempty(tlim) & strcmp(tlim,'all')
    ivg = length(G.ext)-1;
    G.lim{ivg}(1) = datenum(ydeb,1,1);
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
    if exist('OPT','var')
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    for st = 1:nx
        stn = so(st);
        k = find(strcmp(si,ST.ali(stn)) & t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
        DOUT(st).code = ST.cod{stn};
        DOUT(st).time = t(k);
        DOUT(st).data = d(k,:);
    end
end

if nargin > 3
    if nograph == 1, G = []; end
end


% ==== Tracé des graphes de synthèse
stitre = sprintf('Synthèse %s',sname);
for ig = ivg

    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if ~isempty(k)
        ke = k(end);
        k1 = k(1);
    else
        ke = [];
        k1 = [];
    end

    % Titre
    figure(1), clf, orient tall

    %etat = etats(so);
    G.tit = gtitle(stitre,G.ext{ig});
    %G.eta = [G.lim{ig}(2),mean(etat(find(etat ~= -1))),round(mean(acquis(so)))];

    if isempty(k), break; end
    G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc)};

    % Concentration Iode
    subplot(8,1,1), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k)-t0,1000*d(k,i_i),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig}-t0,'FontSize',8)
    ylabel('I^- (µmol)')

    % Legende des site
    pos = get(gca,'position');
    axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/7])
    axis([0 1 0 1]), hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    	xlab = (i-1)/nx + .05;
	text(xlab,0,ST.ali(so(i)),'FontSize',8,'FontWeight','bold','Color',scolor(i), ...
		'VerticalAlignment','bottom','HorizontalAlignment','center')
    end
    axis off, hold off

    % Concentration Chlore
    subplot(8,1,2), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k)-t0,d(k,i_cl),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig}-t0,'FontSize',8)
    ylabel('Cl^- (mmol)')

    % Rapport I/Cl
    subplot(8,1,3:4), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k)-t0,d(k,i_i)./d(k,i_cl),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig}-t0,'FontSize',8)
    ylabel('I^- / Cl^-')

    % Températures
    subplot(8,1,5:6), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        %plot(t(k),d(k,3),'.-','LineWidth',.1,'Color',scolor(i))
        plotmark(d(k,i_ty),t(k)-t0,d(k,i_ts),tmkt,tmks,scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig}-t0,'FontSize',8)
    ylabel(sprintf('Température (°C)'))

    % pH
    subplot(8,1,7), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k)-t0,d(k,i_ph),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig}-t0,'FontSize',8)
    ylabel(sprintf('pH'))

    % Conductivité à 25°C
    subplot(8,1,8), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k)-t0,d(k,26),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'YScale','linear','XLim',G.lim{ig}-t0,'FontSize',8)
    ylabel('Cond. 25°C (µS)')

    tlabel(G.lim{ig},G.utc)

    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
end
close(1)

if ivg(1) == 1
    %mketat(etats(so),max(tlast),sprintf('%s %d %s',stype,nx,G.snm),rcode,G.utc,acquis(so))
    G.sta = {rcode};
    G.ali = {'Traçage'};
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)

