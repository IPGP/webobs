function c = scolor(i,cmap)
%SCOLOR Returns a RGB color
%   SCOLOR(I) returns a color [R G B] for index I, using a default 11-color palette.
%
%   SCOLOR(I,CMAP) selects the color I in a CMAP colormap (Nx3 RGB matrix).
%
%   If I exceeds the number of colors N, a modulo is applied: MOD(I-1,N)+1.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 1999
%	Updated: 2025-04-29

if nargin < 2 || size(cmap,2) ~= 3
    % Default color map
    cmap = [ ...
    0.1     0.3     0.6;
    0.3     0.6     0;
    0.8     0       0;
    0.8     0.5     0;
    0.1     0.7     0.8;
    0.8     0.1     0.7;
    0.5	0	0.5;
    0       0.3     0.8;
    0       0.8     0.3;
    1.0     0.3     0.3;  
    0.7     0.7       0;
    0.3     0.3     0.3;
    ];
end

c = cmap(mod(i-1,size(cmap,1))+1,:);
