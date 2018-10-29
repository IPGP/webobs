function D=readudbf(f);
%READUDBF Read UniversalDataBinFile format of Gantner Instruments
%	D=READUDBF(FILENAME) imports data from FILENAME file format (.dat) and
%	returns structure D containing data and header variables, in particular,
%		D =
%		Name: {1xm cell}
%		Unit: {1xm cell}
%		time: [1xn double] (Matlab datenum format)
%		data: [nxm double]
%
%	The function should work with data files version 1.02 to 1.07.
%
% Author: François Beauducel, Institut de Physique du Globe de Paris
% Created: 2008-07-09
% Modified: 2009-06-01
% References:
% - "e.bloxx System Guide", Gantner Instruments Test & Measurements GMBH, p 89-92
% - "UDBF definition", update document for version 1.07 (www.ioselect.com)

% Definition of data types equivalences for Matlab
datatypes = { ...
    'bit1', ...     % 1 = Boolean
    'int8', ...     % 2 = SignedInt8
    'uint8', ...    % 3 = UnSignedInt8
    'int16', ...    % 4 = SignedInt16
    'uint16', ...   % 5 = UnSignedInt16
    'int32', ...    % 6 = SignedInt32
    'uint32', ...   % 7 = UnSignedInt32
    'single', ...   % 8 = Float
    'bit8', ...     % 9 = BitSet8
    'bit16', ...    % 10 = BitSet16
    'bit32', ...    % 11 = BitSet32
    'double', ...   % 12 = Double
};

maxsize = 3000;

fid = fopen(f,'r','b');	% default mode is binary

% ============== Header reading ==============

% IsBigEndian (1 byte unsigned integer)
% 0.............IsLittleEndian (like Intel CPU's) 
% <>0...........IsBigEndian (like Motorola CPU's) 
D.IsBigEndian = fread(fid,1,'uint8');

% Version (2 byte unsigned integer) 
D.Version = fread(fid,1,'uint16')/100;

% TypeVendorLen (2byte unsigned integer) 
D.TypeVendorLen = fread(fid,1,'uint16');

% TypeVendor (1byte unsigned integer array)
% including terminating \0. 
D.TypeVendor = deblank(char(fread(fid,D.TypeVendorLen,'uint8')'));

% WithCheckSum (1 byte unsigned integer) 
% 0.............NoCheckSum 
% <>0...........WithCheckSum 
D.WithCheckSum = fread(fid,1,'uint8');
      
% ModuleAdditionalDataLen (2 byte unsigned integer) 
% Shows how many ModuleAdditionalData bytes are appended. If a ModuleAdditionalDataLen is set,
% it needs to be at least 4 bytes in length in order to declare variables MODULETYPE and 
% MODULEADDITIONALDATASTRUCTID to determine how ModuleAdditionalData is coded. 
D.ModuleAdditionalDataLen = fread(fid,1,'uint16');

if D.ModuleAdditionalDataLen >= 4

	% Optional: ModuleType (2 byte unsigned integer)
	% If ModuleAdditionalData is appended, this item needs to be set first and is
	% the type of module in standard coding. 
	D.ModuleType = fread(fid,1,'uint16');

	% Optional: ModuleAdditionalDataStructID (2 byte unsigned integer) 
 	% If ModuleAdditionalData is appended, this item needs to be set second and is
	% an ID to describe used structure. 
	D.ModuleAdditionalDataStructID = fread(fid,1,'uint16');
  
	% Optional: ModuleAdditionalData 
	% If ModuleAdditionalDataLen is set to >4, all following data depend on a 
	% user-definable structure. How this structure is coded depends on the version
	% number and is described with MODULETYPE and MODULEADDITIONALDATASTRUCTID. 
	D.ModuleAdditionalData = fread(fid,D.ModuleAdditionalDataLen-4,'uint8');

end

% StartTimeToDayFactor (double ? 8 byte IEEE754 number) 
% This is the factor of the following StartTime with respect to a day. 
% StartTime*StartTimeToDayFactor = Time in [days] 
D.StartTimeToDayFactor = fread(fid,1,'double');

% !!!!!!!!!!!!!!!!!!! Added in V1.07 !!!!!!!!!!!!!!!!!!!
if D.Version >= 1.07

    % dActTimeDataType (2 byte unsigned integer)
    % Delivers data type of ActTime in standard coding. Refer to "DataType" 
    % parameter of variable below. If this is set to "No" than no ActTime is 
    % included.
    D.dActTimeDataType = fread(fid,1,'uint16');
    
end
 
% dActTimeToSecondFactor (double - 8 byte IEEE754 number) 
% This is the factor of the following dActTime (in time/data section) with respect 
% to a second. 
% dActTime*dActTimeToSecondFactor = Time in [s] 
% If this is set to a value <=0.0 than no ActTime is included. 
D.dActTimeToSecondFactor = fread(fid,1,'double');

% StartTime (double - 8 byte IEEE754 number) 
% This is the time at which the startevent occurred. This time is base for all 
% following data items (dActTime) 
D.StartTime = fread(fid,1,'double');
% Converts into Matlab date format (datenum)
D.StartTime = D.StartTime + datenum(1900,1,0) - 1;
D.StartTimeString = datestr(D.StartTime);

% SampleRate (double - 8 byte IEEE754 number) 
% This is the measurement frequency. 
D.SampleRate = fread(fid,1,'double');

% VariableCount (2 byte unsigned integer) 
% Number of configured variables. 
D.VariableCount = fread(fid,1,'uint16');

for i = 1:D.VariableCount
    
    % NameLen (2 byte unsigned integer) 
    % Delivers number of 1byte integer?s, which are used for VariableName. 
    D.NameLen(i) = fread(fid,1,'uint16');
    
    % Name (1 byte unsigned integer array) 
    % Name of variable including terminating \0. 
    D.Name{i} = deblank(char(fread(fid,D.NameLen(i),'uint8')'));
    
    % DataDirection (2 byte unsigned integer) 
    % Delivers data direction of variable in standard coding. 
    %   Input........................0 
    %   Output.......................1 
    %   InputOutput..................2 
    %   Empty........................3 
    % Attention: If a variables data direction has no "Input" set, it also
    % isn't be set in time/data section!
    D.DataDirection(i) = fread(fid,1,'uint16');
    
    % DataType (2 byte unsigned integer) 
    % Delivers data type of variable in standard coding. 
    %   No............................0 
    %   Boolean.......................1 
    %   SignedInt8....................2 
    %   UnSignedInt8..................3 
    %   SignedInt16...................4 
    %   UnSignedInt16.................5 
    %   SignedInt32...................6 
    %   UnSignedInt32.................7 
    %   Float.........................8 
    %   BitSet8.......................9 
    %   BitSet16.....................10 
    %   BitSet32.....................11
    %   Double.......................12
    D.DataType(i) = fread(fid,1,'uint16');
    
    % FieldLen (2 byte unsigned integer) 
    % Delivers the set field lengtD. 
    D.FieldLen(i) = fread(fid,1,'uint16');
    
    % Precision (2 byte unsigned integer) 
    % Delivers the set precision (see also DataType). 
    D.Precision(i) = fread(fid,1,'uint16');
    
    % UnitLen (2byte unsigned integer) 
    % Delivers number of 1byte integer?s, which are used for Unit. 
    D.UnitLen(i) = fread(fid,1,'uint16');
    
    % Unit (1byte unsigned integer array) 
    % Unit including terminating \0. 
    D.Unit{i} = deblank(char(fread(fid,D.UnitLen(i),'uint8')'));
    
    % AdditionalDataLen (2 byte unsigned integer) 
    % Tells how many AdditionalData bytes are appended. If an AdditionalDataLen
    % is set, it needs to be at least 4 bytes to declare variables TYPE and 
    % ADDITIONALDATASTRUCTID to determine how AdditionalData is coded. 
    D.AdditionalDataLen(i) = fread(fid,1,'uint16');
    
    if D.AdditionalDataLen(i) >= 4
        
        % Optional: AdditionalDataType (2 byte unsigned integer) 
        % If AdditionalData is appended, this item needs to be set first and 
        % shows the type of variable in standard coding.
        D.AdditionalDataType(i) = fread(fid,1,'uint16');
 
        % Optional: AdditionalDataStructID (2 byte unsigned integer) 
        % If AdditionalData is appended, this item needs to be set second and
        % is an ID to describe used structure.
        D.AdditionalDataStructID(i) = fread(fid,1,'uint16');
 
        % Optional: AdditionalData 
        % If AdditionalDataLen is set to >4, all following data depend on a 
        % user-definable structure. How this structure is coded depends on the 
        % version number and is described with TYPE and ADDITIONALDATASTRUCTID. 
        D.AdditionalData(i) = fread(fid,D.AdditionalDataLen(i)-4,'uint8');
        
    end
end

% Separation Chars 
% There are separation characters ("*") inserted. At least 8 pieces and maximal
% as many as needed so that the next valid data byte is written to a 16 bytes 
% aligned address. 
z = '*';
while z == '*'
    z = fread(fid,1,'uint8=>char');
end
fseek(fid,-1,0);    % repositionning the file indicator (one byte backward)


% ============== Time and data reading ==============

% For each data item a dActTime (depending on parameters "dActTimeDataType" 
% and "dActTimeToSecondFactor") is placed at the beginning. The appended data 
% depends on variable settings listed in the header and are repeated for each 
% defined variable. In versions <= V1.06 this value, if present, always was an 
% UnSignedInt32.

% for optimization reasons, large arrays D.time and D.data are defined
D.time = zeros(maxsize,1);
D.data = zeros(maxsize,D.VariableCount);

i = 1;

while ~feof(fid)

	if D.dActTimeToSecondFactor > 0 
    		dActTime = fread(fid,1,datatypes{D.dActTimeDataType});
		if feof(fid), break; end
		D.time(i) = dActTime;	
	end

	for ii = 1:D.VariableCount
            if D.DataType(ii) > 0
	        d = fread(fid,1,datatypes{D.DataType(ii)});
		if feof(fid), break; end
                D.data(i,ii) = d;
            else
                D.data(i,ii) = NaN;
            end
	end

	i = i + 1;
end

% deletes unfilled data
D.time(i:end) = [];
D.data(i:end,:) = [];

% Checksum
% When "WithCheckSum" is set a Checksum (4 byte unsigned integer) is placed at 
% the end of the file. The Checksum is calculated from each byte of the file 
% except the checksum itself.
% Variable is read but not used

if D.WithCheckSum
	fseek(fid,-4,0);    % repositionning the file indicator (4 bytes backward)
	D.CheckSum = fread(fid,1,'uint32');
end

% converts time vector into Matlab format
D.time = D.time*D.dActTimeToSecondFactor/86400 + D.StartTime;

fclose(fid);

