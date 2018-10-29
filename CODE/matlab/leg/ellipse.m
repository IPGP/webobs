function ellipse(x1,y1,x2,y2,p,s)
%ELLIPSE	Ellipse plot.
%		ELLIPSE(X1,Y1,X2,Y2,P) draws a graph that displays X2 and Y2 as horizontal
%		and vertical bases of ellipses emanating from the positions 
%		defined by X1 ans Y1. P is the scaling factor.
%
%		ELLIPSE(X1,Y1,X2,Y2,P,'S') use line style 'S' where 'S' is any legal 
%		linetype as described under the PLOT command.
%
%		See also COMPASS, ROSE, FEATHER, and QUIVER.
%
%		François Beauducel, IPGP 20-12-1995

ell=p*exp(2*pi*sqrt(-1)*(0:.05:1))';

if nargin == 5
   s = 'r-';
elseif nargin < 5 
   error('Sucker! Not enough arguments.');
end

z = x1 + i*y1;
if length(z) ~= length(x2+i*y2)
   error('X1, Y1, X2 and Y2 must be same length.');
end

a = real(ell) * x2' + i* imag(ell) * y2' + ones(21,1) * z.';
plot(real(a), imag(a), s)
axis('equal')
