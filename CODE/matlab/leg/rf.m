function y = rf(x)
%RF	Remove first value.
%
%	RF(X) returns vector(s) X minus its first value(s) X(1).
%
%	F. Beauducel IPGP, 1996.

if size(x,1) == 1
 y = x - x(1);
else
 y = x - ones([size(x,1) 1])*x(1,:);
end