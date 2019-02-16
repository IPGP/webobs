function y = diffn(x,n)
%DIFFN	N-spaced difference.
%	DIFFN(X,N), for a vector X, is [... X(i)-X(i-N) ... X(n)-X(n-N)].
%	Because the first N values are not defined, they are set to NaN.
%	DIFFN(X,N), for a matrix X, is the matrix of row N-spaced differences.
%
%	DIFFN(X,1) is equivalent to DIFF(X) but has the same length as X, and 
%	first value is NaN.
%
%	Author: François Beauducel <beauducel@ipgp.fr> / WEBOBS
%	Created: 1996
%	Updated: 2019-02-16


error(nargchk(1,2,nargin))

if ~isnumeric(x)
		error('X argument must be numeric.')
end
%if size(x,1) == 1
%	x = x';
%end

if nargin < 2
	n = 0;
end
if ~isnumeric(n) | numel(n) ~= 1 | n < 0 | mod(n,1) ~= 0
	error('N argument must be a scalar positive integer.')
end

a = [1,zeros(1,n)];
b = [1,zeros(1,n-1),-1];
y = filter(b,a,x - repmat(x(1,:),size(x,1),1));
y(1:n,:) = NaN;

