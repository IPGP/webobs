#!/usr/bin/perl
#

=head1 NAME

showGAZ.pl 

=head1 SYNOPSIS

http://..../showGAZ.pl?.... see 'query string parameters' ...

=head1 DESCRIPTION

'GAZ' est une FORM WebObs.

Ce script permet l'affichage des données d'analyse des
gaz de l'OVSG, par une page HTML contenant un formulaire
pour la selection de paramètres d'affichage, et la possibilité de créer, d'éditer ou d'effacer
une ligne de données.

=head1 Configuration GAZ 

Exemple d'un fichier 'GAZ.conf':

  =key|value
  
  CGI_SHOW|showGAZ.pl
  CGI_FORM|formGAZ.pl
  CGI_POST|postGAZ.pl
  BANG|1811
  FILE_NAME|GAZ.DAT
  TITLE|Banque de donn&eacute;es de chimie des gaz
  FILE_TYPE|typeAmpoulesGaz.conf
  FILE_DEBITS|typeDebitGaz.conf
  FILE_CSV_PREFIX|OVSG_GAZ

=head1 Query string parameters

La Query string fournit les sélections d'affichage. Elle est optionnelle, 
des sélections par défaut étant définies dans le script lui-meme: c'est le cas au 
premier appel, avant que l'utilisateur n'ait a sa disposition le formulaire de 
selection d'affichage.

=over 

=item B<date selection> 

y1= , m1= , d1=
 start date (year,month,day)

 y2= , m2= , d2=
  end date (year, month, day)

=item B<annee=>

OBSOLETE: année à afficher. Défaut: l'année en cours

=item B<mois=>

OBSOLETE: mois à afficher. Defaut: tous les mois de l'année 

=item B<site=>

site (node) à afficher. Si de la forme I<{nomProc}> , affichera tous les sites
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

my $form = "GAZ";

die "You can't view $form reports." if (!clientHasRead(type=>"authforms",name=>"$form"));
my $clientAuth = clientHasEdit(type=>"authforms",name=>"$form") ? 2 : 0;
$clientAuth = clientHasAdm(type=>"authforms",name=>"$form") ? 4 : $clientAuth;

my $FORM = new WebObs::Form($form);
my %Ns;
my @NODESSelList;
my @NODESValidList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
    push(@NODESSelList,"\{$p\}|-- {PROC.$p} $Ps{$p} --");
    my %N = $FORM->nodes($p);
    for my $n (keys(%N)) {
        push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
        push(@NODESValidList,"$n");
    }
    %Ns = (%Ns, %N);
}

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $day  = strftime('%d',@tod);
my $month  = strftime('%m',@tod);
my $year = strftime('%Y',@tod);
my $endDate = strftime('%F',@tod);
my $delay = $FORM->conf('DEFAULT_DAYS') // 30;
my $startDate = qx(date -d "$delay days ago" +%F);
chomp($startDate);
my ($y1,$m1,$d1) = split(/-/,$startDate);

# ---- specific FORMS inits ----------------------------------
my %types    = readCfg($FORM->path."/".$FORM->conf('FILE_TYPE'));
my %debits   = readCfg($FORM->path."/".$FORM->conf('FILE_DEBITS'));

my @html;
my @csv;
my $affiche;
my $s = "";
my $i = 0;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$endDate.csv";

my $afficheMois;
my $afficheSite;
my $critereDate = "";

my @cleParamAnnee = ("Ancien|Ancien");

for ($FORM->conf('BANG')..$year) {
    push(@cleParamAnnee,"$_|$_");
}
my @cleParamMois;
for ('01'..'12') {
    $s = l2u(qx(date -d "$year-$_-01" +"%B")); chomp($s);
    push(@cleParamMois,"$_|$s");
}
my @cleParamSite;

my $titrePage = $FORM->conf('TITLE');

my @option = ();
my @rap;
my $nbRap = 0;
my @rapCalc;

$QryParm->{'y1'}       //= $y1;
$QryParm->{'m1'}       //= $m1;
$QryParm->{'d1'}       //= $d1;
$QryParm->{'y2'}       //= $year;
$QryParm->{'m2'}       //= $month;
$QryParm->{'d2'}       //= $day;
$QryParm->{'node'}     //= "All";
$QryParm->{'radon'}    //= "";
$QryParm->{'isotopes'} //= "";
$QryParm->{'affiche'}  //= "";
$QryParm->{'ampoule'}  //= "";

$startDate = "$QryParm->{'y1'}-$QryParm->{'m1'}-$QryParm->{'d1'}";
$endDate = "$QryParm->{'y2'}-$QryParm->{'m2'}-$QryParm->{'d2'}";

# ---- a site requested as {name} means "all nodes for grid (proc) 'name'"
# 
my @gridsites;
if ($QryParm->{'node'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridsites,"$_");
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
    print "<FORM name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">",
      "<P class=\"boitegrise\" align=\"center\">",
      "<B>$__{'Start Date'}:</B> ";
    print "<SELECT name=\"y1\" size=\"1\">\n";
    for ($FORM->conf('BANG')..$year) { print "<OPTION value=\"$_\"".($QryParm->{'y1'} eq $_ ? " selected":"").">$_</OPTION>\n" }
    print "</SELECT>\n";
    print "<SELECT name=\"m1\" size=\"1\">\n";
    for ("01".."12") { print "<OPTION value=\"$_\"".($QryParm->{'m1'} eq $_ ? " selected":"").">$_</OPTION>\n" }
    print "</SELECT>\n";
    print "<SELECT name=\"d1\" size=\"1\">\n";
    for ("01".."31") { print "<OPTION value=\"$_\"".($QryParm->{'d1'} eq $_ ? " selected":"").">$_</OPTION>\n" }
    print "</SELECT>\n";
    print "&nbsp;&nbsp;<B>$__{'End Date'}:</B> ";
    print "<SELECT name=\"y2\" size=\"1\">\n";
    for ($FORM->conf('BANG')..$year) { print "<OPTION value=\"$_\"".($QryParm->{'y2'} eq $_ ? " selected":"").">$_</OPTION>\n" }
    print "</SELECT>\n";
    print "<SELECT name=\"m2\" size=\"1\">\n";
    for ("01".."12") { print "<OPTION value=\"$_\"".($QryParm->{'m2'} eq $_ ? " selected":"").">$_</OPTION>\n" }
    print "</SELECT>\n";
    print "<SELECT name=\"d2\" size=\"1\">\n";
    for ("01".."31") { print "<OPTION value=\"$_\"".($QryParm->{'d2'} eq $_ ? " selected":"").">$_</OPTION>\n" }
    print "</SELECT>\n";
    print "&nbsp;&nbsp;<select name=\"node\" size=\"1\">";
    for ("All|All nodes",@NODESSelList) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'node'}") {
            print("<option selected value=$val>$cle</option>\n");
        } else {
            print("<option value=$val>$cle</option>\n");
        }
    }
    print "</select>\n",
      " <INPUT type=\"button\" value=\"$__{'Reset'}\" onClick=\"reset()\">",
      " <INPUT type=\"submit\" value=\"$__{'Display'}\">";
    if ($clientAuth > 1) {
        print "<input type=\"button\" style=\"margin-left:15px;color:blue;font-weight:bold\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"$__{'Enter a new record'}\">";
    }
    print("<BR>\n");
    print "Sampling type: <select name=\"ampoule\" size=\"1\">";
    for (("",keys(%types))) {
        print "<option "
          .("$_" eq "$QryParm->{'ampoule'}" ? " selected":"")
          ." value=$_>$types{$_}{name}</option>\n";
    }
    print("</select>&nbsp;&nbsp;");
    print("<input type=\"checkbox\" name=\"radon\" value=1".($QryParm->{'radon'} ne ""? " checked":"").">Rn&nbsp;&nbsp;");
    print("<input type=\"checkbox\" name=\"isotopes\" value=1".($QryParm->{'isotopes'} ne ""? " checked":"").">$__{'Isotopes'}&nbsp;&nbsp;");
    print "</B></P></FORM>\n",
      "<H2>".$FORM->conf('TITLE')."</H2>\n",
      "<P>";
}

# ---- Read the data file 

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
if ($clientAuth > 1) {
    $entete = $entete."<TH rowspan=2></TH>";
}
$entete = $entete."<TH rowspan=2>Date</TH><TH rowspan=2>Site</TH>"
  ."<TH colspan=3>On-site measurements</TH><TH rowspan=2>Type</TH><TH colspan=10>Concentrations (%)</TH>"
  .($QryParm->{'radon'} ne "" ? "<TH rowspan=2>Rn<br>(cp/mn)</TH>":"")
  .($QryParm->{'isotopes'} ne "" ? "<TH colspan=2>Isotopes</TH>":"")
  ."<TH rowspan=2>S/C</TH><TH rowspan=2></TH></TR>\n"
  ."<TR><TH>T (°C)</TH><TH>pH</TH><TH>Flux</TH>"
  ."<TH>H<sub>2</sub></TH><TH>He</TH><TH>CO</TH><TH>CH<sub>4</sub></TH><TH>N<sub>2</sub></TH><TH>H<sub>2</sub>S</TH><TH>Ar</TH><TH>CO<sub>2</sub></TH><TH>SO<sub>2</sub></TH><TH>O<sub>2</sub></TH>"
  .($QryParm->{'isotopes'} ne ""? "<TH>&delta;<sup>13</sup>C</TH><TH>&delta;<sup>18</sup>O</TH>":"");

$entete = $entete."</TR>\n";

$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    my ($id,$date,$heure,$site,$tFum,$pH,$debit,$Rn,$type,$H2,$He,$CO,$CH4,$N2,$H2S,$Ar,$CO2,$SO2,$O2,$d13C,$d18O,$rem,$val) = split(/\|/,$_);
    if ($i eq 0) {
        push(@csv,u2l("$date;$heure;Code Site;$site;$tFum;$pH;$debit;$type;$H2;$He;$CO;$CH4;$N2;$H2S;$Ar;$CO2;$SO2;$O2;$Rn;$d13C;$d18O;S/C;\"$rem\";$val"));
    }
    elsif (($_ ne "")
        && ($site =~ $QryParm->{'node'} || $site ~~ @gridsites || ($QryParm->{'node'} eq "All" && $site ~~ @NODESValidList))
        && ($QryParm->{'ampoule'} eq "" || $type eq $QryParm->{'ampoule'})
        && ($id > 0 || $clientAuth == 4)
        && ($date le $endDate) && ($date ge $startDate)) {

        my $S_C = "";
        if (($CO2 != 0) && ($type ne "NaOH")) {
            $S_C = sprintf("%1.2f",($SO2 + $H2S)/$CO2);
        }

        $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

        my $normSite = normNode(node=>"PROC.$site");
        if ($normSite ne "") {
            $lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><B>$aliasSite</B></A>";
        } else { $lien = "$aliasSite"  }
        $modif = "<a href=\"/cgi-bin/".$FORM->conf('CGI_FORM')."?id=$id\"><img src=\"/icons/modif.png\" title=\"Editer...\" border=0></a>";
        $efface = "<img src=\"/icons/no.png\" title=\"Effacer...\" onclick=\"checkRemove($id)\">";

        $texte = $texte."<TR ".($id < 1 ? "class=\"node-disabled\"":"").">";
        if ($clientAuth > 1) {
            $texte = $texte."<TD nowrap>$modif</TD>";
        }
        $texte = $texte."<TD nowrap>$date $heure</TD><TD align=center>$lien</TD>"
          ."<TD align=center>$tFum</TD><TD align=center>$pH</TD><TD align=center>$debit</TD><TD align=center>$types{$type}{name}</TD>"
          ."<TD align=center>$H2</TD><TD align=center>$He</TD><TD align=center>$CO</TD><TD align=center>$CH4</TD>"
          ."<TD align=center>$N2</TD><TD align=center>$H2S</TD><TD align=center>$Ar</TD><TD align=center>$CO2</TD>"
          ."<TD align=center>$SO2</TD><TD align=center>$O2</TD>"
          .($QryParm->{'radon'} ne "" ? "<TD align=center>$Rn</TD>":"")
          .($QryParm->{'isotopes'} ne "" ? "<TD align=center>$d13C</TD><TD align=center>$d18O</TD>":"")
          ."<TD class=tdResult>$S_C</TD><TD>";
        $txt = "$date;$heure;$site;$aliasSite;$tFum;$pH;$debit;$H2;$He;$CO;$CH4;$N2;$H2S;$Ar;$CO2;$SO2;$O2;$Rn;$d13C;$d18O;$S_C";
        $txt = $txt."\"$rem\"\n";
        if ($rem ne "") {
            $rem =~ s/\'/&rsquo;/g;
            $rem =~ s/\"/&quot;/g;
            $rem = l2u($rem);
            $texte = $texte."<IMG src=\"/icons/attention.gif\" border=0 onMouseOut=\"nd()\" onMouseOver=\"overlib('$rem',CAPTION,'Observations $aliasSite')\">";
        }
        $texte = $texte."</TD></TR>\n";
        push(@csv,u2l($txt));

        $nbLignesRetenues++;
    }
    $i++;
}

push(@html,"Number of records = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>Download a CSV text file of these data <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&y1=$QryParm->{'y1'}&m1=$QryParm->{'m1'}&d1=$QryParm->{'d1'}&y2=$QryParm->{'y2'}&m2=$QryParm->{'m2'}&d2=$QryParm->{'d2'}&node=$QryParm->{'node'}&ampoule=$QryParm->{'ampoule'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>",
        "<P>Types d'Ampoules: ");
    for (keys(%types)) {
        push(@html,"<B>$types{$_}{name}</B> = $_, ");
    }
    push(@html,"\n<P>D&eacute;bits: ");
    for (keys(%debits)) {
        push(@html,"<B>$debits{$_}</B> = $_, ");
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

