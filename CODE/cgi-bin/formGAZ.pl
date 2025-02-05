#!/usr/bin/perl
#

=head1 NAME

formGAZ.pl 

=head1 SYNOPSIS

http://..../formGAZ?[id=]

=head1 DESCRIPTION

Ce script permet l'affichage du formulaire d'édition d'un enregistrement des données d'analyse des
gaz de l'OVSG.
 
=head1 Configuration GAZ 

Voir 'showGAZ.pl' pour un exemple de fichier de configuration 'GAZ.conf'

=head1 Query string parameter

=over

=item B<id=>

numéro d'enregistrement à éditer. Si non fourni, on suppose la création d'un nouvel enregistrement. 

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

die "You can't edit GAZ reports." if (!clientHasEdit(type=>"authforms",name=>"GAZ"));

my $FORM = new WebObs::Form('GAZ');
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

my $titrePage = "&Eacute;dition - ".$FORM->conf('TITLE');

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $sel_jour  = strftime('%d',@tod);
my $sel_mois  = strftime('%m',@tod);
my $sel_annee = strftime('%Y',@tod);
my $anneeActuelle = strftime('%Y',@tod);
my $sel_hr    = "";
my $sel_mn    = "";
my $today     = strftime('%F',@tod);

# ---- specific FORM inits -----------------------------------
my @html;
my $affiche;
my $s;

my %types    = readCfg($FORM->path."/".$FORM->conf('FILE_TYPE'));
my %debits   = readCfg($FORM->path."/".$FORM->conf('FILE_DEBITS'));

$ENV{LANG} = $WEBOBS{LOCALE};

# ----
my ($sel_site,$sel_tFum,$sel_pH,$sel_debit,$sel_Rn,$sel_type,$sel_H2,$sel_He,$sel_CO,$sel_CH4,$sel_N2,$sel_H2S,$sel_Ar,$sel_CO2,$sel_SO2,$sel_O2,$sel_d13C,$sel_d18O,$sel_rem);
$sel_site=$sel_tFum=$sel_pH=$sel_debit=$sel_Rn=$sel_type=$sel_H2=$sel_He=$sel_CO=$sel_CH4=$sel_N2=$sel_H2S=$sel_Ar=$sel_CO2=$sel_SO2=$sel_O2=$sel_d13C=$sel_d18O=$sel_rem = "";

# ---- Variables des menus 
my @anneeListe = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe  = ('01'..'12');
my @jourListe  = ('01'..'31');
my @heureListe = ("",'00'..'23');
my @minuteListe= ("",'00'..'59');

# ---- Debut de l'affichage HTML
#
print "Content-type: text/html\n\n";

print <<__EOD__;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>$titrePage</title>\n
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">\n</head>\n
<meta http-equiv="content-type" content="text/html; charset=utf-8">\n
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script type="text/javascript">
<!--

function nicb()
{
}

function suppress(level)
{
		var str = '@{[ $FORM->conf('TITLE') ]} ?';
		if (level > 1) {
				if (!confirm('$__{'WARNING: do you want PERMANENTLY remove this record from '}' + str)) {
						return false;
				}
		} else {
				if (document.formulaire.id.value > 0) {
						if (!confirm('$__{'Do you want to remove this record from '}' + str)) {
								return false;
						}
				} else {
						if (!confirm('$__{'Do you want to restore this record in '}' + str)) {
								return false;
						}
				}
		}
		document.formulaire.delete.value = level;
	submit();
}

function verif_formulaire()
{
	if(document.formulaire.site.value == "") {
		alert("Veuillez spécifier le site de prélèvement!");
		document.formulaire.site.focus();
		return false;
	}
	if(document.formulaire.type.value == "") {
		alert("Veuillez entrer un type d'ampoule!");
		document.formulaire.type.focus();
		return false;
	}
	submit();
}

function calc()
{
}

function submit()
{
	\$.post("/cgi-bin/@{[ $FORM->conf('CGI_POST') ]}", \$("#theform").serialize(), function(data) {
	   //var contents = \$( data ).find( '#contents' ).text();
	   alert(data);
	   document.location="/cgi-bin/@{[ $FORM->conf('CGI_SHOW') ]}";
	   }
	);
}

//window.captureEvents(Event.KEYDOWN);
//window.onkeydown = nicb();

//-->
</script>

</head>
<body style="background-color:#E0E0E0">

<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID="helpBox"></DIV>
<!-- Pour empêcher que la touche ENTER valide le formulaire -->
<script type="text/javascript">
function stopRKey(evt) {
  var evt = (evt) ? evt : ((event) ? event : null);
  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
  if ((evt.keyCode == 13) && (node.type=="text"))  {return false;}
}
document.onkeypress = stopRKey;
</script>
__EOD__

# ---- read data file 
# 
my $message = "Saisie de nouvelles donn&eacute;es";
my @ligne;
my $ptr='';
my $fts=1;
my ($id,$date,$heure,$site,$tFum,$pH,$debit,$Rn,$type,$H2,$He,$CO,$CH4,$N2,$H2S,$Ar,$CO2,$SO2,$O2,$d13C,$d18O,$rem,$val) = split(/\|/,$_);
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) == 1) {
        chomp(@ligne);
        ($id,$date,$heure,$site,$tFum,$pH,$debit,$Rn,$type,$H2,$He,$CO,$CH4,$N2,$H2S,$Ar,$CO2,$SO2,$O2,$d13C,$d18O,$rem,$val) =  split (/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            ($sel_annee,$sel_mois,$sel_jour) = split (/-/,$date);
            ($sel_hr,$sel_mn) = split (/:/,$heure);
            $sel_site = $site;
            $sel_tFum = $tFum;
            $sel_pH = $pH;
            $sel_debit = $debit;
            $sel_Rn = $Rn;
            $sel_type = $type;
            $sel_H2 = $H2;
            $sel_He = $He;
            $sel_CO = $CO;
            $sel_CH4 = $CH4;
            $sel_N2 = $N2;
            $sel_H2S = $H2S;
            $sel_Ar = $Ar;
            $sel_CO2 = $CO2;
            $sel_SO2 = $SO2;
            $sel_O2 = $O2;
            $sel_d13C = $d13C;
            $sel_d18O = $d18O;
            $sel_rem = $rem;
            $sel_rem =~ s/"/&quot;/g;
            $message = "Modification donn&eacute;e n° $QryParm->{id}";
        } else { $QryParm->{id} = ""; $val = "" ; }
    } else { $QryParm->{id} = ""; $val = "" ;}
}

print "<H1>$titrePage</H1>\n<H2>$message</H2>\n";

print "<FORM name=formulaire id=\"theform\" action=\"\">";
print "<input type=\"hidden\" name=\"oper\" value=\"$USERS{$CLIENT}{UID}\">\n";
print "<input type=\"hidden\" name=\"delete\" value=\"\">\n";
print "<TABLE width=\"100%\">";

if ($QryParm->{id} ne "") {
    print "<TR><TD style=\"border:0\"><HR>";
    print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\">";
    if ($val ne "") {
        print "<P><B>Information de saisie:</B> $val
		<INPUT type=hidden name=val value=\"$val\"></P>";
    }
    print "<INPUT type=\"button\" value=\"".($id < 0 ? "Reset" : "$__{'Remove'}")."\" onClick=\"suppress(1);\">";
    if (clientHasAdm(type=>"authforms", name=>"GAZ")) {
        print "<INPUT type=\"button\" value=\"$__{'Erase'}\" onClick=\"suppress(2);\">";
    }
    print "<HR></TD></TR>";

}
print "</TABLE>";

print "<TABLE style=border:0 onMouseOver=\"calc()\">";
print "<TR>";
print "<TD style=border:0 valign=top>
	<fieldset><legend>Date et lieu du prélèvement</legend>
		<P class=parform>
		<B>Date: </b><select name=annee size=\"1\">";
for (@anneeListe) {
    if ($_ == $sel_annee) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select name=mois size=\"1\">";
for (@moisListe) {
    if ($_ == $sel_mois) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select name=jour size=\"1\">";
for (@jourListe) {
    if ($_ == $sel_jour) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";

print "&nbsp;&nbsp;<b>Heure: </b><select name=hr size=\"1\">";
for (@heureListe) {
    if ($_ eq $sel_hr) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
}
print "</select>";
print " <select name=mn size=\"1\">";
for (@minuteListe) {
    if ($_ eq $sel_mn) {
        print "<option selected value=$_>$_</option>";
    } else {
        print "<option value=$_>$_</option>";
    }
}
print "</select><BR>";

print "<B>Site: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le site du prélèvement')\" name=\"site\" size=\"1\"><option value=\"\"></option>";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    if ($cle[0] eq $sel_site) {
        print "<option selected value=$cle[0]>$cle[1]</option>";
    } else {
        print "<option value=$cle[0]>$cle[1]</option>";
    }
}
print "</select><BR>\n";
print "<B>Type d'Ampoule: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le type d&apos;ampoule')\" name=\"type\" size=\"1\"><option value=\"\"></option>";
for (keys(%types)) {
    print "<option".($_ eq $sel_type ? " selected":"")." value=$_>$types{$_}{name}</option>";
}
print "</select></P>";
print "</fieldset>";

print "<fieldset><legend>Mesures sur site</legend>\n
		<P class=parform>
		<B>Température de la fumerolle</B> (en °C) = <input size=5 class=inputNum name=\"tFum\" value=\"$sel_tFum\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de température de la fumerolle')\"><BR>\n
		<B>pH</B> = <input size=5 class=inputNum name=\"pH\" value=\"$sel_pH\" onKeyUp=\"nicb()\" onChange=\"nicb()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur du pH')\"><BR>\n";
print "<B>Débit </B> (qualitatif) = <select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le débit')\" name=\"debit\" size=\"1\"><option value=\"\"></option>";
for (keys(%debits)) {
    print "<option".($_ eq $sel_debit ? " selected":"")." value=$_>$debits{$_} ($_)</option>";
}
print "</select>\n";
print "</fieldset>";
print "</TD>";

print "<TD style=border:0 valign=top>";
print "<fieldset><legend>Concentrations en majeurs</legend>\n";
print "<table><TR>";
print "<TD style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B>H<sub>2</sub></B> (en %) = <input size=6 class=inputNum name=\"H2\" value=\"$sel_H2\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Hydrogène')\"><BR>\n";
print "<B>He</B> (en %) = <input size=6 class=inputNum name=\"He\" value=\"$sel_He\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Helium')\"><BR>\n";
print "<B>CO</B> (en %) = <input size=6 class=inputNum name=\"CO\" value=\"$sel_CO\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Monoxyde de Carbone')\"><BR>\n";
print "<B>CH<sub>4</sub></B> (en %) = <input size=6 class=inputNum name=\"CH4\" value=\"$sel_CH4\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Méthane')\"><BR>\n";
print "<B>N<sub>2</sub></B> (en %) = <input size=6 class=inputNum name=\"N2\" value=\"$sel_N2\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Azote')\"><BR>\n";
print "</TD><TD style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B>H<sub>2</sub>S</B> (en %) = <input size=6 class=inputNum name=\"H2S\" value=\"$sel_H2S\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Hydrogène Sulfuré')\"><BR>\n";
print "<B>Ar</B> (en %) = <input size=6 class=inputNum name=\"Ar\" value=\"$sel_Ar\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Argon')\"><BR>\n";
print "<B>CO<sub>2</sub></B> (en %) = <input size=6 class=inputNum name=\"CO2\" value=\"$sel_CO2\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Dioxyde de Carbone')\"><BR>\n";
print "<B>SO<sub>2</sub></B> (en %) = <input size=6 class=inputNum name=\"SO2\" value=\"$sel_SO2\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Dioxyne de Soufre')\"><BR>\n";
print "<B>O<sub>2</sub></B> (en %) = <input size=6 class=inputNum name=\"O2\" value=\"$sel_O2\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Oxygène')\"><BR>\n";
print "</TD></TR></table>";
print "</fieldset>";

print "<fieldset><legend>Concentrations en isotopes</legend>";
print "<table><TR><TD style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B><sup>222</sup>Rn</B> (en cp/mn) = <input size=6 class=inputNum name=\"Rn\" value=\"$sel_Rn\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Radon 222')\"><BR>\n";
print "<B>&delta;<sup>13</sup>C</B> = <input size=6 class=inputNum name=\"d13C\" value=\"$sel_d13C\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Carbone 13')\"><BR>\n";
print "<B>&delta;<sup>18</sup>O</B> = <input size=6 class=inputNum name=\"d18O\" value=\"$sel_d18O\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Oxygène 18')\"><BR>\n";
print "</P></TD><TR></table>";
print "</fieldset>";
print "</TD>";
print "<TR>";
print "<TD style=border:0 colspan=2>";
print "<B>Observations</B> : <BR><input size=80 name=rem value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter la phénoménologie (dépôts, couleur, etc...)')\"><BR>";
print "</TR><TR>";
print "<TD style=border:0 colspan=2>";
print "<P style=\"margin-top:20px;text-align:center\">";
print "<input type=\"button\"  name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_SHOW')."'\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\">";
print "</P></TABLE>";
print "</FORM>";

# Fin de la page
#
print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

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

