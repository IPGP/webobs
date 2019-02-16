function y = mmed(x,n)
%MMED	Moving median filtering.
%	MMED(X,N) returns signal X filtered by a moving median on N continuous
%	previous data (filtering is causal). If X is a matrix, each column is 
%	filtered individualy.
%
%	MMED(X,[NB,NF]) filters vector or matrix X using NB elements before 
%	the current and NF elements after. Use [N,N]/2 to make a centered 
%	moving median of N points (or N+1 if N is even).
%
%
%	Author: F. Beauducel, IPGP
%	Created: 2018-01-23 in Yogyakarta, Indonesia
%	Updated: 2019-02-16

if nargin < 2
	error('MMED requires at least 2 input arguments.')
end

if numel(n) > 2 || any(n) < 1
	error('N argument must be a positive integer or 2-element integers.')
end

m = size(x,1);

% inits the output
y = nan(size(x));

n = floor(n);
if numel(n) == 2
	nb = n(1);
	nf = n(2);
else
	nb = n;
	nf = 0;
end
nn = sum(n);

% main loop for matrices (multiple vectors)
for i = 1:size(x,2)
	% makes a MxN matrix
	yy = nan(m,nn);
	for ii = 1:nn
		yy(ii:end,ii) = x(1:(end-ii+1),i);
	end
	if issorted({'2015a',version('-release')})
		y(:,i) = median(yy,2,'omitnan');
	else
		y(:,i) = median(yy,2);
	end
end
