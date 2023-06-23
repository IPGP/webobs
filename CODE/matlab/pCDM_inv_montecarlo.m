function [best_model,m,param] = pCDM_inv_montecarlo(...
  TOPO,X,Y,Z,Ue,Un,Uv,Sigmas,limite,nbtest,trace,opt,PCDM)
%pCDM_inv_montecarlo
%
%	Dependency: pcdmv.mex (compiled from pcdmv.c)
%
%	Authors: Antoine Villié (École des Mines de Paris / UGM / IRD), François Beauducel
%	Created: 2018 in Yogyakarta, Indonesia
%	Updated: 2019-08-14


% Random models creation
param = rand(nbtest,9).*repmat(limite(2,:)-limite(1,:),nbtest,1)+repmat(limite(1,:),nbtest,1);

% for source x and y, use normal distribution if necessary
if opt.apriori_horizontal > 0
	param(:,1) = randnb([nbtest,1],opt.targetxy(1)/1e3,opt.apriori_horizontal,limite(1,1),limite(2,1));
	param(:,2) = randnb([nbtest,1],opt.targetxy(2)/1e3,opt.apriori_horizontal,limite(1,2),limite(2,2));
end

% for source depth (parameter 3), lower values are limited by the topography
lower_z = max(limite(1,3),-interp2(TOPO.xx,TOPO.yy,TOPO.zz,param(:,1),param(:,2),'nearest'));
param(:,3) = rand(nbtest,1).*(limite(2,3) - lower_z) + lower_z;
 
% Computing the random models
%_______________________________________________________________________________
% outputs are NxM matrix where N is number of stations and M is number of models
n = size(X,1);
[ue,un,uv] = pcdmv(repmat(X,1,nbtest)-repmat(param(:,1)',n,1), ...
		   repmat(Y,1,nbtest)-repmat(param(:,2)',n,1),...
		   repmat(Z,1,nbtest)+repmat(param(:,3)',n,1), ...
		   repmat(param(:,4)',n,1),repmat(param(:,5)',n,1), ...
		   repmat(param(:,6)',n,1),repmat(param(:,7)',n,1), ...
		   repmat(param(:,8)',n,1),repmat(param(:,9)',n,1),PCDM.nu);
%ue = nan(n,nbtest);
%un = nan(n,nbtest); 
%uv = nan(n,nbtest);  
%for i = 1:nbtest
	%[ue(:,i),un(:,i),uv(:,i)] = pcdm(X-param(i,1),Y-param(i,2),...
	%	Z+param(i,3),param(i,4),param(i,5),param(i,6),param(i,7),param(i,8),...
	%	param(i,9),PCDM.nu);
	% display a dot each 10,000 models
	%if mod(i,10000) == 0, fprintf('.'); end
%end

% Computing the error matrice
%_______________________________________________________________________________
ke = find(~isnan(Ue));
kn = find(~isnan(Un));
kv = find(~isnan(Uv));

sigmae = Sigmas(ke,1);
sigman = Sigmas(kn,2);
sigmaz = Sigmas(kv,3);

if strcmpi(opt.misfitnorm,'L2')
	if opt.horizonly
		m = sqrt(sum(power((repmat(Ue(ke),[1,nbtest])-ue(ke,:))./repmat(sigmae,[1,nbtest]),2),1) ...
		       + sum(power((repmat(Un(kn),[1,nbtest])-un(kn,:))./repmat(sigman,[1,nbtest]),2),1));
	else
		m = sqrt(sum(power((repmat(Ue(ke),[1,nbtest])-ue(ke,:))./repmat(sigmae,[1,nbtest]),2),1) ...
		       + sum(power((repmat(Un(kn),[1,nbtest])-un(kn,:))./repmat(sigman,[1,nbtest]),2),1)...
		       + sum(power((repmat(Uv(kv),[1,nbtest])-uv(kv,:))./repmat(sigmaz,[1,nbtest]),2),1));
	end
else
	if opt.horizonly
		m = sum(abs((repmat(Ue(ke),[1,nbtest])-ue(ke,:))./repmat(sigmae,[1,nbtest])),1) ...
		  + sum(abs((repmat(Un(kn),[1,nbtest])-un(kn,:))./repmat(sigman,[1,nbtest])),1);
	else
		m = sum(abs((repmat(Ue(ke),[1,nbtest])-ue(ke,:))./repmat(sigmae,[1,nbtest])),1) ...
		  + sum(abs((repmat(Un(kn),[1,nbtest])-un(kn,:))./repmat(sigman,[1,nbtest])),1)...
		  + sum(abs((repmat(Uv(kv),[1,nbtest])-uv(kv,:))./repmat(sigmaz,[1,nbtest])),1);
	end
end
m = exp(-m(:));

% applies a priori info
if opt.apriori_horizontal > 0
	m = m.*exp(-((param(:,1) - opt.targetxy(1)/1e3).^2 + (param(:,2) - opt.targetxy(2)/1e3).^2)/ ...
	    (2*opt.apriori_horizontal^2));
end

best_model = param(m==max(m),:);



% Results display  
%_______________________________________________________________________________



if PCDM.supplementary_graphs && trace
	gridsize = PCDM.heatmap_grid;

	mnormalized = (m-min(m))/max(mnormalized);
	while median(mnormalized)<0.3             % To have a good spread of the results
		mnormalized = mnormalized.^(1/2);
	end
	while median(mnormalized)>0.7             % To have a good spread of the results
		mnormalized = mnormalized.^(2);
	end
	%m=mnormalized;

	coord = nan(gridsize,size(limite,2));
	for h = 1:size(limite,2)
		coord(:,h) = linspace(limite(1,h),limite(2,h),gridsize)';
	end
	
	%coord=linspace(limite(1,:),limite(2,:),gridsize)';
	coordt = coord(1:end-1,:)+repmat((coord(2,:)-coord(1,:))./2,gridsize-1,1);
	names = {'X0','Y0','Z0','OmegaX','OmegaY','OmegaZ','Dvtot','A','B'};

	mkdir(sprintf('%s/pCDM',PCDM.ptmp));

	for a = 1:9
		figure('Name',strcat('Results from the pCDM Monte-Carlo inversion algorithm',names{a}));
		for b = 1:9
			matri = nan(gridsize-1,gridsize-1);
			if a<b
				for i = 1:(gridsize-1)
					for j = 1:(gridsize-1)
						maxi=max(mnormalized(param(:,a)>=coord(i,a) & param(:,a)<=coord(i+1,a) & param(:,b)>=coord(j,b) & param(:,b)<=coord(j+1,b)));
						if (maxi~=0)
							matri(j,i)=maxi;
						 end
					end 
				end
				[grid2,grid1] = ndgrid(coordt(:,a),coordt(:,b));
				subplot(3,3,b)
				try
					contour(grid1,grid2,matri'),hold on,
				catch
				end
				plot(best_model(b),best_model(a),'+r')
				title(strcat(names{a},' function of ',names{b}))
				axis tight;
			end
			if (a==b)
			subplot(3,3,b)
			plot(param(:,a),mnormalized,'.k','markersize',0.1),hold on,
			plot(best_model(a),max(mnormalized(:)),'+r')
			title(strcat('histogram',names{a}))
			axis tight;
		end
	end
	print(sprintf('%s/pCDM/pCDMMC%s',PCDM.ptmp,names{a}),'-dpng');
	close
end 

if PCDM.supplementary_graphs
	save(sprintf('%s/pCDM/environnement',PCDM.ptmp))
end

end

