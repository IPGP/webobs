function y = rmean(x,dim)
%RMEAN  Real average or mean value.
%   For vectors, RMEAN(X) is the mean value of the elements in X, excluding
%   any NaN values. For matrices, RMEAN(X) is a row vector containing the 
%   mean value of each column, excluding any NaN values.
%
%   See also RSTD, MEAN, STD.

%   (c) F. Beauducel, OVSG 2001.

if size(x,1) == 1, x = x'; end
if length(x) == 0, y = []; end
for i = 1:size(x,2)
    k = find(~isnan(x(:,i)));
    n = length(k);
    if n == 0
        n = NaN;
    end
    y(:,i) = sum(x(k,i))/n;
end
