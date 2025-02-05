#!/usr/bin/perl

=head1 NAME

showDISTANCE.pl 

=head1 SYNOPSIS

http://..../showDISTANCE.pl?.... voir 'query string parameters' ...

=head1 DESCRIPTION

'DISTANCE' est une FORM WebObs.

Ce script permet l'affichage des données de
distancemétrie de l'OVSG, par une page HTML contenant un formulaire
pour la selection de paramètres d'affichage, et la possibilité de créer, d'éditer ou d'effacer
une ligne de données.

=head1 Configuration DISTANCE 

Exemple d'un fichier 'DISTANCE.conf':

  =key|value
  CGI_SHOW|showDISTANCE.pl
  CGI_FORM|formDISTANCE.pl
  CGI_POST|postDISTANCE.pl
  BANG|2000
  FILE_NAME|DISTANCE.DAT
  TITLE|Banque de donn&eacute;es de distancem&eacute;trie
  FILE_METEO|meteoDistance.conf
  FILE_TYPE|typeDistance.conf
  SHAKEMAPS_MIN_DISTANCE|5
  FILE_CSV_PREFIX|OVSG_DISTANCE

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

=item B<site=>

site (node) à afficher. Si de la forme I<{nomProc}> , affichera tous les sites
(nodes) de la PROC 'nomProc'. Defaut: tous les nodes de toutes les PROCs associées

=item B<affiche=>

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

die "You can't view DISTANCE reports." if (!clientHasRead(type=>"authforms",name=>"DISTANCE"));
my $editOK = clientHasEdit(type=>"authforms",name=>"DISTANCE");

my $FORM = new WebObs::Form('DISTANCE');
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
my @types   = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));
my @meteo   = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));

my @html;
my @csv;
my $s = '';
my $i = my $j = 0;

my @stations;
my %stationsRes;
my @cleRes;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$today.csv";

my $afficheMois;
my $afficheSite;
my $critereDate = "";
my $unite;

my @cleParamAnnee = ("Ancien|Ancien");
for ($FORM->conf('BANG')..$annee) { push(@cleParamAnnee,"$_|$_") }

my @cleParamMois;
for ('01'..'12') { $s = l2u(qx(date -d "$annee-$_-01" +"%B")); chomp($s); push(@cleParamMois,"$_|$s"); }

my @cleParamSite;

my @option = ();

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

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- start html if not csv output requested

if ($QryParm->{'affiche'} ne "csv") {
    print $cgi->header(-charset=>'utf-8');
    print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
      "<html><head><title>".$FORM->conf('TITLE')."</title>\n",
      "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n";

    print "</head>\n",
      "<body style=\"background-attachment: fixed\">\n",
      "<div id=\"attente\">Recherche des donn&eacute;es, merci de patienter.</div>",
      "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
      "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n",
      "<!-- overLIB (c) Erik Bosrup -->\n";
}

# ---- selection-form for display 
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
    if ($editOK) {
        print("<input type=\"button\" style=\"margin-left:15px;color:blue;\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"nouvel enregistrement\">");
    }
    print "</B></P></FORM>\n",
      "<H2>".$FORM->conf('TITLE')."</H2>\n",
      "<P>Intervalle s&eacute;lectionn&eacute;: <B>$afficheMois $QryParm->{'annee'}</B><BR>",
      "Sites s&eacute;lectionn&eacute;s: <B>$afficheSite</B><BR>";
}

# ---- Lecture du fichier data dans tableau @lignes

my ($fptr, $fpts) = $FORM->data;
my @lignes = @$fptr;
my $nbData = @lignes - 1;

my ($id,$date,$heure,$site,$aemd,$pAtm,$tAir,$HR,$nebul,$vitre,$d0,$rem,$val) = split(/\|/,"");
my @d;
my @v;
my @nd = (0..19);
my $entete;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $txt;
my $fmt = "%0.4f";
my $aliasSite;

$entete = "<TR>";
if ($editOK) {
    $entete = $entete."<TH rowspan=2></TH>";
}
$entete = $entete."<TH rowspan=2>Date</TH><TH rowspan=2>Site</TH>"
  ."<TH rowspan=2>AEMD</TH>"
  ."<TH colspan=5>Infos Tourelle</TH><TH colspan=21>Mesures de distance: D<sub>0</sub> (m) + d<sub>n</sub> (mm)</TH><TH colspan=2>Moyenne (m)</TH><TH rowspan=2></TH></TR>\n"
  ."<TR><TH>Patm<br>(mmHg)</TH><TH>Tair<br>(°C)</TH><TH>H.R.<br>(%)</TH><TH>N&eacute;bul</TH><TH>Vitre</TH><TH>D<sub>0</sub><br>(m)";
for ("01".."20") { $entete = $entete."<TH>d<sub>$_</sub></TH>" }
$entete = $entete."<TH><SPAN style=\"text-decoration:overline\"><I>x</I></SPAN></TH><TH>2&sigma;</TH></TR>\n";

$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    ($id,$date,$heure,$site,$aemd,$pAtm,$tAir,$HR,$nebul,$vitre,$d0,$d[0],$d[1],$d[2],$d[3],$d[4],$d[5],$d[6],$d[7],$d[8],$d[9],$d[10],$d[11],$d[12],$d[13],$d[14],$d[15],$d[16],$d[17],$d[18],$d[19],$rem,$val) = split(/\|/,$_);

    # trie les données pour mettre les champs vides à la fin...
    @d = sort { ($a eq "") <=> ($b eq "") } @d;
    my $DM = "";
    my $DS = "";
    my $n = 0;
    if ($i eq 0) {
        push(@csv,u2l("$date;$heure;Code Site;$site;$aemd;$pAtm;$tAir;$HR;$nebul;$vitre;Dist. Moy (m);2*Sigma (m);\"$rem\";$val"));
    }
    elsif (($_ ne "")
        && (($QryParm->{'site'}  eq "Tout") || ($site =~ $QryParm->{'site'}) || ($site ~~ @gridsites))
        && (($QryParm->{'annee'} eq "Tout") || ($QryParm->{'annee'} eq substr($date,0,4)) || (($QryParm->{'annee'} eq "Ancien") && ($date lt $FORM->conf('BANG'))))
        && (($QryParm->{'mois'}  eq "Tout") || ($QryParm->{'mois'} eq substr($date,5,2)))) {

        for $j(@nd) {
            if ($d[$j] ne "") {
                my $dd = 0;
                if (($d[$j] - $d[0]) > 500) { $dd = -1; }
                if (($d[$j] - $d[0]) < -500) { $dd = 1; }
                $DM += $d0 + $d[$j]/1000 + $dd;		  # $DM = momentanément somme des x
                $DS += ($d0 + $d[$j]/1000 + $dd)**2;  # $DS = momentanément somme des x²
                $n++;
            }
        }
        if ($n > 0) {
            $DM = $DM/$n;	# $DM = moyenne
            $DS = 2 * sqrt($DS/$n - $DM*$DM);	# $DS = 2 * écart-type
        }

        $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

        my $normSite = normNode(node=>"PROC.$site");
        if ($normSite ne "") {
            $lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><B>$aliasSite</B></A>";
        } else { $lien = "$aliasSite"  }
        $modif = "<a href=\"/cgi-bin/".$FORM->conf('CGI_FORM')."?id=$id\"><img src=\"/icons/modif.png\" title=\"Editer...\" border=0></a>";
        $efface = "<img src=\"/icons/no.png\" title=\"Effacer...\" onclick=\"checkRemove($id)\">";

        $texte = $texte."<TR>";
        if ($editOK) {
            $texte = $texte."<TD nowrap>$modif</TD>";
        }
        $texte = $texte."<TD nowrap>$date $heure</TD><TD align=center>$lien</TD>"
          ."<TD align=center>$aemd</TD><TD align=center>$pAtm</TD><TD align=center>$tAir</TD><TD align=center>$HR</TD>"
          ."<TD align=center>$nebul</TD><TD align=center>$vitre</TD><TD align=center>$d0</TD>";
        for (@nd) {
            $texte = $texte."<TD align=center>$d[$_]</TD>";
        }
        $texte = $texte."<TD class=tdResult>".sprintf("%1.3f",$DM)."</TD>";
        if (($DS > 0.1) || ($DS == 0)) {
            $texte .= "<TD class=tdResult style=\"background-color:#FFAAAA\">";
        } elsif ($DS > 0.02 ) {
            $texte .= "<TD class=tdResult style=\"background-color:#FFEBAA\">";
        } else {
            $texte .= "<TD class=tdResult>";
        }
        $texte .= sprintf("%1.3f",$DS)."</TD><TD>";
        $txt = "$date;$heure;$site;$aliasSite;$aemd;$pAtm;$tAir;$HR;$nebul;$vitre;$DM;$DS;";
        if ($rem ne "") {
            $rem =~ s/\'/&rsquo;/g;
            $rem =~ s/\"/&quot;/g;
            $texte = $texte."<IMG src=\"/icons/attention.gif\" border=0 onMouseOut=\"nd()\" onMouseOver=\"overlib('$rem',CAPTION,'Observations $aliasSite')\">";
        }
        $texte = $texte."</TD></TR>\n";
        $txt = $txt."\"$rem\"\n";
        push(@csv,u2l($txt));

        $nbLignesRetenues++;
    }
    $i++;
}

push(@html,"Nombre de donn&eacute;es affich&eacute;es = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>T&eacute;l&eacute;charger un fichier Excel de ces donn&eacute;es: <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&annee=$QryParm->{'annee'}&mois=$QryParm->{'mois'}&site=$QryParm->{'site'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>",
        "<P>Types de Distancem&egrave;tres: ");
    for (@types) {
        my ($tpi,$tpn) = split(/\|/,$_);
        push(@html,"<B>$tpi</B> = $tpn, ");
    }
    push(@html,"\n<P>N&eacute;bulosit&eacute;: ");
    for (@meteo) {
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

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014-2014 - Institut de Physique du Globe Paris

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

