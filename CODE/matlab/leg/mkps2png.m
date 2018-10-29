function mkps2png(f,p,r)
%MKPS2PNG Créé 2 fichiers PS et PNG.
%       MKPS2PNG(F,P) créé 2 fichiers à partir de la figure courante:
%           - F.ps dans le répertoire courant images/.
%           - F.png dans le répertoire P (en utilisant la fonction CONVERT
%             par un appel UNIX).
%           - F.png copié sur www/images/graphes/.
%
%       MKPS2PNG(F,P,R) spécifie la résolution (100 par défaut).

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-07-25
%   Mise à jour : 2007-01-27

X = readconf;

if nargin < 3
    r = 100;
end
pwww = sprintf('%s/%s',X.RACINE_WEB,X.MKGRAPH_PATH_WEB);
ff = sprintf('%s/images/%s.ps',X.RACINE_OUTPUT_MATLAB,f);
print(gcf,'-dpsc','-loose','-painters',ff);
disp(sprintf('Graphe: %s créé.',ff))

unix(sprintf('%s -colors 256 -density %dx%d %s/images/%s.ps %s/%s.png',X.PRGM_CONVERT,r,r,X.RACINE_OUTPUT_MATLAB,f,p,f));
%unix(sprintf('/usr/bin/gs -sDEVICE=png256 -sOutputFile=%s/%s.png -r100 -dNOPAUSE -dBATCH -q %s.ps',p,f,f));
disp(sprintf('Graphe:  %s/%s.png créé.',p,f))

unix(sprintf('/bin/cp -f %s/%s.png %s/.',p,f,pwww));

