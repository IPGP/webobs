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
%	F. Beauducel IPGP, 1996-1997.

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
b = zeros(1,n+pp);
b(pp+1:n+pp) = ones(1,n)/n;
x0 = repmat(x(1,:),[size(x,1) 1]);
if p >= 0
 y = filter(b,1,x-x0) + x0;
else
 y = filtfilt(b,1,x-x0) + x0;
end
