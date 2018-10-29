function DOUT=gpscont(mat,tlim,OPT,nograph,dirspec)
%GPSCONT Graphes des données GPS continu.
%       GPSCONT sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       GPSCONT(MAT,TLIM,JCUM,NOGRAPH) effectue les opérations suivantes:
%           MAT = 1 (défaut) utilise la sauvegarde Matlab (+ rapide);
%           MAT = 0 force l'importation de toutes les données anciennes à
%               partir des fichiers FTP et recréé la sauvegarde Matlab.
%           TLIM = DT ou [T1;T2] trace un graphe spécifique ('_xxx') sur 
%               les DT derniers jours, ou entre les dates T1 et T2, au format 
%               vectoriel [YYYY MM DD] ou [YYYY MM DD hh mm ss].
%           TLIM = 'all' trace un graphe de toutes les données ('_all').
%           OPT(1) = format de date (voir DATETICK).
%           OPT(2) = taille des marqueurs.
%           OPT(3) = période de cumul pour les histogrammes (en jour).
%           NOGRAPH = 1 (optionnel) ne trace pas les graphes.
%
%       DOUT = GPSCONT(...) renvoie une structure DOUT contenant toutes les 
%       données des stations concernées i:
%           DOUT(i).code = code station
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - 1 seul fichier ASCII ('base-ENU.L0')
%           - pas de sauvegarde Matlab
%           - utilise le fichier LOG pour déterminer l'état des stations
%             ainsi que de l'acquisition (acqdc).
%
%   Auteurs: F. Beauducel + S. Acounis + J.B. de Chabalier, OVSG-IPGP
%   Création : 2001-06-18
%   Mise à jour : 2005-10-19

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end

rcode = 'GPSCONT';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
G.dsp = dirspec;
ST = readst(G.cod,G.obs);
sali = char(ST.ali);
stype = 'T';

% Initialisation des variables
samp = 8/24;   % pas d'échantillonnage des données (en jour)
last = 12/24;  % délai d'estimation pour l'état de la station (en jour)
fxmin = 98;    % pourcentage minimum d'ambiguités fixées pour le tracé
ermax = .1;    % erreur maximum pour le tracé (en mètre)
st0 = 'HOUE'; % Station de référence
veille = {'ASF','DDU','PDB'};
calib = {'Est (m)','Nord (m)','Vertical (m)'};

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
%pftp = 'H:/GPS';

sname = G.nom;
G.cpr = 'OVSG-IPGP';

% indice de la station de référence et liste des stations en fonctionnement
i0 = find(strcmp(ST.ali,st0));
so = [];
for i = 1:length(ST.ali)
    if ~strcmp(ST.ali(i),veille) & ~strcmp(ST.ali(i),'-') & i ~= i0
        so = [so,i];
    end
end
nx = length(so);

% Importation du fichier LOG
f = sprintf('%s/GPSlog.txt',pftp);
[j,m,y,h,n,s,slog,flog,nlog] = textread(f,'%2d/%2d/%d %2d:%2d:%2d , %s , %d%[^\n]');
disp(sprintf('Fichier: %s importé.',f))
k = find(y<100);
y(k) = y(k) + 2000;
tlog = datenum(y,m,j,h,n,s) + G.utc/24;

% Importation du fichier de données ENU calcul L0
annee = tnow(1);
f = sprintf('%s/base-ENU.L1',pftp);

%   Ne marche pas à cause de la dernière ligne des fichiers (caractère bizarre)...
%   [y,j,e,de,n,dn,u,du] = textread(f,'%f%f%f%f%f%f%f%f%*[^\n]');
ss = textread(f,'%s','delimiter','\n');
for i = 1:length(ss)
    if length(ss{i}) > 10
        [y,j,de,sde,dn,sdn,du,sdu,dd,sdd,fx,am,tx1,tx2,tx3] = strread(ss{i},'%n%n%n%n%n%n%n%n%n%n%s%n%s%s%s%*[^\n]');
        t(i,1) = datenum([y 0 0 0 0 0]) + j;
        ii0 = find(strcmp(ST.ali,tx2));
        if isempty(ii0), ii0 = NaN; end
        ii = find(strcmp(cellstr(sali(:,1:3)),tx3{1}(6:8)));
        if isempty(ii), ii = NaN; end
        d(i,:) = [de,sde,dn,sdn,du,sdu,dd,sdd,am,ii0,ii];
    end
end
disp(sprintf('Fichier: %s importé.',f))

% La matrice de données contient :
%   1 = Composante Est (m)
%   2 = Sigma Est (m)
%   3 = Composante Nord (m)
%   4 = Sigma Nord (m)
%   5 = Composante Verticale (m)
%   6 = Sigma Vertical (m)
%   7 = Distance (m)
%   8 = Sigma Distance (m)
%   9 = Ambiguités Fixées (%)
%  10 = Indice de la station de référence
%  11 = Indice de la station traitée

% Traitement des données:
%   1. range les données en ordre chronologique;
[t,i] = sort(t);
d = d(i,:);

%  2. filtre les données en fonction des ambiguités et de l'erreur max
k = find(d(:,9) < fxmin | d(:,8) > ermax);
%d(k,[2,4,6,8]) = NaN;
d(k,:) = [];
t(k) = [];

%   3. exportation des données
for i = 1:nx
    st = so(i);
    k = find(d(:,11) == st);
    if ~isempty(k)
        tt = datevec(t(k));
        if length(tlim) == 0
        f = sprintf('%s/%s.DAT',pftp,ST.cod{st});
        fid = fopen(f,'wt');
            fprintf(fid, '# DATE: %s\r\n', datestr(now));
            fprintf(fid, '# TITL: %s: %s %s (ref: %s)\r\n',ST.ali{st},sname,ST.nom{st},ST.cod{i0});
            fprintf(fid, '# SAMP: %g\r\n',samp*86400);
            %fprintf(fid, '# OMGR: /g:,:o* /pe\r\n');
            fprintf(fid, '# CHAN: YYYY MM DD Est_(m) dE_(m) Nord_(m) dN_(m) Vert_(m) dU_(m) Dist_(m) dD_(m) Amb_(%%)\r\n');
            fprintf(fid, '%4d-%02d-%02d %02d:%02d:%02.0f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %3.0f\r\n', ...
	                     [tt,d(k,1:9)]');
        fclose(fid);
        disp(sprintf('Fichier: %s créé.',f))
        end
    end
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
    if exist('OPT','var')
        G.fmt{ivg} = OPT.fmt;
        G.mks{ivg} = OPT.mks;
    end
end

% Renvoi des données dans DOUT, sur la période de temps G(end).lim
if nargout > 0
    for st = 1:length(ST.cod)
        k = find(strcmp(lower(slog),ST.ali) & flog > 0 & tlog>=G.lim{ivg(1)}(1) & tlog<=G.lim{ivg(1)}(2));
        DOUT(st).code = ST.cod;
        DOUT(st).time = tlog(k);
        DOUT(st).data = flog(k);
    end
    k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
    DOUT(st+1).code = rcode;
    DOUT(st+1).time = t(k);
    DOUT(st+1).data = d(k,:);
end

if nargin > 3
    if nograph == 1, G = []; end
end

% Etat des stations et de l'acquisition (d'après le fichier LOG)
if ivg(1) == 1
    sox = find(~strcmp(ST.ali,'-'));
    nxx = length(sox);
    etats = zeros(nxx,1);
    acquis = zeros(nxx,1);
    for i = 1:nxx
        st = sox(i);
        k = find(strcmp(slog,ST.ali(st)) & flog > 0);
        if ~isempty(k)
            acquis(i) = 100*length(find(tlog(k)>=G.lim{1}(1) & tlog(k)<=G.lim{1}(2)))*samp/diff(G.lim{1});
            if tlog(k(end)) >= G.lim{1}(2)-last
                etats(i) = 100;
            else
                etats(i) = 0;
            end
            ss = nlog{k(end)};
            if length(ss) > 3, ss = ss(3:end); end
            sd = sprintf('%s',ss);
            tlast = tlog(k(end));
        else
            sd = 'pas de fichier';
            tlast = datenum(tnow);
        end
        mketat(etats(i),tlast,sd,lower(ST.cod{st}),G.utc,acquis(i))
    end
    mketat(etats,tlog(end),sprintf('%s %d %s',stype,nxx,G.snm),rcode,G.utc,acquis)
end

% ===================== Tracé des graphes

for st = 1:nx
    stn = so(st);
    stitre = sprintf('%s: %s %s',ST.ali{stn},sname,ST.nom{stn});
 
    for ig = ivg

        figure(1), clf, orient tall
        k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2) & stn == d(:,11));
        if isempty(k)
            ke = [];
        else
            ke = k(end);
        end

        % Etat de la station
        acqui = 100*length(find(t(k)>=G.lim{ig}(1) & t(k)<=G.lim{ig}(2)))*samp/diff(G.lim{ig});
        if t(ke) >= G.lim{ig}(2)-last
            etat = 100;
        else
            etat = 0;
        end

        % Titre et informations
        if ig == 1
            sd = sprintf('%1.3f m, %1.3f m, %1.3f m, %1.3f m, %1.3f m, %1.3f m, %1.3f m, %1.3f m, %d %%',d(end,:));
            mketat(etat,t(end),sd,lower(ST.cod{stn}),G.utc,acqui)
        end

        G.tit = gtitle(stitre,G.ext{ig});
        G.eta = [G.lim{ig}(2),etat,acqui];

        if ~isempty(k)

            kk = find(~isnan(d(k,2)));
            tk = t(k(kk));
            dk = d(k(kk),[1,3,5,7]);
            dk = dk - repmat(dk(1,:),[size(dk,1),1]);
            % définit l'échelle des ordonnées
            %v = .5*ceil(10*abs(diff(minmax(dk))))/10;
            v = 2*ceil(10*max(std(dk) + .01))/10;

            % Calcul régression linéaire
            dtk = (tk - tk(1))/365;
            ddk = dk*1000;
            drle = polyfit(dtk,ddk(:,1),1);
            drln = polyfit(dtk,ddk(:,2),1);
            drlu = polyfit(dtk,ddk(:,3),1);
            drld = polyfit(dtk,ddk(:,4),1);
    
            % Zone d'informations
            G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(round(t(ke)*288)/288),G.utc), ...
				sprintf('Calcul {\\bfGGPS L1}'), ...
                sprintf('Ambiguités fixées = {\\bf%d %%}',d(ke,9)), ...
                sprintf('Référence: {\\bf%s}',ST.ali{i0}), ...
                sprintf('dE = {\\bf%+1.3f \\pm %1.3f m}',d(ke,1)-d(k(1),1),d(ke,2)), ...
                sprintf('dN = {\\bf%+1.3f \\pm %1.3f m}',d(ke,3)-d(k(1),3),d(ke,4)), ...
                sprintf('dU = {\\bf%+1.3f \\pm %1.3f m}',d(ke,5)-d(k(1),5),d(ke,6)), ...
                sprintf('dL = {\\bf%1.3f \\pm %1.3f m}',d(ke,7)-d(k(1),7),d(ke,8)), ...
                sprintf('dE(0) + \\delta = %1.3f m {\\bf%+1.1f mm/an}',d(k(1),1),drle(1)), ...
                sprintf('dN(0) + \\delta = %1.3f m {\\bf%+1.1f mm/an}',d(k(1),3),drln(1)), ...
                sprintf('dU(0) + \\delta = %1.3f m {\\bf%+1.1f mm/an}',d(k(1),5),drlu(1)), ...
                sprintf('dL(0) + \\delta = %1.3f m {\\bf%+1.1f mm/an}',d(k(1),7),drld(1)), ...
            };
    
            % Composantes E(t), N(t) et U(t)
            for i = 1:3
                ii = 2*(i-1) + 1;
                subplot(3,1,i), extaxes
                plot([t(k) t(k)]',[d(k,ii)+d(k,ii+1) d(k,ii)-d(k,ii+1)]'-d(k(1),ii),'-g','LineWidth',.1), hold on
                plot(t(k),d(k,ii)-d(k(1),ii),'.r','MarkerSize',G.mks{ig})
				plot(t(k),mavr(d(k,ii)-d(k(1),ii),30),'-b','linewidth',2)
                plot(t(ke),d(ke,ii)-d(k(1),ii),'db'), hold off
                axis([G.lim{ig} -v v]);
                set(gca,'FontSize',8)
                datetick('x',G.fmt{ig},'keeplimits')
                ylabel(calib{i})
            end

            % Composante D(t)
            %subplot(5,1,5), extaxes
            %plot([t(k) t(k)]',[d(k,7)+d(k,8) d(k,7)-d(k,8)]'-d(k(1),7),'-g','LineWidth',.1), hold on
            %plot(t(k),d(k,7)-d(k(1),7),'.r','MarkerSize',G.mks{ig})
            %plot(t(ke),d(ke,7)-d(k(1),7),'db'), hold off
            %axis([G.lim{ig} -v v]);
            %set(gca,'FontSize',8)
            %datetick('x',G.fmt{ig},'keeplimits')
            %ylabel('Distance (m)')
            %tlabel(G.lim{ig},G.utc)

            % Graphes XY: N(E), U(E) et U(N)
            %i1 = [1,1,3];
            %i2 = [3,5,5];
            %for i = 1:3
            %    subplot(5,3,9 + i)
            %    ellipse(d(k,i1(i))-d(k(1),i1(i)),d(k,i2(i))-d(k(1),i2(i)),d(k,i1(i)+1),d(k,i2(i)+1),1,'-g'), hold on
            %    plot(d(k,i1(i))-d(k(1),i1(i)),d(k,i2(i))-d(k(1),i2(i)),'.r','MarkerSize',G.mks{ig})
            %    plot(d(ke,i1(i))-d(k(1),i1(i)),d(ke,i2(i))-d(k(1),i2(i)),'db'), hold off, axis auto
            %    pos = get(gca,'Position');
            %    set(gca,'Position',[pos(1),pos(2)-.02,pos(3),pos(4)*1.5]);
            %    axis equal
            %    set(gca,'FontSize',8,'YLim',[-v v]);
            %    xlabel(calib{(i1(i)-1)/2 +1})
            %    ylabel(calib{(i2(i)-1)/2 +1})
            %end
		else
            G.inf = {''};
        end
        
        mkgraph(sprintf('%s_%s',lower(ST.cod{stn}),G.ext{ig}),G)
    end
end
close

if ivg(1) == 1
    G.sta = [lower(ST.cod(so))];
    G.ali = [ST.ali(so)];
    G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
    htmgraph(G);
end

timelog(rcode,2)
