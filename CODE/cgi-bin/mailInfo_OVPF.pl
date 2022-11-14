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
#	RFcount = Number of rockfalls (mandatory)
#	VTcount = number of VT (mandatory)
#
# 
# Author: Patrice Boissier <boissier@ipgp.fr>
# Acknowledgments:
#       mc3.pl [2004-2011] by Didier Mallarino, Francois
#               Beauducel, Alexis Bosson, Jean-Marie Saurel
# Created: 2012-07-04
#---------------------------------------------------------------
#

use strict;
use File::Basename;
use Data::Dumper;
use Time::Local;
use Time::Piece;
use POSIX qw/strftime/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS;
use Email::MIME::CreateHTML;
use HTML::Entities;
use Encode;
use DateTime qw( );

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm $CLIENT);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Wiki;
use WebObs::QML;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
#my $old_locale = setlocale(LC_NUMERIC);
#setlocale(LC_NUMERIC,'C');

# ---- check client's authorization(s) ----------------------------------------
#
die "$__{'Not authorized'} Main Courante" if (!clientHasRead(type=>"authprocs",name=>"MC"));

# ---- 1st parse query parameters for configuration file and debug option -----
#
my $QryParm  = $cgi->Vars;
$QryParm->{'debug'}     ||= "";
$QryParm->{'mc'}        ||= $WEBOBS{MC3_DEFAULT_NAME};

# ---- read in configuration + info files -------------------------------------
#
my %MC3        = readCfg("$WEBOBS{ROOT_CONF}/$QryParm->{'mc'}.conf");
my $mc3        = $QryParm->{'mc'};

my @infoFiltre = readFile("$MC3{FILTER_POPUP}");
my @infoTexte  = readFile("$MC3{NOTES}");

###############################################################################
## ---- parse remainder of query parameters ------------------------------------
##
#$QryParm->{'y1'}        ||= "";
#$QryParm->{'m1'}        ||= "";
#$QryParm->{'d1'}        ||= "";
#$QryParm->{'y2'}        ||= "";
#$QryParm->{'m2'}        ||= "";
#$QryParm->{'d2'}        ||= "";
#$QryParm->{'type'}      ||= "";
#$QryParm->{'duree'}     ||= "";
#$QryParm->{'amplitude'} ||= "";
#$QryParm->{'location'}  //= $MC3{DISPLAY_LOCATION_DEFAULT};
#$QryParm->{'obs'}       ||= "";
#$QryParm->{'graph'}     ||= "movsum";
#$QryParm->{'dump'}      ||= "";
#$QryParm->{'trash'}     ||= "";
###############################################################################

# - - - - - - - - - - - - - - - - - - - - - - -
# Recuperation des valeurs transmises
# - - - - - - - - - - - - - - - - - - - - - - -
my @parametres = $cgi->url_param();
my $valParams = join(" ",@parametres);

my $debug;
if ($valParams =~ /debug/) {
        $debug = $cgi->url_param('debug');
}

my $dateStart = $cgi->url_param('dateStart');
my $dateEnd = $cgi->url_param('dateEnd');
my $stat_max_duration = $cgi->url_param('stat_max_duration');
my $stat_max_magnitude = $cgi->url_param('stat_max_magnitude');
$stat_max_magnitude =~ s/,/\./;
$stat_max_magnitude = sprintf '%.2f', $stat_max_magnitude;
my $comptabilisesRockfall = $cgi->url_param('RFcount');
my $comptabilisesVT = $cgi->url_param('VTcount');
my $alert = $cgi->url_param('alert');
my $comment = $cgi->url_param('comment');
my $send = $cgi->url_param('send');
my @zones_rockfall = $cgi->url_param('zone_rockfall');
my @zones_vt = $cgi->url_param('zone_vt');
my @comments_geodesy = $cgi->url_param('comment_geodesy');
my $comments_geochemistry = $cgi->url_param('comment_geochemistry');
if ($comments_geochemistry eq "") {
	$comments_geochemistry = "Géochimie non renseignée.";
}
my @mail = $cgi->url_param('mail');

my @infoFiltre = readFile("$MC3{FILTER_POPUP}");
my @signature = readFile("$WEBOBS{FILE_SIGNATURE}");

my @typeAlerts = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{ALERTS_CODES_CONF}");
my @typeZones = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{ZONES_CODES_CONF}");
my @commentsGeodesy = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{COMMENTS_GEODESY_CONF}");

my $dateEndFrench = substr($dateEnd,8,2)."-".substr($dateEnd,5,2)."-".substr($dateEnd,0,4); 
my $dateStartFrench = substr($dateStart,8,2)."-".substr($dateStart,5,2)."-".substr($dateStart,0,4); 
my $timePeriod = "Bilan du $dateEnd";
my $timePeriodHTML = "Bulletin pr&eacute;liminaire d'activit&eacute; du $dateEndFrench";
my $yesterday = DateTime->now()->subtract( days => 1 )->strftime('%Y-%m-%d');

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if (($dateStart ne $dateEnd || $yesterday ne $dateEnd)  && !defined($send)) {
	print $cgi->header(-charset=>'utf-8');
	print <<"PART1";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8">
    <title>Bulletin d'information ReVoSiMa</title>
    <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
    <link rel="stylesheet" type="text/css" href="/css/$MC3{CSS}">
  </head>
  <body>
    <h1>Le bulletin ne doit concerner qu'une journee, celle de la veille : $yesterday.</h1>
  </body>
</html>
PART1

} elsif (defined($send)) {
	my $html;
	#my $outputFilename = '/tmp/bulletin.html';
	my $outputFilename = '/home/sysop/bulletin/bulletin.html';
	my $htmlOutput = "";
	my $htmlBrowser = "";
	my $htmlMail = "";
	my %alerts;
	for (@typeAlerts) {
		my @liste = split(/\|/,$_);
		$alerts{$liste[0]} = $liste[1];
	}
        my %geodesy;
        for (@commentsGeodesy) {
                my @liste = split(/\|/,$_);
                $geodesy{$liste[0]} = $liste[2];
        }

	print $cgi->header(-charset=>'utf-8');

	$html = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">';
	$html .= '<html>';
	$html .= '  <head>';
	$html .= '    <meta http-equiv="content-type" content="text/html; charset=utf-8">';
	$html .= '    <title>Bulletin d\'information</title>';
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= "    <link rel=\"stylesheet\" type=\"text/css\" href=\"./css/VOLCANO.css\">";
	$htmlBrowser .= "    <link rel=\"stylesheet\" type=\"text/css\" href=\"/css/VOLCANO.css\">";
	$html = '  </head>';
	$html .= '  <body>';
	$html .= '  <div id="container">';
	$html .= '    <h1>Observatoire Volcanologique du Piton de La Fournaise</h1>';
	$html .= '    <hr>';
	$html .= '    <div id="nav">';
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= '      <img src=./images/logo-ovpf.png>';
	$htmlBrowser .= '      <img src=http://195.83.188.56/icons/logo-ovpf.png>';
	$html = '    </div>';
	$html .= '    <div id="content">';
	$html .= "    <h2>$timePeriodHTML</h2>";
	my $dateBulletin = localtime->strftime('%d-%m-%Y %H:%M:%S');
	$html .= "    <p>Bulletin cr&eacute;&eacute; le $dateBulletin TU.</p>";
	$html .= "    <p id=\"warning\">Ce bulletin est issu de l'examen pr&eacute;liminaire quotidien des derni&egrave;res donn&eacute;es. Ces informations n'ont pas toutes &eacute;t&eacute; valid&eacute;es et sont susceptibles d'&eacute;voluer.<br/>Pour une information compl&egrave;te, veuillez vous reporter aux <a href=\"http://www.ipgp.fr/fr/dernieres-actualites/344\">Bulletins d'Activit&eacute; valid&eacute;s de l'observatoire.</a></p>";
	$html .= '    <hr>';
	$html .= '    <p>';
	$html .= '      <b>Piton de la Fournaise</b><br/>';
	$html .= '      21&deg;14\'38" S<br/>';
	$html .= '      55&deg;42\'29" E<br/>';
	$html .= '      Altitude : 2632m<br/>';
	$html .= '    </p>';
	$html .= '    <hr>';
	$html .= '    <p>';
	$html .= "      Niveau d'alerte : <b>$alerts{$alert}</b>";
	$html .= '    </p>';
	$html .= '    <hr>';
	my %zones;
	for (@typeZones) {
		my @liste = split(/\|/,$_);
		$zones{$liste[0]} = $liste[1];
        }
	$html .= '    <h3>Sismologie</h3>';
	
	my $subject = "[ovpf_bulletin] $timePeriod"; 
	$html .= "<p>- Nombre d'&eacute;boulements du $dateEndFrench : <b>$comptabilisesRockfall</b><br/>";
	if($#zones_rockfall >= 0) {
		if($#zones_rockfall == 0) {
			$html .= "Zone concern&eacute;e par les &eacute;boulements :<br/>";
		} else {
			$html .= "Zones concern&eacute;es par les &eacute;boulements :<br/>";
		}
		$html .= "<ul>";
		for (@zones_rockfall) {
			$html .= "<li>$zones{$_}</li>";
		}
		$html .= "</ul>";
		$html .= "</p>";
	}
	$html .= "<p>- Nombre de s&eacute;ismes volcano-tectoniques (VT) du $dateEndFrench : <b>$comptabilisesVT</b><br/>";
	if($#zones_vt >= 0) {
		if($#zones_vt == 0) {
			$html .= "Zone concern&eacute;e par les VT :<br/>";
		} else {
			$html .= "Zones concern&eacute;es par les VT :<br/>";
		}
		$html .= "<ul>";
		for (@zones_vt) {
			$html .= "<li>$zones{$_}</li>";
		}
		$html .= "</ul>";
		$html .= "</p>";
	}
	$html .= "<p>- S&eacute;isme volcano-tectonique de plus grande magnitude du $dateEndFrench :<br/>";
	$html .= "<ul>";
	$html .= "<li>Dur&eacute;e : $stat_max_duration s</li>";
	$html .= "<li>Magnitude de dur&eacute;e : $stat_max_magnitude</li>";
	$html .= "</ul>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= "<a href=\"./graphs/Reunion_02m.png\"><img src=\"./graphs/Reunion_02m.png\" width=\"300\"/></a>";
	$htmlBrowser .= "<a href=\"http://195.83.188.56/OUTG/PROC.HYPO/graphs/Reunion_02m.png\"><img src=\"http://195.83.188.56/OUTG/PROC.HYPO/graphs/Reunion_02m.png\" width=\"300\"/></a>";
	$html = "</p>";
	$htmlMail .= $html;
        $html .= "<p id=legend>";
	$html .= "Carte de localisation (&eacute;picentres) et coupes nord-ouest - sud-est et sud-ouest - nord-est (montrant la localisation en profondeur, hypocentres) des s&eacute;ismes enregistr&eacute;s et localis&eacute;s par l'OVPF-IPGP sur 2 mois sous La R&eacute;union. Seuls les s&eacute;ismes localisables ont &eacute;t&eacute; repr&eacute;sent&eacute;s sur la carte.<br/>";
	$html .= "L'observatoire enregistre des &eacute;v&egrave;nements sismiques non repr&eacute;sent&eacute;s sur cette carte car non localisables, en raison de leur trop faible magnitude.<br/>Pour prendre connaissance du nombre de s&eacute;ismes d&eacute;tect&eacute;s par les r&eacute;seaux de l'observatoire, vous pouvez vous reporter à son dernier <a href=\"http://www.ipgp.fr/fr/dernieres-actualites/344\">Bulletin d'Activit&eacute;.</a><br/>";
	$html .= "La sismicit&eacute; d&eacute;termin&eacute;e et valid&eacute;e en continu par l'OVPF-IPGP peut &ecirc;tre &eacute;galement suivie sur le <a href=\"https://renass.unistra.fr/fr/zones/la-reunion/\">portail RENASS.</a>";
	$html .= "</p>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;

        $html = "<h3>D&eacute;formations</h3><p>";
        for (@comments_geodesy) {
                $html .= "      - $geodesy{$_}<br/><br/>";
        }
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= " <table><tr><td><a href=\"./graphs/BASELINES_01y.png\"><img src=\"./graphs/BASELINES_01y.png\" width=\"300\"/></a></td>";
	$htmlOutput .= " <td><a href=\"./graphs/LocalisationBaselines.jpg\"><img src=\"./graphs/LocalisationBaselines.jpg\" height=\"245\"/></a></td><tr></table>";
	$htmlBrowser .= "<table><tr><td><a href=\"http://195.83.188.56/OUTG/PROC.GIPSYX/graphs/BASELINES_01y.png\"><img src=\"http://195.83.188.56/OUTG/PROC.GIPSYX/graphs/BASELINES_01y.png\" width=\"300\"/></a></td></tr></table>";
        $html = "</p>";
	$htmlMail .= $html;
        $html .= "<p id=legend>";
        $html .= "Illustration de la d&eacute;formation sur 1 an. Sont ici repr&eacute;sent&eacute;es des lignes de base (variation de distance entre deux r&eacute;cepteurs GPS) traversant l'&eacute;difice du Piton de la Fournaise, au sommet (en haut), &agrave; la base du c&ocirc;ne terminal (au milieu) et en champ lointain (en bas) (cf. localisation sur les cartes associ&eacute;es). Une hausse est synonyme d'élongation et donc de gonflement du volcan;inversement une diminution est synonyme de contraction et donc de d&eacute;gonflement du volcan. Les &eacute;ventuelles p&eacute;riodes colori&eacute;es en rose clair correspondent aux &eacute;ruptions.";
        $html .= "</p>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;

        $html = "<h3>G&eacute;ochimie</h3>";
        $comments_geochemistry = encode_entities(decode('utf8', $comments_geochemistry));
	$comments_geochemistry =~ s;\n;<br/>;g;
        $html .= "<p>$comments_geochemistry</p>";
	if ($comment ne "") {
		$html .= "<h3>Informations compl&eacute;mentaires</h3>";
		$comment = encode_entities(decode('utf8', $comment));
		$comment =~ s;\n;<br/>;g;
		$html .= "<p>$comment</p>";
	}
	$html .= '    <hr>';
	$html .= "<h3>Glossaire</h3>";
	$html .= "<p>
	          - S&eacute;isme volcano-tectonique sommital : s&eacute;isme localis&eacute; au dessus du niveau de la mer &agrave; l'aplomb du sommet du volcan.<br/>
                  - S&eacute;isme volcano-tectonique profond : s&eacute;isme localis&eacute; sous le niveau de la mer &agrave; l'aplomb du volcan.<br/>
                  - S&eacute;isme local : s&eacute;isme localis&eacute; dans un rayon de 200km de l'&icirc;le.<br/>
                  - Signaux GPS sommitaux: t&eacute;moin de l'influence de sources de pression superficielles &agrave; l'aplomb du volcan.<br/>
                  - Signaux GPS lointains: t&eacute;moin de l'influence de sources de pression profondes &agrave; l'aplomb du volcan.
	          </p>";
        $html .= "    </div>";
        $html .= "  </div>";
        $html .= "  </body>";
        $html .= "</html>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;

	print "$htmlBrowser";

	print "Debut ECRITURE BULLETIN";
	#open(my $fh, '>', $outputFilename) or die "Could not open file '$outputFilename' $!";
	open(my $fh, '>', $outputFilename) or print "Could not open file '$outputFilename' $!";
	print $fh $htmlOutput;
	close $fh;
	print "Fin ECRITURE BULLETIN";

#	print "Envoie du mail";

	my $from = $MC3{MAIL_FROM};
	my $smtpServer = $MC3{MAIL_SMTP_SERVER};
	my $smtpPort = $MC3{MAIL_SMTP_PORT};
	my $user = $MC3{MAIL_USER};
	my $passwd = $MC3{MAIL_PASSWD};

	my $mailList = '';
	my @mailConf = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{MAIL_INFO_CONF}");
	for (@mailConf) {
		my @liste = split(/\|/,$_);
		my %hash;
		@hash{@mail}=();
		if (exists $hash{$liste[0]}){
			if ($mailList eq '') {
				$mailList = $mailList.$liste[4]
			} else {
				$mailList = $mailList.','.$liste[4]
			}
		}
	}
	
	my $message = Email::MIME->create_html(
		header => [
			From => $from,
			'Reply-To' => $from,
			Subject => $subject,
			Type    => 'text/html; charset=UTF-8',
		],
		body => $htmlMail,
	);
	
	my @mailingList = split(/,/,$mailList);
	for(@mailingList) {
		if($MC3{MAIL_USE_SMTP}) {
			my $transport = Email::Sender::Transport::SMTP::TLS->new(
				host     => $smtpServer,
				port     => $smtpPort,
				username => $user,
				password => $passwd,
			);
			sendmail($message, { from => $from, to => $_, transport => $transport});
		} else {
			sendmail($message, { from => $from, to => $_});
		}
	}
} else {
	print $cgi->header(-charset=>'utf-8');
	print <<"PART1";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8">
    <title>Bulletin d'information</title>
    <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
    <link rel="stylesheet" type="text/css" href="/css/$MC3{CSS}">
    <script>
      function alertMessage(){
        if(!confirm("Attention, vous allez changer le niveau d'alerte. Etes-vous sur de vouloir modifier le niveau d'alerte?")) {
          document.forms[0].reset();
        }
      }
      function validateAlert(){
        var alerte = document.forms[0]["alert"].value;
        if (alerte == "NOALERT") {
          alert("Le niveau d'alerte doit etre defini");
          return false;
        }
      }
    </script>
  </head>
  <body>
<!--    <form action="$MC3{CGI_MAIL_INFO}" onsubmit="return validateAlert()" method="GET"> -->
    <form action="mailInfo_OVPF.pl" onsubmit="return validateAlert()" method="GET">
      <h1>$WEBOBS{WEBOBS_TITLE}</h1>
      <h2>$timePeriodHTML</h2>
      <h3>Niveau d'alerte en cours : 
        <select name="alert" onChange="javascript:alertMessage();">
PART1

	for (@typeAlerts) {
		my @liste = split(/\|/,$_);
		print "<option value=\"$liste[0]\">$liste[1]</option>\n";
	}

	print <<"PART2";
        </select><br/><br/>
      </h3>
      <h3>Nombre d'&eacute;boulements : $comptabilisesRockfall</h3>
      <h3>Zone(s) concern&eacute;e(s) par les &eacute;boulements :</h3>
      <p>
PART2

	for (@typeZones) {
		my @liste = split(/\|/,$_);
		print "<input type=\"checkbox\" name=\"zone_rockfall\" value=\"$liste[0]\"/>$liste[1]\n";
	}

	print <<"PART3";
      </p>
      <h3>Nombre de s&eacute;ismes volcano-tectoniques (VT) : $comptabilisesVT</h3>
      <h3>Zone(s) concern&eacute;e(s) par les VT :</h3>
      <p>
PART3

	for (@typeZones) {
		my @liste = split(/\|/,$_);
		print "<input type=\"checkbox\" name=\"zone_vt\" value=\"$liste[0]\"/>$liste[1]\n";
	}

	print <<"PART4";
      </p>
      <h3>VT principal:</h3>
      <p>
        <ul>
          <li>Dur&eacute;e : $stat_max_duration s</li>
          <li>Magnitude de dur&eacute;e : $stat_max_magnitude</li>
        </ul>
      </p>
PART4
        print <<"PART51";
      </p>
      <h3>Commentaire geodesie:</h3>
      <p>
PART51
	my $category = -1;
        for (@commentsGeodesy) {
                my @liste = split(/\|/,$_);
		if ($category != $liste[3]) {
			if ($category != -1) {
				print "</select>";
			}
			print "<select name=\"comment_geodesy\">";
			$category = $liste[3];
		}
                print "<option value=\"$liste[0]\">$liste[1]</option>\n";
        }
        print <<"PART52";
        </select><br/><br/>
PART52
        print <<"PART61";
      </p>
      <h3>Commentaire geochimie:</h3>
      <p><textarea rows="6" cols="50" name="comment_geochemistry"></textarea></p>
      <p>
PART61
	print <<"PART7";
      <h3>Informations compl&eacute;mentaires :</h3>
      <p><textarea rows="6" cols="50" name="comment"></textarea></p>
      <h3>Destinataires :</h3>
      <p>
PART7

	my @mails = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{MAIL_INFO_CONF}");
	for (@mails) {
		my @liste = split(/\|/,$_);
		if ($liste[3] == 1) {
			if ($liste[2] == 1) {
				print "<input type=\"checkbox\" checked=\"checked\" name=\"mail\" value=\"$liste[0]\"/>$liste[1]<br/>\n";
			} else {
				print "<input type=\"checkbox\" name=\"mail\" value=\"$liste[0]\"/>$liste[1]<br/>\n";
			}
		}
	}

	print <<"PART5";
      <input type="hidden" name="dateStart" value="$dateStart"/>
      <input type="hidden" name="dateEnd" value="$dateEnd"/>
      <input type="hidden" name="stat_max_duration" value="$stat_max_duration"/>
      <input type="hidden" name="stat_max_magnitude" value="$stat_max_magnitude"/>
      <input type="hidden" name="RFcount" value="$comptabilisesRockfall"/>
      <input type="hidden" name="VTcount" value="$comptabilisesVT"/>
      <br/><input type="submit" name="send" value="Envoyer"/></p>
    </form>
<br>
@signature
</body>
</html>
PART5
}
