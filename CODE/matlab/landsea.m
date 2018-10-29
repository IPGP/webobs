function c=landsea(m);
%LANDSEA DEM colormap.
%
%	F. Beauducel, OV 1999.

% Matrix taken from a ".clr" GS file.
c0 = [0   0   0   0;
      3   0  51 153;
     29   0 255 255;
     65  51 204  51;
     94 153 102  51;
    100 255 255 255];

if nargin == 0
 m = 256;
end
i = (0:(m-1))';
c = zeros([m 3]);
c(:,1) = interp1(c0(:,1)*m/100,c0(:,2),i)/255;
c(:,2) = interp1(c0(:,1)*m/100,c0(:,3),i)/255;
c(:,3) = interp1(c0(:,1)*m/100,c0(:,4),i)/255;
