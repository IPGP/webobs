#!/usr/bin/perl
#

=head1 NAME

formVEHICLES.pl 

=head1 SYNOPSIS

http://..../formVEHICLES?[id=]

=head1 DESCRIPTION

Ce script permet l'affichage du formulaire d'édition d'un enregistrement des donnéeses journaux de bord
des vehicules de l'OVPF
 
=head1 Configuration VEHICLES 

Voir 'showVEHICLES.pl' pour un exemple de fichier de configuration 'VEHICLES.conf'

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

die "You can't edit VEHICLES reports." if (!clientHasEdit(type=>"authforms",name=>"VEHICLES"));

my $FORM = new WebObs::Form('VEHICLES');
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

my @types    = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));

$ENV{LANG} = $WEBOBS{LOCALE};

# ----
my $sel_type = "PRO";
my ($sel_vehicle,$sel_mileage,$sel_site,$sel_driver,$sel_oil);
$sel_vehicle = $sel_mileage = $sel_site = $sel_driver = $sel_oil = "";

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
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n</head>\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\">
<!--

function verif_formulaire()
{
    if(document.formulaire.site.value == \"\") {
        alert(\"Veuillez spécifier le site de prélèvement!\");
        document.formulaire.site.focus();
        return false;
    }
    if(document.formulaire.type.value == \"\") {
        alert(\"Veuillez entrer un type d'ampoule!\");
        document.formulaire.type.focus();
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
}
window.captureEvents(Event.KEYDOWN);
window.onkeydown = nicb();
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
my ($id,$date,$heure,$vehicle,$mileage,$type,$site,$driver,$oil) = split(/\|/,$_);
if (defined($QryParm->{id})) {
    ($ptr, $fts) = $FORM->data($QryParm->{id});
    @ligne = @$ptr;
    if (scalar(@ligne) == 1) {
        chomp(@ligne);
        ($id,$date,$heure,$vehicle,$mileage,$type,$site,$driver,$oil) =  split (/\|/,l2u($ligne[0]));
        if ($QryParm->{id} eq $id) {
            ($sel_annee,$sel_mois,$sel_jour) = split (/-/,$date);
            ($sel_hr,$sel_mn) = split (/:/,$heure);
            $sel_vehicle = $vehicle;
            $sel_mileage = $mileage;
            $sel_type = $type;
            $sel_site = $site;
            $sel_driver = $driver;
            $sel_oil = $oil;
            $message = "Modification donn&eacute;e n° $QryParm->{id}";
        } else { $QryParm->{id} = ""; }
    } else { $QryParm->{id} = ""; }
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
print "<TR>";
print "<TD style=border:0 valign=top>
    <fieldset><legend>Date et lieu du d&eacute;placement</legend>
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

print "<B>V&eacute;hicule: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('Selectionner le vehicule')\" name=\"vehicle\" size=\"1\"><option value=\"\"></option>";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    if ($cle[0] eq $sel_site) {
        print "<option selected value=$cle[0]>$cle[1]</option>";
    } else {
        print "<option value=$cle[0]>$cle[1]</option>";
    }
}
print "</select><BR>\n";

print "<B>Lieu: </B><input size=30 name=\"site\" value=\"$sel_site\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer le lieu du d&eacute;placement')\"><BR>\n";
print "</P>";
print "</fieldset>";

print "<fieldset><legend>Informations sur le d&eacute;placement</legend>\n
        <P class=parform>";
print "<B>Type de d&eacute;placement: </B><select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le type e d&eacute;placement')\" name=\"type\" size=\"1\"><option value=\"\"></option>";
for (@types) {
    my @cle = split(/\|/,$_);
    print "<option";
    if ($cle[0] eq $sel_type) {
        print " selected";
    }
    print " value=$cle[0]>$cle[1]</option>";
}
print "</select><BR/>";
print " <B>Conducteur: <input size=30 name=\"driver\" value=\"$driver\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer le nom du conducteur')\"><BR>\n
        <B>Kilom&egrave;tre au compteur</B> = <input size=10 class=inputNum name=\"mileage\" value=\"$mileage\" onKeyUp=\"nicb()\" onChange=\"nicb()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur du compteur')\"> km<BR>\n
        <B>Carburant</B> = <input size=5 class=inputNum name=\"oil\" value=\"$oil\" onKeyUp=\"nicb()\" onChange=\"nicb()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur du plein')\">&euro;<BR>\n";

#        print "<B>Débit </B> (qualitatif) = <select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner le débit')\" name=\"debit\" size=\"1\"><option value=\"\"></option>";
#        print "</select>\n";
print "</fieldset>";
print "</TD>";

#print "<TR>";
#print "<TD style=border:0 colspan=2>";
#    print "<B>Observations</B> : <BR><input size=80 name=rem value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter la phénoménologie (dépôts, couleur, etc...)')\"><BR>";
#    if ($val ne "") {
#        print "<BR><B>Information de saisie:</B> $val
#        <INPUT type=hidden name=val value=\"$val\"></P>";
#    }
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

Francois Beauducel, Didier Lafon, Patrice Boissier

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

