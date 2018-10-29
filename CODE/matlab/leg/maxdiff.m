function y=maxdiff(x)
%MAXDIFF Maximum difference of matrix or vector.
%	MAXDIFF(X) returns max(X) - min(X).
%
%	See also MINMAX, MMAX and MMIN.
%
%	F. Beauducel OV, 1999.

k = find(isfinite(x));
y = max(max(x(k))) - min(min(x(k)));
