function [c,xy]=ibln(fichier,a)
%IBLN	Import contour lines in GS ".BLN" format.
%	C=IBLN(FILENAME) imports a contour matrix C from the file FILENAME
%	in Golden Software Blanking format.
%
%  	The contour matrix C is a two row matrix of contour lines. Each
% 	contiguous drawing segment contains the value of the contour, 
% 	the number of (x,y) drawing pairs, and the pairs themselves.  
% 	The segments are appended end-to-end as
%  
%  	    C = [level1 x1 x2 x3 ... level2 x2 x2 x3 ...;
%  	         pairs1 y1 y2 y3 ... pairs2 y2 y2 y3 ...]
%
%	See also EBLN, CONTOURC and PCONTOUR.

%	Author: F. Beauducel
%   Created: OV, 1999
%   Modified: OVSG, 2004

c = load(fichier)';
i = 1;
j = 0;
xy = [];
while i > 0
 n = c(1,i);
 c(:,i) = c([2 1],i);
 xy = [xy;c(:,(i+1):(i+n))'];
 i = i + n + 1;
 j = j + 1;
 if i > length(c), i = -1; end
end
xylim = [min(xy(:,1)),max(xy(:,1)),min(xy(:,2)),max(xy(:,2))];
if nargin < 2
    disp(sprintf('File: %s imported (%d contour lines).',fichier,j))
    disp(sprintf('Xmin = %g, Xmax = %g, Ymin = %g, Ymax = %g.',xylim))
end
if nargout > 1
    xy = xylim;
end
