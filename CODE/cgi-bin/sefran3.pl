#!/usr/bin/perl

=head1 NAME

sefran3.pl

=head1 SYNOPSIS

http://..../sefran3.pl?... see query string parameters below ...

=head1 DESCRIPTION

Display SEFRAN3 data and "Main Courante" form editor. This unique script can generate/manage three
types of HTML pages:

	- Main (default, initial) page, a catalog of available 'hour' images, as thumbnails
	- 'hour' image page, typically selected from p1
	- Analysis/Event page (MC event input or update) page, typically selected from p2 or p1

=head1 Query string parameters

 s3=
  Sefran3 configuration file to be used. Filename only, no path ($WEBOBS{ROOT_CONF} automatically used),
  no extension (.conf automatically used). Defaults to $WEBOBS{SEFRAN3_DEFAULT_NAME}.

 mc3=
  MC3 configuration file to be used. Filename only, no path ($WEBOBS{ROOT_CONF} automatically used),
  no extension (.conf automatically used).
  Defaults to $SEFRAN3{MC3_NAME} if it exists or $WEBOBS{MC3_DEFAULT_NAME}

 id=
  MC event-id, to open an Analysis page for this existing MC event

 header=, status= limit=, ref=, yref=, mref=, dref=, date=, high=

 hideloc=
  hide locations of events in hourly sefran view.
  0: read and display available locations.
  1: don't read or display locations (quicker).
  Defaults to the inverted value of MC3_EVENT_DISPLAY_LOC variable from Sefran configuration.

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use List::Util qw(first);
use Image::Info qw(image_info dim);
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use POSIX qw/strftime/;
use Switch;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Mapping;
use WebObs::Wiki;
use WebObs::QML;
use Locale::TextDomain('webobs');

# ---- inits ----------------------------------
set_message(\&webobs_cgi_msg);
$|=1;
$ENV{LANG} = $WEBOBS{LOCALE};

# ---- get query-string  parameters
my $s3     = $cgi->url_param('s3');
my $mc3    = $cgi->url_param('mc');
my $id     = $cgi->url_param('id');
my $header = $cgi->url_param('header');
my $status = $cgi->url_param('status');
my $trash  = $cgi->url_param('trash');
my $ref    = $cgi->url_param('ref');
my $yref   = $cgi->url_param('yref');
my $mref   = $cgi->url_param('mref');
my $dref   = $cgi->url_param('dref');
my $voies_classiques = $cgi->url_param('va');
my $reglette = $cgi->url_param('rg');
my $date   = $cgi->url_param('date');
my $high   = $cgi->url_param('high');
my $sx     = $cgi->url_param('sx') // 0;
my $replay = $cgi->url_param('replay');
my $limit  = $cgi->url_param('limit');
# $hideloc is read below

# ---- analysis (depouillement) mode ?
my $dep = 0 ;
$dep = 1 if ($date && length($date) > 10) ;

# ---- loads requested Sefran3 configuration or default one
$s3 ||= $WEBOBS{SEFRAN3_DEFAULT_NAME};
my $s3root = "$WEBOBS{PATH_SEFRANS}/$s3";
my $s3conf = "$s3root/$s3.conf";
my %SEFRAN3 = readCfg("$s3conf") if (-f "$s3conf");

my $hideloc = $cgi->url_param('hideloc')
	// not $SEFRAN3{MC3_EVENT_DISPLAY_LOC} =~ m/^(Y|YES|1)$/i;

# ---- loads MC3 configuration: requested or Sefran's or default
$mc3 ||= $SEFRAN3{MC3_NAME} ||= $WEBOBS{MC3_DEFAULT_NAME};
my $mc3conf = "$WEBOBS{ROOT_CONF}/$mc3.conf";
my %MC3 = readCfg("$mc3conf") if (-f "$mc3conf");

# ---- checking for authorizations
my $editOK = 0;
if (%SEFRAN3) {
	if (%MC3) {
		if ( WebObs::Users::clientHasRead(type=>"authprocs",name=>"MC")
			||  WebObs::Users::clientHasRead(type=>"authprocs",name=>"$mc3")) {
			if ( WebObs::Users::clientHasEdit(type=>"authprocs",name=>"MC")
				|| WebObs::Users::clientHasEdit(type=>"authprocs",name=>"$mc3")) {
				$editOK = 1;
			}
		} else { die "$__{'Not authorized'} (read)"}
	} else { die "$__{'Could not read'} MC configuration $mc3" }
} else { die "$__{'Could not read'} Sefran configuration $s3" }

my $userLevel = 0;
$userLevel = 1 if (WebObs::Users::clientHasRead(type=>"authprocs",name=>"MC") || WebObs::Users::clientHasRead(type=>"authprocs",name=>"$mc3"));
$userLevel = 2 if (WebObs::Users::clientHasEdit(type=>"authprocs",name=>"MC") || WebObs::Users::clientHasEdit(type=>"authprocs",name=>"$mc3"));
$userLevel = 4 if (WebObs::Users::clientHasAdm(type=>"authprocs",name=>"MC") || WebObs::Users::clientHasAdm(type=>"authprocs",name=>"$mc3"));

if (!defined($limit)) { $limit = $SEFRAN3{TIME_INTERVALS_DEFAULT_VALUE}; }
# for "last events" mode ($limit = 0), forces real-time ($ref = 0)
if ($limit == 0) { $ref = 0; }

# ---- loads additional configurations:
# channels
my @channels = readCfgFile(exists($SEFRAN3{CHANNEL_CONF}) ? $SEFRAN3{CHANNEL_CONF}:"$s3root/channels.conf");
my @alias;
my @streams;
for (@channels) {
	my ($ali,$cod) = split(/\s+/,$_);
	push(@alias,$ali);
	push(@streams,$cod);
}
# event codes (types)
my %types = readCfg("$MC3{EVENT_CODES_CONF}",'sorted');
my %typesSO;
my $typesJSARR = "[";
for (keys(%types)) {
	$typesSO{$types{$_}{_SO_}} = $_;
	$typesJSARR .= "\"$_\"," if ($types{$_}{WO2SC3} == 1);
}
$typesJSARR .= "]";
# events duration texts
my @durations = readCfgFile("$MC3{DURATIONS_CONF}");
my %duration_s;
for (@durations) {
	my ($key,$nam,$val) = split(/\|/,$_);
	$duration_s{$key} = $val;
}
# events amplitude texts/thresholds
# [TODO]: converts to regular HoH config file...
my %nomAmp;
my %amplitudes;
my @ampfile = readCfgFile("$MC3{AMPLITUDES_CONF}");
my $i = 0;
for (@ampfile) {
        my ($key,$nam,$val,$kb) = split(/\|/,$_);
		my $skey = sprintf("%02d",$i)."_$key"; # adds a prefix "xx_" to the hash key to be sorted
        $nomAmp{$key} = $nam;
        $amplitudes{$skey}{Name} = $nam;
        $amplitudes{$skey}{Value} = $val;
        $amplitudes{$skey}{KBcode} = $kb;
		$i++;
}
# time interval texts + value in hours
my @time_intervals = split(/,/,exists($SEFRAN3{TIME_INTERVALS_LIST}) ? $SEFRAN3{TIME_INTERVALS_LIST}:"0,6,12,24,48");
my %time_limits;
for (@time_intervals) {
	if ($_ == 0) {
		$time_limits{$_} = $__{'Last MC events'};
	} elsif ($_%168 == 0) {
		$time_limits{$_} = ($_/168)." week".($_/168>1 ? "s":"");
	} elsif ($_%24 == 0) {
		$time_limits{$_} = ($_/24)." day".($_/24>1 ? "s":"");
	} else {
		$time_limits{$_} = "$_ hours";
	}
}


# spectrogram
my $sgramOK = isok($SEFRAN3{SGRAM_ACTIVE});

# ---- misc inits (menu, external pgms and requests, ...)
#
my $mseedreq = "/cgi-bin/$WEBOBS{MSEEDREQ_CGI}?s3=$s3&streams=".join(',',@streams);
my $refreshms = ($SEFRAN3{DISPLAY_REFRESH_SECONDS}*1000);
my @menu = readFile("$SEFRAN3{MENU_FILE}");
my $prog ="/cgi-bin/$WEBOBS{CGI_SEFRAN3}?s3=$s3&mc=$mc3";

$SEFRAN3{REF_NORTC} ||= 0;
$MC3{NEW_P_CLEAR_S} ||= 0;
$SEFRAN3{SGRAM_OPACITY} ||= 0.5;
$SEFRAN3{PATH_IMAGES_SGRAM} ||= "sgram";

# ---- Date and time for now (UTC)...
my ($Ya,$ma,$da,$Ha,$Ma,$Sa) = split('/',strftime('%Y/%m/%d/%H/%M/%S',gmtime));
my ($Yr,$mr,$dr,$Hr,$Mr,$Sr) = split('/',strftime('%Y/%m/%d/%H/%M/%S',gmtime(time - 10*60)));
my ($Yy,$my,$dy,$Hy,$My,$Sy) = split('/',strftime('%Y/%m/%d/%H/%M/%S',gmtime(time - 86400)));
my $today = "$Ya-$ma-$da";
my $yesterday = "$Yy-$my-$dy";

# ----
my $titrePage = $SEFRAN3{NAME} ||= $SEFRAN3{TITRE};
my @html;

my $s;
my $i;

if (!$ref) {
	$yref = $Ya;
	$mref = $ma;
	$dref = $da;
} else {
	# permits 29-31 days for all months...
	my $day0 = $dref - 1;
	($yref,$mref,$dref) = split('/',strftime('%Y/%m/%d',gmtime(timegm(0,0,0,1,$mref-1,$yref-1900) + $day0*86400)));
	# if the reference date is specified (not real-time), forces 24 hours minimum display
	$limit = 24 if ($limit < 24);
}
# builds the list of dates and loads associated MC events over the period (+ 1 day)
my @dates;
my @mclist;
for (0 .. $SEFRAN3{DISPLAY_DAYS}) {
	my $ymd = strftime('%Y-%m-%d',gmtime(timegm(0,0,0,$dref,$mref-1,$yref-1900) - $_*86400));
	push(@dates,$ymd) if ($_ < $SEFRAN3{DISPLAY_DAYS});
	my $f = "$MC3{ROOT}/".substr($ymd,0,4)."/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}".substr($ymd,0,4).substr($ymd,5,2).".txt";
	if (-f $f) {
		my @mcday = split(/\n/,qx(awk -F'|' '\$2=="$ymd" {printf "\%s\\n",\$0}' $f));
		push(@mclist,@mcday);
	}
}
my @listeHeures = reverse('00'..'23');


# ---- some display setups
#
my $largeur_vignette = $SEFRAN3{HOURLY_WIDTH}+1;
my $largeur_voies = $SEFRAN3{VALUE_PPI}+1;
my $speed = $SEFRAN3{VALUE_SPEED};
if (($high || $dep) && $SEFRAN3{VALUE_SPEED_HIGH} > 0) {
	$high = 1;
	$speed = $SEFRAN3{VALUE_SPEED_HIGH};
}
my $largeur_image = $speed*$SEFRAN3{VALUE_PPI};
my $hauteur_image = $SEFRAN3{HEIGHT_INCH}*$SEFRAN3{VALUE_PPI}+1;
my $hauteur_label_haut = $SEFRAN3{LABEL_TOP_HEIGHT};
my $hauteur_label_bas = $SEFRAN3{LABEL_BOTTOM_HEIGHT};
my $largeur_fleche = 50;
my $hauteur_titre = 20;
my $dx_mctag = 1*$SEFRAN3{VALUE_PPI};	# channel names image is 1 inch wide
my $sefran_streams = join('","',@streams);

# ---- Start building HTML page -----------------------------------------------
#
print $cgi->header(-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<html><head><title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/$SEFRAN3{CSS}\">\n
<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>\n
<script language=\"JavaScript\" src=\"/js/sefran3.js\" type=\"text/javascript\"></script>\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";

if (!$date && !$ref) {
	print "<meta http-equiv=\"refresh\" content=\"$SEFRAN3{DISPLAY_REFRESH_SECONDS}\">\n";
}

# ---- dynamic Javascript share variables with sefran3.js ----------------------
print <<html;
<script type="text/javascript">

// SCB = Sefran Control Block: javascript global variables shared with cgi
var SCB = {
	PPI : $SEFRAN3{VALUE_PPI},
	SPEED : $speed,
	WIDTHREF : $largeur_image,
	WIDTH : $largeur_image,
	HEIGHT : $SEFRAN3{HEIGHT_INCH},
   HEIGHTIMG : $hauteur_image,
	LABELTOP : $SEFRAN3{LABEL_TOP_HEIGHT},
	LABELBOTTOM : $SEFRAN3{LABEL_BOTTOM_HEIGHT},
	WIDTHVOIES : $largeur_voies,
	CHANNELNB : $#streams + 1,
	STREAMS : ["$sefran_streams"],
	SGRAMOPACITY : $SEFRAN3{SGRAM_OPACITY},
	DX : $dx_mctag,
	SX : $sx,
	PROG : '$prog',
	NOREFRESH: 0
};

// PSE = Predict seismic-events
var PSE = {
        PREDICT_EVENT_TYPE: '$MC3{PREDICT_EVENT_TYPE}',
        PSE_ROOT_CONF: '$MC3{PSE_ROOT_CONF}',
        PSE_ROOT_DATA: '$MC3{PSE_ROOT_DATA}',
        PSE_ALGO_FILEPATH: '$MC3{PSE_ALGO_FILEPATH}',
        PSE_CONF_FILENAME: '$MC3{PSE_CONF_FILENAME}',
        PSE_TMP_FILEPATH: '$MC3{PSE_TMP_FILEPATH}',
        DATASOURCE: '$SEFRAN3{DATASOURCE}',
        SLINKTOOL_PRGM: '$WEBOBS{SLINKTOOL_PRGM}'
};




html

if ($dep) {
	print <<html;
// MECB = MC3 Event Control Block: javascript global variables for Sefran analysis page
// gets initialized/updated by cgi and/or javascript
var MECB = {
	FORM: null,
	MFC: null,
	MINUTE: null,
	PROX: 10,
	CHWIDTH: 120,
	MSEEDREQ: '$mseedreq',
	COLORS: { true: '#ccffcc', false: '#ffcccc' },
	SC3ARR: $typesJSARR,
	MSGS: {
			'staevt': "$__{'Click on first arrival or select station'}",
			'secevt': "$__{'Click on first arrival or enter seconds'}",
			'durevt': "$__{'Click on End of signal or enter duration'}",
			'nbevt' : "$__{'Enter number of event(s)'}",
			'ampevt': "$__{'Select amplitude'}",
			'ovrdur': "$__{'Enter overscale duration'}",
			'notovr': "$__{'Event not flagged OVERSCALE'}",
			'unkevt': "$__{'Event type is unknown/undetermined. Validate as is ?'}",
			'notval': "$__{'You cannot validate an event of type AUTO'}",
			'delete': "$__{'ATT: Do you want PERMANENTLY erase this event from'}",
			'hidevt': "$__{'Do you want to hide this event from'}",
			'resevt': "$__{'Do you want to restore this event in'}"
	      },
	CROSSHAIR: '<span id=crosshairUp></span><span id=crosshairDown></span>',
	NEWPCLEARS: $MC3{NEW_P_CLEAR_S},
	TITLE: '$MC3{TITLE}',
html

	print "	KBtyp: {\n";
	for (keys(%types)) {
		print "		'$_': \"$types{$_}{KBcode}\",\n" if ($types{$_}{KBcode} ne "");
	}
	print "		},\n";
	print "	KBamp: {\n";
	for (sort keys(%amplitudes)) {
		(my $key = $_) =~ s/^.._//g; # removes the xx_ prefix
		print "		'$key': \"$amplitudes{$_}{KBcode}\",\n" if ($amplitudes{$_}{KBcode} ne "");
	}
	print "		}\n};\n\n";

} # endif dep

print "</script>";

# ---- end dynamic Javascript -------------------------------------------------

# ---- dynamic CSS adds to/modifies SEFRAN3.css rules -------------------------
my $crosshair_dy = -($hauteur_image + 10);
my $opacityIE = int($SEFRAN3{MC3_EVENT_OPACITY}*100);

print <<html;
<style type="text/css">
table.sefran {
	margin-left: $SEFRAN3{VALUE_PPI}px;
}
td.rien div,td.fin div {
	width: ${largeur_image}px;
}
.signals img {
	width: ${largeur_image}px;
	height: ${hauteur_image}px;
}
.mctag {
	opacity: $SEFRAN3{MC3_EVENT_OPACITY};
	filter:alpha(opacity=$opacityIE); /* For IE8 and earlier */
}
#eventStart {
	height: ${hauteur_image}px;
}
#eventEnd {
	height: ${hauteur_image}px;
}
#eventSP {
	height: ${hauteur_image}px;
}
#crosshairUp {
	top: ${crosshair_dy};
	height: ${hauteur_image}px;
}
#crosshairDown {
	height: ${hauteur_image}px;
}
</style>
</HEAD>
html
# ---- end dynamic CSS ---------------------------------------------------------

print "<BODY>";
print <<html;
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js"></script>
html

# -----------------------------------------------------------------------------
# ---- Default (initial/catalog) page -----------------------------------------
# -----------------------------------------------------------------------------
if (!$date) {

	# gets the $SEFRAN3{DISPLAY_LAST_MC} last MC events: from the 2 last monthly files, extracts the Nth last event non 'AUTO' and returns 'yyyy-mm-dd|HH'
	#my $last_mc = qx(y=\$(find $MC3{ROOT} -maxdepth 1 -name "????" | sort | tail -n1);find \$y/$MC3{PATH_FILES} -maxdepth 1 -name '*.txt' |sort -r|head -n 2|xargs grep -vhE '(^-|\\|AUTO\\|)'|sed -nr "$SEFRAN3{DISPLAY_LAST_MC}s/^[0-9]+\\|([0-9]{4}-[0-9]{2}-[0-9]{2}\\|[0-9]{2}):.*/\\1/p" | xargs echo -n);
	my $last_mc = qx(y=\$(find $MC3{ROOT} -maxdepth 1 -name "????" | sort | tail -n1);find \$y/$MC3{PATH_FILES} -maxdepth 1 -name '*.txt' |sort -r|head -n 2|xargs grep -vhE '(^-|\\|AUTO\\|)'|sed -nE "$SEFRAN3{DISPLAY_LAST_MC}s/^[0-9]+\\|([0-9]{4}-[0-9]{2}-[0-9]{2}\\|[0-9]{2}):.*/\\1/p" | xargs echo -n);
	my $dt = 0;
	my $last_mn;
	my $lmn;

	# what's the last minute-image ? searches for it and computes realtime delta
	my $last_d = qx(y=\$(find $SEFRAN3{ROOT} -maxdepth 1 -name "????" | sort | tail -n1);find \$y -maxdepth 1| sort | tail -n1 | xargs echo -n);
	if ($last_d) {
		$last_mn = qx/find $last_d -name "??????????????.png"|sort|tail -n1/;
		if ($last_mn) {
			$lmn = basename($last_mn);
			my @lm = (substr($lmn,10,2),substr($lmn,8,2),substr($lmn,6,2),substr($lmn,4,2),substr($lmn,0,4));
			$dt = (timegm(gmtime) - timegm(0,$lm[0],$lm[1],$lm[2],$lm[3]-1,$lm[4]-1900) - 60);
		}
	}

	# title and current data/time
	print "<TABLE style=\"width: 980px; border-collapse: separate\">";
	if ($header) {
		print "<TR><TD align=left style=\"border:0\"><H1>$titrePage".($userLevel == 4 ? " <A href=\"/cgi-bin/formGRID.pl?grid=SEFRAN.$s3\"><IMG src=\"/icons/modif.png\"></A>":"")."</H1>",
			"<P class=\"subMenu\"> <b>&raquo;&raquo;</b> [ ",
			"<A href=\"#\" onClick=\"showmctags();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'showmctags_help'}')\">",
			"<IMG src=\"/icons/mctag.png\" border=1 style=\"vertical-align:middle\"></A> | ";
		print "<A href=\"#\" onClick=\"showsgram();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'showsgram_help'}')\">",
			"<IMG src=\"/icons/sgram.png\" border=1 style=\"vertical-align:middle\"></A> | " if ($sgramOK);
		print "<A href=\"#infos\">$__{'Information'}</A>",
			" | <A href=\"/cgi-bin/$WEBOBS{CGI_MC3}?mc=$mc3\">$MC3{TITLE}</A>",
			" ]</p></TD>";
		if (!$ref || $SEFRAN3{REF_NORTC} == 0) {
			print "<TD id=\"rtclock\" style=\"text-align: center; width: 15%\"><h2 style=\"margin-bottom: 8px\">$Ya-$ma-$da<br>$Ha:$Ma UTC</h2>",
			"&Delta;T ".($dt < 120 ? "= $dt s" : "&lt; ".($dt < 7200 ? int($dt/60 +1)." mn" : int($dt/3600)." hr"))."</TD>";
		}
		print "</TR>";
	}
	# form to display/select dates span (interval) and realtime vs start-date (reference)
	print "<TR id=\"refrow\"><TH colspan=2 align=left>";
		print "<FORM style=\"margin: 0px;\" name=\"form\" action=\"\" method=\"get\">";
		# hidden values to pass all parameters in the form
		print "<INPUT type=hidden name=\"mc\" value=\"$mc3\"/><INPUT type=hidden name=\"s3\" value=\"$s3\"/>";
		print "<B>$__{'Interval'}:</B> <SELECT name=\"limit\" size=\"1\" onchange=\"submit();\">\n";
		for my $id_limit (sort { $a <=> $b } keys %time_limits) {
			 print "<option ".($limit eq $id_limit ? "selected ":"")."value=\"".$id_limit."\">".$time_limits{$id_limit}."</option>\n";
		}
		print "</SELECT>";
		print "<B>&nbsp;&nbsp;$__{'Reference'}:</B> <select name=\"ref\" size=\"1\" onchange=\"mod_ref()\">",
			"<OPTION value=\"0\"".(!$ref ? " selected":"").">$__{'Real-time refresh every'} $SEFRAN3{DISPLAY_REFRESH_SECONDS}s</OPTION>\n",
			"<OPTION value=\"1\"".($ref ? " selected":"").">$__{'Date selection'} ---></OPTION>\n",
			"</SELECT>\n";
		print "<SPAN id=\"formRef\" style=\"visibility:hidden\">";
			print "<SELECT name=\"yref\" size=\"1\">";
			for (reverse($SEFRAN3{BANG}..$Ya)) { print "<OPTION value=\"$_\"".($_ eq $yref ? " selected":"").">$_</OPTION>\n"; }
			print "</SELECT><SELECT name=\"mref\" size=\"1\">";
			for ("01".."12") { print "<OPTION value=\"$_\"".($_ eq $mref ? " selected":"").">$_</OPTION>\n"; }
			print "</SELECT><SELECT name=\"dref\" size=\"1\">";
			for ("01".."31") { print "<OPTION value=\"$_\"".($_ eq $dref ? " selected":"").">$_</OPTION>\n"; }
			print "</SELECT> <INPUT type=button value=\"Display\" onClick=\"submit()\">";
		print "</SPAN>";
		print " <INPUT type=checkbox name=\"header\" value=\"1\"".($header ? " checked":"")." onClick=\"submit()\"/>".$__{'Header'};
		print " <INPUT type=checkbox name=\"status\" value=\"1\"".($status ? " checked":"")." onClick=\"submit()\"/>".$__{'Status'};
		print " <INPUT type=checkbox name=\"trash\" value=\"1\"".($trash ? " checked":"")." onClick=\"submit()\"/>".$__{'Trash'};
		print "</FORM>";
	print "</TH></TR>";
	print "</TABLE>";
	if ($sgramOK) {
		print	"<INPUT type=hidden name=\"sgramslider\" id=\"sgramslider\" value=\"0\">",
		      "<INPUT type=hidden name=\"sgram\" id=\"sgramopacity\" value=\"$SEFRAN3{SGRAM_OPACITY}\">";
	}

	print "<TABLE>";
	my $nb_heures = 0;
	my $nb_vign = 0;
	for (@dates) {
		my $dd = $_;
		my $da = substr($_,0,4);
		my $dm = substr($_,5,2);
		my $dj = substr($_,8,2);
		my $ddd = "$da$dm$dj";
		my $dt = l2u(strftime('%A %-d %B %Y UTC',gmtime(timegm(0,0,0,$dj,$dm-1,$da-1900))));
		my $nb_heures_jour=0;
		for (@listeHeures) {
			my $hh = $_;
			if (($today ne $dd)||($Ha ge $hh)) {
				if (($limit != 0 && ++$nb_heures <= $limit)
					|| ($limit == 0 && ($dd."|".$hh ge $last_mc || $nb_heures++ < $SEFRAN3{DISPLAY_LAST_MC_HOURS}))) {
					$nb_heures_jour++;
					$nb_vign++;
					my $f = "$da/$ddd/$SEFRAN3{PATH_IMAGES_HOUR}/$ddd$hh";
					my $imgopt = "border=\"1\" onClick=\"window.open('$prog&date=$ddd$hh&trash=$trash')\"";
					print "<TR><TD class=\"sefran\" align=center>&nbsp;$da-$dm-$dj&nbsp;<br><font size=\"4\">&nbsp;<b>$hh</b></font>h&nbsp;UTC&nbsp;</TD>";
					if (-e "$SEFRAN3{ROOT}/$f.jpg") {
						my $sgramimg = "";
						my $sgramalign = "";
						if ($sgramOK) {
							my $fs = "$SEFRAN3{ROOT}/${f}s.jpg";
							if (-e $fs) {
								if ($nb_vign > 1) {
									my ($w, $h) = dim(image_info($fs));
									$sgramalign = ";left:".($SEFRAN3{HOURLY_WIDTH}-$w)."px !important";
								}
								$sgramimg = "<IMG class=\"sgram sgramhour\" src=\"$SEFRAN3{PATH_WEB}/${f}s.jpg\" style=\"cursor:pointer$sgramalign\" $imgopt>";
							}
						}
						print "<TD class=\"sefran\" style=\"width:$SEFRAN3{HOURLY_WIDTH};height:$SEFRAN3{HOURLY_HEIGHT};text-align:".($nb_vign < 2 ? "left":"right")."\"><DIV style=\"position:relative\">";
						print	"$sgramimg<IMG src=\"$SEFRAN3{PATH_WEB}/$f.jpg\" style=\"cursor:pointer\" $imgopt>";
					} else {
						print "<TD style=\"width:$SEFRAN3{HOURLY_WIDTH}px;height:$SEFRAN3{HOURLY_HEIGHT}px\" class=\"noImage\"><DIV style=\"position:relative;height:100%\">no image";
					}

					# plots MC events over sefran
					for (reverse @mclist) {
						my %MC = mcinfo($_);
						if (($MC{id} > 0 || ($userLevel >= 2 && $trash == 1)) && $userLevel >= 1) {
							# event start and end expressed in days
							my $d0 = $MC{year}*10000 + $MC{month}*100 + $MC{day} + $MC{hour}/24 + $MC{minute}/1440 + $MC{second}/86400;
							my $d1 = $d0 + $MC{duration}*$duration_s{$MC{unit}}/86400;
							if ($d0 < $ddd + ($hh+1)/24 && $d1 >= $ddd + $hh/24) {
								# event start and duration expressed in hour
								my $h0 = $MC{minute}/60 + $MC{second}/3600;
								my $dh = $MC{duration}*$duration_s{$MC{unit}}/3600;
								# event start and duration expressed in pixels
								my $deb_evt = 2 + int($SEFRAN3{HOURLY_WIDTH}*$h0);
								my $dur_evt = 1 + int(0.5 + $SEFRAN3{HOURLY_WIDTH}*$dh);
								# case A: event starts in the current hour
								if ($MC{hour} eq $hh) {
									# case A1: event duration exceeds current hour
									if ($deb_evt + $dur_evt > $SEFRAN3{HOURLY_WIDTH}) {
										$dur_evt = $SEFRAN3{HOURLY_WIDTH} - $deb_evt + 2;
									}
								# case B: event has started in a previous hour
								} else {
									$deb_evt = 2;
									my $hdeb = $MC{hour};
									$hdeb -= 24 if ($hdeb > $hh); # solves event crossover a day
									# case B1: more than 3 hours overlap = full width
									if ($h0 + $dh > $hh - $hdeb + 1) {
										$dur_evt = $SEFRAN3{HOURLY_WIDTH};
									} else {
										$dur_evt = $SEFRAN3{HOURLY_WIDTH}*($h0 + $dh - ($hh-$hdeb)) + 1;
									}
								}
								print "<DIV class=\"mctag\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$MC{info}',CAPTION,'$MC{firstarrival}',BGCOLOR,'$types{$MC{type}}{Color}',FGCOLOR,'#EEEEEE',WIDTH,250)\" onClick=\"window.open('$prog$MC{edit}')\"",
									" style=\"background-color:$types{$MC{type}}{Color};width:$dur_evt;height:$SEFRAN3{HOURLY_HEIGHT};left:$deb_evt;cursor:pointer\">",
									"</DIV>\n";
							}
						}
					}
				print "</DIV></TD></TR>\n";
				}
			}
		}
		if ($nb_heures_jour > 0) {
			print "<TR><TD style=\"border:0\" colspan=2 class=daySefran>&uArr;&nbsp;&nbsp;$dt&nbsp;&nbsp;&uArr;</TD></TR>\n";
		}

	}

	print "</TABLE><BR>";

	# table information about channel streams
	print "<A name=\"infos\"><H2>Informations</H2></A>\n";
	if ($status) {
		my $now_seconds = timegm(gmtime);
		my $Q = qx($WEBOBS{PRGM_ALARM} $SEFRAN3{SEEDLINK_SERVER_TIMEOUT_SECONDS} $WEBOBS{SLINKTOOL_PRGM} -Q $SEFRAN3{SEEDLINK_SERVER});
		my @stream_server = split(/\n/,$Q);

		# read statistics
		my @stat_streams = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:streams]" $last_mn/);
		my @stat_offset = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:offset]" $last_mn/);
		my @stat_median = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:median]" $last_mn/);
		my @stat_rate = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:rate]" $last_mn/);
		my @stat_sampling = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:sampling]" $last_mn/);
		my @stat_drms = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:drms]" $last_mn/);
		my @stat_asymetry = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:asymetry]" $last_mn/);
		my @stat_fdom;

		if ($sgramOK) {
			(my $last_sg = $last_mn) =~ s/$SEFRAN3{PATH_IMAGES_MINUTE}/$SEFRAN3{PATH_IMAGES_SGRAM}/;
			$last_sg =~ s/\.png/s.png/;
			@stat_fdom = split(/,/,qx/$WEBOBS{PRGM_IDENTIFY} -format "%[sefran3:freqdom]" $last_sg/);
		}

		print "<TABLE style=\"padding:2\"><TR><TH rowspan=2>#</TH>",
			"<TH rowspan=2>Alias</TH><TH rowspan=2>Channel</TH><TH rowspan=2>Calibration<br>(count/(m/s))</TH>",
			"<TH rowspan=2>Filter</TH><TH rowspan=2>Peak-Peak<br>(m/s)</TH>",
			"<TH colspan=".($sgramOK ? "7":"6").">Signal statistics on last image<BR>$lmn</TH><TH colspan=4>SeedLink server $SEFRAN3{SEEDLINK_SERVER}</TH><TH rowspan=2>Status</TH></TR>",
			"<TR><TH colspan=2>Offset<br>(&mu;m/s)</TH><TH>Asym.</TH><TH>RMS&Delta;<br>(&mu;m/s)</TH><TH>Acq.<br>(%)</TH><TH>Samp.<br>(Hz)</TH>",
			($sgramOK ? "<TH>Freq<br>(Hz)</TH>":""),
			"<TH>Oldest data</TH><TH>Last data</TH><TH>Buffer</TH><TH>&Delta;T</TH></TR>\n";
		for (@channels) {
			$i++;
			my ($alias,$codes,$calib,$offset,$pp,$color) = split(/\s+/,$_);
			$color =~ s/"//;
			my ($net,$sta,$loc,$cha) = split(/\./,$codes);
			my @chan = grep(/$net *$sta *$loc *$cha/,@stream_server);
			my $idx = first { $stat_streams[$_] eq $codes } 0..$#stat_streams;

			print "<TR><TD style=\"text-align:right\">$i.</TD>",
				"<TD class=\"code\" style=\"color:$color\">$alias</TD><TD class=\"code\">$codes</TD>",
				"<TD style=\"text-align:center\">$calib</TD><TD style=\"text-align:center\">$offset</TD><TD style=\"text-align:center\">$pp</TD>";

			my $ch_nagios = 3; # Nagios 'UNKNOWN' value
			if ($idx ge 0) {
				my ($status_offset,$status_noise) = (1,1);
				if (abs($stat_offset[$idx]) < $SEFRAN3{STATUS_OFFSET_WARNING}) { $status_offset = 0; }
				elsif (abs($stat_offset[$idx]) > $SEFRAN3{STATUS_OFFSET_CRITICAL}) { $status_offset = 2; }
				if ($stat_drms[$idx] != 0 && ($stat_drms[$idx]/$calib) < $SEFRAN3{STATUS_NOISE_WARNING}) { $status_noise = 0; }
				elsif ($stat_drms[$idx] == 0 || ($stat_drms[$idx]/$calib) > $SEFRAN3{STATUS_NOISE_CRITICAL}) { $status_noise = 2; }
				printf("<TD style=\"text-align:right\" ".($status_offset == 0 ? "":"class=\"status-".($status_offset == 1 ? "warning":"critical")."\"").">%1.4f</TD>",1e6*$stat_median[$idx]/$calib);
				printf("<TD style=\"text-align:right\" ".($status_offset == 0 ? "":"class=\"status-".($status_offset == 1 ? "warning":"critical")."\"").">%2.0f%</TD>",100*$stat_offset[$idx]);
				printf("<TD style=\"text-align:right\">%2.0f%</TD>",100*$stat_asymetry[$idx]);
				printf("<TD style=\"text-align:right\" ".($status_noise == 0 ? "":"class=\"status-".($status_noise == 1 ? "warning":"critical")."\"").">%1.4f</TD>",1e6*$stat_drms[$idx]/$calib);
				printf("<TD style=\"text-align:right\">%1.0f</TD>",100*$stat_sampling[$idx]);
				printf("<TD style=\"text-align:center\">%g</TD>",$stat_rate[$idx]);
				printf("<TD style=\"text-align:center\">%1.2f</TD>",$stat_fdom[$idx]) if ($sgramOK);
				if ($status_offset == 0 && $status_noise == 0) {
					$ch_nagios = 0; # Nagios 'OK' value
				} elsif ($status_offset == 2 || $status_noise == 2) {
					$ch_nagios = 2; # Nagios 'CRITICAL' value
				} else {
					$ch_nagios = 1; # Nagios 'WARNING' value
				}
			} else {
				print "<TD colspan=7 class=\"status-standby\" style=\"text-align:center\"><I>not available</I></TD>";
			}

			if (@chan) {
				my ($start,$end) = split(/  -  /,substr($chan[0],18));
				my $start_s = timegm(substr($start,17,2),substr($start,14,2),substr($start,11,2),substr($start,8,2),substr($start,5,2)-1,substr($start,0,4)-1900);
				my $end_s = timegm(substr($end,17,2),substr($end,14,2),substr($end,11,2),substr($end,8,2),substr($end,5,2)-1,substr($end,0,4)-1900);
				my $bl = int(($end_s - $start_s)/60); # ringbuffer length (in minutes)
				my $dt = ($now_seconds - $end_s);
				my $status_delay = 0;
				if ($dt > $SEFRAN3{STATUS_DELAY_CRITICAL}) {
					$status_delay = 2;
					$ch_nagios = 2;
				} elsif ($ch_nagios < 2 && $dt > $SEFRAN3{STATUS_DELAY_WARNING}) {
					$status_delay = 1;
					$ch_nagios = 1;
				}
				print "<TD>$start</TD><TD>$end</TD>",
					"<TD style=\"text-align:right\">"
					.($bl < 60 ? "$bl mn":($bl < 1440 ? int($bl/60 + 0.5)." h":int($bl/1440 + 0.5)." d"))."</TD>";
				print "<TD style=\"text-align:right\" ".($status_delay =~ /0|3/ ? "":"class=\"status-".($status_delay == 1 ? "warning":"critical")."\"").">"
					.($dt < 60 ? "$dt s":($dt < 3600 ? int($dt/60 + 0.5)." mn":($dt < 86400 ? int($dt/3600 + 0.5)." h":int($dt/86400 + 0.5)." d")))."</TD>";
				#if ($dt > $SEFRAN3{ARCLINK_DELAY_HOURS}) {
			} else {
				print "<TD colspan=4 style=\"text-align:center\"><I>not available</I></TD>";
			}
			switch ($ch_nagios) {
				case 0 { print "<TD class=\"status-ok\" style=\"text-align:center\"><B>OK</B></TD>"; }
				case 1 { print "<TD class=\"status-warning\" style=\"text-align:center\"><B>PB</B></TD>"; }
				case 2 { print "<TD class=\"status-critical\" style=\"text-align:center\"><B>HS</B></TD>"; }
				case 3 { print "<TD class=\"status-standby\" style=\"text-align:center\"><B>?</B></TD>"; }
			}
			print "</TR>\n";
		}
		print "</TABLE><BR>\n";
	}

	print "<P>Sefran3 configuration file: <B>$s3</B></P>\n";
	print "<P>Channels parameters file: <B>$SEFRAN3{CHANNEL_CONF}</B></P>\n";
	print "<P>Update window: <B>$SEFRAN3{UPDATE_HOURS} h</B></P>\n";
	print "<P>Datasource: ".($SEFRAN3{DATASOURCE} ne "" ? "<B>$SEFRAN3{DATASOURCE}</B>":"Not configured.")."</P>\n";
	print "<P>Broom wagon: ".($SEFRAN3{BROOMWAGON_ACTIVE} ? ("<B>Active</B> (delay = <B>$SEFRAN3{BROOMWAGON_DELAY_HOURS} h</B>,"
		."update window = <B>$SEFRAN3{BROOMWAGON_UPDATE_HOURS} h</B>, "
		."maximum dead channels = <B>$SEFRAN3{BROOMWAGON_MAX_DEAD_CHANNELS}</B>, "
		."maximum gap = <B>".sprintf("%g%%",$SEFRAN3{BROOMWAGON_MAX_GAP_FACTOR}*100)."</B>)"):"Not active")."</P>\n";

	print "<TABLE><TR><TH></TH><TH>Virtual speed<br>(inches/minute)</TH><TH>Resolution<br>(pixels/second)</TH>",
		"<TH>1-minute image width<br>(pixels)</TH><TH>Density \@100Hz<br>(samples/pixel)</TH></TR>\n",
 		"<TR><TH>Normal view</TH><TD><B>$SEFRAN3{VALUE_SPEED}</B></TD><TD><B>".int($SEFRAN3{VALUE_SPEED}*$SEFRAN3{VALUE_PPI}/60)."</B>",
		"<TD><B>".int($SEFRAN3{VALUE_SPEED}*$SEFRAN3{VALUE_PPI})."</B></TD>",
		"<TD><B>".int(100*60/($SEFRAN3{VALUE_SPEED}*$SEFRAN3{VALUE_PPI}))."</B></TD></TR>\n",
 		"<TR><TH>High-speed view</TH><TD><B>$SEFRAN3{VALUE_SPEED_HIGH}</B></TD><TD><B>".int($SEFRAN3{VALUE_SPEED_HIGH}*$SEFRAN3{VALUE_PPI}/60)."</B>",
		"<TD><B>".int($SEFRAN3{VALUE_SPEED_HIGH}*$SEFRAN3{VALUE_PPI})."</B></TD>",
		"<TD><B>".int(100*60/($SEFRAN3{VALUE_SPEED_HIGH}*$SEFRAN3{VALUE_PPI}))."</B></TD></TR>\n",
		"</TABLE>\n";

	my @notes = readFile("$SEFRAN3{NOTES}");
	print WebObs::Wiki::wiki2html(join("",@notes));

	print "</BODY></HTML>";
}

# -----------------------------------------------------------------------------
# ---- Case: hour and analysis (depouillement) form page -------------------
# -----------------------------------------------------------------------------
if ($date) {
	my ($Yc,$mc,$dc,$Hc,$Mc) = unpack("a4 a2 a2 a2 a2",$date);

	# read in existing events from MC
	my @mc_liste;
	my $f = "$MC3{ROOT}/$Yc/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$Yc$mc.txt";
	if (-e $f) {
		@mc_liste = split(/\n/,qx(awk -F'|' '\$2 == "$Yc-$mc-$dc" && substr(\$3,1,2) == "$Hc" {printf "\%s\\n",\$0}' $f));
	}

	print "<DIV id=\"sefran\">";
	my %MC;
	my $fileMC = "$MC3{FILE_PREFIX}$Yc$mc.txt";
	my $date_deb; # starting date (relative)
	my $date_nbm; # number of files
	my $date_prec = my $dprec = "";
	my $date_suiv = my $dsuiv = "";
	my $idarg = "";

	if ($dep) {
		if ($id) { 	# read event ID from MC + set number of minute-files containing signal + 1
			my @mc_evt = qx(awk -F'|' '\$1 == $id {printf "\%s",\$0}' $MC3{ROOT}/$Yc/$MC3{PATH_FILES}/$fileMC);
			%MC = mcinfo($mc_evt[0]);
			$date_nbm = 1 + int(1 + ($MC{duration}*$duration_s{$MC{unit}} + $MC{second})/60);
		} else {
			$date_nbm = $MC3{WINDOW_LENGTH_MINUTE};
		}
		$date_deb = 0;
		$date_prec = strftime('%Y%m%d%H%M',gmtime(timegm(0,$Mc,$Hc,$dc,$mc-1,$Yc-1900)-60));
		$dprec = strftime('Jump to %Y-%m-%d <b>%H:%M</b>',gmtime(timegm(0,$Mc,$Hc,$dc,$mc-1,$Yc-1900)-60));
		$date_suiv = strftime('%Y%m%d%H%M',gmtime(timegm(0,$Mc,$Hc,$dc,$mc-1,$Yc-1900)+60));
		$dsuiv = strftime('Jump to %Y-%m-%d <b>%H:%M</b>',gmtime(timegm(0,$Mc,$Hc,$dc,$mc-1,$Yc-1900)+60));
		$idarg = "&id=$id";
	} else {
		$date_deb = -1;
		$date_nbm = 61;
		$date_prec = strftime('%Y%m%d%H',gmtime(timegm(0,0,$Hc,$dc,$mc-1,$Yc-1900)-3600));
		$dprec = strftime('Jump to %Y-%m-%d <b>%Hh</b>',gmtime(timegm(0,0,$Hc,$dc,$mc-1,$Yc-1900)-3600));
		$date_suiv = strftime('%Y%m%d%H',gmtime(timegm(0,0,$Hc,$dc,$mc-1,$Yc-1900)+3600));
		$dsuiv = strftime('Jump to %Y-%m-%d <b>%Hh</b>',gmtime(timegm(0,0,$Hc,$dc,$mc-1,$Yc-1900)+3600));
	}

	# prev+next hour 'big arrows'
	if (!$dep && defined($SEFRAN3{BIGARROWS})) {
		print "<div id=\"Larrow\" onClick=\"location.href='$prog&date=$date_prec&sx=1'\" onMouseOut=\"\$('#Larrow').css('opacity',0); nd()\" onMouseOver=\"\$('#Larrow').css('opacity',0.7); overlib('$dprec',WIDTH,150)\">&nbsp;</div>";
		print "<div id=\"Rarrow\" onClick=\"location.href='$prog&date=$date_suiv'\"      onMouseOut=\"\$('#Rarrow').css('opacity',0); nd()\" onMouseOver=\"\$('#Rarrow').css('opacity',0.7); overlib('$dsuiv',WIDTH,150)\">&nbsp;</div>";
	}

	# control-panel fixed box (zoom,mctag toggle,next/prev buttons)
	print "<div class=\"keysbox\"  onMouseOver=\"showkeys();\" onMouseOut=\"hidekeys();\">";
		print "<span class=\"keytitle\">Controls</span>";
		print "<div class=\"keys\">";
			print "<span class=\"mcbouton\" onClick=\"zoom_in();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Increase speed'} (&times;2)')\"><SPAN class=\"keycap\">+</SPAN></span>\n";
			print "<span class=\"mcbouton\" onClick=\"zoom_1();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Base speed'} (1:1)')\"><SPAN class=\"keycap\">=</SPAN></span>\n";
			print "<span class=\"mcbouton\" onClick=\"zoom_out();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Decrease speed'} (&divide;2)')\"><SPAN class=\"keycap\">&minus;</SPAN></span>\n";
			print "<span class=\"mcbouton\" onClick=\"shrinkmctags();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'showmctags_help'}')\"><SPAN class=\"keycap\"><IMG src=\"/icons/mctag.png\" style=\"vertical-align:middle\"></SPAN></span>\n";
			print "<span class=\"mcbouton\" onClick=\"location.href='$prog&date=$date_prec$idarg'\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$dprec')\"><SPAN class=\"keycap\">&larr;</SPAN></span>\n";
			print "<span class=\"mcbouton\" onClick=\"location.href='$prog&date=$date_suiv$idarg'\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$dsuiv')\"><SPAN class=\"keycap\">&rarr;</SPAN></span>\n";
			print "<span class=\"mcbouton\" onClick=\"quit();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Quit this event without saving changes'}')\"><SPAN class=\"keycap\"><IMG src=\"/icons/cancel.png\" style=\"vertical-align:middle\"></SPAN></span>\n";
			if ($sgramOK) {
				print "<BR><DIV class=\"slidecontainer\"><A href=\"#\" onClick=\"showsgram();return false\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'showsgram_help'}')\">",
					"<IMG src=\"/icons/sgram.png\" border=1 style=\"vertical-align:middle\"></A> ",
					"<INPUT type=\"range\" min=\"0\" max=\"10\" value=\"0\" class=\"slider\" name=\"sgramslider\" id=\"sgramslider\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Adjust Spectrogram opacity'}')\"></div>\n",
		         "<INPUT type=hidden name=\"sgram\" id=\"sgramopacity\" value=\"$SEFRAN3{SGRAM_OPACITY}\">";
			}
		print "</div>";
	print "</div>";

	# image of channels
	my $voies = "$SEFRAN3{PATH_WEB}/$Yc/$Yc$mc$dc/$SEFRAN3{PATH_IMAGES_HEADER}/$Yc$mc$dc$Hc\_voies.png";

	# builds the list of minute images
	my @liste_png;
	for ($i = $date_deb; $i < $date_nbm; $i++) {
		my ($Y,$m,$d,$H,$M) = split('/',strftime('%Y/%m/%d/%H/%M',gmtime(timegm(0,($dep ? "$Mc":"0"),$Hc,$dc,$mc-1,$Yc-1900) + $i*60)));
		push(@liste_png,sprintf("%s/%4d/%04d%02d%02d/%s/%04d%02d%02d%02d%02d00",
			$SEFRAN3{ROOT},$Y,$Y,$m,$d,$SEFRAN3{PATH_IMAGES_MINUTE},$Y,$m,$d,$H,$M));
	}
	my $fin = 0;
	my $reload = 0;

	if ($voies_classiques && !$dep) {
		print "<img class=\"voies-permanentes\" src=\"$voies\">\n";
	} else {
		print "<img class=\"voies-dynamiques\" src=\"$voies\">\n";
	}
	print "<TABLE class=\"sefran\"><tr>\n";
	print "<td class=\"signals\"><div style=\"white-space: nowrap;\">";
	for (@liste_png) {
		my $png = qx(basename $_); chomp $png;
		my ($Y,$m,$d,$H,$M,$S) = unpack("a4 a2 a2 a2 a2 a2",$png);
		my $timestamp = "$Y-$m-$d $H:$M UT";
		my $png_file = "$_".($high ? "_high":"").".png";
		if ( -f $png_file ) {
			my $png_web = "$SEFRAN3{PATH_WEB}/$Y/$Y$m$d/$SEFRAN3{PATH_IMAGES_MINUTE}/$png".($high ? "_high":"").".png";
			my $png_sgram = "$SEFRAN3{PATH_WEB}/$Y/$Y$m$d/$SEFRAN3{PATH_IMAGES_SGRAM}/${png}s.png";
			my $mseed = "$mseedreq&t1=$Y,$m,$d,$H,$M,0&ds=60";

			print "<map name=\"$png\"><area href=\"$mseed\" onMouseOut=\"nd()\" ",
				"onMouseOver=\"overlib('$__{'Click to see miniseed file'}<br>$timestamp', WIDTH, 200)\"",
				" shape=rect coords=\"0,0,$largeur_image,$hauteur_label_haut\" alt=\"miniSEED $png\">",
				"<area onMouseOut=\"nd()\" ";
			if ($dep) {
				#DL-was:print " style=\"cursor:crosshair\" onMouseMove=\"ptr=flypointit(event,false);overlib(ptr,WIDTH,180,OFFSETX,0,FULLHTML)\" onClick=\"flypointit(event,true)\"";
				print " style=\"cursor:crosshair\" class=\"flypointit\"";
			} elsif ($userLevel >= 2) {
				print " class=\"flyhour\"  onMouseOver=\"flyhour(this,'$__{'Click to start input Main Courante'}')\"",
					" href=\"$prog&date=$Y$m$d$H$M&s3=$s3\" target=\"_blank\" rel=\"opener\"";
			}
			print " shape=rect coords=\"0,".($hauteur_label_haut + 1).",$largeur_image,".($hauteur_image - $hauteur_label_haut)."\"></map>";
			print	"<img id=\"sgram\" class=\"sgram\" src=\"$png_sgram\" usemap=\"#$png\">" if ($sgramOK);
			print	"<img id=\"png\" class=\"png\" src=\"$png_web\" usemap=\"#$png\">";
		} elsif ( "$Y$m$d$H$M" >= "$Ya$ma$da$Ha$Ma") {
			if (!$fin) {
				print "</div></td><td class=\"fin\"><div>Now<br>$Ya-$ma-$da<br>$Ha:$Ma:$Sa UTC</div></td><td class=\"signals\">";
				if (!$reload && !$dep) {
					print "<script>setTimeout('window.location.reload()',$refreshms)</script>";
					$reload = 1;
				}
				$fin = 1;
			}
		} elsif ( "$Y$m$d$H$M" >= "$Yr$mr$dr$Hr$Mr") {
			print "</td><td class=\"rien recent\"><div><img border=0 width=50 height=50 src=\"/icons/wait.gif\"><br>In progress...<br>$Y-$m-$d<br>$H:$M:$S UTC</div></td><td class=\"signals\">";
			if (!$reload && !$dep) {
				print "<script>setTimeout('window.location.reload()',$refreshms)</script>";
				$reload = 1;
			}
		} else {
			print "</td><td class=\"rien\"><div>No image<br>$Y-$m-$d<br>$H:$M:$S UTC</div></td><td class=\"signals\">";
		}
	}
	print "</td>";

	for (reverse @mc_liste) {
		my %MC = mcinfo($_);
		#DL-was: if (($MC{id} > 0 || $userLevel == 4) && $userLevel >= 1 && $MC{id} != $id && ($MC{minute} - $Mc) <= $date_nbm) {
		if (($MC{id} > 0 || ($userLevel == 4 && $trash == 1)) && $userLevel >= 1 && ($MC{minute} - $Mc) <= $date_nbm) {
			my $deb_evt;
			if ($dep) {
				$deb_evt = 1 + $SEFRAN3{VALUE_PPI} + int($largeur_image*($MC{minute} - $Mc + $MC{second}/60));
			} else {
				$deb_evt = 1 + $SEFRAN3{VALUE_PPI} + int($largeur_image*($MC{minute} + 1 + $MC{second}/60));
			}
			my $dur_evt = 1 + int(0.5 + $largeur_image*$MC{duration}*$duration_s{$MC{unit}}/60);
			if ($MC{id} != $id) {
				print "<DIV class=\"mctag\" style=\"background-color:$types{$MC{type}}{Color};width:$dur_evt;height:$hauteur_image;left:$deb_evt;cursor:pointer\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$MC{info}',CAPTION,'$MC{firstarrival}',BGCOLOR,'$types{$MC{type}}{Color}',WIDTH,250)\"",
					" onClick=\"window.open('$prog$MC{edit}')\"></DIV>\n";
			} else {
				my $dlstripes = "background: repeating-linear-gradient(120deg, white, white 7px, $types{$MC{type}}{Color} 7px, $types{$MC{type}}{Color} 14px);";
				print "<DIV class=\"mctag\" style=\"$dlstripes;width:$dur_evt;height:$hauteur_image;left:$deb_evt;\"></DIV>";
			}
		}
	}

	print "</tr></TABLE>";
	print "</DIV>";

	if ($dep) {
		# default values for mcform;
		# case : editing an existing id or not
		my $date_evt = ($id ? "$MC{date} $MC{hour}:$MC{minute}" : "$Yc-$mc-$dc $Hc:$Mc");
		my $seconde_evt = ($id ? $MC{second} : "");
		my $type_evt = ($id ? $MC{type} : "$MC3{DEFAULT_TYPE}");
		my $amplitude_evt = ($id ? $MC{amplitude} : "$MC3{DEFAULT_AMPLITUDE}");
		my $duree_evt = ($id ? $MC{duration} : "");
		my $unite_evt = ($id ? $MC{unit} : "s");
		my $duree_sat_evt = ($id ? $MC{overscale} : 0);
		my $nb_evt = ($id ? $MC{amount} : 1);
		my $s_moins_p_evt = ($id ? $MC{s_minus_p} : "");$s_moins_p_evt =~ s/^NA$//;
		my $station = $MC{station};
		my $unique_evt = ($id ? $MC{unique} : 0);
		my $operateur = $MC{operator};
		my $comment_evt = ($id ? htmlspecialchars(l2u($MC{comment})) : "");
		# case : 'replay mode' ('replay' and 'editing id' must be exclusive)
		if ($replay && !$id) {
			my @mcreplay = qx(awk -F'|' '\$1 == $replay {printf "\%s",\$0}' $MC3{ROOT}/$Yc/$MC3{PATH_FILES}/$fileMC);
			my %MCreplay = mcinfo($mcreplay[0]);
			$type_evt = $MCreplay{type};
			$amplitude_evt = $MCreplay{amplitude};
		}

		my $modif = 0;

		if ((isok($MC3{LEVEL2_MODIFY_ALL_EVENTS}) && $userLevel ==2) || ($userLevel == 2 && ($operateur eq "" || $operateur eq $USERS{$CLIENT}{UID} || $type_evt eq "AUTO")) || $userLevel == 4 ) {
			$modif = 1;
		}
		# --- mcform: edit form for Main Courante
		print "<DIV id=\"mcform\" class=\"mcform\">",
			"<FORM name=\"formulaire\" action=\"/cgi-bin/editMC3.pl?s3=$s3&mc=$mc3\" method=\"post\" onSubmit=\"return verif_formulaire()\">",
			"<INPUT type=\"hidden\" name=\"date\" value=\"$date\">",
			"<INPUT type=\"hidden\" name=\"year\" value=\"$Yc\">",
			"<INPUT type=\"hidden\" name=\"month\" value=\"$mc\">",
			"<INPUT type=\"hidden\" name=\"day\" value=\"$dc\">",
			"<INPUT type=\"hidden\" name=\"hour\" value=\"$Hc\">",
			"<INPUT type=\"hidden\" name=\"minute\" value=\"$Mc\">",
			"<INPUT type=\"hidden\" name=\"sec\" value=\"0\">",
			"<INPUT type=\"hidden\" name=\"files\" value=\"$MC{qml}\">", # compatibilite MC2: nombre de fichiers
			"<INPUT type=\"hidden\" name=\"fileNameSUDS\" value=\"$s3\">", # pour compatibilite MC2: remplace par la version SEFRAN
			"<INPUT type=\"hidden\" name=\"imageSEFRAN\" value=\"$MC{image}\">",
			"<INPUT type=\"hidden\" name=\"id_evt\" value=\"$id\">",
			"<INPUT type=\"hidden\" name=\"mc\" value=\"$mc3\">",
			"<INPUT type=\"hidden\" name=\"effaceEvenement\" value=\"\">",
			"<H2 style=\"margin: 5px;\">".($id ? ($modif > 0 ? "$__{'Update'}":""):"$__{'Input'}")." $MC3{TITLE}</H2>";
		if ($id) {
			print "<HR><TABLE style=\"border:0\"><TR>";
			if ($modif) {
				print "<TD style=\"border:0\">",
					"<INPUT type=\"button\" value=\"".($id < 0 ? "$__{'Restore'}":"$__{'Hide'}")."\" onClick=\"supprime(1);\">";
				if ($userLevel == 4) {
					print "<INPUT type=\"button\" value=\"$__{'Delete'}\" onClick=\"supprime(2);\">";
				}
				print "</TD>";
			}
			print "<TD style=\"border:0\">$__{'Event'}";
			if ($operateur eq "" || $operateur eq $MC3{SC3_USER}) {
				print " $__{'not validated by operator (automatic)'}";
			} else {
				print " $__{'identified by'} <B>".join(',',WebObs::Users::userName($operateur))."</B>";
			}
			if (length($MC{qml})>2) {
				print "<BR>QML: <B>$MC{qml}</B>";
			}
			print "</TR></TABLE><HR>";
		}

		# list of operators
		print "<P>$__{'Operator'}: <SELECT onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'your name'}')\" name=\"nomOperateur\" size=\"1\">";
		if ($userLevel < 4) {
			print "<OPTION value=\"$USERS{$CLIENT}{UID}\" selected>$USERS{$CLIENT}{FULLNAME}</OPTION>\n";
		} else {
			# list of SEFRAN/MC users
			my %ku;
			for (keys(%USERS)) {
				if ( WebObs::Users::userHasAuth(user=>"$_", type=>'authprocs', name=>'MC',auth=>2 ) || WebObs::Users::userHasAuth(user=>"$_", type=>'authprocs', name=>"$mc3",auth=>2 ) ) { $ku{$USERS{$_}{FULLNAME}} = $_; }
			}
			for (sort(keys(%ku))) {
				print "<option".($USERS{$ku{$_}}{UID} eq $USERS{$CLIENT}{UID} ? " selected":"")." value=$USERS{$ku{$_}}{UID}>$USERS{$ku{$_}}{FULLNAME}</option>";
			}
		}
		print "</SELECT></P>";

		# list of stations
		print "<P>$__{'Station of first arrival'}: <SELECT name=\"stationEvenement\" size=\"1\"",
			" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Select station or click on first phase of signal'}')\">",
			"<OPTION value=\"\">---</OPTION>";
		for ($i = 0; $i <= $#streams; $i++) {
			print "<OPTION value=\"$streams[$i]\"".($streams[$i] eq $station ? " selected":"").">$alias[$i]</OPTION>\n";
		}
		print "</SELECT>";
		print "&nbsp;&nbsp;<INPUT type=\"radio\" name=\"arriveeUnique\" value=\"0\"".($unique_evt ? "" : " checked")."> Multiple",
			"&nbsp;&nbsp;<INPUT type=\"radio\" name=\"arriveeUnique\" value=\"1\"".($unique_evt ? " checked" : "")."> Unique</P>\n";

		# date and time of first arrival
		print "<P>Date, HH:MM : <SELECT name=\"dateEvenement\" size=\"1\">";
		for ($i = -1; $i <= $MC3{WINDOW_LENGTH_MINUTE}; $i++) {
			my $dd = strftime('%Y-%m-%d %H:%M',gmtime(timegm(0,$Mc,$Hc,$dc,$mc-1,$Yc-1900) + $i*60));
			print "<OPTION value=\"$dd\"".($dd eq $date_evt ? " selected":"").">$dd</OPTION>\n";
		}
		print "</SELECT>";

		# seconds of first arrival
		print " $__{'Seconds'}: <INPUT name=\"secondeEvenement\" size=\"4\" value=\"$seconde_evt\"></P>";

		# duration
		print "<P>$__{'Duration'}: <INPUT name=\"dureeEvenement\" size=\"4\" value=\"$duree_evt\"> ";
		print "<SELECT name=\"uniteEvenement\" size=\"1\">";
		for (@durations) {
			my ($key,$nam,$val) = split(/\|/,$_);
			print "<OPTION value=\"$key\"".($unite_evt eq $key ? " selected":"").">$nam</OPTION>";
		}
		print "</SELECT>\n";

		# number of events
		print "&nbsp;&nbsp;$__{'Number of events'} = <INPUT name=\"nombreEvenement\" size=\"4\" value=\"$nb_evt\"></P>\n";

		# S-P
		print "<P>S&minus;P (<I>$__{'Seconds'}</I>): <input size=\"5\" value=\"$s_moins_p_evt\" name=\"smoinsp\">",
			"<span id=\"dist\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Distance according to indicated S-P'}')\"></span>",
			"<span id=\"mag\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Magnitude according to indicated duration and distance'}')\"></span>",
			"<span id=\"tele\"></span></P>";

		# amplitude and saturation
		print "<P>$__{'Max amplitude'}: <SELECT name=\"amplitudeEvenement\" size=\"1\">";
		for ("",sort keys(%amplitudes)) {
			(my $key = $_) =~ s/^.._//g; # removes the xx_prefix
			print "<OPTION value=\"$key\"".($amplitude_evt eq $key ? " selected":"").">$amplitudes{$_}{Name} "
				.($amplitudes{$_}{KBcode} ne "" ? "[$amplitudes{$_}{KBcode}]":"")."</OPTION>\n";
		}
		print "</SELECT></P>\n";
		print "<P>$__{'Overscale duration'} (<I>$__{'Seconds'}</I>): ",
			"<INPUT size=\"5\" value=\"$duree_sat_evt\" name=\"saturationEvenement\"> (0 = $__{'not overscale'})</P>\n";

		# type of event
		print "<P>$__{'Event type'}: <SELECT id=\"eventList\" name=\"typeEvenement\" size=\"1\" onchange=\"maj_type()\">";
		for (sort(keys(%typesSO))) {
			my $key = $typesSO{$_};
			if ($key ne "AUTO" || $id) {
				print "<OPTION id=\"$key\" value=\"$key\"".($type_evt eq $key ? " selected":"").">$types{$key}{Name} "
					.($types{$key}{KBcode} ne "" ? "[$types{$key}{KBcode}]":"")."</OPTION>\n";
			}
		}
		print "</SELECT>\n";

                # Prediction seismic-event
		if ($MC3{PREDICT_EVENT_TYPE} ne "" && $MC3{PREDICT_EVENT_TYPE} ne "NO") {
                        print "<INPUT type=\"hidden\" id=\"pseresults\" >\n";
			print "<INPUT type=\"button\" style=\"display : none \" id=\"pseCompute\" value=\"$__{'COMPUTE'}\" onClick=\"predict_seismic_event_onclick()\"><BR>\n";
                        print "<P id=\"wait\" style=\"display : none; text-align:center\" > $__{'PLEASE WAIT'}</P>\n";
                }

		# link to USGS
		my $ocl = "<A href=\"$MC3{USGS_URL}\" target=\"_blank\"><B>USGS</B></A>";
		$ocl = $MC3{VISIT_LINK} if (defined($MC3{VISIT_LINK}));
		print "&nbsp;<I>&rarr; $__{'Visit'} $ocl</I></P>\n";

		# comment
		print "<P>$__{'Comment'}: <INPUT size=\"52\" id=\"comment\" name=\"commentEvenement\" value=\"$comment_evt\"></P>\n";

		# options for validation and reset
		if ($modif > 0) {
			print "<TABLE style=\"border:0\" width=\"100%\"><TR><TD style=\"border:0\">";
			if (length($MC{qml}) < 3 && $types{$type_evt}{WO2SC3} != -1) {
				print "<P><INPUT type=\"checkbox\" name=\"newSC3event\" value=\"1\""
					." id=\"newSC3event\"".($types{$type_evt}{WO2SC3} && $id ne "" ? " checked":"").">"
					."<LABEL FOR=\"newSC3event\">$__{'Create a new SeisComp ID'}</LABEL></P>\n";
			}
			# print and replay
			if ($id) {
				print "<P><INPUT type=\"checkbox\" name=\"impression\" value=\"1\">$__{'Print signal'}</P>\n";
			} else {
				print "<INPUT type=\"hidden\" name=\"impression\" value=\"$MC3{AUTOPRINT}\">\n";
				print "<INPUT type=\"checkbox\" name=\"replay\" id=\"replay\"";
				print $replay ? " checked >" : ">";  # coming in with replay ==> keep replay as a default
				print "<LABEL for=\"replay\">$__{'Continue with this window'} (Replay!)</LABEL></P>\n";
			}
			print "</TD><TD style=\"border:0;text-align:right\"><INPUT type=\"button\" value=\"Reset\" onClick=\"reset();maj_formulaire()\">",
				"&nbsp;&nbsp;<INPUT type=\"submit\" value=\"".($id ? "$__{'Modify'}":"$__{'Validate'}")."\"></TD></TR></TABLE>\n";
		}
		# downloads miniseed
		print "<HR><TABLE style=\"border:0\"><TR><TD style=\"border:0\">",
			"<INPUT type=\"button\" value=\"$__{'miniSEED file'}\" onclick=\"view_mseed()\"></TD>",
			"<TD style=\"border:0\">",
			"<INPUT type=\"radio\" name=\"voiesMSEED\" value=\"0\"> $__{'Sefran channels'}<BR>",
			"<INPUT type=\"radio\" name=\"voiesMSEED\" value=\"1\" checked> $__{'Sefran stations (all components)'}<BR>",
			"<INPUT type=\"radio\" name=\"voiesMSEED\" value=\"2\"> $__{'SeedLink/ArcLink all available channels (!)'}",
			"</TD></TR></TABLE>\n";

		print "</FORM></DIV>\n";

		# vertical tag-lines for event-start, event-end and eventS-P
		print "<DIV id=\"eventStart\"><TABLE><TR><TD class=\"eventStart\">START</TD></TR></TABLE></DIV>\n",
			"<DIV id=\"eventEnd\"><TABLE><TR><TD class=\"eventEnd\">END</TD></TR></TABLE></DIV>\n";
		print "<DIV id=\"eventSP\"><TABLE><TR><TD class=\"eventSP\">&nbsp;S&nbsp;</TD></TR></TABLE></DIV>\n";
	}

	print "</BODY></HTML>";
}

# ---- helpers
# ----------------------------------------------------------------------------
sub mcinfo
{
	my %MC;

	($MC{id},$MC{date},$MC{time},$MC{type},$MC{amplitude},$MC{duration},$MC{unit},$MC{overscale},$MC{amount},$MC{s_minus_p},$MC{station},$MC{unique},$MC{sefran},$MC{qml},$MC{image},$MC{signature},$MC{comment}) = split(/\|/,$_[0]);

	($MC{operator},$MC{timestamp}) = split('/',$MC{signature});
	$MC{firstarrival} = "$MC{date} $MC{time} UT";
	$MC{duration} ||= 10;

	my $comment = htmlspecialchars(l2u($MC{comment}));
        $comment =~ s/'/\\'/g; # this is needed by overlib()

	($MC{year},$MC{month},$MC{day}) = split(/-/,$MC{date});
	($MC{hour},$MC{minute},$MC{second}) = split(/:/,$MC{time});

	$MC{edit} = "&date=$MC{year}$MC{month}$MC{day}$MC{hour}$MC{minute}&id=$MC{id}";

	$MC{info} = "<SPAN".($MC{id} < 0 ? " style=text-decoration:line-through>":">")
		."<I>by ".join('',WebObs::Users::userName($MC{operator}))."</I><BR>"
		."<I>Duration:</I> <B>$MC{duration} $MC{unit}</B><BR>"
		."<I>Type:</I> <B>$types{$MC{type}}{Name}</B><BR>"
		."<I>Station:</I> <B>$MC{station}</B>".($MC{unique} ? " (unique)":"")."<BR>"
		.($MC{amplitude} ? "<I>Amplitude:</I> <B>$nomAmp{$MC{amplitude}}</B><BR>":"")
		."<I>Comment:</I> <B>$comment</B>"
		."</SPAN>";

	if (length($MC{qml}) > 2) {
		$MC{info} .= "<HR><I>SC3 ID: $MC{qml}</I>";
		if (not $hideloc) {
			my %QML;
			if ($MC3{SC3_EVENTS_ROOT} ne "" && $MC{qml} =~ /[0-9]{4}\/[0-9]{2}\/[0-9]{2}\/.+/) {
				my ($qmly,$qmlm,$qmld,$sc3id) = split(/\//,$MC{qml});
				%QML = qmlorigin("$MC3{SC3_EVENTS_ROOT}/$MC{qml}/$sc3id.last.xml");
			}
			elsif ($MC{qml} =~ /:\/\//) {
				my ($fdsnws_src,$evt_id) = split(/:\/\//,$MC{qml});
				my $fdsnws_url = "";
				if (defined($MC3{FDSNWS_EVENTS_URL})) {
					$fdsnws_url = $MC3{FDSNWS_EVENTS_URL};
				}
				if (length($fdsnws_src) > 0) {
					my $varname = "FDSNWS_EVENTS_URL_$fdsnws_src";
					$fdsnws_url = "$MC3{$varname}";
				}
				%QML = qmlfdsn("${fdsnws_url}&format=xml&eventid=$evt_id");
			}
			$MC{origin} = ($QML{latitude} < 0 ? sprintf("<b>%2.2f°S</b>",-$QML{latitude}):sprintf("<b>%2.2f°N</b>",$QML{latitude}))
				." / ".($QML{longitude} < 0 ? sprintf("<b>%2.2f°W</b>",-$QML{longitude}):sprintf("<b>%2.2f°E</b>",$QML{longitude}))
				.($QML{depth} ? " / ".sprintf("<b>%1.1f km</b>",$QML{depth}):"");

			$MC{info} .= "<br><I>Quality:</I> <B><B>$QML{phases}</B> phases / <SPAN style=color:"
				.($QML{mode} eq 'manual' ? "green>M":"red>A").($QML{status} ne "" ? " ($QML{status})":"")."</B><BR>"
				."<I>Time:</I> <B>$QML{time}</B><br>"
				."<I>Origin:</I> $MC{origin}<br>"
				.($QML{magtype} && $QML{magnitude} ? "<I>$QML{magtype} =</I> <B>$QML{magnitude}</B>":"");
		}
	}

	return (%MC);
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon, Jean-Marie Saurel, Lucie Van Nieuwenhuyze

Acknowledgments:
- afficheSEFRAN.pl [2009] by Alexis Bosson and Francois Beauducel
- frameMC2.pl and formulaireMC2.pl [2004-2009] by Didier Mallarino, Francois Beauducel and Alexis Bosson

=head1 COPYRIGHT

WebObs - 2012-2022 - Institut de Physique du Globe Paris

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
