function y=min0(x)
%MIN0	Non-zero minimum.
%	MIN0(X) returns the smallest non-zero value of X (in amplitude).
%
%	F. Beauducel IPGP, 1997.

for i = 1:size(x,2)
 xi = x(find(x(:,i)),i);
 y(i) = min(abs(xi)).*sign(min(xi));
end