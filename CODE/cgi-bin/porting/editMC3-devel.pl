#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- WEBOBS -----------------------------------
# editMC3.pl
# ------
# Usage: Process parameters from "Main Courante" editor
#
# 
# Author: Francois Beauducel
# Acknowledgments:
#       traitementMC2.pl [2004-2009] by Didier Mallarino, Francois Beauducel and Alexis Bosson
# Created: 2008
# Updated: 2012-03-28

use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use fonctions;
use Data::Dumper;
$| = 1;
use i18n;

# ----------------------------------------------------
use readConf;
my %WEBOBS = readConfFile;


# GET form parameters
my $s3 = $cgi->url_param('s3');
my $mc3 = $cgi->url_param('mc');

my $fileMC = $cgi->param('fileMC');
my $id_evt_modif = $cgi->param('id_evt');
my $date = $cgi->param('date');
my $delete = $cgi->param('effaceEvenement');

my $name = $cgi->param('nomOperateur');
my $dateEvnt = $cgi->param('dateEvenement');
my ($anneeEvnt,$moisEvnt,$jourEvnt,$heureEvnt,$minEvnt) = split(/-|:|\ /,$dateEvnt);
my $secEvnt = $cgi->param('secondeEvenement');
my $typeEvnt = $cgi->param('typeEvenement');
my $arrivee = $cgi->param('arriveeUnique');
my $dureeEvnt = $cgi->param('dureeEvenement');
my $uniteEvnt = $cgi->param('uniteEvenement');
my $dureeSatEvnt = $cgi->param('saturationEvenement');
my $amplitudeEvnt = $cgi->param('amplitudeEvenement');
my $stationEvnt = $cgi->param('stationEvenement');
my $comment = $cgi->param('commentEvenement');
my $impression = $cgi->param('impression');
my $replay = $cgi->param('replay');
my $dateCourante=$anneeEvnt."-".$moisEvnt."-".$jourEvnt;
my $nbrEvnt =  $cgi->param('nombreEvenement');
my $smoinsp =  $cgi->param('smoinsp');
if ($smoinsp eq "") { $smoinsp="NA"; }
my $imageSEFRAN =  $cgi->param('imageSEFRAN');

# to keep compatibility with MC2
my $nbFichiers = $cgi->param('nombreFichiers');
my $fileNameSUDS = $cgi->param('fileNameSUDS');
my $transfert = $cgi->param('transfert');


# loads Sefran3 configuration file
if ($s3 eq "") {
        $s3 = $WEBOBS{SEFRAN3_DEFAULT_CONF};
}
my %SEFRAN3 = readConfFile("$s3.conf");

# loads MC3 configuration file
if ($mc3 eq "") {
        $mc3 = $WEBOBS{MC3_DEFAULT_CONF};
}
my %MC3 = readConfFile("$mc3.conf");

my $titre = $MC3{TITLE};

# - - - - - - - - - - - - - - - - - - - - - - - - -
# starts HTML page display
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->header(-type=>"text/html;charset=utf-8"),
      $cgi->start_html("Traitement $titre");
print "<BODY>";
print $cgi->h1("Traitement $titre");


# calculates number of minute-images that include signal
my @durations = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$MC3{DURATIONS_CONF}");
my ($key,$nam,$val) = split(/\|/,join('',grep(/^$uniteEvnt/,@durations)));
my $nb_images = int(($dureeEvnt*$val + $secEvnt)/60 + 1);
if ($nb_images > $MC3{IMAGES_MAX_CAT}) {
	$nb_images = $MC3{IMAGES_MAX_CAT};
}

# full path filename MC
$fileMC = "$MC3{ROOT}/".substr($fileMC,3,4)."/$MC3{PATH_FILES}/$fileMC";

# MC image filename (to be saved)
# NOTE: overwrite possible $imageSEFRAN value (in case of date/time event modification)
$imageSEFRAN = sprintf("%4d%02d%02d%02d%02d%02.0f.png",$anneeEvnt,$moisEvnt,$jourEvnt,$heureEvnt,$minEvnt,$secEvnt);
my $imageMC = "$MC3{ROOT}/$anneeEvnt/$MC3{PATH_IMAGES}/$anneeEvnt$moisEvnt/MC_$imageSEFRAN";

# Verification de la possibilité d'ecrire dans le fichier
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $lockFile = "/tmp/.MC3.lock";
if (-e $lockFile) {
	my $lockWho = qx(cat $lockFile | xargs echo -n);
	die "La main courante est en cours d'édition par $lockWho ...";
} else {
	my $retLock = qx(echo "$name" > $lockFile);
}

# Si le fichier existe, on fait un backup
# - - - - - - - - - - - - - - - - - - - - - - - - -
my @lignes;
if (-e $fileMC)  {
	print "<P><B>Fichier existant:</B> $fileMC ...";
	open(FILE, "<$fileMC") || Quit($lockFile," Probleme sur le fichier $fileMC\n");
	while(<FILE>) { push(@lignes,$_); }
	close(FILE);
	print "importé.</P>";

	# Creation d'un backup
	my $fileMCTrtBckp = $fileMC.".backup";
	open(FILE, ">$fileMCTrtBckp") || Quit($lockFile," Probleme sur le fichier $fileMCTrtBckp\n");
	print FILE @lignes;
	close(FILE);
	print "<P><B>Copie de sauvegarde:</B> $fileMCTrtBckp</P>\n";
} else {
	qx(mkdir -p `dirname $fileMC`);
	open(FILE, ">$fileMC") || Quit($lockFile,"Probleme sur le fichier $fileMC\n");
	print FILE ("");
	close(FILE);
}

my $id_evt;

# l'evenement existe (modification): on lit tout sauf l'ID concerne
if ($id_evt_modif) {
	my @lignes_restantes;
	for (@lignes) {
		my ($id_evt_tmp) = split(/\|/,$_);
		if ($id_evt_tmp != $id_evt_modif) {
			push(@lignes_restantes,$_);
		}
	}
	@lignes = @lignes_restantes;
	$id_evt = $id_evt_modif;
	if ($delete == 1) {
		print "<P><B>Suppression d'événement existant:</B> $id_evt</P>";
	} else {
		print "<P><B>Modification d'événement existant:</B> $id_evt</P>";
	}
# l'evenement n'existe pas (nouveau): on lit tout et on calcule le prochain ID
} else {
	my $max = 0;
	for (@lignes) {
		my ($id_evt) = split(/\|/,$_);
		if ($id_evt > $max) {
			$max = $id_evt;
		}
	}
	$id_evt = $max + 1;
	print "<P><B>Nouvel  événement:</B> $id_evt</P>";
}

# Ajout/modification: on ajoute la ligne de données sinon supression
if ($delete != 1) {
	my $chaine = "$id_evt|$anneeEvnt-$moisEvnt-$jourEvnt|$heureEvnt:$minEvnt:$secEvnt|$typeEvnt|$amplitudeEvnt|$dureeEvnt|$uniteEvnt|$dureeSatEvnt|$nbrEvnt|$smoinsp|$stationEvnt|$arrivee|$fileNameSUDS|$nbFichiers|$imageSEFRAN|$name|$comment\n";

	push(@lignes,u2l($chaine));
}

# Creation du nouveau fichier trie
# - - - - - - - - - - - - - - - - - - - - - - - - -
@lignes = sort tri_date_avec_id (@lignes);

open(FILE, ">$fileMC") || Quit($lockFile,"fichier $fileMC  non trouvé\n");
print FILE @lignes;
close(FILE);

my $retCHMOD = qx (/bin/chmod 666 $fileMC);

if (-e $lockFile) {
	unlink $lockFile;
} else {
	print $cgi->b('WARNING: PROBLEME SUR LE LOCK FILE'),"<br>";
}


# Preparation du texte pour impression
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $signalSature = $amplitudeEvnt;
if ($dureeSatEvnt > 0) {
	$signalSature = "Sature ($dureeSatEvnt s)";
}

my $err = 0;
my $textePourImage = "$anneeEvnt-$moisEvnt-$jourEvnt $heureEvnt:$minEvnt:$secEvnt ($name) $typeEvnt ($dureeEvnt $uniteEvnt) $stationEvnt $signalSature - $comment";

# Recherche des fichiers enregistrement et image a conserver
# - - - - - - - - - - - - - - - - - - - - - - - - -
my @files = ("");
my $index = 0;

# Recherche des images Sefran
print '<p><b>Recherche des images individuelles à concaténer</b>...<UL> ';

my @imagesPNG;
my $voies;
my $i;
for ($i = 0; $i < $nb_images; $i++) {
	my ($Y,$m,$d,$H,$M) = split('/',qx(date -d '$dateEvnt $i minute' +"%Y/%m/%d/%H/%M"|xargs echo -n));
	my $f = sprintf("%s/%4d/%04d%02d%02d/%s/%04d%02d%02d%02d%02d00.png",$SEFRAN3{ROOT},$Y,$Y,$m,$d,$SEFRAN3{PATH_IMAGES_MINUTE},$Y,$m,$d,$H,$M);
	push(@imagesPNG,$f);
	print "<LI>$f</LI>\n";
	if ($i == 0) {
		$voies = sprintf("%s/%4d/%04d%02d%02d/%s/%04d%02d%02d%02d_voies.png",$SEFRAN3{ROOT},$Y,$Y,$m,$d,$SEFRAN3{PATH_IMAGES_HEADER},$Y,$m,$d,$H);
	}
}

print '</UL>Terminé.</p>';

# Concaténation des images
print '<p><b>Concaténation des images</b>... ';
my $cmd = "$WEBOBS{PRGM_CONVERT} +append $voies ".join(" ",@imagesPNG)." $imageMC";
qx(mkdir -p `dirname $imageMC`);
(system($cmd) == 0) or $err=1;
print 'Terminé.</p>';
print "<P><B>Image sauvegardée:</B> $imageMC</P>";


if ($impression) {
	print '<p><b>Impression</b>... ';
	print qx($WEBOBS{RACINE_TOOLS_SHELLS}/impression_image "$MC3{PRINTER}" "$imageMC" "$textePourImage");
	print 'Terminé.</p>';
}

# Sortie de la Frame
# - - - - - - - - - - - - - - - - - - - - - - - - -
#sleep(5);
if ($err == 0) {
	print "<script language=\"javascript\">";
	if ($replay) {
		print "window.location='/cgi-bin/$WEBOBS{CGI_SEFRAN3}?date=$date';";
	} else {
		# for Firefox: opens a "false" window to be allowed to close it...
		print "window.open('','_parent','');window.close();";
	}
	print "</script>\n";
} else {
	print $cgi->h3("Une erreur s'est produite !");
}

# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->end_html();


sub Quit 
{
	if (-e $_[0]) {
		unlink $_[0];
	}
	die "WEBOBS: $_[1]";
}

