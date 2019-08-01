function c = split(s,d)
%SPLIT Split string into cell of words
%	SPLIT(S) splits the string or cell vector of string S (space delimited)
%	and returns a cell array of delimited words.
%
%	SPLIT(S,D) uses any character in string D as a possible delimiter.
%
%	Any escaped delimiter character (preceeded by \) in the string will not
%	be splitted.
%
%	Author: François BEAUDUCEL, IPGP
%	Created: 2009-10-09
%	Updated: 2019-08-01


if nargin < 1
	error('Not enough input argument.')
end

if nargin < 2
	d = ' ';
end

if ~ischar(d)
	error('D must be a string of delimiter character(s).')
end

% unit separator ASCII character
us = char(31);

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
		% substitutes escaped delimiters
		ss{i} = strrep(ss{i},['\',d],us);
		c(i) = textscan(ss{i},'%s','Delimiter',d);
		% puts back escaped delimiters
		c{i} = strrep(c{i},us,d);
	end
end	

if ~iscell(s)
	c = c{:}';
end

