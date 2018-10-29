function h=rosace(th,rh,s,mks)
%ROSACE Polar geographic coordinate plot.
%       ROSACE(TH,RH,S) plot a rose with angles TH (in radian), 
%       magnitudes RH and optional line style S, with geographic orientation.
%
%       (c) F. Beauducel, OVSG-IPGP, 2001-2002.

if nargin < 3
    s = '.';
end
if nargin < 4
    mks = 1;
end
m = rmax(rmax(rh));
if isnan(m) | ~m
    m = .1;
end
m2 = m*cos(pi/4);

rectangle('position',m*[-1 -1 2 2],'curvature',[1 1],'FaceColor','w')
hold on

% Grilles
plot(m*[-1 0;1 0],m*[0 1;0 -1],':k')
plot(m2*[-1 -1;1 1],m2*[1 -1;-1 1],':k')
yt = get(gca,'YTick');
yl = get(gca,'YTickLabel');
k = find(yt>0 & yt<=m);
yt = yt(k);
yl = yl(k,:);
for i = 1:length(yt)
    rectangle('position',yt(i)*[-1 -1 2 2],'curvature',[1 1],'LineStyle',':')
end
text(zeros(size(yt)),yt,yl,'HorizontalAlignment','right','VerticalAlignment','top','Fontsize',8)

% Texte
text(0,m,'N','HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold')
text(0,-m,'S','HorizontalAlignment','center','VerticalAlignment','top','FontWeight','bold')
text(m,0,' E','HorizontalAlignment','left','VerticalAlignment','middle','FontWeight','bold')
text(-m,0,'W ','HorizontalAlignment','right','VerticalAlignment','middle','FontWeight','bold')
text(m2,m2,'NE','HorizontalAlignment','left','VerticalAlignment','bottom','FontWeight','bold')
text(-m2,m2,'NW','HorizontalAlignment','right','VerticalAlignment','bottom','FontWeight','bold')
text(m2,-m2,' SE','HorizontalAlignment','left','VerticalAlignment','top','FontWeight','bold')
text(-m2,-m2,'SW ','HorizontalAlignment','right','VerticalAlignment','top','FontWeight','bold')

[x,y] = pol2cart(th,rh);
hh = plot(x,y,s,'MarkerSize',mks);
hold off
axis equal
axis off

if nargout>0
    h = hh;
end
