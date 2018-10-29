function varargout=filedate(f,tz)
%FILEDATE Date of a file
%	FILEDATE(F) returns the date of file F in DATENUM format. Date is expressed
%	in the local system time zone.
%
%	FILEDATE(F,TZ) converts the date in user time zone TZ (in hours).
%
%
%	Created: 2017-01-10, in Yogyakarta, Indonesia
%	Uptaded: 2017-01-17


if exist(f,'file')
	F = dir(f);
	t = F.datenum;
else
	fprintf('** WARNING ** file "%s" does not exist.\n',f);
	t = 0;
end

% user_date = local_date + user_tz - local_tz
if nargin > 1
	t = t + (tz - gettz)/24;
end

if nargout > 0
	varargout{1} = t;
else
	display(datestr(t));
end
