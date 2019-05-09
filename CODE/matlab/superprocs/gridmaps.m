function gridmaps(grids,outd,varargin)
%GRIDMAPS Grids location maps of nodes
%   GRIDMAPS creates or updates NODES location maps for each existing GRIDS 
%   (views or procs). Maps are located in .eps and .png formats. 
%
%   GRIDMAPS(GRIDS) updates only grids listed in GRIDS (string or cell) as
%   	gridtype.gridname
%   Example: GRIDMAPS({'VIEW.GNSS','PROC.GAMIT'})
%
%   GRIDMAPS(GRIDS,OUTD) produces output maps into OUTD directory that will be
%   created. The maps will be standalone html files with html header.
%
%   GRIDMAPS(GRIDS,OUTD,'merge') will produce a single map merging all GRIDS.
%   In that case, all GRIDS additionnal MAP_* are ignored.
%
%   GRIDMAPS([],REQDIR) will produce output maps for all GRIDS defined in
%   the REQUEST.rc file located in REQDIR (made by formGRIDMAPS.pl).
%
%   GRIDMAPS uses SRTM or ETOPO data for background DEM shading maps. Higher
%   resolution DEM can be defined into each grid configuration files, in 
%   ArcInfo format.
%   
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2013-09-13 in Paris, France
%   Updated: 2019-05-09


WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

procmsg = sprintf(' %s',mfilename);
timelog(procmsg,1)

% merges all grids into a single map
merge = any(strcmpi(varargin,'merge'));

% request mode: get GRIDS list and parameters
if nargin > 1 && exist([outd '/REQUEST.rc'],'file')
	P = readcfg(WO,[outd '/REQUEST.rc']);
	grids = {''};
	if isfield(P,'VIEW')
		grids = strcat('VIEW.',fieldnames(P.VIEW));
	end
	if isfield(P,'PROC')
		grids = [grids;strcat('PROC.',fieldnames(P.PROC))];
	end
	merge = 1;
	request = 1;
else
	P = readcfg(WO,WO.GRIDMAPS);
	P.DATE1 = datestr(now,'yyyy-mm-dd');
	P.DATE2 = datestr(now,'yyyy-mm-dd');
	request = 0;
end

% loads transmission information
trans = isok(P,'PLOT_TRANSMISSION');

% gets all VIEWS and PROCS looks inside the GRIDS directories avoiding . .. and non-directory files
if ~request && (nargin < 1 || isempty(grids))
	VIEWS = dir(sprintf('%s/*',WO.PATH_VIEWS));
	PROCS = dir(sprintf('%s/*',WO.PATH_PROCS));
	grids = [strcat('VIEW.',{VIEWS(~strncmp({VIEWS.name},{'.'},1) & cat(2,VIEWS.isdir)).name}), ...
		 strcat('PROC.',{PROCS(~strncmp({PROCS.name},{'.'},1) & cat(2,PROCS.isdir)).name})];
else
	if ~iscell(grids)
		grids = cellstr(grids);
	end
end

%fprintf('%d grids to process:\n',length(grids));
%disp(grids)

if nargin < 2 || isempty(outd)
	outd = WO.ROOT_OUTG;
	fext = 'map';
	html = 0;
else
	fext = 'htm';
	html = 1;
end

ptmp = WO.PATH_TMP_WEBOBS;
wosystem(sprintf('mkdir -p %s',ptmp));

inactivenode = isok(P,'INACTIVE_NODE');
minkm = field2num(P,'MIN_SIZE_KM',2);
maxxy = field2num(P,'MAX_XYRATIO',2);
border = field2num(P,'BORDER_ADD',.1);

if isfield(P,'PAPERSIZE_INCHES')
	psz = repmat(str2double(P.PAPERSIZE_INCHES)*72,[1,2]);
else
	psz = [720,720];
end
dpi = field2num(P,'DPI',100);
%lw = field2num(P,'LINEWIDTH',.1);
lwminor = field2num(P,'CONTOURLINES_MINOR_LINEWIDTH',.1);
lwmajor = field2num(P,'CONTOURLINES_MAJOR_LINEWIDTH',1);
convertopt = field2str(WO,'CONVERT_COLORSPACE','-colorspace sRGB');
feclair = field2num(P,'COLOR_LIGHTENING',.5);
laz = field2num(P,'LIGHT_AZIMUTH',45);
lct = field2num(P,'LIGHT_CONTRAST',1);
if isfield(P,'LANDCOLORMAP') && exist(P.LANDCOLORMAP,'file')
	cmap = eval(P.LANDCOLORMAP);
else
	cmap = landcolor.^1.3;
end
if isfield(P,'SEACOLORMAP') && exist(P.SEACOLORMAP,'file')
	sea = eval(P.SEACOLORMAP);
else
	sea = repmat([0.7,0.9,1],[2,1]);
end
demoptions = {'Interp','Lake','Azimuth',laz,'Contrast',lct,'LandColor',cmap,'SeaColor',sea,'Watermark',feclair,'latlon','legend','axisequal','manual'};


% loads all needed grid's parameters & associated nodes
for g = 1:length(grids)
	s = split(grids{g},'/.');
	if length(s) < 2
		error('Must use the full grid name PROC.NAME or VIEW.NAME');
	end
	GRIDS.(s{1}).(s{2}) = readcfg(WO,sprintf('/etc/webobs.d/%sS/%s/%s.conf',s{1},s{2},s{2}));
	% Loads all existing and valid NODES (declared at least in one VIEW)
	N = readnodes(WO,grids{g});
	GRIDS.(s{1}).(s{2}).N = N;
	if ~isempty(N)
		geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84)];
		dte1 = cat(1,N.INSTALL_DATE);
		dte2 = cat(1,N.END_DATE);
		act = (dte1 <= datenum(P.DATE2) | isnan(dte1)) & (dte2 >= datenum(P.DATE1) | isnan(dte2));
		NN(g).kn = find(all(~isnan(geo),2) & ~all(geo==0,2));
		NN(g).ka = find(all(~isnan(geo),2) & ~all(geo==0,2) & act);
		NN(g).k0 = find(all(~isnan(geo),2) & ~all(geo==0,2) & ~act & ~inactivenode);
		NN(g).geo = geo;
		NN(g).id = cat(1,{N.ID});
		NN(g).alias = cat(1,{N.ALIAS});
		NN(g).name = cat(1,{N.NAME});
	else
		NN(g).kn = [];
	end
end

% merging case: computes the map limits from all nodes
if merge
	geo = cat(1,NN.geo);
	kn = find(all(~isnan(geo),2) & ~all(geo==0,2));
	if isempty(kn)
		error('No NODES to plot. Cannot computes merged map limits.')
	else
		mmaplim = ll2lim(geo(kn,1),geo(kn,2),minkm,maxxy,border);
	end
end

for g = 1:length(grids)

	if merge
		if g == 1
			fprintf('\n%s: Making map of merged grids ',wofun);
		end
		fprintf('%s... ',grids{g});
	else
		fprintf('\n%s: Making map of grid %s...\n',wofun,grids{g});
	end
	s = split(grids{g},'.');
	G = GRIDS.(s{1}).(s{2});
	% GRIDMAPS.rc SRTM1 option applies only if not defined in the PROC's configuration
	if isok(P,'DEM_SRTM1') & (~isfield(G,'DEM_SRTM1') || merge)
		G.DEM_SRTM1 = 'Y';
	end
	if request
		for key = split(P.REQUEST_GRID_KEYLIST,',')
			G.(key{:}) = field2str(P.(s{1}).(s{2}),key{:},field2str(G,key{:}),'notempty');
		end
	end
	nodename = field2str(G,'NODE_NAME','node','notempty');
	nodetype = field2str(G,'NODE_MARKER','o','notempty');
	nodesize = field2num(G,'NODE_SIZE',15,'notempty');
	nodecolor = field2num(G,'NODE_RGB',[1,0,0],'notempty');
	nodefont = field2num(G,'NODE_FONTSIZE',0,'notempty');

	% looks for supplementary maps (MAP*_XYLIM|LON1,LON2,LAT1,LAT2 keys)
	if merge
		maps(1,:) = {'MAP',mmaplim};
	else
		fd = fieldnames(G);
		k = find(~cellfun(@isempty,regexp(fd,'^MAP\d+_XYLIM$')));
		maps = cell(1 + length(k),2);
		maps(1,:) = {'MAP',[]};
		for ii = 1:length(k)
			x = split(fd{k(ii)},'_');
			maps{ii+1,1} = x{1};
			maps{ii+1,2} = sstr2num(G.(fd{k(ii)}));
			if length(maps{ii+1,2}) < 4
				error('%s: %s key must contains 4 elements (LON1,LON2,LAT1,LAT2). Abort.',wofun,fd{k});
			end
		end
	end

	kn = NN(g).kn;
	if merge || ~isempty(kn)
		N = GRIDS.(s{1}).(s{2}).N;
		if merge
			if request
				pimg = sprintf('%s/GRIDMAPS/%s',outd,WO.PATH_OUTG_MAPS);
			else
				pimg = outd;
			end
		else
			pimg = sprintf('%s/%s/%s',outd,grids{g},WO.PATH_OUTG_MAPS);
		end

		wosystem(sprintf('mkdir -p %s',pimg));
		delete(sprintf('%s/*',pimg));

		geo = NN(g).geo;
		ka = NN(g).ka;
		k0 = NN(g).k0;

		for m = 1:size(maps,1)
			if merge
				fimg = sprintf('_%s',lower(maps{m,1}));
			else
				fimg = sprintf('%s_%s',grids{g},lower(maps{m,1}));
			end

			if isempty(maps{m,2})
				[dlat,dlon] = ll2lim(geo(kn,1),geo(kn,2),minkm,maxxy,border);
			else
				dlon = maps{m,2}(1:2);
				dlat = maps{m,2}(3:4);
			end

			% makes basemap for each individual grids or only first in merge mode 
			if ~merge || g == 1
				% loads DEM (G may contain user's defined DEM)
				DEM = loaddem(WO,[dlon,dlat],G);
				x = DEM.lon;
				y = DEM.lat;
				z = DEM.z;
				demcopyright = DEM.COPYRIGHT;

				figure

				% forces papersize units in points and no margin
				set(gcf,'PaperUnits','points','PaperSize',psz);
				set(gcf,'PaperPosition',[0,0,psz],'Position',[0,0,psz])

				subplot(1,1,1); extaxes(gca,[.04,.08]);

				% plots DEM basemap
				dem(x,y,z,demoptions{:});

				hold on

				% contour lines
				if isok(P,'CONTOURLINES')
					zmin = min(z(:));
					zmax = max(z(:));
					dz = double(zmax - zmin);
					% empirical ratio between horizontal extent and elevation interval (dz)
					rzh = dz/min(diff(x([1,end]))*cosd(mean(dlat)),diff(y([1,end])))/degkm/4e2;
					dz0 = tickscale([zmin,zmax],rzh);
					dz0(ismember(0,dz0)) = [];	% eliminates 0 value
					dz1 = tickscale([zmin,zmax],rzh*5);
					dz1(ismember(dz1,dz0)) = [];	% eliminates minor ticks in major ticks
					if isfield(P,'CONTOURLINES_RGB')
						clrgb = eval(sprintf('[%s]',P.CONTOURLINES_RGB));
					else
						clrgb = [0,0,0];
					end
					[~,h] = contour(x,y,z,[0,0,dz1],'-','Color',clrgb);
					set(h,'LineWidth',lwminor);
					[cs,h] = contour(x,y,z,[0,0,dz0],'-','Color',clrgb);
					set(h,'LineWidth',lwmajor);
					if ~isempty(dz0) && isok(P,'CONTOURLINES_LABEL')
						clabel(cs,h,dz0,'Color',clrgb,'FontSize',7,'FontWeight','bold','LabelSpacing',288)
					end
				end

				% plots other maps limits
				for smap = 2:size(maps,1)
					if smap ~= m
						plot(maps{smap,2}([1,2,2,1,1]),maps{smap,2}([3,3,4,4,3]),'-k','LineWidth',.2)
					end
				end

			end

			% plot transmission
			if trans
				for n = 1:length(kn)
					plottrans(WO,N(kn(n)),nodesize);
				end
			end

			% plots active nodes
			if ~isempty(ka)
				target(geo(ka,2),geo(ka,1),nodesize,nodecolor,nodetype)
			end
			% plots inactive nodes
			if ~isempty(k0)
				target(geo(k0,2),geo(k0,1),nodesize,nodecolor,nodetype,2)
			end

			xlim = get(gca,'XLim');
			ylim = get(gca,'YLim');

			% writes node names
			if nodefont > 0
				k = find(isinto(geo(kn,2),xlim) & isinto(geo(kn,1),ylim));
				textlabel(geo(kn(k),2),geo(kn(k),1),cat(1,{N(kn(k)).ALIAS}),'FontSize',nodefont,'FontWeight','bold')
			end

			% makes figure and basemap
			if ~merge || g == length(grids)
				hold off

				% title
				if merge
					titre = field2str(P,'NAME');
				else
					titre = G.NAME;
				end
				title(titre,'FontSize',20,'FontWeight','bold')
				
				pos = get(gca,'Position');

				% gets figure and axes properties
				set(gca,'Units','normalized');
				pos = get(gca,'Position');
				dar = get(gca,'DataAspectRatio');
				if dar(1) > dar(2)
					axp = [pos(1),pos(2) + (1 - dar(2)/dar(1))/2,pos(3),pos(4)*dar(2)/dar(1)];
				end
				axp = plotboxpos(gca);
				xylim = [get(gca,'XLim'),get(gca,'YLim')];

				% copyright
				copyright = sprintf('{\\bf\\copyright %s} - {%s} - %s / %s',WO.COPYRIGHT,strrep(grids{g},'_','\_'),demcopyright,datestr(now,0));
				axes('Position',[pos(1),0,pos(3),pos(2)])
				axis([0,1,0,1]); axis off
				text(.5,0,copyright,'Color',.4*[1,1,1],'FontSize',9,'HorizontalAlignment','center','VerticalAlignment','bottom')

				% nodes legend
				if ~merge
					xl = [.1,.4,.7];
					yl = .5;
					target(xl(2),yl,nodesize,nodecolor,nodetype);
					if ~isempty(k0)
						target(xl(3),yl,nodesize,nodecolor,nodetype,2);
					end
					text(xl,yl*[1,1,1],{sprintf('{\\bf%s}',nodename), ...
						sprintf('    active ({\\bf%d}/%d)',length(ka),length(kn)), ...
						repmat(sprintf('    inactive ({\\bf%d}/%d)',length(k0),length(kn)),~isempty(k0))}, ...
						'FontSize',14,'HorizontalAlignment','left')
				end

				% prints the map (PostScript and PNG)
				fprintf('%s: updating %s/%s.{eps,png} ... ',wofun,pimg,fimg);

				ftmp = sprintf('%s/%s',ptmp,fimg);
				print(gcf,'-depsc','-loose','-painters',sprintf('%s.eps',ftmp));
				wosystem(sprintf('%s %s -density %dx%d %s.eps %s.png',WO.PRGM_CONVERT,convertopt,dpi,dpi,ftmp,ftmp));

				IM = imfinfo(sprintf('%s.png',ftmp));
				ims = [IM.Width IM.Height];

				wosystem(sprintf('mv -f %s/%s.* %s',ptmp,fimg,pimg));
				fprintf('done.\n');

				close

				% makes the HTML mapping
				fprintf('%s: updating %s/%s.%s ... ',wofun,pimg,fimg,fext);
				fid = fopen(sprintf('%s.%s',ftmp,fext),'wt');
				if html
					fprintf(fid,'<HTML><HEAD><TITLE></TITLE></HEAD><BODY>\n<IMG src="%s.png" usemap="#map">\n<MAP name="map">\n',fimg);
				end
				if merge
					glist = 1:length(grids);
				else
					glist = g;
				end
				for gg = glist
					for n = 1:length(NN(gg).kn)
						knn = NN(gg).kn(n);
						x = round(ims(1)*((axp(3)*(NN(gg).geo(knn,2) - xylim(1))/diff(xylim(1:2)) + axp(1))));
						y = round(ims(2) - ims(2)*((axp(4)*(NN(gg).geo(knn,1) - xylim(3))/diff(xylim(3:4)) + axp(2))));
						r = ceil(nodesize/1.5);
						lnk = sprintf('/cgi-bin/showNODE.pl?node=%s.%s',grids{gg},NN(gg).id{knn});
						if html
							txt = regexprep(sprintf('%s: %s',NN(gg).alias{knn},NN(gg).name{knn}),'"','');
							fprintf(fid,'<AREA href="%s" title="%s" shape=circle coords="%d,%d,%d">\n',lnk,txt,x,y,r);
						else
							txt = unicode2native(regexprep(sprintf('<b>%s</b>: %s',NN(gg).alias{knn},NN(gg).name{knn}),'"',''),'utf-8');
							txt = regexprep(char(txt),'''','\\''');
							fprintf(fid,'<AREA href="%s" onMouseOut="nd()" onMouseOver="overlib(''%s'')" shape=circle coords="%d,%d,%d">\n',lnk,txt,x,y,r);
						end
					end
				end
				fprintf(fid,'<AREA nohref shape=rect coords="0,0,%d,%d">\n',ims);

				if html
					fprintf(fid,'</MAP>\n</BODY></HTML>');
				end
				fclose(fid);
				wosystem(sprintf('mv -f %s.%s %s',ftmp,fext,pimg));
				fprintf('done.\n');

			end
		end

	else
		if ~merge
			delete(sprintf('%s/%s/%s/*',outd,grids{g},WO.PATH_OUTG_MAPS));
			fprintf('%s: no georeferenced node found... No map produced.\n',wofun);
		else
			fprintf('%s: no georeferenced node found for grid %s...\n',wofun,grids{g});
		end
	end
	if merge && g == length(grids)
		fprintf('\n');
	end

end

timelog(procmsg,2)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [dlat,dlon] = ll2lim(lat,lon,minkm,maxxy,border)
% Determines X-Y limits of the map from NODE's coordinates
% 	[DLAT,DLON]=LL2LIM(...)
% 	XYLIM=LL2LIM(...)

dlat = [min(lat),max(lat)];
lat0 = mean(dlat);
if diff(dlat) < minkm/degkm
	dlat = lat0 + [-.5,.5]*minkm/degkm;
end
dlon = [min(lon),max(lon)];
lon0 = mean(dlon);
if diff(dlon) < minkm/degkm(lat0)
	dlon = lon0 + [-.5,.5]*minkm/degkm(lat0);
end
% adjusts to respect maximum XY ratio
if maxxy*diff(dlon)/cosd(lat0) < diff(dlat)
	dlon = lon0 + [-.5,.5]*diff(dlat)/cosd(lat0)/maxxy;
end
if maxxy*diff(dlat) < diff(dlon)*cosd(lat0)
	dlat = lat0 + [-.5,.5]*diff(dlon)*cosd(lat0)/maxxy;
end

% adds borders in %
dlon = dlon + diff(dlon)*border*[-1,1]/cosd(lat0);
dlat = dlat + diff(dlat)*border*[-1,1];

% outputs xylim
if nargout == 1
	dlat = [dlon,dlat];
end
