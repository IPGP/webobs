function [lre,V] = smartplot(X,tlim,G,OPT)
%SMARTPLOT Enhanced multi-component timeseries plot
%	SMARTPLOT plots a single graph divided into channel subplots, each
%	subplot grouping all nodes with different colors. This supposes all
%	have the same unit. An option is to duplicate this graph with a time
%	zoomed period.
%
%		       ~~~  (nd 1)
%		ch 1   ~~   (nd 2)
%
%		       ~~~  (nd 1)
%		ch 2   ~~   (nd 2)
%
%		       ~~~  (nd 1)
%		ch 3   ~~   (nd 2)
%
%	SMARTPLOT uses structure of multiple 'nodes' X(n) containing fields:
%	   t: time vector
%	   d: data matrix with several 'channels' d(:,i) with the same unit
%	   e: error matrix (optional, same size, same unit as d)
%	   w: data weight vector (0 = plain, 1 = 50% lighter, 2 = 67%, ...)
%	 trd: trend flag (true plots a linear trend for corresponding node)
%	 rgb: RGB color
%	 nam: node's name string
%
%
%	tlim: 2-element vector to define time period.
%
%	G: A structure containing fields from proc's GTABLE to set G.LINEWIDTH,
%	G.MARKERSIZE, G.DATESTR and G.TZ (timezone).
%
%	OPT: A structure containing fields of options:
%	   linestyle: string compatible with plot function (line/marker type).
%	    fontsize: scalar that applies for all axes text.
%	     chnames: cell of strings defining the channel names.
%	    choffset: scalar defining the space between each channel subplots
%	     zoompca: scalar defining the ratio of zoom if positive or PCA if negative.
%	      movavr: number of samples to compute and plot a moving average
%	 yscalevalue: fixes the Y-scale (value in data unit)
%	  yscaleunit: name of the scale unit (default is 'cm')
%	  yscalefact: factor of the scale unit (default is 100)
%	     TREND_*: several parameters passed to treatsignal function to compute trend.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2019-05-14
%	Updated: 2025-02-27

linestyle = field2str(OPT,'linestyle','-');
fontsize = field2num(OPT,'fontsize',8);
chnames = OPT.chnames;
choffset = field2num(OPT,'choffset');
zoompca = field2num(OPT,'zoompca');
movavr = field2num(OPT,'movavr',1);
yscalevalue = field2num(OPT,'yscalevalue');
yscaleunit = field2str(OPT,'yscaleunit','cm');
yscalefact = field2num(OPT,'yscalefact',100);

tzoom = double(isinto(zoompca,[0,1],'exclude'));
npca = (zoompca<0)*ceil(abs(zoompca));
V = [];
for ii = 0:(tzoom+(zoompca<0))
	% computes PCA
	if npca > 0 && ii > 0
		[y,V,D] = pca(X(npca).d);
		if ~isempty(y)
			X = struct('t',X(npca).t,'d',y,'w',X(npca).w,'e',X(npca).e*V,'nam',X(npca).nam,'rgb',X(npca).rgb,'trd',X(npca).trd);
		else
			X = struct('t',X(npca).t,'d',y,'w',X(npca).w,'e',X(npca).e,'nam',X(npca).nam,'rgb',X(npca).rgb,'trd',X(npca).trd);
		end
		chnames = split(strtrim(sprintf('Eig.#%d %1.1f%%|',[1:size(X.d,2);100*D'/sum(D(:))])),'|');
	end
	% computes global min/max for each component (all stations)
	% completes missing columns
	alld = cat(1,X.d);
	% number of channels
	nx = size(alld,2);
	if tzoom && ii > 0
		tlim = [-zoompca*diff(tlim),0] + tlim(2);
		alld = alld(isinto(cat(1,X.t),tlim),:);
	end
	if ~isempty(alld)
		gmin = min(alld,[],1);
		gmax = max(alld,[],1);
		gmin(isnan(gmin)) = 0;
		gmax(isnan(gmax)) = 0;
	else
		gmin = zeros(1,nx);
		gmax = zeros(1,nx);
	end

	% component offset (relative to first component median value)
	cmpoffset = zeros(1,nx);
	for i = 2:nx
		cmpoffset(i) = cmpoffset(i-1) + gmin(i-1) - gmax(i) - choffset;
	end

	% plots the data
	subplot(4,1,ii*2 + (1:(4/(1+tzoom+(zoompca<0))))), extaxes(gca,[.08,.04])
	hold on
	if ii == 0
		lre = nan(nx,2);
	end
	for i = 1:nx
		if i < nx
			fill([tlim,fliplr(tlim)],cmpoffset(i) + gmin(i) - [.25,.25,.75,.75]*choffset,'w','FaceColor',.95*ones(1,3),'EdgeColor','none')
		end
		for n = 1:length(X)
			if ~isempty(X(n).d)
				d = X(n).d(:,i) + cmpoffset(i);
				if isfield(X(n),'e') && ~isempty(X(n).e)
					d = [d,X(n).e(:,i)];
				end
				plotorbit(X(n).t,d,X(n).w,linestyle,G.LINEWIDTH,G.MARKERSIZE,X(n).rgb,movavr);
				if npca > 0 && ii > 0
					plotorbit(X(n).t,mavr(d(:,1),10),X(n).w,'-',G.LINEWIDTH,G.MARKERSIZE/2,scolor(2));
				end
				kk = find(~isnan(d(:,1)));
				if ii == 0 && X(n).trd && length(kk) >= 2
                    [~,~,lr,tre] = treatsignal(X(n).t(kk) - tlim(1),d(kk,:),1,OPT);
					lre(i,:) = [lr(1),tre];
					plot(tlim,polyval(lr,tlim - tlim(1)),'--k','LineWidth',.2)
				end
			end
		end
	end
	hold off
	if nx > 0
		set(gca,'YLim',[cmpoffset(end)+gmin(end)-abs(choffset)/2,gmax(1)+abs(choffset)/2])
	else
		set(gca,'YLim',0.01 + 3*abs(choffset)*[-1,1]);
	end
	set(gca,'XLim',tlim,'FontSize',fontsize,'YTickLabel',[]);
	box on

	ylim = get(gca,'YLim');
	% --- legends
	datetick2('x',G.DATESTR)
	% y-labels
	for i = 1:nx
		text(tlim(1),cmpoffset(i),[split(chnames{i},' '),' '],'FontSize',fontsize*1.25,'FontWeight','bold', ...
			'HorizontalAlignment','center','VerticalAlignment','bottom','Rotation',90);
	end
	% y-scale
	if yscalevalue > 0 && diff(ylim) > 2*yscalevalue
		set(gca,'YTick',(ceil(ylim(1)/yscalevalue):floor(ylim(2)/yscalevalue))*yscalevalue);
	end
	ytick = get(gca,'YTick');
	set(gca,'TickLength',[0.005,0.005]) % reduces tick length
	hold on
	xt = tlim(2) + .015*diff(tlim)*[1,2,2,1];
	yt = ytick(end-[1,1,0,0]);
	plot(xt,yt,'k','LineWidth',1.5,'Clipping','off')
	text(xt(2),mean(yt(2:3)),sprintf('{\\bf%g %s}',yscalefact*diff(ytick(1:2)),yscaleunit),'FontSize',fontsize*1.25, ...
		'HorizontalAlignment','center','VerticalAlignment','bottom','Rotation',90)

	% indicates zoom
	if tzoom && ii==0
		xt = [-zoompca*diff(tlim),0] + tlim(2);
		yt = ylim(1) - 0.04*diff(ylim) + [0,0];
		ct = .3*[1,1,1];
		plot(xt,yt,'-','LineWidth',1.5,'Color',ct,'Clipping','off')
		text(mean(xt),yt(1),'zoom','Color',ct,'FontSize',fontsize,'FontWeight','bold', ...
			'HorizontalAlignment','center','VerticalAlignment','top')
	end

	hold off

	if ii==0
		% node aliases (not empty elements only)
		ka = find(~cellfun(@isempty,{X.nam}));
		nl = length(ka);
		fs = fontsize*max(min(50/length(strjoin({X.nam})),1),0.5);
		for n = 1:nl
			text(tlim(1)+n*diff(tlim)/(nl+1),ylim(2),X(ka(n)).nam,'Color',X(ka(n)).rgb, ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',fs,'FontWeight','bold')
		end
	end
	if npca > 0 && ii > 0
		title('Principal Component Analysis: raw data and 10-day filtering','FontWeight','bold')
	end
	set(gca,'YLim',ylim);

	tlabel(tlim,G.TZ,'FontSize',fontsize)
end
