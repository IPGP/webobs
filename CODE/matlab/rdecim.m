function y=rdecim(x,r)
%RDECIM Real decimation.
%   RDECIM(X,R) returns vector or matrix X decimated by average of R elements.
%   NaN values are excluded if exist.
%
%   See also RMEAN.
%   
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2002
%   Updated: 2015-08-24

if size(x,1) == 1
	x = x';
end
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
