function DOUT = rsam(mat,tlim,OPT,nograph,dirspec)
%RSAM   Graphes des données RSAM OVSG.
%       RSAM sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       RSAM(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = RSAM(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Attention: nécessite les fonctions PEVENT, TIMELOG, MATPAD, MAKEPSPNG.
%       Attention: toutes les heures en TU, sauf l'heure du serveur (donnée par "now").
%
%       Spécificités du traitement :
%           - fichiers mensuels ASCII
%           - NaN si d==0 (pas de bruit de fond)
%           - seules 8 stations exploitées (sur 16 canaux)
%
%   Auteurs: F. Beauducel + C. Anténor-Habazac, OVSG-IPGP
%   Création : 2001-06-14
%   Mise à jour : 2009-10-06

% ===================== Chargement de toutes les données disponibles

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'RSAM';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;

stype = 'T';

% Initialisation des variables
samp = 10/1440;  % pas d'échantillonnage des données (en jour)
last = 1/24;     % délai d'estimation pour l'état de la station (en jour)

sname = G.nom;
G.cpr = 'OVSG-IPGP';
stitre = sprintf('%s: %s',upper(rcode),sname);
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

% Définit l'heure TU à partir de l'heure du serveur (locale = GMT-4)
t = [];
d = [];

% Chargement du fichier INI (nom de stations)
f = sprintf('%s/WIN_RSAM.INI',pftp);
[Sb,Sn] = textread(f,'%s%s%*[^\n]','headerlines',18);
nx = 16;
so = [1 2 3 6 8 10 11 14 4 13 15 16];
disp(sprintf('Fichier: %s importé.',f))

% Chargement du fichier d'alarmes simplifié
f = sprintf('%s/rsam_alarm.dat',pftp);
[Bh,Bn,Bs,Bm,Bd,By] = textread(f,'%n:%n:%n %n-%n-%n');
talarm = datenum(By,Bm,Bd,Bh,Bn,Bs);
disp(sprintf('Fichier: %s importé.',f))

% Date et mois de début des données existantes
ydeb = 1999;
mdeb = 1;

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_10_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
if mat & exist(f_save,'file')
    load(f_save,'t','d');
    disp(sprintf('Fichier: %s importé.',f_save))
    tdeb = datevec(t(end));
    ydeb = tdeb(1);
    mdeb = tdeb(2)+1;
    if ydeb==tnow(1) & mdeb==tnow(2)
        flag = 1;
    else
        flag = 0;
    end
else
    disp('Pas de sauvegarde Matlab. Chargement de toutes les données...');
    flag = 0;
end

% Importation des fichiers de données (mensuels)
for annee = ydeb:tnow(1)
    p = sprintf('%s/%4d',pftp,annee);
    if exist(p,'dir')
        if annee==ydeb, mm = mdeb; else mm = 1; end
        for m = mm:12
            % Sauvegarde Matlab des données "anciennes"
            if ~flag & annee==tnow(1) & m==tnow(2)
                save(f_save);
                disp(sprintf('Fichier: %s créé.',f_save))
                flag = 1;
            end
            f = sprintf('%s/rsam%02d%02d_10.dat',p,mod(annee,100),m);
            if exist(f,'file')
                [x0,x1,x2,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11,d12,d13,d14,d15,d16] = textread(f,'%20c%s%s%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n');
                disp(sprintf('Fichier: %s importé.',f))
                z0 = zeros(size(d1));
                j = floor(str2double(x2)/10000);
                t = [t;datenum([str2num(x0(:,8:11)) z0 z0 str2num(x0(:,13:14)) str2num(x0(:,16:17)) str2num(x0(:,19:20))]) + j(:,1)];
                d = [d;d1,d2,d3,d4,d5,d6,d7,d8,d9,d10,d11,d12,d13,d14,d15,d16];
            end
        end
    end
end


tlast = t(end);

% Traitement des données
% NaN si d==0
k = find(d==0);
d(k) = NaN;

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
        G.dec{ivg} = OPT.dec;
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
    DOUT.code = rcode;
    DOUT.time = t(k);
    DOUT.data = d(k,:);
end

if nargin > 3
    if nograph == 1, G = []; end
end


% ===================== Tracé des graphes

ylim = [1 1e4];
calarm = .7*[1 1 1];

for ig = ivg
    figure(1), clf, orient tall
    
    ka = find(talarm>=G.lim{ig}(1) & talarm<=G.lim{ig}(2));
    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if G.dec{ig} == 1
        tk = t(k);
        dk = d(k,:);
    else
        tk = rdecim(t(k),G.dec{ig});
        dk = rdecim(d(k,:),G.dec{ig});
    end
    if isempty(k)
        ke = [];
    else
        ke = k(end);
    end

    % Etat de la station
    acqui = 100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig});
    if t(ke) >= G.lim{ig}(2)-last
        etat = 0;
        for i = 1:length(so)
            if ~isnan(d(ke,so(i)))
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

    if strcmp(G.ext{ig},'24h')
        sd = '';
        for i = 1:8
            sd = [sd sprintf(', %s %d',Sn{so(i)},d(end,so(i)))];
        end
        mketat(etat,tlast,sd(3:end),rcode,G.utc,acqui)
    end

    %text(1,.8,sprintf('Acquisition à {\\bf%2.0f %%} sur {\\bf%1.0f jour(s)}',acqui,diff(G.lim{ig})), ...
    %    'HorizontalAlignment','right')
    %text(.9,.1,sprintf('depuis {\\bf%1.0f heure(s)}',last*24), 'HorizontalAlignment','center','FontSize',8)
	%G.tit = [G.tit,{sprintf('%s %+d - État %03d%% - Acquisition %03d%% - %s - %s',datestr(G.lim{ig}(2)),G.utc,round(etat),round(acqui),G.typ,G.acq)}];
    if ~isempty(k)
		G. inf = {' ',sprintf('Dernières valeurs: {\\bf%s %+d}',datestr(t(ke)),G.utc),'en pts (min|moy|max)'};
		if ~isempty(ka)
			G.inf = [G.inf,cellstr(sprintf('Dernière alarme: {\\bf%s %+d}',datestr(talarm(ka(end))),G.utc))];
		else
			G.inf = [G.inf,cellstr(' ')];
		end
		for ii = 1:length(so)
		    ss = sprintf('%02d. {\\bf%s} = %d (%d|%d|%d)',so(ii),Sn{so(ii)},d(ke,so(ii)),rmin(d(k,so(ii))),round(rmean(d(k,so(ii)))),rmax(d(k,so(ii))));
            G.inf = [G.inf,cellstr(ss)];
		end
	else
	    G.inf = {' '};
    end
    
    % Stations Soufrière
    subplot(6,1,1:3), extaxes
    g = 1:7;
    if ~isempty(ka)
        semilogy([talarm(ka) talarm(ka)]',[ylim(1)*ones(size(ka)) ylim(2)*ones(size(ka))]','Color',calarm)
        hold on
    end
    h = semilogy(tk,dk(:,so(g)),'LineWidth',G.mks{ig});
    hold off
    set(gca,'XLim',G.lim{ig},'YLim',ylim,'FontSize',8)
    if ~isempty(k), legend(h,Sn(so(g)),2), end
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel('Réseau Soufrière')
    if G.dec{ig} ~= 1
       title(sprintf('Moyenne %s',adjtemps(samp*G.dec{ig})),'HorizontalAlignment','center','FontSize',8)
    end

    % Stations Régionale
    g = 8:12;
    subplot(6,1,4:6), extaxes
    if ~isempty(ka)
        semilogy([talarm(ka) talarm(ka)]',[ylim(1)*ones(size(ka)) ylim(2)*ones(size(ka))]','Color',calarm)
        hold on
    end
    h = semilogy(tk,dk(:,so(g)),'LineWidth',G.mks{ig});
    hold off
    set(gca,'XLim',G.lim{ig},'YLim',ylim,'FontSize',8)
    if ~isempty(k), legend(h,Sn(so(g)),2), end
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel('Stations régionales')

    tlabel(G.lim{ig},G.utc)
    
    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
    
end
close

if ivg(1) == 1
    G.sta = {rcode};
    G.ali = {rcode};
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)
