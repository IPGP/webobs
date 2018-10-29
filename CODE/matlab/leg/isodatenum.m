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

if ~iscell(dt)
	dt = cellstr(dt);
end

x = NaN*zeros(size(dt));
k = find(~isempty(dt) & ~strcmp(dt,'NA'));
if ~isempty(k)
	dv = split(dt(k),'-: ');

	% completes cell array to match 3-column or 6-column (necessary for DATENUM exigences)
	sz = size(dv);
	if sz(2) < 3
		dv = [dv,cell(sz(1),3-sz(2))];
	end
	if sz(2) > 3 & sz(2) < 6
		dv = [dv,cell(sz(1),6-sz(2))];
	end

	% replaces empty cells by '0'
	kk = find(cellfun('isempty',dv));
	dv(kk) = {'0'};

	x(k) = datenum(str2double(dv));

end
