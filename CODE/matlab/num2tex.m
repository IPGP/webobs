function s=num2tex(x,fmt)
%NUM2TEX Basic numerals to TeX string
%	NUM2TEX(X) returns a string using TeX syntax.
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2019-02-28 in Yogyakarta (Indonesia)
%	Updated: 2020-09-20

if nargin < 2
	fmt = '%g';
end
s = sprintf(fmt,x);
s = regexprep(s,'[eE]([\+\-])([0-9]*)','{\\times}10^{$1$2}');
s = regexprep(s,'{([\-]*)\+*0*','{$1'); % removes + in exponent and trailing zero
