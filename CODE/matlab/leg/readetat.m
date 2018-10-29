function E = readetat(f);
%READETAT Importe le fichier d'état des stations OVSG.
%       READETAT importe le fichier de routine 'etats.txt' et renvoie 
%       une structure E contenant:
%           - E.st = signe état ('-','x' ou 'X')
%           - E.ss = code station ou réseau
%           - E.pp = pourcentage état
%           - E.aa = pourcentage acquisition
%           - E.dd = date dernière mesure valide (AAAA-MM-JJ)
%           - E.tt = heure dernière mesure valide (HH:MM:SS)
%           - E.tu = 0 (TU) ou -4 (locales)
%           - E.cc = commentaires (dernières données)
%           - E.dt = date et heure dernière mesure en temps Matlab

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-10-13
%   Mise à jour : 2005-02-01

X = readconf;
if nargin==0
    f = sprintf('%s/%s',X.RACINE_WEB,X.FILE_WEB_ETATS);
end

if exist(f,'file')
    [st,ss,pp,aa,dd,tt,tu,cc] = textread(f,'%s%s%n%n%s%s%n%[^\n]','commentstyle','shell');
    for i = 1:length(st)
        E.st(i) = st(i);
        E.ss(i) = ss(i);
        E.pp(i) = pp(i);
        E.aa(i) = aa(i);
        E.dd(i) = dd(i);
        E.tt(i) = tt(i);
        E.tu(i) = tu(i);
        E.cc(i) = cc(i);
        [a,m,j] = strread(dd{i},'%n-%n-%n');
        [h,n,s] = strread(tt{i},'%n:%n:%n');
        if ~isnan(a) & ~isnan(m) & ~isnan(j) & ~isnan(h) & ~isnan(n) & ~isnan(s)
            E.dt(i) = datenum(a,m,j,h,n,s);
        else
            E.dt(i) = 0;
        end
	%mpdate=datevec(E.dt(i)-1/6);
	%.dd(i)=cellstr(sprintf('%4d-%02d-%02d',tmpdate(1:3)));
	%.tt(i)=cellstr(sprintf('%02d:%02d:%02.0f',tmpdate(4:6)));
    end
    disp(sprintf('Fichier: %s importé.',f))
else
    E = struct('st',[],'ss',[],'pp',[],'aa',[],'dd',[],'tt',[],'tu',[],'cc',[],'dt',[]);
    disp(sprintf('*** Erreur: fichier %s non trouvé.',f))
end
