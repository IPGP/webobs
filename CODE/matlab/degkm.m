function x=degkm(lat)
%DEGKM One latitude degree in km
%	DEGKM returns the mean km value for 1 degree of latitude.
%	DEGKM(LAT) returns the value of 1 degree of longitude in km, at the
%	latitude LAT (in decimal degree).
%
%	DEGKM use an ellipsoidal Earth (WGS84 model).
%
%
%	Author: F. BEAUDUCEL / WEBOBS
%	Created: 2014
%	Updated: 2015-01-16

% WGS84 ellipsoid
a = 6378.137;		% semi-major axis (km)
e = 0.08181919084;	% first eccentricity
b = a*sqrt(1 - e^2);	% semi-minor axis (km)

x = pi*(a + b)/360;
if nargin > 0
	x = x*cosd(lat);
end

