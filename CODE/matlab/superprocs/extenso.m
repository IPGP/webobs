function DOUT=extenso(varargin)
%EXTENSO WebObs SuperPROC: Updates graphs/exports of Extensometry results.
%
%   EXTENSO(PROC) makes default outputs of PROC.
%
%   EXTENSO(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%      TSCALE = '%' : all timescales defined by PROC.conf (default)
%       TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%       (keywords must be in TIMESCALELIST of PROC.conf)
%
%   EXTENSO(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%   D = EXTENSO(PROC,...) returns a structure D containing all the PROC data:
%       D(i).id = node ID
%       D(i).t = time vector (for node i)
%       D(i).d = matrix of processed data (NaN = invalid data)
%
%   This superproc is specificaly adapted to data from the FORM.EXTENSO genform.
%   But data from other source might be used if the channels contain:
%       d(:,1) = Distance measurement (in mm)
%       e(:,1) = Error on the distance (in mm)
%       d(:,2) = Air temperature (in °C)
%       d(:,3) = Wind velocity (arbitrary scale from 0 to 3)
%
%   See CODE/tplates/PROC.EXTENSO for specific paramaters of this superproc.
%
%
%   Authors: F. Beauducel + J.C. Komorowski / WEBOBS, IPGP
%   Created: 2001-10-23
%   Updated: 2026-02-03

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration and associated nodes for any TSCALE and/or REQDIR
[P,N,D] = readproc(WO,varargin{:});


border = .02;
fontsize = 7;

% data treatment parameters
maxerror = field2num(P,'FILTER_MAX_ERROR_MM',NaN);	% error in mm

terrmod = field2num(P,'TREND_ERROR_MODE',1);

% per node parameters
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','o-');

% SUMMARY parameters
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','o-');
nodes_colormap = field2str(P,'NODES_COLORMAP');
if exist(nodes_colormap,'file')
    cmap = eval(sprintf('%s(%d)',nodes_colormap,numel(N)));
else
    cmap = [];
end

% VECTORS parameters
velscale = field2num(P,'VECTORS_VELOCITY_SCALE',0);
minkm = field2num(P,'VECTORS_MIN_SIZE_KM',1);
maxxy = field2num(P,'VECTORS_MAX_XYRATIO',1.5);
arrowshape = field2num(P,'VECTORS_ARROWSHAPE',[.15,.1,.08,.04]);

% MODELLING parameters
horizonly = isok(P,'MODELLING_HORIZONTAL_ONLY');
maxdep = field2num(P,'MODELLING_MAX_DEPTH',8e3);	% depth limit (m)
bm = field2num(P,'MODELLING_BORDERS',5e3);	% modelling grid borders (m)
rr = field2num(P,'MODELLING_GRID_SIZE',51);
msig = field2num(P,'MODELLING_SIGMAS',1);
plotbest = isok(P,'MODELLING_PLOT_BEST');

geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84),cat(1,N.ALTITUDE)];
tlast = nan(length(N),1);
tfirst = nan(length(N),1);
tfirstall = P.NOW - 1;

for n = 1:length(N)

	stitre = sprintf('%s: %s',N(n).ALIAS,N(n).NAME);

	t = D(n).t;
	d = D(n).d;
	e = D(n).e;
	C = D(n).CLB;
	nx = length(C.nm);

	if ~isempty(t)
		tlast(n) = rmax(t);
		tfirst(n) = rmin(t);
		tfirstall = min(tfirstall,tfirst(n));
	else
		tlast(n) = P.NOW;
		tfirst = P.NOW - 1;
	end

	% filter the data
	if ~isnan(maxerror)
		d(e>maxerror,1) = NaN;
	end



	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure, clf, orient tall
		k = find((t >= P.GTABLE(r).DATE1 | isnan(P.GTABLE(r).DATE1)) & (t <= P.GTABLE(r).DATE2 | isnan(P.GTABLE(r).DATE2)));
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if isempty(k)
			k1 = [];
			ke = [];
			if any(isnan(tlim))
				tlim = P.NOW - [1,0];
			end
			acqui = 0;
		else
			ke = k(end);
			if any(isnan(tlim))
				tlim = [tfirst(n),tlast(n)];
				if diff(tlim)==0
					tlim(1) = tlim(1) - 1;
				end
			end
			acqui = round(100*length(k)*N(n).ACQ_RATE/abs(diff(tlim)));
		end

		if t(ke) >= tlim(2) - N(n).LAST_DELAY
			etat = 0;
			for i = 1:nx
				if ~isnan(d(ke,i))
					etat = etat + 1;
				end
			end
			etat = 100*etat/nx;
		else
			etat = 0;
		end

		% title and status
		OPT.GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		OPT.GSTATUS = [P.NOW,etat,acqui];
		N(n).STATUS = etat;
		N(n).ACQUIS = acqui;
		OPT.INFOS = {''};

		% relative extension with error bars (in mm)
		subplot(6,1,1:4), extaxes(gca,[.07,0])
		if ~isempty(k)
			tk = t(k);
            dk = d(k,1);
			k1 = k(find(~isnan(d(k,1)),1));
			plot(tk,dk,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH,'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',scolor(1),'MarkerFaceColor',scolor(1))
			set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis
			hold on
			plot(repmat(tk,[1,2])',(repmat(dk,[1,2])+e(k,1)*[-1,1])','-','LineWidth',.1,'Color',.6*[1,1,1])
			kk = find(~isnan(dk));
			lre = nan(1,2);
			if length(kk) > 2 && ~isempty(k1)
				lr = wls(tk(kk)-t(k1),dk(kk),1./e(k(kk),1).^2);
				lre = [lr(1),std(dk(kk) - polyval(lr,tk(kk)-t(k1)))/diff(tlim)]*365.25;
				plot(tlim,polyval(lr,tlim - t(k1)),'--k','LineWidth',.2)
			end
			hold off
		end
		set(gca,'XLim',tlim,'FontSize',fontsize)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('%s (%s)',C.nm{1},C.un{1}))
		if isempty(d) || all(isnan(d(k,1)))
			nodata(tlim)
		end

		% air temperature (°C)
		subplot(6,1,5), extaxes(gca,[.07,0])
		if ~isempty(k)
			tk = t(k);
			dk = d(k,2);
			plot(tk,dk,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH,'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',scolor(2),'MarkerFaceColor',scolor(2))
			set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis
		end
		set(gca,'XLim',tlim,'FontSize',fontsize)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('%s (%s)',C.nm{2},C.un{2}))
		if isempty(d)
			nodata(tlim)
		end

		% wind speed
		subplot(6,1,6), extaxes(gca,[.07,0])
		if ~isempty(k)
			tk = t(k);
			dk = d(k,3);
			plot(tk,dk,pernode_linestyle,'LineWidth',P.GTABLE(r).LINEWIDTH,'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',scolor(3),'MarkerFaceColor',scolor(3))
			set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis
		end
		set(gca,'XLim',tlim,'FontSize',fontsize)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(C.nm{3})
		if isempty(d)
			nodata(tlim)
		end

		tlabel(tlim,P.TZ,'FontSize',8)

		if ~isempty(k)
			OPT.INFOS = {sprintf('Last measurement: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.TZ),' (min|moy|max)',' ',' ', ...
				sprintf('1. %s = {\\bf%+1.3f %s} (%+1.3f | %+1.3f | %+1.3f) - Trend = {\\bf%+1.3f \\pm %1.3f mm/yr}', ...
					C.nm{1},d(ke,1),C.un{1},rmin(d(k,1)),rmean(d(k,1)),rmax(d(k,1)),lre), ...
			};
			for i = 2:3
				OPT.INFOS = [OPT.INFOS{:},{sprintf('%d. %s = {\\bf%+1.1f %s} (%+1.1f | %+1.1f | %+1.1f)', ...
					i, C.nm{i},d(ke,i),C.un{i},rmin(d(k,i)),rmean(d(k,i)),rmax(d(k,i)))}];
			end
		end

		% makes graph
        OPT.STATUS = P.GTABLE(r).STATUS;
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P,OPT)
		close

		% exports data
		if isok(P,'EXPORTS') && ~isempty(k)
			E.t = t(k);
			E.d = [d(k,1),e(k,1),d(k,2),d(k,3)];
			E.header = {'Extension(mm)','Ext_std(mm)','Temp(C)','Wind'};
			E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P,r,N(n));
		end
	end

	% Stores in main structure D to prepare the summary graph
	D(n).t = t;
	D(n).d = d;
	D(n).e = e;
end


% ====================================================================================================
% Summary graphs (all proc's nodes)

for r = 1:length(P.GTABLE)

	stitre = sprintf('%s',P.NAME);
	tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
	if any(isnan(tlim))
		tlim = [tfirstall,P.NOW];
	end
	OPT.GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
	if P.GTABLE(r).STATUS
		OPT.GSTATUS = [tlim(2),rmean(cat(1,N.STATUS)),rmean(cat(1,N.ACQUIS))];
	end
	OPT.INFOS = {''};
	tr = nan(length(N),1); % trends per station per component (mm/yr)
	tre = nan(length(N),1); % trends error (mm/yr)
	az = nan(length(N),1);
	vx = nan(length(N),1);
	vy = nan(length(N),1);

	% computes trends
	for n = 1:length(N)
		t = D(n).t;
		d = D(n).d;
		e = D(n).e;
		k = find(t>=tlim(1) & t<=tlim(2));
		if ~isempty(k)
			tk = t(k);
			dk = d(k,1);
			k1 = k(find(~isnan(d(k,1)),1));
            if ~isempty(k1)
                dk = dk - d(k1,1);
            end
			% computes yearly trends (in mm/yr)
			kk = find(~isnan(dk));
			if length(kk) > 2
				[b,stdx] = wls(tk(kk)-tk(1),dk(kk),1./e(k(kk),1));
				tr(n) = b(1)*365.25;
				az(n) = D(n).CLB.az(1);
				[vx(n),vy(n)] = pol2cart((90-az(n))*pi/180,tr(n));
				% different modes for error estimation
				switch terrmod
				case 2
					tre(n) = std(dk(kk) - polyval(b,tk(kk)-tk(1)))*365.25/diff(tlim);
				case 3
					cc = corrcoef(tk(kk)-tk(1),dk(kk));
					r2 = sqrt(abs(cc(2)));
					tre(n) = stdx(1)*365.25/r2;
					fprintf('%s: R = %g\n',N(n).ALIAS,r2);
				otherwise
					tre(n) = stdx(1)*365.25;
				end
				% all errors are adjusted with sampling completeness factor
				if N(n).ACQ_RATE > 0
					acq = length(kk)*N(n).ACQ_RATE/abs(diff(tlim));
					tre(n) = tre(n)/sqrt(acq);
				end
			end
		end
	end


	% --- Time series graph
	figure, clf, orient tall

    zones = length(find(~cellfun(@isempty,regexp(fieldnames(P),'ZONE._NAME'))));
	for i = 1:zones
        nlist = split(P.(sprintf('ZONE%d_NODELIST',i)),',');
		subplot(2*zones,1,(i-1)*(zones-1)+(1:2)), extaxes(gca,[.07,0])
		hold on
		aliases = [];
		ncolors = [];
		for n = 1:length(N)

			t = D(n).t;
			d = D(n).d;
			%e = D(n).e;
			C = D(n).CLB;

			k = find(t>=tlim(1) & t<=tlim(2));
			if any(strcmp(N(n).FID,nlist)) && ~isempty(k)
				tk = t(k);
                dk = d(k,1);
				k1 = k(find(~isnan(d(k,1)),1));
                if ~isempty(k1)
                    dk = dk - d(k1,1);
                end
				plot(tk,dk,summary_linestyle,'Color',scolor(n,cmap),'MarkerSize',P.GTABLE(r).MARKERSIZE,'MarkerFaceColor',scolor(n,cmap))
				aliases = cat(2,aliases,{N(n).ALIAS});
				ncolors = cat(2,ncolors,n);
			end
		end
		hold off
		set(gca,'XLim',tlim,'FontSize',fontsize)
		box on
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel({sprintf('{\\bf%s}',P.(sprintf('ZONE%d_NAME',i))),sprintf('%s (%s)',C.nm{1},C.un{1})})

		% legend: station aliases
		ylim = get(gca,'YLim');
		nl = length(aliases);
		for n = 1:nl
			text(tlim(1)+n*diff(tlim)/(nl+1),ylim(2),aliases(n),'Color',scolor(ncolors(n),cmap), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
		end
		set(gca,'YLim',ylim);
	end

	tlabel(tlim,P.TZ,'FontSize',8)

	mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P,OPT)
	close


	% --- Vectors map
	summary = 'VECTORS';
	if any(strcmp(P.SUMMARYLIST,summary))
		if isfield(P,'VECTORS_EXCLUDED_NODELIST')
			kn = find(~ismemberlist({N.FID},split(P.VECTORS_EXCLUDED_NODELIST,',')));
		else
			kn = 1:length(N);
		end
		figure, set(gcf,'PaperPosition',[0,0,get(gcf,'PaperSize')]);
        orient tall

		% latitude extent of network and xy ratio to respect azimuth angle
		ylim = minmax(geo(kn,1));
		xyr = cosd(mean(ylim));

		OPT.GTITLE = gtitle(P.NAME,P.GTABLE(r).TIMESCALE);

		% scale is adjusted to maximum horizontal vector or error amplitude (in mm/yr)
		if velscale > 0
			vmax = velscale;
		else
			vmax = rmax([abs(tr(kn));abs(tre(kn))/2]);
		end
		vscale = roundsd(vmax,1);
		vsc = .25*max(diff(ylim),minkm/degkm)/vmax;
        fprintf('---> Vmax = %g mm/yr, Vscale = %g\n',vscale,vsc);

		ha = plot(geo(kn,2),geo(kn,1),'k.'); extaxes(gca,[.04,.08])
		hold on
		% plots velocity vectors first
		for nn = 1:length(kn)
			n = kn(nn);
			if ~any(isnan([vsc,vmax])) && ~any(isnan([vx(n),vy(n)]))
				if tr(n) >= 0
					h1 = arrows(geo(n,2),geo(n,1),vsc*vx(n)/xyr,vsc*vy(n),arrowshape,'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n,cmap),'LineWidth',1);
					h2 = arrows(geo(n,2),geo(n,1),-vsc*vx(n)/xyr,-vsc*vy(n),arrowshape,'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n,cmap),'LineWidth',1);
				else
					h1 = arrows(geo(n,2)-vsc*vx(n)/xyr,geo(n,1)-vsc*vy(n),vsc*vx(n)/xyr,vsc*vy(n),arrowshape,'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n,cmap),'LineWidth',1);
					h2 = arrows(geo(n,2)+vsc*vx(n)/xyr,geo(n,1)+vsc*vy(n),-vsc*vx(n)/xyr,-vsc*vy(n),arrowshape,'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n,cmap),'LineWidth',1);
				end
				ha = cat(1,ha,h1,h2);
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

		dem(DEM.lon,DEM.lat,DEM.z,'latlon','watermark',2,'interp','legend')
		text(xlim(2),ylim(2)+.01*diff(ylim),DEM.COPYRIGHT,'HorizontalAlignment','right','VerticalAlignment','bottom','Interpreter','none','FontSize',6)

		% plots stations
		target(geo(kn,2),geo(kn,1),7);

		% puts arrows on top
		h = get(gca,'Children');
		ko = find(ismember(h,ha),1);
		if ~isempty(ko)
			set(gca,'Children',[ha;h(1:ko-1)])
		end

		% plots error ellipse and station name
		for nn = 1:length(kn)
			n = kn(nn);
			if ~isnan(any([vx(n),vy(n)]))
				if tr(n) >= 0
					h1 = ellipse(geo(n,2) + vsc*vx(n)/xyr,geo(n,1) + vsc*vy(n),vsc*tre(n)/xyr,vsc*tre(n), ...
						'EdgeColor',scolor(n,cmap),'LineWidth',.2,'Clipping','on');
					h2 = ellipse(geo(n,2) - vsc*vx(n)/xyr,geo(n,1) - vsc*vy(n),vsc*tre(n)/xyr,vsc*tre(n), ...
						'EdgeColor',scolor(n,cmap),'LineWidth',.2,'Clipping','on');
					ha = cat(1,ha,h1,h2);
				else
					h = ellipse(geo(n,2),geo(n,1),vsc*tre(n)/xyr,vsc*tre(n),'EdgeColor',scolor(n,cmap),'LineWidth',.2,'Clipping','on');
					ha = cat(1,ha,h);
				end
			end
			% text position depends on vector direction
			if vy(n) > 0
				stn = {'','',N(n).ALIAS};
			else
				stn = {N(n).ALIAS,'',''};
			end
			text(geo(n,2),geo(n,1),stn,'FontSize',7,'FontWeight','bold', ...
				'VerticalAlignment','Middle','HorizontalAlignment','Center')
		end

		% plots legend scale
		xsc = xlim(1);
		ysc = ylim(1) - .08*diff(ylim);
		lsc = vscale*vsc;
		arrows(xsc,ysc,lsc,90,arrowshape*vmax/vscale,'FaceColor','none','LineWidth',1,'Clipping','off');
		text(xsc+1.1*lsc,ysc,sprintf('%g mm/yr',vscale),'FontWeight','bold')


		hold off

		rcode2 = sprintf('%s_%s',proc,summary);
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P,OPT)
		close

		% exports data
		if isok(P,'EXPORTS')
			E.infos = { ...
				sprintf('Stations'' aliases: %s',strjoin(cat(1,{N(kn).ALIAS}),',')), ...
				};
			E.t = tlast(kn);
			E.d = [geo(kn,:),tr(kn),tre(kn),az(kn)];
			E.header = {'Latitude','Longitude','Altitude','E_velocity(mm/yr)','dEv(mm/yr)','Azimuth(N)'};
			E.title = sprintf('%s {%s}',stitre,upper(rcode2));
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P,r);
		end
	end


	% --- Modelling
	summary = 'MODELLING';
	if any(strcmp(P.SUMMARYLIST,summary))
		if isfield(P,'MODELLING_EXCLUDED_NODELIST')
			kn = find(~ismemberlist({N.FID},split(P.MODELLING_EXCLUDED_NODELIST,',')));
		else
			kn = 1:length(N);
		end
		OPT.GTITLE = gtitle(sprintf('%s - Source modelling',P.NAME),P.GTABLE(r).TIMESCALE);

		nn = length(kn);

		% computes a mean velocity vector
		mvv = rsum(tr(kn,:)./tre(kn,:))./rsum(1./tre(kn,:));

		% makes the relative data array in mm (from mm/yr)
		d = [tr(kn,:) - repmat(mvv,nn,1),tre(kn,:)]*diff(tlim)/365.25;

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

		vmax = max(abs(d(:,1)));
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

		[ur,uz] = mogi(rsou,repmat(reshape(zsta,1,1,1,nn),[sz,1]) - repmat(zz,[1,1,1,nn]),1e9);
		[ux,uy] = pol2cart(asou,ur);

		% makes vectors relative (as computed for data)
		ux = ux - repmat(mean(ux,4),[1,1,1,nn]);
		uy = uy - repmat(mean(uy,4),[1,1,1,nn]);
		uz = uz - repmat(mean(uz,4),[1,1,1,nn]);

		% removes NaN data
		kk = find(~any(isnan(d(:,1:3)),2));
		kr = length(kk);

		% computes optimal volume variation
		[da,dr] = cart2pol(dx,dy);
		drm = dr.*cos(da - asou);	% data vector radial component
		vv = mean(drm(:,:,:,kk),4)./mean(sqrt(ux(:,:,:,kk).^2 + uy(:,:,:,kk).^2),4);

		% computes probability density
		vvn = repmat(vv,[1,1,1,kr]);
		sigx = repmat(reshape(d(kk,4),1,1,1,kr),[sz,1]);
		sigy = repmat(reshape(d(kk,5),1,1,1,kr),[sz,1]);
		%mm = prod(exp(-(dx(:,:,:,kk) - ux(:,:,:,kk).*vvn).^2./(2*sigx.^2))./(sigx*sqrt(2*pi)),4) ...
		%	.*prod(exp(-(dy(:,:,:,kk) - uy(:,:,:,kk).*vvn).^2./(2*sigy.^2))./(sigy*sqrt(2*pi)),4);
		mm = exp(sum(-(dx(:,:,:,kk) - ux(:,:,:,kk).*vvn).^2./(2*sigx.^2),4))./prod(sigx*sqrt(2*pi),4) ...
			.*exp(sum(-(dy(:,:,:,kk) - uy(:,:,:,kk).*vvn).^2./(2*sigy.^2),4))./prod(sigy*sqrt(2*pi),4);
		if ~horizonly
			dz = repmat(reshape(d(:,3),1,1,1,nn),[sz,1]);
			sigz = repmat(reshape(d(kk,6),1,1,1,kr),[sz,1]);
			mm = mm.*prod(exp(-(dz(:,:,:,kk) - uz(:,:,:,kk).*vvn).^2./(2*sigz.^2))./(sigz*sqrt(2*pi)),4);
		end
		clear ux uy uz sigx sigy sigz % free some memory

		% all solutions above the topography are very much unlikely...
		mm(zz>repmat(zdem,[1,1,sz(3)])) = 0;

		% recomputes the lowest misfit solution
		k = find(mm == max(mm(:)),1,'first');
		[asou,rsou] = cart2pol(xsta-xx(k),ysta-yy(k));
		zsou = zsta - zz(k);
		[ur,uz] = mogi(rsou,zsou,1e9*vv(k));
		[ux,uy] = pol2cart(asou,ur);
		mm0 = sum((d(kk,1) - ux(kk)).^2./d(kk,4).^2) + sum((d(kk,2) - uy(kk)).^2./d(kk,5).^2);
		if horizonly
			mm0 = mm0 + sum((d(kk,3) - ux(kk)).^2./d(kk,6).^2);
		end
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
		clim = [min(mhor(:)),max(mhor(:))*(ws/500)^.5];
		%clim = [min(mhor(:)),max(mhor(:))];
		%clim = minmax(mm);
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
			ellipse(xsta + vsc*d(:,1),ysta + vsc*d(:,2),vsc*d(:,4),vsc*d(:,5),'LineWidth',.2,'Clipping','on')
			arrows(xsta,ysta,vsc*ux,vsc*uy,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor','r','FaceColor','r','Clipping','off')
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
		if ~isnan(vmax)
			arrows(zsta,ysta,vsc*d(:,3),vsc*d(:,2),arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			ellipse(zsta + vsc*d(:,3),ysta + vsc*d(:,2),vsc*d(:,6),vsc*d(:,5),'LineWidth',.2,'Clipping','on')
			arrows(zsta,ysta,vsc*uz,vsc*uy,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor','r','FaceColor','r','Clipping','off')
		end
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
		if ~isnan(vmax)
			arrows(xsta,zsta,vsc*d(:,1),vsc*d(:,3),arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
			arrows(xsta,zsta,vsc*ux,vsc*uz,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor','r','FaceColor','r','Clipping','off')
		end
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
			sprintf('lowest misfit = {\\bf%g mm}',roundsd(mm0,2)), ...
			'', ... %sprintf('width = {\\bf%g m}',roundsd(2*ws,1)), ...
			sprintf('grid size = {\\bf%g^3 nodes}',rr), ...
			sprintf('trend error mode = {\\bf%d}',terrmod), ...
		};
		if horizonly
			info = cat(2,info,'misfit mode = {\bfhorizontal only}');
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
		vlegend = roundsd(vmax/2,1);
		arrows(dxl/2,dyl,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
		text(dxl/2 + vsc*vlegend/2,dyl,sprintf('{\\bf%g mm}',vlegend),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8)
		%ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
		arrows(dxl/2,dyl/2,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor','r','FaceColor','r','Clipping','off')
		text([dxl/2,dxl/2],[dyl,dyl/2],{'data   ','model   '},'HorizontalAlignment','right')
		axis off
		hold off
		set(gca,'XLim',[0,dxl],'YLim',[0,dyl])

		OPT.INFOS = {''};
		%rcode2 = sprintf('%s_%s',proc,summary);
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P,OPT)
		close

		%keyboard
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
