function egrd(x,y,z,fichier)
%EGRD	Export DEM in GS ASCII ".GRD" format.
%	EGRD(X,Y,Z,FILENAME) creates a file FILENAME in Golden Software 
%	ASCII grid format from a Digital Elevation Model data defined by 
%	X and Y (vectors or matrix) and matrix Z of elevations. 

%	F. Beauducel, IPGP 1996

fn = fnamanal(fichier,'grd');
fid = fopen(fn, 'w');
fprintf(fid, 'DSAA\r\n');
fprintf(fid, '%d %d\r\n', size(z'));
fprintf(fid, '%f %f\r\n', minmax(x));
fprintf(fid, '%f %f\r\n', minmax(y));
fprintf(fid, '%f %f\r\n', minmax(z));
fprintf(fid, '%4.1f ', z');
fclose(fid);
