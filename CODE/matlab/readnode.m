function N=readnode(WO,nodefullid,NODES);
%READNODE Read WEBOBS node configuration
%	N = READNODE(WO,NODEFULLID) returns a structure variable X containing
%	every field key and corresponding value from the node .cnf
%	configuration file. NODEFULLID syntax is 'GRIDtype.GRIDname.ID'.
%
%	Specific PROC's parameters (like FIDs, CHANNEL_LIST) will be filtered
%	following the calling PROC.
%
%	Some specific treatments are applied:
%		- numerical parameters are converted to scalar or vectors,
%		- dates are converted to datenum,
%		- TZ and UTC_DATA is converted from hours to days,
%		- ALIAS underscores are escaped (\_) for display purpose.
%
%	Some additional keys are also added:
%	          ID: self reference
%         FULLID: full ID
%	   TIMESTAMP: timestamp of the .cnf file (local time)
%        GEOJSON: GeoJSON string containing feature collection of geometries
%	         CLB: data table from calibration .clb file (if exists)
%	TRANSMISSION: a structure containing following fields (if defined):
%	               TYPE: index in FILE_TELE (NODES.rc)
%	              NODES: cell array of NODES ID
%	          REPEATERi: all base keys of repeater NODE i in a structure
%	      EVENTS: a structure array containing some node's events data:
%	                 dt1: start_date (datenum format, node's TZ)
%	                 dt2: end_date (datenum format, node's TZ)
%	                 nam: node alias, node name and authors
%	                 com: event's title
%	                  lw: default linewidth (from NODES.rc)
%	                 rgb: default color (from NODES.rc)
%	                 out: data outcome flag
%	          WO: copy of the WO structure
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2013-02-22
%   Updated: 2025-05-08


if ~exist('NODES','var')
	NODES = readcfg(WO.CONF_NODES,'quiet');
end

nodeparts = split(nodefullid,'.');
if length(nodeparts) ~= 3
	error('Incorrect NODEFULLID argument')
end
gridtype = nodeparts{1};
gridname = nodeparts{2};
id = nodeparts{3};
f = sprintf('%s/%s/%s.cnf',NODES.PATH_NODES,id,id);

[p,id,e] = fileparts(f);

if ~exist(f,'file')
	fprintf('WEBOBS{%s}: ** Warning: node %s does not exist.\n',mfilename,id);
	N = [];
	return
end


% reads .cnf main conf file
N = readcfg(WO,f,'quiet');

% replaces any PROC's parameters that exists as PROC.name.*
if strcmpi(gridtype,'PROC') && isfield(N,'PROC') && isstruct(N.PROC) && isfield(N.PROC,gridname)
	pf = fieldnames(N.PROC.(gridname));
	for n = 1:length(pf)
		N.(pf{n}) = N.PROC.(gridname).(pf{n});
	end
end


% adds a self-reference
N.ID = id;
N.FULLID = nodefullid;

% adds a timestamp (in the local server time)
X = dir(f);
N.TIMESTAMP = X.datenum;

% --- converts dates in DATENUM format
N.INSTALL_DATE = field2num(N,'INSTALL_DATE');
N.END_DATE = field2num(N,'END_DATE');
N.POS_DATE = field2num(N,'POS_DATE');

N.ALIAS = strrep(field2str(N,'ALIAS'),'_','\_');

N.CHANNEL_LIST = field2str(N,'CHANNEL_LIST');

N.TYPE = field2str(N,'TYPE');

% --- converts to numeric some fields
c2num = {'VALID' 'LAT_WGS84' 'LON_WGS84' 'ALTITUDE' 'TZ' 'UTC_DATA' 'POS_TYPE','ACQ_RATE','LAST_DELAY','CHANNEL_LIST'};
for j = 1:length(c2num)
	if isfield(N,c2num{j}) && ~isempty(N.(c2num{j}))
		N.(c2num{j}) = sstr2num(N.(c2num{j})); %NOTE: str2num() allows some syntax interpretation like '5/1440' (5 mn expressed in days)
	else
		N.(c2num{j}) = NaN;
	end
end

% TZ in days (format +HH or +HHMM)
if isnan(N.TZ)
	N.TZ = 0;
else
	if abs(N.TZ) > 100
		N.TZ = N.TZ/2400;
	else
		N.TZ = N.TZ/24;
	end
end

if isnan(N.UTC_DATA)
	N.UTC_DATA = 0;
else
	N.UTC_DATA = N.UTC_DATA/24;	% UTC in days !!
end

if isnan(N.LAST_DELAY)
	N.LAST_DELAY = 0;
end

% imports .geojson (if exists)
json = sprintf('%s/%s.geojson',p,id);
if exist(json,'file')
    N.GEOJSON = readjson(json);
else
    N.GEOJSON = '';
end

% --- reads .clb calibration file (if exists)
clb = sprintf('%s/%s.clb',p,nodefullid);
autoclb = sprintf('%s/%s_auto.clb',p,nodefullid); % auto-generated clb
legclb = sprintf('%s/%s.clb',p,id); % legacy clb name (for backwards compatibility)
if ~exist(clb,'file')
	if exist(legclb,'file')
		clb = legclb;
	end
	if exist(autoclb,'file')
		clb = autoclb;
	end
end
if exist(clb,'file')
	C = readcfg(WO, clb,'quiet');
end
if exist('C','var') && ~isempty(C)
	keys = fieldnames(C);
	nn = 1;
	for j = 1:numel(keys)
		key = sprintf('KEY%d',j);
		k = strfind(C.(key).nv,'-');
		if isempty(k)
			j1 = str2double(C.(key).nv);
			j2 = j1;
		else
			j1 = str2double(C.(key).nv(1:(k-1)));
			j2 = str2double(C.(key).nv((k+1):end));
		end
		for jj = j1:j2
			if any(isnan(N.CHANNEL_LIST)) || any(N.CHANNEL_LIST==jj)
				CC.dt(nn) = isodatenum(strcat(C.(key).DATE,{' '},C.(key).TIME));
				CC.nv(nn) = jj;
				CC.nm{nn} = C.(key).nm;
				CC.un{nn} = C.(key).un;
				CC.ns{nn} = C.(key).ns;
				CC.cd{nn} = C.(key).cd;
				CC.of(nn) = sstr2num(C.(key).of);
				CC.et{nn} = C.(key).et;
				CC.ga(nn) = sstr2num(C.(key).ga);
				CC.vn(nn) = sstr2num(C.(key).vn);
				CC.vm(nn) = sstr2num(C.(key).vm);
				CC.az(nn) = sstr2num(C.(key).az);
				CC.la(nn) = sstr2num(C.(key).la);
				CC.lo(nn) = sstr2num(C.(key).lo);
				CC.al(nn) = sstr2num(C.(key).al);
				CC.dp(nn) = sstr2num(C.(key).dp);
				CC.sf(nn) = sstr2num(C.(key).sf);
				CC.db{nn} = C.(key).db;
				CC.lc{nn} = C.(key).lc;
				nn = nn + 1;
			end
		end
	end
	if exist('CC','var')
		CC.nx = length(unique(CC.nv));
	else
		CC.nx = 0;
	end
	N.CLB = CC;
end

if ~exist('CC','var') || isempty(CC)
	N.CLB = struct('nx',0,'dt',0,'nv',0,'nm','','un','','ns','','cd','','of',0,'et','','ga',0,'vn',0,'vm',0,'az',0,'la',0,'lo',0,'al',0,'dp',0,'sf',NaN,'db','','lc','');
end

% --- transmission type and nodes' list
tr = split(N.TRANSMISSION,'|, ');

if ~isempty(tr) && ~isempty(tr{1})
	rmfield(N,'TRANSMISSION');	% needed since R2015... (?)
	N.TRANSMISSION = struct('TYPE',str2double(tr{1}));
	nn = 0;
	for n = 2:length(tr)
		f = sprintf('%s/%s/%s.cnf',NODES.PATH_NODES,tr{n},tr{n});
		if exist(f,'file')
			nn = nn + 1;
			N.TRANSMISSION.NODES{nn} = tr{n};
			N.TRANSMISSION.(sprintf('REPEATER%d',nn)) = readcfg(WO,f);
			fprintf('WEBOBS{readnode}: %s read (repeater %d).\n',f,nn);
		end
	end
end

% --- node events
evtpath = sprintf('%s/%s/%s',NODES.PATH_NODES,id,NODES.SPATH_INTERVENTIONS);
if exist(evtpath,'dir')
	[s,w] = wosystem(sprintf('find %s -name "*_????-??-??_??-??*.txt"',evtpath));
else
	s = 1;
end
if ~s && ~isempty(w)
	evtlist = split(w,'\n');
	for e = 1:length(evtlist);
		E = readnodeevent(evtlist{e});
		N.EVENTS(e).dt1 = E.date1 - N.TZ; % TLIM in UTC
		N.EVENTS(e).dt2 = E.date2 - N.TZ; % TLIM in UTC
		N.EVENTS(e).nam = {sprintf('%s: %s (%s)',N.ALIAS,N.NAME,E.author)};
		N.EVENTS(e).com = {E.title};
		N.EVENTS(e).lw = field2num(NODES,'EVENTNODE_PLOT_LINEWIDTH',.1);
		N.EVENTS(e).rgb = field2num(NODES,'EVENTNODE_PLOT_COLOR',rgb('Silver'));
		N.EVENTS(e).hex = rgb2hex(N.EVENTS(e).rgb);
		if isfield(E,'outcome')
			N.EVENTS(e).out = E.outcome;
		else
			N.EVENTS(e).out = false;
		end
	end
	if isok(NODES,'EVENTNODE_PLOT_OUTCOME_ONLY')
		N.EVENTS(~cat(1,N.EVENTS.out)) = [];
	end
else
	N.EVENTS = [];
end

% adds the WO structure
N.WO = WO;
