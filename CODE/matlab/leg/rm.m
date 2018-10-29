function y = rm(x)
%RM	Remove mean value.
%	RM(X) returns vector or matrix X minus its mean value(s).
%
%	F. Beauducel IPGP, 1996.

s = size(x,2);
for i = 1:s
 k = isfinite(x(:,i));
 y(:,i) = x(:,i);
 y(k,i) = x(k,i) - mean(x(k,i));
end
