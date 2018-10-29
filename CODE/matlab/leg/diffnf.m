function y = diffnf(x,n)

%DIFFNF	Difference on n spaced data.
%
%	DIFFNF(X,N) computes differences of vector X, on n spaced data and
%	returns the result. DIFFNF(X,1) is equivalent to DIFF(X) but has the
%	same length as X.
%
%  DIFFNF uses the FILTER function, while DIFFN uses simple matrix
%  operation.
%
%	(c) F.B., IPGP 1996

if nargin < 2, n = 0; end
a = zeros(1,n+1);
a(1) = 1;
b = zeros(1,n+1);
b(1) = 1;
b(n+1) = -1;
y = filter(b,a,x-ones(size(x(:,1)))*x(1,:));
