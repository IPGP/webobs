function tz = gettz
%GETTZ Get local time zone
%	GETTZ returns the time zone expressed in hours.
%
%	GETTZ uses system command 'date'. Example:
%
%	   >> !/bin/date +%z
%	   +0700
%	   >> gettz
%	   ans =
%	        7
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2017-01-17 in Yogyakarta, Indonesia
%	Update: 2017-02-03
%

[rc,w] = wosystem('/bin/date +%z','chomp'); % returns string ±HHMM
if rc == 0 && length(w) == 5
	tz = str2double(w(1:3)) + str2double(w([1,4:5]))/60;
else
	fprintf('WEBOBS{gettz}: ** Warning: problem to get TZ value with system command "date" [%s].\n',w);
	tz = 0;
end

