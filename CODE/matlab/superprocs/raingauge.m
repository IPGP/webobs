function DOUT=raingauge(varargin)
%RAINGAUGE WebObs SuperPROC: Updates graphs/exports of daily raingauges data
%
%       RAINGAUGE(PROC) makes default outputs of PROC.
%
%       RAINGAUGE(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%           TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%           (keywords must be in TIMESCALELIST of PROC.conf)
%
%       RAINGAUGE(PROC,[],REQ) makes graphs/exports for specific request directory REQ.
%       REQ must contain REQUEST.rc file with dedicated parameters.
%
%       D = RAINGAUGE(PROC,...) returns a structure Dcontaining all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%	RAINGAUGE ignores any calibration file of associated NODEs. One channel
%	is processed. Parameters are defined in the PROC configuration file.
%	See readfmtdata_meteofrance.m for further information.
%
%
%	Authors: Alexis Bosson, WEBOBS/IPGP
%	Created: 2016-08-05, in Guadeloupe
%	Updated: 2021-01-01

WO = readcfg;
% Log prefix : function name
wofun = sprintf('WEBOBS{%s}',mfilename);

% A first input argument is mandatory : the PROC's name
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

% Proc name
proc = varargin{1};
% Start log
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration, associated nodes and data for any TSCALE and/or REQDIR and the data
% The proc name and additional arguments are used
% P = PROC parameters
% N = nodes list and parameters
% D = data of nodes
[P,N,D] = readproc(WO,varargin{:});

% Maximum plot number on one page (to add pages for summary graph)
pagemaxsubplot = field2num(P,'PAGE_MAX_SUBPLOT',12);
% Default values of labels, which can be translated in the PROC configuration
rain_label = field2str(P,'RAIN_LABEL','Rain');
cumul_label = field2str(P,'CUMUL_LABEL','Cumul');
rain_subtitle = field2str(P,'RAIN_SUBTITLE','%s rain in mm');
rain_infos_label = field2str(P,'RAIN_INFOS_LABEL','%s rain');
decimation_label_1h = field2str(P,'DECIMATION_LABEL_1h','Hourly');
decimation_label_1 = field2str(P,'DECIMATION_LABEL_1','Daily');
decimation_label_30 = field2str(P,'DECIMATION_LABEL_30','Monthly');
decimation_label_365 = field2str(P,'DECIMATION_LABEL_365','Yearly');
decimation_label_x = field2str(P,'DECIMATION_LABEL_X','%g days');
acq_rate = field2num(P,'ACQ_RATE',1);

% ==============================================================================
% For each node, make the node's graph
for n = 1:length(N)

	% Graph title : node's alias and name
	stitre = sprintf('%s: %s',N(n).ALIAS,N(n).NAME);

	% For each time scale
	for r = 1:length(P.GTABLE)
		% Initialize the figure
		figure
		orient tall

		% Data index of the node
		k = D(n).G(r).k;
		% Last data index of the node
		ke = D(n).G(r).ke;
		% Date/time limits of the processed time scale
		tlim = D(n).G(r).tlim;
		% Initialize the time and data matrices
		tk = [];
		dk = nan(0,1);
		% If there are data for this node
		if ~isempty(k)
			% Decimation of data (averaging)
			[y,tc] = movsum(D(n).t(k),D(n).d(k,1),acq_rate,acq_rate);
			[tk,dk] = treatsignal(tc,y,P.GTABLE(r).DECIMATE,P);
			% Raingauge values must be adjusted after decimation (for correct cumsum). Average multiplied by decimation factor gives cumuls
			dk(:,1) = dk(:,1)*P.GTABLE(r).DECIMATE;
			% Draw two graphs : bargraph of (short time cumulated) data and continuous curve of cumulative sum converted to meters
			[ax, h1, h2] = plotyy(tk, dk(:,1), tk, cumsum(dk(:,1))/1000, 'bar', 'plot');
			% Set the plots colors
			set(h1,'FaceColor','green');
			set(h1,'EdgeColor','green');
			set(h2,'Color','blue');
			% Time limits of X axes (for both graphs)
			set(ax(1),'XLim',tlim);
			set(ax(2),'XLim',tlim);
			% Font size of the axes labels
			set(ax(1),'FontSize',8);
			set(ax(2),'FontSize',8);
			% No X ticks for the second graph
			set(ax(2),'XTick',[],'XTickLabel',[]);
			% Label of the second graph
			ylabel(ax(2),sprintf('%s (m)',cumul_label));
		end
		% Label of the first graph
		ylabel(sprintf('%s (mm)',rain_label));
		% Date labelling of the X axis
		datetick2('x',P.GTABLE(r).DATESTR)

		% If no data is present
		if isempty(D(n).d) || all(isnan(D(n).d(k,1)))
			% Display an empty plot
			nodata(tlim)
		end

		% Define the correct word for the decimation's title
		switch round(P.GTABLE(r).DECIMATE*acq_rate*1440)
			case 60
				hcum = decimation_label_1h;
			case 60*24
				hcum = decimation_label_1;
			case 60*24*30
				hcum = decimation_label_30;
			case 60*24*365
				hcum = decimation_label_365;
			otherwise
				hcum = sprintf(decimation_label_x,P.GTABLE(r).DECIMATE*acq_rate);
		end
		% Subtitle with decimation period
		title(sprintf(rain_subtitle,hcum))
		% Label of the graph : date/time limits
		tlabel(tlim,P.GTABLE(r).TZ)

		% Title of the graph : node's name and timescale
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		% Status line : TODO
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		% Additional information : empty if no data
		P.GTABLE(r).INFOS = {''};
		% If there are data for this node
		if ~isempty(k)
			% Last data date/time and description
			P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.GTABLE(r).TZ),' (min|avr|max)',' '};
			% Rainfall decimated values
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%s = {\\bf%+g %s} (%+g | %+g | %+g)', ...
			sprintf(rain_infos_label,hcum),dk(end,1),'mm',roundsd([rmin(dk(:,1)),rmean(dk(:,1)),rmax(dk(:,1))],5))}];
			% Cumulated value
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%s = {\\bf%+g %s}', ...
			cumul_label,sum(dk(:,1))/1000,'m')}];
		end

		% Export current figure to files with prefix : node ID + timescale
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		% End of the current figure
		close

		% If we need exports and there are data for this node
		if isok(P.GTABLE(r).EXPORTS) && ~isempty(k)
			% Get time and data from current data
			E.t = tk;
			E.d = dk(:,1);
			% Data header
			E.header = {sprintf('%s(mm)',rain_label)};
			% File title : node's alias, name and ID
			E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
			% Export data to text file
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
end


% ==============================================================================
% Summary graph with all nodes displayed in subplots

% Title : PROC's name
stitre = P.NAME;

% Concatenate all the matrices of data to make statistics
G = cat(1,D.G);

% For each time scale
for r = 1:length(P.GTABLE)
	% Date/time limits of the processed time scale
	tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
	% If a limit is NaN
	if any(isnan(tlim))
		% Limits are defined as min max of all data limits
		tlim = minmax(cat(1,D.tfirstlast));
	end
	% Title : PROC's name and timescale
	P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
	% Status line : TODO
	P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
	% Additional information : empty before processing data
	P.GTABLE(r).INFOS = {''};
	% Initialize the figure
	figure
	% If there are more stations than the number allowed on a page
	if length(N) > pagemaxsubplot
		% Get paper dimensions
		ps = get(gcf,'PaperSize');
		% Set paper length to the needed number of pages
		set(gcf,'PaperSize',[ps(1),ps(2)*length(N)/pagemaxsubplot])
	end
	% Orient the graph vertically on the defined paper
	orient tall

	% Define the correct word for the decimation's title
        switch round(P.GTABLE(r).DECIMATE*acq_rate*1440)
		case 60
			hcum = decimation_label_1h;
		case 60*24
			hcum = decimation_label_1;
		case 60*24*30
			hcum = decimation_label_30;
		case 60*24*365
			hcum = decimation_label_365;
		otherwise
			hcum = sprintf(decimation_label_x,P.GTABLE(r).DECIMATE*acq_rate);
        end
	% For each node, make the node's plot
	for n = 1:length(N)
		% Make a subplot for this node
		subplot(length(N),1,n), extaxes
		% Data index of the node
		k = D(n).G(r).k;
		% Initialize the time and data matrices
		tk = [];
		dk = nan(0,1);
		% If there are data for this node
		if ~isempty(k)
			% Decimation of data (averaging)
			[y,tc] = movsum(D(n).t(k),D(n).d(k,1),acq_rate,acq_rate);
			[tk,dk] = treatsignal(tc,y,P.GTABLE(r).DECIMATE,P);
			% Raingauge values must be adjusted after decimation (for correct cumsum). Average multiplied by decimation factor gives cumuls
			dk(:,1) = dk(:,1)*P.GTABLE(r).DECIMATE;
			% Draw two graphs : bargraph of (short time cumulated) data and continuous curve of cumulative sum converted to meters
			[ax, h1, h2] = plotyy(tk, dk(:,1), tk, cumsum(dk(:,1))/1000, 'bar', 'plot');
			% Set the plots colors
			set(h1,'FaceColor','green');
			set(h1,'EdgeColor','green');
			set(h2,'Color','blue');
			% Time limits of X axes (for both graphs)
			set(ax(1),'XLim',tlim);
			set(ax(2),'XLim',tlim);
			% Font size of the axes labels
			set(ax(1),'FontSize',8);
			set(ax(2),'FontSize',8);
			% No X ticks for the second graph
			set(ax(2),'XTick',[],'XTickLabel',[]);
			% Label of the second graph
			ylabel(ax(2),sprintf('%s (m)',cumul_label));
			% Cumulated value
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%s = {\\bf%+g %s}', ...
				N(n).ALIAS,sum(dk(:,1))/1000,'m')}];
		end
		% Font size of the axes labels of empty graphs
		set(gca,'FontSize',7)
		% Date labelling of the X axis
		datetick2('x',P.GTABLE(r).DATESTR)
		% Left label of the subplot : node's alias
		ylabel(sprintf('%s',N(n).ALIAS))

		% If no data is present
		if isempty(D(n).d) || all(isnan(D(n).d(k,1)))
			% Display an empty subplot
			nodata(tlim)
		end
		% Above the first subplot
		if n == 1
			% Subtitle with decimation period
			title(sprintf(rain_subtitle,hcum))
		end
		% Below the last subplot
		if n == length(N)
			% Label of the graph : date/time limits
			tlabel(tlim,P.GTABLE(r).TZ)
		end
	end
	% Export current figure to files with prefix : timescale
	mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
	% End of the current figure
	close
end


% If the function run as a request
if P.REQUEST
	% Make post-request jobs
	mkendreq(WO,P);
end

% End log
timelog(procmsg,2)

% Returns data in DOUT
if nargout > 0
	DOUT = D;
end
