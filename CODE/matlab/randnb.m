function r = randnb(sz,x0,xstd,xlow,xhigh)
%RANDB Normally distributed pseudorandom numbers with boudaries.
%	R = RANDNB(N,X0,XSTD,XLOW,XHIGH) returns an N-by-N matrix containing
%	pseudorandom values drawn from the standard normal distribution, using
%	standard deviation XSTD, centered on X0 and limited to boudaries
%	[XLOW,XHIGH].
%	
%	R = RANDNB([M,N], ...) or RANDNB([M,N,P...], ...) returns an M-by-N or 
%	M-by-N-by-P-by-...	array. RANDSB(SIZE(A)) returns an array the same
%	size as A.
%

if isscalar(sz)
	sz = [sz,sz];
end
n = prod(sz);

if nargin < 2
	x0 = 0;
end

if nargin < 3
	xstd = 1;
end

if nargin < 5
	xlow = -Inf;
	xhigh = +Inf;
end

% proportion of kept samples from normal distribution
p = diff((1/2)*(1 + erf((([xlow,xhigh] - x0)/xstd)/sqrt(2))));

r = [];

% loop to ensure the right number of samples
while numel(r) < n
	rr = rnd([ceil(max(n - numel(r),n/100)/p),1],xstd,x0,xlow,xhigh);
	r = cat(1,r(:),rr);
end

r = reshape(r(1:n),sz);

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rr=rnd(sz,xstd,x0,xlow,xhigh)
rr = randn(sz)*xstd + x0;
rr(rr<xlow | rr>xhigh) = [];