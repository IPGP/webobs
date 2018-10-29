function pp = mketat(p,t,d,s,tu,a)
%MKETAT Ecrit l'état des stations
%       MKETAT(P,T,D,S,TU,A) exporte les dernières données dans "data/etats.dat":
%           - P = pourcentage état station
%           - T = date et heure dernière donnée
%           - D = chaine des dernières données ou nombre de stations du réseau
%           - S = code station (minuscules) ou réseau (majuscules)
%           - TU = fuseau horaire (0 = TU, -4 = local)
%           - A = pourcentage acquisition
%
%       Si P ou A est un vecteur, la moyenne est calculée.

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-06-01
%   Mise à jour : 2004-06-22

X = readconf;

f = sprintf('%s/data/etats.dat',X.RACINE_OUTPUT_MATLAB);

if length(p) > 1
    p = mean(p(find(p ~= -1)));
end
p = round(p);
a = round(mean(a));

if (p < 50 | a <= 50) & p ~= -1
    if p < 50
        if t < now-1
            st = 'x';
        else
            st = 'X';
        end
    else
        st = '?';
    end
else
    st = '-';
end

if isnan(t)
    tv = zeros(1,6);
else
    tv = datevec(t);
end
fid = fopen(f,'at');
fprintf(fid,'%s %11s %03d %03d %4d-%02d-%02d %02d:%02d:%02.0f %+d %s\n',st,s,p,a,tv,tu,d);
fclose(fid);
disp(sprintf('File: %s updated (%s).',f,s))

if nargout
    pp = p;
end
