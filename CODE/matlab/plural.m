function s = plural(n,s)
%PLURAL word's pural
%	PLURAL(N,S) adds a 's' at the end of string S if N > 1. 

if nargin < 2
	s = '';
end
if n > 1
	s = [s,'s'];
end

