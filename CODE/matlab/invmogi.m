function M=invmogi(d,xx,yy,zz,xsta,ysta,zsta,zdem,opt)
%INVMOGI Isotropic point source inversion
%	M=INVMOGI(D,XX,YY,ZZ,XSTA,YSTA,ZSTA,ZDEM,OPT) computes best model from
%	displacement data, where:
%
%	Input parameters:
%	              D = [DX,DY,DZ,EX,EY,EZ] displacement data components and errors (in mm)
%	       XX,YY,ZZ = 3-dimension matrices of coordinates (from meshgrid)
%	 XSTA,YSTA,ZSTA = vectors of stations (observation points) coordinates
%	           ZDEM = matrix of elevation (topography)
%	            OPT = structure of optional parameters:
%	                  .horizonly = flag for horizontal only components
%	                  .misfitnorm = L1 (default) or L2
%	                  .msigp = percentage of best models solution
%	                  .targetxy = [X,Y] coordinates of target source
%	                  .apriori_horizontal = a priori horizontal std (km) from target
%	                  .apriori_depth = a priori depth,std (km)
%	                  .multi = number of sources to compute recursively on residuals
%
%	Output paramaters as structure with fields:
%	      type: 'isotropic'
%	        mm: 3-D matrix of misfit (as probabilities)
%	        vv: 3-D matrix of optimal volume variation
%	         k: = global index of best model into 3-D matrix MM or VV
%	        m0: lowest misfit value (in mm)
%	  ux,uy,uz: displacement vectors at stations for best solution (in m)
%	  ex,ey,ez: best source location uncertainty (in m)
%	        ev: best source volume variation uncertainty (in m3)
%	        ws: distance estimation of msigp best models (in m)
%	     pbest: vector of best parameters (x,y,z,dv)
%
%	Author: François Beauducel
%	Created: 2010 in Paris (France)
%	Updated: 2025-04-04

sz = size(xx);
nn = length(xsta);

% computes Green's functions at stations for a unit volume of 1 Mm3
[asou,rsou] = cart2pol(repmat(reshape(xsta,1,1,1,nn),[sz,1])-repmat(xx,[1,1,1,nn]), ...
	repmat(reshape(ysta,1,1,1,nn),[sz,1])-repmat(yy,[1,1,1,nn]));

[ur,uz] = mogi(rsou,repmat(reshape(zsta,1,1,1,nn),[sz,1]) - repmat(zz,[1,1,1,nn]),1e9);
[ux,uy] = pol2cart(asou,ur);

for m = 1:opt.multi

	% dx,dy,dz data are repeated at each 3-D grid points, stations are the 4th dimension
	dx = repmat(reshape(d(:,1),1,1,1,nn),[sz,1]);
	dy = repmat(reshape(d(:,2),1,1,1,nn),[sz,1]);
	dz = repmat(reshape(d(:,3),1,1,1,nn),[sz,1]);

	% selects data vectors without NaN
	kk = find(~any(isnan(d(:,1:3)),2));
	kr = length(kk);
	kx = find(~isnan(d(:,1)));
	ky = find(~isnan(d(:,2)));
	kz = find(~isnan(d(:,3)));

	% computes optimal volume variation ratio from mean radial displacements
	%if opt.horizonly
		[da,dr] = cart2pol(dx,dy);
		drm = dr.*cos(da - asou);	% horizontal radial component data vector (relative to sources)
		vv = mean(drm(:,:,:,kk),4)./mean(sqrt(ux(:,:,:,kx).^2 + uy(:,:,:,ky).^2),4);
	%else
	%	[tsou,psou,rsou] = cart2sph(repmat(reshape(xsta,1,1,1,nn),[sz,1])-repmat(xx,[1,1,1,nn]), ...
	%		repmat(reshape(ysta,1,1,1,nn),[sz,1])-repmat(yy,[1,1,1,nn]), ...
	%		repmat(reshape(zsta,1,1,1,nn),[sz,1])-repmat(zz,[1,1,1,nn]));
	%	[th,ph,dr] = cart2sph(dx,dy,dz);
	%	drm = dr.*cos(th - tsou).*cos(ph - psou);	% radial component data vector (relative to sources)
	%	vv = mean(drm(:,:,:,kk),4)./mean(sqrt(ux(:,:,:,kk).^2 + uy(:,:,:,kk).^2 + uz(:,:,:,kk).^2),4);
	%end

	% computes probability density
	if ~isempty(kx) || ~isempty(ky)
		vvx = repmat(vv,[1,1,1,length(kx)]);
		vvy = repmat(vv,[1,1,1,length(ky)]);
		sigx = repmat(reshape(d(kx,4),1,1,1,length(kx)),[sz,1]);
		sigy = repmat(reshape(d(ky,5),1,1,1,length(ky)),[sz,1]);
		if strcmpi(opt.misfitnorm,'L2')
			mm = exp(sum(-(dx(:,:,:,kx) - ux(:,:,:,kx).*vvx).^2./(2*sigx.^2),4)) ...
				.*exp(sum(-(dy(:,:,:,ky) - uy(:,:,:,ky).*vvy).^2./(2*sigy.^2),4));
		else
			mm = exp(sum(-abs(dx(:,:,:,kx) - ux(:,:,:,kx).*vvx)./sigx,4)) ...
				.*exp(sum(-abs(dy(:,:,:,ky) - uy(:,:,:,ky).*vvy)./sigy,4));
		end
	else
		mm = nan(sz);
	end

	if ~opt.horizonly && ~isempty(kz)
		vvz = repmat(vv,[1,1,1,length(kz)]);
		sigz = repmat(reshape(d(kz,6),1,1,1,length(kz)),[sz,1]);
		% special case where no horizontal data are available...
		if all(isnan(mm(:)))
			mm(:) = 1;
		end
		if strcmpi(opt.misfitnorm,'L2')
			mm = mm.*exp(sum(-(dz(:,:,:,kz) - uz(:,:,:,kz).*vvz).^2./(2*sigz.^2),4));
		else
			mm = mm.*exp(sum(-abs(dz(:,:,:,kz) - uz(:,:,:,kz).*vvz)./sigz,4));
		end
	end
	clear dx dy dz sigx sigy sigz % free some memory

	% applies a priori info
	if numel(opt.apriori_depth) == 2 && opt.apriori_depth(2) > 0
		mm = mm.*exp(-((zz + opt.apriori_depth(1)	).^2)/(2*(opt.apriori_depth(2))^2));
	end
	if opt.apriori_horizontal > 0
		mm = mm.*exp(-((xx - opt.targetxy(1)).^2 + (yy - opt.targetxy(2)).^2)/ ...
		    (2*(opt.apriori_horizontal*1e3)^2));
	end

	% all solutions above the topography are very much unlikely...
	mm(zz>repmat(zdem,[1,1,sz(3)])) = 0;
	%fprintf('---> misfit grid has %d NaN values.\n',sum(isnan(mm(:))));

	% for correct color rendering it's better to use 0 than NaN...
	mm(isnan(mm)) = 0;
	vv(isnan(vv)) = 0;

	% normalizes mm and look for the lowest misfit solution
	if max(mm(:)) > 0
		mm = mm/max(mm(:));
		k = find(mm == 1,1,'first');
	else
		if ~strcmpi(opt.verbose,'quiet')
			fprintf('---> misfit is all zero... no minimum can be found.\n')
		end
		k = 1;
	end

	% recomputes the lowest L2-misfit solution (dV in Mm3, displacements in mm)
	[abest,rbest] = cart2pol(xsta-xx(k),ysta-yy(k));
	zbest = zsta - zz(k);
	[urb,uzb] = mogi(rbest,zbest,1e9*vv(k));
	[uxb,uyb] = pol2cart(abest,urb);
	m0 = sum((d(kx,1) - uxb(kx)).^2 + (d(ky,2) - uyb(ky)).^2);
	if ~opt.horizonly
		m0 = sqrt((m0 + sum((d(kz,3) - uzb(kz)).^2))/(length(kx)+length(ky)+length(kz)));
	else
		m0 = sqrt(m0/(length(kx)+length(ky)));
	end

	% location uncertainty
	csxy = diff(yy(1:2)); % x-y cell size of the grid
	csz = diff(zz(1,1,1:2)); % z cell size of the grid
	ex = minmax(xx(mm >= (1 - opt.msigp)) - xx(k),[1-opt.msigp,opt.msigp]);
	if ex(1)==0, ex(1) = -csxy; end
	if ex(2)==0, ex(2) = csxy; end
	ey = minmax(yy(mm >= (1 - opt.msigp)) - yy(k),[1-opt.msigp,opt.msigp]);
	if ey(1)==0, ey(1) = -csxy; end
	if ey(2)==0, ey(2) = csxy; end
	ez = minmax(zz(mm >= (1 - opt.msigp)) - zz(k),[1-opt.msigp,opt.msigp]);
	if ez(1)==0, ez(1) = -csz; end
	if ez(2)==0, ez(2) = csz; end

	% volume variation uncertainty
	ev = minmax(vv(mm >= (1 - opt.msigp)),[1-opt.msigp,opt.msigp]);

	% source 3D median width for adjusting the color scale
	d0 = sqrt((xx-xx(k)).^2 + (yy-yy(k)).^2 + (zz-zz(k)).^2);	% distance from source
	%ws = median(d0(mm>minmax(mm(:),.99)));	% median distance of the 1% best models
	ws = 2*median(d0(mm >= (1 - opt.msigp)));	% distance of the best models (msig)

	M(m).mm = mm;
	M(m).vv = vv;
	M(m).m0 = m0;
	M(m).ux = uxb;
	M(m).uy = uyb;
	M(m).uz = uzb;
	M(m).ex = ex;
	M(m).ey = ey;
	M(m).ez = ez;
	M(m).ev = ev;
	M(m).ws = ws;
	M(m).pbest = [xx(k),yy(k),zz(k),vv(k)];
	M(m).type = 'isotropic';

	if ~strcmpi(opt.verbose,'quiet')
		fprintf('---> isotropic best model #%d: x = %g, y = %g, z = %g, dV = %g 10^6 m3, misfit = %g mm.\n',m,M(m).pbest,M(m).m0);
	end

	% for multiple sources: computes the residual as data for next iteration
	if opt.multi > 1
		d(:,1) = d(:,1) - uxb;
		d(:,2) = d(:,2) - uyb;
		d(:,3) = d(:,3) - uzb;
	end
    % rejects the secondary source if not improve misfit: set model displacements to 0 and parameters to NaN
	if m > 1 && M(m).m0 > M(m-1).m0
        M(m).mm(:) = 0;
        M(m).ux(:) = 0;
        M(m).uy(:) = 0;
        M(m).uz(:) = 0;
        M(m).pbest = nan(1,4);
		fprintf('*** WARNING: Source #%d increases global misfit... solution rejected.\n',m)
    else
        M(m).mm = M(m).mm/m; % divides mm by m to reduce importance of secondary source (graphically)
	end
end
