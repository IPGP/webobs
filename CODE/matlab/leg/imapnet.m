function imapnet(f,d,cs,ns,mks,axl,axp)
%IMAPNET Construit le fichier HTML de cartes intéractives
%       IMAPNET(F,D,CS,MKS,AXL,AXP,FGP) où:
%           - F = nom du fichier (sans extention)
%           - D = matrice positions [x,y]
%           - CS = vecteur code stations (cell)
%           - NS = vecteur noms stations (cell)
%           - MKS = vecteur tailles des cercles
%           - AXL = limites axe [Xmin Xmax Ymin Ymax] en unités D
%           - AXP = position axe [left bottom width height] en relatif figure
%
%       Attention: IMAPNET est totalement dépendant de la résolution utilisée 
%       par la fonction UNIX convert (appelée par MKPS2PNG).

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-07-09
%   Mise à jour : 2007-01-27

X = readconf;

pwww = X.RACINE_WEB;
fmap = sprintf('%s/data/%s.map',X.RACINE_OUTPUT_MATLAB,f);
fhtm = sprintf('%s/%s/%s.htm',pwww,X.MAPS_PATH_WEB,f);
fpng = sprintf('../../%s/%s.png',X.MKGRAPH_PATH_WEB,f);
IM = imfinfo(sprintf('%s/%s/%s.png',pwww,X.MKGRAPH_PATH_WEB,f));
ims = [IM.Width IM.Height];

% ----- réduction des tailles de cercles
%mks = .8*mks;

% ----- si test: définition de 2 stations fictives aux coins du graphe

fid = fopen(fhtm,'wt');
fid2 = fopen(fmap,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>Carte intéractive %s</TITLE></HEAD><BODY>\n',f);
%fprintf(fid,'<img src="%s" border=0 alt="Pointez une station SVP" usemap="#map">\n',fpng);
fprintf(fid,'<img src="%s" border=0 usemap="#map">\n',fpng);
fprintf(fid,'<map name="map">\n');

% boucle inverse pour donner la priorité aux stations visibles
for i = length(cs):-1:1
    x = round(ims(1)*((axp(3)*(d(i,1)-axl(1))/diff(axl(1:2)) + axp(1))));
    y = round(ims(2)*(1 -(axp(4)*(d(i,2)-axl(3))/diff(axl(3:4)) + axp(2))));
    r = ceil(mks(i));
        
    % Définit un lien vers la fiche de station
    ss = sprintf('<AREA href="/cgi-bin/%s?stationName=%s" title="%s: %s" shape=circle coords="%d,%d,%d">\n', ...
            X.CGI_AFFICHE_STATION,deblank(cs{i}),deblank(cs{i}),deblank(ns{i}),x,y,r);
    fprintf(fid,'%s',ss);
    fprintf(fid2,'%s',ss);
end
ss = sprintf('<AREA nohref shape=rect coords="%d,%d,%d,%d">\n',[0,0,ims]);
fprintf(fid,'%s',ss);
fprintf(fid2,'%s',ss);
fprintf(fid,'</map>\n</BODY></HTML>');

fclose(fid);
fclose(fid2);
disp(sprintf('Fichier: %s créé.',fhtm))
disp(sprintf('Fichier: %s créé.',fmap))
