function y = rmin(x)
%RMIN  Real minimum value.
%   For vectors, RMIN(X) is the minimum of the elements in X, excluding
%   any NaN values. For matrices, RMIN(X) is a row vector containing the 
%   minimum of each column, excluding any NaN values.
%
%   See also MIN, RSUM, RSTD, RMEAN.

%   (c) F. Beauducel, OVSG 2002.

if size(x,1) == 1, x = x'; end
for i = 1:size(x,2)
    k = find(~isnan(x(:,i)));
    if length(k) == 0
        y(i) = NaN;
    else
        y(i) = min(x(k,i));
    end
end
