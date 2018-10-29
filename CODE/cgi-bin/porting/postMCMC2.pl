#!/usr/bin/perl
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteurs: Didier Mallarino, Francois Beauducel, Alexis Bosson
# ------
# Usage: Ce script permet le traitement de l'entree des donnees en provenance du formulaire
# pour la Main courante (version Sefran2 EarthWorm)
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
use fonctions;
use Data::Dumper;
$| = 1;
use i18n;


# ---- parse query-string 
# 
my $MCfmt  = $cgi->param('MCfmt');
my $fileMC = $cgi->param('fileMC');
$fileMC=$WEBOBS{MC_PATH_FILES}/$fileMC;
my $imageGS = $cgi->param('imageGS');

############################ FIXME JMS
my $fileNameGS = $cgi->param('fileNameGS');
my $suds_a_pointer = $fileNameGS;
if ($fileNameGS =~ "gwa") {
	$suds_a_pointer =~ s/\.gwa/\.gl0/;
} elsif ($fileNameGS =~ "mar") {
	$suds_a_pointer =~ s/\.mar/\.mq0/;
}
my $pathGS = $cgi->param('pathGS');
my $id_evt_modif = $cgi->param('id_evt');
my $suds_debut = $pathGS."/".$fileNameGS;
if ($suds_debut =~ "gl0") {
	$suds_debut =~ s/\.gl0/\.gwa/;
} elsif ($suds_debut =~ "mq0") {
	$suds_debut =~ s/\.mq0/\.mar/;
}
############################ FIXME JMS

#my $fileNameGS = $cgi->param('fileNameGS');
#my $pathGS = $cgi->param('pathGS');
#my $id_evt_modif = $cgi->param('id_evt');
#my $suds_debut = $pathGS."/".$fileNameGS;

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

my $pathSignaux=$WEBOBS{RACINE_SIGNAUX_SISMO}.$pathGS;

if ($MCfmt eq "MC2") {
	# Creating variables for WO2SC3 input file
	# 
	my $sc3date = "date = ". $anneeEvnt. "/". $moisEvnt. "/". $jourEvnt."\n";
	my $sc3time = "time = ". $heureEvnt. ":". $minEvnt. ":". $secEvnt. "\n";
	my $sc3station = "station = ". $stationEvnt. "\n";
	my $sc3files = "files = ". $nbFichiers. "\n";
	my $sc3occurrences = "occurences = ". $nbrEvnt. "\n";
	my $sc3duration = "duration = ". $dureeEvnt. "\n";
	my $sc3sminusp = "sminusp = ". $smoinsp. "\n";
	my $sc3type = "type = " . $typeEvnt. "\n";
	my $sc3comment = "comment = ". $comment. "\n";
	my $sc3amplitude = "amplitude = " .$amplitudeEvnt. "\n";
	my $sc3operator = "operator = " .$name. "\n";
	my $sc3sudsfile = "sudsfile = " .$fileNameGS. "\n";
	# Printing variables into temporary file
	open(FILE, ">/tmp/new-event.txt") or die $!;
	print(FILE $sc3date);
	print(FILE $sc3time);
	print(FILE $sc3station);
	print(FILE $sc3files);
	print(FILE $sc3occurrences);
	print(FILE $sc3duration);
	print(FILE $sc3sminusp);
	print(FILE $sc3type);
	print(FILE $sc3comment);
	print(FILE $sc3operator);
	print(FILE $sc3amplitude);
	print(FILE $sc3sudsfile);
	close(FILE);
}

# ---- Start HTML page 
# 
print $cgi->header(-type=>"text/html;charset=utf-8"),
      $cgi->start_html('Process MC/MC2');
print "<BODY>";
print $cgi->h1('Processing MC/MC2 ');


# ---- MUTEX (using lockfile) 
# 
my $lockFile="/tmp/.MC.lock";
if (-e $lockFile) {
  die "$__{'File is currently being edited'} ($lockFile)" 
} else {
  my $retLock=qx(/bin/touch $lockFile);
}

# ---- If file already exists, read it and back it up 
# 
my @lignes;
if (-e $fileMC)  {
   open(FILE, "<$fileMC") || die "$__{'Could not open'} $fileMC\n";
   while(<FILE>) { push(@lignes,$_); }
   close(FILE);
   # Create backup
   my $fileMCTrtBckp=$fileMC."~";
   open(FILE, ">$fileMCTrtBckp") || die "$__{'Could not open'} backup $fileMCTrtBckp\n";
   print FILE @lignes;
   close(FILE);
} else {
   open(FILE, ">$fileMC") || die "$__{'Could not open'} $fileMC\n";
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
# Calling WO2SC3 binary with argument -i true for SeisComP3 update
#	my @args = ("$WEBOBS{PRGM_WO2SC3}", "-i true" , "-c $WEBOBS{RACINE_FICHIERS_CONFIGURATION}/wo2sc3.cfg");
#	system(@args);
}

# ---- Create new file, sorted 
# 
my $chaine="$id_evt|$anneeEvnt-$moisEvnt-$jourEvnt|$heureEvnt:$minEvnt:$secEvnt|$typeEvnt|$amplitudeEvnt|$dureeEvnt|$uniteEvnt|$dureeSatEvnt|$nbrEvnt|$smoinsp|$stationEvnt|$arrivee|$suds_a_pointer|$nbFichiers|$imageGS|$name|$comment\n";
push(@lignes,u2l($chaine));
@lignes = sort tri_date_avec_id (@lignes);

open(FILE, ">$fileMC") || die "$fileMC $__{'not found'}";
print FILE @lignes;
close(FILE);

my $retCHMOD = qx (/bin/chmod 666 $fileMC);

# ---- release MUTEX
#
if (-e $lockFile) {
  unlink $lockFile;
} else {
  print $cgi->b("$__{'unlink lockfile error'}"),"<br>";
}

# ---- Display transmitted data 
# 
if ($nbFichiers == -1) {
$nbFichiers=$WEBOBS{MC_NOMBRE_FICHIERS_IMAGES};
}
my $signalSature=$amplitudeEvnt;
if ($dureeSatEvnt > 0) {
$signalSature="Sature ($dureeSatEvnt s)";
}

my $err=0;
my $textePourImage=$anneeEvnt."-".$moisEvnt."-".$jourEvnt." ".$heureEvnt.":".$minEvnt.":".$secEvnt." (".$name.") #".$nbFichiers." ".$typeEvnt." (".$dureeEvnt." ".$uniteEvnt.") ".$stationEvnt." ".$signalSature." - ".$comment;

#----  Check for files (enregistrement & image) to be kept 
# 
my @files=("");
my $index=0;

if ($MCfmt eq "MC") {
	my $findFile=0;

	# ---- Fichiers enregistrement
	# opendir(DIR,$pathSignaux) or die $!;
	opendir(DIR,$pathSignaux) or print "Erreur : RÃ©pertoire de signaux introuvable !";
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
}

if ($MCfmt eq "MC2") {
	if ($nbFichiers > 0 && $transfert) {
		my $findFile=0;

		my @liste_suds = fichiersSudsSuivants($suds_debut,$nbFichiers);
		my @liste_presents;
		my @liste_absents;
		foreach my $file (@liste_suds)
		{
			if ( -f $file ) {
				push(@liste_presents,$file);
				$findFile =1;
			} else {
				push(@liste_absents,$file);
			}
		}
		if ($#liste_absents != -1) {
			if ($#liste_presents != -1) {
				print "<p><b>Il manque ".($#liste_absents+1)." fichier(s) sur ".($#liste_absents+1+$#liste_presents+1)." : @liste_absents</b></p>";
				print "<script>window.alert('Fichiers absents : ".join(' ',@liste_absents)."')</script>";
			} else {
				print "<p><b>Les fichiers à transférer sont introuvables !</b></p>";
				$err = 1;
			}
		}
		if ( $findFile ) {
			my $pathDestSgx="$WEBOBS{MC_PATH_DESTINATION_SIGNAUX}/$anneeEvnt-$moisEvnt";
			print '<p>'.$cgi->b("Fusion vers $pathDestSgx de : <br>"),join('<br>',@liste_presents).'<br>';
			my ($dest_dir,$dest) = fusion_suds($suds_debut,$nbFichiers);
			print 'Terminé.</p>';
			if (! -e $pathDestSgx) {
				system("mkdir -p $pathDestSgx");
				system("chmod g+w $pathDestSgx");
			}
	# FIXME JMS	if ($suds_debut =~ /gwa/) {
	#			$suds_a_pointer =~ s/\.gwa/\.gl0/;
	#		} elsif ($suds_debut =~ "mar") {
	#			$suds_a_pointer =~ s/\.mar/\.mq0/;
	#		}
			if ( system("mv $dest $pathDestSgx/$suds_a_pointer") != 0 ) {
	#		if ( system("mv $dest $pathDestSgx/") != 0 ) {
				print "Déplacement du fichier fusionné vers $pathDestSgx impossible !";
				$err=1;
			}
		}
	}
}

# ---- Scan for Suds images
#
print '<p><b>Recherche des images individuelles à concaténer</b>... ';
my @imagesSuds; 
if ($MCfmt eq "MC")  { @imagesSuds = imagesSudsMC($suds_debut) }
if ($MCfmt eq "MC2") { @imagesSuds = imagesSuds2MC($suds_debut) }
my $imageMC = "$WEBOBS{MC_PATH_IMAGES}/".(shift @imagesSuds);
if ($MCfmt eq "MC")  { $voies = imageVoiesSefran($suds_debut) }
if ($MCfmt eq "MC2") { $voies = imageVoiesSefran2($suds_debut) }

if (! -f $WEBOBS{RACINE_SIGNAUX_SISMO}.$suds_debut )
{
	print("Le fichier $suds_debut est introuvable !");
	$err=1;
}
print 'Terminé.</p>';

# Concaténation des images
if ( -f $imageMC ) {
	print "<p><b>L'image concaténée existe déjà.</b></p>";
} else {
	print '<p><b>Concaténation des images</b>... ';
	my $concat='';
	if ($MCfmt eq "MC")  { $concat = $WEBOBS{SEFRAN_RACINE} }
	if ($MCfmt eq "MC2") { $concat = $WEBOBS{SEFRAN2_RACINE} }
	my $cmd = "convert +append $concat/$voies ";
	for (@imagesSuds) {
		$cmd .= " $concat$_";
	}
	$cmd .= " ".$imageMC;
	my $repImg=dirname($imageMC);
	if (! -e $repImg) {
		system("mkdir -p $repImg");
	}
	(system($cmd) == 0) or $err=1;
	print 'Terminé.</p>';
}


if ($impression) {
	print '<p><b>Impression</b>... ';
	#djl-was: print qx($WEBOBS{RACINE_TOOLS_SHELLS}/impression_image "$WEBOBS{MC_PRINTER}" "$imageMC" "$textePourImage");
	print 'Terminé.</p>';
}

# Sortie de la Frame
# - - - - - - - - - - - - - - - - - - - - - - - - -
if ($err == 0) {
	print <<"FIN";
 <script language="javascript">
	window.top.close();
 </script>
FIN
} else {
	print $cgi->h3("Une erreur s'est produite !");
}

# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->end_html();

#-------------------------------------------------------------------#
#                          SeisComP3 linker                         #
#-------------------------------------------------------------------#
#                                                                   #
# Creating variables for WO2SC3 input file                          #
#my $sc3date = "date = ". $anneeEvnt. "/". $moisEvnt. "/". $jourEvnt."\n";
#my $sc3time = "time = ". $heureEvnt. ":". $minEvnt. ":". $secEvnt. "\n";
#my $sc3station = "station = ". $stationEvnt. "\n";
#my $sc3files = "files = ". $nbFichiers. "\n";
#my $sc3occurrences = "occurences = ". $nbrEvnt. "\n";
#my $sc3duration = "duration = ". $dureeEvnt. "\n";
#my $sc3sminusp = "sminusp = ". $smoinsp. "\n";
#my $sc3type = "type = " . $typeEvnt. "\n";
#my $sc3comment = "comment = ". $comment. "\n";
#my $sc3amplitude = "amplitude = " .$amplitudeEvnt. "\n";
#my $sc3operator = "operator = " .$name. "\n";
#                                                                   #
# Printing variables into file                                      #
#open(FILE, ">/tmp/new-event.txt") or die $!;
#print(FILE $sc3date);
#print(FILE $sc3time);
#print(FILE $sc3station);
#print(FILE $sc3files);
#print(FILE $sc3occurrences);
#print(FILE $sc3duration);
#print(FILE $sc3sminusp);
#print(FILE $sc3type);
#print(FILE $sc3comment);
#print(FILE $sc3operator);
#print(FILE $sc3amplitude);
#close(FILE);
#                                                                   #
# Calling WO2SC3 binary with argument -i true                       #
#djl-wasactive: my @args = ("$WEBOBS{PRGM_WO2SC3}", "-i true" , "-c $WEBOBS{RACINE_FICHIERS_CONFIGURATION}/wo2sc3.cfg");
#djl-wasactive: system(@args);
#                                                                   #
#-------------------------------------------------------------------#

