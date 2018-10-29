#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Didier Mallarino, Fran�ois Beauducel
# ------
# Usage: Ce script permet le traitement d'un fichier edité.
#
# ------------------- RCS Header -------------------------------
# $Header: /home/alexis/Boulot/cgi-bin/RCS/traitementTXT.pl,v 1.2 2007/01/23 23:02:46 root Exp alexis $
# $Revision: 1.2 $
# $Author: root $
# --------------------------------------------------------------


use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ----------------------------------------------------
# -------- Modules externes --------------------------
# ----------------------------------------------------
use readConf;

# ----------------------------------------------------
# -------- Configuration du site ---------------------
my %WEBOBS = readConfFile;

# Recuperation des donnees du formulaire
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $texte = $cgi->param('texte');
my $file = $cgi->param('file');
my $src = $cgi->param('src');
my $titre = $cgi->param('titre');
my $html = $cgi->param('html');

my @lignes;

# Affichage de la page HTML
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->header(-charset=>"utf-8"),
      $cgi->start_html('Traitement du texte édité ');
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/.$WEBOBS{FILE_CSS}\">";
#print "<body style=\"background-image:url(/_themes/blueprnt/blutextb.gif)\">";
print "<body>";
print $cgi->h2('Traitement du texte édité');
print "<hr>";

print "<h3>Avant Modification</h3>";
my @Info = stat($file);
print "<pre>\n"; 
print "<b>Fichier:</b>                      $file\n";
printf "<b>Droits d'accès:</b>               %o\n", $Info[2];
print "<b>Nombre de liens au fichier:</b>   $Info[3]\n";
my $userID=getpwuid($Info[4]);
print "<b>User-ID du propriétaire:</b>      $userID ($Info[4])\n";
my $groupID=getgrgid($Info[5]);
print "<b>Group-ID du propriétaire:</b>     $groupID ($Info[5])\n";
print "<b>Taille du fichier:</b>            $Info[7]\n";
my ($secondes, $minutes, $heures, $jour_mois, $mois, $an, $jour_semaine, $jour_calendaire, $heure_ete) = localtime($Info[8]);
$an=$an+1900;
$mois=$mois+1;
if ($mois < 10) {$mois="0".$mois; }
if ($jour_mois < 10) {$jour_mois="0".$jour_mois; }
print "<b>Date du dernier accès:</b>        $an-$mois-$jour_mois $heures:$minutes:$secondes ($Info[8])\n";
($secondes, $minutes, $heures, $jour_mois, $mois, $an, $jour_semaine, $jour_calendaire, $heure_ete) = localtime($Info[9]);
$an=$an+1900;
$mois=$mois+1;
if ($mois < 10) {$mois="0".$mois; }
if ($jour_mois < 10) {$jour_mois="0".$jour_mois; }
print "<b>Date de la dernière modif:</b>    $an-$mois-$jour_mois $heures:$minutes:$secondes ($Info[9])\n";
print "</pre>\n";


# Creation du nouveau fichier
# - - - - - - - - - - - - - - - - - - - - - - - - -
my @lues;
if (-e $file)  {
   open(FILE, "<$file") || die " Probleme pour ouvrir le fichier $file\n";
   while(<FILE>) { push(@lues,$_); }
   close(FILE);
   # Creation d'un backup
   my $fileTrtBckp=$file."TraitementBackup";
   open(FILE, ">$fileTrtBckp") || die " Probleme pour creer le backup du fichier $fileTrtBckp\n";
   print FILE @lues;
   close(FILE);
}
if ($titre ne "") {
	if ($html == 1) {
		@lignes = ("TITRE_HTML|$titre\n");
	} else {
		@lignes = ("TITRE|$titre\n");
	}
}
push(@lignes,$texte);
open(FILE, ">$file") || die "WEBOBS: Problem to write file \"$file\"\n";
print FILE @lignes;
close(FILE);

print "<h3>Après Modification</h3>";
@Info = stat($file);
print "<pre>\n"; 
print "<b>Fichier:</b>                      $file\n";
printf "<b>Droits d'accès:</b>               %o\n", $Info[2];
print "<b>Nombre de liens au fichier:</b>   $Info[3]\n";
$userID=getpwuid($Info[4]);
print "<b>User-ID du propriétaire:</b>      $userID ($Info[4])\n";
$groupID=getgrgid($Info[5]);
print "<b>Group-ID du propriétaire:</b>     $groupID ($Info[5])\n";
print "<b>Taille du fichier:</b>            $Info[7]\n";
($secondes, $minutes, $heures, $jour_mois, $mois, $an, $jour_semaine, $jour_calendaire, $heure_ete) = localtime($Info[8]);
$an=$an+1900;
$mois=$mois+1;
if ($mois < 10) {$mois="0".$mois; }
if ($jour_mois < 10) {$jour_mois="0".$jour_mois; }
print "<b>Date du dernier accès:</b>        $an-$mois-$jour_mois $heures:$minutes:$secondes ($Info[8])\n";
($secondes, $minutes, $heures, $jour_mois, $mois, $an, $jour_semaine, $jour_calendaire, $heure_ete) = localtime($Info[9]);
$an=$an+1900;
$mois=$mois+1;
if ($mois < 10) {$mois="0".$mois; }
if ($jour_mois < 10) {$jour_mois="0".$jour_mois; }
print "<b>Date de la dernière modif:</b>    $an-$mois-$jour_mois $heures:$minutes:$secondes ($Info[9])\n";
print "</pre>\n";


# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - -
print "<BR><HR><BR>
<SCRIPT LANGUAGE=\"JavaScript\">
<!--\n";
if (length($src) == 7) {
	print "	self.location.href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_STATION}?id=$src\"";
} elsif (length($src) == 3) {
        print " self.location.href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_RESEAUX}?reseau=$src\"";
} elsif (length($src) == 1) {
        print " self.location.href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_RESEAUX}?reseau=$src\&expand=0\"";
} elsif ($src eq "tous") {
        print " self.location.href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_RESEAUX}?expand=0\"";
#} elsif (index($file,$WEBOBS{RACINE_DATA_WEB} >= 0)) {
} elsif ($src eq "home") {
	print " self.location.href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_HEBDO}?cle=accueil\"";
} elsif ($src eq "close") {
	print " self.close()";
} else {
	print " self.location.href=\"/cgi-bin/presenteTEXTE.pl?file=".substr($file,length($WEBOBS{RACINE_DATA_WEB})+1)."\"";
}
print "\n//-->
</SCRIPT>
</BODY>";

print $cgi->end_html();
