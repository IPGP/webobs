function h = plotc(x,y,z,map,cmap)
%PLOTC	2D dot colormap plot.
%	PLOTC(X,Y,Z) plots Y versus X with a color scale based on Z values 
%	(default is JET(16)).
%
%	PLOTC(X,Y,Z,MAP) uses the colormap MAP.
%
%	PLOTC(X,Y,Z,MAP,CMAP) scales the colors to CMAP = [ZMIN,ZMAX] instead
%   of MIN(Z) and MAX(Z).
%
%   H=PLOTC(...) returns graphic handles vector H.
%
%	F. Beauducel, IPGP 1998-2005.

if nargin < 4
    map = jet(16);
end
if nargin < 5
    cmap = [min(z),max(z)];
end
n = size(map,1);
c = ceil(n*(z-cmap(1))/diff(cmap));
hd = ishold;
j = 1;
for i = 1:n
    switch i
    case 1
        k = find(c <= i);
    case n
        k = find(c >= i);
    otherwise
        k = find(c==i);
    end
    if ~isempty(k)
        h0 = plot(x(k),y(k),'.','Color',map(i,:),'MarkerSize',0.1);
        hold on
        hh(j) = h0;
        j = j + 1;
    end
end
if ~hd
    hold off
end
if nargout
    h = hh;
end
