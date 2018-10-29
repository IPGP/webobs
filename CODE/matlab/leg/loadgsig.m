function [d,b,s,fs] = loadgsig(f);
%LOADGSIG Imports a GeoSIG data file.
%       [D,B,S,FS]=LOADGSIG(F) loads GeoSIG data file F and returns data vector D,
%       matrix of block information B = [T,C,I] (where T is time stamp, C is time 
%       code quality, and I is index in D of first sample), a string cell 
%       S = {SN,CN,CU} (where SN is station name, CN is channel unit, and CU is 
%       channel physical unit), and frequency sampling FS (in Hz).
%
%       (c) F. Beauducel & GeoSIG, 2003
%       Reference: "GS_DAT_Format_Description.doc", GeoSIG, 2003
%       Aknowledgments: Lukas Gaetzi (GeoSIG) and Alberto Tarchini (OVSG)

d = [];
b = [];

% Definitions
GSI_MAXNUM_CHANNELS = 6;
MAXLEN_GSS_STANAME = 5;     % name of a seismic station
MLI_STR_CHANNAME = 5;       % channel name
MLI_STR_CHUNIT = 5;         % channel physical unit

fid = fopen(f,'r');

% Data file header (66 bytes total)
w_Version = fread(fid,1,'uint16');
sz_StationName = char(fread(fid,MAXLEN_GSS_STANAME + 1,'uchar')');
sz_ChannelName = char(fread(fid,MLI_STR_CHANNAME + 1,'uchar')');
sz_ChannelUnit = char(fread(fid,MLI_STR_CHUNIT + 1,'uchar')');
f_ChannelLSB = fread(fid,1,'double');
w_SamplingRate = fread(fid,1,'uint16');
NotUsed = fread(fid,1,'uint32');
Reserved = char(fread(fid,32,'uchar')');

s = {sz_StationName,sz_ChannelName,sz_ChannelUnit};
fs = w_SamplingRate;
i = 1;

% data block read
while ~feof(fid)

    % data block header (24 bytes total)
    w_SynchroChars = fread(fid,1,'uint16');
    if feof(fid), break; end
    dw_Samples = fread(fid,1,'uint32');
    TimeTag = fread(fid,8,'uint16');
    TimeQuality = fread(fid,1,'uint8');
    Flags = fread(fid,1,'uint8');
    
	if length(TimeTag) == 8
		t = datenum(TimeTag([1,2,4:7])') + TimeTag(8)/86400000;
	else
		break;
	end
    
    % data block
    if Flags == 2
        dd = fread(fid,dw_Samples,'int16');
    else
        dd = fread(fid,dw_Samples,'int32');
    end
    d = [d;dd*f_ChannelLSB];
    b = [b;[t,TimeQuality,i]];
    i = i + dw_Samples;
end

fclose(fid);
