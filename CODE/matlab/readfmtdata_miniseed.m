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
%		type: miniSEED local file(s) defined by RAWDATA
%
%	format 'seedlink'
%		type: SEEDLink data stream (using slinktool)
%		server: P.RAWDATA (host:port)
%		needed in WEBOBS.rc:
%		     WO.SLINKTOOL_PRGM|${ROOT_CODE}/bin/linux-32/slinktool
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
%		     WO.ARCLINKFETCH_PRGM|env LD_LIBRARY_PATH='' /usr/local/bin/arclink_fetch
%
%	format 'fdsnws-dataselect'
%		type: FDSN WebServices waveform request
%		server: P.RAWDATA (base URL)
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2018-05-27

wofun = sprintf('WEBOBS{%s}',mfilename);

mseed2sac = field2str(WO,'MSEED2SAC_PRGM','mseed2sac');

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
tv = floor(datevec(F.datelim - datalinkdelay/86400)');	% floor() is needed to avoid second 60 due to round


% =============================================================================
% selects the method to read data

switch F.fmt

% -----------------------------------------------------------------------------
case 'seedlink'

	% takes former proc's parameter P.SEEDLINK_SERVER if defined, otherwise RAWDATA
	slsrv = field2str(P,'SEEDLINK_SERVER',F.raw{1},'notempty');

	wosystem(sprintf('%s -S %s -s "%s" -tw %d,%d,%d,%d,%d,%1.0f:%d,%d,%d,%d,%d,%1.0f -o %s %s',WO.SLINKTOOL_PRGM,netsta,strjoin(cha_list,' '),tv,fdat,slsrv),P);


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
		wosystem(sprintf('%s -S %s_%s -s "%s" -tw %d,%d,%d,%d,%d,%1.0f:%d,%d,%d,%d,%d,%1.0f -o %s %s',WO.SLINKTOOL_PRGM,N.FDSN_NETWORK_CODE,N.FID,strjoin(cha_list,' '),tv,fdat,lserv{1}),P);
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

	wosystem(sprintf('cat %s > %s',F.raw{1},fdat),P);
	if ~exist(fdat,'file')
		fprintf('%s: ** WARNING ** cannot find file %s for format "%s"!\n',wofun,F.raw{1},F.fmt);
	end


% -----------------------------------------------------------------------------
case 'fdsnws-dataselect'

	% builds request line for dataselect WebService
	wsreq = sprintf('starttime=%04d-%02d-%02dT%02d:%02d:%02.0f&endtime=%04d-%02d-%02dT%02d:%02d:%02.0f&net=%s&sta=%s&cha=%s',tv,N.FDSN_NETWORK_CODE,N.FID,strjoin(cha_list,','));
	wosystem(sprintf('wget -nv -O %s "%s%s"',fdat,F.raw{1},wsreq),P);


% -----------------------------------------------------------------------------
otherwise
	fprintf('%s: ** WARNING ** unknown format "%s" for node %s!\n',wofun,F.fmt,N.ID);
end


% =============================================================================
% loads the miniseed file
if exist(fdat,'file')
	fprintf('%s: data file %s ...',wofun,fdat);
	[X,I] = rdmseedfast(fdat,field2str(WO,'MSEED2SAC_PRGM','mseed2sac','notempty'));
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
	[~,D.CLB] = calib(F.datelim(2),nan(1,N.CLB.nx),N.CLB);
	M = repmat(struct('t',[],'d',[]),N.CLB.nx,1);
	for c = 1:D.CLB.nx
		if isempty(D.CLB.cd{c})
			fprintf('%s: ** WARNING ** no Channel code defined for node %s channel "%s" (calibration file)!\n',wofun,N.ID,D.CLB.nm{c});
		end
		fullchannelname = sprintf('%s:%s:%s:%s',N.FDSN_NETWORK_CODE,N.FID,D.CLB.lc{c},D.CLB.cd{c});
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
	fprintf('no data found!\n')
	t = [];
	d = [];
end
D.t = t - N.UTC_DATA;
D.d = d;

[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
D.t = D.t + P.TZ/24;

