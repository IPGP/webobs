function stations
%STATIONS Listes des stations OVSG
%       STATIONS construit plusieurs feuilles HTML à partir des informations de la base  
%       de données des stations, et du fichier "Codes_Zones_OVSG.txt".
%
%	2005-10-07: STATIONS a été très allégé car la majorité des pages est maintenant 
%	créée par des scripts PERL. Reste la liste des stations et le fichier exporté synthétisant
%	les coordonnées géographiques. Ancienne fonction sauvegardée en STATIONS0
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-12-27
%   Mise à jour : 2005-10-07

X = readconf;

rcode = 'RESEAUX';
scode = 'STATIONS';
timelog(scode,1)

% Initialisation des variables
pwww = sprintf('%s/sites',X.RACINE_WEB);
pftp = sprintf('%s/Reseaux',X.RACINE_FTP);
fzon = sprintf('%s/%s/reseaux_zones.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB);
feta = sprintf('%s/%s/reseaux_etats.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB);
S = readst; sc = char(S.cod);
Z = readcz;
[R,D] = readgr;
E = readetat;
notes = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.STATIONS_FILE_NOTES),'%s','delimiter','\n');

today = now;
todayvec = round(datevec(today));
matp = sprintf('<I>%s.m</I> (c) FB, OVSG-IPGP, %d-%02d-%02d %02d:%02d:%02d',lower(scode),todayvec);
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
fts = 'FONT face="Courier New,Courier" size="2"';
cs0 = 'align="CENTER"';
cs1 = 'align="LEFT"';
bk = '&nbsp;';


% =======================================================================================
% Liste des Stations
fid = fopen(fzon,'wt');

stitre = 'Liste des Stations';
codes(1).dis = 'Sismologie';
codes(1).tec = {'CP',{'SISMOCP'};'LB',{'SISMOLB'};'RAP',{'RAP'}};
codes(2).dis = 'Déformations';
codes(2).tec = {'Inclino',{'INCLINO'};'GPS',{'GPSCONT','GPSREP'};'AEMD',{'AEMD'};'Extenso',{'EXTENSO','FISSURO'}};
codes(3).dis = 'Géochimie';
codes(3).tec = {'Gaz',{'GAZ','BOJAP','RADON'};'Eaux',{'SOURCES'}};
codes(4).dis = 'Géophysique';
codes(4).tec = {'Gravi',{'GRAVI'};'MT',{'MAGN','PSELEC'};'Forage',{'FORAGES'}};
codes(5).dis = 'Divers';
codes(5).tec = {'Visu',{'CAMERAS'};'Météo',{'METEO','PLUVIO'};'Acqui',{'RELAIS','BATIM'}};
k = 0;
for i = 1:length(codes)
    k = k + size(codes(i).tec,1);
end
nbsta = zeros(length(Z.nom),k);

% En-tete HTML
fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>%s</HEAD>\n',stitre,datestr(today,'dd-mmm-yyyy'),css);
fprintf(fid,'<FORM>\n');

fprintf(fid,'<H2>%s</H2>',stitre);

% Tableau Stations
fprintf(fid,'<TABLE width="100%%">\n');
fprintf(fid,'<TR><TH>%s</TH>',bk);
for i = 1:length(codes)
    fprintf(fid,'<TH colspan="%d" %s>%s</TH>',size(codes(i).tec,1),cs0,codes(i).dis);
end
fprintf(fid,'</TR>\n');
fprintf(fid,'<TR><TH>%s</TH>',bk);
for i = 1:length(codes)
    for ii = 1:size(codes(i).tec,1)
        fprintf(fid,'<TH>%s</TH>',codes(i).tec{ii});
    end
end
fprintf(fid,'</TR>\n');
for i = 1:length(Z.nom)
    fprintf(fid,'<TR><TD %s><I>%s</I></TD>',cs0,Z.nom{i});
    js = 0;
    for j = 1:length(codes)
        for jj = 1:size(codes(j).tec,1)
            fprintf(fid,'<TD %s><%s><B>',cs0,fts);
            flag = 0;
            kt = [];
            for k = 1:length(codes(j).tec{jj,2});
                kt = [kt;find(strcmp(cellstr(char(R.rcd)),codes(j).tec{jj,2}{k}))];
            end
            for k = 1:length(kt)
                ks = find(strcmp(cellstr(sc(:,2:3)),R(kt(k)).cod));
                for iii = 1:length(ks)
                    if ~isempty(findstr(Z.cod{i},sc(ks(iii),4:6)))
                        nbsta(i,js+jj) = nbsta(i,js+jj) + 1;
                        if flag
                            fprintf(fid,'<BR>');
                        end
                        scod = deblank(sc(ks(iii),:));
                        fprintf(fid,'<A href="/cgi-bin/%s?stationName=%s">%s</A>',X.CGI_AFFICHE_STATION,scod,scod);
                        flag = 1;
                    end
                end
            end
            if ~flag
                fprintf(fid,'%s',bk);
            end
            fprintf(fid,'</B></FONT></TD>');
        end
        js = js + size(codes(j).tec,1);
    end
    fprintf(fid,'</TR>\n');
end
fprintf(fid,'<TR><TD %s><B>Nb stations</B></TD>',cs0);
k = 0;
for i = 1:length(codes)
    for ii = 1:size(codes(i).tec,1)
        k = k + 1;
        fprintf(fid,'<TD %s><B>%d</B></TD>',cs0,sum(nbsta(:,k)));
    end
end
fprintf(fid,'</TR>\n');

fprintf(fid,'</TABLE>\n');

fprintf(fid,'<P align="CENTER">Nombre total de stations = <B>%d</B></P>\n',sum(sum(nbsta)));

% Codes Techniques
fprintf(fid,'<A name="Codes"></A><P><B>Codes des Techniques</B></P>\n');
fprintf(fid,'<TABLE>\n');
[cod,icod] = sort(char(R.cod));
for i = 1:length(R)
    fprintf(fid,'<TR><TD><B>%s</B></TD>',R(icod(i)).cod);
    fprintf(fid,'<TD><I>%s</I></TD>',R(icod(i)).rcd);
    fprintf(fid,'<TD><B>%s</B> (%s)</TD></TR>\n',R(icod(i)).nom,R(icod(i)).dnm);
end
fprintf(fid,'</TABLE>\n');

% Notes
fprintf(fid,'<P>');
for i = 1:length(notes)
    fprintf(fid,'%s\n',notes{i});
end
fprintf(fid,'</P>\n');

fprintf(fid,'<BR><TABLE><TR><TD style="border: 0"><IMG src="../images/logo_ipgp.jpg"></TD>');
fprintf(fid,'<TD style="border: 0">%s</TD></TR></TABLE>\n',matp);

fprintf(fid,'</FORM></BODY></HTML>\n');
fclose(fid);
disp(sprintf('Fichier: %s créé.',fzon))



% =======================================================================================
% Création d'un fichier de stations (style ancien "Stations_WGS84.txt")
S = readst('',{'G','M','B','C','S'},0);
f = sprintf('%s/Stations_Infos.dat',pftp);
fid = fopen(f,'wt');
fprintf(fid,'# %s : Fichier de stations\n',datestr(today));
fprintf(fid,'#  Code      Alias   Data   Début   Fin    V    Lat_WGS    Lon_WGS   Alt  E_UTMW   N_UTMW  E_UTMA   N_UTMA  Date_Pos    T  Nom\n');
for i = 1:length(S.cod)
    if isnan(S.dte(i))
    	S.dte(i) = 0;
    end
    fprintf(fid,'%7s  %9s  %5s %10s %10s  %d  %9.5f  %9.5f  %4.0f  %5.0f  %6.0f  %5.0f  %6.0f  %s-%s-%s  %d  "%s"\n', ...
        S.cod{i},S.ali{i},S.dat{i},S.ins{i},S.fin{i},S.ope(i),S.geo(i,:),S.wgs(i,1:2),S.utm(i,1:2),datestr(S.dte(i),'yyyy'),datestr(S.dte(i),'mm'),datestr(S.dte(i),'dd'),S.pos(i),S.nom{i});
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));



timelog(scode,2)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [s,t] = pourc(p,m)

if isnan(p)
    t = '&nbsp;';
    s = '#FFFFFF';
else
    t = sprintf('%d&nbsp;%%',p);
end
if p < 10
    if findstr(m,'M') | findstr(m,'A')
        s = '#FF9900';
    else
        s = '#FF0000';
    end
end
if p >= 10 & p < 90
    s = '#FFFF00';
end
if p >= 90
    s = '#00FF00';
end
if p == -1
    t = 'Veille';
    s = '#AAAAAA';
end
