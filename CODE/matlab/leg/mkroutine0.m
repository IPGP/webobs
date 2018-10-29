function mkroutine(fetat)
%MKROUTINE Edite la routine automatique OVSG
%       MKROUTINE construit une feuille de routine HTML à remplir et traduit les 
%       informations contenues dans le fichier horaire "www/sites/etats/etats.txt" 
%       pour préremplir les partties "Acquisitions" et "Stations".
%
%       MKROUTINE(F) utilise le fichier F au lieu du fichier d'états courant.
%
%       MKROUTINE('') produit une feuille de routine vierge. 
%       
%       Spécificités:
%           - les lundis: changement de papier du pluvio
%           - les jour d'astreinte (WE et jours fériés): vérification du Fax et tableau 
%             de controle de l'activité
%           - feuille simplifiée pour l'après-midi (pas de Fax et certains controles)

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-09-12 (à Calgary, Canada...)
%   Mise à jour : 2006-02-06

X = readconf;

rname = 'mkroutine';
stitre = 'Feuille de Routine OVSG';
timelog(rname,1)

% Initialisation des variables
tnw = now;
tnow = datevec(tnw);
pftp = sprintf('%s/Reseaux/Etats',X.RACINE_FTP);
fhtm = sprintf('%s/sites/etats/feuille_routine.htm',X.RACINE_WEB);
if nargin == 0
    fetat = sprintf('%s/%s',X.RACINE_WEB,X.FILE_WEB_ETATS);
end
last = 1/24;


if isempty(fetat)
    vierge = 1;  
else
    vierge = 0;
end

bk = '&nbsp;';
astr = 'ASTREINTE';
ftf = 'face="Arial,Helvetica"';
ftt = sprintf('FONT %s size="4"',ftf);
ft1 = sprintf('FONT %s size="1"',ftf);
ft2 = sprintf('FONT %s size="2"',ftf);
%ctb = 'width="100%" cellspacing="0" border=".5"';
ctb = 'width="100%" cellspacing="0"';
cs0 = 'border-bottom: 1px solid rgb(192,192,192)';
cs1 = 'border-bottom: 1px solid rgb(192,192,192); border-right: 2px solid rgb(192,192,192)';
cs2 = 'border-bottom: 1px solid rgb(192,192,192); border-left: 2px solid rgb(192,192,192)';
cs3 = 'border-bottom: 1px solid rgb(192,192,192); border-left: 1px solid rgb(192,192,192); border-right: 1px solid rgb(192,192,192); background-color: rgb(208,208,208)';
cl0 = 'width="10%" align="CENTER"';
cl0a = 'width="7%" align="CENTER"';
cl1 = 'width="10%" align="CENTER"';
cl2 = 'width="5%" align="RIGHT"';
cl3 = 'width="5%" align="RIGHT"';
%cl4 = ['width="2%" align="CENTER" bgcolor="#DDDDDD"' cs0];
cl4 = 'width="2%" align="CENTER"';
cl5 = 'width="10%" align="CENTER"';
%cl6 = 'width="8%" align="CENTER"';
%cl7 = 'width="18%" align="CENTER"';
cl8 = 'width="20%" align="LEFT"';
cl9 = 'width="5%" align="CENTER"';

scode = {{'gszatg0','images/graphes/gszatg0_0_24h.png'}, {'gslamc0','images/graphes/gslamc0_0_24h.png'}, {'gdcade0','images/graphes/gdcade0_30j.png'},  ...
        {'gszbbl0','images/graphes/gszbbl0_0_24h.png'},  {'gslcde0','images/graphes/gslcde0_0_24h.png'}, {'gdcffe0','images/graphes/gdcffe0_30j.png'}, ...
        {'gszbpa0','images/graphes/gszbpa0_0_24h.png'}, {'gsllkg0','images/graphes/gsllkg0_0_24h.png'}, {'gdchou0','images/graphes/gdchou0_30j.png'}, ...
        {'gszbrg0','images/graphes/gszbrg0_0_24h.png'},  {'gslmml0','images/graphes/gslmml0_0_24h.png'}, {'gdcsou0','images/graphes/gdcsou0_30j.png'}, ...
        {'gszcag0','images/graphes/gszcag0_0_24h.png'}, {'gsaabf0','images/graphes/gsaabf0_ddc.png'}, {'gdiblk0','images/graphes/gdiblk0_24h.png'}, ...
        {'gszdeg0','images/graphes/gszdeg0_0_24h.png'},  {'gsaade0','images/graphes/gsaade0_ddc.png'}, {'gdifno0','images/graphes/gdifno0_24h.png'}, ...
        {'gszdog0','images/graphes/gszdog0_0_24h.png'},  {'gsaber0','images/graphes/gsaber0_ddc.png'},   {'gdigal0','images/graphes/gdigal0_24h.png'}, ...
        {'gszecg0','images/graphes/gszecg0_0_24h.png'},  {'gsacbe0','images/graphes/gsacbe0_ddc.png'},   {'gdirno0','images/graphes/gdirno0_24h.png'}, ...
        {'gszfng0','images/graphes/gszfng0_0_24h.png'},  {'gsagbg0','images/graphes/gsagbg0_ddc.png'},   {'gditar0','images/graphes/gditar0_24h.png'}, ...
        {'gszhmg0','images/graphes/gszhmg0_0_24h.png'},  {'gsahou1','images/graphes/gsahou1_ddc.png'},   {'ggmcag0','images/graphes/MAGN_24h.png'}, ...
        {'gszlkg0','images/graphes/gszlkg0_0_24h.png'},  {'gsaipt0','images/graphes/gsaipt0_ddc.png'},   {'ggmtag0','images/graphes/MAGN_24h.png'}, ...
        {'gszlzg0','images/graphes/gszlzg0_0_24h.png'},  {'gsajar0','images/graphes/gsajar0_ddc.png'},   {'ggmgal0','images/graphes/MAGN_24h.png'}, ...
        {'gszmag0','images/graphes/gszmag0_0_24h.png'},  {'gsames0','images/graphes/gsames0_ddc.png'},   {'ggmcde0','images/graphes/MAGN_24h.png'}, ...
        {'gszmgg0','images/graphes/gszmgg0_0_24h.png'},  {'gsamol0','images/graphes/gsamol0_ddc.png'},  {'ggmf300','images/graphes/MAGN_24h.png'}, ...
        {'gszmgh0','images/graphes/gszmgh0_0_24h.png'},  {'gsapig0','images/graphes/gsapig0_ddc.png'},   {'ggmlgt0','images/graphes/MAGN_24h.png'}, ...
        {'gszmog0','images/graphes/gszmog0_0_24h.png'},  {'gsaprf0','images/graphes/gsaprf0_ddc.png'},   {'ggef301','images/graphes/ggef301_24h.png'}, ...
        {'gszmlg0','images/graphes/gszmlg0_0_24h.png'},  {'gsasag0','images/graphes/gsasag0_ddc.png'},   {'ggwcde0','images/graphes/ggwcde0_24h.png'}, ...
        {'gsznev0','images/graphes/gsznev0_0_24h.png'},  {'gsasbt0','images/graphes/gsasbt0_ddc.png'},   {'ggwsav0','images/graphes/ggwsav0_24h.png'}, ...
        {'gszscg0','images/graphes/gszscg0_0_24h.png'},  {'gsasfg0','images/graphes/gsasfg0_ddc.png'},   {'ggwtas0','images/graphes/ggwtas0_24h.png'}, ...
        {'gszseg0','images/graphes/gszseg0_0_24h.png'},  {'gsasmm0','images/graphes/gsasmm0_ddc.png'},   {'gmmhou0','images/graphes/gmmhou0_24h.png'}, ...
        {'gszsfg0','images/graphes/gszsfg0_0_24h.png'},  {'gsasro0','images/graphes/gsasro0_ddc.png'},   {'gmmsou0','images/graphes/gmmsou0_24h.png'}, ...
        {'gszstg0','images/graphes/gszstg0_0_24h.png'},  {'gsatdb0','images/graphes/gsatdb0_ddc.png'},   {'gpvhou1','ftp/Pub/camera/visu.jpg'}, ...
        {'gsztag0','images/graphes/gsztag0_0_24h.png'},  {'gsathm0','images/graphes/gsathm0_ddc.png'},   {'gpvhou2','ftp/Pub/camera/soufriere.jpg'}, ...
};

tfax = {'"Mode Fax"','Fax urgent'};

TC = {'Météo','Météorologie générale:',{0,'Beau';0,'Variable';0,'Couvert';0,'Vent';0,'Pluie';0,'Orage'};
      'Électrique','Fonctionnement sur:',{0,'<B>EDF</B>';0,'<B>Groupe électrogène</B>';20,'= Explication:'};
      'Onduleurs','',{-2,'<B>Sismo 600 VA</B> (3 voyants verts)';0,'<B>Principal 10 kVA</B> (Status): INVERTER';0,'BATTERY';0,'BY-PASS'};
      'Horloges','',{0,'<B>LENNARTZ</B> OK ';0,'<B>LEAS</B> OK';0,'Synchro OK';0,'Nb Sat. = ___/___&nbsp;&nbsp;<B>GPS-INSU</B> OK';0,'Time Mode';0,'<B>OMEGA</B> OK'};
      'Sefram','Papier:',{0,'Bloqué';6,'à:';6,'TU => Débloqué à:';0,'TU&nbsp;&nbsp;Encriers remplis';-8,'Top Minute OK'};
      'Internet','Modem France-Télécom:',{0,'ALARMES (voyants rouges): <B>Locale</B>';0,'<B>Prolong. Réseau</B>';0,'Voyants oranges: <B>109</B>';0,'<B>103</B>';0,'<B>104</B>'};
      'Gravure','Gravure CDROM (2 graveurs HP):',{0,'Disques éjectés';0,'Gravure vérifiée';-10,'Disques vierges insérés'};
      'Archivage','Sauvegarde ARKEIA',{0,'Job OK';6,'DAT n°'};
      'Commentaires','',{0,''}};
     

%TD = {'Sefram Rouge','Stations OK:',{-2,'<B>MSGZ</B>';-2,'<B>CAGZ</B>';-2,'<B>TAGZ</B>';-2,'<B>DOGZ</B>';-2,'<B>PAGZ</B>';0,'Main courante';2,'Nb événements'};
%      'Sefram Vert','Stations OK:',{-2,'<B>MGHZ</B>';-2,'<B>SEGZ</B>';-2,'<B>DEGZ</B>';-2,'<B>MGGZ</B>';-2,'<B>BBLZ</B>';0,'Main courante';2,'Nb événements'};
TD = {'SefraN','',{5,'Dépouillé jusqu''à ';2,'TU&nbsp;&nbsp;Nb total d''événements = ';2,'dont volcaniques = ';2,'dont Saintes = ';0,'';5,'<br>Dépouillé jusqu''à ';2,'TU&nbsp;&nbsp;Nb total d''événements = ';2,'dont volcaniques = ';2,'dont Saintes = ';0,''}};

TS = {'Sismicité Régionale','',{3,'Nombre de séismes régionaux =';0,'&nbsp;&nbsp;Durée saturation > 1 minute';15,'Observations'};
      'Sismicité Soufrière','',{3,'Nombre de séismes volcaniques =';0,'Durée max. > 30 secondes';15,'Observations'};
      'GPS Soufrière','Visualiser <A href="../../deform/gpsc_visu.htm#SOUDC">SOUDC-HOUDC</A> :',{0,'Variations > 5 cm';15,'Observations'};
      'Forage Soufrière','Visualiser <A href="../../geophys/fora_visu_30j.htm#CDEW0">CDEW0</A> :',{0,'Variations > 0.5 °C';15,'Observations'};
      'Sismicité Montserrat','Activité:',{0,'Faible';0,'Moyenne';0,'Élevée';0,'Signaux saturés';10,'= Commentaires:'};
      'Commentaires','',{0,''}};

% Charge le fichier des acquisitions
A = readpc;
U = readus;
operat = [{bk};U.nom(find(U.ope))];

% Charge le fichier de routine
E = readetat(fetat);
ka = find(strcmp(E.ss,'ACQUIS'));
if ~isempty(ka)
    stacq = sprintf('Dernière routine de test des acquisitions = %s %s',E.dd{ka},E.tt{ka});
else
    stacq = 'ATTENTION: test des acquisitions PLANTÉ !!'
end
kr = find(strcmp(E.ss,'ROUTINE'));
if ~isempty(kr)
    ststa = sprintf('Dernière routine de test des stations = %s %s',E.dd{kr},E.tt{kr});
else
    ststa = 'ATTENTION: test des stations (routines MATLAB) PLANTÉ !!';
end
k = ka;
if isempty(k)
    k = kr;
end
sdate = E.dd{k};
shour = E.tt{k};
today = datenum([sdate(6:7) '/' sdate(9:10) '/' sdate(3:4)]);
trout = today + str2double(shour(1:2))/24 + str2double(shour(4:5))/1440;

% Test sur l'état de la feuille de routine
if tnw - trout > last
    vierge = 1;
end

if vierge == 0
    jjj = sprintf('%03d',today-datenum(['01/00/' sdate(3:4)]));
    wd = datestr(today,'ddd');

    % détermine jour férié ou WE
    J = readjf;
    kk = find(J.dte==today);
    if isempty(kk)
        jf = '';
    else
        jf = sprintf('%s Férié "%s"',astr,char(J.nom(kk)));
    end
    if strcmp(wd,'Sat') | strcmp(wd,'Sun')
        jf = sprintf('%s Week End',astr);
    end

    % détermine matin ou après-midi
    if str2double(shour(1:2)) >= 12
        am = 1;
        sam = 'Après-Midi';
    else
        am = 0;
        sam = 'Matin';
    end
    aujourdhui = sprintf('<B>%s %s %s %s</B> à <B>%sh%s</B> (locales)', ...
        traduc(wd),datestr(today,'dd'),traduc(datestr(today,'mmm')),datestr(today,'yyyy'),shour(1:2),shour(4:5));
else
    jf = bk;
    jjj = sprintf('%03.0f',tnw-datenum(tnow(1),1,0));
    wd = datestr(tnw,'ddd');
    am = 0;
    sam = 'Manuelle';
    aujourdhui = sprintf('<B>%s %s %s %s</B> à <B>%02dh%02d</B> (locales)', ...
        traduc(wd),datestr(tnw,'dd'),traduc(datestr(tnw,'mmm')),datestr(tnw,'yyyy'),tnow(4),tnow(5));
end

am = 0;
sam = '';

fid = fopen(fhtm,'wt');

% =======================================================================================
% En-tete HTML
fprintf(fid,'<HTML><HEAD><TITLE>Feuille de Routine OVSG %s</TITLE>\n',datestr(now));
%fprintf(fid,'<META http-equiv="Refresh" content="60">\n');
fprintf(fid,'</HEAD><BODY text="#000000" bgcolor="#FFFFFF">\n');
fprintf(fid,'<FORM>\n');

% =======================================================================================
% Titre, responsable, date et astreinte
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="3" align="CENTER" style="%s"><FONT %s size=5><B><A href="etats.txt">%s: %s</A></FONT><BR><BR></TD></TR>\n',cs0,ftf,stitre,sam);
fprintf(fid,'<TR><TD style="%s"><%s>Responsable: <SELECT name="Op" size="1"><OPTION selected>%s</OPTION>',cs2,ft2,operat{1});
for i = 2:length(operat)
    fprintf(fid,'<OPTION>%s</OPTION>',operat{i});
end
fprintf(fid,'</SELECT></FONT></TD>');
fprintf(fid,'<TD width="40%%" align="center" style="%s"><%s>%s</FONT></TD>',cs0,ft2,aujourdhui);
fprintf(fid,'<TD width="10%%" align="center" style="%s"><%s>Jour n° <B>%s</B></FONT></TD></TR>\n',cs1,ft2,jjj);

% jours d'astreinte
if ~isempty(jf)
    fprintf(fid,'<TR><TD align="CENTER" style="%s"><%s><B>%s</B></FONT></TD>',cs3,ft2,jf);
    fprintf(fid,'<TD colspan="2" align="right" style="%s">',cs0);
    if am == 0
        fprintf(fid,'<%s><B>Fax:</B>',ft1);
        for i = 1:length(tfax)
            fprintf(fid,' %s&nbsp;<INPUT type="checkbox">',tfax{i});
        end
        fprintf(fid,' = _______________________</FONT>');
    end
    fprintf(fid,'</TD></TR>');
end
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Contrôles Manuels
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>Contrôles Manuels</B></FONT></TD></TR>\n',cs0,ftt);
for j = 1:size(TC,1)
    if am == 0 | find(j == [4 5 8])
        if (strcmp(wd,'Mon') | vierge) & j == 1
            TC{j,2} = ['<B>Pluviomètre OVSG:</B> Papier changé&nbsp;<INPUT type="checkbox"> ' TC{j,2}];
        end
        fprintf(fid,'<TR><TD %s style="%s"><%s><B>%s</B></TD><TD align=right style="%s"><%s>%s',cl0,cs2,ft1,TC{j,1},cs1,ft1,TC{j,2});
        for i = 1:length(TC{j,3}(:,2))
            if TC{j,3}{i,1} <= 0
                fprintf(fid,' &nbsp;&nbsp;%s&nbsp;<INPUT type="checkbox">',TC{j,3}{i,2});
            end
            if TC{j,3}{i,1} < 0
                fprintf(fid,'%s&nbsp;&nbsp;',char('_'*ones(1,-2*TC{j,3}{i,1})));
            end
            if TC{j,3}{i,1} > 0
                %fprintf(fid,' %s&nbsp;<INPUT type="text" size="%d">',TC{j,3}{i,2},TC{j,3}{i,1});
                fprintf(fid,' %s&nbsp;%s',TC{j,3}{i,2},char('_'*ones(1,2*TC{j,3}{i,1})));
            end
        end
        fprintf(fid,'</FONT></TD></TR>\n');
    end
end
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% PC d'acquisition
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD style="%s"><%s><B>État PC</B></FONT></TD>',cs0,ftt);
fprintf(fid,'<TD style="%s"><%s><B>Acqui.</B></FONT></TD><TD style="%s"><%s><B>Horloge</B></FONT></TD>',cs0,ft1,cs0,ft1);
fprintf(fid,'<TD %s style="%s">&nbsp;</FONT></TD><TD %s style="%s"><%s><B>Heure&nbsp;Reset</FONT></TD>',cl4,cs3,cl5,cs1,ft1);
fprintf(fid,'<TD %s style="%s"><%s><B>PC</B></FONT></TD>',cl0,cs2,ft1);
fprintf(fid,'<TD style="%s"><%s><B>Acqui.</B></FONT></TD><TD style="%s"><%s><B>Horloge</B></FONT></TD>',cs0,ft1,cs0,ft1);
fprintf(fid,'<TD %s style="%s">&nbsp;</FONT></TD><TD %s style="%s"><%s><B>Heure&nbsp;Reset</FONT></TD>',cl4,cs3,cl5,cs1,ft1);
fprintf(fid,'<TD %s style="%s"><%s><B>PC</B></FONT></TD>',cl0,cs2,ft1);
fprintf(fid,'<TD style="%s"><%s><B>Acqui.</B></FONT></TD><TD style="%s"><%s><B>Horloge</B></FONT></TD>',cs0,ft1,cs0,ft1);
fprintf(fid,'<TD %s style="%s">&nbsp;</FONT></TD><TD %s style="%s"><%s><B>Heure&nbsp;Reset</FONT></TD>',cl4,cs3,cl5,cs1,ft1);
fprintf(fid,'</TR>\n');
for i = 1:length(A.pc)
    if vierge
        k = [];
    else
        k = find(strcmp(E.ss,A.ac(i)));
    end
    if ~isempty(k)
        k = k(end);
        if strcmp(E.st{k},'-'), se = bk; else se = E.st{k}; end
        if length(E.cc{k})
            [cm1,cm2] = strread(E.cc{k},'%q%q');
            cm1 = cm1{:};
            cm2 = cm2{:};
        else
            cm1 = bk;  cm2 = '';
        end
    else
        se = bk;
        cm1 = '???'; cm2 = '';
    end
    if length(cm2)
        seac = sprintf('<TD style="%s; %s"><%s>%s</TD><TD style="%s; %s"><%s>%s</TD>',cs0,bgcolor(se),ft1,cm1,cs0,bgcolor(se),ft1,cm2);
    else
        seac = sprintf('<TD colspan="2" style="%s; %s"><%s>%s</TD>',cs0,bgcolor(se),ft1,cm1);
    end
    if mod(i,3) == 1
        fprintf(fid,'<TR>');
    end
    fprintf(fid,'<TD %s style="%s; %s">',cl0,cs2,bgcolor(se));
    fprintf(fid,'<%s><B>%s</B></FONT></TD>',ft1,A.ac{i});
    fprintf(fid,'%s',seac);
    fprintf(fid,'<TD %s style="%s"><%s><B>%s</B></FONT></TD>',cl4,cs3,ft1,se);
    fprintf(fid,'<TD %s style="%s">&nbsp;</FONT></TD>',cl5,cs1);
    if mod(i,3)==0
        fprintf(fid,'</TR>\n');
    end
    if mod(i,3) & i==length(A.pc)
        fprintf(fid,'<TD colspan="%d" style="%s">&nbsp;</TD></TR>\n',(mod(i,3)+1)*5,cs1);
    end
end
fprintf(fid,'<TR><TD colspan="2" align="left" style="%s"><%s><B>&nbsp;Commentaires</B></FONT></TD>',cs2,ft1);
fprintf(fid,'<TD colspan="13" align="right" style="%s"><%s>%s <INPUT type="checkbox"></TD></TR>\n',cs1,ft1,stacq);
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Etat des stations
nbes = 3;
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>État Stations</B></FONT></TD>',cs0,ftt);
for i = 1:nbes
    if i > 1
        fprintf(fid,'<TD %s style="%s"><%s><B>Station</FONT></TD><TD %s style="%s"><%s><B>Dernière&nbsp;Mesure</FONT></TD>',cl0a,cs2,ft1,cl1,cs0,ft1);
    end
    fprintf(fid,'<TD %s style="%s"><%s><B>Acqui.</FONT></TD><TD %s style="%s"><%s><B>Valid.</FONT></TD><TD %s style="%s">&nbsp;</FONT></TD><TD %s style="%s"><%s><B>Rem.</FONT></TD>', ...
            cl2,cs0,ft1,cl3,cs0,ft1,cl4,cs3,cl9,cs1,ft1);
end
fprintf(fid,'</TR>\n');
for i = 1:length(scode)
    if vierge
        k = [];
    else
        k = find(strcmp(E.ss,scode{i}{1}));
    end
    if ~isempty(k)
        k = k(end);
        if strcmp(E.st{k},'-'), se = bk; else se = E.st{k}; end
        ld = sprintf('%s&nbsp;%s',datestr(E.dt(k),24),datestr(E.dt(k),15));
        %if strcmp(E.dd{k},sdate), ld = E.tt{k}; else ld = E.dd{k}; end
        sa = sprintf('%03d&nbsp;%%',E.aa(k));
        sp = sprintf('%03d&nbsp;%%',E.pp(k));
        sc = E.cc{k};
        sc = sc(1:min([12,length(sc)]));
    else
        se = bk;
        ld = bk;
        sa = '%';
        sp = '%';
        sc = bk;
    end
    if mod(i,nbes) == 1
        fprintf(fid,'<TR><TD %s style="%s">',cl0a,cs2);
    else
        fprintf(fid,'<TD %s style="%s">',cl0a,cs2);
    end
    if ~isempty(scode{i}{2})
        fprintf(fid,'<%s><A href="/%s" style="text-decoration: none"><B>%s</B></A></FONT></TD>',ft1,scode{i}{2},upper(scode{i}{1}));
    else
        fprintf(fid,'<%s><B>%s</B></FONT></TD>',ft1,upper(scode{i}{1}));
    end
    %fprintf(fid,'<TD style="%s"><%s>%s</FONT></TD>',cs0,ft1,sc);
    fprintf(fid,'<TD %s style="%s"><%s>%s</FONT></TD>',cl1,cs0,ft1,ld);
    fprintf(fid,'<TD %s style="%s"><%s>%s%s</FONT></TD>',cl2,cs0,ft1,sa,bk);
    fprintf(fid,'<TD %s style="%s"><%s>%s%s</FONT></TD>',cl3,cs0,ft1,sp,bk);
    fprintf(fid,'<TD %s style="%s"><%s><B>%s</B></FONT></TD>',cl4,cs3,ft1,se);
    fprintf(fid,'<TD %s style="%s">&nbsp;</FONT></TD>',cl9,cs1);
    if mod(i,nbes)==0 | i==length(scode)
        fprintf(fid,'</TR>\n');
    end
end
fprintf(fid,'<TR><TD colspan="2" align="left" style="%s"><%s><B>&nbsp;Commentaires</B></FONT></TD>',cs2,ft1);
fprintf(fid,'<TD colspan="%d" align="right" style="%s"><%s>%s <INPUT type="checkbox"></TD></TR>\n',nbes*7 - 2,cs1,ft1,ststa);
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Dépouillement Sismologie
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>Dépouillement Sismologie</B></FONT></TD></TR>\n',cs0,ftt);
for j = 1:size(TD,1)
    fprintf(fid,'<TR><TD %s style="%s"><%s><B>%s</B></TD><TD align=right style="%s"><%s>%s',cl0,cs2,ft1,TD{j,1},cs1,ft1,TD{j,2});
    for i = 1:length(TD{j,3}(:,2))
        if TD{j,3}{i,1} <= 0
            fprintf(fid,' %s&nbsp;<INPUT type="checkbox">',TD{j,3}{i,2});
        end
        if TD{j,3}{i,1} < 0
            fprintf(fid,'%s&nbsp;&nbsp;',char('_'*ones(1,-2*TD{j,3}{i,1})));
        end
        if TD{j,3}{i,1} > 0
            fprintf(fid,'%s&nbsp;%s&nbsp;&nbsp;',TD{j,3}{i,2},char('_'*ones(1,2*TD{j,3}{i,1})));
            %fprintf(fid,' %s&nbsp;<INPUT type="text" size="%d">',TD{j,3}{i,2},TD{j,3}{i,1});
        end
    end
    fprintf(fid,'</FONT></TD></TR>\n');
end
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Surveillance (astreinte)
if am & ~isempty(jf)
    fprintf(fid,'<TABLE %s>\n',ctb);
    fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>Surveillance ASTREINTE</B></FONT></TD></TR>\n',cs0,ftt);
    for j = 1:size(TS,1)
        fprintf(fid,'<TR><TD %s style="%s"><%s><B>%s%s</B></TD><TD align=right style="%s"><%s>%s',cl8,cs2,ft1,bk,TS{j,1},cs1,ft1,TS{j,2});
        for i = 1:length(TS{j,3}(:,2))
            if TS{j,3}{i,1} <= 0
                fprintf(fid,' %s%s%s<INPUT type="checkbox">',bk,bk,TS{j,3}{i,2},bk);
            end
            if TS{j,3}{i,1} < 0
                fprintf(fid,'%s%s%s',char('_'*ones(1,-2*TS{j,3}{i,1})),bk,bk);
            end
            if TS{j,3}{i,1} > 0
                fprintf(fid,' %s%s%s',TS{j,3}{i,2},bk,char('_'*ones(1,2*TS{j,3}{i,1})));
            end
        end
        fprintf(fid,'</FONT></TD></TR>\n');
    end
    fprintf(fid,'</TABLE><BR>\n');
end

% =======================================================================================
% En cas de problèmes...
fprintf(fid,'<P align="center"><FONT %s size="1"><I>En cas de problème:</I> ',ft1);
fprintf(fid,'Christian: <B>0690&nbsp;55&nbsp;46&nbsp;33</B>, ');
fprintf(fid,'François: <B>0690&nbsp;55&nbsp;46&nbsp;45</B>, ');
fprintf(fid,'EDF: <B>0590&nbsp;81&nbsp;15&nbsp;47, ');
fprintf(fid,'Internet UAG: <B>0590&nbsp;93&nbsp;86&nbsp;63</B>, ');
fprintf(fid,'France-Télécom (LS n°217B160T): <B>10&nbsp;15</B></FONT></P>');

fprintf(fid,'</FORM></BODY></HTML>\n');

fclose(fid);

disp(sprintf('Fichier: %s créé.',fhtm))

% Archivage des feuilles d'états (tous les jours à 12h)
if tnow(4) == 12
    p = sprintf('%s/%d',pftp,tnow(1));
    if ~exist(p,'dir')
        unix(sprintf('mkdir %s',p));
    end
    f = sprintf('%s/Routine_OVSG_%d%02d%02d.txt',p,tnow(1:3));
    unix(sprintf('cp -f %s %s',fetat,f));
    disp(sprintf('Fichier: %s créé.',f))
end

timelog(rname,2)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Donne la couleur de fond en fonction de l'état
function cs = bgcolor(x);

switch x
case '&nbsp;'
    s = '255,255,255';
case '?'
    s = '255,255,0';
case 'x'
    s = '255,192,0';
case 'X'
    s = '255,0,0';
end
cs = sprintf('background-color: rgb(%s)',s);
