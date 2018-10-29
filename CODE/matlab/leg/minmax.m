function y=minmax(x)
%MINMAX	Minimum and maximum of matrix or vector.
%	MINMAX(X) returns a 2 rows matrix [min(X) max(X)].
%
%	See also MMAX and MMIN.
%
%	F. Beauducel IPGP, 1996.

k = find(isfinite(x));
y = [min(min(x(k))) max(max(x(k)))];
