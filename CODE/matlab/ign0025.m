function c = ign0025(e);
%IGN0025 Calcul des coefficients pour arc de méridien
%       C=IGN0025(E) renvoie un vecteur C de 5 coefficients à partir du paramètre:
%           E = première excentricité de l'ellispoide

%   Bibliographie:
%       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-13

% Jeux d'essai
%e = 0.08199188998;
c = zeros(5,1);
c0 = [-175/16384, 0,   -5/256, 0,  -3/64, 0, -1/4, 0, 1;
       -105/4096, 0, -45/1024, 0,  -3/32, 0, -3/8, 0, 0;
       525/16384, 0,  45/1024, 0, 15/256, 0,    0, 0, 0;
      -175/12288, 0, -35/3072, 0,      0, 0,    0, 0, 0;
      315/131072, 0,        0, 0,      0, 0,    0, 0, 0];
for i = 1:size(c0,1)
    c(i) = polyval(c0(i,:),e);
end
