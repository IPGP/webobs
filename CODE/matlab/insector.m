function k=insector(a,a1,a2)
%INSECTOR Test if azimuth is in a sector
%	INSECTOR(A,B,C) or INSECTOR(A,[B,C]) returns true when azimuth angle A
%	is between azimuth B and azimuth C (all in clockwise degree from North)
%	and returns false otherwise.
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2015-02-07

if nargin < 3 & size(a1,2)==2
	a2 = a1(:,2);
	a1 = a1(:,1);
end

% converts to cartesian
[x,y] = pol2cart(pi/2 - a*pi/180,1);
[x1,y1] = pol2cart(pi/2 - a1*pi/180,1);
[x2,y2] = pol2cart(pi/2 - a2*pi/180,1);

% computes z-component of the two cross products A^B and A^C
k = a1 == -Inf | a2 == Inf | ((x.*y1 - x1.*y) >= 0 & (x.*y2 - x2.*y) <= 0);

