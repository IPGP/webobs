function t = datesys2num(s)
%DATESYS2NUM Translate a system date string in datenum.
%   System dates are of the form '27-aoû-2003 10:10:08' in French and 
%   '27-Aug-2003 10:10:08' in English.
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2004-04-27
%   Updated: 2015-03-25

mois = {'jan','fév','mar','avr','mai','jun','jui','aoû','sep','oct','nov','déc'};
month = {'jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'};

if ~iscell(s)
    s = cellstr(s);
end
sz = length(s);
    
t = zeros(size(s));
for i = 1:sz
    dt = s{i};
    jj = str2double(dt(1:2));
    mm = dt(4:6);
    mm = find(strcmp(lower(mm),mois) | strcmp(lower(mm),month));
    yy = str2double(dt(8:11));
    hh = str2double(dt(13:14));
    nn = str2double(dt(16:17));
    ss = str2double(dt(19:20));
    t(i) = datenum(yy,mm,jj,hh,nn,ss);
end

