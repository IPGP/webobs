function C = codeseisme;
%READCS Importe les codes de séismes
%       READCS renvoie une structure C contenant:
%           - C.cde = code catalogue (2 lettres)
%           - C.nom = nom complet
%           - C.cb3 = nom abrégé pour communiqués B3
%           - C.mks = code marqueur Matlab (cartes hypocentres)
%	    - C.sel = sélection (cartes hypocentres)
%	    - C.typ = type pour les statistiques
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-01-04
%   Mise à jour : 2009-10-09

X = readconf;

f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.SISMOHYP_CODES_FILE);
[C.cde,C.nom,C.cb3,C.mks,C.sel,C.typ] = textread(f,'%s%s%s%s%s%s%*[^\n]','delimiter','|','commentstyle','shell');
C.sel = str2double(C.sel);
disp(sprintf('File: %s imported.',f))
