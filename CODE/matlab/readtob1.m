function X = readtob1(filename)
%READTOB1 Reads Campbell TOB1 format file.
%   READTOB1(FILE) reads a data FILE in the binary format TOB1 from
%   Campbell and returns a structure with following fields:
%		HEADER: structure of header data
%		     t: time vector (datenum format)
%		     d: data matrix (numeric values only)
%		     c: cell of string (for ASCII data type, if any)
%
%	Note: time vector is built from "SECONDS" and "NANOSECONDS" data
%	vector. The data matrix contains all data, including time, "RECORD"
%	and any ascii as NaN.
%
%
%	Author: François Beauducel, IPGP / WEBOBS
%	Created: 2018-06-13 in Jakarta, Indonesia
%	Updated: 2023-12-31

if ~exist(filename,'file')
	error('file %s not exists.',filename)
end

F = dir(filename);

fid = fopen(filename,'rb');

% --- reads header
% must check first the file type
nok = false;
line = fgets(fid);
if ~ischar(line)
	nok = true;
else
	hd = strrep(split(line,','),'"','');
	if ~strcmpi(hd{1},'tob1')
		nok = true;
	end
end
if nok
	fclose(fid);
	warning('File %s is not a valid TOB1 format.\n',filename);
	X = struct('HEADER',[],'t',[],'d',[]);
	return
end

X.HEADER.file_type     = hd{1}; % file type
X.HEADER.station_name  = hd{2}; % name of station as indicated in logger program
X.HEADER.model_name    = hd{3}; % logger model type (e.g. 'cr3000')
X.HEADER.serial_number = hd{4}; % logger serial no
X.HEADER.os_version    = hd{5}; % logger OS version
X.HEADER.dld_name      = hd{6}; % logger program e.g. 'cpu:mpb1csatprf024.cr3'
X.HEADER.dld_signature = hd{7}; % logger program signature
X.HEADER.table_name    = hd{8}; % table name

header_bytes = length(line);

% field headers (4 more lines)
field_headers = {'field_names','field_units','field_processing','data_types'};

for fd = 1:length(field_headers)
	line = fgetl(fid);
	X.HEADER.(field_headers{fd}) = strrep(split(line,','),'"','');
	header_bytes = header_bytes + length(line);
end

% sets the Matlab class and byte size of each field
dtypes = X.HEADER.data_types;
mclass = cell(size(dtypes));
rbytes = zeros(size(dtypes));

for c = 1:length(mclass)
	switch lower(dtypes{c})
		case 'bool'
			mclass{c} = 'uint8';
			rbytes(c) = 1;
		case {'ushort','uint2'}
			mclass{c} = 'uint16';
			rbytes(c) = 2;
		case {'short','int2','bool2'}
			mclass{c} = 'int16';
			rbytes(c) = 2;
		case {'ulong','uint4'}
			mclass{c} = 'uint32';
			rbytes(c) = 4;
		case {'long','int4','bool4'}
			mclass{c} = 'int32';
			rbytes(c) = 4;
		case 'fp2'
			mclass{c} = 'uint16';
			rbytes(c) = 2;
		case {'ieee4','ieee4l'}
			mclass{c} = 'single';
			rbytes(c) = 4;
		otherwise
			% checks the ASCII(x) type
			a = str2double(regexprep(dtypes{c},'ascii\((.+)\)','$1','ignorecase'));
			if a > 0
				rbytes(c) = a;
				mclass{c} = 'char';
			else
				fprintf('** WARNING ** unkonwn data type "%s" in file "%s".\n',dtypes{c},filename);
			end
	end
end
X.HEADER.data_mclass = mclass;
X.HEADER.data_bytes = rbytes;

record_bytes = sum(rbytes); % record length (in byte)
nr = floor((F.bytes - header_bytes)/record_bytes); % number of records in the file

% --- reads the entire file (after header) into memory - VERY fast! -
bb = fread(fid,[record_bytes,nr],'*uint8');

fclose(fid);

% --- now converts the data into the right types
% inits arrays
dd = nan(nr,length(mclass));
cc = cell(nr,length(mclass));

% loop on the data rows
for c = 1:size(dd,2)
	bk = bb(sum(rbytes(1:c-1)) + (1:rbytes(c)),:); % selected bytes for all records of row c
	if strcmp(mclass{c},'char')
		% for ascii type, simply reshapes the matrix
		cc(:,c) = cellstr(reshape(char(bk(:)),rbytes(c),nr)');
	else
		% for numerical, use typecast and converts to double
		dd(:,c) = double(reshape(typecast(bk(:),mclass{c}),1,nr));
	end
end

% must re-convert all 'FP2' data type (unknown by typecast...)
k = find(strcmpi(dtypes,'fp2'));
dd(:,k) = fp2double(dd(:,k));

% --- sets the outputs
X.d = dd;

% timestamp
X.t = dd(:,1)/86400 + dd(:,2)/(86400*1e9) + datenum(1990,1,1);

% ascii data
if any(strcmp(mclass,'char'))
	X.c = cc;
end


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = fp2double(x)
%FP2DOUBLE Converts FP2 2-byte floating point number into double.

% needs to swap the 2 bytes first...
x = double(swapbytes(uint16(x)));

% bit A: polarity (0 = +, 1 = -)
x0 = floor(x/2^15);

% bits B,C: decimal locater (00 = 1, 01 = 0.1, 10 = 0.01, 11 = 0.001)
x1 = floor((x - x0*2^15)/2^13);

% bits D-P: mantisse (13-bit binary value)
x2 = x - x1*2^13 - x0*2^15;

y = x2.*power(10,-x1).*(1 - 2*x0);

% replaces -8190 values by NaN
y(y==-(2^13-2)) = NaN;




