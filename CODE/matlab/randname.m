function s=randname(n,name)
%RANDNAME Random name string
%	RANDNAME returns a random 16-char alpha string.
%	RANDNAME(N) returns a N-char length.
%	RANDNAME(N,NAMES) uses cell array of strings NAMES to ensure a
%	unique new name.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2014-01-04, Paris, France
%	Updated: 2022-11-28

if nargin < 1
	n = 16;
end

if nargin < 2
	name = {''};
end

if ~isnumeric(n) || ~isscalar(n) || n < 1 || round(n) ~= n
	error('N must be a positive scalar integer.')
end

%rng('shuffle');
rng(round(rem(now,1)*1e9)); % for GNU Octave compatibility
s = '';
while isempty(s) || any(strcmp(s,name))
	s = char(floor(rand(1,n)*26) + 65 + round(rand(1,n))*32);
end
