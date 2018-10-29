function yy = rdetrend(x,y)
%RDETREND Remove linear trend of data
%	YY=RDETREND(Y) removes the best straight-line fit from vector Y and returns
%	it in YY.
%
%	YY=RDETREND(X,Y) computes the trend using Y(X), X has same size of Y.
%
%	RDETREND excludes any NaN values from Y.
%
%	Author: F. Beauducel, IPGP
%	Created: 2014-11-14

if nargin < 2
	y = x;
	x = (1:size(y,1))';
end

yy = y;
for n = 1:size(y,2)
	k = find(~isnan(y(:,n)));
	if ~isempty(k)
		p = polyfit(x(k),y(k,n),1);
		yy(:,n) = y(:,n) - polyval(p,x);
	end
end
