function DOUT=sefran(mat,dgh,pub)
%SEFRAN Graphes de la sismicité continue Courte-Période OVSG.
%
%       SEFRAN construit le Sefram Numérique à partir des dernières données de 
%       sismologie continue (GUA ou GUX), par création d'une image PNG par
%       fichier de données, mises en forme sous une page HTML.
%
%       SEFRAN(MAT,NBH,PUB) effectue:
%		- MAT = sans effet
%		- NBH= nombre d'heures à traiter (défaut = variable SEFRAN_UPDATE_HEURES)
%		- PUB = 1 produit également la dernière heure pour le site public.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-01-21
%   Mise à jour : 2013-10-04

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, dgh = str2num(X.SEFRAN_UPDATE_HEURES); end
if nargin < 3, pub = 0; end


rcode = 'SEFRAN';
stype = 'T';
timelog(rcode,1)

G = readgr(rcode);
tnow = datevec(G.now);
ST = readst(G.cod,G.obs);
sali3 = char(ST.dat);
sali3 = cellstr(sali3(:,1:3));

% Initialisation des variables
gris1 = .8*[1,1,1];                         % couleur gris clair
gris2 = .5*[1,1,1];                         % couleur gris foncé
bggux = [1,.8,.5];                          % couleur de fond pour les GUX
bgnir = [.5,1,1];                           % couleur de fond pour sans IRIG

tlim = datenum(tnow) + [-dgh/24,0];			% date du début de la mise à jour
fhz = str2num(X.IASPEI_VALUE_SAMPLING);		% fréquence d'échantillonnage (en Hz)
samp = 1/(86400*fhz);                       % pas d'échantillonnage des données (en jour)
dec = str2num(X.SEFRAN_VALUE_DECIMATION);	% décimation des données
vits = str2num(X.SEFRAN_VALUE_SPEED);		% vitesse Sefram (en pouce/min)
nbpt = str2num(X.IASPEI_VALUE_MAX_PTS);		% dynamique du signal (en points)
ppi = str2num(X.SEFRAN_VALUE_PPI);			% résolution image (en pixel/pouce)
dtt = 1/1440;                               % interval de temps des dates (en jour)
hip = 7;                                    % hauteur de l'image (en pouce)
xip = .5;                                   % largeur des images de coupure (en pouce)
tol = 3/86400;                              % tolérance des limites de fichiers (en jour)
dtl = 4/1440;                               % delais validation dernier fichier
mx = nbpt*[-1,1];                           % échelle signal (en points)
scds = diff(mx)/1.7;
coupure = 'XXX';                            % extension des fichiers lors des coupures
dgua = str2num(X.GUA_DURATION_VALUE)/86400;
dgux = str2num(X.GUX_DURATION_VALUE)/86400;

sname = sprintf('%s: %s',rcode,G.nom);
scopy = '(c) OVSG-IPGP';
psefran = X.SEFRAN_RACINE;
pdon = X.RACINE_SIGNAUX_SISMO;
pws = X.WEB_RACINE_SIGNAUX;
%ptmp = sprintf('%s/sefran',X.RACINE_OUTPUT_MATLAB);
ptmp = '/tmp/sefran';
unix(sprintf('mkdir -p %s/past',ptmp));
fhtv = 'sefran_vign.htm';
fhtv0 = 'sefran_vign_frame.htm';
fhtv1 = 'sefran_vign_head.htm';
fim0 = X.SEFRAN_VOIES_IMAGE;
%f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
f_save = sprintf('%s/past/%s_past.mat',ptmp,rcode);
convert = X.PRGM_CONVERT;
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
bk = '&nbsp;';

notes = textread(sprintf('%s/%s',X.RACINE_DATA_WEB,X.SEFRAN_FILE_NOTES),'%s','delimiter','\n');

% Délai d'affichage des vignettes: dernier événement dépouillé ou valeur min (X.SEFRAN_AFFICHE_HEURES heures)
[s,lastmc] = unix(sprintf('ls %s/files/MC??????.txt | tail -n 1',X.MC_RACINE));
[s,lastmc] = unix(sprintf('head -n 1 %s',lastmc));
[mc_id,mc_a,mc_m,mc_j,mc_h] = strread(lastmc,'%s%n-%n-%n%n%*[^\n]','delimiter','|');
mc_dt = datenum(mc_a,mc_m,mc_j,mc_h,0,0);
daf = max([str2num(X.SEFRAN_AFFICHE_HEURES),ceil((datenum(tnow) - mc_dt)*24)]);
disp(sprintf('Vignettes affichées: %d heures',daf))

stitre = sprintf('%s: %s TU',upper(rcode),sname);

% Voies du Sefram
f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.SEFRAN_FILE_VOIES);
[sfr,sfg] = textread(f,'%s%n','commentstyle','shell');

% Image des voies et choix des couleurs
scol = ones(length(sfr),3);
figure(1), clf
fsxy = [.6,hip];
imv = fsxy*ppi;
set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy]), orient portrait
axes('Position',[0,.07,1,.9]);
set(gca,'XLim',[0,1],'YLim',[-length(sfr)*scds,0])
for i = 1:length(sfr)
    % pour la latitude des stations, recherche des 3 premières lettres de l'alias (composantes horizontales possibles)
    kxs(i) = find(strcmp(sfr{i}(1:3),sali3));
    if ST.geo(kxs(i),1) > 16 & ST.geo(kxs(i),1) < 16.1
        scol(i,:) = [1,0,0];    % stations volcaniques
    else
        scol(i,:) = [0,.6,0];   % stations régionales
    end
    stn = deblank(sfr{i});
    yl = -(i - .5)*scds;
    text(.5,yl,sprintf('%s ',stn),'HorizontalAlignment','center','FontSize',12,'Fontweight','Bold','Color',scol(i,:))
    text(.5,yl-scds/4,sprintf('x%d (%1.0f) ',sfg(i),nbpt/sfg(i)),'HorizontalAlignment','center','FontSize',8,'Color',scol(i,:))
end
axis off
pjour = sprintf('%s/%d%02d%02d',psefran,tnow(1:3));
s = sprintf('mkdir -p %s/images',pjour);
if unix(s)
	disp(sprintf('Warning: problem with system command "%s"',s));
end
s = sprintf('mkdir -p %s/%s',pjour,X.SEFRAN_IMAGES_SUDS);
if unix(s)
	disp(sprintf('Warning: problem with system command "%s"',s));
end
f = sprintf('%s/%s',pjour,fim0);
print(gcf,'-dpng','-painters',sprintf('-r%d',ppi),sprintf('%s/z.png',ptmp));
unix(sprintf('%s -depth 8 -colors 16 %s/z.png %s/z16.png',convert,ptmp,ptmp));
unix(sprintf('cp -f %s/z16.png %s',ptmp,f));
disp(sprintf('Graphe: %s créé.',f));
close(1)

% Nettoyage préliminaire des fichiers PNG vides... (depuis l'utilisation des disques de DECOUVERTE)
%IM = dir(sprintf('%s/*.png',psud));
%k = find(cat(1,IM.bytes)==0);
%for i = 1:length(k)
%    f = sprintf('%s/%s',psud,IM(k(i)).name);
%    delete(f);
%    disp(sprintf('ATTENTION: fichier vide %s effacé...',f))
%end

% Détection des fichiers GUA et GUX sur la période TLIM
[fn1,ft1,fi1] = listsuds(tlim,sprintf('%s/%s',pdon,X.PATH_SOURCE_SISMO_GUA),dgua);
fn = fn1;  ft = ft1;  fi = fi1;
% Traitements des trous de GUA
k1 = find(diff(ft1) > (dgua + tol));
if ~isempty(k1)
    for i = 1:length(k1)
        xtt = [ft1(k1(i))+tol;ft1(k1(i)+1)-tol];
        xtv = datevec(xtt);
        disp(sprintf('Pas de fichiers GUA entre %s et %s TU. Recherche de GUX...',datestr(ft1(k1(i))),datestr(ft1(k1(i)+1))));
        for j = 1:2
            fn = [fn;cellstr(sprintf('%s/%s/%04d%02d%02d/%02d%02d%02d%02.0f.XXX',pdon,X.PATH_SOURCE_SISMO_GUX,xtv(j,1:3),xtv(j,2:end)))];
        end
        ft = [ft;xtt];
        fi = [fi;-ones(size(xtt))];
        [fn2,ft2,fi2] = listsuds(xtt,sprintf('%s/%s',pdon,X.PATH_SOURCE_SISMO_GUX),dgux);
        if ~isempty(fn2)
            fn = [fn;fn2];
            ft = [ft;ft2];
            fi = [fi;fi2];
        else
            disp('Problème: pas de Fichier GUX !!');
        end
    end
end

% Traitement du temps-réel
if ft1(end) < (tlim(2) - dtl)
    xtt = [ft1(end);tlim(2)];
    xtv = datevec(xtt);
    disp(sprintf('Pas de fichiers GUA depuis %s TU. Recherche de GUX...',datestr(ft1(end))));
    fn = [fn;cellstr(sprintf('%s/%s/%04d%02d%02d/%02d%02d%02d%02.0f.XXX',pdon,X.PATH_SOURCE_SISMO_GUX,xtv(1,1:3),xtv(1,2:end)))];
    ft = [ft;xtt];
    fi = [fi;-ones(size(xtt))];
    [fn2,ft2,fi2] = listsuds(xtt,sprintf('%s/%s',pdon,X.PATH_SOURCE_SISMO_GUX),dgux);
    if ~isempty(fn2)
        fn = [fn;fn2];
        ft = [ft;ft2];
        fi = [fi;fi2];
    else
        disp('Problème: pas de Fichier GUX !!');
    end
end


% Construction des noms d'images correspondantes aux GUA et GUX
ss = char(fn);
is0 = length(pdon) + length(X.PATH_SOURCE_SISMO_GUA) + 2;
fni = cellstr([ss(:,is0+[3:6,10:17,19:21]),repmat('.png',size(fn))]);
[s,ss] = unix(sprintf('find %s -mindepth 3 -maxdepth 3 -path "*/%s/*.png"',psefran,X.SEFRAN_IMAGES_SUDS));
[xx,in] = strread(ss,sprintf('%%%ds%%s',length(psefran)+length(X.SEFRAN_IMAGES_SUDS)+11));
if ~isempty(in)
    [s,kfn] = setdiff(fni,in);
    [s,kin] = setdiff(in,fni);
    fn = fn(kfn);
    ft = ft(kfn);
    fi = fi(kfn);
end

% Lecture des fichiers et fabrication des nouvelles images
% Note: - fn contient la liste des fichiers à traiter (GUA ou/et GUX)
%       - ft contient les dates de début des fichiers
%       - fi contient 1 ou 0 suivant la présence du code IRIG et -1 si c'est une coupure
%       - xn contient la liste des noms de fichiers coupures
%       - xt contient les dates de coupures

debimages=now;
for n = 1:length(fn)
    ff = fn{n};
    tv = datevec(ft(n));
    psud = sprintf('%s/%04d%02d%02d/%s',psefran,tv(1:3),X.SEFRAN_IMAGES_SUDS);
    unix(sprintf('mkdir -p %s',psud));
    unix(sprintf('mkdir -p %s/%04d%02d%02d/images',psefran,tv(1:3)));
    f = sprintf('%s/%s%s%s.png',psud,ff((end-18):(end-15)),ff((end-11):(end-4)),ff((end-2):end));
    if fi(n) ~= -1
        [t,d] = ldsuds(fn{n},ft(n),fi(n),dec,fhz,sfr,ptmp,X.PRGM_SUD2MAT);
        if ~exist('t00','var') & exist(f_save,'file')
            eval('load(f_save)','');
            disp(sprintf('Fichier: %s importé.',f_save));
        end
        sz = length(t);
        if sz > 1
             ddt = diff(t([1 end]));
        wip = ddt*vits*1440;    % largeur de l'image (en pouces)
        fsxy = [wip,hip];       % taille de la page (en pouces)
        
        % Traitement de l'alerte (RSAM)
        if exist('t00','var')
            if length(t) == length(t00)
                alm = alarme([t00;t],[d00;d],sfr);
            end
        end
        
        % Sauvegarde des données
        t00 = t;
        d00 = d;
        
        figure(1), clf
        set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy],'Color','w'), orient portrait
        apos = [0,.07,1,.9];
        axes('Position',apos);
        set(gca,'XLim',[0,sz],'YLim',[-length(sfr)*scds,0])
        xlim = get(gca,'XLim');  ylim = get(gca,'YLim');
        hold on

        % labels date et heure
        for ti = floor(t(1)/dtt)*dtt:dtt:ceil(t(end)/dtt)*dtt
            ixt = round((ti - t(1))/(samp*dec));
            lw = 1;  s = datestr(ti,15);  fs = 8;  fw = 'normal';
            if mod(ti,1/24) <= samp*dec,  lw = 3;  fw = 'bold';  end
            if mod(ti,1) <= samp*dec,  lw = 6;  fs = 10;  end
            plot([ixt,ixt]',ylim,'Color',gris1,'LineWidth',lw)
            if mod(ti,5*dtt) <= samp*dec, s = {datestr(ti,15),datestr(ti,1)}; end
            text(ixt,ylim(1),s,'HorizontalAlignment','center','VerticalAlignment','top','FontSize',fs,'FontWeight',fw)
        end

        % limites de fichier
        plot([sz-1;sz-1],ylim,'--','Color',gris1,'LineWidth',2)

        % traces sismiques
        for i = 1:length(sfr)
            % application du gain
            ds = d(:,i)*sfg(i);
            % saturation forcée des signaux
            k = find(ds < mx(1));  ds(k) = mx(1)*ones(size(k));
            k = find(ds > mx(2));  ds(k) = mx(2)*ones(size(k));
        
            stn = deblank(ST.ali{kxs(i)});
            if fi(n)
                sc = scol(i,:);
            else
                sc = gris2;
            end
            plot(ds - (i - .5)*scds,'Color',sc)
            % Indication de détection de phase
            if exist('alm','var')
                if alm(i,1) >= t(1)
                    ixt = round((alm(i,1) - t(1))/(samp*dec));
                    text(ixt,ylim(1),{' ',' ','|'},'Color','b','FontSize',8,'HorizontalAlignment','center','VerticalAlignment','top');
                end
            end
        end
        hold off
        set(gca,'XLim',xlim,'YLim',ylim,'XTick',[],'YTick',[])
        box on

        % nom du fichier
        text(sz/2,0,[ff((end-20):(end-13)),' / ',ff((end-11):end)],'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'Color','k')
        text([0 sz],[0 0],{'|','|'},'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'Fontweight','Bold','Color','k')

        % couleur de fond si pas GUA
        if ~strcmp(ff((end-2):end),'GUA')
            set(gcf,'Color',bggux,'InvertHardCopy','off');
        end

        % création de l'image
        ftmp = sprintf('%s/sefran.png',ptmp);
        ftmp2 = sprintf('%s/sefran16.png',ptmp);
        print(gcf,'-dpng','-painters',sprintf('-r%d',ppi),ftmp)
        %unix(sprintf('cp -f %s %s',ftmp,f));
        unix(sprintf('%s -depth 8 -colors 16 %s %s',convert,ftmp,ftmp2));
        unix(sprintf('cp -f %s %s',ftmp,f));
    else
        % = 2005-03-11 ============================================================================================================================
        % BUG A RESOUDRE
        % pb dans la lecture du fichier : création d'une barre grise
        %imwrite(ones([hip,xip]*ppi)*.5,f);
    end
    disp(sprintf('Graphe: %s créé.',f));
    end
end
if n>0
	disp(sprintf('Temps écoulé pour toutes les images : %.2fs (moyenne %.2fs)\n',(now-debimages)*86400,(now-debimages)*86400/n));
end
close

if exist('t00','var')
    save(f_save,'t00','d00');
    disp(sprintf('Fichier: %s créé.',f_save));
end

% Classement des fichiers
[ft,i] = sort(ft);
fn = fn(i);
fi = fi(i);


% Construction des images et pages horaires (concernées par les nouveaux fichiers fn)
if ~isempty(fn)
    th = floor(ft*24);                  % vecteur tf en heures rondes
    th(find(diff(th) == 0) + 1) = [];   % élimine les heures redondantes (th = liste des heures concernées)
    debimages=now;
    for hh = 1:length(th)
        tv = datevec(th(hh)/24);
        tvp = datevec(datenum(tv) - 0.1/24);    % heure précédente
		fhp = sprintf('%d%02d%02d/%d%02d%02d%02d_sefran.htm',tvp(1:3),tvp(1:4));
        tvn = datevec(datenum(tv) + 1.1/24);    % heure suivante
		fhn = sprintf('%d%02d%02d/%d%02d%02d%02d_sefran.htm',tvn(1:3),tvn(1:4));
        f = sprintf('%s/%d%02d%02d/images/%d%02d%02d%02d_sefran',psefran,tv(1:3),tv(1:4));
		ftmp = sprintf('%s/1h',ptmp);
        psud = sprintf('%s/%04d%02d%02d/%s',psefran,tv(1:3),X.SEFRAN_IMAGES_SUDS);
        unix(sprintf('%s +append %s/%02d%02d%02d%02d*.png -|%s -colors 16 -depth 8 - %s.png',convert,psud,mod(tv(1),100),tv(2:4),convert,ftmp));
        IM = imfinfo(ftmp,'png');
        unix(sprintf('%s -scale %dx%d %s.png %s.jpg',convert,round(IM.Width/8),round(IM.Height/8),ftmp,ftmp));
		unix(sprintf('cp -f %s.png %s.png',ftmp,f));
		unix(sprintf('cp -f %s.jpg %s.jpg',ftmp,f));
        disp(sprintf('Images: %s.png et .jpg créées.',f))
    
        % récupération des noms, dates et tailles des images
        ss = dir(sprintf('%s/%02d%02d%02d%02d*.png',psud,mod(tv(1),100),tv(2:4)));
	if ~isempty(ss)
		fi = sort(cellstr(cat(1,ss.name)));
	else
		fi = cell(0);
	end
        [ti,irig,type] = nf2t(fi);
        im = zeros(size(fi,1),2);
        for i = 1:length(fi)
            I = imfinfo(sprintf('%s/%s',psud,fi{i}),'png');
            im(i,:) = [I.Width,I.Height];
        end
        mim = max(im(:,2));

		% récupération du fichier précédent l'heure
        psudp = sprintf('%s/%04d%02d%02d/%s',psefran,tvp(1:3),X.SEFRAN_IMAGES_SUDS);
        ss = dir(sprintf('%s/%02d%02d%02d%02d*.png',psudp,mod(tvp(1),100),tvp(2:4)));
		if ~isempty(ss)
			fip = sort(cellstr(cat(1,ss.name)));	
		else
			fip = {''};
		end
    
		% ouverture du fichier HTML
        f = sprintf('%s/%d%02d%02d/%d%02d%02d%02d_sefran.htm',psefran,tv(1:3),tv(1:4));
        ftmp = sprintf('%s/1h.htm',ptmp);
        fid = fopen(ftmp,'wt');
        fprintf(fid,'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">\n');
		fprintf(fid,'<HTML>\n<HEAD>\n<meta http-equiv="content-type" content="text/html; charset=utf-8">\n');
		fprintf(fid,'<link rel="stylesheet" type="text/css" href="/%s">\n',X.FILE_CSS);
		fprintf(fid,'<TITLE>%s %d%02d%02d%02d TU</TITLE>\n%s\n</HEAD>\n',sname,tv(1:4),css);
		fprintf(fid,'<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>\n<script language="JavaScript" src="/JavaScripts/overlib.js"></script>\n<!-- overLIB (c) Erik Bosrup -->\n');
		% tableau
        fprintf(fid,'<TABLE border="0" cellpadding="0" cellspacing="0" width="%d"><TR>\n',IM.Width+imv(1));
		% lien vers fichier heure précédente
        fprintf(fid,'<TD style="border:0" align=center><A href="../%s"><B><SUP>HEURE<br>PR&Eacute;C&Eacute;DENTE</SUP></B></A></TD>\n',fhp);
		% images des voies
        fprintf(fid,'<TD style="border:0" nowrap height="%d"><IMG src="%s" width="%d" height="%d" border="0" alt="Voies Sefran">\n',mim,fim0,imv);
		% image heure précédente
		fprintf(fid,'<IMG src="../%d%02d%02d/suds/%s" border="0" title="pour d&eacute;pouiller ce fichier, revenir &agrave; l&apos;heure pr&eacute;c&eacute;dente...">',tvp(1:3),fip{end});
		% images de l'heure
        fprintf(fid,'<IMG src="images/%d%02d%02d%02d_sefran.png" width="%d" height="%d" border="0" usemap="#%02d"></TD>\n',tv(1:4),IM.Width,IM.Height,tv(4));
       	fprintf(fid,'<TD style="border:0" nowrap><IMG src="%s" width="%d" height="%d" border="0" alt="Voies Sefran"></TD>',fim0,imv);
        fprintf(fid,'<TD style="border:0" align=center><A href="../%s"><B><SUP>HEURE<br>SUIVANTE</SUP></B></A></TD>',fhn);
        fprintf(fid,'</TR></TABLE>\n');
        fprintf(fid,'<MAP name="%02d">\n',tv(4));
        for i = 1:length(fi)
            fa = fi{i};
            ff = sprintf('%s.%s',fa(5:12),fa(13:15));
            fr = sprintf('/iaspei%d/%04d%02d%02d/%s',type(i),tv(1:3),ff);
            x2 = sum(im(1:i,1));  x1 = x2 - im(i,1);
            if ~strcmp(fa(13:15),coupure)
                %fprintf(fid,'<AREA href="/cgi-bin/frameMC.pl?f=%s" target="_blank" title="Dépouiller %s" shape="rect" coords="%d,%d,%d,%d" alt="Main courante %s">\n',fr,ff,x1,0,x2-1,20,ff);
				fprintf(fid,'<AREA href="#" onclick="window.open(''/cgi-bin/frameMC.pl?f=%s'',''main courante %s'',''width=1024,height=768,scrollbars=yes''); return false;" onMouseOut="nd()" onMouseOver="overlib(''Lancer la Main Courante sur le fichier %s'')" shape="rect" coords="%d,%d,%d,%d" alt="Main courante %s">\n',fr,ff,ff,x1,0,x2-1,20,ff);
                fprintf(fid,'<AREA href="%s%s" onMouseOut="nd()" onMouseOver="overlib(''Cliquer pour voir les signaux du fichier %s'')" shape=rect coords="%d,%d,%d,%d" alt="Signal %s">\n',pws,fr,ff,x1,21,x2-1,im(i,2)-1,ff);
            end
        end
        %fprintf(fid,'<AREA nohref shape=rect coords="%d,%d,%d,%d">\n',[0,0,IM.Width,IM.Height]);
        fprintf(fid,'</MAP></BODY></HTML>\n');
        fclose(fid);
        unix(sprintf('cp -f %s %s',ftmp,f));
        disp(sprintf('Fichier: %s créé.',f))
    end
    disp(sprintf('Temps écoulé pour toutes les images : %.2fs (moyenne %.2fs)\n',(now-debimages)*86400,(now-debimages)*86400/hh));
end


%=============================================================================================
% Construction des pages HTML

% récupération des noms, dates et tailles des images
fi = [];
im = [];
for j = floor(datenum(tnow)-dgh/24):floor(datenum(tnow))
	tjv = datevec(j);
	psud = sprintf('%s/%04d%02d%02d/%s',psefran,tjv(1:3),X.SEFRAN_IMAGES_SUDS);
	ss = dir(sprintf('%s/*.png',psud));
	if ~isempty(ss)
		fii = sort(cellstr(cat(1,ss.name)));
		imi = zeros(size(fi,1),2);
		for i = 1:length(fii)
		    I = imfinfo(sprintf('%s/%s',psud,fii{i}),'png');
		    imi(i,:) = [I.Width,I.Height];
		end
		fi = [fi;fii];
		im = [im;imi];
	end
end
[ti,irig,type] = nf2t(fi);
mim = max(im(:,2));

i_et = 1/(86400*samp*dec);
i_ps = vits*ppi/60;
i_ve = vits*2.54;


% Page de frame des vignettes
f = sprintf('%s/%s',psefran,fhtv0);
fid = fopen(f,'wt');
fprintf(fid,'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN">\n<HTML><HEAD><meta http-equiv="content-type" content="text/html; charset=iso-8859-1">\n<TITLE>%s %s</TITLE>%s</HEAD>\n',sname,datestr(now),css);
fprintf(fid,'<FRAMESET rows="80,*">\n');
fprintf(fid,'<FRAME name="Head" src="%s" scrolling="No" NoResize frameborder="0">\n',fhtv1);
fprintf(fid,'<FRAME name="Main" src="%s" frameborder="0">\n',fhtv);
fprintf(fid,'</FRAMESET>\n<NOFRAMES>\n');
fprintf(fid,'<BODY onLoad="if (self != top) top.location = self.location"></BODY></HTML>');
fclose(fid);
disp(sprintf('Fichier: %s créé.',f))

% Page d'en-tete des vignettes
f = sprintf('%s/%s',psefran,fhtv1);
fid = fopen(f,'wt');
fprintf(fid,'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">\n<HTML>\n<HEAD>\n<TITLE>%s %s</TITLE>\n%s\n<meta http-equiv="content-type" content="text/html; charset=iso-8859-1">\n<META http-equiv="Refresh" content="30">\n</HEAD>\n',sname,datestr(now),css);
fprintf(fid,'<TABLE border="0" width="100%%"><TR>');
%fprintf(fid,'<TD width="105" style="border: 0"><A href="../../" target="_top"><IMG src="/%s" width="100" height="99" alt="Accueil" border="0"></A></TD>',X.IMAGE_LOGO_OVSG_100_WEB);
fprintf(fid,'<TD style="border:0"><H2>%s</H2>\n',sname);
fprintf(fid,'<P>[ ');
fprintf(fid,'<A href="/cgi-bin/afficheRESEAUX.pl?noaffiche=0" target="bas">Réseaux</A> ');
fprintf(fid,'| <A href="/%s" target="bas">Fichiers</A> ',X.SEFRAN_PATH_WEB);
fprintf(fid,'| <A href="/cgi-bin/afficheRESEAUX.pl?reseau=GSZ" target="bas">Courte-Période</A> ');
fprintf(fid,'| <A href="/auto/sismohyp_visu.htm" target="bas">Hypocentres</A> ');
fprintf(fid,'| <A href="/auto/sismobul_visu.htm" target="bas">Bulletins</A> ');
fprintf(fid,'| <A href="/auto/sismocp_visu.htm" target="bas">Tambours</A> ');
fprintf(fid,'| <A href="/cgi-bin/afficheMC.pl" target="bas">Main Courante</A> ');
fprintf(fid,'| <A href="/%s/MC.png" target="bas">Graphe MC</A> ',X.MC_PATH_WEB);
fprintf(fid,'| <A href="/cgi-bin/%s" target="bas">Dépouillement SEFRAN</A> ',X.CGI_AFFICHE_SEFRAN);
fprintf(fid,']</P>\n</TD><TD align="center" style="border:0"><H2>%d-%02d-%02d<BR>%02d:%02d TU</H2>\n</TD>',tnow(1:5));
fprintf(fid,'</TR></TABLE><HR>');
fprintf(fid,'</TABLE></BODY></HTML>\n');
fclose(fid);
disp(sprintf('Fichier: %s créé.',f))

% Page des vignettes
f = sprintf('%s/%s',psefran,fhtv);
fid = fopen(f,'wt');
fprintf(fid,'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">\n<HTML>\n<HEAD>\n<TITLE>%s %s</TITLE>\n%s\n<meta http-equiv="content-type" content="text/html; charset=iso-8859-1">\n<META http-equiv="Refresh" content="30">\n</HEAD>\n',sname,datestr(now),css);
fprintf(fid,'');
fprintf(fid,'<TABLE border="0">\n',imv,sum(im(:,1))+100,mim);
for i = 0:round(daf - 1)
    th = datenum([tnow(1:3),tnow(4) - i + 24,0,0]) - 1;
    tv = datevec(th);
    ff = sprintf('%d%02d%02d/images/%d%02d%02d%02d_sefran.jpg',tv(1:3),tv(1:4));
    %j = mod(tnow(4) - i + 24,24);
    fprintf(fid,'<TR><TD style="border:0" align="center"><FONT size="1">%d<BR>%02d-%02d%s</FONT><BR><FONT size="4"><B>%02d</B></FONT><BR><FONT size="1">TU</FONT></TD>',tv(1),tv(2:3),bk,tv(4));
    if exist(sprintf('%s/%s',psefran,ff),'file')
        fprintf(fid,'<TD style="border:0"><A href="%d%02d%02d/%d%02d%02d%02d_sefran.htm" target="blank" title="%s %02dh TU"><IMG src="%s" border="1" alt="%s %02dh TU"></A></TD></TR>\n',tv(1:3),tv(1:4),datestr(th,1),tv(4),ff,datestr(th,1),tv(4));
    else
        fprintf(fid,'<TD style="border: 0">&nbsp;</TD></TR>\n');
    end
end
fprintf(fid,'<TR><TD style="border:0" colspan=2>... pour la suite, voir <A href="/cgi-bin/%s" target="_blank">les %d derniers jours de SEFRAN</A></TD></TR>\n',X.CGI_AFFICHE_SEFRAN,str2num(X.GRAVURE_OLD_DATA_JOURS));
fprintf(fid,'</TABLE>\n');
for i = 1:length(notes)
    fprintf(fid,'%s\n',notes{i});
end
fprintf(fid,'<B>Paramètres du SefraN:</B><UL>\n');
fprintf(fid,'<LI>Échantillonnage temporel = <B>%1.0f Hz</B></LI>\n',i_et);
fprintf(fid,'<LI>Résolution temporelle = <B>%1.0f px/s</B></LI>\n',i_ps);
fprintf(fid,'<LI>Vitesse équivalente = <B>%g "/min</B> (%1.1f cm/min)</LI>\n',vits,i_ve);
fprintf(fid,'<LI>Échelle&nbsp;verticale&nbsp;maximum&nbsp;(x1)&nbsp;=&nbsp;<B>%d&nbsp;pts</B></LI>\n',nbpt);
fprintf(fid,'</UL>\n');
fprintf(fid,'</BODY></HTML>\n');

fclose(fid);
disp(sprintf('Fichier: %s créé.',f))

% Copie pour gravure quotidienne précédée d'un effacement
%if tnow(4) == 0 & tnow(5) < 5
%    unix(sprintf('rm -rf %s/graphes/sefran',pdon));
%    unix(sprintf('cp -fpru %s %s/graphes/',psefran,pdon));
%end


% Effacement des fichiers PNG et HTM horaires anciens
% --- fichiers suds
%if ~isempty(kin)
%    for i = 1:length(kin)
%        f = sprintf('%s/%s',psud,in{kin(i)});
%        unix(sprintf('rm -f %s',f));
%        disp(sprintf('Images: %s effacée.',f));
%    end
%end

% --- pages html et images concaténées
%tv = datevec(datenum(tnow) - ceil(dgh/24 + 1));
%f = sprintf('%d%02d%02d*',tv(1:3));
%ff = sprintf('%s/%s',psefran,f);
%unix(sprintf('rm -f %s',ff));
%disp(sprintf('Fichiers: %s effacés.',ff));
%ff = sprintf('%s/images/%s',psefran,f);
%unix(sprintf('rm -f %s',ff));
%disp(sprintf('Images: %s effacés.',ff));

%=============================================================================================
% Construction de la mini vignette 1 heure glissante (intranet)

flst = sprintf('%s/sefran_last.jpg',psefran);
% récupère les dernières vignettes horaires
[s,w] = unix(sprintf('find %s -path "*_sefran.jpg" -mtime 0 | sort',psefran));
f24 = strread(w,'%s','delimiter','\n');
% concatène les 2 dernières et les réduit
unix(sprintf('%s +append %s %s -scale 35%% %s',convert,f24{end-1},f24{end},flst));
% crop
minivign = 320;		% largeur en pixels de la mini vignette
IM = imfinfo(flst,'jpg');
if IM.Width > minivign
	unix(sprintf('%s -crop %dx%d+%d %s %s',convert,minivign,IM.Height,IM.Width-minivign,flst,flst));
end

%=============================================================================================
% Construction de la vignette 1 heure glissante (site public)

if pub == 1
	nb1h = 1/(dgua*24);	% nb de fichiers à prendre pour une heure glissante
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

timelog(rcode,2)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [t,irig,type] = nf2t(f)
% traduit un nom de fichier YYMMDDHHNNSS en date

fa = char(f);
zd = str2double([cellstr(fa(:,1:2)),cellstr(fa(:,3:4)),cellstr(fa(:,5:6)),cellstr(fa(:,7:8)),cellstr(fa(:,9:10)),cellstr(fa(:,11:12))]);
irig = ones(size(f));
type = ones(size(f));

% traitement des secondes (fichiers sans code IRIG: [A-F]X)
k = find(isnan(zd(:,6)));
if ~isempty(k)
    for i = 1:length(k)
        zd(k(i),6) = (double(fa(k(i),11)) - double('A'))*10 + str2double(fa(k(i),12));
        irig(k(i)) = 0;
    end
end
t = datenum([zd(:,1) + 2000,zd(:,2:end)]);

% durée des GUX
k = find(strcmp(cellstr(fa(:,13:15)),'GUX'));
if ~isempty(k)
    type(k) = 2;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [fn,tf,irig] = listsuds(tlim,pdon,dur)
% liste les fichiers SUDS sur la période TLIM, dans le répertoire PDON
% avec une durée de fichier DUR (en jour)

fn = [];  tf = [];  irig = [];
for ih = floor(tlim(1)*24):floor(tlim(2)*24)
    tz = datevec(ih/24);
    am = sprintf('%d%02d%02d',tz(1:3));
    S = dir(sprintf('%s/%s/%02d%02d*',pdon,am,tz(3:4)));
    if ~isempty(S)
        ff = char(sort(cellstr(cat(1,S.name))));
        [tt,ii] = nf2t(cellstr([repmat(am(3:6),[size(ff,1),1]),ff(:,[1:(end-3),(end-2):end])]));
        kk = find(tt <= tlim(2) & (tt + dur) >= tlim(1));
        if ~isempty(kk)
            fn = [fn;cellstr([repmat(sprintf('%s/%s/',pdon,am),[length(kk),1]),ff(kk,:)])];
            tf = [tf;tt(kk)];
            irig = [irig;ii(kk)];
        end
    end
end
if isempty(tf)
    tf = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [tt,dd,irig] = ldsuds(fn,tf,ir,dec,fhz,sfr,ptmp,prog)
% lit les voies Sefran du fichier SUDS

fnam = fn((end-12):end);
delete(sprintf('%s/*.*',ptmp));
unix(sprintf('cp -f %s %s/.',fn,ptmp));
if unix(sprintf('%s %s/%s >/dev/null',prog,ptmp,fnam))
    tt = [];
    dd = [];
    irig = [];
    return;
end
ff = sprintf('%s/tmp.mat',ptmp);
vn = who('-file',ff);
va = char(vn);
for i = 1:length(sfr)
    ii = find(strcmp(sfr(i),cellstr(va(:,1:4))));
    if ~isempty(ii)
        S = load(ff,vn{ii});
        eval(sprintf('dd(:,i) = S.%s;',vn{ii}));
    end
end

% fichier avec code IRIG: tf = heure de début de fichier (exact)
tt = (tf + (1:size(dd,1))/(fhz*86400))';
%num2str(datevec([tt(1),tt(end)]))
% fichiers sans code IRIG: tf = heure de fermeture du fichier (approximatif)
if ir == 0
    tt = tt - diff(tt([1 end]));
end

if dec ~= 1
    tt = rdecim(tt,dec);
    dd = rdecim(dd,dec);
end
%num2str(datevec([tt(1),tt(end)]))
disp(sprintf('Fichier: %s importé.',fn));
