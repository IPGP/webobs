function s=plusminus(x)
%PLUSMINUS Plus or minus character.
%	PLUSMINUS(X) returns '+' for positive X value, '-' for negative, ' ' for zero.
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2014-04-17
s = char(44 - sign(x));
s(x==0) = ' ';
