function S = readus;
%READUS Importe les opérateurs OVSG.
%       READUS renvoie une structure S contenant:
%           - S.cod = initiales
%           - S.nom = nom de l'opérateur
%           - S.ope = niveau
%           - S.usr = login
%           - S.mel = email
%           - S.anv = date naissance

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-01-21
%   Mise à jour : 2007-03-02

X = readconf;

f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_OPERATEURS);
[cod,nom,ope,usr,mel,anv] = textread(f,'%q%q%q%q%q%q%*[^\n]','delimiter','|','commentstyle','shell');
S.cod = cod;
S.nom = nom;
S.ope = str2double(ope);
S.usr = usr;
S.mel = mel;
S.anv = anv;
disp(sprintf('Fichier: %s importé (%d utilisateurs).',f,length(cod)))
