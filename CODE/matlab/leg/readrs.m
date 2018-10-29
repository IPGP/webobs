function S = readrs;
%READRS Importe les codes de réseaux OVSG.
%       READRS renvoie une structure S contenant:
%           - S.nam = nom complet
%           - S.ext = nom court (pour fichiers)
%           - S.cde = liste codes 1 ou 2 caractères
%           - S.sit = type de site
%           - S.mrk = marqueur
%           - S.mks = taille marqueur
%           - S.rvb = couleur RVB marqueur
%           - S.map = type de carte utilisée (code binaire AGBSD)
%           - S.dex = nom court discipline
%           - S.dis = nom discipline associée

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-08-27
%   Mise à jour : 2003-01-02

f = 'data/Reseaux_OVSG.txt';
[nam,ext,cde,sit,mrk,mks,r,v,b,map,dex,dis,obs] = textread(f,'%q%s%q%q%s%n%n%n%n%q%q%q%q','commentstyle','shell');

% Décodage du code cartes AGSD
M = {'ANT','GUA','SBT','SOU','DOM'};
for i = 1:length(map)
    k = find(map{i}=='1');
    mp{i} = M(k);
end
S = struct('nam',nam,'ext',ext,'cde',cde,'sit',sit,'mrk',mrk,'mks',mks,'rvb',[r v b],'map',mp','dex',dex,'dis',dis,'obs',obs);
disp(sprintf('Fichier: %s importé.',f))
