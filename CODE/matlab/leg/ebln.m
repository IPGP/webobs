function ebln(c,fichier,r)
%EBLN	Export contour lines in GS ".BLN" format.
%	EBLN(C,FILENAME) creates a file FILENAME in Golden Software Blanking
%	format from the matrix of contour lines C = CONTOURC(...).
%
%	EBLN(...,R) reduces the number of points per line by a factor R.
%
%	See also IBLN and PCONTOUR.

%	F. Beauducel, OV 1999.

if nargin < 3, r = 1; end
[fn,fh,fe] = fnamanal(fichier,'bln');
fid = fopen(fn, 'wt');
i = 1;
while i > 0
 n = c(2,i);
 nr = floor((n-1)/r)+1;
 % To not create a point (interpreted as symbol)
 if nr > 1
  fprintf(fid,'%g %g\n',[nr;c(1,i)]);
  fprintf(fid,'%g %g\n',c(:,(i+1):r:(i+n)));
 end
 i = i + n + 1;
 if i > length(c), i = -1; end
end
fclose(fid);
