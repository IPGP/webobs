function [t,d] = loadsuds2(fn,sfr,fhz,ptmp,prog)
%LOADSUDS2 lit les fichiers SUDS2.
%	[T,D] = LOADSUDS2(FILENAME,V,FHZ,PTMP,PROG) renvoie un vecteur T et une matrice des
%	signaux D à partir du fichier FILENAME, de la liste des voies V, de la fréquence
%	d'échantillonnage FHZ, du répertoire temporaire PTMP et du programme sud2mat
%	identifié par PROG.

[ss,xx] = unix(sprintf('basename %s',fn));
fnam = xx(1:end-1);
ftmp = sprintf('%s/tmp2.mat',ptmp);
delete(sprintf('%s/*.*',ptmp));
unix(sprintf('cp -f %s %s/.',fn,ptmp));
if unix(sprintf('%s %s/%s %s >&! /dev/null',prog,ptmp,fnam,ftmp))
	t = [];  d = [];
	return;
end
S = load(ftmp);
vn = who('-file',ftmp); % recupere les noms de variables
for i = 1:length(sfr)
        ii = find(strcmp(sfr(i),vn)); % attention: sfr contient le nom complet de la variable signal
        if ~isempty(ii)
                eval(sprintf('D(i).d = S.%s;',vn{ii}));
                eval(sprintf('D(i).rate = S.%s_rate;',vn{ii}));
                eval(sprintf('D(i).t0 = S.%s_t0;',vn{ii}));
                D(i).name = vn{ii};
                % conversion temps unix => matlab
                D(i).t0 = datenum(1970,1,1) + D(i).t0/86400;
	        % vecteur temps
                D(i).t = D(i).t0 + (0:1/(86400*D(i).rate):(size(D(i).d,1)-1)/(86400*D(i).rate))';
                D(i).tmax = max(D(i).t);
        else
                disp(sprintf('Warning: signal %s not found in file %s !',sfr{i},fnam))
        end
end


if ~exist('D','var')
	t = [];  d = [];
	return;
end

% vecteur temps unique
t = (min(cat(1,D.t0)):1/(86400*fhz):max(cat(1,D.tmax)))';

% matrice donnees decimees
d = zeros(size(t,1),length(sfr));
for i = 1:length(sfr)
	if length(D)>=i & length(D(i).d)>0 & D(i).rate>fhz
		dd = rdecim(D(i).d,D(i).rate/fhz);
		if length(dd)==size(d,1)
			d(:,i) = dd;
		else
			if length(dd)>size(d,1)
				d(:,i) = dd(1:size(d,1));
			else
				d(1:length(dd),i) = dd;
			end
			disp(sprintf('Warning: sampling problem with signal %s (%d/%d samples after decimation)',sfr{i},length(dd),size(d,1)));
		end
	end	
end

disp(sprintf('File: %s imported.',fn));

