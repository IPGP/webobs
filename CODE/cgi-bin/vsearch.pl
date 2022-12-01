#!/usr/bin/perl

=head1 NAME

vsearch.pl

=head1 SYNOPSIS

http://..../vsearch.pl?target=type.grid[.node]&str=text&in=category&lop=[AND|OR]&str2=text&in2=category&sort=category&max=maxres&from=firstresnb

=head1 DESCRIPTION

Search for a B<text string> into node events, selecting one B<category> and sorting results Create or update or delete an B<event> file or B<Project> file of a grid or node. Possibility to add a second B<text string> and B<category> using logical operator B<AND> or B<OR>.
See WebObs/Events.pm for a description of the events-directories structures.

=over

=item B<target=type.grid[.node]>

When specified, search events only into a single grid (proc or view) or single node.

=item B<str=search text string>

Text string to be searched (regex for any category but author/remote user)

=item B<in=category>

	{ notebook | author | remote | alias | grid | feature | startdate | enddate | title | comment | outcome }

B<notebook> is notebook number.

B<author> is author and remote operator list.

B<alias> is node ALIAS.

B<grid> is grid type and name, or full referenced node ID (grid.name.node).

B<feature> is node features list.

B<startdate> is start date and time, full or partial syntax yyyy-mm-dd HH:MM.

B<enddate> is end date and time, full or partial syntax yyyy-mm-dd HH:MM.

B<title> is event title line.

B<comment> is event comment multi-lines text.

B<outcome> is sensor/data outcome flag (0 or 1).

The list of available categories is defined by EVENT_SEARCH_CATEGORY_LIST in CONF/NODES.rc

=item B<str2=search text string>

Text string to be searched as second criteria (regex for any category but author/remote user)

=item B<in2=category>

=item B<lop=[AND|OR]>

=item B<sort=category>


=item B<max=maxres>

maxres is maximum number of event to be displayed in the results page.
The list of available numbers is defined by EVENT_SEARCH_MAXDISPLAY_LIST in CONF/NODES.rc


=item B<from=firstresnb>

firstresnb is the index of first result to be displayed.

=back

=cut

use strict;
use warnings;
use Time::Piece;
use File::Basename;
use Switch;
use List::Util qw[min max];
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff ----------------------------------
use WebObs::Config;
use WebObs::Events;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# ---- what are we here for ? can we do it ?
#
my $me = $ENV{SCRIPT_NAME};
my $query = $ENV{QUERY_STRING};
my $QryParm   = $cgi->Vars;

my $target = $QryParm->{'target'} // "";
my $str    = $QryParm->{'str'}    // "";
my $in     = $QryParm->{'in'}     // $NODES{EVENT_SEARCH_DEFAULT};
my $lop    = $QryParm->{'lop'}    // "AND";
my $str2   = $QryParm->{'str2'}   // "";
my $in2    = $QryParm->{'in2'}    // $NODES{EVENT_SEARCH_DEFAULT2};
my $sort   = $QryParm->{'sort'}   // "startdatedec";
my $max    = $QryParm->{'max'}    // "15";
my $from   = $QryParm->{'from'}   // "1";
my $showg  = $QryParm->{'showg'}  // "";
my $shown  = $QryParm->{'shown'}  // "";
my $dump   = $QryParm->{'dump'}   // "";

# predefined lists
my @catlist = split(/,/,$NODES{EVENT_SEARCH_CATEGORY_LIST});
if ($#catlist < 0) {
	@catlist = split(/,/,"grid,alias,feature,author,remote,startdate,title,comment,notebook,outcome");
}
my %category = (
	"grid"      => $__{'Grid Name'},
	"alias"     => $__{'Node Alias/Name'},
	"feature"   => $__{'Node Feature'},
	"author"    => $__{'Author'},
	"remote"    => $__{'Remote Operator'},
	"startdate" => $__{'Start Date'},
	"enddate"   => $__{'End Date'},
	"title"     => $__{'Event Title'},
	"comment"   => $__{'Comment/Observation'},
	"notebook"  => $__{'Notebook #'},
	"outcome"   => $__{'Sensor Outcome'},
);
# removes category notebook if option is not set
delete $category{"notebook"} if (!isok($NODES{EVENTNODE_NOTEBOOK}));

my %catdisplay;
foreach my $n (0..$#catlist) {
	if (defined $category{$catlist[$n]}) {
		$catdisplay{sprintf("%02d|%s", $n, $catlist[$n])} = $category{$catlist[$n]};
	}
}

my %sortlist = (
	"startdateinc"  => $__{'Start Date - increasing'},
	"startdatedec"  => $__{'Start Date - decreasing'},
);

my @maxlist = ("15","50","100");
@maxlist = split(/,/,$NODES{EVENT_SEARCH_MAXDISPLAY_LIST}) if ($NODES{EVENT_SEARCH_MAXDISPLAY_LIST} ne "");

my $mmd = $WEBOBS{WIKI_MMD} // 'YES';        # add MMD

my $pagetitle = $__{'Search Node Events'};

my @html;
my @csv;

# ---- read and search for matching events then store list of event filenames sorted as requested
my @events1;
my @events2;
my @events;
my @lines;
my ($evfname,$node,$date1,$time1,$version);

if ($str ne "") {
	@events1 = searchEvents($target,$str,$in);
}
if ($str2 ne "") {
	@events2 = searchEvents($target,$str2,$in2);
	if ($lop eq "OR") {
		# simply appends the two requests
		push(@events1,@events2);
	}
}

# ---- must remove NODES that are not associated to readable GRIDS by user
my %NG = listNodeGrids;
foreach(@events1) {
	$evfname = $_;
	my $fname = basename($evfname);
	($node,$date1,$time1,$version) = split(/_/,basename(split(/\./,$fname)));
	my $ok = 0;
	foreach(@{$NG{$node}}) {
		my ($GRIDType,$GRIDName) = split(/\./,$_);
		$ok = 1 if (clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName"));
	}
	# avoid duplicates and keeps only vents common to the 2 requests in case of AND logical operator
	if (! grep(/$fname/,@events) && ($lop ne "AND" || $str2 eq "" || grep(/$fname/,@events2))) {
		push(@events,$evfname);
	}
}

# ---- sort events
@events = sort sort_by_date @events;
@events = reverse(@events) if ($sort eq "startdateinc");

$from = ($#events+1) if (($from - 1) > $#events);
my $maxdisp = $max;
$maxdisp = ($#events + 2 - $from) if (($from + $max - 1) > $#events);

# ---- html page
print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/vsearch.css\">
<TITLE>$pagetitle</TITLE>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" onLoad=\"document.theform.str.focus()\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- markitup -->
<script type=\"text/javascript\" src=\"/js/markitup/jquery.markitup.js\"></script>
<script type=\"text/javascript\" src=\"/js/markitup/sets/wiki/set.js\"></script>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/skins/markitup/style.css\" />
<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/wodp.css\">
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/wodp.js\"></script>
";

print "<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>";

print "<A NAME=\"MYTOP\"></A>";
print "\n<H1>$pagetitle</H1>\n";

# form part
print "<FORM name=\"theform\" id=\"theform\" action=\"$me\" method=\"get\">";
	print "<TABLE width=\"100%\" style=\"border:1 solid darkgray\"><TR>";
	print "<TH style=\"text-align:right; border: none;\">";
	print "<B>$__{'Search for'}:</B> <INPUT  size=\"20\" name=\"str\" id=\"str\" value=\"$str\">&nbsp;&nbsp;";
	print "<B>$__{'in'}: </B><SELECT size=\"1\" name=\"in\" id=\"in\"> ";
	foreach (sort(keys(%catdisplay))) {
		my ($n,$k) = split(/\|/,$_);
		print "<OPTION value=\"$k\"".($k eq $in ? " selected":"").">$catdisplay{$_}</OPTION>";
	}
	print "</SELECT><BR>\n";
	print "<SELECT size=\"1\" name=\"lop\" id=\"lop\">";
	foreach ("AND","OR") {
		print "<OPTION value=\"$_\"".($_ eq $lop ? " selected":"").">$__{$_}</OPTION>";
	}
	print "</SELECT>&nbsp;&nbsp;\n";
	print "<INPUT  size=\"20\" name=\"str2\" id=\"str2\" value=\"$str2\">&nbsp;&nbsp;";
	print "<B>$__{'in'}: </B><SELECT size=\"1\" name=\"in2\" id=\"in2\"> ";
	foreach (sort(keys(%catdisplay))) {
		my ($n,$k) = split(/\|/,$_);
		print "<OPTION value=\"$k\"".($k eq $in2 ? " selected":"").">$catdisplay{$_}</OPTION>";
	}
	print "</SELECT></TH>\n";
	print "<TH style=\"border: none;\">";
	print "<B>$__{'sorted by'}: </B><SELECT size=\"1\" name=\"sort\" id=\"sort\"> ";
	foreach (keys(%sortlist)) {
		print "<OPTION value=\"$_\"".($_ eq $sort ? " selected":"").">$sortlist{$_}</OPTION>";
	}
	print "</SELECT><BR>\n";
	print "Show: <INPUT type=\"checkbox\" name=\"showg\"".($showg ? " checked":"")."> grids";
	print "&nbsp;&nbsp;<INPUT type=\"checkbox\" name=\"shown\"".($shown ? " checked":"")."> node's name";
	print "</TH>\n";
	print "<TH style=\"border: none;\">";
	print "<B>$__{'max diplayed'}: </B><SELECT size=\"1\" name=\"max\" id=\"max\"> ";
	foreach (@maxlist) {
		print "<OPTION value=\"$_\"".($_ eq $max ? " selected":"").">$_</OPTION>";
	}
	print "</SELECT></TH><TH style=\"border: none;\">";
	if ($from > 1) {
		my $prev = max(1,$from - $max);
		my $qr = $query;
		$qr =~ s/from=[0-9]*/from=$prev/;
		print "<A href=\"$me?$qr\"><IMG src=\"/icons/ll13.png\" border=0></A>";
	}
	print "</TH><TH style=\"border: none;\">$from - ".($from + $maxdisp - 1)." / ".($#events + 1)."<TH style=\"border: none;\">";
	if ($from + $maxdisp - 2 < $#events) {
		my $next = min($#events + 1,$from + $max);
		my $qr = $query;
		$qr =~ s/from=[0-9]*/from=$next/;
		print "<A href=\"$me?$qr\"><IMG src=\"/icons/rr13.png\" border=0></A>";
	}
	print "</TH>\n<TH style=\"border: none;\"><INPUT type=\"button\" name=\"cancel\" value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\"> ";
	print "<INPUT type=\"submit\" style=\"font-weight:bold\" value=\"$__{'Search'}\" onClick=\"theform.from.value=1\"></TH>\n";
	print "</TR></TABLE>\n";
	print "<INPUT type=\"hidden\" name=\"from\" value=\"$from\">\n";
print "</FORM>\n";

print "<DIV id=\"attente\">$__{'Searching for the data... please wait'}.</DIV>";

# builds the html string
push(@html,"<TABLE width=\"100%\"><TR><TH></TH>");
foreach (sort(keys(%catdisplay))) {
	my ($n,$k) = split(/\|/,$_);
	push(@html,"<TH>$catdisplay{$_}</TH>") if ($_ != 0 || $showg);
}
push(@html,"<TH></TH></TR>\n");

# result part : will read and display only the needed events
my @finalevents = @events[$from-1 .. ($from + $maxdisp)-2];
#print "<H3>".join("<br>",@finalevents)."</H3>";

if ($#finalevents < 0 || $finalevents[0] eq "") {
	@finalevents = ();
	push(@html,"<TR><TD colspan=\"".(keys(%catdisplay) + 2)."\"><H3>No match.</H3></TD></TR>\n");
}

my %G = WebObs::Grids::listNameGrids;

my $n = 0;
foreach(@finalevents) {
	$evfname = $_;
	my $evrel = $evfname;
	$evrel =~ s/.*$NODES{SPATH_INTERVENTIONS}\///g;
	my ($fname,$fext) = split(/\./,basename($evfname));
	($node,$date1,$time1,$version) = split(/_/,basename($fname));
	$time1 =~ s/-/:/;
	$time1 =~ s/NA//;

	# checks attached photos
	my @attach;
	my $dp = $evfname;
	$dp =~ s/\.txt/\/PHOTOS/g;
	if (-d $dp) {
		opendir my $dh, $dp;
		@attach = grep {!/^\./} readdir $dh;
		closedir $dh;
	}

	@lines = readFile("$evfname");
	my ($aa,$ar,$title,$date2,$time2,$feature,$channel,$outcome,$notebook,$notebookfwd) = WebObs::Events::headersplit($lines[0]);
	my @authors = WebObs::Users::userName(@$aa);
	my @remotes = WebObs::Users::userName(@$ar);
	shift(@lines); # shift header line
	my $comment = wiki2html(join("",@lines));
	shift(@lines) if (grep($lines[0],'^WebObs:')); # shift Wiki/MMD metadata
	chomp(@lines);
	my $commentcsv = join(" • ",@lines);
	my %N = readCfg("$NODES{PATH_NODES}/$node/$node.cnf");
	my @nodes;
	foreach(@{$NG{$node}}) {
		push(@nodes,"<A href=\"/cgi-bin/vedit.pl?object=$_.$node&event=$evrel&action=upd\"><IMG src=\"/icons/modif.png\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></A>");
	}

	my $tds = " class=\"td$n\"";

	# highlights results
	my $hauthors = join("<BR>",@authors);
	my $hremotes = join("<BR>",@remotes);
	my $hfeature = $feature;
	my $hdate1 = $date1;
	my $hdate2 = $date2;
	my $htitle = $title;
	if ($str ne "") {
		$hauthors =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "author");
		$hremotes =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "remote");
		$hfeature =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "feature");
		$hdate1 =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "startdate");
		$hdate2 =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "enddate");
		$htitle =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "title");
		$comment =~ s/($str)/<SPAN class="sr1">\1<\/SPAN>/ig if ($in eq "comment");
	}
	if ($str2 ne "") {
		$hauthors =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "author");
		$hremotes =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "remote");
		$hfeature =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "feature");
		$hdate1 =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "startdate");
		$hdate2 =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "enddate");
		$htitle =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "title");
		$comment =~ s/($str2)/<SPAN class="sr2">\1<\/SPAN>/ig if ($in2 eq "comment");
	}

	push(@html,"<TR>");
	#[FB]: possibility to display all edit links (procs and views)
	#print "<TD $tds>".join("<BR>",@nodes)."</TD>";
	push(@html,"<TD $tds>".join("<BR>",$nodes[0])."</TD>");

	my @csvf;
	foreach (sort(keys(%catdisplay))) {
		my ($n,$k) = split(/\|/,$_);
		switch ($k) {
			case "grid"      {
				my @grids;
				my @gridscsv;
				foreach (@{$NG{$node}}) {
					push(@grids,"<A href=\"/cgi-bin/showGRID.pl?grid=$_\" title=\"$_\">$G{$_}</A>");
					push(@gridscsv,$G{$_});
				}
				push(@html,"<TD $tds nowrap>".join("<BR>",@grids)."</TD>") if ($showg);
				push(@csvf,"\"".join(",",@gridscsv)."\"");
			}
			case "alias"     {
				my @alias;
				my @aliascsv;
				foreach (@{$NG{$node}}) {
					push(@alias,"<A href=\"/cgi-bin/showNODE.pl?node=$_.$node#$evrel\" title=\"$_.$node\">$N{ALIAS}</A>".($shown ? " $N{NAME}":"")."");
					push(@aliascsv,$N{ALIAS});
				}
				@alias = ($alias[0]) if (!$showg);
				push(@html,"<TD $tds title=\"$N{NAME}\">".join("<BR>",@alias)."</TD>");
				push(@csvf,"\"".join(",",@aliascsv)."\"");
			}
			case "feature"   {
				push(@html,"<TD $tds nowrap>$hfeature</TD>");
				push(@csvf,"\"$feature\"");
			}
			case "author"    {
				push(@html,"<TD $tds nowrap>$hauthors</TD>");
				push(@csvf,"\"".join(",",@authors)."\"");
			}
			case "remote"    {
				push(@html,"<TD $tds nowrap>$hremotes</TD>");
				push(@csvf,"\"".join(",",@remotes)."\"");
			}
			case "startdate" {
				push(@html,"<TD $tds nowrap>$hdate1 $time1</TD>");
				push(@csvf,"\"$date1 $time1\"");
			}
			case "enddate"   {
				push(@html,"<TD $tds nowrap>$hdate2 $time2</TD>");
				push(@csvf,"\"$date2 $time2\"");
			}
			case "title"     {
				push(@html,"<TD $tds>$htitle</TD>");
				push(@csvf,"\"$title\"");
			}
			case "comment"   {
				push(@html,"<TD $tds style=\"text-align:left\">$comment</TD>");
				push(@csvf,"\"$commentcsv\"");
			}
			case "notebook"  {
				push(@html,"<TD $tds>$notebook</TD>") if (isok($NODES{EVENTNODE_NOTEBOOK}));
				push(@csvf,"\"$notebook\"");
			}
			case "outcome"   {
				push(@html,"<TD $tds>".($outcome > 0 ? "<IMG src=\"/icons/attention.gif\" border=0 title=\"Potential outcome on sensor/data\">":"")."</TD>");
				push(@csvf,"\"$outcome\"");
			}
		}
	}
	push(@csv,join(";",@csvf));
	push(@html,"<TD $tds>".($#attach > 0 ? "<IMG src=\"/icons/attach.png\" border=0 title=\"$#attach attached document(s)\">":"")."</TD>");
	push(@html,"</TR>\n");
	$n = ($n + 1) % 2;
}

push(@html,"</TABLE>\n");
push(@html,"<P><A id=\"download_link\" download=\"my_exported_file.csv\" href=\"\">$__{'Download as CSV File'}</A></P>\n");

print(join("\n",@html));

my $csvstring = join('\\n',@csv);
$csvstring =~ s/'/\\'/g;

print <<"ENDBOTOFPAGE";
<SCRIPT type="text/javascript">
	document.getElementById("attente").style.display = "none";
	var text = '$csvstring';
	var data = new Blob([text], { type: 'text/csv;charset=utf-8;' });
	var url = window.URL.createObjectURL(data);
	document.getElementById('download_link').href = url;
</SCRIPT>
<STYLE type="text/css">
	#attente
	{ display: none;}
</STYLE>
<BR>
</BODY>
</HTML>
ENDBOTOFPAGE


###############################################################################
# this function uses external commands (find, grep, awk ...) to get the list of
# requested events following the search criteria
sub searchEvents {
	my ($target,$str,$in) = @_;
	my $struc = uc($str);
	my ($GRIDType,$GRIDName,$NodeID) = split(/\./,$target);

	my @evt;
	my $cmd;

	# default command is all events...
	my $node = ($NodeID eq "" ? "*":$NodeID);
	my $base = "find $WEBOBS{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS} \\( -name \"*.txt\" -a ! -name \"*_Projet.txt\" \\)";

	# alias will look for $str in the node's ALIAS and NAME configuration
	if ($in eq "alias") {
		$cmd = "find $WEBOBS{PATH_NODES}/$node -name \"*.cnf\" | xargs awk -F'|' '\$1 ~ /^ALIAS|NAME\$/ && toupper(\$2) ~ /$struc/ { print FILENAME }' | awk -F'/[^/]*\$' '{ print \$1 \"/$NODES{SPATH_INTERVENTIONS}\" }' | xargs find | grep \".txt\$\" | grep -v \"_Projet.txt\"";
	}
	# grid will look for $str in the grid's NAME configuration
	if ($in eq "grid") {
		# search for grid names
		my @GRIDlist = qx(find $WEBOBS{ROOT_CONF}/PROCS/* -name "*.conf" | xargs awk -F "|" '\$1 == "NAME" && toupper(\$2) ~ /$struc/ { print FILENAME }' | LC_ALL=C sed -e 's|.*CONF/||g;s|PROCS/|PROC.|g;s|VIEWS/|VIEW.|g;s|/.*||g' 2>&1);
		push(@GRIDlist,qx(find $WEBOBS{ROOT_CONF}/VIEWS/* -name "*.conf" | xargs awk -F "|" '\$1 == "NAME" && toupper(\$2) ~ /$struc/ { print FILENAME }' | LC_ALL=C sed -e 's|.*CONF/||g;s|PROCS/|PROC.|g;s|VIEWS/|VIEW.|g;s|/.*||g' 2>&1));
		chomp(@GRIDlist);
		if ($#GRIDlist < 0) {
			$cmd = "";
		} else {
			$cmd = "find -L $WEBOBS{PATH_GRIDS2NODES} \\( ! -name \"*_Projet.txt\" -a -name \"*.txt\" -a -path \"$node/$NODES{SPATH_INTERVENTIONS}*\" -a \\( -path \"*".join('*" -o -path "*',@GRIDlist)."*\" \\) \\)";
		}
	}
	# startdate will look for $str in event's start date
	if ($in eq "startdate") {
		my $s = $str;
		$s =~ s/:/-/;
		$s =~ s/ /_/;
		$cmd = "find $WEBOBS{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS} \\( -name \"*.txt\" -a -name \"*$s*\" -a ! -name \"*_Projet.txt\" \\)";
	}
	# author and remote will look for $str in author's full names
	if ($in eq "author" || $in eq "remote") {
		# must replaces author names by their UID
		my @UIDlist = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "select UID from users where FULLNAME like '%$str%'");
		chomp(@UIDlist);
		if ($#UIDlist < 0) {
			$cmd = "";
		} else {
			my $f = "1";
			$f = "2" if ($in eq "remote");
			$cmd = $base."|xargs awk -F '[|/]' 'FNR>1 {nextfile} \$$f ~ /".join(/\|/,@UIDlist)."/ { print FILENAME ; nextfile }'";
		}
	}
	# title will look for $str in event's title (2nd field in header line)
	if ($in eq "title") {
		$cmd = $base."| xargs awk -F \"|\" 'FNR>1 {nextfile} toupper(\$2) ~ /".uc($str)."/ { print FILENAME ; nextfile }'";
	}
	# enddate will look for $str in event's end date (3rd field in header line)
	if ($in eq "enddate") {
		$cmd = $base."| xargs awk -F \"|\" 'FNR>1 {nextfile} toupper(\$3) ~ /".uc($str)."/ { print FILENAME ; nextfile }'";
	}
	# feature will look for $str in event's feature (4th field in header line)
	if ($in eq "feature") {
		$cmd = $base."| xargs awk -F \"|\" 'FNR>1 {nextfile} toupper(\$4) ~ /".uc($str)."/ { print FILENAME ; nextfile }'";
	}
	# outcome will look for $str in event's outcome (5th field in header line)
	if ($in eq "outcome") {
		$cmd = $base."| xargs awk -F \"|\" 'FNR>1 {nextfile} toupper(\$6) ~ /".uc($str)."/ { print FILENAME ; nextfile }'";
	}
	# notebook will look for $str in event's outcome (6th field in header line)
	if ($in eq "notebook") {
		$cmd = $base."| xargs awk -F \"|\" 'FNR>1 {nextfile} toupper(\$7) ~ /".uc($str)."/ { print FILENAME ; nextfile }'";
	}
	# comment will look for $str in event's full text (except header line)
	if ($in eq "comment") {
		$cmd = $base."| xargs awk 'FNR>1 && toupper(\$0) ~ /".uc($str)."/ { print FILENAME ; nextfile }'";
	}

	@evt = qx($cmd);
	chomp(@evt);
	return @evt;
}


sub sort_by_date ($$) {
	my ($c,$d) = @_;
	# keeps only the date info (removes path and nodeid)
	$c = basename($c);
	$c =~ s/[^_]*//;
	$d = basename($d);
	$d =~ s/[^_]*//;
	# replaces undefined time by 00:00
	$c =~ s/_NA/_00:00/;
	$d =~ s/_NA/00:00/;
	return $d cmp $c;
}


=pod

=head1 AUTHOR(S)

Francois Beauducel, Christophe Brunet

=head1 COPYRIGHT

WebObs - 2012-2022 - Institut de Physique du Globe Paris

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
