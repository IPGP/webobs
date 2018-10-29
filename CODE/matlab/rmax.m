function y = rmax(x)
%RMAX  Real maximum value.
%   For vectors, RMAX(X) is the maximum of the elements in X, excluding
%   any NaN values. For matrices, RMAX(X) is a row vector containing the 
%   maximum of each column, excluding any NaN values.
%
%   See also MAX, RSUM, RSTD, RMEAN.

%   (c) F. Beauducel, OVSG 2002.

if size(x,1) == 1, x = x'; end
for i = 1:size(x,2)
    k = find(~isnan(x(:,i)));
    if length(k) == 0
        y(i) = NaN;
    else
        y(i) = max(x(k,i));
    end
end
