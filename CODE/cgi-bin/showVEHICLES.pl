#!/usr/bin/perl
#

=head1 NAME

showVEHICLES.pl

=head1 SYNOPSIS

http://..../showVEHICLES.pl?.... see 'query string parameters' ...

=head1 DESCRIPTION

'VEHICLES' est une FORM WebObs.

Ce script permet l'affichage des données es journaux de bord des vehicules
par une page HTML contenant un formulaire pour la selection de paramètres d'affichage,
et la possibilité de créer, d'éditer ou d'effacer une ligne de données.

=head1 Configuration VEHICLES 

Exemple d'un fichier 'VEHICLES.conf':

  =key|value
  CGI_SHOW|showVEHICLES.pl
  CGI_FORM|formVEHICLES.pl
  CGI_POST|postVEHICLES.pl
  
  BANG|2000
  FILE_NAME|VEHICLES.DAT
  TITLE|Databank of vehicles mileage
  FILE_TYPE|typeDeplacement.conf
  
  FILE_CSV_PREFIX|OVPF_VEHICLES
  DEFAULT_DAYS|365

=head1 Query string parameters

La Query string fournit les sélections d'affichage. Elle est optionnelle, 
des sélections par défaut étant définies dans le script lui-meme: c'est le cas au 
premier appel, avant que l'utilisateur n'ait a sa disposition le formulaire de 
selection d'affichage.

=over 

=item B<annee=>

année à afficher. Défaut: l'année en cours

=item B<mois=>

mois à afficher. Defaut: tous les mois de l'année 

=item B<vehicle=>

Vehicle (node) à afficher. Si de la forme I<{nomProc}> , affichera tous les vehicles
(nodes) de la PROC 'nomProc'. Defaut: tous les nodes 

=item B<affiche=>

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

die "You can't view VEHICLES reports." if (!clientHasRead(type=>"authforms",name=>"VEHICLES"));
my $editOK = (clientHasEdit(type=>"authforms",name=>"VEHICLES")) ? 1 : 0;

my $FORM = new WebObs::Form('VEHICLES');
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
my $s = "";
my $i = 0;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$today.csv";

my $afficheMois;
my $afficheVehicle;
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
my @cleParamVehicle;

my $titrePage = $FORM->conf('TITLE');

my @option = ();

$QryParm->{'annee'}    ||= $annee;
$QryParm->{'mois'}     ||= "Tout";
$QryParm->{'vehicle'}  ||= "Tout";
$QryParm->{'affiche'}  ||= "";

# ---- a vehicle requested as {name} means "all nodes for grid (proc) 'name'"
# 
my @gridvehicles;
if ($QryParm->{'vehicle'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridvehicles,"$_");
    }
}

# ----

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- start html if not CSV output 

if ($QryParm->{'affiche'} ne "csv") {
    print $cgi->header(-charset=>'utf-8');
    print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
      "<html><head><title>$titrePage</title>\n",
      "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n";

    print "</head>\n",
      "<body style=\"background-attachment: fixed\">\n",
      "<div id=\"attente\">Recherche des données, merci de patienter.</div>",
      "<!--DEBUT DU CODE ROLLOVER 2-->\n",
      "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
      "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n",
      "<!-- overLIB (c) Erik Bosrup -->\n",
      "<!--FIN DU CODE ROLLOVER 2-->\n";
}

# ---- selection-form for display 
# 
if ($QryParm->{'affiche'} ne "csv") {
    print("<FORM name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">",
        "<P class=\"boitegrise\" align=\"center\">",
        "<B>Sélectionner: <select name=\"annee\" size=\"1\">\n");
    for ("Tout|Tout",reverse(@cleParamAnnee)) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'annee'}") { print("<option selected value=$val>$cle</option>\n"); }
        else { print("<option value=$val>$cle</option>\n"); }
    }
    print("</select>\n",
        "<select name=\"mois\" size=\"1\">");
    for ("Tout|Toute l'année",@cleParamMois) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'mois'}") {
            print("<option selected value=$val>$cle</option>\n");
            $afficheMois = $cle;
        } else {
            print("<option value=$val>$cle</option>\n");
        }
    }
    print("</select>\n",
        "<select name=\"vehicle\" size=\"1\">");
    for ("Tout|Tous les vehicules",@NODESSelList) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'vehicle'}") {
            print("<option selected value=$val>$cle</option>\n");
            $afficheVehicle = "$cle ($val)";
        } else {
            print("<option value=$val>$cle</option>\n");
        }
    }
    print("</select>",
        " <input type=\"submit\" value=\"Afficher\">");
    if ($editOK) {
        print("<input type=\"button\" style=\"margin-left:15px;color:blue;\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"nouvel enregistrement\">");
    }
    print "</B></P></FORM>\n",
      "<H2>$titrePage</H2>\n",
      "<P>Intervalle s&eacute;lectionn&eacute;: <B>$afficheMois $QryParm->{'annee'}</B><BR>",
      "Vehicule s&eacute;lectionn&eacute;s: <B>$afficheVehicle</B><BR>";
}

# ---- Lecture du fichier de données (dans tableau @lignes)

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
my $aliasVehicle;

$entete = "<TR>";
if ($editOK) {
    $entete = $entete."<TH></TH>";
}
$entete = $entete."<TH>Date</TH><TH>Vehicule</TH><TH>Kilom&egrave;trage</TH><TH>Type de d&eacute;placement</TH><TH>Lieux</TH><TH>Conducteur</TH><TH>Plein?</TH>";

$entete = $entete."</TR>\n";

$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    my ($id,$date,$heure,$vehicle,$mileage,$type,$site,$driver,$oil) = split(/\|/,$_);
    if ($i eq 0) {
        push(@csv,u2l("$date;$heure;Code Vehicle;$vehicle;$mileage;$type;$site;$driver;$oil"));
    }
    elsif (($_ ne "")
        && (($QryParm->{'vehicle'} eq "Tout") || ($vehicle =~ $QryParm->{'vehicle'}) || ($vehicle ~~ @gridvehicles))
        && (($QryParm->{'annee'} eq "Tout") || ($QryParm->{'annee'} eq substr($date,0,4)) || (($QryParm->{'annee'} eq "Ancien") && ($date lt $FORM->conf('BANG'))))
        && (($QryParm->{'mois'} eq "Tout") || ($QryParm->{'mois'} eq substr($date,5,2)))) {

        $aliasVehicle = $Ns{$vehicle}{ALIAS} ? $Ns{$vehicle}{ALIAS} : $vehicle;

        my $normVehicle = normNode(node=>"PROC.$vehicle");
        if ($normVehicle ne "") {
            $lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normVehicle\"><B>$aliasVehicle</B></A>";
        } else { $lien = "$aliasVehicle"  }
        $modif = "<a href=\"/cgi-bin/".$FORM->conf('CGI_FORM')."?id=$id\"><img src=\"/icons/modif.png\" title=\"Editer...\" border=0></a>";
        $efface = "<img src=\"/icons/no.png\" title=\"Effacer...\" onclick=\"checkRemove($id)\">";

        $texte = $texte."<TR>";
        if ($editOK) {
            $texte = $texte."<TD>$modif</TD>";
        }
        $texte = $texte."<TD>$date $heure</TD><TD align=center>$lien</TD>"
          ."<TD align=center>$mileage</TD><TD align=center>$type</TD><TD align=center>$site</TD><TD align=center>$driver</TD>"
          ."<TD align=center>$oil</TD></TR>";
        $txt = "$date;$heure;$vehicle;$aliasVehicle;$mileage;$type;$site;$driver;$oil\n";
        push(@csv,u2l($txt));

        $nbLignesRetenues++;
    }
    $i++;
}

push(@html,"Nombre de donn&eacute;es affich&eacute;es = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>T&eacute;l&eacute;charger un fichier Excel de ces donn&eacute;es: <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&annee=$QryParm->{'annee'}&mois=$QryParm->{'mois'}&vehicle=$QryParm->{'vehicle'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>",
        "<P>Types de deplacements: ");
    for (@types) {
        my ($tpi,$tpn) = split(/\|/,$_);
        push(@html,"<B>$tpi</B> = $tpn, ");
    }
    push(@html,"</P>\n");
}

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

