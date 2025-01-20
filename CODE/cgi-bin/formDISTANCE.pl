#!/usr/bin/perl

=head1 NAME

formDISTANCE.pl 

=head1 SYNOPSIS

http://..../formDISTANCE?[id=]

=head1 DESCRIPTION

Ce script permet l'affichage du formulaire d'édition d'un enregistrement des données 
de distancemétrie de l'OVSG. 
 
=head1 Configuration DISTANCE 

Voir 'showDISTANCE.pl' pour un exemple de fichier configuration 'DISTANCE.conf'

=head1 Query string parameter

=over

=itme B<id=>
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

die "You can't edit DISTANCE reports." if (!clientHasEdit(type=>"authforms",name=>"DISTANCE"));

my $FORM = new WebObs::Form('DISTANCE');
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
my $sel_hr    = strftime('%H',@tod);
my $sel_mn    = strftime('%M',@tod);
my $today     = strftime('%F',@tod);

# ---- specific FORM inits -----------------------------------
my @html;
my $s;

my @types    = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));
my @meteo    = readCfgFile($FORM->path."/".$FORM->conf('FILE_METEO'));

my @vitres   = ("0|Ouverte","1|Fermée");

$ENV{LANG} = $WEBOBS{LOCALE};

# ---- 
my $sel_aemd = split(/\|/,$types[0]);
my $sel_pAtm;
my $sel_tAir;
my $sel_HR;
my $sel_nebul = "0";
my $sel_vitre = "0";
my $sel_D0;
my ($sel_site,$sel_d01,$sel_d02,$sel_d03,$sel_d04,$sel_d05,$sel_d06,$sel_d07,$sel_d08,$sel_d09,$sel_d10,$sel_d11,$sel_d12,$sel_d13,$sel_d14,$sel_d15,$sel_d16,$sel_d17,$sel_d18,$sel_d19,$sel_d20);
$sel_site=$sel_d01=$sel_d02=$sel_d03=$sel_d04=$sel_d05=$sel_d06=$sel_d07=$sel_d08=$sel_d09=$sel_d10=$sel_d11=$sel_d12=$sel_d13=$sel_d14=$sel_d15=$sel_d16=$sel_d17=$sel_d18=$sel_d19=$sel_d20 = "";
my $sel_rem;
my $sel;

# ---- Variables des menus 
my @anneeListe  = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe   = ('01'..'12');
my @jourListe   = ('01'..'31');
my @heureListe  = ('00'..'24');
my @minuteListe = ('00'..'59');
my @donneeListe = ('01'..'20');

# ---- Debut de l'affichage HTML
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
        alert(\"Veuillez spécifier le site de mesure!\");
        document.formulaire.site.focus();
        return false;
    }
    if(document.formulaire.D0.value == \"\") {
        alert(\"Veuillez indiquer la distance initiale!\");
        document.formulaire.D0.focus();
        return false;
    }
    if(document.formulaire.moy.value == 0) {
        alert(\"Veuillez indiquer au moins une mesure!\");
        document.formulaire.d01.focus();
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
    var moy = 0;
    var sig = 0;
    var n = 0;
    var v = 0;
    var dd;";

for ('01'..'20') {
    print "if (formulaire.d$_.value != \"\") {
        dd = 0;
        v = formulaire.D0.value*1 + formulaire.d$_.value/1000;
        if ((formulaire.d$_.value - formulaire.d01.value) < -500) { v += 1; }
        if ((formulaire.d$_.value - formulaire.d01.value) > 500) { v -= 1; }
        moy += v; sig += v*v; n++;
        }\n";
}

print "    if (n != 0) {
        moy = moy/n;
        sig = 2*Math.sqrt(sig/n - (moy*moy));
    }
    formulaire.moy.value = moy.toFixed(3);
    formulaire.sig.value = sig.toFixed(3);
    formulaire.sig.style.background = \"#66FF66\";
    if (sig > 0.02) {
        formulaire.sig.style.background = \"#FFD800\";
    }
    if (sig > 0.1) {
        formulaire.sig.style.background = \"#FF0000\";
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
FIN

# ---- read data file 
# 
my $message = "Saisie de nouvelles donn&eacute;es";
my @ligne;
my $ptr='';
my $fts-1;
my ($id,$date,$heure,$site,$aemd,$pAtm,$tAir,$HR,$nebul,$vitre,$D0,$d01,$d02,$d03,$d04,$d05,$d06,$d07,$d08,$d09,$d10,$d11,$d12,$d13,$d14,$d15,$d16,$d17,$d18,$d19,$d20,$rem,$val);
$id=$date=$heure=$site=$aemd=$pAtm=$tAir=$HR=$nebul=$vitre=$D0=$d01=$d02=$d03=$d04=$d05=$d06=$d07=$d08=$d09=$d10=$d11=$d12=$d13=$d14=$d15=$d16=$d17=$d18=$d19=$d20=$rem=$val = "";
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) == 1) {
        chomp(@ligne);
        ($id,$date,$heure,$site,$aemd,$pAtm,$tAir,$HR,$nebul,$vitre,$D0,$d01,$d02,$d03,$d04,$d05,$d06,$d07,$d08,$d09,$d10,$d11,$d12,$d13,$d14,$d15,$d16,$d17,$d18,$d19,$d20,$rem,$val) = split (/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            $sel_annee = substr($date,0,4);
            $sel_mois = substr($date,5,2);
            $sel_jour = substr($date,8,2);
            $sel_hr = substr($heure,0,2);
            $sel_mn = substr($heure,3,2);
            $sel_site = $site;
            $sel_aemd = $aemd;
            $sel_pAtm = $pAtm;
            $sel_tAir = $tAir;
            $sel_HR = $HR;
            $sel_nebul = $nebul;
            $sel_vitre = $vitre;
            $sel_D0 = $D0;
            for (@donneeListe) {
                eval("\$sel_d$_ = \$d$_;");
            }
            $sel_rem = $rem;
            $sel_rem =~ s/"/&quot;/g;
            $message = "Modification donn&eacute;e n° $QryParm->{id}";
        } else { $QryParm->{id} = ""; $val = "" ; }
    } else { $QryParm->{id} = ""; $val = "" ;}
}

print "<TABLE ><TR><TD style=\"border:0\">
<H1>$titrePage</H1>\n<H2>$message</H2>
</TD><TD style=\"border:0; text-align:right\">";
print "</TD></TR></TABLE>";

print "<FORM name=formulaire id=\"theform\" action=\"\">";
if ($QryParm->{id} ne "") {
    print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\">";
}

print "<input type=\"hidden\" name=\"oper\" value=\"$CLIENT\">\n";

print "<TABLE style=border:0 onMouseOver=\"calc()\">
    <TR><TD style=border:0 valign=top nowrap>";
print "<fieldset><legend>Date et site visé</legend>
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
print "<B>Site:</B> <select name=site onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le site')\" size=\"1\"><option value=\"\"></option>\n";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    $sel = "";
    if ($cle[0] eq $sel_site) { $sel = "selected"; }
    print "<option $sel value=$cle[0]>$cle[1]</option>\n";
}
print "</select></P>\n";
print "</fieldset>";

print "<fieldset><legend>Mesures et param&egrave;tres m&eacute;t&eacute;o</legend>
        <P class=parform>
        <B>Pression atmosph&eacute;rique </B> (en mmHg) = <input size=5 class=inputNum name=pAtm value=\"$sel_pAtm\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de pression atmosphérique')\"><BR>\n
        <B>Temp&eacute;rature de l'air</B> (en °C) = <input size=5 class=inputNum name=tAir value=\"$sel_tAir\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de température de l&apos;air')\"><BR>\n
        <B>H.R.</B> (en %) = <input size=5 class=inputNum name=HR value=\"$sel_HR\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur d&apos;humidité relative')\"><BR>
        <B>N&eacute;bulosit&eacute; sur le trajet:</B> <select onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner la n&eacute;bulosit&eacute;')\" name=\"nebul\" size=\"1\">\n";
for (@meteo) {
    my @cle = split(/\|/,$_);
    $sel = "";
    if ($cle[0] eq $sel_nebul) { $sel = "selected"; }
    print "<option $sel value=$cle[0]>$cle[1]</option>\n";
}
print "</select></P>\n";
print "</fieldset>\n";
print "</TD>\n";

print "<TD style=border:0 valign=top>";
print "<fieldset><legend>Mesures de distance (m)</legend>
    <P class=parform>
    <B>Type d'appareil:</B> <select onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner le type d&apos;appareil')\" name=\"aemd\" size=\"1\">\n";
for (@types) {
    my @cle = split(/\|/,$_);
    $sel = "";
    if ($cle[0] eq $sel_aemd) { $sel = "selected"; }
    print "<option $sel value=$cle[0]>$cle[1]</option>\n";
}
print "</select><BR>
    <B>Vitre:</B> <select onMouseOut=\"nd()\" onmouseover=\"overlib('Indiquer si la vitre est ouverte ou ferm&eacute;e')\" name=\"vitre\" size=\"1\">";
for (@vitres) {
    my @cle = split(/\|/,$_);
    $sel = "";
    if ($_ eq $sel_vitre) { $sel = "checked"; }
    print "<option $sel value=$cle[0]>$cle[1]</option>";
}
print "</select></P>";
print "<P class=parform>
        <B>Distance initiale:</B> (en m) <input size=4 class=inputNum name=\"D0\" tabindex=1 value=\"$sel_D0\"
            onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la mesure de distance initiale')\"></P>\n";
print "<P class=parform><B>Fractions:</B> (en mm)<BR>";
for (@donneeListe) {
    print "<input size=3 class=inputNum name=\"d$_\" tabindex=1 value=\"".eval("\$sel_d$_")."\"
            onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la fraction de chaque mesure (en mm)')\">";
}
print "</P>\n";

print "<P class=parform><B>Moyenne</B> (m) = <input name=\"moy\" size=8 readOnly class=inputNumNoEdit>
    <B>2 &times; &Eacute;cart-type</B> (m) = <input name=\"sig\" size=5 readOnly class=inputNumNoEdit></P>\n";
print "</fieldset>\n";
print "</TD>\n";
print "</TR>\n";

print "<TR><TD style=\"border: none\">";
print "<fieldset><legend>Observations</legend>";
print "<P class=parform>";
print "<input size=70 name=rem value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter vos observations')\"><BR>
    <B>Information de saisie:</B> $val
    <INPUT type=hidden name=val value=\"$val\"></P>";
print "</fieldset>\n";
print "</TD></TR>\n";

print "<TR><TD colspan=2 style=border:0>";
print "<P style=\"margin-top:20px;text-align:center\">";
print "<input type=\"button\" name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_SHOW')."'\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\">";
print "</P></FORM>";
print "</TD></TR>";

print "</TABLE>";

# Fin de la page
# 
print "</BODY>\n</HTML>\n";

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

