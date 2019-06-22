function D = readfmtdata_dsv(WO,P,N,F)
%READFMTDATA_DSV subfunction of readfmtdata.m
%	
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	         type: delimiter-separated values text file, date & time 
%	               reference and data columns, all numeric
%	    P.RAWDATA: full path and filename(s) using bash wildcard facilities
%	               (may includes $FID and $yyyy variables) 
%	  data format: date&time;data1;data2; ... ;dataN (semi-colon, coma or space separated values)
%	node channels: if no calibration file defined, will use the first line 
%	               header of data file
%	Specific node's FID_* key:
%		FID_PREPROCESSOR: script name of the filter, located at ROOT_PREPROCESSOR directory in WEBOBS.rc
%		                  (default is dsv_generic)
%		          FID_FS: field separator character (default is semi-colon). Note that blank is always
%		                  considered as separator; successive blanks count for one.
%		    FID_TIMECOLS: index vector of columns defining date&time (default is 6 first columns with
%		                  automatic format detection)
%		          FID_NF: number of columns/fields of the data files (default is automatic)
%		 FID_HEADERLINES: number of uncommented header lines (default is 1)
%
%	output fields:
%		D.t (datenum)
%		D.d (data1 data2 ...)
%
%
%	Authors: François Beauducel, Xavier Béguin
%	Created: 2016-07-11, in Yogyakarta (Indonesia)
%	Updated: 2018-09-22

wofun = sprintf('WEBOBS{%s}',mfilename);

% makes a single file containing rectangular table of numbers, from the raw data
fdat = sprintf('%s/%s.dat',F.ptmp,N.ID);
if exist(fdat,'file')
	delete(fdat)
end
nf = field2num(N,'FID_NF');
if nf > 0
	nftest = nf;
else
	nftest = 0;
end
timecols = field2num(N,'FID_TIMECOLS',[]);
% Input field separator
fs = field2str(N,'FID_FS',';','notempty');
header = field2num(N,'FID_HEADERLINES',1,'notempty');

% name of the script that must preprocess the data
ppscript = field2str(N,'FID_PREPROCESSOR','dsv_generic','notempty');
% for security reasons : keeps only the basename
ppscript = regexprep(ppscript,'^.*/','');
% absolute path
preprocessor = sprintf('%s/bin/preprocessor/%s',WO.ROOT_CODE,ppscript);
if ~exist(preprocessor,'file') && ~isempty(field2str(WO,'ROOT_PREPROCESSOR'))
	preprocessor = sprintf('%s/%s',field2str(WO,'ROOT_PREPROCESSOR'),ppscript);
end

if ~exist(preprocessor,'file')
	error('FID_PREPROCESSOR "%s" not found. Please check or make it empty to use default.',ppscript);
end

% runs the preprocessor and writes to the temporary file
% if RAWDATA contains '$yyyy' internal variable, makes a loop on years
if ~isempty(regexpi(F.raw{1},'\$yyyy'))
	Y = dir(regexprep(F.raw{1},'\$yyyy.*$','*'));
	years = str2num(cat(1,Y(~ismember({Y.name},{'.','..'})' & cat(1,Y.isdir)).name))';
	for y = years
		if (isnan(P.DATELIM(1)) || datenum(y,12,31) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(y,1,1) <= P.DATELIM(2))
			fraw = regexprep(F.raw{1},'\$yyyy',num2str(y),'ignorecase');
			wosystem(sprintf('cat %s | %s %s \\%s %d %d >> %s', ...
				fraw, preprocessor, N.ID, fs, header, nftest, fdat), P);
			fprintf('.');
		end
	end
else
	wosystem(sprintf('for f in $(ls %s);do cat $f | %s %s \\%s %d %d >> %s; done', ...
		F.raw{1}, preprocessor, N.ID, fs, header, nftest, fdat), P);
end

%wosystem(sprintf('for f in $(ls %s);do awk -F''%s'' ''NR>%d {print $0}'' $f | sed -e ''s/  */ /g;s/ *%s */%s/g;s/[%s\\/: ]/;/g;s/[^0-9.+\\-eE;]//g;s/^;/NaN;/g;s/;\\s*;/;NaN;/g;s/;;/;NaN;/g;s/;\\s*$/;NaN/g'' | awk -F'';'' ''%s {print $0}'' >> %s;done',F.raw{1},fs,header,fs,fs,fs,nftest,fdat),P);

t = [];
d = [];
if exist(fdat,'file') 
	dd = load(fdat);
	if ~isempty(dd)
		nx = size(dd,2); % number of data columns
		if ~isempty(timecols) && nx <= max(timecols) 
			error('%s: only %d columns found in data while need %d columns for date and time.', ...
				wofun,nx,length(timecols));
		end
		if isempty(timecols)
			% here we try to guess the order of the 6 first colums
			t = smartdatenum(dd(:,1:6));
			timecols = 1:6;
		else
			t = smartdatenum(dd(:,timecols),1:length(timecols));
		end

		[t,k] = unique(t);
		[t,kk] = sort(t);
		d = dd(k(kk),find(~ismember(1:nx,timecols)));
		% selects only the selected channels
		if ~isnan(N.CHANNEL_LIST)
			d = d(:,N.CHANNEL_LIST);
		end
		fprintf('done (%d samples from %s to %s).\n',length(t),datestr(min(t)),datestr(max(t)));
	end
end
if isempty(t)
	fprintf('** WARNING ** no data found!\n');
end

D.t = t - N.UTC_DATA;
D.d = d;
if N.CLB.nx == 0
	D.CLB.nx = size(d,2);
	D.CLB.un = cell(1,D.CLB.nx);
	D.CLB.nm = cell(1,D.CLB.nx);
	if header==1
		s = wosystem(sprintf('head -q -n 1 %s | uniq > %s',F.raw{1},fdat),P);
		if ~s
			fid = fopen(fdat);
			hdr = textscan(fid,'%s','delimiter',fs);
			fclose(fid);
			D.CLB.nm = hdr{1}(2:end)';
		end
	else
		error('%s: no calibration file for node %s. Cannot proceed!',wofun,N.ID);
	end
else
	[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
end
D.t = D.t + P.TZ/24;

