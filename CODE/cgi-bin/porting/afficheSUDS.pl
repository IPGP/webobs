#!/usr/bin/perl
# vi:enc=utf-8:
# Auteur:	Alexis Bosson
# Fonction:	Affichage de fichiers SUDS (pour MC)
# Créé le:	ven 02 mar 2007 22:35:59 AST
# <2 mar 2007 22:35:59 Alexis Bosson>

use strict;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use readConf;
use Webobs;
use File::Basename;
$| = 1;
my %confStr=readConfFile;

# Traitement des paramètres
my $suds_debut = $cgi->param('f');
(-f $confStr{RACINE_SIGNAUX_SISMO}.$suds_debut ) or die("Le fichier $suds_debut est introuvable !");

my $titreHTML = "MC ".(basename $suds_debut);
# Affichage du début de la page
print $cgi->header();
print <<html;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>$titreHTML</title>
<script language="javascript" src="/JavaScripts/overlib.js"></script>
<style type="text/css">
.suds
{
	background-color: #d0d0d0;
}
.suds img
{
	opacity: 0.9;
}
.suds a:hover img
{
	opacity: 1.0;
}
#attente
{
	 color: gray;
	 background: white;
	 margin: 0.5em;
	 padding: 0.5em;
	 font-size: 1.5em;
	 border: 1px solid gray;
	 position: float;
}
#regle {
	border-collapse: collapse;
	position: relative;
	top: -50px;
	left: -140px;
	width: 260px;
}
#regle td {
	text-align: center;
	font-size: 8px;
	font-weight: bold;
	border-bottom: 1px black solid;
	border-left: 1px black solid;
	border-right: 1px black solid;
	padding: 0;
	width: 19px !important;
	height: 3px;
}
#regle td.premier {
	border-left: 2px black solid;
}
#regle td.dernier {
	border: none;
}
#regle td .secondes {
	position: relative;
	top: 12px;
	left: -10px;
}
</style>
</head>
<body>
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<div id="attente">
Recherche des images et fichiers Suds...
html
# Recherche des images Suds
my @imagesSuds = imagesSudsMC($suds_debut);
my $imageMC = shift @imagesSuds;
my $voies = imageVoiesSefran($suds_debut);

# Bout de HTML avec liens pour afficher les images Suds avec liens vers les fichiers Suds
my $htmlImagesSuds;
my @liste_couleurs = ("#d0ffd0","#d0d0ff");
my $i = 0;
my $regle = <<html;
<table id="regle">
<tr>
<td class="premier"><div class="secondes">0</secondes></td>
<td><div class="secondes">10</secondes></td>
<td><div class="secondes">20</secondes></td>
<td><div class="secondes">30</secondes></td>
<td><div class="secondes">40</secondes></td>
<td><div class="secondes">50</secondes></td>
<td><div class="secondes">60</secondes></td>
<td><div class="secondes">70</secondes></td>
<td><div class="secondes">80</secondes></td>
<td><div class="secondes">90</secondes></td>
<td><div class="secondes">100</secondes></td>
<td><div class="secondes">110</secondes></td>
<td class="dernier"><div class="secondes">120</secondes></td>
</tr>
</table>
html
$regle =~ s/\n//g;
for (@imagesSuds) {
	$i++;
	my $couleur = $liste_couleurs[$i%2];
	my $fichierSuds = fichierSudsImage($_);
	print "<!-- \n".(infosSuds($_,$i).$regle)."\n -->";
	print "<!-- \n".(infosSuds($_,$i).$regle)."\n -->";
	my $infosFichier = htmlspecialchars($regle.infosSuds($_,$i));
	$htmlImagesSuds .= <<html;
		<td class="suds"><a href="fusionSUDS.pl?f=$suds_debut&n=$i"><img src="/$confStr{SEFRAN_PATH_WEB}$_" border="0" onMouseOut="nd()" onmouseover="overlib('$infosFichier', FGCOLOR, '$couleur')"></a></td>
html
}

# Affichage des images et fin de la page
print <<html;
Terminé.
</div>
<table cellpadding="0" cellspacing="0">
	<tr>
		<td><img src="/$confStr{SEFRAN_PATH_WEB}/$voies"></td>
$htmlImagesSuds
	</tr>
</table>
<style type="text/css">
#attente
{
	 display: none;
}
</style>
</body>
</html>
html
