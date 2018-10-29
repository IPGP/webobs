#!/usr/bin/perl

use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use Data::Dumper;
use Webobs;
use i18n;

# ----------------------------------------------------
# ---------- Module de configuration  ----------------
# ----------------------------------------------------
use readConf;
my %WEBOBS=readConfFile;
my @oper = readUsers;
# ----------------------------------------------------

my @stations=("");
my @typeEvnt=("");
my $fileGU = $cgi->url_param('f');
my $id_evt = $cgi->url_param('id_evt');

#  file :
#  */YYyyMMDD/??HHmmSS?eee
#
#  image:
#  yyMMDDHHmmSS.png
#
#  MC file:
#  $WEBOBS{MC_RACINE}/$WEBOBS{MC_PATH_FILES}//MCYYyyMM.txt
#

my $fileNameGU  = basename $fileGU;
my $pathGU      = dirname $fileGU;
my $dirGU       = basename $pathGU;

my $annee4GU    = substr($dirGU,0,4);
my $annee2GU    = substr($dirGU,2,2);
my $moisGU      = substr($dirGU,4,2);
my $jourGU      = substr($dirGU,6,2);
my $heureGU     = substr($fileNameGU,2,2);
my $minuteGU    = substr($fileNameGU,4,2);
my $secondeGU   = substr($fileNameGU,6,2);
my $extensionGU = substr($fileNameGU,9,3);

my $racineImageGU = $annee2GU.$moisGU.$jourGU.$heureGU.$minuteGU.$secondeGU;
my $imageGU = $racineImageGU.".png";
my $fileMC="/MC".$annee4GU.$moisGU.".txt";
my ($id_evt,$date,$heure_evt,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$nb_fichiers,$png,$operateur,$comment) = split(/\|/,l2u(qx(awk -F'|' '\$1 == $id_evt {printf "\%s",\$0}' $WEBOBS{MC_RACINE}/$WEBOBS{MC_PATH_FILES}/$fileMC)));
my ($annee4,$mois,$jour) = split(/-/,$date);
my ($heure,$minute,$seconde) = split(/:/,$heure_evt);
my $date_evt = "$date $heure:$minute";

my @datesValides;
for (0..2) {
	my $dd = qx(date +"%Y-%m-%d %H:%M" -d "$annee4GU-$moisGU-$jourGU $heureGU:$minuteGU $_ minutes");
	chomp($dd);
	push(@datesValides,$dd);
}

# Recuperations des informations
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $fileStations=$WEBOBS{RACINE_FICHIERS_CONFIGURATION}."/".$WEBOBS{SEFRAN_FILE_VOIES};
open(FILE, "<$fileStations") || die "fichier $fileStations  non trouvé\n";
while(<FILE>) { push(@stations,$_); }
close(FILE);
my $fileEvnt=$WEBOBS{RACINE_FICHIERS_CONFIGURATION}."/".$WEBOBS{MC_FILE_CODES_SEISMES};
open(FILE, "<$fileEvnt") || die "fichier $fileEvnt  non trouvé\n";
while(<FILE>) { push(@typeEvnt,l2u($_)); }
close(FILE);

# Les fichiers peuvent supporter des commentaires
# - - - - - - - - - - - - - - - - - - - - - - - - -
@stations = grep(!/^#/, @stations);
@typeEvnt = grep(!/^#/, @typeEvnt);
@typeEvnt = grep(!/^$/, @typeEvnt);

# Récupération des informations en cas de modification.


# Debut de l'affichage HTML
# - - - - - - - - - - - - - - - - - - - - - - - - -
# -------- Controle de la validité de l'opérateur -------------
my $USER=$ENV{"REMOTE_USER"};
my $idUser=-1;
my $userTest=1;
my $nb=0;
while ($nb <= $#oper) {
	if ($USER ne "" && $USER eq $oper[$nb][3] && $oper[$nb][2] gt 0) {
		$idUser=$nb;
		$userTest=0;
	} elsif ($USER eq "") {
		# Le site étant protégé par htpasswd, les clients sans login sont en acquisition => OK
		$userTest=0;
		$USER = "visu";
	}
	$nb++;
}
if ($userTest != 0) { die "Sorry, this form is not authorized for user $USER (level = $oper[$idUser][2])"; }
my $aff_user;
if ($idUser gt -1) {
	$aff_user = "$oper[$idUser][1]";
} else {
	$aff_user = "login: $USER";
}

my %nomsOper;
my $nb=0;
while ($nb <= $#oper) {
	my ($initiales,$nom) = $oper[$nb];
	$nomsOper{$oper[$nb][0]} = $oper[$nb][1];
	$nb++;
}
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
<form name="formulaire" action="/cgi-bin/traitementMC.pl" method="post" onSubmit="return verif_formulaire()">
FIN

my $suds_debut = $pathGU."/".$fileNameGU;
my @imagesSuds = imagesSudsMC($suds_debut);
my $imageMC = shift @imagesSuds;
my @fichiersSuds = fichiersSuds(@imagesSuds);
my @tmp;
for ( @fichiersSuds ) {
	push(@tmp,('$13=="'.basename($_).'"'));
}
my $critere = join(" || ",@tmp);

my @listeSeismes = split(/\n/,qx(awk -F'|' '$critere {print}' $WEBOBS{MC_RACINE}/$WEBOBS{MC_PATH_FILES}/$fileMC|sort));
if (@listeSeismes) {
	print <<html;
<div style="border: 3px solid red;background: white; margin: 0.5em; padding: 0.5em;">
<h2 style="color: red;">Attention !</h2>
<p><b>Séismes identifiés dans les fichiers affichés</b> :</p>
<dl>
html
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
print "<p><input type=\"hidden\" name=\"fileNameGU\" value=\"$fileNameGU\"></p>";

# Genere la liste des operateurs
# - - - - - - - - - - - - - - - - - - - - - - - - -
print "<p>Nom Opérateur: <select onMouseOut=\"nd()\" onmouseover=\"overlib('Saisir votre nom')\" name=\"nomOperateur\" size=\"1\">";
print "<option selected value=\"\"></option>";
my $nb=0;
while ($nb <= $#oper) {
	my $sel;
	if (($id_evt and $operateur eq $oper[$nb][0]) or $USER eq $oper[$nb][3]) { $sel="selected"; }
	print "<option value=\"$oper[$nb][0]\" $sel>$oper[$nb][1]</option>\n";
	$nb++;
}

print "</select></p>";

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Entrée de la date de l'évènement

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
	if ($id_evt and $_ == $seconde) { print "<option selected value=\"$_\">$_</option>\n"; } else { print "<option value=$_>$_</option>\n"; } 
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
	"4 -1" => "Tous",
	"5 0" => "0"
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
	print <<"FIN";
	<p><input type="checkbox" name="transfert" value="1">Transfert des signaux</p>
	<p><input type="checkbox" name="impression" value="1">Impression du signal</p>
FIN
} else {
	print <<"FIN";
	<input type="hidden" name="transfert" value="1">
	<input type="hidden" name="impression" value="1">
FIN
}

# - - - - - - - - - - - - - - - - - - - - - - - - -

print "<input type=\"hidden\" name=\"pathGU\" value=\"$pathGU\">";
print "<input type=\"hidden\" name=\"fileMC\" value=\"$fileMC\">";
print "<input type=\"hidden\" name=\"imageGU\" value=\"$imageGU\">";
print "<input type=\"hidden\" name=\"id_evt\" value=\"$id_evt\">";

print <<"FIN";

<p><input type="submit" value="Soumettre"><input type="reset" value="Effacer"></p>
</form>
</td></tr></table>
<script type="text/javascript">
<!--
document.write("Dernière mise à jour: " + document.lastModified);
//-->
</script>
</font>
</body>
</html>

FIN
