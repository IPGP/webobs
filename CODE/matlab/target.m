function h=target(x,y,s,c,m,w)
%TARGET plot target marker
%	TARGET(X,Y) plots a target marker at coordinates X,Y on current plot.
%
%	TARGET(X,Y,SIZE,COLOR,MARKER,WATERMARK) uses marker size SIZE (default
%	is 8), face color COLOR (default is red), marker type MARKER (default 
%	is circle) and optional color lightning WATERMARK (>= 1).
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2003
%	Updated: 2020-03-21

if nargin < 3
	s = 8;
end

if nargin < 4
	c = [1,0,0];
end

if nargin < 5
	m = 'o';
end

if nargin < 6
	w = 1;
else
	c = (c - 1)/w + 1;
end

if ~isempty(x) && all(size(x)==size(y))
	hold_status = ishold;

	b = 1 - .8*[1,1,1]/w;

	hh = zeros(2,1);

	hold on
	hh(1) = plot(x,y,m,'MarkerSize',s,'MarkerFaceColor',c,'MarkerEdgeColor',b,'Linewidth',s/5);
	hh(2) = plot(x,y,m,'MarkerSize',s + 2,'MarkerEdgeColor',.99*[1,1,1],'MarkerFaceColor','none');

	if ~hold_status
		hold off
	end
	if nargout > 0
		h = hh;
	end
end
