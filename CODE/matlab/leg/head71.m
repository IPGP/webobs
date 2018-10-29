function head71
%HEAD71 Fabrique les en-tetes d'HYPO71

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-01-02
%   Mise à jour : 2004-09-02

X = readconf;

rname = 'head71';
timelog(rname,1)

% Initialisation des variables
pftp = sprintf('%s/Sismologie/Hypocentres/HYPO71',X.RACINE_FTP);

% ===========================================================================
% Fichier tectonique
fhd0 = 'HEADTECT.par';     % fichier paramètres (modèle de vitesse)
fhd = 'HEADTECT';
vit0 = 3500;               % vitesse au dessus du niveau de la mer (m/s)

f = sprintf('%s/%s',pftp,fhd0);
S = readst({'SZ','SA','SL'},{'G','M','B','S','C'},0);
ali = char(S.ali);
% élimine les acquisitions
k = find(~strcmp(S.ali,'-'));
% tri du Nord au Sud
[z,i] = sort(S.geo(k,1)); 
k = flipud(k(i));

f = sprintf('%s/%s',pftp,fhd);
fid = fopen(f,'wt');
fprintf(fid,'HEAD\r\n\r\n');
for ii = 1:length(k)
    i = k(ii);
    fprintf(fid,'  %s%2d%05.2fN %2d%05.2fW%4.0f  %4.2f\r\n', ...
            ali(i,:),floor(S.geo(i,1)),mod(S.geo(i,1),1)*60,floor(-S.geo(i,2)),mod(-S.geo(i,2),1)*60,S.geo(i,3),S.geo(i,3)/vit0);
end
fclose(fid);
unix(sprintf('cat %s/%s >> %s',pftp,fhd0,f));
disp(sprintf('Fichier: %s créé.',f));

% ===========================================================================
% Fichier Volcanique
fhd0 = 'HEADVOLC.par';     % fichier paramètres (modèle de vitesse)
fhd = 'HEADVOLC';
fsn = 'Delais_sismo_num.dat';
hd0 = ['RESET TEST(04)=.010  ';
       'RESET TEST(07)=-.87  ';
       'RESET TEST(08)=2.00  ';
       'RESET TEST(09)=0.0035';
       'RESET TEST(15)=-2.   ';
       'RESET TEST(20)=1.    '];
vit0 = 2500;               % vitesse au dessus du niveau de la mer (m/s)

f = sprintf('%s/%s',pftp,fsn);
[sn,dt] = textread(f,'%s%s');

f = sprintf('%s/%s',pftp,fhd);
S = readst({'SZ','SA','SL'},'G',0);
ali = char(S.ali);
% élimine les acquisitions et les stations hors Guadeloupe
k = find(~strcmp(S.ali,'-') & S.geo(:,1) > 15.7 & S.geo(:,1) < 16.5);
% tri du Nord au Sud
[z,i] = sort(S.geo(k,1)); 
k = flipud(k(i));

f = sprintf('%s/%s.dly',pftp,fhd);
fid = fopen(f,'wt');
fprintf(fid,'HEAD\r\n');
for i = 1:size(hd0,1)
    fprintf(fid,'%s\r\n',hd0(i,:));
end
fprintf(fid,'\r\n');

for ii = 1:length(k)
    i = k(ii);
    kk = find(strcmp(S.cod(i),sn));
    if ~isempty(kk)
        dtt = dt{kk};
    else
        dtt = '';
    end
    fprintf(fid,'  %s%2d%05.2fN %2d%05.2fW%4.0f                                                       %s\r\n', ...
            ali(i,:),floor(S.geo(i,1)),mod(S.geo(i,1),1)*60,floor(-S.geo(i,2)),mod(-S.geo(i,2),1)*60,S.geo(i,3),dtt);
end
fclose(fid);
unix(sprintf('cat %s/%s >> %s',pftp,fhd0,f));
disp(sprintf('Fichier: %s créé.',f));

f = sprintf('%s/%s',pftp,fhd);
fid = fopen(f,'wt');
fprintf(fid,'HEAD\r\n');
for i = 1:size(hd0,1)
    fprintf(fid,'%s\r\n',hd0(i,:));
end
fprintf(fid,'\r\n');

for ii = 1:length(k)
    i = k(ii);
    kk = find(strcmp(S.cod(i),sn));
    if ~isempty(kk)
        dtt = dt{kk};
    else
        dtt = '';
    end
    fprintf(fid,'  %s%2d%05.2fN %2d%05.2fW%4.0f\r\n', ...
            ali(i,:),floor(S.geo(i,1)),mod(S.geo(i,1),1)*60,floor(-S.geo(i,2)),mod(-S.geo(i,2),1)*60,S.geo(i,3));
end
fclose(fid);
unix(sprintf('cat %s/%s >> %s',pftp,fhd0,f));
disp(sprintf('Fichier: %s créé.',f));

% ===========================================================================
% Fichier réseau UTM (carte)
fhd = 'RESEAU.DAT';

f = sprintf('%s/%s',pftp,fhd);
S = readst({'SZ','SA','SL'},{'G','M'});
ali = char(S.ali);
% élimine les acquisitions
k = find(~strcmp(S.ali,'-'));
% tri du Nord au Sud
[z,i] = sort(S.geo(k,1)); 
k = flipud(k(i));

f = sprintf('%s/%s',pftp,fhd);
fid = fopen(f,'wt');
for ii = 1:length(k)
    i = k(ii);
    fprintf(fid,'%s  %7.3f %8.3f %5.3f\r\n',ali(i,:),S.wgs(i,1)/1000,S.wgs(i,2)/1000,S.wgs(i,3)/1000);
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));


timelog(rname,2)
