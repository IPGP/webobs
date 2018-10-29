function [yc,p] = rl(x,y,w,n)
%RL	Linear regression.
%	RL(X,Y) returns the linear regression computed on XY points.
%
%	RL(X,Y,W,N) computes a weight-assigned linear regression. W is 
%	a vector containing relative weight for each value of Y. W will 
%	be normalized to integer values between 0 and N (default N = 10).
%
%	[Y,P] = RL(...) returns A*X+B coefficients in P = [B,A].
%
%	François Beauducel IPGP, 1996-1998

k = find(isfinite(x) & isfinite(y));
if nargin < 3
 p = polyfit(x(k),y(k),1);
else
 if nargin < 4, n = 10; end
 m = min(w(k));
 w = round(n*(w(k)-m)/(max(w(k))-m));
 xw = x(k);
 yw = y(k);
 for i=2:n
  k = find(w==i);
  if ~isempty(k)
   xw = [xw;xw(k)];
   yw = [yw;yw(k)];
  end
 end
 p = polyfit(xw,yw,1);
 clear xw yw w
end
yc = polyval(p,x);
