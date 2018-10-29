function h=plotmark(m,x,y,c,s,col)
%PLOTMARK Marker plot.
%       PLOTMARK(M,X,Y,C) plots vector Y versus vector X, using
%       different markers defined by vector M as index into cell of 
%       marker's character C.
%
%       PLOTMARK(...,S,COL) uses marker size S and color COL.
%
%       (c) F. Beauducel, OVSG-IPGP, 2002.

if nargin < 4
	c = {'.','v','^','s','<','>','d','p','h'};
end
if nargin < 6
	s = 3;
	col = [0 0 .8];
end

if length(s) == 1
	smk = s*ones(size(c));
else
	smk = s;
end

hh = [];
hd = ~ishold;
for i = 1:max(m)
	k = find(m == i);
	if ~isempty(k)
		ii = mod(i-1,max(m)) + 1;
		h1 = plot(x(k),y(k),[c{ii},'-'],'LineWidth',.1,'Color',col,'Markersize',smk(ii),'MarkerFaceColor',col);
		hh = [hh;h1];
		if hd
			hold on
		end
	end
end

if hd
	hold off
end
if nargout
	h = hh;
end
