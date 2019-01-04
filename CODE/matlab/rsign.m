function y = rsign(x)
%RSIGN Signum function excluding NaN
%	Same function as SIGN except that SIGN(NaN) = 0.
y = sign(x);
y(isnan(x)) = 0;
