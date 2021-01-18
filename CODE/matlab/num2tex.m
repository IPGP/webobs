function ss=num2tex(x,fmt)
%NUM2TEX Basic numerals to TeX string
%	NUM2TEX(X) returns a string using TeX syntax for optimal text print. If
%	X is a vector or matrix, returns a cell array of strings, same size as X.
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2019-02-28 in Yogyakarta (Indonesia)
%	Updated: 2021-01-18

if nargin < 2
	fmt = '%g';
end

ss = cell(size(x));

for n = 1:numel(x)
	s = sprintf(fmt,x(n));
	if x(n) >= 1e3 && x(n)==round(x(n))
		s = fliplr(regexprep(fliplr(s),'([0-9][0-9][0-9])','$1 '));
	end
	s = regexprep(s,'[eE]([\+\-])([0-9]*)','{\\cdot}10^{$1$2}');
	s = regexprep(s,'{([\-]*)\+*0*','{$1'); % removes + in exponent and trailing zero
	ss{n} = s;
end

if numel(x) == 1
	ss = ss{:};
end

