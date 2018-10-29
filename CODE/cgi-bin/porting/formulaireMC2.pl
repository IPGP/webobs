#!/usr/bin/perl

#  file 
#  MCfmt=MC2 : */*/YYyyMMDD?HHmmSS?eee
#  MCfmt=MC  : */YYyyMMDD/??HHmmSS?eee
#
#  image:
#  yyMMDDHHmmSS.png
#
#  MC file:
#  $WEBOBS{MC_PATH_FILES}//MCYYyyMM.txt
#

use strict;
use warnings;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Suds;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
 
# ---- client authorization checking
if ( ! clientHasEdit(type=>"authprocs",name=>"MC")) { die "$__{'Not authorized'} (edit) for MC/MC2" }
my $aff_user = $CLIENT;

# ---- inits ----------------------------------
#
my @stations=("");
my @typeEvnt=("");
my $fileGS = $cgi->url_param('f');
my $id_evt = $cgi->url_param('id_evt');
my $MCfmt  = $cgi->url_param('mcfmt');    # MC or MC2

my $fileNameGS   = basename $fileGS;
my $pathGS       = dirname $fileGS;
my $dirGS        = basename $pathGS;
my $annee4GS =my $annee2GS = my $moisGS = my $jourGS = my $heureGS = my $minuteGS = my $secondeGS = my $extensionGS = '';
if ($MCfmt eq "MC2") {
	my $annee4GS    = substr($fileNameGS,0,4);
	my $annee2GS    = substr($fileNameGS,2,2);
	my $moisGS      = substr($fileNameGS,4,2);
	my $jourGS      = substr($fileNameGS,6,2);
	my $heureGS     = substr($fileNameGS,9,2);
	my $minuteGS    = substr($fileNameGS,11,2);
	my $secondeGS   = substr($fileNameGS,13,2);
	my $extensionGS = substr($fileNameGS,16,3);
}
if ($MCfmt eq "MC") {
	my $annee4GS    = substr($dirGS,0,4);
	my $annee2GS    = substr($dirGS,2,2);
	my $moisGS      = substr($dirGS,4,2);
	my $jourGS      = substr($dirGS,6,2);
	my $heureGS     = substr($fileNameGS,2,2);
	my $minuteGS    = substr($fileNameGS,4,2);
	my $secondeGS   = substr($fileNameGS,6,2);
	my $extensionGS = substr($fileNameGS,9,3);
}
my $imageGS = $annee2GS.$moisGS.$jourGS.$heureGS.$minuteGS.$secondeGS.".png";
my $fileMC="/MC".$annee4GS.$moisGS.".txt";

# ---- read requested event record from MC file
#
my ($id_evt,$date,$heure_evt,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$nb_fichiers,$png,$operateur,$comment) = split(/\|/,l2u(qx(awk -F'|' '\$1 == $id_evt {printf "\%s",\$0}' $WEBOBS{MC_PATH_FILES}/$fileMC)));
my ($annee4,$mois,$jour) = split(/-/,$date);
my ($heure,$minute,$seconde) = split(/:/,$heure_evt);
my $date_evt = "$date $heure:$minute";

# ---- generates 3 date/time: this filename date and next 2 minutes
#
my @datesValides;
for (0..2) {
	my $dd = qx(date +"%Y-%m-%d %H:%M" -d "$annee4GS-$moisGS-$jourGS $heureGS:$minuteGS $_ minutes");
	chomp($dd);
	push(@datesValides,$dd);
}

# ---- read additional config files 
#
my $fileStations = "";
if (MCfmt eq "MC")  { $fileStations=$WEBOBS{SEFRAN_FILE_VOIES} }
if (MCfmt eq "MC2") { $fileStations=$WEBOBS{SEFRAN2_FILE_VOIES} }
open(FILE, "<$fileStations") || die "fileStations $__{'not found'}";
while(<FILE>) { push(@stations,$_); }
close(FILE);
@stations = grep(!/^#/, @stations);

my $fileEvnt=$WEBOBS{MC_FILE_CODES_SEISMES};
open(FILE, "<$fileEvnt") || die "$fileEvnt $__{'not found'}";
while(<FILE>) { push(@typeEvnt,l2u($_)); }
close(FILE);
@typeEvnt = grep(!/^#/, @typeEvnt);
@typeEvnt = grep(!/^$/, @typeEvnt);


# ---- start HTML page
#
print <<"FIN";
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Formulaire de saisie MAIN COURANTE</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_CSS}">
<script type="text/javascript">
function maj_formulaire()
{
	couleurs = new Array();
	couleurs[true] = "#ccffcc";
	couleurs[false] = "#ffcccc";
	document.formulaire.nomOperateur.style.backgroundColor = couleurs[(document.formulaire.nomOperateur.value != "")];
	document.formulaire.nombreEvenement.style.backgroundColor = couleurs[(document.formulaire.nombreEvenement.value != "" && ! isNaN(document.formulaire.nombreEvenement.value) && document.formulaire.nombreEvenement.value != 0)];
	document.formulaire.dateEvenement.style.backgroundColor = couleurs[(document.formulaire.dateEvenement.value != "")];
	document.formulaire.secondeEvenement.style.backgroundColor = couleurs[(document.formulaire.secondeEvenement.value != "")];
	document.formulaire.nombreFichiers.style.backgroundColor = couleurs[(document.formulaire.nombreFichiers.value != "")];
	document.formulaire.dureeEvenement.style.backgroundColor = couleurs[(document.formulaire.dureeEvenement.value != "" && ! isNaN(document.formulaire.dureeEvenement.value) && document.formulaire.dureeEvenement.value != 0)];
	document.formulaire.stationEvenement.style.backgroundColor = couleurs[(document.formulaire.stationEvenement.value != "")];
	document.formulaire.amplitudeEvenement.style.backgroundColor = couleurs[(document.formulaire.amplitudeEvenement.value != "")];
	document.formulaire.saturationEvenement.style.backgroundColor = couleurs[(
		( document.formulaire.amplitudeEvenement.value != "Sature" && ( document.formulaire.saturationEvenement.value == 0 || document.formulaire.saturationEvenement.value == ""))
		||
		( document.formulaire.amplitudeEvenement.value == "Sature" && document.formulaire.saturationEvenement.value > 0 )
	)];
	document.formulaire.smoinsp.style.backgroundColor = couleurs[!isNaN(document.formulaire.smoinsp.value)];
	document.getElementById("distance").innerHTML = (document.formulaire.smoinsp.value!="" && !isNaN(document.formulaire.smoinsp.value)) ? " = "+(document.formulaire.smoinsp.value*8)+" km" : "";
	if (document.formulaire.smoinsp.value!="" && !isNaN(document.formulaire.smoinsp.value) && document.formulaire.dureeEvenement.value!="" && !isNaN(document.formulaire.dureeEvenement.value)) {
		switch(document.formulaire.uniteEvenement.value) {
			case "s" : duree = document.formulaire.dureeEvenement.value; break;
			case "min" : duree = document.formulaire.dureeEvenement.value*60; break;
			case "h" : duree = document.formulaire.dureeEvenement.value*3600; break;
		}
		distance=document.formulaire.smoinsp.value*8;
		magnitude=2*Math.log(duree)/Math.log(10)+0.0035*distance-0.87;
		mag=Math.round(10*magnitude)/10;
		pga=Math.round(Math.pow( 10,0.611377 * magnitude -0.00584334 * distance - Math.log(distance)/Math.log(10) - .216674 ) * 3);
	} else {
		mag = 0;
	}
	document.getElementById("mag").innerHTML = (mag>0) ? ", Md="+mag+", PGA="+pga+"mg": "";
	document.formulaire.typeEvenement.style.backgroundColor = couleurs[(document.formulaire.typeEvenement.value != "INCONNU" && (document.formulaire.typeEvenement.value == "TELE" || document.formulaire.smoinsp.value < 60))];
	document.getElementById("tele").style.backgroundColor = couleurs[(document.formulaire.smoinsp.value == "" || document.formulaire.typeEvenement.value == "TELE" || document.formulaire.smoinsp.value < 60)];
	document.getElementById("tele").innerHTML = (document.formulaire.smoinsp.value == "" || document.formulaire.typeEvenement.value == "TELE" || document.formulaire.smoinsp.value < 60) ? "" : "(S-P > 60s = Téléséisme)";
}
function verif_formulaire()
{
	if(document.formulaire.nomOperateur.value == "") {
		alert("Veuillez entrer le nom de l'opérateur!");
		document.formulaire.nomOperateur.focus();
		return false;
	}
	if(document.formulaire.nombreEvenement.value == "" || isNaN(document.formulaire.nombreEvenement.value)) {
		alert("Veuillez entrer le nombre d'événements");
		document.formulaire.nombreEvenement.focus();
		return false;
	}
	if(document.formulaire.nombreEvenement.value == 0) {
		alert("Nombre d'événements incorrect"); 
		document.formulaire.nombreEvenement.focus(); 
		return false; 
	}
	if (document.formulaire.dateEvenement.value == "") {
		alert("Sélectionner la date et l'heure de cet événement  ");
		document.formulaire.dateEvenement.focus();
		return false;
	}
	if (document.formulaire.secondeEvenement.value == "") { 
		alert("Indiquer la seconde de cet événement  "); 
		document.formulaire.secondeEvenement.focus(); 
		return false;
	}
	if (document.formulaire.nombreFichiers.value == "") {
		alert("Veuillez choisir le nombre de fichier SUDS à transférer!");
		document.formulaire.nombreFichiers.focus();
		return false;
	}
	if (document.formulaire.nombreFichiers.value == 0) { 
		if ( confirm("Aucun fichier SUDS ne sera transféré. Merci de confirmer en cliquant sur OK ou de cliquer sur Annuler pour corriger.") )  {
			return true;
		} else { 
			document.formulaire.nombreFichiers.focus();
			return false;
		}
	}
	if(document.formulaire.dureeEvenement.value == "" || isNaN(document.formulaire.dureeEvenement.value)) {
		alert("Veuillez entrer la durée de l'événement!");
		document.formulaire.dureeEvenement.focus();
		return false;
	}
	if(document.formulaire.stationEvenement.value == "") {
		alert("Veuillez entrer la station de première arrivée!");
		document.formulaire.stationEvenement.focus();
		return false;
	}
	if(document.formulaire.amplitudeEvenement.value == "") {
		alert("Veuillez choisir une amplitude pour cet événement!");
		document.formulaire.stationEvenement.focus();
		return false; 
	}
	if(document.formulaire.saturationEvenement.value == "" || isNaN(document.formulaire.saturationEvenement.value)) {
		alert("Veuillez entrer la durée de saturation de l'événement!");
		document.formulaire.saturationEvenement.focus();
		return false;
	}
	if(document.formulaire.saturationEvenement.value < 0)  {
		alert("Veuillez entrer une durée de saturation nulle ou positive!");
		document.formulaire.saturationEvenement.focus();
		return false;
	}
	if(document.formulaire.saturationEvenement.value == 0 && document.formulaire.amplitudeEvenement.value == "Sature") {
		alert("Veuillez entrer la durée de saturation de l'événement!");
		document.formulaire.saturationEvenement.focus(); 
		return false;
	}
	if(document.formulaire.saturationEvenement.value > 0 && document.formulaire.amplitudeEvenement.value != "Sature") {
		alert("L'événement n'est pas indique comme saturé!");
		document.formulaire.saturationEvenement.focus(); 
		return false; 
	}
	if(document.formulaire.saturationEvenement.value > 10 && document.formulaire.typeEvenement.value == "Volcan")  { 
		alert("Séisme volcanique potentiellement ressenti!");
		document.formulaire.saturationEvenement.focus(); 
		return true; 
	}
	if(document.formulaire.saturationEvenement.value > 30 && document.formulaire.typeEvenement.value == "Tectonique")  { 
		alert("Seisme Tectonique potentiellement ressenti!");
		document.formulaire.saturationEvenement.focus();
		return true;
	}
	if (isNaN(document.formulaire.smoinsp.value)) { 
		alert("Veuillez entrer une valeur pour S-P!");
		document.formulaire.smoinsp.focus();
		return false;
	}
}
window.captureEvents(Event.KEYUP);
window.captureEvents(Event.CHANGE);
window.onkeyup = maj_formulaire;
window.onchange = maj_formulaire;
</script>

</head>
<body onLoad="maj_formulaire()">
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="javascript" src="/JavaScripts/overlib.js" type="text/javascript"></script>
<DIV ID="helpBox"></DIV>
<h2 align="center">Saisie Main Courante Sismologie</h2>
<!-- Utilisateur identifié : $aff_user -->
<form name="formulaire" action="/cgi-bin/traitementMC2.pl" method="post" onSubmit="return verif_formulaire()">
FIN

my @imagesSuds; my @fichiersSuds;
if (MCfmt eq "MC")  { @imagesSuds = imagesSudsMC("$pathGS/$fileNameGS") }
if (MCfmt eq "MC2") { @imagesSuds = imagesSuds2MC("$pathGS/$fileNameGS") }
my $imageMC = shift @imagesSuds;
if (MCfmt eq "MC")   { @fichiersSuds = fichiersSuds(@imagesSuds) }
if (MCfmt eq "MC2")  { @fichiersSuds = fichiersSuds2(@imagesSuds) }
my @tmp;
for ( @fichiersSuds ) {
	if (MCfmt eq "MC2") {
		if ($_ =~ "gwa") {
			push(@tmp,('$13=="'.basename($_).'"'));
			$_ =~ s/\.gwa/\.gl0/;
		} elsif ($_ =~ "mar") {
			$_ =~ s/\.mar/\.mq0/;
		}
	}
	push(@tmp,('$13=="'.basename($_).'"'));
}
my $critere = join(" || ",@tmp);

my @listeSeismes = split(/\n/,qx(awk -F'|' '$critere {print}' $WEBOBS{MC_PATH_FILES}/$fileMC|sort));
if (@listeSeismes) {
	print "<div style=\"border: 3px solid red;background: white; margin: 0.5em; padding: 0.5em;\">
	<h2 style=\"color: red;\">Attention !</h2>
	<p><b>S&eacute;ismes identifi&eacute;s dans les fichiers affich&eacute;s</b> :</p>
	<dl>";
	my $id_fichier = 0;
	for ( @fichiersSuds ) {
		my $fichier = basename($_);
		$id_fichier++;
		my $nb_seismes_fichier = 0;
		for (@listeSeismes) {
			my ($tmp_id_evt,$tmp_date,$tmp_heure,$tmp_type,$tmp_amplitude,$tmp_duree,$tmp_unite,$tmp_duree_sat,$tmp_nombre,$tmp_s_moins_p,$tmp_station,$tmp_arrivee,$tmp_suds,$tmp_nb_fichiers,$tmp_png,$tmp_operateur,$tmp_comment) = split(/\|/,l2u($_));
			if ($tmp_suds eq $fichier) {
				if ($nb_seismes_fichier++ eq 0) {
					print "<dt>Fichier n°<b>$id_fichier</b> : <b>$fichier</b></dt>";
				}
				my $style;
				my $modif;
				if ($tmp_id_evt eq $id_evt) {
					$style = " style=\"border: 2px dotted blue; padding: 0.5em;\"";
					$modif = "<span style=\"color: blue;\">Sélectionné pour modification</span> : <br>";
				}
				print "<dd$style>$modif<b>$tmp_heure</b> : Type <b>$tmp_type</b>, première arrivée sur <b>$tmp_station</b>, «<em>$tmp_comment</em>», par <b>$nomsOper{$tmp_operateur}</b></dd>";
			}
		}
	}
	print "</dl></div>";
}
print "<p><input type=\"hidden\" name=\"fileNameGS\" value=\"$fileNameGS\"></p>";

# Operators list/input
print "<P>$__{'Operator'}: <SELECT onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'your name'}')\" name=\"nomOperateur\" size=\"1\">";
for (keys(%USERS)) {
	my $sel = "";
	if ( $USERS{$_}{UID} == $USERS{$CLIENT}{UID} ) { $sel=" selected " }
	print "<option $sel value=$USERS{$_}{UID}>$USERS{$_}{FULLNAME}</option>";
}
print "</SELECT></P>";
#
#
# Event date

print "\n<p>Date, heure, minute: \n";
print "\n<select name=\"dateEvenement\" size=\"1\">\n";
for ("",@datesValides) {
	if (($id_evt and $_ eq $date_evt) or ($_ eq $date_evt)) {
		print "<option selected value = \"$_\">$_</option>\n"; 
	} else {
		print "<option value = \"$_\">$_</option>\n";
	}
}
print "</select>\n";

my @liste_sec=("","00","05","10","15","20","25","30","35","40","45","50","55");
print "\nSecondes: <select name=\"secondeEvenement\" size=\"1\">\n";
for (@liste_sec) {
	print "<option".($id_evt and $_ == $seconde ? " selected":"")." value=\"$_\">$_</option>\n";
}
print "</select></p>\n";

# - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Genere la liste des stations
# - - - - - - - - - - - - - - - - - - - - - - - - -
print "<p>Station de Première Arrivée: <select name=\"stationEvenement\" size=\"1\">";
for (@stations) {
  my ($code, $gain) =split(/\t/,$_);
  if ($code eq $station ) {
	  print "<option selected value=\"$code\">$code</option>";
  } else {
	  print "<option value=$code>$code</option>";
  }
}
print "</select>";
my $arriveeUnique = 0;
if ($id_evt) {
	$arriveeUnique = $arrivee;
}

print "<input type=\"radio\" name=\"arriveeUnique\" value=\"1\"".($arriveeUnique ? " checked" : "").">Arrivée Unique";
print "<input type=\"radio\" name=\"arriveeUnique\" value=\"0\"".($arriveeUnique ? "" : " checked").">Arrivée Multiple<br>";
print "</select></p>";
# - - - - - - - - - - - - - - - - - - - - - - - - -


my $commentaireAmplitude=htmlspecialchars("Définitions (ces amplitude sont lues sur le signal et pas sur le sefran): <hr>Faible: Evenement faible (signal < 500)<br>Moyenne: Evenement a la limite de saturation du sefran (500 < signal < 1000)<br>Forte: Evenement engendrant une saturation du sefran mais pas du signal physique (1000 < signal < 2000)<br>Sature: Au moins une station est saturée (2000 < signal)<br>");

# Genere le formulaire "Nombre de fichiers"
# - - - - - - - - - - - - - - - - - - - - - - - - -
my %lis_nb_fichiers = (
	"0 " => "&nbsp;",
	"1 1" => "1",
	"2 2" => "2",
	"3 3" => "3",
	"4 4" => "4",
	"5 5" => "5",
	"6 6" => "6",
	"7 7" => "7",
	"8 8" => "8",
	"9 9" => "9",
	"A 10" => "10",
	"B -1" => "Tous",
	"C 0" => "0"
);
my %lis_unites = (
	"1 s" => "Secondes",
	"2 min" => "Minutes",
	"3 h" => "Heures"
);
my %lis_amplitudes = (
	"0 " => "&nbsp;",
	"1 Faible" => "Faible",
	"2 Moyenne" => "Moyenne",
	"3 Forte" => "Forte",
	"4 Sature" => "Saturé"
);
 
print <<"FIN";
 Nombre de Fichiers <select onMouseOut="nd()" onmouseover="overlib('Nombre de fichiers SUDS a transferer')" name="nombreFichiers" size="1">
FIN
foreach (sort(keys(%lis_nb_fichiers))) {
	my $val = $lis_nb_fichiers{$_};
	$_ = substr($_,2);
	my $sel = ($id_evt ? ($nb_fichiers eq $_ ? " selected" : "") : ($_ eq "" ? " selected" : ""));
	print "<option value=\"$_\"$sel>$val</option>\n";
}
my $nb_evt = ($id_evt ? $nombre : 1);
my $duree_evt = ($id_evt ? $duree : "");
my $unite_evt = ($id_evt ? $unite : "s");
my $s_moins_p_evt = ($id_evt ? $s_moins_p : "");
$s_moins_p_evt =~ s/^NA$//;
my $duree_sat_evt = ($id_evt ? $duree_sat : 0);
my $comment_evt = ($id_evt ? htmlspecialchars($comment) : "");
print <<"FIN";
</select>
 Nombre d'Evénements: <input onMouseOut="nd()" onmouseover="overlib('Entrez une valeur numérique')" size="5" value = "$nb_evt" name="nombreEvenement">
</P>


<p>Durée de l'Evénement : <input  onMouseOut="nd()" onmouseover="overlib('Entrez la durée mesurée sur le SEFRAN - NE PAS OUBLIER LES UNITES')" name="dureeEvenement" size="5" value="$duree">
<select name="uniteEvenement" size="1">
FIN
foreach (sort(keys(%lis_unites))) {
	my $val = $lis_unites{$_};
	$_ = substr($_,2);
	my $sel = ($id_evt ? ($unite eq $_ ? " selected" : "") : ($_ eq "s" ? " selected" : ""));
	print "<option value=\"$_\"$sel>$val</option>\n";
}
print <<"FIN";
</select></p>

<P>S-P (<I>Secondes</I>): <input size="5" value="$s_moins_p_evt" name="smoinsp"><span id="distance" onMouseOut="nd()" onmouseover="overlib('Distance selon le S-P indiqué.')"></span><span id="mag" onMouseOut="nd()" onmouseover="overlib('&lt;b&gt;Estimations : &lt;/b&gt;&lt;ol&gt;&lt;li&gt;Magnitude de durée selon la durée et la distance.&lt;/li&gt;&lt;li&gt;PGA selon magnitude, distance et B-Cube.&lt;/li&gt;&lt;/ol&gt; &lt;b&gt;Attention !&lt;/b&gt; Ce PGA correspond à la station où le S-P est mesuré, qui ne correspond pas forcément à la zone habitée la plus proche.')"></span> <span id="tele"></span></P>

<p>Amplitude de l'Evénement : <select onMouseOut="nd()" onmouseover="overlib('$commentaireAmplitude')" name="amplitudeEvenement" size="1">
FIN
foreach (sort(keys(%lis_amplitudes))) {
	my $val = $lis_amplitudes{$_};
	$_ = substr($_,2);
	my $sel = ($id_evt ? ($amplitude eq $_ ? " selected" : "") : ($_ eq "" ? " selected" : ""));
	print "<option value=\"$_\"$sel>$val</option>\n";
}
print <<"FIN";
</select>

Durée de Saturation (<I>Secondes</I>) (0 = Non Saturé): <input size="5" value="$duree_sat_evt" name="saturationEvenement">

FIN

# Genere la liste des types d'evenements
# - - - - - - - - - - - - - - - - - - - - - - - - -
# my $comm = htmlspecialchars("Consulter <a href=\"$WEBOBS{MC_USGS_URL}\" target=blank><b>USGS</b></a>");
# print "<p>Type de l\'Evénement: <select onMouseOut=\"nd()\" onmouseover=\"overlib('$comm', MOUSEOFF, WRAP, STICKY)\" name=\"typeEvenement\" size=\"1\">";
print "<p>Type de l\'Evénement: <select name=\"typeEvenement\" size=\"1\">";
for (@typeEvnt) {
	my ($cle,$val)=split(/\|/,$_);
	my $sel = ($id_evt ? ($type eq $cle ? " selected" : "") : "");
	print "<option value=\"$cle\"$sel>$val</option>";
}
print "</select> Consulter <a href=\"$WEBOBS{MC_USGS_URL}\" target=blank><b>USGS</b></a></p>";

print <<"FIN";
<p>Commentaire : <input size="100" name="commentEvenement" value="$comment_evt"></p>

FIN

if ($id_evt) {
	print "<p><input type="checkbox" name="transfert" value="1">Transfert des signaux</p>";
	print "<p><input type="checkbox" name="impression" value="1">Impression du signal</p>";
	if ($MCfmt eq "MC2" ) {
		print "<p><input type="checkbox" name="forcageRapportB3" value="1">Création rapport B3</p>";
	}
} else {
	print <<"FIN";
	<input type="hidden" name="transfert" value="1">
	<input type="hidden" name="impression" value="1">
FIN
}

# - - - - - - - - - - - - - - - - - - - - - - - - -

print "<input type=\"hidden\" name=\"pathGS\" value=\"$pathGS\">";
print "<input type=\"hidden\" name=\"fileMC\" value=\"$fileMC\">";
print "<input type=\"hidden\" name=\"imageGS\" value=\"$imageGS\">";
print "<input type=\"hidden\" name=\"id_evt\" value=\"$id_evt\">";


print "<p><input type=\"submit\" value=\"Soumettre\"><input type=\"reset\" value=\"Effacer\"></p>
</form>
</td></tr></table>
<script type=\"text/javascript\">
<!--
document.write(\"Dernière mise à jour: \" + document.lastModified);
//-->
</script>
</font>
</body>
</html>";

