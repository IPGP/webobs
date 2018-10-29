#!/usr/bin/perl -w
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Didier Mallarino
# ------
# Usage: Ce script permet de generer la page de saisie de la Main courante
# Fenetre de gauche, le sefran cliquable, a droite le formulaire de saisie
# et en bas, la main courante "en cours"
#
# ------------------- RCS Header -------------------------------
# $Header: /home/alexis/Boulot/cgi-bin/RCS/frameMC.pl,v 1.12 2007/05/29 21:38:59 bosson Exp alexis $
# $Revision: 1.12 $
# $Author: bosson $
# --------------------------------------------------------------

# -------- Modules externes --------------------------
use strict;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use readConf;
# -------- Configuration du site ---------------------
my %confStr=readConfFile;

# Recuperations des parametres
my $fileGU = $cgi->url_param('f');
my $id_evt = $cgi->url_param('id_evt');

print $cgi->header(-type=>"text/html;charset=utf-8");

print <<"FIN";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html>
<head>
<title>Saisie Main Courante Sismologie $fileGU</title>
</head>
<frameset FrameBorder="10" scrolling="no" cols="600,*">
	<FRAME name="image" src="/cgi-bin/afficheSUDS.pl?f=$fileGU&amp;id_evt=$id_evt" resize marginwidth=0 marginheight=0>
	<FRAME name="formulaire" src="/cgi-bin/formulaireMC.pl?f=$fileGU&amp;id_evt=$id_evt" resize marginwidth=0 marginheight=0>
</frameset>
</html>
FIN
