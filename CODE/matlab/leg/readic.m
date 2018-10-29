function [S,col,fon] = readic;
%READIC Importe les informations sur les cartes.
%       READIC renvoie une structure S contenant:
%           - S.map = code carte: 1 = DOM; 2 = SOU; 3 = SBT; 4 = GUA; 5 = ANT
%           - S.cde = code: 1 = ile; 2 = ville; 3 = lieu; 4 = rivière
%           - S.est = UTM est (m)
%           - S.nor = UTM nord (m)
%           - S.hal = alignement horizontal du texte
%           - S.val = alignement vertical du texte
%           - S.fwt = poids police
%           - S.fag = angle police
%           - S.fsz = taille police
%           - S.rot = rotation du texte (°)
%           - S.nom = nom de l'ile

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2003-04-23
%   Mise à jour : 2004-07-22

X = readconf;

f = sprintf('%s/Infos_Cartes.conf',X.RACINE_FICHIERS_CONFIGURATION);

col = {[.1 .1 .1],[.2 .2 .2],[.2 .2 .2],[0 .5 1],[0 .5 1]};
fon = {'Arial','Arial','Arial','Arial','Times'};
[map,cde,est,nor,hal,val,fwt,fag,fsz,rot,nom] = textread(f,'%n%n%n%n%q%q%q%q%n%n%q','commentstyle','shell');
for i = 1:length(nom)
    [t,r] = strtok(nom{i},';');
    if ~isempty(r)
        nom{i} = {t,r(2:end)};
    end
end
S = struct('map',num2cell(map),'cde',num2cell(cde),'est',num2cell(est),'nor',num2cell(nor), ...
    'hal',hal,'val',val,'fwt',fwt,'fag',fag,'fsz',num2cell(fsz),'rot',num2cell(rot),'nom',nom);
disp(sprintf('Fichier: %s importé.',f))
