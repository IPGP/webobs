function mkmonitor
%MKMONITOR Edite la page de surveillance OVSG
%       MKMONITOR construit une feuille de surveillance HTML contenant les  
%       informations du fichier "www/sites/etats/etats.txt" sur les PC d'acquisition.
%

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-02-21
%   Mise à jour : 2004-06-22

X = readconf;

rname = 'mkmonitor';
stitre = 'Contrôle Surveillance OVSG';
timelog(rname,1)

% Initialisation des variables
today = now;
tnow = datevec(today);
tutc = datevec(today + 4/24);
fdat1 = sprintf('%s/Acquisition_OVSG.txt',X.RACINE_FICHIERS_CONFIGURATION);
fdat2 = sprintf('%s/data/etat_pc.dat',X.RACINE_OUTPUT_MATLAB);
pwww = X.RACINE_WEB;
fhtm = [pwww '/sites/etats/monitor.htm'];
last = 1/24;
nbc = 7;                                % Nombre d'acquisitions par ligne (tableau)

bk = '&nbsp;';
astr = 'ASTREINTE';
ftf = 'face="Arial,Helvetica"';
ftt = sprintf('FONT %s size="4"',ftf);
ft1 = sprintf('FONT %s size="1"',ftf);
ft2 = sprintf('FONT %s size="2"',ftf);
ft3 = sprintf('FONT %s size="3"',ftf);


% =======================================================================================
% Charge les fichier d'acquisitions et d'états
[A.cd,A.pc,A.dk,A.dl,A.tu,A.an,A.pr,A.co] = textread(fdat1,'%q%q%q%q%n%n%n%q','commentstyle','shell');
[E.cd,E.pp,E.aa,aa,mm,jj,hh,nn,ss,E.tu,E.tz,E.dt,E.pc,E.md] = textread(fdat2,'%q%n%n%n-%n-%n%n:%n:%n%n%n%n%q%n','commentstyle','shell');
E.tt = datenum(aa,mm,jj,hh,nn,ss);

jjj = sprintf('%03d',today - datenum(['01/00/' tnow(3:4)]));
wd = datestr(today,'ddd');


% =======================================================================================
% Détermine jour férié ou WE
J = readjf;
kk = find(J.dte == today);
if isempty(kk)
    jf = '';
else
    jf = sprintf('%s Férié "%s"',astr,char(J.nom(kk)));
end
if strcmp(wd,'Sat') | strcmp(wd,'Sun')
    jf = sprintf('%s Week End',astr);
end
aujourdhui = sprintf('<B>%s %s %s %s<BR>%02dh%02d</B>', ...
        traduc(wd),datestr(today,'dd'),traduc(datestr(today,'mmm')),datestr(today,'yyyy'),tnow(4),tnow(5));

    
% =======================================================================================
% Construit la page HTML
fid = fopen(fhtm,'wt');

% En-tete HTML
fprintf(fid,'<HTML><HEAD><TITLE>%s %s</TITLE>\n',stitre,datestr(now));
fprintf(fid,'<META http-equiv="Refresh" content="30"></HEAD>\n');
fprintf(fid,'<BODY text="#000000" bgcolor="#FFFFFF">\n');
fprintf(fid,'<FORM>\n');

% Titre
fprintf(fid,'<TABLE border="0" width="100%%"><TR>');
fprintf(fid,'<TD width="165"><A href="../../" target="_blank"><IMG src="../../images/logo_ovsg.gif" width="162" height="161" alt="Accueil" border="0"></A></TD>');
fprintf(fid,'<TD><FONT %s><H1>%s</H1></FONT></P>\n',ftf,stitre);
fprintf(fid,'<P><%s>[ ',ft3);
fprintf(fid,'<A href="feuille_routine.htm" target="_blank">Feuille de Routine</A> | ');
fprintf(fid,'<A href="../../sismo/sefran/index.htm" target="_blank">Dépouillement Sismo</A> | ');
fprintf(fid,'<A href="/cgi-bin/afficheMC.pl" target="_blank">Main Courante</A> | ');
fprintf(fid,'<A href="../../sismo/sefran/sefran_vign.htm" target="_blank">Vignettes SEFRAN</A> ]</FONT></P>\n');
fprintf(fid,'</TD><TD align="center"><FONT %s><H1>%s (%02d:%02d TU)</H1></FONT></P>\n',ftf,aujourdhui,tutc(4:5));
fprintf(fid,'</TD></TR></TABLE>');

% Tableau des acquisitions
fprintf(fid,'<TABLE border="1" width="100%%"><TR>');
k = find(A.pr > 0);
[pr,kk] = sort(A.pr(k));
for i = 1:length(kk)
    if i ~= 1 & mod(i - 1,nbc) == 0
        fprintf(fid,'</TR><TR>\n');
    end
    ki = kk(i);
    k = find(strcmp(A.cd(ki),E.cd));
    if ~isempty(k)
        pp = E.pp(k);
        aa = E.aa(k);
        dt = E.dt(k);
    else
        pp = 100;
        aa = 100;
        dt = 0;
    end
    fprintf(fid,'<TD align="center" valign="top" style="%s"><P><%s><B>%s : %s</B></FONT><BR>',bgcolor(pp,aa,dt),ft3,upper(A.cd{ki}),A.pc{ki});
    fprintf(fid,'<%s><B><I>%s</B></I><BR>',ft2,A.co{ki});
    k = find(strcmp(A.cd(ki),E.cd));
    if ~isempty(k)
        if pp ~= 0 | aa ~= 0
            fprintf(fid,'Acquisition: <B>%s</B><BR>',etat(aa));
            fprintf(fid,'Horloge (%+d s, TZ %+d): <B>%s</B><BR>',E.dt(k),E.tz(k),etat(pp));
        else
            fprintf(fid,'<BR><B>! PC PLANTÉ !</B>');
        end
    else
        fprintf(fid,'Acquisition: <B>Manuelle</B><BR>');
    end
    fprintf(fid,'</FONT></TD>');
end
fprintf(fid,'</TR></TABLE><P></P>');

% Dernières heures SEFRAN
fprintf(fid,'<TABLE border="0" cellpadding="0" cellspacing="0">\n');
for i = 0:24
    th = datenum([tutc(1:3),tutc(4) - i + 24,0,0]) - 1;
    tv = datevec(th);
    ff = sprintf('sismo/sefran/images/sefran_%02d%02d.jpg',tv(3:4));
    fprintf(fid,'<TR><TD><%s><B>%s%02d%s</B></FONT></TD>',ftt,bk,tv(4),bk);
    if exist(sprintf('%s/%s',pwww,ff),'file')
        fprintf(fid,'<TD><A href="../../sismo/sefran/sefran_%02d%02d.htm" target="_blank"><IMG src="../../%s"></A></TD></TR>\n',tv(3:4),ff);
    else
        fprintf(fid,'<TD>&nbsp;</TD></TR>\n');
    end
end

fprintf(fid,'</FORM></BODY></HTML>\n');
fclose(fid);

disp(sprintf('Fichier: %s créé.',fhtm))


timelog(rname,2)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Renvoie la couleur de fond en fonction de l'état
function cs = bgcolor(pp,aa,dt);

s = '255,255,255';
if isnan(aa)
    s = '255,255,0';
end
if abs(dt) > 60
    s = '255,192,0';
end
if pp == 0 | aa == 0
    s = '255,0,0';
end
cs = sprintf('background-color: rgb(%s)',s);

% Renvoie OK ou HS en fonction de l'état
function ok = etat(x);

ok = 'OK';
if isnan(x)
    ok = 'Vérifier';
end
if x == 0
    ok = 'HS';
end
