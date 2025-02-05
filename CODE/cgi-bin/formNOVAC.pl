#!/usr/bin/perl
#

=head1 NAME

formNOVAC.pl 

=head1 SYNOPSIS

http://..../formNOVAC?[id=]

=head1 DESCRIPTION

This script allows the display of the form for editing NOVAC data
 
=head1 NOVAC Configuration

See 'showNOVAC.pl' for a configuration file 'NOVAC.conf'

=head1 Query string parameter

=over

=item B<id=>

id number to be edited. If not provided, the creation of a new record is assumed.

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
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- standard FORMS inits ----------------------------------

die "You can't edit NOVAC reports." if (!clientHasEdit(type=>"authforms",name=>"NOVAC"));

my $FORM = new WebObs::Form('NOVAC');
my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
    my %N = $FORM->nodes($p);
    for my $n (keys(%N)) {
        push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
    }
    %Ns = (%Ns, %N);
}

my $titrePage = "Edit - ".$FORM->conf('TITLE');

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------

my $Ctod  = time();  my @tod  = localtime($Ctod);
my $sel_jour  = strftime('%d',@tod);
my $sel_mois  = strftime('%m',@tod);
my $sel_annee = strftime('%Y',@tod);
my $anneeActuelle = strftime('%Y',@tod);
my $today     = strftime('%F',@tod);

my @html;
my $affiche;
$ENV{LANG} = $WEBOBS{LOCALE};

# ------------------------------------------------------------
# ---- start of specific FORM inits --------------------------
# ------------------------------------------------------------

# loads the source of a value (user defined, calculated, etc.)
my @sources    = readCfgFile($FORM->path."/".$FORM->conf('SOURCES'));

# loads the pre-selected cone angles (60 degrees, 90 degrees, etc.)
my @coneangles = readCfgFile($FORM->path."/".$FORM->conf('CONEANGLES'));

# ---- specific NOVAC fields

my ($sel_site,$sel_flux1,$sel_flux2,$sel_windSpeed,$sel_windSpeedSource,$sel_windDirection,$sel_windDirectionSource,$sel_compassDirection,$sel_coneAngle,$sel_tilt,$sel_plumeHeight,$sel_plumeHeightSource,$sel_offset,$sel_plumeCentre,$sel_plumeEdge1,$sel_plumeEdge2,$sel_plumeCompleteness,$sel_geomError,$sel_spectrometerError,$sel_scatteringError,$sel_windError,$sel_nbValidScans);
$sel_site = $sel_flux1 = $sel_flux2 = $sel_windSpeed = $sel_windDirection = $sel_compassDirection = $sel_coneAngle = $sel_tilt = $sel_plumeHeight = $sel_offset = $sel_plumeCentre = $sel_plumeEdge1 = $sel_plumeEdge2 = $sel_plumeCompleteness = $sel_nbValidScans = "";

# ---- predefined NOVAC fields values

$sel_windSpeedSource = "USER";
$sel_windDirectionSource = "USER";
$sel_plumeHeightSource = "USER";
$sel_geomError = 30;
$sel_spectrometerError = 15;
$sel_scatteringError = 30;
$sel_windError = 30;

# ------------------------------------------------------------
# ---- end of specific FORM inits ----------------------------
# ------------------------------------------------------------

# ---- Menu variables
my @anneeListe = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe  = ('01'..'12');
my @jourListe  = ('01'..'31');

# ---- Start HTML output
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

# ------------------------------------------------------------
# ---- start of specific NOVAC javascript form validation ----
# ------------------------------------------------------------
print "\n
<html>\n
  <head>\n
    <title>$titrePage</title>\n
    <link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\"/>\n
    <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"/>\n
    <script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>\n
    <script type=\"text/javascript\">\n
function check_values()
{
    var flux_ton = 0;
    if(document.formulaire.flux1.value == \"\") { 
        flux_ton = 0;
    } else {
        flux_ton = document.formulaire.flux1.value * 86.4;
    }
    document.formulaire.flux2.value = flux_ton.toFixed(2);
}

function verif_formulaire() {
  if(document.formulaire.site.value == \"\") {
    alert(\"Please enter the site!\");
    document.formulaire.site.focus();
    return false;
  }
  if(document.formulaire.windSpeed.value == \"\" || document.formulaire.windSpeed.value < 0 || document.formulaire.windSpeed.value > 60) {
    alert(\"Wind speed must be in range 1-60 (m/s)\");
    document.formulaire.windSpeed.focus();
    return false;
  }
  if(document.formulaire.windDirection.value == \"\" || document.formulaire.windDirection.value < 0 || document.formulaire.windDirection.value > 360) {
    alert(\"Wind direction must be in range 1-360 (deg.)\");
    document.formulaire.windDirection.focus();
    return false;
  }
  if(document.formulaire.plumeCompleteness.value == \"\" || document.formulaire.plumeCompleteness.value < 0.7 || document.formulaire.plumeCompleteness.value > 1) {
    alert(\"Plume completeness must be in range 0.7-1 (70-100%)\");
    document.formulaire.windDirection.focus();
    return false;
  }
  if(document.formulaire.nbValidScans.value == \"\" || document.formulaire.nbValidScans.value < 1) {
    alert(\"There must be at least 1 valid scan\");
    document.formulaire.nbValidScans.focus();
    return false;
  }
  \$.post(\"/cgi-bin/".$FORM->conf('CGI_POST')."\", \$(\"#theform\").serialize(), function(data) {
    //var contents = \$( data ).find( '#contents' ).text(); 
    alert(data);
    document.location=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\";
  });
}

function calc() {
}
window.captureEvents(Event.KEYDOWN);
window.onkeydown = check_values();

    </script>\n
  </head>\n
  <body style=\"background-color:#E0E0E0\" onLoad=\"calc()\">\n";

# ------------------------------------------------------------
# ---- end of specific NOVAC javascript form validation ------
# ------------------------------------------------------------

print <<"FIN";
    <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
    <script language="JavaScript" src="/js/overlib/overlib.js"></script>
    <!-- overLIB (c) Erik Bosrup -->
    <div id="helpBox"></div>
    <!-- Pour empêcher que la touche ENTER valide le formulaire -->
    <script type="text/javascript">
function stopRKey(evt) {
  var evt = (evt) ? evt : ((event) ? event : null);
  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
  if ((evt.keyCode == 13) && (node.type=="text"))  {return false;}
}
document.onkeypress = stopRKey;
    </script>
FIN

# ---- read data file 
# 
my $message = "Add new entry";
my @ligne;
my $ptr='';
my $fts-1;

# ------------------------------------------------------------
# ---- start of specific NOVAC form code ---------------------
# ------------------------------------------------------------
my ($id,$date,$site,$flux1,$flux2,$windSpeed,$windSpeedSource,$windDirection,$windDirectionSource,$compassDirection,$coneAngle,$tilt,$plumeHeight,$plumeHeightSource,$offset,$plumeCentre,$plumeEdge1,$plumeEdge2,$plumeCompleteness,$geomError,$spectrometerError,$scatteringError,$windError,$nbValidScans) = split(/\|/,$_);
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) == 1) {
        chomp(@ligne);
        ($id,$date,$site,$flux1,$flux2,$windSpeed,$windSpeedSource,$windDirection,$windDirectionSource,$compassDirection,$coneAngle,$tilt,$plumeHeight,$plumeHeightSource,$offset,$plumeCentre,$plumeEdge1,$plumeEdge2,$plumeCompleteness,$geomError,$spectrometerError,$scatteringError,$windError,$nbValidScans) = split (/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            ($sel_annee,$sel_mois,$sel_jour) = split (/-/,$date);
            $sel_site = $site;
            $sel_flux1 = $flux1;
            $sel_flux2 = $flux2;
            $sel_windSpeed = $windSpeed;
            $sel_windSpeedSource = $windSpeedSource;
            $sel_windDirection = $windDirection;
            $sel_windDirectionSource = $windDirectionSource;
            $sel_compassDirection = $compassDirection;
            $sel_coneAngle = $coneAngle;
            $sel_tilt = $tilt;
            $sel_plumeHeight = $plumeHeight;
            $sel_plumeHeightSource = $plumeHeightSource;
            $sel_offset = $offset;
            $sel_plumeCentre = $plumeCentre;
            $sel_plumeEdge1 = $plumeEdge1;
            $sel_plumeEdge2 = $plumeEdge2;
            $sel_plumeCompleteness = $plumeCompleteness;
            $sel_geomError = $geomError;
            $sel_spectrometerError = $spectrometerError;
            $sel_scatteringError = $scatteringError;
            $sel_windError = $windError;
            $sel_nbValidScans = $nbValidScans;
            $message = "Changing entry $QryParm->{id}";
        } else { $QryParm->{id} = ""; }
    } else { $QryParm->{id} = ""; }
}

# ------------------------------------------------------------
# ---- end of specific NOVAC form code -----------------------
# ------------------------------------------------------------

print "\n
    <table width=\"100%\">\n
      <tr>\n
        <td style=\"border:0\">\n
          <h1>$titrePage</h1>\n
          <h2>$message</h2>\n
        </td>\n
      </tr>\n
    </table>\n
    <form name=formulaire id=\"theform\" action=\"\">";
if ($QryParm->{id} ne "") {
    print "\n
      <input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\"/>";
}
print "\n
      <input type=\"hidden\" name=\"oper\" value=\"$CLIENT\"/>\n
      <table style=border:0 onMouseOver=\"calc()\">\n
        <tr>\n
          <td style=border:0 valign=top>\n
        <fieldset>
              <legend>Main data</legend>\n
          <p class=parform>\n
            <b>Date: </b>\n
                <select name=annee size=\"1\">";
for (@anneeListe) {
    if ($_ == $sel_annee) {
        print "\n
                  <option selected value=$_>$_</option>";
    } else {
        print "\n
                  <option value=$_>$_</option>";
    }
}
print "\n
                </select>\n
                <select name=mois size=\"1\">";
for (@moisListe) {
    if ($_ == $sel_mois) {
        print "\n
                  <option selected value=$_>$_</option>";
    } else {
        print "\n
                  <option value=$_>$_</option>";
    }
}
print "\n
                </select>\n
                <select name=jour size=\"1\">";
for (@jourListe) {
    if ($_ == $sel_jour) {
        print "\n
                  <option selected value=$_>$_</option>";
    } else {
        print "\n
                  <option value=$_>$_</option>";
    }
}
print "\n
                </select><br/>\n

                <b>Site: </b>\n
                <select onMouseOut=\"nd()\" onmouseover=\"overlib('Select site')\" name=\"site\" class=\"required\">\n
                  <option value=\"\"></option>";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    if ($cle[0] eq $sel_site) {
        print "\n
                  <option selected value=$cle[0]>$cle[1]</option>";
    } else {
        print "\n
                  <option value=$cle[0]>$cle[1]</option>";
    }
}

# ------------------------------------------------------------
# ---- start of specific NOVAC HTML form code ----------------
# ------------------------------------------------------------
print "\n
                </select><br/>\n

                <b>Flux</b> = \n
                <input size=5 class=inputNum name=\"flux1\" value=\"$sel_flux1\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter flux value in kg/s')\"/> kg/s<br/>\n

                <b>Flux</b> = \n
                <input size=5 readOnly class=inputNumNoEdit name=\"flux2\" onFocus=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Flux value in ton/day calculated')\"/> ton/day<br/>\n
              </p>\n
            </fieldset>\n

            <fieldset>\n
              <legend>Wind data</legend>\n 
              <p class=parform>\n
                <b>Wind speed</b> = \n
                <input size=5 class=inputNum name=\"windSpeed\" value=\"$sel_windSpeed\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter wind speed value in m/s (between 1 and 60)')\"/> m/s<br/>\n

                <b>Wind speed source: </b>\n
                <select onMouseOut=\"nd()\" onmouseover=\"overlib('Enter wind speed source')\" name=\"windSpeedSource\" size=\"1\">";
for (@sources) {
    my @cle = split(/\|/,$_);
    print "\n
                  <option";
    if ($cle[0] eq $sel_windSpeedSource) {
        print " selected";
    }
    print " value=$cle[0]>$cle[1]</option>";
}
print "\n
                </select><br/>\n

                <b>Wind direction</b> = \n
                <input size=3 class=inputNum name=\"windDirection\" value=\"$sel_windDirection\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter wind direction value in degrees (between 1 and 360)')\"/> deg<br/>\n

                <b>Wind direction source: </b>\n
                <select onMouseOut=\"nd()\" onmouseover=\"overlib('Enter wind direction source')\" name=\"windDirectionSource\" size=\"1\">";
for (@sources) {
    my @cle = split(/\|/,$_);
    print "\
                  <option";
    if ($cle[0] eq $sel_windDirectionSource) {
        print " selected";
    }
    print " value=$cle[0]>$cle[1]</option>";
}
print "\n
                </select><br/>\n
              </p>\n
            </fieldset>\n

            <fieldset>\n
              <legend>Contignation data</legend>\n 
              <p class=parform>\n
                <b>Compass direction</b> = \n
                <input size=3 class=inputNum name=\"compassDirection\" value=\"$sel_compassDirection\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter compass direction value in degree')\"/> deg<br/>\n

                <b>Cone angle: </b>\n
                <select onMouseOut=\"nd()\" onmouseover=\"overlib('Enter cone angle value')\" name=\"coneAngle\" size=\"1\">";
for (@coneangles) {
    my @cle = split(/\|/,$_);
    print "\n
                  <option";
    if ($cle[0] eq $sel_coneAngle) {
        print " selected";
    }
    print " value=$cle[0]>$cle[1]</option>";
}
print "\n
                </select> deg<br/>\n
                <b>Tilt</b> = \n
                <input size=3 class=inputNum name=\"tilt\" value=\"$sel_tilt\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter tilt value in degree')\"/> deg<br/>\n
              </p>\n
            </fieldset>\n
          </td>\n
          <td style=border:0 valign=top>\n
            <fieldset>
              <legend>Plume height above instrument</legend>\n
              <p class=parform>\n
                <b>Plume height</b> = \n
                <input size=5 class=inputNum name=\"plumeHeight\" value=\"$sel_plumeHeight\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter plume height value in meter')\"/> m<br/>\n

                <b>Plume height source: </b>\n
                <select onMouseOut=\"nd()\" onmouseover=\"overlib('Enter plume height source')\" name=\"plumeHeightSource\" size=\"1\">";
for (@sources) {
    my @cle = split(/\|/,$_);
    print "\n
                  <option";
    if ($cle[0] eq $sel_plumeHeightSource) {
        print " selected";
    }
    print " value=$cle[0]>$cle[1]</option>";
}
print "\n
                </select><br/>\n
              </p>\n
            </fieldset>\n

            <fieldset>\n
              <legend>Plume data</legend>\n
              <p class=parform>\n
                <b>Offset</b> = \n
                <input size=5 class=inputNum name=\"offset\" value=\"$sel_offset\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter offset value')\"/><br/>\n
                <b>Plume centre</b> = \n
                <input size=5 class=inputNum name=\"plumeCentre\" value=\"$sel_plumeCentre\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter plume centre value in degree')\"/> deg<br/>\n
                <b>Plume edge 1</b> = \n
                <input size=3 class=inputNum name=\"plumeEdge1\" value=\"$sel_plumeEdge1\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter plume edge 1 value in degree')\"/> deg<br/>\n
                <b>Plume edge 2</b> = \n
                <input size=3 class=inputNum name=\"plumeEdge2\" value=\"$sel_plumeEdge2\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter plume edge 2 value in degree')\"/> deg<br/>\n
                <b>Plume completeness</b> = \n
                <input size=3 class=inputNum name=\"plumeCompleteness\" value=\"$sel_plumeCompleteness\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter plume completeness value in percent (between 0.7 and 1)')\"/><br/>\n
              </p>\n
            </fieldset>\n

            <fieldset>\n
              <legend>Error</legend>\n
              <p class=parform>\n
                <b>Geom error</b> = \n
                <input size=5 class=inputNum name=\"geomError\" value=\"$sel_geomError\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter geom error value')\"/><br/>\n
                <b>Spectrometer error</b> = \n
                <input size=5 class=inputNum name=\"spectrometerError\" value=\"$sel_spectrometerError\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter spectrometer error value')\"/><br/>\n
                <b>Scattering error</b> = \n
                <input size=5 class=inputNum name=\"scatteringError\" value=\"$sel_scatteringError\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter scattering error value')\"/><br/>\n
                <b>Wind error</b> = \n
                <input size=5 class=inputNum name=\"windError\" value=\"$sel_windError\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter wind error value')\"/><br/>\n
                <b>Number of valid scans</b> = \n
                <input size=5 class=inputNum name=\"nbValidScans\" value=\"$sel_nbValidScans\" onKeyUp=\"check_values()\" onChange=\"check_values()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter number of valid scans (1 at least)')\"/><br/>\n
              </p>\n
            </fieldset>\n
          </td>\n
        </tr>\n
        <tr>\n
          <td style=border:0 colspan=2>\n
            <p style=\"margin-top:20px;text-align:center\">\n
              <input type=\"button\"  name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_SHOW')."'\" style=\"font-weight:normal\"/>\n
              <input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\"/>\n
            </p>\n
          </td>\n
        </tr>\n
      </table>\n
    </form>\n
  </body>\n
</html>\n";

# ------------------------------------------------------------
# ---- end of specific NOVAC HTML form code ------------------
# ------------------------------------------------------------

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

