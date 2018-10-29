function C = readcz;
%READCZ Importe les codes zones OVSG.
%       READCZ lit le fichier "data/Codes_Zones_OVSG.txt" et renvoie une 
%       structure C contenant:
%           - C.nom = nom de la zone géographique
%           - C.cod = code(s) des stations

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-12-27
%   Mise à jour : 2004-06-22

X = readconf;

f = sprintf('%s/Codes_Zones_OVSG.txt',X.RACINE_FICHIERS_CONFIGURATION);
[n,c] = textread(f,'%q%[^\n]','commentstyle','shell');
C.nom = n;
C.cod = c;
disp(sprintf('Fichier: %s importé.',f))
