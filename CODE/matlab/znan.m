function y=znan(x)
%ZNAN Zero if NaN
%   ZNAN(X) returns 0 if X is NaN, and X otherwise.
%
%   Author: F. Beauducel, WEBOBS
%   Created: 2023-08-17

y = x;
y(isnan(x)) = 0;
