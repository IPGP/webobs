function [x,y] = ign0030(lc,n,xs,ys,e,l,p);
%IGN0030 Transformation de coordonnées géographiques en coordonnées projection Mercator Transverse.
%       [X,Y]=IGN0030(LC,N,XS,YS,E,LAM,PHI) renvoie les coordonnées en projection 
%       Transverse Mercator X et Y à partir des paramètres:
%           LC = longitude origine par rapport au méridien origine
%           N = rayon de la sphère intermédiaire
%           XS,YS = constantes sur X, Y
%           E = première excentricité de l'ellipsoide
%           LAM = longitude
%           PHI = latitide
%
%       Autres algorithmes utilisés: IGN0001, IGN0028; IGN0052

%   Bibliographie:
%       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-13

% Jeux d'essai
%lc = -0.05235987756; n = 6375697.8456; xs = 500000; ys = 0; e = 0.08248340004; l = -0.0959931089; p = 0.6065019151;

c = ign0028(e);
L = ign0001(p,e);
P = asin(sin(l - lc)./cosh(L));
LS = ign0001(P,0);
L = atan(sinh(L)./cos(l - lc));

z = complex(L,LS);
Z = n.*c(1).*z + n.*(c(2)*sin(2*z) + c(3)*sin(4*z) + c(4)*sin(6*z) + c(5)*sin(8*z));
x = imag(Z) + xs;
y = real(Z) + ys;
