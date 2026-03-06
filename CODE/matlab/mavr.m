function y = mavr(x,n,p)
%MAVR	Moving average filtering.
%	MAVR(x,n) returns signal X filtered by a moving average	on N 
%	continuous data. The first N-1 values of X will be NaN.
%
%	MAVR(x,n,p) adds a phase (late) of p data (p >= 0).
%
%	MAVR(x,n,-1) eliminates phase distortion (non-causal). Uses FILTFILT 
%	funtion (Signal Processing Toolbox).
%
%	Author: F. Beauducel, IPGP/WebObs
%	Created: 1996
%	Updated: 2026-02-22

if nargin < 2
	error('MAVR requires at least 2 input arguments.')
end

m = size(x,1);

if m == 1
	x = x';
end

pp = 0;
if nargin < 3
	p = 0;
else 
	pp = p*(p < 0);
end
b = zeros(1,n + pp);
b((pp+1):(n+pp)) = ones(1,n)/n;

y = x;

for i = 1:size(x,2)
    % must substract first data point to avoid border effects
	k1 = find(~isnan(x(:,i)),1,'first');
    x0 = 0;
	if ~isempty(k1)
		x0 = x(k1,i);
	end
    k = ~isnan(x(:,i));
    if p >= 0
        y(k,i) = filter(b,1,x(k,i) - x0);
        y(k(1:min(sum(k),n-1)),i) = NaN;
    else
        y(k,i) = filtfilt(b,1,x(k,i) - x0);
    end
    % add first data point back
    y(:,i) = y(:,i) + x0;
end

