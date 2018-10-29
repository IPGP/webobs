function locastat(mat,sta)
%LOCSTAT Construction des cartes de localisation des stations
%   LOCASTAT met à jour (si nécessaire) les cartes de localisation
%
%   LOCASTAT(MAT,STA) utilise les arguments:
%       - MAT = 0 : force la reconstruction de toutes les cartes
%       - STA = liste des codes de station à construire (cellule)

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2007-05-15
%   Mise à jour : 2009-10-27

if nargin < 1
    mat = 1;
end
if nargin < 2
	sta = 'xxxxx';
end

rcode = 'LOCASTAT';
timelog(rcode,1)

X = readconf;

M.mat = {'zone_cdsa';'z24_09';'z24_10';'z25_10'};
M.dat = {'z24-25_09-10.dat';'z24_09.dat';'z24_10.dat';'z25_10.dat'};
M.lim = [-65,-55,10,20,1200,1200; ...
		 -65,-60,15,20,6000,6000; ...
		 -65,-60,10,15,6000,6000; ...
		 -60,-55,10,15,6000,6000];
nodatavalue = -50;		% profondeur du niveau de la mer (nécessaire pour coller avec l'échelle des couleurs)
r0 = 2;				% décimation du MNT basse-résolution
r1 = 5;				% décimation du MNT haute-résolution
r3 = 1;				% décimation de la photo IGN
d1 = .7;			% taille de l'encart n°1 (en degré)
d2 = .07;			% taille de l'encart n° 2 (en degré)
d3 = 300;			% taille de l'encart n°3 = photo IGN (en mètre)
rign = .5;			% résolution des photos IGN (en mètre)
xsc1 = 20;			% échelle de l'encart n°1 (en km)
dxsc1 = 2;			% offset échelle de l'encart n°1 (en km)
xsc2 = 2;			% échelle de l'encart n°2 (en km)
dxsc2 = .2;			% offset échelle de l'encart n°2 (en km)
xsc3 = 100;			% échelle de l'encart n°3 (en mètre)
dxsc3 = d3/70;			% offset échelle par rapport au coin bas-droit (en mètre)
dpi = 76;			% résolution de l'image PNG finale
lw = 1.5;			% épaisseur du trait des cadres
feclair = 1.6;			% facteur d'éclaircissement des couleurs
pcart = 0.05;			% taille verticale du cartouche bas (en fraction de l'image)
cmap = filtre(load(sprintf('%s/landcolor2.dat',X.RACINE_DATA_MATLAB)),feclair);
blanc = .95*[1,1,1];
noir = [0,0,0];
gris = filtre(noir,feclair);
copyright = sprintf('{\\bf \\copyright %s} - DEM: SRTM (NASA-NGA)',X.COPYRIGHT);
pign = sprintf('%s/JPG',X.STATIONS_PATH_PHOTO50CM);


% ---- Reconstruit les MNT au format Matlab (si inexistants)

for i = 1:length(M.mat)
	f_past = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,M.mat{i});
	if ~exist(f_past,'file')
		disp(sprintf('... must rebuild DEM "%s"...',M.mat{i}));
		z = load(sprintf('%s/%s',X.RACINE_DATA_MATLAB,M.dat{i}));
		k = find(z==-9999);
		z(k) = nodatavalue;
		x = linspace(M.lim(i,1),M.lim(i,2),M.lim(i,5)+1);
		x(end) = [];
		y = flipud(linspace(M.lim(i,3),M.lim(i,4),M.lim(i,6)+1)');
		y(end) = [];
		if i == 1
			x0 = x; y0 = y; z0 = z;
			save(f_past,'x0','y0','z0');
		else
			save(f_past,'x','y','z');
		end
		clear x y z
		disp(sprintf('File: %s created...',f_past))
	end
end

% Charge le MNT basse-résolution (utilisé dans tous les cas)
f_past = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,M.mat{1});
load(f_past);
disp(sprintf('File: %s loaded...',f_past))

% Charge toutes les stations opérationnelles de la base
ST = readst('','',0);

for i = 1:length(ST.cod)
	p = sprintf('%s/%s',X.RACINE_DATA_STATIONS,ST.cod{i});
	f = sprintf('%s_map',lower(ST.cod{i}));
	fimg = sprintf('%s/%s.png',p,f);
	futm = sprintf('%s/%s_pos.utm',p,lower(ST.cod{i}));
	if exist(fimg,'file')
		IM = imfinfo(fimg);
		timg = floor(datesys2num(IM.FileModDate));
	else
		timg = 0;
	end
	% reconstruit dans 4 cas:
	%	- le fichier n'existe pas
	%	- l'option MAT=0 est utilisée
	%	- la station est explicitement demandée avec STA
	%	- la date de l'image est plus ancienne que la date de positionnement
	if ((~exist(fimg,'file') | timg <= ST.dte(i)) & nargin < 2) | ~isempty(strmatch(upper(sta),ST.cod(i))) | mat == 0
		figure, set(gcf,'PaperPosition',[0,0,10,5*(1+pcart)],'PaperSize',[5*(1+pcart),10],'Color',[1,1,1],'InvertHardCopy','off')
		disp(sprintf('Making location map for %s: %s [%s] ...',ST.ali{i},ST.nom{i},ST.cod{i}))
		
		% tracé de la carte basse-résolution (n°0)
		axes('Position',[0,pcart/(1+pcart),.25,1-pcart/(1+pcart)]);
		mnt(x0(1:r0:end),y0(1:r0:end),z0(1:r0:end,1:r0:end),cmap,.4)
		set(gca,'XLim',[-65,-59],'Color',cmap(1,:),'XTick',[],'YTick',[],'Linewidth',.1)
		hold on,  [c,h] = contour(x0,y0,z0,[0,0]);  set(h,'EdgeColor',gris),  hold off

		% ----- tracé des cartes à partir du MNT haute-résolution
		k = find(ST.geo(i,2) >= M.lim(:,1) & ST.geo(i,2) < M.lim(:,2) & ST.geo(i,1) >= M.lim(:,3) & ST.geo(i,1) < M.lim(:,4));
		if length(k) > 1
			f_past = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,M.mat{k(2)});
			load(f_past)
			disp(sprintf('File: %s loaded...',f_past))
			xy1 = [ST.geo(i,2)+d1*.5*[-1,1],ST.geo(i,1)+d1*.5*[-1,1]];
			xy2 = [ST.geo(i,2)+d2*.5*[-1,1],ST.geo(i,1)+d2*.5*[-1,1]];
			xy3 = [ST.wgs(i,1)+d3*.5*[-1,1],ST.wgs(i,2)+d3*.5*[-1,1]];
			
			% ----- tracé des cadres sur la carte n°0
			hold on
			plot(xy1([1,2,2,1,1]),xy1([3,3,4,4,3]),'k-','Linewidth',lw)
			cible(ST.geo(i,2),ST.geo(i,1))
			hold off
			
			% ---- tracé de la carte moyenne-résolution (encart n°1)
			ax1 = axes('Position',[.25,(.5+pcart)/(1+pcart),.25,.5/(1+pcart)]);
			kx = find(x >= xy1(1) & x <= xy1(2));
			ky = find(y >= xy1(3) & y <= xy1(4));
			mnt(x(kx(1:r1:end)),y(ky(1:r1:end)),z(ky(1:r1:end),kx(1:r1:end)),cmap,.4)
			set(gca,'XLim',xy1(1:2),'YLim',xy1(3:4),'Color',cmap(1,:),'XTick',[],'YTick',[],'Linewidth',.1)
			hold on
			[c,h] = contour(x(kx),y(ky),z(ky,kx),[0,0]);  set(h,'EdgeColor',gris)
			
			% ----- tracé des cadres sur la carte n°1
			ax = axis;
			plot(xy2([1,2,2,1,1]),xy2([3,3,4,4,3]),'k-','Linewidth',lw)
			cible(ST.geo(i,2),ST.geo(i,1))
			% échelle (convertir le km en degré)
			degkm = 6370*pi*cos(ax(3)*pi/180)/180;	% valeur du degré de longitude à cette latitude (en km)
			xe = ax(2) - (xsc1/2 + dxsc1)/degkm;
			ye = ax(3) + dxsc1/degkm;
			plot(xe + xsc1*.5*[-1,-1,1,1]/degkm,ye + [dxsc1,0,0,dxsc1]/degkm,'-','Color',noir,'Linewidth',2)
			text(xe,ye,sprintf('%g km',xsc1),'Color',noir,'Fontsize',12,'FontWeight','bold', ...
					'HorizontalAlignment','center','VerticalAlignment','bottom')
			hold off

			% ---- tracé de la carte haute-résolution (encart n°2)
			%axes('Position',[.25,.1,.25,.45]);
			ax2 = axes('Position',[.25,(.1+pcart)/(1+pcart),.2,.4/(1+pcart)]);
			kx = find(x >= xy2(1) & x <= xy2(2));
			ky = find(y >= xy2(3) & y <= xy2(4));
			mnt(x(kx),y(ky),z(ky,kx),cmap,.4)
			set(gca,'XLim',xy2(1:2),'YLim',xy2(3:4),'Color',cmap(1,:),'XTick',[],'YTick',[],'Linewidth',.1)
			hold on
			[c,h] = contour(x(kx),y(ky),z(ky,kx),[0,0]);  set(h,'EdgeColor',gris)
			ax = axis;
			cible(ST.geo(i,2),ST.geo(i,1))
			% échelle (convertir le km en degré)
			degkm = 6370*pi*cos(ax(3)*pi/180)/180;	% valeur du degré de longitude à cette latitude (en km)
			xe = ax(2) - (xsc2/2 + dxsc2)/degkm;
			ye = ax(3) + dxsc2/degkm;
			plot(xe + xsc2*.5*[-1,-1,1,1]/degkm,ye + [dxsc2,0,0,dxsc2]/degkm,'-','Color',noir,'Linewidth',2)
			text(xe,ye,sprintf('%g km',xsc2),'Color',noir,'Fontsize',12,'FontWeight','bold', ...
					'HorizontalAlignment','center','VerticalAlignment','bottom')
			ax = axis;
			plot(ax([1,2,2,1,1]),ax([3,3,4,4,3]),'k-','Linewidth',.1)
			hold off
			mmz = minmax(z(ky,kx));
			if mmz(1) == nodatavalue
				mmz(1) = 0;
			end
			
			if diff(mmz) <= 0
				text(ST.geo(i,2),ST.geo(i,1),{'PLOUF !',''},'VerticalAlignment','bottom','HorizontalAlignment','center','FontSize',14)
			else
				% profil EW
				ax21 = axes('Position',[.25,pcart/(1+pcart),.2,.1/(1+pcart)]);
				xp = x(kx); yp = z(round(mean(ky)),kx);
				fill(xp([1,1:end,end,1]),[mmz(1),yp,mmz(1),mmz(1)],gris)
				set(gca,'XLim',xy2(1:2),'YLim',mmz), axis off
				hold on, plot(repmat(ST.geo(i,2),[1,2]),mmz,'-','Color',noir,'Linewidth',.1), hold off
				text(xy2(2),mmz(1),sprintf(' %1.0f m',mmz(1)),'FontSize',9','VerticalAlignment','bottom');
				% calcul de l'exagération verticale...
				dar = daspect(gca);
				figps = get(gcf,'PaperSize');
				figpp = get(gcf,'Position');
				axepp = get(gca,'Position');
				rxy = (figps(2)/figps(1)) * (axepp(3)/axepp(4));
				%disp(sprintf('rxy = %g',rxy))
				text(xy2(2),mean(mmz),sprintf('  x %1.1f',1000*degkm*dar(1)/dar(2)/rxy),'FontSize',8');
				text(xy2(2),mmz(2),sprintf(' %1.0f m',mmz(2)),'FontSize',9','VerticalAlignment','top');
				
				% profil NS
				ax21 = axes('Position',[.45,(.1+pcart)/(1+pcart),.05,.4/(1+pcart)]);
				xp = z(ky,round(mean(kx)))'; yp = y(ky);
				fill([mmz(1),xp,mmz(1),mmz(1)],yp([1,1:end,end,1]),gris)
				set(gca,'XLim',mmz,'YLim',xy2(3:4),'XDir','reverse'), axis off
				hold on, plot(mmz,repmat(ST.geo(i,1),[2,1]),'-','Color',noir,'Linewidth',.1), hold off
			end
			
			%---- extraction de la photo IGN (BDOrtho 50 cm)
			% recherche des photo contenant la station et des 8 photos adjacentes
			%	A31	A32	A33
			%	A21	A22	A23
			%	A11	A12	A13
			% note: la photo finale ne doit pas dépasser la taille d'une dalle unitaire (1 km), sinon l'algorithme ne marche plus...
			ignxy = [floor(ST.wgs(i,1)/1000),ceil(ST.wgs(i,2)/1000)];
			%fign = sprintf('%s-%04d-%04d-u20n.tif',pign,ignxy);
			fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1),ignxy);
			if exist(fign,'file')
				% ----- tracé du cadre sur la carte n°2 (conversion UMT - WGS nécessaire)
				%xy3geo = utm2geo20([xy3([1,2,2,1,1])',xy3([3,3,4,4,3])']);
				%axes(ax2), hold on
				%plot(xy3geo(:,2),xy3geo(:,1),'k-','Linewidth',lw)
				%hold off
				
				I = imread(fign);
				disp(sprintf('Image: %s loaded.',fign));
				A22 = imresize(I,size(I)/r3);
				Z = uint8(double(A22)*0+128);	% dalle vide
				
				% dalle 21
				A21 = Z;
				if mod(ST.wgs(i,1),1000) < d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)-1,ignxy(1)-1,ignxy(2));
					if exist(fimg,'file')
						A21 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 23
				A23 = Z;
				if mod(ST.wgs(i,1),1000) > 1000-d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)+1,ignxy(1)+1,ignxy(2));
					if exist(fimg,'file')
						A23 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 12
				A12 = Z;
				if mod(ST.wgs(i,2),1000) < d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1),ignxy(1),ignxy(2)-1);
					if exist(fimg,'file')
						A12 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 32
				A32 = Z;
				if mod(ST.wgs(i,2),1000) > 1000-d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1),ignxy(1),ignxy(2)+1);
					if exist(fimg,'file')
						A32 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 11
				A11 = Z;
				if mod(ST.wgs(i,1),1000) < d3/2 & mod(ST.wgs(i,2),1000) < d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)-1,ignxy(1)-1,ignxy(2)-1);
					if exist(fimg,'file')
						A11 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 13
				A13 = Z;
				if mod(ST.wgs(i,1),1000) > 1000-d3/2 & mod(ST.wgs(i,2),1000) < d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)+1,ignxy(1)+1,ignxy(2)-1);
					if exist(fimg,'file')
						A13 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 31
				A31 = Z;
				if mod(ST.wgs(i,1),1000) < d3/2 & mod(ST.wgs(i,2),1000) > 1000-d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)-1,ignxy(1)-1,ignxy(2)+1);
					if exist(fimg,'file')
						A31 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% dalle 33
				A33 = Z;
				if mod(ST.wgs(i,1),1000) > 1000-d3/2 & mod(ST.wgs(i,2),1000) > 1000-d3/2
					fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)+1,ignxy(1)+1,ignxy(2)+1);
					if exist(fimg,'file')
						A33 = imresize(imread(fign),size(I)/r3);
						disp(sprintf('Image: %s loaded.',fign));
					end
				end
				
				% concaténation des 9 dalles
				A = [A31,A32,A33;A21,A22,A23;A11,A12,A13];

				xign = ((ignxy(1)-1)*1000):rign*r3:((ignxy(1)+2)*1000-rign);
				yign = (((ignxy(2)+1)*1000):-rign*r3:((ignxy(2)-2)*1000+rign))';
				kx = find(xign >= xy3(1) & xign <= xy3(2));
				ky = find(yign >= xy3(3) & yign <= xy3(4));

				axes('Position',[.5,pcart/(1+pcart),.5,1-pcart/(1+pcart)]);
				imagesc(xign(kx),yign(ky),A(ky,kx,:)), set(gca,'YDir','normal'); axis image, axis off
				hold on
				ax = axis;
				plot(ax([1,2,2,1,1]),ax([3,3,4,4,3]),'k-','Linewidth',.1)
				cible(ST.wgs(i,1),ST.wgs(i,2),15)
				% échelle
				xe = ax(2) - xsc3/2 - dxsc3;
				ye = ax(3) + dxsc3;
				h = rectangle('Position',[xe - xsc3/2 - dxsc3,ye - dxsc3,xsc3 + 2*dxsc3,4*dxsc3]);
				set(h,'FaceColor',noir);
				plot(xe + xsc3*.5*[-1,-1,1,1],ye + [dxsc3,0,0,dxsc3],'-','Color',blanc,'Linewidth',3)
				text(xe,ye,sprintf('%g m',xsc3),'Color',blanc,'Fontsize',14,'FontWeight','bold', ...
					'HorizontalAlignment','center','VerticalAlignment','bottom')
				hold off
				ign = 1;
			else
				ign = 0;
			end
			
			% ---- copyright (cartouche bas)
			axes('Position',[0,0,1,pcart/(1+pcart)]), axis([0,1,0,1]), axis off
			%text(0,.5,[{copyright};{sprintf('%s - F. Beauducel',datestr(now,1))}],'FontSize',10)
			text(0,.5,[copyright,sprintf(' / FB / %s',datestr(now,1))],'FontSize',10)
			if ign
				%text(1,.5,{'BD ORTHO \copyright IGN - Paris - 2004';'Reproduction interdite';'Licence n° 06 CUI-dom 0100 '}, ...
				text(1,.5,{'BD ORTHO \copyright IGN - Paris - 2004'}, ...
					'HorizontalAlignment','right','FontSize',10)
			end
		else
			disp(sprintf('** Warning: pas de MNT correspondant à la station %s !',ST.cod{i}))
		end
		ftmp = '/tmp/locastat.ps';
		print(gcf,'-dpsc','-loose','-painters',ftmp);
		unix(sprintf('%s -colors 256 -density %dx%d %s %s',X.PRGM_CONVERT,dpi,dpi,ftmp,fimg));
		disp(sprintf('Graphe:  %s créé.',fimg))
		close
		
		% Ecrit le fichier de coordonnées UTM ==> PLUS NECESSAIRE DEPUIS IGN.pm [FB]
		%fid = fopen(futm,'wt');
		%fprintf(fid,'%7.0f\n',ST.wgs(i,:));
		%fclose(fid);
	end
end

timelog(rcode,2)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fonction de tracé du marqueur
function cible(x,y,s)
if nargin < 3
	s = 7;
end
plot(x,y,'o','MarkerSize',s,'MarkerFaceColor',[1,0,0],'MarkerEdgeColor',[.2,.2,.2],'Linewidth',s/5)
plot(x,y,'o','MarkerSize',s + 2,'MarkerEdgeColor',.99*[1,1,1])


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fonction d'éclaircissement des couleurs RVB
function y=filtre(x,f)
if f == 1
    y = x;
else
    y = (x/f + 1 - 1/f);
end
