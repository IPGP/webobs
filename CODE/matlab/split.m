function c = split(s,d)
%SPLIT Split string into cell of words
%	SPLIT(S) splits the string or cell vector of string S (space delimited)
%	and returns a cell array of delimited words.
%
%	SPLIT(S,D) uses any character in string D as a possible delimiter.
%
%	Author: François BEAUDUCEL, IPGP
%	Created: 2009-10-09
%	Updated: 2014-12-16


if nargin < 1
	error('Not enough input argument.')
end

if nargin < 2
	d = ' ';
end

if ~ischar(d)
	error('D must be a string of delimiter character(s).')
end

if iscell(s)
	ss = s;
else
	ss = {s};
end

c = cell(size(ss));

for i = 1:length(ss)
	if isempty(ss{i})
		c{i} = '';
	else
		c(i) = textscan(ss{i},'%s','Delimiter',d);
	end
end	

if ~iscell(s)
	c = c{:}';
end

