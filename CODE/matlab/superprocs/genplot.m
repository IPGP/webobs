function DOUT=genplot(varargin)
%GENPLOT WebObs SuperPROC: Updates graphs/exports of any time series.
%
%       GENPLOT(PROC) makes default outputs of a generic time series PROC.
%
%       GENPLOT(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	GENPLOT(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = GENPLOT(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       GENPLOT will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and and nodes' calibration file channels definition to select
%       channels and display names and units.
%
%       In addition to each single node graph, a summary graph with all nodes can
%       be set with 'SUMMARYLIST|SUMMARY' parameter. Default is all channels, but
%       selection can be made with following option:
%          SUMMARY_CHANNELS|1,,4,3
%       using coma-separated channel number list, and optional multiple comas to extend
%       the previous subplot height in proportion to others. In the example the first
%       suplot will contain the channel number 1 and will be double-height compared to
%       the second (channel 4) and third subplot (channel 3).
%
%       See CODE/tplates/PROC.GENPLOT for other specific paramaters.
%
%
%	Authors: F. Beauducel, J.-M. Saurel / WEBOBS, IPGP
%	Created: 2014-07-13
%	Updated: 2022-11-24

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
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','-');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name} ($timescale)}');
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','-');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');
pagemaxsubplot = field2num(P,'PAGE_MAX_SUBPLOT',8);
ylogscale = isok(P,'YLOGSCALE');
movingaverage = round(field2num(P,'MOVING_AVERAGE_SAMPLES',1));

exthax = [.08,.02];
nxm = 0; % max number of channels

for n = 1:length(N)

	C = D(n).CLB;
	nx = C.nx;
	nxm = max(nxm,nx);
	GN = graphstr(field2str(P,'PERNODE_CHANNELS',sprintf('%d,',1:nx),'notempty'));
	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;
	V.last_data = datestr(D(n).tfirstlast(2));


	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		% adjusts moving average filter to decimated data (keeps the cut-off frequency)
		movingaverage_dec = round(movingaverage/P.GTABLE(r).DECIMATE);
		movingaverage_dec(movingaverage_dec<2) = []; % removes any non integer or lower than 2 values

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
			if isok(P,'PERNODE_RELATIVE')
				dk = rf(dk);
			end
		end

		% loop for each data column
		for p = 1:length(GN)

			subplot(GN(p).subplot{:}), extaxes(gca,exthax)
			i = GN(p).chan;
			if ~isempty(k) && i <= nx
				if isok(P,'CONTINUOUS_PLOT') || ~isfield(D(n).CLB,'sf')
					samp = 0;
				else
					samp = D(n).CLB.sf(i);
				end
				col = scolor(p);
				timeplot(tk,dk(:,i),samp,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
					'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
				hold on
				for j = 1:length(movingaverage_dec)
					if movingaverage_dec(j) > 1
						col = j/(j+1) + scolor(p)/(j+1);
						timeplot(tk,mavr(dk(:,i),movingaverage_dec(j)),samp,'-', ...
							'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',col,'MarkerFaceColor',col)
					end
				end
				hold off
			end
			if ylogscale
				set(gca,'YScale','log')
			end
			set(gca,'XLim',tlim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			if p < length(GN)
				set(gca,'XTickLabel',[]);
			end
			ylabel(sprintf('%s %s',D(n).CLB.nm{i},regexprep(D(n).CLB.un{i},'(.+)','($1)')))
			if isempty(D(n).d) || all(isnan(D(n).d(k,i)))
				nodata(tlim)
			end

			% legend: moving average
			xlim = get(gca,'XLim');
			ylim = get(gca,'YLim');
			nn = length(movingaverage_dec);
			for j = 1:nn
				if movingaverage_dec(j) > 1
					col = j/(j+1) + scolor(p)/(j+1);
					text(xlim(1)+j*diff(xlim)/(nn+1),ylim(2)+diff(ylim)/100,sprintf('mov. avg %g',movingaverage_dec(j)),'Color',col, ...
						'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',max(10-nn,6),'FontWeight','bold')
				end
			end
			set(gca,'YLim',ylim);

		end

		tlabel(tlim,P.GTABLE(r).TZ)

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
		if isok(P,'PLOT_GRID')
			grid on
		end

		% makes graph
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
			E.t = tk;
			E.d = dk(:,1:nx);
			E.header = strcat(D(n).CLB.nm,{'('},D(n).CLB.un,{')'});
			E.title = sprintf('%s {%s}',sprintf('%s: %s',N(n).ALIAS,N(n).NAME),upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
end


% ====================================================================================================
% Graphs for all the proc nodes

if any(strcmpi(P.SUMMARYLIST,'SUMMARY'))
	G = cat(1,D.G);

	GS = graphstr(field2str(P,'SUMMARY_CHANNELS',sprintf('%d,',1:nxm),'notempty'));

	for r = 1:length(P.GTABLE)

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(cat(1,D.tfirstlast));
		end
		P.GTABLE(r).GTITLE = varsub(summary_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
		P.GTABLE(r).INFOS = {''};

		% --- Time series graph
		figure
		if length(GS) > pagemaxsubplot
			ps = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[ps(1),ps(2)*length(GS)/pagemaxsubplot])
		end
		orient tall

		for p = 1:length(GS)
			subplot(GS(p).subplot{:}), extaxes(gca,exthax)
			c = GS(p).chan;

			hold on
			aliases = [];
			ncolors = [];
			for n = 1:length(N)
				k = D(n).G(r).k;
				if ~isempty(k)
					[tk,dk] = treatsignal(D(n).t(k),D(n).d(k,c),P.GTABLE(r).DECIMATE,P);
					if isok(P,'SUMMARY_RELATIVE')
						dk = rf(dk);
					end
					if isok(P,'CONTINUOUS_PLOT') || ~isfield(D(n).CLB,'sf')
						samp = 0;
					else
						samp = D(n).CLB.sf(c)/P.GTABLE(r).DECIMATE;
					end
					col = scolor(n);
					timeplot(tk,dk,samp,summary_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH, ...
						'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
					aliases = cat(2,aliases,{N(n).ALIAS});
					ncolors = cat(2,ncolors,n);
				end
			end
			hold off
			if ylogscale
				set(gca,'YScale','log')
			end
			set(gca,'XLim',tlim,'FontSize',8)
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
			if p < length(GS)
				set(gca,'XTickLabel',[]);
			end
			ylabel(sprintf('%s %s',D(1).CLB.nm{c},regexprep(D(1).CLB.un{c},'(.+)','($1)')))

			% legend: station aliases
			xlim = get(gca,'XLim');
			ylim = get(gca,'YLim');
			nn = length(aliases);
			for n = 1:nn
				text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2)+diff(ylim)/100,aliases(n),'Color',scolor(ncolors(n)), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',max(11-nn,6),'FontWeight','bold')
			end
			set(gca,'YLim',ylim);
		end

		tlabel(xlim,P.GTABLE(r).TZ)

		if isok(P,'PLOT_GRID')
			grid on
		end
		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
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
