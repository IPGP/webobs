#!/usr/bin/perl

=head1 NAME

notifyEvent.pl 

=head1 SYNOPSIS

http://..../notifyEvent.pl?... see query string parameters below ...

=head1 DESCRIPTION

Display earthquake notification or "Main Courante" activity bulletin form editor.
This unique script can generate/manage three types of HTML pages:

	- Main (default, initial) page, a list of available notification pages
	- earthquake notification page (event e-mail, tremblemap publication)
	- "Main Courante" activity bulletin form editor

=head1 Query string parameters

 msg=
  quake ... Notify earthquake
  MCbull .. Notify MainCourante activity information bulletin

 mc= 
  MC3 configuration file to be used. Filename only, no path ($WEBOBS{ROOT_CONF} automatically used),
  no extension (.conf automatically used).
  Defaults to $SEFRAN3{MC3_NAME} if it exists or $WEBOBS{MC3_DEFAULT_NAME}

 id= 
  MC event-id, to open an Analysis page for this existing MC event

 header=, limit=, ref=, yref=, mref=, dref=, date=, high= 

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
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
use WebObs::IGN;
use WebObs::Wiki;
use Locale::TextDomain('webobs');
use QML;

# ---- inits ----------------------------------
set_message(\&webobs_cgi_msg);
$|=1;
$ENV{LANG} = $WEBOBS{LOCALE};
my $editOK = 0;
my $userLevel = 0;
$userLevel = 1 if WebObs::Users::clientHasRead(type=>"authprocs",name=>"MC");
$userLevel = 2 if WebObs::Users::clientHasEdit(type=>"authprocs",name=>"MC");
$userLevel = 4 if WebObs::Users::clientHasAdm(type=>"authprocs",name=>"MC");

# ---- get query-string  parameters
my $mc3    = $cgi->url_param('mc');
my $id     = $cgi->url_param('id');
my $header = $cgi->url_param('header');
my $ref    = $cgi->url_param('ref');
my $yref   = $cgi->url_param('yref');
my $mref   = $cgi->url_param('mref');
my $dref   = $cgi->url_param('dref');
my $voies_classiques = $cgi->url_param('va');
my $reglette = $cgi->url_param('rg');
my $date   = $cgi->url_param('date');
my $high   = $cgi->url_param('high');
my $sx     = $cgi->url_param('sx') || 0;
my $replay = $cgi->url_param('replay');

# ---- loads MC3 configuration: requested or Sefran's or default
$mc3 ||= $WEBOBS{MC3_DEFAULT_NAME};
my $mc3conf = "$WEBOBS{ROOT_CONF}/$mc3.conf";
my %MC3 = readCfg("$mc3conf") if (-f "$mc3conf");
my $tremblemapConf = "$WEBOBS{ROOT_CONF}/PROCS/$MC3{TREMBLEMAPS_PROC}/$MC3{TREMBLEMAPS_PROC}.conf";
my %TREMBLEMAP = readCfg("$tremblemapConf") if (-f "$tremblemapConf");;

# ---- checking for authorizations
if (%MC3) {
	if ( WebObs::Users::clientHasRead(type=>"authprocs",name=>"MC")) {
		if ( WebObs::Users::clientHasEdit(type=>"authprocs",name=>"MC")) {
			$editOK = 1;
		}
	} else { die "$__{'Not authorized'} (read)"}
} else { die "$__{'Could not read'} MC configuration $mc3" }

# ---- loads additional configurations:
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
my @amplitudes = readCfgFile("$MC3{AMPLITUDES_CONF}");
my %nomAmp;
for (@amplitudes) {
        my ($key,$nam,$val) = split(/\|/,$_);
        $nomAmp{$key} = $nam;
}

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

# ---- misc inits (menu, external pgms and requests, ...)
#

$MC3{NEW_P_CLEAR_S} ||= 0;

# ---- Date and time for now (UTC)...
my ($Ya,$ma,$da,$Ha,$Ma,$Sa) = split('/',strftime('%Y/%m/%d/%H/%M/%S',gmtime));
my ($Yr,$mr,$dr,$Hr,$Mr,$Sr) = split('/',strftime('%Y/%m/%d/%H/%M/%S',gmtime(time - 10*60)));
my $today = "$Ya-$ma-$da";

# ----
my $titrePage = 'toto';
my @html;

my $s;


my ($Yc,$mc,$dc,$Hc,$Mc) = unpack("a4 a2 a2 a2 a2",$date);
my $fileMC = "$MC3{FILE_PREFIX}$Yc$mc.txt";
my @mc_evt = qx(awk -F'|' '\$1 == $id {printf "\%s",\$0}' $MC3{ROOT}/$Yc/$MC3{PATH_FILES}/$fileMC);


# ---- Retrieve event informations --------------------------------------------
#
my %MC = evtinfo($mc_evt[0]);

my $evtid;
my $agencyid;
my $dat;
my $rms;
my $lat;
my $latE;
my $lon;
my $lonE;
my $dep;
my $depE;
my $gap;
my $pha;
my $mod;
my $sta;
my $mag;
my $mty;
my $mth;
my $mdl;
my $typ;
my $evtmode;
my $bcube;
my $b3_isl;
my $evttype = '';
my $nomB3;

($evtid,$agencyid,$dat,$rms,$lat,$latE,$lon,$lonE,$dep,$depE,$gap,$pha,$mod,$sta,$mag,$mty,$mth,$mdl,$typ) = split(';',$MC{origin});
if($mod eq 'manual') {
	$evtmode = 'm';
}
else {
	$evtmode = 'a';
}
	# calcul de la distance epicentrale minimum (et azimut epicentre/villes)
for (0..$#b3_lat) {
	my $dx = ($lon - $b3_lon[$_])*111.18*cos($lat*0.01745);
	my $dy = ($lat - $b3_lat[$_])*111.18;
	$b3_dat[$_] = sprintf("%06.1f|%g|%s|%s|%g",sqrt($dx**2 + $dy**2),atan2($dy,$dx),$b3_nam[$_],$b3_isl[$_],$b3_sit[$_]);
}
my @xx = sort { $a cmp $b } @b3_dat;
$bcube = $xx[0];
if ($MC3{TREMBLEMAPS_PROC}) {
	$nomB3 = substr($dat,0,4)."/".substr($dat,5,2)."/".substr($dat,8,2)."/$evtid";
}
# Distance et direction d'après B3
my @b3;
my $town;
my $region;
my $pga;
my $pgamax;
my $dir;
my $dkm;
my $ems;
my $emsmax;
if ($bcube) {
	@b3 = split(/\|/,$bcube);
	$b3[2] =~ s/\'/\`/g;
	$town = $b3[2];
	$region = $b3[3];
	#DL-was: if ($b3[4] != $WEBOBS{SHAKEMAPS_COMMUNES_PLACE}) {
	if ($b3[3] ne $MC3{CITIES_PLACE}) {
		$town = $b3[3];
	}
	$pga = attenuation(($mag ? $mag:0),sqrt($b3[0]**2 + ($dep ne "" ? $dep**2:0)));
	#DL-was: my $pgamax = $pga*$WEBOBS{SHAKEMAPS_SITE_EFFECTS};
	#FB-was: $pgamax = $pga*$MC3{CITIES_SITE_EFFECTS};
	$pgamax = $pga*($b3[4] > 0 ? $b3[4]:3);
	$dir = boussole($b3[1]);
	$dkm = sprintf("%5.1f",$b3[0]);
	$ems = pga2msk($pga);
	$emsmax = pga2msk($pgamax);
}


# ---- Notification text -----------------------------------------------------
my $notifyObject = 'tata';

#BEGIN GSE2.0
#MSG_TYPE DATA
#MSG_ID aaaaaaaaaaaaaaaaaaaa source_code
#DATA_TYPE EVENT GSE2.0
# Martinique :  Tectonique à 66 km au Nord-Est de Trinite (Martinique)
#EVENT 
#   Date       Time       Latitude Longitude    Depth    Ndef Nsta Gap    Mag1  N    Mag2  N    Mag3  N  Author          ID 
#       rms   OT_Error      Smajor Sminor Az        Err   mdist  Mdist     Err        Err        Err     Quality
#
#yyyy/mm/dd hh:mm:ss.s    000.0000 0000.0000    000.0    0000 0000 000  aa00.0 00  aa00.0 00  aa00.0 00  aaaaaaaa  aaaaaaaa
#     00.00   +-000.00    0000.0 0000.0  000    +-000.0  000.00 000.00   +-0.0      +-0.0      +-0.0     a a aa
#    (aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
#
#STOP
my $GSE20text = sprintf("BEGIN GSE2.0\\n");
$GSE20text .=   sprintf(  "MSG_TYPE DATA\\n");
$GSE20text .=   sprintf(  "MSG_ID %.20s %s\\n",strftime('%Y-%m-%d_%H:%M:%S',gmtime),$WEBOBS{WEBOBS_ID});
$GSE20text .=   sprintf(  "DATA_TYPE EVENT GSE2.0\\n");
$GSE20text .=   sprintf(  " %s : séisme %s à %s km %s de %s (%s)\\n",$region,$evttype,$dkm,$dir,$town,$region);
$GSE20text .=   sprintf(  "EVENT $evtid\\n");
$GSE20text .=   sprintf(  "   Date       Time       Latitude Longitude    Depth    Ndef Nsta Gap    Mag1  N    Mag2  N    Mag3  N  Author          ID \\n");
$GSE20text .=   sprintf(  "       rms   OT_Error      Smajor Sminor Az        Err   mdist  Mdist     Err        Err        Err     Quality\\n\\n");
$GSE20text .=   sprintf(  "%4.4s/%2.2s/%2.2s %2.2s:%2.2s:%2.2s.%1.1s    ",substr($dat,0,4),substr($dat,5,2),substr($dat,8,2),substr($dat,11,2),substr($dat,14,2),substr($dat,17,2),substr($dat,20,1));
$GSE20text .=   sprintf(  "%8.4f %9.4f    %5.1f              %03d  %-2.2s%4.1f                           ",$lat,$lon,$dep,$gap,$mty,$mag);
$GSE20text .=   sprintf(  "%-8.8s  %-8.8s\\n",$agencyid,substr($evtid,length($evtid)-8,8));
$GSE20text .=   sprintf(  "     %5.2f   +-          %6.1f %6.1f         +-%5.1f                                                  %1.1s i ke\\n",$rms,$latE,$lonE,$depE,$evtmode);
$GSE20text .=   sprintf(  "    (%s DE %s (%s))\\n\\n",uc $dir,uc $town,uc $region);
$GSE20text .=   sprintf(  "STOP\\n");

#BEGIN IMS1.0
#MSG_TYPE DATA
#MSG_ID aaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaa
#DATA_TYPE EVENT IMS1.0
#Event aaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
#   Date       Time        Err   RMS Latitude Longitude  Smaj  Smin  Az Depth   Err Ndef Nsta Gap  mdist  Mdist Qual   Author      OrigID
#yyyy/mm/dd hh:mm:ss.ss  00.00 00.00 000.0000 0000.0000  00.0 000.0 000 000.0  00.0 0000 0000 000 000.00 000.00 a a aa aaaaaaaaa aaaaaaaa
#Magnitude  Err Nsta Author      OrigID
#aaaaa 00.0 0.0 0000 aaaaaaaaa aaaaaaaa
# (aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)
#
#STOP
my $IMS10text = sprintf("BEGIN IMS1.0\\n");
$IMS10text .=   sprintf(  "MSG_TYPE DATA\\n");
$IMS10text .=   sprintf(  "MSG_ID %.20s %s\\n",strftime('%Y-%m-%d_%H:%M:%S',gmtime),$WEBOBS{WEBOBS_ID});
$IMS10text .=   sprintf(  "DATA_TYPE EVENT IMS1.0\\n");
$IMS10text .=   sprintf(  "Event %8.8s séisme %s à %s km %s de %s (%s)\\n",substr($evtid,length($evtid)-8,8),$evttype,$dkm,$dir,$town,$region);
$IMS10text .=   sprintf(  "   Date       Time        Err   RMS Latitude Longitude  Smaj  Smin  Az Depth   Err Ndef Nsta Gap  mdist  Mdist Qual   Author      OrigID\\n");
$IMS10text .=   sprintf(  "%4.4s/%2.2s/%2.2s %2.2s:%2.2s:%2.2s.%2.2s        ",substr($dat,0,4),substr($dat,5,2),substr($dat,8,2),substr($dat,11,2),substr($dat,14,2),substr($dat,17,2),substr($dat,20,2));
$IMS10text .=   sprintf(  "%5.2f %8.4f %9.4f                 %5.1f  %4.1f           %3d               ",$rms,$lat,$lon,$dep,$depE,$gap);
$IMS10text .=   sprintf(  "%1.1s i ke %-9.9s %-8.8s\\n",$evtmode,$agencyid,substr($evtid,length($evtid)-8,8));
$IMS10text .=   sprintf(  "Magnitude  Err Nsta Author      OrigID\\n");
$IMS10text .=   sprintf(  "%-5.5s %4.1f          %-9.9s %-8.8s\\n",$mty,$mag,$agencyid,substr($evtid,length($evtid)-8,8));
$IMS10text .=   sprintf(  " (%s DE %s (%s))\\n\\n",uc $dir,uc $town,uc $region);
$IMS10text .=   sprintf(  "STOP\\n");


# ---- Start building HTML page -----------------------------------------------
#
print $cgi->header(-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<html><head><title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";

# ---- Javascript -------------------------------------------------------------
# ---- Notification text according to the choosen format ----------------------
print "<script language=\"Javascript\">
function notifChange(format)
{
  if(format==\"GSE20\")
    {
    document.getElementById('notificationText').value = \"$GSE20text\";
    }
  else if (format==\"IMS10\")
    {
    document.getElementById('notificationText').value = \"$IMS10text\";
    }
  else
    alert(\"!! Error !! format \" + format);
}
</script>";
# ---- Loads GSE2.0 message by default ---------------------------------------
print "<script language=\"Javascript\">\ndocument.addEventListener(\"DOMContentLoaded\", function() {
  notifChange(\"GSE20\");
})\n</script>";
print "</head><BODY>";
print "<H1>$titrePage</H1>";

# ---- Notification text form ------------------------------------------------
#
print "<form action=\"sendMail.pl\" method=\"POST\">";
print "  <fieldset>
  <legend><H2>Notification par mail <select name=\"format\" onChange=\"notifChange(this.value);\">
    <option value=\"GSE20\" checked=\"checked\">GSE 2.0</option>
    <option value=\"IMS10\">IMS 1.0</option>
    </select>
  </H2></legend>
  <p><H5>Objet <INPUT type=\"text\" size=\"24\" name=\"mailTitle\" value=\"$MC3{TREMBLEMAPS_NOTIFY_SUBJECT}\"></H5></p>\n";


print "  <p><textarea readonly rows=\"17\" cols=\"124\" name=\"mailText\" id=\"notificationText\" style=\"font-family : monospace\">";
print "</textarea>\n  </p>";
	print "  <p><H5>Destinataire <select name=\"dest\">\n";
	for my $dest (split(/;/,$MC3{TREMBLEMAPS_NOTIFY_MAIL_LIST})) {
		my ($mail,$desc) = split(/,/,$dest);
		print "    <option value=\"$mail\">$desc</option>\n";
	}
	print "    </select>\n  </H5></p>";
print "  <input type=\"submit\" name=\"send\" value=\"Envoyer\"/>
  </fieldset>\n</form>";

# ---- B3 form -----------------------------------------------------
#
print "<form action=\"sendMail.pl\" method=\"POST\">";

$notifyObject = sprintf(  "Commmuniqué sur le séisme ressenti du %s (Magnitude %3.1f, %s km à %s de %s)",$dat,$mag,$dkm,$dir,$town);
print "  <fieldset>
  <legend><H2>Communiqué séisme ressenti</H2></legend>
  <p><H5>Objet <INPUT type=\"text\" size=\"124\" name=\"mailTitle\" value=\"$notifyObject\"></H5></p>\n";

# Lien vers le B-Cube
if ($nomB3) {
	my $fileB3 = "$WEBOBS{ROOT_OUTG}/PROC.$MC3{TREMBLEMAPS_PROC}/$WEBOBS{PATH_OUTG_EVENTS}/$nomB3";
	(my $urnB3 = $fileB3 ) =~ s/$WEBOBS{ROOT_OUTG}/\/OUTG/g;
	my $ext = "";
	if (-f "$fileB3/b3.pdf") {
		$ext = ".pdf";
	} elsif (-f "$fileB3/b3.png") {
		$ext = ".png";
	}
	print "  <p><textarea rows=\"15\" cols=\"124\" name=\"mailText\" style=\"font-family : monospace\">";
	my $textfile;
	if ($ext) {
		$textfile = sprintf("$fileB3/mail.txt");
	}
	else {
		$textfile = sprintf("$TREMBLEMAP{REPORT_FELT_FILE}");
	}
	my @infoTexte  = readFile("$textfile");
	print join('',@infoTexte);
	print "\nSi vous avez ressenti ce séisme, merci de témoigner sur le site du BCSF à l'adresse suivante:
    http://www.franceseisme.fr

La Direction de l'$WEBOBS{WEBOBS_ID}";
	print "</textarea>
  </p>\n";
	my @b3s = <$fileB3/???*.jpg>;
	if (-f "$fileB3/b3.jpg") {
	print "   <H5>B3</H5>
  <table>
  <tbody>
  <tr>\n";
		foreach my $file (@b3s) {
			my $filename = basename($file);
			print "    <td><IMG style=\"margin: 1px; background-color: beige; padding: 5px; border: 0; height:112px\" src=\"$urnB3/$filename\"></A></td>\n";
		}
		print "  </tr>\n  <tr>\n";
		@b3s = <$fileB3/???*.pdf>;
		foreach my $file (@b3s) {
			print "    <td><input type=\"radio\" name=\"attached\" value=\"$file\"/></A></td>\n";
		}
		print "  </tr>
  </tbody>
  </table>";
	}
	print "  <p><H5>Destinataire <select name=\"dest\">\n";
	for my $dest (split(/;/,$MC3{TREMBLEMAPS_MAIL_LIST})) {
		my ($mail,$desc) = split(/,/,$dest);
		print "    <option value=\"$mail\">$desc</option>\n";
	}
	print "    </select>\n  </H5></p>";
	print "  <input type=\"submit\" name=\"send\" value=\"Envoyer\"/>\n
  </fieldset>\n</form>";
	}

print "</BODY></HTML>";



# ---- helpers
# ----------------------------------------------------------------------------
sub evtinfo
{
	my %MC;

	($MC{id},$MC{date},$MC{time},$MC{type},$MC{amplitude},$MC{duration},$MC{unit},$MC{overscale},$MC{amount},$MC{s_minus_p},$MC{station},$MC{unique},$MC{sefran},$MC{qml},$MC{image},$MC{operator},$MC{comment}) = split(/\|/,$_[0]);

	$MC{timestamp} = "$MC{date} $MC{time} UT";
	$MC{duration} ||= 10;

	my $comment = htmlspecialchars(l2u($MC{comment}));
        $comment =~ s/'/\\'/g; # this is needed by overlib()

	($MC{year},$MC{month},$MC{day}) = split(/-/,$MC{date});
	($MC{hour},$MC{minute},$MC{second}) = split(/:/,$MC{time});

	if (length($MC{qml}) > 2) {
		if ($MC3{SC3_EVENTS_ROOT} ne "" && $MC{qml} =~ /[0-9]{4}\/[0-9]{2}\/[0-9]{2}\/.+/) {
			my ($qmly,$qmlm,$qmld,$sc3id) = split(/\//,$MC{qml});
			my %QML = qmlorigin("$MC3{SC3_EVENTS_ROOT}/$MC{qml}/$sc3id.last.xml");
			$MC{origin} = "$sc3id;$QML{agency};$QML{time};$QML{rms};$QML{latitude};$QML{latitudeError};$QML{longitude};$QML{longitudeError};$QML{depth};$QML{depthError};$QML{gap};$QML{phases};$QML{mode};$QML{status};$QML{magnitude};$QML{magtype};$QML{method};$QML{model};$QML{type}";
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
			my %QML = qmlfdsn("${fdsnws_url}&format=xml&eventid=$evt_id");
			$MC{origin} = "$evt_id;$QML{agency};$QML{time};$QML{rms};$QML{latitude};$QML{latitudeError};$QML{longitude};$QML{longitudeError};$QML{depth};$QML{depthError};$QML{gap};$QML{phases};$QML{mode};$QML{status};$QML{magnitude};$QML{magtype};$QML{method};$QML{model};$QML{type}";
		}
	}

	return (%MC);
}

__END__

=pod

=head1 AUTHOR(S)

Jean-Marie Saurel, Patrice Boissier

Acknowledgments:

sefran3.pl [2016] by Francois Beauducel and Didier Lafon

mc3.pl [2016] by Francois Beauducel, Didier Mallarino, Alexis Bosson, Jean-Marie Saurel, Patrice Boissier, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014 - Institut de Physique du Globe Paris

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

