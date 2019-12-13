function timecolorbar(x,y,w,h,tlim,cmap,fs,lr)
%TIMECOLORBAR Time colorbar
%	TIMECOLORBAR(X,Y,WIDTH,HEIGHT,TLIM,CMAP,FONTSIZE,LABELROTATION)
%
%	Uses function DTICK.

if nargin < 8
	lr = 0;
end

tscale = linspace(tlim(1),tlim(2),size(cmap,1));
ddt = dtick(diff(tscale([1,end])));
ttick = (ddt*ceil(tscale(1)/ddt)):ddt:tscale(end);

if w < h
	% vertical colorbar
	yy = linspace(0,h,size(cmap,1));
	patch(x + repmat(w*[0;1;1;0],[1,size(cmap,1)]), ...
		y + [repmat(yy,[2,1]);repmat(yy + diff(yy(1:2)),[2,1])], ...
		repmat(tscale,[4,1]), ...
		'EdgeColor','flat','LineWidth',.1,'FaceColor','flat','clipping','off')
	hold on
	patch(x + w*[0,1,1,0],y + h*[0,0,1,1],'k','FaceColor','none','Clipping','off')
	patch(x + w*[0,.5,1],y + h+[0,.02,0],'k','EdgeColor','none','FaceColor','k','Clipping','off')
	stick = datestr(ttick');
	text(x - .05,y + h/2,{'{\bfTime}',''},'HorizontalAlignment','center','rotation',90,'FontSize',fs)
	text(x + 1.3*w + zeros(size(ttick)),y + h*(ttick - tscale(1))/diff(tscale([1,end])),stick, ...
		'HorizontalAlignment','left','VerticalAlignment','middle','FontSize',fs*.75,'Rotation',lr)
else
	% horizontal colorbar
	xx = linspace(0,w,size(cmap,1));
	patch(x + [repmat(xx,[2,1]);repmat(xx + diff(xx(1:2)),[2,1])], ...
		y + repmat(h*[0;1;1;0],[1,size(cmap,1)]), ...
		repmat(tscale,[4,1]), ...
		'EdgeColor','flat','LineWidth',.1,'FaceColor','flat','clipping','off')
	hold on
	patch(x + w*[0,1,1,0],y + h*[0,0,1,1],'k','FaceColor','none','Clipping','off')
	patch(x + w + [0,.02,0],y + h*[0,.5,1],'k','EdgeColor','none','FaceColor','k','Clipping','off')
	stick = datestr(ttick');
	text(x + w/2,y + h,'{\bfTime}','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',fs)
	text(x + w*(ttick - tscale(1))/diff(tscale([1,end])), -.3*h + zeros(size(ttick)),stick, ...
		'HorizontalAlignment','right','VerticalAlignment','middle','FontSize',fs*.75,'Rotation',lr)
end
colormap(cmap)
caxis(tlim)
hold off
axis off

end

