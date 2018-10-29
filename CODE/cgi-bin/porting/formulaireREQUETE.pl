#!/usr/bin/perl
#---------------------------------------------------------------
# WEBOBS: formulaireREQUETE.pl ------------------------------------
# ------
# Usage: This script allows to submit a graph/data request into
# the database.
# 
# Author: François Beauducel, IPGP
# Created: 2009-09-30
# Modified: 2009-10-21
#---------------------------------------------------------------

use strict;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use i18n;

# ----------------------------------------------------
# ---- External modules
use fonctions;
use readFile;
use readConf;
use readCfgFile;
use readGraph;

# ----------------------------------------------------
# ---- Configuration files
my %WEBOBS = readConfFile;
$ENV{TZ} = "America/Guadeloupe";
my $tz_old = $ENV{TZ};
$ENV{LANG} = $WEBOBS{LOCALE};

my $titrePage = "$WEBOBS{MKSPEC_TITLE}";
my $titre2 = "Formulaire de saisie";
my $fileDATA = "$WEBOBS{RACINE_DATA_DB}/$WEBOBS{MKSPEC_FILE_NAME}";
my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
my @graphKeys = sort(keys(%graphStr));
my @reseaux;
# --- search for graphical routines ("ext" key)
for (grep(/ext_/,@graphKeys)) {
	my $routine = substr($_,4);
	if ($graphStr{$_} =~ /xxx/) {	# if extension list contains "xxx" = the routine accepts time intervals as an argument
		push(@reseaux,$routine);
	}
}
my $sismohypMapsFile = "$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{MKSPEC_FILE_SISMOHYP}";
my @sismohypMaps = readCfgFile($sismohypMapsFile);
my @codeSeisme = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{SISMOHYP_CODES_FILE}");
my @typeSeisme;
for (@codeSeisme) {
	my @cle = split(/\|/,$_);
	push(@typeSeisme,$cle[5]);
}
my %seen = ();
@typeSeisme = grep { ! $seen{$_} ++ } @typeSeisme;

my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");
my @users = readUsers;

# --- Control of user validity
my $USER = $ENV{"REMOTE_USER"};
my $idUser = -1;
my $userTest = 1;
my $userLevel = -1;
my $userId;
my $nb = 0;
while ($nb <= $#users) {
	if ($USER ne "" && $USER eq $users[$nb][3] && $users[$nb][2] ge $WEBOBS{MKSPEC_LEVEL}) {
		$idUser = $nb;
		$userTest = 0;
		$userId = $users[$nb][0];
	}
	$nb++;
}
if ($userTest != 0) { die "WEBOBS: Sorry, this form is not allowed."; }
if ($idUser ge 0) { $userLevel = $users[$idUser][2]; }


# ---- Retrieve parameters (GET)
my $submitMode = 0;
my $jvs = "onLoad=\"selectMap()\"";
my @paramGET = $cgi->url_param();
if (grep(/submit/,@paramGET)) {
	$submitMode = 1;
	$titre2 = l2u("Confirmation de requête");
	$jvs = "";
}

# ---- Begin HTML display
print "Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<HTML><HEAD>\n
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
	
<!--DEBUT DU CODE ROLLOVER 2-->
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/JavaScripts/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->
	
<!-- Affichage des bulles d'aide -->
<DIV ID=\"helpBox\"></DIV>
<!-- to avoid press ENTER validates the form -->
<script type=\"text/javascript\">
function stopRKey(evt) {
	  var evt = (evt) ? evt : ((event) ? event : null);
	  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
	  if ((evt.keyCode == 13) && (node.type==\"text\"))  {return false;}
}
document.onkeypress = stopRKey;
</script>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" $jvs>\n";
	
print "<TABLE width=\"100%\"><TR><TD style=\"border:0\">
<H1>$titrePage</H1>\n<H2>$titre2</H2>
</TD><TD style=\"border:0;vertical-align:top;text-align:right\">Utilisateur identifié:<BR>";
if ($idUser gt -1) {
	print "<B>$users[$idUser][1]</B><BR><I>(niveau $userLevel)</I>";
} else {
	print "login: <B>$USER</B>";
}
print "</TD></TR></TABLE>";


# ================================================================
# ==== A. Submit mode: process the form
if ($submitMode) {

	# --- Retrieve parameters (POST)
	my $remUser = $ENV{REMOTE_USER};
	if ($remUser eq "") { $remUser = "UserUnknown"; }
	my $remHost = $ENV{REMOTE_HOST};
	my $httpHost = $ENV{HTTP_HOST};
	my @params = $cgi->param();
	my $paramList = join(" ",@params);
	my @routines = grep(/^routine_/,@params);
	my $entete = "";
	my $donnees = "";
	my $i =0;
	foreach my $champ (@params) {
		if ($champ ne "map") {
			$entete .= ($i ? "|":"").$champ;
			if ($champ eq "HTyp") {
				my @typ = $cgi->param($champ);
				$donnees .= ($i ? "|":"").join("+",@typ);
			} else {
				$donnees .= ($i ? "|":"").$cgi->param($champ);
			}
			$i++;
		}
	}
	$entete .= "|remHost|remUser";
	$donnees .= "|$remHost|$remUser";

	print "<P>Utilisateur: <B>$remUser</B></P>
		<P>Machine: <B>$remHost</B></P>\n";

	if ($userLevel > 4) {
		print "<TABLE><TR><TH>".join("</TH><TH>",split(/\|/,l2u($entete)))."</TH></TR>"
			."<TR><TD>".join("</TD><TD>",split(/\|/,l2u($donnees)))."</TD></TR></TABLE>";
	}

	# --- validates the selected routines
	if ($#routines >= 0) {
		# writes the new file
		open(FILE, ">>$fileDATA") || die "WEBOBS: cannot write on file $fileDATA !";
		print FILE "$entete\n";
		print FILE "$donnees\n";
		close(FILE);
		#print "<P>&Eacute;criture du fichier de donn&eacute;es: \"<B>$fileDATA</B>\".</P>\n";

		my @int = split(/\|/,$donnees);
		print "<P>Intervalle: <B>$int[0]-$int[1]-$int[2] $int[3]:$int[4]</B> &agrave; <B>$int[5]-$int[6]-$int[7] $int[8]:$int[9]</B>"
			.sprintf(" <I>(UTC %+d)</I></P>\n",$int[10]);
		
		@routines = grep(s/^routine_//g,@routines);
		print "<P>Routine(s) demand&eacute;e(s): <B>".join(", ",@routines)."</B></P>";
		print l2u("<P>Dans quelques minutes, vous recevrez un email à l'adresse <B>&lt;$users[$idUser][4]&gt;</B> avec un lien vers la page de vos résultats, qui resteront disponibles pendant <B>$WEBOBS{MKSPEC_OLD_DAYS} jour(s)</B>."),
		l2u(" En cas de problème, affichez la liste des requêtes ci-dessous.");
	} else {
		print l2u("<P>Aucune routine n'a été demandée.</P>");
	}

	# --- Adds a new preset map
	if ($paramList =~ /HNM/) {
		# appends the file
		open(FILE, ">>$sismohypMapsFile") || die "WEBOBS: cannot write on file $sismohypMapsFile !";
		print FILE "0|".$cgi->param("HTitre")."|".$cgi->param("Lon1")."|".$cgi->param("Lon2")."|".$cgi->param("Lat1")."|".$cgi->param("Lat2")."|".$cgi->param("HAz")."|".$cgi->param("HProf")."\n";
		close(FILE);
		print l2u("<P>Mise à jour du fichier <B>$sismohypMapsFile</B></P>\n");
	}	

	print "<HR><FORM action=\"input_button.htm\"><TABLE width=\"100%\"><TR>
		<TD style=\"border:0;text-align:center\"><input type=button name=lien value=\"Retour &agrave; WEBOBS\" onClick=\"document.location='/cgi-bin/presenteTEXTE.pl?file=DONNEES.html'\"></TD>";
	print "<TD style=\"border:0;text-align:center\"><input type=button name=lien value=\"Nouvelle requ&ecirc;te\" onClick=\"document.location='/cgi-bin/$WEBOBS{CGI_MKSPEC}'\"></TD>";
	print "<TD style=\"border:0;text-align:center\"><input type=button name=lien value=\"Affichage de la liste des requ&ecirc;tes\" onClick=\"document.location='/$WEBOBS{MKSPEC_RESULT_PATH_WEB}'\"></TD>
		</TR></TABLE>\n";

	    
}
# ================================================================
# ==== B. Edit mode: edit the form
else {

	my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
	my @graphKeys = keys(%graphStr);
	my @typeFormatDate = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{MKSPEC_FILE_DATE_FORMAT}");
	my @notes = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{MKSPEC_FILE_NOTES}");
	
	my @stations;
	my @codesListe;
	
	my $today = qx(date +\%Y-\%m-\%d);  chomp($today);
	my @listYears = ($WEBOBS{BIG_BANG}..substr($today,0,4));
	my @listMonths = ('01'..'12');
	my @listDays = ('01'..'31');
	my @listHours = ('00'..'23');
	my @listMinutes = ('00'..'59');
	
	# ---- Preset of form parameters (last complete month)
	my $selectedY2 = substr($today,0,4);
	my $selectedB2 = substr($today,5,2);
	my $selectedD2 = "01";
	my $lastMonth = qx(date -d '$selectedY2-$selectedB2-$selectedD2 1 month ago' +\%Y-\%m-\%d);  chomp($lastMonth);
	my $selectedY1 = substr($lastMonth,0,4);
	my $selectedB1 = substr($lastMonth,5,2);
	my $selectedD1 = "01";
	my $selectedPPI = $WEBOBS{MKGRAPH_VALUE_PPI};
	my $selectedMKS = $WEBOBS{MKGRAPH_VALUE_MKS};
	
	print "<script type=\"text/javascript\">
	<!--
	function verif_formulaire()
	{
		if (formulaire.HTitre.value == '') {
			alert('Veuillez entrer un titre pour la carte Hypocentres');
			return false;
		}

		if (formulaire.HCS.checked == true) {
			if (confirm('Vous avez choisi de modifier la carte specifique Hypocentres utilisee en routine. Etes-vous sur ?')) return true;
			else return false;
		}
	}
	
	function selectMap()
	{
		var i;
		var v;
		
		for (i=0;i<formulaire.map.length;i++) {
			v = formulaire.map[i].value.split('|');
			if (i == formulaire.mapNb.value) {
				formulaire.HTitre.value = v[1];
				formulaire.Lon1.value = v[2];
				formulaire.Lon2.value = v[3];
				formulaire.Lat1.value = v[4];
				formulaire.Lat2.value = v[5];
				formulaire.HAz.value = v[6];
				formulaire.HProf.value = v[7];
				if (v[0] == 0) {
					document.getElementById('HCS').style.visibility = 'visible';
				} else {
					document.getElementById('HCS').style.visibility = 'hidden';
				}
			}
		}
		calcRectangle();
		formulaire.HCS.checked = false;
		formulaire.HNM.checked = false;
		document.getElementById('HNM').style.visibility = 'hidden';
	}

	function selectHyp()
	{
		formulaire.routine_SISMOHYP.checked = true;
	}

	function changeMap()
	{
		formulaire.mapNb.value = '-1';
		calcRectangle();
		formulaire.HNM.checked = false;
		document.getElementById('HNM').style.visibility = 'visible';
		selectHyp();
	}

	function calcRectangle()
	{
		var kmLat = 6370*Math.PI/180;
		var kmLon = kmLat * Math.cos((formulaire.Lat2.value*0.5 + formulaire.Lat1.value*0.5)*Math.PI/180);
		
		kmLon *= (formulaire.Lon2.value - formulaire.Lon1.value);
		kmLat *= (formulaire.Lat2.value - formulaire.Lat1.value);
		formulaire.km.value = kmLon.toFixed(1) + ' x ' + kmLat.toFixed(1) + ' km';
	}
	//-->
	</script>";
	

	print "<FORM name=formulaire action=\"/cgi-bin/".basename($0)."?submit=\" method=post onSubmit=\"return verif_formulaire()\">";
	
	print "<HR><TABLE style=\"border:0\" onMouseOver=\"calc()\">
	<TR><TD style=\"border:0;vertical-align:top\" nowrap>";

	# --- Time interval
	print "<H3>Intervalle de temps</H3>
		<P align=right><B>Date d&eacute;but:</B> <SELECT name=\"Y1\" size=\"1\">\n";
	for (@listYears) { print "<OPTION value=\"$_\"".($selectedY1 eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT>\n<SELECT name=\"B1\" size=\"1\">\n";
	for (@listMonths) { print "<OPTION value=\"$_\"".($selectedB1 eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT>\n<SELECT name=\"D1\" size=\"1\">\n";
	for (@listDays) { print "<OPTION value=\"$_\"".($selectedD1 eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT> <B>Heure:</B> <SELECT name=\"H1\" size=\"1\">\n";
	for (@listHours) { print "<OPTION value=\"$_\">$_</OPTION>\n"; }
	print "</SELECT>\n<SELECT name=\"M1\" size=\"1\">\n";
	for (@listMinutes) { print "<OPTION value=\"$_\">$_</OPTION>\n"; }
	print "</SELECT><BR>\n";
	print "<B>Date fin:</B> <SELECT name=\"Y2\" size=\"1\">\n";
	for (@listYears) { print "<OPTION value=\"$_\"".($selectedY2 eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT>\n<SELECT name=\"B2\" size=\"1\">\n";
	for (@listMonths) { print "<OPTION value=\"$_\"".($selectedB2 eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT>\n<SELECT name=\"D2\" size=\"1\">\n";
	for (@listDays) { print "<OPTION value=\"$_\"".($selectedD2 eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT> <B>Heure:</B> <SELECT name=\"H2\" size=\"1\">\n";
	for (@listHours) { print "<OPTION value=\"$_\">$_</OPTION>\n"; }
	print "</SELECT>\n<SELECT name=\"M2\" size=\"1\">\n";
	for (@listMinutes) { print "<OPTION value=\"$_\">$_</OPTION>\n"; }
	print "</SELECT><BR>\n
		<INPUT name=\"TU\" type=\"radio\" value=\"-4\" checked> <B>Local</B> (UTC -4)
		<INPUT name=\"TU\" type=\"radio\" value=\"0\"> <B>UTC</B></P>\n";
	print "<H3>Options g&eacute;n&eacute;rales</h3>
		<P><B>Format date:</B> <SELECT name=\"FMT\" size=\"1\">\n";
	for (@typeFormatDate) {
		my ($cle,$val) = split(/\|/,$_);
		print "<OPTION value=\"$cle\">$val</OPTION>\n";
	}
	print "</SELECT></P>\n";
	
	# --- General options
	print "<P><B>R&eacute;solution des graphes =</B> <SELECT name=\"PPI\" size=\"1\">";
	for ("75","100","150","300","600") { print "<OPTION value=\"$_\"".($selectedPPI eq $_ ? " selected":"").">$_</OPTION>\n"; }
	print "</SELECT> pixels par pouce (ppi)</P>\n";
	print "<P><B>Taille des points =</B> <SELECT name=\"MKS\" size=\"1\">\n";
	for ("1","2","4") {
		print "<OPTION value=\"$_\"".($selectedMKS eq $_ ? " selected":"").">$_</OPTION>\n";
	}
	print "</SELECT> pixel(s)</P>\n";
	print "<P><B>Dur&eacute;e des cumuls =</B> <INPUT type=\"text\" name=\"CUM\" size=\"5\" value=\"1\"> jour(s)</P>\n";
	print "<P><B>D&eacute;cimation des donn&eacute;es =</B> 1/ <INPUT type=\"text\" name=\"DEC\" size=\"5\" value=\"1\"></P>\n";
	print "<P><INPUT type=\"checkbox\" name=\"EPS\" value=\"1\"> Ajouter des graphes PostScript</P>\n";
	print "<P><INPUT type=\"checkbox\" name=\"EXP\" value=\"1\" checked> Cr&eacute;er un fichier de donn&eacute;es ASCII (en b&ecirc;ta)</P>\n";

	print "</TD>";
	
	# --- Routine list
	print "<TD style=\"border:0\"><BLOCKQUOTE style=\"padding-left:50px\"
		<H3>Routines</H3>\n";

	for (@reseaux) {
		my $cle = "nom_$_";
		my $txt = "<INPUT type=\"checkbox\" name=\"routine_$_\" title=\"$_\" value=\"1\"> <B>$graphStr{$cle}</B> ($_)<BR>\n";
		if ($_ eq "SISMOHYP") {
			print "<P style=\"border:1px solid #999999;\">$txt";
			print "<TABLE id=\"SISMOHYP\"><TR><TD style=\"border:0;vertical-align:top\"><P style=\"padding-left:20px\">";
			for (reverse(sort(@typeSeisme))) {
				my $ts = $_;
				print "$ts:";
				for (@codeSeisme) {
					my @cle = split(/\|/,$_);
					if ($cle[5] eq $ts) {
						my $cd = $cle[0];
						print " <INPUT type=\"checkbox\" name=\"HTyp\" value=\"$cd\"".($cle[4] ? " checked":"")
						 ." onMouseOut=\"nd()\" onMouseOver=\"overlib('$cd: $cle[1]')\">&nbsp;<B>$cd</B>&nbsp;&nbsp;\n";
					}
				}
				print "<BR>";
			}
			print "<BR><INPUT type=\"text\" name=\"HMmax\" size=\"3\" value=\"9\" onChange=\"selectHyp()\"> &ge; <B>Magnitude</B>
			 &ge; <INPUT type=\"text\" name=\"HMmin\" size=\"3\" value=\"0.1\" onChange=\"selectHyp()\"><BR>
			 <INPUT type=\"text\" name=\"HPmax\" size=\"3\" value=\"200\" onChange=\"selectHyp()\"> &ge; <B>Prodondeur</B>
			 &ge; <INPUT type=\"text\" name=\"HPmin\" size=\"3\" value=\"-2\" onChange=\"selectHyp()\"> <B>km</B><BR>
			 <B>Intensit&eacute; MSK</B> &ge; <SELECT name=\"MSK\" size=\"1\" onChange=\"selectHyp()\">\n";
			for ("1".."10") {
				print "<OPTION value=\"$_\">".romain($_)."</OPTION>\n";
			}
			print "</SELECT></P>
			 <TABLE width=\"100%\"><TR><TD style=\"border:0\"><INPUT type=\"checkbox\" name=\"HFiltre\" value=\"1\" checked onChange=\"selectHyp()\"> <B>Appliquer les filtres qualit&eacute;</B>:</TD><TD nowrap>
			 <B>Classe QM &ge; <SELECT name=\"HQM\" size=\"1\" onChange=\"selectHyp()\">\n";
			for ("D","C","B","A") {
				print "<OPTION value=\"$_\">$_</OPTION>\n";
			}
			print "</SELECT><BR>
			 <B>Gap</B> &lt; <INPUT type=\"text\" name=\"HGap\" size=\"3\" value=\"360\" onChange=\"selectHyp()\"> &deg;&nbsp;&nbsp;
			 <B>RMS</B> &lt; <INPUT type=\"text\" name=\"HRMS\" size=\"3\" value=\"0.5\" onChange=\"selectHyp()\"> s<BR>
			 <B>ERH</B> &lt; <INPUT type=\"text\" name=\"HErh\" size=\"3\" value=\"100\" onChange=\"selectHyp()\"> km&nbsp;&nbsp;
			 <B>ERZ</B> &lt; <INPUT type=\"text\" name=\"HErz\" size=\"3\" value=\"100\" onChange=\"selectHyp()\"> km
			 </TD></TR></TABLE>
			 <INPUT type=\"checkbox\" name=\"HAnciens\" value=\"1\" checked onChange=\"selectHyp()\"> <B>Afficher en arri&egrave;re plan tous les s&eacute;ismes connus</B>
			 </TD><TD style=\"border:0;vertical-align:top;text-align:right\" nowrap>
			 Cartes pr&eacute;d&eacute;finies: <SELECT name=\"mapNb\" size=\"1\" onChange=\"selectMap()\">\n";
			my $i = -1;
			for (("|- nouvelle carte -"),@sismohypMaps) {
				my @cle = split(/\|/,$_);
				print "<OPTION value=\"$i\"".($cle[0] ne "0" ? " selected":"").">$cle[1]</OPTION>\n";
				$i++;
			}
			print "</SELECT>\n";
			for (@sismohypMaps) {
				print "<INPUT type=\"hidden\" name=\"map\" value=\"$_\">\n";
			}
			print "<P align=\"right\">
			 <B>Titre:</B> <INPUT type=\"text\" name=\"HTitre\" size=\"30\" onKeyUp=\"changeMap()\"><BR>
			 <B>Longitude Ouest</B> = <INPUT type=\"text\" name=\"Lon1\" size=\"6\" onKeyUp=\"changeMap()\">&deg;
			 <B>Latitude Nord</B> = <INPUT type=\"text\" name=\"Lat2\" size=\"6\" onKeyUp=\"changeMap()\">&deg;<BR>
			 <B>Longitude Est</B> = <INPUT type=\"text\" name=\"Lon2\" size=\"6\" onKeyUp=\"changeMap()\">&deg;
			 <B>Latitude Sud</B> = <INPUT type=\"text\" name=\"Lat1\" size=\"6\" onKeyUp=\"changeMap()\">&deg;<BR>
			 Rectangle (E-W x N-S) = <INPUT type=\"text\" readonly name=\"km\" size=\"15\" style=\"border:0;background-color:#E0E0E0\"></P>
			 <P align=\"right\">Projection verticale: <B>Azimuth</B> = <INPUT type=\"text\" name=\"HAz\" size=\"3\"> &deg;N<BR>
			 <B>Prof. max.</B> = <INPUT type=\"text\" name=\"HProf\" size=\"3\"> km</P>
			 <P><DIV id=\"HNM\" style=\"visibility:hidden\"><INPUT type=\"checkbox\" name=\"HNM\"> Ajouter cette carte &agrave; la liste<BR></DIV>
			 <DIV id=\"HCS\" style=\"visibility:hidden\"><INPUT type=\"checkbox\" name=\"HCS\"> Utiliser cette carte en routine (non fonctionnel)</DIV</P>
			 </TD></TR></TABLE></P>\n";
		} else {
			print $txt;
		}
	}
	print "</BLOCKQUOTE></TD></TR><TR><TD style=\"border:0\" colspan=\"2\">";

	print "<P style=\"margin-top:20px;text-align:center\">
		<input type=\"submit\" value=\"Soumettre\">
		</P></FORM>";
	print "</TD></TR></TABLE>";
	
	# --- Notes
	print "<HR><BLOCKQUOTE style=\"background-color:white;margin:0px;padding:10px\"><A name=\"notes\"></A>";
	print txt2htm(l2u(join("",@notes)));
	print "</BLOCKQUOTE>\n";
}


# --- End of the HTML page
print "<BR>\n@signature\n</BODY>\n</HTML>\n";

