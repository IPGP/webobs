#!/usr/bin/perl

=head1 NAME

formHEBDO.pl 

=head1 SYNOPSIS

http://..../formHEBDO.pl?id=1234

=head1 DESCRIPTION

User input form to Edit or Create or Delete a record from HEBDO file.

The existing record to be Edited or Deleted is specified by its unique 'id'.
A new record will be created if no 'id' is specified.

formHEBDO handles both form setup and basic input validations. The form is 
submitted for processing via a jQuery Ajax 'post' to the $HEBDO{CGI_POST} script.
formHebdo will popup (alert) data received (as text) from this 'post', supposed 
to reflect the status of the HEBDO file update operation). 

=cut

use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff 
use WebObs::Config;
use WebObs::Users;
#use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use POSIX qw/strftime/;

my @tod = localtime(); 

my %HEBDO     = readCfg($WEBOBS{HEBDO_CONF});
my $fileHebdo = "$HEBDO{FILE_NAME}";
my %types     = readCfg("$HEBDO{FILE_TYPE_EVENEMENTS}");

# ---- menus variables ---------------------------- 
my $anneeActuelle = strftime('%Y',@tod);
my @anneeListe = ($HEBDO{BANG}..$anneeActuelle+$HEBDO{FUTURE_YEARS});
my @moisListe = ('01'..'12');
my @jourListe = ('01'..'31');
my @heureListe= ("",'00'..'23');
my @minsec = ('','00','15','30','45');

# ---- init some more  ----------------------------
my $Type = my $Ovsg = my $Lieu = my $Other = my $Objet="";

my $YearD  = my $YearF  = my $YearP  = my $YearE  = my $YearC  = strftime('%Y',@tod);
my $MonthD = my $MonthF = my $MonthP = my $MonthE = my $MonthC = strftime('%m',@tod);
my $DayD   = my $DayF   = my $DayP   = my $DayE   = my $DayC   = strftime('%d',@tod);
my $HourD  = my $HourF  = my $MinD   = my $MinF   = my $DateNA="";
my @People=("");

# get & parse the http query string (url-param)
# -------------------------------------------------
my $QryParm = $cgi->Vars;
my $id = $QryParm->{'id'} ||= "";

# -------------------------------------------------
my $message;
my $ligne=""; 
my @lignes;
if ($id ne "") {
	my ($date1, $date2, $h1, $h2);
	my $hfilter = qr/^$QryParm->{'id'}\|/;
	@lignes = readFile($fileHebdo, $hfilter);
	die "$__{'duplicate id'} $QryParm->{'id'} in $fileHebdo" if (scalar(@lignes) > 1);
	die "$QryParm->{'id'} $__{'not found'} in $fileHebdo" if (scalar(@lignes) < 1);
	($id,$date1,$h1,$date2,$h2,$Type,$Ovsg,$Other,$Lieu,$Objet) = split(/\|/,l2u($lignes[0]));

	($YearD,$MonthD,$DayD) = split (/-/,$date1);
	($YearF,$MonthF,$DayF) = split (/-/,$date2);
	if ($h1 ne "") {
	    ($HourD,$MinD) = split (/:/,$h1);
	}
	if ($h2 ne "") {
		($HourF,$MinF) = split (/:/,$h2);
	}
	if (($date1 eq "")||($date2 eq "")) { $DateNA = "NA"; }
	@People = split(/\+/,$Ovsg);
	$message="$__{'Editing event #'}$id";
}
else {
	$message="$__{'Add a new event'}";
}


# Start building HTML Page -------------------------
# 
	#print "Content-type: text/html\n\n";
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print "<html><head>";
print "<title>$__{'Editor'} - $HEBDO{TITLE}</title>\n";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n</head>\n";
print '<meta http-equiv="content-type" content="text/html; charset=utf-8">';

print <<"FIN";
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript">
<!--
function verif_formulaire()
{
	if (document.formulaire.supprime.checked == true) { 
		if ( !confirm("$__{'This event will be removed.'} $__{'Are you sure ?'}") )  {
			return false;
		}
	}
	if(document.formulaire.typeEvenement.value == "") {
		alert("$__{'Enter an event type'}");
		document.formulaire.typeEvenement.focus();
		return false;
	}
	if(document.formulaire.nom.value == "") {
		alert("$__{'Enter a name'} !");
		document.formulaire.nom.focus();
		return false;
	}
	if(document.formulaire.anneeDepart.value > document.formulaire.anneeFin.value) {
		alert("$__{'Enter consistent dates'}");
		document.formulaire.anneeDepart.focus();
		return false;
	}
	if((document.formulaire.moisDepart.value > document.formulaire.moisFin.value) && (document.formulaire.anneeDepart.value == document.formulaire.anneeFin.value)) {
		alert("$__{'Enter consistent months'}");
		document.formulaire.moisDepart.focus();
		return false;
	}
	if((document.formulaire.jourDepart.value > document.formulaire.jourFin.value) && (document.formulaire.moisDepart.value == document.formulaire.moisFin.value) && (document.formulaire.anneeDepart.value == document.formulaire.anneeFin.value)) {
		alert("$__{'Enter consistent days'}");
		document.formulaire.jourDepart.focus();
		return false;
	}
    \$.post("/cgi-bin/$HEBDO{CGI_POST}", \$("#theform").serialize(), function(data) {
	   //var contents = \$( data ).find( '#contents' ).text(); 
	   alert(data);
	   document.location="/cgi-bin/$HEBDO{CGI_SHOW}";
	   }
	);
}
//-->
</script>

</head>
<body style="background-color:#E0E0E0">
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID="helpBox"></DIV>
FIN

# ---- build html client id area --------------------------------
print "<TABLE width=\"100%\"><TR><TD style=\"border:0\">";
print "<H1>$__{'Editor'} - $HEBDO{TITLE}</H1>\n<H2>$message</H2>";
print "</TD><TD style=\"border:0; text-align:right\">";
#djl-del: print "$__{'User logged'}:<BR>";
#djl-del: if (substr($USERS{$CLIENT}{UID},0,1) ne "?") {
#djl-del: 	print "<B>$USERS{$CLIENT}{FULLNAME}</B>";
#djl-del: } else {
#djl-del: 	print "login: <B>$CLIENT</B>";
#djl-del: }
print "</TD></TR></TABLE>";

# ---- build html form ------------------------------------------
print "<FORM name=\"formulaire\" id=\"theform\" action=\"\">";

my $sel = "";
# populate html form --------------------------------------------
if ($QryParm->{'id'} ne "") {
   print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{'id'}\">";
}

print "<TABLE><TR><TD align=right style=border:0>";
print "<input type=\"checkbox\" name=\"supprime\" > <b>$__{'Delete this event'}</b></p></td></tr>";
print "</TABLE>";

print "<TABLE><TR><TD align=right style=\"border:none\">";
### starting date date fields 
print "<b>$__{'Start date'}: </b><select onChange=\"formulaire.anneeFin.value=this.value; return false\" name=\"anneeDepart\" size=\"1\">";
for (@anneeListe) {
    if ($_ == $YearD) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select onChange=\"formulaire.moisFin.value=this.value; return false\" name=\"moisDepart\" size=\"1\">";
for (@moisListe) {
    if ($_ == $MonthD) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select onChange=\"formulaire.jourFin.value=this.value; return false\" name=\"jourDepart\" size=\"1\">";
for (@jourListe) { 
    if ($_ == $DayD) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print "</td>";

### starting date time fields
print "<td align=right style=border:0>";
print "&nbsp;&nbsp;<b>$__{'Start time'}: </b><select name=\"heureDepart\" size=\"1\">";
for (@heureListe) { 
    if ($_ eq $HourD) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}      
print "</select>";
print " <select name=\"minuteDepart\" size=\"1\">";
for (@minsec) {
    if ($_ eq $MinD) {
       print "<option selected value=$_>$_</option>";
    } else {
       print "<option value=$_>$_</option>";
    }
}
print "</select>";
print "</td></tr>";

### Ending date date fields
print "<tr><td align=right style=border:0>";
print "<b>$__{'End date'}: </b><select name=\"anneeFin\" size=\"1\">";
for (@anneeListe) {
    if ($_ == $YearF) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select name=\"moisFin\" size=\"1\">";
for (@moisListe) {
    if ($_ == $MonthF) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select name=\"jourFin\" size=\"1\">";
for (@jourListe) { 
    if ($_ == $DayF) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print "</td>";

### Ending date time fields
print "<td align=right style=border:0>";
print "&nbsp;&nbsp;<b>$__{'End time'}: </b><select name=\"heureFin\" size=\"1\">";
for (@heureListe) { 
    if ($_ eq $HourF) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}      
print "</select>";
print " <select name=\"minuteFin\" size=\"1\">";
for (@minsec) {
    if ($_ eq $MinF) {
       print "<option selected value=$_>$_</option>";
    } else {
       print "<option value=$_>$_</option>";
    }
}
print "</select>";
print "</td></tr></table>";
print "<P>";

### editable types for this client 
print "<B>$__{'Event type'}: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Select event type'})\" name=\"typeEvenement\" size=\"1\"><option value=\"\">$__{'--- please select ---'}</option>";
my %sortedTypes;
for (keys(%types)) {
	$sortedTypes{$types{$_}{Name}} = $_;
}
for (sort keys(%sortedTypes)) {
	my $k = $sortedTypes{$_};
	if ($types{$k}{Auto} ne 1 && WebObs::Users::clientHasEdit(type=>'authmisc',name=>"HEBDO$k")) {
		$sel = ($k eq $Type) ? " selected " : ""; 
		print "<option $sel value=$k>$types{$k}{Name}</option>\n"; 
	}
}
print "</select>";
print "&nbsp;&nbsp;<input".($DateNA eq "NA" ? " checked":"")." type=\"checkbox\" name=\"dateNA\" value=\"NA\" onMouseOut=\"nd()\" onmouseover=\"overlib('Click to enter event without date')\"> <B>$__{'No date'}</B>";
print "</p>";

### lists of people involved
print "<TABLE><tr>";
print "<td style=\"vertical-align: top; border: none;\">";
	print "<B>$__{'Name(s)'}: </B><BR><select onMouseOut=\"nd()\" onmouseover=\"overlib($__{'Select names of people involved (hold CTRL key for multiple selections)'})\" name=\"nom\" size=\"10\" multiple>";
	my %sortedUsers;
	for (keys(%USERS)) {
		$sortedUsers{$USERS{$_}{FULLNAME}} = $_;
	}
	for (sort keys(%sortedUsers)) {
		$sel = "";
		my $k = $sortedUsers{$_};
		print "<option".($USERS{$k}{UID} ~~ @People ? " selected":"")." value=$USERS{$k}{UID}>$USERS{$k}{FULLNAME}</option>";
	}
	print "</select></p>";
	$Other = htmlspecialchars($Other);
	print "<td style=\"vertical-align: top; border: none; padding-left: 10px\">";
	print "<B>$__{'Other people involved'}: </B><BR><input size=\"70\" name=\"nomAutres\" onMouseOut=\"nd()\" onmouseover=\"overlib('Enter names ')\" value=\"$Other\">";
print "</tr></TABLE>";

$Lieu = htmlspecialchars($Lieu);
$Objet = htmlspecialchars($Objet);
print "<p><B>$__{'Place'}: </B><BR><input size=\"30\" name=\"lieuEvenement\" value=\"$Lieu\"></p>
<p><B>$__{'Subject'}: </B><BR><input size=\"100\" name=\"commentEvenement\" value=\"$Objet\"></p>";
print "<table width=\"100%\"><tr><td style=\"border:0;text-align:center\">";
print "<p>";
print "<input type=\"button\" name=\"lien\" value=\"$__{'Cancel'}\" onClick=\"document.location.href=document.referrer\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"$__{'Save'}\" onClick=\"verif_formulaire();\">";
print "</p></td></tr></table>";
print "</form></td></tr></table>";

# We're done with the page
print "\n</BODY>\n</HTML>\n";

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

