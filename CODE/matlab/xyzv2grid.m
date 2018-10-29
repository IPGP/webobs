function [vv,kk] = xyzv2grid(x,y,z,v,xx,yy,zz,method)
%XYZV2GRID Fill 3-D grid from scattered data
%
%
% 

if nargin < 8
	method = 'max';
end
% xx, yy, zz from meshgrid
xlim = [min(xx(:)),max(xx(:))];
ylim = [min(yy(:)),max(yy(:))];
zlim = [min(zz(:)),max(zz(:))];
sz = size(zz);
vv = nan(sz);
kk = nan(sz);

for n = 1:length(v)
	i = min(max(floor(sz(1)*(y(n) - ylim(1))/diff(ylim)),1),sz(1));
	j = min(max(floor(sz(2)*(x(n) - xlim(1))/diff(xlim)),1),sz(2));
	k = min(max(floor(sz(3)*(z(n) - zlim(1))/diff(zlim)),1),sz(3));
	switch method
		case 'min'
			if isnan(vv(i,j,k)) || v(n) < vv(i,j,k)
				vv(i,j,k) = v(n);
				kk(i,j,k) = n;
			end

		case 'max'
			if isnan(vv(i,j,k)) || v(n) > vv(i,j,k)
				vv(i,j,k) = v(n);
				kk(i,j,k) = n;
			end
			
		otherwise
			error('method "%s" unkown',method);
	end
end

end

