#!/usr/bin/perl

=head1 NAME

Welcome.pl 

=head1 SYNOPSIS

1) defined in menu.rc as being the WebObs initial page: WELCOME|/cgi-bin/Welcome.pl   

2) uses its own configuration file, pointed to by $WEBOBS{WELCOME_CONF} 

=head1 DESCRIPTION

Builds a WEBOBS welcome page as the name suggests. Page will be loaded by 'index.pl' script 
if referenced by $WEBOBS{WELCOME_PAGE}. 

Has its own configuration file defined by $WEBOBS{WELCOME_CONF}: it further defines  
the contents of predefined areas on the page: see PAGE LAYOUT below.

=head1 PAGE LAYOUT

	----------------------------------------------
	Header
	----------------------------------------------
	|Actu           |Info                        |
	|               |                            |
	|               |----------------------------|
	|               |Gazette today as catg-list  |
	|               |                            |
	|               |                            |
	|               |----------------------------|
	|               |Calendar |                  |
	|               |  wodp   |      timezone(s) |
	|               |         |                  |
	----------------------------------------------       

=head1 {WELCOME_CONF} format 

	TITLE|        html page title   
	HEAD|         the file containing html for Header 
	ACTU|         the file containing html for Actu
	INFO|         the file containing html (wiki) for Info 
	TIMEZONES|    the configuration file for timezone(s)  
	DAYLIGHT|     option to display a world map

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

use WebObs::Gazette;
use WebObs::Config;
use WebObs::Users;
use WebObs::Dates;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Wiki;
use Time::Piece;

set_message(\&webobs_cgi_msg);

my $today = new Time::Piece;
my $jstoday = '"'.$today->gmtime.'"';
my $me = $ENV{SCRIPT_NAME};

# ---- our configuration
my %APARMS;
if (defined($WEBOBS{WELCOME_CONF})) {
	%APARMS = readCfg("$WEBOBS{WELCOME_CONF}");
	if (!%APARMS) { die "Couldn't read $WEBOBS{WELCOME_CONF}" }
} else { die "No WELCOME-PAGE configuration defined $WEBOBS{WELCOME_CONF}" }
my $DN = $APARMS{DAYNIGHT} || "NO";
my $HW = $APARMS{HELLOWORLD} || $__{'Hello World'};

# ---- prepare timezones area, a view of other interesting places datetime 
my $tz_old = $ENV{TZ};
my %fuseaux_horaires = readCfg("$APARMS{TIMEZONES}");
my @liste_heures; my @liste_coords; my $DNcoords;
my @DNcolors = ( "#FF0000", "#00FF00" , "#0000FF", "#FFFF00" ,"#00FFFF", "#FF00FF");
my $DNc = 0;
for (sort keys(%fuseaux_horaires)) {
	$ENV{TZ} = $_;
	my $bullet = "<span style=\"font-weight: bolder; color: $DNcolors[$DNc]\">&#8226;&nbsp;</span>";
	if ($DN eq "YES") {
		push(@liste_heures,sprintf("<div style=\"padding-bottom: 4px;background-color:%s\">%s<b>%s</b>,<br>&nbsp;&nbsp;&nbsp;&nbsp;<i>%s</i></div>",
									($DNc%2)?"#EAE4CE":"transparent",
									$bullet,
									$fuseaux_horaires{$_},
									l2u(qx(date -d "$today" +"\%A \%-d \%B \%Y - \%H:\%M"))));
	} else {
		push(@liste_heures,sprintf("<b>%s</b>, %s<br>",$fuseaux_horaires{$_},l2u(qx(date -d "$today" +"\%A \%-d \%B \%Y - \%H:\%M"))));
	}
	my @ztab = split(/\t/, qx(grep $_ /usr/share/zoneinfo/zone.tab)); # code \t LatLon \t TZname
	if (@ztab) {
		my ($junk,$lats,$lat,$longs,$long) = split(/([+-])/, $ztab[1]); # either +-DDMM+-DDDMM or +-DDMMSS+-DDDMMSS
		if (length($lat) == 4) {
			$lat = substr($lat,0,2)+substr($lat,2,2)/60;
			$long = substr($long,0,3)+substr($long,3,2)/60;
		} else {
			$lat = substr($lat,0,2)+substr($lat,2,2)/60+substr($lat,4,2)/3600;
			$long = substr($long,0,3)+substr($long,3,2)/60+substr($long,5,2)/3600;
		}
		$lat =~ s/,/./; $long =~ s/,/./;
		push(@liste_coords,"[".$lats.$lat.",".$longs.$long.",'".$DNcolors[$DNc]."']");
		$DNc++; $DNc = 0 if ($DNc > $#DNcolors);
	}
	$DNcoords = "[".join(",",@liste_coords)."]";
	$ENV{TZ} = $tz_old;
}
my $displayListeHeures = "<TABLE align=center>";
$displayListeHeures .= "<tr>";
$displayListeHeures .= "<td style=\"border: none\"><canvas height=\"180\" id=\"DNmap\" width=\"360\"></canvas></td>" if ($DN eq "YES");
$displayListeHeures .= "<td style=\"border: none; text-align: right; vertical-align: top\">".join("\n",@liste_heures)."</td>";
$displayListeHeures .= "</tr>";
$displayListeHeures .= "</TABLE>";

# ---- prepare a wodp (datepicker) with calendar display
my $thismonday = $today-($today->day_of_week+6)%7*86400;
my $daynames   = join(',',map { l2u(($thismonday+86400*$_)->strftime('%A'))} (0..6)) ;
my $monthnames = join(',',map { l2u((Time::Piece->strptime("$_",'%m'))->strftime('%B')) } (1..12)) ;
my $wodp_d2    = "[".join(',',map { "'".substr($_,0,2)."'" } split(/,/,$daynames))."]";
my @months = split(/,/,$monthnames); 
my $wodp_m     = "[".join(',',map { "'$_'" } @months)."]";
my @holidaysdef;
my $wodp_holidays = "[]";
if (open(FILE, "<$WEBOBS{FILE_DAYSOFF}")) {  
	while(<FILE>) { push(@holidaysdef,l2u($_)) if ($_ !~/^(#|$)/); }; close(FILE);
	chomp(@holidaysdef);
	$wodp_holidays = "[".join(',',map { my ($d,$t)=split(/\|/,$_); "{d: \"$d\", t:\"$t\"}" } @holidaysdef)."]";
}
my $calendar = "<input id=\"d0\" class=\"wodp\" type=\"text\"/>";

# ---- prepare an inline view of today's Gazette articles 
my $gview = $APARMS{GAZETTE_VIEW} || 'categorylist';
my $empty = $__{$GAZETTE{EMPTY_SELECTION_MSG}} || $__{"Empty"};
my @gazette = WebObs::Gazette::Show(view=>$gview,from=>$today->strftime('%Y-%m-%d'));
@gazette = ("<h3>$empty</h3>") if (!@gazette);

# ---- prepare (read in) all possible user-defined contents 
my @Head  = readFile("$APARMS{HEAD}");
my @Actu  = readFile("$APARMS{ACTU}");
my @Info  = readFile("$APARMS{INFO}");
my @Misc  = readFile("$APARMS{MISC}"); # future use

# ---- Start HTML page output
my $titrePage = "$APARMS{TITLE}";
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<HTML><HEAD><title>$titrePage</title>\n",
      "<META http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
      "<LINK rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">",
      "<LINK rel=\"stylesheet\" type=\"text/css\" href=\"/css/wodp.css\">";
if ($APARMS{AUTOREFRESH_SECONDS} gt 0) {
	print "<META http-equiv=\"refresh\" content=\"$APARMS{AUTOREFRESH_SECONDS}\">";
}
print "\n</HEAD>\n<BODY>\n",
      "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>",
      "<script language=\"JavaScript\" src=\"/js/jquery.js\"></script>",
      "<script language=\"JavaScript\" src=\"/js/wodp.js\"></script>",
      "<script language=\"JavaScript\" src=\"/js/htmlFormsUtils.js\"></script>",
      "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>",
      "<!-- overLIB (c) Erik Bosrup -->";
if ($DN eq "YES") { print "<script language=\"JavaScript\" src=\"/js/daynight.js\"></script>"; }
print <<"FIN";
<script language="JavaScript">
\$(document).ready(function() {
	\$('input#d0').css('display','none').wodp({
		popup: false,
		days: $wodp_d2,
		months: $wodp_m,
		holidays: $wodp_holidays,
		onpicked: function() { if (! \$('input#d0').data('wodpdesc').match(/init|ranging/)) location.href='/cgi-bin/Gazette.pl?gview=calendar&gdate='+\$('input#d0').val(); },
	});
	if(\$('#DNmap').length != 0) {
		initDN($jstoday, \"/icons/DN2.png\", $DNcoords); 
	}
});
</script>
FIN

print "@Head\n";

print "<TABLE class=\"welcome\" width=\"100%\">"; 
	print "<TR class=\"welcome\">"; 
	print "<TD width=\"340\" class=\"welcome\" rowspan=\"2\" valign=\"top\" align=\"center\">\n";
		print "<div class=\"drawer\"><div class=\"welcomedrawer\">&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#ActuID');\">";
		print "$__{'News'}</div><div id=\"ActuID\">";
		print @Actu;
		print "</div></div>";
	print "</TD>";
	print "<TD class=\"welcome\" valign=\"top\">";
		print "<div class=\"drawer\"><div class=\"welcomedrawer\">&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#InfoID');\">";
		print "Info</div><div id=\"InfoID\" style=\"padding-left: 3px;\">";
		print WebObs::Wiki::wiki2html(join("",@Info));
		print "</div></div>";
	print "</TD>";

	print "</TR>";
	print "<TR class=\"welcome\" >"; 
	print "<TD valign=\"top\" class=\"welcome\">"; 
	print "<div class=\"drawer\"><div class=\"welcomedrawer\">&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#GazetteID');\">";
	print "$__{'Gazette Today'}</div><div id=\"GazetteID\" style=\"padding-left: 3px;\">";
	my $fmt_long_date = $__{'gzt_fmt_long_date'} ;
	if ( uc($APARMS{WETON}) =~ /^(Y|YES|OK|ON|1)$/ ) {
		my $weton = "<H2><small><i>~ ".WebObs::Dates::weton($today->strftime('%Y-%m-%d'))." ~</i></small></H2>";
		print $weton;
	}
	print "<h3 style=\"color: #ff6666\">".l2u($today->strftime($fmt_long_date))."</h3>";
	print @gazette;
	print "</div></div>";

	print "<TABLE width=\"100%\" border=\"0\" style=\"margin-top: 3px;\">";
	print "<TR>";
	print "<TD style=\"border:0;padding: 0px;text-align:center; vertical-align: top\"><div class=\"drawer\"><div class=\"welcomedrawer\">&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#CalID');\">";
	print "$__{'Calendar'}&nbsp;</div><div id=\"CalID\" style=\"padding-left: 3px;padding-right: 3px;\">";
	print "<br>$calendar<br>&nbsp;";
	print "</div></div>";
	print "<TD style=\"border:0;padding: 0 0 0 2px;text-align:center; vertical-align: top\"><div class=\"drawer\"><div class=\"welcomedrawer\">&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#TZID');\">";
	#print "$__{'Hello World'}&nbsp;<a href=\"$me\"><img src=\"/icons/refresh.png\"></a></div><div id=\"TZID\" style=\"padding-left: 3px;\">";
	print "$HW&nbsp;<a href=\"$me\"><img src=\"/icons/refresh.png\"></a></div><div id=\"TZID\" style=\"padding-left: 3px;\">";
	print "<br>$displayListeHeures<br>";
	print "</div></div>";
	print "</TABLE>";

print "</TABLE>";

print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Alexis Bosson, Francois Beauducel, Didier Mallarino, Didier Lafon

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

