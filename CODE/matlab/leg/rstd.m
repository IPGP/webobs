function y = std(x)
%RSTD  Real average or mean value.
%   For vectors, RSTD(X) is the standard deviation, excluding
%   any NaN values. For matrices, RSTD(X) is a row vector containing the 
%   standard deviation of each column, excluding any NaN values.
%
%   See also RMEAN, MEAN, STD.

%   (c) F. Beauducel, OVSG 2001.

if size(x,1) == 1, x = x'; end
for i = 1:size(x,2)
    k = find(~isnan(x(:,i)));
    if length(k)
        y(i) = std(x(k,i));
    else    
        y(i) = NaN;
    end
end
