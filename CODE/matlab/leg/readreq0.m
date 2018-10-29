function R=readreq(req,proc);
%READREQ Read WEBOBS request file
%   R = READREQ(REQ,PROC) returns a structure variable R containing every field key and
%   corresponding value from the request directory REQ and proc name PROC.
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2013-12-25
%   Updated: 2013-12-31

global WO;
readcfg;

% reads the req/REQUEST.rc file (from postREQ.pl)
freq = sprintf('%s/REQUEST.rc',req);
if ~exist(freq,'file')
	error('WEBOBS{readreq}: cannot find request file %s.',freq);
end

R = readcfg(freq);

% converts dates in DATENUM format
R.DATE1 = isodatenum(R.DATE1);
R.DATE2 = isodatenum(R.DATE2);

R.TIMESCALE = '';
R.OUTDIR = sprintf('%s/PROC.%s',req,proc);
R.SELFREF = proc;
R.NAME = '';
R.STATUS = 0;

% converts to numeric some fields
keys = fieldnames(R);
keys = keys(ismember(keys,{'TZ','DATESTR','PPI','MARKERSIZE','CUMULATE','DECIMATE','POSTSCRIPT','EXPORTS'}));
for n = 1:length(keys)
	R.(keys{n}) = str2num(R.(keys{n})); %NOTE: str2num() allows some syntax interpretation like '5/1440' (5 mn expressed in days)
end

% completes some fields from proc
P = readproc(proc);
R.COPYRIGHT = P.COPYRIGHT;
R.COPYRIGHT2 = P.COPYRIGHT2;
R.LOGO_FILE = P.LOGO_FILE;
R.LOGO2_FILE = P.LOGO2_FILE;
