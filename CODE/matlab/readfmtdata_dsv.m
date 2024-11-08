function D = readfmtdata_dsv(WO,P,N,F)
%READFMTDATA_DSV subfunction of readfmtdata.m
%
%	From proc P, node N and options F returns data D.
%	See READFMTDATA function for details.
%
%	         type: delimiter-separated values text file, date & time
%	               reference and data columns, all numeric
%	    P.RAWDATA: full path and filename(s) using bash wildcard facilities
%	               (may includes $FID, $yyyy, $mm, $dd or $doy variables)
%	  data format: date&time;data1;data2; ... ;dataN (semi-colon, comma or space separated values)
%	node channels: if no calibration file defined, will use the first line
%	               header of data file
%	Specific node's FID_* key:
%		FID_PREPROCESSOR: script name of the filter, located at ROOT_PREPROCESSOR directory in WEBOBS.rc
%		                  (default is dsv_generic)
%		          FID_FS: field separator character (default is semi-colon). Note that blank is always
%		                  considered as separator; successive blanks count for one.
%		    FID_TIMECOLS: index vector of columns defining date&time (default is 6 first columns with
%		                  automatic format detection)
%	        FID_DATACOLS: index vector of columns that contain data (default is automatic).
%	       FID_ERRORCOLS: index vector of columns defining data errors (default is none), in the same
%                         order as data (must have the same length, use 0 to skip a column).
%		          FID_NF: number of columns/fields of the data files. Lines that don't respect This
%	                         value will be ignored (default is automatic)
%		 FID_HEADERLINES: number of uncommented header lines (default is 1)
%	   FID_DATA_DECIMATE: decimates the data by N using the average value
%	             FLAGCOL: column index containing a boolean value
%	          FLAGACTION: action to take when FLAG column value is TRUE (default is keep data)
%
%	output fields:
%		D.t (datenum)
%		D.d (data1 data2 ...)
%	    D.e (error1 error2 ...)
%
%	Authors: François Beauducel, Xavier Béguin
%	Created: 2016-07-11, in Yogyakarta (Indonesia)
%	Updated: 2024-10-31

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
timecols = field2num(N,'FID_TIMECOLS',1:6,'notempty');
errorcols = field2num(N,'FID_ERRORCOLS');
datacols = field2num(N,'FID_DATACOLS');
% Input field separator
fs = field2str(N,'FID_FS',';','notempty');
header = field2num(N,'FID_HEADERLINES',1,'notempty');
datadecim = field2num(N,'FID_DATA_DECIMATE',1,'notempty');
flagcol = field2num(N,'FID_FLAGCOL');
flagaction = field2str(N,'FID_FLAGACTION','valid');

% name of the script that must preprocess the data
ppscript = field2str(N,'FID_PREPROCESSOR','dsv_generic','notempty');
% for security reasons : keeps only the basename
ppscript = regexprep(ppscript,'^.*/','');
% absolute path
ppfile = sprintf('%s/shells/preprocessor/%s',WO.ROOT_CODE,ppscript);
if ~exist(ppfile,'file') && ~isempty(field2str(WO,'ROOT_PREPROCESSOR'))
	ppfile = sprintf('%s/%s',field2str(WO,'ROOT_PREPROCESSOR'),ppscript);
end

if ~exist(ppfile,'file')
	error('FID_PREPROCESSOR "%s" not found. Please check or make it empty to use default.',ppscript);
end
% full command of preprocessor with arguments
ppcmd = sprintf('%s %s.%s \\%s %d %d',ppfile,P.SELFREF,N.ID,fs,header,nftest);

% runs the preprocessor and writes to the temporary file

cmd = 'for f in $(ls %s);do cat $f | %s >> %s; done'; % format string used with sprintf to generate the final command

% if RAWDATA contains '$yyyy' internal variable, makes a loop on years
if ~isempty(regexpi(F.raw{1},'\$yyyy'))
	Y = dir(regexprep(F.raw{1},'\$yyyy.*$','*','ignorecase')); % list of existing years in rawdata root directory
	Y = Y(cellfun(@length,{Y.name})==4 & cat(1,Y.isdir)');
	if length(Y)>0
		years = unique(str2num(cat(1,Y.name)))';
	else
		years = [];
	end	
	years = str2num(cat(1,Y(cellfun(@length,{Y.name})==4 & cat(1,Y.isdir)').name))';
	for yyyy = years
		if (isnan(P.DATELIM(1)) || datenum(yyyy,12,31) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,1,1) <= P.DATELIM(2))
			if ~isempty(regexpi(F.raw{1},'\$mm'))
				for mm = 1:12
					ldm = datevec(datenum(yyyy,mm+1,0)); % last day of the month mm (as date vector)
					if (isnan(P.DATELIM(1)) || datenum(ldm) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,mm,1) <= P.DATELIM(2))
						if ~isempty(regexpi(F.raw{1},'\$dd'))
							for dd = 1:ldm(3)
								if (isnan(P.DATELIM(1)) || datenum(yyyy,mm,dd) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,mm,dd) <= P.DATELIM(2))
									fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
									fraw = regexprep(fraw,'\$mm',sprintf('%02d',mm),'ignorecase');
									fraw = regexprep(fraw,'\$dd',sprintf('%02d',dd),'ignorecase');
									wosystem(sprintf(cmd,fraw, ppcmd, fdat), P);
								end
							end
						else
							fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
							fraw = regexprep(fraw,'\$mm',sprintf('%02d',mm),'ignorecase');
							wosystem(sprintf(cmd,fraw, ppcmd, fdat), P);
						end
					end
				end
			else
				if ~isempty(regexpi(F.raw{1},'\$doy'))
					ndy = datenum(yyyy+1,1,1) - datenum(yyyy,1,1); % number of days in year yyyy
					for doy = 1:ndy
						if (isnan(P.DATELIM(1)) || datenum(yyyy,1,doy) >= P.DATELIM(1)) && (isnan(P.DATELIM(2)) || datenum(yyyy,1,doy) <= P.DATELIM(2))
							fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
							fraw = regexprep(fraw,'\$doy',sprintf('%03d',doy),'ignorecase');
							wosystem(sprintf(cmd, fraw, ppcmd, fdat), P);
						end
					end
				else
					fraw = regexprep(F.raw{1},'\$yyyy',num2str(yyyy),'ignorecase');
					wosystem(sprintf(cmd, fraw, ppcmd, fdat), P);
				end
			end
			fprintf('.');
		end
	end
else
	wosystem(sprintf(cmd, F.raw{1}, ppcmd, fdat), P);
end

%wosystem(sprintf('for f in $(ls %s);do awk -F''%s'' ''NR>%d {print $0}'' $f | sed -e ''s/  */ /g;s/ *%s */%s/g;s/[%s\\/: ]/;/g;s/[^0-9.+\\-eE;]//g;s/^;/NaN;/g;s/;\\s*;/;NaN;/g;s/;;/;NaN;/g;s/;\\s*$/;NaN/g'' | awk -F'';'' ''%s {print $0}'' >> %s;done',F.raw{1},fs,header,fs,fs,fs,nftest,fdat),P);

t = [];
d = [];
e = [];
if exist(fdat,'file')
	dd = load(fdat);
	if ~isempty(dd)
		nx = size(dd,2); % number of data columns
		% extracts the time columns
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
		% extracts the data columns
		if any(~isnan(datacols)) && nx < max(datacols)
			error('%s: FID_DATACOLS must indicate valid data columns!');
		end
		% extracts the error columns
		if any(~isnan(errorcols)) && nx < max(errorcols)
			error('%s: FID_ERRORCOLS must indicate valid data columns!');
		end
		% extracts the flag column
		if any(~isnan(flagcol)) && nx < flagcol
			error('%s: FID_FLAGCOL must indicate valid data columns!');
		end

		[t,k] = unique(t);
		[t,kk] = sort(t);
		if isempty(datacols) || all(isnan(datacols))
			datacols = find(~ismember(1:nx,[timecols,errorcols])); % data is all but timecols and errorcols
		end
		d = dd(k(kk),datacols(~isnan(datacols)));
		e = nan(size(d));
		if any(errorcols>0)
			e(:,find(errorcols(errorcols>0))) = dd(k(kk),errorcols(errorcols>0));
		end
		if flagcol>0
			flag = dd(k(kk),flagcol);
			switch flagaction
			case 'valid'
				t(~flag) = [];
				d(~flag,:) = [];
				e(~flag,:) = [];
			end
		end

		% selects only the selected channels
		if ~isnan(N.CHANNEL_LIST)
			if all(N.CHANNEL_LIST <= size(d,2))
				d = d(:,N.CHANNEL_LIST);
				e = e(:,N.CHANNEL_LIST);
			else
				fprintf('** WARNING ** channel list selection mismatch.\n');
			end
		end
		fprintf('done (%d samples from %s to %s).\n',length(t),datestr(min(t)),datestr(max(t)));
	end
end
if isempty(t)
	fprintf('** WARNING ** no data found!\n');
end

D.t = decim(t - N.UTC_DATA,datadecim);
D.d = decim(d,datadecim);
D.e = decim(e,datadecim);
if N.CLB.nx == 0
	D.CLB.nx = size(d,2);
	D.CLB.un = repmat({''},1,D.CLB.nx);
	D.CLB.nm = split(sprintf('data %g\n',1:D.CLB.nx),'\n');
	if header==1
		s = wosystem(sprintf('head -q -n 1 %s | uniq > %s',F.raw{1},fdat),P);
		if ~s
			fid = fopen(fdat);
			hdr = textscan(fid,'%s','delimiter',[' ',fs]);
			fclose(fid);
			D.CLB.nm = hdr{1}(2:end)';
		end
	else
		fprintf('%s: ** Warning ** no calibration file for node %s!\n',wofun,N.ID);
	end
else
	[D.d,D.CLB] = calib(D.t,D.d,N.CLB);
end
D.t = D.t + P.TZ/24;
