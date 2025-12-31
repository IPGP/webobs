function s=nameunit(nm,un)
%NAMEUNIT Print name (unit)
%   NAMEUNIT(NAME,UNIT) returns "NAME (UNIT)" or "NAME" if UNIT is empty.

if isempty(un)
    s = nm;
else
    s = sprintf('%s (%s)',nm,un);
end