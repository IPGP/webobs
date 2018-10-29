function [b,p,x,y]=bvalue(m,m0,w,dw);
%BVALUE  Compute B-Value
%	BVALUE(M) computes B-Value of Gutenberg-Richter's law from a set of magnitudes M (vector).
%
%	BVALUE(M,M0,W,DW) uses optional parameters as follows:
%		M0 = minimal magnitude for linear regression calculation (default = all)
%		W = magnitude interval for histogram function (default = 1)
%		DW = number of magnitude shift for error calculation (default = 1)
%
%	Example: BVALUE(M,3,1,4) computes 4 histograms of 1-degree magnitude interval
%	(shifted by 1/4 = .25 degree), and calculates mean B-Value for magnitudes 3 and higher.

%   Author: F. Beauducel, OVSG-IPGP
%   Created : 2006-06-27
%   Updated : 2006-06-28

if nargin < 2
	m0 = min(m);
end

if nargin < 3
	w = 1;
end

if nargin < 4
	dw = 1;
else
	dw = ceil(abs(dw));
end

% Magnitude base intervals
dm = (-1:w:ceil(max(m)))';

ddm = 0:(w/dw):w*(1-1/dw);

for i = 1:length(ddm)
	x(:,i) = dm+ddm(i);
	y(:,i) = hist(m,x(:,i))';
	k = find(x(:,i)>=m0 & y(:,i)>0);
	p(i,:) = polyfit(x(k,i),log10(y(k,i)),1);
end

b = [-mean(p(:,1)),std(p(:,1))];
