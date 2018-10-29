function mkimap(f,G,t,d,cs,mks,k1,ax1,fp1,k2,ax2,fp2,k3,ax3,fp3,qm);
%MKIMAP Construit le fichier HTML de cartes hypocentres intéractives
%       MKIMAP(F,G,T,D,CS,MKS,K1,AX1,FP1,K2,AX2,FP2,...) où:
%           - F = nom du fichier (sans extention)
%	    - G = structure réseau (contenant notamment G.dsp)
%           - T = vecteur temps (format MATLAB)
%           - D = matrice données [lat,lon,prof,mag,...]
%           - CS = vecteur code séismes (cell)
%           - MKS = vecteur tailles des cercles
%           - K1 = [I,X,Y] = indice et coordonnées X,Y des données
%           - AX1 = limites axe [Xmin Xmax Ymin Ymax] en valeurs physiques
%           - FP1 = position axe [left bottom width height] en relatif figure

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-08-15
%   Mise à jour : 2009-10-09

X = readconf;

dts = 10/1440;       % délais autorisé pour recherche d'événement MC (en jour)

if findstr(f,'_xxx')
    xxx = 1;
    fhtm = sprintf('%s/%s/%s.htm',X.RACINE_WEB,G.dsp,f);
    fpng = sprintf('%s.png',f);
    IM = imfinfo(sprintf('%s/%s/%s.png',X.RACINE_WEB,G.dsp,f));
else
    xxx = 0;
    fhtm = sprintf('%s/data/%s.map',X.RACINE_OUTPUT_MATLAB,f);
    fpng = sprintf('/%s/%s.png',X.MKGRAPH_PATH_WEB,f);
    IM = imfinfo(sprintf('%s/%s',X.RACINE_WEB,fpng));
end
if findstr(f,'-SOU_') | findstr(f,'-DOM_')
    pftp = sprintf('/%s/Sismologie/Hypocentres/Soufriere',X.WEB_RACINE_FTP);
else
    pftp = sprintf('/%s/Sismologie/Hypocentres/Regionaux',X.WEB_RACINE_FTP);
end
ims = [IM.Width IM.Height];
fgp = [0 0 1 1];
ng = (nargin-5)/3;

% ----- réduction des tailles de cercles
mks = .8*mks;

% récupération de la liste des événements Main-Courante
pimg = sprintf('%s/%s',X.MC_PATH_WEB,X.MC_PATH_IMAGES);
[s,ss] = unix(sprintf('find %s/%s/ -mindepth 3 -maxdepth 3 -name "*.png"',X.RACINE_WEB,pimg));
nmc = char(strread(ss,sprintf('%s/%s/%%s',X.RACINE_WEB,pimg)));
dd = str2double([cellstr(nmc(:,1:4)),cellstr(nmc(:,11:12)),cellstr(nmc(:,13:14)),cellstr(nmc(:,15:16)),cellstr(nmc(:,17:18)),cellstr(nmc(:,19:20))]);
k = find(isnan(dd(:,end)));
if ~isempty(k)
    dd(k,end) = 0;
end
tmc = datenum(dd);

fid = fopen(fhtm,'wt');

if xxx
    fprintf(fid,'<HTML><HEAD><TITLE>Carte intéractive %s</TITLE></HEAD><BODY>\n',f);
    fprintf(fid,'<IMG src="%s" border=0 alt="Pointez un séisme SVP" usemap="#map">\n',fpng);
    fprintf(fid,'<MAP name="map">\n');
end

for j = 1:ng
    eval(sprintf('kk = k%d; axl = ax%d; axp = fp%d;',j,j,j));
    % boucle inverse pour donner la priorité aux séismes les plus récents
    for ii = size(kk,1):-1:1
        i = kk(ii,1);  xx = kk(ii,2);  yy = kk(ii,3);
        x = round(ims(1)*(fgp(3)*(axp(3)*(xx-axl(1))/diff(axl(1:2)) + axp(1)) + fgp(1)));
        y = round(ims(2) - ims(2)*(fgp(4)*(axp(4)*(yy-axl(3))/diff(axl(3:4)) + axp(2)) + fgp(2)));
        r = ceil(mks(i));
        tv = datevec(t(i));
        k = find((t(i)-tmc) < dts & (t(i)-tmc) > -1/1440);
        if ~isempty(k)
            lnk = sprintf('/%s/%s',pimg,deblank(nmc(k(1),:)));
        else
            lnk = sprintf('%s/%4d/%4d_%02d.PUN',pftp,tv(1),tv(1),tv(2));
        end
	if xxx
            ss = sprintf('<AREA href="%s" title="%s %s TU %1.1f km Md=%1.1f (%s)" shape=circle coords="%d,%d,%d">\n', ...
            lnk,datestr(t(i),1),datestr(t(i),15),d(i,3:4),deblank(cs{i}),x,y,r);
        else
            ss = sprintf('<AREA href="%s" onMouseOut="nd()" onmouseover="overlib(''%s %s TU %1.1f km Md=%1.1f (%s)'')" shape=circle coords="%d,%d,%d">\n', ...
            lnk,datestr(t(i),1),datestr(t(i),15),d(i,3:4),deblank(cs{i}),x,y,r);
	end
        fprintf(fid,'%s',ss);
    end
end
ss = sprintf('<AREA nohref shape=rect coords="%d,%d,%d,%d">\n',[0,0,ims]);
fprintf(fid,'%s',ss);
if xxx
    fprintf(fid,'</MAP>\n</BODY></HTML>');
end
fclose(fid);

disp(sprintf('Fichier: %s créé.',fhtm))
