function [xlim,ylim] = equalaxis(h)
%EQUALAXIS Axis equal preserving axis position
%	EQUALAXIS(H) addresses axis H (default is GCA).
%
%	Author: F. Beauducel
%	Created: 2014-12-17

if nargin < 1
	h = gca;
end

fpos = get(gcf,'PaperPosition');
apos = get(h,'Position');

xlim = get(h,'XLim');
ylim = get(h,'YLim');

ratio = diff(ylim)*fpos(3)*apos(3)/(diff(xlim)*fpos(4)*apos(4));

if ratio > 1
	dx = diff(xlim)*(ratio - 1);
	xlim = [xlim(1) - dx/2, xlim(2) + dx/2];
	set(h,'XLim',xlim);
else
	dy = diff(ylim)*(1/ratio - 1);
	ylim = [ylim(1) - dy/2, ylim(2) + dy/2];
	set(h,'YLim',ylim);
end
