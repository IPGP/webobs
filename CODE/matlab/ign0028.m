function c = ign0028(e);
%IGN0028 Calcul des coefficients pour la projection Mercator Transverse
%       C=IGN0028(E) renvoie un vecteur C de 5 coefficients à partir du paramètre:
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
     -901/184320, 0,  -9/1024, 0,  -1/96, 0,  1/8, 0, 0;
     -311/737280, 0,  17/5120, 0, 13/768, 0,    0, 0, 0;
      899/430080, 0, 61/15360, 0,      0, 0,    0, 0, 0;
  49561/41287680, 0,        0, 0,      0, 0,    0, 0, 0];
for i = 1:size(c0,1)
    c(i) = polyval(c0(i,:),e);
end
