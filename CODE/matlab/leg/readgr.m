function [G,D]=readgr(r);
%READGR Lit les paramètres graphiques à partir de "RESEAUX.conf" (ancien "GRAPH.conf")
%   G = READGR(RCODE) renvoie une structure G contenant tous les champs associés à la routine RCODE
%   en ajoutant les champs:
%       G.rcd = code routine (RCODE)
%       G.dnm = nom complet de la discipline correspondant au code G.dis
%       G.smk = code du symbole discipline correspondant au code G.dis
%       G.lim = intervalles de temps correspondants à la liste G.ext (basé sur l'heure du serveur)
%	G.now = temps présent (en heure réseau G.utc)
%
%   N = READGR renvoie une structure N avec la liste des réseaux:
%       N().nom = Nom complet du réseau
%       N().cod = Lettre(s) du réseau pour importation des codes stations
%       N().snm = Nom commun d'un site
%       N().ssz = Taille du symbole du site
%       N().rvb = Couleur du symbole en Rouge-Vert-Bleu normalisé
%       N().map = Liste des codes des cartes (ANT/GUA/SBT/SOU/DOM)
%       N().dis = Code de regroupement des réseaux par grandes disciplines: code
%       		renvoyant au champs correspondant
%       N().smk = Code du symbole discipline
%       N().dnm = Nom complet de la discipline
%
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2004-05-28
%   Updated: 2010-07-03

X = readconf;

% temps présent en heure TU
tnow = now - str2double(X.MATLAB_SERVER_UTC)/24;

f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_MATLAB_CONFIGURATION);
T = timescales;
M = {'MSR','SHV'};

[x,s,v] = textread(f,'%q%q%q','delimiter','|','commentstyle','shell');

% --- cas de la lecture d'une seule routine
if nargin > 0
	r = upper(r);	% toutes les routines sont en majuscules
	for i = 1:length(x)
		if strcmp(x(i),r)
			eval(sprintf('G.%s=%s;',s{i},v{i}),'disp(sprintf(''** Warning: READGR : problem reading parameter "%s|%s"'',r,s{i}))');
		end
	end
	if ~exist('G')
		error(sprintf('READGR: routine "%s" does not exists !',r));
	end
	if ~isfield(G,'utc')
		G.utc = 0;
	end
	G.now = tnow + G.utc/24;
    
	if isfield(G,'ext')
		for i = 1:length(G.ext)
			k = find(strcmp(T.key,G.ext{i}));
			if ~isempty(k)
				G.lim{i} = G.now - [T.day(k),0];
			else
				G.lim{i} = G.now - [0,0];
			end
		end
	end
    if isfield(G,'dis')
        k = find(strcmp(x,G.dis) & strcmp(s,'dnm'));
        if ~isempty(k)
            eval(sprintf('G.dnm=%s;',v{k}));
        end
        k = find(strcmp(x,G.dis) & strcmp(s,'smk'));
        if ~isempty(k)
            eval(sprintf('G.smk=%s;',v{k}));
        end
    end
    G.rcd = r;

% --- cas de la lecture complète du fichier
else

    k = find(strcmp(x,'DISCIPLINE'));
    for i = 1:length(k)
        eval(sprintf('D.%s=%s;',s{k(i)},v{k(i)}),'disp(sprintf(''** Warning: READGR : problem reading parameter "DISCIPLINE|%s"'',s{k(i)}))');
    end
    k = find(strcmp(s,'net') & ~strcmp(v,'0'));
    for i = 1:length(k)
        kk = find(strcmp(x,x(k(i))));
        for ii = 1:length(kk)
            eval(sprintf('G(%d).%s=%s;',i,s{kk(ii)},v{kk(ii)}),'disp(sprintf(''** Warning: READGR : problem reading parameter "%s|%s"'',x{k(i)},s{kk(ii)}))');
        end
        if isfield(G(i),'cod') & isfield(D,'cod')
            kk = find(strcmp(D.cod,G(i).cod(1)));
            if ~isempty(kk)
                G(i).dis = D.key{kk};
                G(i).dnm = D.nom{kk};
		if ~isfield(G,'smk') | isempty(G(i).smk)
			G(i).smk = D.mrk{kk};
		end
            end
        end
	if ~isfield(G(i),'utc')
	    G(i).utc = 0;
	end
        G(i).rcd = x{k(i)};
    end
    % OBSOLETE [FB, June 2010]: sort the networks following the net values...
    %[n,i] = sort(cat(1,G.net));
    %G = G(i);
end

disp(sprintf('WEBOBS: %s read.',f));

