function meteo_sanner(mat,tlim,OPT,nograph,dirspec)
%METEO_SANNER graphes spécifiques pour externes.
%       METEO sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       METEO(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%   Auteur: F. Beauducel + J.B. de Chabalier, OVSG-IPGP
%   Création : 2010-07-12
%   Modifié : 2010-10-04

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end
if nargout > 0, nograph = 1; end

rcode = 'METEO_SANNER';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);

G.dsp = dirspec;

% Initialisation des variables
samp = 1/144;   % pas d'échantillonnage des données (en jour)
last = 2/24;    % délai d'estimation pour l'état de la station (en jour)
s_ap = str2double(X.PLUIE_ALERTE_SEUIL);	% seuil de quantitié de pluie (mm)
i_ap = str2double(X.PLUIE_ALERTE_INTERVAL);	% interval temporel du seuil (jour)
j_ap = str2double(X.PLUIE_ALERTE_DELAI);	% délai (jour)
txt_attention = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.PLUIE_ALERTE_ATTENTION),'%s','delimiter','\n','whitespace','');
color_alert_none = [0,.9,0];
color_alert_triggering = [1,0,0];
color_alert_running = [1,.3,.3];

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
pmeteo = sprintf('%s/%s',X.RACINE_WEB,G.don);
dt_data = 10;		% nombre de jours de donnÃ©es exportÃ©es en fichier
ftxt = 'meteosanner.txt';

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
    G.lim{ivg}(1) = datenum(2000,1,1);
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

% importe les données de Sanner sur la plus longue période.
METEO = meteo(1,datevec([G.lim{ivg(end)}(1)-i_ap-j_ap;G.lim{ivg(end)}(2)]));
%METEO = meteo(1,[2000,1,1,0,0,0;datevec(G.lim{2}(2))]);

ST = readst(METEO(2).code);
t = METEO(2).time;
d = METEO(2).data;
chan = METEO(2).chan;
unit = METEO(2).unit;
nx = length(chan);

%stitre = sprintf('%s : %s',ST.ali{:},ST.nom{:});
stitre = 'Météorologie Soufrière - Piton Sanner';

% ===========================================================================
% Traitement de l'alerte forte pluie (coll. BRGM)
% seulement si appel de la fonction sans option (temps réel)
% => calcul de la pluie cumulée sur 24h : si >= 50 mm, danger d'instabilité de terrain pendant 3 jours.

% *****************
% ** test alerte **
%d(end,9) = s_ap+1;
%d(end,9) = 51;
% *****************

if isempty(tlim)
	% lecture du corps de message
	f_msg = sprintf('%s.msg',X.PLUIE_ALERTE_TMP);
	msg = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.PLUIE_ALERTE_NOTES),'%s','delimiter','\n','whitespace','');

	k = find(t >= datenum(tnow)-j_ap-i_ap);	% indice des dernières données (j_ap+i_ap derniers jours)
	d_ap = d(k,9);				% données pluie diurne continue (9ème colonne de données calculée par la fonction meteo
	k_ap = find(d_ap >= s_ap);		% indice des données dépassant le seuil

	if ~isempty(k_ap) & (t(k(k_ap(end)))+j_ap) > datenum(tnow)
		% -- cas où le seuil est dépassé...
		t_ap = t(k(k_ap([1,end])));	% t_ap(1) = date du premier déclenchement, t_ap(2) = date du dernier déclenchement
		m_ap = d_ap([k_ap(end),end]);	% m_ap(1) = valeur du dernier déclenchement, m_ap(2) = dernière valeur (en mm/j)
	else
		if ~isempty(k)
			t_ap = t(k([1,1]))-1;
		else
			t_ap = [0,0];
		end
		m_ap = [0,0];
	end

	if exist(X.PLUIE_ALERTE_TMP,'file')
		% -- si un fichier TMP est présent (= alerte en cours)
		n_ap = load(X.PLUIE_ALERTE_TMP);
		if (t_ap(2)+j_ap) <= datenum(tnow)
			% -- j_ap jours ont passé depuis le dernier déclenchement = levée d'alerte
			alerte(sprintf('LEVÉE ALERTE PLUIE SOUFRIÈRE'),X.PLUIE_ALERTE_EMAIL);
			delete(X.PLUIE_ALERTE_TMP);
			m_ap = [0,0];
		else
			% -- alerte en cours: on met à jour le fichier TMP
			save(X.PLUIE_ALERTE_TMP,'m_ap','-ascii','-double');
			disp(sprintf('*** ALERTE PLUIE EN COURS... %s = %g mm - %s = %g mm en %g j',datestr(t_ap(2)),m_ap(1),datestr(t(end)),m_ap(2),i_ap));
		end
	else
		n_ap = [0,0];
	end
	%if (~isempty(k_ap) & ((m_ap(1) > n_ap(1) & m_ap(1) > s_ap) | ~exist(X.PLUIE_ALERTE_TMP,'file')))
	if (~isempty(k_ap) & (t_ap(2)+j_ap) > datenum(tnow)  & (~exist(X.PLUIE_ALERTE_TMP,'file') | (m_ap(2) < s_ap & n_ap(2) >= s_ap) | (m_ap(2) >= s_ap & n_ap(2) < s_ap)))
		% -- conditions requises pour l'envoi d'un email d'alerte:
		%	+ k_ap non vide = seuil dépassé sur les derniers jours && l'une des 3 conditions:
		%	+ soit pas de fichier TMP = début d'alerte
		%	+ soit dernière valeur < seuil && valeur dans TMP >= seuil = fin de la phase de déclenchement
		%	+ soit dernière valeur >= seuil && valeur dans TMP < seuil = nouvelle phase de déclenchement
		pmax = max(d_ap); kmax = find(d_ap==pmax); tmax = t(k(kmax(end)));
		fid = fopen(f_msg,'wt');
		fprintf(fid,'%s\n',msg{1});
		fprintf(fid,'       Début d''alerte: %s (%s)\n',datestr(t_ap(1)),traduc(datestr(t_ap(1),'ddd')));
		fprintf(fid,'   Pluviosité maximum: %s = %g mm en %g j\n',datestr(tmax),pmax,i_ap);
		fprintf(fid,'Dernier déclenchement: %s = %g mm en %g j\n',datestr(t_ap(2)),m_ap(1),i_ap);
		fprintf(fid,'  Fin d''alerte prévue: %s (%s)\n',datestr(t_ap(2) + j_ap),traduc(datestr(t_ap(2) + j_ap,'ddd')));
		fprintf(fid,'%s\n',msg{2:end});
		fclose(fid);
		save(X.PLUIE_ALERTE_TMP,'m_ap','-ascii','-double');
		%alerte(sprintf('ALERTE PLUIE SOUFRIÈRE: %s = %g mm en %g j',datestr(t_ap(2)),m_ap(1),i_ap),X.PLUIE_ALERTE_EMAIL,f_msg);
		alerte(sprintf('ALERTE PLUIE SOUFRIÈRE: %s = %g mm en %g j',datestr(tmax),pmax,i_ap),X.PLUIE_ALERTE_EMAIL,f_msg);
	end

	% ===========================================================================

	f = sprintf('%s/%s',pmeteo,ftxt);
	% Sélection des données des dt_data derniers jours
	k = find(t >= datenum(tnow)-dt_data);
	tt = datevec(t(k));
	fid = fopen(f,'wt');
	fprintf(fid, '# DATE: %s\n', datestr(now));
	fprintf(fid, '# TITL: %s\n',stitre);
	fprintf(fid, '# CHAN: YYYY-MM-DD HH:NN');
	fmt = '%4d-%02d-%02d %02d:%02d';
	inx = [6,10,11,4,5];
	for i = inx
		fprintf(fid, ' %s_(%s)',chan{i},unit{i});
		fmt = [fmt ' %0.2f'];
	end
	fprintf(fid,'\n');
	fmt = [fmt '\n'];
	fprintf(fid,fmt,[tt(:,1:5),d(k,inx)]');
	fclose(fid);
	disp(sprintf('File: %s created.',f))
	clear tt

end



% ===================== Tracé des graphes

for ig = ivg

	figure, orient tall

	k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
	if isempty(k)
		ke = [];
		tke = 'pas de donnée';
	else
		ke = k(end);
		tke = sprintf('le %s à %s',datestr(t(ke),24),datestr(t(ke),15));
	end

	% Etat de la station
	acqui = round(100*length(find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2)))*samp/diff(G.lim{ig}));
	if t(ke) >= (G.lim{ig}(2)-last)
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
	G.inf = {''};

	% Infos Alerte Pluie
	h = subplot(6,1,1); extaxes
	axis off, axis([0,1,0,1])
	ph = get(h,'position');
	set(h,'Position',[ph(1),ph(2)-.01,ph(3),ph(4)+.01]);
	txt = sprintf('{\\bf%s}\n Critères d''alerte :\n - seuil = {\\bf%g mm}\n - intervalle = {\\bf%g jour(s)}\n - délai = {\\bf%d jour(s)}',X.PLUIE_ALERTE_NOM,s_ap,i_ap,j_ap);
	txt_alerte = '';
	if isempty(tlim)
		if m_ap(1)==0
			msg = 'PAS D''ALERTE';
			cap = color_alert_none;
		else
			if m_ap(2) > s_ap
				msg = 'DÉCLENCHEMENT ALERTE';
				cap = color_alert_triggering;
			else
				msg = 'ALERTE EN COURS';
				cap = color_alert_running;
			end
			txt_alerte = sprintf('Dernier déclenchement le : {\\bf%s = %g mm en %g j} \n Fin d''alerte prévue le : {\\bf%s}',datestr(t_ap(2)),m_ap(1),i_ap,datestr(t_ap(2) + j_ap));
		end
		text(.25+.75/2,1,msg,'Color',cap,'VerticalAlignment','top','HorizontalAlignment','center','FontWeight','bold','FontSize',14)
		text(.25+.75/2,.8,txt_alerte,'VerticalAlignment','top','HorizontalAlignment','center','FontSize',9)
	end
	text(0,.5,txt,'VerticalAlignment','middle','FontSize',9)
	h = rectangle('Position',[.26,0,.73,.45],'Curvature',[.01,.01],'EdgeColor',[0,0,0],'FaceColor',.7*[1,1,1],'LineWidth',2);
	h = text(.625,.225,txt_attention,'VerticalAlignment','middle','HorizontalAlignment','center','Color',[0,0,0], ...
		'FontWeight','bold','FontSize',9);
	
        % Pluie (journalière / horaire)
        subplot(6,1,2:3), extaxes
        g = 6;
        switch G.cum{ig}
		case 1
       		hcum = 'journalière';
		gp = 11;
        	case 30
		hcum = 'mensuelle';
		gp = 12;
		otherwise
        	hcum = 'horaire';
		gp = 10;
        end
	if ~isempty(k)
		[ax,h1,h2] = plotyy(t(k),d(k,gp),t(k),rcumsum(d(k,g)),'area','plot');
		colormap([0,1,1;0,1,1]), grid on
		ylim = get(ax(1),'YLim');
		set(ax(1),'XLim',G.lim{ig},'FontSize',8)
		if G.cum{ig} == 1
			hold on
			plot(G.lim{ig},repmat(s_ap,[1,2]),'r--','LineWidth',2)
			hold off
		end
		ylim = get(ax(2),'YLim');
		datetick2('x',G.fmt{ig},'keeplimits')
		ylabel(sprintf('%s %s (%s)',chan{g},hcum,unit{g}))
		set(ax(2),'XLim',G.lim{ig},'FontSize',8,'XTick',[])
		set(h2,'LineWidth',2)
	
		% -- tracé des fonds "alerte pluie" (calculé sur toutes les données...)
		d(1,9) = 0;	% impose la première donnée à 0 (si elle est au dessus du seuil, ça complique...)
		vp = [diff(d(:,9)>=s_ap);-1];
		kp0 = find(vp==1);
		kp1 = find(vp==-1);
		if ~isempty(kp0)
			ylim = get(gca,'YLim');
			hold on
			for i = 1:length(kp0)
				if t(kp0(i)) >= G.lim{ig}(1) | t(kp1(i)) <= G.lim{ig}(2)
					h = fill3([t(kp0(i))*[1,1],t(kp1(i))*[1,1]],ylim([1,2,2,1]),-1*[1,1,1,1],[1,.3,.3]);
					set(h,'EdgeColor','none');
					h = fill3([t(kp1(i))*[1,1],(t(kp1(i))+j_ap)*[1,1]],ylim([1,2,2,1]),-1*[1,1,1,1],[1,.6,.6]);
					set(h,'EdgeColor','none');
				end
			end
			hold off
		end
		axes(ax(2))
		ylabel('Pluie cumulée (mm)')
		save fb

        % Vent temporel
        ic = [5,4];
        for ii = 1:length(ic)
            g = ic(ii);
            subplot(6,1,3+ii), extaxes
            plot(t(k),d(k,g),'.','MarkerSize',G.mks{ig})
            set(gca,'XLim',G.lim{ig},'FontSize',8), grid on
            datetick2('x',G.fmt{ig},'keeplimits')
            ylabel(sprintf('%s (%s)',chan{g},unit{g}))
            if length(find(~isnan(d(k,g))))==0, nodata(G.lim{ig}), end
        end

        tlabel(G.lim{ig},G.utc)

        % Rose des vents (histogramme des directions)
        h = subplot(6,4,21);
        ph = get(h,'position');
        %set(h,'position',[ph(1)+.04,ph(2)-.04,ph(3)+.04,ph(4)+.04])
        set(h,'position',[ph(1)-.1,ph(2)-.12,ph(3)+.1,ph(4)+.1])
        sa = 10;    % pas de l'histogramme (en degré)
        [th,rh] = rose(pi/2-d(k,4)*pi/180,360/sa);
        rosace(th,100*rh/length(k),'-')
        set(gca,'FontSize',8), grid on
        h = title('Rose des Vents');
        pt = get(h,'position');
        set(h,'position',[pt(1) pt(2)*1.3 pt(3)])

        % Vent (vitesse / direction)
        h = subplot(6,4,22);
        ph = get(h,'position');
        set(h,'position',[ph(1)-.05,ph(2)-.12,ph(3)+.1,ph(4)+.1])
        rosace(pi/2-d(k,4)*pi/180,d(k,5),'.',G.mks{ig})
        [xe,ye] = pol2cart(pi/2-d(k(end),4)*pi/180,d(k(end),5));
        hold on, plot(xe,ye,'om','LineWidth',2), hold off
        set(gca,'FontSize',8), grid on
        h = title(sprintf('Vitesse du Vent (max = {\\bf%1.1f %s})',max(d(k,5)),unit{5}));
        pt = get(h,'position');
        set(h,'position',[pt(1) pt(2)*1.3 pt(3)])

	% infos statistiques
	h = subplot(6,2,12);
	set(h,'XLim',[0,1],'YLim',[0,1]);
	axis off
	pmaxh = max(d(k,10)); kmaxh = find(d(k,10)==pmaxh); tmaxh = t(k(kmaxh(end)));
	pmaxj = max(d(k,11)); kmaxj = find(d(k,11)==pmaxj); tmaxj = t(k(kmaxj(end)));
	txt = { sprintf('Dernière mesure reçue:\n    {\\bf%s} (UTC%+d)\n',tke,G.utc), ...
		sprintf('Données statistiques:'), ...
		sprintf(' -  Pluie cumulée = {\\bf%1.1f %s}',sum(d(k,6)),unit{6}), ...
		sprintf(' -  Pluie maximale horaire = {\\bf%1.1f %s}\n    (le %s à %s)',pmaxh,unit{10},datestr(tmaxh,24),datestr(tmaxh,15)), ...
		sprintf(' -  Pluie maximale diurne = {\\bf%1.1f %s}\n    (le %s à %s)',pmaxj,unit{11},datestr(tmaxj,24),datestr(tmaxj,15)), ...
		sprintf(' -  Vitesse maximale du vent = {\\bf%1.1f %s}',max(d(k,5)),unit{5}), ...
		sprintf(' -  Vitesse moyenne du vent = {\\bf%1.1f %s}',rmean(d(k,5)),unit{5}), ...
		sprintf(' -  Direction moyenne du vent = {\\bf%s}',boussole((90-rmean(d(k,4)))*pi/180)), ...
		};
	text(0,.7,txt,'HorizontalAlignment','left','VerticalAlignment','top','FontSize',9);
	end
    
    f = sprintf('%s_%s',lower(rcode),G.ext{ig});
    OPT.eps = -1;
    mkgraph(f,G,OPT)
    if isempty(tlim)
	    unix(sprintf('cp -f %s/%s/%s.* %s/.',X.RACINE_WEB,X.MKGRAPH_PATH_WEB,f,pmeteo));
	    unix(sprintf('cp -f %s/%s.ps %s/.',X.MATLAB_PATH_IMAGES,f,pmeteo));
    end
    close

end

timelog(rcode,2)
