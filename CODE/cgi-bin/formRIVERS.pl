#!/usr/bin/perl

=head1 NAME

formRIVERS.pl 

=head1 SYNOPSIS

http://..../formRIVERS.pl?[id=]

=head1 DESCRIPTION

Edit form of water chemical analysis data bank.
 
=head1 Configuration RIVERS 

See 'showRIVERS.pl' for an example of configuration file 'RIVERS.conf'

=head1 Query string parameter

=over

=item B<id=>

data ID to edit. If void or inexistant, a new entry is proposed. 

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

die "You can't edit RIVERS reports." if (!clientHasEdit(type=>"authforms",name=>"RIVERS"));

my $FORM = new WebObs::Form('RIVERS');
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

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $sel_jour  = strftime('%d',@tod);
my $sel_mois  = strftime('%m',@tod);
my $sel_annee = strftime('%Y',@tod);
my $anneeActuelle = strftime('%Y',@tod);
my $sel_hr    = "";
my $sel_mn    = "";
my $today = strftime('%F',@tod);

# ---- specific FORM inits -----------------------------------
my @html;
my $affiche;
my $s;
my %types    = readCfg($FORM->path."/".$FORM->conf('FILE_TYPE'));
my %flacons  = readCfg($FORM->path."/".$FORM->conf('FILE_FLACONS'));
my @rapports = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

# ---- 
my $sel_type = "2";
my $sel_flacon = "P";
my ($sel_site,$sel_level,$sel_tRiver,$sel_suspendedLoad,$sel_pH,$sel_debit,$sel_cond25,$sel_cond,$sel_niveau,$sel_cNa,$sel_cK,$sel_cMg,$sel_cCa,$sel_cHCO3,$sel_cCl,$sel_cSO4,$sel_cSiO2,$sel_cDOC,$sel_cPOC,$sel_rem);
$sel_site=$sel_level=$sel_tRiver=$sel_suspendedLoad=$sel_pH=$sel_debit=$sel_cond25=$sel_cond=$sel_niveau=$sel_cNa=$sel_cK=$sel_cMg=$sel_cCa=$sel_cHCO3=$sel_cCl=$sel_cSO4=$sel_cSiO2=$sel_cDOC=$sel_cPOC=$sel_rem = "";

# ---- Variables des menus 
my @anneeListe = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe  = ('01'..'12');
my @jourListe  = ('01'..'31');
my @heureListe = ("",'00'..'23');
my @minuteListe= ("",'00'..'59');

# ---- Debut de l'affichage HTML
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<html><head>
<title>".$FORM->conf('TITLE')."</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/comma2point.js\"></script>
<script type=\"text/javascript\">
<!--
function nicb()
{
	var anions;
	var cations;
	var cations_chromato;
	var hydrogene = 0;
	var nicb;
	if (formulaire.pH.value != \"\") {
		hydrogene = 1000*Math.pow(10,-formulaire.pH.value);
	}
	cations_chromato = formulaire.cNa.value/$GMOL{Na}
		   + formulaire.cK.value/$GMOL{K}
		   + 2*formulaire.cMg.value/$GMOL{Mg}
		   + 2*formulaire.cCa.value/$GMOL{Ca};
	cations = cations_chromato + hydrogene;
	anions = formulaire.cHCO3.value/$GMOL{HCO3}
		   + formulaire.cCl.value/$GMOL{Cl}
		   + 2*formulaire.cSO4.value/$GMOL{SO4}
	formulaire.cH.value = hydrogene.toFixed(2);
	nicb = 100*(cations - anions)/(cations + anions);
	//pHcalcule=-(Math.log((anions - cations_chromato)/1000))/Math.log(10);
	//document.getElementById(\"pHcalcule\").innerHTML = \"<i>pour NICB=0%, pH=\</i>\" + pHcalcule.toFixed(2);
	//document.getElementById(\"pHcalcule\").style.background = \"#EEEEEE\";
	formulaire.NICB.value = nicb.toFixed(1);
	formulaire.NICB.style.background = \"#66FF66\";
	if (nicb > 10 || nicb < -10) {
		formulaire.NICB.style.background = \"#FFD800\";
	}
	if (nicb > 20 || nicb < -20) {
		formulaire.NICB.style.background = \"#FF0000\";
	}
}

function suppress(level)
{
        var str = \"".$FORM->conf('TITLE')." ?\";
        if (level > 1) {
                if (!confirm(\"".$__{'ATT: Do you want PERMANENTLY erase this record from '}."\" + str)) {
                        return false;
                }
        } else {
                if (document.formulaire.id.value > 0) {
                        if (!confirm(\"".$__{'Do you want to remove this record from '}."\" + str)) {
                                return false;
                        }
                } else {
                        if (!confirm(\"".$__{'Do you want to restore this record in '}."\" + str)) {
                                return false;
                        }
                }
        }
        document.formulaire.delete.value = level;
	submit();
}

function verif_formulaire()
{
	if(document.formulaire.site.value == \"\") {
		alert(\"Veuillez spécifier le site de prélèvement!\");
		document.formulaire.site.focus();
		return false;
	}
	if(document.formulaire.type.value == \"\") {
		alert(\"Veuillez entrer un type de prélèvement!\");
		document.formulaire.type.focus();
		return false;
	}
	if(document.formulaire.flacon.value == \"\") {
		alert(\"Veuillez entrer un type de flacon!\");
		document.formulaire.flacon.focus();
		return false;
	}
	submit();
}

function submit()
{
	\$.post(\"/cgi-bin/".$FORM->conf('CGI_POST')."\", \$(\"#theform\").serialize(), function(data) {
			//var contents = \$( data ).find( '#contents' ).text(); 
			alert(data);
			document.location=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\";
		}
	);
}
window.captureEvents(Event.KEYDOWN);
window.onkeydown = nicb();
//-->
</script>

</head>

<body style=\"background-color:#E0E0E0\">";

print <<"FIN";

<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<!-- overLIB (c) Erik Bosrup -->
<script language="javascript" src="/js/overlib/overlib.js"></script>
<DIV ID="helpBox"></DIV>
<!-- Pour empêcher que la touche ENTER valide le formulaire -->
<script type="text/javascript">
function stopRKey(evt) {
  var evt = (evt) ? evt : ((event) ? event : null);
  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
  if ((evt.keyCode == 13) && (node.type=="text"))  {return false;}
}
document.onkeypress = stopRKey;
\$(document).ready(function(){
	nicb();
	\$('input.inputNum').change(nicb).keyup(nicb);
});
</script>
FIN

# ---- read data file 
# 
my $message = "Saisie de nouvelles donn&eacute;es";
my @ligne;
my $ptr;
my $fts = -1;
my ($id,$date,$heure,$site,$level,$type,$flacon,$tRiver,$suspendedLoad,$pH,$cond25,$cond,$cNa,$cK,$cMg,$cCa,$cHCO3,$cCl,$cSO4,$cSiO2,$cDOC,$cPOC,$rem,$val);
$id=$date=$heure=$site=$level=$type=$flacon=$tRiver=$suspendedLoad=$pH=$cond25=$cond=$cNa=$cK=$cMg=$cCa=$cHCO3=$cCl=$cSO4=$cSiO2=$cDOC=$cPOC=$rem=$val = "";
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) >= 1) {
        chomp(@ligne);
        ($id,$date,$heure,$site,$level,$type,$flacon,$tRiver,$suspendedLoad,$pH,$cond25,$cond,$cNa,$cK,$cMg,$cCa,$cHCO3,$cCl,$cSO4,$cSiO2,$cDOC,$cPOC,$rem,$val) = split (/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            ($sel_annee,$sel_mois,$sel_jour) = split (/-/,$date);
            ($sel_hr,$sel_mn) = split (/:/,$heure);
            $sel_site = $site;
            $sel_level = $level;
            $sel_type = $type;
            $sel_flacon = $flacon;
            $sel_tRiver = $tRiver;
            $sel_suspendedLoad = $suspendedLoad;
            $sel_pH = $pH;
            $sel_cond25 = $cond25;
            $sel_cond = $cond;
            $sel_cNa = $cNa;
            $sel_cK = $cK;
            $sel_cMg = $cMg;
            $sel_cCa = $cCa;
            $sel_cHCO3 = $cHCO3;
            $sel_cCl = $cCl;
            $sel_cSO4 = $cSO4;
            $sel_cSiO2 = $cSiO2;
            $sel_cDOC = $cDOC;
            $sel_cPOC = $cPOC;
            $sel_rem = $rem;
            $sel_rem =~ s/"/&quot;/g;
            $message = "Modification donn&eacute;e n° $QryParm->{id}";
        } else { $QryParm->{id} = ""; $val = "" ; }
    } else { $QryParm->{id} = ""; $val = "" ;}
}

print "<FORM name=formulaire id=\"theform\" action=\"\">";
print "<input type=\"hidden\" name=\"oper\" value=\"$USERS{$CLIENT}{UID}\">\n";
print "<input type=\"hidden\" name=\"delete\" value=\"\">\n";

print "<TABLE width=\"100%\"><TR><TD style=\"border:0\">
<H1>".$FORM->conf('TITLE')."</H1>\n
<H2>$message</H2></TR>\n";

if ($QryParm->{id} ne "") {
    print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\">";
    print "<TR><TD style=\"border:0\"><HR>";
    if ($val ne "") {
        print "<P><B>Information de saisie:</B> $val
		<INPUT type=hidden name=val value=\"$val\"></P>";
    }
    print "<INPUT type=\"button\" value=\"".($id < 0 ? "Reset":"$__{'Remove'}")."\" onClick=\"suppress(1);\">";
    if (clientHasAdm(type=>"authforms",name=>"RIVERS")) {
        print "<INPUT type=\"button\" value=\"$__{'Erase'}\" onClick=\"suppress(2);\">";
    }
    print "<HR></TD></TR>";
}

print "</TABLE>";

print "<TABLE style=border:0 onMouseOver=\"nicb()\">";
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

print "<B>Site: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner le site du prélèvement')\" name=\"site\" size=\"1\"><option value=\"\"></option>";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    if ($cle[0] eq $sel_site) {
        print "<option selected value=$cle[0]>$cle[1]</option>";
    } else {
        print "<option value=$cle[0]>$cle[1]</option>";
    }
}
print "</select><BR>\n";

print "<B>Type: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner le type de prélèvement')\" name=\"type\" size=\"1\"><option value=\"\"></option>";
for (sort(keys(%types))) {
    print "<option".($_ eq $sel_type ? " selected":"")." value=$_>$_: $types{$_}{name}</option>";
}
print "</select><BR>\n";

print "<B>Flacon: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner le type de flacon')\" name=\"flacon\" size=\"1\"><option value=\"\"></option>";
for (sort(keys(%flacons))) {
    print "<option".($_ eq $sel_flacon ? " selected":"")." value=$_>$_: $flacons{$_}{name}</option>";
}
print "</select><BR>\n";
print "</P>";
print "</fieldset>";

print "<fieldset><legend>Mesures sur site</legend>";
print "<P class=parform align=right>";
print "<B>Niveau d'eau </B> (en cm) = <input size=5 class=inputNum name=level value=\"$sel_level\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur du niveau de l&rsquo;eau mesuré par la sonde de pression (hauteur DEAL)')\"><BR>";
print "<B>Température du liquide</B> (en °C) = <input size=5 class=inputNum name=tRiver value=\"$sel_tRiver\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de température du liquide')\"><BR>";
print "<B>pH</B> = <input size=5 class=inputNum name=pH value=\"$sel_pH\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur du pH')\"><span id=\"pHcalcule\" class=\"inputNumNoEdit\"></span><BR>";
print "<B>Conductivité</B> (en µS/cm) = <input size=6 class=inputNum name=cond value=\"$sel_cond\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de conductivité électrique')\"><BR>";
print "</P>";
print "</fieldset>";

print "<fieldset><legend>Concentration en autres éléments</legend>";
print "<table><TR><TD style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B>SiO<sub>2</sub></B> (en ppm) = <input size=6 class=inputNum name=\"cSiO2\" value=\"$sel_cSiO2\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Silice')\"><BR>\n";
print "<B>Concentration en suspension solide</B> (en mg/L) = <input size=5 class=inputNum name=suspendedLoad value=\"$sel_suspendedLoad\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de la concentration en suspension solide')\"><BR>";
print "</P></TD></TR></table>";
print "</fieldset>";
print "</TD>";

print "<TD style=border:0 valign=top>";
print "<fieldset><legend>Concentrations en cations et anions</legend>\n";
print "<P><I>Attention: valeurs en <B>ppm = mg/l</B></I></P>\n";

#djl-was: print "</TD></TR><TR><TD style=border:0 valign=top>";
print "<table><tr>";
print "<td style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B>Na<sup>+</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cNa\" value=\"$sel_cNa\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Sodium')\"><BR>\n";
print "<B>K<sup>+</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cK\" value=\"$sel_cK\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Potassium')\"><BR>\n";
print "<B>Mg<sup>++</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cMg\" value=\"$sel_cMg\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Magnésium')\"><BR>\n";
print "<B>Ca<sup>++</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cCa\" value=\"$sel_cCa\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Calcium')\"><BR>\n";
print "<B>H<sup>+</sup></B> (en ppm) = <input size=6 readOnly class=inputNumNoEdit name=\"cH\" onFocus=\"nicb()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Concentration en Hydrogène calculé à partir du pH')\"><BR>\n";
print "</TD><TD style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B>HCO3<sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cHCO3\" value=\"$sel_cHCO3\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Hydrogénocarbonate')\"><BR>\n";
print "<B>Cl<sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cCl\" value=\"$sel_cCl\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Chlore')\"><BR>\n";
print "<B>SO<sub>4</sub><sup>--</sup></B> (en ppm) = <input size=6 class=inputNum name=\"cSO4\" value=\"$sel_cSO4\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en Sulfates')\"><BR>\n";
print "<TR><TD style=border:0 colspan=2 align=center><B>NICB</B> (%) = <input class=inputNum name=\"NICB\" size=5 readOnly onFocus=\"nicb()\" value=\"\"  onMouseOut=\"nd()\" onmouseover=\"overlib('Normalized Inorganic Charge Balance')\">";
print "</TD>";
print "</TR></table>";
print "</fieldset>";

print "<fieldset><legend>Concentrations organiques</legend>";
print "<table><TR><TD style=border:0 valign=top>";
print "<P class=parform align=right>";
print "<B>DOC</B> (en ppm) = <input size=6 class=inputNum name=\"cDOC\" value=\"$sel_cDOC\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration organique dissoute')\"><BR>\n";
print "<B>POC</B> (en ppm) = <input size=6 class=inputNum name=\"cPOC\" value=\"$sel_cPOC\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la concentration en particules organiques')\"><BR>\n";
print "</P></TD></TR></table>";
print "</fieldset>";

print "<fieldset><legend>Mesures en laboratoire</legend>";
print "<P class=parform align=right>";
print "<B>Conductivité à 25°C</B> (en µS/cm) = <input size=6 class=inputNum name=cond25 value=\"$sel_cond25\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de conductivité électrique à 25°C')\"><BR>";
print "</P>";
print "</fieldset>";
print "<TR>";
print "<TD style=border:0 colspan=2>";
print "<B>Observations</B> : <BR><input size=80 name=rem value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter toute présence d&rsquo;odeur, gaz, précipité, etc...')\"><BR>";
print "</TR><TR>";
print "<TD style=border:0 colspan=2>";
print "<P style=\"margin-top:20px;text-align:center\">";
print "<input type=\"button\"  name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_SHOW')."'\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\">";
print "</P></TABLE>";
print "</FORM>";

# Page end
# 
print "<BR>\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon, Jean-Marie Saurel

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

