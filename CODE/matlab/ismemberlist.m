function [lia,locb] = ismemberlist(A,B)
%ISMEMBERLIST True for set member in coma-separated list A
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2014-07-15
%   Updated: 2024-05-31

lia = false(size(A));
locb = zeros(size(A));
for n = 1:length(A)
	if any(ismember(split(A{n},','),B))
		lia(n) = true;
		locb(n) = n;
	end
end
