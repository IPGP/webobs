function nodata(xlim)
%NODATA Writes a message "no data" in the middle of current axes.

if nargin == 0
	xlim = get(gca,'XLim');
else
	set(gca,'XLim',xlim,'YLim',[0,1]);
end

text(mean(xlim),.5,'No data', ...
                    'HorizontalAlignment','center','FontWeight','bold','Color','r')
%text(mean(xlim),.5,{'Aucune donnée valide', ...
%                    sprintf('du %s au %s',datestr(tlim(1)),datestr(tlim(2)))}, ...
%                    'HorizontalAlignment','center','FontWeight','bold','Color','r')
