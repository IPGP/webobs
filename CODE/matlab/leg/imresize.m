function R=imresize(A,s);
%IMRESIZE Image resize
%	IMRESIZE(A,S) returns image A interpolated at new size S = [height,width] pixels.
%	
%	(c) F. Beauducel, IPGP
%	Created: 2007-05-17
%	Modified: 2007-05-17

s = round(s);
R = uint8(ones(s(1),s(2),3));
xx = 1:size(A,2);
yy = 1:size(A,1);

[xi,yi] = meshgrid(linspace(1,size(A,2),s(2)),linspace(1,size(A,1),s(1)));
R(:,:,1) = uint8(interp2(xx,yy,double(A(:,:,1)),xi,yi));
R(:,:,2) = uint8(interp2(xx,yy,double(A(:,:,2)),xi,yi));
R(:,:,3) = uint8(interp2(xx,yy,double(A(:,:,3)),xi,yi));
