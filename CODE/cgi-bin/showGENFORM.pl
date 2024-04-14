#!/usr/bin/perl


=head1 NAME

showGENFORM.pl

=head1 SYNOPSIS

http://..../showGENFORM.pl?.... see 'query string parameters' ...

=head1 DESCRIPTION

'GENFORM' is the generic WebObs FORM.

This script allows displaying and editing data from any proc associated to a
GENFORM form. See fedit.pl for description of configuration.

=head1 Query string parameters

=over

=item B<date selection>

time span of the data, including partial recordings.
y1= , m1= , d1=
 start date (year, month, day) included

 y2= , m2= , d2=
  end date (year, month, day) included

=item B<node=>

node to display, in the format PROC.I<procName>.I<nodeID>. If the node ID is omitted,
PROC.I<procName> will display all nodes associated to the proc 'procName'. The default
is to display all nodes associated to any proc using the form (and user having the
read authorization).

=item B<dump=>

dump=csv will download a csv file of selected data, instead of display.

=back

=cut

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
use WebObs::Users qw(clientMaxAuth);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;


# Keep the URL where the user should be returned after edition
# (this will keep the filters selected by the user)
my $return_url = $cgi->url(-query_string => 1);

my $form = $cgi->param('form');

# Stops early if not authorized
my $clientAuth = clientMaxAuth(type=>"authforms",name=>"('$form')");
die "You can't view $form reports." if ($clientAuth < 1);
my $editForm = ($clientAuth > 2 ? " <A href=\"/cgi-bin/fedit.pl?fname=$form&action=edit\"><IMG src=\"/icons/modif.png\" title=\"Edit...\" border=0></A>":"");

my $FORM = new WebObs::Form($form);

# ---- DateTime inits ----------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $day   = strftime('%d',@tod); 
my $month = strftime('%m',@tod); 
my $year  = strftime('%Y',@tod);
my $today = strftime('%F',@tod);
my $delay = $FORM->conf('DEFAULT_DAYS') // 30;
my $startDate = qx(date -d "$delay days ago" +%F);
my $endDate;
chomp($startDate);
my ($y1,$m1,$d1) = split(/-/,$startDate);

# ---- get CGI parameters
my $QryParm = $cgi->Vars;
$QryParm->{'y1'}       //= $y1; 
$QryParm->{'m1'}       //= $m1; 
$QryParm->{'d1'}       //= $d1; 
$QryParm->{'y2'}       //= $year; 
$QryParm->{'m2'}       //= $month; 
$QryParm->{'d2'}       //= $day; 
$QryParm->{'node'}     //= ""; 
$QryParm->{'trash'}    //= "0";
$QryParm->{'dump'}     //= ""; 

my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (sort keys(%Ps)) {
	if ($QryParm->{'node'} =~ /^$|^PROC\.$p(\.|$)/) { 
		push(@NODESSelList,"PROC.$p|-- {PROC.$p} $Ps{$p} --");
		my %N = $FORM->nodes($p);
		for my $n (sort keys(%N)) {
			push(@NODESSelList,"PROC.$p.$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
		}
		%Ns = (%Ns, %N);
	}
}


# ---- specific FORMS inits ----------------------------------
my @html;
my @csv;
my $s = '';
my $i = 0;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $WEBOBS{WEBOBS_ID}."_".$form."_$today.csv";

my $starting_date = isok($FORM->conf('STARTING_DATE'));

$startDate = "$QryParm->{'y1'}-$QryParm->{'m1'}-$QryParm->{'d1'} 00:00:00";
$endDate = "$QryParm->{'y2'}-$QryParm->{'m2'}-$QryParm->{'d2'} 23:59:59";

# ---- a site requested as PROC.name means "all nodes for proc 'name'"
 
my @procnodes;
if ($QryParm->{'node'} =~ /^PROC\.([^.]*)$/) {
	my %tmpN = $FORM->nodes($1);
	for (keys(%tmpN)) {
		push(@procnodes,"$_");
	}
}
if ($QryParm->{'node'} =~ /^PROC\.[^.]*\.(.*)$/) {
	push(@procnodes,"$1");
}


# ---- start html if not CSV output 

if ($QryParm->{'dump'} ne "csv") {
	print $cgi->header(-charset=>'utf-8');
	print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
	"<html><head><title>".$FORM->conf('TITLE')."</title>\n",
	"<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
	"<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n";

	print "</head>\n",
	"<body style=\"background-attachment: fixed\">\n",
	"<div id=\"waiting\">$__{'Searching for data, please wait.'}</div>\n",
	"<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
	"<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n",
	"<!-- overLIB (c) Erik Bosrup -->\n";
} else {
	push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");
}

# ---- Read the data file 
#

# --- connecting to the database
my $dbh = connectDbForms();

my $tbl = lc($form);

# get the total number or records
my $stmt = "SELECT COUNT(id) FROM $tbl";
my $sth = $dbh->prepare($stmt);
my $rv = $sth->execute() or die $DBI::errstr;
my @row = $sth->fetchrow_array();
my $nbData = join('',@row);
$sth->finish();

# get the list of columns
$stmt = "SELECT group_concat(name, '|') FROM pragma_table_info('$tbl')";
$sth = $dbh->prepare($stmt);
$rv = $sth->execute() or die $DBI::errstr;
my @rownames = split(/\|/,$sth->fetchrow_array());
$sth->finish();

# make an hash of hash of input type lists
my %lists;
foreach my $k (@rownames) {
	my $list = $FORM->conf(uc("$k")."_TYPE");
	if ($list =~ /^list:/) {
		my %l = extract_list($list,$form); 
		$lists{$k} = {%l};
	}
}

# get the requested data
my $filter = "((sdate BETWEEN '$startDate' AND '$endDate') OR (edate BETWEEN '$startDate' AND '$endDate'))";
$filter .= " AND trash = false" if (!$QryParm->{'trash'});
$filter .= " AND node IN ('".join("','",@procnodes)."')" if ($#procnodes >= 0); 
foreach (keys %lists) {
	my $sel_list = $QryParm->{$_};
	$filter .= " AND $_ = \"$sel_list\"" if ($sel_list ne "");
}
$stmt = qq(SELECT * FROM $tbl WHERE $filter;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

my @rows;
while(my @row = $sth->fetchrow_array()) {
	push(@rows, \@row);
}

$dbh->disconnect();

# ---- Form for display selection
#  
if ($QryParm->{'dump'} ne "csv") {
	print "<FORM name=\"formulaire\" action=\"/cgi-bin/showGENFORM.pl\" method=\"get\">",
		"<INPUT name=\"form\" type=\"hidden\" value=\"$form\">";
	print "<P class=\"boitegrise\" align=\"center\">",
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
	for ("|All nodes",@NODESSelList) { 
		my ($key,$val) = split (/\|/,$_);
		my $sel = ("$key" eq "$QryParm->{'node'}" ? "selected":"");
		print "<option $sel value=$key>$val</option>\n";
	}
	print "</select>";
	print " <INPUT type=\"submit\" value=\"$__{'Display'}\" style=\"font-weight:bold\">";
	if ($clientAuth > 1) {
		my $form_url = URI->new("/cgi-bin/formGENFORM.pl");
		$form_url->query_form('form' => $form, 'return_url' => $return_url, 'action' => 'new');
		print qq(<input type="button" style="margin-left:15px;color:blue;font-weight:bold"),
			qq( onClick="document.location='$form_url?form=$form'" value="$__{'Enter a new record'}">);
	}
	print("<BR>\n");
	foreach my $i (keys %lists) {
		my @key = keys %{$lists{$i}};
		print "<B>".$FORM->conf(uc($i)."_NAME").":</B>&nbsp;<SELECT name=\"$i\" size=\"1\">\n";
		print "<OPTION value=\"\"></OPTION>\n";
		foreach (@key) {
			my $sel = ($QryParm->{$i} eq $_ ? "selected":"");
			print "<OPTION value=\"$_\" $sel>$_: $lists{$i}{$_}</OPTION>\n";
		}
		print "</SELECT>\n";
	}
	if ($clientAuth > 1) {
		print "<INPUT type=\"checkbox\" name=\"trash\" value=\"1\"".($QryParm->{'trash'} ? " checked":"").">&nbsp;<B>$__{'Trash'}</B>";
	} else {
		print "<INPUT type=\"hidden\" name=\"trash\">";
	}
	print "</P></FORM>\n",
	"<H2>".$FORM->conf('TITLE')."$editForm</H2>\n",
	"<P>";
}

# ---- Displaying data 
#
my $header;
my $text;
my $csvTxt = qq("id",);
my $edit;
my $delete;
my $nodelink;
my $aliasSite;

my $fs_count  = $FORM->conf('FIELDSETS_NUMBER');
my @fieldsets = extract_fieldsets($fs_count);
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

my @colnam = ("Sampling Date","Site","Oper");
my @colnam2;
if ($starting_date) {
	$colspan{"Sampling Date"} = 2;
	push(@colnam2,("Start","End"));
	$csvTxt .= '"'.join('","', @colnam2, @colnam[1,2]).'"';
} else {
	$csvTxt .= '"'.join('","', @colnam).'"';
}

for (my $i = 0; $i <= $#fs_names; $i++) {
	push(@colnam, $fs_names[$i]);
	my $nb_inputs = $#{$inputs[$i]};
	$colspan{$fs_names[$i]} = $nb_inputs+1;
	for (my $j = 0; $j <= $nb_inputs; $j++) {
		my $input = $inputs[$i][$j];
		my $name_input = $FORM->conf("$input\_NAME");
		my $unit_input = $FORM->conf("$input\_UNIT");
		push(@colnam2, "$name_input".($unit_input ne "" ? " ($unit_input)":""));
		$name_input =~ s/(<su[bp]>|<\/su[bp]>|\&[^;]*;)//g;
		$csvTxt .= ',"'.u2l($name_input).'"';
	}
}
$csvTxt .= "\n";

$header = "<TR>".($clientAuth > 1 ? "<TH rowspan=2></TH>":"");

foreach(@colnam) { 
	$header .= "<TH ".( $colspan{$_} eq "" ? "rowspan=2" : "colspan=$colspan{$_}").">$_</TH>";
}
$header .= "<TH rowspan=2></TH></TR><TR>";
foreach(@colnam2) {
		$header .= "<TH>".$_."</TH>";
}
$header .= "</TR>";

for (my $j = 0; $j <= $#rows; $j++) {
	my ($id, $trash, $site, $edate0, $edate1, $sdate0, $sdate1, $opers, $rem, $ts0, $user) = ($rows[$j][0],$rows[$j][1],$rows[$j][2],$rows[$j][3],$rows[$j][4],$rows[$j][5],$rows[$j][6],$rows[$j][7],$rows[$j][-3],$rows[$j][-2],$rows[$j][-1]);
	$aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

	my $edate = simplify_date($edate0,$edate1);
	my $sdate = simplify_date($sdate0,$sdate1);

	my $nameSite = htmlspecialchars(getNodeString(node=>$site,style=>'html'));
	my $normSite = normNode(node=>"PROC.$site");
	if ($normSite ne "") {
		$nodelink = "<A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$normSite\"><B>$aliasSite</B></A>";
	} else {
		$nodelink = "$aliasSite";
	}
	my @operators = split(/,/,$opers);
	my @nameOper;
	foreach (@operators) {
		push(@nameOper, "<B>$_</B>: ".join('',WebObs::Users::userName($_)));
	}
	my $form_url = URI->new("/cgi-bin/formGENFORM.pl");
	$form_url->query_form('form' => $form, 'id' => $id, 'return_url' => $return_url, 'action' => 'edit');
	$edit = qq(<a href="$form_url"><img src="/icons/modif.png" title="Edit..." border=0></a>);
	$delete = qq(<img src="/icons/no.png" title="Delete..." onclick="checkRemove($id)">);

	$text .= "<TR ".($trash == 1 ? "class=\"node-disabled\"":"").">";
	if ($clientAuth > 1) {
		$text .= "<TD nowrap>$edit</TH>";
	}
	$text .= ($starting_date ? "<TD nowrap>$sdate</TD>":"")."<TD nowrap>$edate</TD>";
	$text .= "<TD nowrap align=center onMouseOut=\"nd()\" onmouseover=\"overlib('$nameSite')\">$nodelink&nbsp;</TD>";
	$text .= "<TD align=center onMouseOut=\"nd()\" onmouseover=\"overlib('".join('<br>',@nameOper)."')\">".join(', ',@operators)."</TD>";
	$csvTxt .= "$id,$sdate,$edate,\"$aliasSite\",\"$opers\",";
	my $nb_inputs = $#{ $rows[$j] };
	for (my $i = 8; $i <= $nb_inputs-3; $i++) {
		my $ov;
		if (defined $lists{$rownames[$i]}) {
			$ov = "onMouseOut=\"nd()\" onMouseOver=\"overlib('<B>$rows[$j][$i]</B>: $lists{$rownames[$i]}{$rows[$j][$i]}')\"";
		}
		$text .= "<TD align=center $ov>$rows[$j][$i]</TD>";
		$csvTxt .= "$rows[$j][$i],";
	}
	$csvTxt .= ",\"".u2l($rem)."\"\n";
	my $remTxt = "<TD></TD>";
	if ($rem ne "") {
		$remTxt = "<TD onMouseOut=\"nd()\" onMouseOver=\"overlib('".htmlspecialchars($rem)."',CAPTION,'Observations $aliasSite')\"><IMG src=\"/icons/attention.gif\" border=0></TD>";
	}
	$text .= "</TD>$remTxt</TR>";
}

if ($QryParm->{'debug'}) {
	push(@html,"<P>Columns = ".join(',',@rownames)."</P>\n");
	push(@html,"<P>Filter = $filter</P>\n");
}
push(@html,"<P>Number of records = <B>".($#rows+1)."</B> / $nbData.</P>\n");
push(@html,"<P>$__{'Download a CSV text file of these data'}: <A href=\"/cgi-bin/showGENFORM.pl?dump=csv&y1=$QryParm->{'y1'}&m1=$QryParm->{'m1'}&d1=$QryParm->{'d1'}&y2=$QryParm->{'y2'}&m2=$QryParm->{'m2'}&d2=$QryParm->{'d2'}&node=$QryParm->{'node'}&trash=$QryParm->{'trash'}&form=$form\"><B>$fileCSV</B></A></P>\n");

if ($text ne "") {
	push(@html,"<TABLE class=\"trData\" width=\"100%\"><TR>$header\n</TR>$text\n<TR>$header\n</TR></TABLE>");
}

if ($QryParm->{'dump'} eq "csv") {
	push(@csv,l2u($csvTxt));
	print @csv;
} else {
	print @html;
	print "<style type=\"text/css\">
		#waiting { display: none; }
	</style>\n
	<BR>\n</BODY>\n</HTML>\n";
}



sub simplify_date {
	my $date0 = shift;
	my $date1 = shift;
	my ($y0,$m0,$d0,$H0,$M0) = split(/[-: ]/,$date0);
	my ($y1,$m1,$d1,$H1,$M1) = split(/[-: ]/,$date1);
	my $date = "$y1-$m1-$d1 $H1:$M1";
	if ($date0 eq $date1 || $date1 eq "") { return $date0; }
	if    ($y1 ne $y0) { $date = "$y0-$y1"; }
	elsif ($m1 ne $m0) { $date = "$y1"; }
	elsif ($d1 ne $d0) { $date = "$y1-$m1"; }
	elsif ($H1 ne $H0) { $date = "$y1-$m1-$d1"; }
	elsif ($M1 ne $M0) { $date = "$y1-$m1-$d1 $H1"; }
	return $date;
}

# Open an SQLite connection to the forms database
sub connectDbForms {
	return DBI->connect("dbi:SQLite:$WEBOBS{SQL_FORMS}", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) || die "Error connecting to $WEBOBS{SQL_FORMS}: $DBI::errstr";
}

sub extract_fieldsets {
    my $fs_count = shift;
    for (my $i = 1; $i <= $fs_count; $i++) {
        push(@fieldsets, "FIELDSET0".$i);
    }
    return @fieldsets;
}

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin, François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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
