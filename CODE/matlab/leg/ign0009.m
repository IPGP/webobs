function [x,y,z] = ign0009(l,p,he,a,e);
%IGN0009 Transformation de coordonnées géographiques ellipsoidales en coordonnées cartésiennes.
%       [X,Y,Z]=IGN0009(LAM,PHI,HE,A,E) renvoie les coordonnées cartésiennes X,Y,Z à 
%       partir des paramètres:
%           LAM = longitude par rapport au méridien origine
%           PHI = latitude
%           HE = hauteur au dessus de l'ellipsoide
%           A = demi-grand axe de l'ellipsoide
%           E = première excentricité de l'ellipsoide
%
%       Autre algorithme utilisé: IGN0021

%   Bibliographie:
%       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-13

N =  ign0021(p,a,e);

x = (N + he).*cos(p).*cos(l);
y = (N + he).*cos(p).*sin(l);
z = (N.*(1 - e*e) + he).*sin(p);

