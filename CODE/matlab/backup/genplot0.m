function DOUT=genplot(varargin)
%GENPLOT WebObs SuperPROC: Updates graphs/exports of any time series.
%
%       GENPLOT(PROC) makes default outputs of a generic time series PROC.
%
%       GENPLOT(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	GENPLOT(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = GENPLOT(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       GENPLOT will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and and nodes' calibration file channels definition.
%       In addition to each single node graph, a summary graph with all nodes can
%       be set with 'SUMMARYLIST|' parameter. Default is all channels, but selection
%       can be made with 'SUMMARY_CHANNELS|' followed by a coma-separated channel 
%       number list (example: 1,4,2,3,6). Other specific paramaters are:
%           PAGE_MAX_NODE|8
%
%
%   Authors: F. Beauducel, J.-M. Saurel / WEBOBS, IPGP
%   Created: 2014-07-13
%   Updated: 2015-03-25

global WO;
readcfg;

% --- checks input arguments
if nargin < 1
	error('WEBOBS{genplot}: must define PROC name.');
end

proc = varargin{1};

% starts process
timelog(proc,1);

% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR and the data
[P,N,D] = readproc(varargin{:});

A = [];

tlast = nan(length(N),1);
tfirst = nan(length(N),1);
tfirstall = NaN;

if isfield(P,'PAGE_MAX_NODE')
	pagemaxnode = str2double(P.PAGE_MAX_NODE);
else
	pagemaxnode = 8;
end

if isfield(P,'YLOGSCALE')
	ylogscale = str2double(P.YLOGSCALE);
else
	ylogscale = 0;
end

for n = 1:length(N)

	stitre = sprintf('%s: %s',N(n).ALIAS,N(n).NAME);
	stype = 'T';

	t = D(n).t;
	d = D(n).d;
	C = D(n).CLB;
	nx = N(n).CLB.nx;

	if ~isempty(t)
		tlast(n) = rmax(t);
		tfirst(n) = rmin(t);
		tfirstall = min(tfirstall,tfirst(n));
	else
		tlast(n) = now;
		tfirst = now-1;
	end


	
	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure
		if length(N) > pagemaxnode
			p = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[p(1),p(2)*length(N)/pagemaxnode])
		end
		orient tall

		k = find((t >= P.GTABLE(r).DATE1 | isnan(P.GTABLE(r).DATE1)) & (t <= P.GTABLE(r).DATE2 | isnan(P.GTABLE(r).DATE2)));
		xlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if isempty(k)
			k1 = [];
			ke = [];
			if any(isnan(xlim))
				xlim = P.NOW - [1,0];
			end
			acqui = 0;
			tk = [];
			dk = [];
		else
			k1 = k(1);
			ke = k(end);
			if any(isnan(xlim))
				xlim = [tfirst(n),tlast(n)];
			end
			acqui = round(100*length(k)*N(n).ACQ_RATE/abs(t(k(end)) - N(n).LAST_DELAY - xlim(1)));
			if P.GTABLE(r).DECIMATE > 1
				tk = rdecim(t(k),P.GTABLE(r).DECIMATE);
				dk = rdecim(d(k,:),P.GTABLE(r).DECIMATE);
			else
				tk = t(k);
				dk = d(k,:);
			end
		end

		if t(ke) >= xlim(2) - N(n).LAST_DELAY
			etat = 0;
			for i = 1:nx
				if ~isnan(d(ke,i))
					etat = etat + 1;
				end
			end
			etat = 100*etat/nx;

		else
			etat = 0;
		end
    

		% title and status
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [xlim(2),etat,acqui];
		N(n).STATUS = etat;
		N(n).ACQUIS = acqui;
		P.GTABLE(r).INFOS = {''};
		if P.GTABLE(r).STATUS
			sd = '';
			for i = 1:nx
				if ~isempty(d)
					sd = [sd sprintf(', %g %s', d(end,i),C.un{i})];
				else
					sd = [sd ', no data'];
				end
			end
			mkstatus(struct('NODE',sprintf('%s.%s',P.SELFREF,N(n).ID),'STA',etat,'ACQ',acqui,'TS',tlast(n),'TZ',P.TZ,'COMMENT',sd(3:end)));
		end

		% loop for each data column
		for i = 1:nx
			subplot(nx*2,1,(i-1)*2+(1:2)), extaxes
			if ~isempty(k)
				plot(tk,dk(:,i),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(i))
			end
			if ylogscale
				set(gca,'YScale','log')
			end
			set(gca,'XLim',xlim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR,'keeplimits')
			if i < nx
				set(gca,'XTickLabel',[]);
			end
			ylabel(sprintf('%s (%s)',C.nm{i},C.un{i}))
			if isempty(d) | isempty(find(~isnan(d(k,i))))
				nodata(xlim)
			end
		end

		tlabel(xlim,P.GTABLE(r).TZ)
		plotevent(P.EVENTS_FILE)

		if ~isempty(k)
			P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ),' (min|avr|max)',' '};
			for i = 1:nx
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+g %s} (%+g | %+g | %+g)', ...
					i, C.nm{i},d(ke,i),C.un{i},roundsd([rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i))],5))}];
			end
		end
		
		% makes graph
		mkgraph(sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close

		% exports data
		if P.GTABLE(r).EXPORTS & ~isempty(k)
			E.t = tk;
			E.d = dk(:,1:nx);
			E.header = strcat(C.nm,{'('},C.un,{')'});
			E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
			mkexport(sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
end


% ====================================================================================================
% Graphs for all the proc nodes

if isfield(P,'SUMMARYLIST')
	stitre = P.NAME;
	etats = rmean(cat(1,N.STATUS));
	acquis = rmean(cat(1,N.ACQUIS));

	if isfield(P,'SUMMARY_CHANNELS')
		so = sstr2num(P.SUMMARY_CHANNELS);
		so = so(ismember(so,1:nx));
	else
		so = 1:nx;
	end

	for r = 1:length(P.GTABLE)

		xlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(xlim))
			xlim = [tfirstall,P.NOW];
		end
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [xlim(2),etats,acquis];
		P.GTABLE(r).INFOS = {''};

		% --- Time series graph
		figure
		if length(so) > pagemaxnode
			p = get(gcf,'PaperSize');
			set(gcf,'PaperSize',[p(1),p(2)*length(so)/pagemaxnode])
		end
		orient tall

		for i = 1:length(so)
			subplot(length(so)*2,1,(i-1)*2+(1:2)), extaxes

			hold on
			aliases = [];
			ncolors = [];
			for n = 1:length(N)
				k = find(D(n).t>=xlim(1) & D(n).t<=xlim(2));
				if ~isempty(k)
					if P.GTABLE(r).DECIMATE > 1
						tk = rdecim(D(n).t(k),P.GTABLE(r).DECIMATE);
						dk = rdecim(D(n).d(k,so(i)),P.GTABLE(r).DECIMATE);
					else
						tk = D(n).t(k);
						dk = D(n).d(k,so(i));
					end
					plot(tk,dk,'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(n))
					aliases = [aliases,{N(n).ALIAS}];
					ncolors = [ncolors,n];
				end
				if length(N(n).CLB.nm) >= so(i)
					C = N(n).CLB;
				end
			end
			hold off
			if ylogscale
				set(gca,'YScale','log')
			end
			set(gca,'XLim',xlim,'FontSize',8)
			box on
			datetick2('x',P.GTABLE(r).DATESTR,'keeplimits')
			if i < length(so)
				set(gca,'XTickLabel',[]);
			end
			ylabel(sprintf('%s (%s)',C.nm{so(i)},C.un{so(i)}))
			
			% legend: station aliases
			xlim = get(gca,'XLim');
			ylim = get(gca,'YLim');
			nn = length(aliases);
			for n = 1:nn
				text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
			end
			set(gca,'YLim',ylim);
		end

		tlabel(xlim,P.GTABLE(r).TZ)
		plotevent(P.EVENTS_FILE)
	    
		mkgraph(sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end
end

if P.REQUEST
	mkendreq(P);
end

timelog(proc,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end

