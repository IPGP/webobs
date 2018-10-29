function DOUT = sources(mat,tlim,OPT,nograph,dirspec)
%SOURCES   Traitement des données des Sources Thermales.
%       SOURCES sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       SOURCES(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = SOURCES(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier de données ASCII ('eaux_dat.txt')
%           - uniques matrices t (temps) et d (données): les sites sont sélectionnés 
%             par un find dans la matrice si (site)
%           - utilise le fichier de noms et positions des stations OVSG (avec 'S')
%           - tri chronologique et élimination des données redondantes (correction de saisie)
%           - pas de sauvegarde Matlab
%           - calcul du bilan ionique et de rapports
%           - exportation de fichiers de données "traitées" par site sur le FTP
%
%   Auteurs: F. Beauducel + G. Hammouya + J.C. Komorowski + C. Dessert + O. Crispi, OVSG-IPGP
%   Création : 2001-12-21
%   Mise à jour : 2010-02-23

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'SOURCES';
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
samp = 30;     % pas d'échantillonnage des données (en jour)
last = 45;     % délai d'estimation pour l'état de la station (en jour)
ydeb = 1978;

sname = G.nom;
G.cpr = 'OVSG-IPGP';
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
pdat = sprintf('/cgi-bin/%s?unite=mmol&site=',X.CGI_AFFICHE_EAUX);
G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};

% ==== Importation du fichier de données des eaux (créé par le formulaire WEB)
%f = sprintf('%s/%s.DAT',pftp,rcode);
f = sprintf('%s/Eaux/EAUX.DAT',X.RACINE_FTP);
[id,dd,hh,si,ty,ta,ts,ph,db,cd,nv,li,na,ki,mg,ca,fi,cl,br,no3,so4,hco3,io,sio2,d13c,d18o,dde,co]=textread(f,'%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','headerlines',1);
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
d = [str2double([ty,ta,ts,ph,db,cd,nv,li,na,ki,mg,ca,fi,cl,br,no3,so4,hco3,io,sio2,d13c,d18o,dde]),NaN*[z0,z0,z0,z0]];

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
%   13-18 = cations F-,Cl-,Br-,NO3-,SO4--,HCO3-,I- (mmol/l)
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
d(:,i_i) = d(:,i_i)/str2double(X.GMOL_I);
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
%   2. exporte un fichier de données par station (avec en-tete EDAS)

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:);
si = si(k);
co = co(k);

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(si,ST.cod(i)));
    if ~isempty(k)
        so = [so i];
        tt = datevec(t(k));
        f = sprintf('%s/%s.DAT',pftp,ST.cod{i});
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s: %s %s\r\n',rcode,ST.ali{i},ST.nom{i});
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# OMGR: /g::o1en/2,,:o3,,:o4 /pe /nan:-1\r\n');
        fprintf(fid, '# CHAN: YYYY MM DD HH NN Type Tair_(°C) Tsource_(°C) pH Débit_(l/mn) Cond_(µS) Niveau_(m) Li+_(mmol/l) Na+_(mmol/l) K+_(mmol/l) Mg++_(mmol/l) Ca++_(mmol/l) F-_(mmol/l) Cl-_(mmol/l) Br-_(mmol/l) NO3-_(mmol/l) SO4--_(mmol/l) HCO3-_(mmol/l) I-_(µmol/l) d13C d18O dD Cl/SO4 HCO3/SO4 Mg/Cl Cond25_(µS) BI\r\n');
        fprintf(fid, '%4d-%02d-%02d %02d:%02d %d %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f %0.2f\r\n',[tt(:,1:5),d(k,:)]');
        fclose(fid);
        disp(sprintf('File: %s updated.',f))
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
    	if isfield(OPT,'fmt')
        	G.fmt{ivg} = OPT.fmt;
	end
    	if isfield(OPT,'mks')
		G.mks{ivg} = OPT.mks;
	end
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    for st = 1:nx
        stn = so(st);
        k = find(strcmp(si,ST.cod(stn)) & t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
        DOUT(st).code = ST.cod{stn};
        DOUT(st).time = t(k);
        DOUT(st).data = d(k,:);
    end
end

if nargin > 3
    if nograph == 1, G = []; nx = 0; ivg = []; end
end

% ==== Tracé des graphes par site
for st = 1:nx
    stn = so(st);
    stitre = sprintf('%s: %s %s',ST.ali{stn},sname,ST.nom{stn});
	G.dat = [G.dat;{sprintf('%s%s',pdat,ST.cod{stn})}];
    
    for ig = ivg
          
        kn = find(strcmp(si,ST.cod(stn)));
        k = find(strcmp(si,ST.cod(stn)) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        if ~isempty(k), ke = k(end); else ke = []; end
        
        % Etat de la station
        acquis(stn) = round(100*length(k)*samp/diff(G.lim{ig}));
        tlast(stn) = t(kn(end));
        kl = find(t(k) >= G.lim{ig}(2)-last);
        if ~isempty(kl)
            etats(stn) = 100;
        else
            etats(stn) = 0;
        end
        % -----------> Veille de certaines sources: à valider ici
        if strcmp(ST.ali(stn),'RM3')
            etats(stn) = -1;
        end
        if ig == 1
            sd = sprintf('%s %0.1f °C, %0.1f °C, %0.2f pH, %0.1f l/mn, %0.1f µS, %0.2f m, %0.3f Li, %0.3f Na+, %0.3f K+, %0.3f Mg++, %0.3f Ca++, %0.3f F-, %0.3f Cl-, %0.3f Br-, %0.3f NO3-, %0.3f SO4--, %0.3f HCO3-, %0.3f d13C, %0.3f d18O, %0.3f dD, %0.3f Cl/SO4, %0.3f HCO3/SO4, %0.3f Mg/Cl, %+0.1f %%',stype,d(kn(end),2:end));
            mketat(etats(stn),tlast(stn),sd,lower(ST.cod{stn}),G.utc,acquis(stn))
        end
    
        % Titre et informations
        figure(1), clf, orient tall

        G.tit = gtitle(stitre,G.ext{ig});
		G.eta = [G.lim{ig}(2),etats(stn),acquis(stn)];

        if isempty(k), break; end

        if d(ke,i_db) == 0, sdb = 'TARIE'; else sdb = sprintf('%1.1f l/mn',d(ke,i_db)); end
        G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc), ...
                sprintf('Tsource = {\\bf%1.1f °C}',d(ke,i_ts)), ...
                sprintf('Tair = {\\bf%1.1f °C}',d(ke,i_ta)), ...
                sprintf('pH = {\\bf%1.2f}',d(ke,i_ph)), ...
                sprintf('Cond. = {\\bf%1.1f µS}',d(ke,i_cd)), ...
                sprintf('Cond_{25} = {\\bf%1.1f µS}',d(ke,25)), ...
                sprintf('Débit = {\\bf%s}',sdb), ...
                sprintf('Analyse ionique ({\\bfmmol/l}) :'), ...
                sprintf('Na^+ = {\\bf%1.1f}',d(ke,i_na)), ...
                sprintf('K^+ = {\\bf%1.1f}',d(ke,i_ki)), ...
                sprintf('Mg^{++} = {\\bf%1.1f}',d(ke,i_mg)), ...
                sprintf('Ca^{++} = {\\bf%1.1f}',d(ke,i_ca)), ...
                sprintf('F^- = {\\bf%1.1f}',d(ke,i_fi)), ...
                sprintf('Cl^- = {\\bf%1.1f}',d(ke,i_cl)), ...
                sprintf('HCO_3^- = {\\bf%1.1f}',d(ke,i_hco3)), ...
                sprintf('SO_4^{--} = {\\bf%1.1f}',d(ke,i_so4)), ...
                sprintf('Cl^- / SO_4^{--} = {\\bf%1.2f}',d(ke,i_cl)), ...
                sprintf('HCO_3^- / SO_4^{--} = {\\bf%1.2f}',d(ke,i_hco3)), ...
                sprintf('B.I. = {\\bf%+1.2f %%}',d(ke,i_bi)), ...
                sprintf('Remarque = {\\bf%s}',char(co(ke))), ...
                };
        
        % Température (source + air)
        subplot(12,1,1:2), extaxes
        % --- air
        plot(t(k),d(k,i_ta),'.-','LineWidth',.1,'Color',.6*[1 1 1]), hold on
        % --- source suivant type échantillonnage
        plotmark(d(k,i_ty),t(k),d(k,i_ts),tmkt,tmks,[0 0 .8])
        hold off
        set(gca,'XLim',G.lim{ig},'FontSize',8)
	legend('Air',2)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Température (°C)')
        
        % Légende des types d'échantillonnage
        pos = get(gca,'position');
        axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/5])
        axis([0 1 0 1]), hold on
        for i = 1:4
            plot((i-1)/4 + .05,.5,tmkt{i},'Markersize',tmks*(1+(tmkt{i}=='.')*2),'MarkerFaceColor','k')
            text((i-1)/4 + .05,.5,['   ',tstr{i}],'FontSize',8)
        end
        axis off, hold off
        
        % pH
        subplot(12,1,3:4), extaxes
        plot(t(k),d(k,i_ph),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('pH')
    
        % Cl- & HCO3-
        subplot(12,1,5:6), extaxes
        plot(t(k),d(k,[i_cl,i_hco3]),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
	legend('Cl^-','HCO_3^-',2)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Cl^- & HCO_3^- (mmol/l)')

        % Cl-/SO4-- & HCO3-/SO4--
        subplot(12,1,7:8), extaxes
        plot(t(k),d(k,23:24),'.-','LineWidth',.1)
        set(gca,'YScale','log','XLim',G.lim{ig},'FontSize',8)
	legend('Cl^-/SO_4^{--}','HCO_3^-/SO_4^{--}',2)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Cl^-/SO_4^{--} & HCO_3^-/SO_4^{--}')

        % Mg++/Cl-
        subplot(12,1,9), extaxes
        plot(t(k),d(k,25),'.-','LineWidth',.1)
        set(gca,'YScale','log','XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Mg^{++}/Cl^-')

        % Débit
        subplot(12,1,10), extaxes
        plot(t(k),d(k,i_db),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Débit (l/mn)')

        % Conductivité
        subplot(12,1,11:12), extaxes
        plot(t(k),d(k,[i_cd,26]),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
	legend('Cond.','Cond_{25}',2)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Cond. & Cond_{25} (µS)')

        tlabel(G.lim{ig},G.utc)
        
        ploterup;
        mkgraph(sprintf('%s_%s',lower(ST.cod{stn}),G.ext{ig}),G,OPT)
    end

end

% ==== Tracé des graphes de synthèse
stitre = sprintf('Synthèse Réseau %s',sname);
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

    etat = etats(so);
    G.tit = gtitle(stitre,G.ext{ig});
    G.eta = [G.lim{ig}(2),mean(etat(find(etat ~= -1))),round(mean(acquis(so)))];

    if isempty(k), break; end
    G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc)};
    
    % Diagramme ternaire Ca/Na/Mg
    subplot(8,2,[1 3])
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        h = ternplot(d(k,i_ca),d(k,i_na),d(k,i_mg),'.',0);
        set(h,'Color',scolor(i));
        set(gca,'FontSize',8)
        hold on
    end
    hold off
    ternlabel('Ca','Na','Mg',0);
    pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

    % Diagramme ternaire SO4/HCO3/Cl
    subplot(8,2,[2 4])
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        h = ternplot(d(k,i_so4),d(k,i_hco3),d(k,i_cl),'.',0);
        set(h,'Color',scolor(i));
        set(gca,'FontSize',8)
        hold on
    end
    hold off
    ternlabel('SO_4','HCO_3','Cl',0);
    pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

    % Légende
	axes('position',[0,pos(2),1,pos(4)]);
	axis([0,1,0,1]);
    hold on
    for i = 1:nx
        xl = .5;
        yl = 1 - i/(nx+3);
        plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(i))
        plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(i))
        text(xl+.03,yl,ST.ali{so(i)},'Fontsize',8,'FontWeight','bold')
    end
    hold off
	axis off
	
    % Températures
    subplot(8,1,3:4), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        %plot(t(k),d(k,3),'.-','LineWidth',.1,'Color',scolor(i))
        plotmark(d(k,i_ty),t(k),d(k,i_ts),tmkt,tmks,scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Température (°C)'))

    % Légende des types d'échantillonnage
    pos = get(gca,'position');
    axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/7])
    axis([0 1 0 1]), hold on
    for i = 1:4
        plot((i-1)/4 + .05,.5,tmkt{i},'Markersize',tmks*(1+(tmkt{i}=='.')*2),'MarkerFaceColor','k')
        text((i-1)/4 + .05,.5,['   ',tstr{i}],'FontSize',8)
    end
    axis off, hold off

    % pH
    subplot(8,1,5), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k),d(k,i_ph),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('pH'))

    % Conductivité à 25°C
    subplot(8,1,6), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k),d(k,26),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'YScale','linear','XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel('Cond. 25°C (µS)')

    % Rapport Cl-/SO4-
    subplot(8,1,7), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k),d(k,23),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'YScale','log','XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel('Cl^- / SO_4^{--}')

    % Rapport HCO3-/SO4-
    subplot(8,1,8), extaxes
    hold on
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        plot(t(k),d(k,24),'.-','LineWidth',.1,'Color',scolor(i))
    end
    hold off, box on
    set(gca,'YScale','log','XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel('HCO_3^- / SO_4^{--}')

    tlabel(G.lim{ig},G.utc)

    ploterup;
    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
end
close

if length(ivg) & ivg(1) == 1
    mketat(etats(so),max(tlast),sprintf('%s %d %s',stype,nx,G.snm),rcode,G.utc,acquis(so))
    G.sta = [{rcode};lower(ST.cod(so))];
    G.ali = [{'Sources'};ST.ali(so)];
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)

