function y=azgap(x,y)
%AZGAP Azimuth gap
%	AZGAP(X,Y) returns the maximum azimut gap (in degree) of points
%	(X,Y) relative to the origin (0,0). X and Y are vectors of
%	coordinates of the same size.
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2017-12-30, in Bandung (Indonesia)
%	Updated: 2017-12-31

% converts into complex vectors
z = complex(x(:),y(:));
m = length(z);

% sorts in trigonometric order
[~,k] = sort(angle(z));
daz = nan(m,1);
for n = 1:m
	daz(n) = angle(z(k(mod(n,m)+1))/z(k(n)));
end
y = max(mod(daz*180/pi + 360,360));
