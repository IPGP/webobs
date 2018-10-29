function H=loadhebdo(f,tlim)
%LOADHEBDO Charge l'hebdo OVSG.
%       LOADHEBDO sans argument charge les événements concernant le jour
%       courant et renvoie une structure :
%           - H.dt1 = date début (format DATENUM)
%           - H.dt2 = date fin
%           - H.typ = type
%           - H.obs = liste des personnels OVSG
%           - H.col = liste des collaborateurs
%           - H.lieu = lieu
%           - H.obj = objet
%
%       LOADHEBDO(FILENAME,TLIM) utilise le fichier FILENAME et l'intervalle
%       TLIM = [T1,T2].
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-07-12
%   Mise à jour : 2004-09-03

X = readconf;

if nargin < 1
    f = sprintf('%s/%s',X.RACINE_DATA_DB,X.HEBDO_FILE_NAME);
end
if nargin < 2
    tlim = floor(now) + [0,.99];
end

[chc,chn] = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.HEBDO_FILE_TYPE_EVENEMENTS),'%s%s','delimiter','|','commentstyle','shell');
[dt1,h1,dt2,h2,typ,obs,col,lieu,obj] = textread(f,'%s%s%s%s%s%s%s%s%s','delimiter','|');
dd = [char(dt1),char(h1)];
z1 = str2double([cellstr(dd(:,1:4)),cellstr(dd(:,6:7)),cellstr(dd(:,9:10)),cellstr(dd(:,11:12)),cellstr(dd(:,14:15))]);
z1(find(isnan(z1))) = 0;
dte1 = datenum([z1,zeros(size(dt1))]);
dd = [char(dt2),char(h2)];
z2 = str2double([cellstr(dd(:,1:4)),cellstr(dd(:,6:7)),cellstr(dd(:,9:10)),cellstr(dd(:,11:12)),cellstr(dd(:,14:15))]);
z2(find(isnan(z2))) = 0;
dte2 = datenum([z2,zeros(size(dt1))]);
k = find(dte1 <= tlim(2) & dte2 >= tlim(1));

H.chp = {chc,chn};

H.dt1 = dte1(k);
H.dt2 = dte2(k);
H.typ = typ(k);
H.obs = obs(k);
H.col = col(k);
H.lieu = lieu(k);
H.obj = obj(k);

disp(sprintf('Fichier: %s importé.',f));