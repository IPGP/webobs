function [vx,vy,vz] = ign0013b(tx,ty,tz,d,rx,ry,rz,u);
%IGN0013B Transformation de coordonnées à 7 paramètres ntre 2 systèmes - passage "inverse".
%       V=IGN0013B(TX,TY,TZ,D,RX,RY,RZ,U) renvoie le vecteur de coordonnées cartésiennes 
%       dans le système 2 V = [VX,VY,VZ] à partir des paramètres:
%           TX = translation suivant l'axe des x (de 2 vers 1)
%           TY = translation suivant l'axe des y (de 2 vers 1)
%           TZ = translation suivant l'axe des z (de 2 vers 1)
%           D = facteur d'échelle (de 2 vers 1)
%           RX = angle de rotation autour de l'axe des x, en rad (de 2 vers 1)
%           RY = angle de rotation autour de l'axe des y, en rad (de 2 vers 1)
%           RZ = angle de rotation autour de l'axe des z, en rad (de 2 vers 1)
%           U = [UX,UY,UZ] = vecteur de coordonnées cartésiennes dans le sytème 2

%   Bibliographie:
%       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2003-01-13
%   Mise à jour : 2003-01-13

% jeux d'essai
%u = [4154005.81,-80587.328,4823289.532]; tx = -69.4; ty = 18; tz = 452.2; d = -3.21e-6; rx = 0; ry = 0; rz = 0.00000499358;

ux = u(:,1);
uy = u(:,2);
uz = u(:,3);

vx = (tx - ux).*(d - 1) + (tz - uz).*ry - (ty - uy).*rz;
vy = (ty - uy).*(d - 1) + (tx - ux).*rz - (tz - uz).*rx;
vz = (tz - uz).*(d - 1) + (ty - uy).*rx - (tx - ux).*ry;

if nargout < 3
    vx = [vx,vy,vz];
end