function DOUT=sara(varargin)
%SARA WebObs SuperPROC: Seismic Amplitude Ratio Analysis
%
%       SARA(PROC) makes default outputs of a generic time series PROC.
%
%       SARA(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	SARA(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = SARA(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       SARA will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and and nodes' calibration file channels definition with
%       names and units.
%
%       In addition to each single node graph, a summary graph with all nodes can
%       be set with 'SUMMARYLIST|' parameter. SARA will compute the mean of all channels
%       for each node.
%
%       In addition to each single node graph, a summary graph with all nodes can
%       be set with 'SUMMARYLIST|SARA' parameter.
%
%       Other specific paramaters are:
%           PICKS_CLEAN_PERCENT|0
%           FLAT_IS_NAN|NO
%           MOVING_AVERAGE_SAMPLES|10
%           CONTINUOUS_PLOT|NO
%	    PERNODE_TITLE|{\fontsize{14}{\bf$node_alias: $node_name} ($timescale)}
%	    PERNODE_LINESTYLE|-
%           PERNODE_RELATIVE|NO
%	    SUMMARY_TITLE|{\fontsize{14}{\bf${NAME}} ($timescale)}
%	    SUMMARY_LINESTYLE|-
%	    SARA_TITLE|
%	    SARA_EXCLUDED_NODELIST|
%	    SARA_CORRELATION_THRESHOLD|0.3
%	    SARA_MINPOINTS|6
%	    SARA_TIMEWINDOWSLIST|6,10:10:60,90,120,240:60:480
%	    SARA_OVERLAP|Y
%	    SARA_OVERLAP_STEP|1
%	    SARA_COLORMAP|hsv
%	    SARA_RATIO_COLORMAP|jet
%	    SARA_CAXIS|0,1
%
%	Reference:
%	   Taisne, B., F. Brenguier, N. M. Shapiro, and V. Ferrazzini (2011),
%	   Imaging the dynamics of magma propagation using radiated seismic intensity,
%	   Geophys. Res. Lett., 38, L04304, doi:10.1029/2010GL046068.
%
%	Authors: Tan Chiou Ting, Benoit Taisne, Francois Beauducel / EOS / IPGP / WEBOBS
%	Created: 2017-09-14
%	Updated: 2026-01-13

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR and the data
[P,N,D] = readproc(WO,varargin{:});

V.name = P.NAME;
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','-');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name} ($timescale)}');
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','-');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');
movingaverage = field2num(P,'MOVING_AVERAGE_SAMPLES',1);
sara_title = field2str(P,'SARA_TITLE','{\fontsize{14}{\bfSARA} ($timescale)}');
sara_colormap = field2str(P,'SARA_COLORMAP','hsv','notempty');
ratio_colormap = field2str(P,'SARA_RATIO_COLORMAP','jet','notempty');
sara_caxis = field2num(P,'SARA_CAXIS',[0,1],'notempty');
sara_threshold = field2num(P,'SARA_CORRELATION_THRESHOLD',0.3,'notempty');
sara_minpoints = field2num(P,'SARA_MINPOINTS',6,'notempty');
sara_timewindows = field2num(P,'SARA_TIMEWINDOWSLIST',[6,10:10:60,120,240:60:480],'notempty');
sara_overlap_step = field2num(P,'SARA_OVERLAP_STEP',1,'notempty');
sara_overlap = field2str(P,'SARA_OVERLAP','Y','notempty');

for n = 1:length(N)

	C = D(n).CLB;
	nx = C.nx;
	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;
	V.last_data = datestr(D(n).tfirstlast(2));


	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure, orient tall

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);

		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;
		tk = [];
		dk = nan(0,nx);
		if ~isempty(k)
			[tk,dk] = treatsignal(D(n).t(k),D(n).d(k,:),P.GTABLE(r).DECIMATE,P);
			if isok(P,'PERNODE_RELATIVE')
				dk = rf(dk);
			end
		end

		% loop for each data column
		for i = 1:nx

			col = scolor(i);
			col2 = .5+col/2;

			% linear time series
			subplot(nx*4,1,4*(i-1) + (1:2)), extaxes(gca,[.07,.01])
			if ~isempty(k)
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = D(n).CLB.sf(i);
				end
				timeplot(tk,dk(:,i),samp,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				if movingaverage > 1
					hold on
					timeplot(tk,mavr(dk(:,i),movingaverage),samp,'-', ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',col2,'MarkerFaceColor',col2)
					hold off
				end
			end
			set(gca,'XLim',tlim,'YLim',[0,Inf],'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s %s',D(n).CLB.nm{i},regexprep(D(n).CLB.un{i},'(.+)','($1)')))
			if isempty(D(n).d) || all(isnan(D(n).d(k,i)))
				nodata(tlim)
			end

			% 1/x time series (Y-axis linear scale forced)
			subplot(nx*4,1,4*(i-1) + (3:4)), extaxes(gca,[.07,.01])
			if ~isempty(k)
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = D(n).CLB.sf(i);
				end
				timeplot(tk,1./dk(:,i),samp,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				if movingaverage > 1
					hold on
					timeplot(tk,mavr(1./dk(:,i),movingaverage),samp,'-', ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',col2,'MarkerFaceColor',col2)
					hold off
				end
			end
			set(gca,'XLim',tlim,'Ylim',[0,Inf],'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s %s',D(n).CLB.nm{i},regexprep(D(n).CLB.un{i},'(.+)','(1/($1))')))
			if isempty(D(n).d) || all(isnan(D(n).d(k,i)))
				nodata(tlim)
			end
		end

		tlabel(tlim,P.GTABLE(r).TZ)
		plotevent(P.EVENTS_FILE)

		% title, status and additional information
		P.GTABLE(r).GTITLE = varsub(pernode_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};
		if ~isempty(k)
			P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.GTABLE(r).TZ),' (min|avr|max)',' '};
			for i = 1:nx
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+g %s} (%+g | %+g | %+g)', ...
					i, D(n).CLB.nm{i},D(n).d(ke,i),D(n).CLB.un{i},roundsd([rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i))],5))}];
			end
		end

		% makes graph
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
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

if isfield(P,'SUMMARYLIST')
	G = cat(1,D.G);
	C = cat(1,D.CLB);

	% -------------------------------------------------------------------------------------
	% --- Summary timeseries graph
	for r = 1:length(P.GTABLE)

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(cat(1,D.tfirstlast));
		end
		P.GTABLE(r).GTITLE = varsub(summary_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
		P.GTABLE(r).INFOS = {''};

		figure
		orient tall

		aliases = [];
		ncolors = [];

		% linear/log time series
		subplot(4,1,1:2), extaxes(gca,[.07,.01])
		hold on
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
				col = scolor(n);
				timeplot(tk,dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				aliases = cat(2,aliases,{N(n).ALIAS});
				ncolors = cat(2,ncolors,n);
			end
		end
		hold off
		ylim = get(gca,'YLim');
		set(gca,'XLim',tlim,'YLim',[0,ylim(2)],'FontSize',8)
		box on
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('All channels %s',regexprep(D(1).CLB.un{1},'(.+)','($1)')))

		% legend: station aliases
		xlim = get(gca,'XLim');
		ylim = get(gca,'YLim');
		nn = length(aliases);
		for n = 1:nn
			text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
		end

		tlabel(xlim,P.GTABLE(r).TZ)
		plotevent(P.EVENTS_FILE)

		% 1/x time series (Y-axis linear scale forced)
		% makes a new data vector with averaged signals

		subplot(4,1,3:4), extaxes(gca,[.07,.01])
		hold on
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
				col = scolor(n);
				timeplot(tk,1./dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
			end
		end
		hold off
		ylim = get(gca,'YLim');
		set(gca,'XLim',tlim,'Ylim',[0,ylim(2)],'FontSize',8)
		box on
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('1/x %s',regexprep(D(1).CLB.un{1},'(.+)','($1)')))

		% legend: station aliases
		xlim = get(gca,'XLim');
		ylim = get(gca,'YLim');
		for n = 1:nn
			text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
		end

		tlabel(xlim,P.GTABLE(r).TZ)
		plotevent(P.EVENTS_FILE)

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end

	% -------------------------------------------------------------------------------------
	% --- SARA synthetic graph
	summary = 'SARA';
	if any(strcmp(P.SUMMARYLIST,summary))
		kn = find(~ismemberlist({N.FID},split(field2str(P,'SARA_EXCLUDED_NODELIST'),',')));
		% To have a single vector t with matrix d, must interpolate all channels at the highest frequency sampling rate
		nsf = nan(length(kn),1);
		for n = 1:length(kn)
			nsf(n) = D(kn(n)).CLB.sf;
		end
		samp = max(nsf);

		% final time vector is F.datelim limits or shorter
		t = (P.DATELIM(1):1/samp/86400:P.DATELIM(2))';
		d = nan(length(t),length(kn));
		for n = 1:length(kn)
			if ~isempty(D(kn(n)).d)
				d(:,n) = interp1(D(kn(n)).t,rmean(D(kn(n)).d,2),t);
			end
		end
		% computes ratios
		dr = nan(length(t),(length(kn)*(length(kn)-1))/2);
		index = 1;
		for i = 1:length(kn)-1
			for ii = i+1:length(kn)
				dr(:,index) = d(:,i)./d(:,ii);
				index = index + 1;
			end
		end

		%% Calculate correlation coefficients
		fprintf('%s: computing correlation coefficients...',wofun);
		all_st_int = [];

		% Calculate correlation coefficient for variety of window sizes
		for window = sara_timewindows
		    coeff_all = [];
		    for st_pair = 1:size(dr,2)
			ratio = dr(:,st_pair);

			%% With overlapping windows
		       if isok(sara_overlap)
			    time_x = 1:size(dr,1);

			    % Extract window-sized block of data and calculate correlation coefficient

			    Coeff = [];
			    for i = 0:length(time_x)-window
				tcor = time_x(i*sara_overlap_step + 1:i*sara_overlap_step + window); % index of points in window for time vector

				rapp = ratio(i*sara_overlap_step + 1:i*sara_overlap_step + window); % index of points in window for ratio vector

				if length(rapp(rapp==rapp)) < sara_minpoints % number of points excluding NaN
					Coeff = [Coeff; NaN];
				else
					%R = corr(t(r==r)',r(r==r),'type','spearman'); % Spearman rank correlation coefficent
					R = corrcoef(tcor(rapp==rapp)',rapp(rapp==rapp)); % Spearman rank correlation coefficent
					Coeff = [Coeff; R(1,2)];
				end
			    end

			%% Non-overlapping windows
		       elseif ~isok(sara_overlap)
			    time_x = 1:size(dr,1);

			    % Extract window-sized block of data and calculate correlation coefficient
			    Coeff = [];
			    for i = 1:length(time_x)/window
				tcor = time_x(((i-1)*window + 1):(i*window));

				rapp = ratio(((i-1)*window + 1):(i*window));

				if length(rapp(rapp==rapp)) < sara_minpoints
				    Coeff = [Coeff; NaN];
				else
					%R = corr(t(r==r)',r(r==r),'type','spearman'); % Spearman rank correlation coefficent
					R = corrcoef(tcor(rapp==rapp)',rapp(rapp==rapp)); % Spearman rank correlation coefficent
					Coeff = [Coeff; R(1,2)];
				end
			    end
		      %end of overlap/no overlap option
		       end
			%% Determine if correlation coefficient exceeds threshold and assign
			%% corresponding values: +1/-1 for exceeding and 0 for not exceeding

			y = Coeff;
			y(y <= -sara_threshold) = -1;
			y(y >= sara_threshold) = 1;
			y(y>-sara_threshold & y<sara_threshold) = 0;

			y_abs = abs(y);
			y_total = sum(y_abs==1);

			% STA1_STA2_flag = 1 or -1 or 0
			coeff_all = [coeff_all  y_abs];
			%flag(:,st_pair) = y_abs;
			%eval([char(ratio_st{st_pair}(1:sta_char)) '_' char(ratio_st{st_pair}(sta_char+2:end)) '_flag = y_abs;'])

		    end

		    %% Calculate total number of station pairs with correlation coefficient
		    %% exceeding threshold

		    % does not differentiate between NaN and 0 (data unavailable due to too few
		    % points or correlation coefficient below threshold); calculates the total
		    % number of station pairs exceeding regardless of unavailable data from
		    % some station pairs
		    %total = nansum(coeff_all,2);

		    % differentiates between data available but correlation zero and data not
		    % available; only calculates the total number of station pairs exceeding
		    % threshold when all station pairs have available data
		    total_nan = sum(coeff_all,2);
		    %% Prepares data for different window sizes for plotting on the same axes
		    % Non-overlapping windows
		    if ~isok(sara_overlap)
			n = window;
			with_repeat = repmat(total_nan',n,1);
			with_repeat = with_repeat(:)';
			if length(with_repeat) < size(dr,1)
			    with_repeat = [with_repeat NaN(1,(size(dr,1)-length(with_repeat)))];
			end
			all_st_int = [all_st_int; with_repeat];
		    % Overlapping windows
		    elseif isok(sara_overlap)
			with_start = NaN(1,size(dr,1));
			with_start(((size(dr,1) - length(total_nan))+1):end) = total_nan';
			all_st_int = [all_st_int; with_start];
		    end
		end


		%% Plot final figure showing number of station pairs exceeding correlation
		%% coefficient threshold using colour
		tplot = t(1:size(all_st_int,2));
		dt = [1:size(all_st_int,1)];
			all_st_int = all_st_int/size(dr,2);
		%all_st_int = [all_st_int; NaN(1,length(tplot)-1)];
		%all_st_int = [all_st_int NaN(length(dt),1) ];

		fprintf(' done!\n');

		for r = 1:length(P.GTABLE)

			V.timescale = timescales(P.GTABLE(r).TIMESCALE);
			tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
			if any(isnan(tlim))
				tlim = minmax(cat(1,D.tfirstlast));
			end
			P.GTABLE(r).GTITLE = varsub(sara_title,V);
			P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
			P.GTABLE(r).INFOS = {''};

			% --- Time series graph
			figure
			orient tall

			aliases = [];
			ncolors = [];

			% log time series (1/4 upper part of the page)
			subplot(8,1,1:2), extaxes(gca,[.07,.02])
			hold on
			for n = 1:length(kn)
				k = find(isinto(t,tlim));
				if ~isempty(k)
					% computes the mean of all channels
					[tk,dk] = treatsignal(t(k),d(k,n),P.GTABLE(r).DECIMATE,P);
					col = scolor(n);
					timeplot(tk,dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
					aliases = cat(2,aliases,{N(n).ALIAS});
					ncolors = cat(2,ncolors,n);
				end
			end
			hold off
			set(gca,'XLim',tlim,'Yscale','log','FontSize',8)
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('All channels (count)'))

			% legend: station aliases
			xlim = get(gca,'XLim');
			ylim = get(gca,'YLim');
			nn = length(aliases);
			for n = 1:nn
				text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
			end

			plotevent(P.EVENTS_FILE)

			% ratios (log scale)
			cols = str2num(sprintf('%s(%d)',ratio_colormap,size(dr,2)));
			subplot(8,1,3:4), extaxes(gca,[.07,.02])
			hold on
			for n = 1:size(dr,2)
				k = find(isinto(t,tlim));
				if ~isempty(k)
					% computes the mean of all channels
					[tk,dk] = treatsignal(t(k),dr(k,n),P.GTABLE(r).DECIMATE,P);
					col = cols(n,:);
					timeplot(tk,dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				end
			end
			hold off
			set(gca,'XLim',tlim,'YScale','log','FontSize',8)
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('Station ratios'))
			plotevent(P.EVENTS_FILE)

			% -----------------------------------------------------------------------------------------
			% SARA coefficients
			subplot(8,1,5:8), extaxes(gca,[.07,.02])

			k = isinto(tplot,tlim);
			imagesc(tplot(k),dt,all_st_int(:,k));
			cols = str2num(sprintf('%s(%d)',sara_colormap,size(dr,2)*10));
			colormap([[0,0,0] ; cols(9:10:end,:)])
			caxis([0 1])
			set(gca,'Ydir','normal')
			grid on
			h = colorbar('location','SouthOutside');
			set(get(h,'XLabel'),'string',sprintf('Fraction of stations pairs\n showing changes in ratio'));
			set(gca,'XLim',tlim,'ytick',dt,'yticklabel',days2h(sara_timewindows/1440,'short'),'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('Time windows'))

			tlabel(xlim,P.GTABLE(r).TZ)
			plotevent(P.EVENTS_FILE)
			rcode2 = sprintf('%s_%s',proc,summary);
			mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r))
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
