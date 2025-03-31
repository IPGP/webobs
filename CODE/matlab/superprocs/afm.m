function DOUT=afm(varargin)
%AFM	WebObs SuperPROC: Updates graphs/exports of AFM results.
%
%       AFM(PROC) makes default outputs of PROC.
%
%       AFM(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10yr,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	AFM(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = AFM(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       AFM will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and nodes' calibration file channels definition.
%       Associated NODEs must have 4 defined channels and optionally a 5th
%       with raingauge. Also, an alarm file can be added using following keys:
%          ALARM_FILE|${RAWDATA}/AFMALARM.DAT
%	   ALARM_TZ|0
%	   PLUVIO_THRESHOLD|3700
%
%
%	Authors: F. Beauducel + V. Clouard + J.M. Saurel / WEBOBS, IPGP
%	Created: 2014-01-03
%	Updated: 2025-03-25

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);


% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR and the data
[P,N,D] = readproc(WO,varargin{:});

A = [];
alarmcolor = [1,.7,.7];
if isfield(P,'ALARM_FILE')
	ptmp = sprintf('%s/%s/%s',WO.PATH_TMP_WEBOBS,P.SELFREF,randname(16));
	fdat = P.ALARM_FILE;
	ftmp = sprintf('%s/alarm.dat',ptmp);
	fprintf('%s: reading alarm file %s ... ',wofun,fdat);
	wosystem(sprintf('mkdir -p %s',ptmp),P);
	wosystem(sprintf('sed -e "s/[\\-\\:]/ /g" -e "s/[^0-9]/ /g" %s | awk ''NF>6 && length($7)==3 && substr($7,1,1)==1 { print $1,$2,$3,$4,$5,$6,substr($7,2,2) }'' > %s',fdat,ftmp),P);
	if exist(ftmp,'file')
		alarm = load(ftmp);
		if isfield(P,'ALARM_TZ')
			atz = str2double(P.ALARM_TZ)/24;
		else
			atz = 0;
		end
		A.t = datenum(alarm(:,[3,1,2,4:6])) - atz;	% alarm file is in local time FWI
		A.s = alarm(:,7);
		fprintf('done.\n');
	else
		fprintf('** WARNING ** file does not exist!\n');
	end
	wosystem(sprintf('rm -rf %s',ptmp),P);
end
if isfield(P,'PLUVIO_THRESHOLD')
	pluvio = str2double(P.PLUVIO_THRESHOLD);
else
	pluvio = 0.9*4096;
end

tlast = nan(length(N),1);
tfirst = nan(length(N),1);
tfirstall = NaN;

for n = 1:length(N)

	stitre = sprintf('%s: %s',N(n).ALIAS,N(n).NAME);

	t = D(n).t;
	d = D(n).d;
	C = D(n).CLB;
	nx = N(n).CLB.nx;

	% make a 6th column with unwraps the rainfall (negative jumps are manual resets)
	if nx > 4
		dd5 = diff(d(:,5));
		dd5(dd5<0) = 0;
		d(:,6) = [0;dd5];

		samp = N(n).ACQ_RATE;
		if samp > 0
			d(:,6) = movsum(d(:,6),round(1/samp));
			C.un{5} = [C.un{5},'/day'];
		end

		% and replaces 5th column by rawdata
		d(:,5) = D(n).r(:,5);
		d(d(:,5)<0,5) = NaN;
	end

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

		figure, clf, orient tall
		k = find((t >= P.GTABLE(r).DATE1 | isnan(P.GTABLE(r).DATE1)) & (t <= P.GTABLE(r).DATE2 | isnan(P.GTABLE(r).DATE2)));
		xlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if isempty(k)
			ke = [];
			if any(isnan(xlim))
				xlim = P.NOW - [1,0];
			end
			acqui = 0;
			tk = [];
			dk = [];
		else
			ke = k(end);
			if any(isnan(xlim))
				xlim = [tfirst(n),tlast(n)];
			end
			acqui = round(100*length(k)*N(n).ACQ_RATE/abs(t(k(end)) - N(n).LAST_DELAY - xlim(1)));
			if P.GTABLE(r).DECIMATE > 1
				tk = decim(t(k),P.GTABLE(r).DECIMATE);
				dk = decim(d(k,:),P.GTABLE(r).DECIMATE);
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
				% specific PLUVIO: d>90% of full scale => status =
				if i == 5 && d(ke,i) > pluvio
					etat = etat - 1;
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

		% loop for each data column
		for i = 1:nx
			subplot(nx*2,1,(i-1)*2+(1:2)), extaxes
			if ~isempty(k)
				switch i
				case {1,2,3,4}
					plot(tk,dk(:,i),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(i))
				case 5
					kr = find(~isnan(dk(:,6)));
					if ~isempty(kr)
						[ax,h1,h2] = plotyy(tk(kr),dk(kr,6),tk,dk(:,5),'area','plot');
						set(h1,'FaceColor','c')
						set(h2,'Color',scolor(i),'LineWidth',P.GTABLE(r).MARKERSIZE/5)
						set(ax(2),'XLim',xlim,'XTick',[],'FontSize',8)
					end
				end
			end

			% plots alarms
			ylim = get(gca,'YLim');
			if ~isempty(A) && isfield(N(n),'FID_AFMALARM')
				hold on
				ka = find(A.t >= xlim(1) & A.t <= xlim(2) & A.s==str2double(N(n).FID_AFMALARM));
				plot3(repmat(A.t(ka),1,2)',repmat(ylim,length(ka),1)',-ones(2,length(ka)),'-','LineWidth',P.GTABLE(r).MARKERSIZE/3,'Color',alarmcolor);
				hold off
			end

			set(gca,'XLim',xlim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s (%s)',C.nm{i},C.un{i}))
			if isempty(d) || all(isnan(d(k,i)))
				nodata(xlim)
			end
		end

		tlabel(xlim,P.GTABLE(r).TZ)

		if ~isempty(k)
			P.GTABLE(r).INFOS = {sprintf('Last data: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ),' (min|moy|max)',' ',' '};
			for i = 1:nx
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+g %s} (%+1.2f | %+1.2f | %+1.2f)', ...
					i, C.nm{i},d(ke,i),C.un{i},rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i)))}];
			end
		end

		% makes graph
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		% exports data
		if isok(P.GTABLE(r),'EXPORTS') && ~isempty(k)
			E.t = tk;
			E.d = dk(:,1:nx);
			E.header = strcat(C.nm,{'('},C.un,{')'});
			E.title = sprintf('%s {%s}',stitre,upper(N(n).ID));
			mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P.GTABLE(r));
		end
	end
end


% ====================================================================================================
% Graphs for all the proc nodes

if isfield(P,'SUMMARYLIST')
	stitre = P.NAME;
	etats = rmean(cat(1,N.STATUS));
	acquis = rmean(cat(1,N.ACQUIS));

	for r = 1:length(P.GTABLE)

		xlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(xlim))
			xlim = [tfirstall,P.NOW];
		end
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [xlim(2),etats,acquis];
		P.GTABLE(r).INFOS = {''};

		% --- Time series graph
		figure, clf, orient tall

		so = [1,2,3];
		for i = 1:3
			subplot(6,1,(i-1)*2+(1:2)), extaxes

			hold on
			aliases = [];
			ncolors = [];
			for n = 1:length(N)
				k = find(D(n).t>=xlim(1) & D(n).t<=xlim(2));
				if ~isempty(k)
					if P.GTABLE(r).DECIMATE > 1
						tk = decim(D(n).t(k),P.GTABLE(r).DECIMATE);
						dk = decim(D(n).d(k,so(i)),P.GTABLE(r).DECIMATE);
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
			set(gca,'XLim',xlim,'FontSize',8)
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
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

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
		close
	end
end

if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end
