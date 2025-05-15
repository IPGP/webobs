#!/usr/bin/perl

=head1 NAME

showBOJAP.pl 

=head1 SYNOPSIS

http://..../showBOJAP.pl? ... voir 'query string parameters' ...

=head1 DESCRIPTION

'BOJAP' est une FORM WebObs.

Ce script permet l'affichage des données des boites japonaise
de l'OVSG, par une page HTML contenant un formulaire de selection d'affichage, et 
la possibilité de créer, éditer et effacer un eneregistrement.

=head1 Configuration BOJAP 

Exemple d'un fichier 'BOJAP.conf':

  =key|value

  CGI_SHOW|showBOJAP.pl
  CGI_FORM|formBOJAP.pl
  CGI_POST|postBOJAP.pl
  BANG|1999
  FILE_NAME|BOJAP.DAT
  TITLE|Banque de donn&eacute;es bo&icirc;tes japonaises
  FILE_RAPPORTS|rapportsBojap.conf
  KOH_N|4
  H2O_ML|500
  FILE_CSV_PREFIX|OVSG_BOJAP

=head1 Query string parameters

La Query string fournit les sélections d'affichage. Elle est optionnelle, 
des sélections par défaut étant définies dans le script lui-meme: c'est le cas au 
premier appel, avant que l'utilisateur n'ait a sa disposition le formulaire de 
selection d'affichage.

=over

=item B<annee=>

année à afficher. Defaut: l' année en cours

=item B<mois=>

mois à afficher. Defaut: tous les mois de l'année

=item B<site=>

site (node) à afficher. Si de la forme I<{nomProc}> , affichera tous les sites
(nodes) de la PROC 'nomProc'. Defaut: tous les nodes

=item B<affiche=>

=item B<unite=>

{ ppm | mmol } . Defaut: ppm

=item B<rap[N]>

selectionne le(s) rapport(s) rap[N] (rap1, rap2, ...) tels que définis dans le fichier de
configuration FILE_TYPE (voir BOJAP.conf)

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
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- standard FORMS inits ----------------------------------

die "You can't view BOJAP reports." if (!clientHasRead(type=>"authforms",name=>"BOJAP"));
my $displayOnly = clientHasEdit(type=>"authforms",name=>"BOJAP") ? 0 : 1;

my $FORM = new WebObs::Form('BOJAP');
my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
    push(@NODESSelList,"\{$p\}|-- $Ps{$p} --");
    my %N = $FORM->nodes($p);
    for my $n (keys(%N)) {
        push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
    }
    %Ns = (%Ns, %N);
}

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $jour  = strftime('%d',@tod);
my $mois  = strftime('%m',@tod);
my $annee = strftime('%Y',@tod);
my $moisActuel = strftime('%Y-%m',@tod);
my $displayMoisActuel = strftime('%B %Y',@tod);
my $today = strftime('%F',@tod);

# ---- specific FORM inits -------------------------------------
#djl-tbd: my @types    = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));
my @rapports = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));

my @html;
my @csv;
my $s = "";
my $i = 0;

#D my %stationsBojap;
#D my @codesBojap;

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$today.csv";

my $afficheMois;
my $afficheSite;
my $critereDate = "";

my @cleParamAnnee = ("Ancien|Ancien");
for ($FORM->conf('BANG')..$annee) {
    push(@cleParamAnnee,"$_|$_");
}
my @cleParamMois;
for ('01'..'12') {
    $s = l2u(qx(date -d "$annee-$_-01" +"%B")); chomp($s);
    push(@cleParamMois,"$_|$s");
}
my @cleParamUnite = ("ppm|en ppm","mmol|en mmol/l");
my @cleParamSite;

my @option = ();
my @rap;
my $nbRap = 0;
my @rapCalc;

$QryParm->{'annee'}    ||= $annee;
$QryParm->{'mois'}     ||= "Tout";
$QryParm->{'site'}     ||= "Tout";
$QryParm->{'affiche'}  ||= "";
$QryParm->{'unite'}    ||= "ppm";

# ---- a site requested as {name} means "all nodes for proc 'name'"
#
my @gridsites;
if ($QryParm->{'site'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridsites,"$_");
    }
}

$i = 0;
for (@rapports) {
    $i++;
    my $rapn = "rap$i";

    #djl-was: if ($valParams =~ /$rapn/) { 
    if (defined($QryParm->{$rapn})) {
        $rap[$i] = 1;
        $nbRap++;
    } else { $rap[$i] = 0 }
}

# ---- Lecture du fichier data dans tableau @lignes
#
my ($fptr, $fpts) = $FORM->data;
my @lignes = @$fptr;
my $nbData = @lignes - 1;

# ----

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- html page setup
# 
push(@html,"Content-type: text/html\n\n",
    "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
    "<html><head><title>".$FORM->conf('TITLE')."</title>\n",
    "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
    "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n</head>\n",
    "<body style=\"background-attachment: fixed\">\n",
    "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
    "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n",
    "<!-- overLIB (c) Erik Bosrup -->\n");

# ---- Debut du formulaire pour la selection de l'affichage
# 
push(@html,"<FORM name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">",
    "<P class=\"boitegrise\" align=\"center\">",
    "<B>Sélectionner: <select name=\"annee\" size=\"1\">\n");
for ("Tout|Tout",reverse(@cleParamAnnee)) {
    my ($val,$cle)=split (/\|/,$_);
    if ("$val" eq "$QryParm->{'annee'}") { push(@html,"<option selected value=$val>$cle</option>\n"); }
    else { push(@html,"<option value=$val>$cle</option>\n"); }
}
push(@html,"</select>\n",
    "<select name=\"mois\" size=\"1\">");
for ("Tout|Toute l'année",@cleParamMois) {
    my ($val,$cle)=split (/\|/,$_);
    if ("$val" eq "$QryParm->{'mois'}") {
        push(@html,"<option selected value=$val>$cle</option>\n");
        $afficheMois = $cle;
    } else {
        push(@html,"<option value=$val>$cle</option>\n");
    }
}
push(@html,"</select>\n",
    "<select name=\"site\" size=\"1\">");
for ("Tout|Tous les sites",@NODESSelList) {
    my ($val,$cle)=split (/\|/,$_);
    if ("$val" eq "$QryParm->{'site'}") {
        push(@html,"<option selected value=$val>$cle</option>\n");
        $afficheSite = "$cle ($val)";
    } else {
        push(@html,"<option value=$val>$cle</option>\n");
    }
}
push(@html,"</select>\n",
    "<select name=\"unite\" size=\"1\">");
for (@cleParamUnite) {
    my ($val,$cle) = split (/\|/,$_);
    if ("$val" eq "$QryParm->{'unite'}") { push(@html,"<option selected value=$val>$cle</option>\n"); }
    else { push(@html,"<option value=$val>$cle</option>\n"); }
}
push(@html,"</select>",
    " <input type=\"submit\" value=\"Afficher\">");
if ($displayOnly ne 1) {
    push(@html,"<input type=\"button\" style=\"margin-left:15px;color:blue;\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"nouvel enregistrement\">");
}
push(@html,"<BR>\n<B>Rapports calculés:</B> ");
$i = 0;
for (@rapports) {
    my ($num,$den,$nhtm,$dhtm) = split(/\|/,$_);
    $i++;
    my $sel_rap = "";
    if ($rap[$i] == 1) { $sel_rap = "checked"; }
    push(@html,"<input type=\"checkbox\" name=\"rap$i\" $sel_rap>$nhtm/$dhtm&nbsp;&nbsp;");
}
push(@html,"</B></P></FORM>\n");
push(@html,"<H2>".$FORM->conf('TITLE')."</H2>");

my $entete;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $tcsv;
my $unite;
my $fmt = "%0.2f";
if ($QryParm->{'unite'} eq "ppm") {
    $unite = "ppm = mg/l";
} else {
    $unite = "mmol/l";
}
my $aliasSite;

$entete = "<TR>";
if ($displayOnly ne 1) {
    $entete = $entete."<TH rowspan=2></TH>";
}
$entete = $entete."<TH colspan=3>Période</TH><TH rowspan=2>Site</TH>"
  ."<TH colspan=2>Solution initiale</TH><TH colspan=5>Masse échantillon (g)</TH><TH colspan=3>Concentrations ($unite)</TH><TH colspan=".(4+$nbRap)."> Calculs</TH><TH rowspan=2></TH></TR>\n"
  ."<TR><TH>Du</TH><TH>Au</TH><TH>Nb<br>jours</TH><TH>H<sub>2</sub>0<br>(ml)</TH><TH>KOH<br>(mol/l)</TH><TH>M<sub>1</sub></TH><TH>M<sub>2</sub></TH><TH>M<sub>3</sub></TH><TH>M<sub>4</sub></TH><TH>Total</TH>"
  ."<TH>Cl<sup>-</sup></TH><TH>CO<sub>2</sub><sup>-</sup></TH><TH>SO<sub>4</sub><sup>--</sup></TH>"
  ."<TH>Flux Cl<br>(g/j)</TH><TH>Flux C<br>(g/j)</TH><TH>Flux S<br>(g/j)</TH><TH>Flux H<sub>2</sub>O<br>(g/j)</TH>";
$i = 0;
for (@rapports) {
    my ($num,$den,$nhtm,$dthm) = split(/\|/,$_);
    $i++;
    if ($rap[$i] == 1) {
        $entete = $entete."<TH><table align=center><tr><th style=\"border:0;border-bottom:solid 1px;text-align:center\">$nhtm</th><tr><tr><th style=\"border:0;text-align:center\">$dthm</th></tr></table></TH>";
    }
}

$entete = $entete."</TR>\n";

$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    my ($id,$date1,$hr1,$date2,$hr2,$site,$cCl,$cCO2,$cSO4,$m1,$m2,$m3,$m4,$h2o,$koh,$rem,$val) = split(/\|/,$_);
    if ($hr1 ne "") { $date1 = "$date1 $hr1"; }
    if ($hr2 ne "") { $date2 = "$date2 $hr2"; }
    if ($i eq 0) {
        push(@csv,u2l("$date1;$date2;Nb jours;Code Site;$site;$h2o;$koh;Masse;$cCl;$cCO2;$cSO4;\"$rem\";$val"));
    }
    elsif (($id ne "")
        && (($QryParm->{'site'} eq "Tout") || ($site =~ $QryParm->{'site'}) || ($site ~~ @gridsites))
        && (($QryParm->{'annee'} eq "Tout") || ($QryParm->{'annee'} eq substr($date1,0,4)) || (($QryParm->{'annee'} eq "Ancien") && ($date1 lt $FORM->conf('BANG'))))
        && (($QryParm->{'mois'} eq "Tout") || ($QryParm->{'mois'} eq substr($date1,5,2)))) {

        my ($cCl_mmol,$cCO2_mmol,$cSO4_mmol) = split(/\|/,"");
        if ($cCl ne "") { $cCl_mmol = sprintf($fmt,$cCl/$GMOL{Cl}); };
        if ($cCO2 ne "") { $cCO2_mmol = sprintf($fmt,$cCO2/$GMOL{CO2}); };
        if ($cSO4 ne "") { $cSO4_mmol = sprintf($fmt,$cSO4/$GMOL{SO4}); };

        my $mtot;
        if ($m1 ne "") { $mtot = sprintf("%1.2f",$m1 + $m2 + $m3 + $m4); }

        my $nj = (qx(date -d "$date2" +%s) - qx(date -d "$date1" +%s))/86400;
        my $f_H2O;
        my $f_Cl;
        my $f_C;
        my $f_S;
        if (($nj != 0) && ($mtot > 0)) {
            $f_H2O = sprintf("%1.2f",($mtot - ($h2o + $GMOL{KOH}*$koh*$h2o/1000))/$nj);
            if ($cCl > 0) { $f_Cl = sprintf("%1.3f",$f_H2O/1e6*$cCl); }
            if ($cCO2 > 0) { $f_C = sprintf("%1.3f",$f_H2O/1e6*$cCO2*12/44); }
            if ($cSO4 > 0) { $f_S = sprintf("%1.3f",$f_H2O/1e6*$cSO4*32/96); }
        }
        my @rapv;
        my $iv = 0;
        my $rapport = "";

        for (@rapports) {
            my ($num,$den,$nrp) = split(/\|/,$_);
            $iv++;
            $rapv[$iv] = eval("sprintf(\"%1.3f\",\$c".$num."_mmol/\$c".$den."_mmol)");
            if ($rap[$iv] == 1) {
                $rapport = $rapport."<TD class=tdResult>$rapv[$iv]</TD>";
            }
        }

        $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

        my $normSite = normNode(node=>"PROC.$site");
        if ($normSite ne "") {
            $lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><B>$aliasSite</B></A>";
        } else { $lien = "$aliasSite"  }
        $modif = "<a href=\"/cgi-bin/".$FORM->conf('CGI_FORM')."?id=$id\"><img src=\"/icons/modif.png\" title=\"Editer...\" border=0></a>";
        $efface = "<img src=\"/icons/no.png\" title=\"Effacer...\" onclick=\"checkRemove($id)\">";

        $texte = $texte."<TR>";
        if ($displayOnly ne 1) {
            $texte = $texte."<TD nowrap>$modif</TD>";
        }
        $texte = $texte."<TD nowrap align=center>$date1</TD><TD nowrap align=center>$date2</TD><TD style=\"text-align:center\" class=tdResult>$nj</TD><TD align=center>$lien</TD><TD align=center>$h2o</TD><TD align=center>$koh</TD>"
          ."<TD align=center>$m1</TD><TD align=center>$m2</TD><TD align=center>$m3</TD><TD align=center>$m4</TD><TD align=center class=tdResult>$mtot</TD>";
        $tcsv = "$date1;$date2;$nj;$site;$aliasSite;$h2o;$koh;$mtot;";
        if ($QryParm->{'unite'} eq "mmol") {
            $texte = $texte."<TD align=center>$cCl_mmol</TD><TD align=center>$cCO2_mmol</TD><TD align=center>$cSO4_mmol</TD>";
            $tcsv = $tcsv."$cCl_mmol;$cCO2_mmol;$cSO4_mmol;";
        } else {
            $texte = $texte."<TD align=center>$cCl</TD><TD align=center>$cCO2</TD><TD align=center>$cSO4</TD>";
            $tcsv = $tcsv."$cCl;$cCO2;$cSO4;";
        }
        $texte = $texte."<TD class=tdResult>$f_Cl</TD><TD class=tdResult>$f_C</TD><TD class=tdResult>$f_S</TD><TD class=tdResult>$f_H2O</TD>$rapport<TD>";
        if ($rem ne "") {
            $rem =~ s/\'/&rsquo;/g;
            $rem =~ s/\"/&quot;/g;
            $texte = $texte."<IMG src=\"/icons/attention.gif\" border=0 onMouseOut=\"nd()\" onMouseOver=\"overlib('$rem',CAPTION,'Observations $aliasSite')\">";
        }
        $texte = $texte."</TD></TR>\n";
        $tcsv = $tcsv."\"$rem\"\n";
        push(@csv,u2l($tcsv));

        $nbLignesRetenues++;
    }
    $i++;
}

push(@html,"<P>Intervalle sélectionné: <B>$afficheMois $QryParm->{'annee'}</B><BR>",
    "Sites sélectionnés: <B>$afficheSite</B><BR>",
    "Unité des concentrations ioniques: <B>$unite</B><BR>",
    "Nombre de données affichées = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>Télécharger un fichier Excel de ces données: <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&annee=$QryParm->{'annee'}&mois=$QryParm->{'mois'}&site=$QryParm->{'site'}&unite=$QryParm->{'unite'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>");
}

# Time to display (or download csv)
# 
push(@html,"<BR>\n</BODY>\n</HTML>\n");
if ($QryParm->{'affiche'}  eq "csv") {
    print @csv;
} else {
    print @html;
}

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

