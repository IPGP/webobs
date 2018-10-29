function h=mnt(x,y,z,map,s,novalue);
%MNT DEM lighted image plot
%	MNT(X,Y,Z,MAP) plots the DEM (X,Y,Z) as a lighted image using colormap MAP.
%
%	MNT(X,Y,Z,MAP,S) controls light contrast, with S as exponent of the gradient. Default is S = 0.3,
%	use S = 0 to remove lighting.
%
%	MNT(X,Y,Z,MAP,S,NOVALUE) set the DEM novalue default is MIN(Z) or NaN);
%
%	(c) F. Beauducel, IPGP
%	Created: 2007-05-17
%	Modified: 2007-05-17

if nargin < 5
	s = .3;
end

zmin = min(min(z));

if nargin < 6
	novalue = zmin;
	flag = 0;
else
	flag = 1;
end

dz = max(max(z)) - min(min(z));

if dz > 0
	% normalisation of Z using MAP and convertion to RGB
	I = ind2rgb(round((z - zmin)*length(map)/(max(max(z))-min(min(z)))),map);

	% compute lighting
	k = find(z == novalue);
	if flag
		z(k) = 0;	% forces Z = 0 where Z = novalue (Z0)
	end
	[fx,fy] = gradient(z);
	r = (fx - min(min(fx)))/(max(max(fx))-min(min(fx)));
	r(k) = 1;				% NOVALUES are not lighted

	hh = imagesc(x,y,I.*repmat(r.^s,[1,1,3]));
else
	hh = imagesc(x,y,z,[novalue 0]);
	colormap(map)
end
set(gca,'YDir','normal')

if nargout > 0
	h = hh;
end
