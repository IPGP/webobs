function DOUT=hypomap(varargin)
%HYPOMAP WebObs SuperPROC: Updates graphs/exports of earthquake catalogs.
%
%       HYPOMAP(PROC) makes default outputs of PROC.
%
%       HYPOMAP(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	HYPOMAP(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = HYPOMAP(PROC,...) returns a structure D containing all the PROC data:
%           D.id = node ID
%           D.t = time vector (for node i)
%           D.d = matrix of data (NaN = invalid data)
%           D.c = matrix of char data (cell)
%           D.e = vector of quality filter (>0 is OK)
%
%       HYPOMAP will use PROC's parameters from .conf file. RAWFORMAT must be
%       one of the following: hyp71sum2k, fdsnws-event, scevtlog-xml
%
%       Specific paramaters are (some will be used by readfmtdata_quake.m):
%		EVENTTYPE_EXCLUDED_LIST|not existing,not locatable,outside of network interest,sonic boom,duplicate,other event
%		EVENTSTATUS_EXCLUDED_LIST|automatic
%		EVENTCOMMENT_EXCLUDED_REGEXP|AUTO
%		SC3_LISTEVT|
%		LATLIM|13,19
%		LONLIM|-64,-58
%		MAGLIM|3,10
%		DEPLIM|-10,200
%		MSKLIM|1,12
%		GAPLIM|0,360
%		RMSLIM|0,1
%		ERHLIM|0,100
%		ERZLIM|0,100
%		NPHLIM|3,Inf
%		CLALIM|0,4
%		QUALITY_FILTER|Y
%		PLOT_BG_ALL|.3
%		DEM_OPT|'WaterMark',2,'FontSize',7
%		SHAPE_FILE|$WEBOBS{PATH_DATA_SHAPE}/antilles_faults.bln
%		MARKER_LINEWIDTH|1
%		BUBBLE_PLOT|Y
%		MAP_Areaname_TITLE|Antilles
%		MAP_Areaname_XYLIM|LON0,LAT0,WIDTH # or LON1,LON2,LAT1,LAT2 (needs to be a square in km)  
%		MAP_Areaname_MAGLIM|3,7
%		MAP_Areaname_DEPLIM|-2,200
%		MAP_Areaname_PROFILE1|-61.4651,16.5138,68,100,200
%		MAP_Areaname_PROFILE2|-61.4651,16.5138,158,100,200 # optional 2nd profile
%		MAP_Areaname_COLORMAP|jet(256)
%
%   Authors: F. Beauducel, J.M. Saurel and F. Massin / WEBOBS, IPGP
%   Created: 2014-11-25 in Paris, France
%   Updated: 2018-08-02


WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = sprintf(' %s',mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration and associated nodes for any TSCALE and/or REQDIR
[P,N,D] = readproc(WO,varargin{:});

% concatenates all nodes data
t = cat(1,D.t);
d = cat(1,D.d);
c = cat(1,D.c);
e = cat(1,D.e);
CLB = D(1).CLB;

pszratio = 5.5;

qualityfilter = isok(P,'QUALITY_FILTER');
plotbgall = field2num(P,'PLOT_BG_ALL',0);
linewidth = field2num(P,'MARKER_LINEWIDTH',1);
bubbleplot = isok(P,'BUBBLE_PLOT');

demopt = {};
if isfield(P,'DEM_OPT')
	try
		eval(sprintf('demopt={%s};',regexprep(P.DEM_OPT,'''''','''')));
	catch
		fprintf('WEBOBS{hypomap}: ** Warning: invalid DEM_OPT value... using default.\n');
	end
end

if isfield(P,'SHAPE_FILE') && exist(P.SHAPE_FILE,'file')
	faults = ibln(P.SHAPE_FILE);
else
	faults = [];
end

if isfield(P,'SUMMARYLIST')
        summarylist = P.SUMMARYLIST;
else
        summarylist = {''};
end

% default colormap
cmap = jet(256);
cmap(237:end,:) = [];

% gets map's parameters in a structure
for m = 1:length(summarylist)
	map = summarylist{m};

	% --- gets parameters for the map
	% title
	M(m).title = P.(sprintf('MAP_%s_TITLE',map));
	% map geographical limits: lon1,lon2,lat1,lat2
	M(m).xylim = sstr2num(P.(sprintf('MAP_%s_XYLIM',map)));
	if numel(M(m).xylim) == 3
		M(m).xylim = xyw2lim(M(m).xylim,1/cosd(M(m).xylim(2)));
	end

	% magnitude limits (for marker size scaling)
	M(m).mlim = field2num(P,sprintf('MAP_%s_MAGLIM',map),P.MAGLIM);
	% depth limits (for marker color scaling)
	M(m).dlim = field2num(P,sprintf('MAP_%s_DEPLIM',map),P.DEPLIM);
	% colormap
	M(m).cmap = field2num(P,sprintf('MAP_%s_COLORMAP',map),cmap,'val');
	% color reference for markers: 'depth' (default) or 'time'
	M(m).cref = field2str(P,sprintf('MAP_%s_COLORREF',map),'depth');
	% optional profile 1 (bottom): point latitude, point longitude, azimuth (degree North), width (km), depth (km)
	M(m).prof1 = field2num(P,sprintf('MAP_%s_PROFILE1',map));
	% optional profile 2 (right): point latitude, point longitude, azimuth (degree North), width (km), depth (km)
	M(m).prof2 = field2num(P,sprintf('MAP_%s_PROFILE2',map));
	% optional time plot: list of parameters (latitude,longitude,depth,profile1,profile2) vs time
	M(m).tplot = split(field2str(P,sprintf('MAP_%s_TIMEPLOT',map)),',');
	% DEM basemap options (see dem.m for complete description)
	fm = sprintf('MAP_%s_DEM_OPT',map);
	M(m).demopt = demopt;
	if isfield(P,fm)
		try
			eval(sprintf('M(m).demopt={%s};',regexprep(P.(fm),'''''','''')));
		catch
			fprintf('WEBOBS{hypomap}: ** Warning: invalid MAP_%s_DEM_OPT value... using default.\n',map);
		end
	end
end

% do the job....
for m = 1:length(summarylist)
	map = summarylist{m};

	zlim = M(m).dlim;
	colortime = strcmpi(M(m).cref,'time');
	if ~colortime
		M(m).cmap = flipud(M(m).cmap);
	end

	% loads DEM
	DEM = loaddem(WO,M(m).xylim,P);

	for r = 1:length(P.GTABLE)
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(t);
		end

		% selects data (time window + map limits + quality filter)
		k = find(isinto(t,tlim) & (e > 0 | ~qualityfilter) & isinto(d(:,1),M(m).xylim(3:4)) & isinto(d(:,2),M(m).xylim(1:2)));
		[tk,kk] = sort(t(k));
		dk = d(k(kk),:);
		ck = c(k(kk),:);
		styp = {};
		if ~isempty(ck)
			T.c = ck(:,4); % takes comment field (if MC)
			kc = cellfun(@isempty,T.c);
			T.c(kc) = ck(kc,3);
			[T.u,T.ia,T.ic] = unique(T.c);
			for n = 1:length(T.u)
				styp = [styp{:},{sprintf('{\\bf%s} (%d),',deblank(T.u{n}),length(find(T.ic==n)))}];
			end
		end

		% init interactive maps
		IMAP = struct('d',[],'gca',[],'s',[],'l',[]);
		nimap = 1;


		figure, clf
		psz = [8,12];
		set(gcf,'PaperUnits','inches','PaperSize',psz,'PaperPosition',[0,0,psz])

		% --- main map
		%[FB-was] if ~isempty(M(m).prof1) & ~isempty(M(m).prof2)
		if numel(M(m).prof2)==5
			set(gcf,'PaperSize',[psz(1)+4,psz(2)])
			axes('position',[0.07,0.33,0.6,0.6]);
		else
			axes('position',[0.07,0.33,0.9,0.6]);
		end
		orient tall

		% basemap
		dem(DEM.lon,DEM.lat,DEM.z,'LatLon','AxisEqual','manual','Position','northwest',M(m).demopt{:})
		hold on

		% plots other maps limits
		for mm = 1:length(summarylist)
			if mm ~= m
				xy = M(mm).xylim;
				plot(xy([1,2,2,1,1]),xy([3,3,4,4,3]),'-k','LineWidth',.1)
			end
		end

		% faults
		if ~isempty(faults)
			plotbln(faults,.4*ones(1,3),[],.5);
		end

		% all events in background
		if plotbgall
			plot(d(:,2),d(:,1),'.','Color',(1-plotbgall)*ones(1,3),'MarkerSize',.1)
		end
		% marker size and color
		mks = (max((dk(:,4)-M(m).mlim(1))/diff(M(m).mlim),0)*5*P.GTABLE(r).MARKERSIZE).^2 + 1;
		if strcmpi(M(m).cref,'time')
			mkc = tk;
			clim = tlim;
		else
			mkc = dk(:,3);
			clim = zlim;
		end

		% felt events
		kf = find(dk(:,11)>1);
		if ~isempty(kf)
			scatter(dk(kf,2),dk(kf,1),mks(kf)*pszratio,'p','MarkerEdgeColor','k','LineWidth',linewidth)
		end
		if bubbleplot
			scatter(dk(:,2),dk(:,1),mks,'MarkerEdgeColor','k','LineWidth',linewidth)
			scatter(dk(:,2),dk(:,1),mks,mkc,'fill','MarkerEdgeColor','none')
		else
			scatter(dk(:,2),dk(:,1),mks,mkc,'fill','MarkerEdgeColor','k','LineWidth',linewidth)
		end
		IMAP(1).d = [dk(:,2),dk(:,1),sqrt(mks/pi)+1];
		IMAP(1).gca = gca;
		IMAP(1).s = cell(size(tk));
		IMAP(1).l = ck(:,6);
		for n = 1:length(IMAP(1).s)
			tevt = deblank(ck{n,3});
			if ~isempty(ck(n,4))
				tevt = deblank(ck{n,4}); % MC3 type might overwrite event type
			end
			IMAP(1).s{n} = sprintf('''%1.1f km %s=%1.1f (%s)'',CAPTION,''%s TU''', ...
				dk(n,3),ck{n,2},dk(n,4),tevt,datestr(tk(n),'dd-mmm-yyyy HH:MM'));
		end
		colormap(M(m).cmap)
		caxis(clim)

		if numel(M(m).prof1)==5
			[xp1,yp1] = plotcross(M(m).prof1,M(m).xylim,'A','B');
		end
		if numel(M(m).prof2)==5
			[xp2,yp2] = plotcross(M(m).prof2,M(m).xylim,'A''','B''');
		end
		hold off
		axis(M(m).xylim);

		% --- profile 1
		prof = M(m).prof1;
		if numel(prof)==5
			axes('position',[0.07,0.13,0.6,0.18])

			% in local referential (x0,y0) and km, cross-section line has equation a.x + b.y + c = 0, where c=0
			% and distance of any point (x,y) from line is abs(a.x + b.y + c)/sqrt(a^2 + b^2)
			pa = -sind(90-prof(3));
			pb = cosd(90-prof(3));

			% selects data in the cross section volume
			dx = (dk(:,2) - prof(1))*degkm(prof(2));
			dy = (dk(:,1) - prof(2))*degkm;
			dd =  abs(dx*pa + dy*pb);
			dl = dx*pb - dy*pa;
			k1 = find(dd <= prof(4));

			% plots topography profile along the cross section
			[pl,pz] = topocross(DEM,prof,xp1,yp1);
			plot(pl,pz,'-','Color',.2*ones(1,3))
			hold on
			if plotbgall
				plot((d(:,2) - prof(1))*degkm(prof(2))*pb - (d(:,1) - prof(2))*degkm*pa,d(:,3),'.','Color',(1-plotbgall)*ones(1,3),'MarkerSize',.1)
			end
			set(gca,'YDir','reverse','XLim',minmax(pl),'YLim',[min(min(pz(:)),zlim(1)),prof(5)],'FontSize',8)
			k = find(dk(k1,11)>1);
			if ~isempty(k)
				scatter(dl(k1(k)),dk(k1(k),3),mks(k1(k))*pszratio,'p','MarkerEdgeColor','k','LineWidth',linewidth)
			end
			if bubbleplot
				scatter(dl(k1),dk(k1,3),mks(k1),'MarkerEdgeColor','k','LineWidth',linewidth)
				scatter(dl(k1),dk(k1,3),mks(k1),mkc(k1),'fill','MarkerEdgeColor','none')
			else
				scatter(dl(k1),dk(k1,3),mks(k1),mkc(k1),'fill','MarkerEdgeColor','k','LineWidth',linewidth)
			end
			caxis(clim)
			hold off
			text(pl([1,end]),pz([1,end]),{'   A','B   '},'FontSize',14,'FontWeight','bold','VerticalAlignment','top','HorizontalAlignment','center')
			ylabel('Depth (km)')
			xlabel('Projected distance on cross-section A-B (km)')

			nimap = nimap + 1;
			IMAP(nimap).d = [dl(k1),dk(k1,3),sqrt(mks(k1)/pi)+1];
			IMAP(nimap).gca = gca;
			IMAP(nimap).s = IMAP(1).s(k1);
			IMAP(nimap).l = IMAP(1).l(k1);
		end

		% --- profile 2
		prof = M(m).prof2;
		if numel(prof)==5
			axes('position',[0.70,0.33,0.23,0.6])

			% in local referential (x0,y0) and km, cross-section line has equation a.x + b.y + c = 0, where c=0
			% and distance of any point (x,y) from line is abs(a.x + b.y + c)/sqrt(a^2 + b^2)
			pa = -sind(90-prof(3));
			pb = cosd(90-prof(3));

			% selects data in the cross section volume
			dx = (dk(:,2) - prof(1))*degkm(prof(2));
			dy = (dk(:,1) - prof(2))*degkm;
			dd =  abs(dx*pa + dy*pb);
			dl = dx*pb - dy*pa;
			k1 = find(dd <= prof(4));

			% selects DEM data in the cross section volume
			[pl,pz] = topocross(DEM,prof,xp2,yp2);
			plot(pz,pl,'-','Color',.2*ones(1,3))
			hold on
			if plotbgall
				plot(d(:,3),(d(:,2) - prof(1))*degkm(prof(2))*pb - (d(:,1) - prof(2))*degkm*pa,'.','Color',(1-plotbgall)*ones(1,3),'MarkerSize',.1)
			end
			set(gca,'YAxisLocation','right','YLim',minmax(pl),'XLim',[min(min(pz(:)),zlim(1)),prof(5)],'FontSize',8)
			k = find(dk(k1,11)>1);
			if ~isempty(k)
				scatter(dk(k1(k),3),dl(k1(k)),mks(k1(k))*pszratio,'p','MarkerEdgeColor','k','LineWidth',linewidth)
			end
			if bubbleplot
				scatter(dk(k1,3),dl(k1),mks(k1),'MarkerEdgeColor','k','LineWidth',linewidth)
				scatter(dk(k1,3),dl(k1),mks(k1),mkc(k1),'fill','MarkerEdgeColor','none')
			else
				scatter(dk(k1,3),dl(k1),mks(k1),mkc(k1),'fill','MarkerEdgeColor','k','LineWidth',linewidth)
			end
			caxis(clim)
			hold off
			text(pz([1,end]),pl([1,end]),{'    A''','B''    '},'FontSize',14,'FontWeight','bold', ...
				'VerticalAlignment','top','HorizontalAlignment','center','rotation',90)
			xlabel('Depth (km)')
			ylabel('Projected distance on cross-section A''-B'' (km)')

			nimap = nimap + 1;
			IMAP(nimap).d = [dk(k1,3),dl(k1),sqrt(mks(k1)/pi)+1];
			IMAP(nimap).gca = gca;
			IMAP(nimap).s = IMAP(1).s(k1);
			IMAP(nimap).l = IMAP(1).l(k1);
		end
		
		
		% --- legend
		axes('position',[0.68,0.105,0.21,0.17]);
		
		% color scale (depth or time)
		wsc = 0.1;
		x = 0.5 - .28*colortime;
		y = linspace(0,1,length(M(m).cmap));
		if colortime
			zscale = linspace(clim(1),clim(2),length(M(m).cmap));
		else
			zscale = linspace(clim(2),clim(1),length(M(m).cmap));
		end
		ddz = dtick(diff(zscale([1,end])));
		ztick = (ddz*ceil(zscale(1)/ddz)):ddz:zscale(end);
		patch(x + repmat(wsc*[0;1;1;0],[1,length(M(m).cmap)]), ...
			[repmat(y,[2,1]);repmat(y + diff(y(1:2)),[2,1])], ...
		repmat(zscale,[4,1]), ...
			'EdgeColor','flat','LineWidth',.1,'FaceColor','flat','clipping','off')
		colormap(M(m).cmap)
		caxis(clim)
		hold on
		patch(x + wsc*[0,1,1,0],[0,0,1,1],'k','FaceColor','none','Clipping','off')
		if colortime
			patch(x + wsc*[0,.5,1],[1,1.05,1],'k','EdgeColor','none','FaceColor','k','Clipping','off')
		end
		if colortime
			slabel = '{\bfTime}';
			stick = datestr(ztick');
		else
			slabel = '{\bfDepth (km)}';
			stick = num2str(ztick');
		end
		text(x - .05,.5,{slabel,''},'HorizontalAlignment','center','rotation',90,'FontSize',8)
		text(x + 1.2*wsc + zeros(size(ztick)),(ztick - zscale(1))/diff(zscale([1,end])),stick, ...
			'HorizontalAlignment','left','VerticalAlignment','middle','FontSize',6)

		% magnitude scale
		magscale = M(m).mlim(1):M(m).mlim(2);
		x = ones(size(magscale));
		y = .9*(magscale-magscale(1))/diff(M(m).mlim);
		scatter(x,y,((magscale - M(m).mlim(1))/diff(M(m).mlim)*5*P.GTABLE(r).MARKERSIZE).^2 + 1,'MarkerEdgeColor','k','LineWidth',linewidth)
		text(x + .15,y,num2str(magscale'),'FontSize',7)
		text(1.3,.5,{'{\bfMagnitude}',''},'HorizontalAlignment','center','rotation',90,'FontSize',8)
		hold off
		set(gca,'XLim',[0,1],'YLim',[0,1])
		axis off


		% information panel
		P.GTABLE(r).INFOS2 = { 'Filters: '};
		for fn = {'MAG','DEP','MSK','GAP','RMS','ERH','ERZ','NPH','CLA'}
			if any(isfinite(P.([fn{:},'LIM'])))
				P.GTABLE(r).INFOS2 = [P.GTABLE(r).INFOS2,{sprintf('%s \\in [{\\bf%g},{\\bf%g}];',fn{:},P.([fn{:},'LIM']))}];
			end
		end
		P.GTABLE(r).INFOS = { ...
			sprintf('From: {\\bf%s}',datestr(tlim(1),'dd-mmm-yyyy HH:MM')), ...
			sprintf('     To: {\\bf%s}',datestr(tlim(2),'dd-mmm-yyyy HH:MM')), ...
			'', ...
			'', ...
			sprintf('  Total events = {\\bf%d}',size(dk,1)), ...
		};
		if ~isempty(tk)
			if ~any(isnan(minmax(dk(:,4))))
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS,{sprintf('  Magnitude: min {\\bf%1.1f} - max {\\bf%1.1f}',minmax(dk(:,4)))}];
			end
			if ~any(isnan(minmax(dk(:,11))))
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS,{sprintf('  Intensity: min {\\bf%s} - max {\\bf%s}',num2roman(min(dk(:,11))),num2roman(max(dk(:,11))))}];
			end
			if ~isempty(styp)
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS,{sprintf('  Types:')}, styp];
			end
		end
		P.GTABLE(r).GTITLE = gtitle(M(m).title,P.GTABLE(r).TIMESCALE);
		OPT.IMAP = IMAP;
		OPT.FIXEDPP = true;
		mkgraph(WO,sprintf('%s_%s',map,P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% --- timeplot (new figure)
		if ~isempty(M(m).tplot)
			figure
			orient tall

			nx = length(M(m).tplot);
			% loop for each parameter
			for i = 1:nx
				subplot(nx*3,1,(i-1)*3+(1:3)), extaxes(gca,[.07,.02])
				switch lower(M(m).tplot{i})
				case 'latitude'
					td = dk(:,1);
				case 'longitude'
					td = dk(:,2);
				case 'depth'
					td = dk(:,3);
				case 'magnitude'
					td = dk(:,4);
				otherwise
					td = nan(size(dk,1),1);
				end
				if bubbleplot
					scatter(tk,td,mks,'MarkerEdgeColor','k','LineWidth',linewidth)
					hold on
					scatter(tk,td,mks,mkc,'fill','MarkerEdgeColor','none')
					hold off
				else
					scatter(tk,td,mks,mkc,'fill','MarkerEdgeColor','k','LineWidth',linewidth)
				end
				set(gca,'XLim',tlim,'FontSize',8)
				datetick2('x',P.GTABLE(r).DATESTR)
				if i < nx
					set(gca,'XTickLabel',[]);
				end
				ylabel(M(m).tplot{i})
				box on
			end
			tlabel(tlim,P.GTABLE(r).TZ)

			P.GTABLE(r).GTITLE = gtitle(M(m).title,P.GTABLE(r).TIMESCALE);

			mkgraph(WO,sprintf('%s_time_%s',map,P.GTABLE(r).TIMESCALE),P.GTABLE(r))
			close
		end

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			E.t = tk;
			E.d = dk;
			E.header = CLB.nm;
			E.title = sprintf('%s {%s}',M(m).title,proc);
			mkexport(WO,sprintf('%s_%s',map,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
end

if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [xp,yp]=plotcross(prof,xylim,a,b)
%PLOTCROSS Plots cross-section

lw = .5;

% if profile azimuth above 45°, plots the cross section lines from X axis limits
if abs(tand(prof(3))) >= 1 
	xp = xylim(1:2);
	yp = prof(2) + [xylim(1)-prof(1),xylim(2)-prof(1)]*tand(90-prof(3));
	plot(repmat(xp,2,1)',repmat(yp,2,1)' + [1,-1;1,-1]*prof(4)/degkm(prof(2))/cosd(90-prof(3)),':k','LineWidth',lw)
% else from Y axis...
else
	yp = xylim(3:4);
	xp = prof(1) + [xylim(3)-prof(2),xylim(4)-prof(2)]*tand(prof(3));
	plot(repmat(xp,2,1)' + [1,-1;1,-1]*prof(4)/degkm(prof(2))/cosd(prof(3)),repmat(yp,2,1)',':k','LineWidth',lw)
end
plot(xp,yp,'-.k','LineWidth',lw)	
%text(prof(1),prof(2),'+','HorizontalAlignment','center','rotation',90-prof(3))
text(xp,yp,{['     ',a],[b,'     ']},'FontSize',12,'FontWeight','bold', ...
	'VerticalAlignment','middle','HorizontalAlignment','center','rotation',90-prof(3))


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [pl,pz]=topocross(DEM,prof,xp,yp)
%TOPOCROSS Computes topographic profile in cross-section

xx = linspace(xp(1),xp(2),500);
yy = linspace(yp(1),yp(2),500);
pl = (xx - prof(1))*degkm(prof(2))*cosd(90-prof(3)) + (yy - prof(2))*degkm*sind(90-prof(3));
pz = interp2(DEM.lon,DEM.lat,-DEM.z/1e3,xx,yy);

