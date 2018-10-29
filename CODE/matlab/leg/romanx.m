function s=romanx(x)
%ROMANX Roman numbers
%   ROMANX(X) returns integer X in roman format.

ss = {'I','II','III','IV','V','VI','VII','VIII','IX','X'};
if x > 0 & x < 11
    s = ss{round(x)};
else
    s = '';
end
