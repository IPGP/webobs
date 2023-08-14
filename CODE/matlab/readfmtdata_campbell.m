function D = readfmtdata_campbell(WO,P,N,F)
%READFMTDATA_CAMPBELL subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: Campbell Scientific datalogger formats
%	output fields:
%		D.t (datenum)
%		D.d (data1 data2 ...)
%	    P.RAWDATA: full path and filename(s) using bash wildcard facilities
%	               (may includes $FID and $yyyy variables)
%		node calibration: possible use of the channel code to order channels
%
%	format 'cr10xasc'
%		type: Campbell Scientific CR10X ascii data acquisition files
%		filename/path: P.RAWDATA/FID/YYYY/YYYYMMDD.DAT
%		data format: PRGM,yyyy,ddd,HM,data1,data2, ... ,dataN
%
%	format 'toa5'
%		type: Campbell Scientific CR?00 ascii 'TOA5' data acquisition files
%		filename/path: P.RAWDATA/FID/YYYY/FID*.dat
%		data format: "yyyy-mm-dd HH:MM:SS",data1,data2, ... ,dataN
%
%	format 'tob1'
%		type: Campbell Scientific CR?00 binary 'TOB1' data acquisition files
%		filename/path: P.RAWDATA/FID/YYYY/FID*.dat
%		data format: binary
%
%
%	Authors: François Beauducel, WEBOBS/IPGP
%	Created: 2016-07-11, in Yogyakarta (Indonesia)
%	Updated: 2023-08-10

wofun = sprintf('WEBOBS{%s}',mfilename);

debug = isok(P,'DEBUG');

% in RAWDATA: replaces $FID by the node's FID value, and $yyyy by $y
pdat = regexprep(regexprep(F.raw{1},'\$FID',N.FID),'\$yyyy','$y');

% select years from F.datelim parameter (loads only necessary data)
years = cellstr(datestr(F.datelim,'yyyy'));
ylist = sprintf('{%s..%s}',years{1},years{end});

% makes a single and homogeneous space-separated numeric file from the raw data
fdat = sprintf('%s/%s.dat',F.ptmp,N.FID);

t = [];
d = [];

switch F.fmt

% -----------------------------------------------------------------------------
case 'cr10xasc'
	% About the format particularities:
	% - hour and minutes are coded in $4 as 'HHMM' but without leading zero, i.e., 00:02 = '2' or 05:10 = '510'
	% - lines anomalies are frequent: checks if year consistent with data directory
	wosystem(sprintf('for y in %s; do for f in $(ls %s);do awk -F "," -v y=$y ''$2==y && NF>=12 {h=int($4/100); m=$4-h*100; print $2,"1",$3,h,m,"0"%s}'' $f;done;done > %s',ylist,pdat,sprintf(',$%d',5:12),fdat),P);

% -----------------------------------------------------------------------------
case {'toa5','t0a5'}

	% needs to fix the number of column (including the 6 first for yyyy-mm-dd HH:MM:SS)
	ncol = 6 + max(str2double(N.CLB.cd));
	wosystem(sprintf('for y in %s; do for f in $(ls %s);do cat $f | grep "^\\"[0-9]" | sed ''s/-/,/;s/-/,/'' | awk -F "[:, ]" ''NF>=%d {gsub(/"/,"");print $1%s}'';done;done > %s',ylist,pdat,ncol,sprintf(',$%d',2:ncol),fdat),P);

% -----------------------------------------------------------------------------
case {'tob1'}
	for y = str2double(years(1)):str2double(years(end))
		G = dir(sprintf('%s',pdat,y,N.FID));
		for i = 1:length(G)
			f = sprintf('%s/%d/%s',pdat,y,G(i).name);
			if debug
				fprintf('\n ---> reading file "%s"...',f);
			end
			X(i) = readtob1(f);
			if exist('X','var')
				t = cat(1,t,X(i).t);
				d = cat(1,d,X(i).d(:,3:end));	% excludes 2 columns of time from the data matrix
				fprintf('.');
			end
		end
	end

end

% only for ascii formats: imports the temporary file 'fdat'
if isempty(t) && exist(fdat,'file') 
	dd = load(fdat);
	if ~isempty(dd)
		t = datenum(dd(:,1:6));
		d = dd(:,7:end);
	end
end

if isempty(t)
	fprintf('** WARNING ** no data found!\n');
else
	l0 = length(t);
	[t,k] = unique(t);
	[t,kk] = sort(t);
	d = d(k(kk),:);
	fprintf('done (removed %d duplicates, %d final samples).\n',l0-length(t),length(t));
end

D.t = t - N.UTC_DATA;
D.d = d;
[D.d,D.CLB] = calib(D.t,D.d,N.CLB,'channelcodeorder');
D.t = D.t + P.TZ/24;
