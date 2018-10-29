function axisgeo

h = gca;
set(h,'TickDir','out')

xt = get(h,'XTick');
yt = get(h,'YTick');
vx = get(h,'Xlim');
vy = get(h,'YLim');
set(h,'XTickLabel',num2str(xt'))
set(h,'YTickLabel',num2str(yt'))
tl = get(h,'TickLength')/2;
[xx,yy] = meshgrid(xt,yt);
hd = ishold;
hold on
plot(xx,yy,'+k','LineWidth',.1)
if ~hd, hold off, end
xt0 = [vx(1) xt vx(2)];
yt0 = [vy(1) yt vy(2)];
for i = 1:(length(xt0)-1)
    %xt0(i) = max([xt0(i) vx(1)]);
    rx = diff(xt0([i i+1]));
    ry = tl(1)*diff(vy);
    if rx > 0
        rectangle('position',[xt0(i) vy(1)-ry rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
        rectangle('position',[xt0(i) vy(2) rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
    end
end
for i = 1:(length(yt0)-1)
    %yt0(i) = max([yt0(i) vy(1)]);
    ry = diff(yt0([i i+1]));
    rx = tl(1)*diff(vy);
    if ry > 0
        rectangle('position',[vx(1)-rx yt0(i) rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
        rectangle('position',[vx(2) yt0(i) rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
    end
end
box off
set(h,'FontSize',6)
