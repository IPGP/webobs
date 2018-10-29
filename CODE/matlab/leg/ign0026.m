function b = ign0026(p,c);
%IGN0026 Calcul de l'abscisse curviligne sur l'arc de méridien pour une latitude donnée.
%       BET=IGN0026(PHI,C) renvoie l'abscisse curviligne BET à partir des paramètres:
%           PHI = latitude
%           C = tableau de 5 coefficients pour arc de méridien

%   Bibliographie:
%       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-13

b = c(1)*p + c(2)*sin(2*p) + c(3)*sin(4*p) + c(4)*sin(6*p) + c(5)*sin(8*p);
