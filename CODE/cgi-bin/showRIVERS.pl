#!/usr/bin/perl

=head1 NAME

showRIVERS.pl 

=head1 SYNOPSIS

http://..../showRIVERS.pl?.... voir 'query string parameters' ...

=head1 DESCRIPTION

'RIVERS' is a WebObs FORM. 

This script allows display and editing of chemical analysis data.

=head1 Configuration RIVERS 

Example of a file 'RIVERS.conf':

  =key|value
  CGI_SHOW|showRIVERS.pl
  CGI_FORM|formRIVERS.pl
  CGI_POST|postRIVERS.pl
  BANG|1797
  FILE_NAME|RIVERS.DAT
  TITLE|Banque de donn&eacute;es chimie des rivières
  FILE_TYPE|typeSitesRivers.conf
  FILE_RAPPORTS|rapportsRivers.conf
  FILE_CSV_PREFIX|OBSERA_RIVERS
  DEFAULT_DAYS|365

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

OBSOLÈTE: année à afficher. Défaut: l'année en cours

=item B<mois=> 

OBSOLÈTE: mois à afficher. Defaut: tous les mois de l'année 

=item B<node=>

node à afficher. Si de la forme I<{nomProc}> , affichera tous les nodes
de la PROC 'nomProc'. Defaut: tous les nodes 

=item B<unite=> 

{ ppm | mmol }. Defaut: ppm 

=item B<sio2=>

displays the Silica column

=item B<organiques=>

displays organics columns.

=item B<affiche=>


=item B<rap[N]>

selectionne le(s) rapport(s) rap[N] (rap1, rap2, ...) tels que définis dans le fichier de
configuration FILE_TYPE (voir RIVERS.conf)


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

my $form = "RIVERS";

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

# ---- DateTime inits ----------------------------------------
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
my @rapports = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));
my @notes    = readCfgFile($FORM->path."/".$FORM->conf('FILE_NOTES'));

my @html;
my @csv;
my $s = '';
my $i = 0;

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('FILE_CSV_PREFIX')."_$endDate.csv";

my $critereDate = "";
my $unite;

my @cleParamAnnee = ("Ancien|Ancien");
for ($FORM->conf('BANG')..$year) {
    push(@cleParamAnnee,"$_|$_");
}
my @cleParamMois;
for ('01'..'12') {
    $s = l2u(qx(date -d "$year-$_-01" +"%B")); chomp($s);
    push(@cleParamMois,"$_|$s");
}
my @cleParamUnite = ("ppm|en ppm","mmol|en mmol/l");
my @cleParamSite;

my @option = ();
my @rap;
my $nbRap = 0;
my @rapCalc;

$QryParm->{'y1'}         //= $y1;
$QryParm->{'m1'}         //= $m1;
$QryParm->{'d1'}         //= $d1;
$QryParm->{'y2'}         //= $year;
$QryParm->{'m2'}         //= $month;
$QryParm->{'d2'}         //= $day;
$QryParm->{'node'}       //= "All";
$QryParm->{'sio2'}       //= "";
$QryParm->{'organiques'} //= "";
$QryParm->{'affiche'}    //= "";
$QryParm->{'unite'}      //= "ppm";
if   ($QryParm->{'unite'} eq "ppm") {$unite = "ppm = mg/l"}
else                                {$unite = "mmol/l"}
$startDate = "$QryParm->{'y1'}-$QryParm->{'m1'}-$QryParm->{'d1'}";
$endDate = "$QryParm->{'y2'}-$QryParm->{'m2'}-$QryParm->{'d2'}";

# ---- a site requested as {name} means "all nodes for proc 'name'"
# 
my @gridsites;
if ($QryParm->{'node'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridsites,"$_");
    }
}

$i = 0;
for (@rapports) {
    $i++;
    my $rapn = "rap$i";
    if (defined($QryParm->{$rapn})) {
        $rap[$i] = 1;
        $nbRap++;
    } else { $rap[$i] = 0 }
}

# ----

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- start html if not CSV output 

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

# ---- Debut du formulaire pour la selection de l'affichage
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
    print("</select>\n",
        "<select name=\"unite\" size=\"1\">");
    for (@cleParamUnite) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'unite'}") { print("<option selected value=$val>$cle</option>\n"); }
        else { print("<option value=$val>$cle</option>\n"); }
    }
    print("</select>",
        " <INPUT type=\"button\" value=\"$__{'Reset'}\" onClick=\"reset()\">",
        " <INPUT type=\"submit\" value=\"$__{'Display'}\">");
    if ($clientAuth > 1) {
        print "<input type=\"button\" style=\"margin-left:15px;color:blue;font-weight:bold\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"$__{'Enter a new record'}\">";
    }
    print("<BR>\n");
    print("<input type=\"checkbox\" name=\"sio2\" value=1".($QryParm->{'sio2'} ne ""? " checked":"").">SiO<sub>2</sub>&nbsp;&nbsp;");
    print("<input type=\"checkbox\" name=\"organiques\" value=1".($QryParm->{'organiques'} ne ""? " checked":"").">$__{'Organiques'}&nbsp;&nbsp;");
    print("&nbsp;&nbsp;\n<B>$__{'Ratios'}:</B> ");

    $i = 0;
    for (@rapports) {
        my ($num,$den,$nhtm,$dhtm) = split(/\|/,$_);
        $i++;
        my $sel_rap = "";
        if ($rap[$i] == 1) { $sel_rap = "checked"; }
        print("<input type=\"checkbox\" name=\"rap$i\" $sel_rap>$nhtm/$dhtm&nbsp;&nbsp;");
    }
    print "</B></P></FORM>\n",
      "<H2>".$FORM->conf('TITLE')."</H2>\n",
      "<P>";
}

# ---- Read the data file 
#
my ($fptr, $fpts) = $FORM->data;
my @lignes = @$fptr;
my $nbData = @lignes - 1;
#
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
$entete = $entete."<TH rowspan=2>Date</TH>"
  ."<TH rowspan=2>Site<br>(Type prél.<br>et flacon)</TH>"
  ."<TH colspan=4>Mesures sur site</TH>"
  ."<TH rowspan=2>Charge<br>solide<br>(mg/L)</TH>"
  ."<TH colspan=4>Cations ($unite)</TH>"
  ."<TH colspan=3>Anions ($unite)</TH>"
  .($QryParm->{'sio2'} ne "" ? "<TH>Autres</TH>":"")
  .($QryParm->{'organiques'} ne "" ? "<TH colspan=2>Organiques</TH>":"")
  ."<TH colspan=".(2+$nbRap)."> Calculs</TH>"
  ."<TH rowspan=2></TH></TR>\n"
  ."<TR><TH>Niveau<br>(cm)</TH>"
  ."<TH>T eau<br>(°C)</TH>"
  ."<TH>pH</TH>"
  ."<TH>Cond<br>(µS/cm)</TH>"
  ."<TH>Na<sup>+</sup></TH>"
  ."<TH>K<sup>+</sup></TH>"
  ."<TH>Mg<sup>++</sup></TH>"
  ."<TH>Ca<sup>++</sup></TH>"
  ."<TH>HCO3<sup>-</sup></TH>"
  ."<TH>Cl<sup>-</sup></TH>"
  ."<TH>SO<sub>4</sub><sup>--</sup></TH>"
  .($QryParm->{'sio2'} ne "" ? "<TH>SiO<sub>2</sub>".($QryParm->{'unite'} ne "mmol" ? "<BR>(ppm)":"")."</TH>":"")
  .($QryParm->{'organiques'} ne "" ? "<TH>DOC</TH><TH>POC</TH>":"")
  ."<TH>Cond<sub>25</sub><br>(&mu;S)</TH>"
  ."<TH>NICB<br>(%)</TH>";
$i = 0;
for (@rapports) {
    my ($num,$den,$nhtm,$dthm) = split(/\|/,$_);
    $i++;
    if ($rap[$i] == 1) {
        $entete = $entete."<TH><table align=center><tr><th style=\"border:0;border-bottom-style:solid;border-bottom-width:1px;text-align:center\">$nhtm</th><tr><tr><th style=\"border:0;text-align:center\">$dthm</th></tr></table></TH>";
    }
}

$entete = $entete."</TR>\n";

$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
    my ($id,$date,$heure,$site,$level,$type,$flacon,$tRiver,$suspendedLoad,$pH,$cond25,$cond,$cNa,$cK,$cMg,$cCa,$cHCO3,$cCl,$cSO4,$cSiO2,$cDOC,$cPOC,$rem,$val) = split(/\|/,$_);
    if ($i eq 0) {
        push(@csv,l2u("$date;$heure;Code Site;$site;$level;$type;$flacon;$tRiver;$suspendedLoad;$pH;$cond;$cNa;$cK;$cMg;$cCa;$cHCO3;$cCl;$cSO4;".($QryParm->{'sio2'} ne "" ? "$cSiO2;":"").($QryParm->{'organiques'} ne "" ? "$cDOC;$cPOC;":"")."$cond25;NICB (%);\"$rem\";$val"));
    }
    elsif (($_ ne "")
        && ($site =~ $QryParm->{'node'} || $site ~~ @gridsites || ($QryParm->{'node'} eq "All" && $site ~~ @NODESValidList))
        && ($id > 0 || $clientAuth == 4)
        && ($date le $endDate) && ($date ge $startDate)) {

        my ($cNa_mmol,$cK_mmol,$cMg_mmol,$cCa_mmol,$cHCO3_mmol,$cCl_mmol,$cSO4_mmol,$cSiO2_mmol);
        $cNa_mmol=$cK_mmol=$cMg_mmol=$cCa_mmol=$cHCO3_mmol=$cCl_mmol=$cSO4_mmol=$cSiO2_mmol=0;
        my $cH_mmol = "";
        my $tzp = "";
        my $tzn = "";

        #        my $cond25 = "";
        my $nicb = "";
        my @rapv;
        my $iv = 0;
        my $rapport = "";

        if ($cNa ne "") { $cNa_mmol = $cNa/$GMOL{Na}; };
        if ($cK ne "") { $cK_mmol = $cK/$GMOL{K}; };
        if ($cMg ne "") { $cMg_mmol = $cMg/$GMOL{Mg}; };
        if ($cCa ne "") { $cCa_mmol = $cCa/$GMOL{Ca}; };
        if ($cHCO3 ne "") { $cHCO3_mmol = $cHCO3/$GMOL{HCO3}; };
        if ($cCl ne "") { $cCl_mmol = $cCl/$GMOL{Cl}; };
        if ($cSO4 ne "") { $cSO4_mmol = $cSO4/$GMOL{SO4}; };
        if ($cSiO2 ne "") { $cSiO2_mmol = $cSiO2/$GMOL{SiO2}; };
        if ($pH ne "") { $cH_mmol = 1000*10**(-$pH); }
        if (($cond ne "") && ($tRiver ne "")) { $cond25 = sprintf("%4.1f",$cond/(1 + 0.02*($tRiver - 25))); };
        $tzp = $cNa_mmol + $cK_mmol + 2*$cMg_mmol + 2*$cCa_mmol;

        #        if ($tzp != 0) { $tzp += $cH_mmol; }
        $tzn = $cHCO3_mmol + $cCl_mmol + 2*$cSO4_mmol;
        if (($tzp != 0) && ($tzn != 0)) { $nicb = 100*($tzp - $tzn)/($tzp + $tzn); }

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

        $texte = $texte."<TR ".($id < 1 ? "class=\"node-disabled\"":"").">";
        if ($clientAuth > 1) {
            $texte = $texte."<TD nowrap>$modif</TD>";
        }
        $texte .= "<TD nowrap>$date $heure</TD><TD align=center>$lien&nbsp;<br><span class=\"typeEaux\">$type&nbsp;$flacon</span></TD><TD align=center>"
          .($level ne ""?"".sprintf('%.2f',$level):"")."</TD><TD align=center>"
          .($tRiver ne ""?"".sprintf('%.2f',$tRiver):"")."</TD><TD align=center>"
          .($pH ne ""?"".sprintf('%.2f',$pH):"")."</TD><TD align=center>"
          .($cond ne ""?"".sprintf('%.2f',$cond):"")."</TD><TD align=center>"
          .($suspendedLoad ne ""?"".sprintf('%.2f',$suspendedLoad):"")."</TD>";
        $txt = "$date;$heure;$site;$aliasSite;$level;$type;$flacon;$tRiver;$suspendedLoad;$pH;$cond;";
        if ($QryParm->{'unite'} eq "mmol") {
            for ("Na","K","Mg","Ca","HCO3","Cl","SO4") {
                $texte .= "<TD align=center>";
                if (eval("\$c$_ ne \"\"")) {
                    $texte .= sprintf($fmt,eval("\$c".$_."_mmol"));
                }
                $texte .= "</TD>";
            }
            $texte .= ($QryParm->{'sio2'} ne "" ? "<TD align=center>".sprintf($fmt,$cSiO2_mmol)."</TD>":"");
            $txt .= "$cNa_mmol;$cK_mmol;$cMg_mmol;$cCa_mmol;$cHCO3_mmol;$cCl_mmol;$cSO4_mmol"
              .($QryParm->{'sio2'} ne "" ? ";$cSiO2_mmol;":";");
        } else {
            $texte .= "<TD align=center>"
              .($cNa ne ""?"".sprintf('%.2f',$cNa):"")."</TD><TD align=center>"
              .($cK ne ""?"".sprintf('%.2f',$cK):"")."</TD><TD align=center>"
              .($cMg ne ""?"".sprintf('%.2f',$cMg):"")."</TD><TD align=center>"
              .($cCa ne ""?"".sprintf('%.2f',$cCa):"")."</TD><TD align=center>"
              .($cHCO3 ne ""?"".sprintf('%.2f',$cHCO3):"")."</TD><TD align=center>"
              .($cCl ne ""?"".sprintf('%.2f',$cCl):"")."</TD><TD align=center>"
              .($cSO4 ne ""?"".sprintf('%.2f',$cSO4):"")."</TD>"
              .($QryParm->{'sio2'} ne ""?"<TD align=center>".($cSiO2 ne ""?"".sprintf('%.2f',$cSiO2):"")."</TD>":"");
            $txt .= "$cNa;$cK;$cMg;$cCa;$cHCO3;$cCl;$cSO4"
              .($QryParm->{'sio2'} ne "" ? ";$cSiO2;":";");
        }
        if ($QryParm->{'organiques'} ne "") {
            $texte .= "<TD align=center>"
              .($cDOC ne ""?"".sprintf('%.2f',$cDOC):"")."</TD><TD align=center>"
              .($cPOC ne ""?"".sprintf('%.2f',$cPOC):"")."</TD>";
            $txt .= "$cDOC;$cPOC;";
        }
        $texte .= "<TD class=tdResult>$cond25</TD>";
        if (($nicb < -20) || ($nicb > 20)) {
            $texte .= "<TD class=tdResult style=\"background-color:#FFAAAA\">";
        } elsif (($nicb < -10) || ($nicb > 10)) {
            $texte .= "<TD class=tdResult style=\"background-color:#FFEBAA\">";
        } else {
            $texte .= "<TD class=tdResult>";
        }
        if ($nicb ne "") {
            $texte .= sprintf("%1.1f",$nicb);
        }
        $texte .= "</TD>$rapport<TD>";

#$texte = $texte."<TD class=tdResult>$so4_cl</TD><TD class=tdResult>$hco3_cl</TD><TD class=tdResult>$ca_cl</TD><TD>";
        $txt = $txt."$cond25;$nicb;\"$rem\"\n";
        if ($rem ne "") {
            $rem =~ s/\'/&rsquo;/g;
            $rem =~ s/\"/&quot;/g;
            $texte = $texte."<IMG src=\"/icons/attention.gif\" border=0 onMouseOut=\"nd()\" onMouseOver=\"overlib('".l2u($rem)."',CAPTION,'Observations $aliasSite')\">";
        }
        $texte = $texte."</TD></TR>\n";
        push(@csv,l2u($txt));

        $nbLignesRetenues++;
    }
    $i++;
}

push(@html,"Number of records = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>Download a CSV text file of these data <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&y1=$QryParm->{'y1'}&m1=$QryParm->{'m1'}&d1=$QryParm->{'d1'}&y2=$QryParm->{'y2'}&m2=$QryParm->{'m2'}&d2=$QryParm->{'d2'}&node=$QryParm->{'node'}&unite=$QryParm->{'unite'}".($QryParm->{'sio2'} ne "" ? "&sio2=$QryParm->{'sio2'}":"").($QryParm->{'organiques'} ne "" ? "&organiques=$QryParm->{'organiques'}":"")."\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>",
        "<P>Types of sites: ");
    for (sort(keys(%types))) {
        push(@html,"<B>$_</B> = $types{$_}{name}, ");
    }
    push(@html,"</P>");
}
push(@html,@notes);

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

Francois Beauducel, Didier Lafon, Jean-Marie Saurel

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

