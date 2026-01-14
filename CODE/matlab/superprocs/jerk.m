function DOUT=jerk(varargin)
%JERK	WebObs SuperPROC: Updates graphs/exports of JERK results.
%
%       JERK(PROC) makes default outputs of PROC.
%
%       JERK(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	JERK(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = JERK(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       JERK will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and associated NODEs' calibration file channels
%       definition. But these nodes must contain 3 channels exactly as follows:
%           Channel 1 = LME Eastern mass position (nm/s2)
%           Channel 2 = LMN Norther mass position (nm/s2)
%           Channel 3 = LKI (temperature) or LDI (atmospheric pressure)
%
%	Also, Earth tide prediction program GOTIC2 is used, downloadable at:
%	    http://www.miz.nao.ac.jp/staffs/nao99/index_En.html
%	so the following key in WEBOBS.rc must be defined:
%	    PRGM_GOTIC2|/opt/nao99b/gotic2/gotic2
%	and NODE's location (latitude,longitude) must be defined and correct.
%
%	Additional keys are needed in the PROC configuration. See template PROC.JERK for
%   details and comments.
%
%
%
%   Authors: F. Beauducel + G. Roult + V. Ferrazzini, WEBOBS/IPGP
%   Created: 2014-04-14 at OVPF, La Réunion, Indian Ocean
%   Updated: 2026-01-13

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);

% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR
[P,N,D] = readproc(WO,varargin{:});

tidemodes = {'Solid+Ocean','Solid','Ocean','none'};

% gets PROC's specific parameters
mw = field2num(P,'JERK_WINDOW_SECONDS');
dt = field2num(P,'JERK_SAMPLING_SECONDS');
threshold_level1 = 1e9*field2num(P,'JERK_THRESHOLD_LEVEL1_MS3',2e-10);	% threshold in nm/s3
threshold_level2 = 1e9*field2num(P,'JERK_THRESHOLD_LEVEL2_MS3',1e-10);	% threshold in nm/s3
threshold_max = 1e9*field2num(P,'JERK_THRESHOLD_MAX_MS3',1e-8);	% max threshold in nm/s3
rgb_level1 = field2num(P,'LEVEL1_RGB',[0.7,1,0.7]);
rgb_level2 = field2num(P,'LEVEL2_RGB',[1,0.7,0.7]);
zoomdays = field2num(P,'JERK_ZOOM_DAYS',1);
targetlatlon = field2num(P,'JERK_TARGET_LATLON');
targetangle = field2num(P,'JERK_TARGET_ANGLE_DEG',45);
procazlim = field2num(P,'JERK_AZLIM',[0,180]);
chan_median_minmax = field2num(P,'MEDIAN_MINMAX_FILTERING');
chan_smooth = field2num(P,'CHANNELS_MOVING_AVERAGE_SAMPLES',ones(1,4));
tidemode = field2num(P,'TIDES_PREDICT_MODE',0);

cb2 = char(178); % superscript 2 (latin)
cb3 = char(179); % superscript 3 (latin)
cba = char(186); % degree sign (latin)

tlast = nan(length(N),1);
tfirst = nan(length(N),1);
tfirstall = NaN;

for n = 1:length(N)
	stitle = sprintf('JERK %s: %s',N(n).ALIAS,N(n).NAME);

	t = D(n).t;
	d = D(n).d;
	for c = 1:size(d,2)
        if length(chan_median_minmax) == 3
            mm = minmax(d(:,c),chan_median_minmax(1:2));
            mm = mm + chan_median_minmax(3)*[-1,1]*diff(mm); % adds extent of minmax to avoid filtering normal maxima
            k = ~isinto(d(:,c),mm);
            d(k,c) = NaN;
            if sum(k)>0
                fprintf('  --> channel %d median min/max filter: %d samples have been excluded.\n',c,sum(k));
            end
        end
		if length(chan_smooth) >= c && chan_smooth(c) > 1
			d(:,c) = mavr(d(:,c),chan_smooth(c));
		end
	end
	C = D(n).CLB;
	nx = N(n).CLB.nx;


	if length(targetlatlon) > 1
		[~,~,tdis,tazm] = greatcircle(N(n).LAT_WGS84,N(n).LON_WGS84,targetlatlon(1),targetlatlon(2),2);
		azlim = tazm(1) + targetangle*[-1,1];
	else
		azlim = procazlim;
	end

	% computes theoretical tides (in nm/s2)
	if tidemode
		% request in UT + takes one day before and after the time window of data to allow time shift
		T = mktides(WO.PRGM_GOTIC2,tidemode,P.DATELIM-P.TZ/24+[-1,1],N(n).LAT_WGS84,N(n).LON_WGS84,N(n).ALTITUDE);
        T.t = T.t + P.TZ/24; % back to PROC's TZ
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
			%k1 = [];
			ke = [];
			if any(isnan(xlim))
				xlim = P.NOW - [1,0];
			end
			acqui = 0;
			tk = [];
			dk = nan(0,5);
		else
			%k1 = k(1);
			ke = k(end);
			if any(isnan(xlim))
				xlim = [tfirst(n),tlast(n)];
			end
			acqui = round(100*length(k)*N(n).ACQ_RATE/abs(t(k(end)) - N(n).LAST_DELAY - xlim(1)));
			[tk,dk] = treatsignal(t(k),d(k,:),P.GTABLE(r).DECIMATE,P);
		end

		etat = 0;
		for i = 1:nx
			if any(~isnan(d(k(t(k) >= xlim(2) - N(n).LAST_DELAY),i)))
				etat = etat + 1;
			end
		end
		etat = 100*etat/nx;

		if isscalar(zoomdays)
			zd = xlim(2) - [zoomdays,0];
		else
			zd = xlim(2) - [max(zoomdays(:)),min(zoomdays(:))];
		end
		[b,a] = butter(2,[1/18,1]/3600/.5);

		if tidemode && ~isempty(k)
			% adjusts phase and amplitude of tides
			tidefit = zeros(3,2);
			for c = 1:2
				% method: inverses both amplitude and time-shift after bandwidth filter (L2 norm)
				kr = find(~isnan(dk(:,c)));
				if ~isempty(kr)
					dd = filter(b,a,dk(kr,c) - mean(dk(kr,c)));
					%dd = linfilter(t - t(1),d(:,c),ceil(diff(minmax(t))/2)+1);
					f = @(x) rsum((dd - filter(b,a,interp1(T.t + x(1),T.d(:,c),tk(kr),'*linear')*x(2))).^2)/length(kr);
					tidefit(c,:) = fminsearch(f,[0,1],optimset('Display','off','MaxIter',50));
				end
				dk(:,3+c) = interp1(T.t + tidefit(c,1),T.d(:,c),tk,'*linear')*tidefit(c,2);
				fprintf('  --> adjusted tide component %d = x %g %+dh %02.0fm\n',c,tidefit(c,2),h2hms(24*tidefit(c,1),1));
			end
		else
			dk(:,4:5) = 0*dk(:,1:2);
		end

		fprintf('%s: computes jerk time series... ',wofun);

		x = dk(:,1) - dk(:,4);
		y = dk(:,2) - dk(:,5);
		ip = (mw:dt:length(x))';
		bx = zeros(length(ip),2);
		by = zeros(length(ip),2);

		ii = 1;
		for i = ip'
			k = i + 1 + (-mw:-1);
			kk = k(~isnan(x(k)));
			bx(ii,:) = polyfit((tk(kk)-tk(1))*86400,x(kk),1);
			kk = k(~isnan(y(k)));
			by(ii,:) = polyfit((tk(kk)-tk(1))*86400,y(kk),1);
			ii = ii + 1;
		end
		[jth,jerk] = cart2pol(bx(:,1),by(:,1));
		jth = mod(90 - jth*180/pi + 360,360); % azimuth in [0,360] �N range

		if strcmp(P.JERK_THRESHOLD_MODE,'auto')
			tf = str2double(P.JERK_THRESHOLD_TIDES_FACTOR);
			threshold_level1 = max([max(abs(diff(d(:,3)))),max(abs(diff(dk(:,4))))])/tf;
		end
		fprintf('done (threshold_level1 = %g).\n',threshold_level1);


		% title and status
		P.GTABLE(r).GTITLE = gtitle(stitle,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [P.NOW,etat,acqui];
		N(n).STATUS = etat;
		N(n).ACQUIS = acqui;
		P.GTABLE(r).INFOS = {''};

		% loop for each data component
		for i = 1:2
			subplot(9,1,(i-1)*2 + (1:2)); extaxes(gca,[.07,.03])
			if ~isempty(k)
				plot(tk,dk(:,i),'-','LineWidth',P.GTABLE(r).LINEWIDTH,'Color',scolor(1))
				hold on
				plot(tk,dk(:,i+3) + rmean(dk(:,i)),'-','LineWidth',P.GTABLE(r).LINEWIDTH/2,'Color',scolor(2))
				plot(tk,dk(:,i) - dk(:,i+3),'-','LineWidth',P.GTABLE(r).LINEWIDTH,'Color',scolor(3))
				hold off
			end
            ylim = minmax(dk(:,i));
			set(gca,'XLim',xlim,'YLim',ylim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s (%s)',C.nm{i},C.un{i}))
			if isempty(d) || all(isnan(d(k,i)))
				nodata(xlim)
			end
            if i==1
                topt = {'HorizontalAlignment','center','FontWeight','bold'};
                text(xlim(1)+diff(xlim)/4,ylim(2),{'original data',''},'Color',scolor(1),topt{:})
                text(xlim(1)+diff(xlim)/2,ylim(2),{'tide model',''},'Color',scolor(2),topt{:})
                text(xlim(1)+diff(xlim)*3/4,ylim(2),{'corrected data',''},'Color',scolor(3),topt{:})
            end
		end

		% additional 3rd channel (LKI, LDI, ...)
		subplot(9,1,5); extaxes(gca,[.07,.03])
		plot(tk,mavr(dk(:,3),chan_smooth(c)),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(4))
		set(gca,'XLim',xlim,'FontSize',8)
		ylim = minmax(dk(:,3));
		if any(isnan(ylim))
			nodata(xlim);
		else
			set(gca,'YLim',ylim)
		end
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('%s (%s)',C.nm{3},C.un{3}))

		% jerk
		subplot(9,1,6:7); extaxes(gca,[.07,.03])
		plot(xlim,repmat(threshold_level2,1,2),'--','Color',rgb_level2,'LineWidth',1)
		hold on
		plot(xlim,repmat(threshold_level1,1,2),'--','Color',rgb_level1,'LineWidth',1)
		plot(tk(ip),jerk,'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',2/3+scolor(1)/3)
        ka = (insector(jth,azlim) | insector(jth-180,azlim));
        tka = tk(ip);
        tka(~ka) = NaN; % set NaN for points outside valid azimuth
		plot(tka,jerk,'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(1))
		ylim = get(gca,'YLim');
		plot(zd,ylim(2)*([1,1]+.03),'-','LineWidth',2,'Color',.7*ones(1,3),'Clipping','off') % zoom interval
		hold off
		set(gca,'XLim',xlim,'Ylim',ylim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('Jerk Aamplitude (nm/s%s)',cb3))
		tlabel(xlim,P.TZ)

		% jerk zoom
		subplot(9,1,8:9); extaxes(gca,[.07,.03])
		pos = get(gca,'Position');
		set(gca,'Position',[.4,pos(2)-.02,pos(3) - .4 + pos(1),pos(4)]);
		kz = find(isinto(tk(ip),zd));
		if ~isempty(kz)
			plot(zd,repmat(threshold_level2,1,2),'--','Color',rgb_level2,'LineWidth',1)
			hold on
			plot(zd,repmat(threshold_level1,1,2),'--','Color',rgb_level1,'LineWidth',1)
			plot(tk(ip(kz)),jerk(kz),'-','LineWidth',P.GTABLE(r).MARKERSIZE/3,'Color',2/3+scolor(1)/3)
            ka = (insector(jth(kz),azlim) | insector(jth(kz)-180,azlim));
            tka = tk(ip(kz));
            tka(~ka) = NaN; % set NaN for points outside valid azimuth
            plot(tka,jerk(kz),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(1))
			hold off
			set(gca,'YLim',[0,max(str2double(P.JERK_ZOOM_MINYLIM_MS3)*1e9,max(jerk(kz)))])
		end
		set(gca,'XLim',zd,'FontSize',8);
		%datetick2('x','mm/dd HH:MM')
		datetick2('x',-1)
		ylabel(sprintf('Jerk Amplitude - Zoom (nm/s%s)',cb3))
		tlabel(zd,P.TZ)

		% plot alerts in background
		ka2 = ip(jerk<threshold_max & jerk>threshold_level2 & (insector(jth,azlim) | insector(jth-180,azlim)));
		if ~isempty(ka2)
			plotevt(tk(ka2),'Color',rgb_level2,'LineWidth',2);
		end
		ka2z = ka2(isinto(tk(ka2),zd));
		if ~isempty(ka2z)
			sal2 = sprintf('{\\bf%s} (total {\\bf%1.0f} mn)',datestr(tk(ka2z(end)),'dd-mmm-yyyy HH:MM'),length(ka2z)*dt/60);
		else
			sal2 = 'none';
		end
		ka1 = ip(jerk<threshold_max & jerk>threshold_level1 & jerk<threshold_level2 & (insector(jth,azlim) | insector(jth-180,azlim)));
		if ~isempty(ka1)
			plotevt(tk(ka1),'Color',rgb_level1,'LineWidth',2);
		end
		ka1z = ka1(isinto(tk(ka1),zd));
		if ~isempty(ka1z)
			sal1 = sprintf('{\\bf%s} (total {\\bf%1.0f} mn)',datestr(tk(ka1z(end)),'dd-mmm-yyyy HH:MM'),length(ka1z)*dt/60);
		else
			sal1 = 'none';
		end

		% jerk polar
		axes('position',[pos(1),pos(2)-.02,.25,pos(4)]);
		circle = exp(1j*linspace(0,2*pi));
		plot(circle*threshold_level1,'--','Color',rgb_level1,'LineWidth',1)
		hold on
		plot(circle*threshold_level2,'--','Color',rgb_level2,'LineWidth',1)
		if ~isempty(kz)
			set(gca,'XLim',[min(min(bx(kz,1)),-threshold_level2),max(max(bx(kz,1)),threshold_level2)], ...
				'YLim',[min(min(by(kz,1)),-threshold_level2),max(max(by(kz,1)),threshold_level2)], ...
				'FontSize',8);
		else
			set(gca,'XLim',[-1,1]*threshold_level2,'YLim',[-1,1]*threshold_level2,'FontSize',8);
		end
		[xlim,ylim] = equalaxis;
		if all(isfinite(azlim))
			az = (90 - azlim)*pi/180;
			[azx,azy] = pol2cart([az(1)+pi,az(1),mean(az),az(2),az(2)+pi,mean(az)+pi],max(abs([xlim,ylim]))*2);
			clip = polyclip([azx',azy'],[xlim([1,2,2,1])',ylim([1,1,2,2])']);
			patch(clip(:,1),clip(:,2),-ones(1,length(clip)),'k','FaceColor',rgb_level2,'EdgeColor','none','Clipping','on');
			plot(azx([3,6]),azy([3,6]),'-.k')
			plot(azx([1,2]),azy([1,2]),'-','Color',.8*ones(1,3),'LineWidth',1)
			plot(azx([4,5]),azy([4,5]),'-','Color',.8*ones(1,3),'LineWidth',1)
			[azx,azy] = pol2cart([az(1)+pi,linspace(az(1),az(2)),linspace(az(2),az(1))+pi],threshold_level2);
			patch(azx,azy,-.9*ones(size(azx)),'k','FaceColor',rgb_level1,'EdgeColor','none','Clipping','on');
			[azx,azy] = pol2cart([az(1)+pi,linspace(az(1),az(2)),linspace(az(2),az(1))+pi],threshold_level1);
			patch(azx,azy,-.8*ones(size(azx)),'k','FaceColor',.9*ones(1,3),'EdgeColor','none','Clipping','on');
		end
		plot(bx(kz,1),by(kz,1),'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',2/3+scolor(1)/3)
        bxa = bx(kz,1);
        bya = by(kz,1);
        bxa(~ka) = NaN; % set NaN for points outside valid azimuth
        bya(~ka) = NaN;
		plot(bxa,bya,'-','LineWidth',P.GTABLE(r).MARKERSIZE/5,'Color',scolor(1))
		hold off
		ylabel(sprintf('Northern jerk (nm/s%s)',cb3))
		xlabel(sprintf('Eastern jerk (nm/s%s)',cb3))
		if length(targetlatlon) > 1
			title(sprintf('Target: {\\bf %g km}, {\\bfN%1.0f \\pm %g%s}',roundsd(tdis(2),2),mod(tazm(1)+360,360),targetangle,cba))
		end

		if ~isempty(k)
			P.GTABLE(r).INFOS = {sprintf('Last data: {\\bf %s} {\\it %+d}',datestr(t(ke)),P.TZ)};
			if tidemode
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{ ...
					sprintf('   Tide predict mode: {\\bf %s}',tidemodes{tidemode}), ...
					sprintf('   E-W tide: {\\bf\\times %1.4f, \\Delta{t} = %+dh %02.0fm}', ...
						tidefit(1,2),h2hms(24*tidefit(1,1),1)), ...
					sprintf('   N-S tide: {\\bf\\times %1.4f, \\Delta{t} = %+dh %02.0fm}', ...
						tidefit(2,2),h2hms(24*tidefit(2,1),1)), ...
				}];
			else
				P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{ ...
					sprintf('   Tide predict mode: {\\bf none}'), ...
					sprintf('   E-W tide: {\\bf none}'), ...
					sprintf('   N-S tide: {\\bf none}'), ...
				}];
			end
			P.GTABLE(r).INFOS = [P.GTABLE(r).INFOS{:},{ ...
				'JERK parameters:', ...
				sprintf('   Sampling: {\\bf %g s}',dt), ...
				sprintf('   Slope window: {\\bf %g s}',mw), ...
				sprintf('   Azimuth interval: {\\bfN %g to N%g}',round(mod(azlim+360,360))), ...
				' ', ...
				sprintf('Last JERK alert (in zoom window):'), ...
				sprintf('   Level1: %s',sal1),sprintf('   Level2: %s',sal2), ' ', ...
			}];
		end

		% makes graph
		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
		close

		if ~isempty(k)
			talarm = tk(ip);
			alarm = zeros(size(jerk));
			alarm(jerk<threshold_max & jerk>threshold_level1 & (insector(jth,azlim) | insector(jth-180,azlim))) = 1;
			alarm(jerk<threshold_max & jerk>threshold_level2 & (insector(jth,azlim) | insector(jth-180,azlim))) = 2;

			% exports data
			if isok(P.GTABLE(r),'EXPORTS')
				E.t = talarm;
				E.d = [dk(ip,:),jerk,jth,alarm];
				E.header = { ...
					sprintf('%s(%s)',C.nm{1},C.un{1}), ...
					sprintf('%s(%s)',C.nm{2},C.un{2}), ...
					sprintf('%s(%s)',C.nm{3},C.un{3}), ...
					sprintf('EW_Tide(nm/s%s)',cb2), ...
					sprintf('NS_Tide(nm/s%s)',cb2), ...
					sprintf('Jerk(nm/s%s)',cb3), ...
					sprintf('Azimuth(%sN)',cba),'Alarm'};
				E.title = sprintf('%s {%s}',stitle,upper(N(n).ID));
				E.fmt = [repmat({'%f'},1,7),{'%g'}];
				mkexport(WO,sprintf('%s_%s',N(n).ID,P.GTABLE(r).TIMESCALE),E,P,r,N(n));
			end

			% email for alerts
			if ~P.REQUEST && isfield(P,'NOTIFY_EVENT') && ~isempty(P.NOTIFY_EVENT)
				falert = sprintf('%s/alertstatus',P.OUTDIR);
				if exist(falert,'file')
					alertlast = load(falert,'-ascii');
				else
					alertlast = [talarm(end),0];
				end
				al = [talarm(end),alarm(end)];
				alert = 0;
				alertlevel = { ...
					'NORMAL', ...
					'WARNING', ...
					'ALERT', ...
					};
				alertstatus = '';
				switch al(2)
				case 0
					switch alertlast(2)
					case 1
						alertstatus = 'end of warning';
						alert = 1;
					case 2
						alertstatus = 'end of alert';
						alert = 1;
					end
				case 1
					switch alertlast(2)
					case 0
						alertstatus = 'start';
						alert = 1;
					case 2
						alertstatus = 'end of alert';
						alert = 1;
					end
				case 2
					switch alertlast(2)
					case {0,1}
						alertstatus = 'start';
						alert = 1;
					end
				end
				save(falert,'al','-ascii','-double');
				if alert
					% root URL
					if isfield(WO,'ROOT_URL')
						url = WO.ROOT_URL;
					else
						url = 'http://webobs';
					end

					% makes a comprehensive text message for email notification
					msg = sprintf('JERK %s: status %s (%s)',N(n).ALIAS,alertlevel{al(2)+1},alertstatus);

					f = sprintf('%s/mail.txt',P.OUTDIR);
					fid = fopen(f,'wt');
					fprintf(fid,'\n\n%s {%s}\n',P.NAME,P.SELFREF);
					fprintf(fid,'%s: %s\n\n',N(n).ALIAS,N(n).NAME);
					fprintf(fid,'Current status\n\t%s: %s\n',datestr(al(1)),alertlevel{al(2)+1});
					fprintf(fid,'Previous status\n\t%s: %s\n',datestr(alertlast(1)),alertlevel{alertlast(2)+1});
					fprintf(fid,'\n\n');
					fprintf(fid,'Real-time graph: %s/cgi-bin/showOUTG.pl?grid=%s&g=%s\n\n',url,P.SELFREF,lower(N(n).ID));
                    fprintf(fid,'Screenshot attached:\n\n');
					fclose(fid);

					notify(WO,P.NOTIFY_EVENT,'!',sprintf('file=%s subject=%s',f,msg));
				end
			end
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
