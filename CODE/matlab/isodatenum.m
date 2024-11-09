function x = isodatenum(dt)
%ISODATENUM Convert ISO date string to serial date number.
%	ISODATENUM(D) returns Matlab serial date number (as DATENUM)
%	from ISO 8601 cell array of strings dates D:
%		YYYY
%		YYYY-MM
%		YYYY-MM-DD
%		YYYY-MM-DD hh:mm:ss
%
%	ISODATENUM is tolerent to weird separator character (all but numerical).
%
%	Author: F. Beauducel, IPGP
%	Created: 2009-10-19
%	Updated: 2022-06-13

if ~iscell(dt)
	dt = cellstr(dt);
end

x = nan(size(dt));
k = find(~strcmp(dt,'') & ~strcmp(dt,'NA'));
for kk = 1:length(k)
	v = str2num(regexprep(dt{k(kk)},'[^0-9]',' '));
	% completes cell array to match 6-column (necessary for DATENUM exigences)
	l = length(v);
	dv = [0,1,1,0,0,0];
	dv(1:min(l,6)) = v(1:min(l,6));
	x(k(kk)) = datenum(dv);
end
