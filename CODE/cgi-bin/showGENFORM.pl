#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw/strftime/;
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

my $form = $cgi->param('form');
=pod
die "You can't view $form reports." if (!clientHasRead(type=>"authforms",name=>"$form"));
my $clientAuth = clientHasEdit(type=>"authforms",name=>"$form") ? 2 : 0;
$clientAuth = clientHasAdm(type=>"authforms",name=>"$form") ? 4 : $clientAuth;
=cut
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
my $day   = strftime('%d',@tod); 
my $month = strftime('%m',@tod); 
my $year  = strftime('%Y',@tod);
my $endDate = strftime('%F',@tod);
my $delay = $FORM->conf('DEFAULT_DAYS') // 30;
my $startDate = qx(date -d "$delay days ago" +%F);
chomp($startDate);
my ($y1,$m1,$d1) = split(/-/,$startDate);

# ---- specific FORMS inits ----------------------------------
my @html;
my @csv;
my $s = '';
my $i = 0;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $FORM->conf('NAME')."_$endDate.csv";

my $ask_start = $FORM->conf('STARTING_DATE');

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

$QryParm->{'y1'}       //= $y1; 
$QryParm->{'m1'}       //= $m1; 
$QryParm->{'d1'}       //= $d1; 
$QryParm->{'y2'}       //= $year; 
$QryParm->{'m2'}       //= $month; 
$QryParm->{'d2'}       //= $day; 
$QryParm->{'node'}     //= "All"; 
$QryParm->{'affiche'}  //= ""; 
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

# ---- Read the data file 
#

# --- connecting to the database
my $dbh = connectDbForms();

my $tbl = lc($form);
my $stmt = qq(select rowid,* from $tbl;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

my $nbData = 0;
my @lignes;
while(my @row = $sth->fetchrow_array()) {
	$nbData++;
	push(@lignes, \@row);
}

$dbh->disconnect();

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
	#if ($clientAuth > 1) {
		my $form_url = URI->new("/cgi-bin/".$FORM->conf('CGI_FORM'));
		$form_url->query_form('form' => $form, 'id' => $nbData, 'return_url' => $return_url, 'action' => 'new');
		print qq(<input type="button" style="margin-left:15px;color:blue;font-weight:bold"),
			qq( onClick="document.location='$form_url?form=$form'" value="$__{'Enter a new record'}">);
	#}
	print("<BR>\n");
	print "</B></P></FORM>\n",
	"<H2>".$FORM->conf('TITLE')."</H2>\n",
	"<P>";
}

# ---- Displaying data 
#
my $entete;
my $pied;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $aliasSite;

my $fs_count  = $FORM->conf('FIELDSETS_NUMBER');
my @fieldsets = extract_fiedlsets($fs_count);
my @fs_names;
my %colspan;
my @inputs;

foreach(@fieldsets) {
	push(@fs_names, $FORM->conf("$_\_NAME"));
	my $nb_col = $FORM->conf("$_\_COLUMNS");
	my @fieldset;
	for (my $i = 0; $i <= $nb_col; $i++) {
		push(@fieldset, split(/,/, $FORM->conf("$_\_C0".$i)));
	}
	push(@inputs, \@fieldset);
}

my @colnam = ("Date","Site");
my @colnam2;
for (my $i = 0; $i <= $#fs_names; $i++) {
	push(@colnam, $fs_names[$i]);
	my $nb_inputs = $#{$inputs[$i]};
	$colspan{$fs_names[$i]} = $nb_inputs+1;
	for (my $j = 0; $j <= $nb_inputs; $j++) {
		my $input = $inputs[$i][$j];
		my $name_input = $FORM->conf("$input\_NAME");
		my $unit_input = $FORM->conf("$input\_UNIT");
		if ($unit_input ne "") {
			push(@colnam2, "$name_input ($unit_input)");
		} else {
			push(@colnam2, $name_input);
		}
	}
}
#print @colnam2;

$entete = "<TR>";
#if ($clientAuth > 1) {
	$entete = $entete."<TH rowspan=2></TH>";
#}

foreach(@colnam) { 
	$entete .= "<TH ".( $colspan{$_} eq "" ? "rowspan=2" : "colspan=$colspan{$_}").">$_</TH>";
}
$entete .= "<TH rowspan=2></TH></TR><TR>";
foreach(@colnam2) {
		$entete .= "<TH>".$_."</TH>";
}
$entete .= "</TR>";

my $nbLignesRetenues = 0;
for (my $j = 0; $j <= $#lignes; $j++) {
	my ($id, $date_beg, $heure_beg, $date_end, $heure_end, $site) = ($lignes[$j][0],$lignes[$j][1],$lignes[$j][2],$lignes[$j][3],$lignes[$j][4],$lignes[$j][5]);
	my $date;
	my $heure;
	if (isok($ask_start)) {
		$date = "$date_beg\T$heure_beg\Z/$date_end\T$heure_end\Z";
		$heure = "$heure_beg/$heure_end";
	} else {
		$date = "$date_beg\T$heure_beg\Z";
		$heure = $heure_beg;
	}
	$aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

	my $normSite = normNode(node=>"PROC.$site");
	if ($normSite ne "") {
		$lien = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><B>$aliasSite</B></A>";
	} else {
		$lien = "$aliasSite";
	}
	my $form_url = URI->new("/cgi-bin/".$FORM->conf('CGI_FORM'));
	$form_url->query_form('form' => $form, 'id' => $id, 'return_url' => $return_url, 'action' => 'edit');
	$modif = qq(<a href="$form_url"><img src="/icons/modif.png" title="Editer..." border=0></a>);
	$efface = qq(<img src="/icons/no.png" title="Effacer..." onclick="checkRemove($id)">);

	$texte = $texte."<TR ".($id < 1 ? "class=\"node-disabled\"":"").">";
	#if ($clientAuth > 1) {
		$texte = $texte."<TD nowrap>$modif</TH>";
	#}
	$texte = $texte."<TD nowrap>$date</TD><TD align=center>$lien&nbsp;</TD>";
	my $nb_inputs = $#{ $lignes[$j] };
	for (my $i = 6; $i <= $nb_inputs; $i++) {
		$texte = $texte."<TD align=center>$lignes[$j][$i]</TD>";
	}
	$texte = $texte."</TD><TD></TD></TR>";

	$nbLignesRetenues++;
}

push(@html,"Number of records = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
	"<P>Download a CSV text file of these data <A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?affiche=csv&y1=$QryParm->{'y1'}&m1=$QryParm->{'m1'}&d1=$QryParm->{'d1'}&y2=$QryParm->{'y2'}&m2=$QryParm->{'m2'}&d2=$QryParm->{'d2'}&node=$QryParm->{'node'}&unite=$QryParm->{'unite'}\"><B>$fileCSV</B></A></P>\n");

if ($texte ne "") {
	push(@html,"<TABLE class=\"trData\" width=\"100%\"><TR>$entete\n</TR>$texte\n<TR>$entete\n</TR></TABLE>");
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

# Open an SQLite connection to the forms database
sub connectDbForms {
	return DBI->connect("dbi:SQLite:$WEBOBS{SQL_FORMS}", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) || die "Error connecting to $WEBOBS{SQL_FORMS}: $DBI::errstr";
}

sub extract_fiedlsets {
    my $fs_count = shift;
    for (my $i = 1; $i <= $fs_count; $i++) {
        push(@fieldsets, "FIELDSET0".$i);
    }
    return @fieldsets;
}

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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
