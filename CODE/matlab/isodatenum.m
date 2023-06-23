function x = isodatenum(dt)
%ISODATENUM Convert ISO date string to serial date number.
%	ISODATENUM(D) returns Matlab serial date number (as DATENUM)
%	from ISO 8601 cell array of strings dates D:
%		YYYY
%		YYYY-MM
%		YYYY-MM-DD
%		YYYY-MM-DD hh:mm:ss
%
%	Author: F. Beauducel, IPGP
%	Created: 2009-10-19
%	Updated: 2014-11-14

if ~iscell(dt)
	dt = cellstr(dt);
end

x = nan(size(dt));
k = find(~isempty(dt) & ~strcmp(dt,'NA'));
for kk = 1:length(k)
	tmp = textscan(dt{k(kk)},'%s','Delimiter','-: ');
	v = str2double(tmp{:});
	% completes cell array to match 6-column (necessary for DATENUM exigences)
	l = length(v);
	dv = [0,1,1,0,0,0];
	dv(1:min(l,6)) = v(1:min(l,6));
	x(k(kk)) = datenum(dv);
end
