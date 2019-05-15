function y = rmedian(x,dim)
%RMEDIAN  Real median value.
%   For vectors, RMEDIAN(X) is the median value of the elements in X, excluding
%   any NaN values. For matrices, RMEAN(X) is a row vector containing the 
%   median value of each column, excluding any NaN values.
%
%   See also MEDIAN, RMEAN.
%
%   Author: F. Beauducel / WEBOBS
%   Created: 2019-05-14 in Yogyakarta (Indonesia)

if nargin < 2
	dim = 1;
end

switch dim
case 1
	y = nan(1,size(x,2));
	for i = 1:size(x,2)
	    k = find(~isnan(x(:,i)));
	    if length(k)
		    y(i) = median(x(k,i));
	    end
	end
case 2
	y = nan(size(x,1),1);
	for i = 1:size(x,1)
	    k = find(~isnan(x(i,:)));
	    if length(k)
		    y(i) = median(x(i,k));
	    end
	end
end
