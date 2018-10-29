function DOUT=rap_modif(mat,tlim,OPT,nograph)
%RAP Graphes de la sismicité déclenchée RAP OVSG.
%       RAP sans option charge les données les plus récentes du FTP
%       et retrace tous les graphes pour le WEB.
%
%       RAP(MAT,TLIM,OPT,NOGRAPH) effectue les opérations suivantes:
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
%       DOUT = RAP(...) renvoie une structure DOUT contenant toutes les 
%       données :
%           DOUT.code = code station
%           DOUT.time = vecteur temps
%           DOUT.data = matrice de données traitées (NaN = invalide)
%
%       Spécificités du traitement:
%           - exploitation des déclenchements fichiers SAC existants)
%           - exploitation des signaux validés (images PS correspondantes)
%           - état des stations par interprétation des fichiers index
%           - création d'une page HTML "bulletin de déclenchements"
%           - création d'une carte de localisation par événement validé
%           - envoi d'un e-mail lors de nouveaux déclenchements

%   Auteurs: F. Beauducel + S. Bazin, OVSG-IPGP
%   Création : 2003-08-19
%   Mise à jour : 2007-07-03

X = readconf;

if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 4, nograph = 0; end

% Initialisation des variables

rcode = 'RAP';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
ST = readst(G.cod,G.obs,1);
ix = find(~strcmp(ST.ali,'-'));
nx = length(ix);

stype = 'T';
email = 'rap@ovsg.univ-ag.fr';
tdeb = datenum(2003,4,1);                   % début RAP OVSG

% Initialisation des constantes
last = 2;                                   % délai de déclenchement "normal" (en jour)
dtmax = 1.4/1440;                           % délai max événement/hypocentre (en jour)
xylim = [-64 -59.5 13.5 18.5];              % limites carte hypo
xylim2 = [-62.2 -60.7 15.5 16.75];         % limites carte réseau
gris = .8*[1,1,1];                          % couleur gris clair
gris2 = .5*[1,1,1];                         % couleur gris foncé
latkm = 6370*pi/180;                        % valeur du degré latitude (en km)
lonkm = latkm*cos(16*pi/180);               % valeur du degré longitude (en km)
pgalim = [1e-5,2];                          % limites PGA (graphe)
dhplim = [1,500];                           % limites distances hypocentrales (graphe)

% Type de sol (fichier "type.txt" de la station) et couleur associée
Tsol = {{'ROCHER','SOL'},{[0,0,1],[1,0,0]}};

sname = G.nom;
G.cpr = 'OVSG-IPGP/RAP/CDSA';
G.lg2 = 'logo_rap.jpg';

pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
G.dsp = sprintf('%s',pftp);
fhyp = sprintf('%s/past/HYPO_past.mat',X.RACINE_OUTPUT_MATLAB);
ftmp1 = '/tmp/rap_tmp.png';
ftmp2 = '/tmp/rap_tmp.txt';
prog = X.PRGM_CONVERT;
pwww = sprintf('%s/%s',X.RACINE_WEB,X.MATLAB_PATH_WEB);
pgra = sprintf('%s/%s',X.RACINE_WEB,X.MKGRAPH_PATH_WEB);
pmap = 'Graphes/cartes';
psig = 'Graphes/signaux';
fwww = [pwww '/rap_list.htm'];
flst = 'rap_list.htm';
fdon = [pftp '/RAP_declenchements.txt'];
fpga = [pftp '/RAP_PGA.txt'];
frap = 'LISTE-VERIFICATION';

css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
ftf = sprintf('face="%s"',X.FONT_FACE_WEB);
ftt = sprintf('FONT %s size="6"',ftf);
ft2 = sprintf('FONT %s size="2"',ftf);
ft3 = sprintf('FONT %s size="3"',ftf);
fts = sprintf('FONT face="Courier New,Courier" size="3"');

notes = sprintf(['Ce tableau présente la liste complète de tous les événements déclenchés ' ...
    'sur une ou plusieurs stations RAP, et localisés par le réseau courte-période OVSG. ' ...
    'Les sismogrammes par station sont disponibles uniquement si l''événement a été validé.' ...
    'Voir aussi les fichiers <A href="%s/%s/DONNEES/%s">%s</A> ' ...
    'et <A href="%s/%s/RAP_PGA.txt">RAP_PGA.txt</A>.'],X.WEB_RACINE_FTP,G.ftp,frap,frap,X.WEB_RACINE_FTP,G.ftp);

matp = sprintf('<I>rap.m</I> (c) FB+SB, OVSG-IPGP, %4d-%02d-%02d %02d:%02d:%02.0f',datevec(now));


% Efface les cartes si mat==0
if mat == 0
    delete(sprintf('%s/%s/*_map.png',pftp,pmap));
    delete(fpga);
    disp('Création de toutes les cartes et recalcul des PGA...');
end

% ==================================================================
% chargement des hypocentres et lignes de cotes Antilles
load(fhyp,'DH','t','d','cse','c_pta');
k = find(t >= tdeb);
DH.tps = [t(k);DH.tps];
DH.lat = [d(k,1);DH.lat];
DH.lon = [d(k,2);DH.lon];
DH.dep = [d(k,3);DH.dep];
DH.mag = [d(k,4);DH.mag];
DH.erh = [d(k,5);DH.erh];
DH.msk = [d(k,6);DH.msk];
DH.typ = [d(k,7);DH.typ];
DH.cod = [cse(k);DH.cod];
clear t d cse k
disp(sprintf('Fichier: %s importé.',fhyp));

% Exploitation des déclenchements (fichiers SAC)
[s,ss] = unix(sprintf('find %s/SAC/ -mindepth 3 -maxdepth 3 -name "*.0-0.SAC"',pftp));
nfsac = char(strread(ss,sprintf('%s/SAC/%%s',pftp)));
sit = cellstr(nfsac(:,29:32));
yy = str2double(cellstr(nfsac(:,9:12)));
mm = str2double(cellstr(nfsac(:,14:15)));
dd = str2double(cellstr(nfsac(:,17:18)));
hh = str2double(cellstr(nfsac(:,20:21)));
nn = str2double(cellstr(nfsac(:,23:24)));
ss = str2double(cellstr(nfsac(:,26:27)));
t = datenum(yy,mm,dd,hh,nn,ss);
dfname = cellstr(nfsac(:,1:32));   % dfname = nom sans extension

% tri par ordre chronologique
[t,i] = sort(t);
sit = sit(i);  dfname = dfname(i);
d = zeros(length(t),6);


% traitement par séisme validé RAP (tous les fichiers existants)
new_evt = [];
for i = 1:length(t)
	pam = sprintf('%04d/%02d',yy(i),mm(i));
    f_ps = sprintf('%s/SAC/%s.0.ps',pftp,dfname{i});
    f_txt = sprintf('%s/rap/%s.txt',X.RACINE_OUTPUT_MATLAB,dfname{i});
    f_png = sprintf('%s/%s/%s/%s_%s.png',pftp,psig,pam,datestr(t(i),30),sit{i});
    f_map = '';
	
    % recherche dans la liste d'hypocentres
    k = find(abs(t(i)-DH.tps) < dtmax);
    [zz,kk] = sort(abs(t(i)-DH.tps(k)));
    if isempty(k)
        %disp(sprintf('Warning: pas d''hypocentre pour %s %s !',sit{i},datestr(t(i))));
    else
        d(i,1) = k(kk(end));
        kk = find(strcmp(sit(i),ST.ali));
        if isempty(kk)
%             disp(sprintf('Warning: données associées à une station %s non valide !',sit{i}));
        else    
            d(i,4) = sqrt((latkm*(DH.lat(d(i,1)) - ST.geo(kk,1))).^2 + (lonkm*(DH.lon(d(i,1)) - ST.geo(kk,2))).^2 + (DH.dep(d(i,1)) - ST.geo(kk,3)/1000).^2);
            %disp(sprintf(' %s: hypocentre trouvé le %s - d = %1.0f km',sit{i},datestr(DH.tps(d(i,1))),d(i,4)));
        end
        f_map = sprintf('%s/%s/%s/%s_rap_lois.png',pftp,pmap,pam,datestr(DH.tps(k(1)),30));
    end
    
	%keyboard
	
    % graphe accélérogramme
    if exist(f_ps,'file')
        %if (exist(f_png,'file') == 0 | exist(f_map,'file') == 0) & ~isempty(k)
	%	k
        %    kk = find(strcmp(sit(i),ST.ali));
	%    % Si les stations ont été lues en ignorant les stations invalides, on ne peut pas faire les graphes des stations désormais invalides
	%    if isempty(kk)
	%	    disp(sprintf('Warning: impossible de générer un graphe pour les données d''une station %s non valide !',sit{i}));
	%    else
	%	    % chargement des SAC et calcul du PGA
	%	    %f0 = sprintf('%s/SAC/%s.0-0.SAC',pftp,dfname{i});
	%	    f1 = sprintf('%s/SAC/%s.0-1.SAC',pftp,dfname{i});
	%	    f2 = sprintf('%s/SAC/%s.0-2.SAC',pftp,dfname{i});
	%	    if exist(f1,'file') & exist(f2,'file')
	%		[x1,h] = loadsac(f1);
	%		disp(sprintf('Fichier: %s chargé.',f1))
	%		size(x1)
	%		[x2,h] = loadsac(f2);
	%		disp(sprintf('Fichier: %s chargé.',f2))
	%		size(x2)
	%		% ===============================================================
	%		% raccourci (temporaire): utilisation de l'étalonnage au temps t(i)
	%		[dc,C] = calib(t(i),1:3,ST.clb(kk));
	%		dx = complex((x2-mean(x2))*C.et(3)*C.ga(3) + C.of(3),(x1-mean(x1))*C.et(2)*C.ga(2) + C.of(2));
	%		d(i,2) = max(abs(dx));
	%		d(i,3) = angle(dx(find(abs(dx)==d(i,2))));
	%		disp(sprintf(' PGA = %g %s, direction %2.0f °N',d(i,2),C.un{1},90-d(i,3)*180/pi))
	%		% ===============================================================
	%		d(i,5) = find(strcmp(ST.typ(kk),Tsol{1}));
	%		d(i,6) = 1;
	%		fid = fopen(fpga,'at');
	%		fprintf(fid,'%s|%s|%1.5f|%1.5f|%1.1f|%1.1f|%g|%2.0f|%1.1f\n', ...
	%		    dfname{i}(9:end),datestr(DH.tps(d(i,1)),31),DH.lat(d(i,1)),DH.lon(d(i,1)),DH.dep(d(i,1)),DH.mag(d(i,1)),d(i,2),90-d(i,3)*180/pi,d(i,4));
	%		fclose(fid);
	%		disp(sprintf('Fichier: %s mis à jour.',fpga));
	%	    end
	%	    % convertion PS2PNG (via GS en attendant CONVERT)
	%	    unix(sprintf('gs -q -sOutputFile=%s -sDEVICE=pngmono -r150 -dNOPAUSE -dBATCH %s',ftmp1,f_ps));
	%			unix(sprintf('mkdir -p %s/%s/%s',pftp,psig,pam));
	%	    unix(sprintf('%s -rotate 90 -scale 792x612 %s %s',prog,ftmp1,f_png));
	%	    disp(sprintf('Graphe:  %s créé.',f_png));
	%    end
        %end
    else
        d(i,2) = NaN;
        if exist(f_txt,'file') == 0
            new_evt = [new_evt,{sprintf('%s : %s',sit{i},datestr(t(i)))}];
	    unix(sprintf('mkdir -p %s/rap/%s',X.RACINE_OUTPUT_MATLAB,dfname{i}(1:7)));
            unix(sprintf('touch %s',f_txt));
        end
    end
end
% => la matrice d contient:
%   1. les indices d'hypocentres dans DH
%   2. la valeur d'accélération max (en g)
%   3. la direction d'accélération max (en rad)
%   4. la distance épicentrale (en km)
%   5. type de sol (1 ou 2)
%   6. flag: 1 = refaire la carte

% Envoi d'un mail d'alerte en cas de nouveau séisme traité
if ~isempty(new_evt)
    f = '/tmp/new_rap.txt';
    fid = fopen(f,'wt');
    for i = 1:length(new_evt)
        fprintf(fid,'%s\n',new_evt{i});
    end
    fclose(fid);
    unix(sprintf('mail %s -s ''Nouveaux déclenchements RAP'' < %s',email,f));
    disp(sprintf('Email: envoyé à %s',email));
end

% ==================================================================
% Création d'un fichier TXT et d'une page HTML
stitre = 'Liste des déclenchements RAP';
kk = zeros(size(DH.tps));
kk(d(find(d(:,1)),1)) = 1;
kh = flipud(find(kk));
fid0 = fopen(fdon,'wt');
f = sprintf('%s/%s',pwww,flst);
fid = fopen(f,'wt');
trap = sprintf('YYYY-MM-DD HH:MM:SS.ss Latitude Longitude Dep M_d ErH Code');
fprintf(fid0,'%s  Stations\n',trap);
% en-tete HTML
fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>%s</HEAD>\n',stitre,datestr(tnow,'dd-mmm-yyyy'),css);
fprintf(fid,'<FORM>\n');
% notes
fprintf(fid,'<P><B>Note :</B> %s</P>\n',notes);
fprintf(fid,'<P><%s><PRE>',fts);
fprintf(fid,'<I>  %s</I>\n',trap);
tps0 = datenum(tnow);
for i = 1:length(kh)
    ki = kh(i);
    k = find(ki==d(:,1));
    sh{i} = sit(k);
    srap = sprintf('%4d-%02d-%02d %02d:%02d:%05.2f %8.5f %8.5f %3.0f %3.1f %3.0f %s', ...
        datevec(DH.tps(ki)),DH.lat(ki),DH.lon(ki),DH.dep(ki),DH.mag(ki),DH.erh(ki),DH.cod{ki});
	pam = sprintf('%s/%s',datestr(DH.tps(ki),'yyyy'),datestr(DH.tps(ki),'mm'));
    f_map = sprintf('%s_rap_lois',datestr(DH.tps(ki),30));
    if i == 1
        map_last = sprintf('%s/%s/%s/%s.png',pftp,pmap,pam,f_map);
    end
    if tps0 > floor(DH.tps(ki))
        fprintf(fid,'\n');
        tps0 = floor(DH.tps(ki));
    end
    fprintf(fid0,srap);
    fprintf(fid,'  %s <A href="%s/%s/%s/%s/%s.png">Carte</A>',srap,X.WEB_RACINE_FTP,G.ftp,pmap,pam,f_map);
    
    % Carte hypocentre
    f = sprintf('%s/%s/%s/%s.png',G.dsp,pmap,pam,f_map)
    if exist(f,'file') == 0 | any(d(k,6))
        figure(1), clf, orient tall
        % --- Titre et statistiques
        G.tit = gtitle(sprintf('%s: événement du %s %+d',sname,datestr(DH.tps(ki)),G.utc),'');
		G.eta = datenum(tnow);
        G.inf={ ...
                sprintf('Localisation OVSG:'), ...
                sprintf('Lat = {\\bf%s}, Lon = {\\bf%s}',ll2dms(DH.lat(ki),'lat'),ll2dms(DH.lon(ki),'lon')), ...
                sprintf('Prof = {\\bf%g km}, Md = {\\bf%1.1f}, Code = {\\bf%s}',DH.dep(ki),DH.mag(ki),DH.cod{ki}), ...
                sprintf('PGA (mg):'), ...
            };
        nv = 6;
        [z,ii] = sort(-d(k,2));
        for j = 1:length(sh{i})
            G.inf = [G.inf,cellstr(sprintf('{\\bf%s}: %0.3f',sit{k(ii(j))},d(k(ii(j)),2)*1000))];
        end
    
        % --- Cartes
        subplot(7,1,1:5), extaxes
        pcontour(c_pta,[],gris), axis(xylim2), dd2dms(gca,1), set(gca,'FontSize',8)
        hold on
        alpha = 0:.01:2*pi;
        for rh = [1,2,5,10,15,20:10:150,200:100:500]
            rd = sqrt(rh^2 - DH.dep(ki)^2);
            if isreal(rd)
                plot(cos(alpha)*rd/lonkm + DH.lon(ki),sin(alpha)*rd/latkm + DH.lat(ki),':','Color',gris2)
                text(DH.lon(ki) + rd/lonkm*[1,-1,0,0],DH.lat(ki) + rd/latkm*[0,0,1,-1],num2str(rh), ...
                    'FontSize',6,'Color',gris2,'HorizontalAlignment','center','Clipping','on')
            end
        end
		
        h = rectangle('Position',[xylim2(1)+.02,xylim2(3)+.02,0.35,0.16]); set(h,'FaceColor','w');
        plot([ST.geo(ix,2);xylim2(1)+.07],[ST.geo(ix,1);xylim2(3)+.1],'o','MarkerSize',6,'MarkerFaceColor','b','MarkerEdgeColor','k')
        spga = .3/max(d(k,2));
        for ii = 1:length(k)
            kk = find(strcmp(sit(k(ii)),ST.ali));
	    % Si les stations ont été lues en ignorant les stations invalides, on ne peut pas faire les graphes des stations désormais invalides
	    if ~isempty(kk)
		    plot(ST.geo(kk,2) + spga*d(k(ii),2)*[0,cos(d(k(ii),3))],ST.geo(kk,1) + spga*d(k(ii),2)*[0,sin(d(k(ii),3))],'-r')
	    end
        end
        plot(xylim2(1)+.05+[0,.05],xylim2(3)+.15+[0,0],'-r')
        plot([DH.lon(ki);xylim2(1)+.07],[DH.lat(ki);xylim2(3)+.05],'p','MarkerSize',15,'MarkerEdgeColor','w','MarkerFaceColor','k')
        text(xylim2(1)+.13,xylim2(3)+.15,sprintf('Echelle PGA = %0.2f mg',50/spga),'FontSize',8);
        text(xylim2(1)+.13,xylim2(3)+.1,'Stations','FontSize',8);
        text(xylim2(1)+.13,xylim2(3)+.05,'Hypocentre OVSG','FontSize',8);
        hold off
        
        % petite carte Antilles en encart
		pos = get(gca,'Position');
        axes('position',[pos(1),pos(2)+pos(4)-.15,.15,.15])
        pcontour(c_pta,[],'k'), axis(xylim), set(gca,'XTick',[],'YTick',[])
        hold on
        plot(DH.lon(ki),DH.lat(ki),'p','MarkerSize',15,'MarkerEdgeColor','w','MarkerFaceColor','k')
        hold off
        
        % --- Loi d'atténuation
        subplot(7,1,6:7), extaxes
        %loi = [0.73352,-0.0057212,-3.55397]; % loi 1
%         loi = [0.611377,-0.00584334,-3.216674]; % loi 2 (avec M USGS)
        xdhp = logspace(log10(dhplim(1)),log10(dhplim(2)));
        %xpga = 10.^(loi(1)*DH.mag(ki) + loi(2)*xdhp - log10(xdhp) + loi(3));
	xpga_b3_rocher=attenuation(1,DH.mag(ki),xdhp,DH.dep(ki));
	xpga_b3_sol=attenuation(2,DH.mag(ki),xdhp,DH.dep(ki));
	xpga_kanno_shallow=attenuation(11,DH.mag(ki),xdhp,DH.dep(ki));
	xpga_kanno_deep=attenuation(12,DH.mag(ki),xdhp,DH.dep(ki));
        plot(xdhp,xpga_b3_rocher,'--b',xdhp,xpga_b3_sol,'--r',xdhp,xpga_kanno_shallow,'--g',xdhp,xpga_kanno_deep,'--y');
        hold on
        kk = find(d(k,5)==1);
        plot([.9;d(k(kk),4)],[1e-6;d(k(kk),2)],'dk','MarkerFaceColor',Tsol{2}{1})
        kk = find(d(k,5)~=1);
        plot([.9;d(k(kk),4)],[1e-6;d(k(kk),2)],'dk','MarkerFaceColor',Tsol{2}{2})
        hold off
        set(gca,'XLim',dhplim,'YLim',pgalim,'Xscale','log','Yscale','log','FontSize',8)
        legend([{'Loi B-Cube'},{'Loi B-Cube au sol'},{'Loi Kanno shallow'},{'Loi Kanno deep'},Tsol{1}],3)
        grid on
        xlabel('Distance du foyer (km)')
        ylabel('Accélération maximale (g)')
        
        %matpad(scopy,0,'data/logo_rap.jpg');
        %print(gcf,'-dpng','-painters','-r100',f);
        %disp(sprintf('Graphe:  %s créé.',f));
		unix(sprintf('mkdir -p %s/Graphes/cartes/%s',pftp,pam));
        mkgraph(sprintf('cartes/%s/%s',pam,f_map),G);
        close(1);
    end

    ss = '';
    for j = 1:length(sh{i})
        fprintf(fid0,' %s',sh{i}{j});
		pam = sprintf('%s/%s',datestr(t(k(j)),'yyyy'),datestr(t(k(j)),'mm'));
    	fsig = sprintf('%s/%s/%s_%s.png',psig,pam,datestr(t(k(j)),30),sit{k(j)});
    	if exist(sprintf('%s/%s',pftp,fsig),'file')
	        fprintf(fid,' <A href="%s/%s/%s">%s</A>',X.WEB_RACINE_FTP,G.ftp,fsig,sh{i}{j});
    	else
    		fprintf(fid,' %s',sh{i}{j});
    	end
        ss = [ss,' ',sh{i}{j}];
    end
    fprintf(fid0,'\n');
    fprintf(fid,'\n');
    %disp(sprintf('- Hypocentre: %s sur %s',datestr(DH.tps(kh(i))),ss));
end
fprintf(fid,'</PRE>\n');
% signature
fprintf(fid,'<BR><TABLE><TR><TD><IMG src="/images/logo_ipgp.jpg"><IMG src="/images/logo_rap.jpg"></TD>');
fprintf(fid,'<TD>%s</TD></TR></TABLE>\n',matp);
fclose(fid0);  disp(sprintf('Fichier: %s créé.',fdon));
fclose(fid);  disp(sprintf('Fichier: %s/%s créé.',pwww,flst));

% ===================================================================
% Création du fichier LISTE-VERIFICATION
[s,ss] = unix(sprintf('find %s/DONNEES/ -mindepth 3 -maxdepth 3 -name "d.*"',pftp));
fd = char(strread(ss,sprintf('%s/DONNEES/%%s',pftp)));
fd = fd(:,9:end);
td = datenum(str2double([cellstr(fd(:,3:6)),cellstr(fd(:,8:9)),cellstr(fd(:,11:12)),cellstr(fd(:,14:15)),cellstr(fd(:,17:18)),cellstr(fd(:,20:21))]));
sd = cellstr(fd(:,23:end));

f = sprintf('%s/DONNEES/%s',pftp,frap);
fid = fopen(f,'wt');
for i = length(kh):-1:1
    ki = kh(i);
    k = find(ki==d(:,1));
    shi = sit(k);
    for j = 1:length(shi)
    	fsig = sprintf('%s/%s/%s/%s_%s.png',psig,datestr(t(k(j)),'yyyy'),datestr(t(k(j)),'mm'),datestr(t(k(j)),30),sit{k(j)});
    	if exist(sprintf('%s/%s',pftp,fsig),'file')
            ks = find(strcmp(sit{k(j)},ST.ali));
            kd = find(abs(td-t(k(j))) < 1/1440 & strcmp(sd,shi{j}));
            if length(kd) == 1
                fprintf(fid,'RAP-IPGP|%s|%4d-%02d-%02d %02d:%02d:%02.0f+00|%1.5f|%1.5f|%4d-%02d-%02d %02d:%02d:%05.2f+00|%1.5f|%1.5f|%1.0f|%1.1f|%s|ovsg|unknown|unknown|unknown|unknown|unknown|unknown|unknown|unknown|unknown|unknown|unknown|%s|O\n', ...
                    shi{j},datevec(t(k(j))),ST.geo(ks,1:2),datevec(DH.tps(ki)),DH.lat(ki),DH.lon(ki),DH.dep(ki),DH.mag(ki),deblank(DH.cod{ki}),fd(kd,:));
            else
                %disp(sprintf('Problème: pas de fichier de données correspondant à %s %s (+/- 1 min)',shi{j},datestr(t(k(j)))))
            end
        end
    end
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));


% ===================================================================
% Etat des stations (derniers index déclenchement)
etats = zeros(size(ix));
acquis = zeros(size(ix));

DI = dir([pftp '/INDX/liste.derniers.index.*']);
diname = char(DI.name);
diname = cellstr(diname(:,22:end));

for si = 1:nx
    st = ix(si);
    scode = lower(ST.cod{st});
    alias = ST.ali{st};
    tm = now;

    k = find(strcmp(alias,diname));
    if ~isempty(k)
        if DI(k).bytes > 0
            etats(si) = 100;
            % lecture du fichier index
            f = sprintf('%s/INDX/%s',pftp,DI(k).name);
            unix(sprintf('tail -n1 %s > %s',f,ftmp2));
            ss1 = char(textread(ftmp2,'%s','delimiter',''));
            if length(ss1) >= 46
                yy = str2double(ss1(6:9));
                mm = str2double(ss1(11:12));
                dd = str2double(ss1(14:15));
                hh = str2double(ss1(17:18));
                nn = str2double(ss1(20:21));
                ss = str2double(ss1(23:24));
                tm = datenum(yy,mm,dd,hh,nn,ss);
            else
                tm = 0;
            end
            if datenum(tnow) - tm < last
                acquis(si) = 100;
            end
        end
    end
    k = find(strcmp(sit,alias));
    if ~isempty(k)
        ke = k(end);
        sddc = datestr(t(ke));
		pam = sprintf('%s/%s',datestr(t(ke),'yyyy'),datestr(t(ke),'mm'));
        f_png = sprintf('%s/%s/%s/%s_%s.png',pftp,psig,pam,datestr(t(ke),30),sit{ke});
        f = sprintf('%s_ddc.png',lower(ST.cod{st}));
        unix(sprintf('cp -f %s %s/%s',f_png,pftp,f));
        unix(sprintf('cp -f %s %s/%s',f_png,pgra,f));
        disp(sprintf('Graphe:  %s mis à jour.',f));
    else
        sddc = 'pas de fichier traité';
    end
    sd = sprintf('%s %s',stype,sddc);
    if mat ~= -1
        mketat(etats(si),tm,sd,lower(ST.cod{st}),G.utc,acquis(si))
    end

end

f = sprintf('%s_ddc.png',rcode);
unix(sprintf('cp -f %s %s/%s',map_last,pftp,f));
unix(sprintf('cp -f %s %s/%s',map_last,pgra,f));
disp(sprintf('Graphe:  %s mis à jour.',f));

etat = mean(etats);
acqui = max(acquis);
if mat ~= -1
    mketat(etat,datenum(tnow),sprintf('%s %d %s',stype,nx,G.snm),rcode,G.utc,acqui)
    G.sta = [{rcode};lower(ST.cod(ix))];
    G.ali = [{'Carte'};ST.ali(ix)];
    G.lnk = {{'Liste',flst}};
    htmgraph(G);
end

timelog(rcode,2)
