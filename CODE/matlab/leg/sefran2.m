function sefran2(mat,dgh,pub)
%SEFRAN2 Graphes de la sismicité continue EarthWorm OVSG.
%
%       SEFRAN2 construit le Sefram Numérique à partir des dernières données de 
%       sismologie continue (gwa), par création d'une image PNG par
%       fichier de données, mises en forme sous une page HTML.
%
%       SEFRAN2(MAT,NBH,PUB) effectue:
%		- MAT = sans effet
%		- NBH= nombre d'heures à traiter (défaut = variable SEFRAN2_UPDATE_HEURES)
%		- PUB = 1 produit également la dernière heure pour le site public.
%
%   Auteurs: F. Beauducel, A. Bosson, OVSG-IPGP
%   Création : 2004-01-21 (sefran.m), 2008-11-11
%   Mise à jour : 2011-01-06

temps = now;
X = readconf('/ipgp/webobs/CONFIG/WEBOBS.conf');
disp(sprintf('@ Temps écoulé : %.2fs',(now-temps)*86400));

if nargin < 1, mat = 1; end
if nargin < 2, dgh = str2num(X.SEFRAN2_UPDATE_HEURES); end
if nargin < 3, pub = 0; end

debut=now;

rcode = 'SEFRAN2';
stype = 'T';
timelog(rcode,1)

tnow = datevec(now - str2double(X.MATLAB_SERVER_UTC)/24);

% Initialisation des variables
gris1 = .8*[1,1,1];                         % couleur gris clair
gris2 = .5*[1,1,1];                         % couleur gris foncé
bggux = [1,.8,.5];                          % couleur de fond pour les GUX
bgnir = [.5,1,1];                           % couleur de fond pour sans IRIG

tlim = datenum(tnow) + [-dgh/24,0];			% date du début de la mise à jour
fhz = str2num(X.SEFRAN2_VALUE_SAMPLING);         % fr?quence d'?chantillonnage (en Hz)
samp = 1/(86400*fhz);                       % pas d'?chantillonnage des donn?es (en jour)
vits = str2num(X.SEFRAN2_VALUE_SPEED);	    % vitesse Sefram (en pouce/min)
ppi = str2num(X.SEFRAN2_VALUE_PPI);        % résolution image (en pixel/pouce)
hip = str2num(X.SEFRAN2_HEIGHT_INCH);       % hauteur de l'image (en pouce)
dtt = 1/1440;                               % interval de temps des dates (en jour)
xip = .5;                                   % largeur des images de coupure (en pouce)
tol = 3/86400;                              % tolérance des limites de fichiers (en jour)
dtl = 4/1440;                               % delais validation dernier fichier
scds = 0.8;			            % espacement vertical des signaux (<1 = chevauchement)
coupure = 'XXX';                            % extension des fichiers lors des coupures
ddmx = str2num(X.GWA_DURATION_VALUE)/86400;

sname = X.SEFRAN2_TITRE;
scopy = '(c) OVSG-IPGP';
psefran = X.SEFRAN2_RACINE;
pdon = X.RACINE_SIGNAUX_SISMO;
pws = X.WEB_RACINE_SIGNAUX;
%ptmp = sprintf('%s/sefran',X.RACINE_OUTPUT_MATLAB);
ptmp = X.SEFRAN2_PATH_TMP;
unix(sprintf('mkdir -p %s/past',ptmp));
fim0 = X.SEFRAN2_VOIES_IMAGE;
%f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
f_save = sprintf('%s/past/%s_past.mat',ptmp,rcode);
convert = X.PRGM_CONVERT;
% css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
bk = '&nbsp;';

% notes = textread(sprintf('%s/%s',X.RACINE_DATA_WEB,X.SEFRAN2_FILE_NOTES),'%s','delimiter','\n');

% Délai d'affichage des vignettes: dernier événement dépouillé ou valeur min (X.SEFRAN2_AFFICHE_HEURES heures)
% temps = now;
% [s,lastmc] = unix(sprintf('ls %s/files/MC??????.txt | tail -n 1',X.MC_RACINE));
% [s,lastmc] = unix(sprintf('head -n 1 %s',lastmc));
% [mc_id,mc_a,mc_m,mc_j,mc_h] = strread(lastmc,'%s%n-%n-%n%n%*[^\n]','delimiter','|');
% mc_dt = datenum(mc_a,mc_m,mc_j,mc_h,0,0);
% daf = max([str2num(X.SEFRAN2_AFFICHE_HEURES),ceil((datenum(tnow) - mc_dt)*24)]);
% disp(sprintf('Displayed thumbnails: %d hours',daf))

stitre = sprintf('%s: %s TU',upper(rcode),sname);
disp(sprintf('@ Temps écoulé : %.2fs',(now-temps)*86400));

% fabrication de l'image de coupure (grise) remplaçant l'image réelle du SUDS
fcut = sprintf('%s/%s.png',psefran,coupure);
if ~exist(fcut,'file')
	imwrite(ones([hip,xip]*ppi)*.5,fcut);
end

% Voies du Sefram
f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.SEFRAN2_FILE_VOIES);
[sfa,sfr,sfo,sfg,sfc] = textread(f,'%s%s%n%n%s','commentstyle','shell');
scol = html2rgb(sfc); 

disp(sprintf('@@ Temps écoulé depuis le début : %.2fs',(now-debut)*86400));
temps = now;
% Création du répertoire du jour
pjour = sprintf('%s/%d%02d%02d',psefran,tnow(1:3));
if ~exist(sprintf('%s/%s',pjour,X.SEFRAN2_IMAGES_HOURLY),'dir')
	unix(sprintf('mkdir -p %s/%s',pjour,X.SEFRAN2_IMAGES_HOURLY));
	unix(sprintf('mkdir -p %s/%s',pjour,X.SEFRAN2_IMAGES_SUDS));
end
fvoies = sprintf('%s/%s',pjour,fim0);
[s]=unix(sprintf('[ 0$(stat -c%%Y %s) -gt 0$(stat -c%%Y %s 2>/dev/null) ]',f,fvoies));
% Image des voies et choix des couleurs
if s == 0 
	figure(1)
	fsxy = [1,hip];
	imv = fsxy*ppi;
	set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy]), orient portrait
	axes('Position',[0,.07,1,.9]);
	set(gca,'XLim',[0,1],'YLim',[-length(sfr)*scds,0])
	for i = 1:length(sfr)
		stn = deblank(sfr{i});
		yl = -(i - .5)*scds;
		text(.5,yl,sprintf('%s ',stn),'HorizontalAlignment','center','FontSize',12,'Fontweight','Bold','Color',scol(i,:),'Interpreter','none')
		text(.5,yl-scds/3,sprintf('%g (%+g) ',sfg(i),sfo(i)),'HorizontalAlignment','center','FontSize',8,'Color',scol(i,:))
	end
	axis off
	print(gcf,'-dpng','-painters',sprintf('-r%d',ppi),sprintf('%s/z.png',ptmp));
	% unix(sprintf('%s -depth 8 -colors 16 %s/z.png %s/z16.png',convert,ptmp,ptmp));
	% unix(sprintf('cp -f %s/z16.png %s',ptmp,fvoies));
	unix(sprintf('cp -f %s/z.png %s',ptmp,fvoies));
	disp(sprintf('Graph: %s created.',fvoies));
	close(1)
end
disp(sprintf('@ Temps écoulé voies : %.2fs',(now-temps)*86400));

% Nettoyage préliminaire des fichiers PNG vides... (depuis l'utilisation des disques de DECOUVERTE)
%IM = dir(sprintf('%s/*.png',psud));
%k = find(cat(1,IM.bytes)==0);
%for i = 1:length(k)
%    f = sprintf('%s/%s',psud,IM(k(i)).name);
%    delete(f);
%    disp(sprintf('ATTENTION: fichier vide %s effacé...',f))
%end

% Détection des fichiers gwa sur la période TLIM
temps = now;
[fn1,ft1,fi1] = listsuds(tlim,sprintf('%s/%s',pdon,X.PATH_SOURCE_SISMO_GWA),ddmx);
disp(sprintf('@ Temps écoulé listsuds : %.2fs',(now-temps)*86400));
fn = fn1;  ft = ft1;  fi = fi1;
% Traitements des trous
k1 = find(diff(ft1) > (ddmx + tol));
if ~isempty(k1)
    for i = 1:length(k1)
        xtt = [ft1(k1(i))+ddmx;ft1(k1(i)+1)];
	xtv = datevec(xtt);
        disp(sprintf('Warning: no gwa files between %s and %s TU...',datestr(xtt(1)),datestr(xtt(2))));
	% nom de fichier de l'image coupure de fin, au format /ipgp/continu/sismo/sefran2/20090319/suds/20090319140800XXX.png
        f = sprintf('%s/%d%02d%02d/%s/%d%02d%02d%02d%02d%02.0f%s.png',psefran,xtv(1,1:3),X.SEFRAN2_IMAGES_SUDS,xtv(1,:),coupure);
	% Copie de l'image grise préfabriquée
	unix(sprintf('cp -f %s %s',fcut,f));
    end
end

% Traitement du temps-réel
if ft1(end) < (tlim(2) - dtl)
    xtt = [ft1(end);tlim(2)];
    xtv = datevec(xtt);
    disp(sprintf('Warning: no gwa file since %s TU...',datestr(ft1(end))));
end


% ------------------------------------------------------------------------------
% Recherche des images à fabriquer
% ------------------------------------------------------------------------------
% Liste des fichiers SUDS au format /ipgp/continu/sismo/SUDS2/20090319/20090319_140800.gwa 
ss = char(fn);
% Longueur du chemin /ipgp/continu/sismo/SUDS2
is0 = length(pdon) + length(X.PATH_SOURCE_SISMO_GWA) + 2;
% D'après la liste des SUDS, séparation en champs (date,heure,extension) et création des noms de fichier PNG censés exister
% /ipgp/continu/sismo/SUDS2/20090319/20090319_140800.gwa -> 20090319140800gwa.png
fni = cellstr([ss(:,is0+[10:17,19:24,26:28]),repmat('.png',size(fn))]);
temps = now;
% Recherche des noms de fichiers PNG existants
% [FB 2011-01-05]: optimisation en réduisant le find sur les jours concernés par la
% période tlim (car le find sur tous les fichiers prend parfois plus de 30 s...)
%[s,ss] = unix(sprintf('find %s -mindepth 3 -maxdepth 3 -path "*/%s/*.png"',psefran,X.SEFRAN2_IMAGES_SUDS));
ss = [];
for tj = floor(tlim(1)):floor(tlim(2))
	tv = datevec(tj);
	[s,sss] = unix(sprintf('find %s/%d%02d%02d -mindepth 2 -maxdepth 2 -path "*/%s/*.png"',psefran,tv(1:3),X.SEFRAN2_IMAGES_SUDS));
	ss = [ss,sss];
end
disp(sprintf('@ Temps écoulé find : %.2fs',(now-temps)*86400));
if ~isempty(ss)
	% Séparation du chemin (inutilisé) et des noms de fichiers
	% /ipgp/continu/sismo/sefran2/20090319/suds/     20090319140800gwa.png
	[xx,in] = strread(ss,sprintf('%%%ds%%s',length(psefran)+length(X.SEFRAN2_IMAGES_SUDS)+11));
	% Index des différences entre les fichiers PNG censés exister et ceux existants
	[s,kfn] = setdiff(fni,in);
	% % Idem inversé, inutilisé !
	% [s,kin] = setdiff(in,fni);

	% Liste des fichiers SUDS à traiter  au format /ipgp/continu/sismo/SUDS2/20090319/20090319_140800.gwa
	fn = fn(kfn);
	% dates de début des fichiers
	ft = ft(kfn);
	% 1 ou 0 suivant la présence de la synchro horloge (GPS) et -1 si c'est une coupure
	fi = fi(kfn);
end

disp('Liste des fichiers SUDS dont il faut créer les images :');
fn

% Lecture des fichiers et fabrication des nouvelles images
% Note: - fn contient la liste des fichiers à traiter
%       - ft contient les dates de début des fichiers
%       - fi contient 1 ou 0 suivant la présence de la synchro horloge (GPS) et -1 si c'est une coupure
%       - xn contient la liste des noms de fichiers coupures
%       - xt contient les dates de coupures

disp(sprintf('@@ Temps écoulé depuis le début : %.2fs',(now-debut)*86400));
debimages=now;
% Pour chaque fichier SUDS à convertir en image
for n = 1:length(fn)
    % Nom du fichier SUDS à traiter
    ff = fn{n};
    % Date de début du SUDS
    tv = datevec(ft(n));
    % Chemin de l'image à fabriquer
    psud = sprintf('%s/%04d%02d%02d/%s',psefran,tv(1:3),X.SEFRAN2_IMAGES_SUDS);
    if ~exist(psud,'dir')
    	unix(sprintf('mkdir -p %s',psud));
    end
    % Nom de l'image à fabriquer, au format /ipgp/continu/sismo/sefran2/20090319/suds/20090319140800gwa.png
    f = sprintf('%s/%s.png',psud,ff(is0+[10:17,19:24,26:28]));
    % Nom de l'image si pas de données, au format /ipgp/continu/sismo/sefran2/20090319/suds/20090319140800XXX.png
    fvide = sprintf('%s/%s%s.png',psud,ff(is0+[10:17,19:24]),coupure);
    % Lecture du fichier SUDS
    %disp(sprintf('Traitement de %s pour fabriquer %s',ff,f));
    [t,d] = ldsuds2(fn{n},sfr,fhz,ptmp,X.PRGM_SUD2MAT2);
    % Appel de la sauvegarde des traces déjà traitées par l'alarme RSAM (l'alarme doit travailler sur 2 fichiers)
    if ~exist('t00','var') & exist(f_save,'file')
        eval('load(f_save)','');
        disp(sprintf('File: %s imported.',f_save));
    end
    sz = length(t);
    % S'il y a des données dans le fichier SUDS, création d'une image
    if sz > 1
        ddt = diff(t([1 end]));
        wip = ddt*vits*1440;    % largeur de l'image (en pouces)
        fsxy = [wip,hip];       % taille de la page (en pouces)
        
        % Traitement de l'alerte (RSAM)
        if exist('t00','var')
            if length(t) == length(t00)
                %alm = alarme2([t00;t],[d00;d],sfr);
            end
        end
        
        % Sauvegarde des données
        t00 = t;
        d00 = d;
        
	% Préparation de l'image du SUDS
        figure(1)
        set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy],'Color','w'), orient portrait
        apos = [0,.07,1,.9];
        axes('Position',apos);
        set(gca,'XLim',[1,sz],'YLim',[-length(sfr)*scds,0])
        xlim = get(gca,'XLim');  ylim = get(gca,'YLim');
        hold on

        % labels date et heure
        for ti = floor(t(1)/dtt)*dtt:dtt:ceil(t(end)/dtt)*dtt
            ixt = round((ti - t(1))/(samp)) + 1;
            lw = 1;  s = datestr(ti,15);  fs = 8;  fw = 'normal';
            if mod(ti,1/24) <= samp,  lw = 3;  fw = 'bold';  end
            if mod(ti,1) <= samp,  lw = 6;  fs = 10;  end
            plot([ixt,ixt]',ylim,'Color',gris1,'LineWidth',lw)
            if mod(ti,5*dtt) <= samp, s = {datestr(ti,15),datestr(ti,1)}; end
            text(ixt,ylim(1),s,'HorizontalAlignment','center','VerticalAlignment','top','FontSize',fs,'FontWeight',fw)
        end

        % limites de fichier
        plot([0;0]+sz+1,ylim,'--','Color',gris1,'LineWidth',2)

        % traces sismiques
        for i = 1:length(sfr)
	    disp(sprintf('Affichage de %s',sfr{i}));
            % application de l'offset et normalisation
            ds = (d(:,i)+sfo(i))/sfg(i);
            % saturation forcee des signaux
	    ds = min(ds,.5);
	    ds = max(ds,-.5);
        
            if fi(n)
                sc = scol(i,:);
            else
                sc = gris2;
            end
            plot(ds - (i - .5)*scds,'Color',sc)
            % Indication de détection de phase
            if exist('alm','var')
                if alm(i,1) >= t(1)
                    ixt = round((alm(i,1) - t(1))/(samp));
                    text(ixt,ylim(1),{' ',' ','|'},'Color','b','FontSize',8,'HorizontalAlignment','center','VerticalAlignment','top');
                end
            end
        end
        hold off
        set(gca,'XLim',xlim,'YLim',ylim,'XTick',[],'YTick',[])
        box on

        % nom du fichier (sans extension gwa pour que ca tienne...)
        text(sz/2,0,sprintf('%s_%s',ff(is0+[10:17]),ff(is0+[19:24])),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'Color','k','Interpreter','none')
        text([1 sz+1],[0 0],{'|','|'},'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'Fontweight','Bold','Color','k')

        % couleur de fond si pas gwa
        if ~strcmp(lower(ff((end-2):end)),'gwa')
            set(gcf,'Color',bggux,'InvertHardCopy','off');
        end

        % création de l'image
        ftmp = sprintf('%s/sefran.png',ptmp);
        ftmp2 = sprintf('%s/sefran16.png',ptmp);
        print(gcf,'-dpng','-painters',sprintf('-r%d',ppi),ftmp)
        %unix(sprintf('cp -f %s %s',ftmp,f));
%         unix(sprintf('%s -depth 8 -colors 16 %s %s',convert,ftmp,ftmp2));
        unix(sprintf('cp -f %s %s',ftmp,f));
    	disp(sprintf('Graph: %s created.',f));
	% Si une image grise existait, on l'enlève
	if exist(fvide,'file')
		unix(sprintf('rm -f %s',fvide));
	end
	close(1)
    else
	    % Pas de données dans le fichier SUDS pourtant présent
    	disp(sprintf('Graph: %s not created. No data in %s',f, ff));
	% Copie de l'image grise préfabriquée
	unix(sprintf('cp -f %s %s',fcut,fvide));
    end
end
disp(sprintf('@@ Temps écoulé depuis le début : %.2fs',(now-debut)*86400));
%disp(sprintf('Temps écoulé pour les images : %.2fs (moyenne %.2fs)\n',(now-debimages)*86400,(now-debimages)*86400/n));

if exist('t00','var')
    save(f_save,'t00','d00');
    disp(sprintf('File: %s created.',f_save));
end

% Classement des fichiers
%[ft,i] = sort(ft);
%fn = fn(i);
%fi = fi(i);

% -- [FB 2011-01-05] suite à des dysfonctionnements après le passage sur sudssrv0,
% nouvelle procédure de construction des images horaires: boucle systématique
% sur toutes les heures de la période concernée (vecteur tlim) et fabrication
% de l'image horaire si au moins l'une des deux conditions est respectée:
%	- soit l'heure contient un des nouveaux fichiers fn (vecteur temps ft);
%	- soit l'image est inexistante.

uft = unique(floor(ft*24));	% vecteur ft en heures rondes et uniques = heures concernées par fn
nbimages = 0;
debimages=now;
for th = floor(tlim(1)*24):floor(tlim(2)*24)
	tv = datevec(th/24);
	pimg = sprintf('%s/%d%02d%02d/%s',psefran,tv(1:3),X.SEFRAN2_IMAGES_HOURLY);
	f = sprintf('%s/%d%02d%02d%02d_sefran.jpg',pimg,tv(1:4));
	if ~exist(f,'file') | any(th==uft)
		ftmp = sprintf('%s/1h',ptmp);
		unix(sprintf('mkdir -p %s',pimg));	% s'assure que le répertoire existe
		unix(sprintf('mkdir -p %s',ptmp));	% s'assure que le répertoire existe
		psud = sprintf('%s/%d%02d%02d/%s',psefran,tv(1:3),X.SEFRAN2_IMAGES_SUDS);
		if ~unix(sprintf('%s +append %s/%d%02d%02d%02d*.png -colors 16 -depth 8 -scale 12.5%% %s.jpg',convert,psud,tv(1:4),ftmp))
			unix(sprintf('cp -f %s.jpg %s',ftmp,f));
			disp(sprintf('Image: %s created.',f))
			nbimages = nbimages + 1;
		end
	end
end
disp(sprintf('@ Temps écoulé pour toutes les images : %.2fs (moyenne %.2fs)',(now-debimages)*86400,(now-debimages)*86400/nbimages));


%=============================================================================================
% Construction de la mini vignette 1 heure glissante (intranet)

flst = sprintf('%s/sefran_last.jpg',psefran);
ftmp = sprintf('%s/v1h.jpg',ptmp);
% récupère les 2 dernières vignettes horaires
% **** problème avec find -mtime: ne prend pas la dernière image car apparemment trop récente...!!
%[s,w] = unix(sprintf('find %s -path "*_sefran.jpg" -mtime 0 | sort | tail -n 2',psefran))
% concatène et réduit
dt1 = datevec(datenum(tnow)-1/24);
f24 = {sprintf('%s/%d%02d%02d/%s/%d%02d%02d%02d_sefran.jpg',psefran,dt1(1:3),X.SEFRAN2_IMAGES_HOURLY,dt1(1:4)), ...
       sprintf('%s/%d%02d%02d/%s/%d%02d%02d%02d_sefran.jpg',psefran,tnow(1:3),X.SEFRAN2_IMAGES_HOURLY,tnow(1:4))};
unix(sprintf('%s +append %s %s -scale 35%% %s',convert,f24{1},f24{2},ftmp));
% crop
minivign = 320;		% largeur en pixels de la mini vignette
IM = imfinfo(ftmp,'jpg');
if IM.Width > minivign
	unix(sprintf('%s -crop %dx%d+%d %s %s',convert,minivign,IM.Height,IM.Width-minivign,ftmp,flst));
else
	unix(sprintf('cp -f %s %s',ftmp,flst));
end

%=============================================================================================
% Construction de la vignette 1 heure glissante (site public)

if pub == 1
	nb1h = 1/(ddmx*24);	% nb de fichiers à prendre pour une heure glissante
	nf1h = sprintf('%s/%s/lasthour',X.RACINE_FTP,X.SISMO_PUBLIC_PATH_FTP);
	ftmp = sprintf('%s/lasthour/lasthour',ptmp);
	IM = dir(sprintf('%s/*GUA.png',psud));
	im1h = sort(cellstr(cat(1,IM.name)));
	delete(sprintf('%s/lasthour/*',ptmp));
	unix(sprintf('cp %s/%s %s/lasthour/00voies.png',pjour,fim0,ptmp));
	unix(sprintf('cp %s/%s %s/lasthour/99voies.png',pjour,fim0,ptmp));
	for i = 1:nb1h
		if i<=length(im1h)
		unix(sprintf('cp %s/%s %s/lasthour/.',psud,im1h{length(im1h)-i+1},ptmp));
		end
	end
	unix(sprintf('%s +append %s/lasthour/*.png %s.png',convert,ptmp,ftmp));
	unix(sprintf('%s -depth 8 -colorspace GRAY %s.png %s16.png', convert,ftmp,ftmp));
	unix(sprintf('%s -scale 12.5%% %s16.png %s.jpg',convert,ftmp,ftmp));
	unix(sprintf('cp -f %s16.png %s.png',ftmp,nf1h));
	unix(sprintf('cp -f %s.jpg %s.jpg',ftmp,nf1h));
	disp(sprintf('Images: %s.png et .jpg créées.',nf1h))
end

disp(sprintf('@@ Temps écoulé depuis le début : %.2fs',(now-debut)*86400));

timelog(rcode,2)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [fn,tf,gps] = listsuds(tlim,pdon,dur)
% liste les fichiers SUDS sur la période TLIM (arrondie à l'heure), dans le répertoire PDON
% et renvoie:
%	- fn = vecteur des noms complets de fichiers SUDS
%	- tf = vecteur temps des fichiers (format Matlab)

fn = [];  tf = [];
for ih = floor(tlim(1)*24):floor(tlim(2)*24)
	tz = datevec(ih/24);
	pj = sprintf('%s/%d%02d%02d/',pdon,tz(1:3));
	S = dir(sprintf('%s%d%02d%02d_%02d*',pj,tz(1:4)));
	if ~isempty(S)
		ff = cat(1,S.name);
		tt = datenum(str2double([cellstr(ff(:,1:4)),cellstr(ff(:,5:6)),cellstr(ff(:,7:8)),cellstr(ff(:,10:11)),cellstr(ff(:,12:13)),cellstr(ff(:,14:15))]));
		fn = [fn;strcat(pj,cellstr(ff))];
		tf = [tf;tt];
	end
end
if isempty(tf)
	tf = 0;
end
gps = ones(size(fn));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [t,d]=ldsuds2(fn,sfr,fhz,ptmp,prog)
% lit les voies Sefran du fichier SUDS, les reechantillonne a la frequence fhz et 
% renvoie un vecteur temps unique t et une matrice des signaux d

[ss,xx] = unix(sprintf('basename %s',fn));
fnam = xx(1:end-1);
ftmp = sprintf('%s/tmp2.mat',ptmp);
delete(sprintf('%s/*.*',ptmp));
unix(sprintf('cp -f %s %s/.',fn,ptmp));
if unix(sprintf('%s %s/%s %s >&! /dev/null',prog,ptmp,fnam,ftmp))
	t = [];  d = [];
	return;
end
S = load(ftmp);
vn = who('-file',ftmp); % recupere les noms de variables
for i = 1:length(sfr)
	ii = find(strcmp(sfr(i),vn)); % attention: sfr contient le nom complet de la variable signal
	if ~isempty(ii)
		eval(sprintf('D(i).d = S.%s;',vn{ii}));
		eval(sprintf('D(i).rate = S.%s_rate;',vn{ii}));
		eval(sprintf('D(i).t0 = S.%s_t0;',vn{ii}));
		D(i).name = vn{ii};
		% conversion temps unix => matlab
		D(i).t0 = datenum(1970,1,1) + D(i).t0/86400;
		% vecteur temps
		D(i).t = D(i).t0 + (0:1/(86400*D(i).rate):(size(D(i).d,1)-1)/(86400*D(i).rate))';
		D(i).tmax = max(D(i).t);
	else
		disp(sprintf('Warning: signal %s not found in file %s !',sfr{i},fnam))
	end
end

if ~exist('D','var')
	t = [];  d = [];
	return;
end

% vecteur temps unique
t = (min(cat(1,D.t0)):1/(86400*fhz):max(cat(1,D.tmax)))';

% matrice donnees decimees
% note [FB]: pour des raisons d'optimisation, le signal est decime par simple moyenne (voir RDECIM);
%	si le nombre d'echantillon final ne colle pas tout à fait (il arrive qu'il y ait 1 echantillon en trop),
%	les donnees sont simplement ignorees.
d = zeros(size(t,1),length(sfr));
for i = 1:length(sfr)
	if length(D)>=i & length(D(i).d)>0 & D(i).rate>fhz
		dd = rdecim(D(i).d,D(i).rate/fhz);
                if length(dd) >= size(d,1)
	                d(:,i) = dd(1:size(d,1));
                else
                        d(1:length(dd),i) = dd;
                end
		if length(dd) ~= size(d,1)
                        disp(sprintf('Warning: sampling problem with signal %s (%d/%d samples after decimation)',sfr{i},length(dd),size(d,1)));
		end
	end	
end


disp(sprintf('File: %s imported.',fn));

