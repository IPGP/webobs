function y = rmax(x)
%RMAX  Real maximum value.
%   For vectors, RMAX(X) is the maximum of the elements in X, excluding
%   any NaN values. For matrices, RMAX(X) is a row vector containing the 
%   maximum of each column, excluding any NaN values.
%
%   See also MAX, RSUM, RSTD, RMEAN.
%
%   Author: F. Beauducel / OVSG / WEBOBS
%   Created: 2002
%   Updated: 2026-04-07

for i = 1:size(x,2)
    k = (~isnan(x(:,i)) & isfinite(x(:,i)));
    if sum(k) == 0
        y(i) = NaN;
    else
        y(i) = max(x(k,i));
    end
end
