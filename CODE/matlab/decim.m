function y = decim(x,r,method)
%DECIM	Data decimation after moving average.
%	DECIM(X,R) resamples data in vector X at 1/R times the
%	original sample rate. The resulting resampled vector is
%	R times shorter. X can be a matrix (multiple data vectors).
%
%   DECIM(X,R,'median') uses median value instead of mean.
%
%	F. Beauducel, IPGP 1996-2014.

if length(r) > 1
	error('R must be a scalar!')
end

if nargin > 2 && strcmpi(method,'median')
	med = 1;
else
	med = 0;
end

l = length(x);
y = nan(floor(l/r),size(x,2));
for i = 1:r:l,
	j = i:min([i+r l]);
	if length(j) == 1
		j = [l l];
	end
	if med
		y(floor((i-1)/r)+1,:) = median(x(j,:));
	else
		y(floor((i-1)/r)+1,:) = mean(x(j,:));
	end
end

