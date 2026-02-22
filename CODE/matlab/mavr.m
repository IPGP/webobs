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
%	Author: F. Beauducel, IPGP
%	Created: 1996
%	Updated: 2023-07-18

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

% must remove first data point to avoid border effects
x0 = zeros(1,size(x,2));
for i = 1:size(x,2)
	k = find(~isnan(x(:,i)),1,'first');
	if ~isempty(k)
		x0(i) = x(k,i);
	end
end
if p >= 0
	y = filter(b,1,x - x0);
    if length(y) > 0
        y(1:min(length(y),n-1)) = NaN;
    end
else
	y = filtfilt(b,1,x - x0);
end
y = y + x0;

