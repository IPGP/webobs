function t = datesys2num(s)
%DATESYS2NUM Traduit une date système en date Matlab.
%   Les dates système sont de la forme '27-aoû-2003 10:10:08' pour les OS
%   en Français et '27-Aug-2003 10:10:08' pour les OS en Anglais.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-04-27
%   Mise à jour : 2004-04-27

mois = {'jan','fév','mar','avr','mai','jun','jui','aoû','sep','oct','nov','déc'};
month = {'jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'};

if ~iscell(s)
    s = cellstr(s);
end
sz = length(s);
    
t = zeros(size(s));
for i = 1:sz
    dt = s{i};
    jj = str2num(dt(1:2));
    mm = dt(4:6);
    mm = find(strcmp(lower(mm),mois) | strcmp(lower(mm),month));
    yy = str2num(dt(8:11));
    hh = str2num(dt(13:14));
    nn = str2num(dt(16:17));
    ss = str2num(dt(19:20));
    t(i) = datenum(yy,mm,jj,hh,nn,ss);
end