#!/usr/bin/perl

=head1 NAME

formSOILSOLUTION.pl

=head1 SYNOPSIS

http://..../formSOILSOLUTION.pl?[id=]

=head1 DESCRIPTION

Edit form of soil solutions chemical analysis data bank.

=head1 Configuration SOILSOLUTION

See 'showSOILSOLUTION.pl' for an example of configuration file 'SOILSOLUTION.conf'

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

die "You can't edit SOILSOLUTION reports." if (!clientHasEdit(type=>"authforms",name=>"SOILSOLUTION"));

my $FORM = new WebObs::Form('SOILSOLUTION');
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

my @depth = split(/,/,$FORM->conf('SAMPLING_DEPTH_CM'));

# ---- Read the data file to retrieve most recent data for each node+depth
my ($lines, $dataTS) = $FORM->data;
@$lines = reverse sort tri_date_avec_id @$lines;
my %lastData;
for my $id (keys(%Ns)) {
    for my $d (@depth) {
        my @tmp = grep(/\|$id\|$d\|/,@$lines);
        chomp(@tmp);
        $lastData{$id."_".$d} = $tmp[$#tmp];
    }
}

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my @defTime = split(/:/,$FORM->conf('DEFAULT_SAMPLING_TIME'));
my $sel_d1 = "";
my $sel_m1 = "";
my $sel_y1 = "";
my $sel_hr1 = "";
my $sel_mn1 = "";
my $sel_d2 = strftime('%d',@tod);
my $sel_m2 = strftime('%m',@tod);
my $sel_y2 = strftime('%Y',@tod);
my $sel_hr2 = $defTime[0];
my $sel_mn2 = $defTime[1];
my $currentYear = strftime('%Y',@tod);
my $today = strftime('%F',@tod);

# ---- specific FORM inits -----------------------------------
my @html;
my $affiche;
my $s;
my @ratios = readCfgFile($FORM->path."/".$FORM->conf('FILE_RATIOS'));

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

# ----
my ($sel_site,$sel_depth,$sel_level,$sel_pH,$sel_cond,$sel_cNa,$sel_cK,$sel_cMg,$sel_cCa,$sel_cHCO3,$sel_cCl,$sel_cNO3,$sel_cSO4,$sel_cSiO2,$sel_cDOC,$sel_rem);
$sel_site=$sel_depth=$sel_pH=$sel_cond=$sel_cNa=$sel_cK=$sel_cMg=$sel_cCa=$sel_cHCO3=$sel_cCl=$sel_cNO3=$sel_cSO4=$sel_cSiO2=$sel_cDOC=$sel_rem = "";
$sel_level = 1; # default box level checked

# ---- Variables des menus
my @yearList = ($FORM->conf('BANG')..$currentYear);
my @monthList  = ('01'..'12');
my @dayList  = ('01'..'31');
my @hourList = ("",'00'..'23');
my @minuteList= ("",'00'..'59');

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
function update_site()
{
    var lastData = {};
];
foreach my $id (keys(%Ns)) {
    foreach my $d (@depth) {
        my $key = $id."_".$d;
        print qq[    lastData["$key"] = "$lastData{$key}";\n];
    }
}
print qq[
    var form = document.formulaire;

    if (form.site.value != "") {
        var array = lastData[form.site.value + "_" + form.depth.value].split("|");
        var date = array[1].split("-");
        var time = array[2].split(":");
        form.y1.value = date[0];
        form.m1.value = date[1];
        form.d1.value = date[2];
        form.hr1.value = time[0];
        form.mn1.value = time[1];
    }
    update_form();
}

function update_form()
{
    var anions;
    var cations;
    var cations_chromato;
    var hydrogene = 0;
    var nicb;
    var form = document.formulaire;

    if (form.pH.value != "") {
        hydrogene = 1000*Math.pow(10,-form.pH.value);
    }
    cations_chromato = form.cNa.value/$GMOL{Na}
           + form.cK.value/$GMOL{K}
           + 2*form.cMg.value/$GMOL{Mg}
           + 2*form.cCa.value/$GMOL{Ca};
    cations = cations_chromato + hydrogene;
    anions = form.cHCO3.value/$GMOL{HCO3}
           + form.cCl.value/$GMOL{Cl}
           + form.cNO3.value/$GMOL{NO3}
           + 2*form.cSO4.value/$GMOL{SO4};
    form.cH.value = hydrogene.toFixed(2);
    nicb = 100*(cations - anions)/(cations + anions);
    // pHcalcule=-(Math.log((anions - cations_chromato)/1000))/Math.log(10);
    // document.getElementById("pHcalcule").innerHTML = "<i>pour NICB=0%, pH=\</i>" + pHcalcule.toFixed(2);
    // document.getElementById("pHcalcule").style.background = "#EEEEEE";
    form.NICB.value = nicb.toFixed(1);
    form.NICB.style.background = "#33FF33";
    if (nicb > 10 || nicb < -10) {
        form.NICB.style.background = "#FFD800";
    }
    if (nicb > 20 || nicb < -20) {
        form.NICB.style.background = "#FF0000";
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

function check_form()
{
    if(document.formulaire.site.value == "") {
        alert("You must select the sample site!");
        document.formulaire.site.focus();
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
my $message = $__{'Enter a new data'};
my @line;
my $ptr;
my $fts = -1;
my ($id,$date2,$time2,$site,$date1,$time1,$depth,$level,$pH,$cond,$cNa,$cK,$cMg,$cCa,$cHCO3,$cCl,$cNO3,$cSO4,$cSiO2,$cDOC,$rem,$val);
$id=$date2=$time2=$site=$date1=$time1=$depth=$level=$pH=$cond=$cNa=$cK=$cMg=$cCa=$cHCO3=$cCl=$cNO3=$cSO4=$cSiO2=$cDOC=$rem=$val = "";
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @line = @$ptr;
    if (scalar(@line) >= 1) {
        chomp(@line);
        ($id,$date2,$time2,$site,$date1,$time1,$depth,$level,$pH,$cond,$cNa,$cK,$cMg,$cCa,$cHCO3,$cCl,$cNO3,$cSO4,$cSiO2,$cDOC,$rem,$val) = split (/\|/,l2u($line[0]));
        if ($QryParm->{id} eq $id) {
            ($sel_y1,$sel_m1,$sel_d1) = split (/-/,$date1);
            ($sel_hr1,$sel_mn1) = split (/:/,$time1);
            ($sel_y2,$sel_m2,$sel_d2) = split (/-/,$date2);
            ($sel_hr2,$sel_mn2) = split (/:/,$time2);
            $sel_site = $site;
            $sel_depth = $depth;
            $sel_level = $level;
            $sel_pH = $pH;
            $sel_cond = $cond;
            $sel_cNa = $cNa;
            $sel_cK = $cK;
            $sel_cMg = $cMg;
            $sel_cCa = $cCa;
            $sel_cHCO3 = $cHCO3;
            $sel_cCl = $cCl;
            $sel_cNO3 = $cNO3;
            $sel_cSO4 = $cSO4;
            $sel_cSiO2 = $cSiO2;
            $sel_cDOC = $cDOC;
            $sel_rem = $rem;
            $message = $__{"Edit existing data n° $QryParm->{id}"};
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
        print qq(<p><b>$__{'Input Information'}:</b> $val
        <input type="hidden" name="val" value="$val"></p>);
    }
    print qq(<input type="button" style="font-weight: bold" value=") . ($id < 0 ? "Reset":"$__{'Remove'}") . qq(" onClick="suppress(1);">);
    if (clientHasAdm(type=>"authforms",name=>"SOILSOLUTION")) {
        print qq(<input type="button" style="font-weight: bold" value="$__{'Erase'}" onClick="suppress(2);">);
    }
    print qq(<hr></td></tr>);
}

print qq(</table>
<table style="border: 0" >
  <tr>
    <td style="border: 0" valign="top">
      <fieldset>
        <legend>$__{'Sampling Location and Time'}</legend>
       <P class="parform" align="right">
    <B>$__{'Site'}: </B>
    <select name="site" size="1" onChange="update_site()"
        onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_site}')">);
print qq(<option value=""></option>) if ($QryParm->{id} eq "");

for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    if ($cle[0] eq $sel_site) {
        print qq(<option selected value="$cle[0]">$cle[1]</option>);
    } elsif ($QryParm->{id} eq "") {
        print qq(<option value="$cle[0]">$cle[1]</option>);
    }
}
print qq(</select><BR>
          <b>$__{'Start Date'}: </b>
          <select name="y1" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date1}')">
);

for (@yearList) {
    if ($_ == $sel_y1) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq(<select name="m1" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date1}')">);
for (@monthList) {
    if ($_ == $sel_m1) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq( <select name="d1" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date1}')">);
for (@dayList) {
    if ($_ == $sel_d1) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print "</select>";

print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name="hr1" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date1}')">);
for (@hourList) {
    if ($_ eq $sel_hr1) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq(<select name="mn1" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date1}')">);
for (@minuteList) {
    if ($_ eq $sel_mn1) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select><BR>
          <b>$__{'End Date'}: </b>
          <select name="y2" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date2}')">
);

for (@yearList) {
    if ($_ == $sel_y2) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq(<select name="m2" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date2}')">);
for (@monthList) {
    if ($_ == $sel_m2) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq( <select name="d2" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date2}')">);
for (@dayList) {
    if ($_ == $sel_d2) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print "</select>";

print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name="hr2" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date2}')">);
for (@hourList) {
    if ($_ eq $sel_hr2) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(</select>);
print qq(<select name="mn2" size="1" onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_date2}')">);
for (@minuteList) {
    if ($_ eq $sel_mn2) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}

print qq(</select></P>
      </fieldset>
      <fieldset>
        <legend>$__{'Lysimeter'}</legend>
        <P class="parform">
          <B>$__{'Sampling Depth'}</B> (cm) = <select name=depth value="$sel_depth" size="1" onChange="update_site()"
              onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_depth}')">);
for (@depth) {
    if ($_ eq $sel_depth) {
        print qq(<option selected value="$_">$_</option>);
    } else {
        print qq(<option value="$_">$_</option>);
    }
}
print qq(
       </select><BR>
       <B>$__{'Water Level'}</B> (filled) = <input type="checkbox" name=level).($sel_level == "1" ? " checked":"")
  .qq( onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_level}')"><BR>
        </P>
      </fieldset>
      <fieldset>
        <legend>$__{'Physical Measurements'}</legend>
        <P class="parform">
          <B>$__{'pH'}</B> = <input size=5 class=inputNum name=pH value="$sel_pH" onMouseOut="nd()"
              onmouseover="overlib('$__{help_soilsolution_ph}')"><BR>
          <B>$__{'Conductivity at 25°C'}</B> (µS/cm) = <input size=6 class=inputNum name=cond value="$sel_cond"
              onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_cond}')"><BR>
          <B>SiO<sub>2</sub></B> (ppm) = <input size=6 class=inputNum name="cSiO2" value="$sel_cSiO2"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_sio2}')"><BR>
          <B>DOC</B> (ppm) = <input size=6 class=inputNum name="cDOC" value="$sel_cDOC"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_doc}')"><BR>
        </P>
      </fieldset>
    </TD>

    <TD style=border:0 valign=top>
      <fieldset>
        <legend>$__{'Cations and Anions Concentrations'}</legend>
        <table>
          <tr>
            <td style="border: 0" valign="top">
              <P class="parform" align="right">
              <B>Na<sup>+</sup></B> (ppm) = <input size=6 class=inputNum name="cNa" value="$sel_cNa"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_na}')"><BR>
              <B>K<sup>++</sup></B> (ppm) = <input size=6 class=inputNum name="cK" value="$sel_cK"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_k}')"><BR>
              <B>Mg<sup>++</sup></B> (ppm) = <input size=6 class=inputNum name="cMg" value="$sel_cMg"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_mg}')"><BR>
              <B>Ca<sup>++</sup></B> (ppm) = <input size=6 class=inputNum name="cCa" value="$sel_cCa"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_ca}')"><BR>
              <B>H<sup>+</sup></B> (ppm) = <input size=6 readOnly class=inputNumNoEdit name="cH"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_h}')"><BR>
              </TD><TD style=border:0 valign=top>
              <P class=parform align=right>
              <B>HCO<sub>3</sub><sup>-</sup></B> (ppm) = <input size=6 class=inputNum name="cHCO3" value="$sel_cHCO3"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_hco3}')"><BR>
              <B>Cl<sup>-</sup></B> (ppm) = <input size=6 class=inputNum name="cCl" value="$sel_cCl"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_cl}')"><BR>
              <B>NO<sub>3</sub><sup>-</sup></B> (ppm) = <input size=6 class=inputNum name="cNO3" value="$sel_cNO3"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_no3}')"><BR>
              <B>SO<sub>4</sub><sup>--</sup></B> (ppm) = <input size=6 class=inputNum name="cSO4" value="$sel_cSO4"
                 onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_so4}')"><BR>
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
    </td>
  </tr>
  <tr>
    <td style="border: 0" colspan="2">
      <B>Observations</B> :<BR>
      <input size=80 name=rem value="$sel_rem"
      onMouseOut="nd()" onmouseover="overlib('$__{help_soilsolution_observations}')"><BR>
    </td>
  </tr>
  <tr>
    <td style="border: 0" colspan="2">
      <P style="margin-top: 20px; text-align: center">
        <input type="button" name=lien value="$__{'Cancel'}"
         onClick="document.location=') . $cgi->param('return_url') . qq('" style="font-weight: normal">
        <input type="button" value="$__{'Submit'}" onClick="check_form();" style="font-weight: bold">
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

François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2021 - Institut de Physique du Globe Paris

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
