function mkpostat(mat,sta)
%MKPOSTAT Créer les icones de position et les cartes des stations
%       MKPOSTAT fabrique pour chaque station S existante dans WEBOBS,
%       une image "S_map.png" contenant :
%           - des informations sur la station (code, alias, position géographique et UTM, ...)
%           - une carte centrée sur la station (à partir des cartes Scan25 de l'IGN)
%           - une photo centrée sur la station (à partir des photos BDOrtho de l'IGN)
%       Les images sont crees ou mise a jour si au moins une des coordonnees est non nulle,
%	et si l'une des 4 conditions suivantes est respectee:
%	    - utilisation de l'option MAT = 0
%           - l'image n'existe pas (nouvelle station)
%           - la date de l'image est antérieure à la date de positionnement de la station
%	    - le code de la station est specifie dans STA (voir option co-dessous)
%
%       MKPOSTAT(0) force la création de toutes les images.
%
%       MKPOSTAT(...,STA) force la création des images pour les codes de 
%       stations contenus dans STA.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-06-20
%   Mise à jour : 2009-06-06

X = readconf;

scode = 'POSTAT';
timelog(scode,1)

% Définition des variables
prog = X.PRGM_CONVERT;
pdon1 = X.STATIONS_PATH_SCAN25;
%pdon2 = X.STATIONS_PATH_PHOTO1M;
pdon2 = X.STATIONS_PATH_PHOTO50CM;
fbln = sprintf('%s/%s',X.RACINE_DATA_MATLAB,X.DATA_CONTOUR_GUAD);

dyp = 50;                   % hauteur zone de texte
pxm = 2.5;                  % largeur d'un pixel pour les cartes IGN_Scan25 (en m)
pxp = .5;                  % largeur d'un pixel pour les photos IGN (en m)
rign = 2;                   % facteur de réduction des cartes IGN
dxy2 = [250,250];           % demies largeur et hauteur de la carte (en pixels)
degkm = 6370000*pi/180;     % valeur du degré (en m)
fontconvert = 'helvetica';
mpos = {'?','carte','GPS'};

ftmp = 'tmp/blank.png';
ftmp1 = 'tmp/pos.png';
ftmp2 = 'tmp/map.png';
ftmp3 = 'tmp/pho.jpg';
ftmp4 = 'tmp/temp.txt';
ftmp5 = 'tmp/guad.jpg';

% Construction de l'image blanche de départ
sz = [dyp + dxy2(2)*2,dxy2(1)*4];
imwrite(ones(sz),ftmp);

if nargin < 1
    mat = 1;
end
if nargin < 2
    sta = [];
else
	sta = upper(sta);
end

% Charge le fichier de stations
%ST = readst('','OVSG',0);
ST = readst('','G',0);
stgeo = ST.geo;
stutm = ST.utm;

% Charge les contours Guadeloupe
[cg,xylim] = ibln(fbln);

% Construit les index des cartes IGN Scan25
DC = dir(sprintf('%s/*.TIF',pdon1));
for i = 1:length(DC)
    nf = DC(i).name;
    fimg = sprintf('%s/%s',pdon1,nf);
    ftab = sprintf('%s/txt/%s.TXT',pdon1,nf(1:(end-4)));
    ss = textread(ftab,'%s','delimiter','\n','headerlines',4);
    d1 = strread(ss{1},'X = %d');
    d2 = strread(ss{4},'Y = %d');
    d3 = strread(ss{2},'Extension en X = %dm');
    d4 = strread(ss{5},'Extension en Y = %dm');
    DC(i).data = [d1,d2,d3,d4];
    DC(i).xy = [d1,d1+d3,d2-d4,d2];
    %disp(sprintf('Fichier: %s importé.',ftab));
end
disp(sprintf('Fichiers: %s/*.TIF importés',pdon1))
xy1 = cat(1,DC.xy);

% Construit les index des photos IGN 1m / 50cm
%DP = dir(sprintf('%s/JPG/*.jpg',pdon2));
[s,ss] = unix(sprintf('find %s/JPG/ -mindepth 2 -maxdepth 2 -name "*.jpg"',pdon2));
nph = char(strread(ss,sprintf('%s/JPG/%%s',pdon2)));
for i = 1:length(nph)
	DP(i).name = nph(i,:);
    [pf,nf,xf] = fileparts(DP(i).name);
    fimg = sprintf('%s/JPG/%s.jpg',pdon2,nf);
    %ftab = sprintf('%s/TAB/%s.TAB',pdon2,nf);
    %[d1,d2,d3,d4] = textread(ftab,'(%n,%n) (%n,%n)%*[^\n]',4,'headerlines',7);
    %DP(i).data = [d1,d2,d3,d4];
    %DP(i).xy = [min(d1),max(d1),min(d2),max(d2)];
    %disp(sprintf('Fichier: %s importé.',ftab));
    [d1,d2] = strread(nf,'971-2004-%n-%n-u20n');
    DP(i).data = [[d1;d1+1;d1;d1+1]*1000,[d2;d2;d2-1;d2-1]*1000,[0;2000;0;2000],[0;0;2000;2000]];
    DP(i).xy = 1000*[d1,d1+1,d2-1,d2];
end
disp(sprintf('Fichiers: %s/JPG/*.jpg importés',pdon2))
xy2 = cat(1,DP.xy);

for i = 1:length(ST.cod)
    st = deblank(ST.cod{i});
    fpos = sprintf('%s/%s/%s_map.png',X.RACINE_DATA_STATIONS,upper(st),lower(st));
    if exist(fpos,'file')
        I = imfinfo(fpos);
        tmap = datesys2num(I.FileModDate);
    else
        tmap = -1;
    end

    if (any(ST.geo(i,:)) & (mat ~= 1 | tmap < ST.dte(i) | find(strcmp(st,sta))))

        % position
        str = sprintf('%s : %s (%s) - Pos. %s (%s)',ST.ali{i},ST.nom{i},st,datestr(ST.dte(i)),mpos{ST.pos(i)+1});
        fid = fopen(ftmp4,'wt'); fprintf(fid,'text 350,15 "%s"',str); fclose(fid);
        unix(sprintf('%s -draw @%s -font %s %s %s',prog,ftmp4,fontconvert,ftmp,ftmp1));
        ddd = ST.geo(i,1); dd = floor(ddd); mmm = 60*(ddd-dd); mm = floor(mmm); ss = 60*(mmm-mm);
        str1 = sprintf('Lat = %2.5f°   %2d°%06.3f''   %2d°%02d''%04.1f'''' N',ddd,dd,mmm,dd,mm,ss);
        ddd = -ST.geo(i,2); dd = floor(ddd); mmm = 60*(ddd-dd); mm = floor(mmm); ss = 60*(mmm-mm);
        str2 = sprintf('Lon = %2.5f°   %2d°%06.3f''   %2d°%02d''%04.1f'''' W',ddd,dd,mmm,dd,mm,ss);

        fid = fopen(ftmp4,'wt'); fprintf(fid,'text 350,30 "%s"',str1); fclose(fid);
        unix(sprintf('%s -draw @%s -font %s %s %s',prog,ftmp4,fontconvert,ftmp1,ftmp1));
        fid = fopen(ftmp4,'wt'); fprintf(fid,'text 350,45 "%s"',str2); fclose(fid);
        unix(sprintf('%s -draw @%s -font %s %s %s',prog,ftmp4,fontconvert,ftmp1,ftmp1));
        unix(sprintf('%s -draw ''text 650,35 "Alt = %1.0f m"'' -font %s %s %s',prog,ST.geo(i,3),fontconvert,ftmp1,ftmp1));
        str1 = sprintf('UTM20 WGS84 = %1.0f E  %1.0f N (m)',ST.wgs(i,1:2));
        str2 = sprintf('UTM20 Ste-A = %1.0f E  %1.0f N (m)',ST.utm(i,1:2));
        unix(sprintf('%s -draw ''text 750,30 "%s"'' -font %s %s %s',prog,str1,fontconvert,ftmp1,ftmp1));
        unix(sprintf('%s -draw ''text 750,45 "%s"'' -font %s %s %s',prog,str2,fontconvert,ftmp1,ftmp1));

        % extraction de la carte IGN Scan25
        dyx = [0,0];
        k = find(ST.utm(i,1) > xy1(:,1) & ST.utm(i,1) < xy1(:,2) & ST.utm(i,2) > xy1(:,3) & ST.utm(i,2) < xy1(:,4));
        if ~isempty(k)
            %k = k(end);
            k = k(1);
            px = (ST.utm(i,1) - DC(k).data(1))/pxm;
            py = (DC(k).data(2) - ST.utm(i,2))/pxm;
            dxy = [min([px-dxy2(1)*rign,0]),min([py-dxy2(2)*rign,0])];
            str = sprintf('%s -crop %dx%d%+1.0f%+1.0f %s/%s %s',prog,2*rign*dxy2,px-dxy2(1)*rign,py-dxy2(2)*rign,pdon1,DC(k).name,ftmp2);
            unix(str);
            str = sprintf('%s -fill red -draw ''circle %d,%d,%d,%d'' %s %s',prog,dxy2*rign + dxy,dxy2*rign + dxy + 4,ftmp2,ftmp2);
            unix(str);
            str = sprintf('%s -scale %dx%d %s %s',prog,2*dxy2,ftmp2,ftmp2);
            unix(str);
            str = sprintf('%s -stroke white -draw ''text 5,%d "(c) SCAN25 IGN - %gx%g m"'' -font %s %s %s',prog,2*dxy2(2)+dxy(2)-10,2*dxy2*pxm*rign,fontconvert,ftmp2,ftmp2);
            unix(str);
            msg = DC(k).name;
        else
            imwrite(ones(dxy2([2,1])*2),ftmp2);
            msg = 'pas de carte IGN';
        end
        I = imfinfo(ftmp2);
        if ~isempty(k)
            unix(sprintf('%s -draw ''image Over %d,%d,%d,%d %s'' %s %s',prog,[0,dyp]-dxy/rign,I.Width,I.Height,ftmp2,ftmp1,fpos));
        end
        disp(sprintf('Carte:   %s créée (Carte Scan25 %s).',fpos,msg))

        % extraction de la photo IGN 1m / 50cm
        k = find(ST.wgs(i,1) > xy2(:,1) & ST.wgs(i,1) < xy2(:,2) & ST.wgs(i,2) > xy2(:,3) & ST.wgs(i,2) < xy2(:,4));
        if ~isempty(k)
            k = k(1);
            px = griddata(DP(k).data(:,1),DP(k).data(:,2),DP(k).data(:,3),ST.wgs(i,1),ST.wgs(i,2));
            py = griddata(DP(k).data(:,1),DP(k).data(:,2),DP(k).data(:,4),ST.wgs(i,1),ST.wgs(i,2));
            dxy = [min([px-dxy2(1),0]),min([py-dxy2(2),0])];
            unix(sprintf('%s -crop %dx%d%+1.0f%+1.0f %s/JPG/%s %s',prog,2*dxy2,px-dxy2(1),py-dxy2(2),pdon2,DP(k).name,ftmp3));
            %unix(sprintf('%s -fill red -draw ''circle %d,%d,%d,%d'' %s %s',prog,dxy2+dxy,dxy2+dxy+3,ftmp3,ftmp3));
            unix(sprintf('%s -stroke red -fill none -draw ''circle %d,%d,%d,%d'' %s %s',prog,dxy2+dxy,dxy2+dxy+5/pxp,ftmp3,ftmp3));
            unix(sprintf('%s -stroke white -draw ''text 5,%d "(c) BdOrtho IGN - %gx%g m"'' -font %s %s %s',prog,2*dxy2(2)+dxy(2)-10,2*dxy2*pxp,fontconvert,ftmp3,ftmp3));
            msg = DP(k).name;
            flag = 1;
        else
            imwrite(ones(dxy2([2,1])*2),ftmp3);
            msg = 'pas de photo IGN';
            flag = 0;
        end
        I = imfinfo(ftmp3);
        if ~isempty(k)
            unix(sprintf('%s -draw ''image Over %d,%d,%d,%d %s'' %s %s',prog,[dxy2(2)*2,dyp]-dxy,I.Width,I.Height,ftmp3,fpos,fpos));
        end
        if flag
            %str = sprintf('%s -stroke white -fill none -draw ''rectangle %d,%d,%d,%d'' %s %s',prog,dxy2(2)*(1 - pxp/(pxm*rign)),dyp + dxy2(1)*(1 - pxp/(pxm*rign)),dxy2(2)*(1 + pxp/(pxm*rign)),dyp + dxy2(1)*(1 + pxp/(pxm*rign)),fpos,fpos);
            prect(prog,fpos,dxy2(2)*(1 - pxp/(pxm*rign)),dyp + dxy2(1)*(1 - pxp/(pxm*rign)),dxy2(2)*(1 + pxp/(pxm*rign)),dyp + dxy2(1)*(1 + pxp/(pxm*rign)));
        end
        unix(sprintf('%s -stroke black -fill none -draw ''rectangle %d,%d,%d,%d'' %s %s',prog,1,dyp,sz(2) - 1,sz(1) - 1,fpos,fpos));
        
        % ajout de la carte Guadeloupe
        if ST.geo(i,2) > xylim(1) & ST.geo(i,2) < xylim(2) & ST.geo(i,1) > xylim(3) & ST.geo(i,1) < xylim(4)
            figure(1), clf
            pcontour(cg,'k',[0,0,0])
            set(gca,'Position',[0,0,1,1])
            axis equal, axis off
            hold on
            fill3(ST.geo(i,2)+[-1,-1,1,1]*rign*pxm*dxy2(1)/degkm,ST.geo(i,1)+[-1,1,1,-1]*rign*pxm*dxy2(2)/degkm,ones(4,1),'r','EdgeColor','r')
            hold off
            print('-djpeg','-r20',ftmp5);
            close(1)
            I = imfinfo(ftmp5);
            str = sprintf('%s -draw ''image Over 0,0,%d,%d %s'' %s %s',prog,I.Width,I.Height,ftmp5,fpos,fpos);
            unix(str);
            disp(sprintf('Carte:   %s mise à jour (Carte Guadeloupe).',fpos))
        end
        
        disp(sprintf('Carte:   %s mise à jour (Photo BDO %s).',fpos,msg))
    end
end

timelog(scode,2)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function prect(prog,f,x1,y1,x2,y2)

unix(sprintf('%s -stroke white -fill none -draw ''rectangle %d,%d,%d,%d'' %s %s',prog,x1,y1,x2,y2,f,f));
unix(sprintf('%s -stroke black -fill none -draw ''rectangle %d,%d,%d,%d'' %s %s',prog,x1-1,y1-1,x2+1,y2+1,f,f));
