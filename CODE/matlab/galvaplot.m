function varargout=galvaplot(t,d,par,varargin)
%GALVAPLOT Galvanometer-like plot
%	GALVAPLOT(T,D,[DX,DY,R]) plots data vector D vs time vector T simulating a 
%	galvanometer rotary trace around the median value of D, with a virtual radius R.
%	R has no dimension and is expressed in multiple of T maximum interval. DX and 
%	DY fix the paper size in T and D units, respectively.
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2017-01-06, in Yogyakarta, Indonesia
%	Updated: 2017-01-10

if ~all(isnumeric(par)) || numel(par) ~= 3
	error('[DX,DY,R] must be a 3-element vector.')
end

% virtual center of rotation distance (normalized)
if par(3) > 0
	r = par(3);
else
	r = Inf;
end

% angle
a = atan2((d - median(d))/par(2),2*r);

h = plot(t + (1 - cos(a))*r*par(1),d,varargin{:});
if nargout > 0
	varargout{1} = h;
end
