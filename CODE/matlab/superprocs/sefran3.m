function sefran3(name,fdate)
%SEFRAN3 Continuous seismogram using SeedLink/ArcLink data request
%
%	SEFRAN3 by itself creates/updates seismogram images in real time:
%		- creates all 1-minute images for selected channels
%		- updates/creates 1-hour thumbnails
%		- creates channel names image
%		- applies optional broom-wagon to fill gaps
%
%	SEFRAN3(NAME) uses NAME.conf configuration file. Default is given by
%	WO.SEFRAN3_DEFAULT_NAME variable. See comments in this conf file for an
%	overall	functionnality.
%
%	SEFRAN3(NAME,DATE) with DATE = 'yyyy[mm[dd[HH[MM]]]], forces
%	creation of all minute images corresponding to this date. Examples:
%		sefran3('SEFRAN3','20131225')
%		sefran3('SEFRAN3','201312251200')
%
%
%	Authors: Francois Beauducel, Didier Lafon, Alexis Bosson, Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2012-02-09 in Paris, France (based on previous versions leg/sefran.m, 2002 and leg/sefran2.m, 2007)
%	Updated: 2018-11-09

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- Reads and imports Sefran3 parameters
if nargin < 1
	name = WO.SEFRAN3_DEFAULT_NAME;
end
SEFRAN3 = readcfg(WO,sprintf('/etc/webobs.d/%s.conf',name));

% determines mode (real-time or force) and creates temporary path
if nargin < 2
	force = 0;
	ptmp = field2str(SEFRAN3,'PATH_TMP_WEBOBS','/tmp/sefran3'); % temporary path
else
	force = 1;
	ptmp = sprintf('%s/force',field2str(SEFRAN3,'PATH_TMP_WEBOBS','/tmp/sefran3')); % different temporary path to avoid (too much) conflicts with real-time
end
wosystem(sprintf('mkdir -p %s',ptmp),SEFRAN3);

% runtime parameters
beat = field2num(SEFRAN3,'BEAT',2);
update = field2num(SEFRAN3,'UPDATE_HOURS',24);
minruntime = field2num(SEFRAN3,'MIN_RUNTIME_SECONDS',600)/86400; % minimum runtime (in days)
maximages = field2num(SEFRAN3,'MAX_IMAGES_IN_RUN',10);

% SeedLink and ArcLink servers
fmsd = sprintf('%s/mseed.tmp',ptmp); % temporary miniseed file
rtdelay = field2num(SEFRAN3,'LATENCY_SECONDS',field2num(SEFRAN3,'SEEDLINK_DELAY_SECONDS',5)); % Real-time latency delay (in seconds)
rtmax = field2num(SEFRAN3,'ARCLINK_DELAY_HOURS',12); % Delay needed for  request, if possible (in hours)
rtsource = field2str(SEFRAN3,'SEEDLINK_SERVER');
rtformat = 'seedlink';
arcsource = field2str(SEFRAN3,'ARCLINK_SERVER','');
arcformat = 'arclink';

% Data format
datasource = field2str(SEFRAN3,'DATASOURCE');
if ~isempty(datasource)
	x = split(datasource,';');
	if length(x) >= 2
		[rtformat,rtsource,arcformat,arcsource] = readcombined(x);
		if length(x) > 2
			rtmax = str2double(x{3});
		end
	else
		[arcformat,arcsource] = readcombined(x);
		rtmax = 0;
	end
end

clean_overlaps = field2num(SEFRAN3,'CLEAN_OVERLAPS',0);

% Broomwagon
broomwagon = isok(SEFRAN3,'BROOMWAGON_ACTIVE'); % Broom-wagon activation
bwdelay = field2num(SEFRAN3,'BROOMWAGON_DELAY_HOURS',6)/24; % Broom-wagon delay (in days)
bwup = field2num(SEFRAN3,'BROOMWAGON_UPDATE_HOURS',1); % Broom-wagon update window (in hours)
bwmdead = field2num(SEFRAN3,'BROOMWAGON_MAX_DEAD_CHANNELS',0); % Broom-wagon maximum dead channels tolerance
bwmgap = field2num(SEFRAN3,'BROOMWAGON_MAX_GAP_FACTOR',0); % Broom-wagon maximum gap tolerance (relative 0-1)

% graphical parameters
vits = field2num(SEFRAN3,'VALUE_SPEED',1.2); % Sefran paper speed (in inches/minute)
vitsh = field2num(SEFRAN3,'VALUE_SPEED_HIGH',4.8); % Sefran paper speed high mode (in inches/minute)
ppi = field2num(SEFRAN3,'VALUE_PPI',100); % image resolution (in pixels/inch)
%oversamp = sstr2num(SEFRAN3.PRINT_OVERSAMPLING_FACTOR); % image oversampling when print in png
hip = field2num(SEFRAN3,'HEIGHT_INCH',7.8); % image height (in inches)
hsig = field2num(SEFRAN3,'INTERTRACE',.8); % normalized signal intertrace (<1 = overlap of traces)
lw = field2num(SEFRAN3,'TRACE_LINEWIDTH',1); % signal trace linewidth
whour = field2num(SEFRAN3,'HOURLY_WIDTH',900); % hourly thumbnail image width (in pixels)
hhour = field2num(SEFRAN3,'HOURLY_HEIGHT',90); % hourly thumbnail image height (in pixels)
wlh = field2num(SEFRAN3,'LASTHOUR_WIDTH',320); % last hour thumbnail width (in pixels)
labeltop = field2num(SEFRAN3,'LABEL_TOP_HEIGHT',23)/ppi; % image top label height (in inches)
labelbottom = field2num(SEFRAN3,'LABEL_BOTTOM_HEIGHT',55)/ppi; % image bottom label height (in inches)
xtickinterval = field2num(SEFRAN3,'XTICK_INTERVAL_SECONDS',1); % Xtick interval (seconds)
xticklabel = field2num(SEFRAN3,'XTICK_LABEL_INTERVAL_SECONDS',10); % Xtick label interval (seconds)
gamma = field2num(SEFRAN3,'HOURLY_CONVERT_GAMMA',.4); % gamma factor for hourly reshape (to preserve contrast)
apos = [0,labelbottom/hip,1,(hip - labeltop - labelbottom)/hip]; % axe position in figure: uses 100%-width and 90%-height (for labels)
gris1 = .8*[1,1,1]; % light gray
%gris2 = .2*[1,1,1]; % dark gray
if isfield(WO,'CONVERT_COLORSPACE')
        convert = sprintf('%s %s',WO.PRGM_CONVERT,WO.CONVERT_COLORSPACE);
else
        convert = sprintf('%s -colorspace sRGB',WO.PRGM_CONVERT);
end
daymn = 1/1440; % 1 minute (in days)

% imports SEFRAN3 channel parameters
fid = fopen(SEFRAN3.CHANNEL_CONF,'rt');
C = textscan(fid,'%q%q%q%q%q%q%*[^\n]','CommentStyle','#');
fclose(fid);
% C{1} = channel name (alias)
% C{2} = channel stream
sfr = C{2};
nchan = length(sfr);
% C{3} = calibration factor (numeric)
% C{4} = filter: offset value (in counts) or 'median','trend','spN','lpbuN,F','hpbuN,F','bpbuN,FL,FH'
% C{5} = peak-to-peak amplitude (numeric)
% C{6} = RGB color string (hexa form #RRGGBB)
scol = htm2rgb(C{6});

% get time zone of the server
tzserver = gettz/24;

% initial start (local time)
tstart = now;
nrun = 1;

% global loop: will end after minruntime or force method
while (~force && (now - tstart) < minruntime) || (force && nrun < 2)

	% current time from server
	tnow = now - tzserver;

	fprintf('=== [%s]: run %d starts on %s TU ===\n',name,nrun,datestr(tnow));


	if force == 0
		% list of minutes in the last SEFRAN3.UPDATE_HOURS
		mlist = (floor(tnow*1440 - 1 - rtdelay/60) - (0:update*60))*daymn;
		% appends broom-wagon interval(s) if active
		if broomwagon
			for bwd = sort(reshape(bwdelay,1,[]))
				mlist = sort(unique(cat(2,mlist,(floor((tnow - bwd)*1440 - 1) - (0:bwup*60))*daymn)),'descend');
			end
		end
	else
		mlist = fdate2mlist(fdate);
	end
	if isok(SEFRAN3,'DEBUG')
		fprintf('%s: minutes to process:\n',wofun);
		disp(datestr(mlist))
	end

	mdone = zeros(size(mlist));
	% loop on each minute of the list (last SEFRAN3.UPDATE_HOURS + broom-wagon intervals)
	for m = 1:length(mlist)
		t0 = mlist(m);
		t1 = t0 + daymn;
		tv = datevec(t0);
		pdat = sprintf('%s/%4d/%4d%02d%02d',SEFRAN3.ROOT,tv(1),tv(1:3));
		f = sprintf('%s/%s/%4d%02d%02d%02d%02d%02d',pdat,SEFRAN3.PATH_IMAGES_MINUTE,tv);
		fpng = sprintf('%s.png',f);
		fpng_high = sprintf('%s_high.png',f);

		% checks images to activate the broom-wagon
		bw = 0;
		% first condition: data time (t1) is in the bw time window(s)
		for bwd = sort(reshape(bwdelay,1,[]),'descend')
			if bw == 0
				if broomwagon && t1 <= (tnow - bwd) && t1 >= (tnow - bwd - bwup/24) && (force || length(find(mdone)) < maximages)
					if exist(fpng,'file')
						age = datenum(tv) - t1;
						% second condition: difference between image's timestamp (tpng) and data time (t1) is less than bw delay
						% -> tpng may be much recent than t1 when the image has been made afterward (bw or gap filling)
						if (age) <= bwd
							% retrieves PNG tag "sampling"
							[~,w] = wosystem(sprintf('%s -format %%[sefran3:sampling] %s;sleep 0.5',WO.PRGM_IDENTIFY,fpng),SEFRAN3);
							ch = str2vec(w);
							ch(isnan(ch)) = 0;
							ch_gaps = 1 - ch;
							gaps = length(find(ch_gaps > bwmgap));
							% third condition: channels over max. gap not over max. "dead channels"
							if gaps > bwmdead 
								bw = 1;
								fprintf('%s: Broom wagon will pick up "%s" (%d channels over %g%% gap)...\n',wofun,fpng,gaps,100*bwmgap);
						end
					end
				end
			end
		end
	end

		if force || ((~exist(fpng,'file') || bw) && length(find(mdone)) < maximages)
			wosystem(sprintf('mkdir -p %s/%s %s/%s %s/%s',pdat,SEFRAN3.PATH_IMAGES_MINUTE,pdat,SEFRAN3.PATH_IMAGES_HOUR,pdat,SEFRAN3.PATH_IMAGES_HEADER),SEFRAN3);

			% delete previous temporary file
			wosystem(sprintf('rm -f %s',fmsd),SEFRAN3);

			if (tnow - t0)*24 < rtmax
				% real-time data
				readdata(WO,SEFRAN3,rtformat,rtsource,t0,C,ptmp,fmsd)
			else
				% archived data
				readdata(WO,SEFRAN3,arcformat,arcsource,t0,C,ptmp,fmsd)
			end

			F = dir(fmsd);
			if ~isempty(F) && F.bytes > 0
				% --- loads the miniseed file
				[S,I] = rdmseed(fmsd);
				channel_list = cellstr(char(I.ChannelFullName));

				% --- makes the 1-minute image
				figure, clf
				fsxy = [vits,hip]; % image size (in inches)
				set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy],'Color','w')
				axes('Position',apos); % axe uses 100% width and 83% height (for labels)
				xlim = [0,daymn]; % X-axe is time (in days)
				ylim = [-nchan*hsig,0]; % Y-axe is amplitude (normalized)
				% date and time labels
				plot(xlim,repmat(ylim,[2,1]),'-','Color','k','LineWidth',1) % horizontal axes
				hold on
				axis off
				th0 = round(t0*24)/24 - t0; % closest rounded hour time
				if abs(th0) <= daymn
					plot(repmat(th0,[1,2]),ylim,'-','Color',gris1,'LineWidth',3)
				else
					plot(repmat(xlim,[2,1]),ylim,'--','Color',gris1,'LineWidth',1) % minutes vertical limits
				end
				if bw || force
					if bw, s = 'BROOM WAGON'; else s = 'FORCED'; end
					text(xlim(2)/2,0,{s,''}, ...
						'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7,'FontWeight','bold','Color',.8*[1,1,1],'Interpreter','none')
				end
				text(xlim(2)/2,0,datestr(t0,'yyyy-mm-dd HH:MM'), ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'Color','k','Interpreter','none')
				text(xlim,[0,0],{'|','|'}, ...
					'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9,'Fontweight','Bold','Color','k')
				text(xlim,repmat(ylim(1),[1,2]),{datestr(t0,'|\nHH:MM\nyyyy-mm-dd');datestr(t1,'|\nHH:MM\nyyyy-mm-dd')}, ...
					'HorizontalAlignment','center','VerticalAlignment','top','FontSize',9,'Fontweight','Bold','Color','k')
				if xtickinterval
					xt = (0:xtickinterval:60)/86400;
					plot(repmat(xt,[2,1]),ylim(1)-repmat([0;.01*ylim(1)],[1,size(xt,2)]),'-','Color','k','LineWidth',.2);
					plot(repmat(xt,[2,1]),repmat([0;.01*ylim(1)],[1,size(xt,2)]),'-','Color','k','LineWidth',.2);
					xticksl = (xticklabel:xticklabel:59);
					xt = xticksl/86400;
					plot(repmat(xt,[2,1]),ylim(1)-repmat([0;.01*ylim(1)],[1,size(xt,2)]),'-k','LineWidth',1);
					plot(repmat(xt,[2,1]),repmat([0;.01*ylim(1)],[1,size(xt,2)]),'-k','LineWidth',1);
					text(xt,repmat(ylim(1),[1,size(xt,2)]),cellstr(num2str(xticksl')), ...
						'HorizontalAlignment','center','VerticalAlignment','top','FontSize',7,'Fontweight','Bold','Color','k');
				end
				%chan_drawn = 0;
				tag_stat_rate = repmat({''},[1,nchan]);
				tag_stat_samp = repmat({''},[1,nchan]);
				tag_stat_medi = repmat({''},[1,nchan]);
				tag_stat_offs = repmat({''},[1,nchan]);
				tag_stat_drms = repmat({''},[1,nchan]);
				tag_stat_asym = repmat({''},[1,nchan]);
				for n = 1:nchan
					c = textscan(sfr{n},'%s','Delimiter','.:'); % splits Network, Station, LocId and Channel codes
					k = find(~cellfun('isempty',regexp(channel_list,sprintf('%s.*%s.*%s.*%s',c{1}{1},c{1}{2},c{1}{3},c{1}{4}))));
					%FB-was: k = find(~cellfun('isempty',regexp(channel_list,sprintf('%s:%s.*%s',c{1}{1},c{1}{2},c{1}{4}))));
					if ~isempty(k)
						%chan_drawn = chan_drawn + 1;
						kk = I(k).XBlockIndex;
						channel_data = cat(1,S(kk).d);
						channel_time = cat(1,S(kk).t);
						if clean_overlaps
							[channel_time,un] = unique(channel_time);
							channel_data = channel_data(un);
						end
						channel_rate = S(kk(1)).SampleRate; % supposes sample rate is constant (looks first block)
						% statistics
						ch_median = median(channel_data);
						ch_minmax = max(channel_data) - min(channel_data);
						ch_offset = ch_median/ch_minmax;
						ch_asym = (std(channel_data(channel_data>ch_median)) - std(channel_data(channel_data<ch_median)))/ch_minmax;
						ch_drms = std(diff(channel_data));
						%FB-was: ch_samp = length(find(channel_time >= t0 & channel_time < (t0 + xlim(2))))/(60*channel_rate);
						ch_samp = length(find(channel_time >= t0 & channel_time < t1))/(60*channel_rate);

						% filtering
						ds = filtsignal(channel_time,channel_data,channel_rate,C{4}{n});

						% calibrates and normalizes signal
						ds = ds/str2double(C{3}{n})/str2double(C{5}{n});

						% clips signal (forces saturation)
						ds = min(ds,.5);
						ds = max(ds,-.5);

						% ... finally plots the signal
						plotregsamp(channel_time - t0,ds - (n - .5)*hsig,'LineWidth',lw,'Color',scol(n,:))
					else
						ch_median = NaN;
						ch_offset = NaN;
						ch_drms = NaN;
						ch_asym = NaN;
						ch_samp = 0;
						channel_rate = NaN;
					end
					tag_stat_rate{n} = sprintf('%1.5f',channel_rate);
					tag_stat_samp{n} = sprintf('%1.5f',ch_samp);
					tag_stat_medi{n} = sprintf('%1.5f',ch_median);
					tag_stat_offs{n} = sprintf('%1.5f',ch_offset);
					tag_stat_drms{n} = sprintf('%1.5f',ch_drms);
					tag_stat_asym{n} = sprintf('%1.5f',ch_asym);
				end

				hold off
				set(gca,'XLim',xlim,'YLim',ylim,'XTick',[],'YTick',[],'XLimMode','manual','YLimMode','manual');

				% PNG tag properties
				tag = [ ...
					sprintf('-set sefran3:ppi "%s" ',SEFRAN3.VALUE_PPI), ...
					sprintf('-set sefran3:intertrace "%s" ',SEFRAN3.INTERTRACE), ...
					sprintf('-set sefran3:top "%s" ',SEFRAN3.LABEL_TOP_HEIGHT), ...
					sprintf('-set sefran3:bottom "%s" ',SEFRAN3.LABEL_BOTTOM_HEIGHT), ...
					sprintf('-set sefran3:streams "%s" ',strjoin(sfr',',')), ...
					sprintf('-set sefran3:gains "%s" ',strjoin(C{3}',',')), ...
					sprintf('-set sefran3:amplitudes "%s" ',strjoin(C{5}',',')), ...
					sprintf('-set sefran3:rate "%s" ',strjoin(tag_stat_rate,',')), ...
					sprintf('-set sefran3:sampling "%s" ',strjoin(tag_stat_samp,',')), ...
					sprintf('-set sefran3:median "%s" ',strjoin(tag_stat_medi,',')), ...
					sprintf('-set sefran3:offset "%s" ',strjoin(tag_stat_offs,',')), ...
					sprintf('-set sefran3:drms "%s" ',strjoin(tag_stat_drms,',')), ...
					sprintf('-set sefran3:asymetry "%s" ',strjoin(tag_stat_asym,',')), ...
				];

				% prints image
				fprintf('%s: creating %s ... ',wofun,fpng);
				ftmp2 = sprintf('%s/sefran.eps',ptmp);
				print(1,'-depsc','-painters','-loose',ftmp2)
				wosystem(sprintf('%s %s -set sefran3:speed "%g" -density %g %s %s',convert,tag,vits,ppi,ftmp2,fpng),SEFRAN3);
				fprintf('done.\n');

				% test: print svg image
				%ftmp3 = sprintf('%s/sefran.svg',ptmp);
				%plot2svg(ftmp3)
				%fsvg = sprintf('%s.svg',f);
				%system(sprintf('mv %s %s.svg',ftmp3,f));
				%fprintf('%s: %s created.\n',wofun,fsvg);

				% prints high-speed image (doesn't replot but modifies the paper size...)
				if vitsh
					fprintf('%s: creating %s ... ',wofun,fpng_high);
					fsxy = [vitsh,hip]; % image size (in inches)
					set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy],'Color','w')
					print(1,'-depsc','-painters','-loose',ftmp2)
					wosystem(sprintf('%s %s -set sefran3:speed "%g" -density %g %s %s',convert,tag,vitsh,ppi,ftmp2,fpng_high),SEFRAN3);
					fprintf('done.\n');
				end
				close
				mdone(m) = 1;
			else
				fprintf('%s: ** WARNING ** no miniSEED file produced at %s. Abort.\n',wofun,datestr(t0));
			end
		end
	end

	% makes channel names header image (one per hour, if needed)
	hdone = unique(floor(mlist(mdone==1)*24)/24); % list of hours containing new or updated images
	flag = 0;
	%FB-was: voies = 'voies.png';
	voies = 'voies';
	for h = 1:length(hdone)
		tv = datevec(hdone(h));
		ftmp = sprintf('%s/%s.eps',ptmp,voies);
		fpng = sprintf('%s/%4d/%4d%02d%02d/%s/%4d%02d%02d%02d_%s.png',SEFRAN3.ROOT,tv(1),tv(1:3),SEFRAN3.PATH_IMAGES_HEADER,tv(1:4),voies);
		if ~exist(fpng,'file')
			if ~flag
				figure, clf
				fsxy = [1,hip]; % image size (in inches)
				set(gcf,'PaperSize',fsxy,'PaperUnits','inches','PaperPosition',[0,0,fsxy],'Color','w')
				orient portrait
				axes('Position',apos);
				xlim = [0,1]; % X-axe
				ylim = [-nchan*hsig,0]; % Y-axe is amplitude (normalized)
				set(gca,'XLim',xlim,'YLim',ylim)
				hold on
				for n = 1:nchan
					yl = -(n - .5)*hsig;
					plot(1 - [.1,0],yl + [0,0],'-','Color',scol(n,:))
					text(.5,yl,sprintf('%s',deblank(C{1}{n})),'FontSize',14,'FontWeight','bold','Color',scol(n,:), ...
						'HorizontalAlignment','center','VerticalAlignment','bottom');
					text(.5,yl,sprintf('%s m/s',C{5}{n}),'FontSize',7,'Color',scol(n,:), ...
						'HorizontalAlignment','center','VerticalAlignment','middle');
					text(.5,yl,sprintf('filter %s',C{4}{n}),'FontSize',7,'Color',scol(n,:), ...
						'HorizontalAlignment','center','VerticalAlignment','top');
				end
				hold off
				axis off
				fprintf('%s: creating %s ... ',wofun,fpng);
				print(1,'-depsc','-painters','-loose',ftmp)
				wosystem(sprintf('%s -density %g %s %s',convert,ppi,ftmp,fpng),SEFRAN3);
				fprintf('done.\n');
				close
				flag = 1;
			else
				fprintf('%s: updating %s (channels banner) ... ',wofun,fpng);
				wosystem(sprintf('%s -density %g %s %s',convert,ppi,ftmp,fpng),SEFRAN3);
				fprintf('done.\n');
			end
		end

		% makes hourly images
		pdat = sprintf('%s/%4d/%4d%02d%02d',SEFRAN3.ROOT,tv(1),tv(1:3));
		ftmp = sprintf('%s/h.png',ptmp);
		f = sprintf('%s/%s/%4d%02d%02d%02d.jpg',pdat,SEFRAN3.PATH_IMAGES_HOUR,tv(1:4));
		wosystem(sprintf('rm -f %s',ftmp),SEFRAN3);
		%[FB-was:] [s,w] = wosystem(sprintf('ls %s/%s/%4d%02d%02d%02d????.png | wc -l',pdat,SEFRAN3.PATH_IMAGES_MINUTE,tv(1:4)),SEFRAN3);
		%[FB-was:] if s==0 && ~isempty(w)
		D = dir(sprintf('%s/%s/%4d%02d%02d%02d*00.png',pdat,SEFRAN3.PATH_IMAGES_MINUTE,tv(1:4)));
		nimg = length(D);
		if nimg > 0
			fprintf('%s: updating %s (hourly thumbnail) ... ',wofun,f);
			wosystem(sprintf('%s -depth 8 %s/%s/%4d%02d%02d%02d??00.png +append %s', ...
				convert,pdat,SEFRAN3.PATH_IMAGES_MINUTE,tv(1:4),ftmp),SEFRAN3);
			% reduces concatenated minutes image to single hourly thumbnail
			% (the formula estimates the number of minutes, thus leads to "whour"-width for complete hour,
			% and relatively smaller for real-time)
			wosystem(sprintf('%s %s -resize %dx%d\\! -gamma %g %s', ...
				convert,ftmp,round(whour*nimg/60),hhour,gamma,f),SEFRAN3);
			fprintf('done.\n');
		end
	end

	% makes last hour thumbnail
	%if force || (~isempty(hdone) && hdone(1) > tnow - 1/24)
	if force || ~isempty(hdone)
		% concatenates the 2 last hourly images (faster than concatenating the last 60 1-minute images...)
		tv0 = datevec(tnow);
		f0 = sprintf('%s/%4d/%4d%02d%02d/%s/%4d%02d%02d%02d.jpg',SEFRAN3.ROOT,tv0(1),tv0(1:3),SEFRAN3.PATH_IMAGES_HOUR,tv0(1:4));
		tv1 = datevec(tnow - 1/24);
		f1 = sprintf('%s/%4d/%4d%02d%02d/%s/%4d%02d%02d%02d.jpg',SEFRAN3.ROOT,tv1(1),tv1(1:3),SEFRAN3.PATH_IMAGES_HOUR,tv1(1:4));
		f = sprintf('%s/last_hour.jpg',SEFRAN3.ROOT);
		ftmp = sprintf('%s/lh.jpg',ptmp);
		if exist(f0,'file') && exist(f1,'file')
			fprintf('%s: updating %s ... ',wofun,f);
			wosystem(sprintf('%s +append %s %s -scale %1.1f%% %s',convert,f1,f0,100*wlh/whour,ftmp),SEFRAN3);
			if exist(ftmp,'file')
				IM = imfinfo(ftmp,'jpg');
				if IM.Width > wlh
					wosystem(sprintf('%s -crop %dx%d+%d %s %s',convert,wlh,IM.Height,IM.Width-wlh,ftmp,f),SEFRAN3);
				else
					wosystem(sprintf('cp -f %s %s',ftmp,f),SEFRAN3);
				end
			end
			fprintf('done.\n');
		end
	end

	if isempty(hdone)
		fprintf('%s: nothing to do in the last %g hours (all OK).\n',wofun,update);
	end


	fprintf('=== [%s]: run %d ends on %s TU ===\n\n',name,nrun,datestr(now - tzserver));

	% waits BEAT seconds (to moderate the loop)
	pause(beat)
	nrun = nrun + 1;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function m = fdate2mlist(s)
%FDATE2MLIST Converts FDATE argument to a vector of minutes

switch length(s)
case 12	% yyyymmddHHMM
	m = datenum([str2double({s(1:4),s(5:6),s(7:8),s(9:10),s(11:12)}),0]);
case 10	% yyyymmddHH
	v = str2double({s(1:4),s(5:6),s(7:8),s(9:10)});
	m = datenum(v(1),v(2),v(3),v(4),0:59,0);
case 8	% yyyymmdd
	v = str2double({s(1:4),s(5:6),s(7:8)});
	m = datenum(v(1),v(2),v(3),0,0:1439,0);
case 6	% yyyymm
	v = str2double({s(1:4),s(5:6)});
	m = datenum(v(1),v(2),1,0,0:(1439*31),0);
	m(~strcmp(cellstr(datestr(m,'mm')),datestr(m(1),'mm'))) = [];	% deletes dates out of the month
case 4	% yyyy
	m = datenum(str2double(s),1,1,0,0:(1439*366),0);
	m(~strcmp(cellstr(datestr(m,'yyyy')),datestr(m(1),'yyyy'))) = [];	% deletes dates out of the year
otherwise
	m = [];
end

fprintf('WEBOBS{sefran3): forces update of all minutes in %s* (from %s to %s)\n',s,datestr(m(1)),datestr(m(end)));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function readdata(WO,SEFRAN3,dataformat,datasource,t0,C,ptmp,fmsd)

wofun = sprintf('WEBOBS{%s}',mfilename);
slinktool = sprintf('%s %g %s',WO.PRGM_ALARM,field2num(SEFRAN3,'SEEDLINK_SERVER_TIMEOUT_SECONDS',5),WO.SLINKTOOL_PRGM);
alfetch = field2str(WO,'ARCLINKFETCH_PRGM','arclink_fetch','notempty');
aluser = field2str(SEFRAN3,'ARCLINK_USER','sefran3','notempty');

t1 = t0 + 1/1440;
sfr = C{2};
nchan = length(sfr);
% vector of added seconds for each channel
dt0 = ~cellfun(@isempty,regexp(C{4},'^(lp|hp|bp|bs)...*'))*field2num(SEFRAN3,'FILTER_EXTRA_SECONDS',0)/86400;

switch dataformat
% =============================================================================
case 'seedlink'

	% checks data availability on SeedLink server
	[s,w] = wosystem(sprintf('%s -Q %s',slinktool,datasource),SEFRAN3);
	if isempty(w) || ~isempty(strfind(w,'error: INFO type requested is not enabled'))
		fprintf('%s: ** WARNING ** SEEDLINK server %s seems to not accept INFO request... use blind mode with timeout.\n',wofun,datasource);
		chan = 1:length(C{2});
	else
		stream = textscan(w,'%s','Delimiter','\n'); % one line for each seedlink stream
		chan = nan(1,nchan);
		for n = 1:nchan
			c = textscan(sfr{n},'%s','Delimiter','.:'); % splits Network, Station, Loc and Channel codes
			k = find(~cellfun('isempty',regexp(stream{1},sprintf('%s.*%s.*%s.*%s',c{1}{1},c{1}{2},c{1}{3},c{1}{4}))));
			if ~isempty(k)
				% has to interpret dates from Seedlink GFZ or IRIS-like formats...
				%FB-was: ct0 = datenum(A{1}{k(1)}(19+(0:23))); % start time
				%FB-was: ct1 = datenum(A{1}{k(1)}(48+(0:23))); % end time
				dte = textscan(stream{1}{k(1)}(19:end),'%n','Delimiter','/-:'); 
				%FB-was: if datenum(dte{1}(1:6)') <= t0 && datenum(dte{1}(7:12)') >= (t1 - rtdelay/86400)
				if datenum(dte{1}(1:6)') <= t0 && datenum(dte{1}(7:12)') >= t1
					chan(n) = n; % channel n is available at time interval [t0,t1]
				else
					fprintf('%s: ** WARNING ** SEEDLINK server %s at %s has no data for channel %s !\n',wofun,datasource,datestr(t1),sfr{n});
				end
			else
				fprintf('%s: ** WARNING ** SEEDLINK server %s has no channel %s available ! \n',wofun,datasource,sfr{n});
			end
		end
		chan(isnan(chan)) = [];
	end
	if ~isempty(chan)
		% build stream list of available channels (slinktool -S option strange format...)
		for n = 1:length(chan)
			c = textscan(sfr{chan(n)},'%s','Delimiter','.:'); % splits NET, STA, LOC, CHA codes
			s = sprintf('%s_%s:%s%s',c{1}{1},c{1}{2},c{1}{3},c{1}{4});
			if n == 1
				streams = s;
			else
				streams = sprintf('%s,%s',streams,s);
			end
		end
		if any(~cellfun(@isempty,regexp(C{4},'^[lhb]p...*')))
			dt = dt0;
		else
			dt = 0;
		end
		% makes SeedLink request and save to temporary miniseed file
		s = wosystem(sprintf('%s -d -o %s -S "%s" -tw %d,%d,%d,%d,%d,%d:%g,%d,%d,%d,%d,%g %s', ...
			slinktool,fmsd,streams,datevec(t0-max(dt0)),datevec(t1),datasource),SEFRAN3);
	else
		fprintf('%s: ** WARNING ** SEEDLINK server %s at %s has no channel available !\n',wofun,datasource,datestr(t1));
	end

% =============================================================================
case 'arclink'
	k = strfind(datasource,'?user=');
	if ~isempty(k)
		aluser = datasource(k+6:end);
		datasource = datasource(1:k-1);
	end
	% builds request file for arclink (arclink_fetch format)
	freq = sprintf('%s/req.txt',ptmp);
	fid = fopen(freq,'wt');
	for n = 1:length(sfr)
		c = textscan(sfr{n},'%s','Delimiter','.:'); % splits Network, Station, Loc and Channel codes
		fprintf(fid,'%d,%d,%d,%d,%d,%g %d,%d,%d,%d,%d,%g %s %s %s %s\n',datevec(t0-dt0(n)),datevec(t1),c{1}{1},c{1}{2},c{1}{4},c{1}{3});
	end
	fclose(fid);
	% makes ArcLink request and save to temporary miniseed file
	[~,w] = wosystem(sprintf('%s -u %s -a %s -o %s %s',alfetch,aluser,datasource,fmsd,freq),SEFRAN3);
	if any(strfind(w,'no data'))
		fprintf('%s: ** WARNING ** ARCLINK server %s at %s has some channels not available !\n',wofun,datasource,datestr(t1));
	end

% =============================================================================
case 'fdsnws-dataselect'
	% delete previous temporary file
	wosystem(sprintf('rm -f %s/postfile.tmp',ptmp),SEFRAN3);
    fpost = sprintf('%s/postfile.tmp',ptmp); % temporary POST file
    fid = fopen(fpost,'w');
	for n = 1:length(sfr)
		c = textscan(sfr{n},'%s','Delimiter','.:'); % splits NET, STA, LOC, CHA codes
		if isempty(c{1}{3}) % if empty location code, replace with '--'
		    c{1}{3} = '--';
	    end
		% builds request line for dataselect WebService POST file
		fprintf(fid,'%s %s %s %s %04d-%02d-%02dT%02d:%02d:%02.0f %04d-%02d-%02dT%02d:%02d:%02.0f\n',c{1}{1},c{1}{2},c{1}{3},c{1}{4},datevec(t0-dt0(n)),datevec(t1));
	end
	% request the data
	wosystem(sprintf('wget -nv -O %s --post-file %s "%s"',fmsd,fpost,datasource),SEFRAN3);

% =============================================================================
case 'miniseed'

% =============================================================================
case 'winston'

otherwise
	error('%s: unknown data format "%s".',wofun,dataformat);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function varargout = readcombined(x)

% default behavior (no prefix)
if length(x) >= 2
	varargout = {'seedlink',x{1},'arclink',x{2}};
else
	varargout = {'arclink',x{1}};
end

for i = 1:length(x)
	k = strfind(x{i},'://');
	if ~isempty(k)
		varargout{i*2} = x{i}(k(1)+3:end);
		fmt = x{i}(1:k(1)-1);
		switch fmt
		case 'slink'
			varargout{i*2 - 1} = 'seedlink';
		case 'arclink'
			varargout{i*2 - 1} = 'arclink';
		case 'fdsnws'
			varargout{i*2 - 1} = 'fdsnws-dataselect';
		case 'file'
			varargout{i*2 - 1} = 'miniseed';
		otherwise
			varargout{i*2 - 1} = fmt;
		end
	end
end
