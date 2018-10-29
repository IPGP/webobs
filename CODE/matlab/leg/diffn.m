function y = diffn(x,n)

%DIFFN	Difference on n spaced data.
%
%	DIFFN(X,N) computes differences of vector X, on n spaced data and
%	returns the result. DIFFN(X,1) is equivalent to DIFF(X) but has the
%	same length as X.
%
%  See also DIFFNF (same function but using FILTER)
%
%	(c) F.B., OVSG-IPGP 2006

if nargin < 2
	n = 0;
end
if size(x,1) == 1
	x = x';
end
yy = [x,x];
yy((n+1):end,1) = x(1:(end-n));
y = diff(yy')';