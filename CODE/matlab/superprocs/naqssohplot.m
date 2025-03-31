function DOUT=naqssohplot(varargin)
%NAQSSOHPLOT WebObs SuperPROC: Updates graphs of Nanometrics Naqs SOH.
%
%       NAQSSOHPLOT(PROC) makes default outputs of Nanometrics Naqs SOH PROC.
%
%       NAQSSOHPLOT(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10yr,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	NAQSSOHPLOT(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = NAQSSOHPLOT(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       NAQSSOHPLOT will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and and nodes' calibration file channels definition.
%       In addition to each single node graph, a summary graph with all nodes can
%       be set with 'SUMMARYLIST|' parameter. Default is all channels, but selection
%       can be made with 'SUMMARY_CHANNELS|' followed by a comma-separated channel
%       number list (example: 1,4,2,3,6). Other specific paramaters are:
%           PAGE_MAX_NODE|8
%
%       Based on genplot, it doesn't read at all the configuration from CLB
%
%
%   Authors: J.M. Saurel / WEBOBS, IPGP
%   Created: 2014-07-13
%   Updated: 2025-03-31

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

tlast = nan(length(N),1);
tfirst = nan(length(N),1);
tfirstall = NaN;

pagemaxnode = field2num(P,'PAGE_MAX_NODE',8);

alarmcolor = [1,.7,.7];
% SOH are 1 point per minute and latency should be less than one day
ACQ_RATE = 1/1440;
LAST_DELAY = 1;
% Thresholds used to calculate NODE status
VOLTAGE_THRESHOLD = 12;		% Input voltage threshold
GPS_THRESHOLD = 3;		% Number of visible GPS satellites
MASS_POS_THRESHOLD = 3.5;	% Absolute value of mass position

for n = 1:length(N)

	stitre = sprintf('%s: %s',N(n).ALIAS,N(n).NAME);
	stype = 'T';

	t = D(n).t;
	d = D(n).d;
	C = D(n).CLB;
	nx = length(C.nm);

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
			if t(ke) >= xlim(2) - LAST_DELAY	% Last data is not late, calculate ratio of available data
				acqui = round(100*length(k)*ACQ_RATE/(t(k(end)) - xlim(1)));
			else					% Last data is late, calulate ratio of expected data
				acqui = round(100*length(k)*ACQ_RATE/(t(k(end)) - LAST_DELAY - xlim(1)));
			end
			if P.GTABLE(r).DECIMATE > 1
				tk = decim(t(k),P.GTABLE(r).DECIMATE);
				dk = decim(d(k,:),P.GTABLE(r).DECIMATE);
			else
				tk = t(k);
				dk = d(k,:);
			end
		end

		if t(ke) >= xlim(2) - LAST_DELAY
			etat = 0;
			if nx == 4				% Centaur
				kX = find(dk(:,1) > VOLTAGE_THRESHOLD);	% Ratio of voltage > threshold vs all measurements
				etatX = length(kX) / length(dk(:,1));
				etat = etat + etatX;

				kX = find(dk(:,3) > GPS_THRESHOLD);		% Ratio of number of GPSs > threshold vs all measurements
				etatX = length(kX) / length(dk(:,3));
				etat = etat + etatX;

				etatX = 1 - rmean(abs(dk(:,4))) / 4;
				etat = etat + etatX;		% Mean of mass position should ba as close to 0 as possible, 4 is maximum
				if rmean(abs(dk(:,4))) > MASS_POS_THRESHOLD	% If mass position > threshold, then urgency, status=0
					etat = 0;
				end

			etat = 100*etat/3;
			end
			if nx == 6				% Taurus, Libra2, Libra1
				kX = find(dk(:,1) > VOLTAGE_THRESHOLD);	% Ratio of voltage > threshold vs all measurements
				etatX = length(kX) / length(dk(:,1));
				etat = etat + etatX;

				kX = find(dk(:,3) > GPS_THRESHOLD);		% Ratio of number of GPSs > threshold vs all measurements
				etatX = length(kX) / length(dk(:,3));
				etat = etat + etatX;

				etatX = 1 - rmean(abs(dk(:,4))) / 4;
				etat = etat + etatX;		% Mean of mass position should ba as close to 0 as possible, 4 is maximum
				if mean(abs(dk(:,4))) > MASS_POS_THRESHOLD	% If mass position > threshold, then urgency, status=0
					etat = 0;
				end

				etatX = 1 - rmean(abs(dk(:,5))) / 4;
				etat = etat + etatX;		% Mean of mass position should ba as close to 0 as possible, 4 is maximum
				if mean(abs(dk(:,5))) > MASS_POS_THRESHOLD	% If mass position > threshold, then urgency, status=0
					etat = 0;
				end

				etatX = 1 - rmean(abs(dk(:,6))) / 4;
				etat = etat + etatX;		% Mean of mass position should ba as close to 0 as possible, 4 is maximum
				if rmean(abs(dk(:,6))) > MASS_POS_THRESHOLD	% If mass position > threshold, then urgency, status=0
					etat = 0;
				end

			etat = 100*etat/5;
			end
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
				plot(tk,dk(:,i),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(i))
				% plots alarms
				ylim = get(gca,'YLim');
				switch i
				case 1
					alarm = VOLTAGE_THRESHOLD;
				case 3
					alarm = GPS_THRESHOLD;
				case {4,5,6}
					alarm = MASS_POS_THRESHOLD * sign(mean(dk(:,i)));
				end
				if alarm > ylim(1) & alarm < ylim(2)
					hold on
					plot(tk,alarm,'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',alarmcolor)
					hold off
				end
			end

			set(gca,'XLim',xlim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			if i < nx
				set(gca,'XTickLabel',[]);
			end
			ylabel(sprintf('%s (%s)',C.nm{i},C.un{i}))
			if isempty(d) | isempty(find(~isnan(d(k,i))))
				nodata(xlim)
			end
		end

		tlabel(xlim,P.GTABLE(r).TZ)

		if ~isempty(k)
			P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ),' (min|avr|max)',' '};
			for i = 1:nx
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+g %s} (%+g | %+g | %+g)', ...
					i, C.nm{i},d(ke,i),C.un{i},roundsd([rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i))],5))}];
			end
		end

		% makes graph
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r))
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

	if isfield(P,'SUMMARY_CHANNELS')
		so = str2num(P.SUMMARY_CHANNELS);
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
			end
			hold off
			set(gca,'XLim',xlim,'FontSize',8)
			box on
			datetick2('x',P.GTABLE(r).DATESTR)
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
