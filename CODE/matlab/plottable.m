function plottable(t,x,y,halign,col,varargin)
%PLOTTABLE Plot basic table on current graph.
%	PLOTTABLE(TXT,X,Y,HALIGN) plots a table of cell string TXT, using:
%	    X = vector of column X positions
%	    Y = 2-element vector of first and last row Y positions
%	    HALIGN = string of horizontal alignment characters (lrc)
%
%	Author: F. Beauducel, IPGP/IRD
%	Created: 2019-07-31 in Yogyakarta (Indonesia)
%   Updated: 2026-04-19

if ~all(size(col)==size(t))
    col = repmat({'none'},size(t))
end

y = linspace(y(1),y(2),size(t,1));
for c = 1:size(t,2)
	for r = 1:size(t,1)
        s = regexprep(t{r,c},'-([0-9])','−$1'); % replaces '-' by U-2212
		text(x(c),y(r),s,'HorizontalAlignment',halign(c),'VerticalAlignment','middle','EdgeColor',col{r,c},'margin',2,varargin{:})
	end
end
