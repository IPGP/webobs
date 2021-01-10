function DOUT=soh(varargin)
%SOH	WebObs SuperPROC: Updates graphs/exports of SOH results.
%
%       SOH(PROC) makes default outputs of PROC from associated nodes
%       that contain State of Health data. The graph contains specific
%       plots for voltage, temperature, current and mass positions.
%
%       SOH(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	SOH(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = SOH(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%	SOH will use PROC's parameters from NODE's .cnf file. Particularily, it
%       uses RAWFORMAT and and associated NODEs' calibration file channels
%       definition. Data must contain following channels: voltage, temperature,
%       current, mass position (1,2,3 or E,N,U) identified by their NODE's
%       calibration file channel numbers.
%
%
%           MOVING_AVERAGE_SAMPLES|100
%	    PDF_COLORMAP|hsv2
%	    VOLTAGE_CHANNEL|
%	    CURRENT_CHANNEL|
%	    TEMPERATURE_CHANNEL|
%	    GPS_COUNT_CHANNEL|
%	    MASS_POS_CHANNELS|1,2,3
%	    MASS_POS_THRESHOLD_PERCENT|80
%	    MASS_POS_COLORMAP|rog
%
%	X-Y graph is set using the x,y channel numbers as:
%	    XY_CHANNELS|${VOLTAGE_CHANNEL},${CURRENT_CHANNEL}
%
%	Two Probability Density Function graphs:
%	    PDF1_CHANNEL|${TEMPERATURE_CHANNEL}
%	    PDF2_CHANNEL|${VOLTAGE_CHANNEL}
%
%	Periodogram:
%	    PGRAM_CHANNEL|${VOLTAGE_CHANNEL}
%	    PGRAM_CHANNEL|jet
%
%

%
%   Authors: Jean-Marie Saurel, Fran�ois Beauducel, IPGP
%   Created: 2017-10-09 in Paris, France
%   Updated: 2021-01-01

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);

% gets PROC's configuration and associated nodes for any TSCALE and/or REQDIR
[P,N,D] = readproc(WO,varargin{:});

% proc's specific variables
movingaverage = field2num(P,'MOVING_AVERAGE_SAMPLES',1);
cmap = field2num(P,'MASS_POS_COLORMAP',rog(64));
masscmap = [cmap;flipud(cmap)];
pdfcmap = field2num(P,'PDF_COLORMAP',hsv(256));
pdfcmap(1,:) = 1; % forces the first color to white
i_voltage = field2num(P,'VOLTAGE_CHANNEL');
i_current = field2num(P,'CURRENT_CHANNEL');
i_temperature = field2num(P,'TEMPERATURE_CHANNEL');
i_gpscount = field2num(P,'GPS_COUNT_CHANNEL');
i_mass = field2num(P,'MASS_POS_CHANNELS');
i_xy = field2num(P,'XY_CHANNELS',[i_voltage,i_current]);
i_pdf1 = field2num(P,'PDF1_CHANNEL',i_temperature);
i_pdf2 = field2num(P,'PDF2_CHANNEL',i_voltage);
i_pgram = field2num(P,'PGRAM_CHANNEL',i_temperature);
pgramcmap = field2num(P,'PGRAM_COLORMAP',jet);


for n = 1:length(N)
	stitre = sprintf('%s : %s',N(n).ALIAS,N(n).NAME);

	t = D(n).t;
	d = D(n).d;
	C = D(n).CLB;
	nx = length(C.nm);

	% needs a constant sampling period...
	dt = unique(diff(t));
	samp = min(dt(dt>0));


	% ===================== makes the proc's job

	for r = 1:length(P.GTABLE)

		figure, clf, orient tall

		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;
		tk = [];
		dk = nan(0,nx);
		if ~isempty(k)
			[tk,dk] = treatsignal(t(k),d(k,:),P.GTABLE(r).DECIMATE,P);
		end

		% title and status
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];
		P.GTABLE(r).INFOS = {''};

		P.GTABLE(r).INFOS = {'Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(t(ke)),P.GTABLE(r).TZ),'(min|moy|max)',' '};
		for i = 1:nx
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{sprintf('%d. %s = {\\bf%+1.1f %s} (%+1.1f | %+1.1f | %+1.1f)', ...
				i, C.nm{i},d(ke,i),C.un{i},rmin(dk(:,i)),rmean(dk(:,i)),rmax(dk(:,i)))}];
		end

		% computes sunrise and sunset for all days in the timescale
		[srise,sset] = sunrise(N(n).LAT_WGS84,N(n).LON_WGS84,N(n).ALTITUDE,P.TZ,(floor(tlim(1)):floor(tlim(2)))');

		py = .78; % lower position of the 3 following graphs

		% X-Y graph
		axes('position',[.07,py,0.21,0.15]);
		plot(dk(:,i_xy(1)),dk(:,i_xy(2)),'.','MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',scolor(i_xy(2)))
		hold on
		if movingaverage > 1
			col = .5 + scolor(i_xy(2))/2;
			plot(mavr(dk(:,i_xy(1)),movingaverage),mavr(dk(:,i_xy(2)),movingaverage),'.', ...
				'MarkerSize',P.GTABLE(r).MARKERSIZE,'Color',col,'MarkerFaceColor',col)
		end
		plot(d(ke,i_xy(1)),d(ke,i_xy(2)),'ok','LineWidth',2)
		hold off
		set(gca,'FontSize',8)
		xlabel(sprintf('%s (%s)',C.nm{i_xy(1)},C.un{i_xy(1)}))
		ylabel(sprintf('%s (%s)',C.nm{i_xy(2)},C.un{i_xy(2)}))

		nbins = min(300,length(unique(mod(tk(:),1))));

		% PDF1
		axes('position',[.35,py,0.28,0.18]);
		kk = find(~isnan(dk(:,i_pdf1)));
		if ~isempty(kk)
			[pdf,xbin,ybin,nmax] = stack2(mod(tk(kk),1),dk(kk,i_pdf1),nbins);
			imagesc(xbin,ybin,100*pdf), axis xy
			colormap(shademap(flipud(hsv(max(64,nmax))),.3))
			caxis([0,100*max(pdf(:))])
			ylim = minmax(ybin);
		else
			ylim = [0,1];
		end
		hold on
		plot(repmat(mod(srise,1),1,2)',repmat(ylim,size(srise,1),1)',':','Color',.5*ones(1,3),'MarkerSize',.1)
		plot(repmat(mod(sset,1),1,2)',repmat(ylim,size(sset,1),1)',':','Color',.5*ones(1,3),'MarkerSize',.1)
		hold off
		set(gca,'FontSize',8,'XLim',[0,1],'YLim',ylim)
		datetick2('x','HH')
		xlabel('Time (hours)')
		ylabel(sprintf('%s (%s)',C.nm{i_pdf1},C.un{i_pdf1}))
		colorbar(gca,'NorthOutside')

		% PDF2
		axes('position',[.7,py,0.28,0.18]);
		kk = find(~isnan(dk(:,i_pdf2)));
		if ~isempty(kk)
			[pdf,xbin,ybin,nmax] = stack2(mod(tk(kk),1),dk(kk,i_pdf2),nbins);
			imagesc(xbin,ybin,100*pdf), axis xy
			colormap(shademap(flipud(hsv(max(64,nmax))),.3))
			caxis([0,100*max(pdf(:))])
			ylim = minmax(ybin);
		else
			ylim = [0,1];
		end
		hold on
		plot(repmat(mod(srise,1),1,2)',repmat(ylim,size(srise,1),1)',':','Color',.5*ones(1,3),'MarkerSize',.1)
		plot(repmat(mod(sset,1),1,2)',repmat(ylim,size(sset,1),1)',':','Color',.5*ones(1,3),'MarkerSize',.1)
		hold off
		set(gca,'FontSize',8,'XLim',[0,1],'YLim',ylim)
		datetick2('x','HH')
		xlabel('Time (hours)')
		ylabel(sprintf('%s (%s)',C.nm{i_pdf2},C.un{i_pdf2}))
		colorbar(gca,'NorthOutside')

		% Periodogram
		subplot(13,1,4:5), extaxes(gca,[.07,.02])
		ti = (tlim(1):samp:tlim(2))';
		k = find(diff(tk)>0) + 1;
		di = interp1(tk(k),dk(k,i_pgram),ti,'nearest') - rmean(dk(:,i_pgram));
		[S,F,T] = myspecgram(di,512,1/(samp*86400),2880,1024);
		n2 = round(length(F)/2);
		SFFT = 20*log10(abs(S(1:n2,:)));
		I = ind2rgb(ceil((length(pgramcmap)*4)*SFFT/max(SFFT(:))),pgramcmap);
		[i,j] = find(isnan(SFFT));
		I(i,j,:) = 1; % forces white for NaN values (not imagesc behavior)
		imagesc(tlim(1)+T/86400,F(1:n2),I), axis xy

		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		set(gca,'XTickLabel',[]);
		ylabel(sprintf('Freq. %s (Hz)',C.nm{i_pgram}))

		% Mass position
		subplot(13,1,6:7), extaxes(gca,[.07,.02])
		hold on
		for i = 1:length(i_mass)
			timeplot(tk,dk(:,i_mass(i)),[],'Color',scolor(i_mass(i)));
		end
		hold off, box on
		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		set(gca,'XTickLabel',[]);
		ylabel(sprintf('Mass pos (%s)',C.un{i_mass(1)}))

		% Time series channels
		tsc = [i_voltage,i_temperature,i_gpscount];
		for i = 1:length(tsc)
			subplot(13,1,7 + (i-1)*2 + (1:2)), extaxes(gca,[.07,.02])
			timeplot(tk,dk(:,tsc(i)),[],'Color',scolor(tsc(i)));
			if movingaverage > 1
				hold on
				col = .5+scolor(tsc(i))/2;
				timeplot(tk,mavr(dk(:,tsc(i)),movingaverage),D(n).CLB.sf(i),'-', ...
					'LineWidth',P.GTABLE(r).LINEWIDTH,'Color',col,'MarkerFaceColor',col)
				hold off
			end
			ylim = minmax(dk(:,tsc(i)));
			if any(isnan(ylim))
				ylim = [0,1];
			end
			set(gca,'XLim',tlim,'YLim',ylim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			if i < length(tsc), set(gca,'XTickLabel',[]); end
			ylabel(sprintf('%s (%s)',C.nm{tsc(i)},C.un{tsc(i)}))
		end

		tlabel(tlim,P.GTABLE(r).TZ)

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

if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)

% Returns data in DOUT
if nargout > 0
	DOUT = D;
end
