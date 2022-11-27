function DOUT=gnss(varargin)
%GNSS	WebObs SuperPROC: Updates graphs/exports of GNSS/GLOBK results.
%
%       GNSS(PROC) makes default outputs of PROC.
%
%       GNSS(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	        TSCALE = '01y' or '30d,10y,all': only specified timescales
%	        (keywords must be in TIMESCALELIST of PROC.conf)
%
%	GNSS(PROC,[],REQDIR) makes graphs/exports for specific request directory
%	REQDIR. REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = GNSS(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       GNSS will use PROC's and NODE's parameters to import data.
%	     Particularily, it can use NODE's calibration file if exists; in that
%	     case channels must be as follows:
%           Channel 1 = Eastern UTM (m)
%           Channel 2 = Northern UTM (m)
%           Channel 3 = Elevation (m)
%           Channel 4 = Orbit (-)
%
%       GNSS will use PROC's parameters from .conf file. See CODE/tplates/PROC.GNSS
%       template file for a list of all parameters with comments.
%
%	Any of the *_TITLE keys may contain local keys (e.g. ${NAME}) and a list
%	of internal variables that will be substituted in the text strings:
%	    $node_name      = node long name
%	    $node_alias     = node alias
%	    $timescale      = time scale string (e.g. '1 year')
%	    $last_data      = last data date and time string
%	    $ref_node_alias = reference node alias
%	    $itrf           = velocity reference string
%
%
%   Authors: François Beauducel, Aline Peltier, Patrice Boissier, Antoine Villié,
%            Jean-Marie Saurel / WEBOBS, IPGP
%   Created: 2010-06-12 in Paris (France)
%   Updated: 2022-10-19

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
G = cat(1,D.G);

% PROC's parameters
border = .1;
fontsize = field2num(P,'FONTSIZE',7);
maxerror = field2num(P,'FILTER_MAX_ERROR_M',NaN);
minerror = field2num(P,'ENU_MIN_ERROR_M',[0.01,0.01,0.01]);
orbiterr = field2num(P,'ORBIT_ERROR_RATIO',[1,2]);
terrmod = field2num(P,'TREND_ERROR_MODE',1);
trendmindays = field2num(P,'TREND_MIN_DAYS',1);
trendminperc = field2num(P,'TREND_MIN_PERCENT',50);
targetll = field2num(P,'GNSS_TARGET_LATLON');
if numel(targetll)~=2 || any(isnan(targetll))
	targetll = [];
end
degm = 1e3*degkm;
velref = field2num(P,'VELOCITY_REF',[0,0,0]);
velrefdate = field2num(P,'VELOCITY_REF_ORIGIN_DATE',datenum(2000,1,1));
itrf = field2str(P,'ITRF_REF','ITRF');
if numel(velref)==3 && any(velref~=0)
	itrf = 'local ref.';
end
enu = {'E','N','U'};
cmpnames = split(field2str(P,'COMPONENT_NAMELIST','Relative Eastern,Relative Northern,Relative Vertical'),',');
disp_yscale = field2num(P,'DISP_YSCALE_M',0);

% Harmonic correction: period list (day), pairs of sine, cosine (mm) for each component
harm_refdate = field2num(P,'HARMONIC_ORIGIN_DATE');
harm_period = field2num(P,'HARMONIC_PERIOD_DAY',0);
harm(1).x = field2num(P,'HARMONIC_EAST_SINCOS_MM')/1e3;
harm(2).x = field2num(P,'HARMONIC_NORTH_SINCOS_MM')/1e3;
harm(3).x = field2num(P,'HARMONIC_UP_SINCOS_MM')/1e3;
harmcorr = false;
if isnumeric(harm_refdate) && all(harm_period > 0)
	if all([numel(harm(1).x),numel(harm(2).x),numel(harm(3).x)]==2*numel(harm_period))
		fprintf('---> Harmonic correction: %s days\n',num2str(harm_period));
		harmcorr = true;
	else
		fprintf('*** Warning: inconsistent pairs of sine/cosine for harmonic correction!\n');
	end
end

% PERNODE graphs parameters
pernode_linestyle = field2str(P,'PERNODE_LINESTYLE','o');
pernode_title = field2str(P,'PERNODE_TITLE','{\fontsize{14}{\bf$node_alias: $node_name - $velref} ($timescale)}');
pernode_timezoom = field2num(P,'PERNODE_TIMEZOOM',0);
pernode_cmpoff = field2num(P,'PERNODE_COMPONENT_OFFSET_M',0.01);

% SUMMARY parameters
summary_linestyle = field2str(P,'SUMMARY_LINESTYLE','o');
summary_title = field2str(P,'SUMMARY_TITLE','{\fontsize{14}{\bf$name - $itrf} ($timescale)}');
summary_timezoom = field2num(P,'SUMMARY_TIMEZOOM',0);
summary_staoff = field2num(P,'SUMMARY_STATION_OFFSET_M',0.01);
summary_cmpoff = field2num(P,'SUMMARY_COMPONENT_OFFSET_M',0.01);

% VECTORS parameters
vectors_excluded = field2str(P,'VECTORS_EXCLUDED_NODELIST');
vectors_included = field2str(P,'VECTORS_INCLUDED_NODELIST');
vectors_excluded_target = field2num(P,'VECTORS_EXCLUDED_FROM_TARGET_KM',0,'notempty');
vrelmode = isok(P,'VECTORS_RELATIVE');
if vrelmode
	vref = '';
	if isfield(P,'VECTORS_VELOCITY_REF')
		vref = P.VECTORS_VELOCITY_REF;
	end
	% PCA applied on relative components X(2)
	if pernode_timezoom < 0
		pernode_timezoom = -2;
	end
end
vrelhorizonly = isok(P,'VECTORS_RELATIVE_HORIZONTAL_ONLY',1);
velscale = field2num(P,'VECTORS_VELOCITY_SCALE',0);
minkm = field2num(P,'VECTORS_MIN_SIZE_KM',10);
maxxy = field2num(P,'VECTORS_MAX_XYRATIO',1);
arrowshape = field2num(P,'VECTORS_ARROWSHAPE',[.1,.1,.08,.02]);
vectors_title = field2str(P,'VECTORS_TITLE','{\fontsize{14}{\bf$name - Vectors} ($timescale)}');
vectors_demopt = field2cell(P,'VECTORS_DEM_OPT','watermark',2,'saturation',.8,'interp','legend','seacolor',[0.7,0.9,1]);
vectors_shape = field2shape(P,'VECTORS_SHAPE_FILE');
vectors_ampcmp = field2num(P,'VECTORS_AMPLITUDE_COMPONENTS',1:2);
if numel(vectors_ampcmp)>3 || ~all(ismember(vectors_ampcmp,1:3))
	fprintf('*** Warning: VECTORS_AMPLITUDE_COMPONENTS not consistent. Using default (1,2)\n');
	vectors_ampcmp = 1:2;
end
vectors_ampstr = strjoin(enu(vectors_ampcmp),'+');

% BASELINES parameters
baselines_excluded = field2str(P,'BASELINES_EXCLUDED_NODELIST');
baselines_included = field2str(P,'BASELINES_INCLUDED_NODELIST');
baselines_excluded_target = field2num(P,'BASELINES_EXCLUDED_FROM_TARGET_KM',0,'notempty');
baselines_horizonly = isok(P,'BASELINES_HORIZONTAL_ONLY');
pagestanum = field2num(P,'BASELINES_PAGE_STA_NUM',10);
baselines_interp_method = field2str(P,'BASELINES_INTERP_METHOD',{'','linear','nearest'});
baselines_linestyle = field2str(P,'BASELINES_LINESTYLE','o-');
baselines_title = field2str(P,'BASELINES_TITLE','{\fontsize{14}{\bf$name - Baselines} ($timescale)}');
baselines_ylabel = field2str(P,'BASELINES_YLABEL','$ref_node_alias ($baselines_unit)');
baselines_unit = field2str(P,'BASELINES_UNIT','m');
baselines_refoff = field2num(P,'BASELINES_REF_OFFSET_M',0.01);
baselines_staoff = field2num(P,'BASELINES_STATION_OFFSET_M',0.01);
baselines_timezoom = field2num(P,'BASELINES_TIMEZOOM',0);

% MOTION parameters
motion_excluded = field2str(P,'MOTION_EXCLUDED_NODELIST');
motion_included = field2str(P,'MOTION_INCLUDED_NODELIST');
motion_excluded_target = field2num(P,'MOTION_EXCLUDED_FROM_TARGET_KM',0,'notempty');
motion_filter = field2num(P,'MOTION_MAFILTER',10);
motion_scale = field2num(P,'MOTION_SCALE_MM',0);
motion_minkm = field2num(P,'MOTION_MIN_SIZE_KM',10);
motion_colormap = field2num(P,'MOTION_COLORMAP',spectral(256));
motion_demopt = field2cell(P,'MOTION_DEM_OPT','watermark',1.5,'saturation',0,'interp');
motion_title = field2str(P,'MOTION_TITLE','{\fontsize{14}{\bf$name - Motion} ($timescale)}');

% MODELNET parameters
modelnet_excluded = field2str(P,'MODELNET_EXCLUDED_NODELIST');
modelnet_included = field2str(P,'MODELNET_INCLUDED_NODELIST');
modelnet_excluded_target = field2num(P,'MODELNET_EXCLUDED_FROM_TARGET_KM',0,'notempty');
modelnet_mindisp = field2num(P,'MODELNET_MIN_DISP_M',[1,1,2]);
modelnet_minsta = round(field2num(P,'MODELNET_MIN_STATION',2));
modelnet_dslice = field2num(P,'MODELNET_DEPTH_SLICE',0:2000:8000);
modelnet_border = field2num(P,'MODELNET_BORDERS',1000);
modelnet_target_included = isok(P,'MODELNET_TARGET_INCLUDED',1);
modelnet_gridsize = field2num(P,'MODELNET_GRID_SIZE',100);
modelnet_vazel = field2num(P,'MODELNET_VIEW_AZEL',[40,10]);
modelnet_dvlim = field2num(P,'MODELNET_DVLIM');
modelnet_cmap = field2num(P,'MODELNET_COLORMAP',roma(256));
modelnet_mks = field2cell(P,'MODELNET_MARKER','^k','MarkerSize',8,'MarkerFaceColor',.99*ones(1,3));
modelnet_title = field2str(P,'MODELNET_TITLE','{\fontsize{14}{\bf$name - Network sensitivity}}');

% MODELLING parameters
modelling_excluded = field2str(P,'MODELLING_EXCLUDED_NODELIST');
modelling_included = field2str(P,'MODELLING_INCLUDED_NODELIST');
modelling_excluded_target = field2num(P,'MODELLING_EXCLUDED_FROM_TARGET_KM',0,'notempty');
modelling_force_relative = isok(P,'MODELLING_FORCE_RELATIVE');
modrelauto = strcmpi(field2str(P,'MODELLING_FORCE_RELATIVE'),'auto');
maxdep = field2num(P,'MODELLING_MAX_DEPTH',8e3);
bm = field2num(P,'MODELLING_BORDERS',5000);
rr = field2num(P,'MODELLING_GRID_SIZE',50);
modelling_cmap = field2num(P,'MODELLING_COLORMAP',ryb(256));
modelling_colorshading = field2num(P,'MODELLING_COLOR_SHADING',0.3);
modelling_topo_rgb = field2num(P,'MODELLING_TOPO_RGB',.5*[1,1,1]);
% color reference for model space: 'pdf' or 'volpdf' (source volume sign x pdf, new default)
modelling_coloref = lower(field2str(P,'MODELLING_COLORREF','volpdf'));
% colors for displacement arrows
datarrcol = field2num(P,'MODELLING_DATA_COLOR',[0,0,0]); % color of model arrows
modarrcol = field2num(P,'MODELLING_MODEL_COLOR',[.7,0,0]); % color of model arrows
resarrcol = field2num(P,'MODELLING_RESIDUAL_COLOR',[0,.5,0]); % color of residual arrows
plotnancomp = isok(P,'MODELLING_PLOT_NAN_COMPONENT',1);
modelling_title = field2str(P,'MODELLING_TITLE','{\fontsize{14}{\bf$name - Source modelling} ($timescale)}');
plotbest = isok(P,'MODELLING_PLOT_BEST');
plotbest_col = field2num(P,'MODELLING_PLOT_BEST_COLOR',.5*ones(1,3));
plotbest_opt = {'p','MarkerSize',15,'LineWidth',1};
modelling_vmax_mm = field2num(P,'MODELLING_VMAX_MM',0);
modelling_vmax_ratio = field2num(P,'MODELLING_VMAX_RATIO',.25);
plotresidual = isok(P,'MODELLING_PLOT_RESIDUAL',1);
if isok(P,'MODELLING_VECTORS_CLIP',0)
	vclip = 'on';
else
	vclip = 'off';
end
modelling_shape = field2shape(P,'MODELLING_SHAPE_FILE');

modelling_source_type = field2str(P,'MODELLING_SOURCE_TYPE','isotropic','notempty');

% some modelling parameters are structure fields to pass them to other functions
modelopt.horizonly = isok(P,'MODELLING_HORIZONTAL_ONLY');
modelopt.minerror = field2num(P,'MODELLING_MINERROR_MM',5); % minimum error on data (in mm)
modelopt.minerrorrel = field2num(P,'MODELLING_MINERROR_PERCENT',1); % minimum relative error on data (in %)
modelopt.enuerror = field2num(P,'MODELLING_ENU_ERROR_RATIO'); % factor ratio to adjust each component error
if numel(modelopt.enuerror) < 3
	modelopt.enuerror = ones(1,3);
end
% a priori source depth (value, gaussian STD in m)
modelopt.apriori_depth = field2num(P,'MODELLING_APRIORI_DEPTH_M');
% a priori horizontal error around the target (in STD, km), 0 or NaN = no a priori
modelopt.apriori_horizontal = field2num(P,'MODELLING_APRIORI_HSTD_KM');
modelopt.msig = field2num(P,'MODELLING_SIGMAS',1);
modelopt.misfitnorm = field2str(P,'MODELLING_MISFITNORM','L1');
modelopt.multi = field2num(P,'MODELLING_MULTIPLE_SOURCES',1,'notempty');

% MODELLING pCDM parameters (see invpcdm.m)
% number of iterations (adjusting the parameter's limits)
PCDM.iterations = field2num(P,'MODELLING_PCDM_ITERATIONS',5);
% number of random samples: scalar or list for each iteration
PCDM.random_sampling = field2num(P,'MODELLING_PCDM_RANDOM_SAMPLING',200000);
% elastic parameter (Poisson's ratio) nu
PCDM.nu = field2num(P,'MODELLING_PCDM_NU',0.25);
% dV parameter limits: total volume variation (in m3)
PCDM.dvlim = field2num(P,'MODELLING_PCDM_DVLIM',[-1e7,1e7]);
% A parameter limits: horizontal over total volume variation ratio
% A = dVZ/(dVX+dVY+dVZ)
% 	0 = vertical (dyke or pipe following B value)
% 	1 = horizontal (sill)
% 	1/3 = isotrop if B = 0.5
PCDM.alim = field2num(P,'MODELLING_PCDM_ALIM',[0,1]);
% B parameter limits: vertical volume variation ratio
% B = dVY/(dVX+dVY)
% 	0 = dyke if A = 0, dyke+sill otherwise
% 	1 = dyke if A = 0, dyke+sill otherwise
% 	0.5 = isotrop if A = 1/3, pipe if A = 0
PCDM.blim = field2num(P,'MODELLING_PCDM_BLIM',[0,1]);
% OmegaX parameter limits: rotation angle around X axis (West-East)
PCDM.oxlim = field2num(P,'MODELLING_PCDM_OXLIM',[-45,45]);
% OmegaY parameter limits: rotation angle around Y axis (South-North)
PCDM.oylim = field2num(P,'MODELLING_PCDM_OYLIM',[-45,45]);
% OmegaZ parameter limits: rotation angle around Z axis (Bottom-Up)
PCDM.ozlim = field2num(P,'MODELLING_PCDM_OZLIM',[-45,45]);
% number of bins for probability vs parameter map (heatmap)
PCDM.heatmap_grid = field2num(P,'MODELLING_PCDM_HEATMAP_GRID',50);
% graphical parameter for heatmaps
PCDM.heatmap_saturation = field2num(P,'MODELLING_PCDM_HEATMAP_SATURATION',0.4);
% number of bins used to smooth the maximum probability curve
PCDM.heatmap_smooth_span = field2num(P,'MODELLING_PCDM_HEATMAP_SMOOTH_SPAN',5);
% polynomial degree to smooth the maximum probability curve
PCDM.heatmap_smooth_degree = field2num(P,'MODELLING_PCDM_HEATMAP_SMOOTH_DEGREE',1);
% minimum number of models to compute maximum probability curve
PCDM.newlimit_threshold = field2num(P,'MODELLING_PCDM_NEW_THRESHOLD',2);
% tolerance ratio to extend the edge limits
PCDM.newlimit_edge_ratio = field2num(P,'MODELLING_PCDM_NEW_LIMIT_EDGE_RATIO',20);
% factor of extension (from the previous interval) when reaching an edge
PCDM.newlimit_extend = field2num(P,'MODELLING_PCDM_NEW_LIMIT_EXTEND',1);
% option to export supplementary graphs (intermediate results per iteration)
PCDM.supplementary_graphs = isok(P,'MODELLING_PCDM_SUPPLEMENTARY_GRAPHS');
tickfactorlim = 5e3; % above 5 km width/depth axis will be in km

% MODELTIME parameters
modeltime_source_type = field2str(P,'MODELTIME_SOURCE_TYPE','isotropic','notempty');
modeltime_period = field2num(P,'MODELTIME_PERIOD_DAY');
modeltime_sampling = field2num(P,'MODELTIME_SAMPLING_DAY',1);
modeltime_max = field2num(P,'MODELTIME_MAX_MODELS',100);
modeltime_gridsize = field2num(P,'MODELTIME_GRID_SIZE',rr);
modeltime_maxmisfit = field2num(P,'MODELTIME_MAX_MISFIT_M',1);
modeltime_title = field2str(P,'MODELTIME_TITLE','{\fontsize{14}{\bf$name - Source best model timeline} ($timescale)}');
modeltime_flowrate = isok(P,'MODELTIME_FLOWRATE',1);
modeltime_flim = field2num(P,'MODELTIME_FLIM');
modeltime_map_period = field2num(P,'MODELTIME_MAP_PERIODLIST',modeltime_period,'notempty');
modeltime_linestyle = field2str(P,'MODELTIME_LINESTYLE','-');
modeltime_marker_linewidth = field2num(P,'MODELTIME_MARKER_LINEWIDTH',1);
modeltime_cmap = field2num(P,'MODELTIME_COLORMAP',spectral(256));
modeltime_markersize = pi*(field2num(P,'MODELTIME_MARKERSIZE',10,'notempty')/2)^2; % scatter needs marker size as a surface (πr²)


geo = [cat(1,N.LAT_WGS84),cat(1,N.LON_WGS84),cat(1,N.ALTITUDE)];

V.name = P.NAME;
V.velref = itrf;
V.baselines_unit = field2str(P,'BASELINES_UNIT','m');

% ==============================================================================
% Makes the proc's job
%
% Note: D(n).d = [E,N,U,Orbit,E_proc,N_proc,U_proc] where columns 1:4 are original
% data (in the local reference) and columns 5:7 are processed/corrected data


for n = 1:numel(N)

	% --- if a local reference is defined (VELOCITY_REF), computes relative positions in
	% D.d from the install date of the station.
	if numel(velref)==3 && ~all(velref==0)
		t0 = velrefdate;
		for c = 1:3
			if size(D(n).d,2) >= c
				D(n).d(:,c) = D(n).d(:,c) - polyval([velref(c)/365250,0],D(n).t - t0);
			end
		end
	end

	% --- add a default orbit column to data if needed
	if ~isempty(D(n).d) && size(D(n).d,2) < 4
		D(n).d(:,4) = zeros(size(D(n).d(:,1)));
	end

	% --- filter the data at once and adjust errors
	if ~isempty(D(n).d)
		if ~isnan(maxerror)
			D(n).d(any(D(n).e>maxerror,2),:) = NaN;
		end
		for c = 1:3
			D(n).e(isnan(D(n).e(:,c)) | D(n).e(:,c)<minerror(c),c) = minerror(c);
		end
		for i = 1:numel(orbiterr)
			k = find(D(n).d(:,4)>=i-1);
			if ~isempty(k) && ~isempty(D(n).e) && orbiterr(i)>0
				D(n).e(k,:) = D(n).e(k,:)*orbiterr(i);
			end
		end
	end

	% --- duplicate raw data in columns 5:7
	if ~isempty(D(n).d)
		D(n).d = D(n).d(:,[1:4,1:3]);
	end

	% --- harmonic correction
	if harmcorr && ~isempty(D(n).d)
		tharm = D(n).t - harm_refdate;
		for i = 1:3
			for c = 1:length(harm_period)
				a = 2*pi*tharm/harm_period(c);
				D(n).d(:,i+4) = D(n).d(:,i+4) - sin(a)*harm(i).x(1+(c-1)*2) - cos(a)*harm(i).x(2+(c-1)*2);
			end
		end
	end

end


for r = 1:numel(P.GTABLE)

	% initializes linear trends table
	tr = nan(numel(N),3); % linear trends per station per component (mm/yr)
	tre = nan(numel(N),3); % linear trends error (mm/yr)

	V.timescale = timescales(P.GTABLE(r).TIMESCALE);
	tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
	if any(isnan(tlim))
		tlim = minmax(cat(1,D.tfirstlast));
	end

	% station offset
	n0 = numel(N) - 1;
	staoffset = ((0:n0) - n0/2)*summary_staoff;

	% to make a synthetic figure we must build a new matrix of processed data first...
	X = repmat(struct('t',[],'d',[],'w',[]),numel(N),1);
	for i = 1:3
		for n = 1:numel(N)

			k = D(n).G(r).k;
			if ~isempty(k)% && ~all(isnan(D(n).d(k,i)))
				dk = cleanpicks(D(n).d(k,i+4) - rmedian(D(n).d(k,i+4)),P);
				tk = D(n).t(k);

				% computes yearly trends (in mm/yr)
				kk = find(~isnan(dk));
				if numel(kk) >= 2 && diff(minmax(tk(kk))) >= trendmindays && 100*diff(minmax(tk(kk)))/diff(tlim) >= trendminperc && ~all(isnan(dk(kk)))
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
						acq = numel(kk)*N(n).ACQ_RATE/abs(diff(tlim));
						tre(n,i) = tre(n,i)/sqrt(acq);
					end
				else
					tr(n,i) = NaN;
					tre(n,i) = NaN;
				end
				X(n).t = tk;
				X(n).d(:,i) = dk + staoffset(n);
				if i == 3
					X(n).w = D(n).d(k,4);
				end
			end
			X(n).nam = N(n).ALIAS;
			X(n).rgb = scolor(n);
			X(n).trd = 0;
		end
	end
	for n = 1:numel(N)
		if isempty(X(n).d)
			X(n).d = nan(0,3);
		end
	end

	% --- Summary plot: time series
	summary = 'SUMMARY';
	if any(strcmp(P.SUMMARYLIST,summary))
		figure, clf, orient tall
		OPT.linestyle = summary_linestyle;
		OPT.fontsize = fontsize;
		OPT.chnames = cmpnames;
		OPT.choffset = summary_cmpoff;
		OPT.zoompca = summary_timezoom;
		OPT.trendmindays = trendmindays;
		OPT.trendminperc = trendminperc;
		OPT.yscalevalue = disp_yscale;
		OPT.yscaleunit = 'cm';
		OPT.yscalefact = 100;
		smartplot(X,tlim,P.GTABLE(r),OPT);
		if isok(P,'PLOT_GRID')
			grid on
		end
		P.GTABLE(r).GTITLE = varsub(summary_title,V);
		P.GTABLE(r).INFOS = {sprintf('Referential: {\\bf%s}',itrf),sprintf('  E {\\bf%+g} mm/yr\n  N {\\bf%+g} mm/yr\n  U {\\bf%+g} mm/yr',velref)};
		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end


	% --- computes vector reference (relative mode) + common part for relative mode
	knv = selectnode(N,tlim,vectors_excluded,vectors_included,[targetll,vectors_excluded_target]);

	if isok(P,'VECTORS_TARGET_INCLUDED') && ~isempty(targetll)
		latlim = minmax([geo(knv,1);targetll(1)]);
		lonlim = minmax([geo(knv,2);targetll(2)]);
	else
		latlim = minmax(geo(knv,1));
		lonlim = minmax(geo(knv,1));
	end
	xyr = cosd(mean(latlim));

	% computes a mean velocity vector (for valid nodes only)
	if numel(knv) > 1
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
			if ~isempty(vref) && all(kvref);
				mode = vref;
				if numel(knref) > 1
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
		tr = tr - repmat(voffset,numel(N),1);
		fprintf('---> Relative mode "%s" - velocity reference = %1.2f, %1.2f, %1.2f mm/yr\n',mode,voffset);
	end

	% --- per node plots
	for n = 1:numel(N)

		V.node_name = N(n).NAME;
		V.node_alias = N(n).ALIAS;
		V.last_data = datestr(D(n).tfirstlast(2));

		figure, clf, orient tall

		% renames main variables for better lisibility...
		k = D(n).G(r).k;
		ke = D(n).G(r).ke;

		% title and status
		P.GTABLE(r).GTITLE = varsub(pernode_title,V);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};

		% loop for Relative Eastern, Northern, and Up components with error bars (in m)
		X = repmat(struct('t',[],'d',[],'e',[],'w',[]),1+vrelmode,1);
		for i = 1:3
			if ~isempty(k)
				tk = D(n).t(k);
				dk = cleanpicks(D(n).d(k,i)-rmedian(D(n).d(k,i)),P);
				X(1).t = tk;
				X(1).d(:,i) = dk;
				X(1).e(:,i) = D(n).e(k,i);
				if i == 3
					X(1).w = D(n).d(k,4);
				end
				if harmcorr || vrelmode
					dk = cleanpicks(D(n).d(k,i+4)-rmedian(D(n).d(k,i+4)),P);
					X(2).t = tk;
					X(2).d(:,i) = dk - polyval([voffset(i)/365250,0],tk - tlim(1));
					X(2).e(:,i) = D(n).e(k,i);
					if i == 3
						X(2).w = D(n).d(k,4);
					end
				end
			end
		end
		if harmcorr || vrelmode
			X(1).nam = 'original';
			X(1).rgb = scolor(1);
			X(1).trd = 0;
			%X(2).nam = sprintf('relative (%s)',mode);
			X(2).nam = sprintf('corrected (%s%s%s)',repmat('harmonic',harmcorr),repmat('+',harmcorr&&vrelmode),repmat('relative',vrelmode));
			X(2).rgb = scolor(3);
			X(2).trd = 1;
		else
			X(1).nam = '';
			X(1).rgb = scolor(1);
			X(1).trd = 1;
		end
		for i = 1:numel(X)
			if isempty(X(i).d)
				X(i).d = nan(0,3);
			end
		end

		% makes the plot
		OPT.linestyle = pernode_linestyle;
		OPT.fontsize = fontsize;
		OPT.chnames = cmpnames;
		OPT.choffset = pernode_cmpoff;
		OPT.zoompca = pernode_timezoom;
		OPT.trendmindays = trendmindays;
		OPT.trendminperc = trendminperc;
		OPT.yscalevalue = disp_yscale;
		OPT.yscaleunit = 'cm';
		OPT.yscalefact = 100;
		[lre,rev] = smartplot(X,tlim,P.GTABLE(r),OPT);
		if ~isempty(rev)
			axes('Position',[.8,.02,.18,.07])
			plotcube([0,0,0],eye(3),[0,0,0],{'E','N','U'}), hold on
			plotcube([0,0,0],rev,[.8,0,0],{'1','2','3'}), hold off
			axis equal, axis tight, axis off, view(30,15)
		end

		if isok(P,'PLOT_GRID')
			grid on
		end

		if ~isempty(k)
			P.GTABLE(r).INFOS = {'Last measurement:',sprintf('{\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.GTABLE(r).TZ),'(median)',' ',' '};
			for i = 1:3
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%1.3f %s} (%1.3f) - Vel. = {\\bf%+1.1f \\pm %1.1f mm/yr}', ...
					i, enu{i},D(n).d(ke,i+4),D(n).CLB.un{i},rmedian(D(n).d(k,i+4)),lre(i,:))}];
			end
		end

		% makes graph
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
			E.t = D(n).t(k);
			E.d = [D(n).d(k,1:3),D(n).e(k,:),D(n).d(k,4)];
			E.header = {'Eastern(m)','Northern(m)','Up(m)','dE','dN','dU','Orbit'};
			E.infos = {};
			if harmcorr || vrelmode
				E.d = [E.d,	...
			   		D(n).d(k,5) - polyval([voffset(1)/365250,0],E.t - tlim(1)), ...
			   		D(n).d(k,6) - polyval([voffset(2)/365250,0],E.t - tlim(1)), ...
			   		D(n).d(k,7) - polyval([voffset(3)/365250,0],E.t - tlim(1)), ...
			   	];
				E.header = {E.header{:},'East_treat(m)','North_treat(m)','Up_treat(m)'};
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
	if any(strcmp(P.SUMMARYLIST,summary))

		if baselines_horizonly
			ib = 5:6;
		else
			ib = 5:7;
		end

		% builds a structure B containing indexes of each node pairs
		if isfield(P,'BASELINES_NODEPAIRS') && ~isempty(P.BASELINES_NODEPAIRS)
			pairgraphs = split(P.BASELINES_NODEPAIRS,';');
			np = 0;
			for nn = 1:numel(pairgraphs)
				pairs = split(pairgraphs{nn},',');
				if numel(pairs)>1
					kr = find(ismemberlist({N.FID},pairs(1)));
					kn = find(ismemberlist({N.FID},pairs(2:end)));
				end
				if ~isempty(kr) && ~isempty(kn)
					np = np + 1;
					B(np).kr = kr;
					B(np).kn = kn;
				else
					fprintf('%s: ** WARNING ** invalid node pairs for %s!\n',wofun,pairgraphs{nn});
				end
			end
		end
		% former behavior: will plot all possible pairs combinations,
		% eventually using only specific reference stations
		if ~exist('B','var')
			kn = selectnode(N,tlim,baselines_excluded,baselines_included,[targetll,baselines_excluded_target]);
			if isfield(P,'BASELINES_REF_NODELIST') && ~isempty(P.BASELINES_REF_NODELIST)
				kr = kn(ismemberlist({N(kn).FID},split(P.BASELINES_REF_NODELIST,',')));
			else
				kr = 1:numel(N);
			end
			for nn = 1:numel(kr)
				B(nn).kr = kr(nn);
				B(nn).kn = kn;
			end
		end

		figure
		if numel(B) > pagestanum
			p = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[p(1),p(2)*numel(kr)/pagestanum])
		end
		orient tall
		P.GTABLE(r).GTITLE = varsub(baselines_title,V);

		% builds the structure X for smartplot: X(n).d(:,i) where
		%   n = destination node and i = reference node
		X = repmat(struct('t',[],'d',[],'e',[],'w',[],'nam',[]),numel(N),1);
		aliases = cell(1,numel(N));
		ncolors = ones(size(aliases));
		refnames = cell(1,numel(B));
		for nn = 1:numel(B)
			n = B(nn).kr;
			k = D(n).G(r).k;
			tk = D(n).t(k);
			V.ref_node_alias = N(n).ALIAS;
			E.t = tk;
			E.d = zeros(size(tk,1),0);
			E.header = [];

			% station offset
			n0 = numel(B(nn).kn) - 1;
			staoffset = ((0:n0) - n0/2)*baselines_staoff;
			for nn2 = 1:numel(B(nn).kn)
				n2 = B(nn).kn(nn2);
				k2 = D(n2).G(r).k;
				V.node_name = N(n2).NAME;
				V.node_alias = N(n2).ALIAS;
				[~,kk] = unique(D(n2).t(k2));	% mandatory for interp1
				k2 = k2(kk);
				if n2 ~= n && numel(k)>1 && numel(k2)>1
					% exported baselines (text files) are based on the reference station time
					if isempty(baselines_interp_method)
						dk = nan(length(k),1);
						[tc,ka,kb] = intersect(D(n).t(k),D(n2).t(k2));
						dk(ka) = sqrt(sum((D(n2).d(k2(kb),ib) - D(n).d(k(ka),ib)).^2,2));
					else
						dk = sqrt(sum((interp1(D(n2).t(k2),D(n2).d(k2,ib),tk,baselines_interp_method) - D(n).d(k,ib)).^2,2));
					end
					dk = cleanpicks(dk,P)/siprefix(baselines_unit,'m');
					E.d = cat(2,E.d,dk);
					E.header = cat(2,E.header,{sprintf('%s-%s_(%s)',N(n).ALIAS,N(n2).ALIAS,baselines_unit)});

					% plotted baselines are based on the destination station time (because of smartplot structure)
					if isempty(baselines_interp_method)
						dd = nan(length(k2),1);
						[tc,ka,kb] = intersect(D(n).t(k),D(n2).t(k2));
						dd(kb) = sqrt(sum((D(n2).d(k2(kb),ib) - D(n).d(k(ka),ib)).^2,2));
					else
						[tk1,kk] = unique(tk);	% mandatory for interp1
						dd = sqrt(sum((D(n2).d(k2,ib) - interp1(tk1,D(n).d(k(kk),ib),D(n2).t(k2),baselines_interp_method)).^2,2));
					end
					X(n2).t = D(n2).t(k2);
					if isempty(X(n2).d)
						X(n2).d = nan(size(X(n2).t,1),numel(B));
					end
					X(n2).d(:,nn) = dd - rmedian(dd) + staoffset(nn2);
					X(n2).w = D(n2).d(k2,4);
					X(n2).nam = sprintf('%s',N(n2).ALIAS);
					X(n2).rgb = scolor(n2);
					X(n2).trd = 1;
				end
			end
			refnames{nn} = varsub(baselines_ylabel,V);

			% exports baseline data for reference n
			if isok(P.GTABLE(r),'EXPORTS')
				E.title = sprintf('%s: ref. %s',P.GTABLE(r).GTITLE,N(n).ALIAS);
				E.infos = {};
				mkexport(WO,sprintf('%s_%s_%s',summary,N(n).FID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
			end
		end

		% makes the plot
		OPT.linestyle = baselines_linestyle;
		OPT.fontsize = fontsize;
		OPT.chnames = refnames;
		OPT.choffset = baselines_refoff;
		OPT.zoompca = baselines_timezoom;
		OPT.trendmindays = trendmindays;
		OPT.trendminperc = trendminperc;
		OPT.yscalevalue = disp_yscale;
		OPT.yscaleunit = 'cm';
		OPT.yscalefact = 1/siprefix(OPT.yscaleunit,'m');
		smartplot(X,tlim,P.GTABLE(r),OPT);

		if isok(P,'PLOT_GRID')
			grid on
		end

		P.GTABLE(r).GSTATUS = [];
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end

	% --- Vectors map
	summary = 'VECTORS';
	if any(strcmp(P.SUMMARYLIST,summary))

		figure, orient tall

		P.GTABLE(r).GTITLE = varsub(vectors_title,V);
		P.GTABLE(r).INFOS = {' ',' ', ...
			sprintf('Referential: {\\bf%s}',itrf),sprintf('   E {\\bf%+g} mm/yr\n   N {\\bf%+g} mm/yr\n   U {\\bf%+g} mm/yr',velref), ...
			' ', ...
			sprintf('Mean velocity (%s):',itrf) ...
		};
		for i = 1:3
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('    %s = {\\bf%+1.2f mm/yr}',enu{i},mvv(i))}];
		end
		if vrelmode
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('Velocity ref. vector ({\\bf%s}):',mode)}];
			for i = 1:3
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('    %s = {\\bf%+1.2f mm/yr}',enu{i},voffset(i))}];
			end
		end

		% scale is adjusted to maximum horizontal vector or error amplitude (in mm/yr)
		if velscale > 0
			vmax = velscale;
		else
			vmax = rmax([abs(complex(tr(knv,1),tr(knv,2)));abs(complex(tre(knv,1),tre(knv,2)))/2]);
		end
		vscale = roundsd(vmax,1);
		vsc = .25*max([diff(latlim),diff(lonlim)*xyr,minkm/degkm])/vmax;

		ha = plot(geo(knv,2),geo(knv,1),'k.');  extaxes(gca,[.04,.08])
		hold on

		if isok(P,'VECTORS_TARGET_INCLUDED',1) && ~isempty(targetll)
			ha = [ha;plot(targetll(2),targetll(1),'k.','MarkerSize',.1)];
		end

		% plots velocity vectors first
		for nn = 1:numel(knv)
			n = knv(nn);
			if ~any(isnan([vsc,vmax])) && ~any(isnan(tr(n,1:2)))
				h = arrows(geo(n,2),geo(n,1),vsc*tr(n,1),vsc*tr(n,2),[arrowshape,xyr],'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n),'LineWidth',1);
				ha = cat(1,ha,h);
			end
		end
		% fixes the axis
		axis tight
		axl = axis;

		% determines X-Y limits of the map
		[ylim,xlim] = ll2lim(axl(3:4),axl(1:2),minkm,maxxy,border);

		set(gca,'XLim',xlim,'YLim',ylim);

		% loads DEM (P may contain user's defined DEM)
		DEM = loaddem(WO,[xlim,ylim],P);
		dem(DEM.lon,DEM.lat,DEM.z,'latlon',vectors_demopt{:})
		text(xlim(2),ylim(2)+.01*diff(ylim),DEM.COPYRIGHT,'HorizontalAlignment','right','VerticalAlignment','bottom','Interpreter','none','FontSize',6)

		% adds distance from target
		if ~isempty(targetll)
			pos = get(gca,'position');
			set(gca,'position',[pos(1),1-pos(4)-0.02,pos(3:4)]);

			[xx,yy] = meshgrid(DEM.lon,DEM.lat);
			DEM.dist = greatcircle(targetll(1),targetll(2),yy,xx);
			[c,h] = contour(DEM.lon,DEM.lat,DEM.dist,'k');
			set(h,'LineColor',modelling_topo_rgb,'LineWidth',.1);
			clabel(c,h,'FontSize',8,'Color',modelling_topo_rgb);
		end

		% plots stations
		target(geo(knv,2),geo(knv,1),7);

		% plots shapes
		if ~isempty(vectors_shape)
			h = plotbln(vectors_shape,.4*ones(1,3),[],.5);
			set(h,'Clipping','on')
		end

		% puts arrows on top
		h = get(gca,'Children');
		ko = find(ismember(h,ha),1);
		set(gca,'Children',[ha;h(1:ko-1)])

		% plots error ellipse, vertical component and station name
		for nn = 1:numel(knv)
			n = knv(nn);
			if ~isnan(any(tr(n,1:2)))
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
			% vertical component value (at the edge of arrow)
			if ~any(isnan(tr(n,:)))
				text(geo(n,2) + vsc*tr(n,1)/xyr,geo(n,1) + vsc*tr(n,2),svc,'Color',scolor(n),'FontSize',7,'FontWeight','bold', ...
					'VerticalAlignment','Middle','HorizontalAlignment','Center')
			elseif ~isnan(tr(n,3))
				text(geo(n,2),geo(n,1),svc,'Color',scolor(n),'FontSize',7,'FontWeight','bold', ...
					'VerticalAlignment','Middle','HorizontalAlignment','Center')
			end
			% station name
			text(geo(n,2),geo(n,1),stn,'FontSize',7,'FontWeight','bold', ...
				'VerticalAlignment','Middle','HorizontalAlignment','Center')
		end

		% plots legend scale
		xsc = xlim(1);
		ysc = ylim(2) + .04*diff(ylim);
		lsc = vscale*vsc;
		arrows(xsc,ysc,lsc,90,[arrowshape*vmax/vscale,xyr],'FaceColor','none','LineWidth',1,'Clipping','off');
		text(xsc + 1.1*lsc/xyr,ysc,sprintf('%g mm/yr',vscale),'FontWeight','bold')


		hold off

		% adds subplot horizontal amplitude vs distance
		if ~isempty(targetll)
			pos = get(gca,'position');
			axes('Position',[.5,.05,.45,pos(2)-0.02])
			plot(0,0)
			hold on
			sta_dist = greatcircle(targetll(1),targetll(2),geo(knv,1),geo(knv,2));
			sta_amp = sqrt(rsum(tr(knv,vectors_ampcmp).^2,2));
			sta_err = sqrt(rsum(tre(knv,vectors_ampcmp).^2,2));
			for nn = 1:numel(knv)
				h = errorbar(sta_dist(nn),sta_amp(nn),sta_err(nn),'.');
				set(h,'MarkerSize',15,'Color',scolor(knv(nn)),'LineWidth',0.1);
			end
			hold off
			set(gca,'FontSize',8)
			if any(~isnan(sta_amp))
				set(gca,'YLim',[0,max(sta_amp+sta_err)])
			end
			xlabel('Distance from Target (km)')
			ylabel({sprintf('Velocity Amplitude (%s)',vectors_ampstr),'(mm/yr)'})
		end


		P.GTABLE(r).GSTATUS = [];
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),struct('FIXEDPP',true,'INFOLINES',9))
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			E.infos = { ...
				sprintf('Velocity reference (%s):  E %+g mm/yr, N %+g mm/yr, U %+g mm/yr',datestr(velrefdate),velref), ...
				sprintf('Stations'' aliases: %s',strjoin(cellstr(cat(1,N(knv).ALIAS)),',')), ...
				};
			E.t = max(cat(1,D(knv).tfirstlast),[],2);
			E.d = [geo(knv,:),tr(knv,:),tre(knv,:)];
			E.header = {'Latitude','Longitude','Altitude','E_velocity(mm/yr)','N_Velocity(mm/yr)','Up_Velocity(mm/yr)','dEv(mm/yr)','dNv(mm/yr)','dUv(mm/yr)'};
			E.title = sprintf('%s {%s}',P.GTABLE(r).GTITLE,upper(sprintf('%s_%s',proc,summary)));
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end

	% --- Motion map
	summary = 'MOTION';
	if any(strcmp(P.SUMMARYLIST,summary))

		figure, orient tall
		ppos = get(gcf,'PaperPosition');

		P.GTABLE(r).GTITLE = varsub(motion_title,V);
		P.GTABLE(r).INFOS = {'{\itTime span}:', ...
			sprintf('     {\\bf%s}',datestr(tlim(1),'yyyy-mm-dd HH:MM')), ...
			sprintf('     {\\bf%s}',datestr(tlim(2),'yyyy-mm-dd HH:MM')), ...
			' '};

		% Selects nodes
		knv = selectnode(N,tlim,motion_excluded,motion_included,[targetll,motion_excluded_target]);

		if ~isempty(targetll)
			latlim = minmax([geo(knv,1);targetll(1)]);
			lonlim = minmax([geo(knv,2);targetll(2)]);
		else
			latlim = minmax(geo(knv,1));
			lonlim = minmax(geo(knv,1));
		end
		xyr = cosd(mean(latlim));

		% makes 3-D vectors
		clear X
		for nn = 1:numel(knv)
			n = knv(nn);
			k = isinto(D(n).t,tlim);
			if ~isempty(k)
				X(nn).t = D(n).t(k);
				X(nn).d = mavr(rf(D(n).d(k,5:7)),motion_filter);
			else
				X(nn).t = [];
				X(nn).d = [];
			end
		end
		alldata = cat(1,X.d);
		if ~isempty(alldata)
			dlim3 = minmax(alldata(:,3));
		else
			dlim3 = [0,1];
		end

		% scale is adjusted to maximum relative displacements (in m)
		if ~isempty(alldata) && (isempty(motion_scale) || ~(motion_scale > 0))
			mscale = max([diff(minmax(alldata(:,1))),diff(minmax(alldata(:,2))),diff(minmax(alldata(:,3)))]);
		elseif motion_scale > 0
			mscale = motion_scale/1e3;
		else
			mscale = 1;
		end
		vscale = roundsd(mscale,1);
		vsc = .3*max([diff(latlim),diff(lonlim)*xyr,minkm/degkm])/mscale; % scale in degree/m

		% --- X-Y view with background map
		pos = [.04,.35,.7,.65];
		axes('Position',pos)
		ha = plot(geo(knv,2),geo(knv,1),'k.');
		hold on
		if isok(P,'MOTION_TARGET_INCLUDED',1) && ~isempty(targetll)
			ha = [ha;plot(targetll(2),targetll(1),'k.','MarkerSize',.1)];
		end
		% plots motion displacements first
		for nn = 1:numel(knv)
			n = knv(nn);
			if ~isempty(X(nn).d)
				h = scatter(geo(n,2) + X(nn).d(:,1)*vsc/xyr,geo(n,1) + X(nn).d(:,2)*vsc,P.GTABLE(r).MARKERSIZE^2*pi,X(nn).t,'filled');
				ha = cat(1,ha,h);
			end
		end
		colormap(motion_colormap)
		caxis(tlim)
		% fixes the axis
		axis tight
		axl = axis;

		% determines X-Y limits of the map
		[ylim,xlim] = ll2lim(axl(3:4),axl(1:2),motion_minkm,1,border);

		set(gca,'XLim',xlim,'YLim',ylim);

		% loads DEM (P may contain user's defined DEM)
		DEM = loaddem(WO,[xlim,ylim],P);

		dem(DEM.lon,DEM.lat,DEM.z,'latlon','Position','northwest','AxisEqual','manual',motion_demopt{:})
		%text(xlim(2),ylim(2)+.01*diff(ylim),DEM.COPYRIGHT,'HorizontalAlignment','right','VerticalAlignment','bottom','Interpreter','none','FontSize',6)
		pos = get(gca,'Position');

		% plots stations
		%target(geo(knv,2),geo(knv,1),7);

		% plots shapes
		if ~isempty(vectors_shape)
			h = plotbln(vectors_shape,.4*ones(1,3),[],.5);
			set(h,'Clipping','on')
		end

		% puts motion particles on top
		h = get(gca,'Children');
		ko = find(ismember(h,ha),1);
		set(gca,'Children',[ha;h(1:ko-1)])

		% --- Z-Y profile
		axes('Position',[pos(1)+pos(3)+0.01,pos(2),0.23,pos(4)])
		plot([0,0],ylim,'-k','LineWidth',.1)
		hold on
		plot(repmat([dlim3(2),0]*vsc,numel(X),1)',repmat(geo(knv,1),1,2)','-k','LineWidth',.1)
		% plots motion displacements first
		for nn = 1:numel(knv)
			n = knv(nn);
			if ~isempty(X(nn).d)
				scatter(X(nn).d(:,3)*vsc,geo(n,1) + X(nn).d(:,2)*vsc,P.GTABLE(r).MARKERSIZE^2*pi,X(nn).t,'filled');
			end
		end
		box on
		hold off
		apos = get(gca,'Position');
		xyf = (diff(dlim3)*vsc/apos(3)/ppos(3))/(diff(ylim)/apos(4)/ppos(4));
		set(gca,'XLim',vsc*(dlim3(2)-[diff(dlim3)/xyf 0]),'YLim',ylim,'XDir','reverse','XTick',[],'YTick',[])
		colormap(motion_colormap)
		caxis(tlim)

		% --- X-Z profile
		axes('Position',[pos(1),pos(2)-0.18,pos(3),.17])
		plot(xlim,[0,0],'-k','LineWidth',.1)
		hold on
		plot(repmat(geo(knv,2),1,2)',repmat([dlim3(2),0]*vsc/xyr,numel(X),1)','-k','LineWidth',.1)
		% plots motion displacements first
		for nn = 1:numel(knv)
			n = knv(nn);
			if ~isempty(X(nn).d)
				scatter(geo(n,2) + X(nn).d(:,1)*vsc/xyr,X(nn).d(:,3)*vsc/xyr,P.GTABLE(r).MARKERSIZE^2*pi,X(nn).t,'filled');
			end
		end
		box on
		apos = get(gca,'Position');
		xyf = (diff(xlim)/apos(3)/ppos(3))/(diff(dlim3)*vsc/xyr/apos(4)/ppos(4));
		set(gca,'XLim',xlim,'YLim',vsc/xyr*(dlim3(2)-[diff(dlim3)*xyf 0]),'XTick',[],'YTick',[])
		colormap(motion_colormap)
		caxis(tlim)

		% displacement legend
		alim = get(gca,'YLim');
		xsc = xlim(1) + [0,vscale*vsc*xyr];
		ysc = repmat(alim(1)-diff(alim)/10,1,2);
		plot(xsc,ysc,'-k','Linewidth',2,'Clipping','off')
		text(mean(xsc),ysc(1),sprintf('%g mm',1e3*vscale),'Clipping','off', ...
			'HorizontalAlignment','center','VerticalAlignment','top','FontWeight','bold')
		hold off

		% additionnal legend
		xsc = xlim(1);
		ysc = alim(1) - 3*diff(alim)/10;
		if motion_filter > 1
			text(xsc,ysc,sprintf('Moving average filter = {\\bf %g}',motion_filter),'FontSize',8)
		end

		% time legend
		axes('position',[.8,0.06,0.17,0.3]);
		timecolorbar(.1,0,.15,.8,tlim,motion_colormap,8)
		set(gca,'XLim',[0,1],'YLim',[0,1])
		axis off

		P.GTABLE(r).GSTATUS = [];
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),struct('FIXEDPP',true,'INFOLINES',9))
		close
	end

	% --- Modelnet
	summary = 'MODELNET';
	if any(strcmp(P.SUMMARYLIST,summary))

		figure, orient tall

		% Selects nodes
		kn = selectnode(N,tlim,modelnet_excluded,modelnet_included,[targetll,modelnet_excluded_target]);

		% minimum number of stations must be a valid number
		modelnet_minsta = max(min(modelnet_minsta,length(kn)),1);

		if length(kn) > 0

			% makes the XYZ space
			if modelnet_target_included && ~isempty(targetll)
				latlim = minmax([geo(kn,1);targetll(1)]);
				lonlim = minmax([geo(kn,2);targetll(2)]);
			else
				latlim = minmax(geo(kn,1));
				lonlim = minmax(geo(kn,2));
			end
			lat0 = mean(latlim);
			lon0 = mean(lonlim);
			ysta = (geo(kn,1) - lat0)*degkm*1e3;
			xsta = (geo(kn,2) - lon0)*degkm(lat0)*1e3;
			zsta = geo(kn,3);

			wid = max(diff(latlim)*degkm*1e3,diff(lonlim)*degkm(lat0)*1e3) + 2*modelnet_border;
			mlim = linspace(-wid/2,wid/2,modelnet_gridsize);

			% loads SRTM DEM for basemap (with 10% extra borders)
			DEM = loaddem(WO,[lon0 + wid/(degkm(lat0)*1e3)*[-.6,.6],lat0 + wid/(degkm*1e3)*[-.6,.6]]);
			[xdem,ydem] = meshgrid(mlim);
			zdem = interp2((DEM.lon-lon0)*degkm(lat0)*1e3,(DEM.lat-lat0)*degkm*1e3,double(DEM.z),xdem,ydem);

			[xx,yy,zz] = meshgrid(mlim,mlim,-modelnet_dslice);
			sz = size(xx);
	       	nn = length(xsta);

	       	% computes Green's functions at stations for a unit volume of 1 m3
	       	[asou,rsou] = cart2pol(repmat(reshape(xsta,1,1,1,nn),[sz,1])-repmat(xx,[1,1,1,nn]), ...
	           	repmat(reshape(ysta,1,1,1,nn),[sz,1])-repmat(yy,[1,1,1,nn]));
	       	[ur,uz] = mogi(rsou,repmat(reshape(zsta,1,1,1,nn),[sz,1]) - repmat(zz,[1,1,1,nn]),1);
	       	[ux,uy] = pol2cart(asou,ur);

			% source dVs for minimum displacements on X,Y,Z radius within an ellipsoid defined by
			% mindisp semi-axis, stations sorted in ascending order of dV
			[th,ph,rh] = cart2sph(ux,uy,uz);
			vv = sort(ellradius(modelnet_mindisp/1e3,th,ph)./rh,4);
			vv = min(vv(:,:,:,modelnet_minsta),[],4);
	       	vv(zz>=repmat(zdem,[1,1,sz(3)])) = NaN; % removes "air-sources"

			dvlim = modelnet_dvlim;
			if any(isnan(dvlim)) || numel(dvlim) ~= 2
				dvlim = minmax(vv);
			end

			axes('Position',[0.03,0.1,0.7,0.8])
	   		slice(xx,yy,zz,vv,[],[],-modelnet_dslice,'nearest')
	   		shading flat
	   		hold on
	   		plot3(xsta,ysta,-modelnet_dslice(1)*ones(size(xsta))+1,modelnet_mks{:})
			if ~isempty(targetll) && modelnet_target_included
				xt = (targetll(2)-lon0)*degm*cosd(lat0);
				yt = (targetll(1)-lat0)*degm;
				plot3([xt,xt],[yt,yt],-modelnet_dslice([1,end]),':k')
			end
	   		for z = modelnet_dslice
	   			c = contourc(mlim,mlim,zdem);
	   			pcontour3(c,-z+1,'Color',.99*ones(1,3),'LineWidth',.1);
	   			c = contourc(mlim,mlim,zdem,[1,1]); % coast line at 1m elevation
	   			pcontour3(c,-z+1,'Color',.99*ones(1,3),'LineWidth',1);
	   			vmm = minmax(interp3(xx,yy,zz,vv,xx(:,:,1),yy(:,:,1),-z*ones(modelnet_gridsize)));
				label = sprintf(' {\\bfDepth = %s m}\n \\DeltaV = %s to %s m^3',num2tex(z), ...
					num2tex(roundsd(vmm(1),2)),num2tex(roundsd(vmm(2),2)));
				if ~isempty(targetll) && modelnet_target_included
	   				vi = interp3(xx,yy,zz,vv,xt,yt,-z);
					label = [label,sprintf('\n\n \\DeltaV_{target} = {\\bf%s m^3}',num2tex(roundsd(vi,2)))];
				end
	   			text(cosd(modelnet_vazel(1))*wid/sqrt(2),sind(modelnet_vazel(1))*wid/sqrt(2),-z,label, ...
	   				'VerticalA','m','FontSize',10)
	   		end

			% adds North compass at first slice
			wc = wid/5;
			xc = mlim(1)-wid/10;
			yc = mlim(end)-wc;
			h = comprose(xc,yc,1,wc,0,'LineWidth',.1,'FaceColor',zeros(1,3));
			moveobj(h,[0,0,-modelnet_dslice(1)]);

			% adds horizontal distance scale at last slice
			ws = dscale(wid/3);
			xs = mlim(1);
			ys = mlim(1)-wid/20;
			zs = -modelnet_dslice(end);
			pap = get(gcf,'PaperPosition').*get(gca,'Position');
			as = -modelnet_vazel(1)*sind(modelnet_vazel(2))/(pap(3)/pap(4));
			plot3(xs+[0,0,ws,ws],ys-wid*[1/40,0,0,1/40],zs*ones(1,4),'k','LineWidth',1)
			if ws < 1e3
				ts = sprintf('%g m',ws);
			else
				ts = sprintf('%g km',ws/1e3);
			end
			text(xs+ws/2,ys,zs,ts,'FontSize',10,'FontWeight','b', ...
				'Rotation',as,'Horiz','c','Verti','top')

	   		hold off
	   		view(modelnet_vazel)
			set(gca,'XLim',minmax(mlim),'YLim',minmax(mlim),'ZLim',minmax(-modelnet_dslice))
			axis tight off
			caxis(dvlim)
		end
	   	axes('position',[.55,.07,.4,.02])
	   	pcolor(linspace(dvlim(1),dvlim(2)),[0,1],repmat(linspace(dvlim(1),dvlim(2)),2,1)), shading flat
	   	set(gca,'YTick',[],'TickDir','out','FontSize',8)
	   	caxis(dvlim)
	   	xlabel('Detactable \DeltaV (m^3)')

		colormap(modelnet_cmap)

		P.GTABLE(r).GTITLE = varsub(modelnet_title,V);
		P.GTABLE(r).INFOS = {'{\itTime span}:', ...
			sprintf('     {\\bf%s}',datestr(tlim(1),'yyyy-mm-dd HH:MM')), ...
			sprintf('     {\\bf%s}',datestr(tlim(2),'yyyy-mm-dd HH:MM')), ...
			' ', ...
			sprintf('{\\bf%d}/%d stations',length(kn),numel(N)), ...
	   		sprintf('minimum displacements at {\\bf%d} stations:',modelnet_minsta), ...
	   		sprintf('E: {\\bf%g mm}, N: {\\bf%g mm}, U: {\\bf%g mm}',modelnet_mindisp), ...
			' ', ...
			};
		P.GTABLE(r).GSTATUS = [];
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),struct('INFOLINES',4))
		close
	end

	% --- common part for MODELLING and MODELTIME
	if any(ismember(P.SUMMARYLIST,{'MODELLING','MODELTIME'}))

		refstring = 'Modelling by Beauducel et al./IPGP';

		% selects stations
		kn = selectnode(N,tlim,modelling_excluded,modelling_included,[targetll,modelling_excluded_target]);

		modelopt.msigp = erf(modelopt.msig/sqrt(2));

		% center coordinates
		if ~isempty(targetll)
			latlim = minmax([geo(kn,1);targetll(1)]);
			lonlim = minmax([geo(kn,2);targetll(2)]);
			lat0 = targetll(1);
			lon0 = targetll(2);
		else
			latlim = minmax(geo(kn,1));
			lonlim = minmax(geo(kn,2));
			targetll = [mean(latlim),mean(lonlim)];
			lat0 = mean(latlim);
			lon0 = mean(lonlim);
		end

		wid = max(diff(latlim)*degkm*1e3,diff(lonlim)*degkm(lat0)*1e3) + bm;
		wbest = wid/20;

		ysta = (geo(kn,1) - lat0)*degkm*1e3;
		xsta = (geo(kn,2) - lon0)*degkm(lat0)*1e3;
		zsta = geo(kn,3);

		% loads SRTM DEM for basemap (with 10% extra borders)
		DEM = loaddem(WO,[mean(lonlim) + wid/(degkm(lat0)*1e3)*[-.6,.6],mean(latlim) + wid/(degkm*1e3)*[-.6,.6]]);

		% makes model space
		xlim = linspace(0,wid,rr) - wid/2 - (lon0 - mean(lonlim))*degkm(lat0)*1e3;
		ylim = linspace(0,wid,rr) - wid/2 - (lat0 - mean(latlim))*degkm*1e3;
		zlim = linspace(-maxdep,roundsd(double(max(DEM.z(:))),2,'ceil'),rr);
		if max(abs([xlim,ylim,zlim])) >= tickfactorlim
			distunit = 'km';
			distfactor = 1e-3;
		else
			distunit = 'm';
			distfactor = 1;
		end

		[xdem,ydem] = meshgrid(xlim,ylim);
		zdem = interp2((DEM.lon-lon0)*degm*cosd(lat0),(DEM.lat-lat0)*degm,double(DEM.z),xdem,ydem);
		mmz = minmax(zdem);

		[xx,yy,zz] = meshgrid(xlim,ylim,zlim);

		% station coordinates relative to target and target relative to network center
		xs = xsta - (targetll(2) - lon0)*degm*cosd(lat0);
		ys = ysta - (targetll(1) - lat0)*degm;
		modelopt.targetxy = (targetll([2,1]) - [lon0,lat0]).*[cosd(lat0),1]*degm;

	end

	% --- Modelling
	summary = 'MODELLING';
	if any(strcmp(P.SUMMARYLIST,summary))

		% loop on the model source type
		for mst = split(modelling_source_type,',')
			mt = lower(char(mst));

		% makes (or not) the relative data array
		d = [tr(kn,:),tre(kn,:)];
		knn = find(~isnan(d(:,1)));
		if ~isempty(knn) && (modelling_force_relative || (modrelauto && (azgap(xs(knn),ys(knn)) < 150 || numel(find(knn)) > 2)))
			% computes a mean velocity vector (horizontal only)
			mvv = rsum(tr(kn,:)./tre(kn,:))./rsum(1./tre(kn,:));
			d(:,1:3) = d(:,1:3) - repmat([mvv(1:2),0],numel(kn),1);
			if isok(P,'DEBUG')
				fprintf('---> Modelling vector relative forced by (%g,%g).\n',mvv(1:2));
			end
		end

		% computes absolute displacement in mm (from velocity in mm/yr)
		d = d*diff(tlim)/365.25;

		modelopt.verbose = '';
		d(:,4:6) = adjerrors(d,modelopt);

		[e0,n0,z0] = ll2utm(lat0,lon0);

		% --- computes the model !
		switch lower(mt)
		case 'pcdm'
			summary = 'MODELLING_pCDM';
			M = invpcdm(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt,PCDM);
			if numel(M) > 1 && M(end).m0 < M(1).m0
				[mm,imm] = max(cat(4,M.mm),[],4);
				% volume for maximum probability
				vv = M(1).vv;
				for m = 2:numel(M)
					vv(imm==m)=M(m).vv(imm==m);
				end
				m0 = cat(1,M.m0);
				ux = sum(cat(2,M.ux),2);
				uy = sum(cat(2,M.uy),2);
				uz = sum(cat(2,M.uz),2);
				ex = cat(1,M.ex);
				ey = cat(1,M.ey);
				ez = cat(1,M.ez);
				ws = cat(1,M.ws);
				ev = cat(1,M.ev)*1e6;
				pbest = cat(1,M.pbest);
				vv0 = pbest(:,7)*1e6; % best dV in m3
			else
				M = M(1);
				mm = M.mm;
				vv = M.vv;
				m0 = M.m0;
				ux = M.ux;
				uy = M.uy;
				uz = M.uz;
				ex = M.ex;
				ey = M.ey;
				ez = M.ez;
				ws = M.ws;
				ev = M.ev*1e6;
				pbest = M.pbest;
				vv0 = pbest(7)*1e6; % best dV in m3
				if isnan(m0)
					pbest = nan(size(pbest));
				end
			end
			if numel(PCDM.random_sampling) == 1
				nmodels = PCDM.random_sampling*PCDM.iterations;
			else
				nmodels = sum(PCDM.random_sampling);
			end
			[lats,lons] = utm2ll(e0+pbest(:,1),n0+pbest(:,2),z0);
		otherwise
			summary = 'MODELLING';
			M = invmogi(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt);
			if numel(M) > 1 && M(end).m0 < M(1).m0
				[mm,imm] = max(cat(4,M.mm),[],4);
				% volume for maximum probability
				vv = M(1).vv;
				for m = 2:numel(M)
					vv(imm==m)=M(m).vv(imm==m);
				end
				m0 = cat(1,M.m0);
				ux = sum(cat(2,M.ux),2);
				uy = sum(cat(2,M.uy),2);
				uz = sum(cat(2,M.uz),2);
				ex = cat(1,M.ex);
				ey = cat(1,M.ey);
				ez = cat(1,M.ez);
				ws = cat(1,M.ws);
				ev = cat(1,M.ev)*1e6;
				pbest = cat(1,M.pbest);
				vv0 = pbest(:,4)*1e6; % best dV in m3
			else
				M = M(1);
				mm = M.mm;
				vv = M.vv;
				m0 = M.m0;
				ux = M.ux;
				uy = M.uy;
				uz = M.uz;
				ex = M.ex;
				ey = M.ey;
				ez = M.ez;
				ws = M.ws;
				ev = M.ev*1e6;
				pbest = M.pbest;
				vv0 = pbest(4)*1e6; % best dV in m3
			end
			[lats,lons] = utm2ll(e0+pbest(:,1),n0+pbest(:,2),z0);
			nmodels = numel(mm);
		end

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			E.t = max(cat(1,D(kn).tfirstlast),[],2);
			E.d = [geo(kn,:),d,ux,uy,uz];
			E.header = {'Latitude','Longitude','Altitude','E_obs(mm)','N_obs(mm)','Up_obs(mm)','dE(mm)','dN(mm)','dU(mm)', ...
				                                      'E_mod(mm)','N_mod(mm)','Up_mod(mm)'};
			if any(~isnan(m0))
				E.infos = { ...
					sprintf('Stations'' aliases: %s',strjoin(cellstr(cat(1,N(kn).ALIAS)),',')), ...
					'', ...
				};
				switch lower(mt)
				case 'pcdm'
					for m = 1:numel(M)
						E.infos = cat(2,E.infos, ...
							sprintf('Least bad pCDM model #%d:',m), ...
							sprintf('latitude = %g N in [%+g , %+g] km',lats(m), roundsd(ey(m,:)/1e3,2)), ...
							sprintf('longitude = %g E in [%+g , %+g]',lons(m), roundsd(ex(m,:)/1e3,2)), ...
							sprintf('depth = %1.1f km in [%1.1f , %1.1f]',pbest(m,3),-fliplr(ez(m,:))/1e3), ...
							sprintf('DeltaV = %+g m^3 in [%+g , %+g]',roundsd([vv0(m,:),ev(m,:)],2)), ...
							sprintf('A = %1.2f / B = %1.2f',pbest(m,8:9)), ...
							sprintf('shape = %s',pcdmdesc(pbest(m,8),pbest(m,9))), ...
							sprintf('OmegaX = %+2.0f / OmegaY = %+2.0f / OmegaZ = %+2.0f',pbest(m,4:6)), ...
							' ');
					end
				otherwise
					for m = 1:numel(M)
						E.infos = cat(2,E.infos, ...
							sprintf('Least bad isotropic model #%d:',m), ...
							sprintf('latitude = %g N in [%+g , %+g] km',lats(m), roundsd(ey(m,:)/1e3,2)), ...
							sprintf('longitude = %g E in [%+g , %+g] km',lons(m), roundsd(ex(m,:)/1e3,2)), ...
							sprintf('depth = %1.1f km in [%1.1f , %1.1f]',-[pbest(m,3),fliplr(ez(m,:))]/1e3), ...
							sprintf('DeltaV = %+g m^3 in [%+g , %+g]',roundsd([vv0(m,:),ev(m,:)],2)), ...
							' ');
					end
				end
			end
			E.title = sprintf('%s {%s}',P.GTABLE(r).GTITLE,upper(sprintf('%s_%s',proc,summary)));
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end

		if isok(P,'MODELLING_EXPORT_MAT')
			f = sprintf('%s_%s.mat',summary,P.GTABLE(r).TIMESCALE);
			fprintf('%s: saving workspace in %s...',wofun,f);
			save(sprintf('%s/%s/%s',P.GTABLE(r).OUTDIR,WO.PATH_OUTG_EXPORT,f),'-v6')
			fprintf(' done.\n');
		end

		% adjusts unit for volume variation
		vunit = 'm^3';
		if all(isfinite(vv0)) && any(abs(vv0) > 0.5e6)
			vfactor = 1e6;
			vunit = ['M',vunit];
		else
			vfactor = 1;
		end

		mhor = max(mm,[],3);
		if strcmp(modelling_coloref,'volpdf')
			%clim = [-1,1]*max(mhor(:))*(ws/500)^.5;
			clim = [-1,1]*max(mm(:));
		else
			%clim = [0,max(mhor(:))*(ws/500)^.5];
			%clim = [min(mhor(:)),max(mhor(:))];
			clim = minmax(mm);
			if diff(clim)<=0
				clim = [0,1];
			end
		end

		% computes the maximum displacement for vector scale
		%if modelopt.horizonly
		%	%vmax = rmax([abs(complex(d(:,1),d(:,2)));abs(complex(d(:,4),d(:,5)))/2]);
		%	vmax = rmax(abs(reshape(d(:,1:2),1,[])))/2;
		%else
			vmax = rmax(abs(reshape(d(:,1:3),[],1)))/2;
		%end
		if modelling_vmax_mm > 0
			vmax = modelling_vmax_mm;
		end
		vsc = modelling_vmax_ratio*min([diff(minmax(xlim)),diff(minmax(ylim)),diff(minmax(zlim))])/vmax;

		% for graphical purpose only: set NaN components in data and model to 0
		if plotnancomp
			k = find(any(~isnan(d(:,1:3)),2));
			if ~isempty(k)
				tmp = d(k,1:3);
				knan = isnan(tmp);
				tmp(knan) = 0;
				d(k,1:3) = tmp;
				ux(k(knan(:,1))) = 0;
				uy(k(knan(:,2))) = 0;
				uz(k(knan(:,3))) = 0;
			end
		end

		% --- plots the results
		figure, orient tall

		stasize = 6;
		arrowshapemod = [.1,.1,.08,.02];
		arrowshapedat = [.1,.1,.08,.04];
		arrowref = vsc*vmax;

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
		[~,h] = contour(xlim,ylim,zdem,0:200:mmz(2));
		set(h,'Color',modelling_topo_rgb,'LineWidth',.1);
		[~,h] = contour(xlim,ylim,zdem,[0:1000:mmz(2),0:-1000:mmz(1)]);
		set(h,'Color',modelling_topo_rgb,'LineWidth',.75);
		% plots shapes
		if ~isempty(modelling_shape)
			plotbln(modelling_shape,.4*ones(1,3),[],.5);
		end
		target(xsta,ysta,stasize)
		if ~isnan(vmax)
			arrows(xsta,ysta,vsc*d(:,1),vsc*d(:,2),arrowshapedat,'Cartesian','Ref',arrowref,'Clipping',vclip)
			ellipse(xsta + vsc*d(:,1),ysta + vsc*d(:,2),vsc*d(:,4),vsc*d(:,5),'LineWidth',.2,'Clipping','on')
			arrows(xsta,ysta,vsc*ux,vsc*uy,arrowshapemod,'Cartesian','Ref',arrowref, ...
				'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping',vclip)
			if plotresidual
				arrows(xsta,ysta,vsc*(d(:,1)-ux),vsc*(d(:,2)-uy),arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping',vclip)
			end
		end
		if ~isempty(targetll)
			plot(repmat(modelopt.targetxy(1),1,2),ylim([1,end]),':k')
			plot(xlim([1,end]),repmat(modelopt.targetxy(2),1,2),':k')
			if modelopt.apriori_horizontal > 0
				acircle = linspace(0,2*pi);
				plot(modelopt.targetxy(1)+modelopt.apriori_horizontal*1e3*cos(acircle), ...
				     modelopt.targetxy(2)+modelopt.apriori_horizontal*1e3*sin(acircle), ...
				     ':k')
			end
		end
		%axis equal; axis tight
		if plotbest && any(~isnan(m0))
			switch lower(mt)
			case 'pcdm'
				plotpcdm(pbest(:,[1:6,8,9]),wbest,'xy','EdgeColor',plotbest_col);
			otherwise
				plot(pbest(:,1),pbest(:,2),plotbest_opt{:},'MarkerEdgeColor',plotbest_col)
			end
		end
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(ylim), ...
			'Position',[0.01,pos(2),pos(3) + pos(1) - 0.01,pos(4)],'YAxisLocation','right','FontSize',6)
		tickfactor(distfactor)
		xlabel(sprintf('Origin (0,0) is lon {\\bf%g E}, lat {\\bf%g N} - Distances in %s',lon0,lat0,distunit),'FontSize',8)

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
			arrows(zsta,ysta,vsc*d(:,3),vsc*d(:,2),arrowshapedat,'Cartesian','Ref',arrowref,'Clipping',vclip)
			ellipse(zsta + vsc*d(:,3),ysta + vsc*d(:,2),vsc*d(:,6),vsc*d(:,5),'LineWidth',.2,'Clipping','on')
			arrows(zsta,ysta,vsc*uz,vsc*uy,arrowshapemod,'Cartesian','Ref',arrowref, ...
				'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping',vclip)
			if plotresidual
				arrows(zsta,ysta,vsc*(d(:,3)-uz),vsc*(d(:,2)-uy),arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping',vclip)
			end
		end
		if ~isempty(targetll)
			plot(zlim([1,end]),repmat(modelopt.targetxy(2),1,2),':k')
		end
		if numel(modelopt.apriori_depth) == 2
			plot(repmat(-modelopt.apriori_depth(1),1,2),ylim([1,end]),':k')
		end
		if plotbest && any(~isnan(m0))
			switch lower(mt)
			case 'pcdm'
				plotpcdm(pbest(:,[1:6,8,9]),wbest,'zy','EdgeColor',plotbest_col);
			otherwise
				plot(pbest(:,3),pbest(:,2),plotbest_opt{:},'MarkerEdgeColor',plotbest_col)
			end
		end
		plot(max(max(zdem,[],3),[],2)',ylim,'-k')
		hold off
		set(gca,'XLim',minmax(zlim),'YLim',minmax(ylim),'XDir','reverse','XAxisLocation','top','YAxisLocation','right','YTick',[],'FontSize',6)
		tickfactor(distfactor)

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
			arrows(xsta,zsta,vsc*d(:,1),vsc*d(:,3),arrowshapedat,'Cartesian','Ref',arrowref,'Clipping',vclip)
			ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
			arrows(xsta,zsta,vsc*ux,vsc*uz,arrowshapemod,'Cartesian','Ref',arrowref, ...
				'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping',vclip)
			if plotresidual
				arrows(xsta,zsta,vsc*(d(:,1)-ux),vsc*(d(:,3)-uz),arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping',vclip)
			end
		end
		if ~isempty(targetll)
			plot(repmat(modelopt.targetxy(1),1,2),zlim([1,end]),':k')
		end
		if numel(modelopt.apriori_depth) == 2
			plot(xlim([1,end]),repmat(-modelopt.apriori_depth(1),1,2),':k')
		end
		if plotbest && any(~isnan(m0))
			switch lower(mt)
			case 'pcdm'
				plotpcdm(pbest(:,[1:6,8,9]),wbest,'xz','EdgeColor',plotbest_col);
			otherwise
				plot(pbest(:,1),pbest(:,3),plotbest_opt{:},'MarkerEdgeColor',plotbest_col)
			end
		end
		plot(xlim,max(max(zdem,[],3),[],1),'-k')
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(zlim),'YAxisLocation','right','XTick',[],'FontSize',6)
		tickfactor(distfactor)
		xlabel(refstring)

		if strcmp(modelling_coloref,'volpdf')
			polarmap(modelling_cmap,modelling_colorshading);
		else
			shademap(modelling_cmap,modelling_colorshading)
		end

		% legends
		% - model parameters
		axes('position',[0.68,0.11,0.3,0.3])
		src_multi = '';
		if modelopt.multi > 1
			src_multi = sprintf('\\times %d',modelopt.multi);
		end
		info = { ...
			' ', ...
			sprintf('model type = {\\bf%s%s}',mt,src_multi), ...
			sprintf('model space = {\\bf%s}',num2tex(nmodels)), ...
			sprintf('misfit norm = {\\bf%s}',modelopt.misfitnorm), ...
			sprintf('uncertainty = {\\bf%g \\sigma (%1.1f%%)}',modelopt.msig,modelopt.msigp*100), ...
		};
		if any(modelopt.enuerror ~= 1)
			info = cat(2,info,sprintf('error E,N,U ratio = {\\bf%g,%g,%g}',modelopt.enuerror));
		end
		if modelopt.horizonly
			info = cat(2,info,'misfit mode = {\bfhorizontal only}');
		end
		if numel(modelopt.apriori_depth) == 2
			info = cat(2,info,sprintf('a priori depth = {\\bf%g \\pm %g km}',roundsd(modelopt.apriori_depth/1e3,2)));
		end
		if modelopt.apriori_horizontal > 0
			info = cat(2,info,sprintf('a priori horiz. STD = {\\bf%g km}',modelopt.apriori_horizontal));
		end
		% displays info for best model(s)
		if any(~isnan(m0))
			%info = cat(2,info,' ',sprintf('   {\\itLeast bad source (%1.1f%%)}:',modelopt.msigp*100));
			switch lower(mt)
			case 'pcdm'
				bstab = {''; ...
					'lat N'; ...
					'lon E'; ...
					'depth (km)'; ...
					sprintf('\\DeltaV (%s)',vunit); ...
					sprintf('{\\itQ} (m^3/s)'); ...
					'A'; ...
					'B'; ...
					'shape'; ...
					'\OmegaX'; ...
					'\OmegaY'; ...
					'\OmegaZ'; ...
					'misfit (mm)'};
				for m = 1:numel(M)
					bstab{1,m+1} = sprintf('Source #%d',m);
					bstab{2,m+1} = sprintf('{\\bf%g}',lats(m));
					bstab{3,m+1} = sprintf('{\\bf%g}',lons(m));
					if plotbest
						bstab{4,m+1} = sprintf('{\\bf%g \\pm %g}', ...
							roundsd(-pbest(m,3)/1e3,2),roundsd(abs(diff(ez(m,:)))/2e3,1));
						bstab{5,m+1} = sprintf('{\\bf%+g \\pm %g}', ...
							roundsd(vv0(m)/vfactor,2),roundsd(abs(diff(ev(m,:)))/2/vfactor,1));
						bstab{6,m+1} = sprintf('%+g \\pm %g',roundsd(vv0(m)/diff(tlim)/86400,2), ...
							roundsd(abs(diff(ev(m,:)))/2/diff(tlim)/86400,1));
					else
						bstab{4,m+1} = sprintf('{\\bf%g} to {\\bf%g}',roundsd(minmax(-(pbest(m,3)+ez(m,:))/1e3),2));
						bstab{5,m+1} = sprintf('{\\bf%+g} to {\\bf%+g}',roundsd(minmax(ev(m,:)/vfactor),2));
						bstab{6,m+1} = sprintf('%+g to %+g',roundsd(minmax(ev(m,:)/diff(tlim)/86400),2));
					end
					bstab{7,m+1} = sprintf('{\\bf%1.2f}',pbest(m,8));
					bstab{8,m+1} = sprintf('{\\bf%1.2f}',pbest(m,9));
					bstab{9,m+1} = sprintf('{\\bf%s}',pcdmdesc(pbest(m,8),pbest(m,9)));
					bstab{10,m+1} = sprintf('{\\bf%+2.0f\\circ}',pbest(m,4));
					bstab{11,m+1} = sprintf('{\\bf%+2.0f\\circ}',pbest(m,5));
					bstab{12,m+1} = sprintf('{\\bf%+2.0f\\circ}',pbest(m,6));
					bstab{13,m+1} = sprintf('{\\bf%g}',roundsd(m0(m),2));
				end
				rowlim = [.7,.1];
			otherwise
				bstab = {''; ...
					'lat N'; ...
					'lon E'; ...
					'depth (km)'; ...
					sprintf('\\DeltaV (%s)',vunit); ...
					sprintf('{\\itQ} (m^3/s)'); ...
					'misfit (mm)'};
				for m = 1:numel(M)
					bstab{1,m+1} = sprintf('Source #%d',m);
					bstab{2,m+1} = sprintf('{\\bf%g}',lats(m));
					bstab{3,m+1} = sprintf('{\\bf%g}',lons(m));
					if plotbest
						bstab{4,m+1} = sprintf('{\\bf%g \\pm %g}', ...
							roundsd(-pbest(m,3)/1e3,2),roundsd(abs(diff(ez(m,:)))/2e3,1));
						bstab{5,m+1} = sprintf('{\\bf%+g \\pm %g}', ...
							roundsd(vv0(m)/vfactor,2),roundsd(abs(diff(ev(m,:)))/2/vfactor,1));
						bstab{6,m+1} = sprintf('%+g',roundsd(vv0(m)/diff(tlim)/86400,2));
					else
						bstab{4,m+1} = sprintf('{\\bf%g} to {\\bf%g}',roundsd(minmax(-(pbest(m,3)+ez(m,:))/1e3),2));
						bstab{5,m+1} = sprintf('{\\bf%+g} to {\\bf%+g}', ...
							roundsd(minmax(ev(m,:)/vfactor),2));
						bstab{6,m+1} = sprintf('%+g to %+g',roundsd(minmax(ev(m,:)/diff(tlim)/86400),2));
					end
					bstab{7,m+1} = sprintf('{\\bf%g}',roundsd(m0(m),2));
				end
				rowlim = [.7,.3];
			end
			plottable(bstab,[.25,.5,.85],rowlim,'rcc','FontSize',8)
		else
			info = cat(2,info,' ','   No source found.');
		end
		text(0,1.1,info,'HorizontalAlignment','left','VerticalAlignment','top','FontSize',8)
		axis([0,1,0,1]); axis off

		% - probability colorscale
		axes('position',[0.33,.05,.25,.015])
		if strcmp(modelling_coloref,'volpdf')
			imagesc(linspace(-1,1,256),[0;1],repmat(linspace(0,1,256),2,1))
			set(gca,'XTick',[-1,0,1],'YTick',[],'XTickLabel',{'High (Deflate)','Low','High (Inflate)'},'TickDir','out','FontSize',8)
		else
			imagesc(linspace(0,1,256),[0;1],repmat(linspace(0,1,256),2,1))
			set(gca,'XTick',[0,1],'YTick',[],'XTickLabel',{'Low','High'},'TickDir','out','FontSize',8)
		end
		title('Model Probability','FontSize',10)

		% - data/model arrows scale
		axes('position',[0.55,0.05,0.3,0.03])
		dxl = diff(xlim([1,end]))*0.3/0.6142;
		dyl = diff(ylim([1,end]))*0.03/0.3;
		hold on
		if ~isnan(arrowref)
			vlegend = roundsd(2*vmax,1);
			arrows(dxl/2,dyl,vsc*vlegend,0,arrowshapedat,'Cartesian','Ref',arrowref,'Clipping','off')
			text(dxl/2 + vsc*vlegend/2,dyl,sprintf('{\\bf%g mm}',vlegend),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8)
			%ellipse(xsta + vsc*d(:,1),zsta + vsc*d(:,3),vsc*d(:,4),vsc*d(:,6),'LineWidth',.2,'Clipping','on')
			arrows(dxl/2,dyl/2,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref,'EdgeColor',modarrcol,'FaceColor',modarrcol,'Clipping','off')
			text([dxl/2,dxl/2],[dyl,dyl/2],{'data   ','model   '},'HorizontalAlignment','right','FontSize',8)
			if plotresidual
				arrows(dxl/2,0,vsc*vlegend,0,arrowshapemod,'Cartesian','Ref',arrowref, ...
					'EdgeColor',resarrcol,'FaceColor',resarrcol,'Clipping','off')
				text(dxl/2,0,'residual   ','HorizontalAlignment','right','FontSize',8)
			end
		end
		axis off
		hold off
		set(gca,'XLim',[0,dxl],'YLim',[0,dyl])

		P.GTABLE(r).GTITLE = varsub(modelling_title,V);
		P.GTABLE(r).INFOS = {'{\itTime span}:', ...
			sprintf('     {\\bf%s}',datestr(tlim(1),'yyyy-mm-dd HH:MM')), ...
			sprintf('     {\\bf%s}',datestr(tlim(2),'yyyy-mm-dd HH:MM')), ...
			' '};
		P.GTABLE(r).GSTATUS = [];
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),struct('FIXEDPP',true))
		close
		end
	end

	% --- Modelling in time
	summary = 'MODELTIME';
	if any(strcmp(P.SUMMARYLIST,summary))
		% remakes the model space
		if modeltime_gridsize ~= rr
			rr = modeltime_gridsize;
			xlim = linspace(0,wid,rr) - wid/2 - (lon0 - mean(lonlim))*degkm(lat0)*1e3;
			ylim = linspace(0,wid,rr) - wid/2 - (lat0 - mean(latlim))*degkm*1e3;
			zlim = linspace(-maxdep,roundsd(double(max(DEM.z(:))),2,'ceil'),rr);
			[xdem,ydem] = meshgrid(xlim,ylim);
			zdem = interp2((DEM.lon-lon0)*degm*cosd(lat0),(DEM.lat-lat0)*degm,double(DEM.z),xdem,ydem);
			[xx,yy,zz] = meshgrid(xlim,ylim,zlim);
		end
		dt = max(modeltime_sampling,ceil(numel(modeltime_period)*diff(tlim)/modeltime_max/modeltime_sampling)*modeltime_sampling);

		% loop on the model source type
		for mst = split(modeltime_source_type,',')
			mt = lower(char(mst));

			switch mt
			case 'pcdm'
				summary = 'MODELTIME_pCDM';
				PCDM.random_sampling = field2num(P,'MODELTIME_PCDM_RANDOM_SAMPLING',PCDM.random_sampling);
			otherwise
				summary = 'MODELTIME';
			end

		info = { ...
			' ', ...
			sprintf('model type = {\\bf%s}',mst{1}), ...
			sprintf('model space = {\\bf%s}',num2tex(rr^3)), ...
			sprintf('misfit norm = {\\bf%s}',modelopt.misfitnorm), ...
			sprintf('uncertainty = {\\bf%g \\sigma (%1.1f%%)}',modelopt.msig,modelopt.msigp*100), ...
		};
		if modelopt.horizonly
			info = cat(2,info,'misfit mode = {\bfhorizontal only}');
		end
		if numel(modelopt.apriori_depth) == 2
			info = cat(2,info,sprintf('a priori depth = {\\bf%g \\pm %g km}',roundsd(modelopt.apriori_depth/1e3,2)));
		end
		if modelopt.apriori_horizontal > 0
			info = cat(2,info,sprintf('a priori horiz. STD = {\\bf%g km}',modelopt.apriori_horizontal));
		end

		mtlabel = cell(1,numel(modeltime_period));
		for m = 1:numel(modeltime_period)
			mtp = modeltime_period(m);
			if mtp > 0
				mtlabel{m} = days2h(mtp,'round');
			else
				mtlabel{m} = 't_0 ref.';
			end
			M(m).mtp = mtp;

			M(m).t = (fliplr(tlim(2):-dt:tlim(1)))';
			% last time must contain data
			tlast = max(max(cat(1,D.tfirstlast)));
			M(m).t(M(m).t > tlast) = [];
			fprintf('%s: computing %d %s models (%s @ %s) ',wofun,numel(M(m).t),mst{1},mtlabel{m},days2h(dt));

			% initiates the model result matrix
			M(m).d = nan(numel(M(m).t),5 + 5*strcmp(mt,'pcdm'));
			M(m).e = nan(numel(M(m).t),5);
			M(m).o = nan(numel(M(m).t),1);
			M(m).type = cell(numel(M(m).t),1);

			for w = 1:numel(M(m).t)
				t2 = M(m).t(w);
				if modeltime_period(m) > 0
					wlim = t2 - [modeltime_period(m),0];
				else
					wlim = [tlim(1),t2];
				end

				% computes linear trends (mm/yr)
				tr = nan(numel(kn),3); % trends per station per component
				tre = nan(numel(kn),3); % trends error per station per component
				tro = zeros(numel(kn),1); % inits to best orbit per station
				for j = 1:numel(kn)
					n = kn(j);
					k = find(isinto(D(n).t,wlim));
					tk = D(n).t(k);
					for i = 1:3
						if ~isempty(k) && ~all(isnan(D(n).d(k,i+4)))
							k1 = k(find(~isnan(D(n).d(k,i+4)),1,'first'));
							ke = k(find(~isnan(D(n).d(k,i+4)),1,'last'));
							dk = cleanpicks(D(n).d(k,i+4) - D(n).d(k1,i+4),P);
							kk = find(~isnan(dk));
							if numel(kk) >= 2 && diff(minmax(D(n).t(kk))) >= trendmindays && 100*diff(minmax(D(n).t(kk)))/diff(wlim) >= trendminperc
								[b,stdx] = wls(tk(kk)-tk(1),dk(kk),1./D(n).e(k(kk),i));
								tr(j,i) = b(1)*365.25*1e3;
								tre(j,i) = stdx(1)*365.25*1e3;
							end
							% sets a lower orbit if there is not enough data
							%if D(n).t(D(n).G(r).ke) >= M(m).t(w)
							if (D(n).t(ke) + 1) < M(m).t(w)
								tro(j) = 2;
							end
						end
					end
				end

				% computes reference (auto, fixed or station)
				if numel(kn) > 1
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
					tr = tr - repmat(voffset,numel(kn),1);
				end

				% makes (or not) the relative data array
				d = [tr,tre];
				knn = find(~isnan(d(:,1)));
				modrelforced = 0;
				if ~isempty(knn) && (modelling_force_relative || (modrelauto && (azgap(xs(knn),ys(knn)) < 150 || numel(knn) > 2)))
					% computes a mean velocity vector (horizontal only)
					if numel(knn) > 1
						mvv = rsum(tr(knn,:)./tre(knn,:))./rsum(1./tre(knn,:));
					else
						mvv = tr(knn,:);
					end
					d(:,1:3) = d(:,1:3) - repmat([mvv(1:2),0],size(d,1),1);
					modrelforced = 1;
				end
				% computes absolute displacement in mm (from velocity in mm/yr)
				d = d*diff(wlim)/365.25;
				modelopt.verbose = 'quiet';
				d(:,4:6) = adjerrors(d,modelopt);

				% --- computes the model (and stores only the source #1) !
				switch mt
				case 'pcdm'
					MM = invpcdm(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt,PCDM);
					M(m).d(w,:) = [MM(1).pbest(1:3),MM(1).pbest(7)*1e6,MM(1).pbest([8,9,4:6]),sign(MM(1).pbest(7))*mean(sqrt(MM(1).ux.^2+MM(1).uy.^2+MM(1).uz.^2))];
				otherwise
					MM = invmogi(d,xx,yy,zz,xsta,ysta,zsta,zdem,modelopt);
					M(m).d(w,:) = [MM(1).pbest(1:3),MM(1).pbest(4)*1e6,sign(MM(1).pbest(4))*mean(sqrt(MM(1).ux.^2+MM(1).uy.^2+MM(1).uz.^2))];
				end
				%M(m).e(w,:) = [MM(1).ws,MM(1).ws,diff(MM(1).ez),diff(MM(1).ev),MM(1).m0];
				M(m).e(w,:) = [diff(MM(1).ex)/2,diff(MM(1).ey)/2,diff(MM(1).ez)/2,diff(MM(1).ev)*1e6/2,MM(1).m0];
				M(m).o(w,1) = median(tro); % model worst orbit
				M(m).type{w} = MM(1).type;

				if isok(P,'DEBUG')
					fprintf('\n%s,%s: %+g 10e6 m3 / %g km',datestr(wlim(1)),datestr(wlim(2)),roundsd([MM.pbest(4),MM.pbest(3)/1e3],3));
					if modrelforced
						fprintf(' / relative mode forced by (%g,%g)',mvv(1:2));
					end
				else
					fprintf('.');
				end
			end

			% converts vv into Q (volumetric flux) in m3/s)
			if modeltime_flowrate
				if modeltime_period(m) == 0
					dtf = (M(m).t - tlim(1))*86400;
				else
					dtf = modeltime_period(m)*86400;
				end
				M(m).d(:,4) = M(m).d(:,4)./dtf;
				M(m).e(:,4) = M(m).e(:,4)./dtf;
				vtype = 'Flow rate';
				vunit = 'm^3/s';
			else
				vtype = '\DeltaV';
				vunit = 'm^3';
			end
			% puts NaN where vv is NaN (no model)
			M(m).d((isnan(M(m).d(:,4)) | M(m).e(:,5) > 1e3*modeltime_maxmisfit),:) = NaN;
			M(m).vmedian = median(M(m).d(:,4));
			M(m).vmax = max(M(m).d(:,4));
			M(m).vmin = min(M(m).d(:,4));

			fprintf(' done!\n');
		end

		% adjusts unit
		vmaxs = max(abs(cat(1,M.vmax)));
		if isfinite(vmaxs) && vmaxs > 0.5e6
			vfactor = 1e6;
			vunit = ['M',vunit];
		else
			vfactor = 1;
		end

		figure, orient tall

		% -- volumetric flow rate from volume variation (moving)
		subplot(10,1,1:3), extaxes(gca,[.08,.04])

		plot(tlim,[0,0],'-k','LineWidth',1)
		hold on
		for m = 1:numel(M)
			col = scolor(m);
			errorbar(M(m).t,M(m).d(:,4)/vfactor,M(m).e(:,4)/vfactor,'-','LineWidth',P.GTABLE(r).LINEWIDTH/3,'Color',col/3 + 2/3)
			%errorarea(M(m).t,M(m).d(:,4)/vfactor,M(m).e(:,4)/vfactor,col);
			plotorbit(M(m).t,M(m).d(:,4)/vfactor,M(m).o,modeltime_linestyle,P.GTABLE(r).LINEWIDTH,P.GTABLE(r).MARKERSIZE,col)
		end
		hold off
		if numel(modeltime_flim)==2
			set(gca,'YLim',modeltime_flim);
		end
		ylim2 = get(gca,'YLim');
		if ylim2(2) > 0
			text(tlim(2),0,{'',' \rightarrow Inflation'},'rotation',90,'Color','k', ...
				'HorizontalAlignment','left','VerticalAlignment','middle','Fontsize',8,'FontWeight','bold')
		end
		if ylim2(1) < 0
			text(tlim(2),0,{'','Deflation \leftarrow '},'rotation',90,'Color','k', ...
				'HorizontalAlignment','right','VerticalAlignment','middle','Fontsize',8,'FontWeight','bold')
		end
		set(gca,'XLim',tlim,'FontSize',fontsize)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(['Source ',vtype,' (',vunit,')'])

		% legend for periods
		for m = 1:numel(M)
			text(tlim(1)+m*diff(tlim)/(numel(M)+1),ylim2(2),mtlabel{m},'Color',scolor(m), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8,'FontWeight','bold')
		end
		set(gca,'YLim',ylim2);

		% -- depth
		subplot(10,1,4:5), extaxes(gca,[.08,.04])
		plot(tlim,[0,0],'-k','LineWidth',1)
		hold on
		for m = 1:numel(M)
			col = scolor(m);
			errorbar(M(m).t,M(m).d(:,3)/1e3,M(m).e(:,3)/1e3,'-','LineWidth',P.GTABLE(r).LINEWIDTH/3,'Color',col/3 + 2/3)
			%errorarea(M(m).t,M(m).d(:,3)/1e3,M(m).e(:,3)/1e3,col);
			plotorbit(M(m).t,M(m).d(:,3)/1e3,M(m).o,modeltime_linestyle,P.GTABLE(r).LINEWIDTH,P.GTABLE(r).MARKERSIZE,col)
		end
		hold off
		set(gca,'XLim',tlim,'FontSize',fontsize,'YLim',minmax(zz)/1e3)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Source Elevation (km asl)')
		pos = get(gca,'Position');

		tlabel(tlim,P.GTABLE(r).TZ,'FontSize',fontsize)

		% -- 3D map
		[~,plist] = ismember(modeltime_map_period,modeltime_period);
		vlim = minmax(abs(cat(1,M(plist).vmax,M(plist).vmin)),'finite')/vfactor;

		set(gcf,'PaperUnits','inches');
		ppos = get(gcf,'PaperPosition');
		prxy = ppos(4)/ppos(3);
		mpos = [pos(1),.18,.3*prxy,.3];

		% X-Y top view
		axes('Position',mpos)
		hold on
		[~,h] = contour(xlim,ylim,zdem,0:200:mmz(2));
		set(h,'Color',modelling_topo_rgb,'LineWidth',.1);
		[~,h] = contour(xlim,ylim,zdem,[0:1000:mmz(2),0:-1000:mmz(1)]);
		set(h,'Color',modelling_topo_rgb,'LineWidth',.75);
		plot(xsta,ysta,'^k','MarkerSize',4,'MarkerFaceColor','k')
		if ~isempty(targetll)
			plot(repmat(modelopt.targetxy(1),1,2),ylim([1,end]),':k')
			plot(xlim([1,end]),repmat(modelopt.targetxy(2),1,2),':k')
			if modelopt.apriori_horizontal > 0
				acircle = linspace(0,2*pi);
				plot(modelopt.targetxy(1)+modelopt.apriori_horizontal*1e3*cos(acircle), ...
				     modelopt.targetxy(2)+modelopt.apriori_horizontal*1e3*sin(acircle), ...
				     ':k')
			end
		end
		for m = plist
			col = scolor(m);
			mks = max((abs(M(m).d(:,4))/vfactor-vlim(1))/diff(vlim),0)*modeltime_markersize + 2;
			scatter(M(m).d(:,1),M(m).d(:,2),mks,'MarkerEdgeColor',col,'LineWidth',modeltime_marker_linewidth)
			scatter(M(m).d(:,1),M(m).d(:,2),mks,M(m).t,'fill','MarkerEdgeColor','none','LineWidth',.01)
		end
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(ylim),'XTickLabel',[],'FontSize',6);
		tickfactor(distfactor)
		ylabel(sprintf('Distances in %s',distunit),'FontSize',8)
		box on
		colormap(modeltime_cmap)
		caxis(tlim)
		nimap = 1;
		for m = plist
			IMAP(nimap).d = [M(m).d(:,1),M(m).d(:,2),sqrt(mks/pi)+modeltime_marker_linewidth/2];
			IMAP(nimap).gca = gca;
			IMAP(nimap).s = cell(size(M(m).t));
			IMAP(nimap).l = cell(size(M(m).t));
			for n = 1:numel(IMAP(nimap).s)
				IMAP(nimap).s{n} = sprintf('''%g km (%s)<br>%s = %g %s<br>misfit = %g mm'',CAPTION,''%s (%s)''', ...
					roundsd(M(m).d(n,3)/1e3,2),	M(m).type{n}, ...
					vtype,roundsd(M(m).d(n,4)/vfactor,2), ...
					regexprep(vunit,'\^3','<sup>3</sup>'),roundsd(M(m).e(n,5),2), ...
					datestr(M(m).t(n),'dd-mmm-yyyy HH:MM'),mtlabel{m});
			end
			nimap = nimap + 1;
		end

		% Z-Y profile view
		axes('Position',[mpos(1)+mpos(3),mpos(2),.15*prxy,mpos(4)])
		plot(max(max(zdem,[],3),[],2)',ylim,'-','Color',modelling_topo_rgb)
		hold on
		%plot(zsta,ysta,'^k','MarkerSize',stasize,'MarkerFaceColor','k')
		if ~isempty(targetll)
			plot(zlim([1,end]),repmat(modelopt.targetxy(2),1,2),':k')
		end
		if numel(modelopt.apriori_depth) == 2
			plot(repmat(-modelopt.apriori_depth(1),1,2),ylim([1,end]),':k')
		end
		for m = plist
			col = scolor(m);
			mks = max((abs(M(m).d(:,4))/vfactor-vlim(1))/diff(vlim),0)*modeltime_markersize + 2;
			scatter(M(m).d(:,3),M(m).d(:,2),mks,'MarkerEdgeColor',col,'LineWidth',modeltime_marker_linewidth)
			scatter(M(m).d(:,3),M(m).d(:,2),mks,M(m).t,'fill','MarkerEdgeColor','none','LineWidth',.01)
		end
		hold off
		set(gca,'XLim',minmax(zlim),'YLim',minmax(ylim),'XDir','reverse','YTickLabel',[],'YAxisLocation','right','FontSize',6);
		tickfactor(distfactor)
		xlabel(sprintf('Depth (%s)',distunit),'FontSize',8)
		box on
		colormap(modeltime_cmap)
		caxis(tlim)
		for m = plist
			IMAP(nimap).d = [M(m).d(:,3),M(m).d(:,2),sqrt(mks/pi)+modeltime_marker_linewidth/2];
			IMAP(nimap).gca = gca;
			IMAP(nimap).s = IMAP(mod(nimap-1,numel(plist))+1).s; % uses the labels for X-Y top view
			IMAP(nimap).l = cell(size(M(m).t));
			nimap = nimap + 1;
		end

		% X-Z profile view
		axes('Position',[mpos(1),mpos(2)-.15,mpos(3),.15])
		plot(xlim,max(max(zdem,[],3),[],1),'-','Color',modelling_topo_rgb)
		hold on
		%plot(xsta,zsta,'^k','MarkerSize',stasize,'MarkerFaceColor','k')
		if ~isempty(targetll)
			plot(repmat(modelopt.targetxy(1),1,2),zlim([1,end]),':k')
		end
		if numel(modelopt.apriori_depth) == 2
			plot(xlim([1,end]),repmat(-modelopt.apriori_depth(1),1,2),':k')
		end
		for m = plist
			col = scolor(m);
			mks = max((abs(M(m).d(:,4))/vfactor-vlim(1))/diff(vlim),0)*modeltime_markersize + 2;
			scatter(M(m).d(:,1),M(m).d(:,3),mks,'MarkerEdgeColor',col,'LineWidth',modeltime_marker_linewidth)
			scatter(M(m).d(:,1),M(m).d(:,3),mks,M(m).t,'fill','MarkerEdgeColor','none','LineWidth',.01)
		end
		hold off
		set(gca,'XLim',minmax(xlim),'YLim',minmax(zlim),'FontSize',6);
		tickfactor(distfactor)
		ylabel(sprintf('Depth (%s)',distunit),'FontSize',8)
		box on
		colormap(modeltime_cmap)
		caxis(tlim)
		for m = plist
			IMAP(nimap).d = [M(m).d(:,1),M(m).d(:,3),sqrt(mks/pi)+modeltime_marker_linewidth/2];
			IMAP(nimap).gca = gca;
			IMAP(nimap).s = IMAP(mod(nimap-1,numel(plist))+1).s; % uses the labels for X-Y top view
			IMAP(nimap).l = cell(size(M(m).t));
			nimap = nimap + 1;
		end


		% legend
		axes('position',[mpos(1)+mpos(3),0.07,pos(3)-mpos(3),0.4]);

		text(.6,1,info,'HorizontalAlignment','left','VerticalAlignment','top','FontSize',8)
		hold on

		% volume scale
		x = .2 + zeros(size(vlim));
		y = .1 - .05*(vlim-vlim(1))/diff(vlim);
		scatter(x,y,(vlim - vlim(1))/diff(vlim)*modeltime_markersize + 2,'MarkerEdgeColor','k','LineWidth',modeltime_marker_linewidth)
		text(x + .05,y,num2str(roundsd(vlim',2)),'FontSize',7)
		text(.15,.15,['{\bf',vtype,'} (',vunit,')'],'HorizontalAlignment','left','FontSize',8)
		hold off

		set(gca,'XLim',[0,1],'YLim',[0,1])
		axis off

		% time color scale
		axes('position',[.8,0.06,0.17,0.3]);
		timecolorbar(.1,0,.15,.8,tlim,modeltime_cmap,8)
		set(gca,'XLim',[0,1],'YLim',[0,1])
		axis off

		% -- displacements module
		%subplot(10,1,6:7), extaxes(gca,[.08,.04])
		%plot(tlim,[0,0],'-k','LineWidth',1)
		%hold on
		%for m = 1:numel(M)
		%	col = scolor(m);
		%	errorbar(M(m).t,M(m).d(:,5),M(m).e(:,5),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',col/2 + 1/2)
		%	plotorbit(M(m).t,M(m).d(:,5),M(m).o,modeltime_linestyle,P.GTABLE(r).LINEWIDTH/2,P.GTABLE(r).MARKERSIZE,col)
		%end
		%hold off
		%ylim = get(gca,'YLim');
		%if ylim(2) > 0
		%	text(tlim(2),0,{'',' \rightarrow Inflation'},'rotation',90,'Color','k', ...
		%		'HorizontalAlignment','left','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		%end
		%if ylim(1) < 0
		%	text(tlim(2),0,{'','Deflation \leftarrow'},'rotation',90,'Color','k', ...
		%		'HorizontalAlignment','right','VerticalAlignment','top','Fontsize',8,'FontWeight','bold')
		%end
		%set(gca,'XLim',tlim,'FontSize',fontsize)
		%datetick2('x',P.GTABLE(r).DATESTR)
		%ylabel('Displ. Amplitude (mm)')

		% -- volume variation (cumulative normalized)
		%subplot(10,1,8:10), extaxes(gca,[.08,.04])

		%plot(tlim,[0,0],'-k','LineWidth',1)
		%hold on
		%for m = 1:numel(M)
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

		axes('Position',[0,0,1,1])
		axis off
		if ~isok(P,'MODELTIME_NOWARNING')
			twarning = {'{\bfWarning:} This graph is experimental. Use results with caution.', ...
				'Processing and modelling by Beauducel et al./IPGP',' '};
				text(.99,.01,twarning,'HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',8)
		end

		P.GTABLE(r).GTITLE = varsub(modeltime_title,V);
		P.GTABLE(r).GSTATUS = [];
		P.GTABLE(r).INFOS = {' '};
		mkgraph(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),P.GTABLE(r),struct('IMAP',IMAP,'FIXEDPP',true))
		close
		clear IMAP

		% exports data
		if isok(P.GTABLE(r),'EXPORTS')
			E.t = M(1).t;
			n = size(M(1).d,2) + size(M(1).e,2);
			E.d = nan(size(M(1).d,1),numel(M)*n);
			E.header = cell(size(M(1).d,1),numel(M)*size(M(1).d,2)*2);
			[e0,n0,z0] = ll2utm(lat0,lon0);
			for m = 1:numel(M)
				k = (m-1)*n + (1:n);
				[lats,lons] = utm2ll(e0+M(m).d(:,1),n0+M(m).d(:,2),z0);
				E.d(:,k) = cat(2,lats,lons,M(m).d(:,3:end),M(m).e);
				switch mt
				case 'pcdm'
					E.header(k) = strcat({'LAT','LON','Z_(m)',sprintf('dV_(%s)',vunit),'A','B','Ox','Oy','Oz','dD_(m)','s_X','s_Y','s_Z','s_dV','s_dD'},sprintf('_%d',m));
				otherwise
					E.header(k) = strcat({'LAT','LON','Z_(m)',sprintf('dV_(%s)',vunit),'dD_(m)','s_X','s_Y','s_Z','s_dV','s_dD'},sprintf('_%d',m));
				end
			end
			E.title = sprintf('%s {%s}',P.GTABLE(r).GTITLE,upper(sprintf('%s_%s',proc,summary)));
			E.infos = {sprintf('Source type: %s',mt)};
			for m = 1:numel(modeltime_period)
				E.infos = cat(2,E.infos,sprintf('Time period #%d = %g days (%s)',m,modeltime_period(m),days2h(modeltime_period(m),'round')));
			end
			mkexport(WO,sprintf('%s_%s',summary,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end

		if isok(P,'MODELTIME_EXPORT_MAT')
			f = sprintf('%s_%s.mat',summary,P.GTABLE(r).TIMESCALE);
			fprintf('%s: saving workspace in %s...',wofun,f);
			save(sprintf('%s/%s/%s',P.GTABLE(r).OUTDIR,WO.PATH_OUTG_EXPORT,f),'-v6')
			fprintf(' done.\n');
		end
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
function e = adjerrors(d,opt)
e = d(:,4:6);

% avoiding numerical problem with pdf due to low errors
emin = abs(d(:,1:3))*opt.minerrorrel/100;
k = (e < emin | isnan(d(:,1:3)) | isnan(e));
if any(k)
	e(k) = emin(k);
	if ~strcmpi(opt.verbose,'quiet')
		fprintf('---> %d data errors have been increased to %g%%.\n',sum(k(:)),opt.minerrorrel);
	end
end

% forces a minimum relative error
k = (e < opt.minerror);
if any(k)
	e(k) = opt.minerror; % forces a minimum absolute error
	if ~strcmpi(opt.verbose,'quiet')
		fprintf('---> %d data errors have been set to %g mm.\n',sum(k(:)),opt.minerror);
	end
end

% ajusts component errors using a priori factor ratio
if any(opt.enuerror ~= 1)
	e = e.*repmat(opt.enuerror(1:3),size(e,1),1);
	if ~strcmpi(opt.verbose,'quiet')
		fprintf('---> all data errors dE,dN,dU have been multiplied by %g,%g,%g.\n',opt.enuerror);
	end
end


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function r = ellradius(abc,lambda,gamma)
% computes radius of an ellipsoid defined by semi-axis ABC = [A,B,C] at
% azimuth/longitude LAMBDA and polar/latitude GAMMA angles (in radian)

r = prod(abc)./sqrt(abc(3)^2*(abc(2)^2*cos(lambda).^2 ...
 	+ abc(1)^2*sin(lambda).^2).*cos(gamma).^2 ...
	+ abc(1)^2*abc(2)^2*sin(gamma).^2);


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function h = errorarea(x,y,e,c)

h = fill([x(:);flipud(x(:))],[y(:)+e(:);flipud(y(:)-e(:))],'k');
set(h,'EdgeColor','none','FaceColor',c/3+2/3,'FaceAlpha',.1);
