function D = readfmtdata_naqs(WO,P,N,F)
%READFMTDATA_NQS subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: SOH csv files from Nanometrics Naqs server,
%	output fields:
%		D.t (datenum)
%		D.d (data1 data2 ...)
%
%	format 'naqs-soh'
%		type: SOH csv files from Nanometrics Naqs server,
%		filename/path: P.RAWDATA/YYYY/YYYY-MM-DD/FID/YYYY-MM-DD_FID_{CYG,TR1,TR2,TR3,TR4,TAU,CEN}.{lis,lgq,fes,hrd}.gz
%		data format: unixtime,yyyy-mm-dd HH:MM:SS,data1,data2, ... ,dataN
%		node FID: FID_NANOSTATYPE contains one of the following:
%			'vsat-libra1'
%			'vsat-libra2'
%			'taurus'
%			'centaur'
%		node calibration: no .CLB file, predefined calibration in this file
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2016-07-11, in Yogyakarta (Indonesia)
%	Updated: 2023-08-30

wofun = sprintf('WEBOBS{%s}',mfilename);

pdat = sprintf('%s',F.raw{1});

% select years from P.DATELIM parameter (loads only necessary data)
if any(isnan(P.DATELIM))
	% gets the list of available years
	G = dir(pdat);
	years = cellstr(cat(1,G(~ismember({G.name},{'.','..'})' & cat(1,G.isdir)).name));
else
	years = cellstr(datestr(F.datelim,'yyyy'));
end
ylist = sprintf('{%s..%s}',years{1},years{end});

% makes a single and homogeneous space-separated numeric file from the raw data
fprintf('type [%s]... ',N.FID_NANOSTATYPE);
ffes = sprintf('%s/%s.fes',F.ptmp,N.FID);
fhrd = sprintf('%s/%s.hrd',F.ptmp,N.FID);
flgq = sprintf('%s/%s.lgq',F.ptmp,N.FID);

switch lower(N.FID_NANOSTATYPE)

% -----------------------------------------------------------------------------
case 'vsat-libra1'

	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CYG.lis.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$6,$8}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,"00",$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd),P);
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CYG.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,"00",$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq),P);
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TR4.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4,$5}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,"00",$7,$8,$9}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes),P);
	D.CLB.nx = 6;
	D.CLB.nm = {'Power','Temperature','GPS','Mass Pos U','Mass Pos V','Mass Pos W'};
	D.CLB.un = {'V','°C','satellites','V','V','V'};


% -----------------------------------------------------------------------------
case 'vsat-libra2'

%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CYG.hrd.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,"00",$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CYG.hrd.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd),P);
%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CYG.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,"00",$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CYG.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq),P);
%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TR4.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4,$5}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,"00",$7,$8,$9}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TR4.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4,$5}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8,$9}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes),P);
	D.CLB.nx = 6;
	D.CLB.nm = {'Power','Temperature','GPS','Mass Pos U','Mass Pos V','Mass Pos W'};
	D.CLB.un = {'V','°C','satellites','V','V','V'};


% -----------------------------------------------------------------------------
case 'taurus'

%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TAU.hrd.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TAU.hrd.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd),P);
%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TAU.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TAU.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq),P);
%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TAU.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4,$5}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8,$9}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_TAU.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4,$5}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8,$9}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes),P);
	D.CLB.nx = 6;
	D.CLB.nm = {'Power','Temperature','GPS','Mass Pos U','Mass Pos V','Mass Pos W'};
	D.CLB.un = {'V','°C','satellites','V','V','V'};



% -----------------------------------------------------------------------------
case 'centaur'

%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CEN.hrd.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CEN.hrd.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7,$8}'';done;done > %s',ylist,pdat,N.FID,N.FID,fhrd),P);
%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CEN.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CEN.lgq.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$4}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7}'';done;done > %s',ylist,pdat,N.FID,N.FID,flgq),P);
%	if s
%		fprintf('** WARNING ** [%s] !\n',w);
%	end
%			[s,w] = system(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CEN.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7+9948.280783}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes));
	wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y-??-??/%s/$y-??-??_%s_CEN.fes.gz);do zcat $f | grep "^ " | awk -F "," ''{print $2,$3}'' | sed ''s/-/ /;s/-/ /;s/:/ /g'' | awk ''{print $1,$2,$3,$4,$5,$6,$7+9948.280783}'';done;done > %s',ylist,pdat,N.FID,N.FID,ffes),P);
	D.CLB.nx = 4;
	D.CLB.nm = {'Power','Temperature','GPS','Max Mass Pos'};
	D.CLB.un = {'V','°C','satellites','V'};

% -----------------------------------------------------------------------------
otherwise
	fprintf('%s: ** WARNING ** unknown Nanometrics station type "%s". Nothing to do!\n',wofun,N.FID_NANOSTATYPE);
	D.CLB.nx = 0;
	D.CLB.nm = {};
end

t = [];
d = [];
nx = D.CLB.nx;
if exist(fhrd,'file') && exist(flgq,'file') && exist(ffes,'file')
	dhrd = load(fhrd);
	dlgq = load(flgq);
	dfes = load(ffes);

	% To have a single vector t with matrix d, must interpolate all channels on the same time vector
	if size(dhrd,2) > 5
		t = datenum(dhrd(:,1:6));
		d = nan(length(t),nx);
		if size(dhrd,2) > 7
			d(:,1:2) = dhrd(:,7:8);
		end
		if ~isempty(dlgq) && size(dlgq,2) > 6
			[tx,kx] = unique(datenum(dlgq(:,1:6)));
			d(:,3) = interp1(tx,dlgq(kx,7),t);
		end
		if ~isempty(dfes) && size(dfes,2) > 6
			[tx,kx] = unique(datenum(dfes(:,1:6)));
			d(:,4:nx) = interp1(tx,dfes(kx,7:(7+nx-4)),t);
		end
		%for c = 4:nx
		%	if ~isempty(dfes) & size(dfes,2) > (6+c-4)
		%		d(:,c) = interp1(datenum(dfes(:,1:6)),dfes(:,7+c-4),t);
		%	end
		%end
	end
	fprintf('done (%d samples).\n',length(t));
end
if isempty(t)
	fprintf('** WARNING ** no data found!\n');
end
D.t = t - N.UTC_DATA;
D.d = d;
D.e = [];
D.t = D.t + P.TZ/24;

