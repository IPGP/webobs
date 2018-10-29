function s=boussole(az,x)
%BOUSSOLE Donne la direction!
%   BOUSSOLE(AZ) retourne une chaine de caractère donnant une abréviation 
%   de la direction ('N','SSE',...) à partir de l'azimuth AZ (en radians, 
%   conventions trogonométriques).
%
%   BOUSSOLE(AZ,1) retourne le texte complet ('au nord','à l'est-sud-est',...).

%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2005-08-09
%   Mise à jour : 2005-08-11

na = {'E','ENE','NE','NNE','N','NNW','NW','WNW','W','WSW','SW','SSW','S','SSE','SE','ESE'};
nc = {'à l''est','à l''est-nord-est','au nord-est','au nord-nord-est','au nord','au nord-nord-ouest','au nord-ouest','à l''ouest-nord-ouest','à l''ouest','à l''ouest-sud-ouest','au sud-ouest','au sud-sud-ouest','au sud','au sud-sud-est','au sud-est','à l''est-sud-est'};

sz = length(na);

k = mod(round(az*sz/(2*pi)),sz) + 1;

if nargin < 2
    s = na{k};
else
    s = nc{k};
end
