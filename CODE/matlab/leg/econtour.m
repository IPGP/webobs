function ce=econtour(c,v,xy)
%ECONTOUR Contour matrix extraction.
%	CE=ECONTOUR(C,V) extracts the contour lines specified by scalar or 
%	vector V from the contour matrix C, and returns a new contour 
%	matrix CE.
%
%	CE=ECONTOUR(C,V,XYLIM) keeps only data included into the limits 
%	defined by XYLIM = [Xmin Xmax Ymin Ymax].
%
%  	The contour matrix C is a two row matrix of contour lines. Each
% 	contiguous drawing segment contains the value of the contour, 
% 	the number of (x,y) drawing pairs, and the pairs themselves.  
% 	The segments are appended end-to-end as
%  
%  	    C = [level1 x1 x2 x3 ... level2 x2 x2 x3 ...;
%  	         pairs1 y1 y2 y3 ... pairs2 y2 y2 y3 ...]
% 
%	See also IBLN, EBLN, CM2XYZ, CONTOURC and PCONTOUR.

%	F. Beauducel, OV 1999.

% Creates a matrix of zeros a little bit two long...
ce = zeros(size(c));

if length(v), vs = v; end
i = 1;
j = 1;
while i > 0
 n = c(2,i);
 if isempty(v), vs = c(1,:); end
 if length(find(c(1,i)==vs))
  k = (i+1):(i+n);
  if nargin > 2
   ks = find(c(1,k)>=xy(1) & c(1,k)<=xy(2) & c(2,k)>=xy(3) & c(2,k)<=xy(4));
  else ks = 1:length(k);
  end
  ns = length(ks);
  if ns > 0
   ce(:,j:(j+ns)) = [[c(1,i);ns] c(:,k(ks))];
   j = j + ns + 1;
  end
 end
 i = i + n + 1;
 if i > length(c), i = -1; end
end

% Erase the last zeros
ce(:,j:length(c)) = [];
