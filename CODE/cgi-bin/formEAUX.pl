#!/usr/bin/perl

=head1 NAME

formEAUX.pl

=head1 SYNOPSIS

http://..../formEAUX.pl?[id=]

=head1 DESCRIPTION

Edit form of water chemical analysis data bank.

=head1 Configuration EAUX

See 'showEAUX.pl' for an example of configuration file 'EAUX.conf'

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

die "You can't edit EAUX reports." if (!clientHasEdit(type=>"authforms",name=>"EAUX"));

my $FORM = new WebObs::Form('EAUX');
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
my @rapports = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

# ----
my $sel_type = "G1";
my ($sel_site,$sel_tAir,$sel_tSource,$sel_pH,$sel_debit,$sel_cond,$sel_niveau,$sel_cLi,$sel_cNa,$sel_cK,$sel_cMg,$sel_cCa,$sel_cF,$sel_cCl,$sel_cBr,$sel_cNO3,$sel_cSO4,$sel_cHCO3,$sel_cI,$sel_cSiO2,$sel_d13C,$sel_d18O,$sel_dD,$sel_rem);
$sel_site=$sel_tAir=$sel_tSource=$sel_pH=$sel_debit=$sel_cond=$sel_niveau=$sel_cLi=$sel_cNa=$sel_cK=$sel_cMg=$sel_cCa=$sel_cF=$sel_cCl=$sel_cBr=$sel_cNO3=$sel_cSO4=$sel_cHCO3=$sel_cI=$sel_cSiO2=$sel_d13C=$sel_d18O=$sel_dD=$sel_rem = "";

# ---- Variables des menus
my @anneeListe = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe  = ('01'..'12');
my @jourListe  = ('01'..'31');
my @heureListe = ("",'00'..'23');
my @minuteListe= ("",'00'..'59');

# ---- Debut de l'affichage HTML
#
print qq[Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>] . $FORM->conf('TITLE') . qq[</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script type="text/javascript">
<!--
function update_form()
{
    var anions;
    var cations;
    var cations_chromato;
    var hydrogene = 0;
    var nicb;
    var formulaire = document.formulaire;

    if (formulaire.pH.value != "") {
        hydrogene = 1000*Math.pow(10,-formulaire.pH.value);
    }
    cations_chromato = formulaire.cLi.value/$GMOL{Li}
           + formulaire.cNa.value/$GMOL{Na}
           + formulaire.cK.value/$GMOL{K}
           + 2*formulaire.cMg.value/$GMOL{Mg}
           + 2*formulaire.cCa.value/$GMOL{Ca};
    cations = cations_chromato + hydrogene;
    anions = formulaire.cF.value/$GMOL{F}
           + formulaire.cCl.value/$GMOL{Cl}
           + formulaire.cBr.value/$GMOL{Br}
           + formulaire.cNO3.value/$GMOL{NO3}
           + 2*formulaire.cSO4.value/$GMOL{SO4}
           + formulaire.cHCO3.value/$GMOL{HCO3}
           + 1e-3*formulaire.cI.value/$GMOL{I};
    formulaire.cH.value = hydrogene.toFixed(2);
    nicb = 100*(cations - anions)/(cations + anions);
    // pHcalcule=-(Math.log((anions - cations_chromato)/1000))/Math.log(10);
    // document.getElementById("pHcalcule").innerHTML = "<i>pour NICB=0%, pH=\</i>" + pHcalcule.toFixed(2);
    // document.getElementById("pHcalcule").style.background = "#EEEEEE";
    formulaire.NICB.value = nicb.toFixed(1);
    formulaire.NICB.style.background = "#66FF66";
    if (nicb > 10 || nicb < -10) {
        formulaire.NICB.style.background = "#FFD800";
    }
    if (nicb > 20 || nicb < -20) {
        formulaire.NICB.style.background = "#FF0000";
    }
}

function suppress(level)
{
    var str = "]  . $FORM->conf('TITLE') . qq[ ?";
    if (level > 1) {
        if (!confirm("$__{'ATT: Do you want PERMANENTLY erase this record from '}" + str)) {
            return false;
        }
    } else {
        if (document.formulaire.id.value > 0) {
            if (!confirm("$__{'Do you want to remove this record from '}" + str)) {
                return false;
            }
        } else {
            if (!confirm("$__{'Do you want to restore this record in '}" + str)) {
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
        alert("Veuillez entrer un type!");
        document.formulaire.type.focus();
        return false;
    }
    submit();
}

function submit()
{
    \$.post("/cgi-bin/] . $FORM->conf('CGI_POST') . qq[", \$("#theform").serialize(), function(data) {
            alert(data);
            // Redirect the user to the form display page while keeping the previous filter
            document.location="] . $cgi->param('return_url') . qq[";
        }
    );
}
//-->
</script>
</head>

<body style="background-color:#E0E0E0">
 <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
 <!-- overLIB (c) Erik Bosrup -->
 <script language="javascript" src="/js/overlib/overlib.js"></script>
 <div id="helpBox"></div>
 <script type="text/javascript">
   // Prevent the Return key from submitting the form
   function stopRKey(evt) {
     var evt = (evt) ? evt : ((event) ? event : null);
     var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
     if ((evt.keyCode == 13) && (node.type=="text"))  {return false;}
   }
   document.onkeypress = stopRKey;

   // Once the document is loaded
   \$(document).ready(function(){
     // Update the form immediately
     update_form();
     // Also update the form when any of its element is changed
     \$('#theform').on("change", update_form);
     // Also update when a key is pressed in the form
     // but wait 1s for the previous handler execution to finish
     \$('#theform').on("keydown", function() { setTimeout(update_form, 1000); });
   });
 </script>
];

# ---- read data file
#
my $message = "Saisie de nouvelles donn&eacute;es";
my @ligne;
my $ptr;
my $fts = -1;
my ($id,$date,$heure,$site,$type,$tAir,$tSource,$pH,$debit,$cond,$niveau,$cLi,$cNa,$cK,$cMg,$cCa,$cF,$cCl,$cBr,$cNO3,$cSO4,$cHCO3,$cI,$cSiO2,$d13C,$d18O,$dD,$rem,$val);
$id=$date=$heure=$site=$type=$tAir=$tSource=$pH=$debit=$cond=$niveau=$cLi=$cNa=$cK=$cMg=$cCa=$cF=$cCl=$cBr=$cNO3=$cSO4=$cHCO3=$cI=$cSiO2=$d13C=$d18O=$dD=$rem=$val = "";
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) >= 1) {
        chomp(@ligne);
        ($id,$date,$heure,$site,$type,$tAir,$tSource,$pH,$debit,$cond,$niveau,$cLi,$cNa,$cK,$cMg,$cCa,$cF,$cCl,$cBr,$cNO3,$cSO4,$cHCO3,$cI,$cSiO2,$d13C,$d18O,$dD,$rem,$val) = split (/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            ($sel_annee,$sel_mois,$sel_jour) = split (/-/,$date);
            ($sel_hr,$sel_mn) = split (/:/,$heure);
            $sel_site = $site;
            $sel_type = $type;
            $sel_tAir = $tAir;
            $sel_tSource = $tSource;
            $sel_pH = $pH;
            $sel_debit = $debit;
            $sel_cond = $cond;
            $sel_niveau = $niveau;
            $sel_cLi = $cLi;
            $sel_cNa = $cNa;
            $sel_cK = $cK;
            $sel_cMg = $cMg;
            $sel_cCa = $cCa;
            $sel_cF = $cF;
            $sel_cCl = $cCl;
            $sel_cBr = $cBr;
            $sel_cNO3 = $cNO3;
            $sel_cSO4 = $cSO4;
            $sel_cHCO3 = $cHCO3;
            $sel_cI = $cI;
            $sel_cSiO2 = $cSiO2;
            $sel_d13C = $d13C;
            $sel_d18O = $d18O;
            $sel_dD = $dD;
            $sel_rem = $rem;
            $message = "Modification donn&eacute;e n° $QryParm->{id}";
        } else { $QryParm->{id} = ""; $val = "" ; }
    } else { $QryParm->{id} = ""; $val = "" ;}
}

print qq(<form name="formulaire" id="theform" action="">
<input type="hidden" name="oper" value="$USERS{$CLIENT}{UID}">
<input type="hidden" name="delete" value="">

<table width="100%">
  <tr>
    <td style="border: 0">
     <h1>) . $FORM->conf('TITLE') . qq(</h1>\
     <h2>$message</h2>
    </td>
  </tr>
);

if ($QryParm->{id} ne "") {
    print qq(<input type="hidden" name="id" value="$QryParm->{id}">);
    print qq(<tr><td style="border: 0"><hr>);
    if ($val ne "") {
        print qq(<p><b>Information de saisie:</b> $val
		<input type="hidden" name="val" value="$val"></p>);
    }
    print qq(<input type="button" value=") . ($id < 0 ? "Reset":"$__{'Remove'}") . qq(" onClick="suppress(1);">);
    if (clientHasAdm(type=>"authforms",name=>"EAUX")) {
        print qq(<input type="button" value="$__{'Erase'}" onClick="suppress(2);">);
    }
    print qq(<hr></td></tr>);
}

print qq(</table>
<table style="border: 0" >
  <tr>
    <td style="border: 0" valign="top">
      <fieldset>
        <legend>Date et lieu du prélèvement</legend>
        <p class="parform">
          <b>Date: </b>
          <select name="annee" size="1">
);

for (@anneeListe) {
    if ($_ == $sel_annee) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq(<select name="mois" size="1">);
for (@moisListe) {
    if ($_ == $sel_mois) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq( <select name=jour size="1">);
for (@jourListe) {
    if ($_ == $sel_jour) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print "</select>";

print qq(&nbsp;&nbsp;<b>Heure: </b><select name=hr size="1">);
for (@heureListe) {
    if ($_ eq $sel_hr) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq(<select name=mn size="1">);
for (@minuteListe) {
    if ($_ eq $sel_mn) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select><BR>
	<B>Site: </B>
	  <select name="site" size="1"
		onMouseOut="nd()"onmouseover="overlib('S&eacute;lectionner le site du prélèvement')">
	  <option value=""></option>);

for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    if ($cle[0] eq $sel_site) {
        print qq(<option selected value="$cle[0]">$cle[1]</option>);
    } else {
        print qq(<option value="$cle[0]">$cle[1]</option>);
    }
}
print qq(</select><BR>
	<B>Type: </B>
      <select name="type" size="1"
		onMouseOut="nd()" onmouseover="overlib('S&eacute;lectionner le type')">
	  <option value=""></option>);

for (sort(keys(%types))) {
    print qq(<option) . ($_ eq $sel_type ? " selected" : "") . qq( value=$_>$_: $types{$_}{name}</option>);
}

print qq(</select>
        </P>
      </fieldset>
      <fieldset>
        <legend>Mesures sur site</legend>
        <P class="parform">
          <B>Température ambiante </B> (en °C) = <input size=5 class=inputNum name=tAir value="$sel_tAir"
              onMouseOut="nd()" onmouseover="overlib('Entrer la valeur de température ambiante')"><BR>
          <B>Température du liquide</B> (en °C) = <input size=5 class=inputNum name=tSource value="$sel_tSource"
              onMouseOut="nd()" onmouseover="overlib('Entrer la valeur de température du liquide')"><BR>
          <B>pH</B> = <input size=5 class=inputNum name=pH value="$sel_pH" onMouseOut="nd()"
              onmouseover="overlib('Entrer la valeur du pH')">&nbsp;&nbsp;&nbsp;
              <span id="pHcalcule" class="inputNumNoEdit"></span><BR>
          <B>Conductivité</B> (en µS) = <input size=6 class=inputNum name=cond value="$sel_cond"
              onMouseOut="nd()" onmouseover="overlib('Entrer la valeur de conductivité électrique')"><BR>
          <B>débit</B> (en l/min) = <input size=5 class=inputNum name=debit value="$sel_debit"
              onMouseOut="nd()" onmouseover="overlib('Entrer la valeur du débit (source <b>tarie</b>: <i>débit = 0</i>)')"><BR>
          <B>Niveau</B> (en m) = <input size=6 class=inputNum name=niveau value="$sel_niveau"
              onMouseOut="nd()" onmouseover="overlib('Entrer la valeur du niveau (lac)')"><BR>
        </P>
      </fieldset>
    </TD>

    <TD style=border:0 valign=top>
      <fieldset>
        <legend>Concentrations en cations et anions</legend>
        <P><I>Attention: valeurs en <B>ppm = mg/l</B></I></P>
        <table>
          <tr>
            <td style="border: 0" valign="top">
              <P class="parform" align="right">
              <B>Li<sup>+</sup></B> (en ppm) = <input size=6 class=inputNum name="cLi" value="$sel_cLi"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Lithium')"><BR>
              <B>Na<sup>+</sup></B> (en ppm) = <input size=6 class=inputNum name="cNa" value="$sel_cNa"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Sodium')"><BR>
              <B>K<sup>++</sup></B> (en ppm) = <input size=6 class=inputNum name="cK" value="$sel_cK"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Potassium')"><BR>
              <B>Mg<sup>++</sup></B> (en ppm) = <input size=6 class=inputNum name="cMg" value="$sel_cMg"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Magnésium')"><BR>
              <B>Ca<sup>++</sup></B> (en ppm) = <input size=6 class=inputNum name="cCa" value="$sel_cCa"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Calcium')"><BR>
              <B>H<sup>+</sup></B> (en ppm) = <input size=6 readOnly class=inputNumNoEdit name="cH"
                 onMouseOut="nd()" onmouseover="overlib('Concentration en Hydrogène calculé à partir du pH')"><BR>
              </TD><TD style=border:0 valign=top>
              <P class=parform align=right>
              <B>F<sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name="cF" value="$sel_cF"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Fluor')"><BR>
              <B>Cl<sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name="cCl" value="$sel_cCl"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Chlore')"><BR>
              <B>Br<sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name="cBr" value="$sel_cBr"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Brome')"><BR>
              <B>NO<sub>3</sub><sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name="cNO3" value="$sel_cNO3"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Nitrates')"><BR>
              <B>SO<sub>4</sub><sup>--</sup></B> (en ppm) = <input size=6 class=inputNum name="cSO4" value="$sel_cSO4"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Sulfates')"><BR>
              <B>HCO<sub>3</sub><sup>-</sup></B> (en ppm) = <input size=6 class=inputNum name="cHCO3" value="$sel_cHCO3"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Carbonates')"><BR>
              <B>I<sup>-</sup></B> (en ppb) = <input size=6 class=inputNum name="cI" value="$sel_cI"
                 onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Iode (<b>ATTENTION: valeur en ppb !</b>)')"><BR>
            </td>
          </tr>
          <tr>
            <td style="border: 0" colspan="2" align="center">
              <B>NICB</B> (%) = <input class=inputNum name="NICB" size=5 readOnly value=""
                 onMouseOut="nd()" onmouseover="overlib('Normalized Inorganic Charge Balance')">
            </td>
          </tr>
        </table>
      </fieldset>

      <fieldset>
        <legend>Concentration en autres éléments</legend>
        <table>
          <TR>
            <TD style=border:0 valign=top>
              <P class=parform align=right>
                <B>SiO<sub>2</sub></B> (en ppm) = <input size=6 class=inputNum name="cSiO2" value="$sel_cSiO2"
                   onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Silice')"><BR>
              </P>
            </TD>
          </TR>
        </table>
      </fieldset>

      <fieldset>
        <legend>Concentrations en isotopes</legend>
        <table>
          <TR>
            <TD style=border:0 valign=top>
              <P class=parform align=right>
                <B>&delta;<sup>13</sup>C</B> = <input size=6 class=inputNum name="d13C" value="$sel_d13C"
                  onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Carbone 13')"><BR>
                <B>&delta;<sup>18</sup>O</B> = <input size=6 class=inputNum name="d18O" value="$sel_d18O"
                  onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Oxygène 18')"><BR>
                <B>&delta;D</B> = <input size=6 class=inputNum name="dD" value="$sel_dD"
                  onMouseOut="nd()" onmouseover="overlib('Entrer la concentration en Deutérium')"><BR>
              </P>
            </TD>
          </TR>
        </table>
      </fieldset>
    </td>
  </tr>
  <tr>
    <td style="border: 0" colspan="2">
      <B>Observations</B> :<BR>
      <input size=80 name=rem value="$sel_rem"
      onMouseOut="nd()" onmouseover="overlib('Noter toute présence d&rsquo;odeur, gaz, précipité, etc...')"><BR>
    </td>
  </tr>
  <tr>
    <td style="border: 0" colspan="2">
      <P style="margin-top: 20px; text-align: center">
        <input type="button" name=lien value="Annuler"
         onClick="document.location=') . $cgi->param('return_url') . qq('" style="font-weight: normal">
        <input type="button" value="Soumettre" onClick="verif_formulaire();">
      </P>
    </td>
  </tr>
</table>
</form>

<br>
</body>
</html>);

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

