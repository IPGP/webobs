#!/usr/bin/perl

=head1 NAME

showFISSURO.pl 

=head1 SYNOPSIS

http://..../showFISSURO.pl? ... see query string definitions below ...

=head1 DESCRIPTION

=head1 Configuration FISSURO

  =key|value
  CGI_SHOW|showFISSURO.pl
  BANG|1980
  DELAY|30
  FILE_NAME|FISSURO.DAT
  TITLE|Banque de donn&eacute;es de fissurom&eacute;trie
  FILE_METEO|meteoExtenso.conf
  FILE_TYPE|typeFissuro.conf
  FILE_COMPONENT|composanteFissuro.conf

=head1 Query string parameters

=over

=item B<y1=> and B<m1> and B<d1>  

select records after (and on) y1/m1/d1 (startdate yyyy/mm/dd). Defaults to enddate minus DELAY days.

=item B<y2=> and B<m2> and B<d2> 

select records before (and on) y2/m2/d2 (enddate yyyy/mm/dd). Defaults to most recent date in file. 

=item B<site=>

node to display. Default to "Tout" (all) 

=item B<affiche=[csv]>

show html page or download (affiche=csv) a csv file for data. Default is "" or none (=show html).

=item B<obs=[regex]>

string used as a regex to select records

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

die "You can't view FISSURO reports." if (!clientHasRead(type=>"authforms",name=>"FISSURO"));
my $displayOnly = clientHasEdit(type=>"authforms",name=>"FISSURO") ? 0 : 1;

my $FORM = new WebObs::Form('FISSURO');
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

my $QP       = $cgi->Vars;

# ---- DateTime inits ----------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $jour  = strftime('%d',@tod);
my $mois  = strftime('%m',@tod);
my $annee = strftime('%Y',@tod);
my $moisActuel = strftime('%Y-%m',@tod);
my $displayMoisActuel = strftime('%B %Y',@tod);
my $today = strftime('%F',@tod);

# ---- specific FORMS inits ----------------------------------
my @meteo    = readCfgFile($FORM->path."/".$FORM->conf('FILE_METEO'));
my @type     = readCfgFile($FORM->path."/".$FORM->conf('FILE_TYPE'));
my @comp     = readCfgFile($FORM->path."/".$FORM->conf('FILE_COMPONENT'));

my @html;
my @csv;
my $affiche;
my $s;
my $i;
my $j;

my %nomMeteo;
my %iconeMeteo;
my %operStat;
my @operNb;

my $dateStart = "";
my $dateEnd = "";
my $fileMC = "";
my $selectedYear1 = "";
my $selectedMonth1 = "";
my $selectedDay1 = "";
my $selectedYear2 = "";
my $selectedMonth2 = "";
my $selectedDay2 = "";
my $selectedSite = "";
my $selectedFilter = "";

my $fileCSV = "OVSG_FISSURO_$today.csv";

my $afficheSite;
my $afficheDates;
my $anneeActuelle = qx(date +"%Y"); chomp($anneeActuelle);
my @mois=("01".."12");
my @jour=("01".."31");

my $titrePage = $FORM->conf('TITLE');

# ---- Read the data file
#
my ($fptr, $fpts) = $FORM->data;
my @lignes = @$fptr;
my $nbData = $#lignes -1;
@lignes = reverse sort tri_date_avec_id @lignes;

# ---- Retrieve the most recent date (for default display)
my (@dd) = split(/\|/,$lignes[$#lignes - 1]);
my $lastDate = $dd[1];

# get query-string parameters 
# ---------------------------------------------------------------
if ($QP->{y1} && $QP->{m1} && $QP->{d1} && $QP->{y2} && $QP->{m2} && $QP->{d2} ) {
    $dateStart = "$QP->{y1}-$QP->{m1}-$QP->{d1}" ;
    $dateEnd   = "$QP->{y2}-$QP->{m2}-$QP->{d2}";
    my $nbJours = (qx(date -d "$dateEnd" +%s) - qx(date -d "$dateStart" +%s))/86400 + 1;
    $afficheDates = "<b>$dateStart</b> &agrave; <b>$dateEnd</b> ($nbJours jours)";
} else {
    my $u = $FORM->conf('DELAY');
    $dateEnd = $lastDate;
    $dateStart = qx(date -d "$dateEnd $u days ago" +"%Y-%m-%d");
    chomp($dateStart);
    ($QP->{y1},$QP->{m1},$QP->{d1}) = split(/-/,$dateStart);
    ($QP->{y2},$QP->{m2},$QP->{d2}) = split(/-/,$dateEnd);
    $afficheDates = "<b>$dateStart</b> &agrave; <b>$dateEnd</b> (d&eacute;faut = ".$FORM->conf('DELAY')." derniers jours de mesures)";
}

$QP->{'site'}    ||= "Tout";
$QP->{'obs'}     ||= "";
$QP->{'affiche'} ||= "";

# ---- a site requested as {name} means "all nodes for grid (proc) 'name'"
# 
my @gridsites;
if ($QP->{'site'} =~ /^{(.*)}$/) {
    my %tmpN = $FORM->nodes($1);
    for (keys(%tmpN)) {
        push(@gridsites,"$_");
    }
}

# ---- 
push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

# ---- start html if not CSV output
if ($QP->{'affiche'} ne "csv") {
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
      "<!-- overLIB (c) Erik Bosrup -->\n",

      print <<"FIN";
    <script type="text/javascript">
    <!--
    function resetMois1()
    {
        document.formulaire.m1.value = "01";
            document.formulaire.d1.value = "01";
    }

    function resetJour1()
    {
            document.formulaire.d1.value = "01";
    }

    function resetMois2()
    {
            document.formulaire.m2.value = "12";
            document.formulaire.d2.value = "31";
    }

    function resetJour2()
    {
            document.formulaire.d2.value = "31";
    }

    function effaceFiltre()
    {
        document.formulaire.obs.value = "";
    }
    //-->
    </script>
FIN
}

# meteo stuff 
for (@meteo) {
    my ($cle,$nom,$ico) = split(/\|/,$_);
    $nomMeteo{$cle} = $nom;
    $iconeMeteo{$cle} = $ico;
}

# File's records selection on string filter (all fields)
if ($QP->{'obs'} ne "") {
    if (substr($QP->{'obs'},0,1) eq "!") {
        my $regex = substr($QP->{'obs'},1);
        @lignes = grep(!/$regex/i, @lignes);
    } else {
        @lignes = grep(/$QP->{'obs'}/i, @lignes);
    }
}

# File's records selection on network / site
if ($QP->{'site'} ne "" && $QP->{'site'} ne "Tout") {
    @lignes = grep(/\|$QP->{'site'}/, @lignes);
}

# File's records selection on dates (from $dateStart to $DateEnd)
my @finalLignes;
my $l = 0;
for (@lignes) {
    my (@dd) = split(/\|/,$_);
    if ($dd[0] ne "ID" && $dd[1] ge $dateStart && $dd[1] le $dateEnd) {
        push(@finalLignes,$_);
    }
    $l++;
}

# Form for display selection
# 
if ($QP->{'affiche'} ne "csv") {
    print("<FORM name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">",
        "<P class=\"boitegrise\" align=\"center\">",
        "<B>Date d&eacute;but: ");

    # ----- YEAR1
    print "<select name=\"y1\" size=\"1\" onChange=\"resetMois1()\">";
    for ($FORM->conf('BANG')..$anneeActuelle) {
        if ($_ == $QP->{y1}) {
            print "<option selected value=$_>$_</option>\n";
        } else {
            print "<option value=$_>$_</option>\n";
        }
    }
    print "</select>\n";

    # -----MONTH1
    print " - <select name=\"m1\" size=\"1\" onChange=\"resetJour1()\">";for (@mois) {
        if ($_ == $QP->{m1}) {
            print "<option selected value=$_>$_</option>\n";
        } else {
            print "<option value=$_>$_</option>\n";
        }
    }
    print "</select>\n";

    # ----- DAY1
    print " - <select name=\"d1\" size=\"1\">";
    for (@jour) {
        if ($_ == $QP->{d1}) {
            print "<option selected value=$_>$_</option>\n";
        } else {
            print "<option value=$_>$_</option>\n";
        }
    }
    print "</select>\n";

    # ----- YEAR2
    print " Date fin: <select name=\"y2\" size=\"1\" onChange=\"resetMois2()\">";
    for ($FORM->conf('BANG')..$anneeActuelle) {
        if ($_ == $QP->{y2}) {
            print "<option selected value=$_>$_</option>\n";
        } else {
            print "<option value=$_>$_</option>\n";
        }
    }
    print "</select>\n";

    # ----- MONTH2
    print " - <select name=\"m2\" size=\"1\" onChange=\"resetJour2()\">";
    for (@mois) {
        if ($_ == $QP->{m2}) {
            print "<option selected value=$_>$_</option>\n";
        } else {
            print "<option value=$_>$_</option>\n";
        }
    }
    print "</select>\n";

    # ----- DAY2
    print " - <select name=\"d2\" size=\"1\">";
    for (reverse(@jour)) {
        if ($_ == $QP->{d2}) {
            print "<option selected value=$_>$_</option>\n";
        } else {
            print "<option value=$_>$_</option>\n";
        }
    }
    print "</select>\n",
      "<select name=\"site\" size=\"1\">";
    for ("Tout|Tous les sites",@NODESSelList) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QP->{'site'}") {
            print("<option selected value=$val>$cle</option>\n");
            $afficheSite = "$cle ($val)";
        } else {
            print("<option value=$val>$cle</option>\n");
        }
    }
    print "</select>";

    # ----- FILTER
    my $msg = "Le filtre fonctionne avec une <a href=http://perl.enstimac.fr/DocFr/perlretut.html target=_blank>expression rationnelle</a> ".
      "(<i>regular expression</i>) et un grep qui ne tient pas compte de la casse. ".
      "Pour la n&eacute;gation, ajouter un point d&rsquo;exclamation en d&eacute;but d&rsquo;expression. ".
      "Le filtre s&rsquo;applique &agrave; toute la ligne de donn&eacute;s: date, site, commentaire,... et valeurs num&eacute;riques.";

    print " Filtre: <input type=\"text\" name=\"obs\" size=15 value=\"$QP->{'obs'}\" onMouseOut=\"nd()\" onmouseover=\"overlib('$msg',CAPTION,'INFORMATIONS',STICKY,WIDTH,300,TIMEOUT,3000)\">";
    if ($QP->{'obs'} ne "") {
        print "<img style=\"border:0;vertical-align:text-bottom\" src=\"/images/cancel.gif\" onClick=effaceFiltre()>";
    }

    print ' <input type="submit" value=" Afficher">';

    if ($displayOnly ne 1) {
        print("<input type=\"button\" style=\"margin-left:15px;color:blue;\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_FORM')."'\" value=\"nouvel enregistrement\">");
    }
    print "</B></P></FORM>\n",
      "<H2>$titrePage</H2>\n",
      "Intervalle des dates: $afficheDates<br>",
      "Sites sélectionnés: <B>$afficheSite</B><BR>";
    if ($QP->{'obs'} ne "") {
        print "Filtre: &laquo;&nbsp;<B>$QP->{'obs'}</B>&nbsp;&raquo;<BR>";
    }
}

my ($id,$date,$heure,$site,$ope,$tAir,$tMeteo,$instr,$comp,$rem,$val) = ("")x11;
my @d;
my @nd = (0..11);
my $entete;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $fmt = "%0.4f";
my $aliasSite;

$entete = "<TR>";
if ($displayOnly ne 1) {
    $entete = $entete."<TH rowspan=2></TH>";
}
$entete = $entete."<TH rowspan=2>Date</TH><TH rowspan=2>Heure</TH><TH rowspan=2>Site</TH>"
  ."<TH colspan=3>M&eacute;tadonn&eacute;es</TH>"
  ."<TH rowspan=2>Composante</TH>"
  ."<TH colspan=12>Mesures (mm): Perpendiculaire (Serrage) / Parall&egrave;le (Jeu Dextre) / Vertical (Mont&eacute;e Est)</TH>"
  ."<TH colspan=2>Statistiques</TH><TH rowspan=2></TH></TR>\n"
  ."<TR><TH>Tair<br>(°C)</TH><TH>M&eacute;t&eacute;o</TH>"
  ."<TH>Instr.</TH>";
for ("1".."12") {
    $entete = $entete."<TH>D<sub>$_</sub></TH>";
}
$entete = $entete."<TH><SPAN style=\"text-decoration:overline\"><I>x</I></SPAN><br>(mm)</TH><TH>2&sigma;<br>(mm)</TH></TR>\n";

push(@csv,l2u("Date;Heure;Code;Site;Operateurs;Temp. Air (�C);Meteo;Instr.;Num.;Serrage/Perp. (mm);S_perp (mm);Jeu Dextre/Para. (mm);S_para (mm);Montee Est/Vert. (mm);S_vert (mm);Remarques\n"));

for(@finalLignes) {
    ($id,$date,$heure,$site,$ope,$tAir,$tMeteo,$instr,$comp,$d[0][0],$d[0][1],$d[0][2],$d[1][0],$d[1][1],$d[1][2],$d[2][0],$d[2][1],$d[2][2],$d[3][0],$d[3][1],$d[3][2],$d[4][0],$d[4][1],$d[4][2],$d[5][0],$d[5][1],$d[5][2],$d[6][0],$d[6][1],$d[6][2],$d[7][0],$d[7][1],$d[7][2],$d[8][0],$d[8][1],$d[8][2],$d[9][0],$d[9][1],$d[9][2],$d[10][0],$d[10][1],$d[10][2],$d[11][0],$d[11][1],$d[11][2],$rem,$val) = split(/\|/,$_);
    $tMeteo = lc($tMeteo);
    chomp($val);
    my $err;
    for (@type) {
        my ($tpi,$tpe,$tpn) = split(/\|/,$_);
        if ($tpi eq $instr) { $err = $tpe; }
    }

    # trie les donn�es pour mettre les champs vides � la fin...
    #@d = sort { ($a eq "") <=> ($b eq "") } @d;
    my @DM = (0,0,0);
    my @DS = (0,0,0);
    my @n = (0,0,0);
    for $i(@nd) {
        for $j(0..2) {
            if ($d[$i][$j] ne "") {
                $DM[$j] +=  $d[$i][$j];        # $DM = momentanément somme des x
                $DS[$j] += ($d[$i][$j])**2;    # $DS = momentanément somme des x²
                $n[$j]++;
            }
        }
    }
    for $j(0..2) {
        if ($n[$j] > 0) {
            $DM[$j] = $DM[$j]/$n[$j];                    # $DM = moyenne mesure
            $DS[$j] = 2 * sqrt($DS[$j]/$n[$j] - ($DM[$j]*$DM[$j]));    # $DS = 2 * écart-type
            if ($DS[$j] < $err) {
                $DS[$j] = $err;
            }
            $DM[$j] = sprintf("%1.2f",$DM[$j]);
            $DS[$j] = sprintf("%1.2f",$DS[$j]);
        } else {
            $DS[$j] = "";
        }
    }

    $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;
    my @listenoms = split(/\+/,$ope);

    #djl-TBD    my $noms = join(", ",nomOperateur(@listenoms));
    #djl-TBD    for (@listenoms) {
    #djl-TBD        $operStat{$_} += 1;
    #djl-TBD    }

    my $normsite = WebObs::Grids::normNode(node=>"PROC.FISSURO.$site");
    if ($normsite eq "") { $normsite =  WebObs::Grids::normNode(node=>".FISSURO.$site") }
    if ($normsite eq "") { $normsite =  WebObs::Grids::normNode(node=>"..$site") }
    $lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normsite\"><B>$aliasSite</B></A>";
    $modif = "<a href=\"/cgi-bin/".$FORM->conf('CGI_FORM')."?id=$id\"><img src=\"/icons/modif.png\" title=\"Editer...\" border=0></a>";
    $efface = "<img src=\"/icons/no.png\" title=\"Effacer...\" onclick=\"checkRemove($id)\">";

    $texte = $texte."<TR>";
    if ($displayOnly ne 1) {
        $texte = $texte."<TD nowrap>$modif</TD>";
    }
    $texte = $texte."<TD nowrap align=center>$date</TD><TD align=center>$heure</TD><TD align=center>$lien</TD>"
      ."<TD align=center>$tAir</TD><TD align=center>";
    if ($iconeMeteo{$tMeteo} ne "") {
        $texte = $texte."<IMG src=\"/icons/meteo/$iconeMeteo{$tMeteo}\" title=\"$nomMeteo{$tMeteo}\">";
    }
    $texte = $texte."</TD>"
      ."<TD align=center>$instr</TD>"
      ."<TD align=center><TABLE cellspacing=0 width=\"100%\"><TD rowspan=3 style=border:0>&nbsp;<B>$comp</B>&nbsp;</TD>"
      ."<TD style=border:0><I>Perp.</I></TD></TR>"
      ."<TR><TD style=border:0><I>Para.</I></TD></TR><TR><TD style=border:0><I>Vert.</I></TD></TR></TABLE></TD>";
    for (@nd) {
        if ($d[$_][0] ne "" || $d[$_][1] ne "" ||$d[$_][2] ne "") {
            $texte = $texte."<TD align=right><TABLE cellspacing=0>"
              ."<TR><TD style=border:0 align=right>".(($d[$_][0] ne "") ? sprintf("%1.2f",$d[$_][0]) : "&nbsp;")."</TD></TR>"
              ."<TR><TD style=border:0 align=right>".(($d[$_][1] ne "") ? sprintf("%1.2f",$d[$_][1]) : "&nbsp;")."</TD></TR>"
              ."<TR><TD style=border:0 align=right>".(($d[$_][2] ne "") ? sprintf("%1.2f",$d[$_][2]) : "&nbsp;")."</TD></TR>"
              ."</TABLE></TD>";
        } else {
            $texte = $texte."<TD>&nbsp;</TD>";
        }
    }
    $texte = $texte."<TD align=center><TABLE cellspacing=0 width=\"100%\">";
    for $j(0..2) {
        $texte = $texte. "<TR><TD class=tdResult style=border:0>$DM[$j]</TD></TR><TR>";
    }
    $texte = $texte."</TABLE></TD><TD align=center><TABLE cellspacing=0 width=\"100%\">";
    for $j(0..2) {
        if ($DS[$j] > 1) {
            $texte = $texte."<TD class=tdResult style=\"border:0;background-color:#FFAAAA\">$DS[$j]</TD></TR>";
        } elsif ($DS[$j] > 0.2 ) {
            $texte = $texte."<TD class=tdResult style=\"border:0;background-color:#FFEBAA\">$DS[$j]</TD></TR>";
        } else {
            $texte = $texte."<TD class=tdResult style=border:0>$DS[$j]</TD></TR>";
        }
    }
    $texte = $texte."</TABLE></TD>\n";
    my $infoRem = "";
    my $infoImg = "";
    if ($rem ne "") {
        $rem =~ s/\'/&rsquo;/g;
        $rem =~ s/\"/&quot;/g;
        $infoRem = "$rem<br>___<br>";
        $infoImg = "<IMG src=\"/images/attention.gif\" border=0>";
    }

#djl-TBD    $texte = $texte."<TD onMouseOut=\"nd()\" onMouseOver=\"overlib('$infoRem<i>Op&eacute;rateurs:</i> $noms<br>___<br><i>Saisie:</i> $val',CAPTION,'Observations $aliasSite')\">$infoImg</TD></TR>\n";
    push(@csv,"$date;$heure;$site;$aliasSite;$ope;$tAir;$tMeteo;$instr;$comp;$DM[0];$DS[0];$DM[1];$DS[1];$DM[2];$DS[2];\"".u2l($rem)."\"\n");
}

push(@html,"Nombre de donn&eacute;es affich&eacute;es = <B>".($#finalLignes + 1)."</B> / $nbData</P>\n",
    "<P>T&eacute;l&eacute;charger un fichier texte/Excel de ces donn&eacute;es: <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&y1=$QP->{y1}&m1=$QP->{m1}&d1=$QP->{d1}&y2=$QP->{y2}&m2=$QP->{m2}&d2=$QP->{d2}&site=$QP->{'site'}&obs=$QP->{'obs'}\"><B>$fileCSV</B></A></P>\n");

push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>",
    "\n<P>Type de mesure: ");
for (@type) {
    my ($tpi,$tpe,$tpn) = split(/\|/,$_);
    push(@html,"<B>$tpi</B> = $tpn (&plusmn; $tpe mm), ");
}
push(@html,"</P><P>Composantes: ");
for (@comp) {
    my ($tpi,$tpn) = split(/\|/,$_);
    push(@html,"<B>$tpi</B> = $tpn, ");
}

if ($QP->{'affiche'} eq "csv") {
    print @csv;
} else {
    print @html;

#djl-TBD    for ($nb=0;$nb<$#operateurs;$nb++) {
#djl-TBD        $operNb[$nb] = sprintf("%5d x %s",$operStat{$operateurs[$nb][0]},$operateurs[$nb][1]);
#djl-TBD    }
#djl-TBD    @operNb = reverse(sort(grep(!/   0 x/,@operNb)));
#djl-TBD    print "<P align=right><SPAN onMouseOut=\"nd()\" onMouseOver=\"overlib('".join("<br>",@operNb)."',CAPTION,'Top op&eacute;rateurs',ABOVE)\"><small>?</small></SPAN></P>";

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

