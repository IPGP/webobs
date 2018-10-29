function A = readacq;
%READACQ Importe les caractéristiques des acquisitions OVSG.
%       READACQ lit le fichier "data/Acquisition_OVSG.txt" et renvoie une 
%       structure A contenant:
%           - A.code = code de l'acquisition
%           - A.pc = nom réseau du PC
%           - A.disk = nom du disque de données exporté
%           - A.dt = délai autorisé (en minutes)
%           - A.tu = TU (0 ou -4)
%           - A.an = différence d'année (pb d'horloge, ex: 1982 pour 2002)
%           - A.prio = ordre de priorité (pour affichage feuille de routine)
%           - A.name = utilisation en clair

%   Auteurs: F. Beauducel & D. Mallarino, OVSG-IPGP
%   Création : 2003-06-30
%   Mise à jour : 2004-08-30

X = readconf;
f = sprintf('%s/%s.matlab',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_ACQUISITIONS);
[acode,apc,adisk,adt,atu,aan,aprio,asms,aname] = textread(f,'%s%s%s%s%s%s%s%s%q','commentstyle','shell');
%A = struct('code',acode,'pc',apc,'disk',adisk,'dt',adt,'tu',atu,'an',aan,'prio',aprio,'name',aname);
A.code = acode;
A.pc = apc;
A.disk = adisk;
A.dt = str2double(adt);
A.tu = str2double(atu);
A.an = str2double(aan);
A.prio = str2double(aprio);
A.sms = str2double(asms);
A.name = aname;
disp(sprintf('Fichier: %s importé.',f))
