function varargout=xyw2lim(xyw,r)
%XYW2LIM Box limits calculation to respect a given X/Y ratio.
%	XYLIM = XYW2LIM(XYW,R) computes, from 3-element vector XYW = [X0,Y0,W]
%	defining a central box coordinates X0,Y0 and a box width W, the 4 
%	limits XYLIM = [X1,X2,Y1,Y1] that respects the ratio X/Y = R, by 
%	adjusting the box height.
%
%   [XLIM,YLIM]=XYW2LIM() also possible.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2017-07-20 in Yogyakarta, Indonesia
%   Updated: 2025-03-17

if nargin < 2
	r = 1;
end
w2 = xyw(3)*[-.5,.5];
xylim = [xyw(1) + w2,xyw(2) + w2/r];

if nargout == 2
    varargout{1} = xylim(1:2);
    varargout{2} = xylim(3:4);
else
    varargout{1} = xylim;
end