function c = scolor(i)
%SCOLOR Renvoie une couleur RVB
%       SCOLOR(I) renvoie un vecteur [R V B] pour l'index I.

% Ordre des couleurs
cc = [0   0   1; % bleu
      0   .5  0; % vert foncé
      1   0   0; % rouge
      0   .7  .7; % turquoise
      .7  0   .7; % mauve
      .7  .7  0; % ocre (jaune foncé)
      .3  .3  .3; % gris foncé
      0   1   .5; % vert clair
      0   .5  1; % bleu ciel
      .5  0   1]; % violet
  %cc = .9*[1 0 0;0 1 0;0 0 1;1 0 1;0 1 1;1 1 0;.5 0 0;0 .5 0;0 0 .5;.5 0 .5;0 .5 .5;.5 .5 0];

c = cc(mod(i-1,size(cc,1))+1,:);
