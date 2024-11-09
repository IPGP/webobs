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
use LWP::UserAgent;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm $CLIENT);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Wiki;
use Locale::TextDomain('webobs');
use WebObs::QML;
use Switch;

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
my @dateStartElements = split(/-/,$dateStart);
my $dateEnd = $cgi->url_param('dateEnd');
my @dateEndElements = split(/-/,$dateEnd);

my $mc3URL = "https://ovs.ipgp.fr/cgi-bin/mc3.pl";
my $user = 'boissier';
my $pass = 'or4OU8di';
my $ua = new LWP::UserAgent;

# DERNIER SEISME RESSENTI
my @date1 = ('2020','01','01','00');
my @date2 = ($dateEndElements[0],$dateEndElements[1],$dateEndElements[2],'23');
my $req = new HTTP::Request(GET => "$mc3URL?slt=0&y1=$date1[0]&m1=$date1[1]&d1=$date1[2]&h1=$date1[3]&y2=$date2[0]&m2=$date2[1]&d2=$date2[2]&h2=$date2[3]&type=ALL&duree=ALL&ampoper=eq&amplitude=ALL&obs=ressenti&locstatus=0&located=0&mc=MC3_Mayotte&dump=bul&newts=&graph=movsum");
$req->authorization_basic($user, $pass);
my $response = $ua->request($req);
my $content = "";
if ($response->is_success) {
    $content = $response->decoded_content();
}
my @lines = split(/\n/, $content);
my @elements = split(/;/, $lines[-1]);
my $date_felt = $elements[0];
$date_felt = substr($date_felt, 6, 2)."-".substr($date_felt,4,2)."-".substr($date_felt,0,4)." ".substr($date_felt,9,2).":".substr($date_felt,11,2).":".substr($date_felt,13,2);
my $magnitude_felt = sprintf '%.2f', $elements[4];
my $lat_felt = sprintf '%.4f', $elements[6];
my $lon_felt = sprintf '%.4f', $elements[5];
my $depth_felt = sprintf '%.2f', $elements[7];
my $loc_felt = "Latitude : $lat_felt - Longitude : $lon_felt";

# EVENEMENTS DE LA VEILLE

$req = new HTTP::Request(GET => "$mc3URL?slt=0&y1=$dateStartElements[0]&m1=$dateStartElements[1]&d1=$dateStartElements[2]&h1=00[3]&y2=$dateEndElements[0]&m2=$dateEndElements[1]&d2=$dateEndElements[2]&h2=23&type=ALL&duree=ALL&ampoper=eq&amplitude=ALL&obs=VOLCVT|VOLCVLP|VOLCLP&locstatus=0&located=0&mc=MC3_Mayotte&dump=bul&newts=&graph=movsum");

$req->authorization_basic($user, $pass);
$response = $ua->request($req);
$content = "";
if ($response->is_success) {
    $content = $response->decoded_content();
}
@lines = split(/\n/, $content);
my $comptabilisesVLP = 0;
my $comptabilisesLP = 0;
my $comptabilisesVT = 0;
my $stat_max_duration = 0;
my $stat_max_magnitude = 0;
for my $line (@lines){
    my @lineElements = split(/;/, $line);
    switch ($lineElements[8]) {
        case "VOLCVT"          {
            $comptabilisesVT++;
            if ($lineElements[2] > $stat_max_duration) {
                $stat_max_duration = $lineElements[2];
                if ($lineElements[4] eq "") {
                    $stat_max_magnitude = "Non calcul&eacute;e";
                } else {
                    $stat_max_magnitude = sprintf '%.2f', $lineElements[4];
                }
            }
        }
        case "VOLCLP"          {$comptabilisesLP++;}
        case "VOLCVLP"         {$comptabilisesVLP++;}
    }
}

my $alert = $cgi->url_param('alert');
my $comment = $cgi->url_param('comment');
my $send = $cgi->url_param('send');
my @comments_geodesy = $cgi->url_param('comment_geodesy');
my $comments_geochemistry = $cgi->url_param('comment_geochemistry');
if ($comments_geochemistry eq "") {
	$comments_geochemistry = "G&eacute;ochimie non renseign&eacute;e.";
}
my @mail = $cgi->url_param('mail');

#my @infoFiltre = readFile("$MC3{FILTER_POPUP}");
my @signature = readFile("$WEBOBS{FILE_SIGNATURE}");

my @typeAlerts = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{ALERTS_CODES_REVOSIMA_CONF}");
my @typeZones = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{ZONES_CODES_REVOSIMA_CONF}");
my @commentsGeodesy = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{COMMENTS_GEODESY_REVOSIMA_CONF}");

my $dateEndFrench = substr($dateEnd,8,2)."-".substr($dateEnd,5,2)."-".substr($dateEnd,0,4); 
my $dateStartFrench = substr($dateStart,8,2)."-".substr($dateStart,5,2)."-".substr($dateStart,0,4); 
my $timePeriod = "Bilan du $dateEnd";
my $timePeriodHTML = "Bulletin pr&eacute;liminaire d'activit&eacute; du $dateEndFrench";

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if ($dateStart ne $dateEnd && !defined($send)) {
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
    <h1>Le bulletin ne doit concerner qu'une journée</h1>
  </body>
</html>
PART1
	
} elsif (defined($send)) {
	my $html;
	my $outputFilename = '/opt/php/bulletin/bulletin.html';
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
	$htmlBrowser .= "    <link rel=\"stylesheet\" type=\"text/css\" href=\"/php/bulletin/css/VOLCANO.css\">";
        $html = '    <script>
function showCredits() {
  var x = document.getElementById("revocredits");
  x.style.display = "none";
  if (x.style.display === "none") {
    x.style.display = "block";
  } else {
    x.style.display = "none";
  }
} 
                      </script>'; 
	$html .= '  </head>';
	$html .= '  <body>';
	$html .= '  <div id="container">';
	$html .= '    <h1>R&eacute;seau de surveillance Volcanologique et Sismologique de Mayotte</h1>';
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$html = '    <hr>';
	$html .= '    <div id="nav">';
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= '      <img src=./images/revosima.png>';
	$htmlBrowser .= '      <img src=/php/bulletin/images/revosima.png>';
	$html = '    </div>';
	$html .= '    <div id="content">';
	$html .= "    <h2>$timePeriodHTML</h2>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= '      <img src=./images/partenaires.png align="right" width=700>';
	$htmlBrowser .= '      <img src=/php/bulletin/images/partenaires.png align="right" width=700>';
	my $dateBulletin = localtime->strftime('%d-%m-%Y %H:%M:%S');
	$html = "    <p>Bulletin cr&eacute;&eacute; le $dateBulletin TU.</p>";
	$html .= "    <p id=\"warning\">Ce bulletin est issu de l'examen pr&eacute;liminaire quotidien des derni&egrave;res donn&eacute;es par un.e analyste du REVOSIMA. Ces informations n'ont pas toutes &eacute;t&eacute; valid&eacute;es et sont susceptibles d'&eacute;voluer.<br/>Pour une information compl&egrave;te, veuillez vous reporter aux <a href=\"http://www.ipgp.fr/fr/actualites-reseau\">Actualit&eacute;s du r&eacute;seau valid&eacute;es.</a></p>";
	$html .= '    <hr>';
	$html .= '    <h3>Activit&eacute;</h3>';
	$html .= '    <p>';
        $html .= '      <b>Ev&egrave;nement en cours :</b> &eacute;ruption sous-marine tr&egrave;s probablement toujours en cours &agrave; 50-60 km &agrave; l\'Est de Mayotte avec sismicit&eacute; et d&eacute;formations associ&eacute;es. ';
	$html .= '    </p>';
	$html .= '    <p>';
        $html .= "      Derni&egrave;re preuve sans &eacute;quivoque d'activit&eacute; &eacute;ruptive : autour du 20 ao&ucirc;t 2019";
	$html .= '    </p>';
	$html .= '    <p>';
	$html .= "      <b>Site &eacute;ruptif actuel (au 20-08-2019)</b><br/>";
	$html .= '      Edifice principal : latitude : -12&deg;54\' ; longitude : 45&deg;43\'<br/>';
	$html .= '      Hauteur : au moins 800 m<br/>';
	$html .= '      Profondeur &agrave; la base du site &eacute;ruptif : -3500 m<br/>';
	$html .= '    </p>';
        $html .= '    <hr>';
        $html .= '    <p>';
        $html .= "      Niveau d'alerte : <b>$alerts{$alert}</b>";
        $html .= '    </p>';
        $html .= '    <hr>';
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	#$htmlOutput .= '      <img src=./images/frise.jpg width="700"/>';
	#$htmlBrowser .= '      <img src=/php/bulletin/images/frise.jpg width="700"/>';
	$html = '    <h3>Sismologie</h3>';
	
	my $subject = "$timePeriod";
	$html .= "<p>- Nombre de signaux sismiques de type tr&egrave;s longue p&eacute;riode VLP (tr&egrave;s basse fr&eacute;quence, entre 0,01Hz et 0,2Hz) du $dateEndFrench : <b>$comptabilisesVLP</b></p>";
	$html .= "<p>- Nombre de signaux sismiques de type longue p&eacute;riode LP (basse fr&eacute;quence, entre 0,5Hz et 5Hz) du $dateEndFrench : <b>$comptabilisesLP</b></p>";
	$html .= "<p>- Nombre de s&eacute;ismes volcano-tectoniques VT (s&eacute;ismes dont la gamme de fr&eacute;quence est la plus large, de 2Hz &agrave; 40Hz) du $dateEndFrench : <b>$comptabilisesVT</b></p>";
	$html .= "<p>- S&eacute;isme volcano-tectonique de plus grande magnitude du $dateEndFrench :<br/>";
	$html .= "<ul>";
	$html .= "<li>Dur&eacute;e : $stat_max_duration s</li>";
	$html .= "<li>Magnitude (MLv) : $stat_max_magnitude</li>";
	$html .= "</ul></p>";
	$html .= "<p>- Dernier s&eacute;isme ressenti :<br/>";
	$html .= "<ul>";
	$html .= "<li>Date : $date_felt</li>";
	$html .= "<li>Magnitude (MLv) : $magnitude_felt</li>";
	$html .= "<li>Profondeur : $depth_felt km</li>";
	$html .= "<li>Localisation : $loc_felt</li>";
	$html .= "</ul></p>";
	$html .= "<p id=legend>Il est fondamental de reporter tout s&eacute;isme ressenti au BCSF-RENASS sur le site : <a href=http://www.franceseisme.fr/>http://www.franceseisme.fr</a></p>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;
	$htmlMail .= $html;
	$htmlOutput .= "<a href=\"./graphs/sismo.png\"><img src=\"./graphs/sismo.png\" width=\"700\"/></a>";
	$htmlBrowser .= "<a href=\"/php/bulletin/graphs/sismo.png\"><img src=\"/php/bulletin/graphs/sismo.png\" width=\"700\"/></a>";
	$html = "</p>";
	$htmlMail .= $html;
        $html .= "<p id=legend>";
	$html .= "Carte de localisation des &eacute;picentres (± 5 km) des s&eacute;ismes volcano-tectoniques avec les r&eacute;seaux sismiques &agrave; terre (IPGP-IFREMER-CNRS-BRGM-BCSF-R&eacute;NaSS, IPGS) au cours du dernier mois (&eacute;chelle temporelle de couleur). Sont aussi repr&eacute;sent&eacute;es une projection des hypocentres des s&eacute;ismes le long de coupes transverses et axiales le long de la ride montrant la localisation estim&eacute;e en profondeur (pr&eacute;cision variant entre +-5km et +-15km) des s&eacute;ismes en fonction de la magnitude (taille des symboles) et de la date (&eacute;chelle temporelle de couleur). &copy;OVPF-IPGP / REVOSIMA";
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
	$htmlOutput .= " <table><tr><td><a href=\"./graphs/gnss.png\"><img src=\"./graphs/gnss.png\" width=\"700\"/></a></td></tr></table>";
	$htmlBrowser .= "<table><tr><td><a href=\"/php/bulletin/graphs/gnss.png\"><img src=\"/php/bulletin/graphs/gnss.png\" width=\"700\"/></a></td></tr></table>";
        $html = "</p>";
	$htmlMail .= $html;
        $html .= "<p id=legend>";
        $html .= "D&eacute;placements (en cm) enregistr&eacute;s sur 9 stations GPS localis&eacute;s &agrave; Mayotte (BDRL, GAMO, KAWE, KNKL, MAYG, MTSA, MTSB, PMZI, PORO), 1 station &agrave; Grande Glorieuse (GLOR) et 1 station au nord de Madagascar &agrave; Diego Suarez (DSUA) sur les composantes est (en haut), nord (au milieu) et vertical (en bas) depuis le 22 d&eacute;cembre 2013 pour visualiser une longue s&eacute;rie temporelle ant&eacute;-crise. Post-traitement de ces donn&eacute;es r&eacute;alis&eacute; par l'IPGP. &copy;OVPF-IPGP / REVOSIMA.";
        $html .= "</p>";
	$htmlOutput .= $html;
	$htmlBrowser .= $html;

        $html = "";
        #$html .= "<h3>G&eacute;ochimie</h3>";
        #$comments_geochemistry = encode_entities(decode('utf8', $comments_geochemistry));
	#$comments_geochemistry =~ s;\n;<br/>;g;
        #$html .= "<p>$comments_geochemistry</p>";
	if ($comment ne "") {
		$html .= "<h3>Informations compl&eacute;mentaires</h3>";
		$comment = encode_entities(decode('utf8', $comment));
		$comment =~ s;\n;<br/>;g;
		$html .= "<p>$comment</p>";
	}
	$html .= '    <hr>';
	$html .= "<h3>Contexte</h3><br/>";
	$html .= "<p>
                  <ul><li>
                  <b>Activit&eacute; &eacute;ruptive:</b> Du 2 au 18 mai 2019, une campagne oc&eacute;anographique (MD220-MAYOBS-1) sur le Marion Dufresne a permis la d&eacute;couverte d'un nouveau site &eacute;ruptif sous-marin &agrave; 50 km &agrave; l'est de Mayotte qui a form&eacute; un &eacute;difice d'environ 820 m de hauteur sur le plancher oc&eacute;anique situ&eacute; &agrave; 3500m de profondeur d'eau. Les campagnes (MD221-MAYOBS-2 - 10-17 juin 2019 ; MD222-MAYOBS-3 - 13-14 juillet 2019 ; MD223-MAYOBS-4 - 19-31 juillet 2019 ; mission SHOM-MAYOBS-5 20-21 ao&ucirc;t 2019) ont mis en &eacute;vidence de nouvelles coul&eacute;es de lave, au sud, &agrave; l'ouest et au nord du nouveau site &eacute;ruptif. Des panaches acoustiques (700 &agrave; 1000 m de haut) de nature hydrothermale et/ou magmatique, ont &eacute;t&eacute; d&eacute;tect&eacute;s dans la colonne d'eau au-dessus des coul&eacute;es actives, ainsi qu'au-dessus de la structure volcanique ancienne dite du \"Fer &agrave; cheval \" situ&eacute;e &agrave; l'aplomb de la zone de l'essaim sismique principal (5-15 km &agrave; l'est de Petite-Terre). En l'&eacute;tat actuel des connaissances, le nouveau site &eacute;ruptif a produit au moins 5,1 km3 de lave depuis le d&eacute;but de son &eacute;dification avec des flux qui ont vari&eacute;s, d'environ 45 &agrave; 200 m3/s. Ces volumes et flux &eacute;ruptifs, notamment au d&eacute;but de la crise, sont exceptionnels et sont, malgr&eacute; les incertitudes, parmi les plus &eacute;lev&eacute;s observ&eacute;s sur un volcan effusif depuis l'&eacute;ruption du Laki (Islande) en 1783.<br/><br/>
                  </li><li>
                  <b>Sismicit&eacute;:</b> l'archipel des Comores se situe dans une r&eacute;gion sismique consid&eacute;r&eacute;e comme mod&eacute;r&eacute;e. Depuis mai 2018, la situation volcano-tectonique a &eacute;volu&eacute;. Une activit&eacute; sismique affecte l'&icirc;le de Mayotte depuis le d&eacute;but du mois de mai 2018 (Lemoine et al., en r&eacute;vision). Ces s&eacute;ismes forment deux essaims avec des &eacute;picentres regroup&eacute;s en mer, entre 5 et 15 km &agrave; l'est de Petite-Terre pour l'essaim sismique principal, et &agrave; 25 km &agrave; l'est de Petite-Terre pour le secondaire, &agrave; des profondeurs comprises majoritairement entre 25 et 50 km dont les localisations ont pu &ecirc;tre affin&eacute;es gr&acirc;ce aux relocalisations effectu&eacute;es lors des campagnes en mer (MD220-MAYOBS-1, MD221-MAYOBS-2, MD222-MAYOBS-3, MD223-MAYOBS-4) et &agrave; terre (pickathons de Brest et de Strasbourg). La majorit&eacute; de ces s&eacute;ismes est de faible magnitude, mais plusieurs &eacute;v&egrave;nements de magnitude mod&eacute;r&eacute;e (max. Mw5,9 le 15 mai 2018) ont &eacute;t&eacute; fortement ressentis par la population et leur succession a endommag&eacute; certaines constructions (rapport BCSF-R&eacute;NaSS juillet 2018). Depuis juillet 2018 et la fin de la premi&egrave;re phase intense de l'&eacute;ruption, le nombre de s&eacute;ismes a diminu&eacute; mais une sismicit&eacute; continue persiste, fluctuante mais qui a pu g&eacute;n&eacute;rer jusqu'&agrave; plusieurs s&eacute;ismes de magnitudes proches de M4 ressentis par mois.<br/><br/>
                  </li><li>
                  <b>D&eacute;formation:</b> Depuis juillet 2018, l'&icirc;le de Mayotte est affect&eacute;e par des d&eacute;placements de surface li&eacute;s &agrave; l'activit&eacute; volcano-tectonique. Ces d&eacute;formations sont li&eacute;es &agrave; des circulations de fluides en profondeur se produisant &agrave; l'est de Mayotte, en lien avec l'activit&eacute; volcanique.
                  </li></ul>
	          </p>
                  <hr/>
                  <p id=legend>
                    <a href=https://www.facebook.com/ReseauVolcanoSismoMayotte>Page Facebook du ReVoSiMa</a>
                    <br/><br/>
                  </p>
                  <h3>Cr&eacute;dits</h3>
                  <div id='revocredits'>
                    <p id=legend>
Ce r&eacute;seau est op&eacute;r&eacute; par l'IPGP avec l'appui du BRGM Mayotte. Le REVOSIMA b&eacute;n&eacute;ficie du soutien de l'Observatoire Volcanologique du Piton de la Fournaise (OVPF-IPGP), de l'IFREMER, du CNRS-INSU et du BRGM. Les donn&eacute;es de ce r&eacute;seau sont produites par un large consortium de partenaires scientifiques financ&eacute;s par l'Etat.<br/>
Le consortium du REVOSIMA : IPGP et Universit&eacute; de Paris, BRGM, IFREMER, CNRS, BCSF-R&eacute;NaSS, IPGS et Universit&eacute; de Strasbourg, IGN, ENS, SHOM, TAAF, M&eacute;t&eacute;o France, CNES, Universit&eacute; Grenoble Alpes et ISTerre, Universit&eacute; Clermont Auvergne, LMV et OPGC, Universit&eacute; de La R&eacute;union, Universit&eacute; Paul Sabatier, Toulouse et GET-OMP, Universit&eacute; de la Rochelle, IRD et collaborateurs. Les astreintes de surveillance renforc&eacute;e du processus sismo-volcanique par le REVOSIMA ont &eacute;t&eacute; assur&eacute;es pendant une phase provisoire depuis le 25 juillet sur la base de la mobilisation exceptionnelle de personnels scientifiques permanents disponibles, qui proviennent de laboratoires de l'INSU-CNRS et de leurs universit&eacute;s associ&eacute;es (BCSF-RENASS, CNRS, IPGS et Universit&eacute; de Strasbourg, Universit&eacute; Grenoble Alpes et ISTerre, Universit&eacute; Paul Sabatier, Toulouse et GET-OMP, Universit&eacute; Clermont Auvergne, LMV et OPGC, BRGM, IPGP et Universit&eacute; de Paris, Universit&eacute; de la R&eacute;union), sous le pilotage de l'IPGP, de l'OVPF-IPGP, et du BRGM Mayotte, et sur la base d'un protocole et d'outils mis en place par l'IPGP, le BCSF-RENASS, l'OVPF-IPGP, et l'IFREMER.<br/><br/>
Ce bulletin quotidien est distribu&eacute; publiquement. Les informations dans ce bulletin sont &agrave; usage d'information, de p&eacute;dagogie et de surveillance. Elles ne peuvent pas &ecirc;tre utilis&eacute;es &agrave; des fins de publications de recherche sans y faire r&eacute;f&eacute;rence explicitement et sans autorisation du comit&eacute; du REVOSIMA. Les donn&eacute;es sismiques sont distribu&eacute;es par l'IPGP (Centre de donn&eacute;es : <a href=http://datacenter.ipgp.fr/>http://datacenter.ipgp.fr</a> et <a href=http://volobsis.ipgp.fr/data.php>http://volobsis.ipgp.fr/data.php</a>) et par les Services Nationaux d'Observations du CNRS-INSU (<a href=http://seismology.resif.fr/>http://seismology.resif.fr/</a>). Les donn&eacute;es GPS sont distribu&eacute;es par l'Institut G&eacute;ographique National (IGN : <a href=http://mayotte.gnss.fr/donnees>http://mayotte.gnss.fr/donnees</a>). Les donn&eacute;es acquises lors des campagnes oc&eacute;anographiques seront distribu&eacute;es par l'IFREMER, les autres donn&eacute;es g&eacute;ologiques et g&eacute;ochimiques seront diffus&eacute;es par le REVOSIMA et ses partenaires.
                    </p>
                  </div> 
                  ";
        $html .= "    </div>";
        $html .= "  </div>";
	$htmlBrowser .= $html;
        $html .= "  </body>";
        $html .= "</html>";
	$htmlOutput .= $html;
	$htmlMail .= $html;

	print "$htmlBrowser";
	print '<a href="mailto:revosima_bulletin@services.cnrs.fr?subject=Bulletin%20du%20Jour">Your visible link text</a>';

	#open(my $fh, '>', $outputFilename) or die "Could not open file '$outputFilename' $!";
	open(my $fh, '>', $outputFilename) or print "Could not open file '$outputFilename' $!";
	print $fh $htmlOutput;
	close $fh;

#	print "Envoie du mail";

#	my $from = $MC3{MAIL_FROM_REVOSIMA};
#	my $smtpServer = $MC3{MAIL_SMTP_SERVER};
#	my $smtpPort = $MC3{MAIL_SMTP_PORT};
#	my $user = $MC3{MAIL_USER_REVOSIMA};
#	my $passwd = $MC3{MAIL_PASSWD_REVOSIMA};
#
#	my $mailList = '';
#	my @mailConf = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{MAIL_REVOSIMA_INFO_CONF}");
#	for (@mailConf) {
#		my @liste = split(/\|/,$_);
#		my %hash;
#		@hash{@mail}=();
#		if (exists $hash{$liste[0]}){
#			if ($mailList eq '') {
#				$mailList = $mailList.$liste[4]
#			} else {
#				$mailList = $mailList.','.$liste[4]
#			}
#		}
#	}
#	
#	my $message = Email::MIME->create_html(
#		header => [
#			From => $from,
#			'Reply-To' => $from,
#			Subject => $subject,
#			Type    => 'text/html; charset=UTF-8',
#		],
#		body => $htmlMail,
#	);
#	
#	my @mailingList = split(/,/,$mailList);
#	for(@mailingList) {
#		if($MC3{MAIL_USE_SMTP_REVOSIMA}) {
#			my $transport = Email::Sender::Transport::SMTP::TLS->new(
#				host     => $smtpServer,
#				port     => $smtpPort,
#				username => $user,
#				password => $passwd,
#			);
#			sendmail($message, { from => $from, to => $_, transport => $transport});
#		} else {
#			sendmail($message, { from => $from, to => $_});
#		}
#	}
} else {
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
    <form action="mailInfo_REVOSIMA.pl" onsubmit="return validateAlert()" method="GET">
      <h1>REVOSIMA</h1>
      <h2>$timePeriodHTML</h2>
      <h3>Niveau d'alerte en cours :
        <select name="alert">
PART1

        for (@typeAlerts) {
                my @liste = split(/\|/,$_);
                print "<option value=\"$liste[0]\">$liste[1]</option>\n";
        }

        print <<"PART12";
        </select><br/><br/>
      </h3>

      <h3>Nombre de VLP : $comptabilisesVLP</h3>
      <h3>Nombre de LP : $comptabilisesLP</h3>
      <h3>Nombre de s&eacute;ismes volcano-tectoniques (VT) : $comptabilisesVT</h3>
      </p>
      <h3>VT principal :</h3>
      <p>
        <ul>
          <li>Dur&eacute;e : $stat_max_duration s</li>
          <li>Magnitude (MLv) : $stat_max_magnitude</li>
        </ul>
      </p>
      <h3>Dernier s&eacute;isme ressenti :</h3>
      <p>
        <ul>
          <li>Date : $date_felt</li>
          <li>Magnitude (MLv) : $magnitude_felt</li>
          <li>Profondeur : $depth_felt km</li>
          <li>Localisation : $loc_felt</li>
        </ul>
      </p>
      <h3>Deplacements sur Mayotte sur le long terme</h3>
      <p>
PART12
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
      <p>
        Ajouter un &eacute;ventuel s&eacute;isme ressenti au cours des 24 derni&egrave;res heures.<br/>
        <textarea rows="6" cols="50" name="comment"></textarea></p>
      <h3>Destinataires :</h3>
      <p>
PART7

	my @mails = readCfgFile("$WEBOBS{ROOT_CONF}/$MC3{MAIL_REVOSIMA_INFO_CONF}");
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
      <input type="hidden" name="date_felt" value="$date_felt"/>
      <input type="hidden" name="magnitude_felt" value="$magnitude_felt"/>
      <input type="hidden" name="depth_felt" value="$depth_felt"/>
      <input type="hidden" name="loc_felt" value="$loc_felt"/>
      <input type="hidden" name="RFcount" value="$comptabilisesVLP"/>
      <input type="hidden" name="RFcount" value="$comptabilisesLP"/>
      <input type="hidden" name="VTcount" value="$comptabilisesVT"/>
      <br/><input type="submit" name="send" value="Envoyer"/></p>
    </form>
<br>
@signature
</body>
</html>
PART5
}
