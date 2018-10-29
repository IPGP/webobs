function mkpostat(mat,sta)
%MKPOSTAT Créer les icones de position et les cartes des stations
%       MKPOSTAT lit le fichier "Stations_WGS84.txt" et exporte pour chaque
%       station S dans le répertoire Web, une image "S_map.jpg" contenant :
%           - des informations sur la station (code, alias, position géographique et UTM, ...)
%           - une carte centrée sur la station (à partir des cartes Scan25 de l'IGN)
%           - une photo centrée sur la station (à partir des photos BDOrtho de l'IGN)
%       Les images sont créées ou mise à jour si l'une des deux conditions suivantes est 
%       respectée :
%           - l'image n'existe pas (nouvelle station)
%           - la date de l'image est antérieure à la date de positionnement de la station
%
%       MKPOSTAT(0) force la création de toutes les images.
%
%       MKPOSTAT(...,STA) force la création des images pour les codes de 
%       stations contenus dans STA.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-06-20
%   Mise à jour : 2004-07-05

X = readconf;

scode = 'POSTAT';
timelog(scode,1)

% Définition des variables
prog = X.PRGM_CONVERT;
pdon1 = X.STATIONS_PATH_SCAN25;
pdon2 = X.STATIONS_PATH_PHOTO1M;

dyp = 50;                 % hauteur zone de texte
dxy2 = [250,250];         % demies hauteur et largeur de la carte (en pixels)
mpos = {'?','carte','GPS'};

ftmp = 'tmp/blank.png';
ftmp1 = 'tmp/pos.png';
ftmp2 = 'tmp/map.jpg';
ftmp3 = 'tmp/pho.jpg';
ftmp4 = 'tmp/temp.txt';

% Construction de l'image blanche de départ
sz = [dyp + dxy2(2)*2,dxy2(1)*4];
imwrite(ones(sz),ftmp);

if nargin < 1
    mat = 1;
end
if nargin < 2
    sta = [];
end

% Charge le fichier de stations
%ST = readst('','OVSG',0);
ST = readst('','G',0);
stgeo = ST.geo;
stutm = ST.utm;

% Construit les index des cartes IGN Scan25
DC = dir(sprintf('%s/*.jpg',pdon1));
for i = 1:length(DC)
    [pf,nf,xf] = fileparts(DC(i).name);
    fimg = sprintf('%s/%s.jpg',pdon1,nf);
    ftab = sprintf('%s/%s.TAB',pdon1,nf);
    [d1,d2,d3,d4] = textread(ftab,'(%n,%n) (%n,%n)%*[^\n]',4,'headerlines',7);
    DC(i).data = [d1,d2,d3,d4];
    DC(i).xy = [min(d1),max(d1),min(d2),max(d2)];
    %disp(sprintf('Fichier: %s importé.',ftab));
end
disp(sprintf('Fichiers: %s/*.jpg importés',pdon1))
xy1 = cat(1,DC.xy);

% Construit les index des photos IGN 1m
DP = dir(sprintf('%s/JPG/*.jpg',pdon2));
for i = 1:length(DP)
    [pf,nf,xf] = fileparts(DP(i).name);
    fimg = sprintf('%s/JPG/%s.jpg',pdon2,nf);
    ftab = sprintf('%s/TAB/%s.TAB',pdon2,nf);
    [d1,d2,d3,d4] = textread(ftab,'(%n,%n) (%n,%n)%*[^\n]',4,'headerlines',7);
    DP(i).data = [d1,d2,d3,d4];
    DP(i).xy = [min(d1),max(d1),min(d2),max(d2)];
    %disp(sprintf('Fichier: %s importé.',ftab));
end
disp(sprintf('Fichiers: %s/JPG/*.jpg importés',pdon2))
xy2 = cat(1,DP.xy);

for i = 1:length(ST.cod)
    st = deblank(ST.cod{i});
    fpos = sprintf('%s/%s/%s_map.jpg',X.RACINE_DATA_STATIONS,upper(st),lower(st));

    if (mat ~= 1 | ~exist(fpos,'file') | find(strcmp(st,sta)))
        fid = fopen(ftmp4,'wt'); fprintf(fid,'text 5,15 "%s: %s"',st,ST.nom{i}); fclose(fid);
        unix(sprintf('%s -draw @%s -font x:fixed %s %s',prog,ftmp4,ftmp,ftmp1));
        unix(sprintf('%s -draw ''text 5,30 "%s"'' -font x:fixed %s %s',prog,ST.ali{i},ftmp1,ftmp1));
        unix(sprintf('%s -draw ''text 5,45 "%s"'' -font x:fixed %s %s',prog,ST.obs{i},ftmp1,ftmp1));

        % position
        unix(sprintf('%s -draw ''text 355,15 "Position du %s (%s)"'' -font x:fixed %s %s',prog,datestr(ST.dte(i)),mpos{ST.pos(i)+1},ftmp1,ftmp1));
        ddd = ST.geo(i,1); dd = floor(ddd); mmm = 60*(ddd-dd); mm = floor(mmm); ss = 60*(mmm-mm);
        str1 = sprintf('Lat = %2.5f°   %2d°%06.3f''   %2d°%02d''%04.1f'''' N',ddd,dd,mmm,dd,mm,ss);
        ddd = -ST.geo(i,2); dd = floor(ddd); mmm = 60*(ddd-dd); mm = floor(mmm); ss = 60*(mmm-mm);
        str2 = sprintf('Lon = %2.5f°   %2d°%06.3f''   %2d°%02d''%04.1f'''' W',ddd,dd,mmm,dd,mm,ss);
        str3 = sprintf('Alt = %1.0f m',ST.geo(i,3));

        fid = fopen(ftmp4,'wt'); fprintf(fid,'text 355,30 "%s"',str1); fclose(fid);
        unix(sprintf('%s -draw @%s -font x:fixed %s %s',prog,ftmp4,ftmp1,ftmp1));
        fid = fopen(ftmp4,'wt'); fprintf(fid,'text 355,45 "%s"',str2); fclose(fid);
        unix(sprintf('%s -draw @%s -font x:fixed %s %s',prog,ftmp4,ftmp1,ftmp1));
        unix(sprintf('%s -draw ''text 650,35 "%s"'' -font x:fixed %s %s',prog,str3,ftmp1,ftmp1));
        str1 = sprintf('UTM20 WGS84 = %1.0f E  %1.0f N (m)',ST.wgs(i,1:2));
        str2 = sprintf('UTM20 Ste-A = %1.0f E  %1.0f N (m)',ST.utm(i,1:2));
        unix(sprintf('%s -draw ''text 750,30 "%s"'' -font x:fixed %s %s',prog,str1,ftmp1,ftmp1));
        unix(sprintf('%s -draw ''text 750,45 "%s"'' -font x:fixed %s %s',prog,str2,ftmp1,ftmp1));

        % extraction de la carte IGN Scan25
        dxy = [0,0];
        k = find(ST.utm(i,1) > xy1(:,1) & ST.utm(i,1) < xy1(:,2) & ST.utm(i,2) > xy1(:,3) & ST.utm(i,2) < xy1(:,4));
        if ~isempty(k)
            k = k(1);
            px = griddata(DC(k).data(:,1),DC(k).data(:,2),DC(k).data(:,3),ST.utm(i,1),ST.utm(i,2));
            py = griddata(DC(k).data(:,1),DC(k).data(:,2),DC(k).data(:,4),ST.utm(i,1),ST.utm(i,2));
            dxy = [min([px-dxy2(1),0]),min([py-dxy2(2),0])];
            unix(sprintf('%s -crop %dx%d+%d+%d %s/%s %s',prog,2*dxy2,px-dxy2(1),py-dxy2(2),pdon1,DC(k).name,ftmp2));
            unix(sprintf('%s -fill red -draw ''circle %d,%d,%d,%d'' %s %s',prog,dxy2+dxy,dxy2+dxy+5,ftmp2,ftmp2));
            unix(sprintf('%s -draw ''text 5,15 "(c) SCAN25 IGN"'' -font x:fixed %s %s',prog,ftmp2,ftmp2));
            msg = DC(k).name;
        else
            imwrite(ones(dxy2([2,1])*2),ftmp2);
            msg = 'pas de carte IGN';
        end
        I = imfinfo(ftmp2);
        unix(sprintf('%s -draw ''image Over %d,%d,%d,%d %s'' %s %s',prog,[0,dyp]-dxy,I.Width,I.Height,ftmp2,ftmp1,fpos));
        disp(sprintf('Carte:   %s créée (Carte Scan25 %s).',fpos,msg))

        % extraction de la photo IGN 1m
        k = find(ST.wgs(i,1) > xy2(:,1) & ST.wgs(i,1) < xy2(:,2) & ST.wgs(i,2) > xy2(:,3) & ST.wgs(i,2) < xy2(:,4));
        if ~isempty(k)
            k = k(1);
            px = griddata(DP(k).data(:,1),DP(k).data(:,2),DP(k).data(:,3),ST.wgs(i,1),ST.wgs(i,2));
            py = griddata(DP(k).data(:,1),DP(k).data(:,2),DP(k).data(:,4),ST.wgs(i,1),ST.wgs(i,2));
            dxy = [min([px-dxy2(1),0]),min([py-dxy2(2),0])];
            unix(sprintf('%s -crop %dx%d+%d+%d %s/JPG/%s %s',prog,2*dxy2,px-dxy2(1),py-dxy2(2),pdon2,DP(k).name,ftmp3));
            unix(sprintf('%s -fill red -draw ''circle %d,%d,%d,%d'' %s %s',prog,dxy2+dxy,dxy2+dxy+3,ftmp3,ftmp3));
            unix(sprintf('%s -draw ''text 5,15 "(c) BdOrtho IGN"'' -font x:fixed %s %s',prog,ftmp3,ftmp3));
            msg = DP(k).name;
        else
            imwrite(ones(dxy2([2,1])*2),ftmp3);
            msg = 'pas de photo IGN';
        end
        I = imfinfo(ftmp3);
        unix(sprintf('%s -draw ''image Over %d,%d,%d,%d %s'' %s %s',prog,dxy2(2)*2,dyp,I.Width,I.Height,ftmp3,fpos,fpos));
        str = sprintf('%s -stroke white -fill none -draw ''rectangle %d,%d,%d,%d'' %s %s',prog,dxy2(2)*.6,dyp + dxy2(1)*.6,dxy2(2)*1.4,dyp + dxy2(1)*1.4,fpos,fpos);
        unix(str);
        unix(sprintf('%s -stroke black -fill none -draw ''rectangle %d,%d,%d,%d'' %s %s',prog,1,dyp,sz(2) - 1,sz(1) - 1,fpos,fpos));
        disp(sprintf('Carte:   %s mise à jour (Photo BDO %s).',fpos,msg))
    end
end

timelog(scode,2)
