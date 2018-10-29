function [P,N,D] = readproc(WO,varargin)
%READPROC Read PROC configuration
%	P = READPROC(WO,PROC) returns a structure variable P containing every field key and
%	corresponding value from the PROC configuration files. PROC can be the proc's name
%	or full path name of the PROC.conf.
%
%	P = READPROC(WO,PROC,TSCALE) returns in P.GTABLE a selection timescales TSCALE found
%	in TIMESCALELIST. TSCALE must be in the form of coma-separated string
%	'ts1,ts2,...,tsn'. Default is '%' to return all the TIMESCALELIST.
%
%	P = READPROC(WO,PROC,TSCALE,REQDIR) ignores TSCALE and returns in P.GTABLE the 
%	parameters of request in REQDIR/REQUEST.rc.
%
%	[P,N] = READPROC(...) returns also a structure N containing all associated nodes
%	configuration.
%
%	[P,N,D] = READPROC(...) returns also a structure D containing the data. RAWFORMAT
%	parameter must be set (see also READFMTDATA function).
%
%
%	Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%	Created: 2013-04-05
%	Updated: 2018-05-30


proc = varargin{1};
wofun = sprintf('WEBOBS{%s}',mfilename);

if strncmp(proc,'/',1)	% if argument contains a path filename, will read it as is...
	f = proc;
else
	proc = regexprep(proc,'PROC.','');
	f = sprintf('%s/%s/%s.conf',WO.PATH_PROCS,proc,proc);
end

if ~exist(f,'file')
	fprintf('%s: ** Warning: file %s does not exist.\n',wofun,f);
	P = [];
	return
end

% reads .conf main conf file
P = readcfg(WO,f);

% split proc's name
[~,proc,~] = fileparts(f);

% adds SELFREF
P.SELFREF = sprintf('PROC.%s',proc);
P.OUTDIR = sprintf('%s/%s',WO.ROOT_OUTG,P.SELFREF);

% tnow = now UT = (matlab's now - system's TZ)
tnow = now - gettz/24;
P.TZ = field2num(P,'TZ',0);
% appends field P.NOW = tnow + proc's defined UTC offset (or assumed 0 if not defined)
P.NOW = tnow + P.TZ/24;
P.BANG = datenum(field2num(P,'BANG',str2num(WO.BIG_BANG)),1,1);
P.PPI = field2num(P,'PPI',field2num(WO,'MKGRAPH_VALUE_PPI',100));
P.PAPER_SIZE = field2str(P,'PAPER_SIZE','');
P.PLOT_GRID = field2str(P,'PLOT_GRID','NO');
P.PDFOUTPUT = field2str(P,'PDFOUTPUT','NO');
P.SVGOUTPUT = field2str(P,'SVGOUTPUT','NO');
P.COPYRIGHT = field2str(P,'COPYRIGHT',WO.COPYRIGHT);
% main logo (upper left) height as a fraction of graph width
P.LOGO_FILE = field2str(P,'LOGO_FILE','');
P.LOGO_HEIGHT = field2num(P,'LOGO_HEIGHT',.04);
P.COPYRIGHT2 = field2str(P,'COPYRIGHT2','');
% secondary logo (upper right)
P.LOGO2_FILE = field2str(P,'LOGO2_FILE','');
P.LOGO2_HEIGHT = field2num(P,'LOGO2_HEIGHT',.04);
P.EXPORTS = field2str(P,'EXPORTS','YES');
P.EVENTS_FILE = field2str(P,'EVENTS_FILE','');

P.DEBUG = isok(field2str(P,'DEBUG',field2str(WO,'DEBUG')));

% appends the list of nodes (i.e., creates field P.NODESLIST)
% list directory WO.PATH_GRIDS2NODES for PROC.n, appends to P as NODESLIST
X = dir(sprintf('%s/PROC.%s.*',WO.PATH_GRIDS2NODES,proc));
P.NODESLIST = {};
for j = 1:length(X)
	nj = split(X(j).name,'.');
	P.NODESLIST{end+1} = nj{3};
end 
% appends the associated FORM (if exists) by listing directory WO.PATH_GRIDS2FORMS
X = dir(sprintf('%s/PROC.%s.*',WO.PATH_GRIDS2FORMS,proc));
if ~isempty(X)
	form = split(X(1).name,'.');
	formname = form{3};
	formroot = sprintf('%s/%s',WO.PATH_FORMS,formname);
	P.FORM = readcfg(WO,sprintf('%s/%s.conf',formroot,formname));
	P.FORM.SELFREF = formname;
	P.FORM.ROOT = formroot;
	P.RAWFORMAT = 'woform';
end 

% TIMESCALELIST : computes the date limits for each timescale and sets P.TIMESCALELIST and P.DATELIST (see timescales.m help)
P = timescales(P);
nlist = length(P.TIMESCALELIST);
if nargin > 2 && isnumeric(varargin{2}) && numel(varargin{2}) == 2
	nlist = 1;
end

% DATESTRLIST 
P = tnorm(P,'DATESTRLIST',nlist,-1);

% MARKERSIZELIST to num vector
P = tnorm(P,'MARKERSIZELIST',nlist,6);

% LINEWIDTHLIST to num vector (default is 1/5 of marker size, for backward compatibility)
P = tnorm(P,'LINEWIDTHLIST',nlist,P.MARKERSIZELIST/5);

% CUMULATELIST to num vector, from arithmetic operations if specified by user
P = tnorm(P,'CUMULATELIST',nlist,1);

% DECIMATELIST to num vector
P = tnorm(P,'DECIMATELIST',nlist,1);

% STATUSLIST to num vector
P = tnorm(P,'STATUSLIST',nlist,0);

% makes the GTABLE
% case A: TIMESCALELIST all or selection
if nargin < 4
	if nargin < 3
		tscale = {'%'};
	else
		if isstr(varargin{2})
			% in deployed application, input arguments are only string
			if isdeployed && numel(str2num(varargin{2}))==2
				tscale = str2num(varargin{2});
			else
				tscale = split(varargin{2},',');
			end
		else
			tscale = varargin{2};
		end
	end
	P.GTABLE = struct([]);
	n = 1;
	for r = 1:nlist
		if isnumeric(tscale) || any(strcmp(tscale,'%')) || ismember(P.TIMESCALELIST(r),tscale)
			% undocumented : TSCALE can be [DATENUM1,DATENUM2]
			if isnumeric(tscale)
				P.GTABLE(n).TIMESCALE = 'xxx';
				P.GTABLE(n).DATE1 = tscale(1);
				P.GTABLE(n).DATE2 = tscale(end);
			else
				P.GTABLE(n).TIMESCALE = P.TIMESCALELIST{r};
				P.GTABLE(n).DATE1 = P.DATELIST{r}(1);
				P.GTABLE(n).DATE2 = P.DATELIST{r}(2);
			end
			P.GTABLE(n).DATESTR = P.DATESTRLIST(r);
			P.GTABLE(n).MARKERSIZE = P.MARKERSIZELIST(r);
			P.GTABLE(n).LINEWIDTH = P.LINEWIDTHLIST(r);
			P.GTABLE(n).CUMULATE = P.CUMULATELIST(r);
			P.GTABLE(n).DECIMATE = P.DECIMATELIST(r);
			P.GTABLE(n).STATUS = P.STATUSLIST(r);
			P.GTABLE(n).NOW = P.NOW;
			P.GTABLE(n).TZ = P.TZ;
			P.GTABLE(n).PPI = P.PPI;
			P.GTABLE(n).PAPER_SIZE = P.PAPER_SIZE;
			P.GTABLE(n).PLOT_GRID = P.PLOT_GRID;
			P.GTABLE(n).EVENTS_FILE = P.EVENTS_FILE;
			P.GTABLE(n).PDFOUTPUT = P.PDFOUTPUT;
			P.GTABLE(n).SVGOUTPUT = P.SVGOUTPUT;
			P.GTABLE(n).EXPORTS = P.EXPORTS;
			P.GTABLE(n).COPYRIGHT = P.COPYRIGHT;
			P.GTABLE(n).COPYRIGHT2 = P.COPYRIGHT2;
			P.GTABLE(n).LOGO_FILE = P.LOGO_FILE;
			P.GTABLE(n).LOGO2_FILE = P.LOGO2_FILE;
			P.GTABLE(n).LOGO_HEIGHT = P.LOGO_HEIGHT;
			P.GTABLE(n).LOGO2_HEIGHT = P.LOGO2_HEIGHT;
			P.GTABLE(n).SELFREF = P.SELFREF;
			P.GTABLE(n).NAME = P.NAME;
			P.GTABLE(n).OUTDIR = P.OUTDIR;
			n = n + 1;
		end
	end
	P.REQUEST = 0;

% case B: request
else
	req = varargin{3};

	% reads the req/REQUEST.rc file (from postREQ.pl)
	freq = [req,'/REQUEST.rc'];
	if ~exist(freq,'file')
		error('%s: cannot find request file %s.',wofun,freq);
	end

	P.GTABLE = readcfg(WO,freq);

	% converts dates in DATENUM format
	P.GTABLE.DATE1 = isodatenum(P.GTABLE.DATE1);
	P.GTABLE.DATE2 = isodatenum(P.GTABLE.DATE2);

	P.GTABLE.TIMESCALE = '';
	P.GTABLE.OUTDIR = sprintf('%s/PROC.%s',req,proc);
	P.GTABLE.SELFREF = P.SELFREF;
	P.GTABLE.NAME = '';
	P.GTABLE.STATUS = 0;

	% converts to numeric some fields
	keys = fieldnames(P.GTABLE);
	keys = keys(ismember(keys,{'TZ','DATESTR','PPI','MARKERSIZE','LINEWIDTH','CUMULATE','DECIMATE'}));
	for n = 1:length(keys)
		P.GTABLE.(keys{n}) = sstr2num(P.GTABLE.(keys{n})); %NOTE: sstr2num() allows some syntax interpretation like '5/1440' (5 mn expressed in days)
	end

	% completes some fields from proc
	P.GTABLE.NOW = P.NOW;
	P.GTABLE.PAPER_SIZE = P.PAPER_SIZE;
	P.GTABLE.EVENTS_FILE = P.EVENTS_FILE;
	P.GTABLE.COPYRIGHT = P.COPYRIGHT;
	P.GTABLE.COPYRIGHT2 = P.COPYRIGHT2;
	P.GTABLE.LOGO_FILE = P.LOGO_FILE;
	P.GTABLE.LOGO2_FILE = P.LOGO2_FILE;
	P.GTABLE.LOGO_HEIGHT = P.LOGO_HEIGHT;
	P.GTABLE.LOGO2_HEIGHT = P.LOGO2_HEIGHT;

	% overwrites some fields of the proc (REQUEST_KEYLIST defined in struct P.GTABLE.PROC.(proc))
	if isfield(P.GTABLE,'PROC') && isfield(P.GTABLE.PROC,proc) && isstruct(P.GTABLE.PROC.(proc))
		P = structmerge(P,P.GTABLE.PROC.(proc));
	end

	P.REQUEST = 1;
end

% summary list
if isfield(P,'SUMMARYLIST')
	P.SUMMARYLIST = split(P.SUMMARYLIST,',');
end

if nargin > 2 && isempty(P.GTABLE)
	fprintf('%s: ** WARNING ** invalid timescale. Please check TIMESCALELIST of proc "%s"...\n',wofun,proc);
else
	d1 = cat(1,P.GTABLE.DATE1);
	d2 = cat(1,P.GTABLE.DATE2);
	if any(isnan(d1))
		P.DATELIM(1) = NaN;
	else
		P.DATELIM(1) = min(d1);
	end
	if any(isnan(d2))
		P.DATELIM(2) = NaN;
	else
		P.DATELIM(2) = max(d2);
	end
end

if nargout > 1
	N = readnodes(WO,P.SELFREF,P.DATELIM);
	% list of complete node's FID (expands multiple FIDs)
	P.FID_LIST = split(char(strcat({N.FID},{','}))',',');
end

if nargout > 2
	D = repmat(struct('t',[],'d',[],'CLB',struct('nx',0,'nm',[])),[length(N),1]);
	if ~isempty(P.GTABLE)
		if isfield(P,'RAWFORMAT')
			[D,P] = readfmtdata(WO,P,N);
		else
			fprintf('%s: ** WARNING ** no RAWFORMAT defined for PROC.%s! Cannot import data.\n',wofun,proc);
		end
	end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Normalize table list from P.*LIST strings
function P = tnorm(P,fd,nlist,dv)

P.(fd) = field2num(P,fd,[]);
lf = length(P.(fd));

if numel(dv) < nlist
	dv = repmat(dv(1),1,nlist);
end

if lf < nlist
	P.(fd)(lf+1:nlist) = dv(lf+1:nlist);
	fprintf('WEBOBS{readproc:tnorm}: ** WARNING ** inconsistent length or inexisting %s in %s timescale table. Fill with default value.\n',fd,P.SELFREF);
end

