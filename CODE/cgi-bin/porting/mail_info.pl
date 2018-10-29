#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# mail_info.pl
# ------
# Usage: Prepare an information mail based on the Main Courante 
#	(MC) seismological database
#
# Arguments
#	mc= MC conf name (optional)
#	dateStart= Start date (mandatory)
#	dateEnd= End date (mandatory)
#	stat_max_duration= Duration of the biggest VT for the
#		selected time interval (mandatory)
#	stat_max_magnitude= Magnitude of the biggest VT for the
#		selected time interval (mandatory)
#	rockfalls= Number of rockfalls
#	vts= number of VT
#
# 
# Author: Patrice Boissier <boissier@ipgp.fr>
# Acknowledgments:
#       mc3.pl [2004-2011] by Didier Mallarino, Francois
#               Beauducel, Alexis Bosson, Jean-Marie Saurel
# Created: 2012-07-04
#---------------------------------------------------------------


# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use File::Basename;
use Data::Dumper;
use Time::Local;
use POSIX qw/strftime/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);

# ---------- Modules WEBOBS  -------------------------
use readConf;
use Webobs;
use i18n;
use QML;

my %WEBOBS = readConfFile;

my $old_locale = setlocale(LC_NUMERIC);
setlocale(LC_NUMERIC,'C');

# ---------------------------------------------------------------
# ------------ MAIN ---------------------------------------------
# ---------------------------------------------------------------


# - - - - - - - - - - - - - - - - - - - - - - -
# Recuperation des valeurs transmises
# - - - - - - - - - - - - - - - - - - - - - - -
my @parametres = $cgi->url_param();
my $valParams = join(" ",@parametres);

my $debug;
if ($valParams =~ /debug/) {
        $debug = $cgi->url_param('debug');
}


# loads MC3 configuration file
my $mc3 = "";
if ($valParams =~ /mc/) {
        $mc3 = $cgi->url_param('mc');
}
if ($mc3 eq "") {
        $mc3 = $WEBOBS{MC3_DEFAULT_CONF};
}
my %MC3 = readConfFile("$mc3.conf");

# -------- Controle de la validite de l'operateur -------------
my @oper = readUsers;

my $USER = $ENV{"REMOTE_USER"};
my $userID;
my $userLevel = $MC3{GUEST_LEVEL};
for (my $nb = 0; $nb <= $#oper; $nb++) {
        if ($USER eq $oper[$nb][3]) {
                $userID = $nb;
        }
}
if ($userID > 0) {
        $userLevel = $oper[$userID][2];
}
if ($userID eq "") {
        die "WEBOBS: user $USER is unknown. Please contact your administrator. \n";
} elsif ($userLevel < $MC3{DISPLAY_LEVEL}) {
        die "WEBOBS: user '$USER' (".u2l($oper[$userID][1]).") is not allowed to display these data. Sorry!\n";
}


my @infoFiltre = readFile("$WEBOBS{RACINE_DATA_WEB}/$MC3{FILTER_POPUP}");
my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");


# large text string containing all HTML (if display mode)
my $html;

my $dateStart = $cgi->url_param('dateStart');
my $dateEnd = $cgi->url_param('dateEnd');
my $stat_max_duration = $cgi->url_param('stat_max_duration');
my $stat_max_magnitude = $cgi->url_param('stat_max_magnitude');
my $rockfalls = $cgi->url_param('rockfalls');
my $vts = $cgi->url_param('vts');

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
print $cgi->header(-charset=>'utf-8');
print <<"FIN";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8">
    <title>Mail d'information</title>
    <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_CSS}">
    <link rel="stylesheet" type="text/css" href="/css/$MC3{CSS}">
    <script>
      function alertMessage(){
        if(!confirm("Attention, vous allez changer le niveau d'alerte. Etes-vous sur de vouloir modifier le niveau d'alerte?")) {
          document.forms[0].reset();
        }
      }
    </script>
  </head>
  <body>
    <form action="send_email.php" method="GET">
      <h1>OBSERVATOIRE VOLCANOLOGIQUE DU PITON DE LA FOURNAISE</h1>
      <h2>Bilan sismique pour la p&eacute;riode du $dateStart au $dateEnd</h2>
      <h3>Niveau d'alerte en cours : 
        <select name="alerte" onChange="javascript:alertMessage();">
          <option value="alerte_0">Pas d'alerte en cours (Enclos Fouqu&eacute; ouvert)</option>
          <option value="vigilance">Vigilance (Enclos Fouqu&eacute; ouvert)</option>
          <option value="alerte_1">Alerte 1 (Enclos Fouqu&eacute; ferm&eacute;)</option>
          <option value="alerte_2">Alerte 2 (Enclos Fouqu&eacute; ferm&eacute;)</option>
        </select><br/><br/>
      </h3>
      <h3>Nombre d'&eacute;boulements : $rockfalls</h3>
      <h3>Zone(s) concern&eacute;e(s) par les &eacute;boulements :</h3>
      <p>
        <input type="checkbox" name="zone_eb" value="cone_commital"> C&ocirc;ne sommital<br/>
        <input type="checkbox" name="zone_eb" value="enclos"> Enclos Fouqu&eacute;<br/>
        <input type="checkbox" name="zone_eb" value="hors_enclos"> Hors Enclos Fouqu&eacute;<br/>
        <input type="checkbox" name="zone_eb" value="pdn"> Piton des neiges
      </p>
      <h3>Nombre de s&eacute;ismes volcano-tectoniques (VT) : $vts</h3>
      <h3>Zone(s) concern&eacute;e(s) par les VT :</h3>
      <p>
        <input type="checkbox" name="zone_vt" value="cone_commital"> C&ocirc;ne sommital<br/>
        <input type="checkbox" name="zone_vt" value="enclos"> Enclos Fouqu&eacute;<br/>
        <input type="checkbox" name="zone_vt" value="hors_enclos"> Hors Enclos Fouqu&eacute;<br/>
        <input type="checkbox" name="zone_vt" value="pdn"> Piton des neiges
      </p>
      <h3>VT principal:</h3>
      <p>
        <ul>
          <li>Dur&eacute;e : $stat_max_duration s</li>
          <li>Magnitude de dur&eacute;e : $stat_max_magnitude</li>
        </ul>
      </p>
      <h3>Informations compl&eacute;mentaires :</h3>
      <p><textarea rows="6" cols="50" name="commentaires"></textarea></p>
      <input type="hidden" name="dateStart" value="$dateStart"/>
      <input type="hidden" name="dateEnd" value="$dateEnd"/>
      <input type="hidden" name="stat_max_duration" value="$stat_max_duration"/>
      <input type="hidden" name="stat_max_magnitude" value="$stat_max_magnitude"/>
      <input type="hidden" name="rockfalls" value="$rockfalls"/>
      <input type="hidden" name="vts" value="$vts"/>
      <p><input type="submit" value="G&eacute;n&eacute;rer"/></p>
    </form>
  </body>
</html>
FIN


print <<"FIN";
<br>
@signature
</body>
</html>

FIN
