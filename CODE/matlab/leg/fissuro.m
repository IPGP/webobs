function DOUT = fissuro(mat,tlim,OPT,nograph,dirspec)
%FISSURO   Traitement des données d'Extensométrie.
%       FISSURO sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       FISSURO(MAT,TLIM,JCUM,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = FISSURO(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code 5 caractères
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier de données ASCII ('FISSURO.DAT')
%           - uniques matrices t (temps) et d (données): les sites sont sélectionnés 
%             par un find dans la matrice si (site)
%           - tri chronologique et fusion des lignes A et B pour une même date et heure
%           - pas de sauvegarde Matlab
%           - soustrait les valeurs de première distance (relatif)
%           - exportation de fichiers de données "traitées" par site sur le FTP (1 par site)
%
%   Auteurs: F. Beauducel + J.C. Komorowski, OVSG-IPGP
%   Création : 2001-10-23
%   Mise à jour : 2009-10-06

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'FISSURO';
timelog(rcode,1)

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);
pdat = sprintf('/cgi-bin/%s?site=',eval(['X.',G.ddb]));
%G.dat = {sprintf('%s%s%s',pdat,G.obs,G.cod)};
G.dat = [];

stype = 'M';
[type_code,type_error,type_name] = textread(strcat(X.RACINE_FICHIERS_CONFIGURATION,'/',X.FISSURO_FILE_TYPE),'%s%n%s','delimiter','|','commentstyle','shell');
serror = {'FP',0.01;'PC',0.02};
scolor = .9*[1 0 0;0 1 0;0 0 1;1 0 1;0 1 1;1 1 0];

% ==== Initialisation des variables
samp = 100;    % pas d'échantillonnage des données (en jour)
last = 100;    % délai d'estimation pour l'état de la station (en jour)
cerr = .9;     % couleur barres d'erreur

sname = G.nom;
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);

% ==== Importation du fichier de données (créé par le formulaire WEB)
f = sprintf('%s/%s',pftp,X.FISSURO_FILE_NAME);
[id,dd,hh,si,op,ta,me,ti,cp, ...
        fp1,fl1,fv1, ...
        fp2,fl2,fv2, ...
        fp3,fl3,fv3, ...
        fp4,fl4,fv4, ...
        fp5,fl5,fv5, ...
        fp6,fl6,fv6, ...
        fp7,fl7,fv7, ...
        fp8,fl8,fv8, ...
        fp9,fl9,fv9, ...
        fp10,fl10,fv10, ...
        fp11,fl11,fv11, ...
        fp12,fl12,fv12, ...
        co] = textread(f,'%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','headerlines',1);
disp(sprintf('Fichier: %s importé.',f))

x = char(dd);
y = char(hh);
z0 = zeros([size(x,1) 1]);
tt = datenum([str2double([cellstr(x(:,1:4)) cellstr(x(:,6:7)) cellstr(x(:,9:10)) cellstr(y(:,1:2)) cellstr(y(:,4:5))]) z0]);
FP = str2double([fp1 fp2 fp3 fp4 fp5 fp6 fp7 fp8 fp9 fp10 fp11 fp12]);
FL = str2double([fl1 fl2 fl3 fl4 fl5 fl6 fl7 fl8 fl9 fl10 fl11 fl12]);
FV = str2double([fv1 fv2 fv3 fv4 fv5 fv6 fv7 fv8 fv9 fv10 fv11 fv12]);

% Remplit la matrice de données avec les mesures suivantes:
%   1. température
%   2-3. moyenne(perpA) & écart-type(perpA)
%   4-5. moyenne(paraA) & écart-type(paraA)
%   6-7. moyenne(vertA) & écart-type(vertA)
%   8-9. moyenne(perpB) & écart-type(perpB)
%   10-11. moyenne(paraB) & écart-type(paraB)
%   12-13. moyenne(vertB) & écart-type(vertB)

% données brutes: une ligne correspond à un site, un temps, et une composante.
% méthode: pour chaque site, sélection d'un temps (date et heure) unique auquel on associe
% la moyenne de toutes les mesures existantes, pour chacune des composantes A et B.
t = [];
d = [];
M.si = [];
M.co = [];
for i = 1:length(ST.cod)
	k = find(strcmp(si,ST.cod(i)));
	if ~isempty(k)
		[t_un,i_un,j_un] = unique(tt(k));	% vecteur temps unique pour le site
		d_un = NaN*zeros(size(t_un,1),13);
		for ii = 1:length(t_un)
			ka = k(find(strcmp(cp(k),'A') & t_un(ii) == tt(k)));
			kb = k(find(strcmp(cp(k),'B') & t_un(ii) == tt(k)));
			d_un(ii,1) = rmean(str2double(ta([ka;kb])));
			if ~isempty(ka)
				fp = FP(ka,:); fl = FL(ka,:); fv = FV(ka,:);
				d_un(ii,2:7) = [rmean(fp(:))',rstd(fp(:))',rmean(fl(:))',rstd(fl(:))',rmean(fv(:))',rstd(fv(:))'];
			end
			if ~isempty(kb)
				fp = FP(kb,:); fl = FL(kb,:); fv = FV(kb,:);
		        	d_un(ii,8:13) = [rmean(fp(:))',rstd(fp(:))',rmean(fl(:))',rstd(fl(:))',rmean(fv(:))',rstd(fv(:))'];
			end
		end
		t = [t;t_un];
		d = [d;d_un];
		M.si = [M.si;si(k(i_un))];
		M.co = [M.co;co(k(i_un))];
	end
end
		
% ==== Traitement des données:
%   1. range les données en ordre chronologique;
%   2. ajuste les erreurs (minimum défini par serror)
%   3. calibre les données (fichier clb)
%   4. exporte un fichier de données par station (avec en-tete EDAS) avec NaN = -1

% Tri par ordre chronologique
[t,k] = sort(t);
d = d(k,:); M.si = M.si(k); M.co = M.co(k);

% Réhausse les erreurs inférieures à serror
%d(:,[3 5 7 9 11 13]) = max(d(:,[3 5 7 9 11 13]),serror{1,2});

so = [];
for i = 1:length(ST.cod)
    k = find(strcmp(M.si,ST.cod(i)));
    if ~isempty(k)
        so = [so i];
        [d(k,:),C(i)] = calib(t(k),d(k,:),ST.clb(i));
        tt = datevec(t(k));
        f = sprintf('%s/%s.DAT',pftp,ST.cod{i});
        fid = fopen(f,'wt');
        fprintf(fid, '# DATE: %s\r\n', datestr(now));
        fprintf(fid, '# TITL: %s: %s %s\r\n',rcode,ST.ali{i},ST.nom{i});
        fprintf(fid, '# SAMP: 0\r\n');
        fprintf(fid, '# OMGR: /g::o1en/2:o3en/4:o5en/6,,:oG /pe\r\n');
        fprintf(fid, '# CHAN: YYYY MM DD HH NN %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s) %s_(%s)\r\n');
        fprintf(fid, '%4d-%02d-%02d %02d:%02d %0.1f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f\r\n', ...
	                     [tt(:,1:5),d(k,:)]');
        fclose(fid);
        disp(sprintf('Fichier: %s créé.',f))
    end
end
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
        k = find(strcmp(M.si,ST.cod(stn)) & t>=G.lim{end}(1) & t<=G.lim{end}(2));
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
          
        kn = find(strcmp(M.si,ST.cod(stn)));
        k = find(strcmp(M.si,ST.cod(stn)) & t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
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
        if ig == 1
            sd = sprintf('%s %0.1f °C, %0.3f ± %0.3f mm, %0.3f ± %0.3f mm, %0.3f ± %0.3f mm, %0.3f ± %0.3f mm, %0.3f ± %0.3f mm, %0.3f ± %0.3f mm',stype,d(kn(end),:));
            mketat(etats(stn),tlast(stn),sd,lower(ST.cod{stn}),G.utc,acquis(stn))
        end
    
        
        % Titre et informations
        figure(1), clf, orient tall

        G.tit = gtitle(stitre,G.ext{ig});
		G.eta = [G.lim{ig}(2),etats(stn),acquis(stn)];
		
        %text(1,.8,sprintf('Acquisition à {\\bf%d %%} sur {\\bf%1.0f jour(s)}',acquis(stn),diff(G(ig).lim)), ...
        %    'HorizontalAlignment','right')
        %text(.9,.1,sprintf('depuis {\\bf%1.0f heure(s)}',last*24), 'HorizontalAlignment','center','FontSize',8)

        if isempty(k), break; end

        kb1 = find(~isnan(d(k,8)));
        kb1 = k(kb1(1));
        G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc), ...
                sprintf('Température = {\\bf%1.1f °C}',d(ke,1)), ...
				' ', ...
                sprintf('Remarque = {\\bf%s}',M.co{ke}), ...
				' ', ...
                sprintf('Serrage {\\bf }'), ...
                sprintf('Jeu Dextre {\\bf }'), ...
                sprintf('Montée Est {\\bf }'), ...
				' ', ...
                sprintf('A = {\\bf%+1.3f \\pm %1.3f mm}',d(ke,2)-d(k(1),2),d(ke,3)), ...
                sprintf('A = {\\bf%+1.3f \\pm %1.3f mm}',d(ke,4)-d(k(1),4),d(ke,5)), ...
                sprintf('A = {\\bf%+1.3f \\pm %1.3f mm}',d(ke,6)-d(k(1),6),d(ke,7)), ...
                sprintf('B = {\\bf%+1.3f \\pm %1.3f mm}',d(ke,8)-d(kb1,8),d(ke,9)), ...
                sprintf('B = {\\bf%+1.3f \\pm %1.3f mm}',d(ke,10)-d(kb1,10),d(ke,11)), ...
                sprintf('B = {\\bf%+1.3f \\pm %1.3f mm}',d(ke,12)-d(kb1,12),d(ke,13)), ...
                };

            
        % Serrage A & B
        subplot(11,1,1:3), extaxes
        dd = d(k,2); ee = d(k,3); ff = d(k(1),2);
        plot([t(k) t(k)]',[dd+ee dd-ee]' - ff,'-','Color',scolor(1,:))
        hold on
        plot(t(k),dd - ff,'.-','LineWidth',.1,'Color',scolor(1,:).^4)
        dd = d(k,8); ee = d(k,9); ff = d(kb1,8);
        plot([t(k) t(k)]',[dd+ee dd-ee]' - ff,'-','Color',scolor(2,:))
        plot(t(k),dd - ff,'.-','LineWidth',.1,'Color',scolor(2,:).^4)
        hold off
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Serrage (mm)')

        % Légende des fissuros
        pos = get(gca,'position');
        axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/10])
        axis([0 1 0 1]), hold on
        plot(.2+[0,.05],.5+[0,0],'.-','LineWidth',.1,'Color',scolor(1,:).^4)
        text(.28,.5,'Ancien Fissuro (A)','FontSize',8)
        plot(.5+[0,.05],.5+[0,0],'.-','LineWidth',.1,'Color',scolor(2,:).^4)
        text(.58,.5,'Nouveau Fissuro (B)','FontSize',8)
        axis off, hold off
            
        % Jeu Dextre A & B
        subplot(11,1,4:6), extaxes
        dd = d(k,4); ee = d(k,5); ff = d(k(1),4);
        plot([t(k) t(k)]',[dd+ee dd-ee]' - ff,'-','Color',scolor(1,:))
        hold on
        plot(t(k),dd - ff,'.-','LineWidth',.1,'Color',scolor(1,:).^4)
        dd = d(k,10); ee = d(k,11); ff = d(kb1,10);
        plot([t(k) t(k)]',[dd+ee dd-ee]' - ff,'-','Color',scolor(2,:))
        plot(t(k),dd - ff,'.-','LineWidth',.1,'Color',scolor(2,:).^4)
        hold off
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Jeu Dextre (mm)')

        % Montée Est A & B
        subplot(11,1,7:9), extaxes
        dd = d(k,6); ee = d(k,7); ff = d(k(1),6);
        plot([t(k) t(k)]',[dd+ee dd-ee]' - ff,'-','Color',scolor(1,:))
        hold on
        plot(t(k),dd - ff,'.-','LineWidth',.1,'Color',scolor(1,:).^4)
        dd = d(k,12); ee = d(k,13); ff = d(kb1,12);
        plot([t(k) t(k)]',[dd+ee dd-ee]' - ff,'-','Color',scolor(2,:))
        plot(t(k),dd - ff,'.-','LineWidth',.1,'Color',scolor(2,:).^4)
        hold off
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Montée Est (mm)')

        % Température
        subplot(11,1,10:11), extaxes
        plot(t(k),d(k,1),'.-','LineWidth',.1)
        set(gca,'XLim',G.lim{ig},'FontSize',8)
        datetick2('x',G.fmt{ig},'keeplimits')
        ylabel('Tair (°C)')

        tlabel(G.lim{ig},G.utc)

        mkgraph(sprintf('%s_%s',lower(ST.cod{stn}),G.ext{ig}),G,OPT)
    end
end
close

if ivg(1) == 1
    mketat(etats(so),max(tlast),sprintf('%s %d stations',stype,nx),rcode,G.utc,acquis(so))
    G.sta = [lower(ST.cod(so))];
    G.ali = [ST.ali(so)];
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)

