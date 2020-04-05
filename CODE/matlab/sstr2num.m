function x=sstr2num(s)
%SSTR2NUM Secure str2num
%	X = SSTR2NUM('str') returns an evaluation of string 'str' after removing any
%	characters except alphanumeric, matrix or arithmetic expressions.
%
%	SSTR2NUM('') returns NaN and not empty like STR2NUM.
%
%	Note: This is for security purpose: str2num uses eval function which is unsecure.
%	Letters are still allowed for functions, but since quote and exclamation is
%	forbidden, it avoids possibility of calling any system command.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2015-01-01
%	Updated: 2020-04-04

if strcmpi(s,'NaN') || isempty(s)
	x = NaN;
else
	% replaces any non-numeric characters before evaluating string
	x = str2num(regexprep(s,'[^\d\.+-\/\*a-zE,;:\ \(\)\[\]]',''));
end
