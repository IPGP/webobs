function D = readfmtdata_earthworm(WO,P,N,F)
%READFMTDATA_EARTHWORM subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: EarthWorm data file request/reading
%	data format: waveform
%	channel stream: NET = node FDSN, STA = node FID, CHA = .CLB Ch. Code, LOC = .CLB LC
%	other PROC's specific parameters with example values:
%		DATALINK_DELAY_SECONDS|10
%		DATALINK_TIMEOUT|10000
%	output fields:
%		D.t (datenum)
%		D.d (channel1 channel2 ...)
%
%
%	format 'winston'
%		type: Winston wave server data stream
%		server: P.RAWDATA (host:port)
%
%
%	Authors: François Beauducel, WEBOBS/IPGP
%	Created: 2017-06-10, in Yogyakarta (Indonesia)
%	Updated: 2018-05-25


wofun = sprintf('WEBOBS{%s}',mfilename);


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

winstonjar = field2str(WO,'WINSTON_JAVA',sprintf('%s/bin/java/winston-bin.jar',WO.ROOT_CODE));
if exist(winstonjar,'file')
	javaaddpath(winstonjar);
else
	printf('%s: ** WARNING ** cannot find the Java Winston class ("%s"). Please check WINSTON_JAVA parameter in WEBOBS.rc.\n',wofun,winstonjar);
end

% adjusts time limit with data delay
F.datelim(2) = min(F.datelim(2),P.NOW - P.TZ/24 + N.UTC_DATA - field2num(P,'DATALINK_DELAY_SECONDS',10)/86400);

fdat = sprintf('%s/%s.msd',F.ptmp,N.ID);


% =============================================================================
% selects the method to read data

switch F.fmt

% -----------------------------------------------------------------------------
case 'winston'

	if ~exist('gov.usgs.winston.server.WWSClient','class')
		error('%s: cannot find the needed class to read Winston data... Abort.\n',wofun);
	end

	ws = split(F.raw{1},':');
	if length(ws) < 2
		error('%s: RAWDATA (%s) must be in the form host:port.\n',wofun,F.raw{1});
	end
	fprintf('\n%s: connect to Winston Wave Server %s ...\n',wofun,F.raw{1});
	WWS = gov.usgs.winston.server.WWSClient(ws{1},str2num(ws{2}));
	WWS.setTimeout(field2num(P,'DATALINK_TIMEOUT',10000));

	% make a request for all channels and possible multiple calibrations periods
	cc = unique(N.CLB.nv);
	%dt = [N.CLB.dt,P.NOW]; % adds an extra value (i+1) for present time
	dt = N.CLB.dt;
	for ic = 1:length(cc)
		X(ic).t = [];
		X(ic).d = [];
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
				fprintf('%s: requesting %s.%s.%s.%s from %s to %s ...',wofun,N.FID,N.CLB.cd{kc(ii)},N.FDSN_NETWORK_CODE,N.CLB.lc{kc(ii)},datestr(t1),datestr(t2));
				dd = WWS.getRawData(N.FID,N.CLB.cd{kc(ii)},N.FDSN_NETWORK_CODE,N.CLB.lc{kc(ii)}, ...
					(t1 - datenum(1970,1,1))*86400, ...
					(t2 - datenum(1970,1,1))*86400);
				if ~isempty(dd)
					tt = linspace(dd.getStartTime,dd.getEndTime,dd.numSamples)'/86400 + datenum(1970,1,1);
					X(ic).t = cat(1,X(ic).t,tt);
					X(ic).d = cat(1,X(ic).d,dd.buffer);
					X(ic).SampleRate = dd.getSamplingRate;
					fprintf(' %d samples imported.\n',length(dd.buffer));
				else
					fprintf(' no data found.\n')
					X(ic).t = [];
					X(ic).d = zeros(0,1);
					X(ic).SampleRate = NaN;
				end
			end
		end
	end
	% after this loop structure X(i) contains all timeseries from channel i

	WWS.close;

	% To have a single vector t with matrix d, must interpolate all channels at the highest frequency sampling rate
	sf = max(cat(1,X.SampleRate));
	% final time vector is F.datelim limits or shorter
	t = (max(min(cat(1,X.t)),F.datelim(1)):1/sf/86400:min(max(cat(1,X.t)),F.datelim(2)))';
	d = nan(length(t),N.CLB.nx);
	for c = 1:N.CLB.nx
		if ~isempty(X(c).d)
			d(:,c) = interp1(X(c).t,double(X(c).d),t);
		end
	end
end
D.t = t - N.UTC_DATA;
D.d = d;

[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
D.t = D.t + P.TZ/24;
