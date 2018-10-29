function varargout=sunrise(lat,lon,alt,tz,dte)
%SUNRISE Computes sunset and sunrise time.
%	SUNRISE(LAT,LON,ALT,TZ) displays time of sunrise and sunset at 
%	location latitude LAT (decimal degrees, positive towards North), 
%	longitude LON (decimal degrees, positive towards East), altitude ALT 
%	(in meters above sea level) for today. Time zone TZ (in hour) is
%	optional (default will be the computer system time zone).
%
%	SUNRISE(LAT,LON,ALT,TZ,DATE) computes sunrise and sunset time for
%	date DATE (in any datenum compatible format). DATE can be scalar,
%	vector or matrix of dates.
%
%	SUNRISE by itself displays time of sunrise and sunset at your
%	approximate location (needs Java activated and internet connection).
%
%	[SRISE,SSET,NOON]=SUNRISE(...) returns time of sunrise, sunset and noon
%	in datenum format. To get only hours, try datestr(srise,'HH:MM').
%
%	DAYLENGTH=SUNRISE(...) returns the day length of light expressed in 
%	fraction of days. Multiply by 24 to get hours.
%
%
%	Examples:
%		>> sunrise(37.71,15.03,2031,2,'2017-07-17')
%		Sunrise: 17-Jul-2017 05:43:10 +02
%		Sunset:  17-Jul-2017 20:30:39 +02
%
%		>> sunrise
%		Location: -8.65 °N, 115.2167 °E, 0 m
%		Sunrise: 16-Oct-2017 05:57:07 +08
%		Sunset:  16-Oct-2017 18:14:31 +08
%
%		Plot sunrise and sunset time variation for the year:
%		days = datenum(2017,1,1:365);
%		[srise,sset,noon]=sunrise(48.8,2.3,0,2,days);
%		plot(days,rem([srise;sset;noon]',1)*24,'linewidth',4)
%		datetick('x')
%
%	Reference:
%	    https://en.wikipedia.org/wiki/Sunrise_equation
%
%	Author: Francois Beauducel, IPGP
%	Created: 2017-10-10 in Paris, France
%	Updated: 2018-10-17

%	Release history:
%	[2018-10-17] v1.2
%		- changes to ip-api.com for automatic geolocalisation
%	[2017-10-16] v1.1
%		- removes dependency from jsondecode function
%		- automatic detection of local timezone (needs Java)
%	[2017-10-10] v1.0
%		- initial function
%
%	Copyright (c) 2017, François Beauducel, covered by BSD License.
%	All rights reserved.
%
%	Redistribution and use in source and binary forms, with or without 
%	modification, are permitted provided that the following conditions are 
%	met:
%
%	   * Redistributions of source code must retain the above copyright 
%	     notice, this list of conditions and the following disclaimer.
%	   * Redistributions in binary form must reproduce the above copyright 
%	     notice, this list of conditions and the following disclaimer in 
%	     the documentation and/or other materials provided with the 
%	     distribution
%	                           
%	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%	IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
%	TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
%	PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
%	OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
%	SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
%	LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
%	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
%	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
%	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
%	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


if nargin < 5
	dte = floor(now);
else
	dte = floor(datenum(dte));
end

if nargin < 4 || isempty(tz)
	if exist('java.util.Date','class')
		tz = -java.util.Date().getTimezoneOffset/60;
	else
		tz = 0;
	end
end

if nargin < 3
	alt = 0;
end

% try to guess the location...
auto = 0;
if nargin < 2
	%s = urlread('http://freegeoip.net/json/');
	s = urlread('http://ip-api.com/json');
	x = textscan(regexprep(s,'[{}"]',''),'%s','delimiter',',');
	lat = jsd(x{1},'lat:');
	lon = jsd(x{1},'lon:');
	if ~isnan(lat) && ~isnan(lon)
		auto = 1;
	else
		error('Cannot determine automatic location... sorry!')
	end
end

% Starts computation

% number of days since Jan 1st, 2000 12:00 UT
n2000 = dte - datenum(2000,1,1,12,0,0) + 68.184/86400;

% mean solar moon
Js = n2000 - lon/360;

% solar mean anomaly
M = mod(357.5291 + 0.98560028*Js,360);

% center
C = 1.9148*sind(M) + 0.0200*sind(2*M) + 0.0003*sind(3*M);

% ecliptic longitude
lambda = mod(M + C + 180 + 102.9372,360);

% solar transit
Jt = 2451545.5 + Js + 0.0053*sind(M) - 0.0069*sind(2*lambda);

% Sun declination
delta = asind(sind(lambda)*sind(23.44));

% hour angle
omega = acosd((sind(-0.83 - 2.076*sqrt(alt)/60) - sind(lat).*sind(delta))./(cosd(lat).*cosd(delta)));

noon = Jt + datenum(2000,1,1,12,0,0) - 2451545 + tz/24;
sset = noon + omega/360;
srise = noon - omega/360;


switch nargout
	case 0
		if auto
			fprintf('Location: %g °N, %g °E, %g m\n',lat,lon,alt);
		end
		for n = 1:numel(dte)
			fprintf('Sunrise: %s %+03d\nSunset:  %s %+03d\n',datestr(srise(n)),tz,datestr(sset(n)),tz);
		end
	case 1 % daylength
		varargout{1} = sset - srise;
	case 2 % sunrise, sunset
		varargout{1} = srise;
		varargout{2} = sset;
	case 3 % sunrise, sunset, noon
		varargout{1} = srise;
		varargout{2} = sset;
		varargout{3} = noon;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y=jsd(X,f)
k = find(~cellfun(@isempty,strfind(X,f)),1);
if ~isempty(k)
	y = str2double(regexprep(X{k},'.*:(.*)','$1'));
else
	y = NaN;
end
