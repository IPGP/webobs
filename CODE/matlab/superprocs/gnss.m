function DOUT=gnss(varargin)
%GNSS	WebObs SuperPROC: Updates graphs/exports of GNSS/GLOBK results.
%
%       GNSS(PROC) makes default outputs of PROC.
%
%       GNSS(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	GNSS(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = GNSS(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       GNSS will use PROC's and NODE's parameters to import data. Particularily, it can
%       use NODE's calibration file if exists; in that case channels must be as follows:
%           Channel 1 = Eastern UTM (m)
%           Channel 2 = Northern UTM (m)
%           Channel 3 = Elevation (m)
%           Channel 4 = Orbit (-)
%
%       GNSS will use PROC's parameters from .conf file. Specific paramaters are:
%           FILTER_MAX_ERROR_M|1
%           PICKS_CLEAN_PERCENT|0
%	    TREND_ERROR_MODE|1
%	    TREND_MIN_DAYS|2
%	    VELOCITY_REF|0,0,0
%	    VELOCITY_REF_ORIGIN_DATE|2000-01-01
%	    GNSS_TARGET_LATLON|
%	    PERNODE_TITLE|{\fontsize{14}{\bf$node_alias: $node_name - ${ITRF_REF}} ($timescale)}
%	    PERNODE_LINESTYLE|o
%	    SUMMARY_LINESTYLE|o
%	    SUMMARY_TITLE|{\fontsize{14}{\bf${NAME} - ${ITRF_REF}} ($timescale)}
%	    BASELINES_NODEPAIRS|
%	    BASELINES_EXCLUDED_NODELIST|
%	    BASELINES_REF_NODELIST|
%	    BASELINES_PAGE_STA_NUM|10
%	    BASELINES_TITLE|{\fontsize{14}{\bf${NAME} - Baselines} ($timescale)}
%	    BASELINES_UNIT|m
%	    BASELINES_YLABEL|$ref_node_alias (${BASELINES_UNIT})
%	    BASELINES_LINESTYLE|o-
%	    VECTORS_EXCLUDED_NODELIST|
%	    VECTORS_RELATIVE|Y
%	    VECTORS_RELATIVE_HORIZONTAL_ONLY|Y
%	    VECTORS_VELOCITY_REF|
%	    VECTORS_VELOCITY_SCALE|
%	    VECTORS_MIN_SIZE_KM|10
%	    VECTORS_MAX_XYRATIO|1.5
%	    VECTORS_ARROWSHAPE|.1,.1,.08,.02
%	    VECTORS_TITLE|{\fontsize{14}{\bf$name - Vectors} ($timescale)}
%	    MODELLING_EXCLUDED_NODELIST|
%	    MODELLING_HORIZONTAL_ONLY|N
%	    MODELLING_FORCE_RELATIVE|N
%	    MODELLING_MAX_DEPTH|8000
%	    MODELLING_BORDERS|5000
%	    MODELLING_GRID_SIZE|100
%	    MODELLING_SIGMAS|1
%	    MODELLING_COLORREF|volpdf
%	    MODELLING_COLORMAP|jet(512)
%	    MODELLING_COLOR_SHADING|0.8
%	    MODELLING_APRIORI_HSTD_KM|10
%	    MODELLING_SOURCE_TYPE|isotropic
%	    MODELLING_APRIORI_HSTD_KM|0
%	    MODELLING_MINERROR_MM|5
%	    MODELLING_PCDM_ITERATIONS|5
%	    MODELLING_PCDM_RANDOM_SAMPLING|200000
%	    MODELLING_PCDM_NU|0.25
%	    MODELLING_PCDM_ALIM|0,1
%	    MODELLING_PCDM_BLIM|0,1
%	    MODELLING_PCDM_OXLIM|-45,45
%	    MODELLING_PCDM_OYLIM|-45,45
%	    MODELLING_PCDM_OZLIM|-45,45
%	    MODELLING_PCDM_HEATMAP_GRID|50
%	    MODELLING_PCDM_HEATMAP_SATURATION|0.4
%	    MODELLING_PCDM_HEATMAP_SMOOTH_SPAN|5
%	    MODELLING_PCDM_HEATMAP_SMOOTH_DEGREE|1
%	    MODELLING_PCDM_NEW_THRESHOLD|2
%	    MODELLING_PCDM_NEW_LIMIT_EDGE_RATIO|20
%	    MODELLING_PCDM_NEW_LIMIT_EXTEND|1
%	    MODELLING_PCDM_SUPPLEMENTARY_GRAPHS|N
%	    MODELLING_PLOT_BEST|N
%	    MODELLING_PLOT_RESIDUAL|Y
%	    MODELLING_TITLE|{\fontsize{14}{\bf$name - Source modelling} ($timescale)}
%	    MODELTIME_PERIOD_DAY|30,0
%	    MODELTIME_SAMPLING_DAY|2
%	    MODELTIME_MAX_MODELS|100
%	    MODELTIME_TITLE|{\fontsize{14}{\bf$name - Source best model timeline} ($timescale)}
%
%	List of internal variables that will be substituted in text strings:
%	    $node_name      = node long name
%	    $node_alias     = node alias
%	    $timescale      = time scale string (e.g. '1 year')
%	    $last_data      = last data date and time string
%	    $ref_node_alias = reference node alias
%
%
%   Authors: François Beauducel, Aline Peltier, Patrice Boissier, Antoine Villié, Jean-Marie Saurel / WEBOBS, IPGP
%   Created: 2010-06-12 in Paris (France)
%   Updated: 2019-01-30

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
modarrcol = [1,0,0]; % color of model arrows
resarrcol = [0,.8,0]; % color of residual arrows

% PROC's parameters
fontsize = field2num(P,'FONTSIZE',7);
maxerror = field2num(P,'FILTER_MAX_ERROR_M',NaN);
picksclean = field2num(P,'PICKS_CLEAN_PERCENT',1);
terrmod = field2num(P,'TREND_ERROR_MODE',1);
trendmindays = field2num(P,'TREND_MIN_DAYS',1);
plotbest = isok(P,'MODELLING_PLOT_BEST');
plotresidual = isok(P,'MODELLING_PLOT_RESIDUAL',1);
targetll = field2num(P,'GNSS_TARGET_LATLON');
velref = field2num(P,'VELOCITY_REF',[0,0,0]);
velrefdate = field2num(P,'VELOCITY_REF_ORIGIN_DATE','2000-01-01');
itrf = field2str(P,'ITRF_REF','ITRF');
if numel(velref)==3 && ~all(velref==0)
	itrf = 'local ref.';
end


% PERNODE graphs parameters 
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','o');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name - $itrf} ($timescale)}');

% SUMMARY parameters 
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','o');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name - $itrf} ($timescale)}');

% VECTORS parameters
vrelmode = isok(P,'VECTORS_RELATIVE');
if vrelmode
	vref = '';
	if isfield(P,'VECTORS_VELOCITY_REF')
		vref = P.VECTORS_VELOCITY_REF;
	end
end
vrelhorizonly = isok(P,'VECTORS_RELATIVE_HORIZONTAL_ONLY',1);
velscale = field2num(P,'VECTORS_VELOCITY_SCALE',0);
minkm = field2num(P,'VECTORS_MIN_SIZE_KM',10);
maxxy = field2num(P,'VECTORS_MAX_XYRATIO',1.5);
arrowshape = field2num(P,'VECTORS_ARROWSHAPE',[.1,.1,.08,.02]);
vectors_title = field2str(P,'VECTORS_TITLE','{\fontsize{14}{\bf$name - Vectors} ($timescale)}');

% BASELINES parameters
pagestanum = field2num(P,'BASELINES_PAGE_STA_NUM',10);
baselines_linestyle = field2str(P,'BASELINES_LINESTYLE','o-');
baselines_title = field2str(P,'BASELINES_TITLE','{\fontsize{14}{\bf$name - Baselines} ($timescale)}');
baselines_ylabel = field2str(P,'BASELINES_YLABEL','$ref_node_alias ($baselines_unit)');
baselines_unit = field2str(P,'BASELINES_UNIT','m');

% MODELLING parameters
modelling_force_relative = isok(P,'MODELLING_FORCE_RELATIVE');
modrelauto = strcmpi(field2str(P,'MODELLING_FORCE_RELATIVE'),'auto');
maxdep = field2num(P,'MODELLING_MAX_DEPTH',8e3);
bm = field2num(P,'MODELLING_BORDERS',5000);
rr = field2num(P,'MODELLING_GRID_SIZE',51);
modelling_cmap = field2num(P,'MODELLING_COLORMAP',jet(512));
modelling_colorshading = field2num(P,'MODELLING_COLOR_SHADING',0.8);
% color reference for model space: 'pdf' or 'volpdf' (source volume sign x pdf, new default)
modelling_coloref = lower(field2str(P,'MODELLING_COLORREF','volpdf'));
modelling_title = field2str(P,'MODELLING_TITLE','{\fontsize{14}{\bf$name - Source modelling} ($timescale)}');

modelling_source_type = field2str(P,'MODELLING_SOURCE_TYPE','isotropic');
% a priori horizontal error around the target (in STD, km), 0 or NaN = no a priori
modelopt.horizonly = isok(P,'MODELLING_HORIZONTAL_ONLY');
modelopt.apriori_horizontal = field2num(P,'MODELLING_APRIORI_HSTD_KM');
modelopt.msig = field2num(P,'MODELLING_SIGMAS',1);
modelopt.minerror = field2num(P,'MODELLING_MINERROR_MM',5);

% MODELLING pCDM parameters (see invpcdm.m)
% number of iterations (adjusting the parameter's limits)
pcdm.iterations = field2num(P,'MODELLING_PCDM_ITERATIONS',5);
% number of random samples: scalar or list for each iteration
pcdm.random_sampling = field2num(P,'MODELLING_PCDM_RANDOM_SAMPLING',200000);
% elastic parameter (Poisson's ratio) nu
pcdm.nu = field2num(P,'MODELLING_PCDM_NU',0.25);
% A parameter limits: horizontal over total volume variation ratio
% A = dVZ/(dVX+dVY+dVZ)
% 	0 = vertical (dyke or pipe following B value)
% 	1 = horizontal (sill)
% 	1/3 = isotrop if B = 0.5
pcdm.alim = field2num(P,'MODELLING_PCDM_ALIM',[0,1]);
% B parameter limits: vertical volume variation ratio
% B = dVY/(dVX+dVY)
% 	0 = dyke if A = 0, dyke+sill otherwise
% 	1 = dyke if A = 0, dyke+sill otherwise
% 	0.5 = isotrop if A = 1/3, pipe if A = 0
pcdm.blim = field2num(P,'MODELLING_PCDM_BLIM',[0,1]);
% OmegaX parameter limits: rotation angle around X axis (West-East)
pcdm.oxlim = field2num(P,'MODELLING_PCDM_OXLIM',[-45,45]);
% OmegaY parameter limits: rotation angle around Y axis (South-North)
pcdm.oylim = field2num(P,'MODELLING_PCDM_OYLIM',[-45,45]);
% OmegaZ parameter limits: rotation angle around Z axis (Bottom-Up)
pcdm.ozlim = field2num(P,'MODELLING_PCDM_OZLIM',[-45,45]);
% number of bins for probability vs parameter map (heatmap)
pcdm.heatmap_grid = field2num(P,'MODELLING_PCDM_HEATMAP_GRID',50);
% graphical parameter for heatmaps
pcdm.heatmap_saturation = field2num(P,'MODELLING_PCDM_HEATMAP_SATURATION',0.4);
% number of bins used to smooth the maximum probability curve
pcdm.heatmap_smooth_span = field2num(P,'MODELLING_PCDM_HEATMAP_SMOOTH_SPAN',5);
% polynomial degree to smooth the maximum probability curve
pcdm.heatmap_smooth_degree = field2num(P,'MODELLING_PCDM_HEATMAP_SMOOTH_DEGREE',1);
% minimum number of models to compute maximum probability curve
pcdm.newlimit_threshold = field2num(P,'MODELLING_PCDM_NEW_THRESHOLD',2);
% tolerance ratio to extend the edge limits
pcdm.newlimit_edge_ratio = field2num(P,'MODELLING_PCDM_NEW_LIMIT_EDGE_RATIO',20);
% factor of extension (from the previous interval) when reaching an edge
pcdm.newlimit_extend = field2num(P,'MODELLING_PCDM_NEW_LIMIT_EXTEND',1);
% option to export supplementary graphs (intermediate results per iteration)
pcdm.supplementary_graphs = isok(P,'MODELLING_PCDM_SUPPLEMENTARY_GRAPHS');


% MODELTIME parameters
modeltime_period = field2num(P,'MODELTIME_PERIOD_DAY');
modeltime_sampling = field2num(P,'MODELTIME_SAMPLING_DAY');
modeltime_max = field2num(P,'MODELTIME_MAX_MODELS',100);
modeltime_title = field2str(P,'MODELTIME_TITLE','{\fontsize{14}{\bf$name - Source best model timeline} ($timescale)}');


geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84),cat(1,N.ALTITUDE)];

V.name = P.NAME;
V.itrf = itrf;
V.baselines_unit = field2str(P,'BASELINES_UNIT','m');

% ====================================================================================================
% Makes the proc's job

% if a local reference is defined (VELOCITY_REF), computes relative positions in D.d
% from the install date of the station.

if numel(velref)==3 && ~all(velref==0)
	for n = 1:length(N)
		t0 = velrefdate;
		for c = 1:3
			D(n).d(:,c) = D(n).d(:,c) - polyval([velref(c)/365250,0],D(n).t - t0);
		end
	end
end


for r = 1:length(P.GTABLE)

	% initializes trends table
	tr = nan(length(N),3); % trends per station per component (mm/yr)
	tre = nan(length(N),3); % trends error (mm/yr)

	V.timescale = timescales(P.GTABLE(r).TIMESCALE);
	tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
	if any(isnan(tlim))
		tlim = minmax(cat(1,D.tfirstlast));
	end

	% --- Summary plot: time series
	figure, clf, orient tall

	for i = 1:3
		subplot(6,1,(i-1)*2+(1:2)), extaxes(gca,[.08,.04])
		hold on
		aliases = [];
		ncolors = [];
		for n = 1:length(N)
			
			V.node_name = N(n).NAME;
			V.node_alias = N(n).ALIAS;
			k = D(n).G(r).k;
		
			% filter the data
			if ~isnan(maxerror)
				D(n).d(D(n).e>maxerror,:) = NaN;
			end

			if ~isempty(k) && ~all(isnan(D(n).d(k,i)))
				k1 = k(find(~isnan(D(n).d(k,i)),1));
				dk = cleanpicks(D(n).d(k,i) - D(n).d(k1,i),picksclean);
				tk = D(n).t(k);
				plotorbit(tk,dk,D(n).d(k,4),summary_linestyle,P.GTABLE(r).LINEWIDTH,P.GTABLE(r).MARKERSIZE,scolor(n));

				% computes yearly trends (in mm/yr)
				kk = find(~isnan(dk));
				if length(kk) >= 2 && diff(minmax(D(n).t(kk))) >= trendmindays
					[b,stdx] = wls(tk(kk)-tk(1),dk(kk),1./D(n).e(k(kk),i));
					tr(n,i) = b(1)*365.25*1e3;
					% different modes for error estimation
					switch terrmod
					case 2
						tre(n,i) = std(dk(kk) - polyval(b,tk(kk)-tk(1)))*365.25*1e3/diff(tlim);
					case 3
						cc = corrcoef(tk(kk)-tk(1),dk(kk));
						r2 = sqrt(abs(cc(2)));
						tre(n,i) = stdx(1)*365.25*1e3/r2;
						fprintf('%s: R = %g\n',N(n).ALIAS,r2);
					otherwise
						tre(n,i) = stdx(1)*365.25*1e3;
					end
					% all errors are adjusted with sampling completeness factor
					if N(n).ACQ_RATE > 0
						acq = length(kk)*N(n).ACQ_RATE/abs(diff(tlim));
						tre(n,i) = tre(n,i)/sqrt(acq);
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
		ylabel(sprintf('Relative %s (%s)',D(n).CLB.nm{i},D(n).CLB.un{i}))
		if isok(P,'PLOT_GRID')
			grid on
		end
		
		% legend: station aliases
		ylim = get(gca,'YLim');
		nl = length(aliases);
		for n = 1:nl
			text(tlim(1)+n*diff(tlim)/(nl+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
		end
		set(gca,'YLim',ylim);
	end

	tlabel(tlim,P.GTABLE(r).TZ,'FontSize',fontsize)
    
	P.GTABLE(r).GTITLE = varsub(summary_title,V);
	P.GTABLE(r).INFOS = {sprintf('Referential: {\\bf%s}',itrf),sprintf('  E {\\bf%+g} mm/yr\n  N {\\bf%+g} mm/yr\n  U {\\bf%+g} mm/yr',velref)};
	mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
	close


	% --- computes vector reference (relative mode) + common part for VECTORS and MODELLING
	if isfield(P,'VECTORS_EXCLUDED_NODELIST')
		knv = find(~ismemberlist({N.FID},split(P.VECTORS_EXCLUDED_NODELIST,',')));
	else
		knv = 1:length(N);
	end

	% latitude extent of network and xy ratio
	latlim = minmax(geo(knv,1));
	xyr = cosd(mean(latlim));

	% computes a mean velocity vector (for valid nodes only)
	if length(knv) > 1
		mvv = rsum(tr(knv,:)./tre(knv,:))./rsum(1./tre(knv,:));
	else
		mvv = tr;
	end
	if vrelmode
		if numel(sstr2num(vref)) == 3
			voffset = sstr2num(vref);
			mode = 'fixed';
		else
			[kvref,knref] = ismember(split(vref,','),{N.FID});
			if all(kvref);
				mode = vref;
				if length(knref) > 1
					voffset = rsum(tr(knref,:)./tre(knref,:))./rsum(1./tre(knref,:));
				else
					voffset = tr(knref,:);
				end
				if any(isnan(voffset))
					voffset = [0,0,0];
					mode = sprintf('invalid reference "%s"',vref);
				end
			else
				% auto relative mode: horizontal only (or not)
				mode = 'auto';
				voffset = [mvv(1:2),(~vrelhorizonly)*mvv(3)];
			end
		end
		tr = tr - repmat(voffset,length(N),1);
		fprintf('---> Relative mode "%s" - velocity reference = %1.2f, %1.2f, %1.2f mm/yr\n',mode,voffset);
	end

	% --- per node plots
	for n = 1:length(N)

		V.node_name = N(n).NAME;
		V.node_alias = N(n).ALIAS;
		V.last_data = datestr(D(n).tfirstlast(2));
		nx = length(D(n).CLB.nm);


		figure, clf, orient tall

		% renames main variables for better lisibility...
		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;
    
		% title and status
		P.GTABLE(r).GTITLE = varsub(pernode_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};

		% loop for Relative Eastern, Northern, and Up components with error bars (in m)
		lre = nan(nx,2);
		for i = 1:3
			subplot(6,1,(i-1)*2+(1:2)), extaxes(gca,[.08,.04])
			if ~isempty(k) && any(~isnan(D(n).d(k,i)))
				tk = D(n).t(k);
				k1 = k(find(~isnan(D(n).d(k,i)),1));
				dk = cleanpicks(D(n).d(k,i)-D(n).d(k1,i),picksclean);
				plotorbit(tk,[dk,D(n).e(k,i)],D(n).d(k,4),pernode_linestyle,P.GTABLE(r).LINEWIDTH,P.GTABLE(r).MARKERSIZE,scolor(1));
				hold on
				if vrelmode
					dk = dk - polyval([voffset(i)/365250,0],tk - tlim(1));
					plotorbit(tk,[dk,D(n).e(k,i)],D(n).d(k,4),pernode_linestyle,P.GTABLE(r).LINEWIDTH,P.GTABLE(r).MARKERSIZE,scolor(3));
				end

				kk = find(~isnan(dk));
				if length(kk) >= 2 && diff(minmax(D(n).t(kk))) >= trendmindays
					lr = wls(tk(kk)-tlim(1),dk(kk),1./D(n).e(k(kk),i).^2);
					%lre(i,:) = [lr(1),stdx(1)]*365.25*1e3;
					lre(i,:) = [lr(1),std(dk(kk) - polyval(lr,tk(kk)-tlim(1)))/diff(tlim)]*365.25*1e3;
					plot(tlim,polyval(lr,tlim - tlim(1)),'--k','LineWidth',.2)
				end
				hold off
			end
			set(gca,'XLim',tlim,'FontSize',fontsize)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('Relative %s (%s)',D(n).CLB.nm{i},D(n).CLB.un{i}))
			if isempty(D(n).d) || all(isnan(D(n).d(k,i)))
				nodata(tlim)
			end

			% legend for vrelmode
			if i==1 && vrelmode
				ly = get(gca,'YLim');
				text(tlim(1) + diff(tlim)/3,ly(2),'original','Color',scolor(1), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'FontWeight','bold')
				text(tlim(1) + diff(tlim)*2/3,ly(2),sprintf('relative (%s)',mode),'Color',scolor(3), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'FontWeight','bold')
			end

			if isok(P,'PLOT_GRID')
				grid on
			end
		end

		tlabel(tlim,P.GTABLE(r).TZ,'FontSize',fontsize)

		if ~isempty(k)
			P.GTABLE(r).INFOS = {sprintf('Last measurement: {\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.GTABLE(r).TZ),' (min|moy|max)',' ',' '};
			for i = 1:3
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+1.3f %s} (%+1.3f | %+1.3f | %+1.3f) - Trend = {\\bf%+1.3f \\pm %1.3f mm/yr}', ...
					i, D(n).CLB.nm{i},D(n).d(ke,i)-D(n).d(k(1),i),D(n).CLB.un{i},rmin(D(n).d(k,i)-D(n).d(k(1),i)),rmean(D(n).d(k,i)-D(n).d(k(1),i)),rmax(D(n).d(k,i)-D(n).d(k(1),i)),lre(i,:))}];
			end
		end
		
		% makes graph
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
			E.t = D(n).t(k);
			E.d = [D(n).d(k,1:3),D(n).e(k,:),D(n).d(k,4)];
			E.header = {'Eastern(m)','Northern(m)','Up(m)','dE','dN','dU','Orbit'};
			if vrelmode
				E.d = [E.d, ...
					D(n).d(k,1) - polyval([voffset(1)/365250,0],E.t - tlim(1)), ...
					D(n).d(k,2) - polyval([voffset(2)/365250,0],E.t - tlim(1)), ...
					D(n).d(k,3) - polyval([voffset(3)/365250,0],E.t - tlim(1)), ...
				];
				E.header = {E.header{:},'East_rel(m)','North_rel(m)','Up_rel(m)'};
			end
			E.title = sprintf('%s {%s}',P.GTABLE(r).GTITLE,upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
	



	if P.GTABLE(r).STATUS
		P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
	end
	P.GTABLE(r).INFOS = {''};


	% --- Baselines time series
	summary = 'BASELINES';
	if isfield(P,'SUMMARYLIST') && any(strcmp(P.SUMMARYLIST,summary))
		if isfield(P,'BASELINES_NODEPAIRS') && ~isempty(P.BASELINES_NODEPAIRS)
			pairgraphs = split(P.BASELINES_NODEPAIRS,';');
			for nn = 1:length(pairgraphs)
				pairs = split(pairgraphs{nn},',');
				if length(pairs)>1
					B(nn).kr = find(ismemberlist({N.FID},pairs(1)));
					B(nn).kn = find(ismemberlist({N.FID},pairs(2:end)));
				else
					fprintf('%s: ** WARNING ** invalid node pairs for %s!\n',wofun,pairgraphs{nn});
				end
			end
		end
		if ~exist('B','var')
			if isfield(P,'BASELINES_EXCLUDED_NODELIST')
				kn = find(~ismemberlist({N.FID},split(P.BASELINES_EXCLUDED_NODELIST,',')));
			else
				kn = 1:length(N);
			end
			if isfield(P,'BASELINES_REF_NODELIST') && ~isempty(P.BASELINES_REF_NODELIST)
				kr = kn(ismemberlist({N(kn).FID},split(P.BASELINES_REF_NODELIST,',')));
			else
				kr = 1:length(N);
			end
			for nn = 1:length(kr)
				B(nn).kr = kr(nn);
				B(nn).kn = kn;
			end
		end

		figure
		if length(B) > pagestanum
			p = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[p(1),p(2)*length(kr)/pagestanum])
		end
		orient tall
		P.GTABLE(r).GTITLE = varsub(baselines_title,V);

		for nn = 1:length(B)
			n = B(nn).kr;
			subplot(length(B)*2,1,(nn-1)*2+(1:2)), extaxes(gca,[.08,.04])
			hold on
			aliases = [];
			ncolors = [];
			k = D(n).G(r).k;
			tk = D(n).t(k);
			V.ref_node_alias = N(n).ALIAS;
			E.t = tk;
			E.d = zeros(size(tk,1),0);
			E.header = [];
			for nn2 = 1:length(B(nn).kn)
				n2 = B(nn).kn(nn2);
				k2 = D(n2).G(r).k;
				V.node_name = N(n2).NAME;
				V.node_alias = N(n2).ALIAS;
				[~,kk] = unique(D(n2).t(k2));	% mandatory for interp1
				k2 = k2(kk);
				if n2 ~= n && ~isempty(k) && length(k2)>1
					dk = cleanpicks(sqrt(sum((interp1(D(n2).t(k2),D(n2).d(k2,1:2),tk,'nearest') - D(n).d(k,1:2)).^2,2)),picksclean);
					dk = dk/siprefix(baselines_unit,'m');
					dk0 = rmean(dk);
					plotorbit(tk,dk - dk0,D(n).d(k,4),baselines_linestyle,P.GTABLE(r).LINEWIDTH,P.GTABLE(r).MARKERSIZE,scolor(n2));
					aliases = cat(2,aliases,{sprintf('%s',N(n2).ALIAS)});
					ncolors = cat(2,ncolors,n2);

					E.d = cat(2,E.d,dk);
					E.header = cat(2,E.header,{sprintf('%s-%s_(%s)',N(n).ALIAS,N(n2).ALIAS,baselines_unit)});
				end
			end
			hold off
			set(gca,'XLim',tlim,'FontSize',fontsize)
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
			if nn < length(B)
				set(gca,'XTickLabel',[]);
			end
			%ylabel(sprintf('%s (%s)',N(n).ALIAS,D(n).CLB.un{1}))
			ylabel(varsub(baselines_ylabel,V))
			if isok(P,'PLOT_GRID')
				grid on
			end
			
			% legend
			ylim = get(gca,'YLim');
			nl = length(aliases);
			for ll = 1:nl
				text(tlim(1)+ll*diff(tlim)/(nl+1),ylim(2),aliases(ll),'Color',scolor(ncolors(ll)), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
			end
			set(gca,'YLim',ylim);

			% exports baseline data for reference n
			if isok(P.GTABLE(r),'EXPORTS')
				E.title = sprintf('%s: ref. %s',P.GTABLE(r).GTITLE,N(n).ALIAS);
				mkexport(WO,sprintf('%s_%s_%s',summary,N(n).FID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
			end
		end

		tlabel(tlim,P.GTABLE(r).TZ,'FontSize',fontsize)
	    
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end

	% --- Vectors map
	summary = 'VECTORS';
	if any(strcmp(P.SUMMARYLIST,summary))

		figure, orient tall
		
		P.GTABLE(r).GTITLE = varsub(vectors_title,V);
		P.GTABLE(r).INFOS = {' ',' ', ...
			sprintf('Referential: {\\bf%s}',itrf),sprintf('  E {\\bf%+g} mm/yr\n  N {\\bf%+g} mm/yr\n  U {\\bf%+g} mm/yr',velref),' ',' ', ...
			sprintf('Network mean velocity (%s):',itrf) ...
		};
		for i = 1:3
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('    %s = {\\bf%+1.2f mm/yr}',D(1).CLB.nm{i},mvv(i))}];
		end
		if vrelmode
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('Velocity reference vector ({\\bf%s}):',mode)}];
			for i = 1:3
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('    %s = {\\bf%+1.2f mm/yr}',D(1).CLB.nm{i},voffset(i))}];
			end
		end

		% scale is adjusted to maximum horizontal vector or error amplitude (in mm/yr)
		if velscale > 0
			vmax = velscale;
		else
			vmax = rmax([abs(complex(tr(knv,1),tr(knv,2)));abs(complex(tre(knv,1),tre(knv,2)))/2]);
		end
		vscale = roundsd(vmax,1);
		vsc = .25*max(diff(latlim),minkm/degkm)/vmax;

		ha = plot(geo(knv,2),geo(knv,1),'k.');  extaxes(gca,[.04,.08])
		hold on
		% plots velocity vectors first
		for nn = 1:length(knv)
			n = knv(nn);
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

		dem(DEM.lon,DEM.lat,DEM.z,'latlon','watermark',2,'interp','legend')
		text(xlim(2),ylim(2)+.01*diff(ylim),DEM.COPYRIGHT,'HorizontalAlignment','right','VerticalAlignment','bottom','Interpreter','none','FontSize',6)

		% plots stations
		target(geo(knv,2),geo(knv,1),7);

		% puts arrows on top
		h = get(gca,'Children');
		ko = find(ismember(h,ha),1);
		set(gca,'Children',[ha;h(1:ko-1)])
		
		% plots error ellipse, vertical component and station name
		for nn = 1:length(knv)
			n = knv(nn);
			if ~isnan(any(tr(n,:)))
				h = ellipse(geo(n,2) + vsc*tr(n,1)/xyr,geo(n,1) + vsc*tr(n,2),vsc*tre(n,1)/xyr,vsc*tre(n,2), ...
					'EdgeColor',scolor(n),'LineWidth',.2,'Clipping','on');
				ha = cat(1,ha,h);
			end
			vc = sprintf('%+1.2f',tr(n,3));
			% text position depends on vector direction
			if tr(n,2) > 0
				stn = {'','',N(n).ALIAS};
				svc = {vc,'',''};
			else
				stn = {N(n).ALIAS,'',''};
				svc = {'','',vc};
			end
			text(geo(n,2) + vsc*tr(n,1)/xyr,geo(n,1) + vsc*tr(n,2),svc,'Color',scolor(n),'FontSize',7,'FontWeight','bold', ...
				'VerticalAlignment','Middle','HorizontalAlignment','Center')
			text(geo(n,2),geo(n,1),stn,'FontSize',7,'FontWeight','bold', ...
				'VerticalAlignment','Middle','HorizontalAlignment','Center')
		end

		% plots legend scale
		xsc = xlim(1);
		ysc = ylim(1) - .05*diff(ylim);
		lsc = vscale*vsc;
		arrows(xsc,ysc,lsc,90,arrowshape*vmax/vscale,'FaceColor','none','LineWidth',1,'Clipping','off');
		text(xsc+1.1*lsc,ysc,sprintf('%g mm/yr',vscale),'FontWeight','bold')


		hold off

		rcode2 = sprintf('%s_%s',proc,summary);
		OPT.FIXEDPP = true;
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			E.t = max(cat(1,D(knv).tfirstlast),[],2);
			E.d = [geo(knv,:),tr(knv,:),tre(knv,:)];
			E.header = {'Latitude','Longitude','Altitude','E_velocity(mm/yr)','N_Velocity(mm/yr)','Up_Velocity(mm/yr)','dEv(mm/yr)','dNv(mm/yr)','dUv(mm/yr)'};
			E.title = sprintf('%s {%s}',P.GTABLE(r).GTITLE,upper(rcode2));
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end


	% --- common part for MODELLING and MODELTIME
	if any(ismember(P.SUMMARYLIST,{'MODELLING','MODELTIME'}))

		% selects stations
		if isfield(P,'MODELLING_EXCLUDED_NODELIST')
			kn = find(~ismemberlist({N.FID},split(P.MODELLING_EXCLUDED_NODELIST,',')));
		else
			kn = 1:length(N);
		end

		degm = 1e3*degkm;
		modelopt.msigp = erf(modelopt.msig/sqrt(2));

		% center coordinates
		if numel(targetll) == 2 && all(~isnan(targetll))
			latlim = minmax([geo(kn,1);targetll(1)]);
			lonlim = minmax([geo(kn,2);targetll(2)]);
		else
			latlim = minmax(geo(kn,1));
			lonlim = minmax(geo(kn,2));
			targetll = [mean(latlim),mean(lonlim)];
		end

		lat0 = mean(latlim);
		lon0 = mean(lonlim);
		wid = max(diff(latlim)*degm,diff(lonlim)*degm*cosd(lat0)) + bm;

		ysta = (geo(kn,1) - lat0)*degm;
		xsta = (geo(kn,2) - lon0)*degm*cosd(lat0);
		zsta = geo(kn,3);

		%wid = max(diff(minmax(xsta)),diff(minmax(ysta))) + bm

		% loads SRTM DEM for basemap (with 10% extra borders)
		DEM = loaddem(WO,[lon0 + wid/(degm*cosd(lat0))*[-.6,.6],lat0 + wid/degm*[-.6,.6]]);

		% makes model space
		xlim = linspace(-wid/2,wid/2,rr);
		ylim = xlim;
		zlim = linspace(-maxdep,roundsd(double(max(DEM.z(:))),2,'ceil'),rr);

		[xdem,ydem] = meshgrid(xlim,ylim);
		zdem = interp2((DEM.lon-lon0)*degm*cosd(lat0),(DEM.lat-lat0)*degm,double(DEM.z),xdem,ydem);

		[xx,yy,zz] = meshgrid(xlim,ylim,zlim);

		% station coordinates relative to target and target relative to network center
		xs = xsta - (targetll(2) - lon0)*degm*cosd(lat0);
		ys = ysta - (targetll(1) - lat0)*degm;
		modelopt.targetxy = (targetll([2,1]) - [lon0,lat0]).*[cosd(lat0),1]*degm;
		
	end

	% --- Modelling
	summary = 'MODELLING';
	if any(strcmp(P.SUMMARYLIST,summary))

		% makes (or not) the relative data array
		d = [tr(kn,:),tre(kn,:)];
		knn = find(~isnan(d(:,1)));
		if ~isempty(knn) && (modelling_force_relative || (modrelauto && (azgap(xs(knn),ys(knn)) < 150 || length(find(knn)) > 2)))
			% computes a mean velocity vector (horizontal only)
			mvv = rsum(tr(kn,:)./tre(kn,:))./rsum(1./tre(kn,:));
			d(:,1:3) = d(:,1:3) - repmat([mvv(1:2),0],length(kn),1);
			if isok(P,'DEBUG')
				fprintf('---> Modelling vector relative forced by (%g,%g).\n',mvv(1:2));
			end
		end

		% computes absolute displacement in mm (from velocity in mm/yr)
		d = d*diff(tlim)/365.25;


		% --- computes the model !
		switch lower(modelling_source_type)
		case 'pcdm'
			[mm,vv,k,mm0,ux,uy,uz,ez,ev,ws,pbest] = invpcdm(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt,pcdm);
			wbest = wid/20;
		otherwise
			[mm,vv,k,mm0,ux,uy,uz,ez,ev,ws] = invmogi(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt);
		end

		mhor = max(mm,[],3);
		if strcmp(modelling_coloref,'volpdf')
			clim = [-1,1]*max(mhor(:))*(ws/500)^.5;
		else
			clim = [0,max(mhor(:))*(ws/500)^.5];
			%clim = [min(mhor(:)),max(mhor(:))];
			%clim = minmax(mm);
			if diff(clim)<=0
				clim = [0,1];
			end
		end

		% computes the maximum displacement for vector scale
		%if modelopt.horizonly
		%	%vmax = rmax([abs(complex(d(:,1),d(:,2)));abs(complex(d(:,4),d(:,5)))/2]);
		%	vmax = rmax(abs(reshape(d(:,1:2),1,[])))/2;
		%else
			vmax = rmax(abs(reshape(d(:,1:3),1,[])))/2;
		%end
		vsc = .25*min([diff(minmax(xlim)),diff(minmax(ylim)),diff(minmax(zlim))])/vmax;

		% --- plots the results
		figure, orient tall

		stasize = 6;
		arrowshapemod = [.1,.1,.08,.02];
		arrowref = vsc*vmax/2;
		maxz = max(zdem(:));

		% X-Y top view
		subplot(5,3,[1,2,4,5,7,8]);
		pos = get(gca,'Position');
		[mmm,imm] = max(mm,[],3);
		if strcmp(modelling_coloref,'volpdf')
			imagesc(xlim,ylim,mmm.*sign(index3d(vv,imm,3)))
		else
			imagesc(xlim,ylim,mmm)
		end
		axis xy; caxis(clim);
		%pcolor(xlim,ylim,squeeze(max(vv,[],3)));shading flat
		hold on
		[~,h] = contour(xlim,ylim,zdem,0:200:maxz);
		set(h,'Color',.3*[1,1,1],'LineWidth',.1);
		[~,h] = contour(xlim,ylim,zdem,0:1000:maxz);
		set(h,'Color',.3*[1,1,1],'LineWidth',.75);
		target(xsta,ysta,stasize)
		if ~isnan(vmax)
			arrows(xsta,ysta,vsc*d(:,1),vsc*d(:,2),arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			ellipse(xsta + vsc*d(:,1),ysta + vsc*d(:,2),vsc*d(:,4),vsc*d(:,5),'LineWidth',.2,'Clipping','on')
			arrows(xsta,ysta,vsc*ux,vsc*uy,arrowshapemod,'Cartesian','Ref',arrowref, ...
				'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping','off')
			if plotresidual
				arrows(xsta,ysta,vsc*(d(:,1)-ux),vsc*(d(:,2)-uy),arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping','off')
			end
		end
		if modelopt.apriori_horizontal > 0
			plot(repmat(modelopt.targetxy(1),1,2),ylim([1,end]),':k')
			plot(xlim([1,end]),repmat(modelopt.targetxy(2),1,2),':k')
		end
		%axis equal; axis tight
		if plotbest
			switch lower(modelling_source_type)
			case 'pcdm'
				plotpcdm([xx(k),yy(k),zz(k),pbest([4:6,8,9])],wbest,'xy');
			otherwise
				plot(xx(k),yy(k),'pk','MarkerSize',10,'LineWidth',2)
			end
		end
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(ylim), ...
			'Position',[0.01,pos(2),pos(3) + pos(1) - 0.01,pos(4)],'YAxisLocation','right','FontSize',6)
		if max(abs([xlim,ylim,zlim])) >= 1e4
			tickfactor(1e-3)
		end
		xlabel(sprintf('Origin (0,0) is lon {\\bf%g E}, lat {\\bf%g N}',lon0,lat0),'FontSize',8)

		% Z-Y profile
		axes('position',[0.68,pos(2),0.3,pos(4)])
		[mmm,imm] = max(mm,[],2);
		if strcmp(modelling_coloref,'volpdf')
			imagesc(zlim,ylim,squeeze(mmm.*sign(index3d(vv,imm,2))))
		else
			imagesc(zlim,ylim,squeeze(mmm))
		end
		axis xy; caxis(clim);
		%pcolor(zlim,ylim,squeeze(max(vv,[],2)));shading flat
		hold on
		target(zsta,ysta,stasize)
		if ~isnan(vmax)
			arrows(zsta,ysta,vsc*d(:,3),vsc*d(:,2),arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			ellipse(zsta + vsc*d(:,3),ysta + vsc*d(:,2),vsc*d(:,6),vsc*d(:,5),'LineWidth',.2,'Clipping','on')
			arrows(zsta,ysta,vsc*uz,vsc*uy,arrowshapemod,'Cartesian','Ref',arrowref, ...
				'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping','off')
			if plotresidual
				arrows(zsta,ysta,vsc*(d(:,3)-uz),vsc*(d(:,2)-uy),arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping','off')
			end
		end
		if plotbest
			switch lower(modelling_source_type)
			case 'pcdm'
				plotpcdm([xx(k),yy(k),zz(k),pbest([4:6,8,9])],wbest,'zy');
			otherwise
				plot(zz(k),yy(k),'pk','MarkerSize',10,'LineWidth',2)
			end
		end
		plot(max(max(zdem,[],3),[],2)',ylim,'-k')
		hold off
		set(gca,'XLim',minmax(zlim),'YLim',minmax(ylim),'XDir','reverse','XAxisLocation','top','YAxisLocation','right','YTick',[],'FontSize',6)
		if max(abs([xlim,ylim,zlim])) >= 1e4
			tickfactor(1e-3)
		end

		% X-Z profile
		axes('position',[0.01,0.11,0.6142,0.3])
		[mmm,imm] = max(mm,[],1);
		if strcmp(modelling_coloref,'volpdf')
			imagesc(xlim,zlim,fliplr(rot90(squeeze(mmm.*sign(index3d(vv,imm,1))),-1)))
		else
			imagesc(xlim,zlim,fliplr(rot90(squeeze(mmm),-1)))
		end
		axis xy; caxis(clim);
		%pcolor(xlim,zlim,fliplr(rot90(squeeze(max(vv,[],1)),-1)));shading flat
		hold on
		target(xsta,zsta,stasize)
		if ~isnan(vmax)
			arrows(xsta,zsta,vsc*d(:,1),vsc*d(:,3),arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
			arrows(xsta,zsta,vsc*ux,vsc*uz,arrowshapemod,'Cartesian','Ref',arrowref, ...
				'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping','off')
			if plotresidual
				arrows(xsta,zsta,vsc*(d(:,1)-ux),vsc*(d(:,3)-uz),arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping','off')
			end
		end
		if plotbest
			switch lower(modelling_source_type)
			case 'pcdm'
				plotpcdm([xx(k),yy(k),zz(k),pbest([4:6,8,9])],wbest,'xz');
			otherwise
				plot(xx(k),zz(k),'pk','MarkerSize',10,'LineWidth',2)
			end
		end
		plot(xlim,max(max(zdem,[],3),[],1),'-k')
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(zlim),'YAxisLocation','right','XTick',[],'FontSize',6)
		if max(abs([xlim,ylim,zlim])) >= 1e4
			tickfactor(1e-3)
		end

		if strcmp(modelling_coloref,'volpdf')
			polarmap(modelling_cmap,modelling_colorshading);
		else
			shademap(modelling_cmap,modelling_colorshading)
		end

		% legend
		subplot(5,3,[12,15])
		info = {'   {\itTime span}:', ...
			sprintf('{\\bf%s}',datestr(tlim(1),'yyyy-mm-dd HH:MM')), ...
			sprintf('{\\bf%s}',datestr(tlim(2),'yyyy-mm-dd HH:MM')), ...
			'', ...
			sprintf('model type = {\\bf%s}',modelling_source_type), ...
		};
		if modelopt.horizonly
			info = cat(2,info,'misfit mode = {\bfhorizontal only}');
		end
		if modelopt.apriori_horizontal > 0
			info = cat(2,info,sprintf('a priori horiz. STD = {\\bf%g km}',modelopt.apriori_horizontal));
		end
			%'', ... %sprintf('width = {\\bf%g m}',roundsd(2*ws,1)), ...
			%sprintf('grid size = {\\bf%g^3 nodes}',rr), ...
			%sprintf('trend error mode = {\\bf%d}',terrmod), ...
		info = cat(2,info,' ',sprintf('   {\\itBest sources (%1.1f%%)}:',modelopt.msigp*100));
		switch lower(modelling_source_type)
		case 'pcdm'
			info = cat(2,info, ...
				sprintf('depth = {\\bf%1.1f km} \\in [%1.1f , %1.1f]',pbest(3),-fliplr(ez)/1e3), ...
				sprintf('\\DeltaV = {\\bf%+g Mm^3} \\in [%+g , %+g]',roundsd([pbest(7)*1e3,ev],2)), ...
				sprintf('A = {\\bf%1.2f} / B = {\\bf%1.2f}',pbest(8:9)), ...
				sprintf('\\OmegaX = {\\bf%+2.0f\\circ} / \\OmegaY = {\\bf%+2.0f\\circ} / \\OmegaZ = {\\bf%+2.0f\\circ}',pbest(4:6)));
		otherwise
			info = cat(2,info, ...
				sprintf('depth = {\\bf%1.1f km} \\in [%1.1f , %1.1f]',-[zz(k),fliplr(ez)]/1e3), ...
				sprintf('\\DeltaV = {\\bf%+g Mm^3} \\in [%+g , %+g]',roundsd([vv(k),ev],2)));
		end
		info = cat(2,info,sprintf('misfit = {\\bf%g mm}',roundsd(mm0,2)));
		text(0,1.1,info,'HorizontalAlignment','left','VerticalAlignment','top')
		axis([0,1,0,1]); axis off

		% - probability colorscale
		axes('position',[0.73,.19,.23,.01])
		if strcmp(modelling_coloref,'volpdf')
			imagesc(linspace(-1,1,256),[0;1],repmat(linspace(0,1,256),2,1))
			set(gca,'XTick',[-1,0,1],'YTick',[],'XTickLabel',{'High (Deflate)','Low','High (Inflate)'},'TickDir','out','FontSize',8)
		else
			imagesc(linspace(0,1,256),[0;1],repmat(linspace(0,1,256),2,1))
			set(gca,'XTick',[0,1],'YTick',[],'XTickLabel',{'Low','High'},'TickDir','out','FontSize',8)
		end
		title('Model Probability','FontSize',10)

		% - data/model arrows scale
		axes('position',[0.68,0.11,0.3,0.03])
		dxl = diff(xlim([1,end]))*0.3/0.6142;
		dyl = diff(ylim([1,end]))*0.03/0.3;
		hold on
		if ~isnan(arrowref)
			vlegend = roundsd(vmax/2,1);
			arrows(dxl/2,dyl,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'Clipping','off')
			text(dxl/2 + vsc*vlegend/2,dyl,sprintf('{\\bf%g mm}',vlegend),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8)
			%ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
			arrows(dxl/2,dyl/2,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping','off')
			text([dxl/2,dxl/2],[dyl,dyl/2],{'data   ','model   '},'HorizontalAlignment','right')
			if plotresidual
				arrows(dxl/2,0,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping','off')
				text(dxl/2,0,'residual   ','HorizontalAlignment','right')
			end
		end
		axis off
		hold off
		set(gca,'XLim',[0,dxl],'YLim',[0,dyl])

		P.GTABLE(r).GTITLE = varsub(modelling_title,V);
		P.GTABLE(r).INFOS = {''};
		OPT.FIXEDPP = true;
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

	end

	% --- Modelling in time
	summary = 'MODELTIME';
	if any(strcmp(P.SUMMARYLIST,summary))
		dt = max(modeltime_sampling,length(modeltime_period)*round(diff(tlim)/modeltime_max));

		mtlabel = cell(1,length(modeltime_period));
		for m = 1:length(modeltime_period)
			mtp = modeltime_period(m);
			if mtp > 0
				mtlabel{m} = sprintf('%g days',mtp);
			else
				mtlabel{m} = 't_0 ref.';
			end
			M(m).mtp = mtp;
			M(m).t = fliplr(tlim(2):-dt:tlim(1));
			fprintf('%s: computing %d models (%s @ %g day) ',wofun,length(M(m).t),mtlabel{m},dt);

			% initiates the model result matrix
			M(m).d = nan(length(M(m).t),5);
			M(m).e = nan(length(M(m).t),5);
			M(m).o = nan(length(M(m).t),1);

			for w = 1:length(M(m).t)
				t2 = M(m).t(w);
				if modeltime_period(m) > 0
					wlim = t2 - [modeltime_period(m),0];
				else
					wlim = [tlim(1),t2];
				end

				% computes trends (mm/yr)
				tr = nan(length(kn),3); % trends per station per component
				tre = nan(length(kn),3); % trends error per station per component
				tro = 2*ones(length(kn),1); % inits to worst orbit per station
				for j = 1:length(kn)
					n = kn(j);
					k = find(isinto(D(n).t,wlim));
					tk = D(n).t(k);
					for i = 1:3
						if ~isempty(k) && ~all(isnan(D(n).d(k,i)))
							k1 = k(find(~isnan(D(n).d(k,i)),1,'first'));
							ke = k(find(~isnan(D(n).d(k,i)),1,'last'));
							dk = cleanpicks(D(n).d(k,i) - D(n).d(k1,i),picksclean);
							kk = find(~isnan(dk));
							if length(kk) >= 2 && diff(minmax(D(n).t(kk))) >= trendmindays
								[b,stdx] = wls(tk(kk)-tk(1),dk(kk),1./D(n).e(k(kk),i));
								tr(j,i) = b(1)*365.25*1e3;
								tre(j,i) = stdx(1)*365.25*1e3;
							end
							% sets a better orbit only if there is enough data
							if D(n).t(D(n).G(r).ke) >= M(m).t(w)
								tro(j) = max(D(n).d(k,4));
							end
						end
					end
				end

				% computes reference (auto, fixed or station)
				if length(kn) > 1
					mvv = rsum(tr./tre)./rsum(1./tre);
				else
					mvv = tr;
				end
				if vrelmode
					voffset = [mvv(1:2),0];
					if ~isempty(vref) && ismember(vref,{N.FID})
						voffset = tr(strcmp(vref,{N.FID}),:);
						if any(isnan(voffset))
							voffset = [0,0,0];
						end
					end
					if numel(sstr2num(vref)) == 3
						voffset = sstr2num(vref);
					end
					tr = tr - repmat(voffset,length(kn),1);
				end

				% makes (or not) the relative data array
				d = [tr,tre];
				knn = find(~isnan(d(:,1)));
				modrelforced = 0;
				if ~isempty(knn) && (modelling_force_relative || (modrelauto && (azgap(xs(knn),ys(knn)) < 150 || length(knn) > 2)))
					% computes a mean velocity vector (horizontal only)
					if length(knn) > 1
						mvv = rsum(tr(knn,:)./tre(knn,:))./rsum(1./tre(knn,:));
					else
						mvv = tr(knn,:);
					end
					d(:,1:3) = d(:,1:3) - repmat([mvv(1:2),0],size(d,1),1);
					modrelforced = 1;
				end
				% computes absolute displacement in mm (from velocity in mm/yr)
				d = d*diff(wlim)/365.25;

				% --- computes the model !
				[mm,vv,kb,mm0,ux,uy,uz,ez,ev,ws] = invmogi(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt);

				M(m).d(w,:) = [xx(kb),yy(kb),zz(kb),vv(kb),sign(vv(kb))*mean(sqrt(ux.^2+uy.^2+uz.^2))];
				M(m).e(w,:) = [ws,ws,diff(ez),diff(ev),mm0];
				M(m).o(w,1) = max(tro); % model worst orbit

				if isok(P,'DEBUG')
					fprintf('\n%s,%s: %+g Mm3 / %g km',datestr(wlim(1)),datestr(wlim(2)),roundsd([vv(kb),zz(kb)/1e3],3));
					if modrelforced
						fprintf(' / relative mode forced by (%g,%g)',mvv(1:2));
					end
				else
					fprintf('.');
				end
			end

			% puts NaN where vv is NaN (no model)
			M(m).d((isnan(M(m).d(:,4)) | M(m).e(:,5) > 1e3*maxerror),:) = NaN;

			fprintf('\n done!\n');
		end

		figure, orient tall

		% volume variation (moving)
		subplot(10,1,1:4), extaxes(gca,[.08,.04])
		
		plot(tlim,[0,0],'-k','LineWidth',1)
		hold on
		for m = 1:length(M)
			col = scolor(m);
			errorbar(M(m).t,M(m).d(:,4),M(m).e(:,4),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',col/2 + 1/2)
			plotorbit(M(m).t,M(m).d(:,4),M(m).o,'o-',P.GTABLE(r).LINEWIDTH/2,P.GTABLE(r).MARKERSIZE,col)
			%plot(M(m).t,M(m).d(:,4),'o-','Color',col,'MarkerFaceColor',col, ...
			%	'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).MARKERSIZE/5)
		end
		hold off
		text(tlim(2),0,{'',' \rightarrow Inflation'},'rotation',90,'Color','k', ...
			'HorizontalAlignment','left','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		text(tlim(2),0,{'','Deflation \leftarrow '},'rotation',90,'Color','k', ...
			'HorizontalAlignment','right','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		set(gca,'XLim',tlim,'FontSize',fontsize)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('{Moving \Delta}V (Mm^3)')

		% legend for periods
		ylim = get(gca,'YLim');
		for m = 1:length(M)
			text(tlim(1)+m*diff(tlim)/(length(M)+1),ylim(2),mtlabel{m},'Color',scolor(m), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8,'FontWeight','bold')
		end
		set(gca,'YLim',ylim);

		% depth
		subplot(10,1,5:6), extaxes(gca,[.08,.04])
		plot(tlim,[0,0],'-k','LineWidth',1)
		hold on
		for m = 1:length(M)
			col = scolor(m);
			errorbar(M(m).t,M(m).d(:,3)/1e3,M(m).e(:,3)/1e3,'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',col/2 + 1/2)
			plotorbit(M(m).t,M(m).d(:,3)/1e3,M(m).o,'o-',P.GTABLE(r).LINEWIDTH/2,P.GTABLE(r).MARKERSIZE,col)
			%plot(M(m).t,M(m).d(:,3)/1e3,'o-','Color',col,'MarkerFaceColor',col, ...
			%	'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).MARKERSIZE/5)
		end
		hold off
		set(gca,'XLim',tlim,'FontSize',fontsize,'YLim',minmax(zz)/1e3)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Source Depth (km)')

		% displacements module
		subplot(10,1,7:10), extaxes(gca,[.08,.04])
		plot(tlim,[0,0],'-k','LineWidth',1)
		hold on
		for m = 1:length(M)
			col = scolor(m);
			errorbar(M(m).t,M(m).d(:,5),M(m).e(:,5),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',col/2 + 1/2)
			plotorbit(M(m).t,M(m).d(:,5),M(m).o,'o-',P.GTABLE(r).LINEWIDTH/2,P.GTABLE(r).MARKERSIZE,col)
			%plot(M(m).t,M(m).d(:,5),'o-','Color',col,'MarkerFaceColor',col, ...
			%	'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).MARKERSIZE/5)
		end
		hold off
		text(tlim(2),0,{'',' \rightarrow Inflation'},'rotation',90,'Color','k', ...
			'HorizontalAlignment','left','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		text(tlim(2),0,{'','Deflation \leftarrow'},'rotation',90,'Color','k', ...
			'HorizontalAlignment','right','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		set(gca,'XLim',tlim,'FontSize',fontsize)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Displ. Amplitude (mm)')

		% volume variation (cumulative normalized)
		%subplot(10,1,8:10), extaxes(gca,[.08,.04])
		
		%plot(tlim,[0,0],'-k','LineWidth',1)
		%hold on
		%for m = 1:length(M)
		%	col = scolor(m);
		%	errorbar(M(m).t,rcumsum(M(m).d(:,4)),sqrt(rcumsum(M(m).e(:,4).^2)),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',col/2 + 1/2)
		%	plot(M(m).t,rcumsum(M(m).d(:,4)),'o-','Color',col,'MarkerFaceColor',col, ...
		%		'MarkerSize',P.GTABLE(r).MARKERSIZE,'LineWidth',P.GTABLE(r).MARKERSIZE/5)
		%end
		%hold off
		%text(tlim(2),0,' \rightarrow Inflation','rotation',90,'Color','k', ...
		%	'HorizontalAlignment','left','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		%text(tlim(2),0,'Deflation \leftarrow ','rotation',90,'Color','k', ...
		%	'HorizontalAlignment','right','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		%set(gca,'XLim',tlim,'FontSize',fontsize)
		%datetick2('x',P.GTABLE(r).DATESTR)
		%ylabel('Absolute pressure source (experimental)')


		tlabel(tlim,P.GTABLE(r).TZ,'FontSize',fontsize)
	    
		P.GTABLE(r).GTITLE = varsub(modeltime_title,V);
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			rcode2 = sprintf('%s_%s',proc,summary);
			E.t = M(1).t;
			n = size(M(1).d,2);
			E.d = nan(size(M(1).d,1),length(M)*size(M(1).d,2)*2);
			for m = 1:length(M)
				k = (m-1)*n*2 + (1:2*n);
				E.d(:,k) = cat(2,M(m).d,M(m).e);
				E.header(k) = strcat({'X','Y','Z','dV','dD','s_X','s_Y','s_Z','s_dV','s_dD'},sprintf('_%g',M(m).mtp));
			end
			E.title = sprintf('%s {%s}',P.GTABLE(r).GTITLE,upper(rcode2));
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
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




% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function h = plotorbit(t,d,orb,lst,lwd,mks,col)
% plots time series with optional error bars (if size(d,2)>1) and watermark colors for orbits > 1
hd = ishold;

plot(t,d(:,1),lst,'LineWidth',lwd,'Color',col,'MarkerSize',mks,'MarkerFaceColor',col)
hold on

if size(d,2) > 1
	set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis (error bars can overflow)
	plot(repmat(t,[1,2])',(repmat(d(:,1),[1,2])+d(:,2)*[-1,1])','-','LineWidth',.1,'Color',.6*[1,1,1])
end

% overwrites not-final orbits
for o = 1:2
	kk = find(orb==o);
	if ~isempty(kk)
		l = o*2;
		wcol = col/l + 1 - 1/l;
		plot(t(kk),d(kk,1),lst,'LineWidth',lwd,'MarkerSize',mks,'Color',wcol,'MarkerFaceColor',wcol)
	end
end

if ~hd
	hold off
end


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = index3d(x,id3,dim)
% returns elements of multidimensional matrix x given by index matrix id3 in 
% the dimension dim. id3 comes from [y,id3] = max(x,[],dim); so y and id3 have
% one dimension less than x.

sz = size(x);
idx = 1:numel(id3);

switch dim
case 1
	[j,k] = ind2sub(sz([2,3]),idx);
	y = x(sub2ind(sz,id3(:),j(:),k(:)));
case 2
	[i,k] = ind2sub(sz([1,3]),idx);
	y = x(sub2ind(sz,i(:),id3(:),k(:)));
case 3
	[i,j] = ind2sub(sz([1,2]),idx);
	y = x(sub2ind(sz,i(:),j(:),id3(:)));
end
y = reshape(y,size(id3));
