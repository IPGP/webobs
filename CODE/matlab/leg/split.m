function c = split(s,d);
%SPLIT Split string into cell
%	SPLIT(S) splits the string S (space delimited) and returns
%	a cell array.
%
%	SPLIT(S,D) uses any character in string D as delimiter
%
%	Author: François BEAUDUCEL, IPGP
%	Created: 2009-10-09
%	Modified: 2009-10-09

if nargin < 2
	d = ' ';
end

if ~iscell(s)
	s = {s};
end

for i = 1:size(s,1)
	r = s{i};
	j = 1;
	while (~isempty(r))
		[t,r] = strtok(r,d);
		c{i,j} = t;
		j = j + 1;
	end
end	
