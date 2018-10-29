function y=rdecim(x,r)
%RDECIM Real decimation.
%   RDECIM(X,R) returns vector or matrix X decimated by average of R elements.
%   NaN values are excluded if exist.
%
%   See also RMEAN.
%   
%   (c) F. Beauducel, IPGP-OVSG 2002.

if size(x,1) == 1, x = x'; end
y = zeros(ceil(size(x,1)/r),size(x,2));
for i = 1:size(x,2)
    y(:,i) = rmean(reshape([x(:,i) ; NaN*ones(size(y,1)*r-size(x,1),1)],r,size(y,1)))';
end
