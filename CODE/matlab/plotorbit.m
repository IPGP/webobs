function h = plotorbit(t,d,orb,lst,lwd,mks,col)
% plots time series with optional error bars (if size(d,2)>1) and watermark colors for orbits > 1
hd = ishold;

% plots data
timeplot(t,d(:,1),[],lst,'LineWidth',lwd,'Color',col,'MarkerSize',mks,'MarkerFaceColor',col)
hold on

% plots error bars
if size(d,2) > 1
	set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis (error bars can overflow)
	plot(repmat(t,[1,2])',(repmat(d(:,1),[1,2])+d(:,2)*[-1,1])','-','LineWidth',.1,'Color',.6*[1,1,1])
end

% overwrites non-final orbits
for o = 1:2
	kk = find(orb==o);
	if ~isempty(kk)
		l = o*2;
		wcol = col/l + 1 - 1/l;
		timeplot(t(kk),d(kk,1),[],lst,'LineWidth',lwd,'MarkerSize',mks,'Color',wcol,'MarkerFaceColor',wcol)
	end
end

if ~hd
	hold off
end

