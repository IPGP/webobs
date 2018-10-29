function nodata(xlim)
%NODATA Ecrit un message au milieu du graphe courant.

if nargin == 0
    xlim = get(gca,'XLim');
end

text(mean(xlim),.5,'Aucune donnée', ...
                    'HorizontalAlignment','center','FontWeight','bold','Color','r')
%text(mean(xlim),.5,{'Aucune donnée valide', ...
%                    sprintf('du %s au %s',datestr(tlim(1)),datestr(tlim(2)))}, ...
%                    'HorizontalAlignment','center','FontWeight','bold','Color','r')
