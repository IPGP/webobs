function DOUT=tides(mat,tlim,OPT,nograph,dirspec)
%TIDES  Tracé des graphes du réseau de marégraphes.
%       TIDES sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       TIDES(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = TIDES(...) renvoie une structure DOUT contenant toutes les 
%       données des stations i :
%           DOUT(i).code = code station
%           DOUT(i).time = vecteur temps
%           DOUT(i).data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement (SOUY0):
%           - fichiers plus ou moins mensuels placés manuellement (*.txt)
%           - les données sont en heure TU
%           - fichier de calibration (.CLB) pour la conversion en valeurs 
%             physiques et le filtrage des données suivant des bornes
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2007-01-08
%   Mise à jour : 2011-01-29

%	Historique des mises à jour:
%	[FB] 2011-01-29: exportation d'un fichier ASCII sur requête uniquement.

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end
if nargout > 0, nograph = 1; end

rcode = 'TIDES';
timelog(rcode,1);

% Initialisation des variables
G = readgr(rcode);
tnow = datevec(G.now);

G.dsp = dirspec;
ST = readst(G.cod,G.obs);
ist = [find(~strcmp(ST.dat,'-'))];
aliases = [];

samp = 15/86400;	% pas d'échantillonnage des données (en jour)
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
fw1 = .004;
fw2 = .07;
fno = 2;
%[ft_b,ft_a] = cheby1(fno,3,[fw1,fw2]);		% Filtre passe-bande (nécessite la boîte à outils SIGNAL)
ft_b = [0.00504819241358,0,-0.01009638482717,0,0.00504819241358];
ft_a = [1.00000000000000 ,-3.84128119687287,5.55805294170394,-3.59190176682855,0.87513717556084];
od = .05;	% offset pour présentation données filtrées (en mètre)

for n = 1:length(ist)

	st = ist(n);
	scode = ST.cod{st};
	alias = ST.ali{st};
	sname = ST.nom{st};
	stitre = sprintf('%s',sname);
	stype = 'A';

	% FIXME AB : Les marégraphes radar ne sont pas encore gérés par ce script !
% 	isodatenum(ST.ins{st})
% 	isodatenum('2010-01-01')
	if isodatenum(ST.ins{st})>isodatenum('2010-01-01')
		disp(sprintf('*** Warning: Station non gérée : %s !',alias));
		continue
	end

	t = [];
	d = [];

	% Test: chargement si la sauvegarde Matlab existe
	f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,lower(scode));
	if mat & exist(f_save,'file')
		load(f_save,'t','d');
		disp(sprintf('Fichier: %s importé.',f_save))
		tdeb = datevec(t(end)-samp);
	else
		disp('Pas de sauvegarde Matlab. Chargement de toutes les données...');
		tdeb = [2006,12,12];
	end

	% Chargement des fichiers (SSSYYYYMMDD*.txt)
	flag = 0;
	for annee = tdeb(1):tnow(1)
		p = sprintf('%s/%4d',pftp,annee);
		if exist(p,'dir')
			l = dir(sprintf('%s/%s*.txt',p,ST.dat{st}));
			for i = 1:length(l)
				li = l(i).name;
				tf = datenum(str2double({li(4:7),li(8:9),li(10:11)}));
				if tf >= datenum(tdeb)
					f = sprintf('%s/%s',p,l(i).name);
					[mm,dd,yy,hh,nn,ss,d1,d2] = textread(f,'%n-%n-%n%n:%n:%n,%n,%n%*[^\n]','headerlines',4);
					disp(sprintf('Fichier: %s importé.',f));
					tt = datenum(yy,mm,dd,hh,nn,ss);
					if isempty(t) | tt(end) > t(end)
					    t = [t;tt];
					    d = [d;[d1,d2]];
					    flag = 1;
					else
					    disp('*** Warning: pas de données nouvelles... données non importées.');
                    end
				end
			end
		end
	end
        % Sauvegarde Matlab des données "anciennes"
        if flag
		save(f_save);
                disp(sprintf('Fichier: %s créé.',f_save))
        end


	% Nettoyage, calibration et filtres
	%k = find(t<datenum(2006,12,1) | t>datenum(tnow));
	%t(k) = [];  d(k,:) = [];
	%[t,i] = sort(t);
	%d = d(i,:);
	%k = find(diff(t)==0);
	%t(k) = [];
	%d(k,:) = [];
	nx = ST.clb(st).nx;
	if nx == 0
		disp(sprintf('*** Warning: no calibration file for station %s !',alias));
	end
	[d,C] = calib(t,d,ST.clb(st));
	so = 1:nx;


	% Stockage dans autres variables pour graphe de synthèse
	eval(sprintf('d_%d=d;t_%d=t;',n,n));
	
	tlast(st) = t(end);

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
		if ~nograph
			f = sprintf('%s/%s/%s_xxx.txt',X.RACINE_WEB,dirspec,scode);
			k = find(t>=G.lim{ivg}(1) & t<=G.lim{ivg}(2));
			tt = datevec(t(k));
			fid = fopen(f,'wt');
				fprintf(fid, '# DATE: %s\r\n', datestr(now));
				fprintf(fid, '# TITL: Marégraphe OVSG-IPGP - %s\r\n',stitre);
				fprintf(fid, '# SAMP: %d\r\n',round(samp*60*60*24));
				fprintf(fid, '# CHAN: YYYY MM DD HH NN SS');
				fmt = '%4d-%02d-%02d %02d:%02d:%02.0f';
				for i = 1:nx
					fprintf(fid, ' %s_(%s)',C.nm{i},C.un{i});
					fmt = [fmt ' %0.3f'];
				end
				fprintf(fid,'\r\n');
				fmt = [fmt '\r\n'];
				fprintf(fid,fmt,[tt(:,1:6),d(k,:)]');
			fclose(fid);
			disp(sprintf('Fichier: %s créé.',f))
			clear tt
		end
	end

	% Renvoi des données dans DOUT, sur la période de temps G.lim(end)
	if nargout > 0
		k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
		DOUT(1).code = scode;
		DOUT(1).time = t(k);
		DOUT(1).data = d(k,:);
		DOUT(1).chan = C.nm;
		DOUT(1).unit = C.un;
	end

	% Si nograph==1, quitte la routine sans production de graphes
	if nograph == 1, ivg = []; end


	% ===================== Tracé des graphes

	for ig = ivg

		figure, clf, orient tall
		k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
		if isempty(k)
			ke = [];
		else
			ke = k(end);
		end

		% Etat de la station
                kacq = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
                if isempty(kacq)
			acqui = 0;
		else
			acqui = round(100*length(kacq)*samp/abs(t(kacq(end))-G.lim{ig}(1)));
		end
		if t(ke) >= G.lim{ig}(2)-G.lst
			etat = 0;
			for i = 1:nx
				if ~isnan(d(ke,i))
					etat = etat+1;
				end
			end
			etat = 100*etat/nx;
		else
			etat = 0;
		end
    

		% Titre et informations
		G.tit = gtitle(stitre,G.ext{ig});
		G.eta = [G.lim{ig}(2),etat,acqui];
		etats(st) = etat;
		acquis(st) = acqui;
		if ig == 1 | strcmp(tlim,'all')
			if ig == 1
				sd = '';
				for i = 1:nx
					sd = [sd sprintf(', %1.1f %s', d(end,i),C.un{i})];
				end
				mketat(etat,tlast(st),sd(3:end),lower(scode),G.utc,acqui)
			end
		end

		if ~isempty(k)
			G.inf = {sprintf('Dernière mesure: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc),'(min|moy|max)', ...
				sprintf('1. %s = {\\bf%1.2f %s} (%1.2f | %1.2f | %1.2f)',C.nm{1},d(ke,1),C.un{1},rmin(d(k,1)),rmean(d(k,1)),rmax(d(k,1))) ...
				sprintf('2. %s = {\\bf%1.1f %s} (%1.1f | %1.1f | %1.1f)',C.nm{2},d(ke,2),C.un{2},rmin(d(k,2)),rmean(d(k,2)),rmax(d(k,2))), ...
			};
		end
		
		% pression brute profondeur
		subplot(10,1,1:2), extaxes
		plot(t(k),d(k,1),'.','MarkerSize',G.mks{ig})
		set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
		datetick2('x',G.fmt{ig},'keeplimits')
		ylabel(sprintf('%s (%s)',C.nm{1},C.un{1}))
		if length(find(~isnan(d(k,1))))==0, nodata(G.lim{ig}), end

		% pression atmosphérique
		subplot(10,1,3:4), extaxes
		plot(t(k),d(k,2),'.g','MarkerSize',G.mks{ig})
		set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
		datetick2('x',G.fmt{ig},'keeplimits')
		ylabel(sprintf('%s (%s)',C.nm{2},C.un{2}))
		if length(find(~isnan(d(k,2))))==0, nodata(G.lim{ig}), end
		
		% profondeur corrigée
		subplot(10,1,5:7), extaxes
		plot(t(k),d(k,1)-(d(k,2)-mean(d(k,2)))/1000,'.r','MarkerSize',G.mks{ig})
		set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
		datetick2('x',G.fmt{ig},'keeplimits')
		ylabel(sprintf('%s corrigée (%s)',C.nm{1},C.un{1}))
		if length(find(~isnan(d(k,1))))==0, nodata(G.lim{ig}), end

		% profondeur corrigée + filtrée
		subplot(10,1,8:10), extaxes
		if ~isempty(k)
			plot(t(k),filter(ft_b,ft_a,rf(d(k,1)-(d(k,2)-mean(d(k,2)))/1000)),'.m','MarkerSize',G.mks{ig})
		end
		%plot(t(k),d(k,1)-(d(k,2)-mean(d(k,2)))/1000,'.m','MarkerSize',G.mks{ig})
		set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
		datetick2('x',G.fmt{ig},'keeplimits')
		ylabel(sprintf('%s corrigée et filtrée (%s)',C.nm{1},C.un{1}))
		if length(find(~isnan(d(k,1))))==0, nodata(G.lim{ig}), end


		tlabel(G.lim{ig},G.utc)
    
		mkgraph(sprintf('%s_%s',lower(scode),G.ext{ig}),G,OPT)
		close
	end
    
end


% ====================================================================================================
% Graphe de synthèse réseau

stitre = sprintf('Réseau %s',G.nom);
etat = mean(etats);
acqui = mean(acquis);

for ig = ivg

	figure, clf, orient tall

	G.tit = gtitle(stitre,G.ext{ig});
	G.eta = [G.lim{ig}(2),etat,acqui];
	G.inf = {''};
	
	% pression brute profondeur
	subplot(4,1,1:2), extaxes
	hold on
	aliases = [];
	for n = 1:length(ist)
		% FIXME Stations radar non gérées
		if isodatenum(ST.ins{ist(n)})>isodatenum('2010-01-01') , continue , end
		eval(sprintf('d=d_%d;t=t_%d;',n,n));
		k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
		if ~isempty(k)
			plot(t(k),d(k,1),'-','Color',scolor(n),'LineWidth',.1)
			aliases = [aliases,ST.ali(ist(n))];
		end
	end
	hold off
	set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
	box on
	datetick2('x',G.fmt{ig},'keeplimits')
	ylabel(sprintf('Profondeurs brutes (%s)',C.un{1}))
	if ~isempty(aliases)
		legend(aliases,2)
	end

	% profondeurs filtrées
	subplot(4,1,3:4), extaxes
	hold on
	aliases = [];
	for n = 1:length(ist)
		% FIXME Stations radar non gérées
		if isodatenum(ST.ins{ist(n)})>isodatenum('2010-01-01') , continue , end
		eval(sprintf('d=d_%d;t=t_%d;',n,n));
		k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
		if ~isempty(k)
			plot(t(k),filter(ft_b,ft_a,rf(d(k,1)-(d(k,2)-mean(d(k,2)))/1000))+od*(n-1),'-','Color',scolor(n),'LineWidth',.1)
			aliases = [aliases,ST.ali(ist(n))];
		end
	end
	hold off
	set(gca,'XLim',[G.lim{ig}(1) G.lim{ig}(2)],'FontSize',8)
	box on
	datetick2('x',G.fmt{ig},'keeplimits')
	ylabel(sprintf('Profondeurs filtrées (%s)',C.un{1}))
	if ~isempty(aliases)
		legend(aliases,2)
	end
	title(sprintf('Filtre passe-bande ordre %d [%1.0f - %1.0f s]',fno,86400*samp/(2*fw1),86400*samp/(2*fw2)));

	tlabel(G.lim{ig},G.utc)
    
	mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
	close

end

if isempty(tlim)
	mketat(etat,max(tlast),sprintf('%s %d stations',stype,length(etats)),rcode,G.utc,acqui)
	G.sta = [{rcode};lower(ST.cod(ist))];
	G.ali = [{rcode};ST.ali(ist)];
	G.ext = G.ext(1:end-1); % graphes: tous sauf 'xxx'
	htmgraph(G);
end

timelog(rcode,2)
