function D = readfmtdata_gnss(WO,P,N,F)
%READFMTDATA_GNSS subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: GNSS positions
%	output fields:
%		D.t (datenum)
%		D.d (Eastern Northern Vertical Orbit)
%		D.e (Eastern Northern Vertical NaN)
%
%	format 'globkval'
%		type: GAMIT/GLOBK GNSS results using VAL summary file
%		filename: P.RAWDATA/VAL.xxxx
%		data format: VAL file GAMIT/GLOBK output format
%		node calibration: no .CLB file or 3 components (East, North, Up) in meters
%
%	format 'globkorg'
%		type: GAMIT/GLOBK GNSS results using .org daily files
%		filename: P.RAWDATA (use full path and wildcards to point to all .org files)
%		data format: .org files GAMIT/GLOBK output format
%		node calibration: no .CLB file or 3 components (East, North, Up) in meters
%
%	format 'gipsy'
%		type: JPL/GIPSY GNSS .tdp results ITRF08
%		filename: P.RAWDATA/FID/YYYY/FID/YYYY-MM-DD.FID.tdp*
%		data format: extract from tdp_final output file (grep "STA [XYZ]" lines)
%		node calibration: no .CLB file or 4 components (East, North, Up) in meters and (Orbit)
%
%	format 'gipsyx'
%		type: JPL/GipsyX GNSS .tdp results ITRF08
%		filename: P.RAWDATA/FID/YYYY/FID/YYYY-MM-DD.FID.tdp*
%		data format: extract from SmoothFinal.tdp output file (grep "Station.SSSS.State.pos.[XYZ]" lines)
%		node calibration: no .CLB file or 4 components (East, North, Up) in meters and (Orbit)
%
%	format 'usgs-rneu'
%		type: USGS GPS results ITRF08
%		filename/url: P.RAWDATA (use $FID to point the right file/url)
%		data format: ascii
%		node calibration: no .CLB file or 4 components (East, North, Up) in meters and (Orbit)
%
%
%	Authors: François Beauducel and Jean-Bernard de Chabalier, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2019-02-12

wofun = sprintf('WEBOBS{%s}',mfilename);


switch F.fmt
% -----------------------------------------------------------------------------
case 'globkval'

	% extracts components from VAL file
	s = split(F.raw{1},'/');
	chantier = s{end};
	fraw = sprintf('%s/VAL.%s',F.raw{1},chantier);

	fdat = sprintf('%s/%s.dat',F.ptmp,N.ID);
	wosystem(sprintf('rm -f %s',fdat),P);
	lfid = split(N.FID,',');
	if exist(fraw,'file')

		% loop on potential list of dataIDs
		for nn = lfid(:)'
			nfid = strtrim(nn{:});
			for c = {'E','N','U'}
				wosystem(sprintf('sed -n "/^%s_.PS to %s/,/^Wmean/p" %s | sed -e "/^Wmean.*$/d;/^%s_.PS.*$/d;/^\\s*$/d" | sort -k1 -k2 -k3 -k4 -k5 -n > %s/%s_%s.dat',nfid,c{:},fraw,nfid,F.ptmp,nfid,c{:}),P);
			end
			% concatenates to a single file
			wosystem(sprintf('paste %s/%s_?.dat >> %s',F.ptmp,nfid,fdat),P);
		end
	else
		fprintf('%s: ** WARNING ** Raw data file %s not found.\n',wofun,fraw);
	end

	% load the file
	if exist(fdat,'file')
		dd = load(fdat);
	else
		dd = [];
	end
	if ~isempty(dd)
		[t,k] = sort(datenum([dd(:,1:5),zeros(size(dd,1),1)]));
		d = [dd(k,[6,15,24]),zeros(size(dd,1),1)]; % 4th column are zeros for "final orbit"
		e = dd(k,[7,16,25]);
		fprintf('%d data imported.\n',size(dd,1));
	else
		fprintf('no data found!\n')
		t = [];
		d = [];
		e = [];
	end
	% IRTF year
	%itrf = '';
	%f = sprintf('%s/gsoln.templates/globk_comb.cmd',F.fmt);
	%if exist(f,'file')
	%	[s,w] = system(sprintf('grep apr_file %s | sed "s/.*tables\\///" | sed "s/\\.apr//"',f));
	%	if s==0
	%		 itrf = upper(strtrim(w));
	%	end
	%end
	%D.ITRF_YEAR = itrf;

% -----------------------------------------------------------------------------
case {'gipsy','gipsy-tdp','gipsyx'}

	fdat = sprintf('%s/%s.dat',F.ptmp,N.ID);
	wosystem(sprintf('rm -f %s',fdat),P);
	lfid = split(N.FID,',');
	orbits = {'tdp','tdp.ql*','tdp.ultra'};
	tv = datevec(F.datelim);
	ylim = tv(1:2);

	% loop on potential list of dataIDs
	for nn = 1:length(lfid)	
		nfid = strtrim(lfid{nn});

		switch F.fmt
		case 'gipsyx'
			grepstr = [nfid,'.State.Pos.'];
			awkstr = '$1,$3,$4';
			kmfact = 1;
		otherwise
			grepstr = 'STA ';
			awkstr = '$1,$3,$4';
			kmfact = 1000;
		end
	
		if any(isnan(ylim))
			% gets the list of existing year directories
			Z = dir(sprintf('%s/%s/',F.raw{nn},nfid));
			s = cellstr(char(Z.name));
			ylist = str2double(s(cat(1,Z.isdir)))';
			ylist = ylist(~isnan(ylist));
		else
			ylist = ylim(1):ylim(2);
		end
		for y = ylist	% loop on years
			fprintf('.');
			for o = 1:length(orbits)	% loop on orbits
				for c = {'X','Y','Z'}	% loop on components
					wosystem(sprintf('grep -sh "%s%s" %s/%s/%4d/*.%s | awk ''{print %s,%d}'' >> %s/%s.%s', ...
						grepstr,c{1},F.raw{nn},nfid,y,orbits{o},awkstr,o-1,F.ptmp,nfid,c{1}),P);
				end
			end
		end
		s = wosystem(sprintf('paste %s/%s.{X,Y,Z} >> %s',F.ptmp,nfid,fdat),P);
		if s
			fprintf('%s: ** WARNING ** no data found!\n',wofun);
		end
	end

	% load the file
	if exist(fdat,'file')
		dd = load(fdat);
	else
		dd = [];
	end
	if ~isempty(dd)
		% converts GPS J2000 time to datenum
		t = dd(:,1)/86400 + datenum(2000,1,1,12,0,0);
		% converts cartesian geocentric (X,Y,Z) to UTM, estimating errors
		[enu,e] = cart2utm(dd(:,[2,6,10])*kmfact,dd(:,[3,7,11])*kmfact);
		d = [enu,dd(:,4)];
		% minimum decent error is 1 mm (!)
		e(e<1e-3) = 1e-3;
		fprintf(' %d data imported.\n',size(dd,1));
	else
		fprintf(' no data found!\n')
		t = [];
		d = [];
		e = [];
	end
	%D.ITRF_YEAR = 'ITRF08';

% -----------------------------------------------------------------------------
case 'usgs-rneu'

	fdat = sprintf('%s/%s.dat',F.ptmp,N.ID);
	wosystem(sprintf('rm -f %s',fdat),P);
	for a = 1:length(F.raw)
		fraw = F.raw{a};
		if strncmpi('http',fraw,4)
			s = wosystem(sprintf('curl "%s" | awk ''{print $1,$3,$4,$5,$6,$7,$8,$9}'' | sed -e ''s/rrr/0/g;s/ppp/1/g'' >> %s',fraw,fdat),P);
			if s ~= 0
				break;
			end
		elseif exist(fraw,'file')
			% extracts necessary data and replaces orbit with 0 (rrr) and 1 (ppp)
			wosystem(sprintf('awk ''{print $1,$3,$4,$5,$6,$7,$8,$9}'' %s | sed -e ''s/rrr/0/g;s/ppp/1/g'' >> %s',fraw,fdat),P);
		else
			fprintf('%s: ** WARNING ** Raw data "%s" not found.\n',wofun,fraw);
		end
	end

	% load the file
	if exist(fdat,'file')
		dd = load(fdat);
	else
		dd = [];
	end
	if ~isempty(dd)
		ty = floor(dd(:,1)/1e4);
		tm = floor(dd(:,1)/1e2) - ty*1e2;
		td = dd(:,1) - ty*1e4 - tm*1e2;
		t = datenum(ty,tm,td,12,0,0);	% date is YYYYMMDD and we force time to 12:00:00
		d = [dd(:,[3,2,4])/1e3,dd(:,5)];	% North(mm),East(mm),Up(mm),Orbit => E(m),N(m),U(m),O
		e = dd(:,[7,6,8])/1e3;
		fprintf('%d data imported.\n',size(dd,1));
	else
		fprintf('no data found!\n')
		t = [];
		d = [];
		e = [];
	end

% -----------------------------------------------------------------------------
otherwise
	fprintf('%s: ** WARNING ** unknown format "%s" for node %s!\n',wofun,F.fmt,N.ID);
end

% NODE's data timestamp converted in UT
D.t = t - N.UTC_DATA;
D.d = d;
D.e = e;

if N.CLB.nx ~= 4
	D.CLB.nx = 4;
	D.CLB.nm = {'Eastern','Northern','Vertical','Orbit'};
	D.CLB.un = {'m','m','m',''};
else
	[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
end
D.t = D.t + P.TZ/24;

