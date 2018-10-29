function htmgraph(S)
%HTMGRAP Fabrique des pages graphiques HTML
%   HTMGRAPH(S) fabrique des pages HTML (frame, en-tete et graphes), à partir
%   de la structure S:
%       S.nom = nom complet du réseau (pages)
%       S.rcd = code du réseau
%       S.ftp = sous-répertoire des données "FTP" (devenu ipgp/acqui)
%       S.htm = page HTML du réseau (si existe)
%       S.ext = extensions des pages temporelles
%       S.sta = liste des codes graphiques (stations, réseau)
%       S.ali = liste des alias graphiques (stations, réseau)
%	S.dat = liste des liens vers les données
%
%   Si un fichier *.map existe pour un graphe donné, un IMAP est intégré avec le code
%   HTML du contenu.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-05-26
%   Mise à jour : 2009-09-10

X = readconf;

if nargin > 1
    imap = 1;
else
    imap = 0;
end

nbv = str2double(X.MKGRAPH_NBTAB_VIGNETTE);
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
ftf = sprintf('face="%s"',X.FONT_FACE_WEB);
ftt = sprintf('FONT %s size="%s"',ftf,X.FONT_SIZE_WEB);
bk = '&nbsp;';
novsg = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_NOTES_OVSG),'%s','delimiter','\n');
ngraph = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.MKGRAPH_FILE_NOTES),'%s','delimiter','\n');

if ~isfield(S,'img')
    for i = 1:length(S.ext)
        for ii = 1:length(S.sta)
            S.img{i}{ii} = sprintf('/%s/%s_%s.png',X.MKGRAPH_PATH_WEB,S.sta{ii},S.ext{i});
        end
    end
end

if ~isfield(S,'htm')
	S.htm = sprintf('/cgi-bin/afficheRESEAUX.pl?reseau=%s%s',S.obs,S.cod);
end

% Page frame
f = sprintf('%s/%s/%s_visu.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(S.rcd));
fid = fopen(f,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>Frame: %s %s</TITLE>%s</HEAD>\n',S.nom,datestr(now),css);
fprintf(fid,'<FRAMESET FrameBorder="0" scrolling="No" rows="110,*">\n');
fprintf(fid,'<FRAME name="Head" src="%s_head.htm" scrolling="No" NoResize>\n',lower(S.rcd));
fprintf(fid,'<FRAME name="Main" src="%s_visu_%s.htm">\n',lower(S.rcd),S.ext{1});
fprintf(fid,'</FRAMESET>\n<NOFRAMES>\n');
fprintf(fid,'<BODY onLoad="if (self != top) top.location = self.location"></BODY></HTML>');
fclose(fid);
disp(sprintf('Page: %s created.',f))

% Page d'en-tete
f = sprintf('%s/%s/%s_head.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(S.rcd));
fid = fopen(f,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>En-Tete: %s %s</TITLE>%s</HEAD><BODY>',S.nom,datestr(now),css);

%fprintf(fid,'<TABLE border="0" width="100%%"><TR>');
%fprintf(fid,'<TD width="105" style="border: 0"><A href="/" target="_top"><IMG src="/%s" width="100" height="99" alt="Accueil" border="0"></A></TD>',X.IMAGE_LOGO_OVSG_100_WEB);
%if S.net
%    fprintf(fid,'<TD style="border: 0"><H2>Graphes Réseau %s</H2></P>\n',S.nom);
%else
%    fprintf(fid,'<TD style="border: 0"><H2>Graphes %s</H2></P>\n',S.nom);
%end
if S.net
    fprintf(fid,'<H1>Graphes Réseau %s</H1>\n',S.nom);
else
    fprintf(fid,'<H1>Graphes %s</H1>\n',S.nom);
end
fprintf(fid,'<P>[ <A href="%s" target="bas">%s</A> | ',S.htm,S.nom);
if isfield(S,'dat')
	fprintf(fid,'<A href="%s" target="Main">Base de données</A>',S.dat{1});
else
	fprintf(fid,'<A href="%s/%s" target="Main">Données FTP</A>',X.WEB_RACINE_FTP,S.ftp);
end
fprintf(fid,' | Graphes:');
for i = 1:length(S.ext)
	if i>1, fprintf(fid,' |'); end
	fprintf(fid,' <A href="%s_visu_%s.htm" target="Main">%s</A>',lower(S.rcd),S.ext{i},ext2str(S.ext{i}));
end
if isfield(S,'lnk')
    for i = 1:length(S.lnk)
        fprintf(fid,' | <A href="%s" target="Main">%s</A>',S.lnk{i}{2},S.lnk{i}{1});
    end
end
fprintf(fid,' ]</P>\n');
%fprintf(fid,'<FONT size="1">');
%for i = 1:length(novsg)
%    fprintf(fid,'%s',novsg{i});
%end
%fprintf(fid,' Mise à jour: %s</FONT>',datestr(now));
%fprintf(fid,'</TD></TR></TABLE><HR>');
fprintf(fid,'<HR>');
fprintf(fid,'</FORM></BODY></HTML>\n');
fclose(fid);
disp(sprintf('Page: %s created.',f))

% Pages de graphes
for i = 1:length(S.ext)
    f = sprintf('%s/%s/%s_visu_%s.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(S.rcd),S.ext{i});
    fid = fopen(f,'wt');
    fprintf(fid,'<HTML><HEAD><TITLE>Graphe %s: %s %s</TITLE>%s</HEAD><BODY>\n',S.ext{i},S.nom,datestr(now),css);
    fprintf(fid,'<DIV id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></DIV>\n<SCRIPT language="JavaScript" src="/JavaScripts/overlib.js"></SCRIPT>\n<!-- overLIB (c) Erik Bosrup -->\n');
    if strcmp(S.ext(i),'ico')
        % --- page de vignettes
        fprintf(fid,'<TABLE border="0" width="100%%">');
        for ii = 1:length(S.sta)
            if mod(ii-1,nbv) == 0
                fprintf(fid,'<TR>');
            end
            fprintf(fid,'<TD align="center" style="border:0"><A href="%s"><IMG src="/%s/%s_%s.jpg" border="0"><BR>',S.img{end}{ii},X.MKGRAPH_PATH_WEB,S.sta{ii},S.ext{end});
            fprintf(fid,'<B>%s</B></A></TD>',S.ali{ii});
            if mod(ii,nbv) == 0 | ii == length(S.sta)
                fprintf(fid,'</TR>');
            end
        end
        fprintf(fid,'</TABLE>\n');
    else
        % --- page normale
        for ii = 1:length(S.sta)
            % Barres de liens
            fprintf(fid,'<P></P><P><A name="%s"></A>[',upper(S.sta{ii}));
            for iii = 1:length(S.sta)
                % graphes réseaux/stations
                if iii == ii
                    fprintf(fid,' <B>%s</B> |',S.ali{iii});
                else
                    fprintf(fid,' <A href="#%s"><B>%s</B></A> |',upper(S.sta{iii}),S.ali{iii});
                end
            end
            for iii = 1:length(S.ext)
                % graphes périodes temporelles
                if iii==i
                    fprintf(fid,' <B>%s</B> |',S.ext{iii});
                else
                    fprintf(fid,' <A href="%s_visu_%s.htm#%s"><B>%s</B></A> |',lower(S.rcd),S.ext{iii},upper(S.sta{ii}),S.ext{iii});
                end
            end
            % lien vers données
			if isfield(S,'dat')
				if length(S.dat) >= ii
					fprintf(fid,' <A href="%s"><IMG src="/images/data.gif" border="0" align="center"></A>',S.dat{ii});
				end
			else
				ff1 = sprintf('%s/%s.DAT',S.ftp,upper(S.sta{ii}));
				ff2 = sprintf('%s/%s_%s.txt',S.ftp,upper(S.sta{ii}),S.ext{iii});
				if exist(sprintf('%s,%s',X.RACINE_FTP,ff2),'file')
					fprintf(fid,' <A href="/%s/%s"><IMG src="/images/data.gif" border="0" align="center"></A>',ff2);
				else
					if exist(sprintf('%s,%s',X.RACINE_FTP,ff1),'file')
						fprintf(fid,' <A href="/%s/%s"><IMG src="/images/data.gif" border="0" align="center"></A>',ff1);
					else
						fprintf(fid,' <A href="%s/%s"><IMG src="/images/data.gif" border="0" align="center"></A>',X.WEB_RACINE_FTP,S.ftp);
					end
				end
            end
            % lien vers fiche station
            k = findstr(S.sta{ii},'_');
            if ~isempty(k)
                sta = S.sta{ii}(1:(k(1)-1));
            else
                sta = S.sta{ii};
            end
            ff = sprintf('%s/%s/%s.conf',X.RACINE_DATA_STATIONS,upper(sta),upper(sta));
            %ff = sprintf('%s/sites/stations/%s.htm',X.RACINE_WEB,sta);
            if exist(ff,'file')
                fprintf(fid,' <A href="/cgi-bin/%s?stationName=%s"><IMG src="/images/stat.gif" border="0" align="center"></A>',X.CGI_AFFICHE_STATION,upper(sta));
            end
            fprintf(fid,' ]</P>\n');
            % Image du graphe
            fmap = sprintf('%s/data/%s_%s.map',X.RACINE_OUTPUT_MATLAB,S.sta{ii},S.ext{i});
            if exist(fmap,'file')
                ss = textread(fmap,'%s','delimiter','\n');
                fprintf(fid,'<P><IMG src="%s" border="0" usemap="#map%d"></P>\n',S.img{i}{ii},ii);
                fprintf(fid,'<MAP name="map%d">\n',ii);
                for iii = 1:length(ss)
                    fprintf(fid,'%s\n',ss{iii});
                end
                fprintf(fid,'</MAP>');
            else
                fprintf(fid,'<P><IMG src="%s" border="0"></P>\n',S.img{i}{ii});
            end
        end
        fprintf(fid,'<A href="#%s"><B>Retour en haut</B></A>',upper(S.sta{1}));
    end
    % Notes
    fprintf(fid,'<HR>');
    for ii = 1:length(ngraph)
        fprintf(fid,'%s\n',ngraph{ii});
    end
    fprintf(fid,'<H6>');
    for ii = 1:length(novsg)
        fprintf(fid,'%s',novsg{ii});
    end
    fprintf(fid,'<BR>Mise à jour: %s</H6>',datestr(now));

    fprintf(fid,'</BODY></HTML>\n');
    fclose(fid);
    disp(sprintf('Page: %s created.',f))
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y=ext2str(x)
switch x
case '24h'
    y = '24 heures';
case '10j'
    y = '10 jours';
case '30j'
    y = '30 jours';
case '1an'
    y = '1 année';
case '5an'
    y = '5 années';
case '10a'
    y = '10 années';
case 'all'
    y = 'Toutes les données';
case '10l'
    y = '10 événements';
case 'ddc'
    y = 'Derniers déclenchements';
case 'ico'
    y = 'Vignettes';
case 'xxx'
    y = 'Spec';
otherwise
    y = 'Visu';
end
