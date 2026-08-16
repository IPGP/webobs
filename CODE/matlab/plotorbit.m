function h = plotorbit(t,d,orb,lst,lwd,mks,col,mav)
%PLOTORBIT Time series plot with error bars and watermark color
%   PLOTORBIT(T,D,ORBIT,LINESTYLE,LINEWIDTH,MARKER,COLOR,MOVAVG) plots time series 
%   D(T) with optional error bars (if size(D,2)>1) using LINESTYLE, LINEWIDTH,
%   MARKER and COLOR, and watermark color for ORBIT > 1.
%   Plots also optional moving average if MOVAVG > 1, using lighter color for 
%   raw data in that case.
%
%   Author: François Beauducel, WebObs
%   Created: 2019-05-19
%   Updated: 2026-08-13

hd = ishold;

if nargin < 8
	mav = 1;
end
if mav > 1
	c = col/2 + 0.5;
	k = ~isnan(d(:,1));
    d2 = nan(size(d(:,1)));
    d2(k,:) = mavr(d(k,1),mav);
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
	end
end

% overwrites non-final orbits
for o = 1:2
	kk = (orb >= o);
	if sum(kk) > 0
		l = o*2;
		wcol = c/l + 1 - 1/l;
		timeplot(t(kk),d(kk,1),[],lst,'LineWidth',lwd,'MarkerSize',mks,'Color',wcol,'MarkerFaceColor',wcol)
	end
end

% overwrites with moving average
if mav > 1
    for o = 0:2
        kk = (orb == o);
        if sum(kk) > 0
            l = 1 + o;
            wcol = col/l + 1 - 1/l;
            timeplot(t(kk),d2(kk),[],lst,'LineWidth',lwd,'MarkerSize',mks,'Color',wcol,'MarkerFaceColor',wcol)
        end
    end
end


if ~hd
	hold off
end

