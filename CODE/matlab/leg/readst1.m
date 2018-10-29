function S = readst(cd,ob,op);
%READST Importe les coordonnées de stations Antilles.
%       READST lit le fichier "data/Stations_WGS84.txt" et renvoie une 
%       structure S contenant:
%           - S.cod = code station (5 caractères)
%           - S.ali = alias de la station
%           - S.nom = nom complet de la station
%           - S.geo = vecteur de coordonnées géographiques WGS84 [Lat Lon Alt]
%                     en degrés décimaux et mètre pour l'altitude
%           - S.wgs = vecteur de coordonnées WGS84 UTM20 [Est Nord Alt] en mètres
%           - S.utm = vecteur de coordonnées Ste-Anne UTM20 [Est Nord Alt] en mètres
%           - S.dte = date positionning (DATENUM format)
%           - S.pos = type position (0 = inconnue, 1 = Carte, 2 = GPS)
%           - S.ope = type de station (0 = ancienne station, 1 = opérationnelle)
%           - S.obs = observatoire (OVSG, OVMP, MVO, SRU...)
%
%       READST(R) où R = {R1,R2,..} est la liste des codes de réseau,
%           sélectionne les stations correspondantes. Exemples: 
%           READST({'Z ','L'}) renvoie toutes les stations sismiques CP et LB ;
%           READST('D9') renvoie les stations de distancemétrie.
%
%      READST(R,OBS,OP) spécifie l'observatoire (défaut = tous) et le code OP
%      (pour spécifier toutes les stations, faire READST('','',...) )
%

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-08-17
%   Mise à jour : 2004-06-10

X = readconf;

% traitement des arguments d'entrée
if nargin < 1
    cd = {''};        % défaut = toutes les stations
else
    cd = cellstr(cd);
end
if nargin < 2
    ob = {'OVSG'};        % défaut = OVSG seulement
else
    ob = cellstr(ob);
end
if nargin < 3
    op = 1;         % défaut = stations opérationnelles seulement
else
    op = 0;
end

% lecture du fichier
f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_STATIONS);
[cod,ali,lat,lon,alt,pos,dte,ope,obs,nom] = textread(f,'%5c%q%n%n%n%n%q%n%q%q','commentstyle','shell');

% calcul des coordonnées UTM (WGS84 et Ste-Anne) = geo2utmwgs
wgs = geo2utmwgs([lat lon alt]);
utm = geo2utmsa([lat lon alt]);

% sélection des stations
k = [];
for i = 1:length(cd)
    for j = 1:length(ob)
        if isempty(cd{i})
            k = [k;find(ope >=op & strcmp(obs,ob(j)))];
        else
            k = [k;find(ope >=op & strcmp(cellstr(cod(:,3+find(cd{i}))),upper(deblank(cd{i}))) & strcmp(obs,ob(j)))];
        end
    end
end

% construction de la structure de sortie
S.cod = cellstr(cod(k,:));
S.ali = ali(k);
S.nom = nom(k);
S.geo = [lat(k) lon(k) alt(k)];
S.wgs = [wgs(k,1:2) alt(k)];
S.utm = [utm(k,1:2) alt(k)];
S.pos = pos(k);
S.ope = ope(k);
S.obs = obs(k);
dd = char(dte(k));
S.dte = datenum(str2double(cellstr(dd(:,1:4))),str2double(cellstr(dd(:,6:7))),str2double(cellstr(dd(:,9:10))));

disp(sprintf('Fichier: %s importé ("%s" "%s" OP>=%d %d/%d stations).',f,char(cd)',char(ob)',op,length(k),length(cod)))

