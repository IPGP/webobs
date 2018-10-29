function lia = ismemberlist(A,B)
%ISMEMBERLIST True for set member in coma-separated list
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2014-07-15
%   Updated: 2016-07-10

lia = false(size(A));
for n = 1:length(A)
	lia(n) = any(ismember(split(A{n},','),B));
end
