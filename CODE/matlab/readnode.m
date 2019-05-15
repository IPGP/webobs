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
%		- UTC_DATA is converted from hours to days,
%		- ALIAS underscores are escaped (\_) for display purpose.
%
%	Some additional keys are also added:
%	          ID: self reference
%	   TIMESTAMP: timestamp of the .cnf file (local time)
%	         CLB: data table from calibration .clb file (if exists)
%	TRANSMISSION: a structure containing following fields (if defined):
%	               TYPE: index in FILE_TELE (NODES.rc)
%	              NODES: cell array of NODES ID
%	          REPEATERi: all base keys of repeater NODE i in a structure 
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2013-02-22
%   Updated: 2019-02-14


if ~exist('NODES','var')
	NODES = readcfg(WO.CONF_NODES);
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
N = readcfg(WO,f);

% replaces PROC's parameters (PROC.name.* if exist)
if strcmpi(gridtype,'PROC') && isfield(N,'PROC') && isstruct(N.PROC) && isfield(N.PROC,gridname)
	pf = fieldnames(N.PROC.(gridname));
	for n = 1:length(pf)
		N.(pf{n}) = N.PROC.(gridname).(pf{n});
	end
end


% adds a self-reference
N.ID = id;

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
c2num = {'VALID' 'LAT_WGS84' 'LON_WGS84' 'ALTITUDE' 'UTC_DATA' 'POS_TYPE','ACQ_RATE','LAST_DELAY','CHANNEL_LIST'};
for j = 1:length(c2num)
	if isfield(N,c2num{j}) && ~isempty(N.(c2num{j}))
		N.(c2num{j}) = sstr2num(N.(c2num{j})); %NOTE: str2num() allows some syntax interpretation like '5/1440' (5 mn expressed in days)
	else
		N.(c2num{j}) = NaN;
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

% --- reads .clb calibration file (if exists)
clb = sprintf('%s/%s.clb',p,id);
if exist(clb,'file')
	fid = fopen(clb);
	C = textscan(fid,'%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','Delimiter','|','CommentStyle','#');
	fclose(fid);
	%[y,m,d,h,n,nv,nm,un,ns,cc,of,et,ga,vn,vm,az,la,lo,al] = textread(f,'%d-%d-%d%d:%d%s%s%s%s%s%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|','commentstyle','shell');
	nn = 1;
	for j = 1:length(C{1})
		k = strfind(C{3}{j},'-');
		if isempty(k)
			j1 = str2double(C{3}{j});
			j2 = j1;
		else
			j1 = str2double(C{3}{j}(1:(k-1)));
			j2 = str2double(C{3}{j}((k+1):end));
		end
		for jj = j1:j2
			if any(isnan(N.CHANNEL_LIST)) || any(N.CHANNEL_LIST==jj)
				CC.dt(nn) = isodatenum(strcat(C{1}(j),{' '},C{2}(j)));
				CC.nv(nn) = jj;
				CC.nm{nn} = C{4}{j};
				CC.un{nn} = C{5}{j};
				CC.ns{nn} = C{6}{j};
				CC.cd{nn} = C{7}{j};
				CC.of(nn) = sstr2num(C{8}{j});
				CC.et(nn) = sstr2num(C{9}{j});
				CC.ga(nn) = sstr2num(C{10}{j});
				CC.vn(nn) = sstr2num(C{11}{j});
				CC.vm(nn) = sstr2num(C{12}{j});
				CC.az(nn) = sstr2num(C{13}{j});
				CC.la(nn) = sstr2num(C{14}{j});
				CC.lo(nn) = sstr2num(C{15}{j});
				CC.al(nn) = sstr2num(C{16}{j});
				CC.dp(nn) = sstr2num(C{17}{j});
				CC.sf(nn) = sstr2num(C{18}{j});
				CC.db{nn} = C{19}{j};
				CC.lc{nn} = C{20}{j};
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

if ~exist('CC','var') | isempty(CC)
	N.CLB = struct('nx',0,'dt',0,'nv',0,'nm','','un','','ns','','cd','','of',0,'et',0,'ga',0,'vn',0,'vm',0,'az',0,'la',0,'lo',0,'al',0,'dp',0,'sf',NaN,'db','','lc','');
end

% --- transmission type and nodes' list
tr = split(N.TRANSMISSION,'|, ');

if length(tr) > 0 & ~isempty(tr{1})
	rmfield(N,'TRANSMISSION');	% needed since R2015... (?)
	N.TRANSMISSION = struct('TYPE',str2num(tr{1}));
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

