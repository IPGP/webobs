#!/usr/bin/perl
# vi:enc=utf-8:
# Rajouter l'option -w en cas de debug
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Didier Mallarino
# ------
# Usage: Ce script permet de generer
# un password pour un utilisateur qui souhaite acceder
# au site de l'observatoire
#
# ------------------- RCS Header -------------------------------
# $Header:$
# $Revision:$
# $Author:$
# --------------------------------------------------------------

# ----------------------------------------------------
# -------- Modules externes --------------------------
# ----------------------------------------------------
use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use i18n;

# ----------------------------------------------------
# -------- Modules externes --------------------------
# ----------------------------------------------------
use readConf;
use Webobs;
use checkIP;

# ----------------------------------------------------
# -------- Configuration du site ---------------------
my %confStr=readConfFile;
# -------- Recupere le pied de page ------------------
my @signature=readFile("$confStr{RACINE_DATA_WEB}/$confStr{FILE_SIGNATURE}");
# -------- Controle la validité de l'IP  -------------
my $IP=$ENV{REMOTE_ADDR};
my $ipTest=checkIP($IP);
# if ($ipTest != 0) { die "Formulaire non autorisé"; }
# ----------------------------------------------------

# ----- Lecture de la charte de l'observatoire
my @charte=readFile("$confStr{RACINE_DATA_WEB}/$confStr{CHARTE_SITE_WEB}");

# Debut de l'affichage HTML
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $titrePage="$confStr{OBSERVATOIRE} WEBOBS: $__{'Create a new individual account'}";

# Affichage du Header HTML et du Titre
# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
print $cgi->header(-charset=>'utf-8'),
$cgi->start_html($titrePage);
print <<"FIN";

<!--CODE DE GESTION DU FORMULAIRE-->
<script type="text/javascript">
<!--

function verifForm() {

  if (document.formulaire.name.value == "") {
     alert('Please enter your name!');
     document.formulaire.name.focus();
     return false;
  }
  if (document.formulaire.login.value == "") {
     alert('Please enter your login name!');
     document.formulaire.login.focus();
     return false;
  }
  if (document.formulaire.mail.value == "") {
     alert('Please enter your e-mail address!!');
     document.formulaire.mail.focus();
     return false;
  } else {
     adresse = document.formulaire.mail.value;
     var place = adresse.indexOf("@",1);
     var point = adresse.indexOf(".",place+1);
     if ((place < -1)||(adresse.length <2)||(point < 1)) {
	alert('Please enter a valid e-mail address.');
	return false;
     }
  }
  if (document.formulaire.pass.value == "") {
     alert('Please enter your password!');
     document.formulaire.pass.focus();
     return false;
  }
  if (document.formulaire.pass.value != document.formulaire.pass2.value) {
     alert('The two entered passwords are not the same. Please correct.');
     document.formulaire.pass.focus();
     return false;
  }
  if (document.formulaire.conditions.checked == false) {
     alert('You must accept the terms ! Thanks.');
     document.formulaire.conditions.focus();
     return false;
  }
}

//-->
</SCRIPT>



FIN

print "</head>\n<!-- ********** FIN DU HEAD ************ -->\n";

print <<"FIN";

<!-- ********** DEBUT DU BODY ************ -->
<BODY>
<!-- Affichage des bulles d aide -->
<DIV ID="helpBox"></DIV>

FIN

print "<H1>$titrePage</H1>";

print "<HR>@charte</HR>";

print "<FORM name=\"formulaire\" action=\"/cgi-bin/traitementInscription.pl\" method=\"post\" onSubmit=\"return verifForm()\">
<TABLE>
<tr><td><b>$__{'Full name'}</b></td><td><input type=\"text\" name=\"name\" maxlength=\"30\" size=\"30\"></TD></TR>
<tr><td><b>$__{'Birthday'} (YYYY-MM-DD)</b></td><td><input type=\"text\" name=\"birthday\" maxlength=\"10\" size=\"30\"> (optional)</TD></TR>
<tr><td><b>$__{'E-mail address'}</b></td><tD><input type=\"text\" name=\"mail\" maxlength=\"50\" size=\"30\"></TD></TR>
<tr><td><b>$__{'Login user name'}</b></td><td><input type=\"text\" name=\"login\" maxlength=\"10\" size=\"30\"></TD></TR>
<tr><td><b>$__{'Password'}</b></td><td><input type=\"password\" name=\"pass\" maxlength=\"10\" size=\"30\"></TD></TR>
<tr><td><b>$__{'Password again'}</b></td><td><input type=\"password\" name=\"pass2\" maxlength=\"10\" size=\"30\"></TD></TR>
</TABLE>
<HR>
<P><input type=\"checkbox\" name=\"conditions\" value=\"1\">$__{'I do accept the terms of use'}.</P>
<P>3. <input type=\"submit\" value=\"$__{'Submit'}\"></P>
</FORM>";

print @signature;
