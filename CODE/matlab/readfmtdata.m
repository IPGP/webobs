function [D,P] = readfmtdata(WO,P,N)
%READFMTDATA Read formatted data file.
%	D=READFMTDATA(WO,P,N) imports data of proc P (structure from READPROC), in the preset format
%	defined by P.RAWFORMAT and P.RAWDATA or associated form P.FORM, for proc's nodes N 
%	(structure from READPROC or READNODES) and returns a structure D with:
%		D.t = time vector in DATENUM format. D.t will be expressed in P.TZ time zone.
%		D.r = raw data matrix
%		D.d = calibrated data matrix
%		D.e = error matrix
%		D.CLB = calibration matrix
%		D.(...) = any other fields specific to a format.
%
%	[D,P] = READFMTDATA(...) returns an updated structure P (some formats may add or update fields).
%
%	PROC's parameters P.RAWFORMAT and P.RAWDATA apply to all associated NODES, excepted if those 
%	parameters are defined into the NODE itself.
%
%	The RAWFORMAT string is case insensitive.
%
%	List of formats selectable by users must be set in CODE/etc/rawformats.conf
%
%
%	Authors: Fran?ois Beauducel, Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2013-12-29, in Guadeloupe, French West Indies
%	Updated: 2019-12-24

wofun = sprintf('WEBOBS{%s}',mfilename);

% creates temporary directory
F.ptmp = sprintf('%s/%s/%s',WO.PATH_TMP_WEBOBS,P.SELFREF,randname(16));
wosystem(sprintf('mkdir -p %s',F.ptmp));

if isfield(P,'FORM')

	D = readfmtdata_woform(WO,P,N);

else

	for n = 1:length(N)

		F.fmt = lower(field2str(N(n),'RAWFORMAT',P.RAWFORMAT,'notempty'));
		fraw = field2str(N(n),'RAWDATA',P.RAWDATA,'notempty');
		F.raw = {fraw};
		lfid = split(N(n).FID,',');	% possible comma separated list of FID
		for a = 1:length(lfid)
			F.raw{a} = regexprep(fraw,'\$FID',lfid{a}); % special variable substitution	
		end
	
		% datelim is finite dates limits of PROC (or NODE) expressed in the NODE's TZ
		F.datelim = [max([P.DATELIM(1),N(n).INSTALL_DATE,P.BANG]), min([P.DATELIM(2),N(n).END_DATE,P.NOW])] - P.TZ/24 + N(n).UTC_DATA;

		fprintf('%s: loading data [%s] for node "%s" {%s} ...',wofun,F.fmt,N(n).FID,N(n).ID);

		% -------------------------------------------------------------
		switch F.fmt

		case {'mat-file'}
			D(n) = readfmtdata_matlab(WO,P,N(n),F);

		case {'winston'}
			D(n) = readfmtdata_earthworm(WO,P,N(n),F);

		case {'miniseed','seedlink','arclink','combined','fdsnws-dataselect'}
			D(n) = readfmtdata_miniseed(WO,P,N(n),F);

		case {'globkval','gipsy','gipsyx','gipsy-tdp','usgs-rneu','ies-neu','ogc-neu','ingv-gps','sbe37-ascii'}
			D(n) = readfmtdata_gnss(WO,P,N(n),F);

		case {'hyp71sum2k','fdsnws-event','scevtlog-xml'}
			[D(n),P] = readfmtdata_quake(WO,P,N(n),F);

		case {'fdsnws-bulletin','scevtlog-xml-bulletin','wo-mc'}
			[D(n),P] = readfmtdata_bulletins(WO,P,N(n),F);

		case {'afmascii','porkyasc'}
			D(n) = readfmtdata_porkyasc(WO,P,N(n),F);

		case {'bpptkg-sql','sql-table'}
			D(n) = readfmtdata_sqltable(WO,P,N(n),F);

		case {'ascii','dsv'}
			D(n) = readfmtdata_dsv(WO,P,N(n),F);

		case {'cr10xasc','toa5','t0a5','tob1'}
			D(n) = readfmtdata_campbell(WO,P,N(n),F);

		case 'teqc-qc'
			D(n) = readfmtdata_rinex(WO,P,N(n),F);

		case 'naqs-soh'
			D(n) = readfmtdata_naqs(WO,P,N(n),F);

		case {'meteofrance'}
			D(n) = readfmtdata_meteofrance(WO,P,N(n),F);

		case {'mc3'}
			D(n) = readfmtdata_mc3(WO,P,N(n),F);

		otherwise
			fprintf('%s: ** WARNING ** unknown format "%s". Nothing to do!\n',wofun,F.fmt);
	
		end
	end
end

% =============================================================================

% computes timescale parameters (data indexes and status)
for n = 1:length(N)
	if ~isempty(D(n).t)
		D(n).tfirstlast = minmax(D(n).t);
		if diff(D(n).tfirstlast) == 0
			D(n).tfirstlast = D(n).tfirstlast + [-.5,.5];
		end
	else
		D(n).tfirstlast = P.NOW - [1,0];
	end
	for r = 1:length(P.GTABLE)
		k = find((D(n).t >= P.GTABLE(r).DATE1 | isnan(P.GTABLE(r).DATE1)) & (D(n).t <= P.GTABLE(r).DATE2 | isnan(P.GTABLE(r).DATE2)));
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = D(n).tfirstlast;
		end
		k1 = [];
		ke = [];
		samp = 0;
		last = 0;
		sd = '';
		if ~isempty(k)
			k1 = k(1);
			ke = k(end);
			xlim1 = max(tlim(1),N(n).INSTALL_DATE);
			xlim2 = max(min(tlim(2) - N(n).LAST_DELAY,N(n).END_DATE),xlim1 + 1);
			samp = round(100*length(find(isinto(D(n).t(k),[xlim1,xlim2])))*N(n).ACQ_RATE/abs(xlim2 - xlim1));
			if D(n).t(ke) >= xlim2
				for i = 1:D(n).CLB.nx
					if ~isnan(D(n).d(ke,i))
						last = last + 1;
						if isfield(D(n).CLB,'un')
							sd = [sd sprintf(', %g %s', D(n).d(ke,i),D(n).CLB.un{i})];
						else
							sd = [sd sprintf(', %g', D(n).d(ke,i))];
						end
					else
						sd = [sd ', no data'];
					end
				end
				last = 100*last/size(D(n).d,2);
			end
		end
		if P.GTABLE(r).STATUS
			if ~any(isnan([N(n).LAST_DELAY,N(n).ACQ_RATE]))
				mkstatus(WO,struct('NODE',sprintf('%s.%s',P.SELFREF,N(n).ID),'STA',last,'ACQ',samp,'TS',D(n).tfirstlast(2),'TZ',P.TZ,'COMMENT',sd(3:end)));
			else
				fprintf('%s: ** WARNING ** cannot compute status for node %s. Please set "Acq. period" (ACQ_RATE) and "Acq. delay" (LAST_DELAY) fields.\n',wofun,N(n).ID);
			end
		end

		D(n).G(r).k = k;
		D(n).G(r).k1 = k1;
		D(n).G(r).ke = ke;
		D(n).G(r).samp = samp;
		D(n).G(r).last = last;
		D(n).G(r).tlim = tlim;
	end
end
P.tfirstall = rmin(cat(1,D.tfirstlast));


% removes the temporary directory
if ~isok(P.DEBUG)
	wosystem(sprintf('rm -rf %s',F.ptmp));
end

