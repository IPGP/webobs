function DOUT=sismobul(mat,tlim,OPT,nograph,dirspec)
%SISMOBUL Graphes des Bulletins Sismicité OVSG.
%       SISMOBUL sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       SISMOBUL(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = SISMOBUL(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code station
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - utilisation d'un fichier ASCII pour les données 1955-1980 (mensuel/annuel)
%           - fichiers de phases (bulletin) mensuels ASCII au format HYPO71 (.HYP ou .TXT)
%           - différents critères d'interprétation
%           - création de fichiers ASCII synthétiques: liste des séismes ("sismo_volc.dat"),
%             histogrammes journalier ("sismo_volc_day.dat"), mensuel ("sismo_volc_month.dat")
%           - pas d'état de station
%           - graphe supplémentaire "10 derniers événements"
%
%   Auteurs: F. Beauducel + C. Anténor, OVSG-IPGP
%   Création : 2001-08-01
%   Mise à jour : 2010-07-11

% ===================== Chargement de toutes les données disponibles

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

% Initialisation des variables

rcode = 'SISMOBUL';
timelog(rcode,1)

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;

% Initialisation des variables
tu = G.utc;        % temps station (en heure TU)

sgra = {sprintf('%s-VOL',rcode)};
sgrn = {'Volcanique Soufrière'};
sali = {'Soufrière'};
sftp = {'Soufriere'};

G.cpr = 'OVSG-IPGP';


% ======================================================================
% ============ Bulletin Volcanique

st = 1;
sname = sprintf('%s %s',G.nom,sgrn{st});
pftp = sprintf('%s/%s/%s',X.RACINE_FTP,G.ftp,sftp{st});
fanc = 'volca_1955-1980.txt';

ts = {'VT','VE','EM','LP','Autre'};
C = struct('name',{'Magnitude','Energie','Durée','Type','Ressenti','Phases'}, ...
    'unit',{'','MJ','s','','',''});

car10 = '                 10';  % ligne "caractère 10' séparation événementc
idur = 71:75;   % Indices du champ durée
icom = 76;      % Indice du début du champ commentaire
icod = 85:89;   % Indices du champ code séisme
ipha = 12:24;   % indices des phases (à partir du mois)

% Définit l'heure TU à partir de l'heure du serveur (locale = GMT-4)
t = [];     % vecteur temps
d = [];     % matrice données
stitre = sprintf('%s: %s',upper(rcode),sname);

% Date et mois de début des données existantes
ydeb = 1981;
mdeb = 1;
flag = 0;
sdeb = sprintf('Début des bulletins complets: %s',datestr(datenum(ydeb,mdeb,1),1));

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
if mat & exist(f_save,'file')
    load(f_save,'t','d');
    disp(sprintf('Fichier: %s importé.',f_save))
    % date dernier événement sauvé
    tdeb = datevec(t(end));
    % le chargement commencera au mois suivant
    ydeb = tdeb(1);
    mdeb = tdeb(2)+1;
    if mdeb == 13
        ydeb = ydeb + 1;
        mdeb = 1;
    end
else
    disp('Pas de sauvegarde Matlab. Chargement de toutes les données...');
end

% Importation des données anciennes (valeurs annuelles ou mensuelles)
f = sprintf('%s/%s',pftp,fanc);
[yy,mm,nn,ee,rr] = textread(f,'%n%n%n%n%n','commentstyle','shell');
t0 = datenum(yy,mm,1);
d0 = [nn,ee,rr,zeros(size(rr))];
disp(sprintf('Fichier: %s importé.',f))

% Importation des fichiers de données (mensuels)
for annee = ydeb:tnow(1)
    p = sprintf('%s/%4d',pftp,annee);
    if exist(p,'dir')
        if annee == ydeb, mm = mdeb; else mm = 1; end
        for m = mm:12
            % Sauvegarde Matlab des données "anciennes"
            if ~flag & ((annee == tnow(1) & m+1 == tnow(2)) | (annee+1 == tnow(1) & m-11 == tnow(2)))
                save(f_save);
                disp(sprintf('Fichier: %s créé.',f_save))
                flag = 1;
            end
            f = sprintf('%s/%4d-%02dV.',p,annee,m);
            if annee < 2001
                f = [f,'HYP'];
            else
                f = [f,'txt'];
            end    
            if exist(f,'file')
                dd = textread(f,'%s','delimiter','\n','whitespace','');
                disp(sprintf('Fichier: %s importé.',f))
                
                % Interprétation des phases (extraction des séismes)
                %   md = magnitude de durée
                %   du = durée (secondes)
                %   ty = type (voir ts)
                tt = NaN;  du = NaN;  ty = 1;  rs = 0;  np = 0;
                for i = 1:size(dd,1)
                    ds = dd{i,:};
                    % ligne CAR10 = fin d'événement
                    %if strmatch(car10,ds)  %%% !!! ne marche pas sous Matlab 6.0 => pb textread qui ne garde pas les espaces en début de chaine
                    if str2double(ds) == 10
                        switch ty
                        case {1,2}
                            [md,en] = emd(du,3);
                        otherwise
                            md = NaN;
                            en = 0;
                        end
                        t = [t;tt];
                        d = [d;[md,en,du,ty,rs,np]];
                        tt = NaN;  du = NaN;  ty = 1;  rs = 0;  np = 0;
                    else if length(ds) >= max(ipha)
                        np = np + 1;
                        % lit la date de la première phase P
                        if isnan(tt)
                            pm = str2double(ds(ipha(1:2)));
                            pd = str2double(ds(ipha(3:4)));
                            ph = str2double(ds(ipha(5:6)));
                            pn = str2double(ds(ipha(7:8)));
                            ps = str2double(ds(ipha(9:end)));
                            tt = datenum([annee,pm,pd,ph,pn,ps]);
                        end
                        % lit la durée
                        if length(ds) >= idur(end)
                            if ~isempty(deblank(ds(idur)))
                                du = str2double(ds(idur));
                            end
                        end
                        % lit le code (s'il existe)
                        if length(ds) >= icod(end) & annee >= 2001
                            switch ds(icod(1:2))
			    case '  '	% important: ne rien faire si pas de code.
                            case {'VA','VB'}
                                ty = 1;
                            case {'VE'}
                                ty = 2;
                            case {'EM','HY'}
                                ty = 3;
			    case {'VM'}
			     	ty = 4;
                            otherwise
			    	ty = 0;
                            end
                            if length(deblank(ds(icod)) > 2)
                                rs = str2double(ds(icod(3)));
                            end
                        end
                        % lit les commentaires (si le type n'est pas encore déterminé)
                        if length(ds) >= icom
                            if ty==1 & (~isempty(findstr(ds(icom:end),'EMB')) | ~isempty(findstr(ds(icom:end),'E=')) | ~isempty(findstr(ds(icom:end),' d=')))
                                ty = 3;
                            end
                            if ~isempty(findstr(upper(ds(icom:end)),'RESS'))
                                rs = 2;
                            end
                        end
		    end
                    end
                end
            end
        end
    end
end

% Traitement des données:
%   1. range les données en ordre chronologique;
%   2. supprime les dates NaN et types 0
[t,i] = sort(t);
d = d(i,:);
k = find(isnan(t) | d(:,4)==0);
t(k) = [];
d(k,:) = [];
tt = datevec(t);

% La matrice de données d contient:
%   1 = magnitude
%   2 = énergie
%   3 = durée (s)
%   4 = type (voir ts)
%   5 = ressenti (intensité)
%   6 = nb de phases

if isempty(tlim)
    % Exportation des fichiers synthétiques ASCII
    %   1. fichier complet (à partir de 1981)
    f = sprintf('%s/sismo_volc.dat',pftp);
    fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s\r\n',sname);
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# CHAN: YYYY MM DD HH NN SS Magnitude Energy_(MJ) Duration_(s) Type Felt Phases\r\n');
        fprintf(fid, '%4d-%02d-%02d %02d:%02d:%05.2f %1.2f %1.3f %4.1f %d %d %d\r\n',[tt,d]');
    fclose(fid);
    disp(sprintf('File: %s created.',f))

    %   2. fichier histogramme journalier (à partir de 1981)
    th = floor(t(1)):(floor(now)-1);
    tv = datevec(th);
    [dh,ih] = histc(t,th);
    % DEBUG AB : La fonction histc retourne 0 pour les valeurs incorrectes et ça ne marche pas comme index, il faut les virer
    ih(find(ih==0))=[];
    eh = zeros(size(dh));
    for i = 1:length(eh)
        eh(i) = sum(d(find(ih==i),2));
    end
    rh = zeros(size(dh));
    for i = 1:length(rh)
        rh(i) = sum(d(find(ih==i),5)>1);
    end
    rl = zeros(size(dh));
    for i = 1:length(rl)
        rl(i) = sum(d(find(ih==i),4)==4);
    end
    f = sprintf('%s/sismo_volc_day.dat',pftp);
    fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s - Daily Histogram\r\n',sname);
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# CHAN: YYYY MM DD Number_(#) Energy_(MJ) Nb_Felt_(#) Nb_LP(#)\r\n');
        fprintf(fid, '%4d-%02d-%02d %4d %6.3f %4d %4d\r\n',[tv(:,1:3),dh,eh,rh,rl]');
    fclose(fid);
    disp(sprintf('Fichier: %s créé.',f))

    %   3. fichier histogramme mensuel (à partir de 1980)
    kv0 = find(t0 >= datenum(1980,1,1));
    tv1 = (1:((tt(end,1)-tt(1,1))*12 + tt(end,2) + 1))';
    tv = [tt(1,1)*ones(size(tv1)),tv1,ones(size(tv1))];
    th = datenum(tv);
    tv = datevec([t0(kv0);th]);
    [dh,ih] = histc(t,th);
    eh = zeros(size(dh));
    for i = 1:length(eh)
        eh(i) = sum(d(find(ih==i),2));
    end
    rh = zeros(size(dh));
    for i = 1:length(rh)
        rh(i) = sum(d(find(ih==i),5)>1);
    end
    rl = zeros(size(dh));
    for i = 1:length(rl)
        rl(i) = sum(d(find(ih==i),4)==4);
    end
    f = sprintf('%s/sismo_volc_month.dat',pftp);
    fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s - Monthly Histogram\r\n',sname);
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# CHAN: YYYY MM Number_(#) Energy_(MJ) Nb_Felt_(#) Nb_LP_(#)\r\n');
        fprintf(fid, '%4d-%02d %4d %7.3f %4d %4d\r\n',[tv(:,1:2),[d0(kv0,:);[dh,eh,rh,rl]]]');
    fclose(fid);
    disp(sprintf('Fichier: %s créé.',f))

    %   4. fichier histogramme annuel (total)
    %th = floor(t(1)):ceil(t(end));
    %tv = datevec(th);
    %[dh,ih] = histc(t,th);
    
    tv = datevec([t0(1);t(end)]);
    th = datenum((tv(1):tv(2))',1,1);
    tv = datevec(th);
    %dz = [d0;[ones(size(t)),d(:,2),(d(:,5)>1),(d(:,4)==4)]];
    %[dh,ih] = histw([t0;t],dz(:,1),th);
    [dh,ih] = histc([t0;t],th);
    % DEBUG AB : La fonction histc retourne 0 pour les valeurs incorrectes et ça ne marche pas comme index, il faut les virer
    ih(find(ih==0))=[];
    % DEBUG AB : Si on prend t0, il faut aussi prendre d0, non ???
    d_d0=[[d0,zeros(size(rr)),zeros(size(rr))];d];
    eh = zeros(size(dh));
    for i = 1:length(eh)
        eh(i) = sum(d_d0(find(ih==i),2));
%         eh(i) = sum(d(find(ih==i),2));
    end
    rh = zeros(size(dh));
    for i = 1:length(rh)
        rh(i) = sum(d_d0(find(ih==i),5)>1);
%         rh(i) = sum(d(find(ih==i),5)>1);
    end
    rl = zeros(size(dh));
    for i = 1:length(rl)
        rl(i) = sum(d_d0(find(ih==i),4)==4);
%         rl(i) = sum(d(find(ih==i),4)==4);
    end
    f = sprintf('%s/sismo_volc_year.dat',pftp);
    fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s - Yearly Histogram\r\n',sname);
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# CHAN: YYYY Number_(#) Energy_(MJ) Nb_Felt_(#) Nb_LP_(#)\r\n');
        fprintf(fid, '%4d %4d %7.3f %4d %4d\r\n',[tv(:,1),[dh,eh,rh,rl]]');
    fclose(fid);
    disp(sprintf('Fichier: %s créé.',f))
end

% Interprétation des arguments d'entrée de la fonction
%	- t1 = temps min
%	- t2 = temps max
%	- structure G = paramètres de chaque graphe
%		.ext = type de graphe (durée) "station_EXT.png"
%		.lim = vecteur [tmin tmax]
%		.fmt = numéro format de date (fonction DATESTR) pour les XTick
%		.cum = durée cumulée pour les histogrammes (en jour)
%		.mks = taille des points de données (fonction PLOT)

% Décodage de l'argument TLIM
if isempty(tlim)
    ivg = 1:(length(G.ext)-2);
    if strcmp(G.ext(1),'10l')
        % Définition des temps min et max pour les 1à derniers événements
        G.lim{1} = [floor(t(end-9)) ceil(t(end))];
    end
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
    if exist('OPT','var')
    	if isfield(OPT,'fmt')
		G.fmt{ivg} = OPT.fmt;
	end
    	if isfield(OPT,'mks')
		G.mks{ivg} = OPT.mks;
	end
    	if isfield(OPT,'cum')
		G.cum{ivg} = OPT.cum;
	end
    end
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


% ===================== Tracé des graphes

for ig = ivg

    figure(1), clf, orient tall
    % tous les séismes Md > 0.1
    k = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2) & d(:,1) ~= 0);
    % séismes ressentis
    kr = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2) & d(:,5) > 1);
    % tous les séismes emboités et longue période
    ke = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2) & (d(:,4) == 2 | d(:,4) == 3));
    % séismes Md > 0.1 et non emboités
    km = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2) & d(:,1) ~= 0 & d(:,4) == 1);
    % séismes longue période
    kl = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2) & d(:,4) == 4);
    % tous les séismes confondus (Md > 0.1 ou emboité)
    kn = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2) & (d(:,1) ~= 0));
    % tous les séismes, avec ou sans magnitude
    kz = find(t >= G.lim{ig}(1) & t <= G.lim{ig}(2));
    % séismes anciens
    k0 = find(t0 >= G.lim{ig}(1) & t0 <= G.lim{ig}(2));

    switch G.cum{ig}
        case 1
            hcum = 'journalier';
        case 10
            hcum = '10 jours';
        case 30
            hcum = 'mensuel';
        case 365
            hcum = 'annuel';
        otherwise
            hcum = 'horaire';
    end

    % Titre et informations
    subplot(6,1,1)
    axis([0 1 0 1]);
    axis off
    gtitle(stitre,G.ext{ig})
    if ~isempty(k)
        text(0,.4,{'Dernier événement:', ...
            sprintf('   Date: {\\bf%s} {\\it%+d}',datestr(t(k(end))),tu), ...
            sprintf('   %s = {\\bf%g}',C(1).name,d(k(end),1)), ...
            sprintf('   %s = {\\bf%g %s}',C(2).name,d(k(end),2),C(2).unit), ...
            sprintf('   %s = {\\bf%g %s}',C(3).name,d(k(end),3),C(3).unit), ...
            sprintf('   %s = {\\bf%s}',C(4).name,ts{d(k(end),4)}), ...
            },'FontSize',10)
     end
       text(.5,.4,{ ...
            sprintf('   Période: {\\bf%s} au {\\bf%s} {\\it%+d}',datestr(G.lim{ig}(1)),datestr(G.lim{ig}(2)),tu), ...
            sprintf('   Magnitude maximale = {\\bf%1.1f}',max([0;d(k,1)])), ...
            sprintf('   %s cumulée = {\\bf%3g %s}',C(2).name,sum(d(k,2)),C(2).unit), ...
            sprintf('   Total événements = {\\bf%d}',length(kz)), ...
            sprintf('   Total séismes (dont ressentis) = {\\bf%d} ({\\bf%d})',length(kn)+sum(d0(k0,1)),length(kr)+sum(d0(k0,3))), ...
            sprintf('   Séismes emboités (durée totale) = {\\bf%d} ({\\bf%d s})',length(ke),rsum(d(ke,3))), ...
            sprintf('   Séismes longue période = {\\bf%d}',length(kl)), ...
            },'FontSize',8)
    
    % Nombre séismes + nombre cumulé (uniquement Md >= 0.1 ou emboité)
    subplot(6,1,4:5), extaxes
    tt0 = []; for i = 1:length(k0), tt0 = [tt0;repmat(t0(k0(i)),[d0(k0(i),1),1])]; end
    if ~isempty(kn)
        tj = G.lim{ig}(1):G.cum{ig}:G.lim{ig}(2);
        if isempty(km), djm = zeros(size(tj)); else djm = histc([tt0;t(km)],tj); end
        if isempty(kl), djl = zeros(size(tj)); else djl = histc(t(kl),tj); end
        if isempty(ke), dje = zeros(size(tj)); else dje = histc(t(ke),tj); end
        hp1 = bar(tj+G.cum{ig}/2,[djm(:),djl(:),dje(:)],'stack');
        colormap([0 .7 0;1 0 0;0 0 1])
    else
        nodata(G.lim{ig})
    end
    set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
    ylim = get(gca,'YLim');
    set(gca,'YLim',[0,max([5,ylim(2)])]);
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('Nb séismes (%s)',hcum))
    if ~isempty(kn)
        h1 = gca;
        h2 = axes('Position',get(h1,'Position'));
        tj = [[t0(k0);t(kn)],[t0(k0);t(kn)]]';  tj = tj(:);  tj(1) = [];
        dj = [zeros(size([t0(k0);t(kn)])),[d0(k0,1);ones(size(t(kn)))]]';  dj = dj(:);  dj(1) = [];
        hp2 = plot(tj,cumsum(dj),'-k');
        set(h2,'YAxisLocation','right','Color','none','XTickLabel',[],'XTick',[])
        set(h2,'XLim',get(h1,'XLim'),'Layer','top','FontSize',8)
        ylim = get(gca,'YLim');
        set(gca,'YLim',[0,max([5,ylim(2)])]);
        ylabel('Nombre cumulé')
        legend([hp1,hp2],'Isolés (VA)','Longue Période (VM)','Emboités (VE/EM)','Nb cumulé',2)
    end
    pos = get(gca,'Position');

    % Histogramme des magnitudes
    subplot(6,2,[3 5])
    pos1 = get(gca,'Position');
    set(gca,'Position',[pos(1),pos1(2),pos1(3)+pos1(1)-pos(1),pos(4)]);
    dmd = .5;
    if ~isempty(k)
        tj = -.5:dmd:5;
        dj = histc(d(k,1),tj);
        bar(tj+dmd/2,dj,'c')
        text(tj+dmd/2,dj,num2str(dj(:)),'HorizontalAlignment','left','VerticalAlignment','middle','rotation',90, ...
            'FontSize',8,'FontWeight','b')
    else
        nodata(G.lim{ig})
    end
    set(gca,'FontSize',8)
    xtick = get(gca,'XTick');
    set(gca,'XTick',xtick(1):dmd:xtick(end));
    ylim = get(gca,'YLim');
    set(gca,'YLim',[0,max([5,ylim(2)])]);
    ylabel('Nombre de séismes')
    xlabel(sprintf('%s (0.5(n) \\leq Md < 0.5(n+1))',C(1).name))
    title(sdeb)
    
    % Gutenberg-Richter B-value (nombre/magnitude en log)
    subplot(6,2,[4 6])
    pos1 = get(gca,'Position');
    set(gca,'Position',[pos1(1),pos1(2),pos(1)+pos(3)-pos1(1),pos(4)]);
    if ~isempty(k)
        tj = (0:.5:5)';
        dj = flipud(cumsum(flipud(histc(d(k,1),tj))));
        kk = find(dj > 1);
		if ~isempty(kk)
            dj = log10(dj(kk));
            tj = tj(kk);
            [p,s] = polyfit(tj,dj,1);
            if all(p)
               [y,delta] = polyval(p,tj,s);
               plot(tj,y,':','Color',.5*[1,1,1],'LineWidth',1.5), hold on
               plot(tj,dj,'ok','MarkerFaceColor','r','MarkerSize',8), hold off
               title(sprintf('Gutenberg-Richter B-Value = \\bf{%1.2f}',-p(1)),'FontSize',8)
		    end
        end
    end
    set(gca,'FontSize',8,'XLim',[0 6],'YLim',[0 Inf])
    xlabel('Magnitude')
    ylabel('LOG_{10}(Nombre de séismes)')

    % Energie histogramme + énergie cumulée
    subplot(6,1,6), extaxes
    if ~isempty(k)
        tj = (G.lim{ig}(1)+.5*G.cum{ig}):G.cum{ig}:(G.lim{ig}(2)-.5*G.cum{ig});
        pj = xcum([t0(k0);t(k)],[d0(k0,2);d(k,2)],tj)*1e6;
        ym = ceil(log10(max(pj)));
        kk = find(pj==0);
        pj(kk) = NaN;
        bar(tj,log10(pj),'c')
    else
        nodata(G.lim{ig})
	% DEBUG : Plantage si ym n'est pas défini
	ym=0;
    end
    set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'YLim',[3 max([4,ym])],'FontSize',8)
    datetick2('x',G.fmt{ig},'keeplimits')
    ylabel(sprintf('LOG_{10} %s (J, %s)',C(2).name,hcum))

    tlabel(G.lim{ig},tu)
    
    if ~isempty(k)
        h1 = gca;
        h2 = axes('Position',get(h1,'Position'));
        tj = [[t0(k0);t(k)],[t0(k0);t(k)]]';  tj = tj(:);  tj(1) = [];
        dj = [0*[d0(k0,2);d(k,2)],[d0(k0,2);d(k,2)]]';  dj = dj(:);  dj(1) = [];
        plot(tj,cumsum(dj),'-b')
        set(h2,'YAxisLocation','right','Color','none')
        set(h2,'XLim',get(h1,'XLim'),'XTickLabel',[],'XTick',[],'Layer','top','FontSize',8)
        ylim = get(gca,'YLim');
        set(gca,'YLim',[0,ylim(2)]);
        ylabel(sprintf('%s cumulée (%s)',C(2).name,C(2).unit))
    end

    ploterup;
    mkgraph(sprintf('%s_%s',sgra{st},G.ext{ig}),G,OPT)
    
end
close

if ivg(1) == 1
    G.sta = sgra;
    G.ali = sali;
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)
