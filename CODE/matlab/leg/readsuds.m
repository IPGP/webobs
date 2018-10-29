function [t,d,vn,fl,it,nb_traites] = readsuds(tdeb,dec,pdon,ptmp);
%READSUDS Importe les derniers fichiers SUDS
%       [T,D,V,F,I]=READSUDS(TD) importe les fichiers SUDS à partir 
%       du temps TD et renvoie un vecteur temps T, une matrice de données D, 
%       un vecteur des noms de voies V, un vecteur des noms de fichiers F et
%       l'index I des limites de fichiers dans le vecteur T.
%       La dernière colonne de la matrice D contient un indice de 
%       synchronisation (1 = code IRIG OK, 0 = pas de code IRIG).
%
%       [...]=READSUDS(T0,DEC,P) spécifie la décimation des données DEC (par 
%       sous-échantillonnage bestial), le répertoire de données P (par défaut
%       P = '/ipgp/continu/sismo/iaspei1').
%
%   Auteurs: F. Beauducel + A. Nercessian, OVSG-IPGP
%   Création : 2003-03-12
%   Mise à jour : 2004-10-11

X = readconf;

if nargin < 2
	dec = 1;
end
if nargin < 3
	pdon = sprintf('%s/%s',X.RACINE_SIGNAUX_SISMO,X.PATH_SOURCE_SISMO_GUA);
end
if nargin < 4
	ptmp = sprintf('/tmp/sismo/suds',X.RACINE_OUTPUT_MATLAB);
end

if ~isdir(ptmp)
	unix(sprintf('mkdir -p %s',ptmp));
end

% Initialisation des variables
fhz = str2num(X.IASPEI_VALUE_SAMPLING);
ftmp = sprintf('%s/sismo_lst.dat',ptmp);
prog = X.PRGM_SUD2MAT;
tol = 2/86400;      % tolérence fin de fichier (en jour)
tnow = datevec(now + 4/24);
tt0 = datevec(tdeb);
t = [];  d = [];  it = [];  vn = [];  fl = [];

nb_traites=0;
nb_traites_max=str2num(X.SISMOCP_MAX_TRAITES);

% Importation des fichiers de données SUDS (.GU*)
for ttt = floor(datenum(tt0)):floor(datenum(tnow))
	tz = datevec(ttt);
	dir0 = sprintf('%s/%d%02d%02d/',pdon,tz(1:3));
	unix(sprintf('ls -t %s%02d* > %s',dir0,tz(3),ftmp));
	fn = flipud(textread(ftmp,[dir0 '%s']));
	for j = 1:length(fn)
		s = fn{j};
		zd = str2double({s(1:2),s(3:4),s(5:6),s(7:8)});
		% traitement des secondes (fichiers sans code IRIG: [A-E]X)
		if isnan(zd(4))
			zd(4) = (double(s(7)) - double('A'))*10 + str2double(s(8));
			irig = 0;
		else
			irig = 1;
		end
		tf = datenum([tz(1:2) zd]);
		if nb_traites < nb_traites_max
			if tf >= (tdeb - tol)
				fl = [fl;fn(j)];
				delete(sprintf('%s/*.*',ptmp));
				fnam = sprintf('%s/%d%02d%02d/%s',pdon,tz(1:3),fn{j});
				unix(sprintf('cp -f %s %s/.',fnam,ptmp));
				if unix(sprintf('%s %s/%s >&! /dev/null',prog,ptmp,fn{j})) == 0
					va = [];  st = [];
					ff = sprintf('%s/tmp.mat',ptmp);
					load(ff);
					va = who('-file',ff);
					ns = length(va);
					eval(sprintf('sz = length(%s);',va{1}));
					dd = zeros(sz,ns);
					for i = 1:ns
						[zs,zr] = strtok(va{i},'_');
						j = str2double(zr(2:end)) + 1;
						vn{j} = zs;
						eval(sprintf('dd(:,j) = %s;',va{i}));
					end

					% fichier avec code IRIG: tf = heure de début de fichier (exact)
					tt = (tf + (1:sz)/(fhz*86400))';
					% fichiers sans code IRIG: tf = heure de fermeture du fichier (approximatif)
					if irig == 0
						tt = tt - diff(tt([1 end]));
					end
					if dec ~= 1
						tt = rdecim(tt,dec);
						dd = rdecim(dd,dec);
					end
					t = [t;tt];
					d = [d;[dd,ones(size(tt))*irig]];
					it = [it;length(t)];
					nb_traites=nb_traites+1;
					disp(sprintf('Fichier: %s importé (n° %d).',fnam,nb_traites));
				else
					disp(sprintf('!! Problème avec le fichier %s.',fnam));
				end
			end
		end
	end
end
delete(sprintf('%s/*.*',ptmp));
