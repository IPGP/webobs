function y = rsum(x)
%RSUM  Real sum value.
%   For vectors, RSUM(X) is the sum of the elements in X, excluding
%   any NaN values. For matrices, RSUM(X) is a row vector containing the 
%   sum of each column, excluding any NaN values.
%
%   See also SUM, RSTD, RMEAN.

%   (c) F. Beauducel, OVSG 2001.

if size(x,1) == 1, x = x'; end
for i = 1:size(x,2)
    k = find(~isnan(x(:,i)));
    if length(k) == 0
        y(i) = NaN;
    else
        y(i) = sum(x(k,i));
    end
end
