#!/usr/bin/perl
#

=head1 NAME

formGRIDMAPS.pl

=head1 SYNOPSIS

http://..../formGRIDMAPS.pl

=head1 DESCRIPTION

Builds/Manages the input html-form for 'B<Gridmaps Request>' and processes it with postGRIDMAPS.pl.
A B<Gridmaps Request> is the execution of Gridmaps routine for merged GRIDS and optional set of
B<Date-span and Parameters>.

Available GRIDS (VIEWS and PROCS) are those containing at least one NODE with a geographic location
and for which the USER has at least read authorization.

A submitted B<Gridmaps Request> will have its results (output maps) files grouped into the
OUTR directory, under a subdirectory whose name uniquely identifies the Request:

    OUTR/YYYYMMDD_HHMMSS_HOSTNAME_UID
        REQUEST.rc
        GRIDMAPS/{exports,maps}/

See postGRIDMAPS.pl documentation for further Gridmaps Request's execution/parameters description.

=head1 RELATED GRID CONFIGURATION PARAMETERS

Individual GRID's configuration parameters related to B<Gridmaps Request> are those indicated in the
B<REQUEST_GRID_KEYLIST> of GRIDMAPS.rc configuration file. This key is used to specify a list of
comma-separated keys of some parameters, that will be presented to the user so that (s)he will have
a chance to overwrite corresponding values for request execution.
Such parameters will be appended to the REQUEST.rc file as 'GRID.gridname.originalKey|user's value'

    Example:
    REQUEST_GRID_KEYLIST|NODE_SIZE,NODE_RGB,NODE_FONTSIZE,NODE_MARKER
    will appear in REQUEST.rc as:
    GRID.THISGRID.NODE_SIZE|15
    GRID.THISGRID.NODE_RGB|1,0,0
    GRID.THISGRID.NODE_FONTSIZE|0
    GRID.THIDGRID.NODE_MARKER|o

=head1 DATE SPAN AND PARAMETERS

Date span allows to select the validity interval of NODES:

    A start date
    An end date

Parameters (list of keys and default values are taken from GRIDMAPS.rc).

=cut

use strict;
use warnings;
use File::Basename;
use CGI;
my $cgi = new CGI;
$CGI::POST_MAX = 1024;
use CGI::Carp qw(fatalsToBrowser set_message);
use Locale::TextDomain('webobs');
use POSIX qw/strftime/;

# ---- webobs stuff
#
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::i18n;

# ---- misc inits
#
set_message(\&webobs_cgi_msg);
my @tod = localtime();
my $QryParm   = $cgi->Vars;

my %SCHED;
my @gridavailable;
my @gridlist;
my %G;

# ---- Things to populate select dropdown fields
my $year = strftime('%Y',@tod);
my @yearList = reverse($WEBOBS{BIG_BANG}..$year+1);
my @monthList = ('01'..'12');
my @dayList = ('01'..'31');

# ---- dates
#      default to full previous month
my @tm = gmtime(time);
$tm[3] = 1;
my ($usrYearE,$usrMonthE,$usrDayE) = split(/-/,strftime("%Y-%m-%d",@tm));
if ($tm[4]==0) { $tm[5]--; $tm[4] = 11;} else { $tm[4]--; }
my ($usrYearS,$usrMonthS,$usrDayS) = split(/-/,strftime("%Y-%m-%d",@tm));

map (push(@gridavailable,"VIEW.".basename($_,".conf")), qx(ls $WEBOBS{PATH_VIEWS}/*/*.conf ));
map (push(@gridavailable,"PROC.".basename($_,".conf")), qx(ls $WEBOBS{PATH_PROCS}/*/*.conf ));
chomp(@gridavailable);
if (scalar(@gridavailable)==0) { die "$__{'No GRID eligible for requests submission.'}" }
foreach (@gridavailable) {
    push(@gridlist,$_) if ($_ =~ /^VIEW/ && WebObs::Users::clientHasRead(type=>"authviews",name=>"$_"));
    push(@gridlist,$_) if ($_ =~ /^PROC/ && WebObs::Users::clientHasRead(type=>"authprocs",name=>"$_"));
}
if (scalar(@gridlist)==0) { die "$__{'No GRID eligible for this user. Please ask an administrator.'}" }

# ---- read in default values for initializing
# ---- form fields used for request.rc creation
my %REQDFLT;
my $reqdflt = "$WEBOBS{ROOT_CODE}/tplates/request-template";
if (-e $reqdflt ) {
    %REQDFLT = readCfg($reqdflt)
}
my %GRIDMAPS = readCfg($WEBOBS{GRIDMAPS});

# ---- passed all checkings above ...
# ---- build/process the form HTML page
#
my $pagetitle = "$__{'Gridmaps Request'} (under development)";

print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<TITLE>$pagetitle</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\">

function selGrid(grid) {
    obj = \"#pkeysdrawer\"+grid;
    //toggle to show/hide; prop(disabled) to (not)serialize in post
    //all inputs of a grd must start as  display:none AND disabled
    \$(obj).toggle();
    \$(obj).find('input').each( function(){ \$(this).prop('disabled',!\$(this).prop('disabled')) });
}

function checkForm()
{
    var d1 = document.formulaire.startY.value.concat(document.formulaire.startM.value,document.formulaire.startD.value);
    var d2 = document.formulaire.endY.value.concat(document.formulaire.endM.value,document.formulaire.endD.value);
    if (d1 >= d2) {
        alert(\"End date must not be before Start date!\");
        return false;
    }
    var checkboxes = document.formulaire.querySelectorAll(\"input[type=checkbox]\");
    var requestgrids = 0;
    for (index = 0; index < checkboxes.length; ++index) {
        if (checkboxes[index].name.substring(0, 2) == \"g_\" && checkboxes[index].checked) {
            requestgrids++;
        }
    }
    if (requestgrids == 0) {
        alert(\"You must select at least one GRID to execute...\");
    } else {
        postIt();
    }
}
function postIt()
{
    \$.post(\"/cgi-bin/postGRIDMAPS.pl\", \$(\"#theform\").serialize(), function(data) {
        alert(data);
    });
}
</script>
</HEAD>
<BODY onLoad=\"document.formulaire.origin.value=window.location.protocol + '//' + window.location.hostname + (window.location.port ? (':' + window.location.port) : '');\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>";

print "<h2>$pagetitle</h2>";
print "<P class=\"subMenu\"> <b>&raquo;&raquo;</b> [ <a href=\"/cgi-bin/showREQ.pl\">Results</a> ]</P>";

print "<form id=\"theform\" name=\"formulaire\" action=\"\">";

print "<TABLE style=\"border:0\" width=\"100%\">";
print "<TR>";
print "<TD style=\"border:0;vertical-align:top;\" nowrap>";   # left column

# ---- Display list of PROCS that are eligible for requests
print "<fieldset><legend>$__{'Available GRIDS'}</legend>";
print "<div style=\"overflow-y: scroll;height: 400px\">";
for my $g (@gridlist) {
    my ($gt,$gn) = split(/\./,$g);
    %G = readGrid($g);
    my $nn = scalar(@{$G{$g}{NODESLIST}});
    (my $gg = $g) =~ s/\./_/g;
    if ($nn > 0) {
        print "<INPUT type=\"checkbox\" name=\"g_$g\" title=\"$g\" onclick=\"selGrid('$gg')\" value=\"0\"> <B>{$g}:</B> $G{$g}{NAME} (<B>$nn</B> node".($nn>1?"s":"").")<BR>\n";
        print pkeys($g,\%G);
    }
}
print "</div>";
print "</TD>\n";                                             # end left column

print "<TD style=\"border:0;vertical-align:top\" nowrap>";   # right column

print "<fieldset><legend>$__{'Date span (NODES validity)'}</legend>";

#    DATE1|  DATE2|
print "<TABLE>";
print "<TR>";
print "<TD style=\"border:0;text-align:right\">";
print "<div class=parform>";
print "<B>$__{'Start date'}:</b> <select name=\"startY\" size=\"1\">";
for (@yearList) { print "<option".(($_ eq $usrYearS)?" selected":"")." value=$_>$_</option>\n"; }
print "</select>";
print " <select name=\"startM\" size=\"1\">";
for (@monthList) { print "<option".(($_ eq $usrMonthS)?" selected":"")." value=$_>$_</option>\n"; }
print "</select>";
print " <select name=\"startD\" size=\"1\">";
for (@dayList) {     print "<option".(($_ eq $usrDayS)?" selected":"")." value=$_>$_</option>\n"; }
print "</select><BR>";
print "<b>$__{'End date'}:</b> <select name=\"endY\" size=\"1\">";
for (@yearList) { print "<option".(($_ eq $usrYearE)?" selected":"")." value=$_>$_</option>\n"; }
print "</select>";
print " <select name=\"endM\" size=\"1\">";
for (@monthList) { print "<option".(($_ eq $usrMonthE)?" selected":"")." value=$_>$_</option>\n"; }
print "</select>";
print " <select name=\"endD\" size=\"1\">";
for (@dayList) { print "<option".(($_ eq $usrDayE)?" selected":"")." value=$_>$_</option>\n"; }
print "</select>";
print "</select>";
print "</div></TD>";
print "<TD style=\"border:0\">";
print "<label for=\"inactive\">Plots inactive nodes:</label><INPUT type=\"checkbox\" name=\"inactive\" id=\"inactive\" value=\"0\">\n";
print "</TD>";
print "</TR>";
print "</TABLE>\n";
print "</fieldset>";

print "<fieldset><legend>$__{'Basemap parameters'}</legend>";
print "<TABLE>";
print "<TR>";
print "<TD style=\"border:0\">";
foreach (sort keys(%GRIDMAPS)) {
    if ($_ ne 'REQUEST_GRID_KEYLIST' && $_ !~ /^SUBMIT_/) {
        print "<LABEL style=\"width:200px\" for=\"$_\">$_:</LABEL>";
        if ($GRIDMAPS{$_} =~ /^(Y|N|YES|NO|OK|KO|ON|OFF)$/i) {
            print "<INPUT type=\"checkbox\" name=\"$_\" id=\"$_\" value=\"Y\" ".(isok($GRIDMAPS{$_}) ? "checked":"").">";
        } else {
            print "<INPUT id=\"$_\" name=\"$_\" size=\"20\" value=\"$GRIDMAPS{$_}\">";
        }
        print "<BR>\n";
    } else {
        print "<INPUT type=\"hidden\" id=\"$_\" name=\"$_\" value=\"$GRIDMAPS{$_}\">";
    }
}
print "</TD>";

print "</TR>";
print "</TABLE>\n";
print "</fieldset>";
print "</TD>\n";                                             # end right column

print "</TR></TABLE>\n";
print "<P align=center>";
print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"$__{'Submit'}\" onClick=\"checkForm();\" style=\"font-weight:bold\">";
print "<input type=\"hidden\" id=\"origin\" name=\"origin\" value=\"\">";
print "</P>";

print "</form>";

# ---- end HTML
#
print "\n</BODY>\n</HTML>\n";

# ---- build a div for a grid's keylist input fields
# (args: gridType.gridName, \%gridConf)
sub pkeys {
    my ($g,$GG) = @_;
    if (defined($g)) {
        (my $gg = $g) =~ s/\./_/g;
        my $div = "<div id='pkeysdrawer$gg' class='pkeysdrawer' style='display: none'>";
        foreach (split(/,/,$GRIDMAPS{REQUEST_GRID_KEYLIST})) {
            s/^\s+|\s+$//g;
            $div .= sprintf("<label for='%s.%s'>%s:</label>",$g,$_,$_);
            $div .= sprintf("<input disabled id='%s.%s' name='%s.%s' maxlength='200' size='20' value='%s'><br>",$g,$_,$g,$_,defined($GG->{$g}{$_})?$GG->{$g}{$_}:"");
        }
        $div .= "</div>";
        return $div;
    }
    return "" ; # no request_keylist
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2017 - Institut de Physique du Globe Paris

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
