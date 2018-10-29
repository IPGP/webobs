function C = readcs;
%READCS Importe les codes de séismes
%       READCS renvoie une cellule C contenant:
%           - C(1,:) = code type de séisme (2 lettres)
%           - C(2,:) = nom complet
%           - C(3,:) = nom abrégé (communiqués)

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-01-04
%   Mise à jour : 2009-10-07

X = readconf;

f = sprintf('%s/codes_seismes.txt',X.RACINE_FICHIERS_CONFIGURATION);
[cde,nom,abr] = textread(f,'%q%q%q','commentstyle','shell');
C = [cde';nom';abr'];
disp(sprintf('File: %s imported.',f))
