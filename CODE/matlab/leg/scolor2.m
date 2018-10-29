function c = scolor2(i)
%SCOLOR2 Renvoie une couleur RVB
%       SCOLOR2(I) renvoie un vecteur [R V B] pour l'index I.

% Ordre des couleurs
cc = hsv(10);

c = cc(mod(i-1,size(cc,1))+1,:);
