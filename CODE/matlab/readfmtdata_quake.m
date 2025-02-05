function [D,P] = readfmtdata_quake(WO,P,N,F)
%READFMTDATA_QUAKE subfunction of readfmtdata.m
%
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: earthquake catalogs
%	output fields:
%		D.t (datenum)
%		D.d (Latitude Longitude Depth Magnitude Azimuthal_Gap RMS ErH ErZ Phase_Count Quality EMS98 ErMag)
%		D.c (eventID MagnitudeType EventType Comment Status MCImage)
%		D.e (quality)
%
%	format 'hyp71sum2k'
%		type: Hypo71, year 2000 compatible, summary lines in a file
%		filename/path: P.RAWDATA or N.RAWDATA
%		data format:
%		#   DATE ORIGIN     LAT N     LONG W   DEPTH Mt MAG  NO GAP DMIN RMS  ERH  ERZ  Q SCode File
%		20141005 1819 07.34 14-48.70  61-10.33  -0.24 D 1.52  8 166  0.3 0.26  0.6  0.8 C  EB1   20141005_181900_a.mq0
%		node specific variables: FID_MAGTYPE_DEFAULT, FID_MAGERR_DEFAULT
%		node calibration: none
%
%	format 'fdsnws-event'
%		type: FDSN WebServices event request
%		filename/path: P.RAWDATA or N.RAWDATA (base URL)
%		data format: QuakeML1.2
%		node specific variables: FID_MAGTYPE_DEFAULT, FID_MAGERR_DEFAULT
%		node calibration: none
%
%	format 'scevtlog-xml'
%		type: SeisComP3-xml files created by scevtlog
%		filename/path: P.RAWDATA or N.RAWDATA will search for events in
%			RAWDATA/YYYY/MM/DD/eventID/eventID.last.xml
%			Note that YYYY/MM/DD isn't the event origin time, but the event creation time
%		data format: sc3ml
%		node specific variables: FID_MAGTYPE_DEFAULT, FID_MAGERR_DEFAULT
%		node calibration: none
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2025-01-29

wofun = sprintf('WEBOBS{%s}',mfilename);

% filters
for fn = {'LAT','LON','MAG','DEP','MSK','GAP','RMS','ERH','ERZ','NPH','CLA'}
	fd = [fn{:},'LIM'];
	if ~isfield(P,fd) || isempty(P.(fd))
		P.(fd) = '-Inf,Inf';
	end
	if ischar(P.(fd))
		P.(fd) = str2vec(P.(fd));
	end
	if numel(P.(fd)) ~= 2
		fprintf('** WARNING ** %s must be empty or with two elements.\n',fd);
		P.(fd) = [-Inf,Inf];
	end
end
if isfield(P,'EVENTTYPE_EXCLUDED_LIST') && ~isempty(P.EVENTTYPE_EXCLUDED_LIST)
	extypes = split(P.EVENTTYPE_EXCLUDED_LIST,',');
else
	extypes = {''};
end
if isfield(P,'EVENTSTATUS_EXCLUDED_LIST') && ~isempty(P.EVENTSTATUS_EXCLUDED_LIST)
	exstatus = split(P.EVENTSTATUS_EXCLUDED_LIST,',');
else
	exstatus = {''};
end

felteventcode = isok(P,'FELT_EVENTCODE_OK');
feltcomment = field2str(P,'EVENTCOMMENT_FELT_REGEXP');
excomment = field2str(P,'EVENTCOMMENT_EXCLUDED_REGEXP');
incomment = field2str(P,'EVENTCOMMENT_INCLUDED_REGEXP');

% default values
magtype = field2str(N,'FID_MAGTYPE_DEFAULT');
magerr = field2num(N,'FID_MAGERR_DEFAULT');


% =============================================================================
switch F.fmt

% -----------------------------------------------------------------------------
case 'hyp71sum2k'

	% makes a single and homogeneous space-separated numeric file (fdat) from the raw data (D.d)
	% and a single and homogeneous pipe-separated text file (fcdat) for the text data (D.c)
	fawk = sprintf('%s/awk',F.ptmp);
	fdat = sprintf('%s/dat',F.ptmp);
	fcdat = sprintf('%s/cdat',F.ptmp);
	fid = fopen(fawk,'wt');
	fprintf(fid,'BEGIN{\nFIELDWIDTHS="4 2 2 1 2 2 6 3 1 5 4 1 5 7 1 1 5 3 4 5 5 5 5 1 1 2 5 1 21";\nOFS="|";\n}\n');
	fprintf(fid,'!/^(#|$|\\r)/{\ngsub("\\\\*\\\\*\\\\*\\\\*\\\\*","     ",$0);\n');
	fprintf(fid,'if($2=="  ") mm=1; else mm=$2;\n');
	fprintf(fid,'if($3=="  ") dd=1; else dd=$3;\n');
	fprintf(fid,'if($9=="S") lat=-($8+$10/60); else lat=$8+$10/60;\n');
	fprintf(fid,'if($12=="E") lon=$11+$13/60; else lon=-($11+$13/60);\n');
	fprintf(fid,'if(!strtonum($14)) depth="NaN"; else depth=$14;\n');
	fprintf(fid,'if(!strtonum($17)) mag="NaN"; else mag=$17;\n');
	fprintf(fid,'magtype="M"$16;\n');
	fprintf(fid,'if(!strtonum($18)) phasecount="NaN"; else phasecount=$18;\n');
	fprintf(fid,'if(!strtonum($19)) gap="NaN"; else gap=$19;\n');
	fprintf(fid,'if(!strtonum($21)) RMS="NaN"; else RMS=$21;\n');
	fprintf(fid,'if(!strtonum($22)) ErH="NaN"; else ErH=$22;\n');
	fprintf(fid,'if(!strtonum($23)) ErZ="NaN"; else ErZ=$23;\n');
	fprintf(fid,'qual=index("ABCD",$25);\n');
	fprintf(fid,'if($27=="     ") code="-"; else code=$27;\n');
	fprintf(fid,'msk=substr($27,3,1);\n');
	fprintf(fid,'if(!strtonum(msk)) msk="NaN";\n');
	fprintf(fid,'if(msk==0) msk=10;\n');
	fprintf(fid,'if(length($29)>12) evtid=substr($29,0,15); else evtid=substr($29,0,8); gsub(/\\r$/,"",evtid);\n');
	fprintf(fid,'print $1,mm,dd,$5,$6,$7,lat,lon,depth,mag,gap,RMS,ErH,ErZ,phasecount,qual,msk,"NaN";\n');
	fprintf(fid,'print evtid,magtype,code,"","manual","" >> "%s";\n}\n',fcdat);
	fclose(fid);
	wosystem(sprintf('gawk -f %s %s | sed ''s/ //g;s/|/ /g'' > %s',fawk,F.raw{1},fdat),P);

	t = nan(0,1);
	d = nan(0,12);
	c = cell(0,6);
	if exist(fdat,'file') && exist(fcdat,'file')
		dd = load(fdat);
		fid = fopen(fcdat,'rt');
		cc = textscan(fid,'%q%q%q%q%q%q','Delimiter','|');
		fclose(fid);
		cc = cat(2,cc{:});
		if ~isempty(dd)
			t = datenum(dd(:,1:6));
			% applies the selection filters (dates, latitude, longitude, depth, magnitude and max intensity)
			k = find((t >= F.datelim(1) & t <= F.datelim(2)) ...
				& isinto(dd(:,7), P.LATLIM) ...
				& isinto(dd(:,8), P.LONLIM) ...
				& isinto(dd(:,9), P.DEPLIM) ...
				& isinto(dd(:,10),P.MAGLIM) ...
				& isinto(dd(:,17),P.MSKLIM) ...
			);

			[t,kk] = sort(t(k));
			d = dd(k(kk),7:end);
			c = cc(k(kk),:);

			if ~isnan(magerr)
				d(isnan(d(:,12)),12) = magerr;
			end
			if ~isempty(magtype)
				k = find(strcmp(c(:,2),'M'));
				c(k,2) = repmat({magtype},length(k),1);
			end

			fprintf('done (%d/%d events imported).\n',length(t),size(dd,1));

		end
	end
	if isempty(t)
		fprintf('** WARNING ** no events found!\n');
	end

% -----------------------------------------------------------------------------
case 'fdsnws-event'

	setenv('LD_LIBRARY_PATH', '');	% needed to wget system call
	nbmax = 1000;	% max number of )event for a request (due to possible memory problems in xmlread)
	wsreq = sprintf('format=xml&orderby=time-asc&limit=%d',nbmax);
	wsreqstime = '';
	wsreqetime = '';
	if all(~isnan(P.DATELIM))
		tv = datevec(F.datelim);
		wsreqstime = sprintf('&starttime=%04d-%02d-%02dT%02d:%02d:%02.0f',tv(1,:));
		wsreqetime = sprintf('&endtime=%04d-%02d-%02dT%02d:%02d:%02.0f',tv(2,:));
	end
	if all(isfinite(P.LATLIM))
		wsreq = sprintf('%s&minlatitude=%g&maxlatitude=%g',wsreq,P.LATLIM);
	end
	if all(isfinite(P.LONLIM))
		wsreq = sprintf('%s&minlongitude=%g&maxlongitude=%g',wsreq,P.LONLIM);
	end
	if all(isfinite(P.DEPLIM))
		wsreq = sprintf('%s&mindepth=%g&maxdepth=%g',wsreq,P.DEPLIM);
	end
	if isfinite(P.MAGLIM(1))
		wsreq = sprintf('%s&minmagnitude=%g',wsreq,P.MAGLIM(1));
	end
	if isfinite(P.MAGLIM(2))
		wsreq = sprintf('%s&maxmagnitude=%g',wsreq,P.MAGLIM(2));
	end

	% makes a single and homogeneous space-separated numeric file from the raw data
	evtCount = nbmax;
	t = nan(0,1);
	d = nan(0,12);
	c = repmat({''},0,6);
	while evtCount == nbmax
		fdat = sprintf('%s/req.xml',F.ptmp);
		%[FBnote]: xmlread(url) often freezes with bad internet connection...
		%[FBnote]: urlread() ok but options charset and timeout only available after R2012b...
		%[FBnote]: best (temporary?) solution is wget + xmlread(file) which seems stable.
		%
		%quakeml = xmlread(sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw{1},wsreq,wsreqstime,wsreqetime));
		%xml = urlread(sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw{1},wsreq,wsreqstime,wsreqetime),'Charset','UTF-8','Timeout',60);
		%xml = urlread(sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw{1},wsreq,wsreqstime,wsreqetime));
		url = sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw{1},wsreq,wsreqstime,wsreqetime);
		s = wosystem(sprintf('wget -q "%s" -O %s -t 1 -T 60',url,fdat),P);
		if s ~= 0
			break;
		end
		if ~isempty(fdat)
			quakeml = xmlread(fdat);
			fprintf('.');
			evtCount = quakeml.getElementsByTagName('event').getLength;
			tt = nan(evtCount,1);
			dd = nan(evtCount,12);
			cc = repmat({''},evtCount,6);
			for evt = 1:evtCount
				eventNode =  quakeml.getElementsByTagName('event').item(evt-1);
				cc{evt,1} = regexprep(char(eventNode.getAttributes().item(0).getTextContent),'.*[/=]',''); % takes the last word (eventid)...
				% needs to make a loop because getElementsByTagName('type') returns multiple answers...
				child = eventNode.getFirstChild;
				while ~isempty(child) && ~strcmp(child.getNodeName,'type')
					child = child.getNextSibling;
				end
				if ~isempty(child)
					cc{evt,3} = char(child.getTextContent);
				end
				tt(evt) = datenum(char(eventNode.getElementsByTagName('time').item(0).getElementsByTagName('value').item(0).getTextContent),'yyyy-mm-ddTHH:MM:SS.FFF');
				dd(evt,1) = str2double(eventNode.getElementsByTagName('latitude').item(0).getElementsByTagName('value').item(0).getTextContent);
				dd(evt,2) = str2double(eventNode.getElementsByTagName('longitude').item(0).getElementsByTagName('value').item(0).getTextContent);
				if eventNode.getElementsByTagName('depth').getLength
					dd(evt,3) = str2double(eventNode.getElementsByTagName('depth').item(0).getElementsByTagName('value').item(0).getTextContent) / 1000;
					if eventNode.getElementsByTagName('depth').item(0).getElementsByTagName('uncertainty').getLength
						dd(evt,8) = str2double(eventNode.getElementsByTagName('depth').item(0).getElementsByTagName('uncertainty').item(0).getTextContent) / 1000;
					end
				end
				if eventNode.getElementsByTagName('magnitude').getLength
					dd(evt,4) = str2double(eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('mag').item(0).getElementsByTagName('value').item(0).getTextContent);
					if eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('type').getLength
						cc{evt,2} = char(eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('type').item(0).getTextContent);
					end
					if eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('uncertainty').getLength
						dd(evt,12) = str2double(eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('uncertainty').item(0).getTextContent);
					end
				end
				if eventNode.getElementsByTagName('comment').getLength
					cc{evt,4} = char(eventNode.getElementsByTagName('comment').item(0).getTextContent.getElementsByTagName('text').item(0).getTextContent);
				end
				if eventNode.getElementsByTagName('evaluationMode').getLength
					cc{evt,5} = char(eventNode.getElementsByTagName('evaluationMode').item(0).getTextContent);
				end
				if eventNode.getElementsByTagName('quality').getLength
					if eventNode.getElementsByTagName('quality').item(0).getElementsByTagName('azimuthalGap').getLength
						dd(evt,5) = str2double(eventNode.getElementsByTagName('quality').item(0).getElementsByTagName('azimuthalGap').item(0).getTextContent);
					end
					if eventNode.getElementsByTagName('quality').item(0).getElementsByTagName('standardError').getLength
						dd(evt,6) = str2double(eventNode.getElementsByTagName('quality').item(0).getElementsByTagName('standardError').item(0).getTextContent);
					end
					if eventNode.getElementsByTagName('quality').item(0).getElementsByTagName('usedPhaseCount').getLength
						dd(evt,9) = str2double(eventNode.getElementsByTagName('quality').item(0).getElementsByTagName('usedPhaseCount').item(0).getTextContent);
					end
				end
				if eventNode.getElementsByTagName('originUncertainty').getLength
					if eventNode.getElementsByTagName('originUncertainty').item(0).getElementsByTagName('horizontalUncertainty').getLength
						dd(evt,7) = str2double(eventNode.getElementsByTagName('originUncertainty').item(0).getElementsByTagName('horizontalUncertainty').item(0).getTextContent) / 1000;
					end
				end
			end
			t = [t;tt];
			d = [d;dd];
			c = [c;cc];

			if evtCount == nbmax
				% next request will start 1 second after the last existing data
				wsreqstime = sprintf('&starttime=%04d-%02d-%02dT%02d:%02d:%02.0f',datevec(t(end) + 1/86400));
			end
		end
	end
	if ~isnan(magerr)
		d(isnan(d(:,12)),12) = magerr;
	end
	if ~isempty(magtype)
		k = find(isempty(c(:,2)));
		c(k,2) = repmat({magtype},length(k),1);
	end
	if ~isempty(t)
		fprintf(' done (%d events).\n',length(t));
	else
		fprintf('** WARNING ** no events found!\n');
	end

% -----------------------------------------------------------------------------
case 'scevtlog-xml'

	fdat = sprintf('%s/%s.list',F.ptmp,N.ID);

	% --- makes a single and homogeneous space-separated numeric file from the raw data
	% the loop ends tonight (UTC) because directory is the date of event creation and not event origin
	for day = floor(F.datelim(1)):ceil(P.NOW - P.TZ/24)
		tv = datevec(day);
		wosystem(sprintf('d=%s/%4d/%02d/%02d;if [ -d "$d" ]; then for evt in $d/*;do evtid=`basename ${evt}`;echo ${evt}/${evtid}.last.xml >> %s;done;fi',F.raw{1},tv(1:3),fdat),P);
	end

	if exist(fdat,'file')
		fid = fopen(fdat);
		list = textscan(fid,'%s','Delimiter','\n');
		fclose(fid);
	else
		list{1} = {};
	end

	% extracts user-defined events from existing files
	if ~isempty(field2str(P,'SC3_LISTEVT'))
		evtlist = split(P.SC3_LISTEVT,', ');
		ke = [];
		for i = 1:length(evtlist)
			ke = [ke;find(~cellfun(@isempty,strfind(list{1},evtlist{i})))];
		end
		list{1} = list{1}(ke);
	end

	evtCount = length(list{1});
	t = nan(evtCount,1);
	d = nan(evtCount,12);
	c = repmat({''},evtCount,6);
	for evt = 1:evtCount
		sc3ml = xmlread(list{1}{evt});
		eventNode = sc3ml.getElementsByTagName('EventParameters').item(0);
		eventID = char(eventNode.getElementsByTagName('event').item(0).getAttributes().item(0).getTextContent);
		c{evt,1} = eventID;
		childList = eventNode.getElementsByTagName('event').item(0).getChildNodes;
		preferredOriginID = '';
		preferredMagnitudeID = '';
		for child = 0:childList.getLength - 1
			switch  char(childList.item(child).getNodeName)
			case 'type'
				c{evt,3} = char(childList.item(child).getTextContent);
			case 'preferredOriginID'
				preferredOriginID = childList.item(child).getTextContent;
			case 'preferredMagnitudeID'
				preferredMagnitudeID = childList.item(child).getTextContent;
			case 'comment'
				c{evt,4} = char(childList.item(child).getElementsByTagName('text').item(0).getTextContent);
			end
		end
		if eventNode.getElementsByTagName('magnitude').getLength
			for k = 0:eventNode.getElementsByTagName('magnitude').getLength - 1
				magnitudeNode = eventNode.getElementsByTagName('magnitude').item(k);
				if magnitudeNode.hasAttributes() && strcmp(magnitudeNode.getAttributes().item(0).getTextContent,preferredMagnitudeID)
					d(evt,4) = str2double(magnitudeNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('value').item(0).getTextContent);
					c{evt,2} = char(magnitudeNode.getElementsByTagName('type').item(0).getTextContent);
					if magnitudeNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('uncertainty').getLength
						d(evt,12) = str2double(magnitudeNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('uncertainty').item(0).getTextContent);
					end
					break
				end
			end
		end
		switch eventNode.getElementsByTagName('origin').getLength
		case 0
			printf('** WARNING: Event ID %s (%d) has no origin!\n',eventID,evt);
		 	continue
		case 1
			originNode = eventNode.getElementsByTagName('origin').item(0);
		otherwise
			for originI = 0:eventNode.getElementsByTagName('origin').getLength - 1
				originNode = eventNode.getElementsByTagName('origin').item(originI);
				if strcmp(originNode.getAttributes().item(0).getTextContent,preferredOriginID)
					break
				end
			end
		end
		t(evt) = datenum(char(originNode.getElementsByTagName('time').item(0).getElementsByTagName('value').item(0).getTextContent),'yyyy-mm-ddTHH:MM:SS.FFF');
		d(evt,1) = str2double(originNode.getElementsByTagName('latitude').item(0).getElementsByTagName('value').item(0).getTextContent);
		d(evt,2) = str2double(originNode.getElementsByTagName('longitude').item(0).getElementsByTagName('value').item(0).getTextContent);
		if originNode.getElementsByTagName('latitude').item(0).getElementsByTagName('uncertainty').getLength && originNode.getElementsByTagName('longitude').item(0).getElementsByTagName('uncertainty').getLength
			d(evt,7) = max(str2double(originNode.getElementsByTagName('latitude').item(0).getElementsByTagName('uncertainty').item(0).getTextContent),str2double(originNode.getElementsByTagName('longitude').item(0).getElementsByTagName('uncertainty').item(0).getTextContent));
		end
		if originNode.getElementsByTagName('depth').getLength
			d(evt,3) = str2double(originNode.getElementsByTagName('depth').item(0).getElementsByTagName('value').item(0).getTextContent);
			if originNode.getElementsByTagName('depth').item(0).getElementsByTagName('uncertainty').getLength
				d(evt,8) = str2double(originNode.getElementsByTagName('depth').item(0).getElementsByTagName('uncertainty').item(0).getTextContent);
			end
		end
		if originNode.getElementsByTagName('azimuthalGap').getLength
			d(evt,5) = str2double(originNode.getElementsByTagName('quality').item(0).getElementsByTagName('azimuthalGap').item(0).getTextContent);
		end
		if originNode.getElementsByTagName('standardError').getLength
			d(evt,6) = str2double(originNode.getElementsByTagName('quality').item(0).getElementsByTagName('standardError').item(0).getTextContent);
		end
		if originNode.getElementsByTagName('horizontalUncertainty').getLength
			d(evt,7) = str2double(originNode.getElementsByTagName('horizontalUncertainty').item(0).getTextContent);
		end
		if originNode.getElementsByTagName('usedPhaseCount').getLength
			d(evt,9) = str2double(originNode.getElementsByTagName('usedPhaseCount').item(0).getTextContent);
		end
		if originNode.getElementsByTagName('evaluationMode').getLength
			c{evt,5} = char(originNode.getElementsByTagName('evaluationMode').item(0).getTextContent);
		end
	end
	if ~isempty(d)
		% applies the selection filters (dates, latitude, longitude, depth, magnitude and max intensity)
		k = find((t >= F.datelim(1) & t <= F.datelim(2)) ...
			& (isnan(d(:,1))  | isinto(d(:,1),P.LATLIM)) ...
			& (isnan(d(:,2))  | isinto(d(:,2),P.LONLIM)) ...
			& (isnan(d(:,3))  | isinto(d(:,3),P.DEPLIM)) ...
			& (isnan(d(:,4))  | isinto(d(:,4),P.MAGLIM)) ...
		);
		if ~isnan(magerr)
			d(isnan(d(:,12)),12) = magerr;
		end
		if ~isempty(magtype)
			k = find(isempty(c(:,2)));
			c(k,2) = repmat({magtype},length(k),1);
		end
		[t,kk] = sort(t(k,1));
		d = d(k(kk),:);
		c = c(k(kk),:);
		fprintf('done (%d/%d events).\n',length(t),evtCount);
	else
		fprintf('** WARNING ** no events found!\n');
	end

% -----------------------------------------------------------------------------
otherwise
	fprintf('%s: ** WARNING ** unknown format "%s" for node %s!\n',wofun,F.fmt,N.ID);
end


% =============================================================================
% applies the quality filters (1 = good, 0 = not good)
e = double( (isnan(d(:,5)) | isinto(d(:,5),P.GAPLIM)) ...
	& (isnan(d(:,6))  | isinto(d(:,6),P.RMSLIM)) ...
	& (isnan(d(:,7))  | isinto(d(:,7),P.ERHLIM)) ...
	& (isnan(d(:,8))  | isinto(d(:,8),P.ERZLIM)) ...
	& (isnan(d(:,9))  | isinto(d(:,9),P.NPHLIM)) ...
	& (isnan(d(:,10)) | isinto(d(:,10),P.CLALIM)) ...
);

% filters or purge invalid event types or status
if ~isempty(t) && (~any(cellfun(@isempty,extypes)) || ~any(cellfun(@isempty,exstatus)))
	if isok(P,'PURGE_EXCLUDED_EVENT')
		k = find(ismemberlist(c(:,3),extypes) | ismemberlist(c(:,5),exstatus));
		if ~isempty(k)
			fprintf('%s: ** WARNING ** %d excluded events have been tagged for purge.\n',wofun,length(k));
			e(k) = -1;
		end
	else
		k = find(~ismemberlist(c(:,3),extypes) & ~ismemberlist(c(:,5),exstatus));
		fprintf('%s: filtering event types "%s"...\n',wofun,strjoin(extypes,', '));
		fprintf('%s: filtering event status "%s"...\n',wofun,strjoin(exstatus,', '));
		if length(t) ~= length(k)
			fprintf('%s: ** WARNING ** %d events have been excluded from type and status.\n',wofun,length(t)-length(k));
			t = t(k,1);
			d = d(k,:);
			c = c(k,:);
			e = e(k,1);
		end
	end
end

% replaces empty type by empty string
c(cellfun(@isempty,c)) = {''};

t = t - N.UTC_DATA;

% =============================================================================
% Search for MC3 links
if isfield(N,'FID_MC3') && ~isempty(N.FID_MC3) && ~isempty(t)
	MC3 = readcfg(WO,sprintf('/etc/webobs.d/%s.conf',N.FID_MC3));
	MC3TYPES = readcfg(WO,MC3.EVENT_CODES_CONF);
	tv = datevec(t);
	tv1 = datevec(t + 1/1440); % next minute
	% reads MC3 for the corresponding months
	fdat = sprintf('%s/mc3.dat',F.ptmp);
	if exist(fdat,'file')
		delete(fdat)
	end
	% loops on the months as linear vector ym = year*12 + month-1
	for ym = (tv(1,1)*12 + tv(1,2) - 1):(tv(end,1)*12 + tv(end,2) - 1)
		y = floor(ym/12); % retrieves the year
		m = mod(ym,12) + 1; % retrieves the month
		s = wosystem(sprintf('sed ''/^$/d'' %s/%d/files/%s%d%02d.txt >> %s',MC3.ROOT,y,MC3.FILE_PREFIX,y,m,fdat),P);
	end

	if exist(fdat,'file')
		mc3 = readdatafile(fdat,17,'CommentStyle',''); % reads all events (trash included)
	end
	if exist('mc3','var') && ~isempty(mc3)
		%ID|yyyy-mm-dd|HH:MM:SS.ss|type|amplitude|duration|s|0|1||STA|0|SEFRAN3|SC3ID|image.png|op/timestamp|comment
        k = (cellfun(@str2num,mc3(:,1))>=0); % remove trash entries
        fprintf(' found %d valid mc3 entries, removed %d trash events.\n',sum(k),size(mc3,1)-sum(k));
        mc3 = mc3(k,:);
		fprintf('%s: associating %s event types and images ...',wofun,N.FID_MC3);
		nbid = 0;
		nmc3 = 0;
		nflt = 0;
		% now must process all events in a loop...
		for ii = 1:length(t)
			k = find(~cellfun(@isempty,regexp(mc3(:,13),c(ii,1))) | ~cellfun(@isempty,regexp(mc3(:,14),c(ii,1))),1);
			if ~isempty(k)
				% set as felt event if the event comment contains the code |xxN|
				if felteventcode && regexp(c{ii,4},'\|[A-Z]{2}[1-9].*\|')
					ems = str2double(regexprep(c{ii,4},'.*\|[A-Z]{2}([1-9]).*','$1'));
					d(ii,11) = max(2,ems);
					nflt = nflt + 1;
				% or the MC3 comment contains the right regexp...
				elseif ~isempty(feltcomment) && ~isempty(mc3{k,17})
					if ~isempty(regexpi(mc3{k,17},feltcomment))
						% get the maximum intensity N from a code xxN (if specified)
						ems = str2double(regexprep(mc3(k,17),'.*[A-Z]{2}([2-9]).*','$1'));
						d(ii,11) = max(2,ems);
						nflt = nflt + 1;
					end
				end
				% comment field (c(:,4)) is replaced by MC3 event type
				c{ii,4} = mc3(k,4);
				c{ii,6} = sprintf('%s/%d/images/%d%02d/%s',MC3.PATH_WEB,tv(ii,[1,1:2]),mc3{k,15});
				nbid = nbid + 1;
			else
				X = dir(sprintf('%s/%d/images/%d%02d/%d%02d%02d%02d%02d*.png',MC3.ROOT,tv(ii,[1,1:2,1:5])));
				X1 = dir(sprintf('%s/%d/images/%d%02d/%d%02d%02d%02d%02d*.png',MC3.ROOT,tv1(ii,[1,1:2,1:5])));
				X = cat(1,X,X1);
				for iii = 1:numel(X)
					k = ~cellfun(@isempty,regexp(mc3(:,15),X(iii).name));
					if any(k)
						c{ii,4} = mc3(k,4);
						c{ii,6} = sprintf('%s/%d/images/%d%02d/%s',MC3.PATH_WEB,tv(ii,[1,1:2]),X(iii).name);
						nmc3 = nmc3 + 1;
						break
					end
				end
			end
			if isfield(MC3TYPES,c{ii,4})
				c{ii,4} = MC3TYPES.(c{ii,4}{1}).Name;
			%[FB-note] it seems better to keep the undocumented event type here...
			%else
			%	c{ii,4} = '';
			end
		end
		fprintf(' found %d sc3/hypo71id, %d mc3id, %d felt.\n',nbid,nmc3,nflt);

	end
end

% applies a filter on the comment field (regexp)
%[Note] if the event has been found in MC3, comment contains the MC3 event type name
if ~isempty(incomment)
	k = ~cellfun(@isempty,regexp(c(:,4),incomment));
	if any(k)
		fprintf('%s: ** WARNING ** only %d events have been selected from comment (%s).\n',wofun,sum(k),incomment);
		t = t(k,1);
		d = d(k,:);
		c = c(k,:);
		e = e(k,1);
	end
end
% applies a filter on the comment field (case-insensitive regexp)
if ~isempty(excomment)
	k = cellfun(@isempty,regexpi(c(:,4),excomment));
	if any(k)
		fprintf('%s: ** WARNING ** %d events have been excluded from comment (%s).\n',wofun,length(t)-sum(k),excomment);
		t = t(k,1);
		d = d(k,:);
		c = c(k,:);
		e = e(k,1);
	end
end
% applies a last selection filter on MSK (may come from MC3)
k = isnan(d(:,11)) | isinto(d(:,11),P.MSKLIM);
t = t(k,1);
d = d(k,:);
c = c(k,:);
e = e(k,1);

D.t = t + P.TZ/24;
D.d = d;
D.c = c;
D.e = e;
D.CLB.nx = 12;
D.CLB.nm = {'Latitude','Longitude','Depth','Magnitude','Azimuthal Gap', 'RMS','ErH','ErZ','Phase Count','Quality','EMS98','ErMag'};
D.CLB.un = {'°','°','km','','°','s','km','km','','','',''};
