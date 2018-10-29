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
%   Mise à jour : 2005-01-17

X = readconf;

% Mettre test = 1 pour n'afficher qu'un rectangle (ajustement manuel)
test = 0;


pwww = X.RACINE_WEB;
fmap = sprintf('%s/data/%s.map',X.RACINE_OUTPUT_MATLAB,f);
fhtm = sprintf('%s/%s/%s.htm',pwww,X.MAPS_PATH_WEB,f);
fpng = sprintf('../../%s/%s.png',X.MKGRAPH_PATH_WEB,f);
IM = imfinfo(sprintf('%s/%s/%s.png',pwww,X.MKGRAPH_PATH_WEB,f));
ims = [IM.Width IM.Height];

% Ajustements manuels
% ----- position figure par rapport à l'image; celle-ci ne pouvant etre connue 
%       par MATLAB avec l'option "-nodisplay"
fgp = [0 0 1 1];
if ~isempty(findstr(f,'RESEAUX_')) | ~isempty(findstr(f,'DISCIPLINE_'))
    if findstr(f,'_DOM'), fgp = [-.114 .170 1.140 .860]; end % OK
    if findstr(f,'_SOU'), fgp = [-.115 .171 1.141 .858]; end % OK
    if findstr(f,'_SBT'), fgp = [-.115 .168 1.141 .861]; end % OK
    if findstr(f,'_GUA'), fgp = [-.114 .233 1.140 .789]; end % OK
    if findstr(f,'_ANT'), fgp = [-.114 .170 1.140 .860]; end % OK
    if findstr(f,'_DOM_BDO'), fgp = [0.001 .170 1.023 .860]; end % 
    if findstr(f,'_SOU_BDO'), fgp = [0.001 .170 1.023 .860]; end % 
    if findstr(f,'_SBT_BDO'), fgp = [0.001 .22 1.023 .802]; end % 
else
    if findstr(f,'_DOM'), fgp = [0.017 0 0.905 1.020]; end % OK
    if findstr(f,'_SOU'), fgp = [0.020 0 0.905 1.023]; end % OK
    if findstr(f,'_SBT'), fgp = [0.020 0 0.900 1.025]; end % OK
    if findstr(f,'_GUA'), fgp = [-.056 0 1.035 1.020]; end % OK
    if findstr(f,'_ANT'), fgp = [0.017 0 0.908 1.029]; end % OK
end

% ----- réduction des tailles de cercles
mks = .8*mks;
% ----- si test: définition de 2 stations fictives aux coins du graphe
if test
    d = axl([2 3;1 4]);
end

fid = fopen(fhtm,'wt');
fid2 = fopen(fmap,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>Carte intéractive %s</TITLE></HEAD><BODY>\n',f);
%fprintf(fid,'<img src="%s" border=0 alt="Pointez une station SVP" usemap="#map">\n',fpng);
fprintf(fid,'<img src="%s" border=0 usemap="#map">\n',fpng);
fprintf(fid,'<map name="map">\n');
if test
    x = round(ims(1)*(fgp(3)*(axp(3)*(d(:,1)-axl(1))/diff(axl(1:2)) + axp(1)) + fgp(1)));
    y = round(ims(2) - ims(2)*(fgp(4)*(axp(4)*(d(:,2)-axl(3))/diff(axl(3:4)) + axp(2)) + fgp(2)));
    fprintf(fid,'<area href="/data/" title="Ca doit cadrer !" shape=rect coords="%d,%d,%d,%d">\n', ...
            x(1),y(1),x(2),y(2));
else
    % boucle inverse pour donner la priorité aux stations visibles
    for i = length(cs):-1:1
        x = round(ims(1)*(fgp(3)*(axp(3)*(d(i,1)-axl(1))/diff(axl(1:2)) + axp(1)) + fgp(1)));
        y = round(ims(2) - ims(2)*(fgp(4)*(axp(4)*(d(i,2)-axl(3))/diff(axl(3:4)) + axp(2)) + fgp(2)));
        r = ceil(mks(i));
        
        % Définit un lien vers la fiche de station
        ss = sprintf('<AREA href="/cgi-bin/%s?stationName=%s" title="%s: %s" shape=circle coords="%d,%d,%d">\n', ...
                X.CGI_AFFICHE_STATION,deblank(cs{i}),deblank(cs{i}),deblank(ns{i}),x,y,r);
        fprintf(fid,'%s',ss);
        fprintf(fid2,'%s',ss);
    end
end
ss = sprintf('<AREA nohref shape=rect coords="%d,%d,%d,%d">\n',[0,0,ims]);
fprintf(fid,'%s',ss);
fprintf(fid2,'%s',ss);
fprintf(fid,'</map>\n</BODY></HTML>');

fclose(fid);
fclose(fid2);
disp(sprintf('Fichier: %s créé.',fhtm))
disp(sprintf('Fichier: %s créé.',fmap))
