function x = isodatenum(dt,hr)
%ISODATENUM Convert ISO date string to serial date number.
%   ISODATENUM(D) or ISODATENUM(D,H) returns Matlab serial date number (as DATENUM)
%   from ISO 8601 cell array of strings date D (format 'YYYY-MM-DD') and optional
%   hour H (format 'hh:mm:ss').
%
%   ISODATENUM(S) considers S in format 'YYYY-MM-DD hh:mm:ss'.
%
%   (c) F. Beauducel, OVSG-IPGP, 2005-2008

if ~iscell(dt)
	dt = cellstr(dt);
end
dte = char(dt);
x = zeros(size(dt));
k = find(~strcmp(dt,'NA'));
if ~isempty(k) & (size(dte,2) >= 10)
    if nargin > 1
        hre = char(hr);
        if size(hre,2) >= 8
            x(k) = datenum(str2num(dte(k,1:4)),str2num(dte(k,6:7)),str2num(dte(k,9:10)),str2num(hre(k,1:2)),str2num(hre(k,4:5)),str2num(hre(k,7:8)));
        else
            x(k) = datenum(str2num(dte(k,1:4)),str2num(dte(k,6:7)),str2num(dte(k,9:10)),str2num(hre(k,1:2)),str2num(hre(k,4:5)),zeros(size(k)));
        end
    else
        if size(dte,2) >= 19
            x(k) = datenum(str2num(dte(k,1:4)),str2num(dte(k,6:7)),str2num(dte(k,9:10)),str2num(dte(k,12:13)),str2num(dte(k,15:16)),str2num(dte(k,18:19)));
        else    
            x(k) = datenum(str2num(dte(k,1:4)),str2num(dte(k,6:7)),str2num(dte(k,9:10)));
        end
    end
end
