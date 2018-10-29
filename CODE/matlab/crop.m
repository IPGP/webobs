function y=crop(x,lim)
%CROP Crop values
%	CROP(X,LIM) returns scalar, vector or matrix X values cropped using
%	[MIN(LIM),MAX(LIM)] interval.
%
%	Author: F. Beauducel / IPGP
%	Created: 2015-01-05

if nargin ~= 2
	error('Two arguments are expected')
end

if numel(lim) < 2
	error('Argument LIM must be a vector of minimum 2 elements.')
end
y = [min(max(x,min(lim(:))),max(lim(:)))];

