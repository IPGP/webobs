function y = rcumsum(x)
%RCUMSUM  Real cumulated sum.
%	For vectors, RCUMSUM(X) is the cumulated sum of the elements in X, excluding
%	any NaN values. For matrices, RCUMSUM(X) is a row vector containing the 
%	sum of each column, excluding any NaN values.
%
%	See also CUMSUM, RSTD, RMEAN.
%
%	Author: F. Beauducel, IPGP
%	Created: 2004
%	Updated: 2019-02-16

y = x;
for i = 1:size(x,2)
	k = find(~isnan(x(:,i)));
	if length(k) == 0;
		y(:,i) = cumsum(x(:,i));
	else
		y(k,i) = cumsum(x(k,i));
	end
end
