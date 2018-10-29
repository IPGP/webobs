function DOUT=pselec(mat,tlim,OPT,nograph,dirspec)
%PS     Tracé des graphes du réseau PS.
%       PSELEC sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       PSELEC(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = PSELEC(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code station
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Particularités:
%           - si toutes les voies sont à zéro (avant calibration, la ligne de 
%             données est éliminée (station considérée HS);
%           - 0.0 mV est considéré comme NaN (en plus du test Vmin et Vmax).
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-07-23
%   Mise à jour : 2009-10-06

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'PSELEC';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);

ist = find(strcmp(ST.dat,'F30'));
nb = length(ist);

stype = 'T';

% Initialisation des variables
samp = 1/1440;  % pas d'échantillonnage des données (en jour)
last = 1/24;    % délai d'estimation pour l'état de la station (en jour)
G.cpr = 'FB, OVSG-IPGP/OPGC';
G.lg2 = 'logo_umr6524.jpg';

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

for st = 1:nb

    stn = ist(st);
    scode = ST.cod{stn};
    sname = ST.nom{stn};
    sali = ST.ali{stn};

    % Récupère l'heure du serveur (locale = GMT-4)
    jnow = floor(datenum(tnow)-datenum(tnow(1),1,0));
    t = [];
    d = [];

    % Calibration et filtres
    [stitre,c,nx] = readclb(sprintf('%s/%s/%s.clb',pftp,sali,sali));
    so = 1:9;

    % Année de début des données existantes
    ydeb = 2000;

    % Test: chargement si la sauvegarde Matlab existe
    f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,lower(scode));
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
        ydeb = 2000;
        jdeb = 353;
    end

    % Chargement des fichiers journaliers (AAA*.TXT)
    for annee = ydeb:tnow(1)
        p = sprintf('%s/%s/%d',pftp,sali,annee);
        if exist(p,'dir')
            if annee==ydeb, jj = jdeb; else jj = 1; end
            for j = jj:366
                % Sauvegarde Matlab des données "anciennes"
                if ~flag & annee==tnow(1) & j==jnow
                    save(f_save);
                    disp(sprintf('Fichier: %s créé.',f_save))
                end
                f = sprintf('%s/%s_%04d_%03d.',p,sali,annee,j);
                if exist([f 'txt'],'file')
                    f = [f 'txt'];
                end
                if exist([f 'TXT'],'file')
                    f = [f 'TXT'];
                end
                if exist(f,'file')
                    x = load(f);
                    disp(sprintf('Fichier: %s importé.',f))
                    sz = size(x,1);
                    if sz
                        t = [t;datenum(annee,1,0)+floor(x(:,1))+mod(x(:,1),1)*1e5/86400];
                        d = [d;x(:,2:2:18)];
                    end
                end
            end
        end
    end    

    tacq = t;
    vacq = datevec(tacq(end));
    facq = sprintf('%s_%04d_%03d.TXT',sali,vacq(1),floor(tacq(end))-datenum([vacq(1),0,1]));
 
    % Traitement des données:
    %   1. supprime les données (et le temps) si toutes les voies sont à zéro
    %   2. calibre les données;
    %   3. filtre Vmin/Vmax et remplace par des NaN.
    k = find(all(d' == 0));
    t(k) = [];
    d(k,:) = [];

    for i = 1:nx
        d(:,i) = d(:,i)*c.x1(i) + c.x0(i);
        k = find(d(:,i)<c.vmin(i) | d(:,i)>c.vmax(i) | (d(:,i)==0 & strcmp(c.unit{i},'mV')));
        d(k,i) = d(k,i)*NaN;
    end

    tn = min(t);
    tm = datenum(tnow);
    tlast = t(end);

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
        k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
        DOUT(stn).code = scode;
        DOUT(stn).time = t(k);
        DOUT(stn).data = d(k,:);
    end

    % Si nograph==1, quitte la routine sans production de graphes
    if nargin > 3
        if nograph == 1, G = []; end
    end


    % ===================== Tracé des graphes

    for ig = ivg
    
        figure(1), clf, orient tall
        k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
        if isempty(k)
            ke = [];
        else
            ke = k(end);
        end 
    
        % Etat de la station
        acquis(st) = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
        if t(ke) >= G.lim{ig}(2)-last
            etat = 0;
            for i = 1:nx
                if ~isempty(find(~isnan(d(ke,i))))
                    etat = etat+1;
                end
            end
            etats(st) = 100*etat/length(so);
        else
            etats(st) = 0;
        end
    
        % Titre et informations
        if ig == 1
            sd = '';
            for i = 1:nx
                sd = [sd sprintf(', %1.1f %s', d(end,i),c.unit{i})];
            end
            mketat(etats(st),tlast,sd(3:end),lower(scode),G.utc,acquis(st))
            aacq = round(100*length(find(tacq>=G.lim{ig}(1) & tacq<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
            if tacq(end) >= G.lim{ig}(2)-last
                etat = 100;
            else
                etat = 0;
            end
            mketat(etat,tacq(end),facq,'acqe',G.utc,aacq)
        end

        G.tit = gtitle(stitre,G.ext{ig});
        G.eta = [G.lim{ig}(2),etats(st),acquis(st)];
		
		if ~isempty(k)
			G.inf = {'Dernière mesure:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc),' ',' ', ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(1),c.name{so(1)},d(ke,so(1)),c.unit{so(1)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(3),c.name{so(3)},d(ke,so(3)),c.unit{so(3)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(5),c.name{so(5)},d(ke,so(5)),c.unit{so(5)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(7),c.name{so(7)},d(ke,so(7)),c.unit{so(7)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(2),c.name{so(2)},d(ke,so(2)),c.unit{so(2)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(4),c.name{so(4)},d(ke,so(4)),c.unit{so(4)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(6),c.name{so(6)},d(ke,so(6)),c.unit{so(6)}), ...
                sprintf('%d. %s = {\\bf%1.1f %s}',so(8),c.name{so(8)},d(ke,so(8)),c.unit{so(8)}), ...
                sprintf('%s = {\\bf%1.1f %s}, cumulée = {\\bf%1.1f %s}',c.name{so(9)},d(ke,so(9)),c.unit{so(9)},sum(d(k,so(9))),c.unit{so(9)}), ...
				};
		else
		    G.inf = {''};
        end

   
        if ~isempty(k)
            % Pluie (cumulée et journalière / horaire)
            subplot(9,1,1)
            g = 9;
            tj = (G.lim{ig}(1)+.5*G.cum{ig}):G.cum{ig}:(G.lim{ig}(2)-.5*G.cum{ig});
            pj = xcum(t(k),d(k,so(g)),tj);
            %pj = decicum(d(k,so(g)),G(ig).cum/samp);
            %tj = linspace(t(k(1)),t(k(end)),length(pj)) + .5*G(ig).cum;
            if G.cum{ig} == 1
                hcum = 'journalière';
            else
                hcum = 'horaire';
            end
            bar(tj,pj,'g')
            set(gca,'XLim',G.lim{ig},'FontSize',8)
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel(sprintf('%s %s (%s)',c.name{so(g)},hcum,c.unit{so(g)}))
            h1 = gca;
            h2 = axes('Position',get(h1,'Position'));
            plot(t(k),cumsum(d(k,so(g))),'-')
            set(h2,'YAxisLocation','right','Color','none','XTickLabel',[],'XTick',[])
            set(h2,'XLim',get(h1,'XLim'),'Layer','top','FontSize',8)
            ylabel(sprintf('%s cumulée (%s)',c.name{so(g)},c.unit{so(g)}))

            % Electrodes
            ic = 1:8;
            for ii = 1:length(ic)
                g = ic(ii);
                subplot(9,1,1+ii)
                plot(t(k),d(k,so(g)),'.','MarkerSize',G.mks{ig})
                set(gca,'XLim',G.lim{ig},'FontSize',8)
                datetick2('x',G.fmt{ig},'keeplimits')
                ylabel(sprintf('%s (%s)',c.name{so(g)},c.unit{so(g)}))
                if length(find(~isnan(d(k,so(g)))))==0, nodata(G.lim{ig}), end
            end
            tlabel(G.lim{ig},G.utc)
        end
        
        mkgraph(sprintf('%s_%s',lower(scode),G.ext{ig}),G,OPT)
    end
end
close

if ivg(1) == 1
    mketat(etats,max(tlast),sprintf('%s %d %s',stype,length(etats),G.snm),rcode,G.utc,acquis)
    G.sta = lower(ST.cod(ist));
    G.ali = ST.ali(ist);
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)
