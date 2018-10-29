function X=readconf(f);
%READCONF Read the WEBOBS configuration file
%   READCONF retunrs a structure variable containing every field key and
%   corresponding value from "WEBOBS.conf".
%
%   READCONF(F) reads the file F instead of default.
%
%   Note this is the only function that needs hard coding of WEBOBS path
%   for default "WEBOBS.conf" file. Needs to define a symbolic link
%   /etc/webobs pointing to the WEBOBS 'CONFIG' directory.
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2004-04-20
%   Modified: 2010-06-04


if nargin < 1
    f = '/etc/webobs/WEBOBS.conf';
end
[x,v] = textread(f,'%s%[^\n]','delimiter','|','commentstyle','shell');
for i = 1:length(x)
	vv = strrep(v{i},'''','''''');
    eval(sprintf('X.%s=''%s'';',x{i},vv));
end
%disp(sprintf('WEBOBS: %s read.',f));

