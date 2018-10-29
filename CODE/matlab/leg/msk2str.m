function s=msk2str(x)
%MSK2STR MSK intensity scale.
%   MSK2STR(X) returns X value on the MSK scale (roman numbers).
%
%   MSK2STR allows half-levels, e.g., MSK2STR(7.5) = 'VII-VIII'.
%
% Author: F. Beauducel, IPGP
% Created: 2009-01-19

% definition of 23 half-levels in roman numbers
ss = {'I','I-II','II','II-III','III','III-IV','IV','IV-V','V','V-VI','VI','VI-VII','VII','VII-VIII','VIII','VIII-IX','IX','IX-X','X','X-XI','XI','XI-XII','XII'}';

% X < 1 = I
k = find(x < 1);
if ~isempty(k)
    x(k) = 1;
end

% X > 12 = XII
k = find(x > 12);
if ~isempty(k)
    x(k) = 12;
end

s = ss(floor(x*2)-1);

if length(s) == 1
    s = char(s);
end
