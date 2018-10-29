function y=arrondi(x,n)
%ARRONDI Round with fixed significant numbers
%   ARRONDI(X,N) rounds X keeping N significant numbers.
%
%   Author: F. Beauducel, IPGP
%   Created: 2009-01-16

og = 10.^(floor(log10(x) - n + 1));
y = round(x./og).*og;
