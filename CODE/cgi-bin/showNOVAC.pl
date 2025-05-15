#!/usr/bin/perl
#

=head1 NAME

showNOVAC.pl

=head1 SYNOPSIS

http://..../showNOVAC.pl?.... see 'query string parameters' ...

=head1 DESCRIPTION

'NOVAC' is a WebObs FORM.

This script allows the display of NOVAC gas data from the EOS,
an HTML page containing a form for the selection of display parameters,
and the ability to create, edit or delete a data row.

=head1 Configuration NOVAC 

'NOVAC.conf' Example:

  =key|value
  CGI_SHOW|showNOVAC.pl
  CGI_FORM|formNOVAC.pl
  CGI_POST|postNOVAC.pl
  
  BANG|1980
  FILE_NAME|NOVAC.DAT
  TITLE|EOS NOVAC Databank
  
  FILE_CSV_PREFIX|EOS_NOVAC
  DEFAULT_DAYS|365

=head1 Query string parameters

The string query provides the display selections. It is optional,
with default selections defined in the script itself:
this is the case at the first call,
before the user has access to the display selection form.

=over 

=item B<date selection>

 y1= , m1= , d1=
  start date (year,month,day)

 y2= , m2= , d2=
  end date (year, month, day)

=item B<annee=>

Obsolete

=item B<mois=>

Obsolete

=item B<site=>

site (node) to display. If value is I<{nomProc}> , will display all sites
(nodes) from PROC 'nomProc'. Default: all nodes

=item B<affiche=>

=back

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ------------------------------------------------------------
# ---- standard FORMS inits ----------------------------------
# ------------------------------------------------------------

die "You can't view NOVAC reports." if (!clientHasRead(type=>"authforms",name=>"NOVAC"));
my $editOK = (clientHasEdit(type=>"authforms",name=>"NOVAC")) ? 1 : 0;

my $FORM = new WebObs::Form('NOVAC');
my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
    push(@NODESSelList,"\{$p\}|-- $Ps{$p} --");
    my %N = $FORM->nodes($p);
    for my $n (keys(%N)) {
        push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
    }
    %Ns = (%Ns, %N);
}

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $jour  = strftime('%d',@tod);
my $mois  = strftime('%m',@tod);
my $annee = strftime('%Y',@tod);
my $moisActuel = strftime('%Y-%m',@tod);
my $displayMoisActuel = strftime('%B %Y',@tod);
my $today = strftime('%F',@tod);

# ---- FORMS inits -------------------------
my @types    = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));

my @html;
my @csv;
my $affiche;
my $s = "";
my $i = 0;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$today.csv";

my $showMonth;
my $showSite;
my $critereDate = "";

my @cleParamAnnee = ("Old|Old");

for ($FORM->conf('BANG')..$annee) {
    push(@cleParamAnnee,"$_|$_");
}
my @cleParamMois;
for ('01'..'12') {
    $s = l2u(qx(date -d "$annee-$_-01" +"%B")); chomp($s);
    push(@cleParamMois,"$_|$s");
}

my $titrePage = $FORM->conf('TITLE');

my @option = ();

$QryParm->{'annee'}    ||= $annee;
$QryParm->{'mois'}     ||= "All";
$QryParm->{'site'}  ||= "All";
$QryParm->{'affiche'}  ||= "";

# ---- a site requested as {name} means "all nodes for grid (proc) 'name'"
# 
my @gridsites;
if ($QryParm->{'site'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridsites,"$_");
    }
}

# ----

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- start html if not CSV output 

if ($QryParm->{'affiche'} ne "csv") {
    print $cgi->header(-charset=>'utf-8');
    print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<html>\n
  <head>\n
    <title>$titrePage</title>\n
    <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"/>\n
    <link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\"/>\n
  </head>\n
  <body style=\"background-attachment: fixed\">\n
    <div id=\"attente\">Getting data, please wait.</div>\n
    <!--DEBUT DU CODE ROLLOVER 2-->\n
    <div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n
    <script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n
    <!-- overLIB (c) Erik Bosrup -->\n
    <!--FIN DU CODE ROLLOVER 2-->";
}

# ---- selection-form for display 
# 
if ($QryParm->{'affiche'} ne "csv") {
    print "\n
    <form name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">\n
      <p class=\"boitegrise\" align=\"center\">\n
        <b>Select: </b>\n
        <select name=\"annee\" size=\"1\">\n";
    for ("All|All",reverse(@cleParamAnnee)) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'annee'}") {
            print "\n
          <option selected value=$val>$cle</option>\n";
        } else {
            print "\n
          <option value=$val>$cle</option>\n";
        }
    }
    print "\n
        </select>\n
        <select name=\"mois\" size=\"1\">";
    for ("All|All year",@cleParamMois) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'mois'}") {
            print "\n
          <option selected value=$val>$cle</option>\n";
            $showMonth = $cle;
        } else {
            print "\n
          <option value=$val>$cle</option>\n";
        }
    }
    print "\n
        </select>\n
    <select name=\"site\" size=\"1\">";
    for ("All|All sites",@NODESSelList) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'site'}") {
            print "\n
          <option selected value=$val>$cle</option>\n";
            $showSite = "$cle ($val)";
        } else {
            print "\n
          <option value=$val>$cle</option>\n";
        }
    }
    print "\n
        </select>\n
    <input type=\"submit\" value=\"Show\"/>";
    if ($editOK) {
        print "\n
        <input type=\"button\" style=\"margin-left:15px;color:blue;\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"new record\"/>";
    }
    print "\n
      </p>\n
    </form>\n
    <h2>$titrePage</h2>\n
    <p>\n
      Selected month: <b>$showMonth $QryParm->{'annee'}</b><br/>\n
      Selected site: <b>$showSite</b><br/>\n";
}

# ---- Lecture du fichier de données (dans tableau @lignes)

my ($fptr, $fpts) = $FORM->data;
my @lignes = @$fptr;

my $nbData = @lignes - 1;

my $tableHeader;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $txt;
my $fmt = "%0.4f";
my $aliasSite;

$tableHeader = "<tr>";
if ($editOK) {
    $tableHeader = $tableHeader."<th></th>";
}

# ------------------------------------------------------------
# ---- start of specific NOVAC form code ---------------------
# ------------------------------------------------------------
$tableHeader = $tableHeader."<th>Date</th><th>Site</th><th>Flux 1 [kg/s]</th><th>Flux 2 [ton/day]</th><th>Wind speed [m/s]</th>";
$tableHeader = $tableHeader."<th>Wind speed source</th><th>Wind direction [deg]</th><th>Wind direction source</th>";
$tableHeader = $tableHeader."<th>Compass direction [deg]</th><th>Cone angle [deg]</th><th>Tilt [deg]</th><th>Plume height [m]</th>";
$tableHeader = $tableHeader."<th>Plume height source</th><th>Offset</th><th>Plume centre [deg]</th><th>Plume edge 1 [deg]</th>";
$tableHeader = $tableHeader."<th>Plume edge 2 [deg]</th><th>Plume completeness</th><th>Geom error</th>";
$tableHeader = $tableHeader."<th>Spectrometer error</th><th>Scattering error</th><th>Wind error</th>";
$tableHeader = $tableHeader."<th>Nb of valid scans</th>";
$tableHeader = $tableHeader."</tr>\n";

$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    my ($id,$date,$site,$flux1,$flux2,$windSpeed,$windSpeedSource,$windDirection,$windDirectionSource,$compassDirection,$coneAngle,$tilt,$plumeHeight,$plumeHeightSource,$offset,$plumeCentre,$plumeEdge1,$plumeEdge2,$plumeCompleteness,$geomError,$spectrometerError,$scatteringError,$windError,$nbValidScans) = split(/\|/,$_);
    if ($i eq 0) {
        push(@csv,u2l("$date;Code Site;$flux1;$flux2;$windSpeed;$windSpeedSource;$windDirection;$windDirectionSource;$compassDirection;$coneAngle;$tilt;$plumeHeight;$plumeHeightSource;$offset;$plumeCentre;$plumeEdge1;$plumeEdge2;$plumeCompleteness;$geomError;$spectrometerError;$scatteringError;$windError;$nbValidScans"));
    }
    elsif (($_ ne "")
        && (($QryParm->{'site'} eq "All") || ($site =~ $QryParm->{'site'}) || ($site ~~ @gridsites))
        && (($QryParm->{'annee'} eq "All") || ($QryParm->{'annee'} eq substr($date,0,4)) || (($QryParm->{'annee'} eq "Old") && ($date lt $FORM->conf('BANG'))))
        && (($QryParm->{'mois'} eq "All") || ($QryParm->{'mois'} eq substr($date,5,2)))) {

        $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

        my $normSite = normNode(node=>"PROC.$site");
        if ($normSite ne "") {
            $lien = "<a href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><b>$aliasSite</b></a>";
        } else { $lien = "$aliasSite"  }
        $modif = "<a href=\"/cgi-bin/".$FORM->conf('CGI_FORM')."?id=$id\"><img src=\"/icons/modif.png\" title=\"Edit...\" border=0/></a>";
        $efface = "<img src=\"/icons/no.png\" title=\"Remove...\" onclick=\"checkRemove($id)\"/>";

        $texte = $texte."<tr>";
        if ($editOK) {
            $texte = $texte."<td>$modif</td>";
        }
        $texte = $texte."<td>$date</td><td align=center>$lien</td><td align=center>$flux1</td>"
          ."<td align=center>$flux2</td><td align=center>$windSpeed</td>"
          ."<td align=center>$windSpeedSource</td><td align=center>$windDirection</td>"
          ."<td align=center>$windDirectionSource</td><td align=center>$compassDirection</td>"
          ."<td align=center>$coneAngle</td><td align=center>$tilt</td>"
          ."<td align=center>$plumeHeight</td><td align=center>$plumeHeightSource</td>"
          ."<td align=center>$offset</td><td align=center>$plumeCentre</td>"
          ."<td align=center>$plumeEdge1</td><td align=center>$plumeEdge2</td>"
          ."<td align=center>$plumeCompleteness</td><td align=center>$geomError</td>"
          ."<td align=center>$spectrometerError</td><td align=center>$scatteringError</td>"
          ."<td align=center>$windError</td><td align=center>$nbValidScans</td>";
        $texte = $texte."</tr>";
        $txt = "$date;$site;$flux1;$flux2;$windSpeed;$windSpeedSource;$windDirection;$windDirectionSource;$compassDirection;$coneAngle;$tilt;$plumeHeight;$plumeHeightSource;$offset;$plumeCentre;$plumeEdge1;$plumeEdge2;$plumeCompleteness;$geomError;$spectrometerError;$scatteringError;$windError;$nbValidScans";
        push(@csv,u2l($txt));

        $nbLignesRetenues++;
    }
    $i++;
}

# ------------------------------------------------------------
# ---- end of specific NOVAC HTML code -----------------------
# ------------------------------------------------------------

push(@html,"\n
      Number of entries = <b>$nbLignesRetenues</b> / $nbData.\n
    </p>\n
    <p>
      Download data (CSV file format): <a href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&annee=$QryParm->{'annee'}&mois=$QryParm->{'mois'}&site=$QryParm->{'site'}\"><b>$fileCSV</b></a>\n
    </p>\n");

if ($texte ne "") {
    push(@html,"\n
    <table class=\"trData\" width=\"100%\">\n
      $tableHeader\n
      $texte\n
      $tableHeader\n
    </table>");
}

if ($QryParm->{'affiche'} eq "csv") {
    print @csv;
} else {
    print @html;
    print "\n
    <style type=\"text/css\">\n
#attente { display: none; }
    </style>\n
    <br/>\n
  </body>\n
</html>\n";
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon, Patrice Boissier

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

