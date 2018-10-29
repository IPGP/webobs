#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# mc3.pl
# ------
# Usage: Display Main Courante (MC) seismological database
#
# Arguments
#       mc= MC conf name (optional)
#
# 
# Author: Francois Beauducel <beauducel@ipgp.fr>
# Acknowledgments:
#       afficheMC.pl [2004-2011] by Didier Mallarino, Francois
#		Beauducel, Alexis Bosson, Jean-Marie Saurel
# Created: 2012-02-26
# Updated: 2012-06-22
# Updated: 2012-07-03
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

# text array containing CSV export data (if dump mode)
my @csv;

my $dateStart;
my $dateEnd;
my $fileMC;
my $selectedYear1;
my $selectedMonth1;
my $selectedDay1;
my $selectedYear2;
my $selectedMonth2;
my $selectedDay2;
my $selectedType;
my $selectedDuration;
my $selectedAmplitude;
my $selectedLocation;
my $filter;
my $graph;
my $dump;
my $trash;
my $dumpFile = "${mc3}_dump.csv";

if (($valParams =~ /y1/) && ($valParams =~ /m1/) && ($valParams =~ /d1/) && ($valParams =~ /y2/) && ($valParams =~ /m2/) && ($valParams =~ /d2/))  {
	$selectedYear1 = $cgi->url_param('y1');
	$selectedMonth1 = $cgi->url_param('m1');
	$selectedDay1 = $cgi->url_param('d1');
	$selectedYear2 = $cgi->url_param('y2');
	$selectedMonth2 = $cgi->url_param('m2');
	$selectedDay2 = $cgi->url_param('d2');

	# pour gerer les problemes de dates (28 à 31 jours/mois), on recalcule la date avec "YYYY-MM-01 (DD-1) day"
	# Ex: 2012-02-30 donne 2012-03-01
	($selectedYear1,$selectedMonth1,$selectedDay1) = split(/-/,strftime('%F',gmtime(timegm(0,0,0,1,$selectedMonth1-1,$selectedYear1-1900)+($selectedDay1 - 1)*86400)));
	($selectedYear2,$selectedMonth2,$selectedDay2) = split(/-/,strftime('%F',gmtime(timegm(0,0,0,1,$selectedMonth2-1,$selectedYear2-1900)+($selectedDay2 - 1)*86400)));
	$dateStart = $selectedYear1."-".$selectedMonth1."-".$selectedDay1;
	$dateEnd = $selectedYear2."-".$selectedMonth2."-".$selectedDay2;

	# vérifie que $dateStart < $dateEnd et sinon les inverse
	if ($dateStart gt $dateEnd) {
		($dateStart,$dateEnd,$selectedYear1,$selectedMonth1,$selectedDay1,$selectedYear2,$selectedMonth2,$selectedDay2)
		= ($dateEnd,$dateStart,$selectedYear2,$selectedMonth2,$selectedDay2,$selectedYear1,$selectedMonth1,$selectedDay1);
	}
} else {
	$dateStart = strftime('%F',gmtime(timegm(gmtime) - $MC3{DEFAULT_TABLE_DAYS}*86400));
	($selectedYear1,$selectedMonth1,$selectedDay1) = split(/-/,$dateStart);
	$dateEnd = strftime('%F',gmtime);
	($selectedYear2,$selectedMonth2,$selectedDay2) = split(/-/,$dateEnd);
}

if ($valParams =~ /type/) { 
	$selectedType = $cgi->url_param('type');
}

if ($valParams =~ /duree/) { 
	$selectedDuration = $cgi->url_param('duree');
}

if ($valParams =~ /amplitude/) { 
	$selectedAmplitude = $cgi->url_param('amplitude');
}

if ($valParams =~ /location/) { 
	$selectedLocation = $cgi->url_param('location');
}
if ($selectedLocation eq "") {
	$selectedLocation = $MC3{DISPLAY_LOCATION_DEFAULT};
}

if ($valParams =~ /obs/) { 
	$filter = $cgi->url_param('obs');
}

if ($valParams =~ /graph/) { 
	$graph = $cgi->url_param('graph');
}
if ($graph eq "") {
	$graph = 'movsum';
}

if ($valParams =~ /dump/) { 
	$dump = $cgi->url_param('dump');
}

if ($valParams =~ /trash/) { 
	$trash = $cgi->url_param('trash');
}


my $anneeActuelle = strftime('%Y',gmtime);
my @mois = ("01".."12");
my @jour = ("01".."31");

# - - - - - - - - - - - - - - - - - - - - - - -
# Charge les infos complementaires
# - - - - - - - - - - - - - - - - - - - - - - -
my @cleEvnt;
my %nomEvnt;
my %couleurEvnt;
my %mdEvnt;
my @typeEvnt = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$MC3{EVENT_CODES_CONF}");
for (@typeEvnt) {
	my @liste = split(/\|/,$_);
	push(@cleEvnt,$liste[0]); 
	$nomEvnt{$liste[0]}=$liste[1]; 
	$couleurEvnt{$liste[0]}=$liste[2]; 
	$mdEvnt{$liste[0]} = $liste[3]; 
}
my @durations = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$MC3{DURATIONS_CONF}");
my %duration_s;
for (@durations) {
        my ($key,$nam,$val) = split(/\|/,$_);
        $duration_s{$key} = $val;
}
my @amplitudes = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$MC3{AMPLITUDES_CONF}");
my %nomAmp;
for (@amplitudes) {
        my ($key,$nam,$val) = split(/\|/,$_);
        $nomAmp{$key} = $nam;
}

# ----- mseed file request: additionnal parameters will be completed
my $mseedreq = "/cgi-bin/$WEBOBS{MSEEDREQ_CGI}?all=2";

my @infoTexte = readFile("$WEBOBS{RACINE_DATA_WEB}/$MC3{NOTES}");


$|=1;

if ($dump eq "") {

	# -----------------------------------------
	# ----- TITRE ET MENU
	$html .= "<H2>$MC3{TITLE}</H2><P>"
		#." <A href=\"/\" target=\"_top\">Webobs</A>"
		."[ <A href=\"#Note\">Notes</A>"
		." | <A href=\"/cgi-bin/$WEBOBS{CGI_SEFRAN3}?header=1\">Sefran3</A>"
		." ]</P>";
	
	# -----------------------------------------
	# ----- FORMULAIRE DE SELECTION D'AFFICHAGE

	$html .= "<FORM name=\"formulaire\" action=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_MC3}\" method=\"get\">"
		."<TABLE width=\"100%\" style=\"border:1 solid darkgray\"><TR><TH>Date début: ";

	# ----- Boite Selection ANNEE1
	$html .= "<select name=\"y1\" size=\"1\" onChange=\"resetMois1()\">";
	for ($MC3{BANG}..$anneeActuelle) { 
		$html .= "<option ".($_ == $selectedYear1 ? "selected":"")." value=\"$_\">$_</option>\n"; 
	}

	# ----- Boite Selection MOIS1
	$html .= "</select> - <select name=\"m1\" size=\"1\" onChange=\"resetJour1()\">";
	for (@mois) { 
		$html .= "<option ".($_ == $selectedMonth1 ? "selected":"")." value=\"$_\">$_</option>\n"; 
	}

	# ----- Boite Selection JOUR1
	$html .= "</select> - <select name=\"d1\" size=\"1\">";
	for (@jour) { 
		$html .= "<option ".($_ == $selectedDay1 ? "selected":"")." value=\"$_\">$_</option>\n"; 
	}

	# ----- Boite Selection ANNEE2
	$html .= "</select>\n Date fin: <select name=\"y2\" size=\"1\" onChange=\"resetMois2()\">";
	for ($MC3{BANG}..$anneeActuelle) { 
		$html .= "<option ".($_ == $selectedYear2 ? "selected":"")." value=\"$_\">$_</option>\n"; 
	}

	# ----- Boite Selection MOIS2
	$html .= "</select> - <select name=\"m2\" size=\"1\" onChange=\"resetJour2()\">";
	for (@mois) { 
		$html .= "<option ".($_ == $selectedMonth2 ? "selected":"")." value=\"$_\">$_</option>\n"; 
	}

	# ----- Boite Selection JOUR2
	$html .= "</select> - <select name=\"d2\" size=\"1\">";
	for (reverse(@jour)) { 
		$html .= "<option ".($_ == $selectedDay2 ? "selected":"")." value=\"$_\">$_</option>\n"; 
	}

	# ----- Boite Selection TYPE EVNT
	$html .= "</select>\n Type: <select name=\"type\" size=\"1\">";
	for ("ALL|--",@typeEvnt) {
		my ($key,$val) = split(/\|/,$_);
		$html .= "<option ".($key eq $selectedType ? "selected":"")." value=\"$key\">$val</option>\n"; 
	}

	# ----- Boite Selection DUREE
	$html .= "</select>\n Durée: <select name=\"duree\" size=\"1\">"
		."<option selected value=\"ALL\">--</option>";
	for (10,20,30,40,50,60,80,100,120,150,180) {
		my $d;
		$d = sprintf("%d'%02d\"",int($_ / 60),($_ % 60));
		$html .= "<option ".($_ eq $selectedDuration ? "selected":"")." value=\"$_\">$d</option>\n";
	}

	# ----- Boite Selection AMPLITUDE
	$html .= "</select>\n Amplitude: <select name=\"amplitude\" size=\"1\">"
		."<option selected value=\"ALL\">--</option>";
	for (@amplitudes) {
		my ($key,$val) = split(/\|/,$_);
		$html .= "<OPTION".($key eq $selectedAmplitude ? " selected":"")." value=\"$key\">$val</OPTION>\n";
	}
	$html .= "</select>\n<br>";

	# ----- Boite Selection OBSERVATION
	my $msg = "Regular expression";
	if (@infoFiltre ne ("")) {
		$msg = htmlspecialchars(join('',@infoFiltre));
		$msg =~ s/\n//g; # this is needed by overlib()
		$msg =~ s/'/\\'/g; # this is needed by overlib()
	}
			     
	$html .= " Filtre&nbsp;(<A href=\"#\" onMouseOut=\"nd()\" onmouseover=\"overlib('$msg',CAPTION, 'INFORMATIONS',STICKY,WIDTH,300,DELAY,250)\">?</A>):"
		."&nbsp;<INPUT type=\"text\" name=\"obs\" size=30 value=\"$filter\">";
	if ($filter ne "") {
		$html .= "<img style=\"border:0;vertical-align:text-bottom\" src=\"/icons-webobs/cancel.gif\" onClick=effaceFiltre()>";
	}

	# ----- Boite sélection LOCALISATION
	$html .= "&nbsp;&nbsp;Localisations: <select name=\"location\" size=\"1\">";
	for ("0|--","1|Affichées","2|Uniquement","3|Manuelles","4|Automatiques") {
		my ($key,$val) = split(/\|/,$_);
		$html .= "<option".($key eq $selectedLocation ? " selected":"")." value=\"$key\">$val</option>\n"; 
	}
	$html .= "</select>\n";
	if ($userLevel > 4) {
		$html .= "&nbsp;&nbsp;<INPUT type=\"checkbox\" name=\"trash\" value=\"1\"".($trash ? " checked":"").">Corbeille";
	}
	$html .= "</TH><TH>";

	# ----- Champs cachés et submit
	$html .= "<INPUT type=\"hidden\" name=\"mc\" value=\"$mc3\">\n"
		."<INPUT type=\"hidden\" name=\"dump\" value=\"\">\n"
		."<INPUT type=\"button\" value=\"Afficher\" onClick=\"display()\">"
		."</TH></TR></TABLE>\n"
		."<DIV id=\"attente\">Searching for data... please wait.</DIV>";

	# ----- FIN DU FORMULAIRE DE SELECTION
	# -----------------------------------------

	$html .= "<TABLE width=\"100%\"><TR><TD nowrap style=\"border:0;text-align:left;vertical-align:top\">"
		."<P><B>Graphe:</B>&nbsp;<SELECT name=\"graph\" size=\"1\" onChange=\"plotFlot()\">";

	# ----- Boite sélection du type de graphe
	foreach ("bars|Histogramme journalier","movsum|Histogramme glissant 24h","ncum|Nombre cumulé","mcum|Moment sismique cumulé","gr|Gutenberg-Richter (log)") {
		my ($key,$val) = split(/\|/,$_);
		$html .= "<OPTION value=\"$key\"".($key eq $graph ? " selected":"").">$val</OPTION>";
	}
	$html .= "</SELECT></P></FORM>\n";
}
	
# Main Courante
# - - - - - - - - - - - - - - - - - - - - - - -

my @lignes;
my @titres;
my @hypo = ("");
my @hypos = ("");
#my %dateModif;
my $nb = 0;
my @finalLignes;
my $flagStart = 0;
my $flagEnd = 0;
my $nbLignesRetenues = 0;
my @numeroLigneReel = ("");
my $nosuds = "xxxxxxxx.xxx";
#my $search = "style=\"background-color:#FFFF55\"";
my $search = "class=\"searchResult\"";

# - - - - - - - - - - - - - - - - - - - - - - -
# Charge la liste des communes pour infos loc et B3
# - - - - - - - - - - - - - - - - - - - - - - -
my @listeCommunes = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{SHAKEMAPS_COMMUNES_FILE}");
my @b3_lon;
my @b3_lat;
my @b3_nam;
my @b3_isl;
my @b3_sit;
my @b3_dat;
my $i = 0;
for (@listeCommunes) {
	my (@champs) = split(/\|/,$_);
	$b3_sit[$i] = $champs[0];
	$b3_lon[$i] = $champs[1];
	$b3_lat[$i] = $champs[2];
	$b3_nam[$i] = $champs[3];
	$b3_isl[$i] = $champs[4];
	$i++;
}

# - - - - - - - - - - - - - - - - - - - - - - -
# Charge les fichiers d'hypocentres (MC2)
# - - - - - - - - - - - - - - - - - - - - - - -
if ($MC3{SISMOHYP_HYPO_USE}) {
	my $fileHypo = "$WEBOBS{RACINE_FTP}/$WEBOBS{SISMOHYP_PATH_FTP}/$WEBOBS{SISMOHYP_HYPO_FILE}";
	if (-e $fileHypo) {
		@hypos = readFile($fileHypo);
	}
	my $fileHypoAuto = "$WEBOBS{RACINE_FTP}/$WEBOBS{SISMOHYP_PATH_FTP}/Auto/$WEBOBS{SISMOHYP_HYPO_FILE}";
	if (-e $fileHypoAuto) {
		push(@hypos,readFile($fileHypoAuto));
	}
}


# - - - - - - - - - - - - - - - - - - - - - - -
# Charge les fichiers de donnees (MC et HYPO)
# - - - - - - - - - - - - - - - - - - - - - - -
my $pathFileMC = $MC3{ROOT}."/".$MC3{PATH_FILES};
# boucle sur les années concernées
for (substr($dateStart,0,4)..substr($dateEnd,0,4)) {
	my $y = $_;
	my $y2 = substr($y,2);
	if ($MC3{SISMOHYP_HYPO_USE}) {
		my $fileHypo2 = $WEBOBS{RACINE_FTP}."/".$WEBOBS{SISMOHYP_PATH_FTP}."/Global/$y"."_".$WEBOBS{SISMOHYP_HYPO_FILE};
		if (-e $fileHypo2) {
			push(@hypos,readFile($fileHypo2));
		}
	}
	if ($MC3{OVPF_HYPO_USE}) {
		my $fileHypo3 = "$WEBOBS{OVPFHYP_PATH}/$y.hyp";
		if (-e $fileHypo3) {
			push(@hypos,readFile($fileHypo3));
		}
	}
	for ("01".."12") {
		my $m = $_;
		if ("$y-$m" ge substr($dateStart,0,7) && "$y-$m" le substr($dateEnd,0,7)) {
			$fileMC = "$MC3{ROOT}/$y/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$y$m.txt";
			if (-e $fileMC) {
				#my @Info = stat($fileMC);
				my $tmp = "$y$m";
				#$dateModif{$tmp} = $Info[8];	
				push(@lignes,readCfgFile($fileMC));
				$nb = $#lignes;
			}
			# @hypo will contain only valid year-month locations
			if ($MC3{SISMOHYP_HYPO_USE}) {
				push(@hypo,grep(/^$y$m/,@hypos));
			}
			if ($MC3{OVPF_HYPO_USE}) {
				push(@hypo,grep(/^$y2$m/,@hypos));
			}
		}
	}
}

# - - - - - - - - - - - - - - - - - - - - - - -
# Charge la ligne des titres
# - - - - - - - - - - - - - - - - - - - - - - -
my @ligneTitre;
@ligneTitre = readCfgFile($WEBOBS{RACINE_FICHIERS_CONFIGURATION}."/".$MC3{TABLE_HEADERS_CONF});

if ($dump eq 'bul') {
	push(@csv,"YYYYmmdd HHMMSS.ss;Duration;Magnitude;Longitude;Latitude;Depth;Type;File;Valid;Projection;Operator\n");
}



# ==================================================================
# Filtrage des événements suivant les critères de sélection
#
# Optimisation: selection "grep" en premier (les plus rapides sur le tableau)


# Filtre des événements à la corbeille (sauf administrateur)
# - - - - - - - - - - - - - 
if ($userLevel < 5 || $trash == 0) {
	@lignes = grep(!/^-/, @lignes);
}

# Selection sur le type
# - - - - - - - - - - - - - 
if (($selectedType ne "") && ($selectedType ne "ALL")) {
	@lignes = grep(/\|$selectedType\|/, @lignes)
}

# Selection sur l'amplitude
# - - - - - - - - - - - - - 
if (($selectedAmplitude ne "") && ($selectedAmplitude ne "ALL")) {
	@lignes = grep(/\|$selectedAmplitude\|/, @lignes)
}

# Selection sur les observations (en fait tous les champs)
# - - - - - - - - - - - - - 
if ($filter ne "") {
	if (substr($filter,0,1) eq "!") {
		my $regex = substr($filter,1);
		@lignes = grep(!/$regex/i, @lignes);
	} else {
		@lignes = grep(/$filter/i, @lignes);
	}
}

# Selection nécessitant de charger les données: dates (de $dateStart a $DateEnd), duree, localisation, ...
# - - - - - - - - - - - - - 
my $l = 0;
my %QML;
foreach my $line (@lignes) {
	$l++;
	my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$png,$operateur,$comment,$origin) = split(/\|/,$line);
	$duree *= $duration_s{$unite};
	if (($date le $dateEnd && $date ge $dateStart) 
		&& ($selectedDuration eq "" || $selectedDuration eq "NA" || $selectedDuration eq "ALL" || $duree >= $selectedDuration)
		&& ($selectedLocation < 2 || length($qml)>2)) {
		# cas d'un ID SC3: chargement du fichier qml correspondant et écrasement d'une éventuelle origine existante (cas de Zandets)
		if ($selectedLocation > 0 && $MC3{SC3_EVENTS_ROOT} ne "" && length($qml) > 2) {
			my ($qmly,$qmlm,$qmld,$sc3id) = split(/\//,$qml);
			%QML = qmlorigin("$MC3{SC3_EVENTS_ROOT}/$qml/$sc3id.last.xml");
			$origin = "$sc3id;$QML{time};$QML{latitude};$QML{longitude};$QML{depth};$QML{phases};$QML{mode};$QML{status};$QML{magnitude};$QML{magtype}";
			$line = "$id_evt|$date|$heure|$type|$amplitude|$duree|$unite|$duree_sat|$nombre|$s_moins_p|$station|$arrivee|$suds|$qml|$png|$operateur|$comment|$origin";
		} else {
			for (keys %QML) {
				delete $QML{$_};
			}
		}

		if ($selectedLocation < 3 || ($selectedLocation == 3 && $QML{mode} eq 'manual') || ($selectedLocation == 4 && $QML{mode} eq 'automatic')) {
			if ($dump eq 'bul') {
				push(@csv,join('',split(/-/,$date))." ".join('',split(/:/,$heure)).";"
					."$duree;$QML{magnitude};$QML{longitude};$QML{latitude};$QML{depth};$nomEvnt{$type};$qml;"
					.($QML{mode} eq 'manual' ? "1":"0").";WGS84;$operateur\n");
			} elsif ($dump eq "") {
				push(@finalLignes,$line);
				push(@numeroLigneReel,$l);
			}
		}
	}
}

# Trier les donnees
# - - - - - - - - - - - - -
@finalLignes = sort tri_date_avec_id @finalLignes;



# - - - - - - - - - - - - - - - - - - - - - - -
# Statistiques sur le nombre de séismes (pour graphe flot et dump CSV)
# - - - - - - - - - - - - - - - - - - - - - - -
my $timeS = timegm(0,0,0,substr($dateStart,8,2),substr($dateStart,5,2)-1,substr($dateStart,0,4)-1900);
my $timeE = timegm(0,0,0,substr($dateEnd,8,2),substr($dateEnd,5,2)-1,substr($dateEnd,0,4)-1900);
my $nbJours = ($timeE - $timeS)/86400;
my @stat_t;
my @stat_j; # Javascript dates (in ms since 1970-01-01)
for ("0" .. $nbJours) {
	push(@stat_t, strftime('%F',gmtime($timeS + $_*86400)));
	push(@stat_j, ($timeS + ($_ + 0.5)*86400)*1000);
}
my @stat_th;
my @stat_th1;
my @stat_jh; # Javascript dates hourly (in ms since 1970-01-01)
for ("0" .. (($nbJours+1)*24 - 1)) {
	push(@stat_th, strftime('%F %H',gmtime($timeS + $_*3600)));
	push(@stat_th1, strftime('%F %H',gmtime($timeS + $_*3600 - 86400)));
	push(@stat_jh, ($timeS + $_*3600)*1000);
}
my %stat_m; # hash of event types seismic moment per day
my %stat_mh; # hash of event types seismic moment per hour
my %stat_d; # hash of event types per day
my %stat_dh; # hash of event types per hour
my %stat_ch; # hash of cumulated event types per hour
my %stat; # hash of event types total number
my %stat_gr; # hash of event types Gutenberg-Richter number
my @stat_grm; # array of magnitudes bin
my $stat_max_duration = 0;
my $stat_max_magnitude = 0;
foreach (@finalLignes) {
	if ( $_ ne "" ) {
		my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$png,$operateur,$comment,$origin) = split(/\|/,$_);
		my $time =  timegm(substr($heure,6,2),substr($heure,3,2),substr($heure,0,2),substr($date,8,2),substr($date,5,2)-1,substr($date,0,4)-1900);
		# computes index into data array from time
		my $kd = int(($time - $timeS)/86400);
		my $kh = int(($time - $timeS)/3600);
		if ($origin) {
			my @orig = split(';',$origin);
			my $M0 = 10**(1.5*$orig[8] - 3); # unit = 10^18 dyn.cm
			$stat_m{$type}[$kd] += $M0;
			$stat_mh{$type}[$kh] += $M0;
			my $km = int($orig[8]*10);
			$stat_grm[$km] = $km/10;
			$stat_gr{$type}[$km] += 1;
		}
		$stat{$type} += $nombre;
		$stat{total} += $nombre;

		$stat_d{$type}[$kd] += $nombre;
		$stat_ch{$type}[$kh] += $nombre;
		for ($kh .. ($kh+23)) {
			if ($_ <= $#stat_th) {
				$stat_dh{$type}[$_] += $nombre;
			}
		}
		if (($type eq 'VOLCSUMMIT' || $type eq 'VOLCDEEP') && $duree > $stat_max_duration) {
			my $dist;
			if ($s_moins_p ne "NA" && $s_moins_p ne "") {
				$dist = 8*$s_moins_p;
			} else {
				$dist = 0;
			}
			$stat_max_duration = $duree;
			$stat_max_magnitude = sprintf("%.1f",2*log($duree)/log(10)+0.0035*$dist-0.87);
		}
	}
} 
my $total = 0;
my $i = 0;
foreach (@stat_t) {
	my $daily_count = 0;
	my $daily_moment = 0;
	for(keys(%stat_d)) {
		$daily_count += $stat_d{$_}[$i];
		$daily_moment += $stat_m{$_}[$i];
	}
	$total += $daily_count;
	if ($dump eq 'cum') {
		push(@csv,sprintf("%s;%d;%1.2e\n",$_,$daily_count,1e18*$daily_moment));
	}
	$i++;
}
for ($i = 1; $i <= $#stat_th; $i++) {
	foreach (keys(%stat_mh)) {
		$stat_mh{$_}[$i] += $stat_mh{$_}[$i-1];
	}
	foreach (keys(%stat_ch)) {
		$stat_ch{$_}[$i] += $stat_ch{$_}[$i-1];
	}
}
for ($i = $#stat_grm - 1; $i >= 0; $i--) {
	if ($stat_grm[$i] eq "") {
		$stat_grm[$i] = $i/10;
	}
	foreach (keys(%stat_gr)) {
		$stat_gr{$_}[$i] += $stat_gr{$_}[$i+1];
	}
}
my @key = keys(%stat_gr);
for ($i = 0; $i <= $#stat_grm; $i++) {
	foreach (@key) {
		$stat_gr{total}[$i] += $stat_gr{$_}[$i];
	}
}

$html .= "<P><b>Sélection:</b> ".($nbJours + 1)." jours ";
if ($nbJours > 365) {
	$html .= "( ~ ".int($nbJours/365.25 + 0.5)." an(s) ".int(($nbJours%365.25)/30.4 + 0.5)." mois ) ";
} elsif ($nbJours > 30) {
	$html .= "( ~ ".int($nbJours/30. + 0.5)." mois ) ";
}
$html .= "</P><P><b>Nombre total d'événements</b>: $total</P>";
$html .= "<P><B>Cumul journalier</B>: <INPUT type=\"button\" value=\"Fichier CSV\" onClick=\"dumpData('cum');\"></P>";
$html .= "<P><B>Bulletin d'événements</B>: <INPUT type=\"button\" value=\"Fichier CSV\" onClick=\"dumpData('bul');\"></P>";

# -----------------------------------------
# ----- FORMULAIRE DE MAIL D'INFORMATION

my $vts = $stat{'VOLCSUMMIT'} + $stat{'VOLCDEEP'};
$html .= "<FORM name=\"formulaire_mail\" action=\"/cgi-bin/mail_info.pl\" method=\"get\">";
$html .= "<P><B>Mail d'information</B>: <INPUT type=\"submit\" value=\"G&eacute;n&eacute;rer\"/></P>";
$html .= "<INPUT type=\"hidden\" name=\"dateStart\" value=\"".$dateStart."\"/>";
$html .= "<INPUT type=\"hidden\" name=\"dateEnd\" value=\"".$dateEnd."\"/>";
$html .= "<INPUT type=\"hidden\" name=\"stat_max_duration\" value=\"".$stat_max_duration."\"/>";
$html .= "<INPUT type=\"hidden\" name=\"stat_max_magnitude\" value=\"".$stat_max_magnitude."\"/>";
$html .= "<INPUT type=\"hidden\" name=\"rockfalls\" value=\"".$stat{'ROCKFALL'}."\"/>";
$html .= "<INPUT type=\"hidden\" name=\"vts\" value=\"".$vts."\"/>";
$html .= "</FORM>\n";

# ----- FIN DU FORMULAIRE DE SELECTION
# -----------------------------------------


#print "<TABLE><tr>";
#for(sort(keys(%stat))) {
#	print "<th style=\"font-size:8\"><b>$_</b></th>";  
#}
#print "<th><b>Total</b></th></tr><tr>";
#print "<td style=\"color:red;\"><b>$total</b></td></tr></TABLE>",
$html .= "</TD><TD style=\"border:0;text-align:right\">"
	."<DIV id=\"mcgraph\" style=\"width:800px;height:200px;float:right;\"></DIV>"
	."<DIV id=\"graphinfo\" style=\"width:800px;height:15px;position:relative;float:right;font-size:smaller;color:#545454;\"></DIV>"
	."</TD></TR></TABLE>"
	."<HR>";

# --- JavaScript pour graphes Flot
my @stat_v;
$html .= "<script type=\"text/javascript\">
var lines = false;
var bars = true;
var datad = [];
var datah = [];
var datac = [];
var datam = [];
var datag = [];
var plot;
";
$nomEvnt{total} = 'Total';
$couleurEvnt{total} = '#000000';
foreach (@cleEvnt) {
	if ($stat{$_}) {
		$html .= " datad.push({ label: \"$nomEvnt{$_} = <b>$stat{$_}</b>\", color: \"$couleurEvnt{$_}\","
			." data: [";
		for (my $i=0; $i<=$#stat_t; $i++) {
			my $d = $stat_d{$_}[$i];
			$html .= "[ $stat_j[$i],".($d ? $d:"0")." ],";
		}
		$html .= "]});\n";
		$html .= " datah.push({ label: \"$nomEvnt{$_} = <b>$stat{$_}</b>\", color: \"$couleurEvnt{$_}\","
			." data: [";
		for (my $i=0; $i<=$#stat_th; $i++) {
			my $d = $stat_dh{$_}[$i];
			$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
		}
		$html .= "]});\n";
		$html .= " datac.push({ label: \"$nomEvnt{$_} = <b>$stat{$_}</b>\", color: \"$couleurEvnt{$_}\","
			." data: [";
		for (my $i=0; $i<=$#stat_th; $i++) {
			my $d = $stat_ch{$_}[$i];
			$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
		}
		$html .= "]});\n";
		$html .= " datam.push({ label: \"$nomEvnt{$_} = <b>".sprintf("%1.1f",$stat_mh{$_}[$#stat_th])."</b> (10^18 dyn.cm)\", color: \"$couleurEvnt{$_}\","
			." data: [";
		for (my $i=0; $i<=$#stat_th; $i++) {
			my $d = $stat_mh{$_}[$i];
			$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
		}
		$html .= "]});\n";
	}
}
foreach (@cleEvnt,'total') {
	if ($stat{$_}) {
		$html .= " datag.push({ label: \"$nomEvnt{$_} = <b>$stat{$_}</b>\", color: \"$couleurEvnt{$_}\","
			." data: [";
		for (my $i=0; $i<=$#stat_grm; $i++) {
			my $d = $stat_gr{$_}[$i];
			$html .= "[ $stat_grm[$i],".($d > 0 ? log($d)/log(10):"-0.5")." ],";
		}
		$html .= "]});\n";
	}
}

$html .= "function plotFlot() {
	var gtype = document.formulaire.graph.value;
	xmode = 'time';
	stack = true;
	lines = true;
	linewidth = 1;
	bars = false;
	fill = 0.7;
	points = false;
	ymin = 0;
	if (gtype == 'bars') {
		data = datad;
		lines = false;
		bars = true;
	} else if (gtype == 'mcum') {
		data = datam;
	} else if (gtype == 'ncum') {
		data = datac;
	} else if (gtype == 'gr') {
		data = datag;
		xmode = null;
		stack = null;
		fill = null;
		linewidth = 2;
		points = true;
		ymin = -0.2;

	} else {
		data = datah;
	}
	plot = \$.plot(\$('#mcgraph'), data, {
		xaxis: { mode: xmode },
		yaxis: { min: ymin, minTickSize: 1, tickDecimals: 0 },
		series: {
			stack: stack,
			bars: {
				show: bars,
				fill: fill,
				barWidth: 80000000,
				align: 'center',
				lineWidth: 1
			},
			lines: {
				show: lines,
				fill: fill,
				lineWidth: linewidth
			},
			points: {
				show: points
			}
		},
		legend: { position: 'nw' },
		grid: { hoverable: true, autoHighlight: false },
		crosshair: { mode: 'x', color: 'gray' },
	});

	var legends = \$('#mcgraph .legendLabel');
	var info = document.getElementById('graphinfo');
	var time = new Date();

	var updateLegendTimeout = null;
	var latestPosition = null;

	function updateLegend() {
		updateLegendTimeout = null;

		var pos = latestPosition;

		var axes = plot.getAxes();
		if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
			pos.y < axes.yaxis.min || pos.y > axes.yaxis.max)
			return;

		var i, j, dataset = plot.getData();
		for (i = 0; i < dataset.length; ++i) {
			var series = dataset[i];
			var p = pos.x;
			if (xmode == 'time') {	
				time.setTime(p);
				info.textContent = time.toUTCString();
			} else {
				info.innerHTML = 'M &ge; ' + p.toFixed(1);
			}
			if (gtype == 'bars') {
				p -= 1000*86400/2;
			}
			// find the nearest points, x-wise
			for (j = 0; j < series.data.length; ++j)
				if (series.data[j][0] > p)
				break;

			var y = series.data[j][1];
			if (gtype == 'mcum') {
				y = y.toFixed(1) + ' (10^18 dyn.cm)';
			}
			if (gtype == 'gr') {
				y = Math.pow(10,y).toFixed(0);
			}
			legends.eq(i).text(series.label.replace(/=.*/, '= ' + y));
		}
	}

	\$('#mcgraph').bind('plothover', function (event, pos, item) {
		latestPosition = pos;
		if (!updateLegendTimeout) updateLegendTimeout = setTimeout(updateLegend, 50);
	});
}

plotFlot();


</script>\n";

# - - - - - - - - - - - - - - - - - - - - - - -
# Debut du tableau principal
# - - - - - - - - - - - - - - - - - - - - - - -


$html .= "<table class=\"trData\" width=\"100%\"><tr>";
@titres = split(/\|/,$ligneTitre[0]);
for (my $i = 0; $i <= $#titres; $i++) { 
	if ($selectedLocation > 0 || $i < 15 ) {
		$html .= "<th nowrap>$titres[$i]</th>"; 
	}
}
$html .= "</tr>";

# - - - - - - - - - - - - - - - - - - - - - - -
# Affiche le contenu sous forme de tableau
# - - - - - - - - - - - - - - - - - - - - - - -
for (@finalLignes) {
	if ( $_ ne "") {
		my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$png,$operateur,$comment,$origin) = split(/\|/,$_);
		my ($evt_annee4,$evt_mois,$evt_jour,$suds_jour,$suds_heure,$suds_minute,$suds_seconde,$suds_reseau) = split;
		my $diriaspei;
		my $suds_continu;
		my $dirTrigger;
		my $seedlink;
		my $editURL;
		my $begin;
		my $duration_s = $duree*$duration_s{$unite};
		my $durmseed = ($duration_s + 20);
		if (length($suds) > 10 && $suds =~ ".gwa") {
			($evt_annee4, $evt_mois, $suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a4 a2 a2 x a2 a2 a2 a2 x a3",$suds);
			$diriaspei = $WEBOBS{PATH_SOURCE_SISMO_GWA}."/".$evt_annee4.$evt_mois.$suds_jour;
			$suds_continu = $evt_annee4.$evt_mois.$suds_jour."_".$suds_heure.$suds_minute.$suds_seconde.".gwa";
			$editURL = "frameMC2.pl?f=/$diriaspei/$suds_continu&amp;id_evt=$id_evt";
		} elsif (length($suds) > 10 && $suds =~ ".mq0") {
			($evt_annee4, $evt_mois, $suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a4 a2 a2 x a2 a2 a2 a2 x a3",$suds);
			$diriaspei = $WEBOBS{PATH_SOURCE_SISMO_MQ0}."/".$evt_annee4.$evt_mois.$suds_jour;
			$suds_continu = $evt_annee4.$evt_mois.$suds_jour."_".$suds_heure.$suds_minute.$suds_seconde.".mar";
			$editURL = "frameMC.pl?f=/$diriaspei/$suds_continu&amp;id_evt=$id_evt";
		} elsif (length($suds) > 10 && $suds =~ ".GUA" || $suds =~ ".GUX" || $suds =~ ".gl0") {
			($suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a2 a2 a2 a2 x a3",$suds);
			($evt_annee4,$evt_mois,$evt_jour) = split(/-/,$date);
			$diriaspei = $WEBOBS{"PATH_SOURCE_SISMO_$suds_reseau"}."/".$evt_annee4.$evt_mois.$suds_jour;
			$editURL = "frameMC.pl?f=/$diriaspei/$suds_continu&amp;id_evt=$id_evt";
		} else {
			($evt_annee4, $evt_mois, $suds_jour) = unpack("a4 x a2 x a2",$date);
			($suds_heure,$suds_minute) = unpack("a2 x a2",$heure);
			$editURL = "$WEBOBS{CGI_SEFRAN3}?mc=$mc3&s3=$suds&amp;date=$evt_annee4$evt_mois$suds_jour$suds_heure$suds_minute&amp;id=$id_evt";
			$seedlink = 1;
			$begin = strftime('%Y,%m,%d,%H,%M,%S',
				gmtime(timegm(substr($heure,6,2),substr($heure,3,2),substr($heure,0,2),
					substr($date,8,2),substr($date,5,2)-1,substr($date,0,4)-1900)-10));
		}
		$dirTrigger = "$WEBOBS{SISMOCP_PATH_FTP}/$evt_annee4/".substr($evt_annee4,2,2)."$evt_mois";
		my @loca;
		my @suds_liste;
		my $suds_sans_seconde;
		my $suds_racine;
		my $suds_ext;
		my $suds2_pointe;
		if (length($suds)==12 && substr($suds,10,1) eq '.') {
			# ne prend que les premiers caractères du nom de fichier
			$suds_sans_seconde = substr($suds,0,7);
			@suds_liste = <$WEBOBS{RACINE_FTP}/$dirTrigger/$suds_sans_seconde*>;
			@loca = grep(/ $suds_sans_seconde/,grep(/^$evt_annee4$evt_mois/,@hypo));
		} elsif (length($suds)==19) {
			$suds_racine = substr($suds,0,15);
			$suds_ext = substr($suds,16,3);
			$suds2_pointe = "${suds_racine}_a.${suds_ext}";
			@loca = grep(/ $suds_racine/,grep(/^$evt_annee4$evt_mois/,@hypo));
		}

		my @lat;
		my @lon;
		my @dep;
		my @mag;
		my @mty;
		my @cod;
		my @msk;
		my @dat;
		my @qua;
		my @mod;
		my @sta;
		my @bcube;
		my @nomB3;
		my $isNotManuel = 1;
		my $nomB3FTP = "";
		my $class_Auto = "";
		my $gse = "";

		my $ii;
		if ($selectedLocation > 0) {
			if ($MC3{SISMOHYP_HYPO_USE} > 0) {
				$ii = 0;
				for (@loca) {
					$dat[$ii] = sprintf("%d-%02d-%02d %02d:%02d:%02.2f TU",substr($_,0,4),substr($_,4,2),substr($_,6,2),substr($_,9,2),substr($_,11,2),substr($_,14,5));
					$mag[$ii] = substr($_,47,5);
					$mty[$ii] = 'Md';
					$lat[$ii] = substr($_,20,2) + substr($_,23,5)/60;
					$lon[$ii] = -(substr($_,30,2) + substr($_,33,5)/60);
					$dep[$ii] = substr($_,39,6);
					$qua[$ii] = sprintf("%d phases - classe %s",substr($_,53,2),substr($_,80,1));
					$cod[$ii] = substr($_,83,5);
					if ($cod[$ii] ne "XXX  ") { $isNotManuel = 0; }
					if (substr($cod[$ii],2,1) ne "1") { $msk[$ii] = romain(substr($cod[$ii],2,1)); }
					if ($isNotManuel) {
						$nomB3[$ii] = $WEBOBS{SISMORESS_AUTO_PATH_FTP}."/".substr($_,0,4)."/".substr($_,4,2)."/"
						.substr($_,0,8)."T".sprintf("%02.0f",substr($_,9,2)).sprintf("%02.0f",substr($_,11,2))
						.sprintf("%02.0f",substr($_,14,5))."_b3";
					}
					else {
						$nomB3[$ii] = $WEBOBS{SISMORESS_PATH_FTP}."/".substr($_,0,4)."/".substr($_,4,2)."/"
						.substr($_,0,8)."T".sprintf("%02.0f",substr($_,9,2)).sprintf("%02.0f",substr($_,11,2))
						.sprintf("%02.0f",substr($_,14,5))."_b3";
					}
					$ii ++;
				}
			}

			# cas d'un ID SC3: chargement du fichier qml correspondant
			if ($origin ne "") {
				($cod[0],$dat[0],$lat[0],$lon[0],$dep[0],$qua[0],$mod[0],$sta[0],$mag[0],$mty[0]) = split(';',$origin);
				$qua[0] .= " phases";
				if($mod[0] eq 'manual' && $type eq 'AUTO') {
					$type = 'UNKNOWN';
				}
			}

			for ($ii = 0; $ii <= $#dat; $ii++) {
				# calcul de la distance epicentrale minimum (et azimut epicentre/villes)
				for (0..$#b3_lat) {
					my $dx = ($lon[$ii] - $b3_lon[$_])*111.18*cos($lat[$ii]*0.01745);
					my $dy = ($lat[$ii] - $b3_lat[$_])*111.18;
					$b3_dat[$_] = sprintf("%06.1f|%g|%s|%s|%g",sqrt($dx**2 + $dy**2),atan2($dy,$dx),$b3_nam[$_],$b3_isl[$_],$b3_sit[$_]);
				}
				my @dhyp = sort { $a cmp $b } @b3_dat;
				$bcube[$ii] = $dhyp[0];
			}
		}

		($duree_sat eq 0) and $duree_sat = " ";
		($s_moins_p eq 0) and $s_moins_p = " ";

		my $code = $station;
		# extraction du code station (depuis NET.STA.LOC.CHA)
		if ($station =~ /\./) {
			my @stream = split(/\./,$station);
			$code = substr($stream[1],0,3);
		}

		# mise en evidence du filtre
		my $typeAff = $nomEvnt{$type};
		if ($filter ne "") {
			#if (grep(/$filter/i,$type)) {
			#	$typeAff =~ s/($filter)/<span $search>$1<\/span>/ig;
			#}
			if (grep(/$filter/i,$station)) {
				$station =~ s/($filter)/<span $search>$1<\/span>/ig;
			}
			if (grep(/$filter/i,$comment)) {
				$comment =~ s/($filter)/<span $search>$1<\/span>/ig;
			}
		}
		if ($type eq "AUTO") {
			$class_Auto = " class=\"AutoLoc\"";
		}

		$html .= "<TR".($id_evt < 0 ? " class=\"fiche-invalide\"":"").$class_Auto.">";

		# --- bouton de modification
		$html .= "<TD nowrap>";
		my $msg = "Voir...";
		if (($userLevel == 3 && ($operateur eq "" || $operateur eq $oper[$userID][0])) || $userLevel >= 4 ) {
			$msg = "&Eacute;diter...";
		}
		$html .= "<a href=\"$editURL\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$msg',WIDTH,50)\" target=\"_blank\">"
			."<IMG src=\"/icons-webobs/modif.gif\" style=\"border:0;margin:2\"></a></TD>";
		my $tmp = "$evt_annee4$evt_mois";

		# --- calcul de la distance et magnitude de duree
		my $md;
		my $dist;
		if ($s_moins_p ne "NA" && $s_moins_p ne "" && $mdEvnt{$type} != -1) {
			$dist = 8*$s_moins_p;
		}
		if ($mdEvnt{$type} == 0 && $dist eq "") {
			$dist = 0;
		}
		if ($duration_s > 0 && $dist ne "") {
			$md = sprintf("%.1f",2*log($duration_s)/log(10)+0.0035*$dist-0.87);
			$html .= "<td style=\"color: gray;\" nowrap>$md</td><td style=\"color: gray;\" nowrap>".sprintf("%.0f",$dist)."</td>";
		} else {
			$html .= "<td>&nbsp;</td><td>&nbsp;</td>";
		}

		# --- station premiere arrivee
		if ($arrivee eq "0") {
			$html .= "<td style=\"font-family:monospace\">$code</td>";
		} else {
			$html .= "<td style=\"font-family:monospace;font-weight:bold\">$code</td>";
		}

		# --- date et heure
		$html .= "<td nowrap>&nbsp;$date&nbsp;</td>"
			."<td style=\"text-align:left\" nowrap>&nbsp;$heure&nbsp;</td>";

		# --- nombre d'evenements
		$html .= "<td nowrap>&nbsp;".($nombre gt 1 ? "<b>$nombre</b>" : $nombre)."&nbsp;&times;</td>";

		# --- type d'evenement
		$html .= "<td style=\"color:$couleurEvnt{$type}\"><b>$typeAff</b></td>";
		my $amplitude_texte = ($amplitude eq "Sature" || $amplitude eq "OVERSCALE") ? "<b>$nomAmp{$amplitude}</b> ($duree_sat s)" : "$nomAmp{$amplitude}";
		my $amplitude_img = "/icons-webobs/signal_amplitude_".lc($amplitude).".png";
		$html .= "<td nowrap>$amplitude_texte</td>";

		# --- duree
		$html .= "<td style=\"text-align:right;\">".sprintf("%1.1f",$duree)."&nbsp;$unite</td>";

		# --- S-P
		$html .= "<td style=\"text-align:right;\">".($s_moins_p eq "NA" ? "&nbsp;" : "$s_moins_p")."</td>";

		# --- lien vers le signal
		$html .= "<td>";
		if (length($suds)==12 && substr($suds,10,1) eq '.') {
			for(@suds_liste) { 
				$html .= "<a href=\"$WEBOBS{WEB_RACINE_FTP}/$dirTrigger/$_\"><img title=\"Pointés $_\" src=\"/icons-webobs/signal_pointe.png\" border=\"0\"></a>";
			}
		} elsif (-f "$WEBOBS{RACINE_FTP}/$dirTrigger/$suds2_pointe") { 
			for my $lettre ("a".."z") {
				$suds2_pointe = "${suds_racine}_${lettre}.${suds_ext}";
				if (-f "$WEBOBS{RACINE_FTP}/$dirTrigger/$suds2_pointe") { 
					$html .= "<a href=\"$WEBOBS{WEB_RACINE_FTP}/$dirTrigger/$suds2_pointe\"><img title=\"Pointés $suds2_pointe\" src=\"/icons-webobs/signal_pointe.png\" border=\"0\"></a>";
				}
			}
		} elsif (-f "$MC3{PATH_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds") { 
			$html .= "<a href=\"$MC3{WEB_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds\" title=\"Signaux $suds\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
		} elsif (-f "$MC3{PATH_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds") { 
			$html .= "<a href=\"$MC3{WEB_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds\" title=\"Signaux $suds\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
		} elsif (-f "$WEBOBS{RACINE_SIGNAUX_SISMO}/$diriaspei/$suds") { 
			$html .= "<a href=\"$WEBOBS{WEB_RACINE_SIGNAUX}/$diriaspei/$suds\" title=\"Signaux $suds\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
		} elsif ($suds eq $nosuds) {
			$html .= "<img src=\"/icons-webobs/nofile.gif\" title=\"Pas de fichier\">";
		} elsif ($seedlink) {
			# [FXB] AJOUTER &all=1 lorsque le serveur ArcLink acceptera les wildcards...
			$html .= "<a href=\"$mseedreq&s3=$suds&t1=$begin&ds=$durmseed\" onMouseOut=\"nd()\" onMouseOver=\"overlib('Fichier miniSEED',WIDTH,110)\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
		} else {
			$html .= "<span style=\"font-size:6pt\">($suds)</span>";
		}
		$html .= "</td>";

		#print "<td>$sc3id</td>";

		# --- lien vers image Sefran
		$html .= "<td>";
		my $sefranPNG = "$evt_annee4/$MC3{PATH_IMAGES}/$evt_annee4$evt_mois/$MC3{FILE_PREFIX}$png";
		my $sefranCaption = "$date $heure UT - $typeAff $duree s $code - $comment [$operateur]";
#$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$png,$operateur,$comment
		if (-e "$MC3{ROOT}/$sefranPNG") { 
			$html .= "<a href=\"/$MC3{PATH_WEB}/$sefranPNG\" rel=\"lightbox\" title=\"$sefranCaption\" onMouseOut=\"nd()\" onMouseOver=\"overlib('Image du Sefran',WIDTH,110)\"><img src=\"$amplitude_img\" border=\"0\"></a>";
			#print "<a href=\"/$MC3{PATH_WEB}/$sefranPNG\" onClick=\"window.open('/$MC3{PATH_WEB}/$sefranPNG','SefraN','width=1300,height=700,scrollbars=yes'); return false;\"><img src=\"$amplitude_img\" border=\"0\" alt=\"image du SefraN\"></a>";
		} else {
			#print "<img src=\"/icons-webobs/nofile.gif\" border=\"0\">";
		}

		# --- opérateur
		$html .= "</td><td>$operateur</td>";

		# --- commentaire
		$html .= "<td style=\"text-align:left;\"><i>$comment</i></td>";

		# S'il y a au moins une localisation correspondante à l'événement: extraction des infos et calculs
		$ii = 0;
		for (@dat) {
# S'il y a une localisation validée, on n'affiche pas la localisation automatique
			if ( ($isNotManuel && ($cod[$ii] eq "XXX  ")) || ($cod[$ii] ne "XXX  ") ) {
# Si la localisation est automatique, surlignage
				if ($cod[$ii] eq "XXX  ") { $class_Auto = " class=\"AutoLoc\""; }
				else { $class_Auto = ""; }
# S'il y en a plus d'une, elles sont mises sur des lignes en-dessous, qui ne répetent pas les dates/heures
				if ($ii > 0) {
					$html .= "</td></tr><tr><td colspan=16>"; 
				}
# Distance et direction d'après B3
				my $sc3AutoStyle = ($mod[$ii] eq 'automatic' ? "color:gray":"");
				my @b3 = split(/\|/,$bcube[$ii]);
				$b3[2] =~ s/\'/\`/g;
				my $town = $b3[2];
				if ($b3[4] != $WEBOBS{SHAKEMAPS_COMMUNES_PLACE}) {
					$town = $b3[3];
				}
				my $dhyp = sqrt($b3[0]**2 + $dep[$ii]**2);
				my $pga = attenuation($mag[$ii],$dhyp);
				my $pgamax = $pga*$WEBOBS{SHAKEMAPS_SITE_EFFECTS};
				my $dir = boussole($b3[1]);
				my $dkm = sprintf("%5.1f",$b3[0]);
				$dkm =~ s/\s/&nbsp;&nbsp;/g;
				my $ems = pga2msk($pga);
				my $emsmax = pga2msk($pgamax);
				my $M_A = "<b><span style=color:".($mod[$ii] eq 'manual' ? "green>M":"red>A")."</span></b>";
# Info-bulle avec les détails de la localisation
				$html .= "<td".$class_Auto." nowrap style=\"text-align:left;$sc3AutoStyle\">$M_A</td>\n";
				$html .= "<td".$class_Auto." nowrap style=\"text-align:left;$sc3AutoStyle\" onMouseOut=\"nd()\" onMouseOver=\"overlib('"
					.sprintf("%s = <b>%1.2f</b><br>",$mty[$ii],$mag[$ii])
					.($lat[$ii] < 0 ? sprintf("<b>%2.2f°S</b>",-$lat[$ii]):sprintf("<b>%2.2f°N</b>",$lat[$ii]))
					."&nbsp;&nbsp;"
					.($lon[$ii] < 0 ? sprintf("<b>%2.2f°W</b>",-$lon[$ii]):sprintf("<b>%2.2f°E</b>",$lon[$ii]))
					."&nbsp;&nbsp;"
					.sprintf("<b>%1.1f km</b><br>",$dep[$ii])
					."$dkm km $dir $town<br>"
					."$qua[$ii] / $mod[$ii]".($sta[$ii] ne "" ? " ($sta[$ii])":"")."<br>"
					."<HR>"
					."<i>ID = $cod[$ii]</i>',CAPTION,'$dat[$ii]')\">"
					."$dkm km <img src=\"/icons-webobs/boussole/".lc($dir).".png\" align=\"middle\" alt=\"".$dir."\"> ".$town."</td>";
				$html .= "<td".$class_Auto." style=\"$sc3AutoStyle\">".sprintf("%2.1f",$dep[$ii])."</td>";
				$html .= "<td".$class_Auto." style=\"$sc3AutoStyle\">"
					.sprintf("%1.2f&nbsp;&nbsp;%s",$mag[$ii],$mty[$ii])."</td>";
				
					#if ($MC3{SISMOHYP_HYPO_USE} > 0) {
					$html .= "<td class=\"msk\" style=\"$sc3AutoStyle\">$msk[$ii]</td>";
					#}
				$html .= "<td nowrap style=\"$sc3AutoStyle\" onMouseOut=\"nd()\" onMouseOver=\"overlib('";
# Lien vers le B-Cube
				$nomB3FTP = $WEBOBS{RACINE_FTP}."/".$nomB3[$ii];
				my $ext = "";
				if (-e "$nomB3FTP.pdf") {
					$ext = ".pdf";
				} elsif (-e "$nomB3FTP.png") {
					$ext = ".png";
				}
				if ($ext) {
					$html .= "<img src=&quot;$WEBOBS{WEB_RACINE_FTP}/$nomB3[$ii].jpg&quot;><br>";
				}
				$html .= sprintf("Predicted intensity at:<br><b>%s (%s)</b><br><b>%s</b> (max. %s)",$b3[2],$b3[3],$ems,$emsmax)
					."',CAPTION,'Rapport B³',WIDTH,80)\">";
				if ($ext) {
					$html .= "<A href=\"$WEBOBS{WEB_RACINE_FTP}/$nomB3[$ii]$ext\"><IMG  onMouseOver=\"overlib('<img src=&quot;$WEBOBS{WEB_RACINE_FTP}/$nomB3[$ii].jpg&quot;',CAPTION,'Rapport B³',WIDTH,80)\" src=\"/icons-webobs/logo_b3.gif\" border=0></A>";
				} elsif ($emsmax ne 'I') {
					$html .= "<b>$ems</b> ($emsmax)";
				}
				$html .= "</td></tr>";
			}
			$ii++;
		}
		$html .= ($ii == 0 ? "<td colspan=4>":"")."</td></tr>\n";
		$nbLignesRetenues++;
	}
}

$html .= "</TABLE>\n";

if ($debug) {
	$html .= "<hr>";
	$html .= "<b>Nombre de lignes retenues / lues: </b> $nbLignesRetenues / $nb<br>";
	$html .= "<b>Intervalle des dates: </b>[$dateStart , $dateEnd]<br>";
	$html .= "<b>Critère de type: </b>$selectedType<br>";
	$html .= "<b>Durées supérieures a: </b>$selectedDuration s <br>";
	$html .= "<B>User:</b> $oper[$userID][1] - <b>Level:</b> $userLevel<br>";
	$html .= join('<br>',@listeCommunes);
}

# Affiche la note explicative
# - - - - - - - - - - - - - - - - - - - - - - -
$html .= "<HR><A name=\"Note\"></A>";

# Affiche le tableau des types
# - - - - - - - - - - - - - - - - - - - - - - -
$html .= "<H3>Types d'événements</H3>"
	."<TABLE style=\"margin-left:50px\"><TR><TH>Code</TH><TH>Type d'événement</TH><TH>Couleur</TH></TR>\n";
for (@typeEvnt) {
	my @t = split(/\|/,$_);
	$html .= "<TR><TD class=\"code\">$t[0]</TD><TD>$t[1]</TD><TD style=\"border:1px solid white;background-color:$t[2]\">&nbsp;&nbsp;&nbsp;</TD></TR>\n";
}
$html .= "</TABLE>\n"
	."<HR>".join('',@infoTexte)."<HR>";


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if ($dump eq "") {
		print $cgi->header(-charset=>'utf-8');
	print <<"FIN";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>$MC3{TITLE}</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_CSS}">
<link rel="stylesheet" type="text/css" href="/css/$MC3{CSS}">
<style type="text/css">
<!--
	th { font-size:8pt; border-width:0px; }
	td { font-size:8pt; border-width:0px; text-align:center }
	#attente
	{
		 display: block;
		 color: gray;
		 background: white;
		 margin: 0.5em;
		 padding: 0.5em;
		 font-size: 1.5em;
		 border: 1px solid gray;
	}
-->
</style>
</head>
<body>
<!--DEBUT DU CODE ROLLOVER 2-->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->

<!-- LIGHTBOX http://lokeshdhakar.com/projects/lightbox/ -->
<script language="javascript" type="text/javascript" src="/js/lightbox/lightbox.js"></script>
<link href="/js/lightbox/lightbox.css" rel="stylesheet" />

<!-- jQuery & FLOT http://code.google.com/p/flot -->
<!--[if lte IE 8]><script language="javascript" type="text/javascript" src="/js/flot/excanvas.min.js"></script><![endif]-->
<script language="javascript" type="text/javascript" src="/js/flot/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.stack.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.crosshair.js"></script>

<script type="text/javascript">
<!--
valFile0 = "$MC3{ROOT}/$MC3{PATH_FILES}/";

function resetMois1()
{
	document.formulaire.m1.value = "01";
	document.formulaire.d1.value = "01";
}

function resetJour1()
{
	document.formulaire.d1.value = "01";
}

function resetMois2()
{
	document.formulaire.m2.value = "12";
	document.formulaire.d2.value = "31";
}

function resetJour2()
{
	document.formulaire.d2.value = "31";
}

function effaceFiltre()
{
	document.formulaire.obs.value = "";
}

function dumpData(d) {
	document.formulaire.dump.value = d;
	document.formulaire.submit();
}

function display() {
	document.formulaire.dump.value = "";
	document.formulaire.submit();
}

//-->
</script>

FIN



	print $html;

	# Fin de la page
	# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	print <<"FIN";
	<script type="text/javascript">
		document.getElementById("attente").style.display = "none";
	</script>

	<style type="text/css">
		#attente
		{
			display: none;
		}
	</style>

	<br>
	@signature
	</body>
	</html>
FIN

} else {
	print "Content-Disposition: attachment; filename=\"$dumpFile\";\nContent-type: text/csv\n\n"
		.join('',@csv);
}


setlocale(LC_NUMERIC,$old_locale);

