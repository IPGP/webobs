function D = sismoecole;
%SISMOECOLE Construit un catalogue de sismicité pour le projet "Sismo à l'Ecole"
%	- à partir de la dernière sauvegarde de "hypoovsg.txt" (HYPO_past.mat)
%	- catalogue simplifié: date, heure, lat, lon, prof, mag, commentaire
%	- le commentaire est construit spécialement, ex: "52 km à l'est de Marie-Galante"

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2006-12-16
%   Mise à jour : 2007-02-15

X = readconf;

rcode = 'SISMOECOLE';
timelog(rcode,1)

% Variables
ff = sprintf('%s/%s/%s',X.RACINE_FTP,X.SISMOECOLE_PATH_FTP,X.SISMOECOLE_CATALOGUE);
f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.SISMO_REGIONS_FILE);
[IC.lon,IC.lat,IC.nom] = textread(f,'%n%n%q','commentstyle','shell');
disp(sprintf('Fichier: %s chargé.',f));
latkm = 6370*pi/180;                        % valeur du degré latitude (en km)
lonkm = latkm*cos(16*pi/180);               % valeur du degré longitude (en km)
ttu = now+4/24;			% date TU
delai = 60;			% délai glissant du bulletin (en jours)
mdmin = 2;			% magnitude minimale

% chargement des derniers hypocentres (2004 - présent)
f = sprintf('%s/past/HYPO_past.mat',X.RACINE_OUTPUT_MATLAB);
load(f,'DH');
disp(sprintf('Fichier: %s chargé.',f));

[t,j] = sort(DH.tps);
k = find(DH.tps >= (ttu - delai) & DH.mag >= mdmin);
kk = j(k);

% exportation du catalogue
fid = fopen(ff,'wt');
fprintf(fid,[repmat('#',1,79),'\n']);
fprintf(fid,'# CATALOGUE DU RÉSEAU SISMOLOGIQUE PERMANENT DE LA GUADELOUPE\n');
fprintf(fid,'# Institut de Physique du Globe de Paris\n# Observatoire Volcanologique et Sismologique de Guadeloupe\n');
fprintf(fid,'# Le Houëlmont, 97113 Gourbeyre, Guadeloupe, FWI\n# Tél: 05 90 99 11 33 - Fax: 05 90 99 11 34\n');
fprintf(fid,'# Contact: %s\n# Mise à jour: %s (GMT)\n#\n',X.SISMO_EMAIL,datestr(ttu));
fprintf(fid,'# Filtres:\n');
fprintf(fid,'# - magnitudes >= %g\n',mdmin);
fprintf(fid,'# - délai < %g jours\n',delai);
fprintf(fid,'#\n');
fprintf(fid,'# Explication des champs:\n');
fprintf(fid,'# - Réseau: OVSG-IPGP\n');
fprintf(fid,'# - Date: AAAA-MM-JJ (TU, format ISO 8601)\n');
fprintf(fid,'# - Heure: hh:mm:ss (TU, format ISO 8601)\n');
fprintf(fid,'# - Lat: latitude (en ° positif vers le N)\n');
fprintf(fid,'# - Lon: longitude (en ° positif vers l''Est)\n');
fprintf(fid,'# - Prof: profondeur (en km)\n');
fprintf(fid,'# - Mag: magnitude\n');
fprintf(fid,'# - Type: type de magnitude (MD = magnitude de durée)\n');
fprintf(fid,'# - MSK: intensité max en Guadeloupe (I = non ressenti)\n');
fprintf(fid,'# - Commentaire: région épicentrale\n');
fprintf(fid,'#\n# Réseau\tDate      \tHeure   \tLat  \tLon   \tProf\tMag\tType\tMSK\tCommentaire\n');
for i = 1:length(kk)
	ki = kk(i);
	depi = sqrt(((IC.lon - DH.lon(ki))*lonkm).^2 + ((IC.lat - DH.lat(ki))*latkm).^2);
	[xx,iv] = sort(depi);
	if depi(iv(1)) >= 2
		com = sprintf('%1.0f km %s %s',depi(iv(1)),boussole(atan2(DH.lat(ki) - IC.lat(iv(1)),DH.lon(ki) - IC.lon(iv(1)))),IC.nom{iv(1)});
	else
		com = sprintf('%s',IC.nom{iv(1)});
	end
	if ~isnan(DH.tps(ki))
		fprintf(fid,'OVSG-IPGP\t%s\t%s\t%1.2f\t%1.2f\t%3.0f\t%1.1f\tMD\t%s\t%s\n',datestr(DH.tps(ki),'yyyy-mm-dd'),datestr(DH.tps(ki),'HH:MM:SS'),DH.lat(ki),DH.lon(ki),DH.dep(ki),DH.mag(ki),romanx(DH.msk(ki)),com);
	else
		disp('* WARNING: NaN date value !!');
	end
end

fclose(fid);
disp(sprintf('Fichier: %s créé.',ff));
ffp = sprintf('%s/%s',X.RACINE_FTP,X.SISMO_PUBLIC_PATH_FTP);
unix(sprintf('cp -f %s %s',ff,ffp));
disp(sprintf('... fichier copié dans %s.',ffp));

timelog(rcode,2)
