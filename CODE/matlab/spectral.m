function J = spectral(m)
%SPECTRAL Red, orange, yellow, green, blue colormap
%   SPECTRAL(M) returns an M-by-3 matrix containing the ryb colormap, a
%	a diverging colormap where luminance is highest at the midpoint, and 
%	decreases towards differently-colored endpoints. SPECTRAL, by itself,
%	is the same length as the current figure's colormap. If no figure 
%	exists, MATLAB uses the length of the default colormap.
%
%   See also JET, RYB, POLARMAP, COLORMAP.
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2020-11-25 in Yogyakarta (Indonesia)

if nargin < 1
   f = get(groot,'CurrentFigure');
   if isempty(f)
      m = size(get(groot,'DefaultFigureColormap'),1);
   else
      m = size(f.Colormap,1);
   end
end

% 16-colors base
rgb = [ ...
    94    79   162;
    68   112   177;
    65   153   181;
   101   193   165;
   145   210   164;
   190   229   160;
   228   244   153;
   245   251   176;
   254   243   171;
   254   223   139;
   253   190   110;
   249   149    85;
   243   108    67;
   222    75    75;
   190    36    73;
   158     1    66;
];

n = size(rgb,1);
J = interp1(1:n,rgb/255,linspace(1,n,m));
