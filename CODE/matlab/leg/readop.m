function S = readop;
%READOP Importe les codes opérateurs OVSG.
%       READOP renvoie une structure S contenant:
%           - S.code = initiales
%           - S.name = nom complet

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-10-20
%   Mise à jour : 2001-10-20

f = 'data/Operateurs_OVSG.txt';
[code,name] = textread(f,'%s%q','commentstyle','shell');
S = struct('code',code,'name',name);
disp(sprintf('Fichier: %s importé.',f))
