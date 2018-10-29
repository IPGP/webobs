function [b,s] = wls(x,y,w)
%WLS Weighted least-squares
%	[B,E] = WLS(X,Y,W) computes linear coefficients Y = B(1)*X + B(2) and 
%	standard errors E, using inverse variance W.
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: ?
%	Updated: 2017-10-05


if nargin < 3
	w = ones(size(y));
end
X = [x(:),ones(size(x(:)))];
[b,s,mse] = lscov(X,y(:),w(:));
%s = s/sqrt(mse);

%S = sum(w);
%Sx = sum(w.*x);
%Sy = sum(w.*y);
%Sxx= sum(w.*x.^2);
%Sxy= sum(w.*x.*y);
%Delta = S*Sxx - (Sx)^2;
%a = (Sxx*Sy - Sx*Sxy)./Delta;
%b = (S*Sxy - Sx*Sy)./Delta;
