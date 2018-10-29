#!/usr/bin/perl -w
# vi:enc=utf-8:
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Didier Mallarino
# ------
# Usage: Script de traitement du formulaire d'inscription des 
# utilisateurs du site WEB
#
# ------------------- RCS Header -------------------------------
# $Header: /home/alexis/Boulot/cgi-bin/RCS/traitementInscription.pl,v 1.1 2007/05/29 21:59:30 bosson Exp alexis $
# $Revision: 1.1 $
# $Author: bosson $
# --------------------------------------------------------------

use File::Basename;
use CGI;
my $cgi = new CGI;
use i18n;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;


# ----------------------------------------------------
# ---------- Module de configuration  ----------------
# ----------------------------------------------------
use readConf;
my %WEBOBS=readConfFile;
# ----------------------------------------------------

# ---------------------------------------------------------------
# ----------- Sous Routines de lecture des fichiers -------------
# ---------------------------------------------------------------
use Webobs;
# ---------------------------------------------------------------


# Recuperation des donnees du formulaire
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $name = $cgi->param('name');
my $mail = $cgi->param('mail');
my $login = $cgi->param('login');
my $pass = $cgi->param('pass');
my $birthday = $cgi->param('birthday');
my $checkbox = $cgi->param('conditions');

# Si le fichier existe, on fait un backup
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $file="$WEBOBS{RACINE_DATA_DB}/$WEBOBS{BDD_SITE_USERS}";
if (-e $file)  {
	# Creation d'un backup
	system("cp $file $file.TraitementBackup");
} else {
	open(FILE, ">$file") || die "WEBOBS: Problem with the file $file\n";
	print FILE ("");
	close(FILE);
}

# Creation du nouveau fichier trié
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $logincmd=$login;
my $passcmd=$pass;
$logincmd=~s/(["' ()\$#\\])/\\$1/g;
$passcmd=~s/(["' ()\$#\\])/\\$1/g;
my $cmd = u2l("/usr/bin/htpasswd -nb $logincmd $passcmd");
my $encryptedPass=`$cmd`;
my $chaine=u2l("$name|$login|$mail|$birthday|$encryptedPass");
open(FILE, ">>$file") || die "WEBOBS: file $file not found.\n";
print FILE $chaine;
close(FILE);

# Affichage de la page HTML
# - - - - - - - - - - - - - - - - - - - - - - - - -
$title = "WEBOBS-$WEBOBS{OBSERVATOIRE}";
$titlepage = "$__{'Process of new user account'} $title";
print $cgi->header(-charset=>"utf-8"),
	$cgi->start_html($titlepage);
print "<body>";
print $cgi->h1($titlepage);


# Affichage des données transmises
# - - - - - - - - - - - - - - - - - - - - - - - - -
print "<H2>$title: $__{'New user account acknowledgment'}</H2>";
print "<HR>";
print $cgi->b('Full name:  '),$name,"<br>";
print $cgi->b('Mail:  '),$mail,"<br>";
print $cgi->b('User login:  '),$login,"<br>";
#print $cgi->b('Pass:  '),$pass,"<br>";
print $cgi->b('Birthday:  '),$birthday,"<br>";
print "<BR><HR>";
print "Your demand will be processed as soon as the signed web-charte will be received and accepted. You will also receive a single e-mail with your personnal data.<BR><BR>";

# Envoi d'un e-mail aux administrateurs
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $subject="[$title] WEB Access Request $name";
my $destinataires=$WEBOBS{ACCOUNT_MANAGER_EMAIL};
my @ret=qx(echo "$chaine" | mutt -F $WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{EMAIL_CONF_FILE} -s "$subject" "$destinataires");

$subject="[$title] Access request aknowledgment";
my $confirm=u2l("Summary of your personnal data\nFull name: $name\nBirthday: $birthday\nE-mail: $mail\nUser login: $logincmd\nUser password: $passcmd");
@ret=qx(echo "$confirm" | mutt -F $WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{EMAIL_CONF_FILE} -s "$subject" "$mail");


# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->end_html();

