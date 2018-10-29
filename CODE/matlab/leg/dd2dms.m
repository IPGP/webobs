function hout=dd2dms(h,x);
%DD2DMS	Decimal degree to DMS geographical axis.
%	DD2DMS changes the axis ticks and labels of the current graph 
%	from signed decimal degrees to degrees, minutes and seconds 
%	geographical latitude-longitude coordinates.
%
%	DD2DMS(H) applies to the axe's handle H.
%
%   DD2HMS(H,X) adds GMT-like axis (X=0) and small crosses inside graphic for each tick (X=1).
%
%	Note: to adjust axis after a zoom, type DD2DMS again.
%
%	F. Beauducel, OV 1999.
%   Revised: 2005-08-18, OVSG-IPGP

if nargin==0, h = gca; end
pc = 'W ES N';
a = 'XY';
eps = 1/36000;
tickint = [100    20;
            50    10;
            25     5; 
            10     2;
             5     1;
             2.5    .5;
             1     1/3;
              .5   1/6;
              .25  1/12;
              .1   1/30;
              .05  1/60;
              .025 1/120;
              .01  1/180;
              .005 1/360;
              .0025 1/720;
              .001  1/1440;
             0 1/3600];
xylim = [get(h,'XLim'),get(h,'YLim')];
pos = get(h,'Position');
hh = [];
for i = 1:2
    v = get(h,[a(i) 'Lim']);
    m = diff(v);
    if m >= tickint(1,1), dt = tickint(1,2);
    else dt = tickint(min(find(m >= tickint(:,1))),2);
    end
    t = dt*round(v(1)/dt):dt:v(2);
    set(h,[a(i) 'Tick'],t)
    set(h,[a(i) 'Lim'],v)
    t = get(h,[a(i) 'Tick']);
    l = length(t);
    dms = zeros(l,4);
    dms(:,4) = sign(t');
    t = abs(t');
    dms(:,1) = fix(t+eps);
    dms(:,2) = fix((t-dms(:,1)+eps)*60);
    dms(:,3) = round((t-dms(:,1)-dms(:,2)/60)*3600);

    if all(dms(:,3)==0)
        if all(dms(:,2)==0)
            lb = reshape(sprintf('%3d°',dms(:,1)'),4,l)';
        else
            lb = reshape(sprintf('%3d°%02d''',dms(:,1:2)'),7,l)';
        end
    else
        lb = reshape(sprintf('%3d°%02d''%02d"',dms(:,1:3)'),10,l)';
    end
    lb = [lb pc(rem(dms(:,4),6)+i*3-1)'];
    set(h,[a(i) 'TickLabel'],'')
    if i == 1
        ho = text(get(h,[a(i) 'Tick']),repmat(xylim(3)-.015*diff(xylim(1:2)),size(t)),cellstr(lb),'HorizontalAlignment','center','VerticalAlignment','top','FontSize',8);
    else
        ho = text(repmat(xylim(1)-.015*diff(xylim(1:2)),size(t)),get(h,[a(i) 'Tick']),cellstr(lb),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8,'rotation',90);
    end
    hh = [hh;ho];
end

set(h,'TickDir','out')

% Adds crosses at each tick
if nargin > 1
    xt = get(h,'XTick');
    yt = get(h,'YTick');
    vx = get(h,'Xlim');
    vy = get(h,'YLim');
    tl = get(h,'TickLength')/2;
    [xx,yy] = meshgrid(xt,yt);
    if x == 1
        hold on
        plot(xx,yy,'+k','LineWidth',.1)
        hold off
    end
    xt0 = [vx(1) xt vx(2)];
    yt0 = [vy(1) yt vy(2)];
    for i = 1:(length(xt0)-1)
        xt0(i) = max([xt0(i) vx(1)]);
        rx = diff(xt0([i i+1]));
        ry = tl(1)*diff(vy);
        if rx > 0
            rectangle('position',[xt0(i) vy(1)-ry rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
            rectangle('position',[xt0(i) vy(2) rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
        end
    end
    for i = 1:(length(yt0)-1)
        yt0(i) = max([yt0(i) vy(1)]);
        ry = diff(yt0([i i+1]));
        rx = tl(1)*diff(vy);
        if ry > 0
            rectangle('position',[vx(1)-rx yt0(i) rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
            rectangle('position',[vx(2) yt0(i) rx ry],'FaceColor',mod(i,2)*[1 1 1],'Clipping','off')
        end
    end
end
box off
set(h,'XTickMode','manual','YTickMode','manual')

if nargout > 0
    hout = hh;
end
