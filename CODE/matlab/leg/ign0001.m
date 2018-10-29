function l = ign0001(p,e)
%IGN0001 Calcul de la latitude isométrique
%       L = IGN0001(PHi,E) renvoie la altitude isométrique à partir des paramètres:
%           PHI = latitude
%           E = première excentricité de l'ellpsoide

%   Bibliographie:
%       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-13

% Jeux d'essai
%e = 0.08199188998; p = 0.872664626;
l = log(tan(pi/4 + p/2).*(((1 - e*sin(p))./(1 + e*sin(p))).^(e/2)));
