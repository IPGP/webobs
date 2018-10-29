function S = timescales;
%TIMESCALES Import information about time scales
%       TIMESCALES returns a structure S containing:
%           - S.key = 3-letter used for filenames extension and RESEAUX.conf
%           - S.nam: displayed on webpages (must be short)
%           - S.day: duration in days
%
%
%   Author: F. Beauducel, IPGP
%   Created: 2010-06-12

X = readconf;

f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.MKGRAPH_FILE_TIMESCALES);
[key,nam,day] = textread(f,'%q%q%n','delimiter','|','commentstyle','shell');
S.key = key;
S.nam = nam;
S.day = day;
disp(sprintf('File: %s imported.',f))
