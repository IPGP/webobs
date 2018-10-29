function y = rdetrend(t,x)
%RDETREND   Real remove linear trend.
%	    RDETREND(T,X) removes the best linear trend from X(T), excluding
%       NaN values if exist.
%
%       See also DETREND, RMEAN, RMIN, RMAX.
%
%	(c) F. Beauducel OVSG, 2002

k = find(~isnan(x));
t = t - t(1);
if ~isempty(k)
    p = polyfit(t(k),x(k),1);
    y = x - polyval(p,t);
else
    y = x;
end
