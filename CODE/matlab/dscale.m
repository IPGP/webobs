function l=dscale(w,bins)
%DSCALE Scale length
%	L=DSCALE(W) returns optimized scale length L for a graph width W. W can
%	be scalar, vector or matrix and L will have the same size. L values 
%	will be chosen as the closest significant digit from 1, 2 or 5. To 
%	limit L to a portion R of W, simply use W/R as input.
%
%	DSCALE(W,BINS) uses base vector BINS instead of default [1,2,5].

if nargin < 2
	bins = [1,2,5];
end

w2 = abs(w(:));
m = 10.^floor(log10(w2));
l = reshape(interp1(bins,bins,floor(w2./m),'nearest','extrap').*m,size(w));


