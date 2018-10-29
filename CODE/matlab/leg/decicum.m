function y = decicum(x,r)
%DECIMCUM	Data decimation after cumulation.
%	    DECICUM(X,R) resamples data in vector X at 1/R times the
%   	original sample rate. The resulting resampled vector is
%   	R times shorter.
%
%   	(c) F. Beauducel, OVSG-IPGP 2001-06-29.

% Adds zeros to X to make length(X) multiple of R
x = [x;zeros([r-mod(length(x),r),1])];

% Sums every R elements of X
y = sum(reshape(x,r,length(x)/r))';

