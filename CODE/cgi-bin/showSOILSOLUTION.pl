#!/usr/bin/perl

=head1 NAME

showSOILSOLUTION.pl

=head1 SYNOPSIS

http://..../showSOILSOLUTION.pl?.... see 'query string parameters' ...

=head1 DESCRIPTION

'SOILSOLUTION' is a WebObs FORM.

This script allows displaying and editing soil solution chemical analysis data from
any proc associated to the form SOILSOLUTION.

=head1 Configuration SOILSOLUTION

Example of a file 'SOILSOLUTION.conf':

  =key|value
  CGI_SHOW|showSOILSOLUTION.pl
  CGI_FORM|formSOILSOLUTION.pl
  CGI_POST|postSOILSOLUTION.pl
  BANG|2000
  FILE_NAME|SOILSOLUTION.DAT
  TITLE|Databank of soil solution chemical analysis
  FILE_RATIOS|ratios.conf
  FILE_NOTES|notes.html
  FILE_CSV_PREFIX|SOILSOLUTION
  DEFAULT_DAYS|365
  DEFAULT_SAMPLING_TIME|11:00

=head1 Query string parameters

=over

=item B<date selection>

time span of the data, including partial recordings.
y1= , m1= , d1=
 start date (year, month, day) included

 y2= , m2= , d2=
  end date (year, month, day) included

=item B<node=>

node (ID) to display. The format I<{procName}> will display all nodes associated
to the proc 'procName'. Default: display all nodes associated to any proc using
the form (and user having the read authorization).

=item B<unit=>

{ ppm | mmol }. Default: ppm

=item B<dump=>

dump=csv will download a csv file of selected data, instead of display.


=item B<ratio[N]>

selects the ratio(s) ratio[N] (ratio1, ratio2, ...) as defined in the configuration
file FILE_RATIOS (see SOILSOLUTION.conf)


=back

=cut

use strict;
use warnings;
use Time::Local;
use DateTime;
use Math::Trig;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);
use URI;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- Return URL --------------------------------------------
# Keep the URL where the user should be returned after edition
# (this will keep the filters selected by the user)
my $return_url = $cgi->url(-query_string => 1);

# ---- standard FORMS inits ----------------------------------

my $form = "SOILSOLUTION";

die "You can't view $form reports." if (!clientHasRead(type=>"authforms",name=>"$form"));
my $clientAuth = clientHasEdit(type=>"authforms",name=>"$form") ? 2 : 0;
$clientAuth = clientHasAdm(type=>"authforms",name=>"$form") ? 4 : $clientAuth;

my $FORM = new WebObs::Form($form);
my %Ns;
my @NODESSelList;
my @NODESValidList;
my %Ps = $FORM->procs;
for my $p (sort keys(%Ps)) {
    push(@NODESSelList,"\{$p\}|-- {PROC.$p} $Ps{$p} --");
    my %N = $FORM->nodes($p);
    for my $n (sort keys(%N)) {
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
my @ratios = readCfgFile($FORM->path."/".$FORM->conf('FILE_RATIOS'));
my @notes    = readCfgFile($FORM->path."/".$FORM->conf('FILE_NOTES'));

my @html;
my @csv;
my $s = '';
my $i = 0;

my %GMOL = readCfg("$WEBOBS{ROOT_CODE}/etc/gmol.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $WEBOBS{WEBOBS_ID}."_".$FORM->conf('FILE_CSV_PREFIX')."_$endDate.csv";

my $critereDate = "";
my $unit;

my @cleParamUnite = ("ppm|in ppm","mmol|in mmol/l");
my @cleParamSite;

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
$QryParm->{'dump'}  //= "";
$QryParm->{'unit'}    //= "ppm";
$unit = ($QryParm->{'unit'} eq "ppm" ? "ppm":"mmol/l");
$startDate = "$QryParm->{'y1'}-$QryParm->{'m1'}-$QryParm->{'d1'}";
$endDate = "$QryParm->{'y2'}-$QryParm->{'m2'}-$QryParm->{'d2'}";

$i = 0;
for (@ratios) {
    my $rapn = "rap$i";
    if (defined($QryParm->{$rapn})) {
        $rap[$i] = 1;
        $nbRap++;
    } else { $rap[$i] = 0 }
    $i++;
}

# ---- a site requested as {name} means "all nodes for proc 'name'"
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

if ($QryParm->{'dump'} ne "csv") {
    print $cgi->header(-charset=>'utf-8');
    print qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
    <html><head><title>).$FORM->conf('TITLE').qq(</title>
    <meta http-equiv="content-type" content="text/html; charset=utf-8">
    <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">);

    print qq(</head>
    <body style="background-attachment: fixed">
    <div id="attente">$__{'Searching for the data... please wait'}.</div>
    <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
    <script language="JavaScript" src="/js/overlib/overlib.js"></script>
    <!-- overLIB (c) Erik Bosrup -->\n);
}

# ---- Debut du formulaire pour la selection de l'affichage
#
if ($QryParm->{'dump'} ne "csv") {
    print "<FORM name=\"formulaire\" action=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\" method=\"get\">",
      "<TABLE width=\"100%\"><TR><TD class=\"boitegrise\" style=\"border:0;text-align:center\">",
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
    print qq(</select>
    <select name="unit" size="1">);
    for (@cleParamUnite) {
        my ($val,$cle) = split (/\|/,$_);
        if ("$val" eq "$QryParm->{'unit'}") { print qq(<option selected value=$val>$cle</option>\n); }
        else { print qq(<option value=$val>$cle</option>\n); }
    }
    print qq(</select>&nbsp;&nbsp;&nbsp;
    <INPUT type="button" value="$__{'Reset'}" onClick="reset()">
    <INPUT type="submit" value="$__{'Display'}" style="font-weight: bold"><BR>
    &nbsp;&nbsp;\n<B>$__{'Ratios'}:</B>);

    $i = 0;
    for (@ratios) {
        my ($num,$den,$nhtm,$dhtm) = split(/\|/,$_);
        my $sel_rap = "";
        if ($rap[$i] == 1) { $sel_rap = "checked"; }
        print qq(<input type="checkbox" name="rap$i" $sel_rap>$nhtm/$dhtm&nbsp;&nbsp;);
        $i++;
    }
    print "</TD>";
    if ($clientAuth > 1) {
        my $form_url = URI->new("/cgi-bin/".$FORM->conf('CGI_FORM'));
        $form_url->query_form('return_url' => $return_url);
        print qq(<TD class="boitegrise" style="border:0"><input type="button" style="margin-left:15px;color:blue;font-weight:bold"),
          qq( onClick="document.location='$form_url'" value="$__{'Enter a new record'}"></TD>);
    }
    print qq(</B></TR></TABLE></FORM>
    <H1>).$FORM->conf('TITLE').qq(</H1>\n);
}

# ---- Read the data file
#
my ($fptr, $fpts) = $FORM->data;
my @lines = @$fptr;
my $nbData = @lines - 1;
#
my $header;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $txt;
my $fmt = "%0.4f";
my $aliasSite;

$header = "<TR>";
if ($clientAuth > 1) {
    $header = $header."<TH rowspan=2></TH>";
}
$header = $header."<TH colspan=3>Sampling Time Collection</TH>"
  ."<TH rowspan=2>Site</TH>"
  ."<TH colspan=2>Lysimeter</TH>"
  ."<TH colspan=4>Laboratory Meas.</TH>"
  ."<TH colspan=4>Cations ($unit)</TH>"
  ."<TH colspan=4>Anions ($unit)</TH>"
  ."<TH rowspan=2>NICB<br>(%)</TH>"
  .($nbRap > 0 ? "<TH colspan=".$nbRap."> Ratios</TH>":"")
  ."<TH rowspan=2></TH></TR>\n"
  ."<TR><TH>Start<br>Date &amp; Time</TH><TH>End<br>Date &amp; Time</TH><TH>Days</TH>"
  ."<TH>Depth<br>(cm)</TH><TH>Level</TH>"
  ."<TH>pH</TH>"
  ."<TH>Cond.<br>(µS)</TH>"
  ."<TH>SiO<sub>2</sub><br>(ppm)</TH>"
  ."<TH>DOC<br>(ppm)</TH>"
  ."<TH>Na<sup>+</sup></TH>"
  ."<TH>K<sup>+</sup></TH>"
  ."<TH>Mg<sup>++</sup></TH>"
  ."<TH>Ca<sup>++</sup></TH>"
  ."<TH>HCO<sub>3</sub><sup>-</sup></TH>"
  ."<TH>Cl<sup>-</sup></TH>"
  ."<TH>NO<sub>3</sub><sup>-</sup></TH>"
  ."<TH>SO<sub>4</sub><sup>--</sup></TH>";
$i = 0;
for (@ratios) {
    my ($num,$den,$nhtm,$dthm) = split(/\|/,$_);
    if ($rap[$i] == 1) {
        $header = $header."<TH><table align=center><TR>"
          ."<TH style=\"border:0;border-bottom-style:solid;border-bottom-width:1px;text-align:center\">$nhtm</TH></TR>"
          ."<TR><TH style=\"border:0;text-align:center\">$dthm</TH></TR></TABLE></TH>";
    }
    $i++;
}

$header = $header."</TR>\n";

$i = 0;
my $nbLignesRetenues = 0;
for (@lines) {
    my ($id,$date2,$time2,$site,$date1,$time1,$depth,$level,$pH,$cond,$cNa,$cK,$cMg,$cCa,$cHCO3,$cCl,$cNO3,$cSO4,$cSiO2,$cDOC,$rem,$val) = split (/\|/,$_);
    if ($i eq 0) {
        push(@csv,l2u("$date1;$time1;$date2;$time2;Site ID;$site;$depth;$level;$pH;$cond;$cSiO2;$cDOC;$cNa;$cK;$cMg;$cCa;$cHCO3;$cCl;$cNO3;$cSO4;NICB (%);\"$rem\";$val"));
    }
    elsif (($_ ne "")
        && ($site eq $QryParm->{'node'} || grep(/^$site$/, @gridsites) || ($QryParm->{'node'} eq "All" && grep(/^$site$/, @NODESValidList)))
        && ($id > 0 || $clientAuth == 4)
        && ($date1 le $endDate) && ($date2 ge $startDate)) { # here we accept any data partially included in the time span

        my ($y,$m,$d) = split(/-/,$date1);
        my ($hr,$mn) = split(/:/,($time1 eq "" ? $FORM->conf('DEFAULT_SAMPLING_TIME'):$time1));
        my $d1 = DateTime->new(year => $y, month => $m, day => $d, hour => ($hr eq "" ? "00":$hr), minute => ($mn eq "" ? "00":$mn));
        my ($y,$m,$d) = split(/-/,$date2);
        my ($hr,$mn) = split(/:/,($time2 eq "" ? $FORM->conf('DEFAULT_SAMPLING_TIME'):$time2));
        my $d2 = DateTime->new(year => $y, month => $m, day => $d, hour => ($hr eq "" ? "00":$hr), minute => ($mn eq "" ? "00":$mn));
        my $dur = $d1->delta_days($d2)->delta_days;
        my ($cNa_mmol,$cK_mmol,$cMg_mmol,$cCa_mmol,$cCl_mmol,$cNO3_mmol,$cSO4_mmol,$cHCO3_mmol);
        $cNa_mmol=$cK_mmol=$cMg_mmol=$cCa_mmol=$cCl_mmol=$cNO3_mmol=$cSO4_mmol=$cHCO3_mmol=0;
        my $cH_mmol = "";
        my $tzp = "";
        my $tzn = "";
        my $nicb = "";
        my @rapv;
        my $rapport = "";

        if ($cNa ne "") { $cNa_mmol = $cNa/$GMOL{Na}; };
        if ($cK ne "") { $cK_mmol = $cK/$GMOL{K}; };
        if ($cMg ne "") { $cMg_mmol = $cMg/$GMOL{Mg}; };
        if ($cCa ne "") { $cCa_mmol = $cCa/$GMOL{Ca}; };
        if ($cCl ne "") { $cCl_mmol = $cCl/$GMOL{Cl}; };
        if ($cNO3 ne "") { $cNO3_mmol = $cNO3/$GMOL{NO3}; };
        if ($cSO4 ne "") { $cSO4_mmol = $cSO4/$GMOL{SO4}; };
        if ($cHCO3 ne "") { $cHCO3_mmol = $cHCO3/$GMOL{HCO3}; };
        if ($pH ne "") { $cH_mmol = 1000*10**(-$pH); }
        $tzp = $cNa_mmol + $cK_mmol + 2*$cMg_mmol + 2*$cCa_mmol;
        if ($tzp != 0) { $tzp += $cH_mmol; }
        $tzn = $cCl_mmol + 2*$cSO4_mmol + $cHCO3_mmol;
        if (($tzp != 0) && ($tzn != 0)) { $nicb = 100*($tzp - $tzn)/($tzp + $tzn); }

        my $iv = 0;
        for (@ratios) {
            if ($rap[$iv] == 1) {
                my ($num,$den,$nrp) = split(/\|/,$_);
                $rapv[$iv] = eval("sprintf(\"%1.3f\",\$c".$num."_mmol/\$c".$den."_mmol)");
                $rapport = $rapport."<TD class=tdResult>$rapv[$iv]</TD>";
            }
            $iv++;
        }

        $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

        my $normSite = normNode(node=>"PROC.$site");
        if ($normSite ne "") {
            $lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><B>$aliasSite</B></A>";
        } else {
            $lien = "$aliasSite";
        }
        my $form_url = URI->new("/cgi-bin/".$FORM->conf('CGI_FORM'));
        $form_url->query_form('id' => $id, 'return_url' => $return_url);
        $modif = qq(<a href="$form_url"><img src="/icons/modif.png" title="Edit..." border=0></a>);
        $efface = qq(<img src="/icons/no.png" title="Remove..." onclick="checkRemove($id)">);

        $texte = $texte."<TR ".($id < 1 ? "class=\"node-disabled\"":"").">";
        if ($clientAuth > 1) {
            $texte = $texte."<TD nowrap>$modif</TD>";
        }
        $texte = $texte."<TD nowrap>$date1 $time1</TD><TD nowrap>$date2 $time2</TD><TD align=center>$dur</TD><TD align=center>$lien</TD>"
          ."<TD align=center>$depth</TD><TD align=center>$level</TD>"
          ."<TD align=center>$pH</TD><TD align=center>$cond</TD>"
          ."<TD align=center>$cSiO2</TD><TD align=center>$cDOC</TD>";
        $txt = "$date1;$time1;$date2;$time2;$site;$aliasSite;$depth;$level;$pH;$cond;$cSiO2;$cDOC;";
        if ($QryParm->{'unit'} eq "mmol") {
            for ("Na","K","Mg","Ca","HCO3","Cl","NO3","SO4") {
                $texte .= "<TD align=center>";
                if (eval("\$c$_ ne \"\"")) {
                    $texte .= sprintf($fmt,eval("\$c".$_."_mmol"));
                }
                $texte .= "</TD>";
            }
            $txt .= "$cNa_mmol;$cMg_mmol;$cCa_mmol;$cHCO3_mmol;$cCl_mmol;$cNO3_mmol;$cSO4_mmol;";
        } else {
            $texte .= "<TD align=center>$cNa</TD><TD align=center>$cK</TD><TD align=center>$cMg</TD><TD align=center>$cCa</TD>"
              ."<TD align=center>$cHCO3</TD><TD align=center>$cCl</TD><TD align=center>$cNO3</TD><TD align=center>$cSO4</TD>";
            $txt .= "$cNa;$cK;$cMg;$cCa;$cHCO3;$cCl;$cNO3;$cSO4;";
        }
        if ($nicb and ($nicb < -20) || ($nicb > 20)) {
            $texte .= "<TD class=tdResult style=\"background-color:#FFAAAA\">";
        } elsif ($nicb and ($nicb < -10) || ($nicb > 10)) {
            $texte .= "<TD class=tdResult style=\"background-color:#FFEBAA\">";
        } else {
            $texte .= "<TD class=tdResult>";
        }
        if ($nicb ne "") {
            $texte .= sprintf("%1.1f",$nicb);
        }
        $texte .= "</TD>$rapport<TD>";
        $txt = $txt.sprintf("%0.1f",$nicb).";\"$rem\"\n";
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

push(@html,"$__{'Number of records'} = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
    "<P>$__{'Download a CSV text file of these data'} <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?dump=csv&y1=$QryParm->{'y1'}&m1=$QryParm->{'m1'}&d1=$QryParm->{'d1'}&y2=$QryParm->{'y2'}&m2=$QryParm->{'m2'}&d2=$QryParm->{'d2'}&node=$QryParm->{'node'}&unit=$QryParm->{'unit'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
    push(@html,"<TABLE class=\"trData\" width=\"100%\">$header\n$texte\n$header\n</TABLE>");
    push(@html,"</P>");
}
push(@html,@notes);

if ($QryParm->{'dump'} eq "csv") {
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

Francois Beauducel

=head1 COPYRIGHT

Webobs - 2012-2021 - Institut de Physique du Globe Paris

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
