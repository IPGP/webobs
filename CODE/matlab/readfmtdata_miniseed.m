function D = readfmtdata_miniseed(WO,P,N,F)
%READFMTDATA_MINISEED subfunction of readfmtdata.m
%
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: miniSEED file request/reading
%	data format: miniSEED
%	channel stream: NET = node FDSN, STA = node FID, CHA = .CLB Chan. Code, LOC = .CLB LC
%	other PROC's specific parameters with example values:
%		P.STREAM_CHANNEL_SELECTOR|[NET_STA:]CHA[,NET_STA:CHA [CHA]]
%		P.DATALINK_DELAY_SECONDS|300
%	output fields:
%		D.t (datenum)
%		D.d (channel1 channel2 ...)
%
%
%	format 'miniseed'
%		type: miniSEED local file(s)
%	    files: P.RAWDATA contains full path and filename(s) using bash wildcard
%		     facilities. The string may include $FID, $NET, $yyyy, $mm, $dd or
%		     $doy variables.
%
%	format 'seedlink'
%		type: SEEDLink data stream (using slinktool)
%		server: P.RAWDATA (host:port)
%		needed in WEBOBS.rc:
%		     WO.SLINKTOOL_PRGM|${ROOT_CODE}/bin/linux-32/slinktool
%		     WO.PRGM_ALARM|perl -e "alarm shift @ARGV; exec @ARGV"
%
%	format 'arclink'
%		type: ArcLink request (using arclink_fetch)
%		server: P.RAWDATA (host:port)
%		user: P.ARCLINK_USER (optional, uses 'wo' if undefined)
%		needed in WEBOBS.rc:
%		     WO.ARCLINKFETCH_PRGM|env LD_LIBRARY_PATH='' /usr/local/bin/arclink_fetch
%
%	format 'combined'
%		type: SEEDLink data stream (using slinktool) or ArcLink request (using arclink_fetch)
%		server: P.RAWDATA (seedlinkhost:seedlinkport;arclinkhost:arclinkport;delayhours)
%		needed in WEBOBS.rc:
%		     WO.SLINKTOOL_PRGM|${ROOT_CODE}/bin/linux-32/slinktool
%		     WO.PRGM_ALARM|perl -e "alarm shift @ARGV; exec @ARGV"
%		     WO.ARCLINKFETCH_PRGM|env LD_LIBRARY_PATH='' /usr/local/bin/arclink_fetch
%
%	format 'fdsnws-dataselect'
%		type: FDSN WebServices waveform request
%		server: P.RAWDATA (base URL)
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2022-06-09

wofun = sprintf('WEBOBS{%s}',mfilename);

mseed2sac = field2str(WO,'MSEED2SAC_PRGM','mseed2sac','notempty');

% checks correct definition of codes and calibration for the node N
if isempty(N.FDSN_NETWORK_CODE)
	error('%s: no FDSN code defined for node %s !\n',wofun,N.ID);
end
if isempty(N.FID)
	error('%s: no FID code defined for node %s !\n',wofun,N.FID);
end
if N.CLB.nx == 0
	error('%s: no CLB file for node %s. Cannot import data.',wofun,N.ID);
end

netsta = [N.FDSN_NETWORK_CODE,'_',N.FID];
% channel list filter is in the format of slinktool [NET_STA:][LC]CHA
% since this function works for a single node (station), we exclude other nodes if needed
cha_list = field2str(P,'STREAM_CHANNEL_SELECTOR','???','notempty');
cha_list = regexprep(split(cha_list,','),[netsta,':'],''); % removes NET_STA for node N
cha_list = regexprep(cha_list,'.*_.*',''); % removes all remaining NET_CHA (not node N)
cha_list = split(strjoin(cha_list,' '),' '); % splits multiple channels
cha_list(strcmp(cha_list,'')) = []; % cleans empty strings in cell array

% reduces the CLB file to specified channels
N.CLB = clbselect(N.CLB,cha_list);

datalinkdelay = field2num(P,'DATALINK_DELAY_SECONDS',0);

fdat = sprintf('%s/%s.msd',F.ptmp,N.ID);
if exist(fdat,'file')
	delete(fdat)
end
tv = floor(datevec(F.datelim - datalinkdelay/86400)');	% floor() is needed to avoid second 60 due to round

% add an alarm to slinktool to avoid freezing...
slinktool = sprintf('%s %g %s',WO.PRGM_ALARM,field2num(P,'SEEDLINK_SERVER_TIMEOUT_SECONDS',5,'notempty'),WO.SLINKTOOL_PRGM);

% =============================================================================
% selects the method to read data

switch F.fmt

% -----------------------------------------------------------------------------
case 'seedlink'

	% takes former proc's parameter P.SEEDLINK_SERVER if defined, otherwise RAWDATA
	slsrv = field2str(P,'SEEDLINK_SERVER',F.raw{1},'notempty');

	s = wosystem(sprintf('%s -S %s -s "%s" -tw %d,%d,%d,%d,%d,%1.0f:%d,%d,%d,%d,%d,%1.0f -o %s %s',slinktool,netsta,strjoin(cha_list,' '),tv,fdat,slsrv),P,'warning');
	if s
		delete(fdat);
	end


% -----------------------------------------------------------------------------
case 'arclink'

	% builds request file for arclink (arclink_fetch format)
	freq = sprintf('%s/req.txt',F.ptmp);
	fid = fopen(freq,'wt');
	for nn = 1:length(cha_list)
		fprintf(fid,'%d,%d,%d,%d,%d,%d %d,%d,%d,%d,%d,%d %s %s %s *\n',tv,N.FDSN_NETWORK_CODE,N.FID,cha_list{nn});
	end
	fclose(fid);
	fprintf('\n%s: arclink request:\n',wofun);
	type(freq)
	% takes former proc's parameter P.ARCLINK_SERVER if defined, otherwise RAWDATA
	alsrv = field2str(P,'ARCLINK_SERVER',F.raw{1},'notempty');
	aluser = field2str(P,'ARCLINK_USER','wo','notempty');
	% makes ArcLink request and save to temporary miniseed file
	s = wosystem(sprintf('%s -u %s -a %s -o %s %s',WO.ARCLINKFETCH_PRGM,aluser,alsrv,fdat,freq),P);


% -----------------------------------------------------------------------------
case 'combined'

	lserv = split(F.raw{1},';');
	if length(lserv) < 3
		delay = 1;
	else
		delay = str2double(lserv(3));
	end
	if (P.NOW - F.datelim(1)) < delay/24 || length(lserv) < 2
		% seedlink request
		s = wosystem(sprintf('%s -S %s_%s -s "%s" -tw %d,%d,%d,%d,%d,%1.0f:%d,%d,%d,%d,%d,%1.0f -o %s %s',slinktool,N.FDSN_NETWORK_CODE,N.FID,strjoin(cha_list,' '),tv,fdat,lserv{1}),P,'warning');
		if s
			delete(fdat);
		end
	else
		% builds request file for arclink (arclink_fetch format)
		freq = sprintf('%s/req.txt',F.ptmp);
		fid = fopen(freq,'wt');
		for nn = 1:length(cha_list)
			fprintf(fid,'%d,%d,%d,%d,%d,%1.0f %d,%d,%d,%d,%d,%1.0f %s %s %s *\n',tv,N.FDSN_NETWORK_CODE,N.FID,cha_list{nn});
		end
		fclose(fid);
		% makes ArcLink request and save to temporary miniseed file
		s = wosystem(sprintf('%s -u WebObs%s -a %s -o %s %s',WO.ARCLINKFETCH_PRGM,N.ID,lserv{2},fdat,freq),P);
	end


% -----------------------------------------------------------------------------
case 'miniseed'

	% if RAWDATA contains the '$yyyy' variable, makes a loop on years
	if ~isempty(regexpi(F.raw{1},'\$yyyy'))
		Y = dir(regexprep(F.raw{1},'\$yyyy.*$','*'));
		years = str2num(cat(1,Y(cellfun(@length,{Y.name})==4 & cat(1,Y.isdir)').name))';
		for yyyy = years
			if (isnan(P.DATELIM(1)) || datenum(yyyy,12,31) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,1,1) <= P.DATELIM(2))
				if ~isempty(regexpi(F.raw{1},'\$mm'))
					for mm = 1:12
						if (isnan(P.DATELIM(1)) || datenum(yyyy,mm,31) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,mm,1) <= P.DATELIM(2))
							if ~isempty(regexpi(F.raw{1},'\$dd'))
								for dd = 1:31
									if (isnan(P.DATELIM(1)) || datenum(yyyy,mm,dd) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,mm,dd) <= P.DATELIM(2))
										fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
										fraw = regexprep(fraw,'\$mm',sprintf('%02d',mm),'ignorecase');
										fraw = regexprep(fraw,'\$dd',sprintf('%02d',dd),'ignorecase');
										wosystem(sprintf('cat %s >> %s',fraw,fdat), P);
									end
								end
							else
								fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
								fraw = regexprep(fraw,'\$mm',sprintf('%02d',mm),'ignorecase');
								wosystem(sprintf('cat %s >> %s',fraw,fdat), P);
							end
						end
					end
				else
					if ~isempty(regexpi(F.raw{1},'\$doy'))
						for doy = 1:366
							if (isnan(P.DATELIM(1)) || datenum(yyyy,1,doy) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,1,doy) <= P.DATELIM(2))
								fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
								fraw = regexprep(fraw,'\$doy',sprintf('%03d',doy),'ignorecase');
								wosystem(sprintf('cat %s >> %s',fraw,fdat), P);
							end
						end
					else
						fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
						wosystem(sprintf('cat %s >> %s',fraw,fdat), P);
					end
				end
				fprintf('.');
			end
		end
	else
		wosystem(sprintf('cat %s > %s',F.raw{1},fdat),P);
	end


% -----------------------------------------------------------------------------
case 'fdsnws-dataselect'
	% builds request file for POST method (all channels and possible multiple calibrations periods)
	freq = sprintf('%s/post.txt',F.ptmp);
	fid = fopen(freq,'wt');
	cc = unique(N.CLB.nv);
	dt = N.CLB.dt;
	for ic = 1:length(cc)
		c = cc(ic);
		kc = find(N.CLB.nv == c);
		for ii = 1:length(kc)
			if dt(kc(ii)) < F.datelim(2) && (ii==length(kc) || dt(kc(ii+1)) > F.datelim(1))
				t1 = max(dt(kc(ii)),F.datelim(1));
				if ii == length(kc)
					t2 = F.datelim(2);
				else
					t2 = min(dt(kc(ii+1)),F.datelim(2));
				end
				fprintf(fid,'%s %s %s %s %04d-%02d-%02dT%02d:%02d:%02.0f %04d-%02d-%02dT%02d:%02d:%02.0f\n', ...
					N.FDSN_NETWORK_CODE,N.FID,N.CLB.lc{kc(ii)},N.CLB.cd{kc(ii)},datevec(t1),datevec(t2));
			end
		end
	end
	fclose(fid);
	if isok(P,'DEBUG')
		fprintf('\n%s: FDSNWS dataselect POST request:\n',wofun);
		type(freq)
	end

	% makes the request
	wosystem(sprintf('wget -nv --post-file %s -O %s %s',freq,fdat,F.raw{1}),P);


% -----------------------------------------------------------------------------
otherwise
	fprintf('%s: ** WARNING ** unknown format "%s" for node %s!\n',wofun,F.fmt,N.ID);
end


% =============================================================================
% loads the miniseed file
if exist(fdat,'file')
	fprintf('%s: data file %s ...',wofun,fdat);
	[X,I] = rdmseedfast(fdat,mseed2sac);
	fprintf(' loaded.\n');

	% copy the original file to export directory (if needed)
	if isok(P,'EXPORTS')
		pexp = sprintf('%s/%s',P.GTABLE(1).OUTDIR,WO.PATH_OUTG_EXPORT);
		wosystem(sprintf('mkdir -p %s && cp %s %s/',pexp,fdat,pexp),P);
		for g = 1:length(P.GTABLE)
			wosystem(sprintf('ln -sf $(basename %s) %s/%s_%s.msd',fdat,pexp,N.ID,P.GTABLE(g).TIMESCALE),P);
		end
	end

	% list of channels existing in the imported data
	chlist = cellstr(cat(1,I.ChannelFullName));
	if any(isnan(P.DATELIM))
		F.datelim = minmax(cat(1,X.t));
		P.DATELIM = F.datelim - N.UTC_DATA + P.TZ/24;
	end
	[~,CLB] = calib(F.datelim(2),nan(1,N.CLB.nx),N.CLB);
	M = repmat(struct('t',[],'d',[]),N.CLB.nx,1);
	for c = 1:CLB.nx
		if isempty(CLB.cd{c})
			fprintf('%s: ** WARNING ** no Channel code defined for node %s channel "%s" (calibration file)!\n',wofun,N.ID,CLB.nm{c});
		end
		fullchannelname = sprintf('%s:%s:%s:%s',N.FDSN_NETWORK_CODE,N.FID,CLB.lc{c},CLB.cd{c});
		i = find(strcmp(chlist,fullchannelname));
		if ~isempty(i)
			k = I(i).XBlockIndex;
			M(c).t = cat(1,X(k).t);
			M(c).d = double(cat(1,X(k).d));
			% delete overlaps
			[t,k] = sort(M(c).t);
			d = M(c).d(k);
			dt = [1;diff(t)];
			M(c).t = t(dt>0);
			M(c).d = d(dt>0);
		else
			M(c).t = [];
			M(c).d = [];
			fprintf('%s: ** WARNING ** no data found for "%s"!\n',wofun,fullchannelname);
		end

	end
	% To have a single vector t with matrix d, must interpolate all channels at the highest frequency sampling rate
	sf = max(cat(1,X.SampleRate));
	t = (min(cat(1,X.t)):1/sf/86400:max(cat(1,X.t)))';
	d = nan(length(t),N.CLB.nx);
	for c = 1:N.CLB.nx
		if ~isempty(M(c).d)
			d(:,c) = interp1(M(c).t,M(c).d,t);
		end
	end
else
	fprintf('%s: ** WARNING ** no data found in file "%s" with format "%s"!\n',wofun,F.raw{1},F.fmt);
	t = [];
	d = [];
end
D.t = t - N.UTC_DATA;
D.d = d;

[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
D.t = D.t + P.TZ/24;

if isok(P,'DEBUG')
	D
	D.CLB
end
