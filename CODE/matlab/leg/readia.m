function S = readia;
%READIA Importe les informations sur les iles et villes des Antilles.
%       READIA renvoie une structure S contenant:
%           - S.cde = code: 0 = ile; 1 = ile Guadeloupe; 2 = ville
%           - S.lat = latitude
%           - S.lon = longitude
%           - S.hal = alignement horizontal du texte
%           - S.val = alignement vertical du texte
%           - S.fwt = poids police
%           - S.fag = angle police
%           - S.fsz = taille police
%           - S.nom = nom de l'ile

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-08-16
%   Mise à jour : 2004-06-22

X = readconf;

f = sprintf('%s/Infos_Antilles.txt',X.RACINE_FICHIERS_CONFIGURATION);
[cde,lon,lat,hal,val,fwt,fag,fsz,nom] = textread(f,'%n%n%n%q%q%q%q%n%q','commentstyle','shell');
S = struct('cde',num2cell(cde),'lat',num2cell(lat),'lon',num2cell(lon), ...
    'hal',hal,'val',val,'fwt',fwt,'fag',fag,'fsz',num2cell(fsz),'nom',nom);
disp(sprintf('File: %s imported.',f))
