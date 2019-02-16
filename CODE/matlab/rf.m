function y = rf(x)
%RF	Remove first value.
%
%	Y = RF(X) removes the first non NaN value from vector X and returns the
%	residual in vector Y. If X is a matrix,	RF(X) removes the first value 
%	from each column of the matrix.
%
%
%	Author: F. Beauducel, IPGP
%	Created: 1996 in Paris, France
%	Updated: 2019-02-16

y = x;

 for n = 1:size(x,2)
	k = find(~isnan(x(:,n)));
	if ~isempty(k)
		y(:,n) = y(:,n) - x(k(1),n);
	end
end
