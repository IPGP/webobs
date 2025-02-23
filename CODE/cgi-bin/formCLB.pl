#!/usr/bin/perl

=head1 NAME

formCLB.pl

=head1 SYNOPSIS

 http://..../formCLB.pl?node=NODEID

=head1 DESCRIPTION

 Editing or creating the calibration file of a node in association to a proc.

=head1 Query string parameters

 node=
 the fully qualified node name whose CLB file will be edited, e.g.,
 node=PROC.procname.nodename

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
my $cgi = new CGI;
use DBI;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Wiki;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
$ENV{LANG} = $WEBOBS{LOCALE};

# --- subroutine

sub sort_clb_lines {
    my %data = shift(@_);

    # Sort the list of lines of the calibration file by date, time,
    # and channel number, using a numerical sort for the latter.
    $data{$a}{'DATE'} cmp $data{$b}{'DATE'} or
      $data{$a}{'TIME'} cmp $data{$b}{'TIME'} or
      $data{$a}{'nv'} <=> $data{$b}{'nv'} or
      $a cmp $b; # final comparison to make sure the ordering is always well defined
}

# ---- inits and checkings
my $GRIDName  = my $GRIDType  = my $NODEName = my $RESOURCE = "";
my %NODE;
my %CLBS;
my @clbNote;
my %fieldCLB;
my $fileDATA = "";
my @newChan;
my %data;
my $nb = 0;
my $nouveau = 0;
my $QryParm = $cgi->Vars;
my @hiden_params = ("az", "la", "lo", "al", "dp", "sf", "db", "lc");

$QryParm->{'node'}   ||= "";

($GRIDType, $GRIDName, $NODEName) = split(/[\.\/]/, trim($QryParm->{'node'}));
if ( $GRIDType eq "PROC" && $GRIDName ne "" ) {
    if ( !clientHasEdit(type=>"authprocs",name=>"$GRIDName")) {
        die "$__{'Not authorized'} (edit) $GRIDType.$GRIDName.$NODEName";
    }
    if ($NODEName ne "") {
        my %S = readNode($NODEName);
        %NODE = %{$S{$NODEName}};
        if (%NODE) {
            %CLBS = readCfg("$WEBOBS{ROOT_CODE}/etc/clb.conf");
            @clbNote  = wiki2html(join("",readFile($CLBS{NOTES})));
            %fieldCLB = readCfg($CLBS{FIELDS_FILE}, "sorted");
            %data = readCLB("$GRIDType.$GRIDName.$NODEName");
        } else {
            die "$__{'Could not read'} $QryParm->{'node'} $__{'node configuration'}";
        }
    } else {
        die "$__{'No node requested'}";
    }
} else {
    die ("$__{'You cannot edit a NODE calibration file outside of PROC context'}");
}

# ---- OK, passed all above checks

my $titre2 = "$NODE{ALIAS}: $NODE{NAME} [$QryParm->{'node'}]";

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $todayyear = strftime('%Y',@tod);
my $today = strftime('%F',@tod);
my $firstyear = $WEBOBS{BIG_BANG};
if ($NODE{INSTALL_DATE} and $NODE{INSTALL_DATE} =~ /\d{4}-\d{2}-\d{2}/) {
    $firstyear = substr($NODE{INSTALL_DATE},0,4);
}

my @yearList  = ($firstyear..$todayyear);
my @monthList   = ('01'..'12');
my @dayList   = ('01'..'31');
my @hourList  = ('00'..'23');
my @minuteList = ('00'..'59');

# ---- Start HTML page
my $titlePage = "Edit - $__{'Calibration file'}";
print "Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<HTML><HEAD>\n
<title>$titlePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<script language=\"JavaScript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/htmlFormsUtils.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
</HEAD>";
my $jvs = ($QryParm->{'submit'}) ? 'onLoad="calc()"' : "";
print "<BODY style=\"background-color:#E0E0E0\" $jvs>\n";
print "<H1>$titlePage</H1>\n<H2>$titre2</H2>\n";

# ---- take care of new "lines" if any
#

$nb = keys %data;  # number of elements in @data

my @params;
foreach my $k (sort { $fieldCLB{$a}{'_SO_'} <=> $fieldCLB{$b}{'_SO_'} } keys %fieldCLB) {
    push(@params, $k);
}

#foreach my $k (keys %{$fieldCLB{"DATE"}}) {
#    print $k, ": ", $fieldCLB{"0"}{$k}, "<br>";
#}

# ---- now inject some js code
#

my $max_index = scalar(keys %fieldCLB) - 2; # indexes start at 1 / DATE and TIME don't have input names.

print "
<div id=\"helpBox\"></div>
<script type=\"text/javascript\">

function verif_formulaire()
{
    var i;
    var j;
    var v;

    for (i=1;i<=".scalar(keys %data).";i++) {
        for (j=1;j<=".$max_index.";j++) {
            eval('v = document.formulaire.v' + i + '_' + j + '.value');
            if (v.indexOf(\"#\") != -1) {
                alert(' # not allowed in any field');
                eval('document.formulaire.v' + i + '_' + j + '.focus()');
                return false;
            }
        }
    }
    \$.post(\"/cgi-bin/postCLB.pl\", \$(\"#theform\").serialize(), function(data) {
        if ( data.match(/auto reload edit form/gi) != null ) {
            location.reload(true);
        } else {
            alert(data);
            location.href = document.referrer;
        }
       }
    );
}

function calc()
{
    // This function should be changed to be run as a change callback
    // First, one should make sure this all make any sense...
    var i;
    // I guess 'ok' should be 1 if changes are to be submitted/recorded
    // and 0 if the form is to be updated.
    var ok = 1;

    if (document.formulaire.nbc.value != document.formulaire.nbc.defaultValue) {
        ok = 0;
    }

    for (i=1;i<=".scalar(keys %data).";i++) {
        // Note: not really sure if the fix of this nonsense is ok, but it
        // was useless anyway, as sX.value is always 'on' as the 'value' HTML
        // attribute of the checkbox is not defined.
        //if (eval('document.formulaire.s' + i + '.value') != '') ok = 0;
        if (eval('document.formulaire.s' + i + '.checked')) { ok = 0; }
    }

    // Update the label of the submit button : I guess 'Submit' is supposed to
    // be used when the form needs to be updated, and 'Validate' when
    // calibration file is ready to be written (and, of course, the user is
    // supposed to understand the difference. Poor, poor user.)
    var sb = document.getElementById('submit_button')
    if (ok) {
        sb.value = '$__{'Validate'}';
    } else {
        sb.value = '$__{'Submit'}';
    }
}

\$(function() { // Executed after page is loaded

    // Not sure this is still useful
    window.onkeydown = calc();

    // Prevent implicit submission of the form on pressing the Enter key
    document.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
        }
    });
});

</script>\n\n";

my $c = "";
print "<P>@clbNote</P>\n";

#djl-was: print "<FORM name=formulaire action=\"/cgi-bin/".basename($0)."?submit=\" method=post onSubmit=\"return verif_formulaire()\">";
print "<FORM name=formulaire id=\"theform\" action=\"\">";
print "<input type=\"hidden\" name=\"node\" value=\"$QryParm->{'node'}\">",
  "<input type=\"hidden\" name=\"nb\" value=\"$nb\">\n\n",
  "<TABLE class=\"CLBtable\" width=\"100%\" style=\"border:0\" onMouseOver=\"calc()\">",
  "<TR>";
foreach my $k ( @params ) {
    if ($k ~~ @hiden_params) { $c = ' class="CLBshowhide"' } else { $c = '' }
    print "<TH$c>",$fieldCLB{$k}{'Name'}."</TH>";
}
print "</TR>\n";

my $i    = 0;
my $nbc  = 0;

my $line;
foreach my $id (sort sort_clb_lines keys %data) {
    $i++;
    my %line = %{$data{$id}};
    print "<TR>";

    my @date = split(/-/, $line{'DATE'});
    my @heure = split(/:/, $line{'TIME'});
    print "<TD nowrap onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB{'DATE'}{'MSGID'}}')\"><select name=\"y$i\" size=\"$fieldCLB{'DATE'}{'NbCar'}\">";
    for (@yearList) {
        my $sel = "";
        if ($_ eq $date[0]) { $sel = "selected"; }
        print "<option $sel value=$_>$_</option>";
    }
    print "</select><select name=\"m$i\" size=\"$fieldCLB{'DATE'}{'NbCar'}\">";
    for (@monthList) {
        my $sel = "";
        if ($_ eq $date[1]) { $sel = "selected"; }
        print "<option $sel value=$_>$_</option>";
    }
    print "</select><select name=\"d$i\" size=\"$fieldCLB{'DATE'}{'NbCar'}\">";
    for (@dayList) {
        my $sel = "";
        if ($_ eq $date[2]) { $sel = "selected"; }
        print "<option $sel value=$_>$_</option>";
    }
    print "</select></TD>\n";
    print "<TD nowrap onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB{'TIME'}{'MSGID'}}')\"><select name=\"h$i\" size=\"$fieldCLB{'TIME'}{'NbCar'}\">";
    for (@hourList) {
        my $sel = "";
        if ($_ eq $heure[0]) { $sel = "selected"; }
        print "<option $sel value=$_>$_</option>";
    }
    print "</select><select name=\"n$i\" size=\"$fieldCLB{'TIME'}{'NbCar'}\">";
    for (@minuteList) {
        my $sel = "";
        if ($_ eq $heure[1]) { $sel = "selected"; }
        print "<option $sel value=$_>$_</option>";
    }
    print "</select></TD>\n";
    print "<TD nowrap><input type=checkbox name=\"s$i\" onChange=\"calc()\">
        <input name=\"v"."$i"."_1\" readonly value=\"$line{'nv'}\" size=\"$fieldCLB{'nv'}{'NbCar'}\" style=\"font-weight:bold;background-color:#E0E0E0;border:0\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB{'nv'}{'MSGID'}}')\">";
    if ($line{'nv'} > $nbc) {
        $nbc = $line{'nv'};
    }
    my $ki = 2;
    foreach my $k ( @params ) {
        if ($k ~~ @hiden_params) { $c = ' class="CLBshowhide"' } else { $c = '' }
        if (not $k ~~ ["DATE", "TIME", "nv"]) {
            print "<TD$c onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB{$k}{'MSGID'}}')\"><input name=\"v".$i."_".$ki++
              ."\" value=\"".($line{$k} // '')."\" size=\"$fieldCLB{$k}{'NbCar'}\"></TD>\n";
        }
    }
}
print "</TR><TR<TD style=\"border:0\">&nbsp;</TD></TR>\n";

my $txt = "Number of channels for the node:<ul>"
  ."<li>increase to add channels;"
  ."<li>decrease to remove all lines of channels with a greater number."
  ."</ul>";
print "<TR><TD style=\"border:0\" colspan=2>
        <P><B>Fix number of channels</B> =
        <input type=\"text\" name=\"nbc\" size=2 value=\"$nbc\" onKeyUp=\"calc()\"
        onMouseOut=\"nd()\" onMouseOver=\"overlib('$txt',CAPTION,'ATTENTION')\"></P>
        </TD><TD style=\"border:0\" colspan=5>&nbsp;&uarr; <B>Selected lines :</B><BR>\n
        <input type=radio name=action value=duplicate checked> <B>Duplicate</B> (add a new line)<BR>
        <input type=radio name=action value=delete>            <B>Delete</B> (remove a line)<BR>";

print "<TD style=\"border:0\" colspan=".(keys %fieldCLB)."><P style=\"text-align:right\">";
print "<input type=\"button\" onClick=\"CLBshowhide();\" value=\"$__{'show/hide extra columns'}\">";
print "<input type=\"button\" name=lien onClick=\"history.go(-1);\" value=\"$__{'Cancel'}\">";
print "<input type=\"button\" id=\"submit_button\" value=\"$__{'Submit'}\" onClick=\"verif_formulaire();\" style=\"font-weight:bold\"> ";

print "</P></TD></TR></TABLE></FORM>";

# --- End of the HTML page
print "<BR>\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, François Beauducel, Alexis Bosson, Didier Lafon, Lucas Dassin

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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
