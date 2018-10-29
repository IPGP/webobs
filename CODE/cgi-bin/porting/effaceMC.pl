#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Didier Mallarino
# ------
# Usage: Ce script permet d'effacer une ligne dans la Main Courante
# Cette fonctionnalité doit etre autorise par le checkIP.pm
#
# ------------------- RCS Header -------------------------------
# $Header: /home/alexis/Boulot/cgi-bin/RCS/effaceMC.pl,v 1.7 2007/05/29 21:43:42 bosson Exp alexis $
# $Revision: 1.7 $
# $Author: bosson $
# --------------------------------------------------------------

# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
$|=1;

# ----------------------------------------------------
# -------- Controle la validité de l'IP  -------------
# ----------------------------------------------------
use checkIP;
my $IP=$ENV{REMOTE_ADDR};
my $ipTest=checkIP($IP);
if ($ipTest != 0) { die "OPERATION INTERDITE"; }

# Recuperation des donnees du formulaire
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $ligneToRemove = $cgi->param('id_evt') || "";
my $fileMC =  $cgi->param('fileMC');
#my $dateModif =  $cgi->param('dateModif') || "";


# ----------------------------------------------------
# ---------- Module de configuration  ----------------
# ----------------------------------------------------
use readConf;
my %confStr=readConfFile;
# ----------------------------------------------------

# Variables locales
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $nb=0;
my @lignes;

# Affichage de la page HTML
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->header(-type=>"text/html;charset=utf-8"),
$cgi->start_html('Effacement Ligne  MAIN COURANTE ');
print "<BODY>";
print $cgi->h1('Effacement Ligne  MAIN COURANTE ');

if ($fileMC ne "" and $ligneToRemove ne "" ) {

# Verification de la possibilité d'ecrire dans le fichier et lock File
# - - - - - - - - - - - - - - - - - - - - - - - - -
	# Depuis qu'il y a des numéros d'évènements dans les fichiers MC, peu importent le timestamp du fichier qui servait quand on indiquait le numéro de ligne
	#my @Info = stat($fileMC);
	#if ($Info[8] != $dateModif) {
	#	print "<b>Nom du fichier traité: </b>",$fileMC,"<br>";
	#	print "<b>Ligne a supprimer: </b>",$ligneToRemove,"<br>";
	#	print "<b>Date de derniere modification: </b>",$Info[8],"<br>";
	#	print "<b>Date de derniere modification transmise: </b>",$dateModif,"<br>";
	#	die "Modification IMPOSSIBLE car les dates ne coincident pas";
	#}
	my $lockFile="/tmp/.MC.lock";
	if (-e $lockFile) {
		die "Le fichier de verrouillage de la main courante est présent. Bug !!! $lockFile"
	} else {
		my $retLock=qx(/bin/touch $lockFile);
	}

# Recupere le contenu du fichier
# - - - - - - - - - - - - - - - - - - - - - - -
	print "<b>Nom du fichier traité: </b>",$fileMC,"<br>";
	print "<b>Ligne a supprimer: </b>",$ligneToRemove,"<br>";
	#print "<b>Date de derniere modification: </b>",$Info[8],"<br>";
	open(FILE, "<$fileMC") || die "fichier $fileMC  non trouvé\n";
	while(<FILE>) { push(@lignes,$_); $nb=$.; }
	close(FILE);
	print "<b>Nombre de lignes lues: </b>",$nb,"<br>";

# Supprime la ligne
# - - - - - - - - - - - - - - - - - - - - - - -
	use Data::Dumper;
	print '<pre style="background-color: #eee; text-align: left;">'.Dumper('Fichier : '.__FILE__,'Ligne : '.__LINE__,'$ligneToRemove',$ligneToRemove).'</pre>';
	if ($ligneToRemove ne "") {
		# Cree un backup
		my $fileMCback=$fileMC.".EffacementBackup";
		print "<b>Ecriture du fichier backup: </b>",$fileMCback,"<br>";
		open(FILE, ">$fileMCback") || die "fichier $fileMCback  non trouvé\n";
		print FILE @lignes;
		close(FILE); 
		# Efface la ligne
		print $cgi->b('Effacement de la ligne:  '),$ligneToRemove,"<br>";

		my @lignes_restantes;
		my $png_suppr;
		my $path_png_suppr;
		my @liste_png;
		for (@lignes) {
			my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$nb_fichiers,$png,$operateur,$comment) = split(/\|/,$_);
			if ($id_evt eq $ligneToRemove) {
				# Ligne trouvée
				my ($evt_annee4,$evt_mois,$evt_jour) = split(/-/,$date);
				$path_png_suppr = "$confStr{MC_RACINE}/$confStr{MC_PATH_IMAGES}/$evt_annee4/$evt_mois";
				$png_suppr = $png;
			} else {
				push(@lignes_restantes,$_);
				push(@liste_png,$png);
			}
		}
		print "<br>$png_suppr need probably to be removed. I will check: ";
		my $suppr = 1;
		for (@liste_png) {
			if ($_ == $png_suppr) {
				$suppr = 0;
			}
		}
		if ($suppr eq 1) { 
			print "<br>Check OK<br>";
			print $cgi->i('Removing '),"$path_png_suppr/$png_suppr<br>";
			my $retRM=qx(/bin/rm -f "$path_png_suppr/$png_suppr");
			print "<br>REMOVING DONE";
		} else {
			print "<br>Check not OK";
			print "<br>NO removing done";
		}
		# Ecrit le nouveau fichier
		open(FILE, ">$fileMC") || die "fichier $fileMC  non trouvé\n";
		print FILE @lignes_restantes;
		close(FILE); 
		print "<br><hr><br>Fichier $fileMC corrigé - <b>DONE</b><br>";
	} else {
		print $cgi->b('PAS DE LIGNE A EFFACER');
		print "<br><hr><br>Fichier $fileMC non modifié - <b>DONE</b><br>";
	}

# Enleve le lock file
# - - - - - - - - - - - - - - - - - - - - - - - - -
	if (-e $lockFile) {
		unlink $lockFile;
	} else {
		print $cgi->b('WARNING: PROBLEME SUR LE LOCK FILE'),"<br>";
	}

	sleep 2;

} else {
		print $cgi->b("Pas d'arguments (fichier, id_evt)");
}
# Re-affiche le tableau
# - - - - - - - - - - - - - - - - - - - - - - - - -
print <<"FIN";
<script language="javascript">window.location.href="/cgi-bin/afficheMC.pl";</script>
</body>
FIN
print $cgi->end_html();
