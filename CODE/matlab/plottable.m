function plottable(t,x,y,halign,col,varargin)
%PLOTTABLE Plot basic table on current graph.
%	PLOTTABLE(TXT,X,Y,HALIGN) plots a table of cell string TXT, using:
%	        X = vector of column X positions (same number of column as TXT)
%	        Y = 2-element vector of first and last row Y positions (will 
%               interpolate linearily)
%	   HALIGN = cell array of string of horizontal alignment characters
%               (lrc) for each column
%         COL = MxN cell array of color string (optional)
%
%	Author: F. Beauducel, IPGP/IRD
%	Created: 2019-07-31 in Yogyakarta (Indonesia)
%   Updated: 2026-08-10


if ~all(size(col)==size(t))
    col = repmat({'none'},size(t));
end

y = linspace(y(1),y(2),size(t,1));
for c = 1:size(t,2)
	for r = 1:size(t,1)
        s = t{r,c};
		text(x(c),y(r),s,'HorizontalAlignment',halign(c),'VerticalAlignment','middle','EdgeColor',col{r,c},'margin',2,varargin{:})
	end
end
