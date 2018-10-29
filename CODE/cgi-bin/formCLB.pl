#!/usr/bin/perl

=head1 NAME

formCLB.pl 

=head1 SYNOPSIS

 http://..../formCLB.pl?node=NODEID

=head1 DESCRIPTION

Editing the calibration file of a node.

=head1 Query string parameters

 node=  
 the NODE name whose CLB file will be edited
 
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

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
$ENV{LANG} = $WEBOBS{LOCALE};

# ---- inits and checkings   
my %NODE;
my %CLBS;
my @clbNote;
my @fieldCLB;
my $fileDATA = "";
my @newChan; 
my @donnees;
my $nb = 0;
my $nouveau = 0; 
my $QryParm = $cgi->Vars;

$QryParm->{'node'}   ||= "";

if (clientHasEdit(type=>"authmisc",name=>"CLB")) {
	if ($QryParm->{'node'} ne "") {
		my %S = readNode($QryParm->{'node'});
		%NODE = %{$S{$QryParm->{'node'}}};
		if (%NODE) {
			%CLBS = readCfg($WEBOBS{CLB_CONF});
			if (%CLBS) {
				@clbNote  = readFile($CLBS{NOTES});
				@fieldCLB = readCfg($CLBS{FIELDS_FILE});
				if (@fieldCLB) {
					$fileDATA = "$NODES{PATH_NODES}/$QryParm->{'node'}/$QryParm->{'node'}.clb";
					if ((-s $fileDATA) != 0) {
						@donnees = readCfgFile($fileDATA);
					} else { $nouveau = 1; @newChan = (1..$QryParm->{'nbc'})}
				} else { die "$__{'Could not read'} $__{'calibration data-fields definition'}" } 
			} else { die "$__{'Could not read'} $__{'calibration-files configuration'}" }
		} else { die "$__{'Could not read'} $QryParm->{'node'} $__{'node configuration'}" }
	} else { die "$__{'No node requested'}" }
} else { die "$__{'Not authorized'} (edit)" }

# ---- OK, passed all above checks

my $titre2 = "$NODE{ALIAS}: $NODE{NAME} [$QryParm->{'node'}]";
		
# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $anneeActuelle = strftime('%Y',@tod);
my $today = strftime('%F',@tod);

my @anneeListe  = ($CLBS{BANG}..$anneeActuelle);
my @moisListe   = ('01'..'12');
my @jourListe   = ('01'..'31');
my @heureListe  = ('00'..'23');
my @minuteListe = ('00'..'59');

# ---- Start HTML page 
my $titrePage = "Edit - $CLBS{TITLE}";
print "Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<HTML><HEAD>\n
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<script language=\"JavaScript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/htmlFormsUtils.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID=\"helpBox\"></DIV>
<!-- to avoid validating form when pressing ENTER -->
<script type=\"text/javascript\">
function stopRKey(evt) {
	var evt = (evt) ? evt : ((event) ? event : null);
	var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
	if ((evt.keyCode == 13) && (node.type==\"text\"))  {return false;}
}
document.onkeypress = stopRKey;
</script>
</HEAD>";
my $jvs = ($QryParm->{'submit'}) ? 'onLoad="calc()"' : "";
print "<BODY style=\"background-color:#E0E0E0\" $jvs>\n";
print "<H1>$titrePage</H1>\n<H2>$titre2</H2>\n";
	
# ---- take care of new "lines" if any 
#
for (@newChan) {
	my $s = ($nouveau && $NODE{INSTALL_DATE} ne "" ? "$NODE{INSTALL_DATE}":$today) ;
	$s .= "|$fieldCLB[1][1]|$_";
	for (3..($#fieldCLB)) {
		if    ($_ == 13) { $s .= "|".$NODE{LAT_WGS84}; }
		elsif ($_ == 14) { $s .= "|".$NODE{LON_WGS84}; }
		elsif ($_ == 15) { $s .= "|".$NODE{ALTITUDE}; }
		else { $s .= "|".$fieldCLB[$_][1]; }
	}
	push(@donnees,$s);
}
$nb = $#donnees + 1;
@donnees = sort(@donnees);

# ---- now inject some js code
#
print "<script type=\"text/javascript\">
function verif_formulaire()
{
	var i;
	var j;
	var v;
	for (i=1;i<=".($#donnees+1).";i++) {
		for (j=1;j<=".($#fieldCLB-1).";j++) {
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
	var i;
	var ok = 1;

	if (document.formulaire.nbc.value != document.formulaire.nbc.defaultValue) ok = 0;

	for (i=1;i<=".($#donnees+1).";i++) {
		if (eval('document.formulaire.s' + i + '.value') != '') ok = 0;
	}
	if (ok) document.formulaire.submit.value = 'Valider';
	else document.formulaire.submit.value = 'Soumettre';

}

window.captureEvents(Event.KEYDOWN);
window.onkeydown = calc();
</script>\n\n";

my $c = "";
print "<P>@clbNote</P>\n";
#djl-was: print "<FORM name=formulaire action=\"/cgi-bin/".basename($0)."?submit=\" method=post onSubmit=\"return verif_formulaire()\">";
print "<FORM name=formulaire id=\"theform\" action=\"\">";
print "<input type=\"hidden\" name=\"node\" value=\"$QryParm->{'node'}\">",
      "<input type=\"hidden\" name=\"nb\" value=\"$nb\">\n\n",	
	  "<TABLE width=\"100%\" style=\"border:0\" onMouseOver=\"calc()\">",
	  "<TR>";
		for (0..($#fieldCLB)) {
			if ($_ >= 12 && $_ <= 16) { $c = ' class="CLBshowhide"' } else { $c = ''} 
			print "<TH$c>",$fieldCLB[$_][2]."</TH>";
		}
print "</TR>\n";

my $i    = 0;
my $nbc  = 0;
for (@donnees) {
	$i++;
	print "<TR>";
	
	my (@d) = split(/\|/,$_);
	my (@date) = split(/-/,$d[0]);
	my (@heure) = split(/:/,$d[1]);
	print "<TD nowrap onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB[0][3]}')\"><select name=\"y$i\" size=\"$fieldCLB[0][0]\">";
	for (@anneeListe) {
		my $sel = "";
			if ($_ eq $date[0]) { $sel = "selected"; }
			print "<option $sel value=$_>$_</option>";
	}
	print "</select><select name=\"m$i\" size=\"$fieldCLB[0][0]\">";
	for (@moisListe) {
		my $sel = "";
			if ($_ eq $date[1]) { $sel = "selected"; }
			print "<option $sel value=$_>$_</option>";
	}
	print "</select><select name=\"d$i\" size=\"$fieldCLB[0][0]\">";
	for (@jourListe) {
		my $sel = "";
			if ($_ eq $date[2]) { $sel = "selected"; }
			print "<option $sel value=$_>$_</option>";
	}
	print "</select></TD>\n";
	print "<TD nowrap onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB[1][3]}')\"><select name=\"h$i\" size=\"$fieldCLB[1][0]\">";
	for (@heureListe) {
		my $sel = "";
			if ($_ eq $heure[0]) { $sel = "selected"; }
			print "<option $sel value=$_>$_</option>";
	}
	print "</select><select name=\"n$i\" size=\"$fieldCLB[1][0]\">";
	for (@minuteListe) {
		my $sel = "";
			if ($_ eq $heure[1]) { $sel = "selected"; }
			print "<option $sel value=$_>$_</option>";
	}
	print "</select></TD>\n";
	print "<TD nowrap><input type=checkbox name=\"s$i\" onChange=\"calc()\">
		<input name=\"v".$i."_1\" readonly value=\"$d[2]\" size=\"$fieldCLB[2][0]\" style=\"font-weight:bold;background-color:#E0E0E0;border:0\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB[2][3]}')\">";
	if ($d[2] > $nbc) {
		$nbc = $d[2];
	}
	for ("2"..($#fieldCLB-1)) {
		my $j = $_;
		if ($j >= 11 && $j <= 15) { $c = ' class="CLBshowhide"' } else { $c = ''} 
		print "<TD$c onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{$fieldCLB[$_+1][3]}')\"><input name=\"v".$i."_".$j."\" value=\"$d[$j+1]\" size=\"$fieldCLB[$_+1][0]\"></TD>\n";
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

print "<TD style=\"border:0\" colspan=".(@fieldCLB-7)."><P style=\"text-align:center\">";
print "<input type=\"button\" onClick=\"CLBshowhide();\" value=\"$__{'show/hide Loc'}\">";
print "<input type=\"button\" name=lien onClick=\"history.go(-1);\" value=\"$__{'Cancel'}\">";
print "<input type=\"button\" value=\"$__{'Submit'}\" onClick=\"verif_formulaire();\" style=\"font-weight:bold\">";

print "</P></TD></TR></TABLE></FORM>";

# --- End of the HTML page
print "<BR>\n</BODY>\n</HTML>\n";

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

