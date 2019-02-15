function DOUT=tilt(varargin)
%TILT	WebObs SuperPROC: Updates graphs/exports of tiltmeter network.
%
%       TILT(PROC) makes default outputs of PROC.
%
%       TILT(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	TILT(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = TILT(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       TILT will use PROC's and NODE's parameters to import data. Particularily, it uses
%       NODE's calibration file channels definition, that must contain these 3 channels:
%           Tilt X (탍ad)
%           Tilt Y (탍ad)
%           Temperature (캜)
%       defined by these 3 PROC's parameters (values are selected Ch. Nb. in calibration
%       file order, starting from 1):
%           TILTX_CHANNEL|1
%           TILTY_CHANNEL|2
%           TEMPERATURE_CHANNEL|3
%	Note that channels X and Y azimuth values are mandatory to convert to NS and EW
%	components.
%	
%
%       TILT will use PROC's parameters from .conf file. Specific paramaters are:
%           PICKS_CLEAN_PERCENT|0
%	    MEDIAN_FILTER_SAMPLES|10
%           FLAT_IS_NAN|YES
%	    TREND_ERROR_MODE|1
%	    PERNODE_TEMPERATURE_BACKGROUND|N
%	    PERNODE_TEMPERATURE_COLOR|1,.7,.7
%	    TILT_TARGET_LATLON|-7.54144,110.44574
%	    MOTION_EXCLUDED_NODELIST|
%	    MOTION_MIN_SIZE_KM|10
%	    MOTION_MAX_XYRATIO|1.5
%	    MOTION_TIME_COLORMAP|jet(256)
%	    MOTION_DEM_OPT|'colormap',.5*ones(64,3),'watermark',2,'interp','legend'
%	    MOTION_TITLE|{\fontsize{14}{\bf$name} ($timescale)}
%	    VECTORS_EXCLUDED_NODELIST|
%	    VECTORS_VELOCITY_SCALE|
%	    VECTORS_MIN_SIZE_KM|10
%	    VECTORS_MAX_XYRATIO|1.5
%	    VECTORS_ARROWSHAPE|.1,.1,.08,.02
%	    VECTORS_DEM_OPT|'watermark',2,'interp','legend'
%	    VECTORS_TITLE|{\fontsize{14}{\bf$name} ($timescale)}
%	    MODELLING_EXCLUDED_NODELIST|
%	    MODELLING_MODULE_ONLY|0
%	    MODELLING_MAX_DEPTH|8000
%	    MODELLING_BORDERS|5000
%	    MODELLING_GRID_SIZE|100
%	    MODELLING_SIGMAS|1
%	    MODELLING_PLOT_BEST|N
%	    MODELLING_TITLE|{\fontsize{14}{\bf$name} ($timescale)}
%
%
%   Authors: F. Beauducel, A. Peltier, P. Boissier, Ph. Kowalski, Ph. Catherine, C. Brunet, V. Ferrazini, Moussa Mogne Ali, Shafik Bafakih / WEBOBS, IPGP-OVPF-OVK
%   Created: 2015-08-24 in Yogyakarta, Indonesia
%   Updated: 2018-04-23

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
G = cat(1,D.G);


border = .1;
fontsize = 7;
darkgray = ones(1,3)*.1;

% gets PROC's specific parameters
debug = isok(P,'DEBUG');
ixyt = [field2num(P,'TILTX_CHANNEL',1),field2num(P,'TILTY_CHANNEL',2),field2num(P,'TEMPERATURE_CHANNEL',3)];
terrmod = field2num(P,'TREND_ERROR_MODE',1);
targetlatlon = field2num(P,'TILT_TARGET_LATLON');
velscale = field2num(P,'VECTORS_VELOCITY_SCALE',0);
minkm = field2num(P,'VECTORS_MIN_SIZE_KM',10);
maxxy = field2num(P,'VECTORS_MAX_XYRATIO',1.5);
arrowshape = field2num(P,'VECTORS_ARROWSHAPE',[.1,.1,.08,.02]);
vectors_title = field2str(P,'VECTORS_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');
vectors_demopt = field2cell(P,'VECTORS_DEM_OPT','watermark',2,'interp','legend');
maxdep = field2num(P,'MODELLING_MAX_DEPTH',8e3);	% depth limit (m)
bm = field2num(P,'MODELLING_BORDERS',5000);
rr = field2num(P,'MODELLING_GRID_SIZE',51);
msig = field2num(P,'MODELLING_SIGMAS',1);
plotbest = isok(P,'MODELLING_PLOT_BEST');
moduleonly = isok(P,'MODELLING_MODULE_ONLY');
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','-');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name} ($timescale)}');
pernode_temperature_bg = isok(P,'PERNODE_TEMPERATURE_BACKGROUND');
pernode_temperature_col = field2num(P,'PERNODE_TEMPERATURE_COLOR',.7*ones(1,3));
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','-');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');
modelling_title = field2str(P,'MODELLING_TITLE','{\fontsize{14}{\bf$name} ($timescale)}');

geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84),cat(1,N.ALTITUDE)];

for n = 1:length(N)

	% in "target mode", adds 2 more columns to data matrix: radial and tangential 
	if length(targetlatlon) > 1
		%[lat,lon,dist,bear] = greatcircle(geo(n,1),geo(n,2),targetlatlon(1),targetlatlon(2),2);
		%D(n).d = [D(n).d,];
	end
	
	t = D(n).t;
	d = D(n).d;
	C = D(n).CLB;
	nx = length(C.nm);
	if ~all(isinto(ixyt,1:size(d,2)))
		error('%s: TILTX_CHANNEL, TILTY_CHANNEL or TEMPERATURE_CHANNEL are not consistent with data channel numbers for node %s.',N(n).ID)
	end

	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;
	V.last_data = datestr(D(n).tfirstlast(2));

	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure
		if pernode_temperature_bg

			% reduces paper height
			ps = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[ps(1),ps(2)*0.7])
		end
		orient tall

		% renames main variables for better lisibility...
		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;
    
		% title and status
		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		stitre = varsub(pernode_title,V,'tex');
		P.GTABLE(r).GTITLE = stitre;
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};

		% loop for X and Y components with error bars (in m)
		lre = nan(nx,2);
		if pernode_temperature_bg
			if ~isempty(k)
				[tkt,dkt] = treatsignal(t(k),d(k,ixyt(3)),P.GTABLE(r).DECIMATE,P);
			end
			for ii = 1:2
				i = ixyt(ii);
				subplot(4,1,(ii-1)*2+(1:2)), extaxes(gca,[0.07,0.07])
				rel = '';
				if ~isempty(k)
					k1 = k(find(~isnan(d(k,i)),1));
					if ~isempty(k1)
						[tk,dk] = treatsignal(t(k),d(k,i)-d(k1,i),P.GTABLE(r).DECIMATE,P);
						rel = 'Relative ';
					else
						[tk,dk] = treatsignal(t(k),d(k,i),P.GTABLE(r).DECIMATE,P);
					end
					kreal = find(~isnan(dk) & ~isnan(dkt));
					rxy = corrcoef(dk(kreal),dkt(kreal));
					tsign = sign(rxy(2));
					[ax,h1,h2] = plotyy(tk,dk,tkt,dkt*tsign,'timeplot');
					set(h1,'LineStyle',pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',scolor(i));
					set(h2,'LineStyle',pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',pernode_temperature_col);
					set(ax(1),'Ylim',get(ax(1),'YLim'),'YColor',scolor(i))	% freezes Y axis
					box on
					set(ax(2),'Ylim',get(ax(2),'YLim'),'YColor','k')	% freezes Y axis
					ytick = get(ax(2),'YTick');
					set(ax(2),'YTickLabel',num2str(tsign*ytick(:)));
					box on

					kk = find(~isnan(dk));
					if length(kk) > 2 && ~isempty(k1)
						lr = polyfit(tk(kk)-t(k1),dk(kk),1);
						lre(i,:) = [lr(1),std(dk(kk) - polyval(lr,tk(kk)-t(k1)))/diff(tlim)];
						hold on
						plot(tlim,polyval(lr,tlim - t(k1)),'--k','LineWidth',.2)
						hold off
					end
					set(ax,'XLim',tlim,'FontSize',fontsize)
					axes(ax(1))
					datetick2('x',P.GTABLE(r).DATESTR)
					ylabel(sprintf('%s%s (%s)',rel,C.nm{i},C.un{i}))
					axes(ax(2))
					datetick2('x',P.GTABLE(r).DATESTR)
					ylabel(sprintf('%s (%s)',C.nm{ixyt(3)},C.un{ixyt(3)}))
				else
					set(gca,'XLim',tlim,'FontSize',fontsize)
					datetick2('x',P.GTABLE(r).DATESTR)
					ylabel(sprintf('%s%s (%s)',rel,C.nm{i},C.un{i}))

				end
				if isempty(d) || all(isnan(d(k,i)))
					nodata(tlim)
				end
				
			end
			OPT.FIXEDPP = true;
		else
			for ii = 1:3
				i = ixyt(ii);
				subplot(6,1,(ii-1)*2+(1:2)), extaxes(gca,[.07,0])
				rel = '';
				if ~isempty(k)
					k1 = k(find(~isnan(d(k,i)),1));
					if ii < 3 && ~isempty(k1)
						[tk,dk] = treatsignal(t(k),d(k,i)-d(k1,i),P.GTABLE(r).DECIMATE,P);
						rel = 'Relative ';
					else
						[tk,dk] = treatsignal(t(k),d(k,i),P.GTABLE(r).DECIMATE,P);
					end
					if isok(P,'CONTINUOUS_PLOT')
						samp = 0;
					else
						samp = D(n).CLB.sf(i);
					end
					timeplot(tk,dk,samp,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',scolor(i))
					set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis

					kk = find(~isnan(dk));
					if length(kk) > 2 && ~isempty(k1)
						lr = polyfit(tk(kk)-t(k1),dk(kk),1);
						lre(i,:) = [lr(1),std(dk(kk) - polyval(lr,tk(kk)-t(k1)))/diff(tlim)];
						hold on
						plot(tlim,polyval(lr,tlim - t(k1)),'--k','LineWidth',.2)
						hold off
					end
				end
				set(gca,'XLim',tlim,'FontSize',fontsize)
				datetick2('x',P.GTABLE(r).DATESTR)
				ylabel(sprintf('%s%s (%s)',rel,C.nm{i},C.un{i}))
				if isempty(d) || all(isnan(d(k,i)))
					nodata(tlim)
				end
			end
			OPT.FIXEDPP = false;
		end
		tlabel(tlim,P.GTABLE(r).TZ,'FontSize',8)

		if ~isempty(k) && ~isempty(k1)
			P.GTABLE(r).INFOS = {sprintf('Last measurement: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ),' (min|moy|max)',' ',' '};
			for i = ixyt
				drel = d(k1,i)*(i<3);
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+1.3f %s} (%+1.3f | %+1.3f | %+1.3f) - Trend = {\\bf%+1.3f \\pm %1.3f %s/day}', ...
					i, C.nm{i},d(ke,i)-drel,C.un{i},rmin(d(k,i)-drel),rmean(d(k,i)-drel),rmax(d(k,i)-drel),lre(i,:),C.un{i})}];
			end
		end
		
		% makes graph
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
			E.t = t(k);
			E.d = d(k,ixyt);
			E.header = {'TiltX(탍ad)','TiltY(탍ad)','Temperature(캜)'};
			E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
	
	% Stores in main structure D to prepare the summary graph
	D(n).t = t;
	D(n).d = d;
end


% ====================================================================================================
% Summary graphs (all proc's nodes)

for r = 1:length(P.GTABLE)

	tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
	if any(isnan(tlim))
		tlim = minmax(cat(1,D.tfirstlast));
	end
	
	V.name = P.NAME;
	V.timescale = timescales(P.GTABLE(r).TIMESCALE);
	P.GTABLE(r).GTITLE = varsub(summary_title,V,'tex');
	if P.GTABLE(r).STATUS
		P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
	end
	P.GTABLE(r).INFOS = {''};
	tr = nan(length(N),2); % trends per station per component (탍ad/day)
	tre = nan(length(N),2); % trends error (탍ad/day)


	% --- Time series graph
	figure, clf, orient tall

	for ii = 1:3
		i = ixyt(ii);
		subplot(6,1,(ii-1)*2+(1:2)), extaxes(gca,[.07,0])
		hold on
		aliases = [];
		ncolors = [];
		rel = '';
		for n = 1:length(N)
			
			k = D(n).G(r).k;
			if ~isempty(k)
				k1 = k(find(~isnan(D(n).d(k,i)),1));
				if ii < 3 && ~isempty(k1)
					[tk,dk] = treatsignal(D(n).t(k),D(n).d(k,i) - D(n).d(k1,i),P.GTABLE(r).DECIMATE,P);
					rel = 'Relative ';
				else
					[tk,dk] = treatsignal(D(n).t(k),D(n).d(k,i),P.GTABLE(r).DECIMATE,P);
				end
				if isok(P,'CONTINUOUS_PLOT')
					samp = 0;
				else
					samp = D(n).CLB.sf(i);
				end
				timeplot(tk,dk,samp,summary_linestyle,'Color',scolor(n),'MarkerSize',P.GTABLE(r).MARKERSIZE/10)
				% computes yearly trends (in 탍ad/day)
				kk = find(~isnan(dk));
				if i < 3 && length(kk) > 2
					b = polyfit(tk(kk)-tk(1),dk(kk),1);
					tr(n,ii) = b(1);
					tre(n,ii) = std(dk(kk) - polyval(b,tk(kk)-tk(1)))/diff(tlim);
					% all errors are adjusted with sampling completeness factor
					acq = 1;
					if N(n).ACQ_RATE > 0
						acq = length(kk)*N(n).ACQ_RATE/abs(diff(tlim));
						tre(n,ii) = tre(n,ii)/sqrt(acq);
					end
					if debug
						fprintf('%s: tr = %g, tre = %g (acq = %g)\n',N(n).ALIAS,tr(n,ii),tre(n,ii),roundsd(acq,3));
					end
				end
				%tki = linspace(tk(1),tk(end));
				%dki = interp1(tk,dk,tki,'cubic');
				%plot(tki,dki,'-','Color',scolor(n),'LineWidth',.1)
				aliases = cat(2,aliases,{N(n).ALIAS});
				ncolors = cat(2,ncolors,n);
			end
		end
		hold off
		set(gca,'XLim',tlim,'FontSize',fontsize)
		box on
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('%s%s (%s)',rel,D(n).CLB.nm{i},D(n).CLB.un{i}))
		
		% legend: station aliases
		ylim = get(gca,'YLim');
		nl = length(aliases);
		for n = 1:nl
			text(tlim(1)+n*diff(tlim)/(nl+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
		end
		set(gca,'YLim',ylim);
	end

	tlabel(tlim,P.GTABLE(r).TZ,'FontSize',8)
    
	mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
	close


	% --- Vectors map
	summary = 'VECTORS';
	if isfield(P,'SUMMARYLIST') && any(strcmp(P.SUMMARYLIST,summary))
		if isfield(P,'VECTORS_EXCLUDED_NODELIST')
			kn = find(~ismemberlist({N.FID},split(P.VECTORS_EXCLUDED_NODELIST,',')));
		else
			kn = 1:length(N);
		end
		figure, set(gcf,'PaperPosition',[0,0,get(gcf,'PaperSize')]);

		% latitude extent of network and xy ratio
		ylim = minmax(geo(kn,1));
		xyr = cosd(mean(ylim));

		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		stitre = varsub(vectors_title,V,'tex');
		P.GTABLE(r).GTITLE = stitre;

		% scale is adjusted to maximum horizontal vector or error amplitude (in 탍ad/day)
		if velscale > 0
			vmax = velscale;
		else
			vmax = rmax([abs(complex(tr(kn,1),tr(kn,2)));abs(complex(tre(kn,1),tre(kn,2)))/2]);
		end
		vscale = roundsd(vmax,1);
		vsc = .25*max(diff(ylim),minkm/degkm)/vmax;

		ha = plot(geo(kn,2),geo(kn,1),'k.');  extaxes(gca,[.04,.08])
		hold on
		% plots velocity vectors first
		for nn = 1:length(kn)
			n = kn(nn);
			if ~any(isnan([vsc,vmax])) && ~any(isnan(tr(n,:)))
				h = arrows(geo(n,2),geo(n,1),vsc*tr(n,1)/xyr,vsc*tr(n,2),arrowshape,'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n),'LineWidth',1);
				ha = cat(1,ha,h);
			end
		end
		% fixes the axis
		axis tight
		axl = axis;
		
		% determines X-Y limits of the map
		dlat = axl(3:4);
		lat0 = mean(axl(3:4));
		if diff(axl(3:4)) < minkm/degkm
			dlat = lat0 + [-.5,.5]*minkm/degkm;
		end
		dlon = axl(1:2);
		lon0 = mean(dlon);
		if diff(dlon) < minkm/degkm(lat0)
			dlon = lon0 + [-.5,.5]*minkm/degkm(lat0);
		end
		% adjusts to respect maximum XY ratio
		if maxxy*diff(dlon)/cosd(lat0) < diff(dlat)
			dlon = lon0 + [-.5,.5]*diff(dlat)*cosd(lat0)/maxxy;
		end
		if maxxy*diff(dlat) < diff(dlon)*cosd(lat0)
			dlat = lat0 + [-.5,.5]*diff(dlon)/cosd(lat0)/maxxy;
		end

		% adds borders in %
		xlim = dlon + diff(dlon)*border*[-1,1]/cosd(lat0);
		ylim = dlat + diff(dlat)*border*[-1,1];

		set(gca,'XLim',xlim,'YLim',ylim);

		% loads DEM (P may contain user's defined DEM)
		DEM = loaddem(WO,[xlim,ylim],P);

		dem(DEM.lon,DEM.lat,DEM.z,'latlon',vectors_demopt{:})
		
		% adds distance from target
		if length(targetlatlon) > 1
			hold on
			[xx,yy] = meshgrid(DEM.lon,DEM.lat);
			DEM.dist = greatcircle(targetlatlon(1),targetlatlon(2),yy,xx);
			[c,h] = contour(DEM.lon,DEM.lat,DEM.dist,'k');
			set(h,'Color',darkgray,'LineWidth',.1);
			clabel(c,h,'FontSize',8,'Color',darkgray);
			hold off
		end

		text(xlim(2),ylim(2)+.01*diff(ylim),DEM.COPYRIGHT,'HorizontalAlignment','right','VerticalAlignment','bottom','Interpreter','none','FontSize',6)

		% plots stations
		target(geo(kn,2),geo(kn,1),7);

		% puts arrows on top
		h = get(gca,'Children');
		ko = find(h == ha(1));
		set(gca,'Children',[ha;h(1:ko)])
		
		% plots error ellipse, vertical component and station name
		for nn = 1:length(kn)
			n = kn(nn);
			if ~isnan(any(tr(n,:)))
				h = ellipse(geo(n,2) + vsc*tr(n,1)/xyr,geo(n,1) + vsc*tr(n,2),vsc*tre(n,1)/xyr,vsc*tre(n,2), ...
					'EdgeColor',scolor(n),'LineWidth',.2,'Clipping','on');
				ha = cat(1,ha,h);
			end
			% text position depends on vector direction
			if tr(n,2) > 0
				stn = {'','',N(n).ALIAS};
			else
				stn = {N(n).ALIAS,'',''};
			end
			text(geo(n,2),geo(n,1),stn,'FontSize',7,'FontWeight','bold', ...
				'VerticalAlignment','Middle','HorizontalAlignment','Center')
		end

		% plots legend scale
		xsc = xlim(1);
		ysc = ylim(1) - .05*diff(ylim);
		lsc = vscale*vsc;
		arrows(xsc,ysc,lsc,90,arrowshape*vmax/vscale,'FaceColor','none','LineWidth',1,'Clipping','off');
		text(xsc+1.1*lsc,ysc,sprintf('%g 탍ad/day',vscale),'FontWeight','bold')

		hold off

		% adds plot amplitude vs distance
		if length(targetlatlon) > 1
			axes('Position',[.08,.03,.4,.1])
			plot(0,0)
			hold on
			sta_dist = greatcircle(targetlatlon(1),targetlatlon(2),geo(kn,1),geo(kn,2));
			sta_amp = sqrt(sum(tr(:,1:2).^2,2));
			sta_err = sqrt(sum(tre(:,1:2).^2,2));
			for nn = 1:length(kn)
				n = kn(nn);
				errorbar(sta_dist(nn),sta_amp(nn),sta_err(nn),'.','MarkerSize',15,'Color',scolor(n))
			end
			hold off
			set(gca,'FontSize',8)
			if any(~isnan(sta_amp))
				set(gca,'YLim',[0,max(sta_amp+sta_err)])
			end
			xlabel('Distance from target (km)')
			ylabel('Tilt amplitude (탍ad)')
		end

		rcode2 = sprintf('%s_%s',proc,summary);
		OPT.FIXEDPP = true;
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			E.t = max(cat(1,D(kn).tfirstlast),[],2);
			E.d = [geo(kn,:),tr(kn,:),tre(kn,1:2)];
			E.header = {'Latitude','Longitude','Altitude','E_tilt(탍ad/day)','N_Tilt(탍ad/day)','dEt(탍ad/day)','dNt(탍ad/day)'};
			E.title = sprintf('%s {%s}',stitre,upper(rcode2));
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end


	% --- Modelling
	summary = 'MODELLING';
	if isfield(P,'SUMMARYLIST') && any(strcmp(P.SUMMARYLIST,summary))
		if isfield(P,'MODELLING_EXCLUDED_NODELIST')
			kn = find(~ismemberlist({N.FID},split(P.MODELLING_EXCLUDED_NODELIST,',')));
		else
			kn = 1:length(N);
		end
		V.timescale = timescales(P.GTABLE(r).TIMESCALE);
		stitre = varsub(modelling_title,V,'tex');
		P.GTABLE(r).GTITLE = stitre;

		nn = length(kn);

		% makes the data array in 탍ad (from 탍ad/day)
		d = [tr(kn,:),tre(kn,:)]*diff(tlim);

		degm = 1e3*degkm;

		lat0 = mean(minmax(geo(kn,1)));
		lon0 = mean(minmax(geo(kn,2)));

		ysta = (geo(kn,1) - lat0)*degm;
		xsta = (geo(kn,2) - lon0)*degm*cosd(lat0);
		zsta = geo(kn,3);

		wid = max(diff(minmax(xsta)),diff(minmax(ysta))) + bm;

		% loads SRTM DEM for basemap
		DEM = loaddem(WO,[lon0 + wid/degm*cosd(lat0)*[-.6,.6],lat0 + wid/degm*[-.6,.6]]);

		% makes model space
		xlim = linspace(-wid/2,wid/2,rr);
		ylim = xlim;
		zlim = linspace(-maxdep,roundsd(double(max(DEM.z(:))),2,'ceil'),rr);

		vmax = max(sqrt(sum(d(:,1:3).^2,2)));
		vsc = .25*max(ylim(end)-ylim(1),minkm/degkm)/vmax;


		[xdem,ydem] = meshgrid(xlim,ylim);
		zdem = interp2((DEM.lon-lon0)*degm*cosd(lat0),(DEM.lat-lat0)*degm,double(DEM.z),xdem,ydem);
		maxz = max(zdem(:));

		[xx,yy,zz] = meshgrid(xlim,ylim,zlim);
		sz = size(xx);

		dx = repmat(reshape(d(:,1),1,1,1,nn),[sz,1]);
		dy = repmat(reshape(d(:,2),1,1,1,nn),[sz,1]);

		[asou,rsou] = cart2pol(repmat(reshape(xsta,1,1,1,nn),[sz,1])-repmat(xx,[1,1,1,nn]), ...
			repmat(reshape(ysta,1,1,1,nn),[sz,1])-repmat(yy,[1,1,1,nn]));

		[~,~,dt] = mogi(rsou,repmat(reshape(zsta,1,1,1,nn),[sz,1]) - repmat(zz,[1,1,1,nn]),1e6);
		[tx,ty] = pol2cart(asou,dt);

		% removes NaN data
		kk = find(~any(isnan(d(:,1:2)),2));
		kr = length(kk);

		% computes optimal volume variation
		[da,dr] = cart2pol(dx,dy);
		drm = dr.*cos(da - asou);	% data vector radial component
		vv = mean(drm(:,:,:,kk),4)./mean(dt(:,:,:,kk),4);
			
		% computes probability density
		vvn = repmat(vv,[1,1,1,kr]);
		sigx = repmat(reshape(2*d(kk,3),1,1,1,kr),[sz,1]);
		sigy = repmat(reshape(2*d(kk,4),1,1,1,kr),[sz,1]);
		if moduleonly
			% -- misfit from vector module only
			mm = exp(sum(-(dr(:,:,:,kk) - dt(:,:,:,kk).*vvn).^2./(2*(sigx + sigy).^2),4))./prod((sigx + sigy)*sqrt(2*pi),4);
		else
			% -- misfit from vectors difference module (two components)
			mm = exp(sum(-(dx(:,:,:,kk) - tx(:,:,:,kk).*vvn).^2./(2*sigx.^2),4))./prod(sigx*sqrt(2*pi),4) ...
				.*exp(sum(-(dy(:,:,:,kk) - ty(:,:,:,kk).*vvn).^2./(2*sigy.^2),4))./prod(sigy*sqrt(2*pi),4);
		end
		clear tx ty sigx sigy % free some memory

		% all solutions above the topography are very much unlikely...
		mm(zz>repmat(zdem,[1,1,sz(3)])) = 0;

		% recomputes the lowest misfit solution
		k = find(mm == max(mm(:)),1,'first');
		[asou,rsou] = cart2pol(xsta-xx(k),ysta-yy(k));
		zsou = zsta - zz(k);
		[~,~,dt] = mogi(rsou,zsou,1e6*vv(k));
		[tx,ty] = pol2cart(asou,dt);
		mm0 = sum((d(kk,1) - tx(kk)).^2.) + sum((d(kk,2) - ty(kk)).^2);
		mm0 = sqrt(mm0/length(kk));
		msigp = erf(msig/sqrt(2));

		% vertical uncertainty
		ez = minmax(zz(mm >= (1 - msigp)*max(mm(:))),[1-msigp,msigp]);

		% volume variation uncertainty
		ev = minmax(vv(mm >= (1 - msigp)*max(mm(:))),[1-msigp,msigp]);

		% source 3D median width for adjusting the color scale
		d0 = sqrt((xx-xx(k)).^2 + (yy-yy(k)).^2 + (zz-zz(k)).^2);	% distance from source
		%ws = median(d0(mm>minmax(mm(:),.99)));	% median distance of the 1% best models
		ws = 2*median(d0(mm >= (1 - msigp)*max(mm(:))));	% distance of the best models (msig)
		
		mhor = max(mm,[],3);
		clim = [min(mhor(:)),max(mhor(:))*(ws/1e6)^.5]
		%clim = [min(mhor(:)),max(mhor(:))];
		%clim = minmax(mm)
		if ~(diff(clim)>0)
			clim = [0,1];
		end

		stasize = 6;
		arrowshapemod = [.1,.1,.08,.02];
		arrowref = vsc*vmax/2;

		% plots the results
		figure, orient tall

		subplot(5,3,[1,2,4,5,7,8]);
		pos = get(gca,'Position');
		imagesc(xlim,ylim,squeeze(max(mm,[],3)));axis xy;caxis(clim)
		hold on
		[~,h] = contour(xlim,ylim,zdem,0:200:maxz);
		set(h,'Color',.3*[1,1,1],'LineWidth',.1);
		[~,h] = contour(xlim,ylim,zdem,0:1000:maxz);
		set(h,'Color',.3*[1,1,1],'LineWidth',.75);
		%pcolor(xlim,ylim,squeeze(max(vv,[],3)));shading flat
		target(xsta,ysta,stasize)
		if ~isnan(vmax)
			arrows(xsta,ysta,vsc*d(:,1),vsc*d(:,2),arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			ellipse(xsta + vsc*d(:,1),ysta + vsc*d(:,2),vsc*d(:,3),vsc*d(:,4),'LineWidth',.2,'Clipping','on')
			arrows(xsta,ysta,vsc*tx,vsc*ty,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor','r','FaceColor','r','Clipping','off')
		end
		%axis equal; axis tight
		if plotbest
			plot(xx(k),yy(k),'pk','MarkerSize',10,'LineWidth',2)
		end
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(ylim), ...
			'Position',[0.01,pos(2),pos(3) + pos(1) - 0.01,pos(4)],'XTick',[],'YTick',[])

		% Z-Y profile
		axes('position',[0.68,pos(2),0.3,pos(4)])
		imagesc(zlim,ylim,squeeze(max(mm,[],2)));axis xy;caxis(clim)
		%pcolor(zlim,ylim,squeeze(max(vv,[],2)));shading flat
		hold on
		target(zsta,ysta,stasize)
		if plotbest
			plot(zz(k),yy(k),'pk','MarkerSize',10,'LineWidth',2)
		end
		plot(max(max(zdem,[],3),[],2)',ylim,'-k')
		hold off
		set(gca,'XLim',minmax(zlim),'YLim',minmax(ylim),'XDir','reverse','XAxisLocation','top','YAxisLocation','right','YTick',[],'FontSize',6)

		% X-Z profile
		axes('position',[0.01,0.11,0.6142,0.3])
		imagesc(xlim,zlim,fliplr(rot90(squeeze(max(mm,[],1)),-1)));axis xy;caxis(clim)
		%pcolor(xlim,zlim,fliplr(rot90(squeeze(max(vv,[],1)),-1)));shading flat
		hold on
		target(xsta,zsta,stasize)
		if plotbest
			plot(xx(k),zz(k),'pk','MarkerSize',10,'LineWidth',2)
		end
		plot(xlim,max(max(zdem,[],3),[],1),'-k')
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(zlim),'YAxisLocation','right','XTick',[],'FontSize',6)
		shademap(jet(512),0.8)

		% legend
		subplot(5,3,[12,15])
		info = {'   {\itTime span}:', ...
			sprintf('{\\bf%s}',datestr(tlim(1),'yyyy-mm-dd HH:MM')), ...
			sprintf('{\\bf%s}',datestr(tlim(2),'yyyy-mm-dd HH:MM')), ...
			'', ...
			sprintf('   {\\itBest sources (%1.1f%%)}:',msigp*100), ...
			sprintf('depth = {\\bf%1.1f km} \\in [%1.1f , %1.1f]',-[zz(k),fliplr(ez)]/1e3), ...
			sprintf('\\DeltaV = {\\bf%+g Mm^3} \\in [%+g , %+g]',roundsd([vv(k),ev],2)), ...
			sprintf('lowest misfit = {\\bf%g 탍ad}',roundsd(mm0,2)), ...
			'', ... %sprintf('width = {\\bf%g m}',roundsd(2*ws,1)), ...
			sprintf('grid size = {\\bf%g^3 nodes}',rr), ...
			sprintf('trend error mode = {\\bf%d}',terrmod), ...
		};
		if moduleonly
			info = cat(2,info,'misfit mode = {\bfmodule only}');
		end
		text(0,1,info,'HorizontalAlignment','left','VerticalAlignment','top')
		axis([0,1,0,1]); axis off

		axes('position',[0.73,.18,.23,.01])
		imagesc(linspace(0,1,256),[0;1],repmat(linspace(0,1,256),2,1))
		set(gca,'XTick',[0,1],'YTick',[],'XTickLabel',{'Low','High'},'TickDir','out','FontSize',8)
		title('Probability density','FontSize',10)

		axes('position',[0.68,0.11,0.3,0.03])
		dxl = diff(xlim([1,end]))*0.3/0.6142;
		dyl = diff(ylim([1,end]))*0.03/0.3;
		hold on
		if ~isnan(arrowref)
			vlegend = roundsd(vmax/2,1);
			arrows(dxl/2,dyl,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			text(dxl/2 + vsc*vlegend/2,dyl,sprintf('{\\bf%g 탍ad}',vlegend),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8)
			%ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
			arrows(dxl/2,dyl/2,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor','r','FaceColor','r','Clipping','off')
			text([dxl/2,dxl/2],[dyl,dyl/2],{'data   ','model   '},'HorizontalAlignment','right')
		end
		axis off
		hold off
		set(gca,'XLim',[0,dxl],'YLim',[0,dyl])

		P.GTABLE(r).INFOS = {''};
		%rcode2 = sprintf('%s_%s',proc,summary);
		OPT.FIXEDPP = true;
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
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
