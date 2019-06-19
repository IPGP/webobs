function y = seacolorsc3(n)
%SEACOLORSC3 Sea colormap adapted from SeisComP3 maps
%
%	Author: Francois Beauducel <beauducel@ipgp.fr>

J = [linspace(51,144)',linspace(79,161)',linspace(122,178)']/255;

l = size(J,1);
if nargin < 2
	n = 256;
end
y = interp1(1:l,J,linspace(1,l,n),'*linear');

