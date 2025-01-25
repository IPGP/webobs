#!/usr/bin/perl

=head1 NAME

showGENFORM.pl

=head1 SYNOPSIS

http://..../showGENFORM.pl?.... see 'query string parameters' ...

=head1 DESCRIPTION

'GENFORM' is the generic WebObs FORM.

This script allows displaying and editing data from any proc associated to a
GENFORM form. See formGRID.pl for description of configuration.

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
use File::Basename qw(basename fileparse);
use Math::Trig 'pi';
use List::Util qw[min max sum];

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw($CLIENT clientMaxAuth);
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

my %G = readForm($form);
my %FORM = %{$G{$form}};

my $title = ($FORM{NAME} ? $FORM{NAME}:$FORM{DESCRIPTION});

# ---- DateTime inits ----------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $day   = strftime('%d',@tod);
my $month = strftime('%m',@tod);
my $year  = strftime('%Y',@tod);
my $today = strftime('%F',@tod);
my $default_days = $FORM{DEFAULT_DAYS} // 30;
my ($y1,$m1,$d1) = split(/[-T]/,DateTime->today()->subtract(days => $default_days - 1));

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
$QryParm->{'debug'}    //= "";

my $re = $QryParm->{'filter'};

my @formnodes;
my %Ns;
my @NODESSelList;
for (@{$FORM{NODESLIST}}) {
    my $id = $_;
    my %N = readNode($id);
    push(@NODESSelList,"$id|$N{$id}{ALIAS}: $N{$id}{NAME}");
    %Ns = (%Ns, %N);
    push(@formnodes, $id) if ($QryParm->{'node'} =~ /^($id|)$/)
}

my @validity = split(/[, ]/, ($FORM{VALIDITY_COLORS} ? $FORM{VALIDITY_COLORS}:"#66FF66,#FFD800,#FFAAAA"));

# make a list of formulas and threshods
my @formulas;
my @thresh;
foreach (sort keys %FORM) {
    if ($_ =~ /^OUTPUT.*_TYPE/ && $FORM{$_} =~ /^formula/) {
        push(@formulas, (split /_TYPE/, $_)[0]);
    }
    if ($_ =~ /^(IN|OUT)PUT.*_THRESHOLD/) {
        push(@thresh, (split /_THRESHOLD/, $_)[0]);
    }
}

# ---- specific FORMS inits ----------------------------------
my @html;
my @csv;
my $s = '';
my $i = 0;

$ENV{LANG} = $WEBOBS{LOCALE};

my $fileCSV = $WEBOBS{WEBOBS_ID}."_".$form."_$today.csv";

my $starting_date = isok($FORM{STARTING_DATE});

my $startDate = "$QryParm->{'y1'}-$QryParm->{'m1'}-$QryParm->{'d1'} 00:00:00";
my $endDate = "$QryParm->{'y2'}-$QryParm->{'m2'}-$QryParm->{'d2'} 23:59:59";
my $delay = datediffdays($startDate,$endDate);

my $PATH_FORMDOCS = $GRIDS{SPATH_FORMDOCS} || "FORMDOCS";
my $PATH_THUMBNAILS = $GRIDS{SPATH_THUMBNAILS} || "THUMBNAILS";
my $PATH_SLIDES = $GRIDS{SPATH_SLIDES} || "SLIDES";
my $MAX_IMAGES = $GRIDS{GENFORM_THUMB_MAX_IMAGES} || 20;
my $MAX_COLS = $GRIDS{GENFORM_THUMB_MAX_COLUMNS} || 4;
my $THUMB_DISPLAYED_HEIGHT = 16;

# ---- Temporary file cleanup
if ($WEBOBS{ROOT_DATA} && $PATH_FORMDOCS && $CLIENT && $form) {
    my $path = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/.tmp/".$CLIENT."/".uc($form);
    qx(rm $path -R);
}

# ---- start html if not CSV output 

print $cgi->header(-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
  "<html><head><title>".$title."</title>\n",
  "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
  "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n";

print "</head>\n",
  "<body style=\"background-attachment: fixed\">\n",
  "<div id=\"waiting\">$__{'Searching for data, please wait.'}</div>\n",
  "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
  "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\" type=\"text/javascript\"></script>",
  "<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>",
  "<script language=\"JavaScript\" src=\"/js/wolb.js\" type=\"text/javascript\"></script>",
  "<link href=\"/css/wolb.css\" rel=\"stylesheet\" />";
  "<script language=\"JavaScript\" src=\"/js/htmlFormsUtils.js\" type=\"text/javascript\"></script>\n",
  "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>\n",
  "<!-- overLIB (c) Erik Bosrup -->\n";

print <<"EOF";
<script type="text/javascript">
<!--
function eraseFilter()
{
    document.form.filter.value = "";
}
//-->
</script>
EOF

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
    my $list = $FORM{uc("$k")."_TYPE"};
    if ($list =~ /^list:/) {
        my %l = extract_list($list,$form);
        $lists{$k} = {%l};
    }
}

# get the requested data
my $filter = "((sdate BETWEEN '$startDate' AND '$endDate') OR (edate BETWEEN '$startDate' AND '$endDate'))";
$filter .= " AND trash = false" if (!$QryParm->{'trash'});
$filter .= " AND node IN ('".join("','",@formnodes)."')" if ($#formnodes >= 0);
foreach (keys %lists) {
    my $sel_list = $QryParm->{$_};
    $filter .= " AND $_ = \"$sel_list\"" if ($sel_list ne "");
}
$filter .= " AND comment REGEXP '$re'" if ($re ne "");
$stmt = qq(SELECT * FROM $tbl WHERE $filter ORDER BY edate DESC;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

my @rows;
while(my @row = $sth->fetchrow_array()) {
    push(@rows, \@row);
}

$dbh->disconnect();

# ---- Prepare form contains
#
my @fieldsets;
my $max_columns = count_columns(keys %FORM);
foreach (map { sprintf("COLUMN%02d_LIST", $_) } (1..$max_columns)) {
    push(@fieldsets, split(/,/, $FORM{$_}));
}
my @fs_names;
my @field_names;

foreach my $f (@fieldsets) {
    push(@fs_names, $FORM{"$f\_NAME"});
    my @fieldset;
    my ($fscells,$fsdir) = split(/[, ]/,$FORM{"$f\_CELLS"});
    for (my $i = 1; $i <= $fscells; $i++) {
        my @fields;
        foreach (split(/,/, $FORM{sprintf("$f\_C%02d",$i)})) {
            my ($size, $default) = extract_type($FORM{$_."_TYPE"});
            if ($size ne "0" && ! ($_ =~ /^OUTPUT/ && $FORM{$_."_TYPE"} =~ /^text/)) {
                push(@fields, $_);
            }
        }
        push(@fieldset, @fields);
    }
    push(@field_names, \@fieldset);
}

# ---- Form for display selection
#

print "<FORM name=\"form\" action=\"/cgi-bin/showGENFORM.pl\" method=\"get\">",
  "<INPUT name=\"form\" type=\"hidden\" value=\"$form\">";
print "<P class=\"boitegrise\" align=\"center\">",
  "<TABLE width=\"100%\"><TR><TD style=\"border:0;text-align:center\">",
  "<B>$__{'Start Date'}:</B> ";
print "<SELECT name=\"y1\" size=\"1\">\n";
for ($FORM{BANG}..$year) { print "<OPTION value=\"$_\"".($QryParm->{'y1'} eq $_ ? " selected":"").">$_</OPTION>\n" }
print "</SELECT>\n";
print "<SELECT name=\"m1\" size=\"1\">\n";
for ("01".."12") { print "<OPTION value=\"$_\"".($QryParm->{'m1'} eq $_ ? " selected":"").">$_</OPTION>\n" }
print "</SELECT>\n";
print "<SELECT name=\"d1\" size=\"1\">\n";
for ("01".."31") { print "<OPTION value=\"$_\"".($QryParm->{'d1'} eq $_ ? " selected":"").">$_</OPTION>\n" }
print "</SELECT>\n";
print "&nbsp;&nbsp;<B>$__{'End Date'}:</B> ";
print "<SELECT name=\"y2\" size=\"1\">\n";
for ($FORM{BANG}..$year) { print "<OPTION value=\"$_\"".($QryParm->{'y2'} eq $_ ? " selected":"").">$_</OPTION>\n" }
print "</SELECT>\n";
print "<SELECT name=\"m2\" size=\"1\">\n";
for ("01".."12") { print "<OPTION value=\"$_\"".($QryParm->{'m2'} eq $_ ? " selected":"").">$_</OPTION>\n" }
print "</SELECT>\n";
print "<SELECT name=\"d2\" size=\"1\">\n";
for ("01".."31") { print "<OPTION value=\"$_\"".($QryParm->{'d2'} eq $_ ? " selected":"").">$_</OPTION>\n" }
print "</SELECT>\n";
print "&nbsp;&nbsp;<select name=\"node\" size=\"1\">";
for ("|$__{'All nodes'}",@NODESSelList) {
    my ($key,$val) = split (/\|/,$_);
    my $sel = ("$key" eq "$QryParm->{'node'}" ? "selected":"");
    print "<option $sel value=$key>$val</option>\n";
}
print "</select>";
print "<BR>\n";
print " \n";
foreach my $i (sort keys %lists) {
    if (isok($FORM{uc($i)."_FILT"})) {
        my @key = keys %{$lists{$i}};
        print "<B>".$FORM{uc($i)."_NAME"}.":</B>&nbsp;<SELECT name=\"$i\" size=\"1\">\n";
        print "<OPTION value=\"\"></OPTION>\n";
        my $nam;
        foreach (sort @key) {
            if (ref $lists{$i}{$_}) {
                $nam = ($lists{$i}{$_}{name} ? $lists{$i}{$_}{name}:$_);
            } else {
                $nam = ($lists{$i}{$_} ? $lists{$i}{$_}:$_);
            }
            my $sel = ($QryParm->{$i} eq $_ ? "selected":"");
            print "<OPTION value=\"$_\" $sel>$_: $nam</OPTION>\n";
        }
        print "</SELECT>\n";
    }
}
foreach (@fieldsets) {
    if (isok($FORM{$_.'_TOGGLE'})) {
        my $fs = lc($_);
        print " <INPUT type=\"checkbox\" name=\"$fs\" value=\"1\"".($QryParm->{$fs} ? " checked":"").">&nbsp;<B>$FORM{$_.'_NAME'}</B>";
    }
}

print "</TD><TD style=\"border:0;text-align:center\">";
print "<IMG src=\"/icons/search.png\">&nbsp;<INPUT name=\"filter\" type=\"text\" size=\"10\" value=\"$re\">";
if ($re ne "") {
    print "<img style=\"border:0;vertical-align:text-bottom\" src=\"/icons/cancel.gif\" onClick=eraseFilter()>";
}
if ($clientAuth > 1) {
    print "<BR><INPUT type=\"checkbox\" name=\"trash\" value=\"1\"".($QryParm->{'trash'} ? " checked":"").">&nbsp;<B>$__{'Trash'}</B>";
} else {
    print "<INPUT type=\"hidden\" name=\"trash\">";
}
print "</TD><TD style=\"border:0;text-align:center\">";
print "<INPUT type=\"submit\" value=\"$__{'Display'}\">";
print "</TD></TR></TABLE></P></FORM>\n",
  "<H1 style=\"margin-bottom:6pt\">$title</H1>\n",
  "<DIV id='selbanner' style='background-color: beige; padding: 5px; margin-bottom:10px'>",
  "<B>»»</B> [ <A href=\"/cgi-bin/showGRID.pl?grid=FORM.$form\"><B>Form</B></A>";
if (-d "$WEBOBS{ROOT_OUTG}/FORM.$form/$WEBOBS{PATH_OUTG_MAPS}") {
    print " | <B><A href=\"/cgi-bin/showOUTG.pl?grid=FORM.$form&ts=map\">Map</A></B>";
}
print " | <A href=\"#download\">$__{'Download data'}</A> ]</DIV>\n<P>";

# ---- Displaying data
#
my $header;
my $text;
my $csvTxt = qq("id",);
my $edit;
my $delete;
my $nodelink;
my $aliasSite;

my @colnam = ("Sampling Date","Site","Oper");
my @colnam2;
my %colspan;
if ($starting_date) {
    $colspan{"Sampling Date"} = 2;
    push(@colnam2,("Start","End"));
    $csvTxt .= '"'.join('","', @colnam2, @colnam[1,2]).'"';
} else {
    $csvTxt .= '"'.join('","', @colnam).'"';
}

for (my $i = 0; $i <= $#fs_names; $i++) {
    my $fs = $fieldsets[$i];
    my $showfs = ((!isok($FORM{$fs.'_TOGGLE'}) || $QryParm->{lc($fs)}) ? "1":"0");
    push(@colnam, $fs_names[$i]) if ($showfs);
    my $nb_fields = $#{$field_names[$i]};
    $colspan{$fs_names[$i]} = $nb_fields+1;
    for (my $j = 0; $j <= $nb_fields; $j++) {
        my $field = $field_names[$i][$j];
        my $name_field = $FORM{"$field\_NAME"};
        my $unit_field = $FORM{"$field\_UNIT"};
        $unit_field = ($unit_field ne "" ? " ($unit_field)":"");
        push(@colnam2, htm2frac($name_field).$unit_field) if ($showfs);
        $name_field =~ s/<su[bp]>|<\/su[bp]>|\&[^;]*;//g; # removes HTML tags or characters
        $csvTxt .= ',"'.$name_field.$unit_field.'"';
    }
}
$csvTxt .= "\n";

# makes the table header
$header = "<TR>";
if ($clientAuth > 1) {
    my $form_url = URI->new("/cgi-bin/formGENFORM.pl");
    $form_url->query_form('form' => $form, 'site' => $QryParm->{'node'}, 'return_url' => $return_url, 'action' => 'new');
    $header .= "<TH rowspan=2><A href=\"$form_url\"><IMG src=\"/icons/new.png\" border=\"0\" title=\"$__{'Enter a new record'}\"></A></TH>\n";
}
foreach(@colnam) {
    $header .= "<TH ".( $colspan{$_} eq "" ? "rowspan=2" : "colspan=$colspan{$_}").">$_</TH>\n";
}
$header .= "<TH rowspan=2></TH></TR>\n";
foreach(@colnam2) {
    $header .= "<TH>".$_."</TH>\n";
}
$header .= "</TR>\n";

for (my $j = 0; $j <= $#rows; $j++) {
    my ($id, $trash, $quality, $site, $edate0, $edate1, $sdate0, $sdate1, $opers, $rem, $ts0, $user) = ($rows[$j][0],$rows[$j][1],$rows[$j][2],$rows[$j][3],$rows[$j][4],$rows[$j][5],$rows[$j][6],$rows[$j][7],$rows[$j][8],$rows[$j][9],$rows[$j][10],$rows[$j][11]);

    # makes a hash of all fields values (input and output)
    my %fields;

    # stores input db rows
    for (my $i = 8; $i <= $#{$rows[$j]}; $i++) {
        $fields{$rownames[$i]} = $rows[$j][$i];
    }

    # stores formulas
    foreach (@formulas) {
        my ($formula, $size, @x) = extract_formula($FORM{$_."_TYPE"});
        my $nan = 0;
        foreach (@x) {
            my $f = lc($_);
            $formula =~ s/$_/\$fields{$f}/g;
        }
        my $res = eval($formula);
        if ($res ne "") {
            if ($size > 0) {
                $fields{lc($_)} = roundsd($res, $size - 3); # results is rounded with $size-3 digits
            } else {
                $fields{lc($_)} = $res; # hidden formula
            }
        } else {
            $fields{lc($_)} = "";
        }
    }

    $aliasSite = $Ns{$site}{ALIAS} ? $Ns{$site}{ALIAS} : $site;

    my $edate = simplify_date($edate0,$edate1);
    my $sdate = simplify_date($sdate0,$sdate1);

    my $nameSite = htmlspecialchars(getNodeString(node=>$site,style=>'html'));
    my $normSite = "FORM.$form.$site";
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

    $text .= "<TR".($trash == 1 ? " class=\"inTrash\"":"").">";
    if ($clientAuth > 1) {
        $text .= "<TH nowrap>$edit</TH>";
    }
    $text .= ($starting_date ? "<TD nowrap>$sdate</TD>":"")."<TD nowrap>$edate</TD>";
    $text .= "<TD nowrap align=center onMouseOut=\"nd()\" onmouseover=\"overlib('$nameSite',CAPTION,'$site')\">$nodelink&nbsp;</TD>\n";
    $text .= "<TD align=center onMouseOut=\"nd()\" onmouseover=\"overlib('".join('<br>',@nameOper)."')\">".join(', ',@operators)."</TD>\n";
    $csvTxt .= "$id".($starting_date ? ",\"$sdate\"":"").",\"$edate\",\"$aliasSite\",\"$opers\",";
    for (my $f = 0; $f <= $#fieldsets; $f++) {
        my $fs = $fieldsets[$f];
        my $nb_fields = $#{$field_names[$f]};
        for (my $n = 0; $n <= $nb_fields; $n++) {
            my $Field = $field_names[$f][$n];
            my $field = lc($Field);
            my $opt;
            my $val = $fields{$field};
            my $hlp;
            if (defined $lists{$field}) {
                if (ref $lists{$field}{$fields{$field}}) {
                    my %v = %{$lists{$field}{$fields{$field}}}; # list is a HoH
                    $hlp = "<B>$fields{$field}</B>: $v{name}";
                    if ($v{icon}) {
                        $val = "<IMG src=\"$v{icon}\">";
                    }
                } else {
                    $hlp = "<B>$fields{$field}</B>: $lists{$field}{$fields{$field}}";
                }
                $hlp = "<I>$__{'unknown key list!'}</I>" if ($val eq "");
                $opt = "onMouseOut=\"nd()\" onMouseOver=\"overlib('$hlp')\"";
            }
            if (grep(/^$field$/i, @formulas)) {
                $opt = " class=\"tdResult\" onMouseOut=\"nd()\" onMouseOver=\"overlib('<B>$field</B>:')\"";
            }
            if (grep(/^$Field$/, @thresh) ) {
                my @tv = split(/[, ]/,$FORM{$Field."_THRESHOLD"});
                if (abs($fields{$field}) >= $tv[0] && abs($fields{$field}) < $tv[1]) {
                    $opt .= " style=\"background-color:$validity[1]\"";
                } elsif (abs($fields{$field}) >= $tv[1]) {
                    $opt .= " style=\"background-color:$validity[2]\"";
                }
            }
            if ($FORM{$Field."_TYPE"} =~ /^image/) {
                my $img_id = uc($form."/record".$id."/".$Field);
                my @listeTarget = <"$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/$img_id"/*.*> ;
                my $pathSource = "/data/$PATH_FORMDOCS/$img_id";
                $val = "<table>";
                foreach my $index (0..$#listeTarget) {
                    my $olmsg = "Click to enlarge ".($index+1)." / ".scalar(@listeTarget);
                    my ( $name, $path, $extension ) = fileparse ( $listeTarget[$index], '\..*' );
                    my $urn = "$pathSource/$PATH_SLIDES/$name$extension.jpg";
                    my $Turn = "$pathSource/$PATH_THUMBNAILS/$name$extension.jpg";
                    if ($index % $MAX_COLS == 0) { $val .= "<tr>"; }
                    $val .= $index+1 > $MAX_IMAGES ? qq(<td style="display:none;">) : "<td>";
                    $val .= qq(<img height=$THUMB_DISPLAYED_HEIGHT wolbset=SLIDES index=$index wolbsrc=$urn src=$Turn onMouseOver=\"overlib('$olmsg')\"></td>);
                    if ($index % $MAX_COLS + 1 == 0) { $val .= "</tr>"; }
                }
                $val .= "</table>";
                if ($#listeTarget+1 > $MAX_IMAGES) { $val .= "<br><b>... </b><i>gallery limited to ".$MAX_IMAGES." images</i>"; }
            }
            $text .= "<TD align=center $opt>$val</TD>\n" if (!isok($FORM{$fs.'_TOGGLE'}) || $QryParm->{lc($fs)});
            if ($FORM{$Field."_TYPE"} =~ /^numeric|^$/) {
                $csvTxt .= "$fields{$field},";
            } else {
                $csvTxt .= "\"$fields{$field}\",";
            }
        }
    }
    $csvTxt .= ",\"".$rem."\"\n";
    my $remTxt = "<TD></TD>";
    if ($rem ne "") {
        $remTxt = "<TD onMouseOut=\"nd()\" onMouseOver=\"overlib('".htmlspecialchars($rem,$re)."',CAPTION,'Observations $aliasSite')\"><IMG src=\"/icons/attention.gif\" border=0></TD>";
    }
    $text .= "</TD>$remTxt</TR>\n";
}

if ($QryParm->{'debug'}) {
    print("<H3>Debug</H3><UL>
    <LI>y1 = ".$QryParm->{'y1'}.", m1 = ".$QryParm->{'m1'}.", d1 = ".$QryParm->{'d1'}."</LI>
    <LI>startDate = $startDate, endDate = $endDate, default days = $FORM{DEFAULT_DAYS}</LI>
    <LI>Conf = ".join(',',sort keys %FORM)."</LI>
    <LI>Columns = ".join(',',@rownames)."</LI>
    <LI>Formulas = ".join(',',@formulas)."</LI>
    <LI>Fieldsets = ".join(',',@fieldsets)."</LI>
    <LI>Field names = ".join(";", map { join(",", @$_) } @field_names)."</LI>
    <LI>Filter = $filter</LI>
    </UL>\n");
}
push(@html,"<P>$__{'Genform code'}: <B class='code'>FORM.$form</B><BR>\n");
push(@html,"$__{'Date interval'} = <B>$delay days.</B><BR>\n");
push(@html,"$__{'Number of records'} = <B>".($#rows+1)."</B> / $nbData.</P>\n");

# displays all lists explicitely
my $listoflist = "<BR><BR><div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#listID');\">&nbsp;&nbsp;";
$listoflist .= "$__{'Lists'}\n";
$listoflist .= "</div><div id=\"listID\"><UL>";
foreach my $i (sort keys %lists) {
    my @key = keys %{$lists{$i}};
    my @kv;
    my $nam;
    foreach (sort @key) {
        if (ref $lists{$i}{$_}) {
            $nam = ($lists{$i}{$_}{name} ? $lists{$i}{$_}{name}:$_);
        } else {
            $nam = ($lists{$i}{$_} ? $lists{$i}{$_}:$_);
        }
        push(@kv, "<B>$_</B> = $nam");
    }
    $listoflist .= "<LI><I>".$FORM{uc($i)."_NAME"}.":</I> ".join(", ", @kv)."</LI>\n";
}
$listoflist .= "</UL>\n</div></div>";

# displays all formulas explicitely
my $listofformula = "<BR><BR><div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#formulaID');\">&nbsp;&nbsp;";
$listofformula .= "$__{'Formulas'}\n";
$listofformula .= "</div><div id=\"formulaID\"><UL>";
foreach (@formulas) {
    my ($formula, $size, @x) = extract_formula($FORM{$_."_TYPE"});
    my $name = $FORM{$_."_NAME"};
    my $unit = ($FORM{$_."_UNIT"} ne "" ? " (".$FORM{$_."_UNIT"}.")":"");
    foreach (@x) {
        my $v = $FORM{$_."_NAME"};
        $formula =~ s/$_/<b>$v<\/b>/g;
    }
    $listofformula .= "<LI><B>$name</B>$unit = $formula</LI>\n";
}
$listofformula .= "</UL>\n</div></div>";

$csvTxt =~ s/'/&#39;/g; # escapes any single quote
push(@csv,$csvTxt);

push(@html,"<TABLE class=\"trData\" width=\"100%\">$header\n$text".($text ne "" ? "\n$header\n":"")."</TABLE>\n$listoflist\n$listofformula");
push(@html, qq(<hr><a name="download"></a><form action="/cgi-bin/postFormData.pl?form=$form" method="post">
<input type="submit" value="$__{'Download a CSV text file of these data'}">
<input type="hidden" name="form" value=$form>
<input type="hidden" name="csv" value='@csv'>
<span" title="$__{'Include associated form data (files, images,...)'}"><input type="checkbox" name="all">&nbsp;$__{'Include associated form data'}</span>
</form>));

print @html;
print "<style type=\"text/css\">
    #waiting { display: none; }
</style>\n
<BR>\n</BODY>\n</HTML>\n";

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

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin, François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2025 - Institut de Physique du Globe Paris

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
