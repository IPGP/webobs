function [ y ] = linfilter(t,d,n,m)
%LINFILTER Linear filter
%   LINFILTER(T,D,N,M) returns signal D(T) removed from:
%		N = 1 : median value
%		N = 2 : linear trend
%		N > 2 : spline fitting based on N-point cubic interpolation
%
%	Linear and spline fitting are based on vector D which is decimated by
%	a factor of M (default is M = 100).
%
%	LINFILTER uses DECIM function.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2014-09-22

if nargin < 3
	n = 2;
else
	n = ceil(n);
end

if nargin < 4
	m = 100;
end

t1 = decim(t,m,'median');
d1 = decim(d,m,'median');
if n < 2
	y = d - median(d);
else
	b = linspace(1,length(d1),n);
	ti = interp1(t1,b);
	di = interp1(d1,b);
	y = d - interp1(ti,di,t,'cubic');
end

end

