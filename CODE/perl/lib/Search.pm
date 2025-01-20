package WebObs::Search;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 DESCRIPTION

Search box (html form). Currently used in showGRIDS, showPROCS and showVIEWS. 
Reurn the html string for displaying the search box form, that will trigger (action)
nsearch.pl. 

=cut

use strict;
use warnings;
use WebObs::Config;
use WebObs::Grids;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

sub searchform {
    my $searchW = my $entireW = my $majmin = my $extend = my $year1 = my $month1 = my $day1 = my $year2 = my $month2 = my $day2 = "";
    my $netinfo = my $stainfo = my $evtinfo = my $clbinfo = "OK";
    my $anneeActuelle = qx(date +\%Y);  chomp($anneeActuelle);
    my @listeAnnees = reverse($WEBOBS{BIG_BANG}..$anneeActuelle);
    my $SF = "";
    $SF =  "<FORM name=\"formulaire\" style=\"margin: 0px\" action=\"/cgi-bin/nsearch.pl\" method=\"post\">\n";
    $SF .= "<TABLE class=\"searchForm\">";
    $SF .= "<TR>";
    $SF .= "<TD>";
    $SF .= "<B>$__{'Search in selected grids below'}</B><input type=\"hidden\" name=\"grid\" size=\"1\">\n";
    $SF .= "</select>\n";
    $SF .= "<TD><B>$__{'Word/Expression'}:</B> <input size=\"30\" name=\"searchW\" value=\"$searchW\">\n";
    $SF .= "<img src=\"/icons/help.png\" onMouseOut=\"nd()\" onmouseover=\"overlib('regular expression, case insensitive', CAPTION, 'INFORMATIONS', STICKY, WIDTH, 400)\">";
    $SF .= "<TD><input type=\"submit\" value=\"$__{'Search'}\" onClick=\"if (document.formulaire.searchW.value == '') { return false; }\">";
    $SF .= "<input type=\"button\" class=\"advsearch\" onclick=\"\$('tr.advsearch').toggle()\" value=\"$__{'Advanced Search'}\">";

    $SF .= "<TR class=\"advsearch\">";
    $SF .= "<TD>";
    $SF .= "<INPUT type=\"checkbox\" name=\"stainfo\"".($stainfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include file/node description'}."')\"><B>$__{'Node info'}</B>\n";
    $SF .= "<INPUT type=\"checkbox\" name=\"clbinfo\"".($clbinfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include calibration file'}."')\"><B>CLB</B>\n";
    $SF .= "<INPUT type=\"checkbox\" name=\"evtinfo\"".($evtinfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include file/node dated events'}."')\"><B>$__{'Node events'}</B>\n";
    $SF .= "<BR>";
    $SF .= "<label width=\"30px\" for=\"year1\">$__{'Start date'}:</label>";
    $SF .= "<SELECT id=\"year1\" name=\"year1\" size=\"1\">";
    for ("",@listeAnnees) {
        $SF .= "<OPTION".(($year1 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
    }
    $SF .= "</SELECT>\n<SELECT name=\"month1\" size=\"1\">";
    for ("","01".."12") {
        $SF .= "<OPTION".(($month1 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
    }
    $SF .= "</SELECT>\n<SELECT name=\"day1\" size=\"1\">";
    for ("","01".."31") {
        $SF .= "<OPTION".(($day1 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
    }
    $SF .= "</SELECT>\n<BR>";
    $SF .= "<label width=\"30px\" for=\"year2\">$__{'End date'}:</label>";
    $SF .= "<SELECT id=\"year2\" name=\"year2\" size=\"1\">";
    for ("",@listeAnnees) {
        $SF .= "<OPTION".(($year2 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
    }
    $SF .= "</SELECT>\n<SELECT name=\"month2\" size=\"1\">";
    for ("","01".."12") {
        $SF .= "<OPTION".(($month2 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
    }
    $SF .= "</SELECT>\n<SELECT name=\"day2\" size=\"1\">";
    for ("","01".."31") {
        $SF .= "<OPTION".(($day2 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
    }
    $SF .= "</SELECT></TD>\n";
    $SF .= "<TD>";
    $SF .= "<input type=\"checkbox\" name=\"entireW\"".($entireW eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\" onmouseover=\"overlib('".$__{'Select to match entire word'}."')\"><B>$__{'Entire word'}</B>\n";
    $SF .= "<input type=\"checkbox\" name=\"majmin\"".($majmin eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\" onmouseover=\"overlib('".$__{'Select to match case'}."')\"<B>$__{'Upper/lower case'}</B>\n";
    $SF .= "<input type=\"checkbox\" name=\"extend\"".($extend eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\" onmouseover=\"overlib('i".$__{'Select to display the entire text (not only fitting lines)'}."')\"><B>$__{'Display Entire text'}</B><BR>\n";
    $SF .= "</TD>";

    $SF .= "</TABLE></FORM>";
    return $SF;
}

sub searchpopup {
    my ($tody,$todm,$todd) = split(/-/,qx(date +'%F')); chomp($todd);
    my @validYears = reverse($WEBOBS{BIG_BANG}..$tody);
    my $SP = "";
    $SP .= "<div id=\"srchovly\" style=\"display:none\"></div>";
    $SP .= "<form id=\"srchoverlay_form\" style=\"display:none\">";
    my $sfstyle = "style=\"border: none; background: transparent; float: none; font: inherit; margin: 0; width: auto\"";
    $SP .= "<p><b><i>Search {"."<input $sfstyle type=\"text\" id=\"grid\" name=\"grid\" value=\"\" maxlength=\"200\" size=\"15\">"."} for:</i></b></p>";
    $SP .= "<label for=\"searchW\">$__{'Word/Expression'}:<span class=\"small\">regular expression</span></label>";
    $SP .= "  <input size=\"40\" id=\"searchW\" name=\"searchW\" value=\"\">\n";
    $SP .= "<br style=\"clear: left\"><br>";

    $SP .= "<div class='advsearch' style='background-color: #ddddcc;'>";
    $SP .= "<label for=\"year1\">$__{'Start date'}:</label>";
    $SP .= "<select id=\"year1\" name=\"year1\" size=\"1\">";

#for ("",@validYears) { $SP .= "<OPTION".(($tody eq $_)?" selected":"")." value=\"$_\">$_</OPTION>" }
    for ("",@validYears) { $SP .= "<OPTION value=\"$_\">$_</OPTION>" }
    $SP .= "</select>\n<select name=\"month1\" size=\"1\">";

#for ("","01".."12") { $SP .= "<OPTION".(($todm eq $_)?" selected":"")." value=\"$_\">$_</OPTION>" }
    for ("","01".."12") { $SP .= "<OPTION value=\"$_\">$_</OPTION>" }
    $SP .= "</select>\n<select name=\"day1\" size=\"1\">";

#for ("","01".."31") { $SP .= "<OPTION".(($todd eq $_)?" selected":"")." value=\"$_\">$_</OPTION>" }
    for ("","01".."31") { $SP .= "<OPTION value=\"$_\">$_</OPTION>" }
    $SP .= "</select>";
    $SP .= "<br style=\"clear: left\"><br>";

    $SP .= "<label for=\"year2\">$__{'End date'}:</label>";
    $SP .= "<select id=\"year2\" name=\"year2\" size=\"1\">";

#for ("",@validYears) { $SP .= "<OPTION".(($tody eq $_)?" selected":"")." value=\"$_\">$_</OPTION>" }
    for ("",@validYears) { $SP .= "<OPTION value=\"$_\">$_</OPTION>" }
    $SP .= "</select>\n<select name=\"month2\" size=\"1\">";

#for ("","01".."12") { $SP .= "<OPTION".(($todm eq $_)?" selected":"")." value=\"$_\">$_</OPTION>" }
    for ("","01".."12") { $SP .= "<OPTION value=\"$_\">$_</OPTION>" }
    $SP .= "</select>\n<select name=\"day2\" size=\"1\">";

#for ("","01".."31") { $SP .= "<OPTION".(($todd eq $_)?" selected":"")." value=\"$_\">$_</OPTION>" }
    for ("","01".."31") { $SP .= "<OPTION value=\"$_\">$_</OPTION>" }
    $SP .= "</select>";
    $SP .= "<br style=\"clear: left\"><br>";

    $SP .= "<label for=\"stainfo\">$__{'Node definitions'}:<span class=\"small\">check to include</span></label>";
    $SP .= "<input type=\"checkbox\" id=\"stainfo\" name=\"stainfo\" checked value=\"OK\">";
    $SP .= "<label for=\"clbinfo\">$__{'CLB file'}:<span class=\"small\">check to include</span></label>";
    $SP .= "<input type=\"checkbox\" id=\"clbinfo\" name=\"clbinfo\" checked value=\"OK\">";
    $SP .= "<label for=\"evtinfo\">$__{'Node events'}:<span class=\"small\">check to include</span></label>";
    $SP .= "<input type=\"checkbox\" id=\"evtinfo\" name=\"evtinfo\" checked value=\"OK\">";
    $SP .= "<br style=\"clear: left\"><br>";

    $SP .= "<label for=\"entireW\">$__{'Match word'}:<span class=\"small\">match entire</span></label>";
    $SP .= "<input type=\"checkbox\" id=\"entireW\" name=\"entireW\" value=\"\" >";
    $SP .= "<label for=\"majmin\">$__{'Match case'}:<span class=\"small\">case sensitive</span></label>";
    $SP .= "<input type=\"checkbox\" id=\"majmin\" name=\"majmin\" value=\"\" >";
    $SP .= "<label for=\"extend\">$__{'Display all'}:<span class=\"small\">not only matched lines</span></label>";
    $SP .= "<input type=\"checkbox\" id=\"extend\" name=\"extend\" value=\"\" >";
    $SP .= "<br style=\"clear: left\"><br>";
    $SP .= "</div>";

    $SP .= "<p style=\"margin: 0px; text-align: center\">";
    $SP .= "<input type=\"button\" name=\"sendbutton\" value=\"$__{'Search'}\" onclick=\"srchsendPopup(); return false;\" />";
    $SP .= "<input type=\"button\" value=\"cancel\" onclick=\"srchclosePopup(); return false\" />";
    $SP .= "</p>";
    $SP .= "</form>";
    return $SP;
}

1;

__END__

=pod

=head1 AUTHOR

Didier Lafon

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
                
