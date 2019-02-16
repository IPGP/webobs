function y = rmean(x,dim)
%RMEAN  Real average or mean value.
%   For vectors, RMEAN(X) is the mean value of the elements in X, excluding
%   any NaN values. For matrices, RMEAN(X) is a row vector containing the 
%   mean value of each column, excluding any NaN values.
%
%   See also RSTD, MEAN, STD.
%
%   Author: F. Beauducel / OVSG / WEBOBS
%   Created: 2001
%   Updated: 2019-02-16

if length(size(x)) > 2
	error('RMEAN works only for vectors or matrices.')
end

if nargin < 2
	dim = 1;
end

switch dim
case 1
	y = nan(1,size(x,2));
	for i = 1:size(x,2)
	    k = find(~isnan(x(:,i)));
	    if length(k)
		    y(i) = mean(x(k,i));
	    end
	end
case 2
	y = nan(size(x,1),1);
	for i = 1:size(x,1)
	    k = find(~isnan(x(i,:)));
	    if length(k)
		    y(i) = mean(x(i,k));
	    end
	end
end
