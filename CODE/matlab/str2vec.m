function v=str2vec(s)
%STR2VEC String list to numerical vector
%	STR2VEC(S) converts a coma delimited string list of numbers to a vector.
%
%	Author: F. Beauducel
%	Created: 2015-03-01
%	Updated: 2019-07-09

if ~isempty(s)
	v = textscan(s,'%s','Delimiter',',');
	v = str2double(v{:}');
else
	v = [];
end
