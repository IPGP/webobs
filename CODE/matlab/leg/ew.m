function ew
%EW Configuration EarthWorm
%   - fabrique un fichier EW_HELI_SISMO??_CONF_FILE contenant les paramètres pour les 
%     tambours EW (stations SISMOCP et SISMOLB)

%   Auteurs: F. Beauducel + A. Nercessian, OVSG-IPGP
%   Création : 2007-02-25
%   Mise à jour : 2007-02-25

X = readconf;

rname = 'ew';
timelog(rname,1)

% --- Variables
% stations avec SGRAM (alias)
sgram = {'AMCL','LKGL','CDEL','MMLL','TAGZ','TBGZ','HMGZ'};

f = sprintf('%s/%s/%s',X.RACINE_FTP,X.EW_PATH_FTP,X.EW_HELI_CONF_FILE);
fid = fopen(f,'wt');

% --- Stations courte-période
S = readst('SZ','G');
for i = 1:length(S.ali)
	if ~strcmp(S.ali(i),'-')
		if S.clb(i).nx < 3
			cdc = {S.ali(i),{'Z'}};
		else
			cdc = {S.clb(i).nm,S.clb(i).cd};
		end
		for ii = 1:length(cdc{1})
			fprintf(fid,' Plot %s %2s  SG 24 24  -4  AST  1  0  900  10  15 1. 1.  1   "%s %s"  CP',cdc{1}{ii},cdc{2}{ii},S.nom{i},cdc{2}{ii});
			if ii == 1 & ~isempty(find(strcmp(S.ali(i),sgram)))
				fprintf(fid,' SGRAML');
			end
			fprintf(fid,'\n');
		end
	end
end

% --- Stations large-bande
S = readst('SL','G');
for i = 1:length(S.ali)
	if ~strcmp(S.ali(i),'-')
		cdc = {S.clb(i).nm,S.clb(i).cd};
		for ii = 1:length(cdc{1})
			fprintf(fid,' Plot %s %2s  SG 24 24  -4  AST  1  0  900  10  15 1.2 .04  1   "%s %s"  LB',cdc{1}{ii},cdc{2}{ii},S.nom{i},cdc{2}{ii});
			if ii == 1 & ~isempty(find(strcmp(S.ali(i),sgram)))
				fprintf(fid,' SGRAML');
			end
			fprintf(fid,'\n');
		end
	end
end

fclose(fid);
disp(sprintf('Fichier: %s créé.',f));

timelog(rname,2)

