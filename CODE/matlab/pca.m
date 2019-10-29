function [y,V,D]=pca(x,varargin)
%PCA	Principal component analysis
%	[Y,V,D]=PCA(X)
%
%	Author: F. Beauducel / IPGP
%	Created: 1992 in Paris
%	Updated: 2019-10-13

% selects only non-NaN values
k = all(~isnan(x),2);

if ~isempty(k)
	% removes mean value of each column
	x0 = bsxfun(@minus, x, mean(x(k,:),1));

	% computes covariance and eigen vectors
	[V,D] = eig(cov(x0(k,:)));

	% sorts components
	[D,order] = sort(diag(D), 'descend');
	V = V(:,order);

	% transforms data to new reference
	y = x0*V;
else
	y = x;
	V = eye(size(x,2));
	D = zeros(size(x,2),1);
end
