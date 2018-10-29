function DOUT = gaz(mat,tlim,OPT,nograph,dirspec)
%GAZ   Traitement des données des Gaz Fumerolliens
%       GAZ sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       GAZ(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = GAZ(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier de données ASCII ('GAZ.DAT')
%           - uniques matrices t (temps) et d (données): les sites sont sélectionnés 
%             par un find dans la matrice si (site)
%           - utilise le fichier de noms et positions des stations OVSG (avec 'G')
%           - tri chronologique et élimination des données redondantes (correction de saisie)
%           - pas de sauvegarde Matlab
%           - exportation de fichiers de données "traitées" par site sur le FTP
%
%   Auteurs: F. Beauducel + G. Hammouya, OVSG-IPGP
%   Création : 2003-04-14
%   Mise à jour : 2009-10-06

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'GAZ';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);
pdat = sprintf('/cgi-bin/%s?site=',X.CGI_AFFICHE_GAZ);
G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};

stype = 'M';

% types d'échantillonnage et marqueurs associés (voir fonction PLOTMARK)
tstr = {'In situ/Condensat','Prélèvement'};
tmkt = {'.','v'};
tmks = 3;
debit = {'TARIE','Nul','Faible','Moyen','Elevé','Très élevé'};
sveille = {'CHD','COE','FFN','FLS','FLI','FLI2','LCN1','LAC1','SFF'};

f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.GAZ_FILE_TYPE);
tamp = textread(f,'%s%*[^\n]','delimiter','|','commentstyle','shell');

% ==== Initialisation des variables
samp = 30;     % pas d'échantillonnage des données (en jour)
last = 45;     % délai d'estimation pour l'état de la station (en jour)

sname = G.nom;
G.cpr = 'OVSG-IPGP';
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

% ==== Importation du fichier de données (créé par le formulaire WEB)
f = sprintf('%s/%s',pftp,X.GAZ_FILE_NAME);
[id,dd,hr,si,tf,ph,db,rn,ap,ph2,phe,pco,pch4,pn2,ph2s,par,pco2,pso2,po2,d13c,d18o,co]=textread(f,'%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','headerlines',1);
disp(sprintf('Fichier: %s importé.',f))

x = char(dd);
t = datenum(str2double([cellstr(x(:,1:4)) cellstr(x(:,6:7)) cellstr(x(:,9:10))]));

% Remplit la matrice de données avec :
%   1 = température fumerolle (°C)
%   2 = pH
%   3 = débit (0 = Nul à 4 = très élevé)
%   4 = Rn (coup/min)
%   5 = type ampoule (1 = P2O5, 2 = NaOH, 3 = vide)
%   6 à 15 = concentrations H2,He,CO,CH4,N2,H2S,Ar,CO2,SO2,O2 (%)
%   16 = isotope d13C
%   17 = isotope d18O
%   18 = rapport S/C: (H2S+SO2)/CO2
amp = ones(size(ap))*'1';
k = find(strcmp(ap,'NaOH'));
amp(k) = '2';
k = find(strcmp(ap,'Vide'));
amp(k) = '3';
d = str2double([tf,ph,db,rn,cellstr(char(amp)),ph2,phe,pco,pch4,pn2,ph2s,par,pco2,pso2,po2,d13c,d18o]);
d(:,18) = (d(:,11)+d(:,14))./d(:,13);

% ==== Traitement des données:
%   1. range les données en ordre chronologique;
%   2. exporte un fichier de données par station (avec en-tete EDAS)

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:);
si = si(k);
ap = ap(k);
co = co(k);

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(si,ST.cod(i)));
    if ~isempty(k)
        so = [so i];
	for ii = 1:length(tamp)
	     kk = find(strcmp(ap(k),tamp(ii)));
	     if ~isempty(kk)
	          tt = datevec(t(k(kk)));
                  f = sprintf('%s/%s_%s.DAT',pftp,ST.cod{i},tamp{ii});
                  fid = fopen(f,'wt');
                  fprintf(fid, '# DATE: %s\r\n', datestr(now));
                  fprintf(fid, '# TITL: %s: %s %s (%s)\r\n',rcode,ST.ali{i},ST.nom{i},tamp{ii});
                  fprintf(fid, '# SAMP: 0\r\n');
                  fprintf(fid, '# OMGR: /g::o1en/2,,:o3,,:o4 /pe /nan:-1\r\n');
                  fprintf(fid, '# CHAN: YYYY MM DD HH NN Tfum_(°C) pH Rn_(cp/mn) H2_(%%) He_(%%) CO_(%%) CH4_(%%) N2_(%%) H2S_(%%) Ar_(%%) CO2_(%%) SO2_(%%) O2_(%%) d13C d18O S/C \r\n');
                  fprintf(fid, '%4d-%02d-%02d %02d:%02d %0.2f %0.1f %1.0f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f\r\n',[tt(:,1:5),d(k(kk),[1,2,4,6:18])]');
                  fclose(fid);
                  disp(sprintf('File: %s updated.',f))
             end
	end
    end
end
nx = length(so);

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
    if exist('OPT','var')
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
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
    if nograph == 1, G = []; end
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
        % -----------> Veille de certaines fumerolles
        if find(strcmp(ST.ali(stn),sveille))
            etats(stn) = -1;
        end
        if ig == 1
            sd = sprintf('%s %0.1f °C (%d), %0.2f pH (%d), %d débit, %0.1f Rn cp/min, %d, %0.3f %%H2, %0.3f %%He, %0.3f %%CO, %0.3f %%CH4, %0.3f %%N2, %0.3f %%H2S, %0.3f %%Ar, %0.3f %%CO2, %0.3f %%SO2, %0.3f %%O2, %0.3f d13C, %0.3f d18O',stype,d(kn(end),:));
            mketat(etats(stn),tlast(stn),sd,lower(ST.cod{stn}),G.utc,acquis(stn))
        end
    
        % Titre et informations
        figure(1), clf, orient tall

        G.tit = gtitle(stitre,G.ext{ig});
		G.eta = [G.lim{ig}(2),etats(stn),acquis(stn)];

        if isempty(k), break; end

        if isnan(d(ke,5)), sdb = ''; else sdb = debit{d(ke,5)+1}; end
        G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc), ...
                sprintf('Tfumerolle = {\\bf%1.1f °C}',d(ke,1)), ...
                sprintf('pH = {\\bf%1.2f}',d(ke,2)), ...
                sprintf('Débit = {\\bf%s}',sdb), ...
                sprintf('^{222}Rn = {\\bf%g cp/min}',d(ke,4)), ...
                sprintf('Remarque = {\\bf%s}',char(co(ke))), ...
                };
        
        % Température fumerolle (suivant type échantillonnage)
        subplot(6,1,1), extaxes
        plot(t(k),d(k,1),'.-','Color',[0 0 .8])
        hold off
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Température (°C)')
        
        % pH
        subplot(6,1,2), extaxes
        plot(t(k),d(k,2),'.-','Color',[0 0 .8])
        %plot(t(k),d(k,3),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('pH')
    
        % Débit
        subplot(12,1,5), extaxes
        plot(t(k),d(k,3),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Débit')

        % Radon
        subplot(12,1,6), extaxes
        plot(t(k),d(k,4),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('^{226}Rn (cp/min)')

        % S/C
        subplot(6,1,4), extaxes
        kk = find(strcmp(si,ST.cod(stn)) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2) & d(:,5) ~= 2);
        plot(t(kk),d(kk,18),'.-','LineWidth',.1)
        set(gca,'YScale','lin','XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Rapport S/C')

        % Isotope d13C
        subplot(6,1,5), extaxes
        plot(t(k),d(k,16),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('\\delta^{13}C'))

        % Isotope d18C
        subplot(6,1,6), extaxes
        plot(t(k),d(k,17),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('\\delta^{18}O'))

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

    % Titre et légende
    figure(1), clf, orient tall

    etat = etats(so);
    G. tit = gtitle(stitre,G.ext{ig});
    G.eta = [G.lim{ig}(2),mean(etat(find(etat ~= -1))),round(mean(acquis(so)))];


    if isempty(k), break; end
    G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc)};
  
    % Températures
    subplot(7,1,1:3), extaxes
	ilg = [];
    hold on
    id_couleur=0;
    for i = 1:nx
	    k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2) & ~isnan(d(:,1)));
	    if ~isempty(k)
			id_couleur=id_couleur+1;
			plot(t(k),d(k,1),'.-','LineWidth',.1,'Color',scolor(id_couleur))
			ilg = [ilg;i];
		end
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    legend(ST.ali(so(ilg)),2)
    ylabel(sprintf('Température (°C)'))

    % pH
    subplot(7,1,4), extaxes
    hold on
    id_couleur=0;
    for i = 1:nx
	    k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2) & ~isnan(d(:,2)));
	    if ~isempty(k)
			id_couleur=id_couleur+1;
			plot(t(k),d(k,2),'.-','LineWidth',.1,'Color',scolor(id_couleur))
	end
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    legend(ST.ali(so(ilg)),2)
    ylabel(sprintf('pH'))

    % S/C
    subplot(7,1,5:6), extaxes
    hold on
    id_couleur=0;
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2) & ~isnan(d(:,18)) & d(:,5) ~= 2);
	    if ~isempty(k)
			id_couleur=id_couleur+1;
			plot(t(k),d(k,18),'.-','LineWidth',.1,'Color',scolor(id_couleur))
	end
    end
    hold off, box on
    set(gca,'YScale','lin','XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    legend(ST.ali(so(ilg)),2)
    ylabel(sprintf('Rapport S/C'))

    % Isotope d13C
    subplot(7,1,7), extaxes
    hold on
    id_couleur=0;
    for i = 1:nx
        k = find(strcmp(si,ST.cod(so(i))) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2) & ~isnan(d(:,16)));
	    if ~isempty(k)
			id_couleur=id_couleur+1;
        plot(t(k),d(k,16),'.-','LineWidth',.1,'Color',scolor(id_couleur))
	end
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    legend(ST.ali(so(ilg)),2)
    ylabel(sprintf('\\delta^{13}C'))

    tlabel(G.lim{ig},G.utc)

    ploterup;
    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
end
close(1)

if ivg(1) == 1
    mketat(etats(so),max(tlast),sprintf('%s %d %s',stype,nx,G.snm),rcode,G.utc,acquis(so))
    G.sta = [{rcode};lower(ST.cod(so))];
    G.ali = [{'Gaz'};ST.ali(so)];
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end


timelog(rcode,2)

