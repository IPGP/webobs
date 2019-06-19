function varargout=sunrise(varargin)
%SUNRISE Computes sunset and sunrise time.
%	SUNRISE(LAT,LON,ALT,TZ) displays time of sunrise and sunset at 
%	location latitude LAT (decimal degrees, positive towards North), 
%	longitude LON (decimal degrees, positive towards East), altitude ALT 
%	(in meters above sea level) for today. Time zone TZ (in hour) is
%	recommanded but optional (default is the computer system time zone).
%
%	SUNRISE(LAT,LON,ALT,TZ,DATE) computes sunrise and sunset time for
%	date DATE (in any datenum compatible format). DATE can be scalar,
%	vector or matrix of dates (strings or datenum).
%
%	SUNRISE by itself displays time of sunrise and sunset at your
%	approximate location (needs Java activated and internet connection).
%
%	[SRISE,SSET,NOON]=SUNRISE(...) returns time of sunrise, sunset and noon
%	in datenum format. To get only hours, try datestr(srise,'HH:MM').
%
%	DAYLENGTH=SUNRISE(...) returns the day length of light expressed in 
%	fraction of day. Multiply by 24 to get hours.
%
%   LAT=SUNRISE(DAYLENGTH,ALT,DATE,'day2lat') estimates the latitude from  
%	day length (in fraction of day) and altitude ALT (in meters) for the 
%	day DATE. If ALT is ommitted it uses sea level (0 m). If DATE is 
%	ommitted it computes for today.
%
%   [LAT,LON]=SUNRISE(SRISE,SSET,ALT,'sun2ll') estimates the latitude and
%	longitude from sunrise and sunset dates/time, both in GMT time zone 
%	(TZ = 0), and altitude ALT (in meters). If ALT is ommitted it uses sea 
%	level (0 m).
%
%	Note: reverse function does not try to fit the sunrise and sunset times, 
%	but it uses both noon time (average of sunrise/sunset) and day length
%	(difference between sunrise/sunset) values to look for the best 
%	latitude and longitude.
%
%
%	Examples:
%		>> sunrise(37.71,15.03,2031,2,'2017-07-17')
%		Sunrise: 17-Jul-2017 05:43:10 +02
%		Sunset:  17-Jul-2017 20:30:39 +02
%		Day length: 14h 47mn 30s
%
%		>> sunrise
%		Location: -8.65°N, 115.2167°E, 0m
%		Sunrise: 16-Oct-2017 05:57:07 +08
%		Sunset:  16-Oct-2017 18:14:31 +08
%		Day length: 12h 17mn 24s
%
%       >> sunrise(14/24,0,'2019-04-21','day2lat')
%       Estimated latitude: 49.076°N
%
%		>> sunrise('2019-04-22 04:52:12','2019-04-22 18:51:04',0,'sun2ll')
%		Estimated location: 47.9995°N, 2.00142°E
%
%		Plot sunrise and sunset time variation for the year:
%		days = datenum(2017,1,1:365);
%		[srise,sset,noon]=sunrise(48.8,2.3,0,2,days);
%		plot(days,rem([srise;sset;noon]',1)*24,'linewidth',4)
%		datetick('x')
%
%
%	Reference:
%	    https://en.wikipedia.org/wiki/Sunrise_equation
%
%	Author: Francois Beauducel, IPGP
%	Created: 2017-10-10 in Paris, France
%	Updated: 2019-04-22

%	Release history:
%	[2019-04-21] v1.3
%		- adds reverse functions to compute lat/lon from sunrise/sunset
%		  (thanks to a suggestion by Jaechan Lim)
%	[2018-10-17] v1.2
%		- changes to ip-api.com for automatic geolocalisation
%	[2017-10-16] v1.1
%		- removes dependency from jsondecode function
%		- automatic detection of local timezone (needs Java)
%	[2017-10-10] v1.0
%		- initial function
%
%	Copyright (c) 2019, François Beauducel, covered by BSD License.
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


day2lat = any(strcmpi(varargin,'day2lat'));
sun2ll = any(strcmpi(varargin,'sun2ll'));

% --- Forward problem: sunrise(lat,lon,alt,tz,dte)
if ~day2lat && ~sun2ll
	if nargin < 5
		dte = floor(now);
	else
		dte = floor(datenum(varargin{5}));
	end

	if nargin < 4 || isempty(varargin{4})
		if exist('java.util.Date','class')
			tz = -java.util.Date().getTimezoneOffset/60;
		else
			tz = 0;
		end
	elseif nargin > 3
		tz = varargin{4};
	end

	if nargin < 3
		alt = 0;
	else
		alt = varargin{3};
	end

	% try to guess the location...
	if nargin < 2 || isempty(varargin{1}) || isempty(varargin{2})
		%api = 'http://freegeoip.net/json/';
		api = 'http://ip-api.com/json';
		if exist('webread','file')
			S = webread(api);
			if isfield(S,'lat') && isfield(S,'lon')
				lat = S.lat;
				lon = S.lon;
			else
				lat = NaN;
				lon = NaN;
			end
		else
			% for Matlab release < 2014b
			s = urlread(api);
			x = textscan(regexprep(s,'[{}"]',''),'%s','delimiter',',');
			lat = jsd(x{1},'lat:');
			lon = jsd(x{1},'lon:');
		end
		if isnan(lat) || isnan(lon)
			error('Cannot determine automatic location... sorry!')
		end
		autoloc = 1;
	else
		lat = varargin{1};
		lon = varargin{2};
		autoloc = 0;
	end

	% main computation
	[omega,noon] = omeganoon(lat,lon,alt,tz,dte);
	sset = noon + omega/360;
	srise = noon - omega/360;
	dayl = omega/180;

	switch nargout
		case 0
			if autoloc
				fprintf('Location: %g°N, %g°E, %gm\n',lat,lon,alt);
			end
			for n = 1:numel(dte)
				fprintf('Sunrise: %s %+03d\nSunset:  %s %+03d\nDay length: %gh %gmn %gs\n\n', ...
					datestr(srise(n)),tz,datestr(sset(n)),tz, ...
					floor(24*dayl),floor(mod(24*dayl,1)*60),round(mod(1440*dayl,1)*60));
			end
		case 1 % daylength
			varargout{1} = dayl;
		case 2 % sunrise, sunset
			varargout{1} = srise;
			varargout{2} = sset;
		case 3 % sunrise, sunset, noon
			varargout{1} = srise;
			varargout{2} = sset;
			varargout{3} = noon;
	end

end

% --- Inverse problem: sunrise(daylength,alt,dte,'day2lat') to latitude
if day2lat
    if nargin > 1
		dayl = varargin{1};
		if dayl < 0 || dayl > 1
			error('DAYLENGTH must be a value between 0 and 1.');
		end
		if nargin < 3
			alt = 0;
		else
			alt = varargin{2};
		end
		if nargin < 4
			dte = floor(now);
		else
			dte = floor(datenum(varargin{3}));
		end
		vlat = -90:90;
		vomega = omeganoon(vlat,0,alt,0,dte); % supposes longitude = 0
		[vdl,k] = unique(vomega/180);
		lat = interp1(vdl,vlat(k),dayl);
		if nargout > 0
			varargout{1} = lat;
		else
			fprintf('Estimated latitude: %g°N\n',lat);
		end
	else
		error('DAYLENGTH must be defined for reverse computation.')
    end
end


% --- Inverse problem: sunrise(srise,sset,alt,'sun2ll') to lat/lon
if sun2ll
    if nargin > 2
		srise = datenum(varargin{1});
		sset = datenum(varargin{2});
		dayl = sset - srise;
		if dayl < 0 || dayl > 1
			error('SUNRISE and SUNSET times must be within 24 hours.')
		end
		if nargin < 4
			alt = 0;
		else
			alt = varargin{3};
		end
		
		% longitude from noon date and time
		vlon = -180:180;
		[~,vnoon] = omeganoon(0,vlon,alt,0,round(srise)); % supposes latitude = 0
		[vno,k] = unique(vnoon);
		lon = interp1(vno,vlon(k),(srise+sset)/2);
		
		% latitude from daylength
		vlat = -90:90;
		vomega = omeganoon(vlat,lon,alt,0,round(srise));
		[vdl,k] = unique(vomega/180);
		lat = interp1(vdl,vlat(k),dayl);
		if nargout > 1
			varargout(1:2) = {lat,lon};
		else
			fprintf('Estimated location: %g°N, %g°E\n',lat,lon);
		end
	else
		error('SUNRISE and SUNSET must be defined for reverse computation.')
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [omega,noon] = omeganoon(lat,lon,alt,tz,dte)
% main function that computes daylength and noon time
% https://en.wikipedia.org/wiki/Sunrise_equation

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

% hour angle (day expressed in geometric degrees)
h = (sind(-0.83 - 2.076*sqrt(alt)/60) - sind(lat).*sind(delta))./(cosd(lat).*cosd(delta));
omega = acosd(h);
% to avoid meaningless complex angles: forces omega to 0 or 12h
omega(h<-1) = 180;
omega(h>1) = 0;
omega = real(omega);

% noon
noon = Jt + datenum(2000,1,1,12,0,0) - 2451545 + tz/24;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y=jsd(X,f)
% very simple interpretation of JSON string
k = find(~cellfun(@isempty,strfind(X,f)),1);
if ~isempty(k)
	y = str2double(regexprep(X{k},'.*:(.*)','$1'));
else
	y = NaN;
end
