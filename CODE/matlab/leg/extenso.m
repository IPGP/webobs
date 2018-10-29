function DOUT = extenso(mat,tlim,OPT,nograph,dirspec)
%EXTENSO   Traitement edes données d'Extensométrie.
%       EXTENSO sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       EXTENSO(MAT,TLIM,JCUM,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = EXTENSO(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier de données ASCII ('EXTENSO.DAT')
%           - uniques matrices t (temps) et d (données): les sites sont sélectionnés 
%             par un find dans la matrice si (site)
%           - tri chronologique
%           - pas de sauvegarde Matlab
%           - soustrait les valeurs de première distance (relatif)
%           - exportation de fichiers de données "traitées" par site sur le FTP
%
%   Auteurs: F. Beauducel + J.C. Komorowski, OVSG-IPGP
%   Création : 2001-10-23
%   Mise à jour : 2013-10-18

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'EXTENSO';
timelog(rcode,1)

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs,0);
pdat = sprintf('/cgi-bin/%s?site=',eval(['X.',G.ddb]));
G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};


Z = struct('nom',{'Zone Nord','Zone Sud-Est','Zone Sud'}, ...
           'cod',{{'GDEFNW1','GDEDUP1','GDEDUP2','GDEDUP3','GDEFNO1'}, ...
                   {'GDENAP1','GDEF8J1','GDEBLK1','GDELCX1','GDECSD1'}, ...
                   {'GDEDOL1','GDEDOL2','GDEPEY1','GDEF302','GDEF303'}});
stype = 'M';
serror = 0.1;

% ==== Initialisation des variables
samp = 100;    % pas d'échantillonnage des données (en jour)
last = 100;    % délai d'estimation pour l'état de la station (en jour)
cerr = .9;     % couleur barres d'erreur

sname = G.nom;
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

% ==== Importation du fichier de données (créé par le formulaire WEB)
f = sprintf('%s/%s.DAT',pftp,rcode);
[id,dd,hh,si,op,ta,me,ru,eo, ...
        ef1,ec1,ev1, ...
        ef2,ec2,ev2, ...
        ef3,ec3,ev3, ...
        ef4,ec4,ev4, ...
        ef5,ec5,ev5, ...
        ef6,ec6,ev6, ...
        ef7,ec7,ev7, ...
        ef8,ec8,ev8, ...
        ef9,ec9,ev9, ...
        co] = textread(f,'%d%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','headerlines',1);
disp(sprintf('File: %s imported.',f))

x = char(dd);
y = char(hh);
z0 = zeros([size(x,1) 1]);
t = datenum([str2double([cellstr(x(:,1:4)) cellstr(x(:,6:7)) cellstr(x(:,9:10)) cellstr(y(:,1:2)) cellstr(y(:,4:5))]) z0]);

% Remplit la matrice de données avec les mesures suivantes:
%   1. température
%   2. moyenne(ruban+fen+cadr) + offset
%   3. écart-type(ruban+fen+cadr)
%   4. moyenne(vent)
exm = str2double([ef1 ef2 ef3 ef4 ef5 ef6 ef7 ef8 ef9]);
ec = str2double([ec1 ec2 ec3 ec4 ec5 ec6 ec7 ec8 ec9]);
% when "cadran" field is NaN (empty) = new extenso with direct final reading
ec(isnan(ec)) = 0;
exm = exm + ec;
d = [str2double(ta),str2double(ru)+str2double(eo)+rmean(exm')',rstd(exm')', ...
     rmean(str2double([ev1 ev2 ev3 ev4 ev5 ev6 ev7 ev8 ev9])')', ...
 ];

% ==== Traitement des données:
%   1. range les données en ordre chronologique;
%   2. calibre les données avec le fichier de calibration
%   3. ajuste les erreurs (minimum défini par serror)
%   4. exporte un fichier de données par station (avec en-tete EDAS) avec NaN

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:);
si = si(k);
op = op(k);
co = co(k);

% Réhausse les erreurs inférieures à serror
d(:,3) = max(d(:,3),serror);

% Calibration et exportation des fichiers (par site)

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(si,ST.cod(i)));
    if ~isempty(k)
    	so = [so i];
	[d(k,:),C(i)] = calib(t(k),d(k,:),ST.clb(i));
        tt = datevec(t(k));
        f = sprintf('%s/%s.DAT',pftp,ST.cod{i});
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s: %s %s\r\n',rcode,ST.ali{i},ST.nom{i});
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# OMGR: /g::o1en/2,,:o3,,:o4 /pe\r\n');
        fprintf(fid, '# CHAN: YYYY MM DD HH NN %s_(%s) %s_(%s) %s_(%s) %s_(%s)\r\n',C(i).nm{1},C(i).un{1},C(i).nm{2},C(i).un{2},C(i).nm{3},C(i).un{3},C(i).nm{4},C(i).un{4});
        fprintf(fid, '%4d-%02d-%02d %02d:%02d %0.2f %0.2f %0.1f %0.1f\r\n',[tt(:,1:5),d(k,:)]');
        fclose(fid);
        disp(sprintf('File: %s updated.',f))
    end
end

% so contient les indices de stations (dans ST) pour lesquelles il y a des données
nx = length(so);

tm = datenum(tnow);
tn = min(t);

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
        k = find(strcmp(si,ST.ali(stn)) & t>=G.lim{end}(1) & t<=G.lim{end}(2));
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
    stitre = sprintf('%s: %s %s',ST.ali{stn},G.nom,ST.nom{stn});
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
        % -----------> stations en veille
        if ST.ope(stn) == 0
            etats(stn) = -1;
        end
        if ig == 1
            sd = sprintf('%s %0.1f °C, %0.2f ± %0.2f mm, %0.1f vt',stype,d(kn(end),1:4));
            mketat(etats(stn),tlast(stn),sd,lower(ST.cod{stn}),G.utc,acquis(stn))
        end
    
        
        % Titre et informations
        figure(1), clf

		G.tit = gtitle(stitre,G.ext{ig});
    	G.eta = [G.lim{ig}(2),etats(stn),acquis(stn)];

        if isempty(k), break; end

        G.inf = {sprintf('Dernière mesure: {\\bf%s %+d}',datestr(t(ke)),G.utc), ...
                sprintf('%s = {\\bf%+1.2f \\pm %1.2f %s}',C(stn).nm{2},d(ke,2)-d(k(1),2),d(ke,3),C(stn).un{2}), ...
                sprintf('Distance initiale = {\\bf%1.2f %s}',d(k(1),2),C(stn).un{2}), ...
                sprintf('%s = {\\bf%1.1f %s}',C(stn).nm{1},d(ke,1),C(stn).un{1}), ...
                sprintf('%s = {\\bf%1.1f} (0 à 3)',C(stn).nm{4},d(ke,4)), ...
                sprintf('Divers = {\\bf%s / %s}',char(me(ke)),char(op(ke))), ...
                sprintf('Remarque = {\\bf%s}',char(co(ke))), ...
                };
            
        % Distance
        subplot(14,1,2:9), extaxes
        plot([t(k) t(k)]',[d(k,2)+d(k,3) d(k,2)-d(k,3)]' - d(k(1),2),'-g')
        hold on
        plot(t(k),d(k,2) - d(k(1),2),'.-r','LineWidth',.1)
        hold off
        set(gca,'XLim',G.lim{ig},'XTickLabel',[],'FontSize',8)
        ylabel(sprintf('%s (%s)',C(stn).nm{2},C(stn).un{2}))
        
        % Température
        subplot(14,1,10:11), extaxes
        plot(t(k),d(k,1),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'XTickLabel',[],'FontSize',8)
        ylabel(sprintf('%s (%s)',C(stn).nm{1},C(stn).un{1}))

        % Vent
        subplot(14,1,12:13), extaxes
        plot(t(k),d(k,4),'.-m','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel(sprintf('%s (%s)',C(stn).nm{4},C(stn).un{4}))

        tlabel(G.lim{ig},G.utc)

        mkgraph(sprintf('%s_%s',lower(ST.cod{stn}),G.ext{ig}),G,OPT)
    end
end
close

% ==== Tracé des graphes de synthèse
stitre = sprintf('Synthèse Réseau %s',sname);
for ig = ivg

    k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
    if ~isempty(k), ke = k(end); else ke = []; end

    % Titre et informations
    figure(1), clf, orient tall
    
	G.tit = gtitle(stitre,G.ext{ig});
	G.eta = [G.lim{ig}(2),rmean(etats(so)),rmean(acquis(so))];

    if isempty(k), break; end
    G.inf = {sprintf('Dernière mesure: {\\bf%s %+d}',datestr(t(ke)),G.utc)};
    
    for iz = 1:length(Z)
        lz = length(Z(iz).cod);
        % Tracé courbes
        subplot(9,1,3*(iz-1)+(1:3)), extaxes
        h = gca;
        hold on
        for i = 1:lz
            k = find(strcmp(si,Z(iz).cod(i)) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
            if ~isempty(k)
                dex = d(k,2); eex = d(k,3); fex = d(k(1),2);
                plot([t(k) t(k)]',[dex+eex dex-eex]' - fex,'-','Color',scolor(i))
                plot(t(k),dex - fex,'.-','LineWidth',.1,'Color',scolor(i))
            end
        end
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        hold off, box on
        ylabel(sprintf('Écartement %s (mm)',Z(iz).nom))
        if iz == length(Z)
            tlabel(G.lim{ig},G.utc)
        end    

        % Légende
        axes('Position',get(h,'Position'));
        axis([0 1 0 1]); axis off
        hold on
        for i = 1:lz
            xl = .03;
            yl = 1 - .06*i;
            plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(i))
            plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(i))
            text(xl+.03,yl,ST.ali{find(strcmp(ST.cod,Z(iz).cod{i}))},'Fontsize',8,'FontWeight','bold')
        end
        hold off
    end
    mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
end
close

if ivg(1) == 1
    mketat(etats(so),max(tlast),sprintf('%s %d stations',stype,nx),rcode,G.utc,acquis(so))
    G.sta = [{rcode};lower(ST.cod(so))];
    G.ali = [{'Extenso'};ST.ali(so)];
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)

