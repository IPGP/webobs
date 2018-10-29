function y = xcum(t,x,td)
%XCUM	Data decimation after cumulation.
%	    XCUM(T,X,TD) computes the sum of X(T) for regular time intervals around
%       each value of TD.
%       XCUM works as an histogram but returns the sum of data instead of 
%       the number of occurences.
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created : 2001-10-08
%   Mpdofied : 2004-02-04

if length(td) > 1
    r = diff(td(1:2))/2;
else
    r = .5;
end
y = zeros(size(td));
for i = 1:length(td)
    k = find(t >= td(i)-r & t < td(i)+r);
    y(i) = sum(x(k));
end
