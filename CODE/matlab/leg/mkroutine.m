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
%   Mise à jour : 2007-09-23

X = readconf;

rname = 'mkroutine';
stitre = 'Feuille de routine OVSG';
timelog(rname,1)

% Initialisation des variables
tnw = now;
tnow = datevec(tnw);
pftp = sprintf('%s/Reseaux/Etats',X.RACINE_FTP);
fhtm = sprintf('%s/sites/etats/feuille_routine.htm',X.RACINE_WEB);
ftmp = '/tmp/routine.htm';
if nargin == 0
    fetat = sprintf('%s/%s',X.RACINE_WEB,X.FILE_WEB_ETATS);
end
last = 1/24;
%last=1;

scode = {'SISMOCP','SISMOLB','RAP','GPSCONT','INCLINO','AEMD','EXTENSO','TIDES','MAGN','TEMPFLUX','GAZ','SOURCES','METEO','CAMERAS'};

if isempty(fetat)
    vierge = 1;  
else
    vierge = 0;
end

bk = '&nbsp;';
astr = 'ASTREINTE';
ftt = sprintf('FONT size="4"');
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

css = {'body { font-family: Arial,Helvetica; font-size: 7pt; background-color: white; color: black; }', ...
       'td { font-size: 7pt; } input {border 1px solid black}', ...
};

tfax = {'"Mode Fax"','Fax urgent'};

TC = {'Météo','<b><a href="http://www.ovsg.univ-ag.fr/auto/meteo_visu.htm">Station météo</a> et observations</b>',{0,'&nbsp;Beau';0,'&nbsp;Variable';0,'&nbsp;Couvert';
0,'<br>Vent';4,'&nbsp;Pluie';0,'mm.&nbsp;&nbsp;Orage'};
      'Électrique','<b>Fonctionnement sur</b>:',{0,'EDF';0,'Groupe';30,'...'};
      'Onduleurs','',{0,'<B>Baie sismique 600 VA</B> : Entrée';0,'Batterie';0,'Sortie';
                      0,'<br><B><a href="http://ond1.ovsg.univ-ag.fr/">Principal 10 kVA</a></B>';4,'Charge';30,'...'};
                      %0,'<br><B>Powerware serveurs</B> «On Line» : A1';0,'A3';0,'A4'};
      'Horloges','',{0,'<B>Lennartz</B>';
      0,'<br><B>GPS-Insu</B>';0,'Time mode';0,'Time out';
      0,'<br><B>GPS ES911</B>';0,'Time sync';0,'GPS lock'};
      %0,'<br><B>Émetteur GPS</B>'};
      %'Sefram','Papier:',{0,'Bloqué';6,'à:';6,'TU => Débloqué à:';0,'TU&nbsp;&nbsp;Encriers remplis';-8,'Top Minute OK'};
      %'Climatisation','Climatisation des acquisitions :', { 0,'Portes et fenêtres fermées'; 0,'Ventilation : 1'; 0,'Froid'; 0,'Volets'; 0,'Volets'; 0,'Alternance manuelle'; };
      %'Archivage','Gravure CDROM:',{0,'<B>HP n°1</B>: Disque éjecté';0,'Gravure vérifiée';0,'Disque vierge inséré';
      %0,'<br><B>HP n°2</B>: Disque éjecté';0,'Gravure vérifiée';0,'Disque vierge inséré';
      %0,'<br><b>Sauvegarde Bacula</b> OK';4,'VS160-1 K7 éjectée n°';4,'K7 insérée n°'};
%      'Surveillance','Disponibilité, date et heure :',{0,'<B>Contrôle Surveillance</B>';0,'<B>SefraN</B>';0,'<B>Feuille de routine</B>';
%	      0,'<br><b>Nagios, nouvelles pannes :</b>';0,'Réseau'; 0,'Hôtes'; 0,'Services'; };
      %'Surveillance','',{0,'<b>Nouvelles pannes <a href="http://nagios.ovsg.univ-ag.fr/nagios3/">Nagios</a></b>';0,'<b><a href="http://nagios.ovsg.univ-ag.fr/cgi-bin/nagios3/status.cgi?servicegroup=sms&amp;style=detail">Alertes SMS</a></b>'; 30,'...'; };
      %'Climatisation','Climatiseurs :', { 0,'<b>A1</b> : Ventilation'; 0,'Froid'; 0,'Volets : H'; 0,'V';
      %0,'<br><b>A2</b> : Ventilation'; 0,'Froid'; 0,'Volets : H'; 0,'V';
      %0,'<br>Portes et fenêtres fermées'; 0,'Alternance manuelle'; 20,};
      'Climatisation','', { 0,'<b>Acquisition</b> : A1';0,'A2'; 0,'  <b>Chimie</b> : Eaux'; 0,'Gaz';30,'...'};
      'Chimie','<b>Spectromètre gaz</b> :',{6,'Pression';0,'10<sup>-8</sup> mb&nbsp;OK (<5)'};
      'Commentaires','',{120,''}};
     

%TD = {'Sefram Rouge','Stations OK:',{-2,'<B>MSGZ</B>';-2,'<B>CAGZ</B>';-2,'<B>TAGZ</B>';-2,'<B>DOGZ</B>';-2,'<B>PAGZ</B>';0,'Main courante';2,'Nb événements'};
%      'Sefram Vert','Stations OK:',{-2,'<B>MGHZ</B>';-2,'<B>SEGZ</B>';-2,'<B>DEGZ</B>';-2,'<B>MGGZ</B>';-2,'<B>BBLZ</B>';0,'Main courante';2,'Nb événements'};
TD = {'SefraN','',{5,'Opérateur';5,'Dépouillé jusqu''à ';2,'TU&nbsp;&nbsp;Nb total d''événements';2,'dont volcaniques';2,'dont Saintes';0,'';
               5,'<br>Opérateur';5,'Dépouillé jusqu''à ';2,'TU&nbsp;&nbsp;Nb total d''événements';2,'dont volcaniques';2,'dont Saintes';0,'';
               5,'<br>Opérateur';5,'Dépouillé jusqu''à ';2,'TU&nbsp;&nbsp;Nb total d''événements';2,'dont volcaniques';2,'dont Saintes';0,'';
               5,'<br>Opérateur';5,'Dépouillé jusqu''à ';2,'TU&nbsp;&nbsp;Nb total d''événements';2,'dont volcaniques';2,'dont Saintes';0,'';
       }};

%TS = {'Sismicité Régionale','',{3,'Nombre de séismes régionaux =';0,'&nbsp;&nbsp;Durée saturation > 1 minute';15,'Observations'};
%      'Sismicité Soufrière','',{3,'Nombre de séismes volcaniques =';0,'Durée max. > 30 secondes';15,'Observations'};
%      'GPS Soufrière','Visualiser <A href="auto/gpscont_visu.htm#GDCSOU0">SOUF-HOUE</A> :',{0,'Variations > 5 cm';15,'Observations'};
%      'Commentaires','',{0,''}};
TS = {'Commentaires','',{0,''}};


% Charge les informations des réseaux
G = readgr;

% Charge le fichier des acquisitions
A = readpc;
U = readus;
operat = [{bk};U.nom(find(U.ope))];

% Charge le fichier de routine
E = readetat(fetat);
ka = find(strcmp(E.ss,'ACQUIS'));
if ~isempty(ka)
    stacq = sprintf('Test à %s %s',E.dd{ka},E.tt{ka});
else
    stacq = 'ATTENTION: test des acquisitions PLANTÉ !!'
end
kr = find(strcmp(E.ss,'ROUTINE'));
if ~isempty(kr)
    ststa = sprintf('Test à %s %s',E.dd{kr},E.tt{kr});
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

    aujourdhui = sprintf('<B>%s %s %s %s</B> à <B>%sh%s</B> (locales)', ...
        traduc(wd),datestr(today,'dd'),traduc(datestr(today,'mmm')),datestr(today,'yyyy'),shour(1:2),shour(4:5));
else
    jf = bk;
    jjj = sprintf('%03.0f',tnw-datenum(tnow(1),1,0));
    wd = datestr(tnw,'ddd');
    aujourdhui = sprintf('<B>%s %s %s %s</B> à <B>%02dh%02d</B> (locales)', ...
        traduc(wd),datestr(tnw,'dd'),traduc(datestr(tnw,'mmm')),datestr(tnw,'yyyy'),tnow(4),tnow(5));
end

fid = fopen(ftmp,'wt');

% =======================================================================================
% En-tete HTML
fprintf(fid,'<HTML><HEAD><TITLE>Feuille de Routine OVSG %s</TITLE>\n',datestr(now));
%fprintf(fid,'<META http-equiv="Refresh" content="60">\n');
fprintf(fid,'<style type="text/css">\n<!--\n');
for i = 1:length(css)
    fprintf(fid,'%s\n',css{i});
end
fprintf(fid,'--></style></HEAD><BODY>\n<FORM>\n');

% =======================================================================================
% Titre, responsable, date et astreinte
fprintf(fid,'<TABLE %s>\n',ctb);
%fprintf(fid,'<TR><TD colspan="3" align="CENTER" style="%s"><FONT size=5><B><A href="etats.txt">%s</A></FONT><BR><BR></TD></TR>\n',cs0,stitre);
fprintf(fid,'<TR><TD><B>%s</B>    <A href="etats.txt">Données</A>    <A href="http://wiki.ovsg.univ-ag.fr/dokuwiki/doku.php?id=feuille_de_routine">Manuel</A></TD>\n',stitre);
fprintf(fid,'<TD><FONT size=2>Responsable: <SELECT name="Op" size="1"><OPTION selected>%s</OPTION>',operat{1});
for i = 2:length(operat)
    fprintf(fid,'<OPTION>%s</OPTION>',operat{i});
end
fprintf(fid,'</SELECT></FONT></TD>');
fprintf(fid,'<TD align="center">%s</TD>',aujourdhui);
fprintf(fid,'<TD align="center">Jour n° <B>%s</B></TD></TR>\n',jjj);

% jours d'astreinte
if ~isempty(jf)
    fprintf(fid,'<TR><TD align="CENTER" style="%s"><B>%s</B></FONT></TD>',cs3,jf);
    fprintf(fid,'<TD colspan="2" align="right" style="%s">',cs0);
        fprintf(fid,'<B>Fax:</B>');
        for i = 1:length(tfax)
            fprintf(fid,' %s&nbsp;<INPUT type="checkbox">',tfax{i});
        end
        fprintf(fid,' = _______________________ </FONT>');
    fprintf(fid,'</TD></TR>');
end
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Contrôles Manuels
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>Contrôles Manuels</B></FONT></TD></TR>\n',cs0,ftt);
for j = 1:size(TC,1)
        if (strcmp(wd,'Mon') | vierge) & j == 1
            TC{j,2} = ['<B>Pluviomètre OVSG:</B> Papier changé&nbsp;<INPUT type="checkbox"> ' TC{j,2}];
        end
        fprintf(fid,'<TR><TD %s style="%s"><B>%s</B></TD><TD align=right style="%s; white-space: nowrap;">%s&nbsp;&nbsp;',cl0,cs2,TC{j,1},cs1,TC{j,2});
        for i = 1:length(TC{j,3}(:,2))
            if TC{j,3}{i,1} <= 0
                fprintf(fid,'%s&nbsp;<INPUT type="checkbox"> ',TC{j,3}{i,2});
            end
            if TC{j,3}{i,1} < 0
                fprintf(fid,'%s&nbsp;',char('_'*ones(1,-2*TC{j,3}{i,1})));
            end
            if TC{j,3}{i,1} > 0
                fprintf(fid,' %s&nbsp;<INPUT type="text" size="%d">',TC{j,3}{i,2},TC{j,3}{i,1});
                %fprintf(fid,'%s&nbsp;%s&nbsp;',TC{j,3}{i,2},char('_'*ones(1,2*TC{j,3}{i,1})));
            end
        end
        fprintf(fid,'</FONT></TD></TR>\n');
end
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% PC d'acquisition
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD style="%s"><%s><B>État PC</B></TD>',cs0,ftt);
fprintf(fid,'<TD style="%s"><B>Acqui.</B></TD><TD style="%s"><B>Horloge</B></TD>',cs0,cs0);
fprintf(fid,'<TD %s style="%s">&nbsp;</TD><TD %s style="%s"><B>Heure&nbsp;Reset</TD>',cl4,cs3,cl5,cs1);
fprintf(fid,'<TD %s style="%s"><B>PC</B></TD>',cl0,cs2);
fprintf(fid,'<TD style="%s"><B>Acqui.</B></TD><TD style="%s"><B>Horloge</B></TD>',cs0,cs0);
fprintf(fid,'<TD %s style="%s">&nbsp;</TD><TD %s style="%s"><B>Heure&nbsp;Reset</TD>',cl4,cs3,cl5,cs1);
fprintf(fid,'<TD %s style="%s"><B>PC</B></TD>',cl0,cs2);
fprintf(fid,'<TD style="%s"><B>Acqui.</B></TD><TD style="%s"><B>Horloge</B></TD>',cs0,cs0);
fprintf(fid,'<TD %s style="%s">&nbsp;</TD><TD %s style="%s"><B>Heure&nbsp;Reset</TD>',cl4,cs3,cl5,cs1);
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
        seac = sprintf('<TD style="%s; %s">%s</TD><TD style="%s; %s">%s</TD>',cs0,bgcolor(se),cm1,cs0,bgcolor(se),cm2);
    else
        seac = sprintf('<TD colspan="2" style="%s; %s">%s</TD>',cs0,bgcolor(se),cm1);
    end
    if mod(i,3) == 1
        fprintf(fid,'<TR>');
    end
    fprintf(fid,'<TD %s style="%s; %s">',cl0,cs2,bgcolor(se));
    fprintf(fid,'%s</TD>',A.ac{i});
    fprintf(fid,'%s',seac);
    fprintf(fid,'<TD %s style="%s"><B>%s</B></TD>',cl4,cs3,se);
    fprintf(fid,'<TD %s style="%s">&nbsp;</TD>',cl5,cs1);
    if mod(i,3)==0
        fprintf(fid,'</TR>\n');
    end
    if mod(i,3) & i==length(A.pc)
        fprintf(fid,'<TD colspan="%d" style="%s">&nbsp;</TD></TR>\n',(mod(i,3)+1)*5,cs1);
    end
end
fprintf(fid,'<TR><TD colspan="2" align="left" style="%s"><B>Commentaires</B></TD>',cs2);
fprintf(fid,'<TD colspan="13" align="right" style="%s; white-space: nowrap;"><input type="text" size="80"> %s <INPUT type="checkbox"></TD></TR>\n',cs1,stacq);
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Etat des stations
nbes = 3;
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>État des stations</B></TD></TR>\n',cs0,ftt);
for i = 1:length(scode)
    kr = find(strcmp(cellstr(char(G.rcd)),scode{i}));
    S = readst(G(kr).cod,G(kr).obs);
    fprintf(fid,'<TR><TD align=CENTER style="%s; white-space: nowrap;">%s</TD><TD style="%s">',cs2,G(kr).nom,cs1);
    k = strmatch(lower([G(kr).obs,G(kr).cod]),E.ss);
    for ii = 1:length(k)
        if ~strcmp(E.st(k(ii)),'-')
            ks = find(strcmp(E.ss(k(ii)),lower(S.cod)));
            fprintf(fid,'<A href="/cgi-bin/afficheSTATION.pl?stationName=%s" style="text-decoration: none">%s</A>&nbsp;(%s) ',S.cod{ks},S.ali{ks},E.st{k(ii)});
        end
    end
    fprintf(fid,'&nbsp;</TD></TR>\n');
end
fprintf(fid,'<TR><TD align="left" style="%s"><B>&nbsp;Commentaires</B></TD>',cs2);
fprintf(fid,'<TD align="right" style="%s; white-space: nowrap;"><input type="text" size="80"> %s <INPUT type="checkbox"></TD></TR>\n',cs1,ststa);
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Dépouillement Sismologie
fprintf(fid,'<TABLE %s>\n',ctb);
fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>Dépouillement Sismologie</B></FONT></TD></TR>\n',cs0,ftt);
for j = 1:size(TD,1)
    fprintf(fid,'<TR><TD %s style="%s"><B>%s</B></TD><TD align=right style="%s"; white-space: nowrap;>%s',cl0,cs2,TD{j,1},cs1,TD{j,2});
    for i = 1:length(TD{j,3}(:,2))
        if TD{j,3}{i,1} <= 0
            fprintf(fid,' %s&nbsp;<INPUT type="checkbox">',TD{j,3}{i,2});
        end
        if TD{j,3}{i,1} < 0
            fprintf(fid,'%s&nbsp;&nbsp;',char('_'*ones(1,-2*TD{j,3}{i,1})));
        end
        if TD{j,3}{i,1} > 0
            %fprintf(fid,'%s&nbsp;%s&nbsp;&nbsp;',TD{j,3}{i,2},char('_'*ones(1,2*TD{j,3}{i,1})));
            fprintf(fid,' %s&nbsp;<INPUT type="text" size="%d">',TD{j,3}{i,2},TD{j,3}{i,1});
        end
    end
    fprintf(fid,'</FONT></TD></TR>\n');
end
fprintf(fid,'</TABLE><BR>\n');

% =======================================================================================
% Surveillance (astreinte)
if ~isempty(jf)
    fprintf(fid,'<TABLE %s>\n',ctb);
    fprintf(fid,'<TR><TD colspan="2" style="%s"><%s><B>Surveillance ASTREINTE</B></FONT></TD></TR>\n',cs0,ftt);
    for j = 1:size(TS,1)
        fprintf(fid,'<TR><TD %s style="%s"><B>%s%s</B></TD><TD align=right style="%s">%s',cl8,cs2,bk,TS{j,1},cs1,TS{j,2});
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
fprintf(fid,'<P align="center"><FONT size="1"><I>En cas de problème:</I> ');
fprintf(fid,'Jean-Bernard: <B>0690&nbsp;55&nbsp;46&nbsp;45</B>, ');
fprintf(fid,'Céline: <B>0690&nbsp;56&nbsp;68&nbsp;86</B>, ');
fprintf(fid,'Christian: <B>0690&nbsp;55&nbsp;46&nbsp;33</B>, ');
fprintf(fid,'Alexis: <B>0690&nbsp;12&nbsp;99&nbsp;42</B>, ');
fprintf(fid,'EDF: <B>0590&nbsp;81&nbsp;15&nbsp;47</B>, ');
fprintf(fid,'Internet UAG: <B>0590&nbsp;48&nbsp;32&nbsp;42</B>, ');
fprintf(fid,'France-Télécom (VPN Equant n°0008PWU9): <B>10&nbsp;15</B></FONT></P>');

fprintf(fid,'</FORM></BODY></HTML>\n');

fclose(fid);
unix(sprintf('cp -f %s %s',ftmp,fhtm));
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
