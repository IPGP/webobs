#!/usr/bin/perl

=head1 NAME

showPLUVIO.pl 

=head1 SYNOPSIS

http://..../showPLUVIO.pl? ... see query string parameters ...

=head1 DESCRIPTION

'PLUVIO' est une FORM WebObs.

Ce script permet l'affichage des données pluviomètres
de l'OVSG, par une page HTML contenant un formulaire
pour la selection de paramètres d'affichage, et la possibilité de créer, d'éditer ou d' effacer
une ligne de données.

=head1 Configuration PLUVIO 

Exemple d'un fichier 'PLUVIO.conf':

  =key|value
  CGI_SHOW|showPLUVIO.pl
  CGI_FORM|formPLUVIO.pl
  CGI_POST|postPLUVIO.pl
  BANG|1964
  FILE_NAME|PLUVIO.DAT
  TITLE|Banque de donn&eacute;es de pluviom&egrave;tres
  FILE_TYPE|typeValiditePluvio.conf
  FILE_CSV_PREFIX|OVSG_PLUVIO

=head1 Query string parameters

La Query string fournit les sélections d'affichage. Elle est optionnelle, 
des sélections par défaut étant définies dans le script lui-meme: c'est le cas au 
premier appel, avant que l'utilisateur n'ait a sa disposition le formulaire de 
selection d'affichage.

=over

=item B<annee=> 

année à afficher. Défaut: l'année en cours

=item B<mois=> 

mois à afficher. Défaut: tous les mois de l'année 

=item B<site=>

site (node) à afficher. Si de la forme I<{nomProc}> , affichera tous les sites
(nodes) de la PROC 'nomProc'. Defaut: tous les nodes 

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

die "You can't view PLUVIO reports." if (!clientHasRead(type=>"authforms",name=>"PLUVIO"));
my $displayOnly = clientHasEdit(type=>"authforms",name=>"PLUVIO") ? 0 : 1;

my $FORM = new WebObs::Form('PLUVIO');
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

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $jour  = strftime('%d',@tod);
my $mois  = strftime('%m',@tod);
my $annee = strftime('%Y',@tod);
my $moisActuel = strftime('%Y-%m',@tod);
my $displayMoisActuel = strftime('%B %Y',@tod);
my $today = strftime('%F',@tod);

# ---- specific FORMS inits ----------------------------------
my @types    = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));

my @html;
my @csv;
my $affiche;
my $s;
my $i;
my @nomMois = ("janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre");

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$today.csv";

my $afficheMois;
my $afficheSite;
my $critereDate = "";
my $unite;

my @cleParamAnnee = ("Ancien|Ancien");
for ($FORM->conf('BANG')..$annee) {
    push(@cleParamAnnee,"$_|$_");
}
my @cleParamMois;
for ('01'..'12') {
    $s = l2u(qx(date -d "$annee-$_-01" +"%B")); chomp($s);
    push(@cleParamMois,"$_|$s");
}
my @cleParamSite;

my $titrePage = $FORM->conf('TITLE');

my @option = ();
my $msgFinal;

$QryParm->{'annee'}    ||= $annee;
$QryParm->{'mois'}     ||= "Tout";
$QryParm->{'site'}     ||= "Tout";
$QryParm->{'affiche'}  ||= "";

# ---- a site requested as {name} means "all nodes for grid (proc) 'name'"
# 
my @gridsites;
if ($QryParm->{'site'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridsites,"$_");
    }
}

# ----

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- start html if not CSV output 

if ($affiche ne "csv") {
    print $cgi->header(-charset=>'utf-8');
    print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
      "<html><head><title>$titrePage</title>\n",
      "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n";

    print "</head>\n",
      "<body style=\"background-attachment: fixed\">\n",
      "<div id=\"attente\">Recherche des donn&eacute;es, merci de patienter.</div>",
      "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
      "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n",
      "<!-- overLIB (c) Erik Bosrup -->\n";
}

# Debut du formulaire pour la selection de l'affichage
#  
if ($QryParm->{'affiche'} ne "csv") {
    print("<FORM name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">",
        "<P class=\"boitegrise\" align=\"center\">",
        "<B>S&eacute;lectionner: <select name=\"annee\" size=\"1\">\n");
    for ("Tout|Tout",reverse(@cleParamAnnee)) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'annee'}") { print("<option selected value=$val>$cle</option>\n"); }
        else { print("<option value=$val>$cle</option>\n"); }
    }
    print("</select>\n",
        "<select name=\"mois\" size=\"1\">");
    for ("Tout|Toute l'ann&eacute;e",@cleParamMois) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'mois'}") {
            print("<option selected value=$val>$cle</option>\n");
            $afficheMois = $cle;
        } else {
            print("<option value=$val>$cle</option>\n");
        }
    }
    print("</select>\n",
        "<select name=\"site\" size=\"1\">");
    for ("Tout|Tous les sites",@NODESSelList) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'site'}") {
            print("<option selected value=$val>$cle</option>\n");
            $afficheSite = "$cle ($val)";
        } else {
            print("<option value=$val>$cle</option>\n");
        }
    }
    print("</select>",
        " <input type=\"submit\" value=\"Afficher\">");
    if ($displayOnly ne 1) {
        print("<input type=\"button\" style=\"margin-left:15px;color:blue;\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"nouvel enregistrement\">");
    }
    print "</B></P></FORM>\n",
      "<H2>$titrePage</H2>\n",
      "<P>Intervalle s&eacute;lectionn&eacute;: <B>$afficheMois $QryParm->{'annee'}</B><BR>",
      "Sites s&eacute;lectionn&eacute;s: <B>$afficheSite</B><BR>";
}

# ---- Lecture du fichier de données dans tableau @lignes
my ($fptr, $fpts) = $FORM->data;
my @lignes = @$fptr;

my $nbData = @lignes - 1;

my $entete;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $txt;
my $fmt = "%0.4f";
my $aliasSite;

$entete = "<TR>";
if ($displayOnly ne 1) {
    $entete = $entete."<TH rowspan=2></TH>";
}
$entete = $entete."<TH rowspan=2>Année</TH>"
  ."<TH rowspan=2>Mois</TH>"
  ."<TH rowspan=2>Site</TH>"
  ."<TH colspan=31>Pluviométrie journalière (en mm)</TH>"
  ."<TH rowspan=2>Cumul<br>(mm)</TH>"
  ."</TR>\n<TR>";
for ("01".."31") {
    $entete = $entete."<TH>$_</TH>";
}
$entete = $entete."</TR>\n";

# Tableau de données
$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    my ($id,$aa,$mm,$site,$d01,$v01,$d02,$v02,$d03,$v03,$d04,$v04,$d05,$v05,$d06,$v06,$d07,$v07,$d08,$v08,$d09,$v09,$d10,$v10,$d11,$v11,$d12,$v12,$d13,$v13,$d14,$v14,$d15,$v15,$d16,$v16,$d17,$v17,$d18,$v18,$d19,$v19,$d20,$v20,$d21,$v21,$d22,$v22,$d23,$v23,$d24,$v24,$d25,$v25,$d26,$v26,$d27,$v27,$d28,$v28,$d29,$v29,$d30,$v30,$d31,$v31,$val) = split(/\|/,$_);
    my $sc = "";
    my $cm = 0;
    if ($i eq 0) {
        push(@csv,u2l("$aa;$mm;Code Site;$site;$d01;$d02;$d03;$d04;$d05;$d06;$d07;$d08;$d09;$d10;$d11;$d12;$d13;$d14;$d15;$d16;$d17;$d18;$d19;$d20;$d21;$d22;$d23;$d24;$d25;$d26;$d27;$d28;$d29;$d30;$d31;$val"));
    }
    elsif (($_ ne "")
        && (($QryParm->{'site'} eq "Tout") || ($site =~ $QryParm->{'site'}) || ($site ~~ @gridsites))
        && (($QryParm->{'annee'} eq "Tout") || ($QryParm->{'annee'} == $aa) || (($QryParm->{'annee'} eq "Ancien") && ($aa lt $FORM->conf('BANG'))))
        && (($QryParm->{'mois'} eq "Tout") || ($QryParm->{'mois'} == $mm))) {

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
        $texte = $texte."<TD align=center>$aa</TD>"
          ."<TD align=center>$nomMois[$mm-1]</TD>"
          ."<TD align=center>$lien</TD>";
        $txt = "$aa;$mm;$site;$aliasSite";
        for ("01".."31") {
            my $dd = eval("\$d$_");
            my $vv = eval("\$v$_");
            my $ss = "";
            $cm += $dd;
            if ($dd ne "") { $dd = sprintf("%0.1f",$dd); }
            if ($vv == 2) {
                $ss = "style=\"background-color:#FFAAAA\" onMouseOut=\"nd()\" onMouseOver=\"overlib('Donnée douteuse')\"";
            }
            if (($vv == 3) || ($sc ne "")) {
                if ($sc eq "") { $sc = "Cumul depuis le $_ $nomMois[$mm-1] $aa"; };
                $ss = "style=\"background-color:#AAAAFF\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$sc')\"";
            }
            if ($vv == 4) {
                $ss = "";
                $sc = "";
            }
            $texte = $texte."<TD align=right $ss>$dd</TD>";
            $txt = $txt.";".eval("\$d$_");
        }
        $texte = $texte."<TD class=tdResult>$cm</TD></TR>\n";
        $txt = $txt."\n";
        push(@csv,$txt);

        $nbLignesRetenues++;
    }
    $i++;
}

push(@html,"Nombre de donn&eacute;es affich&eacute;es = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>T&eacute;l&eacute;charger un fichier Excel de ces donn&eacute;es: <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&annee=$QryParm->{'annee'}&mois=$QryParm->{'mois'}&site=$QryParm->{'site'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>\n");
}

# Time to display (or download csv)
# 
if ($QryParm->{'affiche'} eq "csv") {
    print @csv;
} else {
    print @html;
    print "<style type=\"text/css\">
        #attente { display: none; }
    </style>\n
    <BR>\n</BODY>\n</HTML>\n";
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

