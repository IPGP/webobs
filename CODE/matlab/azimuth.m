function [s,a]=azimuth(x,locale)
%AZIMUTH Gives compass direction from angle.
%   AZIMUTH(X) returns a string of 16-point compass direction ('N','ESE',...)
%   from azimuth angle X (in degrees from North, clockwise). If X is a vector,
%   it returns a cell array of the same size.
%
%   AZIMUTH(X,LOCALE) returns a full description string ('north','east-southeast',...)
%   using language LOCALE (default is en_EN).
%
%   [S,A]=AZIMUTH(...) returns also the azimuth A in radians.
%   A has the same size as X.
%
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2005-08-09
%   Updated: 2017-09-16


X = readcfg('${ROOT_CODE}/etc/azimuth.conf','keyarray');

sz = length(X);
a = (90 - x)*pi/180;
k = mod(round(a*sz/(2*pi)),sz) + 1;

if nargin < 2
	s = cat(1,{X(k).az});
elseif isfield(X,locale)
	s = cat(1,{X(k).(locale)});
else
	s = cat(1,{X(k).en_EN});
end

if length(x) == 1
	s = s{:};
end

