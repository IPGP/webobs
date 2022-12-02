#!/usr/bin/perl

=head1 NAME

mc3.pl

=head1 SYNOPSIS

http://..../mc3.pl?

=head1 DESCRIPTION

Displays 'Main Courante' (MC) seismological database

=head1 Query string parameters

mc=
 configuration file. Optional, defaults to $WEBOBS{ROOT_CONF}/$WEBOBS{MC3_DEFAULT_NAME}.conf

debug=
 debug level. Optional, defaults to '0' (no debug outputs)
 currently supported level: 1

y1= , m1= , d1= , h1=
 start date (year,month,day) and hour

y2= , m2= , d2= , h2=
 end date (year, month, day) and hour (included)

routine=
 last full day, month or year (overwrites any other dates arguments)

type=
 see valid key values in EVENT_CODES_CONF conf file

duree=
 see valid key values in DURATIONS_CONF conf file

amplitude=
 see valid key values in AMPLITUDES_CONF conf file

ampoper=
 amplitude operator
 le = less or equal to
 eq = equal (default)
 ge = greater or equal to

located=
 selection events to be shown. Optional, default to 0, show all events.
 0 show all events.
 1 show only events which have a location.
 2 show only events which don't have a location.

locstatus=
 select location to be shown by status. Optional, defaults to 0, show everything.
 0 show all.
 1 show manual only.
 2 show auto only.

hideloc=
 hide locations. Optional, defaults to !DISPLAY_LOCATION_DEFAULT variable from MC3 conf
 0 parse and show, if available, locations.
 1 don't parse (and show, quicker) locations.

obs=
 regular expression for data filtering

graph=
  hbars Hourly Histogram
   bars Daily Histogram
 movsum Daily Moving Histogram
   ncum Cumulated
   mcum Seismic moment cum.
     gr Gutenberg-Richter (log)

slt=
 use local time zone for date/time selection and statistics (from SELECT_LOCAL_TZ)

newts=
 select events newer than edit/create timestamp (format ISO yyyymmddTHHMMSS UTC only)

dump=
 bul event bulletin as .csv file
 cum daily statistics as .csv file

trash=

=head1 MC & MC2 COMPATIBILITY

=head2 MC/MC2/MC3 Files

MC file: MC3{ROOT}/YYYY/MC3{PATH_FILES}/MC3{FILE_PREFIX}YYYYMM.txt

 MC file lines format:
 id|date|time|type|amplitude|duration|unit|dur_sat|number|s-p|station|arrival|suds|qml|png|oper|comment|origin

 edit url =
                                    !----------$diriaspei----------------!
   suds = YYYYMMDD?HHMMSSNN.gwa  => WEBOBS{PATH_SOURCE_SISMO_GWA}/YYYYMMDD/YYYYMMDD_HHMMSS.gwa
          YYYYMMDD?HHMMSSNN.mq0  => WEBOBS{PATH_SOURCE_SISMO_MQ0}/YYYYMMDD/YYYYMMDD_HHMMSS.mar
          DDHHMMSS.GUA           => WEBOBS{PATH_SOURCE_SISMO_GUA}/YYYYMMDD/
          DDHHMMSS.GUX           => WEBOBS{PATH_SOURCE_SISMO_GUX}/YYYYMMDD/
          DDHHMMSS.gl0           => WEBOBS{PATH_SOURCE_SISMO_gl0}/YYYYMMDD/
     or = must be sefran3 config =>                                       YYYYYMMDDHHMM        (sefran3, $seedlink = 1)

   if suds == SSSSSSSS.eee         => suds_liste = <WEBOBS{SISMOCP_PATH_FTP}/YYYY/YYMM/SSSSSSSS*>
   if suds == RRRRRRRRRRRRRRR.eee  => suds2_pointe = RRRRRRRRRRRRRRR_a.eee

 signal =
   if    suds == SSSSSSSS.eee                   => WEBOBS{SISMOCP_PATH_FTP}/YYYY/YYMM/SSSSSSSS*
   elsif exists WEBOBS{SISMOCP_PATH_FTP}/YYYY/YYMM/RRRRRRRRRRRRRRR_a.eee
                                                => WEBOBS{SISMOCP_PATH_FTP}/YYYY/YYMM/RRRRRRRRRRRRRRR_{a..z}.eee
   elsif exists                                 => MC3{PATH_DESTINATION_SIGNAUX}/YYYY-MM/suds
   elsif exists                                 => MC3{PATH_DESTINATION_SIGNAUX}/YYYY-MM/suds
   elsif exists                                 => WEBOBS{RACINE_SIGNAUX_SISMO}/$diriaspei/suds
   elsif $suds == "xxxxxxxx.xxx"                => no file
   elsif $seedlink                              => mseedreq&s3=$suds&t1=$begin&ds=$durmseed


=head1 HYPOCENTERS FILES

mc3.pl can handle two (2) formats for hypocenters files. Wether they are used or not is determined by the HYPO_USE_FMT0 and HYPO_USE_FMT1 parameters
in the mc3 configuration file:

HYPO_USE_FMT0|path,file ==> use hypocenters files "path/file" + "path/Auto/file" + "path/Global/yyyy._file"

HYPO_USE_FMT1|path      ==> use hypocenters files "path/yyyy.hyp"

These definitions are optional (ie. " HYPO_USE_FMTx| " means that corresponding hypocenters files will not be processed).

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use DateTime;
use DateTime::Duration;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use POSIX qw(strtod setlocale LC_NUMERIC);
setlocale LC_NUMERIC, "C";

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm $CLIENT);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Mapping;
use WebObs::i18n;
use WebObs::Wiki;
use WebObs::QML;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
#DL-TBD: no strict "subs";
#DL-TBD: my $old_locale = setlocale(LC_NUMERIC);
#DL-TBD: setlocale(LC_NUMERIC,'C');
#DL-TBD: use strict "subs";

# ---- 1st parse query parameters for configuration file and debug option -----
#
my $QryParm  = $cgi->Vars;
$QryParm->{'debug'}     //= "";
$QryParm->{'mc'}        //= $WEBOBS{MC3_DEFAULT_NAME};

# ---- read in configuration + info files -------------------------------------
#
my $mc3        = $QryParm->{'mc'};
my %MC3        = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");

# ---- check client's authorization(s) ----------------------------------------
#
die "$__{'Not authorized'} Main Courante" if (!clientHasRead(type=>"authprocs",name=>"MC") && !clientHasRead(type=>"authprocs",name=>"$mc3"));

my @infoFiltre = readFile("$MC3{FILTER_POPUP}");
my @infoTexte  = readFile("$MC3{NOTES}");

# ---- parse remainder of query parameters ------------------------------------
#
$QryParm->{'y1'}        //= "";
$QryParm->{'m1'}        //= "";
$QryParm->{'d1'}        //= "";
$QryParm->{'h1'}        //= "";
$QryParm->{'y2'}        //= "";
$QryParm->{'m2'}        //= "";
$QryParm->{'d2'}        //= "";
$QryParm->{'h2'}        //= "";
$QryParm->{'type'}      //= "";
$QryParm->{'routine'}   //= "";
$QryParm->{'duree'}     //= "";
$QryParm->{'amplitude'} //= "ALL";
$QryParm->{'ampoper'}   //= "eq";
$QryParm->{'located'}   //= "";
$QryParm->{'locstatus'} //= $MC3{DISPLAY_LOCATION_STATUS_DEFAULT};
$QryParm->{'hideloc'}   //= !$MC3{DISPLAY_LOCATION_DEFAULT};
$QryParm->{'obs'}       //= "";
$QryParm->{'graph'}     //= "movsum";
$QryParm->{'slt'}       //= $MC3{DEFAULT_SELECT_LOCAL};
$QryParm->{'newts'}     //= "";
$QryParm->{'dump'}      //= "";
$QryParm->{'trash'}     //= "";

# ---- DateTime inits ---------------------------------------------------------
#
my $now = DateTime->now( time_zone => 'UTC' );
my $currentYear = $now->strftime('%Y');
my $currentMonth = $now->strftime('%m');
my $currentDay = $now->strftime('%d');
my @month_list = ("01".."12");
my @day_list = ("01".."31");
my @hour_list = ("00".."23");

my $slt = sprintf("%+03d",$MC3{SELECT_LOCAL_TZ});

# ---- my inits ---------------------------------------------------------------
#
my $html;
my @csv;
my $start_datetime;
my $end_datetime;
my $fileMC;
my $dumpFile = ""; # Default name of the CSV file
my @cleEvnt;
my $mseedreq = "/cgi-bin/$WEBOBS{MSEEDREQ_CGI}?all=2";

$|=1;


# ---- a few useful subroutines -----------------------------------------------

sub compute_energy {
	# Energy calculation in joules, from:
	# Hanks, T. C., & Kanamori, H. (1979). A moment magnitude scale.
	# Journal of Geophysical Research: Solid Earth, 84(B5), 2348-2350
	my $mag = shift;
	return 10**(1.5 * $mag + 11.8) / 10**7;
}


# ---- check/fix OR default the requested date range --------------------------
#    - handle 28-31 days/month by re-evaluating  with "YYYY-MM-01 (DD-1) day"
#      (ie. 2012-02-30 ==> 2012-03-02)
#    - check range-start < range-end , otherwise swap
if ($QryParm->{'routine'} =~ /^(day|month|year)$/) {
	if ($QryParm->{'routine'} eq "day") {
		$start_datetime = DateTime->today()->subtract(days => 1);
		$end_datetime = DateTime->today()->subtract(hours => 1);
	} elsif ($QryParm->{'routine'} eq "month") {
		$start_datetime = DateTime->today()->set_day(1)->subtract(months => 1);
		$end_datetime = DateTime->today()->set_day(1)->subtract(hours => 1);
	} elsif ($QryParm->{'routine'} eq "year") {
		$start_datetime = DateTime->today()->subtract(years => 1)->set_month(1)->set_day(1);
		$end_datetime = DateTime->today()->set_month(1)->set_day(1)->subtract(hours => 1);
	}
} elsif (($QryParm->{'y1'} ne "") && ($QryParm->{'m1'} ne "") && ($QryParm->{'d1'} ne "")
	&& ($QryParm->{'y2'} ne "") && ($QryParm->{'m2'} ne "") && ($QryParm->{'d2'} ne "")) {

	# We chose to handle short months by converting (e.g.) 30 February to 02 March, or 31 June to 01 July.
	# For this, we add the number of days to the first day of the chosen month.
	$start_datetime = DateTime->new(year => $QryParm->{y1},
					month => $QryParm->{m1},
					day => 1)
			+ DateTime::Duration->new(days => ($QryParm->{d1}-1))
			+ DateTime::Duration->new(hours => ($QryParm->{h1}));
	$end_datetime = DateTime->new(year => $QryParm->{y2},
					month => $QryParm->{m2},
					day => 1)
			+ DateTime::Duration->new(days => ($QryParm->{d2}-1))
			+ DateTime::Duration->new(hours => ($QryParm->{h2}));
} else {
	$start_datetime = DateTime->now()->subtract(hours => (24*$MC3{DEFAULT_TABLE_DAYS}-1));
	$end_datetime = $now;
}

# Change to local time
if ($QryParm->{'slt'} != 0) {
	$start_datetime = $start_datetime - DateTime::Duration->new(hours => ($slt));
	$end_datetime = $end_datetime - DateTime::Duration->new(hours => ($slt));
}

# Swap start and end if necessary
if ($start_datetime gt $end_datetime) {
	($start_datetime, $end_datetime) = ($end_datetime, $start_datetime);
}

$QryParm->{'y1'} = $start_datetime->year;
$QryParm->{'m1'} = $start_datetime->month;
$QryParm->{'d1'} = $start_datetime->day;
$QryParm->{'h1'} = $start_datetime->hour;
$QryParm->{'y2'} = $end_datetime->year;
$QryParm->{'m2'} = $end_datetime->month;
$QryParm->{'d2'} = $end_datetime->day;
$QryParm->{'h2'} = $end_datetime->hour;

# ---- Load Event Codes -------------------------------------------------------
#
my %types = readCfg("$MC3{EVENT_CODES_CONF}",'sorted');
$types{ALL} = { 'Name' => "-- $__{'All'} --", '_SO_' => '000'};
$types{TOTAL} = { 'Name' => "Total", 'Color' => '#000000', '_SO_' => ''};
my %typesSO;
for (keys(%types)) { $typesSO{$types{$_}{_SO_}} = $_; }

# ---- Load Durations ---------------------------------------------------------
#
my @Durations = readCfgFile("$MC3{DURATIONS_CONF}");
my %duration_s;
for (@Durations) {
        my ($key,$nam,$val) = split(/\|/,$_);
        $duration_s{$key} = $val;
}
# ---- Load Amplitudes --------------------------------------------------------
#
my @amplitudes = readCfgFile("$MC3{AMPLITUDES_CONF}");
my %namAmp;
my %valAmp;
my %opeAmp = ( 'le' => '&le;', 'eq' => '=', 'ge' => '&ge;' );
for (@amplitudes) {
        my ($key,$nam,$val) = split(/\|/,$_);
        $namAmp{$key} = $nam;
        $valAmp{$key} = $val;
}

# ---- Load No location SC3 types ----------------------------------------------
my @nolocation_types = split(/,/,$MC3{SC3_EVENT_TYPES_NOLOCATION});

# ---- Build the DISPLAY-SELECTION form if NOT a 'dump' request ---------------
#
if ($QryParm->{'dump'} eq "") {

	$html .= "<H1>$MC3{TITLE}</H1><P>";
	$html .= "<P class=\"subMenu\"> <b>&raquo;&raquo;</b> [ Associated Sefran3: ";
	# adds links to all associated Sefran
	my @Sefran = qx(grep -H -E 'MC3_NAME\|$mc3\$' $WEBOBS{PATH_SEFRANS}/*/*.conf);
	my @SefranLinks;
	for my $s3 (@Sefran) {
		chomp $s3;
		$s3 =~ s/^$WEBOBS{PATH_SEFRANS}\///g;
		$s3 =~ s/\/.*//g;
		push(@SefranLinks, "<A href=\"/cgi-bin/$WEBOBS{CGI_SEFRAN3}?header=1&s3=$s3&mc3=$mc3\"><B>$s3</B></A>");
	}
	$html .= join(" | ",@SefranLinks)." - <A href=\"#Note\">Notes</A> ]</P>";

	$html .= "<FORM name=\"formulaire\" action=\"/cgi-bin/$WEBOBS{CGI_MC3}\" method=\"get\">"
		."<TABLE width=\"100%\" style=\"border:1 solid darkgray\"><TR>";
		;

	# ----- selection box TZ (UTC or local)
	if ($MC3{SELECT_LOCAL_TZ} ne "") {
		$html .= "<TH rowspan=2>Date TZ: <select name=\"slt\" size=\"1\">";
		$html .= "<option ".($QryParm->{'slt'} == 0 ? "selected":"")." value=\"0\">UTC</option>\n";
		$html .= "<option ".($QryParm->{'slt'} != 0 ? "selected":"")." value=\"1\">GMT $slt</option>\n";
		$html .= "</select></TH>\n";
	}

	$html .="<TH>Start Date: ";

	# ----- selection box YEAR1
	$html .= "<select name=\"y1\" size=\"1\" onChange=\"resetDate1(0)\">";
	for ($MC3{BANG}..$currentYear) {
		$html .= "<option ".($_ == $QryParm->{'y1'} ? "selected":"")." value=\"$_\">$_</option>\n";
	}
	$html .= "</select>\n";
	# ----- selection box MONTH1
	$html .= "<select name=\"m1\" size=\"1\" onChange=\"resetDate1(1)\">";
	for (@month_list) {
		$html .= "<option ".($_ == $QryParm->{'m1'} ? "selected":"")." value=\"$_\">$_</option>\n";
	}
	$html .= "</select>\n";
	# ----- selection box DAY1
	$html .= "<select name=\"d1\" size=\"1\" onChange=\"resetDate1(2)\">";
	for (@day_list) {
		$html .= "<option ".($_ == $QryParm->{'d1'} ? "selected":"")." value=\"$_\">$_</option>\n";
	}
	$html .= "</select>\n";
	# ----- selection box HOUR1
	$html .= "<select name=\"h1\" size=\"1\">";
	for (@hour_list) {
		$html .= "<option ".($_ == $QryParm->{'h1'} ? "selected":"")." value=\"$_\">$_ h</option>\n";
	}
	$html .= "</select>\n";

	# ----- selection box YEAR2
	$html .= " &nbsp;&nbsp; End Date: <select name=\"y2\" size=\"1\" onChange=\"resetDate2(0)\">";
	for ($MC3{BANG}..$currentYear) {
		$html .= "<option ".($_ == $QryParm->{'y2'} ? "selected":"")." value=\"$_\">$_</option>\n";
	}
	$html .= "</select>\n";
	# ----- selection Box MONTH2
	$html .= "<select name=\"m2\" size=\"1\" onChange=\"resetDate2(1)\">";
	for (@month_list) {
		$html .= "<option ".($_ == $QryParm->{'m2'} ? "selected":"")." value=\"$_\">$_</option>\n";
	}
	$html .= "</select>\n";
	# ----- selection box DAY2
	$html .= "<select name=\"d2\" size=\"1\" onChange=\"resetDate2(2)\">";
	for (reverse(@day_list)) {
		$html .= "<option ".($_ == $QryParm->{'d2'} ? "selected":"")." value=\"$_\">$_</option>\n";
	}
	$html .= "</select>\n";
	# ----- selection box HOUR2
	$html .= "<select name=\"h2\" size=\"1\">";
	for (@hour_list) {
		$html .= "<option ".($_ == $QryParm->{'h2'} ? "selected":"")." value=\"$_\">$_ h</option>\n";
	}
	$html .= "</select>\n";

	# ----- selection box TYPE EVNT
	$html .= " &nbsp;&nbsp; Type: <select name=\"type\" size=\"1\">";
	for (sort(keys(%typesSO))) {
		my $key = $typesSO{$_};
		if ($_ ne "") {
			$html .= "<option ".($key eq $QryParm->{'type'} ? "selected":"")." value=\"$key\">$types{$key}{Name}</option>\n";
		}
	}
	$html .= "</select>\n";

	# ----- selection box DUREE
	$html .= " &nbsp;&nbsp; Duration: <select name=\"duree\" size=\"1\">"
		."<option selected value=\"ALL\">--</option>";
	for (10,20,30,40,50,60,80,100,120,150,180) {
		my $d;
		$d = sprintf("%d'%02d\"",int($_ / 60),($_ % 60));
		$html .= "<option ".($_ eq $QryParm->{'duree'} ? "selected":"")." value=\"$_\">$d</option>\n";
	}
	$html .= "</select>\n";

	# ----- selection box AMPLITUDE
	$html .= " &nbsp;&nbsp; Amplitude: <SELECT name=\"ampoper\" size=\"1\">";
	for (keys(%opeAmp)) {
		$html .= "<OPTION".($_ eq $QryParm->{'ampoper'} ? " selected":"")." value=\"$_\">$opeAmp{$_}</OPTION>";
	}
	$html .= "</SELECT><SELECT name=\"amplitude\" size=\"1\">"
		."<OPTION selected value=\"ALL\">--</OPTION>";
	for (@amplitudes) {
		my ($key,$nam,$val) = split(/\|/,$_);
		$html .= "<OPTION".($key eq $QryParm->{'amplitude'} ? " selected":"")." value=\"$key\">$nam</OPTION>\n";
	}
	$html .= "</SELECT>\n<br>";

	# ----- selection box OBSERVATION
	my $msg = "Regular expression";
	if (@infoFiltre ne ("")) {
		$msg = htmlspecialchars(join('',@infoFiltre));
		$msg =~ s/\n//g; # this is needed by overlib()
		$msg =~ s/'/\\'/g; # this is needed by overlib()
	}

	$html .= " Filter&nbsp;(<A href=\"#\" onMouseOut=\"nd()\" onmouseover=\"overlib('$msg',CAPTION, 'INFORMATIONS',STICKY,WIDTH,300,DELAY,250)\">?</A>):"
		."&nbsp;<INPUT type=\"text\" name=\"obs\" size=30 value=\"$QryParm->{'obs'}\">";
	if ($QryParm->{'obs'} ne "") {
		$html .= "<img style=\"border:0;vertical-align:text-bottom\" src=\"/icons/cancel.gif\" onClick=effaceFiltre()>";
	}

	# ----- selection box LOCALISATION
	$html .= "&nbsp;&nbsp;Status: <select name=\"locstatus\" size=\"1\">";
	for ("0|All","1|Manual","2|Auto") {
		my ($key,$val) = split(/\|/,$_);
		$html .= "<option".($key eq $QryParm->{'locstatus'} ? " selected":"")." value=\"$key\">$val</option>\n";
	}
	$html .= "</select>\n";

	$html .= "&nbsp;&nbsp;Locations: <select name=\"located\" size=\"1\">";
	for ("0|All","1|Located","2|Not located") {
		my ($key,$val) = split(/\|/,$_);
		$html .= "<option".($key eq $QryParm->{'located'} ? " selected":"")." value=\"$key\">$val</option>\n";
	}
	$html .= "</select>\n";

	if ( !$MC3{DISPLAY_LOCATION_DEFAULT} ) {
		$html .= "&nbsp;&nbsp;<INPUT type=\"checkbox\" name=\"hideloc\" value=\"0\"".($QryParm->{'hideloc'} ? "":" checked").">Show loc info (slower)";
	} else {
		$html .= "&nbsp;&nbsp;<INPUT type=\"checkbox\" name=\"hideloc\" value=\"1\"".($QryParm->{'hideloc'} ? " checked":"").">No loc info (faster)";
	}

	if (clientHasAdm(type=>"authprocs",name=>"MC") || clientHasAdm(type=>"authprocs",name=>"$mc3")) {
		$html .= "&nbsp;&nbsp;<INPUT type=\"checkbox\" name=\"trash\" value=\"1\"".($QryParm->{'trash'} ? " checked":"").">Trash";
	}
	$html .= "&nbsp;&nbsp;<INPUT type=\"checkbox\" name=\"nograph\" value=\"1\"".($QryParm->{'nograph'} ? " checked":"").">No graph (faster)";
	$html .= "</TH><TH>";

	# ----- Hidden fields + button(s)
	$html .= "<INPUT type=\"hidden\" name=\"mc\" value=\"$mc3\">\n"
		."<INPUT type=\"hidden\" name=\"dump\" value=\"\">\n"
		."<INPUT type=\"hidden\" name=\"newts\" value=\"$QryParm->{'newts'}\">\n"
		#."<INPUT type=\"button\" value=\"$__{'Reset'}\" onClick=\"document.formulaire.reset()\">"
		."<INPUT type=\"button\" value=\"$__{'Display'}\" onClick=\"display()\">"
		."</TH></TR></TABLE>\n"
		."<DIV id=\"attente\">Searching for data... please wait.</DIV>";

	$html .= "<TABLE width=\"100%\"><TR><TD width=700>";
	if ($QryParm->{'nograph'} == 0) {
		$html .= "<DIV id=\"mcgraph\" style=\"width:700px;height:200px;float:left;\"></DIV>\n"
			."<DIV id=\"showall\" style=\"width:50px;height:15px;position:relative;float:left;font-size:smaller;\"><A href=\"#\" onClick=\"plotAll()\">plot all</A></DIV>\n"
			."<DIV id=\"graphinfo\" style=\"width:600px;height:15px;position:relative;float:left;font-size:smaller;color:#545454;\"></DIV></TD>\n"
			."<TD nowrap style=\"text-align:left\"><DIV id=\"graphlegend\" style=\"width:200px;height:200px;position:static;\"></DIV></TD>\n"
			."<TD nowrap style=\"text-align:left;vertical-align:top\">";
		# ----- selection box graph-type
		$html .= "<P><B>Graph:</B>&nbsp;<SELECT name=\"graph\" size=\"1\" onChange=\"plotFlot(document.formulaire.graph.value)\">";
		foreach my $menu_opts ("hbars|Hourly Histogram",
		                       "bars|Daily Histogram",
		                       "movsum|Daily Moving Histogram",
		                       "ncum|Cumulated",
		                       "mcum|Seismic moment cumul.",
		                       "ecum|Energy cumul. by type (J)",
		                       "ecum_total|Total energy cumul. (J)",
		                       "gr|Gutenberg-Richter (log)")
		{
			my ($key, $val) = split(/\|/, $menu_opts);
			if ($QryParm->{'hideloc'} == 0 || ($key ne "mcum" && $key ne "gr")) {
				$html .= "<OPTION value=\"$key\"".($key eq $QryParm->{'graph'} ? " selected":"").">$val</OPTION>";
			}
		}
		$html .= "</SELECT></P>";
	} else {
		$html .= "<TD width=200></TD><TD nowrap style=\"text-align:left;vertical-align:top\">";
	}
}

# ---- some more inits (mainly for files below) -------------------------------
#
my @lignes;
my @titres;
my @hypo = ("");
my @hypos = ("");
my $nb = 0;
my @finalLignes;
my $flagStart = 0;
my $flagEnd = 0;
my $nbLignesRetenues = 0;
my @numeroLigneReel = ("");
my $nosuds = "xxxxxxxx.xxx";
my $search = "class=\"searchResult\"";

# ---- Load 'cities' : locations + B3 -----------------------------------------
#
my @listeCommunes = readCfgFile("$MC3{CITIES}");
my @b3_lon; my @b3_lat; my @b3_nam; my @b3_isl; my @b3_sit; my @b3_dat;
my $i = 0;
for (@listeCommunes) {
	my (@champs) = split(/\|/,$_);
	$b3_sit[$i] = $champs[4];
	$b3_lon[$i] = $champs[1];
	$b3_lat[$i] = $champs[0];
	$b3_nam[$i] = $champs[2];
	$b3_isl[$i] = $champs[3];
	$i++;
}

# ---- init/check for Hypocenters files (FMT) usage ---------------------------
#
my $HYPO_USE_FMT0_PATH = "";     # FMT0 was SISMOHYP_HYPO_USE and al.
my $HYPO_USE_FMT0_FILE = "";     # FMT0 was SISMOHYP_HYPO_USE and al.
my $HYPO_USE_FMT1_PATH = "";     # FMT1 was OVPF_HYPO_USE and al.
if (defined $MC3{HYPO_USE_FMT0} and length $MC3{HYPO_USE_FMT0}) {
	($HYPO_USE_FMT0_PATH,$HYPO_USE_FMT0_FILE) = split(/,/,$MC3{HYPO_USE_FMT0});
}
if (defined $MC3{HYPO_USE_FMT1} and length $MC3{HYPO_USE_FMT1}) {
	$HYPO_USE_FMT1_PATH = $MC3{HYPO_USE_FMT1};
}

# ---- Load hypocentres -------------------------------------------------------
#
#DL-was: if ($MC3{SISMOHYP_HYPO_USE}) {
#DL-was: 	my $fileHypo = "$WEBOBS{RACINE_FTP}/$WEBOBS{SISMOHYP_PATH_FTP}/$WEBOBS{SISMOHYP_HYPO_FILE}";
if ($HYPO_USE_FMT0_PATH) {
	my $fileHypo = "$HYPO_USE_FMT0_PATH/$HYPO_USE_FMT0_FILE";
	if (-e $fileHypo) {
		@hypos = readFile($fileHypo);
	}
	my $fileHypoAuto = "$HYPO_USE_FMT0_PATH/Auto/$HYPO_USE_FMT0_FILE";
	if (-e $fileHypoAuto) {
		push(@hypos,readFile($fileHypoAuto));
	}
}

# ---- Load data files (MC + HYPO) for [dateStart-dateEnd] --------------------
#
for my $y ($start_datetime->year..$end_datetime->year) {
	my $y2 = substr($y,2);
	if ($HYPO_USE_FMT0_PATH) {
		my $fileHypo2 = "$HYPO_USE_FMT0_PATH/Global/$y"."_".$HYPO_USE_FMT0_FILE;
		if (-e $fileHypo2) {
			push(@hypos,readFile($fileHypo2));
		}
	}
	#DL-was: if ($MC3{OVPF_HYPO_USE}) {
	#DL-was:	my $fileHypo3 = "$WEBOBS{OVPFHYP_PATH}/$y.hyp"
	if ($HYPO_USE_FMT1_PATH) {
		my $fileHypo3 = "$HYPO_USE_FMT1_PATH/$y.hyp";
		if (-e $fileHypo3) {
			push(@hypos,readFile($fileHypo3));
		}
	}
	for my $m ("01".."12") {
		my $start_month = DateTime->new(year => $y, month => $m, day => 1);
		#my $end_month = DateTime->last_day_of_month(year => $y, month => $m);
		my $end_month = $start_month->clone;
		$end_month->add( months => 1 ); # first day of the next month
		if (DateTime->compare($end_month,$start_datetime) gt 0
		    && DateTime->compare($start_month,$end_datetime) le 0) {
			$fileMC = "$MC3{ROOT}/$y/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$y$m.txt";
			if (-e $fileMC) {
				push(@lignes,grep(/.+\|.+/,readCfgFile($fileMC)));
				$nb = $#lignes;
			}
			# @hypo will contain only valid year-month locations
			if ($HYPO_USE_FMT0_PATH) {
				push(@hypo,grep(/^$y$m/,@hypos));
			}
			if ($HYPO_USE_FMT1_PATH) {
				push(@hypo,grep(/^$y2$m/,@hypos));
			}
		}
	}
}

# ---- Load titles ------------------------------------------------------------
#
my @ligneTitre;
@ligneTitre = readCfgFile($MC3{TABLE_HEADERS_CONF});

# ---- Process request to dump a bulletin -------------------------------------
#
if ($QryParm->{'dump'} eq 'bul') {
	$dumpFile = "${mc3}_dump_bulletin.csv";
	push(@csv,"#WEBOBS-$WEBOBS{WEBOBS_ID}: $MC3{TITLE}\n");
	push(@csv,"#YYYYmmdd HHMMSS.ss;Nb(#);Duration;Amplitude;Magnitude;E(J);Longitude;Latitude;Depth;Type;File;LocMode;LocType;Projection;Operator;Timestamp;ID\n");
}
if ($QryParm->{'dump'} eq 'cum') {
	$dumpFile = "${mc3}_dump_daily_total.csv";
	push(@csv,"#WEBOBS-$WEBOBS{WEBOBS_ID}: $MC3{TITLE}\n");
	push(@csv,"#Daily histogram counted from ".(($start_datetime)->strftime('%F %H:00:00'))."\n");
	push(@csv,"#YYYY-mm-dd Daily_Total(#);Daily_Count;Daily_Moment(N.m);Daily_Energy(J)\n");
}

# ---- Filter events based on selection criteria: use of grep on the data line (fast!) ------------------------------

	# Filter out trashed event (except for Administrators)
	#
	if ( (!clientHasAdm(type=>"authprocs",name=>"MC") && !clientHasAdm(type=>"authprocs",name=>"$mc3"))  || $QryParm->{'trash'} == 0 ) {
		@lignes = grep(!/^-/, @lignes);
	}
	# Filter on type
	#
	if (($QryParm->{'type'} ne "") && ($QryParm->{'type'} ne "ALL")) {
		@lignes = grep(/\|$QryParm->{'type'}\|/, @lignes)
	}
	# Filter on amplitude
	#
	if (($QryParm->{'ampoper'} eq "eq") && ($QryParm->{'amplitude'} ne "") && ($QryParm->{'amplitude'} ne "ALL")) {
		@lignes = grep(/\|$QryParm->{'amplitude'}\|/, @lignes)
	}
	# Filter on observations
	#
	if ($QryParm->{'obs'} ne "") {
		if (substr($QryParm->{'obs'},0,1) eq "!") {
			my $regex = substr($QryParm->{'obs'},1);
			@lignes = grep(!/$regex/i, @lignes);
		} else {
			@lignes = grep(/$QryParm->{'obs'}/i, @lignes);
		}
	}

# ---- Filters requiring loading of data from $dateStart to $DateEnd), duration, localization, ...
#
my $l = 0;
my %QML;
foreach my $line (@lignes) {
	$l++;
	my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,
	    $nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$event_img,$signature,
	    $comment) = split(/\|/,$line);
	my ($operator,$timestamp) = split("/",$signature);
    	my $origin;
	my $duree_s = ($duree ? $duree*$duration_s{$unite}:"");
	my @evt_date_elem = split(/-/,$date);
	my @evt_hour_elem = split(/:/,$heure);
	my $evt_date = DateTime->new(year => $evt_date_elem[0],
				     month => $evt_date_elem[1],
				     day => $evt_date_elem[2],
				     hour => $evt_hour_elem[0]);
	my $evt_amp = $valAmp{$amplitude};
	# default timestamp for old data is event date
	$timestamp = join('',@evt_date_elem)."T".join('',@evt_hour_elem) if ($timestamp eq "");
	my ($lat,$lon,$dep,$mag,$mty,$cod,$dat,$pha,$qua,$mod,$sta,$mth,$mdl,$typ);
	#XB-was: if (($date le $dateEnd && $date ge $dateStart)
	#XB-was: && ($QryParm->{'duree'} eq "" || $QryParm->{'duree'} eq "NA" || $QryParm->{'duree'} eq "ALL" || $duree_s >= $QryParm->{'duree'})
	if ($evt_date ge $start_datetime && $evt_date le $end_datetime
		&& ($QryParm->{'duree'} ~~ ["", "NA", "ALL"] || $duree_s >= $QryParm->{'duree'} || length($qml) > 2)
		&& ($QryParm->{'amplitude'} ~~ ["", "ALL"] || $QryParm->{'ampoper'} eq 'eq'
			|| ($QryParm->{'ampoper'} eq 'le' && $evt_amp <= $valAmp{$QryParm->{'amplitude'}})
		        || ($QryParm->{'ampoper'} eq 'ge' && $evt_amp >= $valAmp{$QryParm->{'amplitude'}}))
		&& ($QryParm->{'newts'} eq "" || $timestamp ge $QryParm->{'newts'})
	) {
		# do not display location informations
		if ($QryParm->{'hideloc'} == 1 || $MC3{SC3_EVENTS_ROOT} eq "") {
			for (keys %QML) {
				delete $QML{$_};
			}
		}
		# ID SC3 case: load SC3ml file (et écrasement d'une éventuelle origine existante - cas de Zandets)
		elsif ($MC3{SC3_EVENTS_ROOT} ne "" && $qml =~ /[0-9]{4}\/[0-9]{2}\/[0-9]{2}\/.+/) {
			my ($qmly,$qmlm,$qmld,$sc3id) = split(/\//,$qml);
			%QML = qmlorigin("$MC3{SC3_EVENTS_ROOT}/$qml/$sc3id.last.xml");
                       if (%QML) {
                               $origin = "$sc3id;$QML{time};$QML{latitude};$QML{longitude};$QML{depth};$QML{phases};$QML{mode};$QML{status};$QML{magnitude};$QML{magtype};$QML{method};$QML{model};$QML{type}";
                       } else {
                               $origin = '';
                       }
			$line = "$id_evt|$date|$heure|$type|$amplitude|$duree|$unite|$duree_sat|$nombre|$s_moins_p|$station|$arrivee|$suds|$qml|$event_img|$signature|$comment|$origin";
		}
		# ID FDSNWS case: request QuakeML file by FDSN webservice
		elsif ($qml =~ /:\/\//) {
			my ($fdsnws_src,$evt_id) = split(/:\/\//,$qml);
			my $fdsnws_url = "";
			my $fdsnws_detail = "";
			if (defined($MC3{FDSNWS_EVENTS_URL})) {
				$fdsnws_url = $MC3{FDSNWS_EVENTS_URL};
				($fdsnws_url,$fdsnws_detail) = split(/\?/,$fdsnws_url);
				$fdsnws_url = $fdsnws_url."?";
			}
			if (length($fdsnws_src) > 0) {
				my $varname = "FDSNWS_EVENTS_URL_$fdsnws_src";
				$fdsnws_url = "$MC3{$varname}";
				($fdsnws_url,$fdsnws_detail) = split(/\?/,$fdsnws_url);
				$fdsnws_url = $fdsnws_url."?";
				$varname = "FDSNWS_EVENTS_DETAIL_$fdsnws_src";
				if (defined($MC3{$varname})) {
					$fdsnws_detail = $MC3{$varname};
				}
			}
			%QML = qmlfdsn("${fdsnws_url}&format=xml&eventid=$evt_id");
			if (%QML) {
				#[FB-note]: replaced by empty type in the SC3_EVENT_TYPES_NOLOCATION list
				#$QML{type} = "not locatable" if ($QML{type} eq "");
				$origin = "$evt_id;$QML{time};$QML{latitude};$QML{longitude};$QML{depth};$QML{phases};$QML{mode};$QML{status};$QML{magnitude};$QML{magtype};$QML{method};$QML{model};$QML{type}";
			} else {
				$origin = '';
			}
			$line = "$id_evt|$date|$heure|$type|$amplitude|$duree|$unite|$duree_sat|$nombre|$s_moins_p|$station|$arrivee|$suds|$qml|$event_img|$signature|$comment|$origin";
		}
		# Old suds ID case :
		elsif (length($qml) < 3 && $HYPO_USE_FMT0_PATH) {
			my @loca;
			my $suds_sans_seconde;
			my $suds_racine;
			my $evt_annee4;
			my $evt_mois;
			if (length($suds) > 10 && ($suds =~ ".gwa" || $suds =~ ".mq0")) {
				($evt_annee4, $evt_mois) = unpack("a4 a2",$suds);
			} else {
				($evt_annee4, $evt_mois) = unpack("a4 x a2",$date);
			}
			if (length($suds)==12 && substr($suds,8,1) eq '.') {
				# ne prend que les premiers caractères du nom de fichier
				$suds_sans_seconde = substr($suds,0,7);
				@loca = grep(/ $suds_sans_seconde/,grep(/^$evt_annee4$evt_mois/,@hypo));
			} elsif (length($suds)==19) {
				$suds_racine = substr($suds,0,15);
				@loca = grep(/ $suds_racine/,grep(/^$evt_annee4$evt_mois/,@hypo));
			}
			for (@loca) {
				my $id;
				$dat = sprintf("%d-%02d-%02d %02d:%02d:%02.2f TU",substr($_,0,4),substr($_,4,2),substr($_,6,2),substr($_,9,2),substr($_,11,2),substr($_,14,5));
				$mag = substr($_,47,5);
				$mty = 'Md';
				$lat = substr($_,20,2) + substr($_,23,5)/60;
				$lon = -(substr($_,30,2) + substr($_,33,5)/60);
				$dep = substr($_,39,6);
				$pha = substr($_,53,2);
				$qua = substr($_,80,1);
				$cod = substr($_,83,5);
				if (length(substr($_,89))>15) {
					$id  = substr($_,89,15);
				}
				elsif (length(substr($_,89))<10) {
					$id  = substr($_,89);
				}
				$mod = 'manual';
				$origin = "$id;$dat;$lat;$lon;$dep;$pha;$mod;;$mag;$mty;Hypo71;;$cod";
				$line = "$id_evt|$date|$heure|$type|$amplitude|$duree|$unite|$duree_sat|$nombre|$s_moins_p|$station|$arrivee|$suds|$qml|$event_img|$signature|$comment|$origin";
			}
		}

		($cod,$dat,$lat,$lon,$dep,$pha,$mod,$sta,$mag,$mty,$mth,$mdl,$typ) = split(';',$origin);
		my $noloc = 0;
		$noloc = 1 if (grep(/^$typ$/,@nolocation_types));

		if ($QryParm->{'located'} == 0 && $QryParm->{'locstatus'} == 0
			|| ($QryParm->{'located'} == 0 && $noloc == 0 && $pha >= $MC3{LOCATION_MIN_PHASES} && $QryParm->{'locstatus'} == 1 && $mod eq 'manual')
			|| ($QryParm->{'located'} == 0 && $noloc == 0 && $pha >= $MC3{LOCATION_MIN_PHASES} && $QryParm->{'locstatus'} == 2 && $mod eq 'automatic')
			|| ($QryParm->{'located'} == 1 && $noloc == 0 && $pha >= $MC3{LOCATION_MIN_PHASES} && $QryParm->{'locstatus'} == 0)
			|| ($QryParm->{'located'} == 1 && $noloc == 0 && $pha >= $MC3{LOCATION_MIN_PHASES} && $QryParm->{'locstatus'} == 1 && $mod eq 'manual')
			|| ($QryParm->{'located'} == 1 && $noloc == 0 && $pha >= $MC3{LOCATION_MIN_PHASES} && $QryParm->{'locstatus'} == 2 && $mod eq 'automatic')
			|| ($QryParm->{'located'} == 2 && ($noloc == 1 || $pha >= $MC3{LOCATION_MIN_PHASES}) && $QryParm->{'locstatus'} == 0)
			|| ($QryParm->{'located'} == 2 && ($noloc == 1 || $pha >= $MC3{LOCATION_MIN_PHASES}) && $QryParm->{'locstatus'} == 1 && $mod eq 'manual')
			|| ($QryParm->{'located'} == 2 && ($noloc == 1 || $pha >= $MC3{LOCATION_MIN_PHASES}) && $QryParm->{'locstatus'} == 2 && $mod eq 'automatic')
			|| $QryParm->{'hideloc'} == 1 ) {
			if ($QryParm->{'dump'} eq 'bul') {
				my $energy = '';
				if ($mag) {
					# Include energy in joules into the CSV output
					$energy = compute_energy($mag);
				}
				push(@csv,join('',split(/-/,$date))." ".join('',split(/:/,$heure)).";"
					."$nombre;$duree_s;$amplitude;$mag;$energy;$lon;$lat;$dep;$type;$qml;"
					#.($mod eq 'manual' ? "1":"0").";WGS84;$operator;$timestamp;"
					."$mod".($sta == "" ? "":" ($sta)").";$typ;WGS84;$operator;$timestamp;"
					.substr($date,0,7)."#$id_evt\n");
			#FB-was:} elsif ($QryParm->{'dump'} eq "") {
			} else {
				push(@finalLignes,$line);
				push(@numeroLigneReel,$l);
			}
		}
	}
}

# ---- finalLignes = data to process, sorted ----------------------------------
#
@finalLignes = sort tri_date_avec_id @finalLignes;
@csv = sort @csv;

# ---- Statistics on number of seisms (for flot-graph and dump CSV) -----------
#
#XB-was: my $timeS = timegm(0,0,0,substr($dateStart,8,2),substr($dateStart,5,2)-1,substr($dateStart,0,4)-1900);
#XB-was: my $timeE = timegm(0,0,0,substr($dateEnd,8,2),substr($dateEnd,5,2)-1,substr($dateEnd,0,4)-1900);
#my $timeS = $start_datetime->epoch();
#my $timeE = $end_datetime->epoch();
#my $nbDays = ($timeE - $timeS)/86400;
my $nbDays = $end_datetime->subtract_datetime_absolute($start_datetime)->seconds/86400 + 1/24;

my @stat_t; # Dates in YYYY-MM-DD format
my @stat_j; # Javascript dates (in ms since 1970-01-01)
for my $d (0..($nbDays - 1/24)) {
	#push(@stat_t, strftime('%F',gmtime($timeS + $_*86400)));
	#push(@stat_j, ($timeS + ($_ + 0.5)*86400)*1000);
	push(@stat_t, ($start_datetime + DateTime::Duration->new(days => $d))->strftime('%F'));
	#FB-was: push(@stat_j, ($start_datetime + DateTime::Duration->new(days => ($d+0.5)))->epoch * 1000);
	push(@stat_j, ($start_datetime + DateTime::Duration->new(days => $d) + DateTime::Duration->new(hours => 12))->epoch * 1000);
}
my @stat_th;
my @stat_jh;     # Javascript dates hourly (in ms since 1970-01-01)
for my $h (0 .. ($nbDays*24 - 1)) {
	#push(@stat_th, strftime('%F %H',gmtime($timeS + $_*3600)));
	#push(@stat_th1, strftime('%F %H',gmtime($timeS + $_*3600 - 86400)));
	#push(@stat_jh, ($timeS + $_*3600)*1000);
	my $d = $start_datetime + DateTime::Duration->new(hours => $h);
	#my $d1 = $d - DateTime::Duration->new(days => 1);
	if ($d <= $now) {
		push(@stat_th, $d->strftime('%F %H'));
		#push(@stat_jh, $d1->epoch*1000);
		#push(@stat_jh, ($d + DateTime::Duration->new(minutes => 30))->epoch*1000);
		push(@stat_jh, $d->epoch*1000);
	}
}
my %stat_m;      # hash of event types seismic moment per day
my %stat_energy; # hash of event types seismic energy per day
my %stat_mh;     # hash of event types seismic moment per hour
my %stat_d;      # hash of event types per day
my %stat_dh;     # hash of event types per hour
my %stat_vh;     # hash of daily moving histogram event types (per hour)
my %stat_ch;     # hash of cumulated event types (per hour)
my %stat;        # hash of event types total number
my %stat_gr;     # hash of event types Gutenberg-Richter number
my @stat_grm;    # array of magnitudes bin
my $stat_max_duration = 0;
my $stat_max_magnitude = 0;
foreach (@finalLignes) {
	if ( $_ ne "" ) {
		my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$event_img,$signature,$comment,$origin) = split(/\|/,$_);
		if (!$nombre) { $nombre = 1; }
		my $time =  timegm(substr($heure,6,2),substr($heure,3,2),substr($heure,0,2),substr($date,8,2),substr($date,5,2)-1,substr($date,0,4)-1900);
		my $duree_s = ($duree ? $duree*$duration_s{$unite}:0);
		# computes index into data array from time
		my $time_dt = DateTime->new(year => substr($date,0,4),
				     	    month => substr($date,5,2),
				     	    day => substr($date,8,2),
					    hour => substr($heure,0,2),
					    minute => substr($heure,3,2),
					    second => substr($heure,6,2));
		#my $kd = int(($time - $timeS)/86400);
		#my $kh = int(($time - $timeS)/3600);
		my $kd = int($time_dt->subtract_datetime_absolute($start_datetime)->seconds/86400);
		my $kh = int($time_dt->subtract_datetime_absolute($start_datetime)->seconds/3600);
		if ($origin) {
			my @orig = split(';',$origin);
			if ($orig[0]) {
				# Event has an ID
				my $M0 = 0;
				my $km = 0;
				my $mag = $orig[8];
				if ($mag) {
					$M0 = 10**(1.5*$mag + 9.1); # unit = N.m
					$stat_m{$type}[$kd] += $M0;
					$stat_mh{$type}[$kh] += $M0;
					$km = int($mag*10);
					# negative magnitudes are counted in the first histogram bin
					if ($km < 0) { $km = 0; }
					$stat_grm[$km] = $km/10;
					$stat_gr{$type}[$km] += 1;

					# Seismic energy calculation (J)
					my $energy = compute_energy($mag);
					$stat_energy{$type}[$kd] += $energy;
					$stat_energy{TOTAL}[$kd] += $energy;
				}
			}
		}
		$stat{$type} += $nombre;
		$stat{TOTAL} += $nombre;
		$stat{VTcount} += ($types{$type}{asVT} ? $nombre * $types{$type}{asVT}:0);
		$stat{RFcount} += ($types{$type}{asRF} ? $nombre * $types{$type}{asRF}:0);

		$stat_d{$type}[$kd] += $nombre;
		if ($QryParm->{'nograph'} == 0) {
			$stat_ch{$type}[$kh] += $nombre;
			$stat_dh{$type}[$kh] += $nombre;
			for ($kh .. ($kh+23)) {
				if ($_ <= $#stat_th) {
					$stat_vh{$type}[$_] += $nombre;
				}
			}
		}
		if ($types{$type}{asVT} && $duree_s > $stat_max_duration) {
			my $dist;
			my $Pvel = 6;
			$Pvel = $MC3{P_WAVE_VELOCITY} if (defined $MC3{P_WAVE_VELOCITY});
			my $VpVs = 1.75;
			$VpVs = $MC3{VP_VS_RATIO} if (defined $MC3{VP_VS_RATIO});
			if ($s_moins_p ne "NA" && $s_moins_p ne "") {
				# $dist = 8*$s_moins_p;
    			$dist = $Pvel*$s_moins_p/($VpVs-1);
			} else {
				$dist = 0;
			}
			$stat_max_duration = $duree_s;
			$stat_max_magnitude = 2*log($duree_s)/log(10)+0.0035*$dist-0.87;
		}
	}
}

my $total = 0;
$i = 0;
foreach my $day (@stat_t) {
	my $daily_count = 0;
	my $daily_moment = 0;
	my $daily_energy = 0;
	foreach my $evt_type (keys(%stat_d)) {
		$daily_count += $stat_d{$evt_type}[$i] || 0;
		$daily_moment += $stat_m{$evt_type}[$i] || 0;

		# Cumulate the total events energy for this day
		$daily_energy += $stat_energy{$evt_type}[$i] || 0;

		# Also add up daily energy for this type of event
		$stat_energy{$evt_type}[$i] += ($stat_energy{$evt_type}[$i-1] || 0) unless ($i == 0);
	}
	# Store the total daily energy
	$stat_energy{TOTAL}[$i] = ($i > 0 ? $stat_energy{TOTAL}[$i-1] : 0) + $daily_energy;

	if ($QryParm->{'dump'} eq 'cum') {
		push(@csv, sprintf("%s;%d;%g;%e\n", $day, $daily_count, $daily_moment, $daily_energy));
	}
	$total += $daily_count;
	$i++;
}
if ($QryParm->{'nograph'} == 0) {
	for ($i = 1; $i <= $#stat_th; $i++) {
		foreach (keys(%stat_mh)) {
			$stat_mh{$_}[$i] += ($stat_mh{$_}[$i-1] ? $stat_mh{$_}[$i-1]:0);
		}
		foreach (keys(%stat_ch)) {
			$stat_ch{$_}[$i] += ($stat_ch{$_}[$i-1] ? $stat_ch{$_}[$i-1]:0);
		}
	}
	for ($i = $#stat_grm - 1; $i >= 0; $i--) {
		if (!$stat_grm[$i]) {
			$stat_grm[$i] = $i/10;
		}
		foreach (keys(%stat_gr)) {
			$stat_gr{$_}[$i] += ($stat_gr{$_}[$i+1] ? $stat_gr{$_}[$i+1]:0);
		}
	}
	my @key = keys(%stat_gr);
	for ($i = 0; $i <= $#stat_grm; $i++) {
		foreach (@key) {
			$stat_gr{TOTAL}[$i] += ($stat_gr{$_}[$i] ? $stat_gr{$_}[$i]:0);
		}
	}
}

my $nbD = int($nbDays);
$html .= "<P><b>Selection:</b> $nbD day".($nbD>1 ? "s":"");
if ($nbDays - $nbD != 0) {
	my $nbH = int(($nbDays - $nbD)*24);
	$html .= " $nbH hour".($nbH>1 ? "s":"");
}
if ($nbDays > 365) {
	my $nbY = int($nbDays/365.25 + 0.5);
	my $nbM = int(($nbDays%365.25)/30.4 + 0.5);
	$html .= " ( ~ $nbY year".($nbY>1 ? "s":"")." $nbM month".($nbM>1 ? "s":"")." ) ";;
} elsif ($nbDays > 30) {
	my $nbM = int($nbDays/30. + 0.5);
	$html .= " ( ~ $nbM month".($nbM>1 ? "s":"")." ) ";
}
$html .= "</P><P><b>Total number of events</b>: $total</P>";
$html .= qq(<p><b>Cumulated energy:</b>).sprintf(" %.3e&nbsp;MJ", $stat_energy{TOTAL}[-1] / 10**6).qq(</p>);
$html .= "<P><B>Daily total</B>: <INPUT type=\"button\" value=\"CSV File\" onClick=\"dumpData('cum');\"></P>";
$html .= "<P><B>Events bulletin</B>: <INPUT type=\"button\" value=\"CSV File\" onClick=\"dumpData('bul');\"></P>";
$html .= "</FORM>\n";


# ---- HTML-form for Information mailing
#
if ($MC3{DISPLAY_INFO_MAIL} && (clientHasAdm(type=>"authprocs",name=>"MC") || clientHasAdm(type=>"authprocs",name=>"$mc3"))) {
	$html .= "<FORM name=\"formulaire_mail\" action=\"/cgi-bin/$MC3{CGI_MAIL_INFO}\" method=\"get\">";
	$html .= "<P><B>Mail d'information</B>: <INPUT type=\"submit\" value=\"G&eacute;n&eacute;rer\"/></P>";
	#XB-was: $html .= "<INPUT type=\"hidden\" name=\"dateStart\" value=\"".$dateStart."\"/>";
	#XB-was: $html .= "<INPUT type=\"hidden\" name=\"dateEnd\" value=\"".$dateEnd."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"dateStart\" value=\"".$start_datetime->strftime("%F")."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"dateEnd\" value=\"".$end_datetime->strftime("%F")."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"stat_max_duration\" value=\"".$stat_max_duration."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"stat_max_magnitude\" value=\"".$stat_max_magnitude."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"RFcount\" value=\"".$stat{RFcount}."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"VTcount\" value=\"".$stat{VTcount}."\"/>";
	$html .= "</FORM>\n";
	$html .= "<FORM name=\"formulaire_mail_revosime\" action=\"/cgi-bin/$MC3{CGI_REVOSIMA_MAIL_INFO}\" method=\"get\">";
	$html .= "<P><B>Mail d'information REVOSIMA</B>: <INPUT type=\"submit\" value=\"G&eacute;n&eacute;rer\"/></P>";
	$html .= "<INPUT type=\"hidden\" name=\"dateStart\" value=\"".$start_datetime->strftime("%F")."\"/>";
	$html .= "<INPUT type=\"hidden\" name=\"dateEnd\" value=\"".$end_datetime->strftime("%F")."\"/>";
	$html .= "</FORM>\n";
}
# ---- END of HTML-form

#print "<TABLE><tr>";
#for(sort(keys(%stat))) {
#	print "<th style=\"font-size:8\"><b>$_</b></th>";
#}
#print "<th><b>Total</b></th></tr><tr>";
#print "<td style=\"color:red;\"><b>$total</b></td></tr></TABLE>",
$html .= "</TD></TR></TABLE>"
	."<HR>";

# ---- JavaScript for graphs with flot.js -------------------------------------
#
if ($QryParm->{'nograph'} == 0) {
	my @stat_v;
	$html .= "<script type=\"text/javascript\">";
	foreach (sort(keys(%typesSO))) {
		my $key = $typesSO{$_};
		if ($key ne "TOTAL" && $stat{$key}) {
			$html .= " datad.push({ label: \"$types{$key}{Name} = $stat{$key} / $stat{$key}\", color: \"$types{$key}{Color}\","
				." data: [";
			for (my $i=0; $i<=$#stat_t; $i++) {
				my $d = $stat_d{$key}[$i];
				$html .= "[ $stat_j[$i],".($d ? $d:"0")." ],";
			}
			$html .= "]});\n";
			$html .= " datah.push({ label: \"$types{$key}{Name} = $stat{$key} / $stat{$key}\", color: \"$types{$key}{Color}\","
				." data: [";
			for (my $i=0; $i<=$#stat_th; $i++) {
				my $d = $stat_dh{$key}[$i];
				$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
			}
			$html .= "]});\n";
			$html .= " datav.push({ label: \"$types{$key}{Name} = $stat{$key} / $stat{$key}\", color: \"$types{$key}{Color}\","
				." data: [";
			for (my $i=0; $i<=$#stat_th; $i++) {
				my $d = $stat_vh{$key}[$i];
				$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
			}
			$html .= "]});\n";
			$html .= " datac.push({ label: \"$types{$key}{Name} = $stat{$key} / $stat{$key}\", color: \"$types{$key}{Color}\","
				." data: [";
			for (my $i=0; $i<=$#stat_th; $i++) {
				my $d = $stat_ch{$key}[$i];
				$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
			}
			$html .= "]});\n";
			$html .= " datam.push({ label: \"$types{$key}{Name} = ".sprintf("%1.1f",($stat_mh{$key}[$#stat_th] ? $stat_mh{$key}[$#stat_th]:0))." (10^18 dyn.cm)\", color: \"$types{$key}{Color}\","
				." data: [";
			for (my $i=0; $i<=$#stat_th; $i++) {
				my $d = $stat_mh{$key}[$i];
				$html .= "[ $stat_jh[$i],".($d ? $d:"0")." ],";
			}
			$html .= "]});\n";
			# Daily cumulated energy, by type
			$html .= " data_energy.push({ label: \"$types{$key}{Name} = "
				.sprintf("%.3f", $stat_energy{$key}[-1] / 10**6)
				." (MJ)\", color: \"$types{$key}{Color}\", data: [";
			for (my $i = 0; $i <= $#stat_j; $i++) {
				$html .= sprintf("[%s, %s],", $stat_j[$i], ($stat_energy{$key}[$i] / 10**6 || "0"));
			}
			$html .= "]});\n";
		}
		if ($stat{$key}) {
			$html .= " datag.push({ label: \"$types{$key}{Name} = <b>$stat{$key}</b>\", color: \"$types{$key}{Color}\","
				." data: [";
			for (my $i=0; $i<=$#stat_grm; $i++) {
				my $d = $stat_gr{$key}[$i];
				$html .= "[ $stat_grm[$i],".($d ? log($d)/log(10):"-0.5")." ],";
			}
			$html .= "]});\n";
		}
	}
	# Total daily cumulated energy (all types merged)
	$html .= " data_energy_total = [{ label: \"Total = "
		.sprintf("%.3e", $stat_energy{TOTAL}[$#stat_j] / 10**6)
		." (MJ)\", color: \"".($types{ENERGY}{Color} || "#4A65B8")."\", data: [";
	for (my $i = 0; $i <= $#stat_j; $i++) {
		$html .= sprintf("[%s, %f],", $stat_j[$i], ($stat_energy{TOTAL}[$i] / 10**6 || 0));
	}
	$html .= "]}];\n";

	$html .= "</script>\n";
}

# ---- start building main table ----------------------------------------------
#
$html .= "<table class=\"trData\" width=\"100%\"><tr>";
@titres = split(/\|/,$ligneTitre[0]);
for (my $i = 0; $i <= $#titres; $i++) {
	if ($QryParm->{'hideloc'} == 0 || $i < 15 ) {
		$html .= "<th nowrap>$titres[$i]</th>";
	}
}
$html .= "</tr>";

# ---- build/display main table -----------------------------------------------
#
for (@finalLignes) {
	if ( $_ ne "") {
		my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$event_img,$signature,$comment,$origin) = split(/\|/,$_);
		my ($operator,$timestamp) = split("/",$signature);
		my ($evt_annee4,$evt_mois,$evt_jour,$suds_jour,$suds_heure,$suds_minute,$suds_seconde,$suds_reseau) = split;
		my $diriaspei;
		my $suds_continu;
		my $dirTrigger;
		my $dirTriggerUrn;
		my $seedlink;
		my $editURL = "$WEBOBS{CGI_SEFRAN3}?mc=$mc3&amp;date=".substr($date,0,4).substr($date,5,2).substr($date,8,2).substr($heure,0,2).substr($heure,3,2).substr($heure,6,2)."&amp;id=$id_evt";
		my $begin = strftime('%Y,%m,%d,%H,%M,%S',
				gmtime(timegm(substr($heure,6,2),substr($heure,3,2),substr($heure,0,2),
				substr($date,8,2),substr($date,5,2)-1,substr($date,0,4)-1900)-10));
		my $duree_s = ($duree ne "" ? $duree*$duration_s{$unite}:0);
		my $durmseed = ($duree_s + 20);
		if (length($suds) > 10 && $suds =~ ".gwa") {
			($evt_annee4, $evt_mois, $suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a4 a2 a2 x a2 a2 a2 a2 x a3",$suds);
			$diriaspei = $WEBOBS{PATH_SOURCE_SISMO_GWA}."/".$evt_annee4.$evt_mois.$suds_jour;
			$suds_continu = $evt_annee4.$evt_mois.$suds_jour."_".$suds_heure.$suds_minute.$suds_seconde.".gwa";
			#djl-was:$editURL = "frameMC2.pl?f=/$diriaspei/$suds_continu&amp;id_evt=$id_evt";
		} elsif (length($suds) > 10 && $suds =~ ".mq0") {
			($evt_annee4, $evt_mois, $suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a4 a2 a2 x a2 a2 a2 a2 x a3",$suds);
			$diriaspei = $WEBOBS{PATH_SOURCE_SISMO_MQ0}."/".$evt_annee4.$evt_mois.$suds_jour;
			$suds_continu = $evt_annee4.$evt_mois.$suds_jour."_".$suds_heure.$suds_minute.$suds_seconde.".mar";
			#djl-was: $editURL = "frameMC.pl?f=/$diriaspei/$suds_continu&amp;id_evt=$id_evt";
		} elsif (length($suds) > 10 && $suds =~ ".GUA" || $suds =~ ".GUX" || $suds =~ ".gl0") {
			($suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a2 a2 a2 a2 x a3",$suds);
			($evt_annee4,$evt_mois,$evt_jour) = split(/-/,$date);
			$diriaspei = $WEBOBS{"PATH_SOURCE_SISMO_$suds_reseau"}."/".$evt_annee4.$evt_mois.$suds_jour;
			#djl-was: $editURL = "frameMC.pl?f=/$diriaspei/$suds_continu&amp;id_evt=$id_evt";
		} else {
			($evt_annee4, $evt_mois, $suds_jour) = unpack("a4 x a2 x a2",$date);
			($suds_heure,$suds_minute) = unpack("a2 x a2",$heure);
			$editURL = "$WEBOBS{CGI_SEFRAN3}?mc=$mc3&s3=$suds&amp;date=$evt_annee4$evt_mois$suds_jour$suds_heure$suds_minute&amp;id=$id_evt";
			$seedlink = 1;
		}
# JMS was
#		$dirTrigger    = "$WEBOBS{SISMOCP_PATH_FTP}/$evt_annee4/".substr($evt_annee4,2,2)."$evt_mois";
#		$dirTriggerUrn = "$WEBOBS{SISMOCP_PATH_FTP_URN}/$evt_annee4/".substr($evt_annee4,2,2)."$evt_mois";
#		my @loca;
#		my @suds_liste;
#		my $suds_sans_seconde;
#		my $suds_racine;
#		my $suds_ext;
#		my $suds2_pointe;
		#djl-was: if (length($suds)==12 && substr($suds,10,1) eq '.') {
#		if (length($suds)==12 && substr($suds,8,1) eq '.') {
#			# ne prend que les premiers caractères du nom de fichier
#			$suds_sans_seconde = substr($suds,0,7);
#			@suds_liste = <$dirTrigger/$suds_sans_seconde*>;
#			@loca = grep(/ $suds_sans_seconde/,grep(/^$evt_annee4$evt_mois/,@hypo));
#		} elsif (length($suds)==19) {
#			$suds_racine = substr($suds,0,15);
#			$suds_ext = substr($suds,16,3);
#			$suds2_pointe = "${suds_racine}_a.${suds_ext}";
#			@loca = grep(/ $suds_racine/,grep(/^$evt_annee4$evt_mois/,@hypo));
#		}

		my @lat;
		my @lon;
		my @dep;
		my @mag;
		my @mth;
		my @mdl;
		my @typ;
		my @mty;
		my @cod;
		my @msk;
		my @dat;
		my @pha;
		my @qua;
		my @mod;
		my @sta;
		my @bcube;
		my @nomB3;
		my $isNotManuel = 1;
		my $gse = "";

		my $ii;
		if ($QryParm->{'hideloc'} == 0) {
# JMS was
#			if ($HYPO_USE_FMT0_PATH) {
#				$ii = 0;
#				for (@loca) {
#					$dat[$ii] = sprintf("%d-%02d-%02d %02d:%02d:%02.2f TU",substr($_,0,4),substr($_,4,2),substr($_,6,2),substr($_,9,2),substr($_,11,2),substr($_,14,5));
#					$mag[$ii] = substr($_,47,5);
#					$mty[$ii] = 'Md';
#					$lat[$ii] = substr($_,20,2) + substr($_,23,5)/60;
#					$lon[$ii] = -(substr($_,30,2) + substr($_,33,5)/60);
#					$dep[$ii] = substr($_,39,6);
#					#$qua[$ii] = sprintf("%d phases - classe %s",substr($_,53,2),substr($_,80,1));
#					$pha[$ii] = substr($_,53,2);
#					$qua[$ii] = substr($_,80,1);
#					$cod[$ii] = substr($_,83,5);
#					$mod[$ii] = 'manual';
#					if ($cod[$ii] ne "XXX  ") { $isNotManuel = 0; }
#					if (substr($cod[$ii],2,1) ne "1") { $msk[$ii] = romain(substr($cod[$ii],2,1)); }
#					if ($isNotManuel) {
#						$nomB3[$ii] = $WEBOBS{SISMORESS_AUTO_PATH_FTP}."/".substr($_,0,4)."/".substr($_,4,2)."/"
#						.substr($_,0,8)."T".sprintf("%02.0f",substr($_,9,2)).sprintf("%02.0f",substr($_,11,2))
#						.sprintf("%02.0f",substr($_,14,5))."_b3";
#					}
#					else {
#						$nomB3[$ii] = $WEBOBS{SISMORESS_PATH_FTP}."/".substr($_,0,4)."/".substr($_,4,2)."/"
#						.substr($_,0,8)."T".sprintf("%02.0f",substr($_,9,2)).sprintf("%02.0f",substr($_,11,2))
#						.sprintf("%02.0f",substr($_,14,5))."_b3";
#					}
					# calcul de la distance epicentrale minimum (et azimut epicentre/villes)
#					for (0..$#b3_lat) {
#						my $dx = ($lon[$ii] - $b3_lon[$_])*111.18*cos($lat[$ii]*0.01745);
#						my $dy = ($lat[$ii] - $b3_lat[$_])*111.18;
#						$b3_dat[$_] = sprintf("%06.1f|%g|%s|%s|%g",sqrt($dx**2 + $dy**2),atan2($dy,$dx),$b3_nam[$_],$b3_isl[$_],$b3_sit[$_]);
#					}
#					my @xx = sort { $a cmp $b } @b3_dat;
#					$bcube[$ii] = $xx[0];
#					$ii ++;
#				}
#			}

			# si le séisme a été localisé, les infos sont dans le champ $origin
			if ($origin) {
				($cod[0],$dat[0],$lat[0],$lon[0],$dep[0],$pha[0],$mod[0],$sta[0],$mag[0],$mty[0],$mth[0],$mdl[0],$typ[0]) = split(';',$origin);
				if($mod[0] eq 'manual' && $type eq 'AUTO') {
					$type = 'UNKNOWN';
				}

				for ($ii = 0; $ii <= $#dat; $ii++) {
					# calcul de la distance epicentrale minimum (et azimut epicentre/villes)
					for (0..$#b3_lat) {
						my ($dist,$bear) = greatcircle($b3_lat[$_],$b3_lon[$_],$lat[$ii],$lon[$ii]);
						#my $dx = ($lon[$ii] - $b3_lon[$_])*111.18*cos($lat[$ii]*0.01745);
						#my $dy = ($lat[$ii] - $b3_lat[$_])*111.18;
						#$b3_dat[$_] = sprintf("%06.1f|%g|%s|%s|%g",sqrt($dx**2 + $dy**2),atan2($dy,$dx),$b3_nam[$_],$b3_isl[$_],$b3_sit[$_]);
						$b3_dat[$_] = sprintf("%06.1f|%g|%s|%s|%g",$dist,$bear,$b3_nam[$_],$b3_isl[$_],$b3_sit[$_]);
					}
					my @xx = sort { $a cmp $b } @b3_dat;
					$bcube[$ii] = $xx[0];
					if ($MC3{TREMBLEMAPS_PROC}) {
						$nomB3[$ii] = substr($dat[$ii],0,4)."/".substr($dat[$ii],5,2)."/".substr($dat[$ii],8,2)."/$cod[$ii]";
					}
					# cas d'une loc au format hyp71sum2k
					if ($HYPO_USE_FMT0_PATH && (substr($typ[$ii],2,1) =~ /[2-9]{1}/)) {
						$msk[$ii] = romain(substr($typ[$ii],2,1));
					}
				}
			}
		}

		($duree_sat eq 0) and $duree_sat = " ";
		($s_moins_p eq 0) and $s_moins_p = " ";

		my $code = $station;
		# extraction du code station (depuis NET.STA.LOC.CHA)
		if ($station =~ /\./) {
			my @stream = split(/\./,$station);
			#$code = substr($stream[1],0,3);
			$code = $stream[1];
		}

		# mise en evidence du filtre et pop-up
		my $typeAff = ($types{$type}{Name} ? $types{$type}{Name}:"");
		my $imageCAPTION = "$date $heure UT";
		my $imagePOPUP = "$typeAff $duree s $code - $comment [$operator]";
		if ($QryParm->{'obs'} ne "") {
			#if (grep(/$QryParm->{'obs'}/i,$type)) {
			#	$typeAff =~ s/($QryParm->{'obs'})/<span $search>$1<\/span>/ig;
			#}
			if (grep(/$QryParm->{'obs'}/i,$station)) {
				$station =~ s/($QryParm->{'obs'})/<span $search>$1<\/span>/ig;
			}
			if (grep(/$QryParm->{'obs'}/i,$comment)) {
				$comment =~ s/($QryParm->{'obs'})/<span $search>$1<\/span>/ig;
			}
		}
		my $tc = $type;
		if ($operator eq $MC3{SC3_USER}) { $tc = "AUTO"; }

		$html .= "<TR".($id_evt < 0 ? " class=\"node-disabled\"":"")." style=\"background-color:$types{$tc}{BgColor}\">";

		# --- edit button
		$html .= "<TD nowrap>";
		if ($editURL ne "") {
			my $msg = "View...";
			my $ico = "view.png";
			if ( (($operator eq "" || $operator eq $CLIENT || $type eq "AUTO")
				&& (clientHasEdit(type=>"authprocs",name=>"MC") ||clientHasEdit(type=>"authprocs",name=>"$mc3"))) || (clientHasAdm(type=>"authprocs",name=>"MC") || clientHasAdm(type=>"authprocs",name=>"$mc3")) ) {
				$msg = "Edit...";
				$ico = "modif.png";
			}
			$html .= qq(<a href="$editURL" onMouseOut="nd()" onMouseOver="overlib('$msg',WIDTH,50)" target="_blank" rel="opener">)
			         .qq(<img src="/icons/$ico" style="border:0;margin:2"></a>);
		} else { $html .= "&nbsp;" }
		$html .= "</TD>";
		my $tmp = "$evt_annee4$evt_mois";

		# --- computes distance and duration magnitude
		my $md;
		my $dist = -1;
		if ($types{$type}{Md} == 0) {
			$dist = 0;
		}
		if ($s_moins_p && !($s_moins_p ~~ ["","NA"," "]) && $types{$type}{Md} != -1) {
			$dist = 8*$s_moins_p;
		}
		if ($duree_s > 0 && $dist >= 0) {
			$md = sprintf("%.1f",2*log($duree_s)/log(10)+0.0035*$dist-0.87);
			$html .= "<td style=\"color: gray;\" nowrap>$md</td><td style=\"color: gray;\" nowrap>".sprintf("%.0f",$dist)."</td>";
		} else {
			$html .= "<td>&nbsp;</td><td>&nbsp;</td>";
		}

		# --- first arrival station
		if ($arrivee eq "0") {
			$html .= "<td style=\"font-family:monospace\">$code</td>";
		} else {
			$html .= "<td style=\"font-family:monospace;font-weight:bold\">$code</td>";
		}

		# --- date and hour
		$html .= "<td nowrap>&nbsp;$date&nbsp;</td>"
			."<td style=\"text-align:left\" nowrap>&nbsp;$heure&nbsp;</td>";

		# --- number of event
		$html .= "<td nowrap>&nbsp;".($nombre gt 1 ? "<b>$nombre</b>" : $nombre)."&nbsp;&times;</td>";

		# --- type of event
		$html .= "<td".($types{$type}{Color} ? " style=\"color:$types{$type}{Color}\"":"")."><b>$typeAff</b></td>";
		my $amplitude_texte = ($amplitude ? (($amplitude eq "Sature" || $amplitude eq "OVERSCALE") ? "<b>$namAmp{$amplitude}</b> ($duree_sat s)" : "$namAmp{$amplitude}"):"");
		my $amplitude_img = "/icons/signal_amplitude_".lc($amplitude).".png";
		if (! -e "$WEBOBS{ROOT_CODE}/$amplitude_img" ) {
			$amplitude_img = "/icons/signal_amplitude_.png";
		}
		$html .= "<td nowrap>$amplitude_texte</td>";

		# --- duree
		$html .= "<td style=\"text-align:right;\">".($duree ? sprintf("%1.1f&nbsp;%s",$duree,$unite):"")."</td>";

		# --- S-P
		$html .= "<td style=\"text-align:right;\">".($s_moins_p eq "NA" ? "&nbsp;" : "$s_moins_p")."</td>";

		# --- link to the waveform signal
		$html .= "<td>";
		#djl-was: if (length($suds)==12 && substr($suds,10,1) eq '.') {
		#if (length($suds)==12 && substr($suds,8,1) eq '.') {
		#	for(@suds_liste) {
		#		$html .= "<a href=\"$dirTriggerUrn/$_\"><img title=\"Pointés $_\" src=\"/icons/signal_pointe.png\" border=\"0\"></a>";
		#	}
		#} elsif (-f "$dirTrigger/$suds2_pointe") {
		#	for my $lettre ("a".."z") {
		#		$suds2_pointe = "${suds_racine}_${lettre}.${suds_ext}";
		#		if (-f "$dirTrigger/$suds2_pointe") {
		#			$html .= "<a href=\"$dirTriggerUrn/$suds2_pointe\"><img title=\"Pointés $suds2_pointe\" src=\"/icons/signal_pointe.png\" border=\"0\"></a>";
		#		}
		#	}
		#} elsif (-f "$MC3{PATH_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds") {
		#	$html .= "<a href=\"$MC3{WEB_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds\" title=\"Signaux $suds\"><img src=\"/icons/signal_non_pointe.png\" border=\"0\"></a>";
		#} elsif (-f "$MC3{PATH_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds") {
		#	$html .= "<a href=\"$MC3{WEB_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds\" title=\"Signaux $suds\"><img src=\"/icons/signal_non_pointe.png\" border=\"0\"></a>";
		#} elsif (-f "$WEBOBS{RACINE_SIGNAUX_SISMO}/$diriaspei/$suds") {
		#	$html .= "<a href=\"$WEBOBS{WEB_RACINE_SIGNAUX}/$diriaspei/$suds\" title=\"Signaux $suds\"><img src=\"/icons/signal_non_pointe.png\" border=\"0\"></a>";
		#} elsif ($suds eq $nosuds) {
		#	$html .= "<img src=\"/icons/nofile.gif\" title=\"Pas de fichier\">";
		#} elsif ($seedlink) {
			# [FXB] AJOUTER &all=1 lorsque le serveur ArcLink acceptera les wildcards...
		$html .= "<A href=\"$mseedreq&s3=$suds&t1=$begin&ds=$durmseed\" target=\"_blank\" onMouseOut=\"nd()\" onMouseOver=\"overlib('miniSEED file',WIDTH,110)\"><IMG src=\"/icons/"
			.($mod[0] && $mod[0] eq "manual" ? "signal_pointe.png":"signal_non_pointe.png")."\" border=\"0\"></A>";
		#} else {
		#	$html .= "<span style=\"font-size:6pt\">($suds)</span>";
		#}
		$html .= "</td>";

		#print "<td>$sc3id</td>";

		# --- link to Sefran screenshot
		$html .= "<td>";
		#FB-was: my $event_img_subdir = "$evt_annee4/$MC3{PATH_IMAGES}/$evt_annee4$evt_mois/$MC3{FILE_PREFIX}$event_img";
		my $event_img_subdir = "$evt_annee4/$MC3{PATH_IMAGES}/$evt_annee4$evt_mois";
		my $event_img_path = "$MC3{ROOT}/$event_img_subdir/$event_img";

		# Split the MC3 column value on commas in case multiple images were to be displayed
		my @img_list = map { $_ =~ s/^\s+|\s+$//g; $_; } split(/,/, "$event_img");

		if (@img_list) {
			# Define the icon visible in the MC3 'Sefran' column
			# (wolbtarget designates the gallery of images to display defined below)
			$html .= "<img style=\"cursor:pointer;\" wolbtarget=\"event-img-$id_evt\" border=\"0\" src=\"$amplitude_img\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$imagePOPUP',CAPTION,'$imageCAPTION')\">";

			# Add all collected images to a unique common gallery (same wolbset)
			for my $img (@img_list) {
				$html .= "<span wolbset=\"event-img-$id_evt\" wolbsrc=\"$MC3{PATH_WEB}/$event_img_subdir/$img\" ></span>";
			}
		} else {
			# No image was designated in the MC3 entry
			$html .= "&nbsp;";
		}

		# --- operator
		$html .= "</td><td>$operator</td>";

		# --- comment
		$html .= "<td style=\"text-align:left;\"><i>$comment</i></td>";

		# S'il y a au moins une localisation correspondante à l'événement: extraction des infos et calculs
		$ii = 0;
		for (@dat) {
		# S'il y a une localisation validée, on n'affiche pas la localisation automatique
			if ( ($isNotManuel && ($cod[$ii] eq "XXX  ")) || $cod[$ii] ne "XXX  " ) {
			# Si la localisation est automatique, surlignage
				# S'il y en a plus d'une, elles sont mises sur des lignes en-dessous, qui ne répetent pas les dates/heures
				if ($ii > 0) {
					$html .= "</td></tr><tr><td colspan=16>";
				}
				# Distance et direction d'après B3
				my $noloc = 0;
				$noloc = 1 if (grep(/^$typ[$ii]$/,@nolocation_types));
				my $sc3AutoStyle = ($mod[$ii] eq 'automatic' || $noloc == 1 ? "color:gray":"");
				my @b3;
				my $town;
				my $pga;
				my $pgamax;
				my $dir;
				my $dkm;
				my $ems;
				my $emsmax;
				if ($bcube[$ii]) {
					@b3 = split(/\|/,$bcube[$ii]);
					$b3[2] =~ s/\'/\`/g;
					$town = $b3[2];
					#DL-was: if ($b3[4] != $WEBOBS{SHAKEMAPS_COMMUNES_PLACE}) {
					if ($b3[3] ne $MC3{CITIES_PLACE}) {
						$town = $b3[3];
					}
					$pga = attenuation(($mag[$ii] ? $mag[$ii]:0),sqrt($b3[0]**2 + ($dep[$ii] ne "" ? $dep[$ii]**2:0)));
					#DL-was: my $pgamax = $pga*$WEBOBS{SHAKEMAPS_SITE_EFFECTS};
					#FB-was: $pgamax = $pga*$MC3{CITIES_SITE_EFFECTS};
					$pgamax = $pga*($b3[4] > 0 ? $b3[4]:3);
					$dir = compass($b3[1]);
					$dkm = sprintf("%5.1f",$b3[0]);
					$dkm =~ s/\s/&nbsp;&nbsp;/g;
					$ems = pga2msk($pga);
					$emsmax = pga2msk($pgamax);
				}
				my $M_A = "<b><span style=color:".($mod[$ii] eq 'manual' ? "green>M":"red>A")."</span></b>";

				# Info-bulle avec les détails de la localisation
				$html .= "<td nowrap style=\"text-align:left;$sc3AutoStyle\">$M_A</td>\n";
				$html .= "<td nowrap style=\"text-align:left;$sc3AutoStyle\" onMouseOut=\"nd()\" onMouseOver=\"overlib('";
				if ($noloc == 0 && $lat[$ii]) {
					$html .= ($mty[$ii] && $mag[$ii] ? sprintf("%s = <b>%1.2f</b><br>",$mty[$ii],$mag[$ii]):"")
					.($lat[$ii] < 0 ? sprintf("<b>%2.2f°S</b>",-$lat[$ii]):sprintf("<b>%2.2f°N</b>",$lat[$ii]))
					."&nbsp;&nbsp;"
					.($lon[$ii] < 0 ? sprintf("<b>%2.2f°W</b>",-$lon[$ii]):sprintf("<b>%2.2f°E</b>",$lon[$ii]))
					.($dep[$ii] ? "&nbsp;&nbsp;".sprintf("<b>%1.1f km</b>",$dep[$ii]):"")."<br>"
					.(@b3 ? "$dkm km $dir $town<br>":"");
				}
				$html .="$pha[$ii] phases".($qua[$ii] ? " ($qua[$ii])":"")." / $mod[$ii]".($sta[$ii] ne "" ? " ($sta[$ii])":"")."<br>"
					.($mth[$ii] ne "" || $mdl[$ii] ne "" ? "$mth[$ii] / $mdl[$ii]<br>":"")
					.($typ[$ii] ne "" ? "$typ[$ii]<br>":"")
					."<HR>"
					."<i>ID = $cod[$ii]</i>',CAPTION,'$dat[$ii]')\">";
				if ($noloc == 0 && $pha[$ii] >= $MC3{LOCATION_MIN_PHASES} && @b3) {
					$html .= "$dkm km <img src=\"/icons/boussole/".lc($dir).".png\" align=\"middle\" alt=\"$dir\"> $town</td>"
						."<td style=\"$sc3AutoStyle\">".($dep[$ii] ? sprintf("%2.1f",$dep[$ii]):"")."</td>";
				} else {
					$html .= "<i>&nbsp;&nbsp;not locatable</i></td><td></td>";
				}

				# --- Event energy calculation in joules (displayed in the popover for the magnitude column)
				my $popover_attrs = "";
				if ($mag[$ii]) {
					my $mag_disp = sprintf("%.2f %s", $mag[$ii], $mty[$ii]);
					my $energy_disp = sprintf("%.3e", compute_energy($mag[$ii]));
					my $popover_text  = qq(<b>Magnitude:</b> $mag_disp<br>);
					$popover_text .= qq(<b>Energy:</b> $energy_disp J<br>);
					$popover_attrs = qq(onMouseOut="nd()" onMouseOver="overlib('$popover_text', CAPTION, 'Mag / Energy', WIDTH, 140)");
				}

				# --- Magnitude
				$html .= qq(<td style="$sc3AutoStyle" $popover_attrs>)
					.($mty[$ii] && $mag[$ii] ? sprintf("%1.2f&nbsp;&nbsp;%s",$mag[$ii],$mty[$ii]):"")."</td>";

				# --- EMS
					#if ($MC3{SISMOHYP_HYPO_USE} > 0) {
					$html .= "<td class=\"msk\" style=\"$sc3AutoStyle\">".($msk[$ii] ? $msk[$ii]:"")."</td>";
					#}

				# Lien vers le B-Cube
				if ($nomB3[$ii]) {
					$html .= "<td nowrap style=\"color: gray;\" onMouseOut=\"nd()\" onMouseOver=\"overlib('";
					my $fileB3 = "$WEBOBS{ROOT_OUTG}/PROC.$MC3{TREMBLEMAPS_PROC}/$WEBOBS{PATH_OUTG_EVENTS}/$nomB3[$ii]";
					(my $urnB3 = $fileB3 ) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
					my $ext = "";
					if (-f "$fileB3/b3.pdf") {
						$ext = ".pdf";
					} elsif (-f "$fileB3/b3.png") {
						$ext = ".png";
					}
					if ($ext) {
						$html .= "<img src=&quot;$urnB3/b3.jpg&quot;><br>";
					}
					if (@b3) {
						$html .= sprintf("Predicted intensity at:<br><b>%s (%s)</b><br><b>%s</b> (max. %s)",$b3[2],$b3[3],$ems,$emsmax)
					}
					$html .= "',CAPTION,'Rapport B³',WIDTH,80)\">";
					if ($ext) {
						( my $link = readlink("$fileB3/b3$ext") ) =~ s/.pdf//g;
						$html .= "<A href=\"/cgi-bin/showOUTG.pl?grid=PROC.$MC3{TREMBLEMAPS_PROC}&ts=events&g=$nomB3[$ii]/$link\"><IMG  onMouseOver=\"overlib('<img src=&quot;$urnB3/b3.jpg&quot;',CAPTION,'Rapport B³',WIDTH,80)\" src=\"/icons/logo_b3.gif\" border=0></A>";
					# Print a link to remove the B3 file, only if no filter is in use and only for the last 10 lines
					#if ($end_datetime->truncate(to => 'day') == $today
					if ($nbLignesRetenues <= 10
					    and ( (($operator eq "" || $operator eq $CLIENT)
						  && (clientHasEdit(type=>"authprocs",name=>"MC") || clientHasEdit(type=>"authprocs",name=>"$mc3")))
						  || (clientHasAdm(type=>"authprocs",name=>"MC") || clientHasAdm(type=>"authprocs",name=>"$mc3")) )  ) {
						$html .= qq{&nbsp; <a href="/cgi-bin/deleteB3.pl?b3=$nomB3[$ii]/$link&amp;mc=$mc3" title="Rebuild the B³ report" target="_blank" >x</a>};
					}
					} elsif ($emsmax ne 'I') {
						$html .= "<b>$ems</b> ($emsmax)";
					}
				} else {
					$html .= "<td>";
				}
				$html .= "</td></tr>";
			}
			$ii++;
		}
		$html .= ($ii == 0 ? "<td colspan=6>":"")."</td></tr>\n";
		$nbLignesRetenues++;
	}
}

$html .= "</TABLE>\n";

if ($QryParm->{'debug'}) {
	$html .= "<hr>";
	$html .= "<b>Number of lines kept / read: </b> $nbLignesRetenues / $nb<br>";
	$html .= "<b>Dates interval: </b>[".$start_datetime->strftime("%F %Hh").",".$end_datetime->strftime("%F %Hh")."]<br>";
	$html .= "<b>Type criteria: </b>$QryParm->{'type'}<br>";
	$html .= "<b>Durations greater than: </b>$QryParm->{'duree'} s <br>";
	$html .= "<B>User:</b> $CLIENT <br>";
	$html .= join('<br>',@listeCommunes);
}

# ---- Notes/legends area -----------------------------------------------------
#
$html .= "<HR><A name=\"Note\"></A>";

	# legend : build types table ----------------------------------------------
	$html .= "<H2>Event Types</H2>"
		."<TABLE style=\"margin-left:50px\"><TR><TH>Code</TH><TH>Type</TH></TR>\n";
	for (sort(keys(%typesSO))) {
		my $key = $typesSO{$_};
		if ($key ne 'ALL' && $key ne 'TOTAL') {
			$html .= "<TR><TD class=\"code\" style=\"text-align:right;color:$types{$key}{Color};background-color:$types{$key}{BgColor}\">$key</TD>"
				."<TD style=\"text-align:left;vertical-align:middle\">$types{$key}{Name}</TD></TR>\n";
		}
	}
	# note : read from file ---------------------------------------------------
	$html .= "</TABLE>\n"
		."<HR>".WebObs::Wiki::wiki2html(join('',@infoTexte))."<HR>";


# ---- now wrap $html into page html+javascript -------------------------------
#
if ($QryParm->{'dump'} eq "") {
	print $cgi->header(-charset=>'utf-8');
	print <<"ENDTOPOFPAGE";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>$MC3{TITLE}</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/$MC3{CSS}">
</head>
<body>
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js"></script>

<!-- jQuery & FLOT http://code.google.com/p/flot -->
<!--[if lte IE 8]><script language="javascript" type="text/javascript" src="/js/flot/excanvas.min.js"></script><![endif]-->
<script language="javascript" type="text/javascript" src="/js/flot/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.time.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.stack.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.crosshair.js"></script>
<script language="javascript" type="text/javascript" src="/js/flot/jquery.flot.selection.js"></script>
<script language="JavaScript" type="text/javascript" src="/js/mc3.js"></script>

<script language="javascript" type="text/javascript" src="/js/wolb.js"></script>
<link href="/css/wolb.css" rel="stylesheet" />

<script type="text/javascript">
<!--
valFile0 = "$MC3{ROOT}/$MC3{PATH_FILES}/";

function resetDate1(x)
{
	if (x == 0) document.formulaire.m1.value = "01";
	if (x <= 1) document.formulaire.d1.value = "01";
	if (x <= 2) document.formulaire.h1.value = "00";
}

function resetDate2(x)
{
	if (x == 0) document.formulaire.m2.value = "12";
	if (x <= 1) document.formulaire.d2.value = "31";
	if (x <= 2) document.formulaire.h2.value = "23";
}

function effaceFiltre()
{
	document.formulaire.obs.value = "";
}

function dumpData(d) {
	document.formulaire.dump.value = d;
	document.formulaire.setAttribute("target", "_blank");
	document.formulaire.submit();
}

function display() {
	document.formulaire.dump.value = "";
	document.formulaire.setAttribute("target", "");
	document.formulaire.submit();
}

//-->
</script>

ENDTOPOFPAGE

	print $html;

	print <<"ENDBOTOFPAGE";
<script type="text/javascript">
	document.getElementById("attente").style.display = "none";
	plotFlot(document.formulaire.graph.value);
</script>
<style type="text/css">
	#attente
	{
		display: none;
	}
</style>
<br>
</body>
</html>
ENDBOTOFPAGE

} else {
	print "Content-Disposition: attachment; filename=\"$dumpFile\";\nContent-type: text/csv\n\n"
		.join('',@csv);
}

#DL-TBD: no strict "subs";
#DL-TBD: setlocale(LC_NUMERIC,$old_locale);
#DL-TBD: use strict "subs";

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Mallarino, Alexis Bosson, Jean-Marie Saurel, Patrice Boissier, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2019 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
