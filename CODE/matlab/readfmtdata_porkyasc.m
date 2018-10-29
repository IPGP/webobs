function D = readfmtdata_porkyasc(WO,P,N,F)
%READFMTDATA_PORKYASC subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: Porky ascii data files
%	filename/path: P.RAWDATA/FID/YYYY/YYYYMMDD.DAT
%	data format: DATE HH:MM data1 data2 ... dataN
%	node calibration: possible use of the channel code to order channels
%
%
%	Authors: François Beauducel and Jean-Marie Saurel, WEBOBS/IPGP
%	Created: 2016-07-10, in Yogyakarta (Indonesia)
%	Updated: 2017-02-04

wofun = sprintf('WEBOBS{%s}',mfilename);


pdat = sprintf('%s/%s',F.raw{1},N.FID);

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
wosystem(sprintf('for y in %s;do for f in $(ls %s/$y/$y????.DAT);do awk -v f=$f ''NF > 6 {sub(/:/," ");print substr(f,length(f)-11,4),substr(f,length(f)-7,2),substr(f,length(f)-5,2),$2,$3,$4,$5,$6,$7,$8}'' $f;done;done > %s',ylist,pdat,fdat),P);

if exist(fdat,'file')
	dd = load(fdat);
	d = dd(:,6:end);
	t = datenum(dd(:,1),dd(:,2),dd(:,3),dd(:,4),dd(:,5),0);
	fprintf('done (%d samples).\n',length(t));

	% negative time steps are due, generally, to the last previous day data written in the bad file...
	k = find([0;diff(t)] < 0 & [diff(t);0] > .5);
	if ~isempty(k), t(k) = t(k) + 1; end
	k = find([0;diff(t)] > .5 & [diff(t);0] < 0);
	if ~isempty(k), t(k) = t(k) - 1; end
else
	fprintf('** WARNING ** no data found!\n');
	t = [];
	d = [];
end
D.t = t - N.UTC_DATA;
D.r = d; % raw data
[D.d,D.CLB] = calib(t,d,N.CLB,'channelcodeorder');
D.t = D.t + P.TZ/24;
D.e = [];

