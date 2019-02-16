function y = mavr(x,n,p)
%MAVR	Moving average filtering.
%	MAVR(x,n) returns signal X filtered by a moving average	on N 
%	continuous data.
%
%	MAVR(x,n,p) adds a phase (late) of p data (p >=0).
%
%	MAVR(x,n,-1) eliminates phase distortion (non-causal). Uses FILTFILT 
%	funtion (Signal Processing Toolbox).
%
%	Author: F. Beauducel, IPGP/WEBOBS
%	Created: 1996
%	Updated: 2019-02-16

if nargin < 2
	error('MAVR requires at least 2 input arguments.')
end

if nargin < 3
	pp = 0;
	p = 0;
else 
	if p < 0
		pp = 0;
	else
		pp = p;
	end
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
xx0 = repmat(x0,[size(x,1) 1]);
if p >= 0
	y = filter(b,1,x - xx0);
else
	y = filtfilt(b,1,x - xx0);
end
y = y + xx0;

