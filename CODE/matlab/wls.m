function [b,s] = wls(x,y,w)
%WLS Weighted least-squares
%	[B,E] = WLS(X,Y,W) computes linear coefficients Y = B(1)*X + B(2) and 
%	standard errors E, using inverse variance W.
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: ?
%	Updated: 2026-08-12


if nargin < 3
	w = ones(size(y));
end

X = [x(:),ones(size(x(:)))];
% to avoid error in lscov, replaces Inf values of w by 1
w(isinf(w)) = 1;

[b,s] = lscov(X,y(:),w(:));

%s = s/sqrt(mse);
s(isinf(s)) = NaN;