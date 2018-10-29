#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- COMMENTAIRES ------------------------
# Auteur: Didier Mallarino + Fran�ois Beauducel
# ------
# Usage: Ce script permet l'affichage d'un fichier texte transmis en parametre:
# - contenant une première ligne de titre
# - se trouvant dans le répertoire RACINE_DATA_WIKI.
# ne permet pas l'affichage
#
# Créé: le 
# Modifié le : 2007-05-19
#---------------------------------------------------------------


# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ----------------------------------------------------
# -------- Fichiers de configurations ----------------
# ----------------------------------------------------
use readConf;
use Webobs;

# ----------------------------------------------------
# ----- Appel du Module de lecture de la configuration
my %WEBOBS = readConfFile;
# -------- Recupere le pied de page ------------------
my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");

# ----------------------------------------------------
# -------- Controle la validité de l'IP  -------------
# ----------------------------------------------------
use checkIP;
my $editOK = 0;
my $IP = $ENV{REMOTE_ADDR};
my $ipTest = checkIP($IP);
if ($ipTest != 0) { $editOK = 1; }


# ----------------------------------------------------
# ---------- Le coeur du programme -------------------
# ----------------------------------------------------

# Variables Locales et Recuperations des informations
# - - - - - - - - - - - - - - - - - - - - - - - - -

my $file="";
my @lignes;
my $texte;
my $editeur;
my @parametres=$cgi->url_param();
my $valParams = join(" ",@parametres);
if ($valParams =~ /file/) {
   $file="$WEBOBS{RACINE_DATA_WIKI}/".$cgi->url_param('file');
   if ( -e $file && $file =~ /$WEBOBS{REGEX_FICHIERS_AFF}/ ) {
       open(FILE, "<$file") || die " Probleme pour ouvrir le fichier $file\n";
       while(<FILE>) {
       		my $l = $_;
		chomp($_);
		push(@lignes,$l);
	}
       close(FILE);
   } else {
       die "Fichier $file INCONNU";
   }  
}
else {
   die "PARAMETRES INCONNUS - Operation Impossible";
}

my $fileName = basename($file);
my $html = 0;
my $titre;
chomp($lignes[0]);
if ($lignes[0] =~ /^TITRE_HTML\|/) {
	$titre = substr($lignes[0],11);
	$html = 1;
}
if ($lignes[0] =~ /^TITRE\|/) {
	$titre = substr($lignes[0],6);
}
shift(@lignes);

if ($editOK == 0) {
	$editeur = "<P align=\"right\"><A href=\"/cgi-bin/editTXT.pl?file=$file\"><B>$__{'Edit this page'}</B></A></P>";
}

print "Content-type: text/html

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<head>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_CSS}\">
<title>$titre</title>
<meta http-equiv=Content-Type content=\"text/html; charset=utf-8\">
</head>
<BODY>
<!--DEBUT DU CODE ROLLOVER 2-->
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/JavaScripts/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->
<!-- Affichage des bulles d'aide -->
<DIV ID=\"helpBox\"></DIV>";
if ($titre ne "") {
	print "<H1>$titre</H1>";
}
if ($html) {
	print @lignes;
} else {
	print txt2htm(join("",@lignes));
}
print "<BR>
@signature
$editeur
</BODY>
</HTML>";
