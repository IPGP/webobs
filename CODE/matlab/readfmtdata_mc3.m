function [D,P] = readfmtdata_mc3(WO,P,N,F)
%READFMTDATA_MC3 subfunction of readfmtdata.m
%
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: MainCourante events catalog
%	output fields:
%		D.t (datenum)
%		D.d (MC_eventID MC_Duration MC_S-P MC_Magnitude Latitude Longitude Depth Magnitude Azimuthal_Gap RMS ErH ErZ Phase_Count Quality EMS98 ErMag)
%		D.c (MC_EventType eventID MagnitudeType EventType Comment Status)
%		D.e (quality)
%       FID : MC3_Name
%		data format: MC3
%       #id|date|time|type|amplitude|duration|unit|dur_sat|number|s-p|station|arrival|suds|qml|png|oper|comment|origin
%		node specific variables: none
%		node calibration: none
%
%
%	Authors: Fran?ois Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2019-01-21, in Paris (France)
%	Updated: 2020-04-14

wofun = sprintf('WEBOBS{%s}',mfilename);

% filters
for fn = {'LAT','LON','DEP','MAG'}
	fd = [fn{:},'LIM'];
	if ~isfield(P,fd) || numel(P.(fd)) ~= 2
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

excomment = field2str(P,'EVENTCOMMENT_EXCLUDED_REGEXP');

if isfield(P,'MC_EVENTTYPE_LIST')
    incMCtypes = split(P.MC_EVENTTYPE_LIST,',');
else
    incMCtypes = '';
end


% =============================================================================
% reads MC3 configuration
conf = sprintf('/etc/webobs.d/%s.conf',N.FID);
if exist(conf,'file')
	MC3 = readcfg(WO,conf);
else
	error('%s: MC3 configuration file {%s:FID} "%s" does not exists.',wofun,N.ID,N.FID);
end
MC3TYPES = readcfg(WO,MC3.EVENT_CODES_CONF);
% durations conf is a former file format without '=key' header: it cannot be read with readcfg
ss = textscan(fileread(MC3.DURATIONS_CONF),'%s%s%n','CommentStyle','#','Delimiter','|');
for i = 1:length(ss{1})
	MC3DURATIONS.(ss{1}{i}) = ss{3}(i);
end

Pvel = field2num(MC3,'P_WAVE_VELOCITY',6);
VpVs = field2num(MC3,'VP_VS_RATIO',1.75);

% =============================================================================
% reads MC3 for the corresponding years
fdat = sprintf('%s/mc3.dat',F.ptmp);
tv = datevec(F.datelim);
s = wosystem(sprintf('sed ''/^$/d'' %s/{%d..%d}/files/%s??????.txt > %s',MC3.ROOT,tv(:,1),MC3.FILE_PREFIX,fdat),P);
if s==0
    mc3 = readdatafile(fdat,17,'CommentStyle',''); % reads all events (trash included)
    k = find(cellfun(@str2num,mc3(:,1))>=0); % remove trash entries
    fprintf(' found %d valid mc3 entries, removed %d trash events.\n',size(k,1),size(mc3,1)-size(k,1));
    mc3 = mc3(k,:);
    fprintf(' found %d mc3 events (including multiple).\n',sum(cellfun(@str2num,mc3(:,9))));
    Nmc3 = size(mc3,1);
    k=cellfun(@isempty,mc3); % search empty strings and replace by NaN
    k(:,1:5)=false; % only work on columns 6 to 10
    k(:,11:end)=false;
    mc3(k)={'NaN'};
    k = find(cellfun(@str2num,mc3(:,9))>1); % search entries with more than one event
    mc3 = [mc3; repmat({''},sum(cellfun(@str2num,mc3(k,9)))-length(k),size(mc3,2))]; % expand mc3 by number of events
    j = Nmc3 + 1;
    for i = 1:length(k) % duplicate entries when more than one event
        n = cellfun(@str2num,mc3(k(i),9)) - 1;
        mc3(j:j+n-1,:) = repmat(mc3(k(i),:),n,1);
        mc3(j:j+n-1,6) = repmat({'NaN'},n,1);
        mc3(j:j+n-1,8) = repmat({'NaN'},n,1);
        mc3(j:j+n-1,9) = repmat({'1'},n,1);
        mc3(k(i),9) = {'1'};
        mc3(j:j+n-1,10) = repmat({'NaN'},n,1);
        mc3(j:j+n-1,[13:14]) = repmat({''},n,2);
        j = j + n;
    end
    t = datenum(datevec(strcat(mc3(:,2),{' '},mc3(:,3)),'YYYY-mm-dd HH:MM:SS.FFF'));
    d = nan(length(t),16);
    c = cell(length(t),7);
    e = nan(length(t),1);
    d(:,1) = cellfun(@str2num,mc3(:,1));
    d(:,3) = cellfun(@str2num,mc3(:,10));

    for k = 1:length(t)
        % duration in seconds
        d(k,2) = cellfun(@str2num,mc3(k,6)) * MC3DURATIONS.(mc3{k,7});
        % hypocentral distance
        if ~isnan(d(k,3))
            dist = Pvel*d(k,3)/(VpVs-1);
        end
        % duration magnitude if event type allows
        switch str2double(MC3TYPES.(mc3{k,4}).Md)
            case 1
                if (~isnan(d(k,3))) && (~isnan(d(k,2)))
                    dist = Pvel*d(k,3)/(VpVs-1);
                    d(k,4) = -0.87 + 2*log10(d(k,2)) + 0.0035*dist;
                end
            case 0
                if ~isnan(d(k,3))
                    dist = Pvel*d(k,3)/(VpVs-1);
                else
                    dist = 0;
                end
                if ~isnan(d(k,2))
                    d(k,4) = -0.87 + 2*log10(d(k,2)) + 0.0035*dist;
                end
        end
    end
    c(:,1) = mc3(:,4);
end

% =============================================================================
% reads scevtlog-xml catalog format
% search entries matching scevetlog-xml format
fprintf('%s: reads associated scevtlog-xml catalog... ',wofun);
x = 0;
k = find(~cellfun(@isempty,regexp(mc3(:,14),'[0-9]{4}/[0-9]{2}/[0-9]{2}/.+')));
if ~isempty(k)
    SC3 = F;
    SC3.raw = {MC3.SC3_EVENTS_ROOT};
    SC3.fmt = 'scevtlog-xml';
    sc3ids = split(mc3(k,14),'/');
    sc3ids = horzcat(sc3ids{:});
    Pquake = P;
%     Pquake.SC3_LISTEVT = strjoin(sc3ids(4,:),',');
    D = readfmtdata_quake(WO,Pquake,N,SC3);
    for kk = 1:length(k)
        j = find(~cellfun(@isempty,strfind(D.c(:,1),char(sc3ids(4,kk)))));
        if ~isempty(j)
            d(k(kk),5:16) = D.d(j(1),:);
            c(k(kk),2:7) = D.c(j(1),:);
            e(k(kk)) = e(j(1));
	    x = x + 1;
        end
    end
    clear D;
    clear SC3;
end
fprintf('done (%d events found).\n',x);

% =============================================================================
% reads fdsnws-event catalog format
% search entries matching fdsnws-event format
fprintf('%s: reads associated fdsnws-event catalog... ',wofun);
x = 0;
k = find(~cellfun(@isempty,regexp(mc3(:,14),'://')));
if ~isempty(k)
    qmlids = cellfun(@(x)regexp(x,'://','split'),mc3(k,14),'UniformOutput',false);
    qmlids = vertcat(qmlids{:});
    evtids = qmlids(:,2);
    fdsnws_src = unique(qmlids(:,1));
    for i = 1:length(fdsnws_src)    % iterate over different fdsnws-event servers
        FDSNWS = F;
        if ~isempty(fdsnws_src{i})
            %[FBwas:]FDSNWS.raw = split({MC3.(sprintf('FDSNWS_EVENTS_URL_%s',fdsnws_src{i}))},'?');
            FDSNWS.raw = split(MC3.(['FDSNWS_EVENTS_URL_',fdsnws_src{i}]),'?');
        else
            %[FBwas:]FDSNWS.raw = split({MC3.FDSNWS_EVENTS_URL},'?');
            FDSNWS.raw = split(MC3.FDSNWS_EVENTS_URL,'?');
        end
        FDSNWS.raw = {sprintf('%s?',FDSNWS.raw{1})};
        FDSNWS.fmt = 'fdsnws-event';
        D = readfmtdata_quake(WO,P,N,FDSNWS);
	for kk = 1:length(k)
	        j = find(~cellfun(@isempty,strfind(D.c(:,1),char(qmlids(kk,2)))));
	        if ~isempty(j)
	            d(k(kk),5:16) = D.d(j(1),:);
	            c(k(kk),2:7) = D.c(j(1),:);
	            e(k(kk)) = e(j(1));
		    x = x + 1;
	        end
        end
        clear FDSNWS;
        clear D;
    end
end
fprintf('done (%d events found).\n',x);

% =============================================================================
% applies the quality filters (1 = good, 0 = not good)
e = double(	isinto(d(:,5),P.LATLIM) ...
	& isinto(d(:,6),P.LONLIM) ...
	& isinto(d(:,7),P.DEPLIM) ...
	& isinto(d(:,8),P.MAGLIM) ...
);

% select on MC event type
if ~isempty(incMCtypes)
    k = find(ismemberlist(c(:,1),incMCtypes));
    fprintf('%s: selecting only MCeventTypes "%s"...\n',wofun,strjoin(incMCtypes,', '));
    if length(t) ~= length(k)
        fprintf('%s: ** WARNING ** %d events have been selected from MC EventType.\n',wofun,length(k));
        t = t(k,1);
        d = d(k,:);
        c = c(k,:);
        e = e(k,1);
    end
end

% remove catalog values for invalid event types or status
if ~isempty(extypes) || ~isempty(exstatus)
    k = find(~ismemberlist(c(:,4),extypes) & ~ismemberlist(c(:,6),exstatus));
    fprintf('%s: filtering event types "%s"...\n',wofun,strjoin(extypes,', '));
    fprintf('%s: filtering event status "%s"...\n',wofun,strjoin(exstatus,', '));
    if length(t) ~= length(k)
        fprintf('%s: ** WARNING ** %d events have been excluded from type and status.\n',wofun,length(t)-length(k));
        d(k,5:16) = NaN;
        c(k,2:7) = cell(length(k),6);
        e = e(k,1);
    end
end

% replaces empty type by empty string
c(cellfun(@isempty,c)) = {''};

t = t - N.UTC_DATA;


D.t = t + P.TZ/24;
D.d = d;
D.c = c;
D.e = e;
D.CLB.nx = 16;
D.CLB.nm = {'MC_eventID','MC_Duration','MC_S-P','MC_Magnitude','Latitude','Longitude','Depth','Magnitude','Azimuthal Gap', 'RMS','ErH','ErZ','Phase Count','Quality','EMS98','ErMag'};
D.CLB.un = {'','s','s','','?','?','km','','?','s','km','km','','','',''};
