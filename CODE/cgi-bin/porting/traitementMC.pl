#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Didier Mallarino
# ------
# Usage: Ce script permet le traitement de l'entree des donnees en provenance du formiulaire
# pour la Main courante
#
# ------------------- RCS Header -------------------------------
# $Header: /ipgp/webobs/WWW/cgi-bin/RCS/traitementMC.pl,v 1.6 2007/05/29 21:47:11 bosson Exp bosson $
# $Revision: 1.6 $
# $Author: bosson $
# --------------------------------------------------------------

use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use Webobs;
use Data::Dumper;
$| = 1;
use i18n;

# ----------------------------------------------------
# ---------- Module de configuration  ----------------
# ----------------------------------------------------
use readConf;
my %confStr=readConfFile;
# ----------------------------------------------------


# Recuperation des donnees du formulaire
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $fileMC = $cgi->param('fileMC');
my $imageGU = $cgi->param('imageGU');
my $fileNameGU = $cgi->param('fileNameGU');
my $pathGU = $cgi->param('pathGU');
my $id_evt_modif = $cgi->param('id_evt');

my $name = $cgi->param('nomOperateur');
my $dateEvnt = $cgi->param('dateEvenement');
my $anneeEvnt = substr($dateEvnt,0,4);
my $moisEvnt = substr($dateEvnt,5,2);
my $jourEvnt = substr($dateEvnt,8,2);
my $heureEvnt = substr($dateEvnt,11,2);
my $minEvnt = substr($dateEvnt,14,2);
my $secEvnt = $cgi->param('secondeEvenement');
my $typeEvnt = $cgi->param('typeEvenement');
my $arrivee = $cgi->param('arriveeUnique');
my $dureeEvnt = $cgi->param('dureeEvenement');
my $uniteEvnt = $cgi->param('uniteEvenement');
my $dureeSatEvnt = $cgi->param('saturationEvenement');
my $amplitudeEvnt = $cgi->param('amplitudeEvenement');
my $nbFichiers = $cgi->param('nombreFichiers');
my $stationEvnt = $cgi->param('stationEvenement');
my $comment = $cgi->param('commentEvenement');
my $impression = $cgi->param('impression');
my $transfert = $cgi->param('transfert');
my $dateCourante=$anneeEvnt."-".$moisEvnt."-".$jourEvnt;
my $nbrEvnt =  $cgi->param('nombreEvenement');
my $smoinsp =  $cgi->param('smoinsp');
if ($smoinsp eq "") { $smoinsp="NA"; }

# Fabrication des variables
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $pathFileMC=$confStr{MC_RACINE}."/".$confStr{MC_PATH_FILES};
$fileMC=$pathFileMC.$fileMC;
my $pathSignaux=$confStr{RACINE_SIGNAUX_SISMO}.$pathGU;

# Demarre l'affichage de la page HTML
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->header(-type=>"text/html;charset=utf-8"),
      $cgi->start_html('Traitement MAIN COURANTE');
print "<BODY>";
print $cgi->h1('Traitement MAIN COURANTE ');


# Verification de la possibilité d'ecrire dans le fichier
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $lockFile="/tmp/.MC.lock";
if (-e $lockFile) {
  die "Quelqu'un edite la main courante... $lockFile existe" 
} else {
  my $retLock=qx(/bin/touch $lockFile);
}

# Si le fichier existe, on fait un backup
# - - - - - - - - - - - - - - - - - - - - - - - - -
my @lignes;
if (-e $fileMC)  {
   open(FILE, "<$fileMC") || die " Probleme sur le fichier $fileMC\n";
   while(<FILE>) { push(@lignes,$_); }
   close(FILE);
   # Creation d'un backup
   my $fileMCTrtBckp=$fileMC."TraitementBackup";
   open(FILE, ">$fileMCTrtBckp") || die " Probleme sur le fichier $fileMCTrtBckp\n";
   print FILE @lignes;
   close(FILE);
} else {
   open(FILE, ">$fileMC") || die " Probleme sur le fichier $fileMC\n";
   print FILE ("");
   close(FILE);
}

my $id_evt;
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
} else {
	my $max = 0;
	for (@lignes) {
		my ($id_evt) = split(/\|/,$_);
		if ($id_evt > $max) {
			$max = $id_evt;
		}
	}
	$id_evt = $max+1;
}

# Creation du nouveau fichier trié
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $chaine="$id_evt|$anneeEvnt-$moisEvnt-$jourEvnt|$heureEvnt:$minEvnt:$secEvnt|$typeEvnt|$amplitudeEvnt|$dureeEvnt|$uniteEvnt|$dureeSatEvnt|$nbrEvnt|$smoinsp|$stationEvnt|$arrivee|$fileNameGU|$nbFichiers|$imageGU|$name|$comment\n";
push(@lignes,u2l($chaine));
@lignes = sort tri_date_avec_id (@lignes);

open(FILE, ">$fileMC") || die "fichier $fileMC  non trouvé\n";
print FILE @lignes;
close(FILE);

my $retCHMOD = qx (/bin/chmod 666 $fileMC);

if (-e $lockFile) {
  unlink $lockFile;
} else {
  print $cgi->b('WARNING: PROBLEME SUR LE LOCK FILE'),"<br>";
}


# Affichage des données transmises
# - - - - - - - - - - - - - - - - - - - - - - - - -
if ($nbFichiers == -1) {
$nbFichiers=$confStr{MC_NOMBRE_FICHIERS_IMAGES};
}
my $signalSature=$amplitudeEvnt;
if ($dureeSatEvnt > 0) {
$signalSature="Satur� ($dureeSatEvnt s)";
}

my $textePourImage=$anneeEvnt."-".$moisEvnt."-".$jourEvnt." ".$heureEvnt.":".$minEvnt.":".$secEvnt." (".$name.") #".$nbFichiers." ".$typeEvnt." (".$dureeEvnt." ".$uniteEvnt.") ".$stationEvnt." ".$signalSature." - ".$comment;

# Recherche des fichiers enregistrement et image a conserver
# - - - - - - - - - - - - - - - - - - - - - - - - -
my @files=("");
my $index=0;
my $findFile=0;

# ---- Fichiers enregistrement
# opendir(DIR,$pathSignaux) or die $!;
opendir(DIR,$pathSignaux) or print "Erreur : Répertoire de signaux introuvable !";
@files = readdir(DIR);
closedir(DIR);

$index=0;
$findFile=0;
my @sortedFiles=sort(@files);
foreach my $file (@sortedFiles)
{
   $index++;
   if ($file eq $fileNameGU) { 
      $findFile=1;
      last;
    }
}
if ($findFile==1) {
   my $debut=$index-1;
   my $fin=$index+$nbFichiers-1;
   splice (@sortedFiles,$fin);
   splice (@sortedFiles,0,$debut);
   for (@sortedFiles) { print $cgi->b('Identified Files:'),$_,"<br>" ; }

   if ($transfert) {
	   # Transfert des fichiers
	   for (@sortedFiles) {
		   my $pathDestSgx="$confStr{MC_PATH_DESTINATION_SIGNAUX}/$anneeEvnt-$moisEvnt";
		   if (! -e $pathDestSgx) {
			   system("mkdir -p $pathDestSgx");
			   system("chmod g+w $pathDestSgx");
		   }
		   my $extensionGU = substr($_,9,3);
		   my $racineGU = substr($_,0,8);
		   if ($extensionGU eq "GUX") {
			   print $cgi->b('TRANSFERT DE:'),$_." vers ",$pathDestSgx,"<br>";
			   my $retCP = system("/bin/cp $pathSignaux/$_ $pathDestSgx 2>&1");
			   if ( $retCP != 0 ) {
				   print "Copie de $pathSignaux/$_ vers $pathDestSgx impossible !";
			   }
		   }
		   elsif ($extensionGU eq "GUA") {
			   my $repDate=basename($pathSignaux);
			   print $cgi->b('TRANSFERT DE:'),$racineGU,".MIX vers ",$pathDestSgx,"<br>";
			   my $cmdSmb="cp $confStr{RACINE_SIGNAUX_SISMO}/MIX/$repDate/$racineGU.MIX $pathDestSgx/ 2>&1";
			   my $retSmb = system($cmdSmb);
			   if ( $retSmb != 0 ) {
				   print "Copie de $confStr{RACINE_SIGNAUX_SISMO}/MIX/$repDate/$racineGU.MIX vers $pathDestSgx impossible !";

				   # SI ERREUR, TRANSFERER LE GUA
				   print $cgi->b('TRANSFERT DE:'),$_." vers ",$pathDestSgx,"<br>";
				   my $retCP = system("/bin/cp $pathSignaux/$_ $pathDestSgx 2>&1");
				   if ( $retCP != 0 ) {
					   print "Copie de $pathSignaux/$_ vers $pathDestSgx impossible !";
				   }
			   }
		   }
	   }
   }

} else {
   print "<HR><BR>PROBLEME SUR LE FICHIER ENREGISTREMENT<BR><HR>";
}



# Recherche des images Suds
print '<p><b>Recherche des images individuelles à concaténer</b>... ';
my $suds_debut = $pathGU."/".$fileNameGU;
my @imagesSuds = imagesSudsMC($suds_debut);
my $imageMC = "$confStr{MC_RACINE}/$confStr{MC_PATH_IMAGES}/".(shift @imagesSuds);
my $voies = imageVoiesSefran($suds_debut);

(-f $confStr{RACINE_SIGNAUX_SISMO}.$suds_debut ) or print("Le fichier $suds_debut est introuvable !");
print 'Terminé.</p>';

# Concaténation des images
if ( -f $imageMC ) {
	print "<p><b>L'image concaténée existe déjà.</b></p>";
} else {
	print '<p><b>Concaténation des images</b>... ';
	my $cmd = "convert +append $confStr{SEFRAN_RACINE}/$voies ";
	for (@imagesSuds) {
		$cmd .= " $confStr{SEFRAN_RACINE}$_";
	}
	$cmd .= " ".$imageMC;
	my $repImg=dirname($imageMC);
	if (! -e $repImg) {
		system("mkdir -p $repImg");
	}
	system($cmd);
	print 'Terminé.</p>';
}


if ($impression) {
	print '<p><b>Impression</b>... ';
	if ( -e "/etc/debian_version" ){
		print qx($confStr{RACINE_TOOLS_SHELLS}/impression_image "$confStr{MC_PRINTER}" "$imageMC" "$textePourImage");
	} else {
		my $HACK_OLD_RH=6.2;
		qx(/usr/bin/convert -page letter -label "$textePourImage" -rotate 90 -border 2x2 -bordercolor black $imageMC /tmp/imageMC.$$.ps);
		qx(/usr/bin/lpr /tmp/imageMC.$$.ps);
		qx(/bin/rm /tmp/imageMC.$$.ps);
	}
	print 'Terminé.</p>';
}

# Sortie de la Frame
# - - - - - - - - - - - - - - - - - - - - - - - - -
print <<"FIN";
 <script language="javascript">
	window.top.close();
 </script>
 </body>
FIN

# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->end_html();
