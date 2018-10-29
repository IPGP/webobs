function [x,y,z]=geo2cart(lat,lon,alt,a,e)
%GEO2CART Geodetic to cartesian geocentric coordinates

% default is WGS84
if nargin < 5
	a = 6378137.0;
	e = 0.08181919084;
end

% great normal of ellipsoid
N = a./sqrt(1 - e^2*sind(lat).^2);

x = (N + alt).*cosd(lat).*cosd(lon);
y = (N + alt).*cosd(lat).*sind(lon);
z = (N.*(1 - e^2) + alt).*sind(lat);
