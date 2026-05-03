function DOUT=rsam(varargin)
%RSAM WebObs SuperPROC: Real-time seismic amplitude measurements.
%
%       RSAM(PROC) makes default outputs of a generic time series PROC.
%
%       RSAM(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	RSAM(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = RSAM(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       RSAM will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and and nodes' calibration file channels definition with
%       names and units.
%
%       In addition to each single node graph, a summary graph with all nodes can
%       be set with 'SUMMARYLIST|SUMMARY' parameter. RSAM will compute the mean of
%        all channels for each node, or mean of SUMMARY_CHANNELS list.
%
%       Other specific paramaters are described in CODE/tplates/PROC.RSAM.
%
%	Reference: based on the tremor maps made by V. Ferrazzini / OVPF-IPGP
%
%	Authors: F. Beauducel, J.-M. Saurel / WEBOBS, IPGP
%	Created: 2017-07-19
%	Updated: 2026-04-30

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR and the data
[P,N,D] = readproc(WO,varargin{:});

V.name = P.NAME;
eps_min = field2num(P,'EPS_IS_NAN',eps);
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','-');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name} ($timescale)}');

summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','-');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');

alarm_xml = field2str(P,'ALARM_XML');
alarm_threshold_level = field2num(P,'ALARM_THRESHOLD_LEVEL',0);
alarm_color = field2num(P,'ALARM_COLOR',[1,0,0]);
alarm_linestyle = field2str(P,'ALARM_LINESTYLE','--');
alarm_linewidth = field2num(P,'ALARM_LINEWIDTH',2);

targetll = field2num(P,'TARGET_LATLON');
if numel(targetll)~=2 || any(isnan(targetll))
	targetll = [];
end

sourcemap_excluded = field2str(P,'SOURCEMAP_EXCLUDED_NODELIST');
sourcemap_included = field2str(P,'SOURCEMAP_INCLUDED_NODELIST');
sourcemap_excluded_target = field2num(P,'SOURCEMAP_EXCLUDED_FROM_TARGET_KM',0,'notempty');
sourcemap_perchannel = isok(P,'SOURCEMAP_PERCHANNEL');
sourcemap_method = field2str(P,'SOURCEMAP_METHOD','mean');
sourcemap_n = field2num(P,'SOURCEMAP_N',2);
sourcemap_title = field2str(P,'SOURCEMAP_TITLE','{\fontsize{14}{\bf$name - Source Map $chan_name} ($timescale)}');
sourcemap_colormap = field2num(P,'SOURCEMAP_COLORMAP',spectral(256));
sourcemap_alpha = field2num(P,'SOURCEMAP_COLORMAP_ALPHA',[0,1]);
sourcemap_caxis = field2num(P,'SOURCEMAP_CAXIS');
sourcemap_cmax = field2num(P,'SOURCEMAP_CMAX');
sourcemap_lmax = field2num(P,'SOURCEMAP_LMAX',1000);
sourcemap_dem_opt = field2cell(P,'SOURCEMAP_DEM_OPT','colormap',white);
sourcemap_station_marker = field2str(P,'SOURCEMAP_STATION_MARKER','^');
sourcemap_station_size = field2num(P,'SOURCEMAP_STATION_SIZE',6);
sourcemap_max_opt = field2cell(P,'SOURCEMAP_MAX_OPT','pk','MarkerFaceColor','k','MarkerSize',10);
sourcemap_allmax_exp = field2num(P,'SOURCEMAP_ALLMAX_EXPONENT',2);
sourcemap_allmax_marker = field2str(P,'SOURCEMAP_ALLMAX_MARKER','.');
sourcemap_allmax_size = field2num(P,'SOURCEMAP_ALLMAX_SIZE',5);

ylogscale = isok(P,'YLOGSCALE');
ymax = field2num(P,'YMAX_MEDIAN',[0.99,0.1]);
pagemaxsubplot = field2num(P,'PAGE_MAX_SUBPLOT',8);
movingaverage = field2num(P,'MOVING_AVERAGE_SAMPLES',1);

% XML file to overwrite FID_THRESHOLD values
if ~isempty(alarm_xml) && exist(alarm_xml,'file')
    alm = xmlread(alarm_xml);
    stations = alm.getElementsByTagName('station');
    for i = 1:stations.getLength
        station = stations.item(i-1);
        nam = string(station.getAttribute('name'));
        k = find(strcmp(nam,cat(1,{N.FID})));
        if ~isempty(k)
            rsam_nodes = station.getElementsByTagName('rsam_threshold');
            if rsam_nodes.getLength > 0
                N(k).THRESHOLD = str2double(rsam_nodes.item(0).getTextContent);
            end
        end
    end
end

% text options for station legend
topt = {'BackgroundColor','w','Margin',.1,'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'FontWeight','bold'};

% common unit for all channels
clb = cat(1,D.CLB);
nxm = 0; % max number of channels

for n = 1:length(N)

	C = D(n).CLB;
	nx = C.nx;
    nmn = strcommon(C.nm,'All channels');
    unn = strcommon(C.un);
	nxm = max(nxm,nx);
	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;
	V.last_data = datestr(D(n).tfirstlast(2));

    pernode_channels = field2num(P,'PERNODE_CHANNELS',1:nx,'notempty');
    threshold = field2num(N(n),'THRESHOLD',alarm_threshold_level);
    OPT.IMAP = [];

	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure
		if length(N) > pagemaxsubplot
			ps = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[ps(1),ps(2)*length(N)/pagemaxsubplot])
		end
		orient tall

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);

		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;
		tk = [];
		dk = nan(0,nx);
		if ~isempty(k)
			[tk,dk] = treatsignal(D(n).t(k),D(n).d(k,:),P.GTABLE(r).DECIMATE,P);
		end

        % --- linear time series
        subplot(4,1,1:2), extaxes(gca,[.07,.01])
        if threshold > 0 && alarm_linewidth > 0
            plot(tlim,repmat(threshold,1,2),alarm_linestyle,'Color',alarm_color,'LineWidth',alarm_linewidth)
            OPT.IMAP(1).d = [tlim(1),threshold,tlim(2),threshold];
            OPT.IMAP(1).gca = gca;
            OPT.IMAP(1).s = {sprintf('''Level = %g %s'',CAPTION,''Alarm threshold'',BGCOLOR,''%s'',FGCOLOR,''#EEEEEE''',threshold,unn,char(rgb2hex(alarm_color)))};
            OPT.IMAP(1).l = {''};
        end
        hold on
        ylim = [0,Inf];
		
		aliases = [];
		ncolors = [];
		for i = pernode_channels
			col = scolor(i);
			col2 = .5+col/2; % light color
            aliases = cat(2,aliases,C.nm(i));
            ncolors = cat(2,ncolors,i);
			if ~isempty(k)
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = C.sf(i);
				end
				timeplot(tk,dk(:,i),samp,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				if movingaverage > 1
					timeplot(tk,mavr(dk(:,i),movingaverage),samp,'-', ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',col2,'MarkerFaceColor',col2)
				end
                if numel(ymax) == 2
                    ylim(2) = rmax([minmax(dk(:,i),ymax(1));ylim(2);threshold]);
                    ylim(2) = ylim(2)*(1+ymax(2));
                    if isnan(ylim(2))
                        ylim(2) = Inf;
                    end
                end
            end
        end
        hold off; box on
        set(gca,'XLim',tlim,'YLim',ylim,'FontSize',8,'TickDir','out')
        if ylogscale
            set(gca,'YScale','log')
        end
        datetick2('x',P.GTABLE(r).DATESTR)
        ylabel(sprintf('%s %s',nmn,regexprep(unn,'(.+)','($1)')))
        if isempty(k)
            nodata(tlim)
        end
		tlabel(tlim,P.TZ)

		% legend: channel aliases
		for i = 1:length(aliases)
			text(tlim(1)+i*diff(tlim)/(length(aliases)+1),ylim(2),aliases(i), ...
                'Color',scolor(ncolors(i)),topt{:})
		end

        % --- 1/x time series (Y-axis linear scale forced)
        subplot(4,1,3:4), extaxes(gca,[.07,.01])
        if threshold > 0 && alarm_linewidth > 0
            plot(tlim,repmat(1/threshold,1,2),alarm_linestyle,'Color',alarm_color,'LineWidth',alarm_linewidth)
            OPT.IMAP(2).d = [tlim(1),1/threshold,tlim(2),1/threshold];
            OPT.IMAP(2).gca = gca;
            OPT.IMAP(2).s = {sprintf('''Level = %g %s'',CAPTION,''Alarm threshold'',BGCOLOR,''%s'',FGCOLOR,''#EEEEEE''',threshold,unn,char(rgb2hex(alarm_color)))};
            OPT.IMAP(2).l = {''};
        end
        hold on
        ylim = [0,Inf];
		
		for i = pernode_channels
			col = scolor(i);
			col2 = .5+col/2; % light color
			if ~isempty(k)
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = D(n).CLB.sf(i);
				end
                invdk = 1./dk(:,i);
                invdk(dk(:,i)<eps_min) = NaN;
				timeplot(tk,invdk,samp,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				if movingaverage > 1
					timeplot(tk,mavr(invdk,movingaverage),samp,'-', ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',col2,'MarkerFaceColor',col2)
				end
                if numel(ymax) == 2
                    ylim(2) = rmax([minmax(invdk,ymax(1));ylim(2);1/threshold]);
                    ylim(2) = ylim(2)*(1+ymax(2));
                    if isnan(ylim(2))
                        ylim(2) = Inf;
                    end
                end
			end
		end
        hold off; box on
        set(gca,'XLim',tlim,'Ylim',ylim,'FontSize',8,'TickDir','out')
        datetick2('x',P.GTABLE(r).DATESTR)
        ylabel(sprintf('1/(%s) %s',nmn,regexprep(unn,'(.+)','(1/($1))')))
        if isempty(k)
            nodata(tlim)
        end

		tlabel(tlim,P.TZ)

		% legend: channel aliases
		for i = 1:length(aliases)
			text(tlim(1)+i*diff(tlim)/(length(aliases)+1),ylim(2),aliases(i), ...
                'Color',scolor(ncolors(i)),topt{:})
		end

		% title, status and additional information
		OPT.GTITLE = varsub(pernode_title,V);
		OPT.GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		OPT.INFOS = {''};
		if ~isempty(k)
			OPT.INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.TZ),' (min|avr|max)',' '};
			for i = 1:nx
				OPT.INFOS = [OPT.INFOS{:},{sprintf('%d. %s = {\\bf%+g %s} (%+g | %+g | %+g)', ...
					i, D(n).CLB.nm{i},D(n).d(ke,i),D(n).CLB.un{i},roundsd([rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i))],5))}];
			end
		end

		% makes graph
        OPT.STATUS = P.GTABLE(r).STATUS;
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P,OPT)
		close

		% exports data
		if isok(P,'EXPORTS') && ~isempty(k)
			E.t = tk;
			E.d = dk(:,1:nx);
			E.header = strcat(D(n).CLB.nm,{'('},D(n).CLB.un,{')'});
			E.title = sprintf('%s {%s}',sprintf('%s: %s',N(n).ALIAS,N(n).NAME),upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P,r,N(n));
		end
	end
end


% ====================================================================================================
% Graphs for all the proc nodes

summary = 'SUMMARY';
if any(strcmp(P.SUMMARYLIST,summary))
	G = cat(1,D.G);
    summary_channels = field2num(P,'SUMMARY_CHANNELS',1:nxm,'notempty');
    un = strcommon(cat(2,clb.un));

	% -------------------------------------------------------------------------------------
	% --- Summary timeseries graph
	for r = 1:length(P.GTABLE)

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(cat(1,D.tfirstlast));
		end
		OPT.GTITLE = varsub(summary_title,V);
        OPT.STATUS = P.GTABLE(r).STATUS;
		OPT.GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
		OPT.INFOS = {''};
        OPT.IMAP = [];

		figure
		orient tall

		aliases = [];
		ncolors = [];

		% linear/log time series
		subplot(4,1,1:2), extaxes(gca,[.07,.01])
		hold on
        dmax = NaN;
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = D(n).CLB.sf(1);
				end
				% computes the mean of all channels
				[tk,dk] = treatsignal(D(n).t(k),rmean(D(n).d(k,summary_channels),2),P.GTABLE(r).DECIMATE,P);
                dmax = max(dmax,minmax(dk,ymax(1)));
				col = scolor(n);
				timeplot(tk,dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				aliases = cat(2,aliases,{N(n).ALIAS});
				ncolors = cat(2,ncolors,n);
			end
		end
		hold off; box on
        ylim = [0,Inf];
        if numel(ymax) == 2
            ylim(2) = dmax*(1+ymax(2));
            if isnan(ylim(2))
                ylim(2) = Inf;
            end
        end
		set(gca,'XLim',tlim,'YLim',ylim,'FontSize',8,'TickDir','out')
		if ylogscale
			set(gca,'YScale','log')
		end
		box on
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('RSAM %s',regexprep(un,'(.+)','($1)')))

		% legend: station aliases
		xlim = get(gca,'XLim');
		ylim = get(gca,'YLim');
		nn = length(aliases);
		for n = 1:nn
			text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n), ...
                'Color',scolor(ncolors(n)),topt{:})
		end

		tlabel(xlim,P.TZ)

		% 1/x time series (Y-axis linear scale forced)
		% makes a new data vector with averaged signals

		subplot(4,1,3:4), extaxes(gca,[.07,.01])
		if alarm_threshold_level > 0
			plot(tlim,1./repmat(alarm_threshold_level,1,2),alarm_linestyle,'Color',alarm_color,'LineWidth',alarm_linewidth)
		end
		hold on
        dmax = NaN;
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = D(n).CLB.sf(1);
				end
				% computes the mean of all channels
				[tk,dk] = treatsignal(D(n).t(k),rmean(D(n).d(k,:),2),P.GTABLE(r).DECIMATE,P);
                invdk = 1./dk;
                invdk(dk<eps_min) = NaN;
                dmax = max(dmax,minmax(invdk,ymax(1)));
				col = scolor(n);
				timeplot(tk,invdk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
			end
		end
		hold off; box on
        ylim = [0,Inf];
        if numel(ymax) == 2
            ylim(2) = dmax*(1+ymax(2));
            if isnan(ylim(2))
                ylim(2) = Inf;
            end
        end
		set(gca,'XLim',tlim,'Ylim',ylim,'FontSize',8,'TickDir','out')
		box on
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('1/RSAM %s',regexprep(un,'(.+)','1/($1)')))

		% legend: station aliases
		xlim = get(gca,'XLim');
		ylim = get(gca,'YLim');
		for n = 1:nn
			text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n), ...
                'Color',scolor(ncolors(n)),topt{:})
		end

		tlabel(xlim,P.TZ)

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P,OPT)
		close
	end
end

% -------------------------------------------------------------------------------------
% --- Source mapping from amplitude
summary = 'SOURCEMAP';
if any(strcmp(P.SUMMARYLIST,summary))
	G = cat(1,D.G);
    sourcemap_channels = field2num(P,'SOURCEMAP_CHANNELS',1:nxm,'notempty');
    refstring = 'Processing by Taisne et al., IPGP/EOS';
    geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84),cat(1,N.ALTITUDE)];

    % selects stations
    kn = selectnode(N,tlim,sourcemap_excluded,sourcemap_included,[targetll,sourcemap_excluded_target]);
    
    % sampling interval (for ALLMAX plot)
    sf = cat(1,clb(kn).sf);
    dtmin = rmin(sf(:)); % minimum delta t (sf must be defined at least in one node'clb !)
    wolog('minimum sampling interval for %d nodes = %g s\n',length(kn),dtmin*86400);
    
    if sourcemap_perchannel
        nc = length(sourcemap_channels);
    else
        nc = 1;
    end

    % load topo and compute basemap limits: a square that includes all nodes
    lat0 = mean(minmax(geo(kn,1)));
    lon0 = mean(minmax(geo(kn,2)));
    xylim = xyw2lim([lon0,lat0,1.1*max(diff(minmax(geo(kn,1))),diff(minmax(geo(kn,2)))/cosd(lat0))],1/cosd(lat0));
    DEM = loaddem(WO,xylim,P);
    wolog('Making the basemap. ');
    I = dem(DEM.lon,DEM.lat,DEM.z,'latlon','noplot','maxlength',sourcemap_lmax/sourcemap_n,sourcemap_dem_opt{:});
    [xx,yy] = meshgrid(I.x,I.y);
    % adds distances from target
    if numel(targetll) == 2
        [xdt,ydt] = meshgrid(DEM.lon,DEM.lat);
        DEM.dist = greatcircle(targetll(1),targetll(2),ydt,xdt);
    end

    for r = 1:length(P.GTABLE)

        V.timescale = timescales(P.GTABLE(r).TIMESCALE);
        tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
        if any(isnan(tlim))
            tlim = minmax(cat(1,D.tfirstlast));
        end
        OPT.STATUS = P.GTABLE(r).STATUS;
        OPT.GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
        OPT.INFOS = { ...
            sprintf('Average method: {\\bf %s}',sourcemap_method), ...
            sprintf('Reference: {\\bf %s}',refstring), ...
        };

        for c = 1:nc
            cnm = cat(1,clb(kn).nm);
            if sourcemap_perchannel
                V.chan_name = strcommon(cnm(:,sourcemap_channels(c)),'All channels');
            else
                V.chan_name = strcommon(cnm(sourcemap_channels),'Channel mean');
            end
            OPT.GTITLE = varsub(sourcemap_title,V);

            % --- Time series graph
            figure
            orient tall

            aliases = [];
            ncolors = [];

            % linear/log time series (1/4 upper part of the page)
            subplot(4,1,1), extaxes(gca,[.07,.01])
            hold on
            dmax = NaN;
            for i = 1:length(kn)
                n = kn(i);
                k = D(n).G(r).k;
                if ~isempty(k)
                    if isok(P,'CONTINUOUS_PLOT')
                        samp = 0;
                    else
                        samp = D(n).CLB.sf(1);
                    end
                    if sourcemap_perchannel
                        dd = D(n).d(k,sourcemap_channels(c));
                    else
                        dd = rmean(D(n).d(k,sourcemap_channels),2);
                    end
                    [tk,dk] = treatsignal(D(n).t(k),dd,P.GTABLE(r).DECIMATE,P);
                    col = scolor(n);
                    dmax = max(dmax,minmax(dk,ymax(1)));
                    timeplot(tk,dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
                        'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
                    aliases = cat(2,aliases,{N(n).ALIAS});
                    ncolors = cat(2,ncolors,n);
                end
            end
            hold off
            ylim = [0,Inf];
            if numel(ymax) == 2
                ylim(2) = dmax*(1+ymax(2));
                if isnan(ylim(2))
                    ylim(2) = Inf;
                end
            end
            set(gca,'XLim',tlim,'YLim',ylim,'FontSize',8,'TickDir','out')
            if ylogscale
                set(gca,'YScale','log')
            end
            box on
            datetick2('x',P.GTABLE(r).DATESTR)
            ylabel(sprintf('All stations (%s)',un))

            % legend: station aliases
            xlim = get(gca,'XLim');
            nn = length(aliases);
            for n = 1:nn
                text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n), ...
                    'Color',scolor(ncolors(n)),topt{:});
            end

            tlabel(xlim,P.TZ)

            % plots maps time limits
            tbin = linspace(xlim(1),xlim(2),sourcemap_n^2+1);
            plotevt(tbin,'-.','Color',.5*ones(1,3),'LineWidth',1)

            % --- maps of source location

            cmap = shademap(sourcemap_colormap,sourcemap_alpha);

            clear IMAP
            for m = 1:(sourcemap_n^2)
                wlim  = tbin(m+(0:1));
                x0 = 0.18;
                dx = 0.75;
                y0 = 0.1;
                dy = 0.62;
                ddy = 0.03; % margin Y
                switch sourcemap_n
                    case 2
                        ddx = 0.08; % margin X
                        width  = (dx-ddx)/2;
                        height = (dy-ddy)/2;
                        left   = x0 + mod(m-1,2)*(width + ddx);
                        bottom = y0 + (2-ceil(m/2))*(height + ddy);
                    case 3
                        ddx = 0.05; % margin X
                        width  = (dx-2*ddx)/3;
                        height = (dy-2*ddy)/3;
                        left   = x0 + mod(m-1,3)*(width + ddx);
                        bottom = y0 + (3-ceil(m/3))*(height + ddy);
                    otherwise
                        left   = x0;
                        width  = dx;
                        bottom = y0;
                        height = dy;
                end
                axes('Position',[left bottom width height]);
                % extaxes tries to fit dataaspect ratio
                extaxes(gca,[repmat(1-cosd(lat0),1,2),0,0])

                % computes the mean value for each node
                dx = [geo(kn,2);xylim([1,2,1,2])'];
                dy = [geo(kn,1);xylim([3,3,4,4])'];
                dz = nan(length(kn)+4,1); % init with NaN
                dz(end-3:end) = 0; % 4 last to fix map corners to 0
                for i = 1:length(kn)
                    n = kn(i);
                    k = D(n).G(r).k;
                    kw = isinto(D(n).t,wlim);
                    if ~isempty(k)
                        if sourcemap_perchannel
                            dd = D(n).d(kw,sourcemap_channels(c));
                        else
                            dd = rmean(D(n).d(kw,:),2);
                        end
                        switch sourcemap_method
                            case 'median'
                                dz(n) = rmedian(dd);
                            otherwise
                                dz(n) = rmean(dd);
                        end
                    end
                end
                k = find(~isnan(dz));
                zz = griddata(dx(k),dy(k),dz(k),xx,yy,'v4');

                % computed mixed map with shaded relied
                clim = minmax(dz);
                if numel(sourcemap_caxis) == 2
                    clim = sourcemap_caxis;
                end
                if ~any(isnan(sourcemap_cmax)) && length(sourcemap_cmax) == nc
                    clim = [0,sourcemap_cmax(c)];
                end
                inorm = zz/diff(clim) + clim(1); % normalized values (0,1)
                inorm(inorm<0) = 0;
                inorm(inorm>1) = 1;
                I.msk = ind2rgb(round(size(sourcemap_colormap,1)*inorm),sourcemap_colormap); % RGB map
                A = repmat(interp1(linspace(0,1,length(sourcemap_alpha)),sourcemap_alpha,inorm),[1,1,3]);
                I.tot = I.rgb.*(1 - A) + I.msk.*A;
                image(xx(1,:),yy(:,1),I.tot);
                axis xy

                %set(gca,'XTick',[],'YTick',[],'DataAspectRatio',[1,cosd(lat0),1],'FontSize',8)
                set(gca,'XTick',[],'YTick',[],'FontSize',8)
                hold on
                % adds distance from target
                if numel(targetll) == 2
                    [ct,h] = contour(DEM.lon,DEM.lat,DEM.dist,'k');
                    set(h,'LineColor',.5*ones(1,3),'LineWidth',.1);
                    clabel(ct,h,'FontSize',8,'Color',.5*ones(1,3));
                end
                % plot stations
                target(geo(kn,2),geo(kn,1),sourcemap_station_size,'w',sourcemap_station_marker)
                % plot all max values
                if isok(P,'SOURCEMAP_ALLMAX')
                    tw = wlim(1):dtmin:wlim(2);
                    if length(tw) > 100
                        tw = linspace(wlim(1),wlim(2),100);
                    end
                    wolog('plotting %d sources on map #%d... ',length(tw),m);
                    xy = nan(length(tw),3);
                    for i = 1:length(tw)
                        v = nan(length(kn)+4,1);
                        for ii = 1:length(kn)
                            n = kn(ii);
                            kw = isinto(D(n).t,wlim);
                            dd = rmean(D(n).d(kw,c),2);
                            if sum(kw) > 1 && ~all(isnan(dd))
                                v(ii) = interp1(D(n).t(kw),dd,tw(i),'nearest');
                            end
                        end
                        w = v.^sourcemap_allmax_exp;
                        x0 = rsum(w.*dx) / rsum(w);
                        y0 = rsum(w.*dy) / rsum(w);
                        v0 = rsum(v.^2) / rsum(v);
                        xy(i,:) = [x0 y0 v0];
                    end
                    col = linspace(1,0,length(tw));
                    scatter(xy(:,1),xy(:,2),sourcemap_allmax_size^2*xy(:,3)/clim(2),col,sourcemap_allmax_marker,'filled')
                    colormap(gray)
                    caxis([0,1])
                    fprintf(' done.\n');
                end
                % plot max value
                if isok(P,'SOURCEMAP_PLOT_MAX') && max(zz(:)) ~= 0
                    km = find(zz == max(zz(:)));
                    plot(mean(xx(km)),mean(yy(km)),sourcemap_max_opt{:})
                end
                hold off
                xlabel({sprintf('{\\bf%s} {\\it%+g}',datestr(wlim(1)),P.TZ), ...
                    sprintf('{\\bf%s} {\\it%+g}',datestr(wlim(2)),P.TZ)});

                % interactive map with max value per station
                IMAP(m).d = [dx(1:length(kn)),dy(1:length(kn)),repmat(sourcemap_station_size,length(kn),1)];
                IMAP(m).gca = gca;
                IMAP(m).s = cell(length(kn),1);
                IMAP(m).l = cell(length(kn),1);
                for n = 1:numel(IMAP(m).s)
                    IMAP(m).s{n} = sprintf('''<i>start:</i> %s<br><i>end:</i> %s<br>average = %g %s'',CAPTION,''%s: %s''', ...
                        datestr(wlim(1),'dd-mmm-yyyy HH:MM'),datestr(wlim(2),'dd-mmm-yyyy HH:MM'), ...
                        roundsd(dz(n),3),un,N(n).ALIAS,regexprep(regexprep(N(n).NAME,'"',''),'('')','\\$1'));
                end

            end

            % legend (colorscale)
            axes('position',[0.05,0.3,0.02,0.2]);
            clin = linspace(clim(1),clim(2),size(cmap,1))';
            crgb = ind2rgb(repmat(1:size(cmap,1),2,1)',cmap); % RGB map
            image([0,1],clin,crgb);
            ylim = get(gca,'Ylim');
            patch([0,.5,1,0],ylim(2) + diff(ylim)*[0,.05,0,0],'k','FaceColor','k','Clipping','off')
            patch([0,.5,1,0],ylim(1) - diff(ylim)*[0,.05,0,0],'k','FaceColor','w','Clipping','off')
            axis xy
            set(gca,'XLim',[0,1],'XTick',[],'FontSize',8)
            title({un,''},'FontWeight','bold')

            axes('position',[0.05,0.1,0.02,0.6]);
            hold on
            plot(.5,.25,'pk','MarkerSize',10,'MarkerFaceColor','k')
            text(.5,.25,{'','max.','amplitude'},'FontSize',8,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top')
            target(.5,.15,sourcemap_station_size,'w',sourcemap_station_marker)
            text(.5,.15,{'','station'},'FontSize',8,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top')
            hold off
            set(gca,'XLim',[0,1],'YLim',[0,1]);
            axis off

            OPT.FIXEDPP = true;
            OPT.IMAP = IMAP;
            f = sprintf('%s%s_%s',summary,repmat(sprintf('_%d',c),c>1),P.GTABLE(r).TIMESCALE);
            mkgraph(WO,f,P,OPT)
            close
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
