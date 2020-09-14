function varargout=target(x,y,s,c,m,w,varargin)
%TARGET plot target marker
%	TARGET(X,Y) plots a target marker (circle) at coordinates X,Y on the
%	current plot. TARGET uses a black edge color and adds a white 
%	surrounding edge to make the marker visible on any background.
%
%	TARGET(X,Y,SIZE,COLOR,MARKER,WATERMARK) uses target parameters:
%	       SIZE = size in pt (default is 8),
%	      COLOR = face color as RGB (default is [1 0 0] for red),
%	     MARKER = marker type, any valid character for PLOT function (default
%	              is 'o' for circle),
%	  WATERMARK = optional color lightning (>= 1).
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2003
%	Updated: 2020-03-21

blank = .99*[1,1,1];

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
	if strcmp(m,'-')
		oldunits = get(gca,'Units');
		set(gca,'Units','inches');
		pos = get(gca,'Position');
		xlim = get(gca,'XLim');
		set(gca,'Units',oldunits);
		xx = x(:) + repmat(diff(xlim)*s/72/pos(3)*[-1,1],numel(x),1);
		yy = y(:) + repmat([0,0],numel(x),1);
		hh(1) = plot(xx,yy,m,'Color',blank,'Linewidth',2);
		hh(2) = plot(xx,yy,m,'Color',c,'Linewidth',1.5);
	else
		hh(1) = plot(x,y,m,'MarkerSize',s,'MarkerFaceColor',c,'MarkerEdgeColor',b,'Linewidth',s/5);
		hh(2) = plot(x,y,m,'MarkerSize',s + 2,'MarkerEdgeColor',blank,'MarkerFaceColor','none');
	end
	if ~hold_status
		hold off
	end
	if nargout > 0
		varargout{1} = hh;
	end
end
