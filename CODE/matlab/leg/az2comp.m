function s=az2comp(az)
%AZ2COMP Azimuth to compass indication
%   S = AZ2COMP(AZ) returns a text of compass direction from 
%   azimuth AZ value (in degree relative to North).
%
%   Examples:   AZ2COMP(0) returns 'N'
%               AZ2COMP(160) returns 'SSE'

%   (c) F. Beauducel, OVSG-IPGP 2003

sc = {'N','NNE','ENE','E','ESE','SSE','S','SSW','WSW','W','WNW','NNW'};
s = sc(mod(round(az*12/360),12)+1);
