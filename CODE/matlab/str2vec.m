function v=str2vec(s)
%STR2VEC String list to numerical vector
%	STR2VEC(S) converts a coma delimited string list of numbers to a vector.
%
%	Author: F. Beauducel
%	Created: 2015-03-01

v = textscan(s,'%s','Delimiter',',');
v = str2double(v{:}');
