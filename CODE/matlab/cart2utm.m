function [enu,senu] = cart2utm(xyz,sxyz)
%CART2UTM Cartesian geocentric to UTM coordinates with errors
%	ENU=CART2UTM(XYZ) converts the cartesian geocentric coordinates
%	XYZ=[X,Y,Z] to Universal Transverse Mercator WGS84 projection 
%	ENU=[E,N,U].
%
%	[ENU,SENU]=CART2UTM(XYZ,SXYZ) estimates the errors on UTM
%	components from errors on cartesian components [sX,sY,sZ].
%
%	Author: François Beauducel, WEBOBS/IPGP, <beauducel@ipgp.fr>
%	Created: 2016-04-21, Ternate, Indonesia
%	Updated: 2016-04-22
	
[lat,lon,u] = cart2geo(xyz(:,1),xyz(:,2),xyz(:,3));
[e,n] = ll2utm(lat,lon);
enu = [e,n,u];

if nargin == 2
	% error estimation using random values for each point, and take the
	% maximum of resulting error after full convertion.
	senu = zeros(size(enu));
	for i = 1:size(xyz,1)
		r = 2*rand(1000,3) - 1;	% random values in [-1,1] interval
		xx = xyz(i,1) + sxyz(i,1)*r(:,1);
		yy = xyz(i,2) + sxyz(i,2)*r(:,2);
		zz = xyz(i,3) + sxyz(i,3)*r(:,3);
		[lat,lon,uu] = cart2geo(xx,yy,zz);
		[ee,nn] = ll2utm(lat,lon);
		senu(i,:) = [max(abs(e(i) - ee)),max(abs(n(i) - nn)),max(abs(u(i) - uu))];
	end
end