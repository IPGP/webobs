function D = readfmtdata_sqltable(WO,P,N,F)
%READFMTDATA_SQLTABLE subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	type: SQL database with simple table
%		P.RAWDATA: mysql -h host -u user -ppasswd -Ddatabase -N -B -e 'SELECT time,data1,data2,data3 from $FID WHERE time between "$date1" and "$date2";'
%		or P.RAWDATA can be a filename that may includes $FID variable 
%		data format: yyyy-mm-dd HH:MM:SS data1 data2 data3 ... (must start with timestamp)
%		node calibration: used if exists, if not guess the number of channels from the data.
%
%
%	Authors: François Beauducel, WEBOBS/IPGP
%	Created: 2016-07-11, in Yogyakarta (Indonesia)
%	Updated: 2018-08-28


wofun = sprintf('WEBOBS{%s}',mfilename);

fdat = sprintf('%s/%s.dat',F.ptmp,N.ID);
wosystem(['rm -f ',fdat],P)

for a = 1:length(F.raw)
	% makes a single and homogeneous space-separated numeric file from the raw data
	cmd = F.raw{a};
	cmd = regexprep(cmd,'''''','''');
	cmd = regexprep(cmd,'\$date1\>',datestr(F.datelim(1),'yyyy-mm-dd HH:MM:SS'));	% start date
	cmd = regexprep(cmd,'\$date2\>',datestr(F.datelim(2),'yyyy-mm-dd HH:MM:SS'));	% end date

	if exist(cmd,'file')	% possibility to set a filename into RAWDATA
		wosystem(sprintf('cat %s >> %s',cmd,fdat),P)
	else
		% executes sql command and replaces all separators with spaces and NULL by NaN
		% (takes care of negative values and floats like 1.234e-5)
		wosystem(sprintf('%s | sed -e ''s/\t-/ @/g;s/[eE]-/@/g;s/[-:\t]/ /g;s/@/-/g;s/NULL/NaN/g'' >> %s',cmd,fdat),P)	
	end
end

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

if N.CLB.nx == 0
	D.CLB = clbdefault(size(d,2));
else
	[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
end
D.t = D.t + P.TZ/24;

