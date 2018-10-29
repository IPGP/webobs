function y=h2hms(x,hm)
%H2HMS Minute seconds convert
%	H2HMS(X) converts hours/degrees H to vector [H,M,S]
%	H2HMS(X,1) converts to [H,M]

s = sign(x(:));
x = abs(x(:));
if nargin < 2
	y = [s.*floor(x),floor(rem(x*60,60)),rem(x*3600,60)];
else
	y = [s.*floor(x),60*(x - floor(x))];
end
