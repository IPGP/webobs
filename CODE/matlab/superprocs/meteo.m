function DOUT=meteo(varargin)
%METEO	WebObs SuperPROC: Updates graphs/exports of METEO results.
%
%       METEO(PROC) makes default outputs of PROC from associated nodes
%       that contain meteorological data. The graph contains wind rose
%       histogram and direction graph, a rain gauge graph with cumulated
%       curve and possible alerts, and a user-defined XY graph.
%
%       METEO(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	METEO(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = METEO(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%	METEO will use PROC's parameters from NODE's .cnf file. Particularily, it
%       uses RAWFORMAT and and associated NODEs' calibration file channels
%       definition. Data must contain a rain gauge channel, a wind speed and wind
%       azimuth channels, and optionaly any other parameters. In the following channel
%       numbers refer to NODE's calibration file channel numbers.
%
%       The rain gauge channel number must be set using this key (default is
%       channel 6):
%	    RAIN_CHANNEL|6
%	If rain data are already cumulated, set this key to Y:
%	    RAIN_CUMSUM_DATA|N
%	
%	Wind speed and azimuth channels numbers are set with (defaults are 5 and 4):
%	    WIND_SPEED_CHANNEL|5
%	    WIND_AZIMUTH_CHANNEL|4
%	    WIND_ROSE_STEP|10
%	Azimuth data must be in degrees from North (°N), clockwise.
%
%	X-Y graph is set using the x,y channel numbers as (default is 8 vs. 3):
%	    XY_CHANNELS|3,8
%
%       Below these graphs can be set a list of channels as time series:
%           NODE_CHANNELS|1,2,7,4,5,3,8
%
%	Additional keys can be defined to compute rain alerts: RAIN_ALERT_THRESHOLD
%	is the amount of cumulated rain (same unit as RAIN_CHANNEL) per RAIN_ALERT_INTERVAL
%	(in days), and last for RAIN_ALERT_DELAY days; example:
%	    RAIN_ALERT_THRESHOLD|50
%	    RAIN_ALERT_INTERVAL|1
%	    RAIN_ALERT_DELAY|3
%	    RAIN_ALERT_RGB|1,.3,.3
%	    RAIN_ALERT_DELAY_RGB|1,.6,.6

%
%   Authors: F. Beauducel + S. Acounis / WEBOBS, IPGP
%   Created: 2001-07-04
%   Updated: 2017-08-02

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

% proc's specific variables
i_winds = field2num(P,'WIND_SPEED_CHANNEL',5);
i_winda = field2num(P,'WIND_AZIMUTH_CHANNEL',4);
wind_step = field2num(P,'WIND_ROSE_STEP',10);    % step for rose diagram (in degrees)
i_rain = field2num(P,'RAIN_CHANNEL',6);
rain_cum = isok(P,'RAIN_CUMSUM_DATA');
s_ap = field2num(P,'RAIN_ALERT_THRESHOLD',NaN);
i_ap = field2num(P,'RAIN_ALERT_INTERVAL',1);
j_ap = field2num(P,'RAIN_ALERT_DELAY',NaN);
alertcolor1 = field2num(P,'RAIN_ALERT_RGB',[1,.3,.3]);
alertcolor2 = field2num(P,'RAIN_ALERT_DELAY_RGB',[1,.6,.6]);
node_chan = field2num(P,'NODE_CHANNELS',[1,2,7,4,5,3,8]);
i_xy = field2num(P,'XY_CHANNELS',[3,8]);
gxy = (length(i_xy) == 2);

for n = 1:length(N)
	stitre = sprintf('%s : %s',N(n).ALIAS,N(n).NAME);

	t = D(n).t;
	d = D(n).d;
	C = D(n).CLB;
	nx = length(C.nm);

	% fixes colors for each channel
	col = [1,1,3,2,2,3,1,4];

	% if rain gauge are cumulated data, differentiating first
	if rain_cum
		d(:,i_rain) = [0;diff(d(:,i_rain))];
	end
	if ~isempty(t)

		% Irradiation: replaces negative values by 0
		%d((d(:,3)<0),3) = 0;

		% adds extra column with continuous rain on i_ap days (in mm/j)
		d(:,nx+1) = movsum(d(:,i_rain),round(i_ap/N(n).ACQ_RATE));

		% adds 3 other columns with continuous rain at different time scales
		d(:,nx+2) = movsum(d(:,i_rain),round(1/24/N(n).ACQ_RATE));	% hourly
		d(:,nx+3) = movsum(d(:,i_rain),round(1/N(n).ACQ_RATE));	% daily
		d(:,nx+4) = movsum(d(:,i_rain),round(30/N(n).ACQ_RATE));	% monthly
	end

	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure, clf, orient tall

		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;
		tk = [];
		dk = nan(0,nx);
		if ~isempty(k)
			[tk,dk] = treatsignal(t(k),d(k,:),P.GTABLE(r).DECIMATE,P);
			% raingauge values must be adjusted after decimation (for correct cumsum)
			dk(:,i_rain) = dk(:,i_rain)*P.GTABLE(r).DECIMATE;
		end

		% title and status
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};

		P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ),'(min|moy/cum|max)',' '};
		for i = 1:nx
			if i ~= i_rain
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+1.1f %s} (%+1.1f | %+1.1f | %+1.1f)', ...
					i, C.nm{i},d(ke,i),C.un{i},rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i)))}];
			else
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+1.1f %s} (%+1.1f | %+1.1f / %+1.1f | %+1.1f)', ...
					i, C.nm{i},d(ke,i),C.un{i},rmin(dk(:,i)),rmean(dk(:,i)),rsum(dk(:,i)),rmax(dk(:,i)))}];
			end
		end

		% X-Y graph
		if gxy
			h = subplot(length(node_chan) + 5,3,[3 6]); extaxes
			ph = get(h,'position');
			set(h,'position',[ph(1)+.6,ph(2)+.01,ph(3)-.6,ph(4)-.01])
			plot(dk(:,i_xy(1)),dk(:,i_xy(2)),'.','MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',scolor(i_xy(2)))
			hold on, plot(d(ke,i_xy(1)),d(ke,i_xy(2)),'ok','LineWidth',2), hold off
			%[FB-was]: set(gca,'XLim',[0 Inf],'FontSize',8)
			set(gca,'FontSize',8)
			grid on
			xlabel(sprintf('%s (%s)',C.nm{i_xy(1)},C.un{i_xy(1)}))
			ylabel(sprintf('%s (%s)',C.nm{i_xy(2)},C.un{i_xy(2)}))
		end

		% Rainfall (daily / hourly)
		subplot(length(node_chan) + 4,1,3:4), extaxes
		switch P.GTABLE(r).CUMULATE
		case 1
			hcum = 'daily';
			gp = nx + 3;
		case 30
			hcum = 'monthly';
			gp = nx + 4;
		otherwise
			hcum = 'hourly';
			gp = nx + 2;
		end
		if ~isempty(tk)
			% area plot does not support NaN...
			kr = find(~isnan(dk(:,gp)));
			if ~isempty(kr)
				[ax,h1,h2] = plotyy(tk(kr),dk(kr,gp),tk,rcumsum(dk(:,i_rain)),'area','plot');
				colormap([0,1,1;0,1,1]), grid on
				ylim = get(gca,'YLim');
				set(ax(1),'XLim',tlim,'YLim',[0,ylim(2)],'FontSize',8)
				set(ax(2),'XLim',tlim,'FontSize',8,'XTick',[])
				set(h2,'LineWidth',P.GTABLE(r).MARKERSIZE/3)
			end
		
			% rainfall alerts in background
			vp = [diff(d(:,nx+1)>=s_ap);-1];
			kp0 = find(vp==1);
			kp1 = find(vp==-1);
			if ~isempty(kp0)
				ylim = get(gca,'YLim');
				hold on
				for i = 1:length(kp0)
					if t(kp0(i)) <= tlim(2) & t(kp1(i)) >= tlim(1)
						h = fill3([max(tlim(1),t(kp0(i)))*[1,1],min(tlim(2),t(kp1(i)))*[1,1]],ylim([1,2,2,1]),-ones([1,4]),alertcolor1);
						set(h,'EdgeColor','none','Clipping','on');
					end
					if t(kp1(i)) <= tlim(2) & (t(kp1(i))+j_ap) >= tlim(1)
						h = fill3([max(tlim(1),t(kp1(i)))*[1,1],min(tlim(2),t(kp1(i))+j_ap)*[1,1]],ylim([1,2,2,1]),-ones([1,4]),alertcolor2);
						set(h,'EdgeColor','none','Clipping','off');
					end
				end
				hold off
			end
		end
		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('%s %s (%s)',C.nm{6},hcum,C.un{6}))

		% Wind rose (histogram of azimuths)
		h = subplot(length(node_chan) + 5,2+gxy,[1 3+gxy]);
		ph = get(h,'position');
		set(h,'position',[ph(1)-.1,ph(2)-.04,ph(3)+.04,ph(4)+.04])
		[th,rh] = rose(pi/2-dk(:,i_winda)*pi/180,360/wind_step);
		rosace(th,100*rh/length(k),'-','Color',scolor(i_winda))
		set(gca,'FontSize',8), grid on
		h = title('Wind Rose');
		pt = get(h,'position');
		set(h,'position',[pt(1) pt(2)*1.3 pt(3)])

		% Wind (velocity vs. azimuth)
		h = subplot(length(node_chan) + 5,2+gxy,[2 4+gxy]);
		ph = get(h,'position');
		set(h,'position',[ph(1)-.1,ph(2)-.04,ph(3)+.04,ph(4)+.04])
		h = rosace(pi/2-dk(:,i_winda)*pi/180,dk(:,i_winds),'.','Color',scolor(i_winds),'MarkerSize',P.GTABLE(r).MARKERSIZE);
		set(h,'Color',scolor(i_winds))
		[xe,ye] = pol2cart(pi/2-d(ke,i_winda)*pi/180,d(ke,i_winds));
		hold on, plot(xe,ye,'ok','LineWidth',2), hold off
		set(gca,'FontSize',8), grid on
		h = title(sprintf('Wind Speed (max. = {\\bf%1.1f %s})',max(dk(:,i_winds)),C.un{i_winds}));
		pt = get(h,'position');
		set(h,'position',[pt(1) pt(2)*1.3 pt(3)])

		% Other sensors
		for ii = 1:length(node_chan)
			g = node_chan(ii);
			subplot(length(node_chan) + 4,1,4+ii), extaxes
			% if plotting wind azimuth, apply modulo +/- 180°
			if g == i_winda
				dd = mod(dk(:,g) + 180,360) - 180;
			else
				dd = dk(:,g);
			end
			plot(tk,dd,'.','MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',scolor(g)), grid on
			set(gca,'XLim',tlim,'FontSize',8)
			if g == i_winda
				set(gca,'YLim',[-180,180],'YTick',-180:90:180);
			else
				ylim = minmax(dd);
				if diff(ylim)>0
					set(gca,'YLim',ylim);
				end
			end
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s (%s)',C.nm{g},C.un{g}))
			if length(find(~isnan(dk(:,g))))==0, nodata(tlim), end
		end
		tlabel(tlim,P.GTABLE(r).TZ)
    
		% makes graph
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
			E.t = tk;
			E.d = dk(:,1:nx);
			E.header = strcat(C.nm,{'('},C.un,{')'});
			E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
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
