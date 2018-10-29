function DOUT=inclino(mat,tlim,OPT,nograph,dirspec)
%INCLINO  Tracé des graphes du réseau inclinométrie.
%       INCLINO sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       INCLINO(MAT,TLIM,NOGRAPH) effectue les opérations suivantes:
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
%           DIRSPEC = Repertoire d'ecriture des graphes specifiques (pour les requetes)
%
%       DOUT = INCLINO(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - boucle sur toutes les stations inclino
%           - fichiers journaliers en mV à partir de décembre 1994 (.MV)
%           - fichier de calibration (????DATA.DAT) pour la convertion en valeurs physique et 
%             le filtrage des données suivant des bornes en mV
%           - affichage des interventions de terrain (trait vertical grisé)
%           - ajustement automatique des échelles axe Y (4*std)
%       
%   Auteurs: F. Beauducel + C. Anténor-Habazac, OVSG-IPGP
%   Création : 2001-07-01
%   Mise à jour : 2009-10-06

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'INCLINO';
timelog(rcode,1);

% Lecture du fichier de configuration pour "rcode"
G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
% Lecture des informations sur les stations concernées
ST = readst(G.cod,G.obs);

% Indices des stations hors acquisition (codée par -)
ist = find(~strcmp(ST.dat,'-'));
nb = length(ist);

% Initialisation des variables
samp = 1/144;   % pas d'échantillonnage des données (en jour)
last = 1/24;    % délai d'estimation pour l'état de la station (en jour)

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
stype = 'T';
G.cpr = 'OVSG-IPGP';

coul = [1 0 0;  % Radial 1
        0 .5 0; % Radial 2
        1 0 0;  % Tangentiel 1
        0 .5 0; % Tangentiel 2   
        0 0 1;  % Température 1
        0 1 1;  % Température 2
        1 0 1]; % Batterie
cinterv = .7*[1 1 1];

% Astuce pour permettre la reconstruction de la base sur une seule station N (MAT = -N)
if mat<0
    ist = abs(mat);
    mat = 0;
end
    
for st = 1:nb

    stn = ist(st);
    scode = ST.cod{stn};
    alias = ST.ali{stn};
    sname = ST.nom{stn};

    % Récupère l'heure du serveur (locale = GMT-4)
    jnow = floor(datenum(tnow)-datenum(tnow(1),1,0));
    t = [];
    d = [];

    % Année etjour de début des données existantes
    ydeb = 1994;
    jdeb = 1;
    tdeb0 = datenum(ydeb,1,1);
    
    % Test: chargement si la sauvegarde Matlab existe
    f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,lower(scode));
    if mat & exist(f_save,'file')
        disp(sprintf('Importation de %s',f_save))
        load(f_save,'t','d'); % Charge les variables t et d depuis le fichier de sauvegarde
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
    end

    % Chargement des fichiers journaliers (*.MV)
    for annee = ydeb:tnow(1)
        p = sprintf('%s/%s/%d',pftp,alias,annee);
        if exist(p,'dir')
            if annee==ydeb, jj = jdeb; else jj = 1; end
            for j = jj:366
                % Sauvegarde Matlab des données "anciennes"
                if ~flag & annee==tnow(1) & j==jnow
                    save(f_save);
                    disp(sprintf('Fichier: %s créé.',f_save))
                end
                f = sprintf('%s/%s%1d%03d.MV',p,alias,mod(annee,10),j);
                if exist(f,'file')
                    eval('x = load(f);','warning(''problem to read file...'')');
                    disp(sprintf('Fichier: %s importé.',f))
                    if ~isempty(x)
                        sz = size(x(:,1));
                        if strcmp(alias,'BLKI') & datenum(annee,1,j)<datenum(2002,1,106)
                            x = [x NaN*zeros(sz(1),4)];
                        end
                        if strcmp(alias,'RNOI') & datenum(annee,1,j)<datenum(1998,1,325)
                            x = [x NaN*zeros(sz(1),4)];
                        end
                        if strcmp(alias,'TARI') & datenum(annee,1,j)<datenum(2002,1,1)
                            x = [x(:,1:5) NaN*zeros(sz(1),1) x(:,[10 6 7 9])];
                        end
                        t = [t;datenum(annee,1,j) + x(:,1)/24 + x(:,2)/1440];
                        d = [d;x(:,3:end)];
                    end
                end
            end
        end
    end    

    % Calibration et filtres
    [nx,tx,sx,dx,tr,dr] = readidat(sprintf('%s/%sDATA.DAT',pftp,alias));
    dr = flipud(cumsum(flipud(dr)));
    stitre = sprintf('%s : %s',alias,sname);
    srad = []; stan = []; stmp = []; sbat = []; snoc = [];
    for i = 1:nx
        sss = char(sx{i}{1});
        switch sss
            case 'InclinoR', srad = [srad;i];
            case 'InclinoT', stan = [stan;i];
            case 'Temp', stmp = [stmp;i];
            case 'Batterie', sbat = [sbat;i];
            otherwise, snoc = [snoc;i];
        end
    end
    so = [srad;stan;stmp;sbat];

    tn = min(t);
    tm = datenum(tnow);
    tlast(stn) = t(end);
    ta = tr';
    dmv = d(end,:);

    % Traitement des données (en fonction des dates tr et tx):
    %   1. filtre Vmin/Vmax/0 (en mV) et remplace par des NaN;
    %   2. applique les coefficients de calibration;
    %   3. applique les offsets de recentrage.
    %   4. filtre le bruit > 3*std
    
    for i = 1:nx
        ki = find(dx(:,1)==i);
        tt = [tm tx(ki)];
        for j = length(ki):-1:1
            k = find(t>=tt(j+1) & t<tt(j));
            kk = find(d(k,i)<dx(ki(j),4) | d(k,i)>dx(ki(j),5) | d(k,i)==0);
            if ~isempty(kk), d(k(kk),i) = d(k(kk),i)*NaN; end
            d(k,i) = d(k,i)./(dx(ki(j),2)*(dx(ki(j),3)^2));
        end
    end
    tt = [tm tr];
    for j = length(tr):-1:1
        k = find(t>=tt(j+1) & t<tt(j));
        d(k,:) = d(k,:) + repmat(dr(j,:),[length(k) 1]);
        disp(sprintf(' Recentre %2d : %s = %+g,%+g,%+g,%+g,%+g,%+g,%+g,%+g (%d éch)',j,datestr(tr(j)),dr(j,:),length(k)));
    end

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
    end
    
    % Renvoi des données dans DOUT, sur la période de temps G(end).lim
    if nargout > 0
        k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
        DOUT(stn).code = scode;
        DOUT(stn).time = t(k);
        DOUT(stn).data = d(k,:);
    end

    % Si nograph==1, quitte la boucle sans production de graphes
    if nargin > 3
        if nograph == 1, G = []; end
    end

    % ===================== Tracé des graphes

    for ig = ivg

       figure(1), clf, orient tall
       k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
       ka = find(ta>=G.lim{ig}(1) & ta<=G.lim{ig}(2));

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
                if ~isempty(find(~isnan(d(ke,so(i)))))
                    etat = etat + 1;
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
            etats(stn) = etat;
            acquis(stn) = acqui;
            sd = '';
            for i = 1:nx
                sd = [sd sprintf(', %1.1f %s',d(end,i),char(sx{i}{2}))];
            end
            mketat(etat,t(end),sd(3:end),lower(scode),G.utc,acqui)
        end


        if ~isempty(k)

	        % Définit les écart-types et premiers indices non NaN & < 3*std de la moyenne
            vrms = max([rstd(dk(:,srad(1))),rstd(dk(:,srad(2))),rstd(dk(:,stan(1))),rstd(dk(:,srad(2)))]);
	        vrms = 10*ceil(4*vrms/10);
            k1 = [];
            for i = 1:length(so)
                kk = find(~isnan(dk(:,so(i))) & abs(dk(:,so(i))-rmean(dk(:,so(i)))) < 3*rstd(dk(:,so(i))));
                if ~isempty(kk), k1(i) = kk(1); else k1(i) = 1; end
            end

            G.inf = {'Dernière mesure:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(k(end))),G.utc),' ',' ', ...
                    sprintf('%d. %s = {\\bf%+1.1f %s} (%+d mV)',srad(1),char(sx{srad(1)}{4}),dk(end,srad(1))-dk(k1(1),srad(1)),char(sx{srad(1)}{2}),dmv(srad(1))), ...
                    sprintf('%d. %s = {\\bf%+1.1f %s} (%+d mV)',stan(1),char(sx{stan(1)}{4}),dk(end,stan(1))-dk(k1(3),stan(1)),char(sx{stan(1)}{2}),dmv(stan(1))), ...
                    sprintf('%d. %s = {\\bf%1.1f %s} (%+d mV)',stmp(1),char(sx{stmp(1)}{4}),dk(end,stmp(1)),char(sx{stmp(1)}{2}),dmv(stmp(1))), ...
                    sprintf('%d. %s = {\\bf%1.1f %s} (%+d mV)',sbat(1),char(sx{sbat(1)}{4}),dk(end,sbat(1)),char(sx{sbat(1)}{2}),dmv(sbat(1))), ...
                    };
            if nx > 4
                G.inf = [G.inf,{ ...
                    sprintf('%d. %s = {\\bf%+1.1f %s} (%+d mV)',srad(2),char(sx{srad(2)}{4}),dk(end,srad(2))-dk(k1(2),srad(2)),char(sx{srad(2)}{2}),dmv(srad(2))), ...
                    sprintf('%d. %s = {\\bf%+1.1f %s} (%+d mV)',stan(2),char(sx{stan(2)}{4}),dk(end,stan(2))-dk(k1(4),stan(2)),char(sx{stan(2)}{2}),dmv(stan(2))), ...
                    sprintf('%d. %s = {\\bf%1.1f %s} (%+d mV)',snoc(1),char(sx{snoc(1)}{4}),dk(end,snoc(1)),char(sx{snoc(1)}{2}),dmv(snoc(1))), ...
                    sprintf('%d. %s = {\\bf%1.1f %s} (%+d mV)',snoc(2),char(sx{snoc(2)}{4}),dk(end,snoc(2)),char(sx{snoc(2)}{2}),dmv(snoc(2))), ...
                    }];
            end            
        
            % Radial
            subplot(6,1,1:2), extaxes
            plot(tk,dk(:,srad(1))-dk(k1(1),srad(1)),'.','Color',coul(1,:),'MarkerSize',G.mks{ig})
            hold on
            if length(srad) > 1
                plot(tk,dk(:,srad(2))-dk(k1(2),srad(2)),'.','Color',coul(2,:),'MarkerSize',G.mks{ig})
            end
            set(gca,'XLim',G.lim{ig})
            if ~isnan(vrms) & vrms, set(gca,'YLim',[-vrms vrms],'FontSize',8), end
            ylim = get(gca,'YLim');
            if ~isempty(ka)
                plot([ta(ka) ta(ka)]',[ylim(1)*ones(size(ka)) ylim(2)*ones(size(ka))]','Color',cinterv)
            end
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel('Inclinomètre radial (µrad)')
            if length(find(~isnan(dk(:,srad))))==0, nodata(G.lim{ig}), end
            v = axis;
            xl = diff(v(1:2))/100;
            yl = diff(v(3:4))/10;
            for i = 1:length(srad)
                plot(v(1)+xl,v(4)-i*yl,'.','Color',coul(i,:),'MarkerSize',6)
                text(v(1)+xl,v(4)-i*yl,sprintf('  %s',char(sx{srad(i)}{4})),'FontSize',8,'FontWeight','bold')
            end
            hold off
            if G.dec{ig} ~= 1
                title(sprintf('Moyenne %s',adjtemps(samp*G.dec{ig})))
            end

            % Tangentiel
            subplot(6,1,3:4), extaxes
            plot(tk,dk(:,stan(1))-dk(k1(3),stan(1)),'.','Color',coul(3,:),'MarkerSize',G.mks{ig})
            hold on
            if length(stan) > 1
                plot(tk,dk(:,stan(2))-dk(k1(4),stan(2)),'.','Color',coul(4,:),'MarkerSize',G.mks{ig})
            end
            set(gca,'XLim',G.lim{ig})
            if ~isnan(vrms) & vrms, set(gca,'YLim',[-vrms vrms],'FontSize',8), end
            ylim = get(gca,'YLim');
            if ~isempty(ka)
                plot([ta(ka) ta(ka)]',[ylim(1)*ones(size(ka)) ylim(2)*ones(size(ka))]','Color',cinterv)
            end
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel('Inclinomètre tangentiel (µrad)')
            if length(find(~isnan(dk(:,stan))))==0, nodata(G.lim{ig}), end
            v = axis;
            xl = diff(v(1:2))/100;
            yl = diff(v(3:4))/10;
            for i = 1:length(stan)
                plot(v(1)+xl,v(4)-i*yl,'.','Color',coul(i+2,:),'MarkerSize',6)
                text(v(1)+xl,v(4)-i*yl,sprintf('  %s',char(sx{stan(i)}{4})),'FontSize',8,'FontWeight','bold')
            end
            hold off

            % Température
            subplot(6,1,5), extaxes
            plot(tk,dk(:,stmp(1)),'.','Color',coul(5,:),'MarkerSize',G.mks{ig})
            hold on
            if length(stmp) > 1
                plot(tk,dk(:,stmp(2)),'.','Color',coul(6,:),'MarkerSize',G.mks{ig})
            end
            set(gca,'XLim',G.lim{ig},'YLim',[10 30],'FontSize',8)
            ylim = get(gca,'YLim');
            if ~isempty(ka)
                plot([ta(ka) ta(ka)]',[ylim(1)*ones(size(ka)) ylim(2)*ones(size(ka))]','Color',cinterv)
            end
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel('Température (°C)')
            if length(find(~isnan(dk(:,stmp))))==0, nodata(G.lim{ig}), end
            v = axis;
            xl = v(1) + diff(v(1:2))/100;
            yl = diff(v(3:4))/10;
            for i = 1:length(stmp)
                plot(xl,v(4)-i*yl,'.','Color',coul(4+i,:),'MarkerSize',6)
                text(xl,v(4)-i*yl,sprintf('  %s',char(sx{stmp(i)}{4})),'FontSize',8,'FontWeight','bold')
            end
            hold off
            
            % Batterie
            subplot(6,1,6), extaxes
            plot(tk,dk(:,sbat(1)),'.','Color',coul(7,:),'MarkerSize',G.mks{ig})
            hold on
            set(gca,'XLim',G.lim{ig},'YLim',[10 15],'FontSize',8)
            ylim = get(gca,'YLim');
            if ~isempty(ka)
                plot([ta(ka) ta(ka)]',[ylim(1)*ones(size(ka)) ylim(2)*ones(size(ka))]','Color',cinterv)
            end
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel(sprintf('Batterie (V)'))
            if length(find(~isnan(dk(:,sbat))))==0, nodata(G.lim{ig}), end
            hold off
            
            tlabel(G.lim{ig},G.utc)

        else
		    G.inf = {''};
        end

        mkgraph(sprintf('%s_%s',lower(scode),G.ext{ig}),G,OPT)
    end

end
close

if ivg(1) == 1
    mketat(mean(etats),max(tlast),sprintf('%s %d %s',stype,length(etats),G.snm),rcode,G.utc,mean(acquis))
    G.sta = lower(ST.cod(ist));
    G.ali = ST.ali(ist);
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)
