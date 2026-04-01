function nodata(xlim)
%NODATA Writes a message "no data" in the middle of current axes.

if nargin == 0
	xlim = get(gca,'XLim');
else
	set(gca,'XLim',xlim,'YLim',[0,1]);
end

text(mean(xlim),.5,'No data', ...
                    'HorizontalAlignment','center','FontWeight','bold','Color',[.7,0,0])
