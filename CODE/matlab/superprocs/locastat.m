function locastat(sta)
%LOCSTAT Detailed location maps for WebObs nodes.
%   LOCASTAT updates (if necessary) the single location maps of
%	georeferenced nodes. The condition for map automatic update is one of
%	the following:
%   	- no existing map (new node),
%   	- node configuration file timestamp newer than map file timestamp.
%
%   LOCASTAT(STA) uses string or cell array of string STA as list of 
%	node IDs (or part of ID) to build or re-build. Use STA='*' to force
%	rebuild of all nodes.
%
%   LOCASTAT uses SRTM data for background DEM shading maps. For the right part of the graph,
%   it uses SRTM by default (but poor resolution), or any higher resolution DEM defined in 
%   CONF/LOCASTAT.rc, in ArcInfo format.
%    

%   Author: F. Beauducel/WEBOBS, IPGP
%   Created: 2007-05-15
%   Updated: 2017-09-05

WO = readcfg;

wofun = sprintf('WEBOBS{%s}',mfilename);

procmsg = sprintf(' %s',mfilename);
timelog(procmsg,1)

if nargin < 1
	sta = '';
elseif ischar(sta)
	sta = cellstr(sta);
end

P = readcfg(WO,WO.LOCASTAT);

NODES = readcfg(WO,WO.CONF_NODES);

% loads transmission information
trans = isok(P,'PLOT_TRANSMISSION');


ptmp = WO.PATH_TMP_WEBOBS;
wosystem(sprintf('mkdir -p %s',ptmp));

d0 = field2num(P,'FRAME0_WIDTH_KM',100);
d1 = field2num(P,'FRAME1_WIDTH_KM',30);
d2 = field2num(P,'FRAME2_WIDTH_KM',5);
d3 = field2num(P,'FRAME3_WIDTH_KM',1.5);
xsc1 = field2num(P,'FRAME1_SCALE_KM',10);
dxsc1 = d1/30;
xsc2 = field2num(P,'FRAME2_SCALE_KM',.2);	
dxsc2 = d2/30;
r2 = field2num(P,'FRAME2_RESAMPLING',200);	
xsc3 = field2num(P,'FRAME3_SCALE_KM',.5);
dxsc3 = d3*15;
r3 = field2num(P,'FRAME3_RESAMPLING',400);	
dpi = field2num(P,'DPI',80);
lw = field2num(P,'LINEWIDTH',1.5);
convertopt = field2str(WO,'CONVERT_COLORSPACE','-colorspace sRGB');

feclair = field2num(P,'COLOR_LIGHTENING',1.2);
laz = field2num(P,'LIGHT_AZIMUTH',-45);
lct = field2num(P,'LIGHT_CONTRAST',1);
sea = field2num(P,'SEACOLOR','[0.7,0.9,1]','notempty');
fcmap = field2str(P,'COLORMAP','landcolor');
if exist(fcmap,'file')
	cmap = str2num(fcmap);
else
	cmap = landcolor.^1.3;
end
demoptions = {'Interp','Azimuth',laz,'Contrast',lct,'LandColor',cmap,'SeaColor',sea,'Watermark',feclair};

pcart = 0.05;		% height of the bottom banner (in fraction of image)
blanc = .95*[1,1,1];	% near white (to avoid automatic replacement)
noir = [0,0,0];		% black
gris = .5*[1,1,1];	% half-gray
gris2 = .2*[1,1,1];	% dark-gray


if isfield(WO,'IGN_PATH_PHOTO50CM')
	pign = sprintf('%s/JPG',WO.IGN_PATH_PHOTO50CM);
else
	pign = '';
end


% makes SRTM directories
wosystem(sprintf('mkdir -p %s',WO.PATH_DATA_DEM_SRTM));
loaddemopt = {};
if isfield(WO,'PATH_DATA_DEM_SRTM1') && isok(P,'FRAME3_SRTM1')
	loaddemopt = {struct('DEM_SRTM1','Y')};
	wosystem(sprintf('mkdir -p %s',WO.PATH_DATA_DEM_SRTM1));
end


% Loads the high resolution DEM for frame 3
f3dem = 0;
if isfield(P,'FRAME3_DEM_FILE')
	f = P.FRAME3_DEM_FILE;
	if exist(f,'file')
		[xdem,ydem,zdem] = igrd(f);
		fprintf('%s: DEM file %s loaded...\n',wofun,f);
		f3dem = 1;
		if isfield(P,'FRAME3_DEM_TYPE') & strcmp(P.FRAME3_DEM_TYPE,'LATLON')
			[xdem,ydem,zdem] = latlon2utm(ydem,xdem,zdem,r3);
		end
	end
end

% gets all VIEWS and GRIDS: looks inside CONF directories... avoiding . .. and non-directory files
GV = dir(sprintf('%s/*',WO.PATH_VIEWS));
GP = dir(sprintf('%s/*',WO.PATH_PROCS));
grids = [strcat('VIEW.',{GV(~strncmp({GV.name},{'.'},1) & cat(2,GV.isdir)).name}), ...
	 strcat('PROC.',{GP(~strncmp({GP.name},{'.'},1) & cat(2,GP.isdir)).name})];

% loads all existing and valid NODES in existing grids
N = readnodes(WO,grids);

geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84)];
utm = ll2utm(geo);
% selects georeferenced nodes only
k = find(all(~isnan(geo),2) & any(geo,2));

for i = 1:length(k)
	ki = k(i);
	p = sprintf('%s/%s',NODES.PATH_NODES,N(ki).ID);
	f = sprintf('%s_map',N(ki).ID);
	fimg = sprintf('%s/%s.png',p,f);
	if exist(fimg,'file')
		IM = dir(fimg);
		timg = IM.datenum;
	else
		timg = 0;
	end
	
	% conditions to make (or remake) the map (at least one of the following):
	%	- map file does not exist
	%	- NODE is explicitely in the list STA
	%	- map file timestamp is older than NODE's timestamp
	%	- STA='*' (forced) 
	
	if ((~exist(fimg,'file') || timg <= N(ki).TIMESTAMP) && nargin < 1) || any(ismember(upper(sta),N(ki).ID)) || any(strcmp(sta,'*'))
		fprintf('%s: Updating location map for %s: %s [%s] ... ',wofun,N(ki).ALIAS,N(ki).NAME,N(ki).ID)

		lonkm = degkm(geo(ki,1));	% valeur du degré de longitude à cette latitude (en km)

		% inset frames coordinates
		xy1 = [geo(ki,2) + d1*.5*[-1,1]/lonkm,geo(ki,1) + d1*.5*[-1,1]/degkm];
		xy2 = [geo(ki,2) + d2*.5*[-1,1]/lonkm,geo(ki,1) + d2*.5*[-1,1]/degkm];
		xy3 = [utm(ki,1) + d3*.5*[-1,1]*1e3,utm(ki,2) + d3*.5*[-1,1]*1e3];

		% loading full resolution DEM data (SRTM3) based on frame0 width
		xlim = geo(ki,2) + d0*[-.5,.5]/lonkm;
		ylim = geo(ki,1) + d0*[-1,1]/degkm;
		D = loaddem(WO,[xlim,ylim]);

		figure, clf
		set(gcf,'PaperUnits','Inches','PaperSize',[10,5*(1+pcart)],'PaperPosition',[0,0,10,5*(1+pcart)],'Color',[1,1,1])
		
		% ----- low-resolution map (frame n°0)
		axes('Position',[0.01,pcart/(1+pcart)+.01,.25,1-pcart/(1+pcart)-.02]);
		dem(D.lon,D.lat,D.z,'LatLon','FontSize',8,demoptions{:})
		
		hold on
		if trans, plottrans(WO,N(ki)); end
		% inset of frame 1
		plot(xy1([1,2,2,1,1]),xy1([3,3,4,4,3]),'k-','Linewidth',lw)
		cible(geo(ki,2),geo(ki,1))
		hold off
		
		% ---- mid-resolution map (frame n°1)
		ax1 = axes('Position',[.255,(.5+pcart)/(1+pcart),.25,.5/(1+pcart)]);
		kx = find(D.lon >= xy1(1) & D.lon <= xy1(2));
		ky = find(D.lat >= xy1(3) & D.lat <= xy1(4));
		dem(D.lon(kx),D.lat(ky),D.z(ky,kx),'latlon','BorderWidth',.1,'FontSize',0,demoptions{:})
		set(gca,'XTick',[],'YTick',[])
		hold on
		
		if trans, plottrans(WO,N(ki)); end
		% inset of frame 2 (on frame 1)
		ax = axis;
		plot(xy2([1,2,2,1,1]),xy2([3,3,4,4,3]),'k-','Linewidth',lw)
		cible(geo(ki,2),geo(ki,1))
		xe = ax(2) - (xsc1/2 + dxsc1)/lonkm;
		ye = ax(3) + dxsc1/degkm;
		plot(xe + xsc1*.5*[-1,-1,1,1]/lonkm,ye + [dxsc1,0,0,dxsc1]/degkm,'-','Color',noir,'Linewidth',2)
		text(xe,ye,sprintf('%g km',xsc1),'Color',noir,'Fontsize',12,'FontWeight','bold', ...
				'HorizontalAlignment','center','VerticalAlignment','bottom')
		hold off

		% ---- tracé de la carte haute-résolution (encart n°2)
		ax2 = axes('Position',[.255,(.1+pcart)/(1+pcart),.2,.4/(1+pcart)]);
		% sur-échantillonnage de la carte
		[xx2,yy2] = meshgrid(xy2(1):(d2/lonkm/r2):xy2(2),xy2(3):(d2/degkm/r2):xy2(4));
		zz = interp2(D.lon,D.lat,double(D.z),xx2,yy2,'*cubic');
		[h,I,zz2] = dem(xx2(1,:),yy2(:,1),zz,'latlon','BorderWidth',0,'FontSize',0,demoptions{:});
		set(gca,'XTick',[],'YTick',[])
		hold on
		if trans, plottrans(WO,N(ki)); end
		%[c,h] = contour(xx2(1,:),yy2(:,1),zz2,[0,0]);  set(h,'EdgeColor',gris)
		ax = axis;
		cible(geo(ki,2),geo(ki,1))
		% échelle (convertir le km en degré)
		xe = ax(2) - (xsc2/2 + dxsc2)/lonkm;
		ye = ax(3) + dxsc2/degkm;
		plot(xe + xsc2*.5*[-1,-1,1,1]/lonkm,ye + [dxsc2,0,0,dxsc2]/degkm,'-','Color',noir,'Linewidth',2)
		text(xe,ye,sprintf('%g km',xsc2),'Color',noir,'Fontsize',12,'FontWeight','bold', ...
				'HorizontalAlignment','center','VerticalAlignment','bottom')
		ax = axis;
		plot(ax([1,2,2,1,1]),ax([3,3,4,4,3]),'k-','Linewidth',.1)
		hold off
		mmz = minmax(zz2);
		
		if ~all(isnan(mmz)) & ~all(mmz==0)
			% profil EW
			ax21 = axes('Position',[.255,pcart/(1+pcart),.2,.1/(1+pcart)]);
			xp = xx2(1,:); yp = zz2(round(size(zz2,1)/2),:);
			yp(find(isnan(yp))) = 0;
			fill(xp([1,1:end,end,1]),[mmz(1),yp,mmz(1),mmz(1)],gris)
			set(gca,'XLim',xy2(1:2),'YLim',mmz), axis off
			hold on, plot(repmat(geo(ki,2),[1,2]),mmz,'-','Color',noir,'Linewidth',.1), hold off
			text(xy2(2),mmz(1),sprintf(' %1.0f m',mmz(1)),'FontSize',9,'VerticalAlignment','bottom');
			% calcul de l'exagération verticale...
			dar = daspect(gca);
			figps = get(gcf,'PaperSize');
			figpp = get(gcf,'Position');
			axepp = get(gca,'Position');
			rxy = (figps(2)/figps(1)) * (axepp(3)/axepp(4));
			%disp(sprintf('rxy = %g',rxy))
			text(xy2(2),mean(mmz),sprintf('  x %1.1f',1000*lonkm*dar(1)/dar(2)/rxy),'FontSize',8');
			text(xy2(2),mmz(2),sprintf(' %1.0f m',mmz(2)),'FontSize',9','VerticalAlignment','top');
			
			% profil NS
			ax21 = axes('Position',[.455,(.1+pcart)/(1+pcart),.045,.4/(1+pcart)]);
			xp = zz2(:,round(size(zz2,2)/2))'; yp = yy2(:,1);
			xp(find(isnan(xp))) = 0;
			fill([mmz(1),xp,mmz(1),mmz(1)],yp([1,1:end,end,1]),gris)
			set(gca,'XLim',mmz,'YLim',xy2(3:4),'XDir','reverse'), axis off
			hold on, plot(mmz,repmat(geo(ki,1),[2,1]),'-','Color',noir,'Linewidth',.1), hold off
		end
		
		%---- extraction de la photo IGN (BDOrtho 50 cm)
		% recherche des photo contenant la station et des 8 photos adjacentes
		%	A31	A32	A33
		%	A21	A22	A23
		%	A11	A12	A13
		% note: la photo finale ne doit pas dépasser la taille d'une dalle unitaire (1 km), sinon l'algorithme ne marche plus...
		ignxy = [floor(utm(ki,1)/1000),ceil(utm(ki,2)/1000)];
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
			if mod(utm(ki,1),1000) < d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)-1,ignxy(1)-1,ignxy(2));
				if exist(fimg,'file')
					A21 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 23
			A23 = Z;
			if mod(utm(ki,1),1000) > 1000-d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)+1,ignxy(1)+1,ignxy(2));
				if exist(fimg,'file')
					A23 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 12
			A12 = Z;
			if mod(utm(ki,2),1000) < d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1),ignxy(1),ignxy(2)-1);
				if exist(fimg,'file')
					A12 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 32
			A32 = Z;
			if mod(utm(ki,2),1000) > 1000-d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1),ignxy(1),ignxy(2)+1);
				if exist(fimg,'file')
					A32 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 11
			A11 = Z;
			if mod(utm(ki,1),1000) < d3*1e3/2 & mod(utm(ki,2),1000) < d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)-1,ignxy(1)-1,ignxy(2)-1);
				if exist(fimg,'file')
					A11 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 13
			A13 = Z;
			if mod(utm(ki,1),1000) > 1000-d3*1e3/2 & mod(utm(ki,2),1000) < d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)+1,ignxy(1)+1,ignxy(2)-1);
				if exist(fimg,'file')
					A13 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 31
			A31 = Z;
			if mod(utm(ki,1),1000) < d3*1e3/2 & mod(utm(ki,2),1000) > 1000-d3*1e3/2
				fign = sprintf('%s/%04d/971-2004-%04d-%04d-u20n.jpg',pign,ignxy(1)-1,ignxy(1)-1,ignxy(2)+1);
				if exist(fimg,'file')
					A31 = imresize(imread(fign),size(I)/r3);
					disp(sprintf('Image: %s loaded.',fign));
				end
			end
			
			% dalle 33
			A33 = Z;
			if mod(utm(ki,1),1000) > 1000-d*1e3/2 & mod(utm(ki,2),1000) > 1000-d3*1e3/2
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
			cible(utm(ki,1),utm(ki,2),15)
			% échelle
			xe = ax(2) - xsc3*1e3/2 - dxsc3;
			ye = ax(3) + dxsc3;
			h = rectangle('Position',[xe - xsc3*1e3/2 - dxsc3,ye - dxsc3,xsc3*1e3 + 2*dxsc3,4*dxsc3]);
			set(h,'FaceColor',noir);
			plot(xe + xsc3*1e3*.5*[-1,-1,1,1],ye + [dxsc3,0,0,dxsc3],'-','Color',blanc,'Linewidth',3)
			text(xe,ye,sprintf('%g m',xsc3*1e3),'Color',blanc,'Fontsize',14,'FontWeight','bold', ...
				'HorizontalAlignment','center','VerticalAlignment','bottom')
			hold off
			ign = 1;
		else
			ign = 0;
		end

		% --- frame 3: user-defined DEM or interpolated SRTM
		if f3dem & utm(ki,1) >= min(xdem) & utm(ki,1) <= max(xdem) & utm(ki,2) >= min(ydem) & utm(ki,2) <= max(ydem)
			x3 = xdem;
			y3 = ydem;
			z3 = zdem;
			demcopyright = P.COPYRIGHT2;
			demflag = 1;
		else
			% loading full resolution DEM data (SRTM1 30m) based on frame3 limits
			xlim = geo(ki,2) + d3*.6*[-1,1]/lonkm;
			ylim = geo(ki,1) + d3*1.1*[-1,1]/degkm;
			D = loaddem(WO,[xlim,ylim],loaddemopt{:});
			[x3,y3,z3] = latlon2utm(D.lon,D.lat,D.z,r3);
			demcopyright = D.COPYRIGHT;
			demflag = 0;
		end

		kx = find(x3 >= (utm(ki,1) - d3*1e3/2) & x3 <= (utm(ki,1) + d3*1e3/2));
		ky = find(y3 >= (utm(ki,2) - d3*1e3/2) & y3 <= (utm(ki,2) + d3*1e3/2));
		axes('Position',[.5,pcart/(1+pcart),.5,1-pcart/(1+pcart)]);
		zmax = max(max(z3(ky,kx)));
		if ~isempty(kx) & ~isempty(ky)
			dem(x3(kx),y3(ky),z3(ky,kx),demoptions{:}); axis off
			hold on
			[cs,h] = contour(x3(kx),y3(ky),z3(ky,kx),[0,0,50:100:zmax],'-k');
			set(h,'LineWidth',.1,'Color',gris2);
			if zmax >= 100
				[cs,h] = contour(x3(kx),y3(ky),z3(ky,kx),[100,100,100:100:zmax],'-k');
				set(h,'LineWidth',1.5,'Color',gris2);
				clabel(cs,h,'FontSize',7,'FontWeight','bold','LabelSpacing',288,'Color',gris2)
			end
			if trans, plottrans(WO,N(ki),15,'utm'); end
			ax = axis;
			plot(ax([1,2,2,1,1]),ax([3,3,4,4,3]),'k-','Linewidth',.1)
			cible(utm(ki,1),utm(ki,2),15)
			% échelle
			xe = ax(2) - xsc3*1e3/2 - dxsc3;
			ye = ax(3) + dxsc3;
			h = rectangle('Position',[xe - xsc3*1e3/2 - dxsc3,ye - dxsc3,xsc3*1e3 + 2*dxsc3,4*dxsc3]);
			set(h,'FaceColor',noir);
			plot(xe + xsc3*1e3*.5*[-1,-1,1,1],ye + [dxsc3,0,0,dxsc3],'-','Color',blanc,'Linewidth',3)
			text(xe,ye,sprintf('%g m',xsc3*1e3),'Color',blanc,'Fontsize',14,'FontWeight','bold', ...
				'HorizontalAlignment','center','VerticalAlignment','bottom')
			hold off
		else
			axis off
		end

		% plots frame on inset n°2 (approximative)
		axes(ax2); hold on
		plot(geo(ki,2) + d3/lonkm*.5*[-1,1,1,-1,-1],geo(ki,1) + d3/degkm*.5*[-1,-1,1,1,-1],'k-','Linewidth',lw)
		hold off
		
		% ---- copyright (cartouche bas)
		copyright = sprintf('{\\bf\\copyright %s} - %s / %s',WO.COPYRIGHT,demcopyright,datestr(now,0));
		axes('Position',[0,0,1,pcart/(1+pcart)]); axis([0,1,0,1]); axis off
		%text(0,.5,[{P.COPYRIGHT1};{sprintf('%s - F. Beauducel',datestr(now,1))}],'FontSize',10)
		text(.5,.5,copyright,'FontSize',10,'HorizontalAlignment','center')
		if ign
			%text(1,.5,{'BD ORTHO \copyright IGN - Paris - 2004';'Reproduction interdite';'Licence n° 06 CUI-dom 0100 '}, ...
			text(1,.5,{'BD ORTHO \copyright IGN - Paris - 2004'}, ...
				'HorizontalAlignment','right','FontSize',10)
		end
		if demflag
			text(1,.5,sprintf('\\copyright %s  ',demcopyright), ...
				'HorizontalAlignment','right','FontSize',10)
		end
		ftmp = sprintf('%s/locastat',ptmp);
		print(gcf,'-depsc2','-loose','-painters',sprintf('%s.ps',ftmp));
		wosystem(sprintf('%s %s -density %dx%d %s.ps %s.png',WO.PRGM_CONVERT,convertopt,dpi,dpi,ftmp,ftmp));
		wosystem(sprintf('mv -f %s.png %s',ftmp,fimg));
		
		fprintf('done.\n');

		close
		
	else
		if nargin < 1
			fprintf('%s: "%s" is up to date.\n',wofun,fimg);
		end
	end
end

timelog(procmsg,2)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cible(x,y,s)
% target function

if nargin < 3
	s = 7;
end
plot(x,y,'o','MarkerSize',s,'MarkerFaceColor',[1,0,0],'MarkerEdgeColor',[.2,.2,.2],'Linewidth',s/5)
plot(x,y,'o','MarkerSize',s + 2,'MarkerEdgeColor',.99*[1,1,1])


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [xi,yi,zi] = latlon2utm(x,y,z,r3)
% latitude/longitude to UTM conversion of DEM


% minimal number of pixel of final UTM DEM
nn = min([size(z),r3]);

% converts x/y vectors in coordinates matrix
[xx,yy] = meshgrid(x,y);

% main LL2UTM conversion
en = ll2utm(yy(:),xx(:));

% rebuilts coordinate matrix
e = reshape(en(:,1),size(z));
n = reshape(en(:,2),size(z));

% border X-Y limits (e/n are not rectangular after conversion)
xlim = [max(e(:,1)),min(e(:,end))];
ylim = [max(n(1,:)),min(n(end,1))];

z(find(z == 0)) = -1;

% interpolation on a regular grid
[xi,yi] = meshgrid(linspace(xlim(1),xlim(2),nn),linspace(ylim(1),ylim(2),nn));
%zi = griddata(e(:),n(:),z(:),xi,yi,'cubic');	% cubic method sometimes get in a complete muddle!...
zi = griddata(e(:),n(:),z(:),xi,yi);

% extract x/y vectors
xi = xi(1,:);
yi = yi(:,1);
