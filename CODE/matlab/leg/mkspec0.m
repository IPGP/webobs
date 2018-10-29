function mkspec
%MKSPEC Interprète le formulaire de graphes spécifiques.
%   MKSPEC est lancé par crontab toutes les minutes dès qu'un fichier visu_grspec.tmp
%   est détecté (voir "matlab-spec.csh").
%
%   - lance successibement toutes les routines choisies avec les options (dates et autre)
%   - les graphes (et données exportées) sont placées dans le répertoire
%   - un .zip du tout est produit au même endroit
%   - un fichier index.htm présente l'ensemble sous forme de page web
%   - un email est envoyé au demandeur
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-01-11
%   Mise à jour : 2009-10-01

X = readconf;

pwww = X.RACINE_WEB;
phtm = X.MKSPEC_RESULT_PATH_WEB;
fdat = sprintf('%s/%s',X.RACINE_OUTPUT_TOOLS,X.MKSPEC_OUTPUT_TMP_FILE);
fhcs = sprintf('%s/SISMOHYP_Spec.dat',X.RACINE_DATA_MATLAB);
flog = 'visu_grspec.log';
tnow = round(datevec(now));
sdate = sprintf('%d%02d%02d_%02d%02d',tnow(1:5));

if ~exist(fdat,'file')
	return;
end

% Log des requetes
unix(sprintf('cat %s >> %s/%s/%s',fdat,pwww,phtm,flog));

[line] = textread(fdat,'%s','delimiter','\n');
if isempty(line)
	return
end
[head] = strread(line{1},'%q','delimiter','|');
[data] = strread(line{end},'%q','delimiter','|');

% La ligne data contient:
%   - 1 à 5 : date début (DD MM YY hh mm)
%   - 6 à 10 : date fin (DD MM YY hh mm)
%   - 11 : TU (en heure)
%   - 12 : format date (fonction datestr)
%   - 13 : taille marqueurs (en pixels)
%   - 14 : durée cumul (en jour)
%   - 15 : décimation
%   - 16 : exportation
%   - 17 : toutes les routines (si 1)
%   - 18 à fin-1 : routine à lancer (1 ou 0)

dd = str2double(data(1:10));
ka = find(strcmp(head,'TOUT'));
va = str2double(data(ka));
k = find(strcmp(head,'HMmax'));
k0 = find(strcmp(head,'Envoyer'));
kr = (ka+1):(k-1);
nr = head(kr);
vr = str2double(data(kr));
sname = data{find(strcmp(head,'remHost'))};
suser = data{find(strcmp(head,'remUser'))};
t1 = datenum([dd([3 2 1 4 5]);0]');
t2 = datenum([dd([8 7 6 9 10]);0]');

% décodage des options dans la structure OPT
OPT.tu = str2double(data(11));
OPT.fmt = str2double(data(12));
OPT.mks = str2double(data(13));
OPT.cum = eval(data{14});
OPT.dec = str2double(data(15));
OPT.exp = str2double(data(16));
OPT.eps = 1;
% magnitudes
k = find(strcmp(head,'HMmax'));
hm = str2double(data(k + (0:1)));
OPT.hmmx = max(hm);
OPT.hmmn = min(hm);
% profondeurs
k = find(strcmp(head,'HPmax'));
hp = str2double(data(k + (0:1)));
OPT.hpmx = max(hp);
OPT.hpmn = min(hp);
k = find(strcmp(head,'MSK'));
OPT.hmsk = str2double(data(k));
k = find(strcmp(head,'HErh'));
OPT.herh = str2double(data(k));
k = find(strcmp(head,'HFiltre'));
if ~isempty(k)
	OPT.hfil = str2double(data(k));
else
	OPT.hfil = 0;
end
k = find(strcmp(head,'HAnciens'));
if ~isempty(k)
	OPT.hanc = str2double(data(k));
else
	OPT.hanc = 0;
end
k = find(strcmp(head,'HTitre'));
OPT.htit = data{k};
k = find(strcmp(head,'Lon1'));
hlo = str2double(data(k + (0:1)));
OPT.hloe = max(hlo);
OPT.hloo = min(hlo);
hla = str2double(data(k + (2:3)));
OPT.hlas = min(hla);
OPT.hlan = max(hla);
OPT.hcaz = str2double(data(k+4));
OPT.hcpr = str2double(data(k+5));
k = find(strcmp(head,'HCS'));
if ~isempty(k)
    OPT.hcsp = str2double(data(k));
    % modification de la carte spécifique en routine
    fid = fopen(fhcs,'wt');
    for i = 8:14, fprintf(fid,'"%s" ',head{k+i}); end
    fprintf(fid,'\n');
    for i = 8:14, fprintf(fid,'"%s" ',data{k+i}); end
    fclose(fid);
    disp(sprintf('Fichier: %s créé.',fhcs));
else
	OPT.hcsp = 0;
end

% toutes les routines
if ~isnan(va)
	vr = ones(size(vr));
end

if length(find(~isnan(vr)))

	% charge la liste des opérateurs
	O = readus;
	kuser = find(strcmp(suser,O.usr));
	if ~isempty(kuser)
		nuser = O.nom{kuser};
	else
		nuser = 'inconnu';
	end
    
    % construction du répertoire de requete
    dnam = sprintf('%s/%s_%s_%s',phtm,sdate,sname,suser);
    dirspec = sprintf('%s/%s',pwww,dnam);
    unix(sprintf('mkdir %s',dirspec));
    disp(sprintf('Répertoire: %s créé.',dirspec));

    % lancement des routines
    for i = 1:length(vr)
        if ~isnan(vr(i)) & exist(lower(nr{i}))
            nrout = sprintf('%s(1,[%d %d %d %d %d %d;%d %d %d %d %d %d],OPT,0,''%s'')',lower(nr{i}),datevec(t1),datevec(t2),dnam);
            ncatc = sprintf('disperr(''%s'')',nr{i});
            disp(sprintf('Eval: %s',nrout))
            eval(nrout,ncatc);
        end
    end
    
    if ~isempty(lasterr)
        unix(sprintf('cp /tmp/matlab-spec.log %s/error.txt',dirspec));
    end

    % identification des images créées
    fzip = sprintf('%s_OVSG_request.zip',sdate);
	LI = dir(sprintf('%s/*.png',dirspec));
    fimg = cellstr(char(LI.name));
    nb = length(LI);
    fgra = [];
    snav = ' ';
    for i = 1:nb
        ss = strread(fimg{i},'%s',1,'delimiter','_');
        fgra = [fgra,ss];
        snav = [snav sprintf('<A href="#%s"><B>%s</B></A> |',ss{:},upper(ss{:}))];
    end
    snav(end) = [];

    % fabrication d'une page Web sur la requete
    stitre = 'Résultat de Requête Graphique';
    fhtm = [dirspec '/index.htm'];
    matp = sprintf('<I>mkspec.m</I> (c) FB, OVSG-IPGP, %d-%02d-%02d %02d:%02d:%02d',tnow);
    bk = '&nbsp;';

    fid = fopen(fhtm,'wt');

    fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE><LINK rel="stylesheet" type="text/css" href="/%s"></HEAD>\n',stitre,datestr(now,'dd-mmm-yyyy'),X.FILE_CSS);
    fprintf(fid,'<BODY>\n');
    fprintf(fid,'<FORM>\n');
    fprintf(fid,'<TABLE border="0" width="100%%"><TR>');
    fprintf(fid,'<TD width="165"><A href="/" target="_top"><IMG src="/images/logo_ovsg.gif" alt="Accueil" border="0"></A></TD>');
    fprintf(fid,'<TD><H1>%s</H1>\n',stitre);
    fprintf(fid,'<P>Date: <B>%s</B><BR>\n',datestr(datenum(tnow)));
    fprintf(fid,'Utilisateur: <B>%s</B> (%s)<BR>\n',suser,nuser);
    fprintf(fid,'Machine: <B>%s</B><BR>',sname);
    fprintf(fid,'Période demandée: <B>%s</B> à <B>%s</B><BR>',datestr(t1),datestr(t2));
    fprintf(fid,'Nombre de graphe(s) créé(s): <B>%d</B></FONT></P>\n',length(fimg));
    fprintf(fid,'<P>[ <A href="../">Retour</A> | <A href="%s">Fichier ZIP</A> ]</FONT></P>\n',fzip);
    fprintf(fid,'</TD></TR></TABLE>');

    for i = 1:nb
        fprintf(fid,'<P><A name="%s"></A>[%s]<BR>\n',fgra{i},snav);
        if findstr(fgra{i},'SISMOHYP')
            fprintf(fid,'<A href="%s_xxx.htm"><IMG src="%s" alt="Cliquez pour accéder à la carte intéractive"></A></P>\n',fgra{i},fimg{i});
        else
            fprintf(fid,'<IMG src="%s"></P>\n',fimg{i});
        end
        fprintf(fid,'<P align="right"><A href="#top"><B>Retour en haut</B></A></P>');
    end

    fprintf(fid,'<BR><TABLE><TR><TD><IMG src="/images/matpad.gif" width="26" height="26"></TD>');
    fprintf(fid,'<TD>%s</TD></TR></TABLE>\n',matp);
    fprintf(fid,'</FORM></BODY></HTML>\n');

    fclose(fid);
    disp(sprintf('Fichier: %s créé.',fhtm))

    % Création du ZIP contenant tous les fichiers
    unix(sprintf('zip -q -T -j %s/%s %s/*',dirspec,fzip,dirspec));
    disp(sprintf('Fichier: %s/%s créé.',dirspec,fzip));


	% Envoi d'un email à l'utilisateur
	if ~isempty(O.mel(kuser))
		ftmp = sprintf('%s/mail',dirspec);
		fid = fopen(ftmp,'wt');
		fprintf(fid,'%s\n',stitre);
		fprintf(fid,'Date: %s\n',datestr(datenum(tnow)));
		fprintf(fid,'Utilisateur: %s (%s)\n',suser,nuser);
		fprintf(fid,'Machine: %s\n',sname);
		fprintf(fid,'Période demandée: %s à %s\n',datestr(t1),datestr(t2));
		fprintf(fid,'\nCliquer sur le lien ci-dessous pour accéder au(x) graphe(s) et fichier(s):\n\n');
	 	fprintf(fid,'http://%s/%s/',X.RACINE_URL,dnam);
		fclose(fid);
		alerte(sprintf('[WEBOBS-%s] Your graphic request is ready',X.OBSERVATOIRE),O.mel{kuser},ftmp);
	end
end


%==========================================================================
% Affiche des informations sur l'erreur
function disperr(s)
disp(sprintf('* Matlab Error: Problème avec la fonction %s',upper(s)));
disp(lasterr);
