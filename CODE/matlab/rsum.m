function y = rsum(x,dim)
%RSUM  Real sum value.
%   For vectors, RSUM(X) is the sum of the elements in X, excluding
%   any NaN values. For matrices, RSUM(X) is a row vector containing the 
%   sum of each column, excluding any NaN values.
%
%	RSUM(X,2) computes the sum of each row (along dimension 2).
%
%   See also SUM, RSTD, RMEAN.
%
%   Author: F. Beauducel / OVSG / WEBOBS
%   Created: 2001
%   Updated: 2019-02-16

if nargin < 2
	dim = 1;
end

% Matlab's habit: line vector is processed as colum vector
if dim == 2
	x = x';
	y = nan(size(x,2),1);
else
	y = nan(1,size(x,2));
end
for i = 1:size(x,2)
	k = find(~isnan(x(:,i)));
	if ~isempty(k)
		y(i) = sum(x(k,i));
	end
end
