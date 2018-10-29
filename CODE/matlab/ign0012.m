function [l,p,h] = ign0012(x,y,z,a,e,EPS);
%IGN0012 Transformation de coordonnées cartésiennes en coordonnées géographiques.
%       [LAM,PHI,HE]=IGN0012(X,Y,Z,A,E,EPS) renvoie les coordonnées géographiques LAM
%       (longitude par rapport au méridien origine), PHI (latitude) et HE (auteur ellipsoidale)
%       à partir des paramètres:
%           X,Y,Z = coordonnées cartésiennes
%           A = demi-grand axe de l'ellipsoide
%           E = première excentricité de l'ellipsoide
%           EPS = tolérance de convergence, en rad (défaut = 1E-11)

%   Bibliographie:
%       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-14


% Jeu d'essai
%a = 6378249.2; e = 0.08248325679; x = 6376064.695; y = 111294.623; z = 128984.725;

if nargin < 6
    EPS = 1e-11;
end
IMAX = 10;               % Imax = nombre maximum d'itérations

R = sqrt(x.*x + y.*y);
l = 2*atan(y./(x + R));
p0 = atan(z./sqrt(x.*x + y.*y.*(1 - (a*e*e)./sqrt(x.*x + y.*y + z.*z))));
i = 0;
fin = 0;
while i < IMAX & ~fin
    i = i + 1;
    p1 = atan((z./R)./(1 - (a*e*e*cos(p0))./(R.*sqrt(1 - e*e*sin(p0).^2))));
    res = max(abs(p1-p0));
    if res < EPS
        fin = 1;
    end
    p0 = p1;
end
if fin
    p = p1;
    h = R./cos(p) - a./sqrt(1 - e*e*sin(p).^2);
else
    error('Problème de convergence...');
end
