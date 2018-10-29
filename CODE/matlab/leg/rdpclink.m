function [t,d] = rdpclink(p,y,m,ext)
%RDPCLINK   Read PCLINK database files (DAVIS INSTRUMENTS).
%   [T,D] = RDPCLINK(F) or RDPCLINK(P,YYYY,MM,EXT) imports data from 
%   file F or 'P/YYYY-MM.EXT' and return a vector time T (Matlab format) 
%   and 14-column matrix data D:
%       - D(:,3) = inside temperature (°C)
%       - D(:,5) = barometer (mm Hg)
%       - D(:,6) = inside humidity (%)
%       - D(:,14) = acquisition time interval (minutes)

%   Author: F. Beauducel, OVSG
%   Reference: "Weather Link serial communication reference", Davis Instruments, 1999.
%   Creation: 2001-09-02
%   Modified: 2001-09-03

MAX_DAYS_IN_MONTH = 31;

if nargin == 4
    f = sprintf('%s/%04d-%02d.%s',p,y,m,ext);
else
    f = p;
    y = str2double(f((end-10):(end-7)));
    m = str2double(f((end-5):(end-4)));
end
[fid,message] = fopen(f);
if fid == -1, disp(message), end

HD.idcode = char(fread(fid,16,'uchar'));
HD.num_days = fread(fid,1,'int16');
HD.tot_recs = fread(fid,1,'int32');
for i = 1:MAX_DAYS_IN_MONTH
    HD.num_recs(i) = fread(fid,1,'int16');
    HD.index(i) = fread(fid,1,'int32');
end
dd = fread(fid,[12 HD.tot_recs],'int16')';
fclose(fid);

%struct weatherData
%{
%   int packedTime;               // minuts since midnight (0-1440)
%   int hiOutsideTemperature;     // in 1/10'ths of a degree F
%   int lowOutsideTemperature;    // in 1/10'ths of a degree F
%   int insideTemperature;        // in 1/10'ths of a degree F
%   int outsideTemperature;       // in 1/10'ths of a degree F
%   int barometer;                // in 1/1000'ths of an inch Hg
%   unsigned char insideHumidity; // in percent (0-100)
%   unsigned char outsideHumidity;// in percent (0-100)
%   int DewPoint;                 // in 1/10'ths of a degree F
%   int rain;                     // encoded rain clicks, see below
%   unsigned char windSpeed;      // in miles per hour
%   unsigned char windGust;       // in miles per hour
%   int WindChill;                // in 1/10'ths of a degree F
%   unsigned char windDirection;  // encoded wind direction, see below
%   unsigned char archiveInterval;// in minutes
%};


% ---- Assign time references for each day of the month
t = ones([HD.tot_recs 1])*datenum(y,m,0);
for j = 1:MAX_DAYS_IN_MONTH
    i = (1:HD.num_recs(j)) + HD.index(j);
    t(i) = t(i) + j + dd(i,1)/1440;
end

% ---- Construct data matrix d from dd
d = zeros([HD.tot_recs 14]);
d(:,[1:5 8:9 12]) = dd(:,[2:6 8:9 11]);
% Rebuilt real unsigned char
i = [7 10 12];
xx = dd(:,i);
k = find(xx < 0);
xx(k) = xx(k) + 2^16;
dd(:,i) = xx;

% Split double uchar in channels 7, 10, and 12
xx = dec2hex(dd(:,7),4);
d(:,6) = hex2dec(xx(:,3:4));
d(:,7) = hex2dec(xx(:,1:2));
xx = dec2hex(dd(:,10),4);
d(:,10) = hex2dec(xx(:,3:4));
d(:,11) = hex2dec(xx(:,1:2));
xx = dec2hex(dd(:,12),4);
d(:,13) = hex2dec(xx(:,3:4));
d(:,14) = hex2dec(xx(:,1:2));


% ---- Assign NaN for invalid data
% Temperatures
i = [1:4 8 12];
dd = d(:,i);
k = find(dd == -32768);
dd = (dd/10 - 32)/1.8;
dd(k) = dd(k)*NaN;
d(:,i) = dd;

% Humidity
i = [6:7];
dd = d(:,i);
k = find(dd == 128);
dd(k) = dd(k)*NaN;
d(:,i) = dd;

% Barometer
i = 5;
dd = d(:,i);
k = find(dd==-32768);
dd = dd*25.4/1000;
dd(k) = dd(k)*NaN;
d(:,i) = dd;

% Wind direction
i = 13;
dd = d(:,i);
k = find(dd == 255);
dd(k) = dd(k)*NaN;
d(:,i) = dd;

