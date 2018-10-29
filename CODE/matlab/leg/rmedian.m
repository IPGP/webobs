function y = rmedian(x)
%RMEDIAN  Real median value.
%   For vectors, RMEDIAN(X) is the mean value of the elements in X, excluding
%   any NaN values. For matrices, RMEDIAN(X) is a row vector containing the 
%   mean value of each column, excluding any NaN values.
%
%   See also RSTD, RMEAN, RSTD, MEDIAN.

%   (c) F. Beauducel, IPGP 2009.

if size(x,1) == 1, x = x'; end
if length(x) == 0, y = []; end
for i = 1:size(x,2)
    k = find(~isnan(x(:,i)));
    n = length(k);
    y(:,i) = median(x(k,i));
end
