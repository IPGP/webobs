function y=strcommon(x)
%STRCOMMON Common part of strings
%   STRCOMMON(C) return the longest common part of strings in cell C, i.e.,
%   same character at the same position for all strings.
%
%
%   Author: F. Beauducel, OVPF-IPGP
%   Created: 2025-12-29, La Plaine des Cafres (La Réunion)

if ~iscell(x) || ~all(cellfun(@ischar,x))
    error('input must be a cell array of strings.')
end

if length(x) < 2
    y = x{1};
else
    c = char(x(:)); % converts into a single array of char N x ...
    k = all(diff(c,1)==0,1); % true for each char common to string pairs
    y = x{1}(k); % returns the match for first string
end
