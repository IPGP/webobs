function h = plotorbit(t,d,orb,lst,lwd,mks,col,mav)
% plots time series with optional error bars (if size(d,2)>1) and watermark colors for orbits > 1
hd = ishold;

if nargin < 8
	mav = 1;
end
if mav > 1
	c = col/2 + 0.5;
else
	c = col;
end

% plots data
timeplot(t,d(:,1),[],lst,'LineWidth',lwd,'Color',c,'MarkerSize',mks,'MarkerFaceColor',c);
hold on

% plots error bars
if size(d,2) > 1
	set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis (error bars can overflow)
	h = plot(repmat(t,[1,2])',(repmat(d(:,1),[1,2])+d(:,2)*[-1,1])','-','LineWidth',.1,'Color',.6*[1,1,1]);
	if exist('uistack','file') == 2 % checks if uistack function exists, (only MATLAB, not octave compatible)
		uistack(h,'bottom')
	else % Octave equivalent
		set(h, 'HandleVisibility', 'off');
		axes_children = get(gca, 'Children');
		other_children = setdiff(axes_children, h);
		set(gca, 'Children', [other_children; h]);
		set(h, 'HandleVisibility', 'on');
	end
end

% overwrites non-final orbits
for o = 1:2
	kk = find(orb==o);
	if ~isempty(kk)
		l = o*2;
		wcol = c/l + 1 - 1/l;
		timeplot(t(kk),d(kk,1),[],lst,'LineWidth',lwd,'MarkerSize',mks,'Color',wcol,'MarkerFaceColor',wcol)
	end
end

if mav > 1
	k = ~isnan(d(:,1));
	timeplot(t(k),mavr(d(k,1),mav),[],lst,'LineWidth',lwd,'Color',col,'MarkerSize',mks,'MarkerFaceColor',col)
end


if ~hd
	hold off
end

