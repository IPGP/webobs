function c=ibln(fichier)
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

%	F. Beauducel, OV 1999-2002.

c = load(fichier)';
i = 1; j = 0;
while i > 0
 n = c(1,i);
 c(:,i) = c([2 1],i);
 i = i + n + 1;
 j = j + 1;
 if i > length(c), i = -1; end
end
disp(sprintf('IBLN: %d contour lines imported from %s.',j,fichier))
