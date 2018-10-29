function E = readetatpc(f);
%READETATPC Importe le fichier d'état des acquisitions OVSG.
%       READETATPC importe le fichier de routine 'etat_pc.txt' et renvoie 
%       une structure E contenant:
%           - E.ss = code acquisition
%           - E.pp = pourcentage état
%           - E.aa = pourcentage acquisition
%           - E.dh = date et heure dernière mesure valide
%           - E.tu = timezone machine
%           - E.tz = timezone théorique
%           - E.dt = délai horloge (en secondes)
%           - E.pc = nom du PC d'acquisition
%           - E.md = montage disque (0 = réussi, 1 = raté)

%   Auteurs: F. Beauducel & D. Mallarino, OVSG-IPGP
%   Création : 2003-06-30
%   Mise à jour : 2006-05-03

X = readconf;
if nargin == 0
    f = sprintf('%s/%s',X.RACINE_OUTPUT_TOOLS,X.TESTE_ETAT_FILE);
end

[ss,pp,aa,dd,hh,tu,tz,dt,pc,md,dl] = textread(f,'%s%n%n%s%s%n%n%n%s%n%n','commentstyle','shell');
for i = 1:length(ss)
    E.ss(i) = ss(i);
    E.pp(i) = pp(i);
    E.aa(i) = aa(i);
    [a,m,j] = strread(dd{i},'%n-%n-%n');
    [h,n,s] = strread(hh{i},'%n:%n:%n');
    if ~isnan(a) & ~isnan(m) & ~isnan(j) & ~isnan(h) & ~isnan(n) & ~isnan(s)
        E.dh(i) = datenum(a,m,j,h,n,s);
    else
        E.dh(i) = 0;
    end
    E.tu(i) = tu(i);
    E.tz(i) = tz(i);
    E.dt(i) = dt(i);
    E.pc(i) = pc(i);
    E.md(i) = md(i);
end
disp(sprintf('Fichier: %s importé.',f))
