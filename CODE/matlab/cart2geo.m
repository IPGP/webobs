function [lat,lon,alt]=cart2geo(x,y,z,a,e)
%CART2GEO Cartesian geocentric to geodetic coordinates

% default is WGS84
if nargin < 5
	a = 6378137.0;
	e = 0.08181919084;
end

[l,p,h] = ign0012(x,y,z,a,e);
lon = l*180/pi;
lat = p*180/pi;
alt = h;
