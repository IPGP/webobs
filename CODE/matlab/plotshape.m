function h=plotshape(varargin)
%PLOTSHAPE Plot 2D shape
%	PLOTSHAPE(X,Y,C) or PLOTSHAPE(XY,C) plots shapes with fill color C,
%	defined by coordinates X and Y or XY = [X,Y]. Multiple shapes are
%   separated by NaN.
%
%   If X/Y pairs define a closed polygon, i.e., the last point is equal to the
%   first one (same coordinates), then the PATCH function is used to plot
%   the shape, with possible fill color.
%   In other cases, i.e. X/Y pairs define a point, a line, or a curve, then the
%   PLOT function will be used.
%
%   PLOTSHAPE(...,param1,value1,...) adds optional param/value pairs that
%   will be applied to the drawing command (PLOT or PATCH).
%
%
%	Author: François Beauducel, IPGP/IRD
%	Created: 2020-02-27 in Yogyakarta (Indonesia)
%   Updated: 2025-05-09

if nargin > 1 && size(varargin{1},2) == 2
	x = varargin{1}(:,1);
	y = varargin{1}(:,2);
	c = varargin{2};
	iarg = 3;
elseif nargin > 2
	x = varargin{1};
	y = varargin{2};
	c = varargin{3};
	iarg = 4;
else
	error('not enough input arguments.')
end

k1 = 1;
kn = find(isnan(x) | isnan(y));

for n = 0:length(kn)
	if n == length(kn)
		k2 = length(x);
	else
		k2 = kn(n+1) - 1;
	end
	k = k1:k2;
	h = patch(x(k),y(k),c,varargin{iarg:end});
	k1 = k2 + 2;
end