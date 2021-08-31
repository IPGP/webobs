function M = invpcdm(d,xx,yy,zz,xsta,ysta,zsta,zdem,opt,PCDM)
%INVPCDM pCDM model inversion using Monte-Carlo method
%
%	Input parameters:
%	               d: displacements data matrix (E,N,U,dE,dN,dU) in m
%	        xx,yy,zz: 3-D matrix of coordinates (in m)
%	  xsta,ysta,zsta: station coordinates (in m)
%	            zdem: topographic elevation matrix (in m)
%	   opt.horizonly: flag to use only horizontal components
%	       opt.msigp: number of sigma for best model uncertainty
%	            PCDM: structure of additional parameters (see gnss.m)
%
%
%	Output paramaters as structure with fields:
%	      type: source type (description)
%	        mm: 3-D matrix of misfit (as probabilities)
%	        vv: 3-D matrix of optimal volume variation
%	         k: = global index of best model into 3-D matrix MM or VV
%	        m0: lowest misfit value (in mm)
%	  ux,uy,uz: displacement vectors at stations for best solution (in m)
%	  ex,ey,ez: best source location uncertainty (in m)
%	        ev: best source volume variation uncertainty (in m)
%	        ws: distance estimation of msigp best models (in m)
%	     pbest: vector of best parameters (x,y,z,Ox,Oy,Oz,dV,A,B)
%
%	Reference:
%		Villié Antoine, Master 1 report, Ecole des Mines de Paris / Universitas Gadjah Mada, July 2018.
%
%	Authors: Antoine Villié and François Beauducel
%	Created: 2018-07-11 in Yogyakarta (Indonesia)
%	Updated: 2021-08-31

if all(length(PCDM.random_sampling) ~= [1,PCDM.iterations])
	error('MODELLING_PCDM_RANDOM_SAMPLING must be scalar or vector of MODELLING_PCDM_ITERATIONS length.')
end

sz = size(xx);
nn = length(xsta);

% topography (in km)
TOPO.xx = xx(:,:,1)/1e3;
TOPO.yy = yy(:,:,1)/1e3;
TOPO.zz = zdem/1e3;

% computes parameter limits for first iteration
first_limits = nan(2,9);
first_limits(:,1) = minmax(xx)'/1e3;
first_limits(:,2) = minmax(yy)'/1e3;
first_limits(:,3) = minmax(-zz)'/1e3;
first_limits(:,4) = PCDM.oxlim';
first_limits(:,5) = PCDM.oylim';
first_limits(:,6) = PCDM.ozlim';

%first_limits(:,7) = [-1e-2,1e-2]; % dVtot (km3)
first_limits(:,7) = PCDM.dvlim'/1e9; % dVtot (km3)

first_limits(:,8) = PCDM.alim';
first_limits(:,9) = PCDM.blim';
if ~strcmpi(opt.verbose,'quiet')
	fprintf('---> pCDM parameter limits:\n');
	pname = {'X','Y','Z','Ox','Oy','Oz','dV','A','B'};
	for p = 1:length(pname)
		fprintf('    %2s : %10g %10g\n',pname{p},first_limits(:,p));
	end
end

PCDM.ptmp = '/tmp/webobs/pcdm';

for m = 1:opt.multi

	% removes NaN data
	k = find(any(~isnan(d(:,1:3)),2));
	kr = length(k);
	MM = pCDM_inversion(TOPO,xsta(k)/1e3,ysta(k)/1e3,zsta(k)/1e3,d(k,1)/1e6,d(k,2)/1e6,d(k,3)/1e6,...
		d(k,4:6)/1e6,first_limits,opt,PCDM);

	% concatenates all models from all iterations
	param = cat(1,MM(1:PCDM.iterations).param);
	prob = cat(1,MM(1:PCDM.iterations).prob);
	% interpolates probability on a regular 3-D grid
	[mm,kk] = xyzv2grid(param(:,1)*1e3,param(:,2)*1e3,-param(:,3)*1e3,prob,xx,yy,zz);

	kr = find(~isnan(kk));
	vv = nan(size(kk));
	vv(kr) = param(kk(kr),7)*1e3;

	% for volpdf colorscale: must change NaN to 0
	mm(isnan(mm)) = 0;
	vv(isnan(vv)) = 0;

	% recomputes the lowest misfit solution
	[pmax,kmax] = max(prob);
	[ux,uy,uz] = pcdmv(xsta/1e3 - param(kmax,1),ysta/1e3 - param(kmax,2),zsta/1e3 + param(kmax,3),repmat(param(kmax,4),size(xsta)),repmat(param(kmax,5),size(xsta)),repmat(param(kmax,6),size(xsta)),repmat(param(kmax,7),size(xsta)),repmat(param(kmax,8),size(xsta)),repmat(param(kmax,9),size(xsta)),PCDM.nu);

	% from km to mm
	ux = ux*1e6;
	uy = uy*1e6;
	uz = uz*1e6;

	% finds best model in the grid
	kb = find(mm == max(mm(:)),1,'first');
	kx = find(~isnan(d(:,1)));
	ky = find(~isnan(d(:,2)));
	kz = find(~isnan(d(:,3)));

	m0 = sum((d(kx,1) - ux(kx)).^2 + (d(ky,2) - uy(ky)).^2);
	if ~opt.horizonly
		m0 = sqrt((m0 + sum((d(kz,3) - uz(kz)).^2))/(length(kx)+length(ky)+length(kz)));
	else
		m0 = sqrt(m0/(length(kx)+length(ky)));
	end

	% location uncertainty
	ex = minmax(xx(mm >= (1 - opt.msigp)*max(mm(:))),[1-opt.msigp,opt.msigp]);
	ey = minmax(yy(mm >= (1 - opt.msigp)*max(mm(:))),[1-opt.msigp,opt.msigp]);
	ez = minmax(zz(mm >= (1 - opt.msigp)*max(mm(:))),[1-opt.msigp,opt.msigp]);

	% volume variation uncertainty
	ev = minmax(vv(mm >= (1 - opt.msigp)*max(mm(:))),[1-opt.msigp,opt.msigp]);

	% source 3D median width for adjusting the color scale
	d0 = sqrt((xx-xx(kb)).^2 + (yy-yy(kb)).^2 + (zz-zz(kb)).^2);	% distance from source
	%ws = median(d0(mm>minmax(mm(:),.99)));	% median distance of the 1% best models
	ws = 2*median(d0(mm >= (1 - opt.msigp)*max(mm(:))));	% distance of the best models (msig)

	M(m).mm = mm/m; % divides mm by m to reduce importance of secondary source
	M(m).vv = vv;
	M(m).m0 = m0;
	M(m).ux = ux;
	M(m).uy = uy;
	M(m).uz = uz;
	M(m).ex = ex;
	M(m).ey = ey;
	M(m).ez = ez;
	M(m).ev = ev;
	M(m).ws = ws;
	pbest = param(kmax,:);
	M(m).type = pcdmdesc(pbest(8),pbest(9));
	% coordinates in m, depth < 0, dV in Mm3
	M(m).pbest = [pbest(1:2)*1e3,-pbest(3)*1e3,pbest(4:6),pbest(7)*1e3,pbest(8:9)];

	if ~strcmpi(opt.verbose,'quiet')
		fprintf('---> pCDM least bad model #%d:\n',m)
		for p = 1:length(pname)
			fprintf('    %2s : %10g\n',pname{p},param(kmax,p));
		end
		fprintf(' misfit : %g mm\n',m0);
	end

	% for multiple sources: computes the residual as data for next iteration
	if opt.multi > 1
		d(:,1) = d(:,1) - ux;
		d(:,2) = d(:,2) - uy;
		d(:,3) = d(:,3) - uz;
	end
	if m > 1 && M(m).m0 > M(m-1).m0
		fprintf('*** WARNING: Source #%d increases global misfit... solution rejected.\n',m)
	end
end

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [Output] = pCDM_inversion(TOPO,X,Y,Z,Ue,Un,Uv,Sigmas,first_limits,opt,PCDM)

nb_iterations = PCDM.iterations;
tracepCDM = 0;

trace = 0;                % for pCDM_inv_montecarlo (si trace~=0, alors on trace
					  % les cartes de proba sur une dernière itération avec un nombre
					  % de modèles égale à trace)
if PCDM.supplementary_graphs
	% PCDM.ptmp is path to write supplementary results
	mkdir(PCDM.ptmp)
end

nb_models = PCDM.random_sampling;
% if nb_models is scalar, set for all iterations
if length(nb_models)==1
	nb_models = nb_models*ones(1,nb_iterations);
end

low_limits(:,:,1) = first_limits(1,:);
high_limits(:,:,1) = first_limits(2,:);
Output(1).plim = first_limits;

% Inversion: main loop of iterations
for i = 1:nb_iterations
	if ~strcmpi(opt.verbose,'quiet')
		fprintf('---> pCDM iteration %d/%d (%d models)...',i,nb_iterations,nb_models(i));
	end
	[Output(i).best_model,Output(i).prob,Output(i).param] = pCDM_inv_montecarlo(...
	TOPO,X,Y,Z,Ue,Un,Uv,Sigmas,Output(i).plim,nb_models(i),trace,opt,PCDM);

	Output(i+1).plim = mknewlimits(Output(i).prob,Output(i).param,Output(i).plim,first_limits,PCDM,i);

	low_limits(:,:,i+1) = Output(i+1).plim(1,:);
	high_limits(:,:,i+1) = Output(i+1).plim(2,:);
	if ~strcmpi(opt.verbose,'quiet')
		fprintf(' done.\n');
	end
end
Output(nb_iterations+1).best_model = nan(1,9);
Output(nb_iterations+1).prob = NaN;
Output(nb_iterations+1).param = nan(1,9);
best_model = cat(1,Output.best_model);


if PCDM.supplementary_graphs
	% Summary graph: limits and best model vs. iteration
	figure
	names = {'X0','Y0','Z0','OmegaX','OmegaY','OmegaZ','Dvtot','A','B'};
	indice = [1 4 7 2 5 8 3 6 9];
	for param_number = 1:9
		subplot(3,3,indice(param_number))
		title(names{param_number})
		axis('square')
		hold on
		plot(1:nb_iterations+1,reshape(low_limits(1,param_number,1:end),[1,nb_iterations+1]),'r')
		plot(1:nb_iterations+1,reshape(high_limits(1,param_number,1:end),[1,nb_iterations+1]),'r')
		plot(1:nb_iterations,best_model(1:end-1,param_number)')
		hold off
	end
	print(sprintf('%s/Resume_Global',PCDM.ptmp),'-dpng');
	save(sprintf('%s/environnement',PCDM.ptmp))
	close

	%-------------------------------------------------------------------------------




	% Text file with the iterations details
	%_______________________________________________________________________________
	% Cette partie sort le fichier texte avec le résumé des limites et best_models pour chaque itération
	%-------------------------------------------------------------------------------

	first_colums = linspace(1,nb_iterations+1,nb_iterations+1)';
	low_limits = cat(2,first_colums,reshape(low_limits,[9,nb_iterations+1])')';
	high_limits = cat(2,first_colums,reshape(high_limits,[9,nb_iterations+1])')';
	best_models = cat(2,first_colums(1:end-1),cat(1,Output(1:end-1).best_model))';
	fid = fopen(sprintf('%s/Results.txt',PCDM.ptmp),'wt');
	fprintf(fid,'\n');
	fprintf(fid,'%2s %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t\n','low_limits','X0   ',' Y0   ','Z0   ','OmegaX','OmegaY','OmegaZ','Dvtot ','A   ','B   ');
	fprintf(fid,'%2.0f\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t\n',low_limits);
	fprintf(fid,'\n');
	fprintf(fid,'%2s %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t\n','high_limits','X0   ',' Y0   ','Z0   ','OmegaX','OmegaY','OmegaZ','Dvtot ','A   ','B   ');
	fprintf(fid,'%2.0f\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t\n',high_limits);
	fprintf(fid,'\n');
	fprintf(fid,'%2s %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t %9s\t\n','best model','X0   ',' Y0   ','Z0   ','OmegaX','OmegaY','OmegaZ','Dvtot ','A   ','B   ');
	fprintf(fid,'%2.0f\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t %4.3e\t\n',best_models);
	fclose(fid);
	%-------------------------------------------------------------------------------
	%-------------------------------------------------------------------------------
	%Last iteration - probabilities visualisation
	%_______________________________________________________________________________
	% Cette partie trace, si demandé, les cartes deproba d'une dernière itération
	if tracepCDM~=0
		pCDM_inv_montecarlo(TOPO,X,Y,Z,Ue,Un,Uv,Sigmas,Output(nb_iterations+1).plim,PCDM.nu,tracepCDM,PCDM.heatmap_grid,PCDM.ptmp,1,opt,PCDM);
	end
end



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function new_limits = mknewlimits(m,param,limits,initial_limits,PCDM,numeroiter)
% normalisation de la matrice des probas et on augmente sa médiane de manière
% à avoir des résultats lisibles
m = (m-min(m))/max(m);
i = 1;
while median(m)<0.2 && i < 10
	m = sqrt(m);
	i = i + 1;
end

grid_size = PCDM.heatmap_grid;

next_limits = [];
names = {'X0','Y0','Z0','OmegaX','OmegaY','OmegaZ','Dvtot','A','B'};

for param_number = 1:9
	% Heatmap
	%_________________________________________________________________________
	Xedges = linspace(limits(1,param_number),limits(2,param_number),grid_size);
	Yedges = linspace(0,1,grid_size);
	subplot(3,3,param_number)
	N = hist2d(param(:,param_number),m,grid_size);
	if PCDM.supplementary_graphs
		pcolor(Xedges,Yedges,N);
		shading flat;
		axis tight;
		axis('square')
		caxis([1,max(N(:).^PCDM.heatmap_saturation)]);
	end
	% Curve
	%_________________________________________________________________________
	mat = cumsum(flipud(N));
	pp = zeros(size(Xedges));
	for i = 1:length(Xedges)
		k = find(mat(:,i)>PCDM.newlimit_threshold,1);
		if ~isempty(k)
			pp(i) = Yedges(max(length(Yedges)-k,1));
		end
	end
	pp = pp-min(pp(:));
	if max(pp(:))~=0
		pp = pp./max(pp(:));
	end
	pp = smooth(pp,PCDM.heatmap_smooth_span,'sgolay',PCDM.heatmap_smooth_degree);
	% Next limits
	%_________________________________________________________________________
	%Test with different convergence speeds (x,y, dvtot)

	xnext = find(pp>=mean(pp));

	if xnext(1)<grid_size/PCDM.newlimit_edge_ratio
		xnext(1) = 1;
	end
	if xnext(end)>(PCDM.newlimit_edge_ratio-1)*grid_size/PCDM.newlimit_edge_ratio
		xnext(end) = grid_size;
	end


	xnext = [Xedges(min(xnext(:))); Xedges(max(xnext(:)))];
	if param_number==3 && numeroiter==1
		xnext = [Xedges(1);Xedges(end)];
	end



	next_limits = cat(2,next_limits,xnext);
	if PCDM.supplementary_graphs
		hold on
		plot(Xedges,pp,'-r')
		plot(Xedges,repmat(mean(pp),size(Xedges)),'-k')
		plot([xnext(1) xnext(1)],[0,1],'r')
		plot([xnext(2) xnext(2)],[0,1],'r')
		title(names{param_number})
	end

end

if PCDM.supplementary_graphs
	hold off
	print(sprintf('%s/Resume_iteration_number%d',PCDM.ptmp,numeroiter),'-dpng');
	close all
end

% Outputs
%_____________________________________________________________________________
for i = 1:9
	if (next_limits(1,i)==limits(1,i))
		next_limits(1,i) = max(limits(1,i)-(limits(2,i)-limits(1,i))*PCDM.newlimit_extend,initial_limits(1,i));
	end
	if (next_limits(2,i)==limits(2,i))
		next_limits(2,i) = min(limits(2,i)+(limits(2,i)-limits(1,i))*PCDM.newlimit_extend,initial_limits(2,i));
	end
end
new_limits = next_limits(:,:);
