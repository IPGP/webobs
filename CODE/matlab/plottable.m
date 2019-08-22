function plottable(t,x,y,halign,varargin)
%PLOTTABLE Plot basic table on current graph.
%	PLOTTABLE(TXT,X,Y,HALIGN) plots a table of cell string TXT, using:
%	    X = vector of column X positions
%	    Y = 2-element vector of first and last row Y positions
%	    HALIGN = string of horizontal alignment characters (lrc)
%
%	Author: F. Beauducel, IPGP/IRD
%	Created: 2019-07-31 in Yogyakarta (Indonesia)

y = linspace(y(1),y(2),size(t,1));
for c = 1:size(t,2)
	for r = 1:size(t,1)
		text(x(c),y(r),t{r,c},'HorizontalAlignment',halign(c),'VerticalAlignment','middle',varargin{:})
	end
end
