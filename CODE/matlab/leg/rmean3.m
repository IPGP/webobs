function y = rmean3(x)
%RMEAN3  Real average or mean value.
%   For vectors, RMEAN3(X) is the mean value of the elements in X, excluding
%   any NaN values. For matrices, RMEAN(X) is a row vector containing the 
%   mean value of each column, excluding any NaN values.
%
%   See also RSTD, MEAN, STD.

%   (c) F. Beauducel, OVSG 2001.

if size(x,1) == 1, x = x'; end
for j = 1:size(x,3)
    for i = 1:size(x,2)
        k = find(~isnan(x(:,i,j)));
        n = length(k);
        if n == 0
            n = NaN;
        end
        y(:,i,j) = sum(x(k,i,j))/n;
    end
end
