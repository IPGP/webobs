function k=isinto(x,lim,varargin)
%ISINTO Is into an interval limits.
%	ISINTO(X,[XMIN,XMAX]) returns a logical vector of the same size as X,
%	containing 1 where X is into the interval defined by [XMIN,XMAX]
%	inclusively, and 0 elsewhere.
%
%	ISINTO(X,[XA,XB],'degree') or ISINTO(X,[XA,XB],'radian') considers 
%	values of X as angles in degree or in radian, respectively. The angle 
%	interval limits is defined from XA to XB. Note that XA is not 
%	necessarily lower than XB due to possible angle wrapping, and [XB,XA] 
%	defines the complementary angle.
%
%	ISINTO(X,Y) where Y is a vector or matrix, uses min/max values of Y
%	to define the interval limits. This syntax is not compatible with angle
%	options.
%
%	ISINTO(...,'exmin') excludes min interval limit, includes max.
%	ISINTO(...,'exmax') excludes max interval limit, includes min.
%	ISINTO(...,'exclude') excludes both interval limits.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2014-12-17
%	Updated: 2022-05-22

if numel(lim)<2
	error('Second input argument must be a two-element vector.')
end

if any(strcmpi(varargin,'exclude')) || (any(strcmpi(varargin,'exmin')) && any(strcmpi(varargin,'exmax')))
	opt = 'exclude';
elseif any(strcmpi(varargin,'exmin'))
	opt = 'exmin';
elseif any(strcmpi(varargin,'exmax'))
	opt = 'exmax';
else
	opt = '';
end

if any(strcmpi(varargin,'degree'))
	x = mod(x+360,360);
	xmin = mod(lim(1)+360,360);
	xmax = mod(lim(2)+360,360);
elseif any(strcmpi(varargin,'radian'))
	x = mod(x+2*pi,2*pi);
	xmin = mod(lim(1)+2*pi,2*pi);
	xmax = mod(lim(2)+2*pi,2*pi);
else
	xmin = min(lim(:));
	xmax = max(lim(:));
end

switch lower(opt)
case 'exclude'
	k = x > xmin & x < xmax;
case 'exmin'
	k = x > xmin & x <= xmax;
case 'exmax'
	k = x >= xmin & x < xmax;
otherwise
	k = x >= xmin & x <= xmax;
end
