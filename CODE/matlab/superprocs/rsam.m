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
%       be set with 'SUMMARYLIST|' parameter. RSAM will compute the mean of all channels
%       for each node.
%
%       Other specific paramaters are described in CODE/tplates/PROC.RSAM.
%
%	Reference: based on the tremor maps made by V. Ferrazzini / OVPF-IPGP
%
%	Authors: F. Beauducel, J.-M. Saurel / WEBOBS, IPGP
%	Created: 2017-07-19
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
alarm_threshold_level = field2num(P,'ALARM_THRESHOLD_LEVEL',0);
alarm_color = field2num(P,'ALARM_COLOR',[1,0,0]);
sourcemap_n = field2num(P,'SOURCEMAP_N',2);
sourcemap_title = field2str(P,'SOURCEMAP_TITLE','{\fontsize{14}{\bf$name - Source Map} ($timescale)}');
sourcemap_colormap = field2num(P,'SOURCEMAP_COLORMAP',spectral(256));
sourcemap_alpha = field2num(P,'SOURCEMAP_COLORMAP_ALPHA');
sourcemap_caxis = field2num(P,'SOURCEMAP_CAXIS',[0,2e-5]);
ylogscale = isok(P,'YLOGSCALE');
pagemaxsubplot = field2num(P,'PAGE_MAX_SUBPLOT',8);
movingaverage = field2num(P,'MOVING_AVERAGE_SAMPLES',1);

for n = 1:length(N)

	C = D(n).CLB;
	nx = C.nx;
	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;
	V.last_data = datestr(D(n).tfirstlast(2));


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
			if alarm_threshold_level > 0
				plot(tlim,repmat(alarm_threshold_level,1,2),'--','Color',alarm_color,'LineWidth',1)
			end
			hold on
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
			hold off
			set(gca,'XLim',tlim,'YLim',[0,Inf],'FontSize',8)
			if ylogscale
				set(gca,'YScale','log')
			end
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s %s',D(n).CLB.nm{i},regexprep(D(n).CLB.un{i},'(.+)','($1)')))
			if isempty(D(n).d) || all(isnan(D(n).d(k,i)))
				nodata(tlim)
			end

			% 1/x time series (Y-axis linear scale forced)
			subplot(nx*4,1,4*(i-1) + (3:4)), extaxes(gca,[.07,.01])
			if alarm_threshold_level > 0
				plot(tlim,1./repmat(alarm_threshold_level,1,2),'--','Color',alarm_color,'LineWidth',1)
			end
			hold on
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
			hold off
			set(gca,'XLim',tlim,'Ylim',[0,Inf],'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s %s',D(n).CLB.nm{i},regexprep(D(n).CLB.un{i},'(.+)','(1/($1))')))
			if isempty(D(n).d) || all(isnan(D(n).d(k,i)))
				nodata(tlim)
			end
		end

		tlabel(tlim,P.TZ)

		% title, status and additional information
		P.GTABLE(r).GTITLE = varsub(pernode_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};
		if ~isempty(k)
			P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.TZ),' (min|avr|max)',' '};
			for i = 1:nx
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+g %s} (%+g | %+g | %+g)', ...
					i, D(n).CLB.nm{i},D(n).d(ke,i),D(n).CLB.un{i},roundsd([rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i))],5))}];
			end
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
		if alarm_threshold_level > 0
			plot(tlim,repmat(alarm_threshold_level,1,2),'--','Color',alarm_color,'LineWidth',1)
		end
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
		if ylogscale
			set(gca,'YScale','log')
		end
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

		tlabel(xlim,P.TZ)

		% 1/x time series (Y-axis linear scale forced)
		% makes a new data vector with averaged signals

		subplot(4,1,3:4), extaxes(gca,[.07,.01])
		if alarm_threshold_level > 0
			plot(tlim,1./repmat(alarm_threshold_level,1,2),'--','Color',alarm_color,'LineWidth',1)
		end
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

		tlabel(xlim,P.TZ)

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end

	% -------------------------------------------------------------------------------------
	% --- Source mapping from amplitude
	summary = 'SOURCEMAP';
	if any(strcmp(P.SUMMARYLIST,summary))
		geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84),cat(1,N.ALTITUDE)];
		for r = 1:length(P.GTABLE)

			V.timescale = timescales(P.GTABLE(r).TIMESCALE);
			tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
			if any(isnan(tlim))
				tlim = minmax(cat(1,D.tfirstlast));
			end
			P.GTABLE(r).GTITLE = varsub(sourcemap_title,V);
			P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
			P.GTABLE(r).INFOS = {''};

			% --- Time series graph
			figure
			orient tall

			aliases = [];
			ncolors = [];

			% linear/log time series (1/4 upper part of the page)
			subplot(4,1,1), extaxes(gca,[.07,.01])
			if alarm_threshold_level > 0
				plot(tlim,repmat(alarm_threshold_level,1,2),'--','Color',alarm_color,'LineWidth',1)
			end
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
			set(gca,'XLim',tlim,'FontSize',8)
			if ylogscale
				set(gca,'YScale','log')
			end
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('All channels (m/s)'))

			% legend: station aliases
			xlim = get(gca,'XLim');
			ylim = get(gca,'YLim');
			nn = length(aliases);
			for n = 1:nn
				text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
			end

			tlabel(xlim,P.TZ)

			% plots maps time limits
			tbin = linspace(xlim(1),xlim(2),sourcemap_n^2+1);
			plotevt(tbin,'-.','Color',.5*ones(1,3),'LineWidth',1)

			% --- maps of source location
			% computes map limits: a square that includes all nodes
			lat0 = mean(geo(:,1));
			lon0 = mean(geo(:,2));
			xylim = xyw2lim([lon0,lat0,.01+max(diff(minmax(geo(:,1))),diff(minmax(geo(:,2))/cosd(lat0)))],1/cosd(lat0));
			DEM = loaddem(WO,xylim,P);
			I = dem(DEM.lon,DEM.lat,DEM.z,'latlon','noplot','colormap',white);
			[xx,yy] = meshgrid(I.x,I.y);

			for m = 1:(sourcemap_n^2)
				tlim  = tbin(m+(0:1));
				% suplots are made to fill the 3/4 lower part of the page
				switch sourcemap_n
				case 1
					subplot(4,1,2:4);
				case 2
					subplot(8,2,m + 4*floor((m-1)/2) + 4 + (0:2:4));
				case 3
					subplot(4,3,m + 3);
				case 4
					subplot(16,4,m + 8*floor((m-1)/4) + 16 + (0:4:8));
				end
				extaxes(gca,[0.1,0.1,0,0.1])

				% computes the mean value for each node
				dx = [geo(:,2);xylim([1,2,1,2])'];
				dy = [geo(:,1);xylim([3,3,4,4])'];
				dz = nan(1,length(N)+4); % init with NaN
				dz(end-3:end) = 0; % 4 last to fix map corners to 0
				for n = 1:length(N)
					k = D(n).G(r).k;
					if ~isempty(k)
						dz(n) = rmean(D(n).d(isinto(D(n).t,tlim)));
					end
				end
				k = find(~isnan(dz));
				zz = griddata(dx(k),dy(k),dz(k),xx,yy,'v4');

				% computed mixed map with shaded relied
				inorm = zz/diff(sourcemap_caxis) + sourcemap_caxis(1); % normalized values (0,1)
				inorm(inorm<0) = 0;
				inorm(inorm>1) = 1;
				I.msk = ind2rgb(round(size(sourcemap_colormap,1)*inorm),sourcemap_colormap); % RGB map
				A = repmat(interp1(linspace(0,1,length(sourcemap_alpha)),sourcemap_alpha,inorm),[1,1,3]);
				I.tot = I.rgb.*(1 - A) + I.msk.*A;
				imagesc(xx(1,:),yy(:,1),I.tot);
				axis xy

				set(gca,'XTick',[],'YTick',[],'DataAspectRatio',[1,cosd(lat0),1],'FontSize',8)
				hold on
				% plot stations
				plot(geo(:,2),geo(:,1),'^k','MarkerSize',4)
				% plot max value
				if isok(P,'SOURCEMAP_PLOT_MAX')
					k = find(zz == max(zz(:)));
					plot(mean(xx(k)),mean(yy(k)),'pk','MarkerSize',5,'LineWidth',2)
				end
				hold off
				xlabel({sprintf('{\\bf%s} {\\it%+g}',datestr(tlim(1)),P.TZ), ...
					sprintf('{\\bf%s} {\\it%+g}',datestr(tlim(2)),P.TZ)});

			end

			% legend (colorscale)
			axes('position',[0.05,0.3,0.02,0.2]);
			clin = linspace(sourcemap_caxis(1),sourcemap_caxis(2));
			imagesc([0,1],clin*1e6,repmat(clin',[1,2]));
			ylim = get(gca,'Ylim');
			patch([0,.5,1,0],ylim(2) + diff(ylim)*[0,.05,0,0],'k','FaceColor','k','Clipping','off')
			patch([0,.5,1,0],ylim(1) - diff(ylim)*[0,.05,0,0],'k','FaceColor','w','Clipping','off')
			axis xy
			set(gca,'XLim',[0,1],'XTick',[],'FontSize',8)
			colormap(shademap(sourcemap_colormap,sourcemap_alpha))
			caxis(sourcemap_caxis);
			title({'{\mu}m/s',''},'FontWeight','bold')

			axes('position',[0.05,0.1,0.02,0.6]);
			hold on
			plot(.5,.25,'pk','MarkerSize',5,'LineWidth',2)
			text(.5,.25,{'','max.','amplitude'},'FontSize',8,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top')
			plot(.5,.15,'^k','MarkerSize',4)
			text(.5,.15,{'','station'},'FontSize',8,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top')
			hold off
			set(gca,'XLim',[0,1],'YLim',[0,1]);
			axis off

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
