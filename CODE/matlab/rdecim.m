function y=rdecim(x,r)
%RDECIM Real decimation.
%   RDECIM(X,R) decimates each column of matrix X of size MxN and returns a 
%   matrix of size (M/R)xN, where each element is the average of R elements of
%   X column. NaN values are excluded if exist.
%
%   See also RMEAN.
%   
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2002
%   Updated: 2019-02-16

% to reproduce the former behavior of Matlab...
%if size(x,1) == 1
%	x = x';
%end
r = round(r);
if r > 1
	y = zeros(ceil(size(x,1)/r),size(x,2));
	leading = nan(size(y,1)*r-size(x,1),1);
	if ~isempty(leading)
		x = cat(1,x,repmat(leading,[1,size(x,2)]));
	end

	for i = 1:size(x,2)
		y(:,i) = rmean(reshape(x(:,i),r,size(y,1)))';
	end
else
	y = x;
end
