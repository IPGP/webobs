#!/usr/bin/perl

=head1 NAME

formBOJAP.pl 

=head1 SYNOPSIS

http://..../formBOJAP.pl?[id=]

=head1 DESCRIPTION

Ce script permet l'affichage du formulaire d'édition d'un enregistrement 
des données boîtes japonaises de l'OVSG.

=head1 Configuration BOJAP

Voir 'showBOJAP.pl' pour une exemple de fichier de configuration 'BOJAP.conf'

=head1 Query string parameter

=over

=item B<id=>

numéro d'enregistrement à éditer. Si non fourni, on suppose la création
d'un nouvel enregistrement. 

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

die "You can't edit BOJAP reports." if (!clientHasEdit(type=>"authforms",name=>"BOJAP"));

my $FORM = new WebObs::Form('BOJAP');
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

# ---- Variables de la date courante
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $anneeActuelle = strftime('%Y',@tod);
my $sel_annee1    = strftime('%Y',@tod);
my $sel_mois1     = "";
my $sel_jour1     = "";
my $sel_hr1       = "";
my $sel_mn1       = "";
my $sel_annee2    = strftime('%Y',@tod);
my $sel_mois2     = strftime('%m',@tod);
my $sel_jour2     = strftime('%d',@tod);
my $sel_hr2       = "";
my $sel_mn2       = "";

# ---- specific FORM inits --------------------------
my @html;
my $affiche;
my $s;
my @codesListe;
#my @types    = readCfgFile("$FORMPATH/$FORM{FILE_TYPE}");
my @rapports = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

# ----
my $sel_h2o = $FORM->conf('H2O_ML');
my $sel_koh = $FORM->conf('KOH_N');
my ($sel_site,$sel_m1,$sel_m2,$sel_m3,$sel_m4,$sel_cCl,$sel_cCO2,$sel_cSO4,$sel_rem) = split (/\|/,"");;

# ---- Variables des menus 
my @anneeListe  = ("",$FORM->conf('BANG')..$anneeActuelle);
my @moisListe   = ("",'01'..'12');
my @jourListe   = ("",'01'..'31');
my @heureListe  = ("",'00'..'23');
my @minuteListe = ("",'00'..'59');

# Debut de l'affichage HTML
# 
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<html><head>
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n</head>\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/comma2point.js\"></script>
<script type=\"text/javascript\">
<!--
function verif_formulaire()
{
	if(document.formulaire.site.value == \"\") {
		alert(\"Veuillez spécifier le site de prélèvement!\");
		document.formulaire.site.focus();
		return false;
	}
	if(document.formulaire.annee1.value == \"\") {
		alert(\"Veuillez spécifier l'année de début!\");
		document.formulaire.annee1.focus();
		return false;
	}
	if(document.formulaire.mois1.value == \"\") {
		alert(\"Veuillez spécifier le mois de début!\");
		document.formulaire.mois1.focus();
		return false;
	}
	if(document.formulaire.jour1.value == \"\") {
		alert(\"Veuillez spécifier le jour de début!\");
		document.formulaire.jour1.focus();
		return false;
	}
	if(document.formulaire.annee2.value == \"\") {
		alert(\"Veuillez spécifier l'année de fin!\");
		document.formulaire.annee2.focus();
		return false;
	}
	if(document.formulaire.mois2.value == \"\") {
		alert(\"Veuillez spécifier le mois de fin!\");
		document.formulaire.mois2.focus();
		return false;
	}
	if(document.formulaire.jour2.value == \"\") {
		alert(\"Veuillez spécifier le jour de fin!\");
		document.formulaire.jour2.focus();
		return false;
	}
    \$.post(\"/cgi-bin/".$FORM->conf('CGI_POST')."\", \$(\"#theform\").serialize(), function(data) {
	   //var contents = \$( data ).find( '#contents' ).text(); 
	   alert(data);
	   document.location=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\";
	   }
	);
}

function calc()
{
	var mtotale = 0;
	if (formulaire.m1.value != \"\") {
		mtotale = formulaire.m1.value*1
			+ formulaire.m2.value*1
			+ formulaire.m3.value*1
			+ formulaire.m4.value*1;
		formulaire.MTOT.value = mtotale.toFixed(2);
	}
}
window.captureEvents(Event.KEYDOWN);
window.onkeydown = calc();
//-->
</script>

</head>
<body style=\"background-color:#E0E0E0\" onLoad=\"calc()\">";

print <<"FIN";

<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<!-- Affichage des bulles d'aide -->
<DIV ID="helpBox"></DIV>
<!-- Pour empécher que la touche ENTER valide le formulaire -->
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
my $message = "Saisie de nouvelles donn&eacute;es";
my @ligne;
my $ptr;
my $fts = -1;
my ($id,$date1,$hr1,$date2,$hr2,$site,$cCl,$cCO2,$cSO4,$m1,$m2,$m3,$m4,$h2o,$koh,$rem,$val);
$id=$date1=$hr1=$date2=$hr2=$site=$cCl=$cCO2=$cSO4=$m1=$m2=$m3=$m4=$h2o=$koh=$rem=$val="";
if (defined($QryParm->{id})) {
	($ptr, $fts) = $FORM->data($QryParm->{id});
	@ligne = @$ptr;
	if (scalar(@ligne) == 1) {
		chomp(@ligne);
		($id,$date1,$hr1,$date2,$hr2,$site,$cCl,$cCO2,$cSO4,$m1,$m2,$m3,$m4,$h2o,$koh,$rem,$val) = split (/\|/,l2u($ligne[0]));
		if ($QryParm->{id} eq $id) {
			($sel_annee1,$sel_mois1,$sel_jour1) = split (/-/,$date1);
			($sel_hr1,$sel_mn1) = split (/:/,$hr1);
			($sel_annee2,$sel_mois2,$sel_jour2) = split (/-/,$date2);
			($sel_hr2,$sel_mn2) = split (/:/,$hr2);
			$sel_site = $site;
			$sel_cCl = $cCl;
			$sel_cCO2 = $cCO2;
			$sel_cSO4 = $cSO4;
			$sel_h2o = $h2o;
			$sel_koh = $koh;
			$sel_m1 = $m1;
			$sel_m2 = $m2;
			$sel_m3 = $m3;
			$sel_m4 = $m4;
			$sel_rem = $rem;
			$sel_rem =~ s/"/&quot;/g;
			$message = "Modification donnée n° $QryParm->{id}";
		} else { $QryParm->{id} = ""; $val = ""; }
	} else { $QryParm->{id} = ""; $val = "" ;}
}

print "<TABLE width=\"100%\"><TR><TD style=\"border:0\">
<H1>$titrePage</H1>\n<H2>$message</H2>
</TD><TD style=\"border:0; text-align:right\">";
print "</TD></TR></TABLE>";

print "<FORM name=formulaire id=\"theform\" action=\"\">";
if ($QryParm->{id} ne "") {
   print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\">";
}

print "<input type=\"hidden\" name=\"oper\" value=\"$CLIENT\">\n";

print "<TABLE style=border:0 onMouseOver=\"calc()\">";
print "<TR><TD style=border:0 valign=top>";
print "<fieldset><legend>Date et lieu du pr&eacute;l&egrave;vement</legend>";
	print "<P class=parform align=right>
	<B>Date d&eacute;but: </b><select name=annee1 size=\"1\">";
	for (@anneeListe) {
		if ($_ == $sel_annee1) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=mois1 size=\"1\">";
	for (@moisListe) {
		if ($_ == $sel_mois1) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=jour1 size=\"1\">";
	for (@jourListe) { 
		if ($_ == $sel_jour1) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print "&nbsp;&nbsp;<b>Heure: </b><select name=hr1 size=\"1\">";
	for (@heureListe) { 
		if ($_ eq $sel_hr1) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}      
	print "</select>";
	print " <select name=mn1 size=\"1\">";
	for (@minuteListe) {
		if ($_ eq $sel_mn1) {
		   print "<option selected value=$_>$_</option>";
		} else {
		   print "<option value=$_>$_</option>";
		}
	}
	print "</select><BR>";

	print "<B>Date fin: </b><select name=annee2 size=\"1\">";
	for (@anneeListe) {
		if ($_ == $sel_annee2) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=mois2 size=\"1\">";
	for (@moisListe) {
		if ($_ == $sel_mois2) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=jour2 size=\"1\">";
	for (@jourListe) { 
		if ($_ == $sel_jour2) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print "&nbsp;&nbsp;<b>Heure: </b><select name=hr2 size=\"1\">";
	for (@heureListe) { 
		if ($_ eq $sel_hr2) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}      
	print "</select>";
	print " <select name=mn2 size=\"1\">";
	for (@minuteListe) {
		if ($_ eq $sel_mn2) {
		   print "<option selected value=$_>$_</option>";
		} else {
		   print "<option value=$_>$_</option>";
		}
	}
	print "</select><BR>";

	print "<B>Site: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le site du prélèvement')\" name=\"site\" size=\"1\"><option value=\"\"></option>";
	for (@codesListe) {
		my @cle = split(/\|/,$_);
		if ($cle[0] eq $sel_site) {
			print "<option selected value=$cle[0]>$cle[1]</option>";
		} else {
			print "<option value=$cle[0]>$cle[1]</option>";
		}
	}
	print "</select></P>";
print "</fieldset>\n";

print "<fieldset><legend>Solution initiale</legend>";
	print "<P class=parform>";
	print "<B>Volume H<sub>2</sub>O</B> (en ml) = <input size=6 class=inputNum name=h2o value=\"$sel_h2o\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer le volume d&rsquo;eau')\"><BR>\n
	<B>Concentration KOH</B> (en mol/l) = <input size=3 class=inputNum name=koh value=\"$sel_koh\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en KOH')\"><BR>\n";
	print "</P>";
print "</fieldset>\n";
print "</TD>";

print "<TD style=border:0 valign=top>";
print "<fieldset><legend>Masse recueillie</legend>\n";
	print "<table><TR><TD style=border:0 valign=top>";
	print "<P class=parform align=right>";
	print "<B>M<sub>1</sub></B> (en g) = <input size=6 class=inputNum name=\"m1\" value=\"$sel_m1\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la pesée n°1')\"><BR>\n";
	print "<B>M<sub>2</sub></B> (en g) = <input size=6 class=inputNum name=\"m2\" value=\"$sel_m2\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la pesée n°2')\"><BR>\n";
	print "<B>M<sub>3</sub></B> (en g) = <input size=6 class=inputNum name=\"m3\" value=\"$sel_m3\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la pesée n°3')\"><BR>\n";
	print "<B>M<sub>4</sub></B> (en g) = <input size=6 class=inputNum name=\"m4\" value=\"$sel_m4\" onKeyUp=\"calc()\" onChange=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la pesée n°4')\"><BR>\n";
	print "<BR>";
	print "<B>Masse totale</B> (g) = <input class=inputNum name=\"MTOT\" size=6 readOnly onFocus=\"calc()\" value=\"\"  onMouseOut=\"nd()\" onmouseover=\"overlib('Masse totale')\"><BR></TD>";
	print "</TD>";
	print "</TR></table>";
print "</fieldset>\n";

print "<fieldset><legend>Concentrations</legend>\n";
	print "<table><TR><TD style=border:0 valign=top>";
	print "<P><I>Attention: valeurs en <B>ppm = mg/l</B></I></P>\n";
	print "<P class=parform align=right>";
	print "<B>Cl</B> (mg/l) = <input size=6 class=inputNum name=\"cCl\" value=\"$sel_cCl\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en chlorures')\"><BR>\n";
	print "<B>CO<sub>2</sub></B> (mg/l) = <input size=6 class=inputNum name=\"cCO2\" value=\"$sel_cCO2\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en carbonates')\"><BR>\n";
	print "<B>SO<sub>4</sub></B> mg/l) = <input size=6 class=inputNum name=\"cSO4\" value=\"$sel_cSO4\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en sulfates')\"><BR>\n";
	print "</P></TD></TR></table>";
print "</fieldset>\n";
print "</TD>";
print "<TR>";
print "<TD style=border:0 colspan=2>";
	print "<P class=parform>",
	"<B>Observations</B> : <BR><input size=80 name=rem value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter les problèmes éventuels (particules solides, contamination, pertes ...)')\"><BR>";
	if ($val ne "") {
		print "<B>Information de saisie:</B> $val
		<INPUT type=hidden name=val value=\"$val\"></P>";
	}	
print "</TR><TR>";
print "<TD style=border:0 colspan=2>";
print "<P style=\"margin-top:20px;text-align:center\">";
print "<input type=\"button\"  name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/$FORM->conf('CGI_SHOW')\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\">";
print "</P></TABLE>";
print "</FORM>";

# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
print "<BR>\n</BODY>\n</HTML>\n";

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

