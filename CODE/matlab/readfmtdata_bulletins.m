function [D,P] = readfmtdata_bulletins(WO,P,N,F)
%READFMTDATA_BULLETINS subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: earthquake bulletins
%	output fields:
%		D.t (datenum)
%		D.d (Uncertainty Residual Azimuth Distance TakeOff Weight Polarity TimeCorrection HorizontalSlowness HorizontalSlownessResidual BackAzimuth BackAzimuthResidual Magnitude)
%		D.c (eventID PickType Network Station Channel LocationCode MagnitudeType)
%		D.e (quality)
%
%	format 'fdsnws-event'
%		type: FDSN WebServices event request
%		filename/path: P.RAWDATA or N.RAWDATA (base URL)
%		data format: QuakeML1.2
%		node calibration: none
%
%	format 'scevtlog-xml'
%		type: SeisComP3-xml files created by scevtlog
%		filename/path: P.RAWDATA or N.RAWDATA will search for events in
%			RAWDATA/YYYY/MM/DD/eventID/eventID.last.xml
%			Note that YYYY/MM/DD isn't the event origin time, but the event creation time
%		data format: sc3ml
%		node calibration: none
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2017-01-30, in Paris (France)
%	Updated: 2017-08-02

wofun = sprintf('WEBOBS{%s}',mfilename);

% filters
for fn = {'LAT','LON','MAG','DEP','GAP','RMS','ERH','ERZ','NPH'}
	fd = [fn{:},'LIM'];
	if ~isfield(P,fd)
		P.(fd) = '-Inf,Inf';
	end
	if ischar(P.(fd))
		P.(fd) = str2vec(P.(fd));
	end
end
if isfield(P,'EVENTTYPE_EXCLUDED_LIST')
	extypes = split(P.EVENTTYPE_EXCLUDED_LIST,',');
else
	extypes = '';
end
if isfield(P,'EVENTSTATUS_EXCLUDED_LIST')
	exstatus = split(P.EVENTSTATUS_EXCLUDED_LIST,',');
else
	exstatus = '';
end


% =============================================================================
switch F.fmt

% -----------------------------------------------------------------------------
case 'fdsnws-bulletin'

	setenv('LD_LIBRARY_PATH', '');	% needed to wget system call
	nbmax = 1000;	% max number of )event for a request (due to possible memory problems in xmlread)
	wsreq = sprintf('format=xml&orderby=time&limit=%d',nbmax);
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
	t = []; d = []; c = [];
	while evtCount == nbmax
		fdat = sprintf('%s/req.xml',F.ptmp);
		%[FBnote]: xmlread(url) often freezes with bad internet connection...
		%quakeml = xmlread(sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw,wsreq,wsreqstime,wsreqetime));
		%[FBnote]: urlread() ok but options charset and timeout only available after R2012b...
		%xml = urlread(sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw,wsreq,wsreqstime,wsreqetime),'Charset','UTF-8','Timeout',60);
		%xml = urlread(sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=false&%s%s%s',F.raw,wsreq,wsreqstime,wsreqetime));
		url = sprintf('%s&includeallmagnitudes=false&includeallorigins=false&includearrivals=true&%s%s%s',F.raw{1},wsreq,wsreqstime,wsreqetime);
		s = wosystem(sprintf('wget "%s" -O %s -t 1 -T 60',url,fdat),P);
		if s ~= 0
			break;
		end
		%fid = fopen(fdat,'wt');  fprintf(fid,'%s',xml);  fclose(fid);
		quakeml = xmlread(fdat);
		fprintf('.');
		evtCount = quakeml.getElementsByTagName('event').getLength;
		tt = []; dd = []; cc = [];
		magnitude = NaN; magnitudeType = '';
		k = 1;
		for evt = 1:evtCount
			eventNode =  quakeml.getElementsByTagName('event').item(evt-1);
			originNode = eventNode.getElementsByTagName('origin').item(0);
			pickList = eventNode.getElementsByTagName('pick');
			eventID = regexprep(char(eventNode.getAttributes().item(0).getTextContent),'.*[/=]',''); % takes the last word (eventid)...
			if eventNode.getElementsByTagName('magnitude').getLength
				magnitude = str2double(eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('mag').item(0).getElementsByTagName('value').item(0).getTextContent);
				if eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('type').getLength
					magnitudeType = char(eventNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('type').item(0).getTextContent);
				end
			end

			for arrival = 1:originNode.getElementsByTagName('arrival').getLength;
				arrivalNode = originNode.getElementsByTagName('arrival').item(arrival-1);
				pickID = char(arrivalNode.getElementsByTagName('pickID').item(0).getTextContent);
				for pk = 1:pickList.getLength
					if pickList.item(pk-1).hasAttributes() && strcmp(pickList.item(pk-1).getAttributeNode('publicID').getValue,pickID)
						tt = [tt; nan(1,1)];
						dd = [dd; nan(1,13)];
						cc = [cc; cell(1,7)];
						cc{k,1} = eventID;
						cc{k,7} = magnitudeType;
						dd(k,13) = magnitude;
						pickNode = pickList.item(pk-1);
						tt(k) = datenum(char(pickNode.getElementsByTagName('time').item(0).getElementsByTagName('value').item(0).getTextContent),'yyyy-mm-ddTHH:MM:SS.FFF');
						if pickNode.getElementsByTagName('time').item(0).getElementsByTagName('lowerUncertainty').getLength
							dd(k,1) = str2double(pickNode.getElementsByTagName('time').item(0).getElementsByTagName('lowerUncertainty').item(0).getTextContent);
						end
						if pickNode.getElementsByTagName('time').item(0).getElementsByTagName('upperUncertainty').getLength
							dd(k,1) = dd(k,1) + str2double(pickNode.getElementsByTagName('time').item(0).getElementsByTagName('upperUncertainty').item(0).getTextContent);
						end
						if pickNode.getElementsByTagName('time').item(0).getElementsByTagName('uncertainty').getLength
							dd(k,1) = str2double(pickNode.getElementsByTagName('time').item(0).getElementsByTagName('uncertainty').item(0).getTextContent);
						end
						if pickNode.getElementsByTagName('horizontalSlowness').getLength
							dd(k,9) = str2double(pickNode.getElementsByTagName('horizontalSlowness').item(0).getTextContent);
						end
						if pickNode.getElementsByTagName('backazimuth').getLength
							dd(k,11) = str2double(pickNode.getElementsByTagName('backazimuth').item(0).getTextContent);
						end
						if pickNode.getElementsByTagName('polarity').getLength
							if strcmp(pickNode.getElementsByTagName('polarity').item(0).getTextContent,'positive')
								dd(k,7) = 1;
							elseif strcmp(pickNode.getElementsByTagName('polarity').item(0).getTextContent,'negative')
								dd(k,7) = -1;
							end
						else
							dd(k,7) = 0;
						end
						if pickNode.getElementsByTagName('waveformID').item(0).hasAttribute('networkCode')
							cc{k,3} = char(pickNode.getElementsByTagName('waveformID').item(0).getAttributeNode('networkCode').getValue);	% Network code
						end
						if pickNode.getElementsByTagName('waveformID').item(0).hasAttribute('stationCode')
							cc{k,4} = char(pickNode.getElementsByTagName('waveformID').item(0).getAttributeNode('stationCode').getValue);	% Station code
						end
						if pickNode.getElementsByTagName('waveformID').item(0).hasAttribute('channelCode')
							cc{k,5} = char(pickNode.getElementsByTagName('waveformID').item(0).getAttributeNode('channelCode').getValue);	% Channel code
						end
						if pickNode.getElementsByTagName('waveformID').item(0).hasAttribute('locationCode')
							cc{k,6} = char(pickNode.getElementsByTagName('waveformID').item(0).getAttributeNode('locationCode').getValue);	% Location code
						end
						cc{k,2} = char(arrivalNode.getElementsByTagName('phase').item(0).getTextContent);
						if arrivalNode.getElementsByTagName('timeResidual').getLength
							dd(k,2) = str2double(arrivalNode.getElementsByTagName('timeResidual').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('azimuth').getLength
							dd(k,3) = str2double(arrivalNode.getElementsByTagName('azimuth').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('distance').getLength
							dd(k,4) = str2double(arrivalNode.getElementsByTagName('distance').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('takeoffAngle').getLength
							dd(k,5) = str2double(arrivalNode.getElementsByTagName('takeoffAngle').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('timeWeight').getLength
							dd(k,6) = str2double(arrivalNode.getElementsByTagName('timeWeight').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('timeCorrection').getLength
							dd(k,8) = str2double(arrivalNode.getElementsByTagName('timeCorrection').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('horizontalSlownessResidual').getLength
							dd(k,10) = str2double(arrivalNode.getElementsByTagName('horizontalSlownessResidual').item(0).getTextContent);
						end
						if arrivalNode.getElementsByTagName('backazimuthResidual').getLength
							dd(k,12) = str2double(arrivalNode.getElementsByTagName('backazimuthResidual').item(0).getTextContent);
						end
						k = k + 1;
					end
				end
			end
		end
		t = [t;tt];
		d = [d;dd];
		c = [c;cc];

		if evtCount == nbmax
			% next request will end 1 second before the first existing data
			wsreqetime = sprintf('&endtime=%04d-%02d-%02dT%02d:%02d:%02.0f',datevec(min(t(:)) - 1/86400));
		end
	end
	fprintf(' done (%d phases).\n',length(t));

	if ~quakeml.getElementsByTagName('event').getLength
		fprintf('** WARNING ** no events found!\n');
	end

% -----------------------------------------------------------------------------
case 'scevtlog-xml-bulletin'

	fdat = sprintf('%s/%s.list',F.ptmp,N.ID);

	% makes a single and homogeneous space-separated numeric file from the raw data
	for day = floor(F.datelim(1)):floor(F.datelim(2))
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
	d = nan(evtCount,11);
	c = repmat({''},evtCount,6);
	for evt = 1:evtCount
		sc3ml = xmlread(list{1}{evt});
		eventNode = sc3ml.getElementsByTagName('EventParameters').item(0);
		c{evt,1} = char(eventNode.getElementsByTagName('event').item(0).getAttributes().item(0).getTextContent);
		childList = eventNode.getElementsByTagName('event').item(0).getChildNodes;
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
		if eventNode.getElementsByTagName('origin').getLength == 1
			originNode = eventNode.getElementsByTagName('origin').item(0);
		else
			for originI = 0:eventNode.getElementsByTagName('origin').getLength - 1
				originNode = eventNode.getElementsByTagName('origin').item(originI);
				if strcmp(originNode.getAttributes().item(0).getTextContent,preferredOriginID)
					break;
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
		if eventNode.getElementsByTagName('magnitude').getLength
			for k = 0:eventNode.getElementsByTagName('magnitude').getLength - 1
				magnitudeNode = eventNode.getElementsByTagName('magnitude').item(k);
				if magnitudeNode.hasAttributes() && strcmp(magnitudeNode.getAttributes().item(0).getTextContent,preferredMagnitudeID)
					d(evt,4) = str2double(magnitudeNode.getElementsByTagName('magnitude').item(0).getElementsByTagName('value').item(0).getTextContent);
					c{evt,2} = char(magnitudeNode.getElementsByTagName('type').item(0).getTextContent);
					break;
				end
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
		if originNode.getElementsByTagName('evaluationMode').getLength
			c{evt,5} = char(originNode.getElementsByTagName('evaluationMode').item(0).getTextContent);
		end
	end
	if ~isempty(d)
		% applies the selection filters (dates, latitude, longitude, depth, magnitude and max intensity)
		k = find((t >= F.datelim(1) & t <= F.datelim(2)) ...
			& ((isnan(d(:,1))  & all(~isfinite(P.LATLIM))) | (d(:,1)  >= min(P.LATLIM) & d(:,1)  <= max(P.LATLIM))) ...
			& ((isnan(d(:,2))  & all(~isfinite(P.LONLIM))) | (d(:,2)  >= min(P.LONLIM) & d(:,2)  <= max(P.LONLIM))) ...
			& ((isnan(d(:,3))  & all(~isfinite(P.DEPLIM))) | (d(:,3)  >= min(P.DEPLIM) & d(:,3)  <= max(P.DEPLIM))) ...
			& ((isnan(d(:,4))  & all(~isfinite(P.MAGLIM))) | (d(:,4)  >= min(P.MAGLIM) & d(:,4)  <= max(P.MAGLIM))) ...
			& ((isnan(d(:,11)) & all(~isfinite(P.MSKLIM))) | (d(:,11) >= min(P.MSKLIM) & d(:,11) <= max(P.MSKLIM))) ...
		);
		[t,kk] = sort(t(k,1));
		d = d(k(kk),:);
		c = c(k(kk),:);
		fprintf('done (%d/%d events).\n',length(t),evtCount);
	else
		fprintf('** WARNING ** no events found!\n');
	end

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
);

% filters or purge invalid event types or status
if ~isempty(extypes) || ~isempty(exstatus)
	if isok(P,'PURGE_EXCLUDED_EVENT')
		k = find(ismemberlist(c(:,3),extypes) | ismemberlist(c(:,5),exstatus));
		if ~isempty(k)
			fprintf('%s: ** WARNING ** %d excluded events have been tagged for purge.\n',wofun,length(k));
			e(k) = -1;
		end
	else
		k = find(~ismemberlist(c(:,3),extypes) & ~ismemberlist(c(:,5),exstatus));
		if length(t) ~= length(k)
			fprintf('%s: ** WARNING ** %d events have been excluded.\n',wofun,length(t)-length(k));
			t = t(k,1);
			d = d(k,:);
			c = c(k,:);
			e = e(k,1);
		end
	end
end

D.t = t - N.UTC_DATA;

% =============================================================================
% Search for MC3 links
if isfield(N,'FID_MC3') && ~isempty(N.FID_MC3) && ~isempty(t)
	MC3 = readcfg(WO,sprintf('/etc/webobs.d/%s.conf',N.FID_MC3));
	MC3TYPES = readcfg(WO,MC3.EVENT_CODES_CONF);
	tv = datevec(D.t);
	tv1 = datevec(D.t + 1/1440); % next minute
	% reads MC3 for the corresponding years
	fdat = sprintf('%s/mc3.dat',F.ptmp);
	s = wosystem(sprintf('sed ''/^$/d'' %s/{%d..%d}/files/%s??????.txt > %s',MC3.ROOT,tv([1,end],1),MC3.FILE_PREFIX,fdat),P);
	if s==0
		mc3 = readdatafile(fdat,17,'CommentStyle',''); % reads all events (trash included)
		fprintf('%s: associating %s event types and images ...',wofun,N.FID_MC3);
		nsc3 = 0;
		nh71 = 0;
		nmc3 = 0;
		for ii = 1:length(t)
			k1 = find(~cellfun(@isempty,regexp(mc3(:,13),c(ii,1))));
			k2 = find(~cellfun(@isempty,regexp(mc3(:,14),c(ii,1))));
			if ~isempty(k1)
				c{ii,4} = mc3(k1,4);
				c{ii,6} = sprintf('%s/%d/images/%d%02d/%s',MC3.PATH_WEB,tv(ii,[1,1:2]),mc3{k1,15});
				nh71 = nh71 + 1;
			elseif ~isempty(k2)
				c{ii,4} = mc3(k2,4);
				c{ii,6} = sprintf('%s/%d/images/%d%02d/%s',MC3.PATH_WEB,tv(ii,[1,1:2]),mc3{k2,15});
				nsc3 = nsc3 + 1;
			else
				X = dir(sprintf('%s/%d/images/%d%02d/%d%02d%02d%02d%02d*.png',MC3.ROOT,tv(ii,[1,1:2,1:5])));
				X1 = dir(sprintf('%s/%d/images/%d%02d/%d%02d%02d%02d%02d*.png',MC3.ROOT,tv1(ii,[1,1:2,1:5])));
				X = cat(1,X,X1);
				for iii = 1:numel(X)
					k = find(~cellfun(@isempty,regexp(mc3(:,15),X(iii).name)));
					if ~isempty(k)
						c{ii,4} = mc3(k,4);
						c{ii,6} = sprintf('%s/%d/images/%d%02d/%s',MC3.PATH_WEB,tv(ii,[1,1:2]),X(iii).name);
						nmc3 = nmc3 + 1;
						break
					end
				end
			end
			if isfield(MC3TYPES,c{ii,4})
				c{ii,4} = MC3TYPES.(c{ii,4}{1}).Name;
			else
				c{ii,4} = '';
			end
		end
		fprintf(' found %d sc3id, %d hypo71id and %d mc3id.\n',nsc3,nh71,nmc3);
	end
end

D.d = d;
D.c = c;
D.e = e;
D.CLB.nx = 12;
D.CLB.nm = {'Uncertainty' 'Residual','Azimuth','Distance','TakeOff','Weight', 'Polarity','Time Correction','Horizontal Slowness','Horizontal Slowness Residual','Back Azimuth','Back Azimuth Residual'};
D.CLB.un = {'s' 's','°','°','°','','','s','s/°','s/°','°','°'};
D.t = D.t + P.TZ/24;

