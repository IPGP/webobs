function stations
%STATIONS Listes des stations OVSG
%       STATIONS construit plusieurs feuilles HTML à partir des informations de la base  
%       de données des stations, et du fichier "Codes_Zones_OVSG.txt".
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-12-27
%   Mise à jour : 2005-03-24

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
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/OVSG.css">');
ftf = sprintf('face="%s"',X.FONT_FACE_WEB);
ftt = sprintf('FONT %s size="6"',ftf);
ft1 = sprintf('FONT %s size="1"',ftf);
ft2 = sprintf('FONT %s size="2"',ftf);
ft3 = sprintf('FONT %s size="3"',ftf);
ft4 = sprintf('FONT %s size="4"',ftf);
ft5 = sprintf('FONT %s size="5"',ftf);
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

fprintf(fid,'<P align="CENTER"><%s>Nombre total de stations = <B>%d</B></FONT></P>\n',ft2,sum(sum(nbsta)));

% Codes Techniques
fprintf(fid,'<A name="Codes"></A><P><%s><B>Codes des Techniques</B></FONT></P>\n',ft4);
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
% Etats des Stations
fid = fopen(feta,'wt');

stitre = 'États des Stations';
prjmax = 80;

% En-tete HTML
fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>%s</HEAD>\n',stitre,datestr(today,'dd-mmm-yyyy'),css);
fprintf(fid,'<FORM>\n');

fprintf(fid,'<H2>%s</H2>',stitre);
fprintf(fid,'<P>[');
for i = 1:length(D.key)
    kt = find(strcmp(cellstr(char(R.dis)),D.key(i)));
    if i ~= 1, fprintf(fid,' |'); end
    fprintf(fid,' <A href="#%s">%s</A>',D.key{i},R(kt(1)).dnm);
end
fprintf(fid,' ]</P>\n');
        
% Tableau Disciplines, Techniques et Stations
fprintf(fid,'<TABLE width="100%%">\n');
for i = 1:length(D.key)
    kt = find(strcmp(cellstr(char(R.dis)),D.key(i)));
    if ~isempty(kt)
        fprintf(fid,'<TR><TD colspan="8" style="border:0"><BR><A name="%s"></A><H3>%s</H3> <P>[',D.key{i},R(kt(1)).dnm);
        for j = 1:length(kt)
            if j ~= 1, fprintf(fid,' |'); end
            fprintf(fid,' <A href="#%s">%s</A>',R(kt(j)).rcd,R(kt(j)).nom);
        end
        fprintf(fid,' ]</P></TD></TR>\n');
        for j = 1:length(kt)
            ST = readst(strread(R(kt(j)).cod,'%s'),R(kt(j)).obs);
            st = char(ST.cod);
            fprintf(fid,'<TH>État</TH><TH>Acqui</TH>');
            fprintf(fid,'<TH colspan="4"><A name="%s"></A>Réseau %s : ',R(kt(j)).rcd,R(kt(j)).nom);
            fprintf(fid,'%d %ss</TH></TR>\n',length(ST.cod),R(kt(j)).snm);
            for k = 1:length(ST.cod)
                scod = deblank(st(k,:));
                if strcmp(ST.cod{k}(1),'G')
                    fprintf(fid,'<TR>');
                    ks = find(strcmp(E.ss,lower(scod)));
                    if ~isempty(ks)
                        ks = ks(end);
                        [cs,ts] = pourc(E.pp(ks),R(kt(j)).typ);
                        fprintf(fid,'<TD %s bgcolor="%s"><B>%s</B></TD>',cs0,cs,ts);
                        [cs,ts] = pourc(E.aa(ks),R(kt(j)).typ);
                        fprintf(fid,'<TD %s bgcolor="%s"><B>%s</B>',cs0,cs,ts);
                    else
                        fprintf(fid,'<TD>%s</TD><TD>%s',bk,bk);
                    end
                    fprintf(fid,'</TD>');
                    % Code
                    fprintf(fid,'<TD %s><%s><A href="/cgi-bin/%s?stationName=%s"><B>%s</B></A></FONT></TD>',cs0,fts,X.CGI_AFFICHE_STATION,scod,scod);
                    % Alias
                    fprintf(fid,'<TD %s><B>%s</B></TD>',cs0,ST.ali{k});
                    % Nom
                    fprintf(fid,'<TD width="30%%" %s>%s</TD>',cs1,ST.nom{k});
                    % Projets
                    fprintf(fid,'<TD %s>',cs1);
                    fp = sprintf('%s/%s/INTERVENTIONS/%s_Projet.txt',X.RACINE_DATA_STATIONS,scod,scod);
                    if exist(fp,'file')
                        prj = textread(fp,'%s','delimiter','\n');
                        if length(prj) < 2
                            fprintf(fid,'%s',bk);
                        else
                            for ii = 2:length(prj)
                                fprintf(fid,'%s',prj{ii});
                            end
                        end
                    else
                        fprintf(fid,'%s',bk);
                    end
                    fprintf(fid,'</TD>');
                    fprintf(fid,'</TR>\n');
                end
            end
        end
    end
end

fprintf(fid,'</TABLE>\n');

% Codes Techniques
fprintf(fid,'<A name="Codes"></A><P><B>Codes des Techniques</B></FONT></P>\n');
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
disp(sprintf('Fichier: %s créé.',feta))


% =======================================================================================
% Création d'un fichier de stations (style ancien "Stations_WGS84.txt")
S = readst('',{'G','M','B','C','S'},0);
f = sprintf('%s/Stations_Infos.dat',pftp);
fid = fopen(f,'wt');
fprintf(fid,'# %s : Fichier de stations\n',datestr(today));
fprintf(fid,'#  Code      Alias   Data   Début   Fin    V    Lat_WGS    Lon_WGS   Alt  E_UTMW   N_UTMW  E_UTMA   N_UTMA  Date_Pos    T  Nom\n');
for i = 1:length(S.cod)
    fprintf(fid,'%7s  %9s  %5s %10s %10s  %d  %9.5f  %9.5f  %4.0f  %5.0f  %6.0f  %5.0f  %6.0f  %s-%s-%s  %d  "%s"\n', ...
        S.cod{i},S.ali{i},S.dat{i},S.ins{i},S.fin{i},S.ope(i),S.geo(i,:),S.wgs(i,1:2),S.utm(i,1:2),datestr(S.dte(i),'yyyy'),datestr(S.dte(i),'mm'),datestr(S.dte(i),'dd'),S.pos(i),S.nom{i});
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));


% =======================================================================================
% Création des pages individuelles de disciplines et réseaux (OVSG)

for i = 1:length(D.key)
    kd = find(strcmp(cellstr(char(R.dis)),D.key(i)) & strcmp(cellstr(char(R.obs)),'G'));
    pdis = sprintf('%s/%s',X.RACINE_DATA_WEB,D.key{i});
    f_obj = sprintf('%s_objet.txt',pdis);
    f_inf = sprintf('%s_informations.txt',pdis);
    f = sprintf('%s/%s/%s.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,D.key{i});
    fid = fopen(f,'wt');
    stitre = sprintf('Réseaux de %s',D.nom{i});
    fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>%s</HEAD>\n',stitre,datestr(today,'dd-mmm-yyyy'),css);
    fprintf(fid,'<FORM>\n');
    fprintf(fid,'<H2>%s</H2>\n<P>[ <A href="reseaux_stat.htm">Réseaux</A> |',stitre);
    for ii = 1:length(kd)
        if ii > 1
            fprintf(fid,' |');
        end
        fprintf(fid,' <A href="%s_stat.htm">%s</A>',lower(R(kd(ii)).rcd),R(kd(ii)).nom);
    end
    fprintf(fid,' ]</P>');
    fprintf(fid,'<H3>Objet</H3>\n');
    if exist(f_obj,'file')
        s = textread(f_obj,'%s','delimiter','\n');
        for iii = 1:length(s)
            fprintf(fid,'%s\n',s{iii});
        end
    end
    fprintf(fid,'<H3>Carte des réseaux intégrés</H3>\n');
    M = dir(sprintf('%s/sites/maps/DISCIPLINE_%s_*.htm',X.RACINE_WEB,D.key{i}));
    for iii = 1:length(M)
        if iii == 1
            fmap = sprintf('%s/data/%s.map',X.RACINE_OUTPUT_MATLAB,M(iii).name(1:(end-4)));
            if exist(fmap,'file')
                ss = textread(fmap,'%s','delimiter','\n');
                fprintf(fid,'<P><IMG src="/images/graphes/%s.png" border="1" usemap="#map"></P>\n',M(iii).name(1:(end-4)));
                fprintf(fid,'<MAP name="map">\n');
                for iiii = 1:length(ss)
                    fprintf(fid,'%s\n',ss{iiii});
                end
                fprintf(fid,'</MAP>');
            else
                fprintf(fid,'<P><A href="/sites/maps/%s"><IMG src="/images/graphes/%s.png"></A></P>',M(iii).name,M(iii).name(1:(end-4)));
            end
        else
            fprintf(fid,'<P>Voir aussi : <A href="/sites/maps/%s">Carte %s</A></P>',M(iii).name,M(iii).name(1:(end-4)));
        end                
    end
    if exist(f_inf,'file')
        s = textread(f_inf,'%s','delimiter','\n');
        for iii = 1:length(s)
            fprintf(fid,'%s\n',s{iii});
        end
    end
    fprintf(fid,'<BR><TABLE><TR><TD style="border: 0"><IMG src="../images/logo_ipgp.jpg"></TD>');
    fprintf(fid,'<TD style="border: 0">%s</TD></TR></TABLE>\n',matp);
    fprintf(fid,'</FORM></BODY></HTML>\n');
    fclose(fid);
    disp(sprintf('Page: %s créée.',f));
    
    for ii = 1:length(kd)
        pres = sprintf('%s/%s',X.RACINE_DATA_WEB,lower(R(kd(ii)).rcd));
        f_des = sprintf('%s_description.txt',pres);
        f_pro = sprintf('%s_protocole.txt',pres);
        f_bib = sprintf('%s_bibliographie.txt',pres);
        ST = readst(strread(R(kd(ii)).cod,'%s'),R(kd(ii)).obs,0);
        f = sprintf('%s/%s/%s_stat.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(R(kd(ii)).rcd));
        fid = fopen(f,'wt');
        stitre = sprintf('Stations Réseau %s',R(kd(ii)).nom);

        fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>%s</HEAD>\n',stitre,datestr(today,'dd-mmm-yyyy'),css);
        fprintf(fid,'<FORM>\n');
        fprintf(fid,'<H2>Réseau %s</H2>\n',R(kd(ii)).nom);
        fprintf(fid,'<P>[ <A href="%s.htm">%s</A> | ',D.key{i},D.nom{i});
        fprintf(fid,'<A href="#Caractéristiques">Caractéristiques</A> | <A href="#Stations">Liste</A> | <A href="#Localisation">Localisation</A> | <A href="#Protocole">Protocole</A> | <A href="#Bibliographie">Bibliographie</A> | ');
        fprintf(fid,'<A href="%s/%s">Données FTP</A> | <A href="%s_visu.htm" target="bas">Graphes</A> ]</P>',X.WEB_RACINE_FTP,R(kd(ii)).ftp,lower(R(kd(ii)).rcd));
        fprintf(fid,'<A name="Caractéristiques"><H3>Caractéristiques</H3></A>\n');
        fprintf(fid,'<P><B>Nombre de %ss:</B> %d (dont %d arrêtées)</P>',R(kd(ii)).snm,length(find(~strcmp(ST.ali,'-'))),length(find(ST.ope==0)));
        if ~isempty(R(kd(ii)).typ)
            fprintf(fid,'<P><B>Type de transmission:</B> %s - <B>Code réseau:</B> %s (n° %d)</P>',R(kd(ii)).typ,R(kd(ii)).cod,R(kd(ii)).net);
        end
        if ~isempty(R(kd(ii)).smp)
            fprintf(fid,'<P><B>Echantillonnage (mesure):</B> %s - <B>Période d''acquisition:</B> %s</P>',R(kd(ii)).smp,R(kd(ii)).acq);
        end
        fprintf(fid,'<P><B>Description:</B> ');
        if exist(f_des,'file')
            s = textread(f_des,'%s','delimiter','\n');
            for iii = 1:length(s)
                fprintf(fid,'%s\n',s{iii});
            end
        end
        fprintf(fid,'</P>\n');
        fprintf(fid,'<A name="Stations"><H3>Liste des %ss</H3></A>\n',R(kd(ii)).snm);
        fprintf(fid,'<TABLE width="100%%">\n');
        fprintf(fid,'<TR><TH>État</TH><TH>Acqui</TH><TH>Code</TH><TH>Alias</TH><TH>Nom</TH><TH>Type</TH><TH>Début</TH><TH>Fin / Dernière Mesure</TH></TR>');
        for iii = 1:length(ST.cod)
            scod = ST.cod{iii};
            ks = find(strcmp(E.ss,lower(scod)));
            if ~isempty(ks)
                ks = ks(end);
                [cs,ts] = pourc(E.pp(ks),R(kd(ii)).typ);
                fprintf(fid,'<TR><TD %s bgcolor="%s"><B>%s</B></TD>',cs0,cs,ts);
                [cs,ts] = pourc(E.aa(ks),R(kd(ii)).typ);
                fprintf(fid,'<TD  %s bgcolor="%s"><B>%s</B>',cs0,cs,ts);
            else
                fprintf(fid,'<TR><TD %s>%s</TD><TD %s>%s',cs0,bk,cs0,bk);
            end
            fprintf(fid,'<TD %s><%s><A href="/cgi-bin/%s?stationName=%s"><B>%s</B></A></FONT></TD>',cs0,fts,X.CGI_AFFICHE_STATION,scod,scod);
            fprintf(fid,'<TD %s><B>%s</B></TD>',cs0,ST.ali{iii});
            fprintf(fid,'<TD %s>%s</TD>',cs0,ST.nom{iii});
            styp = textread(sprintf('%s/%s/type.txt',X.RACINE_DATA_STATIONS,scod),'%s','delimiter','\n');
            if isempty(styp)
                styp = '';
            else
                styp = deblank(styp{1});
            end
            fprintf(fid,'<TD %s>%s</TD>',cs1,styp);
            fprintf(fid,'<TD %s>%s</TD>',cs0,ST.ins{iii});
            if ~isempty(ks) & strcmp(ST.fin{iii},'NA')
                fprintf(fid,'<TD %s>%s %s</TD>',cs0,E.dd{ks},E.tt{ks});
            else
                fprintf(fid,'<TD %s>%s</TD>',cs0,ST.fin{iii});
            end

            fprintf(fid,'</TR>');
        end
        fprintf(fid,'</TABLE>\n');
        fprintf(fid,'<A name="Localisation"><H3>Localisation des %ss</H3></A>\n',R(kd(ii)).snm);
        for iii = 1:length(R(kd(ii)).map)
            map = sprintf('%s_%s_MAP',R(kd(ii)).rcd,R(kd(ii)).map{iii});
            if iii == 1
                fmap = sprintf('%s/data/%s.map',X.RACINE_OUTPUT_MATLAB,map);
                if exist(fmap,'file')
                    ss = textread(fmap,'%s','delimiter','\n');
                    fprintf(fid,'<P><IMG src="/images/graphes/%s.png" border="1" usemap="#map"></P>\n',map);
                    fprintf(fid,'<MAP name="map">\n');
                    for iiii = 1:length(ss)
                        fprintf(fid,'%s\n',ss{iiii});
                    end
                    fprintf(fid,'</MAP>');
                else
                    fprintf(fid,'<P><A href="/sites/maps/%s.htm"><IMG src="/images/graphes/%s.png"></A></P>',map,map);
                end
            else
                fprintf(fid,'<P>Voir aussi : <A href="/sites/maps/%s.htm">Carte %s</A></P>',map,map);
            end                
        end
        fprintf(fid,'<A name="Protocole"><H3>Protocole</H3></A>\n');
        if exist(f_pro,'file')
            s = textread(f_pro,'%s','delimiter','\n');
            for iii = 1:length(s)
                fprintf(fid,'%s\n',s{iii});
            end
        end
        fprintf(fid,'<A name="Bibliographie"><H3>Bibliographie</H3></A>\n');
        if exist(f_bib,'file')
            s = textread(f_bib,'%s','delimiter','\n');
            fprintf(fid,'<UL>');
            for iii = 1:length(s)
                fprintf(fid,'<LI>%s\n',s{iii});
            end
            fprintf(fid,'</UL>');
        end
        fprintf(fid,'<BR><TABLE><TR><TD style="border: 0"><IMG src="../images/logo_ipgp.jpg"></TD>');
        fprintf(fid,'<TD style="border: 0">%s</TD></TR></TABLE>\n',matp);
        fprintf(fid,'</FORM></BODY></HTML>\n');
        fclose(fid);
        disp(sprintf('Page: %s créée.',f));
    end
end


% =======================================================================================
% Création de la page principale des disciplines et réseaux (OVSG)

stitre = sprintf('Réseaux de Surveillance');
f = sprintf('%s/%s/%s_stat.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(rcode));
fid = fopen(f,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>%s</HEAD>\n',stitre,datestr(today,'dd-mmm-yyyy'),css);
fprintf(fid,'<FORM>\n');
fprintf(fid,'<H2>%s</H2>',stitre);
pres = sprintf('%s/%s',X.RACINE_DATA_WEB,rcode);
f_obj = sprintf('%s_objet.txt',pres);
f_inf = sprintf('%s_informations.txt',pres);
fprintf(fid,'<H3>Objet</H3>\n<P>');
if exist(f_obj,'file')
    s = textread(f_obj,'%s','delimiter','\n');
    for iii = 1:length(s)
        fprintf(fid,'%s\n',s{iii});
    end
end
fprintf(fid,'</P>');
fprintf(fid,'<TABLE width="100%%">\n');
fprintf(fid,'<TR><TH>Discipline</TH><TH>Réseau</TH><TH>Type</TH><TH>Échant.</TH><TH>Acqui.</TH><TH>Nb</TH><TH>Graphes</TH><TH>Données</TH><TH>État</TH></TR>');
for i = 1:length(D.key)
    kd = find(strcmp(cellstr(char(R.dis)),D.key(i)) & strcmp(cellstr(char(R.obs)),'G'));
    fprintf(fid,'<TR><TD rowspan="%d" %s><A href="%s.htm"><B>%s</B></A></TD>',length(kd),cs1,D.key{i},D.nom{i});
    for ii = 1:length(kd)
        if ii > 1
            fprintf(fid,'<TR>');
        end
        rcod = lower(R(kd(ii)).rcd);
        ST = readst(strread(R(kd(ii)).cod,'%s'),R(kd(ii)).obs);
        fprintf(fid,'<TD %s><A href="%s_stat.htm"><B>%s</B></A></TD>',cs1,rcod,R(kd(ii)).nom);
        if isfield(R(kd(ii)),'typ')
            fprintf(fid,'<TD %s><B>%s</B></TD>',cs0,R(kd(ii)).typ);
        else
            fprintf(fid,'<TD %s>%s</TD>',cs0,bk);
        end
        if isfield(R(kd(ii)),'smp')
            fprintf(fid,'<TD %s>%s</TD>',cs0,R(kd(ii)).smp);
        else
            fprintf(fid,'<TD %s>%s</TD>',cs0,bk);
        end
        if isfield(R(kd(ii)),'acq')
            fprintf(fid,'<TD %s>%s</TD>',cs0,R(kd(ii)).acq);
        else
            fprintf(fid,'<TD %s>%s</TD>',cs0,bk);
        end
            
        fprintf(fid,'<TD %s>%d</TD>',cs0,length(find(~strcmp(ST.ali,'-'))));
        fgr = sprintf('%s/%s/%s_visu.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,rcod);
        if exist(fgr,'file')
            fprintf(fid,'<TD %s><A href="%s_visu.htm" target="bas"><IMG src="/images/visu.gif" border="0"></A></TD>',cs0,rcod);
        else
            fprintf(fid,'<TD %s>%s</TD>',cs0,bk);
        end
        if ~isempty(R(kd(ii)).ftp)
            fprintf(fid,'<TD %s><A href="%s/%s"><IMG src="/images/data.gif" border="0"></A></TD>',cs0,X.WEB_RACINE_FTP,R(kd(ii)).ftp);
        else
            fprintf(fid,'<TD %s>%s</TD>',cs0,bk);
        end
        ks = find(strcmp(E.ss,upper(rcod)));
        if ~isempty(ks)
            ks = ks(end);
            [cs,ts] = pourc(E.pp(ks),R(kd(ii)).typ);
            fprintf(fid,'<TD %s bgcolor="%s"><B>%s</B></TD>',cs0,cs,ts);
        else
            fprintf(fid,'<TD>%s</TD>',bk);
        end
        fprintf(fid,'</TR>');
    end
end
fprintf(fid,'</TABLE>\n');
if exist(f_inf,'file')
    s = textread(f_inf,'%s','delimiter','\n');
    for iii = 1:length(s)
        fprintf(fid,'%s\n',s{iii});
    end
end
fprintf(fid,'<BR><TABLE><TR><TD style="border: 0"><IMG src="../images/logo_ipgp.jpg"></TD>');
fprintf(fid,'<TD style="border: 0">%s</TD></TR></TABLE>\n',matp);fprintf(fid,'</FORM></BODY></HTML>\n');
fclose(fid);
disp(sprintf('Page: %s créée.',f));

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
