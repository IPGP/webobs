function k=isinto(x,lim,opt)
%ISINTO Is into an interval
%	ISINTO(X,[XMIN,XMAX]) returns a bolean vector of the same size as X,
%	containing 1 where X is into the interval defined by [XLIM,XMAX]
%	inclusively, and 0 elsewhere.
%
%	ISINTO(X,Y) where Y is a vector or matrix, uses min/max values of Y
%	to define interval limits.
%
%	ISINTO(...,'exmin') excludes min interval limit, includes max.
%	ISINTO(...,'exmax') excludes max interval limit, includes min.
%	ISINTO(...,'exclude') excludes both interval limits.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2014-12-17
%	Updated: 2020-04-14

if isempty(lim)
	lim = NaN;
end
if nargin < 3
	opt = '';
end

switch lower(opt)
case 'exclude'
	k = x>min(lim(:)) & x<max(lim(:));
case 'exmin'
	k = x>min(lim(:)) & x<=max(lim(:));
case 'exmax'
	k = x>=min(lim(:)) & x<max(lim(:));
otherwise
	k = x>=min(lim(:)) & x<=max(lim(:));
end
