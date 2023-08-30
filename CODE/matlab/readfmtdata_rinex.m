function D = readfmtdata_rinex(WO,P,N,F)
%READFMTDATA_RINEX subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: Rinex files 
%	output fields:
%		D.t (datenum)
%		D.d (data1 data2 ...)
%
%	format 'teqc-qc'
%		type: 
%		filename/path: 
%		data format: 
%		node calibration: 
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2016-07-11, in Yogyakarta (Indonesia)
%	Updated: 2023*08-30

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
fdat = sprintf('%s/%s.dat',F.ptmp,N.FID);
wosystem(sprintf('for y in %s; do yy=`echo $y | cut -c 3-4`;for f in $(ls %s/$y/???/%s???0.${yy}S);do grep -h SUM $f | sed ''s/:/ /g;s/n\\/a/NaN/g'' | awk -v year=$y ''{print year,$3,$4,$5,$6,"00",$12*100/24,$16,$17,$18,$19*100/$15}'';done;done > %s',ylist,pdat,lower(N.FID),fdat),P);

t = [];
d = [];
if exist(fdat,'file') 
	dd = load(fdat);
	if ~isempty(dd)
		t = datenum(dd(:,1:6));
		[t,k] = unique(t);
		[t,kk] = sort(t);
		d = dd(k(kk),7:end);
		fprintf('done (%d samples).\n',length(t));
	end
end
if isempty(t)
	fprintf('** WARNING ** no data found!\n');
end

D.t = t - N.UTC_DATA;
D.d = d;
D.e = [];
D.CLB.nx = 5;
D.CLB.nm = {'Duration','Obs','Mp1','Mp2','O/slps'};
D.CLB.un = {'% 24h','% Total','m','m','% Obs'};
D.t = D.t + P.TZ/24;

