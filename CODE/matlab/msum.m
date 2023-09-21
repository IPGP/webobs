function y = msum(t,x,tw)
%MSUM Moving sum.
%	Y = MSUM(T,X,TW) computes the sum of values of X(T) in each preceeding
%   time window TW (in days), where T is a time vector in DATENUM format,
%   same length as the number of lines in X. X can be an irregularly space
%   data vector.
%
%	If X is a matrix, MSUM2 work down the columns. Y has the same size as X.
%
%	Author: F. Beauducel / WebObs
%	Created: 2023-09-21
%	Updated: 2023-09-21
%
y = x;
k = 1;
for i = 2:numel(y)
	y(i) = y(i-1) + x(i);
	for j = k:i-1
		if (t(i) - tw) > t(j)
			y(i) = y(i) - x(j);
			k = k + 1;
		else
			break;
		end
	end
end
