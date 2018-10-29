#!/usr/bin/perl

=head1 NAME

showHEBDO.pl 

=head1 SYNOPSIS

https://.../cgi-bin/showHebdo.pl?date=..&type=..&tri=..&search=..

=head1 DESCRIPTION

CGI script to process user requests for displaying the HEBDO (or a selection of events from the HEBDO)

This script is responsible for:
- building / displaying the html form that the client will use to 
specify further  selection criteria

- processing these inputs (from its url query string), finally using  
the Hebdo.pm module to format requested WEBOBS display.  

=head1 Query string parameters

 date=      date selection (see Hebdo.pm for interpretation)
 type=      events type selection
 tri=       format
 search=    user string to filter events

=cut

use strict;
use warnings;
use File::Basename;
use Time::Local;
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser  set_message);
my $cgi = new CGI;
set_message(\&webobs_cgi_msg);

# ---- webobs stuff 
use Hebdo;
use WebObs::Config;
use WebObs::Users;
use WebObs::Dates;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use constant { SEC => 0, MIN => 1, HOUR => 2, MDAY => 3, MON => 4, YEAR => 5, WDAY => 6, YDAY => 7, ISDST => 8,};

# ---- get HEBDO definitions 
my %HEBDO = readCfg("$WEBOBS{HEBDO_CONF}");
my %types = readCfg("$HEBDO{FILE_TYPE_EVENEMENTS}");

# ---- Inits
my @cleParamDate = ("Today|$__{'Today'}","Demain|$__{'Tomorow'}","semaineCourante|$__{'This Week'}","moisCourant|$__{'This Month'}","aVenir|$__{'To be coming'}");
my @cleParamTri = ("Type|$__{'by type'}","Date|$__{'by date'}","Calendar|$__{'calendar'}");
  
my $titrePage = "$HEBDO{TITLE}";
  
my @dateListe;
my ($s, $i, $ii, $j, $jj, $d1, $d2);
  
# ---- today's reference (*tod*) and some useful date-strings ...
my $Ctod = time(); my @tod  = localtime($Ctod);
my $jourSemaine = strftime('%w',@tod); 
my $annee       = strftime('%Y',@tod); 
my $todayDate   = strftime('%F',@tod); 
my $numeroSemaine = strftime('%V',@tod); 
my $moisActuel = strftime('%Y-%m',@tod); 
my $displayTodayDate  = l2u(strftime('%A %d %Y',@tod)); 
my $displayAujourdhui = l2u(strftime("$__{'hebdo_long_date_format'}",@tod)); 
my $demainDate = strftime("%F",localtime($Ctod+86400)); 
my $displayDemain = l2u(strftime("$__{'hebdo_long_date_format'}",localtime($Ctod+86400))); 
my $anneeMax = $annee + $HEBDO{FUTURE_YEARS};
my $moisCalendrier = $moisActuel;
  
my $critereDate = "";
my $critereDebut = "";
my $critereFin = "";
  
# get & parse the http query string (url-param)
# ---------------------------------------------
my @option=();
my $QryParm = $cgi->Vars;
$QryParm->{'date'}    ||= $HEBDO{DEFAULT_DATE};
$QryParm->{'type'}    ||= $HEBDO{DEFAULT_TYPE};
$QryParm->{'tri'}     ||= $HEBDO{DEFAULT_TRI};
$QryParm->{'search'}  ||= "";

Hebdo::Params($QryParm->{'search'},$QryParm->{'type'},$QryParm->{'tri'},1); 
Hebdo::Dates($QryParm->{'date'});
my @hebdoContent = Hebdo::Html();

if (($option[0] eq "all") && ($QryParm->{'tri'} eq "Calendar")) { $QryParm->{'tri'} = "Date"; }
@cleParamDate = ("$QryParm->{'date'}|$QryParm->{'date'}",@cleParamDate);

my @calendar = WebObs::Dates::Calendar(month=>$Hebdo::moisCalendrier, ptri=>$QryParm->{'tri'});
  
# ---- Start HTML page output
#print "Content-type: text/html; charset=utf-8\n\n";
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<html><head><title>$titrePage</title>\n",
      "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n</head>\n";
  
# Debut du body et JavaScripts
print "<body>",
    "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>",
    "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>",
    "<!-- overLIB (c) Erik Bosrup -->\n";

# Debut du formulaire de l'Hebdo pour la selection de l'affichage
print "<FORM name=\"formulaire\" action=\"/cgi-bin/$HEBDO{CGI_SHOW}\" method=\"get\">",
      "<P class=\"boitegrise\" align=\"center\">",
      "<TABLE width=\"100%\"><TR><TD style=\"border:0;text-align:left\">".join("",@calendar)."</TD>",
      "<TD style=\"border:0;text-align:right\">",
      "<B>$__{'Time interval'}:</B> <select name=\"date\" size=\"1\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{hebdo_help_time_interval}')\">\n";

for ($HEBDO{BANG}..$anneeMax) {
  push(@cleParamDate,"$_|$_");
}
for (@cleParamDate,"Tout|$__{'All'}") { 
    my ($val,$cle)=split (/\|/,$_);
    if ("$val" eq "$QryParm->{'date'}") { print "<option selected value=$val>$cle</option>\n"; } 
    else { print "<option value=$val>$cle</option>\n"; }
}
print "</select><BR>\n";
print "<B>$__{'Type of event'}:</B> <select name=\"type\" size=\"1\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{hebdo_help_type_event}')\">";
for (keys(%types)) {
	if (WebObs::Users::clientHasRead(type=>'authmisc',name=>"HEBDO$_")) {
		if ("$_" eq "$QryParm->{'type'}") { print "<option selected value=$_>$types{$_}{Name}</option>\n"; }
		else { print "<option value=$_>$types{$_}{Name}</option>\n"; }
	}
}
print "</select><BR>\n";
print "<B>$__{'Presentation'}:</B> <select name=\"tri\" size=\"1\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{hebdo_help_presentation}')\">";
for (@cleParamTri) { 
    my ($val,$cle)=split (/\|/,$_);
    if ("$val" eq "$QryParm->{'tri'}") { print "<option selected value=$val>$cle</option>\n"; } 
    else { print "<option value=$val>$cle</option>\n"; }
}
print "</select><BR>\n";
print "<B>$__{'Filter keyword'}:</B> <input type=\"text\" name=\"search\" value=\"$QryParm->{'search'}\" size=\"10\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{hebdo_help_filter}')\"></TD>";
print "<TD style=\"border:0\"><input type=\"submit\" value=\"$__{'Display'}\">";
print "</TD><TD style=\"border:0; text-align:right\">";
my $reslist = join (',', map { "'HEBDO$_'" } keys(%types));
if (WebObs::Users::clientMaxAuth(type=>'authmisc',name=>"($reslist)") >= EDITAUTH ) {
	print "<BR><BR><B>$__{'Enter'} <a href='/cgi-bin/$HEBDO{CGI_FORM}'>$__{'new event'}</a>.</B>";
}
print "</TD></TR></TABLE></P></FORM>\n";
print @hebdoContent;
  
__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

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

