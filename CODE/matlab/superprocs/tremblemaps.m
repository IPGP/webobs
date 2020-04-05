function DOUT=tremblemaps(varargin)
%TREMBLEMAPS WebObs SuperPROC: Makes eathquake event reports.
%
%       TREMBLEMAPS(PROC) makes output graphs for each valid event imported from associated
%       catalog (NODES), using default values of PROC.
%
%       TREMBLEMAPS(PROC,TSCALE) uses all or a selection of TIMESCALES for data import:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	TREMBLEMAPS(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = TREMBLEMAPS(PROC,...) returns a structure D containing all the PROC data:
%           D.id = node ID
%           D.t = time vector (for node i)
%           D.d = matrix of data (NaN = invalid data)
%           D.c = matrix of char data (cell)
%
%       TREMBLEMAPS will use PROC's parameters from .conf file. RAWFORMAT must be
%       one of the "quake" formats (see readfmtdata_quake.m for details).
%
%       Specific paramaters are:
%		EVENTTYPE_EXCLUDED_LIST|not existing,not locatable,outside of network interrest,sonic boom,duplicate,other
%		EVENTSTATUS_EXCLUDED_LIST|auto
%		PURGE_EXCLUDED_EVENT|
%		SC3_LISTEVT|
%		MAGLIM|2,Inf
%		MC3_NAME|
%		CITIES|$WEBOBS{ROOT_CONF}/Cities.conf
%		REGION|Guadeloupe
%		GMPE|beauducel09
%		GMICE|gr42
%		TOPOVS30|Y
%		TOPOVS30_FILTER|9
%		FELT_MSK_MIN|1.5
%		FELT_FORCED|0
%       	TZ|-4
%       	LOCALE|fr_FR
%		AREA|la Guadeloupe et Îles du Nord
%		MAP_XYLIM|
%		MAP_LANDONLY|Y
%		MAP_INSET_EPIMAX|0
%		MAP_DEM_OPT|'LandColor',.8*ones(2,3),'SeaColor',white,'Contrast',1,'LCut',0.01
%		EPICENTER_PLOT_OPT|'p','MarkerSize',12,'MarkerEdgeColor','r','MarkerFaceColor','w','LineWidth',1.5
%		SHAKEMAP_SHAPEFILES_ROOT|
%		COLORMAP|jet
%		COLORMAP_ALPHA|0,1
%		FELTOTHERPLACES_OK|1
%		EVENT_TITLE1|Magnitude $quake_magnitude, $quake_latitude, $quake_longitude, profondeur $quake_depth
%		EVENT_TITLE2|$long_date $time
%		WATERMARK_AUTO|AUTOMATIQUE
%		WATERMARK|
%		REPORT_DATE|Paris, $report_date $report_time (local time)
%		REPORT_TEXT_ROOT|$WEBOBS{ROOT_CONF}/TREMBLEMAPS
%		REPORT_TEXT_FILE|${REPORT_TEXT_ROOT}_TEXT_en.txt
%		REPORT_FELT_FILE|${REPORT_TEXT_ROOT}_FELT_en.txt
%		REPORT_AUTO_FILE|${REPORT_TEXT_ROOT}_AUTO_en.txt
%		COPYRIGHT|(c) OVSG-IPGP
%		REFERENCES|Loi d'atténuation B-Cube [Beauducel et al., 2011]
%		LOGO2|logo_b3r.jpg
%		LOGO1|logo_ovsgipgp.jpg
%		TITLE1|Rapport préliminaire de séisme concernant
%		TITLE2|${AREA}
%		SUBTITLE1|{\bfObservatoire Volcanologique et Sismologique de Guadeloupe - IPGP}
%		SUBTITLE2|Le Hou¨lmont - 97113 Gourbeyre - Guadeloupe (FWI)
%		SUBTITLE3|Tél: +590 (0)590 99 11 33 - Fax: +590 (0)590 99 11 34 - infos@ovsg.univ-ag.fr - www.ipgp.fr
%		EVENT_TITLE1|Magnitude $magnitude, $latitude, $longitude, profondeur $depth
%		EVENT_TITLE2|$long_date $long_time
%		LIST_TITLE1|{\bfIntensités probables moyennes}
%		LIST_TITLE2|{\bf(et maximales)}
%		LIST_OUTOF|Hors ${AREA}
%		TABLE_HEADERS|Perception Humaine,Dégâts Potentiels,Accélérations (mg),Intensités EMS98
%		FOOTNOTE1|(*) {\bfmg} = "milli gé" est une unité d'accélération correspondant au millième de la pesanteur terrestre
%		FOOTNOTE2|La ligne pointillée délimite la zone où le séisme a pu être potentiellement ressenti.
%		LESS_1KM_TEXT|moins de 1 km
%		ADDITIONAL_TEXT|
%		GSE_TITLE|${REGION}: $quake_strength $quake_type $epicentral $azimuth of $city ($region)
%		GSE_AUTO_TITLE|${REGION}: $quake_strength $epicentral $azimuth of $city ($region)
%		GSE_COMMENT|$azimuth of $city ($region)
%		NOTIFY_EVENT|feltquake.
%		PDFOUTPUT|1
%		AUTOPRINT_OK|1
%		
%		List of internal variables that will be substituted in text strings:
%			$report_date      = long date string of the report (local time)
%			$report_time      = time string of the report (local time)
%			$long_date        = earthquake long date string TU (using LOCALE and TZ for system call)
%			$time             = earthquake time string TU (idem)
%			$long_date_local  = earthquake long date string local (idem)
%			$time_local       = earthquake time string local (idem)
%			$quake_strength   = earthquake magnitude adjective string
%			$quake_magnitude  = earthquake magnitude value
%			$quake_latitude   = earthquake origin latitude
%			$quake_longitude  = earthquake origin longitude
%			$quake_depth      = earthquake origin depth
%			$quake_depth_bsl  = earthquake origin depth above/below sea level
%			$quake_type       = earthquake type
%			$quake_mag_error  = earthquake magnitude error/uncertainty
%			$quake_mag_type   = earthquake magnitude type
%			$city             = city with the maximum predicted intensity
%			$region           = region of the city
%			$epicentral       = epicentral distance (km)
%			$hypocentral      = hypocentral distance (km)
%			$azimuth          = azimuth of origin (°N)
%			$pga              = predicted PGA (mg)
%			$pga_max          = max. predicted PGA (mg)
%			$msk              = predicted MSK value
%			$long_msk         = predicted MSK string
%			$msk_max          = max. predicted MSK value
%			$long_msk_max     = max. predicted MSK string
%			$additional_text
%
%	Reference paper:
%	   Beauducel F., S. Bazin, M. Bengoubou-Valérius, M.-P. Bouin, A. Bosson, C. Anténor-Habazac, V. Clouard, J.-B. de Chabalier, 2011.
%	   Empirical model for rapid macroseismic intensities prediction in Guadeloupe and Martinique.
%	   C.R. Geoscience, 343:11-12, 717-728, doi:10.1016/j.crte.2011.09.004.
%
%
%	Authors: F. Beauducel and J.M. Saurel / WEBOBS, IPGP
%	Created: 2005-01-12, Guadeloupe, French West Indies
%	Updated: 2020-04-05


WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

procmsg = sprintf(' %s',mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration and associated nodes for any TSCALE and/or REQDIR
[P,N,D] = readproc(WO,varargin{:});

% concatenates all nodes data
t = cat(1,D.t);
d = cat(1,D.d);
c = cat(1,D.c);
e = cat(1,D.e);

% PROC's TZ must be in local time: set back data to UT
t = t - P.TZ/24;

demopt = field2cell(P,'MAP_DEM_OPT');
if isok(P,'MAP_LANDONLY',1)
	P.ETOPO_SRTM_MERGE = 'N';
end

% colormap options
cmap = field2num(P,'COLORMAP',jet(256));
amap = field2num(P,'COLORMAP_ALPHA',[0,1]);
twmsk = field2num(P,'TABLE_WHITE_MSK',10:12);

forced = isok(P,'FELT_FORCED',0);
mskmin = field2num(P,'FELT_MSK_MIN',2);
citiesdisplaylist = field2num(P,'CITIES_DISPLAY_LIST',0);

% loads description and parameters for MSK and MAG tables
mskscale = sprintf('%s/etc/mskscale.%s',WO.ROOT_CODE,P.LOCALE);
if ~exist(mskscale,'file')
	mskscale = strrep(mskscale,P.LOCALE,'en_EN');
end
MSK = readcfg(WO,mskscale,'keyarray');
MAG = readcfg(WO,sprintf('%s/etc/quakemagnitudes.conf',WO.ROOT_CODE),'keyarray');
pgamsk = gmice(1:length(MSK),P.GMICE,'reverse');

region = P.REGION;

% loads cities (with elevations)
CITIES = readcities(WO,P.CITIES,'elevation');

if isfield(P,'SHAPE_FILE') && exist(P.SHAPE_FILE,'file')
	faults = ibln(P.SHAPE_FILE);
else
	faults = [];
end
txtb3 = sprintf('WEBOBS %s %s - %s',P.COPYRIGHT,datestr(now,'yyyy'),P.REFERENCES);

A1 = imread(P.LOGO_FILE);
A3 = imread(P.LOGO2_FILE);

[suser,wuser] = wosystem('echo "$(whoami)@$(hostname)"','chomp');
nbsig = 2;                                       % nombre de chiffres significatifs pour PGA affichés
lastb3 = '';

% main loop on each data event
for n = 1:length(t)

	vtps = datevec(t(n));
	% basename example = 20140419T193135_b3_MD31_manual
	fnam = sprintf('%4d%02d%02dT%02d%02d%02.0f_b3_%s%02.0f_%s',vtps,regexprep(c{n,2},'\W',''),d(n,4)*10,c{n,5});
	% event directory
	id = c{n,1};
	if isempty(id)
		id = 'id';
	end
	P.GTABLE(1).EVENTS = sprintf('%4d/%02d/%02d/%s',vtps(1:3),id);
	pdat = sprintf('%s/%s/%s',P.GTABLE(1).OUTDIR,WO.PATH_OUTG_EVENTS,P.GTABLE(1).EVENTS);
	fdat = sprintf('%s/%s.txt',pdat,fnam);

	if all(~isnan(d(n,1:4))) && ~exist(fdat,'file') && e(n) >= 0

		depi = greatcircle(CITIES.lat,CITIES.lon,d(n,1),d(n,2));	% epicentral distance to all cities
		dhyp = sqrt(depi.^2 + (CITIES.alt/1e3 + d(n,3)).^2);	% hypocentral distance to all cities
		pga = 1e3*repmat(gmpe(P.GMPE,d(n,4),dhyp,d(n,3)),1,2).*[ones(size(depi)),CITIES.factor];	% predicted PGA (in mg) and PGAmax (with amplification factor)
		msk = gmice(pga,P.GMICE);	% predicted intensity (MSK scale)
		% sort all pga values in decreasing order
		[~,k] = sort(pga(:,2),1,'descend');
		k1 = k(1);

		% exports the data in a text file
		fprintf('%s: exporting file %s ...',wofun,fdat);
		wosystem(sprintf('mkdir -p %s',pdat),P);
		fid = fopen(fdat,'wt');
		fprintf(fid,'%s\n',repmat('#',[1,80]));
		fprintf(fid,'# %s\n#\n',WO.WEBOBS_TITLE);
		fprintf(fid,'# PROC: {%s} %s\n',P.SELFREF,P.NAME);
		fprintf(fid,'# FILENAME: %s\n',fdat);
		fprintf(fid,'#\n\n'); 
		if ~suser
			fprintf(fid,'#\n# CREATED: %s by %s\n',datestr(now),wuser);
		end
		fprintf(fid,'# COPYRIGHT: %s, %s\n',datestr(now,'yyyy'),P.COPYRIGHT);
		fprintf(fid,'#\n');
		fprintf(fid,'# Ground Motion Prediction Equation: %s (see gmpe.m)\n',P.GMPE);
		fprintf(fid,'# Ground Motion Intensity Conversion Equation: %s (see gmice.m)\n',P.GMICE);
		fprintf(fid,'# Hypocenter data (from %s):\n',strjoin(cellstr(char(N.NAME)),'+'));
		fprintf(fid,'#\tTime (UT) = %s\n#\t%s = %1.1f (±%1.1f)\n#\tType = %s\n',datestr(t(n)),c{n,2},d(n,4),d(n,12),c{n,3});
		fprintf(fid,'#\tLatitude = %g N\n#\tLongitude = %g E\n#\tDepth = %g km\n',d(n,1:3));
		fprintf(fid,'#\n# Hypocentral distances (km) and computed PGA (mg), using local amplification factors\n');
		fprintf(fid,'# for each city, and corresponding intensity MSK:\n#\n');
		fprintf(fid,'#\n');
		fprintf(fid,'#                    City/Region, site,  dHyp, PGA_mean, PGA_max, MSK_mean, MSK_max\n#\n');
		for ii = 1:length(depi)
			ki = k(ii);
			fprintf(fid,'%35s, %g, %7.1f, %8.4f, %8.4f, %6s, %6s\n', ...
				sprintf('%s/%s',CITIES.name{ki},CITIES.region{ki}),CITIES.factor(ki),dhyp(ki),pga(ki,:),msk2str(msk(ki,1)),msk2str(msk(ki,2)));
		end
		fprintf(fid,'%s\n',repmat('#',1,80));
		fclose(fid);
		fprintf(' done.\n');

		% exports data
		%if isok(P.GTABLE(r),'EXPORTS')
		%	E.t = tk;
		%	E.d = dk;
		%	E.header = CLB.nm;
		%	E.title = sprintf('%s {%s}',M.(map).title,proc);
		%	mkexport(WO,sprintf('%s_%s',map,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		%end

		% removes all symbolic links
		wosystem(sprintf('rm -f %s/b3*',pdat),P,'warning');

		% determines if a report is needed (felt event)
		if forced > 0 || ( msk(k1,2) >= mskmin && (str2double(P.FELTOTHERPLACES_OK) > 0 || strcmp(CITIES.region(k1),region)) )

			pps = [.2,.25,7.8677,11.2929];	% paper position (inches)
			pos0 = [.055,.115,.9,.600];	% map position on the paper

			% sorts cities in the current region
			kdpt = k(strcmp(CITIES.region(k),region));
			if isempty(kdpt)
				fprintf('%s: ** WARNING ** no city found for region "%s" in file %s ! Use the nearest city instead...\n',wofun,region,P.CITIES);
				kepi = k1;
			else
				% index of the highest-intensity city
				kepi = kdpt(1);
			end
			% selects local region cities to be displayed
			kcom = kdpt(msk(kdpt,2) >= mskmin);

			% if map limits are not fixed, defines them from the event properties
			if isfield(P,'MAP_XYLIM')
				xylim = sstr2num(P.MAP_XYLIM);
			else
				xylim = [];
			end
			if length(xylim) < 4
				kfelt = [kepi;find(msk(:,2) >= mskmin)]; % index of potentially felt cities + nearest local region city
				xylim = [minmax([CITIES.lon(kfelt);d(n,2)]),minmax([CITIES.lat(kfelt);d(n,1)])];
				lat0 = mean(xylim(3:4));
				if citiesdisplaylist
					xylim(1) = xylim(1) - .3*diff(xylim(1:2));	% adds 30% on the left (for city list)
				end
				xylim = xylim + 10*[[-1,1]/degkm(lat0),[-1,1]/degkm];	% adds 10 km for borders
				% adjust left or bottom limits to fit axis ratio
				rlon = cosd(lat0);
				axyratio = pos0(3)*pps(3)/pos0(4)/pps(4);
				mxyratio = diff(xylim(1:2))*rlon/diff(xylim(3:4));
				if mxyratio < axyratio
					dx = (axyratio - mxyratio)*diff(xylim(3:4))/rlon;
					xylim(1:2) = xylim(1:2) + dx*[-.5,.5];
				else
					dy = (mxyratio/axyratio - 1)*diff(xylim(3:4));
					xylim(3:4) = xylim(3:4) + dy*[-.5,.5];
				end
			end

			% loads DEM
			DEM = loaddem(WO,xylim,P);
			if isok(P,'MAP_COASTLINE')
				DEM.c = contour(DEM.lon,DEM.lat,DEM.z,[0,0]);
			end
			DEM.opt = demopt;

			% selects cities from other regions to be displayed
			kregion = k(msk(k,2) >= mskmin & ~strcmp(CITIES.region(k),region));           
			% unification (1 seule commune par île)
			[~,k] = unique(CITIES.region(kregion),'first');
			kregion = kregion(k);
			%[xx,kk] = unique(flipud(CITIES.region(kregion)));
			%kregion = kregion(length(kregion)-kk+1);
			[~,kk] = sort(msk(kregion),1,'descend');
			kregion = kregion(kk);

			% calculates the maximum site amplification (felt cities only)
			maxamp = max(CITIES.factor(msk(:,2) >= mskmin));
			if forced
				maxamp = CITIES.factor(k1);
			end

			% gets a string date in the locale language
			[s,w] = wosystem(sprintf('LC_ALL=%s.ISO8859-1 date -d "%s" +"%%A %%d %%B %%Y"',P.LOCALE,datestr(P.NOW,'yyyy-mm-dd')),P,'chomp');
			if s
				E.report_date = datestr(P.NOW,'dddd dd mmmm yyyy');
			else
				E.report_date = w;
			end
			E.report_time = datestr(P.NOW,'HH:MM');

			% defines event description parameters
			[s,w] = wosystem(sprintf('LC_ALL=%s.ISO8859-1 date -d "%s" +"%%A %%d %%B %%Y|%%H:%%M TU|"',P.LOCALE,datestr(t(n),'yyyy-mm-dd HH:MM')),P,'chomp');
			if s
				w = datestr(t(n),'dddd dd mmmm yyyy|HH:MM TU');
			end
			ww = split(w,'|');
			E.long_date = ww{1};
			E.time = ww{2};
			[s,w] = wosystem(sprintf('LC_ALL=%s.ISO8859-1 date -d "%s" +"%%A %%d %%B %%Y|%%H:%%M|"',P.LOCALE,datestr(t(n) + P.TZ/24,'yyyy-mm-dd HH:MM')),P,'chomp');
			if s
				w = datestr(t(n) + P.TZ/24,'dddd dd mmmm yyyy|HH:MM TU');
			end
			ww = split(w,'|');
			E.long_date_local = ww{1};
			E.time_local = ww{2};
			if isfield(MAG,P.LOCALE)
				locale = P.LOCALE;
			else
				locale = 'en_EN';
			end
			E.quake_magnitude = sprintf('%1.1f',d(n,4));
			E.quake_strength  = MAG(max([1,floor(str2double(E.quake_magnitude))])).(locale);
			E.quake_latitude  = sprintf('%1.2f%c%c',abs(d(n,1)),char(176),char('N' + (d(n,1)<0)*('S'-'N')));
			E.quake_longitude = sprintf('%1.2f%c%c',abs(d(n,2)),char(176),char('E' + (d(n,2)<0)*('W'-'E')));
			if d(n,3) < 1
				E.quake_depth = P.LESS_1KM_TEXT;
			else
				E.quake_depth = sprintf('%1.0f km',d(n,3));
			end
			if ~isempty(c{n,4})
				E.quake_type = c{n,4}; % event type from comment 
			else
				E.quake_type = c{n,3}; % from type
			end
			E.quake_mag_type = c{n,2}; % magnitude type
			if size(d,2) > 11
				E.quake_mag_error = sprintf('%1.1f',d(n,12)); % magnitude error
			end
			E.city            = CITIES.name{kepi};
			E.region          = CITIES.region{kepi};
			[~,~,xepi,xazi] = greatcircle(CITIES.lat(kepi),CITIES.lon(kepi),d(n,1),d(n,2),2);
			epi = xepi(2);
			E.azimuth         = azimuth(xazi(1),P.LOCALE);
			if epi < 1
				E.epicentral = P.LESS_1KM_TEXT;
			else
				E.epicentral = sprintf('%1.0f km',epi);
			end
			E.hypocentral     = sprintf('%1.0f km',sqrt(epi^2 + d(n,3)^2));
			E.pga             = sprintf('%g',roundsd(pga(kepi,1),nbsig));
			E.msk             = msk2str(msk(kepi,1));
			E.long_msk        = MSK(max(floor(msk(kepi,1)),1)).name;
			E.msk_max         = msk2str(msk(kepi,2));
			E.long_msk_max    = MSK(max(round(msk(kepi,2)),1)).name;
			E.additional_text = P.ADDITIONAL_TEXT;
			
			% watermak
			if isfield(P,'WATERMARK')
				watermark = P.WATERMARK;
			else
				watermark = '';
			end
			if strcmp(c(n,5),'automatic')
				watermark = P.WATERMARK_AUTO;
				maintext = readtextfile(P.REPORT_AUTO_FILE);
				gse_title = P.GSE_AUTO_TITLE;
				gse_evtype = 'uk';
			elseif forced
				maintext = readtextfile(P.REPORT_FELT_FILE);
				gse_title = P.GSE_TITLE;
				gse_evtype = 'ke';
			else
				maintext = readtextfile(P.REPORT_TEXT_FILE);
				gse_title = P.GSE_TITLE;
				gse_evtype = 'ke';
			end
				
			% ===========================================================
			% makes the figure

			figure; orient tall
			set(gcf,'PaperUnit','inches','PaperType','A4');
			set(gcf,'PaperPosition',pps);
		
			% event text
			axes('Position',[.05,.73,.9,.17]);

			if ~isempty(watermark)
			    text(.5,.5,watermark,'FontSize',72,'FontWeight','bold','Color',[1,.8,.8],'Rotation',10, ...
			    'HorizontalAlignment','center','VerticalAlignment','middle');
			end
			
			text(1,1,varsub(P.REPORT_DATE,E),'horizontalAlignment','right','VerticalAlignment','top','FontSize',10);
			text(.5,.7,{varsub(P.EVENT_TITLE1,E,'tex'),varsub(P.EVENT_TITLE2,E)}, ...
			     'horizontalAlignment','center','VerticalAlignment','middle','FontSize',14,'FontWeight','bold');

			text(0,0,varsub(maintext,E),'horizontalAlignment','left','VerticalAlignment','bottom','FontSize',10);
			set(gca,'XLim',[0,1],'YLim',[0,1]), axis off
			isz1 = size(A1);
			isz3 = size(A3);

			pos = [0.03,1-isz1(1)/(P.PPI*pps(4)),isz1(2)/(P.PPI*pps(3)),isz1(1)/(P.PPI*pps(4))];
			
			% logos and main title
			axes('Position',pos,'Visible','off');
			image(A1), axis off
			axes('Position',[sum(pos([1,3]))+.03,pos(2),.95-sum(pos([1,3])),pos(4)]);
			text(0,1,varsub({P.TITLE1,P.TITLE2},E), ...
			    'VerticalAlignment','top','FontSize',16,'FontWeight','bold','Color',.3*[0,0,0]);
			text(0,0,{P.SUBTITLE1,P.SUBTITLE2,P.SUBTITLE3}, ...
			     'VerticalAlignment','bottom','FontSize',8,'Color',.3*[0,0,0]);
			set(gca,'YLim',[0,1]), axis off
			% logo B3
			pos = [.95 - isz3(2)/(P.PPI*pps(4)),1-isz3(1)/(P.PPI*pps(4)),isz3(2)/(P.PPI*pps(3)),isz3(1)/(P.PPI*pps(4))];
			axes('Position',pos,'Visible','off');
			image(A3), axis off
			
			% ---- map
			%pos0 = [.092,.08,.836,.646];
			axes('Position',pos0);
			basemap(d(n,:),xylim,DEM,MSK,P,maxamp,cmap,amap)
			h = dd2dms(gca,0);
			set(h,'FontSize',7)

			% adds all felt cities
			%plot(CITIES.lon(kfelt),CITIES.lat(kfelt),'s','MarkerSize',6,'LineWidth',1,'MarkerEdgeColor','k','MarkerFaceColor','none')
			% adds closest city
			if citiesdisplaylist
				plot(CITIES.lon(kepi),CITIES.lat(kepi),'s','MarkerSize',P.GTABLE(1).MARKERSIZE,'LineWidth',2,'MarkerEdgeColor','k','MarkerFaceColor','none')
				if cosd(xazi(1)) > 0
					ctxt = {CITIES.name{kepi},'',''};
				else
					ctxt = {'','',CITIES.name{kepi}};
				end
				text(CITIES.lon(kepi),CITIES.lat(kepi),ctxt, ...
					'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',P.GTABLE(1).MARKERSIZE,'FontWeight','bold')
			end
			hold off
			
			% ---- inset with epicentral zoom
			if epi < str2double(P.MAP_INSET_EPIMAX)
				if epi > 8
				    depi = 20;  % inset half width (km)
				    dsc = 10;   % inset scale (km)
				    fsv = 8;    % city name fontsize
				    msv = 6;    % city markersize
				else
				    depi = 10;
				    dsc = 5;
				    fsv = 11;
				    msv = 8;
				end
				ect = [d(n,2) + depi/degkm(d(n,1))*[-1,1],d(n,1) + depi/degkm*[-1,1]];
				% tracé du carré sur la carte principale
				hold on
				plot(ect([1,2,2,1,1]),ect([3,3,4,4,3]),'w-','LineWidth',2);
				plot(ect([1,2,2,1,1]),ect([3,3,4,4,3]),'k-','LineWidth',.1);
				hold off
				w1 = .3;    % taille relative de l'encart (par rapport à la page)
				axes('Position',[pos0(1)+pos0(3)-(w1+.01),pos0(2)+pos0(4)-(w1+.01)*pps(3)/pps(4),w1,w1*pps(3)/pps(4)]);
				
				basemap(d(n,:),ect,DEM,MSK,P,maxamp,cmap,amap)
				hold on
				plot(ect([1,2,2,1,1]),ect([3,3,4,4,3]),'k-','LineWidth',2);
				k = find(CITIES.lon > ect(1) & CITIES.lon < ect(2) & CITIES.lat > ect(3) & CITIES.lat < ect(4));
				plot(CITIES.lon(k),CITIES.lat(k),'s','MarkerSize',msv,'LineWidth',2,'MarkerEdgeColor','k','MarkerFaceColor','none')
				text(CITIES.lon(k),CITIES.lat(k)+.05*depi/degkm,CITIES.name(k),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',fsv,'FontWeight','bold')
				xsc = ect(1) + .75*diff(ect(1:2));
				ysc = ect(3)+.03*diff(ect(3:4));
				plot(xsc+dsc*[-.5,.5]/degkm(d(n,1)),[ysc,ysc],'-k','LineWidth',2)
				text(xsc,ysc,sprintf('%d km',dsc),'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold')
				hold off
				axis off
			end
			
			axes('Position',pos0);
			axis([0,1,0,1]), axis off

			% ---- list of cities and mean/max intensities
			if citiesdisplaylist
				tfont = 7;
				hligne = tfont*.01/4.3;
				lrect = 1.3/4.3;
				posx = lrect/2 + .12/4.3;
				maxlines = 55; % maximum number of lines
				if ~isempty(kcom)
				    ncom = length(kcom);
				else
				    ncom = 2;
				end
				hrect = (min(ncom + length(kregion) + 2*(~isempty(kregion)),maxlines) + 3)*hligne;
				h = rectangle('Position',[.05/4.3,.05/4.15,lrect,hrect]);
				set(h,'FaceColor','w')
				h = rectangle('Position',[.05/4.3,hrect + (.05 - .16)/4.15,lrect,.16/4.15]);
				set(h,'FaceColor','k')
				
				text(.05/4.3 + lrect/2,.05/4.15 + hrect,{P.LIST_TITLE1,P.LIST_TITLE2}, ...
					'HorizontalAlignment','center','VerticalAlignment','top','FontSize',tfont,'Color',.999*[1,1,1]);
				if isempty(kcom)
				    posy = hrect - 4*hligne;
				    text(posx,posy,{P.LIST_UNFELT1,P.LIST_UNFELT2},'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',tfont)
				else
				    for ii = 1:ncom
					posy = hrect - (ii + 2)*hligne;
					if ii >= maxlines
						text(posx,posy,'{\bf...}','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',tfont);
						break
					else
						text(posx,posy,CITIES.name{kcom(ii)},'HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',tfont);
						text(posx,posy,sprintf(' : {\\bf%s}',msk2str(msk(kcom(ii),1))),'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',tfont);
						text(posx + .27/4.3,posy,sprintf('(%s)',msk2str(msk(kcom(ii),2))),'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',tfont);
					end
				     end
				end
				
				if ~isempty(kregion) && ncom < maxlines
				    text(posx,hrect - (ncom + 3.7)*hligne,P.LIST_OUTOF, ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',tfont);
					for ii = 1:length(kregion)
						posy = hrect - (ncom + ii + 4)*hligne;
						if (ii + ncom + 3) > maxlines
							text(posx,posy,'{\bf...}','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',tfont);
							break
						else
							text(posx,posy,CITIES.name{kregion(ii)},'HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',tfont);
							text(posx,posy,sprintf(' : {\\bf%s}',msk2str(msk(kregion(ii),1))),'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',tfont);
							text(posx + .27/4.3,posy,sprintf('(%s)',msk2str(msk(kregion(ii),2))),'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',tfont);
						end
					end
				end
			end

			% ---- copyright
			text(1.01,0,txtb3,'Rotation',90,'HorizontalAlignment','left','VerticalAlignment','top','FontSize',7);
			
			
			% ---- Legend table for intensities and PGA
			axes('Position',[.03,.022,.95,.068]);
			sz = length(pgamsk) - 1;
			headers = split(P.TABLE_HEADERS,',');
			% colorscale
			xx = linspace(2,sz+2,256)/(sz+2);
			pcolor(xx,repmat([0;1/4],[1,length(xx)]),repmat(linspace(log10(pgamsk(1)),log10(pgamsk(10)),length(xx)),[2,1]))
			shading flat, caxis(log10(pgamsk([1,10])))
			colormap(shademap(cmap,amap))
			hold on
			% borders
			plot([0,0,1,1,0],[0,1,1,0,0],'-k','LineWidth',2);
			for ii = 1:3
			    plot([0,1],[ii,ii]/4,'-k','LineWidth',.1);
			end
			for ii = 2:(sz+1)
			    plot([ii,ii]/(sz+2),[0,1],'-k','LineWidth',.1);
			end
			text(1/(sz+2),3.5/4,sprintf('{\\bf%s}',headers{1}),'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			for ii = 1:sz
			    xx = (ii + 1.5)/(sz+2);
			    text(xx,3.5/4,MSK(ii).human,'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			end
			text(1/(sz+2),2.5/4,sprintf('{\\bf%s}',headers{2}),'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			for ii = 1:sz
			    xx = (ii + 1.5)/(sz+2);
			    text(xx,2.5/4,MSK(ii).damages,'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			end
			text(1/(sz+2),1.5/4,sprintf('{\\bf%s}',headers{3}),'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			for ii = 1:sz
			    xx = (ii + 1.5)/(sz+2);
			    switch ii
			    case 1 
				ss = sprintf('< %g',roundsd(pgamsk(ii+1),nbsig));
			    case sz
				ss = sprintf('> %g',roundsd(pgamsk(ii),nbsig));
			    otherwise
				ss = sprintf('%g - %g',roundsd(pgamsk([ii,ii+1]),nbsig));
			    end
			    text(xx,1.5/4,ss,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			end
			text(1/(sz+2),.5/4,sprintf('{\\bf%s}',headers{4}),'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
			for ii = 1:sz
			    xx = (ii + 1.5)/(sz+2);
			    switch ii
			    case sz
				ss = sprintf('%s+',msk2str(ii));
			    otherwise
				ss = msk2str(ii);
			    end
			    sc = zeros(1,3); % normal black color
			    if any(ii == twmsk)
				    sc = .99*ones(1,3);
			    end
			    text(xx,.5/4,ss,'Color',sc,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',9);
			end
			text(0,0,{P.FOOTNOTE1,P.FOOTNOTE2},'HorizontalAlignment','left','VerticalAlignment','top','FontSize',7);
			hold off
			set(gca,'XLim',[0,1],'YLim',[0,1]), axis off                    

			mkgraph(WO,fnam,P.GTABLE(1))
			lastb3 = P.GTABLE(1).EVENTS;
			close
			
			% ===========================================================
			% exports GSE file
			fgse = sprintf('%s/%s.gse',pdat,fnam);
			fprintf('%s: exporting GSE file %s ...',wofun,fgse);
			fid = fopen(fgse,'wt');
			fprintf(fid,'BEGIN GSE2.0\n');
			fprintf(fid,'MSG_TYPE DATA\n');
			fprintf(fid,'MSG_ID %s %s\n',fnam,WO.WEBOBS_ID);
			fprintf(fid,'DATA_TYPE EVENT GSE2.0\n');
			fprintf(fid,'%s\n',varsub(gse_title,E));
			fprintf(fid,'EVENT %s\n',id);
			fprintf(fid,'   Date       Time       Latitude Longitude    Depth    Ndef Nsta Gap    Mag1  N    Mag2  N    Mag3  N  Author          ID \n');
			fprintf(fid,'     rms   OT_Error      Smajor Sminor Az        Err   mdist  Mdist     Err        Err        Err     Quality\n\n');
			fprintf(fid,'%4d/%02d/%02d %02d:%02d:%04.1f    %8.4f %9.4f    %5.1f              %03d  %2s%4.1f                           %-8.8s  %02.0f%03.0f%03.0f\n', ...
				datevec(t(n)),d(n,[1,2,3,5]),c{n,2},d(n,4),WO.WEBOBS_ID,d(n,[1,2,3]));
			fprintf(fid,'     %5.2f   +-          %6.1f %6.1f         +-%5.1f                                                  %-1.1s i %s\n', ...
				d(n,[6,7,7,8]),c{n,5},gse_evtype);
			fprintf(fid,'\n%s\n',upper(varsub(P.GSE_COMMENT,E)));
			fprintf(fid,'\n\nSTOP\n');
			fclose(fid);
			fprintf(' done.\n');

			% ===========================================================
			% exports a comprehensive text message (for notification)
			msg = strjoin(regexprep(varsub(maintext,E),'{\\bf|}',''),' ');
			fmsg = sprintf('%s/%s.msg',pdat,fnam);
			fprintf('%s: exporting MSG file %s ...',wofun,fmsg);
			fid = fopen(fmsg,'wt');
			fprintf(fid,'%s',msg);
			fclose(fid);
			fprintf(' done.\n');

			% ===========================================================
			% creates symbolic links to preferred (last) files
			for ext = {'txt','gse','pdf','jpg','png','msg'}
				if exist(sprintf('%s/%s.%s',pdat,fnam,ext{:}),'file')
					wosystem(sprintf('ln -fs %s.%s %s/b3.%s',fnam,ext{:},pdat,ext{:}),P);
				end
			end

			% ===========================================================
			% make email message
			f = sprintf('%s/mail.txt',pdat);
			fid = fopen(f,'wt');
			fprintf(fid,'\n\n%s %s\n\n',P.TITLE1,P.TITLE2);
			fprintf(fid,'%s\n',varsub(P.REPORT_DATE,E));
			fprintf(fid,'%s\n',msg);
			fprintf(fid,'\n\n');
			if ~P.REQUEST
				% root URL
				if isfield(WO,'ROOT_URL')
					url = WO.ROOT_URL;
				else
					url = 'http://webobs';
				end
				fprintf(fid,'%s/cgi-bin/showOUTG.pl?grid=%s&ts=events&g=%s/%s\n',url,P.SELFREF,P.GTABLE(1).EVENTS,fnam);
			end
			fclose(fid);

			if ~P.REQUEST && isfield(P,'NOTIFY_EVENT') && ~isempty(P.NOTIFY_EVENT)
				if isfield(P,'NOTIFY_EMAIL_SUBJECT')
					subject = sprintf(' subject=%s',varsub(P.NOTIFY_EMAIL_SUBJECT,E));
				else
					subject = '';
				end
				notify(WO,P.NOTIFY_EVENT,'!',sprintf('file=%s%s',f,subject));
			end

			% ===========================================================
			% exports KML file
			fkml = sprintf('%s/%s.kml',pdat,fnam);
			fprintf('%s: exporting KML file %s ...',wofun,fkml);
			ipe2kml(fkml,d(n,:),P.GMPE,P.GMICE)
			fprintf(' done.\n');
		end % of report
	end

	% purge event (remove symbolic link)
	if e(n) < 0 && exist(sprintf('%s/b3.jpg',pdat),'file')
		wosystem(sprintf('rm -f %s/b3*',pdat),P,'warning');
		wosystem(sprintf('mv -f %s/%s.txt{,.purged}',pdat,fnam),P,'warning');
		fprintf('%s: ** WARNING ** event %s has been purged.\n',wofun,pdat);
	end

end

if P.REQUEST
	mkendreq(WO,P);
else
	if ~isempty(lastb3)
		lnk = sprintf('%s/%s/lastevent',P.GTABLE(1).OUTDIR,WO.PATH_OUTG_EVENTS);
		wosystem(sprintf('rm -f %s',lnk),P);
		wosystem(sprintf('ln -s %s %s',lastb3,lnk),P);
	end
end

timelog(procmsg,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function basemap(eq,xylim,DEM,MSK,P,maxamp,cmap,amap)
%BASEMAP makes the map (intensities over shaded relief)

% computed the shaded relief image
I = dem(DEM.lon,DEM.lat,DEM.z,'latlon','noplot','crop',xylim,DEM.opt{:});
[x,y] = meshgrid(I.x,I.y);
% hypocentral distance on the grid XY + relief
xydhp = sqrt(greatcircle(y,x,eq(1),eq(2)).^2 + (I.z/1e3 + eq(3)).^2);
% PGA on the grid XY
xypga = 1e3*gmpe(P.GMPE,eq(4),xydhp);

topofilter = field2num(P,'TOPOVS30_FILTER',9);
if isok(P,'TOPOVS30')
	F = topovs30(I.x,I.y,I.z,xypga,'latlon','nozero');
	xypga = xypga.*F.f;
end

cax = log10(gmice([1,10],P.GMICE,'reverse'));
inorm = (log10(xypga) - cax(1))/diff(cax); % normalized intensities (I,X) => (0,1)
inorm(inorm<0) = 0;
inorm(inorm>1) = 1;
I.msk = ind2rgb(round(size(cmap,1)*inorm),cmap); % RGB map of intensities

% transparency follows colormap alpha relation
A = repmat(interp1(linspace(0,1,length(amap)),amap,inorm),[1,1,3]); 

% adds intensity color to shaded relief
I.tot = I.rgb.*(1 - A) + I.msk.*A;
%I.tot = I.rgb./2 + I.msk./2;
if isok(P,'MAP_LANDONLY',1)
	k = (repmat(I.z,[1,1,3])<=0);
	I.tot(k) = I.rgb(k);
end

imagesc(I.x,I.y,I.tot), axis xy
hold on
if isfield(DEM,'c') && ~isempty(DEM.c)
	pcontour(DEM.c,'k')
end
axis(xylim)

% --- plots intensity contours
xymsk = gmice(xypga,P.GMICE);
if isok(P,'TOPOVS30')
	%f = [.05 .1 .05; .1 .4 .1; .05 .1 .05];
	f = ones(topofilter)/topofilter^2;
	xymsk = conv2(xymsk,f,'same');
end
imax = ceil(max(xymsk(I.z>0)));	% max intensity on land
fact = 1e3; % this factor multiplies intensity values to gives contour labels enough space for roman numerals
for ii = 2:imax
	[cs,h] = contour(I.x,I.y,fact*xymsk,fact*[ii,ii]);
	set(h,'LineWidth',str2double(MSK(ii).lw),'EdgeColor','k');
	if ~isempty(h)
		hl = clabel(cs,h,'FontSize',12);
		lb = get(hl,'UserData');
		% replacing numbers by roman
		for iii = 1:length(hl)
			if iscell(lb)
			    lbb = lb{iii}/fact;
			else
			    lbb = lb(iii)/fact;
			end
			set(hl(iii),'String',sprintf('%s',msk2str(lbb)),'FontWeight','bold','FontSize',12);
		end
	end
end
% limits of felt area (intensity II with amplified PGA)
xymskmax = gmice(xypga*maxamp,P.GMICE);
if isok(P,'TOPOVS30')
	%xymskmax = conv2(xymskmax,f,'same');
	xymskmax = gmice(xypga*maxamp./F.f,P.GMICE);	% better simplified limit without topographic effects.
end
cs = contourc(I.x,I.y,xymskmax,[2,2]);
if ~isempty(cs)
	h = pcontour(cs,'k');
	set(h,'LineStyle',':','LineWidth',.25);
end
    
% epicenter marker
opt = {'p','MarkerSize',10,'MarkerEdgeColor','r','MarkerFaceColor','w','LineWidth',1.5};
if isfield(P,'EPICENTER_PLOT_OPT')
	try
		eval(sprintf('opt={%s};',strrep(P.EPICENTER_PLOT_OPT,'''''','''')));
	catch
		fprintf('%s: ** Warning: invalid EPICENTER_PLOT_OPT value... using default.\n',wofun);
	end
end
plot(eq(2),eq(1),opt{:})



