function s = mkstatus(WO,S)
%MKSTATUS Writes NODES status from associated GRID (PROC or VIEW)
%       MKSTATUS(WO,S) exports last data NODE status in NODES.SQL_DB_STATUS database:
%           - S.NODE = NODE full qualified ID (GRIDTYPE.GRIDNAME.NODEID)
%           - S.STA = NODE status value (in %)
%           - S.ACQ = NODE sampling completeness value (in %)
%           - S.TS = last data timestamp (DATENUM format)
%           - S.TZ = GRID TZ (0 = TU, -4 = GMT-4)
%           - S.COMMENT = string of comment (e.g., with last data values)
%
%	MKSTATUS uses system call to sqlite3.
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2001-06-01 in Guadeloupe (French West Indies)
%   Updated: 2017-09-05


wofun = sprintf('WEBOBS{%s}',mfilename);

NODES = readcfg(WO,WO.CONF_NODES);
f = field2str(NODES,'SQL_DB_STATUS',sprintf('%s/NODESSTATUS.db',WO.PATH_DATA_DB));

if isnan(S.TS)
	tv = zeros(1,6);
else
	tv = datevec(S.TS);
end

if isnan(S.STA)
	S.STA = 0;
end

if isnan(S.ACQ)
	S.ACQ = 0;
end

fprintf('%s: updating %s (%s) ... ',wofun,f,S.NODE);

wosystem(sprintf('sqlite3 %s "create table if not exists status (NODE varchar(150) PRIMARY KEY, STA int, ACQ int, TS timestamp, UPDATED timestamp, COMMENT varchar(1000));"',f),'warning');

wosystem(sprintf('sqlite3 %s "replace into status values (''%s'',%03d,%03d,''%4d-%02d-%02d %02d:%02d:%02.0f%+06.2f'',CURRENT_TIMESTAMP,''%s'')"', ...
	f,S.NODE,round([S.STA,S.ACQ]),tv,S.TZ,S.COMMENT),'warning');

fprintf('done.\n');

