function dx=tickscale(x,r)
%TICKSCALE Tick "best" interval
%	TICKSCALE(X) returns a rounded subvalue interval that divides X into
%	"natural" multiples of 1, 2 or 5.
%
%	When X is a scalar, TICKSCALE returns the tick interval as a scalar.
%
%	When X is a vector or a matrix, TICKSCALE uses minimum and maximum 
%	values of X, and returns a vector of tick values.
%
%	TICKSCALE(X,R) applies a ratio of R.
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2013-09-16 in Paris, France
%	Updated: 2018-01-14

if nargin < 2
	r = 1;
end

if isscalar(x)
	d = x;
else
	lim = [min(x(:)),max(x(:))];
	d = diff(lim);
end
d = d/r;
m = 10^floor(log10(d));
p = ceil(d/m);
if p <= 1
	dd = .1*m;
elseif p == 2
	dd = .2*m;
elseif p <= 5
	dd = .5*m;
else
	dd = m;
end

if isscalar(x)
	dx = dd;
else
	dx = ceil(lim(1)/dd)*dd:dd:floor(lim(2)/dd)*dd;
end

