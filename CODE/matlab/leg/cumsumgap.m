function y = cumsumgap(x)
%CUMSUMGAP

k = find(isnan(x));
x(k) = 0;
y = cumsum(x);
y(k) = NaN;

