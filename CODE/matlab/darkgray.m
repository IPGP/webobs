function rgb = darkgray(x)
%DARKGRAY Dark gray color.
%	DARKGRAY returns a 10% gray RGB color vector.
%	DARKGRAY(X) returns a X% dark gray (X between 0 = black and 100 = white).

if nargin < 1
	x = 10;
end
rgb = ones(1,3)*x/100;
