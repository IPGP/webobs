function DOUT = aemd(mat,tlim,OPT,nograph,dirspec)
%AEMD   Traitement des données de Distancemétrie.
%       AEMD sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       AEMD(MAT,TLIM,JCUM,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = AEMD(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier de données ASCII ('aemd_dat.txt')
%           - uniques matrices t (temps) et d (données): les sites sont sélectionnés 
%             par un find dans la matrice si (site)
%           - utilise le fichier de noms et positions des stations OVSG (avec 'D9')
%           - tri chronologique et élimination des données redondantes (correction de saisie)
%           - pas de sauvegarde Matlab
%           - calcul de correction météo
%           - soustrait les valeurs de première distance (relatif)
%           - exportation de fichiers de données "traitées" par site sur le FTP
%
%   Auteurs: F. Beauducel + J.C. Ruegg, OVSG-IPGP
%   Création : 2001-08-29
%   Mise à jour : 2009-10-06


X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'AEMD';
timelog(rcode,1)

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);
pdat = sprintf('/cgi-bin/%s?site=',X.CGI_AFFICHE_DISTANCE);
G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};

% ==== Initialisation des variables
samp = 7;      % pas d'échantillonnage des données (en jour)
last = 30;     % délai d'estimation pour l'état de la station (en jour)
n0 = 309.6;    % indice standard de réfraction de l'air
ddt = 2/24;    % délai toléré pour le différentiel (en jour)

stype = 'M';
sname = G.nom;
G.cpr = 'OVSG-IPGP';
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

% ==== Importation des paramètres stations
%i0 = 1; % Indice de la station de base ACQD9 (TRES IMPORTANT !! utilisé pour météo)
%i1 = 5; % Indice de la station de référence NEZD9 (TRES IMPORTANT !! utilisé pour le différentiel)
i0 = find(strcmp(ST.ali,'-')); % Indice de la station de base ACQ
i1 = find(strcmp(ST.ali,'NEZ')); % Indice de la station de référence NEZ

% ==== Importation du fichier de données (créé par le formulaire WEB)
f = sprintf('%s/%s',pftp,X.DISTANCE_FILE_NAME);
[id,dd,hh,si,ty,pa,ta,hr,me,vi,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11,d12,d13,d14,d15,d16,d17,d18,d19,d20,co]=textread(f,'%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%q%*[^\n]','delimiter','|','headerlines',1);
disp(sprintf('Fichier: %s importé.',f))

x = char(dd);
y = char(hh);
z0 = zeros([size(x,1) 1]);
t = datenum([str2double([cellstr(x(:,1:4)) cellstr(x(:,6:7)) cellstr(x(:,9:10)) cellstr(y(:,1:2)) cellstr(y(:,4:5))]) z0]);
% Remplit la matrice de données avec pression, température, humidité, moyenne des distances, écart-type des distances
ddd = str2double([d1 d2 d3 d4 d5 d6 d7 d8 d9 d10 d11 d12 d13 d14 d15 d16 d17 d18 d19 d20]);
k = find((ddd-repmat(ddd(:,1),[1,20])) > 500);
if ~isempty(k), ddd(k) = ddd(k) - 1000; end
k = find((ddd-repmat(ddd(:,1),[1,20])) < -500);
if ~isempty(k), ddd(k) = ddd(k) + 1000; end
ddd = repmat(str2double(d0),[1,20]) + ddd/1000;

d = [str2double(pa),str2double(ta),str2double(hr),rmean(ddd')',rstd(ddd')',z0];
% Convertit la pression en mmHg (si nécessaire)
k = find(d(:,1)>760);
d(k,1) = d(k,1)/1.3328;


% ==== Traitement des données:
%   1. range les données en ordre chronologique;
%   2. élimine les redondances temporelles pour une meme station (erreurs de saisie)
%   3. remplit la dernière colonne de données avec le coefficient de correction météo (en ppm)
%      (utilise l'altitude des stations et appelle la fonction indrefr.m)
%   4. exporte un fichier de données par station (avec en-tete EDAS)

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:);
si = si(k); me = me(k); vi = vi(k); co = co(k);

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(si,ST.cod(i)));
    if ~isempty(k)
        so = [so i];
	% calibre les données (surtout offset!)
        % Calcul les paramètres météo à l'altitude du réflecteur
        pa2 = d(k,1).*(((1 - 22.557e-6*ST.utm(i,3))./(1. - 22.557e-6*ST.utm(i0,3))).^5.225);
        ta2 = d(k,2) - 0.00606*(ST.utm(i,3) - ST.utm(i0,3));
        hr2 = d(k,3);
        n1 = indrefr(d(k,1),d(k,2),d(k,3));
        n2 = indrefr(pa2,ta2,hr2);
        d(k,6) = n0 - (n1 + n2)/2;
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
        k = find(strcmp(si,ST.cod{stn}) & t>=G.lim{end}(1) & t<=G.lim{end}(2));
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
        
        kn = find(strcmp(si,ST.cod{stn}));
        k = find(strcmp(si,ST.cod{stn}) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
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
        % -----------> Veille des stations
        if strcmp(ST.ali(stn),'CSD')
            etats(stn) = -1;
        end
        if ig == 1
            sd = sprintf('%s %0.1f mmHg, %0.1f °C, %0.1f %%, %0.3f ± %0.3f m, %0.2f ppm',stype,d(kn(end),:));
            mketat(etats(stn),tlast(stn),sd,lower(ST.cod{stn}),G.utc,acquis(stn))
        end
    
        % Titre et informations
        figure(1), clf
		G.tit = gtitle(stitre,G.ext{ig});
		G.eta = [G.lim{ig}(2),etats(stn),acquis(stn)];

		if ~isempty(ke)
			G.inf = {sprintf('Dernière mesure: {\\bf%s %+d}',datestr(t(ke)),G.utc), ...
                sprintf('Variation distance = {\\bf%1.3f \\pm %1.3f m}',d(ke,4)-d(kn(1),4),d(ke,5)), ...
                sprintf('Distance initiale = {\\bf%1.3f m}',d(kn(1),4)), ...
                sprintf('Correction météo = {\\bf%1.2f ppm}',d(ke,6)), ...
                sprintf('Divers = {\\bf%s / %s}',char(me(ke)),char(vi(ke))), ...
                sprintf('Remarque = {\\bf%s}',char(co(ke))), ...
                };
		else
			G.inf = {' '};
		end
        
        % Distance
        subplot(14,1,2:8), extaxes
        % ---- barres d'erreurs
        plot([t(k) t(k)]',[d(k,4)+d(k,5) d(k,4)-d(k,5)]' - d(kn(1),4),'-g')
        hold on
        % ---- données corrigées de la météo
        %plot(t(k),d(k,4)-d(k,4).*d(k,6)*1e-6 - (d(kn(1),4)-d(kn(1),4).*d(kn(1),6)*1e-6),'-','Color',.7*[1 1 1])
        % ---- données brutes et dernière mesure
        plot(t(k),d(k,4) - d(kn(1),4),'.-r','LineWidth',.1)
        plot(t(ke),d(ke,4) - d(kn(1),4),'db')
        hold off
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Distance (m)')
        
        % Correction météo
        subplot(14,1,10:13), extaxes
        plot(t(k),d(k,6),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('N_0-N_m (ppm)')
        
        tlabel(G.lim{ig},G.utc)
    
        mkgraph(sprintf('%s_%s',lower(ST.cod{stn}),G.ext{ig}),G,OPT)
    end
end
close

% ==== Tracé du graphe de synthèse
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

    % Titre et informations
    figure(1), orient tall, clf
    
    G.tit = gtitle(stitre,G.ext{ig});
    G.eta = [G.lim{ig}(2),rmean(etats(so)),rmean(acquis(so))];

    if isempty(k), break; end
    G.inf = {' ',' ',' ',' ',sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc)};
    %hold on
    %for i = 1:nx
    %    xl = .1 + .2*(i > 4);
    %    yl = .8 - .15*(mod(i-1,4)+1);
    %    plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(i))
    %    plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(i))
    %    text(xl+.03,yl,ST.ali{so(i)},'Fontsize',8,'FontWeight','bold')
    %end
    %hold off
	
%	for i = 1:nx
%        G.inf = [G.inf,{sprintf('{\\color[rgb]{%g %g %g}--} {\\bf%s}',scolor(i),ST.ali{so(i)})}];
%    end

    % Tracé courbes
    subplot(8,1,1:4),extaxes
    h = gca;
    hold on
    g = 1;
    sog = [];
    for i = 1:nx
        k = find(strcmp(si,ST.cod{so(i)}) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        if ~isempty(k)
            dex = d(k,4);
            eex = d(k,5);
            fex = d(k(1),4);
            plot([t(k) t(k)]',[dex+eex dex-eex]' - fex,'-','Color',scolor(g))
            plot(t(k),dex - fex,'.-','LineWidth',.1,'Color',scolor(g))
            g = g + 1;
            sog = [sog;i];
        end
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Distance relative (m)'))

    % Légende
    axes('Position',get(h,'Position'));
    axis([0 1 0 1]); axis off
    hold on
    for i = 1:length(sog)
        xl = .03;
        yl = 1 - .05*i;
        plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(i))
        plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(i))
        text(xl+.03,yl,ST.ali{so(sog(i))},'Fontsize',8,'FontWeight','bold')
    end
    hold off

 
    % Tracé courbes relatives NEZ
    subplot(8,1,5:8),extaxes
    h = gca;
    hold on
    g = 1;
    sog = [];
    for i = 1:nx
        k = [];  k0 = [];
        kk = find(strcmp(si,ST.cod{so(i)}) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        for j = 1:length(kk)
            kr = find(strcmp(si,ST.cod(i1)) & abs(t - t(kk(j)))<ddt);
            if ~isempty(kr)
                k0 = [k0;kr(1)];
                k = [k;kk(j)];
            end
        end
        if ~isempty(k)
            dex = d(k,4) - d(k0,4);
            eex = sqrt(d(k,5).^2 + d(k0,5).^2);
            fex = d(k(1),4) - d(k0(1),4);
            plot([t(k) t(k)]',[dex+eex dex-eex]' - fex,'-','Color',scolor(g))
            plot(t(k),dex - fex,'.-','LineWidth',.1,'Color',scolor(g))
            g = g + 1;
            sog = [sog;i];
        end
    end
    hold off, box on
    set(gca,'XLim',G.lim{ig},'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Distance relatives différentielles par rapport à {\\bf%s} (m)',ST.ali{i1}))
    tlabel(G.lim{ig},G.utc)

    % Légende
    axes('Position',get(h,'Position'));
    axis([0 1 0 1]); axis off
    hold on
    for i = 1:length(sog)
        xl = .03;
        yl = 1 - .05*i;
        plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(i))
        plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(i))
        text(xl+.03,yl,ST.ali{so(sog(i))},'Fontsize',8,'FontWeight','bold')
    end
    hold off

    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G)
end
close

if ivg(1) == 1
    mketat(etats(so),max(tlast),sprintf('%s %d stations',stype,nx),rcode,G.utc,acquis(so))
    G.sta = [{rcode};lower(ST.cod(so))];
    G.ali = [{'Distance'};ST.ali(so)];
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)

