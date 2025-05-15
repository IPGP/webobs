#!/usr/bin/perl

=head1 NAME

formPLUVIO.pl 

=head1 SYNOPSIS

http://..../formPLUVIO.pl?[id=]

=head1 DESCRIPTION

Ce script permet l'affichage du formulaire d'édition d'un enregistrement des données
de pluviomètres de l'OVSG.
 
=head1 Configuration PLUVIO 

Voir 'showPLUVIO.pl' pour un exemple de fichier de configuration 'PLUVIO.conf':

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

# ---- standard FORMS inits --------------------------------

die "You can't edit PLUVIO reports." if (!clientHasEdit(type=>"authforms",name=>"PLUVIO"));

my $FORM = new WebObs::Form('PLUVIO');
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

# ---- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $anneeActuelle = strftime('%Y',@tod);
my $sel_annee     = strftime('%Y',@tod);
my $sel_mois      = strftime('%m',@tod);

# ---- specific FORM inits --------------------------------
my @html;
my $affiche;
my $s;
my @nomMois = ("janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre");

my @types    = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));

$ENV{LANG} = $WEBOBS{LOCALE};

my $sel_type = "1";
my ($sel_site,$sel_d01,$sel_v01,$sel_d02,$sel_v02,$sel_d03,$sel_v03,$sel_d04,$sel_v04,$sel_d05,$sel_v05,$sel_d06,$sel_v06,$sel_d07,$sel_v07,$sel_d08,$sel_v08,$sel_d09,$sel_v09,$sel_d10,$sel_v10,$sel_d11,$sel_v11,$sel_d12,$sel_v12,$sel_d13,$sel_v13,$sel_d14,$sel_v14,$sel_d15,$sel_v15,$sel_d16,$sel_v16,$sel_d17,$sel_v17,$sel_d18,$sel_v18,$sel_d19,$sel_v19,$sel_d20,$sel_v20,$sel_d21,$sel_v21,$sel_d22,$sel_v22,$sel_d23,$sel_v23,$sel_d24,$sel_v24,$sel_d25,$sel_v25,$sel_d26,$sel_v26,$sel_d27,$sel_v27,$sel_d28,$sel_v28,$sel_d29,$sel_v29,$sel_d30,$sel_v30,$sel_d31,$sel_v31) = split(/\|/,$_);
my $sel;

# ---- Variables des menus 
my @anneeListe = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe = ('01'..'12');
my @jourListe = ('01'..'31');

# Debut de l'affichage HTML
# 
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<html><head>
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
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
    \$.post(\"/cgi-bin/".$FORM->conf('CGI_POST')."\", \$(\"#theform\").serialize(), function(data) {
       //var contents = \$( data ).find( '#contents' ).text(); 
       alert(data);
       document.location=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\";
       }
    );
}

function zeros()
{";

for ("01".."31") {
    print "if (formulaire.d$_.value == \"\" && formulaire.d$_.disabled == false) { formulaire.d$_.value = 0; }\n";
}

print "}

function nbj()
{
    var m = formulaire.mois.value;
    switch(m) {
    case \"01\": case \"03\": case \"05\": case \"07\": case \"08\": case \"10\": case \"12\":
        formulaire.d30.disabled = false;
        formulaire.v30.disabled = false;
        formulaire.d31.disabled = false;
        formulaire.v31.disabled = false;
        break;
    case \"04\": case \"06\": case \"09\": case \"11\":
        formulaire.d30.disabled = false;
        formulaire.v30.disabled = false;
        formulaire.d31.value = \"\";
        formulaire.d31.disabled = true;
        formulaire.v31.disabled = true;
        break;
    case \"02\":
        formulaire.d30.value = \"\";
        formulaire.d30.disabled = true;
        formulaire.v30.disabled = true;
        formulaire.d31.value = \"\";
        formulaire.d31.disabled = true;
        formulaire.v31.disabled = true;
        break;
    }
}
function calc()
{
    var dec1 = 0;
    var dec2 = 0;
    var dec3 = 0;
    var tot = 0;
    
    dec1 = formulaire.d01.value*1
         + formulaire.d02.value*1
         + formulaire.d03.value*1
         + formulaire.d04.value*1
         + formulaire.d05.value*1
         + formulaire.d06.value*1
         + formulaire.d07.value*1
         + formulaire.d08.value*1
         + formulaire.d09.value*1
         + formulaire.d10.value*1;
    formulaire.sum1.value = dec1.toFixed(1);
    dec2 = formulaire.d11.value*1
         + formulaire.d12.value*1
         + formulaire.d13.value*1
         + formulaire.d14.value*1
         + formulaire.d15.value*1
         + formulaire.d16.value*1
         + formulaire.d17.value*1
         + formulaire.d18.value*1
         + formulaire.d19.value*1
         + formulaire.d20.value*1;
    formulaire.sum2.value = dec2.toFixed(1);
    dec3 = formulaire.d21.value*1
         + formulaire.d22.value*1
         + formulaire.d23.value*1
         + formulaire.d24.value*1
         + formulaire.d25.value*1
         + formulaire.d26.value*1
         + formulaire.d27.value*1
         + formulaire.d28.value*1
         + formulaire.d29.value*1
         + formulaire.d30.value*1
         + formulaire.d31.value*1;
    formulaire.sum3.value = dec3.toFixed(1);
    tot = formulaire.sum1.value*1
        + formulaire.sum2.value*1
        + formulaire.sum3.value*1;
    formulaire.sumtotal.value = tot.toFixed(1);
}
window.captureEvents(Event.KEYDOWN);
window.onkeydown = calc();
//-->
</script>

</head>
<body onLoad=\"calc();nbj()\">";

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
my $ptr;
my $fts = -1;
my ($id,$aa,$mm,$site,$d01,$v01,$d02,$v02,$d03,$v03,$d04,$v04,$d05,$v05,$d06,$v06,$d07,$v07,$d08,$v08,$d09,$v09,$d10,$v10,$d11,$v11,$d12,$v12,$d13,$v13,$d14,$v14,$d15,$v15,$d16,$v16,$d17,$v17,$d18,$v18,$d19,$v19,$d20,$v20,$d21,$v21,$d22,$v22,$d23,$v23,$d24,$v24,$d25,$v25,$d26,$v26,$d27,$v27,$d28,$v28,$d29,$v29,$d30,$v30,$d31,$v31,$val);
$id=$aa=$mm=$site=$d01=$v01=$d02=$v02=$d03=$v03=$d04=$v04=$d05=$v05=$d06=$v06=$d07=$v07=$d08=$v08=$d09=$v09=$d10=$v10=$d11=$v11=$d12=$v12=$d13=$v13=$d14=$v14=$d15=$v15=$d16=$v16=$d17=$v17=$d18=$v18=$d19=$v19=$d20=$v20=$d21=$v21=$d22=$v22=$d23=$v23=$d24=$v24=$d25=$v25=$d26=$v26=$d27=$v27=$d28=$v28=$d29=$v29=$d30=$v30=$d31=$v31=$val;
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) == 1) {
        chomp(@ligne);
        ($id,$aa,$mm,$site,$d01,$v01,$d02,$v02,$d03,$v03,$d04,$v04,$d05,$v05,$d06,$v06,$d07,$v07,$d08,$v08,$d09,$v09,$d10,$v10,$d11,$v11,$d12,$v12,$d13,$v13,$d14,$v14,$d15,$v15,$d16,$v16,$d17,$v17,$d18,$v18,$d19,$v19,$d20,$v20,$d21,$v21,$d22,$v22,$d23,$v23,$d24,$v24,$d25,$v25,$d26,$v26,$d27,$v27,$d28,$v28,$d29,$v29,$d30,$v30,$d31,$v31,$val) = split(/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            $sel_annee = $aa;
            $sel_mois = $mm;
            $sel_site = $site;
            for (@jourListe) {
                eval("\$sel_d$_ = \$d$_;");
                eval("\$sel_v$_ = \$v$_;");
            }
            $message = "Modification donn&eacute;e n° $QryParm->{id}";
        } else { $QryParm->{id} = ""; $val = ""; }
    } else { $QryParm->{id} = ""; $val = "" ;}
}

print "<TABLE><TR><TD style=\"border:0\">
<H1>$titrePage</H1>\n<H2>$message</H2>
</TD><TD style=\"border:0;text-align:right;vertical-align:top\">";
print "</TD></TR></TABLE>";

print "<FORM name=formulaire id=\"theform\" action=\"\">";
if ($QryParm->{id} ne "") {
    print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\">";
}

print "<input type=\"hidden\" name=\"oper\" value=\"$CLIENT\">\n";

print "<TABLE style=border:0 onMouseOver=\"calc()\">
    <TR><TD style=border:0 valign=top>
    <fieldset><legend>Mois et Site</legend>
    <P class=parform>
    <B>Ann&eacute;e:</B> <select name=annee size=\"1\">";
for (@anneeListe) {
    $sel = "";
    if ($_ == $sel_annee) { $sel = "selected"; }
    print "<option $sel value=\"$_\">$_</option>\n";
}
print "</select>";
print " <B>Mois:</B> <select name=mois size=\"1\">";
for (@moisListe) {
    $sel = "";
    if ($_ == $sel_mois) { $sel = "selected"; }
    print "<option $sel onClick=\"nbj()\" value=\"$_\">".$nomMois[$_ - 1]."</option>\n";
}
print "</select>\n";
print "&nbsp;&nbsp;
        <B>Site:</B> <select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le site')\" name=\"site\" size=\"1\"><option value=\"\"></option>\n";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    $sel = "";
    if ($cle[0] eq $sel_site) { $sel = "selected"; }
    print "<option $sel value=$cle[0]>$cle[1]</option>\n";
}
print "</select>";
print "</fieldset>";
print "</TD></TR>\n";

print "<TR><TD style=border:0>
    <fieldset><legend>Pluviom&eacute;trie journali&egrave;re (mm)</legend>\n";
print "<table>";
print "<TR>";
print "<TD style=\"border:0; padding-right: 30px; \" valign=top>";
for (@jourListe) {
    print "<B>$_.</B> <input size=5 class=inputNum name=\"d$_\" tabindex=1 value=\"".eval("\$sel_d$_")."\"
            onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de pluie du $_')\">";
    print "&nbsp;<select onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner le type de donn&eacute;e')\" name=\"v$_\" size=\"1\">";
    my $v = "";
    $v = eval("\$sel_v$_");
    for (@types) {
        my @cle = split(/\|/,$_);
        $sel = "";
        if ($cle[0] eq $v) {    $sel = "selected"; }
        print "<option $sel value=$cle[0]>$cle[1]</option>";
    }
    print "</select><BR>";
    if (($_ eq "10") || ($_ eq "20")) { print "</TD><TD style=border:0 valign=top>"; }
}
print "</TD></TR>\n";
print "<TR><TD style=\"border:0; padding-right: 30px; \"><B>Cumul 1<sup>&egrave;re</sup> d&eacute;cade</B> <input name=\"sum1\" size=5 readOnly class=inputNumNoEdit></TD>
        <TD style=\"border:0; padding-right: 30px; \"><B>Cumul 2<sup>ème</sup> décade</B> <input name=\"sum2\" size=5 readOnly class=inputNumNoEdit></TD>
        <TD style=\"border:0; padding-right: 30px; \"><B>Cumul 3<sup>ème</sup> décade</B> <input name=\"sum3\" size=5 readOnly class=inputNumNoEdit></TD>
        </TR>\n";
print "<TR><TD style=border:0><B>Cumul mensuel</B> (mm) = <input name=\"sumtotal\" size=5 readOnly class=inputNumNoEdit></P></TD></TR>\n";
print "</table>";
print "</fieldset>";
print "</TD></TR>";

print "<TR><TD style=border:0 colspan=2><P class=parform><B>Information de saisie:</B> $val
<INPUT type=hidden name=val value=\"$val\"></P></TD></TR>";

print "<TR><TD style=border:0 colspan=3>";
print "<P style=\"margin-top:20px;text-align:center\">";
print "<input style=\"margin-right: 30px\" type=button value=\"Compléter de zéros\" onClick=\"zeros()\">";
print "<input type=\"button\" name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_SHOW')."'\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\">";
print "</P></FORM>";
print "</TD></TR></TABLE>";

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

