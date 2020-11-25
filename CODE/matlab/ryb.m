function J = ryb(m)
%RYB Red, yellow, blue colormap
%   RYB(M) returns an M-by-3 matrix containing the ryb colormap, also known
%	as RdYlBu, a diverging colormap where luminance is highest at the 
%	midpoint, and decreases towards differently-colored endpoints. RYB, by
%   itself, is the same length as the current figure's colormap. If no
%   figure exists, MATLAB uses the length of the default colormap.
%
%   See also JET, POLARMAP, COLORMAP.
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
    38    41   112;
    64   100   169;
    88   140   190;
   123   177   209;
   160   209   227;
   197   230   240;
   229   246   239;
   252   254   201;
   252   237   168;
   251   208   135;
   250   174   104;
   243   130    84;
   228    85    63;
   206    45    46;
   171    16    43;
   143     6    38;	
];

n = size(rgb,1);
J = interp1(1:n,rgb/255,linspace(1,n,m));
