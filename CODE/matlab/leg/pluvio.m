function DOUT = pluvio(mat,tlim,OPT,nograph,dirspec)
%PLUVIO Traitement des données de Pluviométrie.
%       PLUVIO sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       PLUVIO(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = PLUVIO(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier de données ASCII ('pluv_dat.txt') avec données jour en
%             lignes mensuelles
%           - uniques matrices t (temps) et d (données): les sites sont sélectionnés 
%             par un find dans la matrice si (site)
%           - utilise le fichier de noms et positions des stations OVSG (avec 'Y1')
%           - tri chronologique et élimination des données redondantes (correction de saisie)
%           - pas de sauvegarde Matlab
%           - exportation de fichiers de données "traitées" par site sur le FTP
%           - les stations sont classées par altitude décroissante sur le graphe
%
%   Auteurs: F. Beauducel + J.C. Komorowski, OVSG-IPGP
%   Création : 2002-02-01
%   Mise à jour : 2009-10-06

% ===================== Chargement de toutes les données disponibles

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'PLUVIO';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);
pdat = sprintf('/cgi-bin/%s?site=',X.CGI_AFFICHE_PLUVIO);
G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};


% ==== Initialisation des variables
samp = 1;      % pas d'échantillonnage des données (en jour)
last = 90;     % délai d'estimation pour l'état de la station (en jour)

sname = G.nom;

G.cpr = 'OVSG-IPGP/MétéoFrance';
G.lg2 = 'logo_meteo.jpg';

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
stype = 'A';

mois = [31,28,31,30,31,30,31,31,30,31,30,31];

% ==== Importation du fichier de données (créé par le formulaire WEB)
f = sprintf('%s/%s',pftp,X.PLUVIO_FILE_NAME);
[id,yy,mm,ss,d01,v01,d02,v02,d03,v03,d04,v04,d05,v05,d06,v06,d07,v07,d08,v08,d09,v09,d10,v10,d11,v11,d12,v12,d13,v13,d14,v14,d15,v15,d16,v16,d17,v17,d18,v18,d19,v19,d20,v20,d21,v21,d22,v22,d23,v23,d24,v24,d25,v25,d26,v26,d27,v27,d28,v28,d29,v29,d30,v30,d31,v31]=textread(f,'%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','headerlines',1);
disp(sprintf('Fichier: %s importé.',f))
mm = str2double(mm);
yy = str2double(yy);
dd = str2double([d01,d02,d03,d04,d05,d06,d07,d08,d09,d10,d11,d12,d13,d14,d15,d16,d17,d18,d19,d20,d21,d22,d23,d24,d25,d26,d27,d28,d29,d30,d31]);
vv = str2double([v01,v02,v03,v04,v05,v06,v07,v08,v09,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,v28,v29,v30,v31]);
nj = mois(mm)';  % nombre de jours dans le mois
% traitement des années bissextiles
k = find(nj == 28);
ab = datevec(datenum(yy(k),2*ones(size(k)),29*ones(size(k))));
kk = k(find(ab(:,3) == 29));
nj(kk) = 29*ones(size(kk));

% Remplit la matrice de données journalières avec :
%   1 = précipitations (mm)
%   2 = validité: 0 = pas de donnée, 1 = correct, 2 = douteux, 3 = début, 4 = fin cumul

t = []; d = []; si = [];
for i = 1:length(mm)
    t = [t;datenum(yy(i)*ones(nj(i),1),mm(i)*ones(nj(i),1),(1:nj(i))')];
    d = [d;dd(i,1:nj(i))',vv(i,1:nj(i))'];
    si = [si;cellstr(char(ones(nj(i),1)*ss{i}))];
end


% ==== Traitement des données:
%   1. range les données en ordre chronologique;
%   3. exporte un fichier de données par station (avec en-tete EDAS)

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:);
si = si(k);

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(si,ST.cod(i)));
    if ~isempty(k)
        so = [so i];
    end
end
% Tri des stations par altitude décroissante
nx = length(so);
[alt,i] = sort(ST.wgs(so,3));
so = so(flipud(i));

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
        G.cum{ivg} = OPT.cum;
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    for st = 1:nx
        stn = so(st);
        k = find(strcmp(si,ST.cod(stn)) & t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
        DOUT(st).code = ST.ali(stn);
        DOUT(st).time = t(k);
        DOUT(st).data = d(k,:);
    end
end

if nargin > 3
    if nograph == 1, G = []; end
end

% ==== Tracé des graphes
stitre = sprintf('%s: Réseau %s',rcode,sname);
for ig = ivg

    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if ~isempty(k), ke = k(end); else ke = []; end

    % Titre et légende
    figure(1), clf
	psz = get(gcf,'PaperSize');
set(gcf,'PaperSize',[psz(1),psz(2) + 2*nx])
orient tall

    G.tit = gtitle(stitre,G.ext{ig});

    sinf = [];
	for g = 1:nx
        stn = so(g);
        kn = find(strcmp(si,ST.cod(stn)));
        k = find(strcmp(si,ST.cod(stn)) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        % Etat de la station
        acquis(stn) = round(100*length(k)*samp/diff(G.lim{ig}));
        tlast(stn) = t(kn(end));
        kl = find(t(k) >= G.lim{ig}(2)-last);
        if ~isempty(kl)
            etats(stn) = 100;
        else
            etats(stn) = 0;
        end
        % -----------> Veille de certaines stations: à valider ici
        if strcmp(ST.ali(stn),'CARBET3')
            etats(stn) = -1;
        end
        if ig == 1
            sd = sprintf('%s %0.1f mm, %d',stype,d(kn(end),:));
            mketat(etats(stn),tlast(stn),sd,lower(ST.cod{stn}),G.utc,acquis(stn))
        end
		if ~isempty(k)
		    sinf = [sinf,{sprintf('%s = {\\bf%1.3f}',ST.ali{stn},rsum(d(k,1))/1e3)}];
		else
		    sinf = [sinf,{sprintf('%s = ',ST.ali{stn})}];
		end
    end
    etat = etats(so);
    G.eta = [G.lim{ig}(2),mean(etat(find(etat ~= -1))),round(mean(acquis(so)))];
	if ~isempty(ke)
       G.inf = {'Dernière mesure:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc),'Cumul (en m)',' '};
	   G.inf = [G.inf,sinf];
	end

    if ig == 1
        mketat(etats(so),max(tlast),sprintf('%s %d %s',stype,nx,G.snm),rcode,G.utc,acquis(so))
    end

    % Pluviométrie par site
    for g = 1:nx
        subplot(nx,1,g), extaxes
        stn = so(g);
        k = find(strcmp(si,ST.cod(stn)) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        tj = (G.lim{ig}(1)+.5*G.cum{ig}):G.cum{ig}:(G.lim{ig}(2)-.5*G.cum{ig});
        pj = xcum(t(k),d(k,1),tj);
        bar(tj,pj,'g')
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('%s (mm)',ST.ali{stn}))
        switch G.cum{ig}
            case 1
                hcum = 'journalière';
            case 30
                hcum = 'mensuelle';
            case 365
                hcum = 'annuelle';
            otherwise
                hcum = sprintf('%g jour(s)',G.cum{ig});
        end
        if g == 1
            title(sprintf('Pluviosité %s en mm',hcum))
        end
        if g == nx
            tlabel(G.lim{ig},G.utc)
        end
        h1 = gca;
        h2 = axes('Position',get(h1,'Position'));
        plot(t(k),cumsumgap(d(k,1))/1000,'-')
        set(h2,'YAxisLocation','right','Color','none','XTickLabel',[],'XTick',[])
        set(h2,'XLim',get(h1,'XLim'),'Layer','top','FontSize',8)
        ylabel(sprintf('Cumul (m)'))
    end

    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
end
close

if ivg(1) == 1
    G.sta = {rcode};
    G.ali = {'Pluvio'};
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)

