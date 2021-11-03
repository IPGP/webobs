#!/usr/bin/perl

=head1 NAME

showOUTG.pl

=head1 SYNOPSIS

http://..../showOUTG.pl?grid=gridname[,ts=][,g=][,refresh=]

=head1 DESCRIPTION

Displays contents of OUTG directory for the GRID gridname (ie. gridType.gridName).
Optionaly specify the graph to display:

ts=	can be any key defined in the GRID configuration TIMESCALELIST or 'map' or 'events'
g=	any key defined in SUMMARYLIST, or one of the NODE ID
	void (default) means an overview of all thumbnails for the first available timescale
	for a PROC, and map for a VIEW
	g=col shows all graphs in one column at full scale

	if ts=events, YYYY or YYYY/MM or YYYY/MM/DD to display available events
	void (default) is last available year

refresh=
	defines the number of seconds for automatic reloading of the page. This
	overwrites default PROC's value AUTO_REFRESH_SECONDS

header=no
	hides the title, menu links and icons above the image

Directory paths of OUTG content is defined by the following variables:
	- ROOT_OUTG (disk root path) in WEBOBS.rc (default is /opt/webobs/OUTG)
	- URN_OUTG (web root path) in WEBOBS.rc (default is /OUTG)
	- an alias in Apache configuration (must be URN_OUTG pointing to ROOT_OUTG!)
=cut

use strict;
use warnings;

$|=1;
use Cwd qw(abs_path);
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

use WebObs::Config;
use WebObs::Grids;
use WebObs::Users;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Form;
use Locale::TextDomain('webobs');

use POSIX qw/setlocale LC_ALL strftime/;
#use Encode;
#my ($strftime_encoding)= setlocale(LC_ALL);
#sub strftime2 {    # try to return an utf8 value from strftime
#	$strftime_encoding ? Encode::decode($strftime_encoding, &strftime) : &strftime;
#}

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
set_message(\&webobs_cgi_msg);
my %GRID;
my %G; my %P;
my $GRIDType = my $GRIDName = my $RESOURCE = my $OUTG = "";
my @OUTGList;

my $QryParm   = $cgi->Vars;
my @GID = split(/[\.\/]/, trim($QryParm->{'grid'}));


# ---- what grid do we have to process ? any showstoppers ?
if (scalar(@GID) == 2) {
	($GRIDType, $GRIDName) = @GID;
	if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
	elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
	if (%G) {
		%GRID = %{$G{$GRIDName}} ;
		if ( WebObs::Users::clientHasRead(type=>"authprocs",name=>"$GRIDName") || WebObs::Users::clientHasRead(type=>"authviews",name=>"$GRIDName") ) {
			$RESOURCE = "authmisc/$GRIDName";
			if (-d "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName" ) {
				$OUTG = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName";
			} else { die "$__{'No outputs for'} $GRIDType.$GRIDName" }
		} else { die "$__{'Not authorized'} $GRIDName (read)"}
	} else { die "$__{'Could not read'} $GRIDType.$GRIDName configuration" }
} else { die "$__{'Not a valid GRID requested (NOT gridtype.gridname)'}" }

# ---- good, passed all validity/authorization checkings above
# ---- grab additional arguments specifying which unique output we have to show
$QryParm->{'ts'}       ||= '';
$QryParm->{'g'}        ||= '';
$QryParm->{'refresh'}  ||= $GRID{DISPLAY_AUTOREFRESH_SECONDS};

if ($GRIDType eq 'VIEW' && $QryParm->{'ts'} eq '') { $QryParm->{'ts'} = 'map' }

if ($QryParm->{'g'} =~ s!^lastevent(\b|$)!!) {
	# "^lastevent" was removed from 'g':
	# replace it with the directory the 'lastevent' symlink links to.
	my $lastevent_dir = abs_path("$OUTG/$WEBOBS{PATH_OUTG_EVENTS}/lastevent");
	# Remove ^$OUTG/events/ from the path to only keep "yyyy/mm/dd/eventid"
	my $OUTGabs = abs_path("$OUTG/$WEBOBS{PATH_OUTG_EVENTS}");
	$lastevent_dir =~ s!$OUTGabs/!!;
	# Replace 'g' with this link and append the remaining of the original 'g', if any
	# (so that both g=lastevent and g=lastevent/b3 work).
	$QryParm->{'g'} = $lastevent_dir.$QryParm->{'g'};
}

# ---- initialize 'timescales' definitions
my %TIMESCALES = (
	xxx => 'Manual',
	  r => 'Reference',
	all => 'All Data',
	  s => 'second',
	  h => 'hour',
	  d => 'day',
	  w => 'week',
	  m => 'month',
	  y => 'year',
);

# ---- get the list of nodes currently belonging to grid
# ---- and the list of possible summary grid's summary filenames
my %DefinedNodes = listGridNodes(grid=>"$GRIDType.$GRIDName");
my @SummaryList  = split(/,/,$GRID{SUMMARYLIST});
outgHouseKeeping();

# ---- Start HTML page
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<HTML><HEAD><title>OUTG for $GRIDType.$GRIDName</title>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";
if ($QryParm->{'refresh'} gt 0) {
	print "<meta http-equiv=\"refresh\" content=\"$QryParm->{'refresh'}\">";
}
print "</head><body>";
print "<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>";
print "<!-- overLIB (c) Erik Bosrup --><div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\" type=\"text/javascript\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/wolb.js\"></script>
<link href=\"/css/wolb.css\" rel=\"stylesheet\" />";

print "<A NAME=\"MYTOP\"></A>";
print "<H1 style=\"margin-bottom:6pt\">$GRID{NAME}</H1>\n" if ($QryParm->{'header'} ne 'no');
my $go2top = "<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";


# ---- build the top-of-page outputs selection banner:
# 1st line for timescale selection
# 2nd line for output selection

# base url (string that is passed through all links)
my $baseurl = "/cgi-bin/showOUTG.pl?grid=$GRIDType.$GRIDName&refresh=$QryParm->{'refresh'}&header=$QryParm->{'header'}";

print "<DIV id='selbanner' style='background-color: beige; padding: 5px; margin-bottom:10px;"
	.($QryParm->{'header'} eq 'no' ? " display:none":"")."'>";
	# build $tslist = the list of defined timescales for proc from proc's configuration file
	# and $tsSelected = index of the one currently selected (defaults to first item of $tslist)
	my @tslist = split(/,/, $GRID{TIMESCALELIST});
	my $tsSelected = 0 ;
	my $tsHtml = "";
	for my $i (0..$#tslist) {
		my $ts = $tslist[$i];
		my $tsName = $ts;
		# for backward compatibility (replaces some of old "timescales.conf" definitions)
		$ts =~ s/a$|an$|yr$/y/;
		$ts =~ s/j$/d/;
		my $n = 1*substr($ts,0,-1);
		if ($n > 0) {
			$tsName = "$n $TIMESCALES{substr($ts,-1)}".($n > 1 ? "s":"");
		} elsif (substr($ts,0,1) eq "r") {
			my $r = 1*substr($ts,1);
			$tsName = "$TIMESCALES{r}".($r > 0 ? " $r":"");
		} elsif (defined($TIMESCALES{$ts})) {
			$tsName = $TIMESCALES{$ts};
		}
		if ($QryParm->{'ts'} eq $tslist[$i] ) {
			$tsSelected = $i;
			$tsHtml .= " <B>$tsName</B> |";
		} else {
			$tsHtml .= " <B><A href=\"$baseurl&ts=$tslist[$i]&g=$QryParm->{'g'}\">$tsName</A></B> |";
		}
	}
	chop($tsHtml);
	print "<B>»»</B> [ <A href=\"/cgi-bin/showGRID.pl?grid=$GRIDType.$GRIDName\"><B>".ucfirst(lc($GRIDType))."</B></A> ";
	if ($QryParm->{'ts'} eq 'map' ) {
		print "| <B>Map</B> ";
	} elsif (-d "$OUTG/$WEBOBS{PATH_OUTG_MAPS}") {
		print "| <B><A href=\"$baseurl&ts=map\">Map</A></B> ";
	}
	if ($QryParm->{'ts'} eq 'events' ) {
		print "| <B>Events</B> ";
	} elsif (-d "$OUTG/$WEBOBS{PATH_OUTG_EVENTS}") {
		print "| <B><A href=\"$baseurl&ts=events\">Events</A></B> ";
	}
	if (-d "$OUTG/$WEBOBS{PATH_OUTG_EVENTS}") {
		(my $EVTurn = $OUTG) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
		print "| <B><A href=\"$EVTurn/$WEBOBS{PATH_OUTG_EVENTS}\">All files</A></B> ";

		# build @nlist = the list of available nodes in events/*/*/*/ subdirectories
		my (@ilist) = glob "$OUTG/$WEBOBS{PATH_OUTG_EVENTS}/????/*/*/*";
		my @nlist;
		foreach (sort(keys(%DefinedNodes))) {
			if (grep(/$_/i,@ilist)) {
				push(@nlist,$_);
				if ($QryParm->{'g'} =~ /$_/) {
					print "| <B>$DefinedNodes{$_}{ALIAS}</B> ";
				} else {
					print "| <A href=\"$baseurl&ts=events&g=*/*/*/$_\"><B>$DefinedNodes{$_}{ALIAS}</B></A> ";
				}
			}
		}
	}
	if ($#tslist >= 0 && -d "$OUTG/$WEBOBS{PATH_OUTG_GRAPHS}") {
		print "| Time scales: $tsHtml ";
	}
	print " | <img src=\"/icons/refresh.png\" style=\"vertical-align:middle\" title=\"Refresh\" onclick=\"document.location.reload(false)\"> ]\n";

	# build @elist = the list of available .eps graphs for timescale $tslist[$tsSelected]
	my (@elist) = glob "$OUTG/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.eps";

	# build @plist = the list of available .pdf graphs for timescale $tslist[$tsSelected]
	my (@plist) = glob "$OUTG/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.pdf";

	# build @dlist = the list of available data/**.* for timescale $tslist[$tsSelected]
	my (@dlist) = glob "$OUTG/$WEBOBS{PATH_OUTG_EXPORT}/*_$tslist[$tsSelected]*.*";

	# build @ylist = the list of available events/* years
	my (@ylist) = glob "$OUTG/$WEBOBS{PATH_OUTG_EVENTS}/????";


	# build @glist = the list of available .png graphs for timescale $tslist[$tsSelected]
	# $glistHtml is the corresponding string of html hrefs to these graphs
	# with each nodenames replaced with their alias if it is defined
	my (@glist) = sort glob "$OUTG/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.png";
	my $glistHtml = "";
	if ($QryParm->{'ts'} eq 'events' ) {
		if ($QryParm->{'g'} eq "") {
			$QryParm->{'g'} = $ylist[$#ylist];
			$QryParm->{'g'} =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_EVENTS}\///;
		}
		foreach (@ylist) {
			my $year = $_;
			$year =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_EVENTS}\///;
			if ($QryParm->{'g'} eq $year) {
				$glistHtml .= " $year |";
			} else {
				$glistHtml .= " <A href=\"$baseurl&ts=events&g=$year\"> $year</A> |";
			}
		}
	} else {
		my $lnk = "$baseurl&ts=$tslist[$tsSelected]&g=";
		$glistHtml .= " <A href=\"$lnk\"> Overview</A> | ";
		$glistHtml .= ($QryParm->{'g'} ne "col" ? "<A href=\"${lnk}col\">Column</A>":"Column")." |";
		for my $fpath (@glist) {
			my $gname = $fpath;
			$gname =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_$tslist[$tsSelected].*$/$1/;
			$gname =~ s/^$/SUMMARY/;
			my $gbase = $gname;
			$gbase =~ s/(.*)_.*$/$1/;
			my $gmenu = $gname;
			if ($gname ne 'SUMMARY' && !(grep( /^$gbase$/i, @SummaryList)) ) {
				if ( grep( /^$gname$/i, keys(%DefinedNodes)) ) {  # it's a node file AND node still in proc
					my $alias = getNodeString(node=>uc($gname), style=>'alias');
					$gmenu = $alias if ( $alias ne '' && $alias ne '-' );
				} else { # it's a node file, but node NOT currently in proc == stale node that survived the housekeeping above
					$gmenu = 'STALE';
				}
			}
			if ( $gmenu ne 'STALE' ) {
				if ($QryParm->{'g'} eq $gname) {
					$glistHtml .= " $gmenu |";
				} else {
					$glistHtml .= " <A href=\"$lnk$gname\"> $gmenu</A> |";
				}
			}
		}
	}
	chop($glistHtml);
	if ($QryParm->{'ts'} ne 'map' ) {
		print "<BR><B>[ ".$glistHtml." ]</B>\n";
	}
print "</DIV>";


# ---- now show the selected item
# -- case 'Map'
if ($QryParm->{'ts'} eq 'map') {

	# only 1 map : *.png and its corresponding *.map
	my $MAPpath = my $MAPurn = "";
	my @htmlarea;
	$MAPpath = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/$WEBOBS{PATH_OUTG_MAPS}";
	( $MAPurn  = $MAPpath ) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;

	my $mapname = "$GRIDType.$GRIDName"."_map";
	if ( -e "$MAPpath/$mapname.eps" ) {
		print "<A href=\"$MAPurn/$mapname.eps\"><IMG alt=\"$mapname.eps\" src=\"/icons/feps.png\"></A><BR>\n";
	}
	if  ( -e "$MAPpath/$mapname.png" ) {
		print "<IMG style=\"margin-bottom: 15px; background-color: beige;\" src=\"$MAPurn/$mapname.png\" usemap=\"#map\"><BR>\n";
		if (-e "$MAPpath/$mapname.map") {
			@htmlarea = readFile("$MAPpath/$mapname.map");
			print "<map name=\"map\">@htmlarea</map>\n";
		}
	}

# -- case 'Events'
} elsif ($QryParm->{'ts'} eq 'events') {

	# this lists files using complementary wildcards from g= YYYY[/MM[/DD[/EVENTID[/EVENTNAME]]]]
	(my $depth = $QryParm->{'g'}) =~ s/[^\/]//g;
	$depth = length($depth); # $depth is number of "/" in the g= argument

	# lists all files
	@plist = glob "$OUTG/$WEBOBS{PATH_OUTG_EVENTS}/$QryParm->{'g'}".("/*" x (4 - $depth)).".jpg";

	# target directory contains multiple files: displays existing thumbnails
	if ($#plist > 1) {
		my $month0 = "";
		for (@plist) {
			if ( ($depth < 3 && -l $_) || ($depth == 3 && ! -l $_)) {
				(my $JPGurn = $_) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
				(my $EVENTid = $_) =~ s/$OUTG\/$WEBOBS{PATH_OUTG_EVENTS}\///g;
				if (-l $_) {
					my $lnk = basename($_);
					my $tgt = readlink($_);
					$EVENTid =~ s/$lnk/$tgt/g;
				}
				$EVENTid =~ s/\.jpg//g;
				(my @evt) = split(/\//,$EVENTid);
				my $dte = l2u(strftime("%A %d %B %Y",0,0,0,$evt[2],$evt[1] - 1,$evt[0] - 1900));
				my $month = l2u(strftime("%B %Y",0,0,0,$evt[2],$evt[1] - 1,$evt[0] - 1900));
				my $msg = "ID: $evt[3]<BR>$evt[4]";
				if ($depth == 3 && $QryParm->{'g'} !~ m/\*/ && $month ne $month0) {
					print "<H2>$dte: <I>$evt[3]</I></H2>\n";
					$month0 = $month;
				} elsif ($month ne $month0) {
					print "<H2>$month</H2>\n";
					$month0 = $month;
				}
				my $thumb = "";
				if ($WEBOBS{MKGRAPH_THUMBNAIL_HEIGHT} > 0) {
					$thumb = "; height:$WEBOBS{MKGRAPH_THUMBNAIL_HEIGHT}px";
				}
				my $target = $EVENTid;
				if ($depth < 3) {
					$target = join("/",@evt[0..3]);
				}
				print "<A href=\"$baseurl&ts=events&g=$target\">",
					"<IMG style=\"margin: 1px; background-color: beige; padding: 5px; border: 0$thumb\" src=\"$JPGurn\"",
					"onMouseOut=\"nd()\" onMouseOver=\"overlib('$msg',CAPTION,'$dte')\"></A>\n";
			}
		}
	# single file: displays .png (or .jpg) and links to other files (.eps,.pdf,.gse,.txt)
	} else {
		my $addlinks = "";
		(my $short = $plist[0]) =~ s/\.jpg//g;
		(my $urn = $short) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
		(my $EVENTid = $short) =~ s/$OUTG\/$WEBOBS{PATH_OUTG_EVENTS}\///g;
		(my @evt) = split(/\//,$EVENTid);
		my $dte = l2u(strftime("%A %d %B %Y",0,0,0,$evt[2],$evt[1] - 1,$evt[0] - 1900));
		foreach ("eps","pdf","gse","txt","kml") {
			if ( -e "$short.$_" ) {
				$addlinks .= " <A href=\"$urn.$_\"><IMG alt=\"$urn.$_\" src=\"/icons/f$_.png\"></A> ";
			}
		}
		print "<H2>$dte: <I>$evt[3]&nbsp;/&nbsp;$evt[4]</I></H2>\n";
		print "$addlinks<BR>" if ($QryParm->{'header'} ne 'no');
		my $img = "$urn.png";
		if ( ! -f "$short.png" ) {
			$img = "$urn.jpg";
		}
		print "<IMG style=\"margin-bottom: 15px; background-color: beige; padding: 5px\" src=\"$img\"><BR>";
	}

# -- case 'Timescales'
} else {

	# i.e "only display requested g= in query-string"
	# if none requested in query-string, show thumbnails of all available graphs
	if ($QryParm->{'g'} eq "") {

		for my $g (@glist) {
			(my $urn  = $g) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
			$urn =~ s/\.png$/\.jpg/;
			(my $short = $g) =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
			$short =~ s/^$/SUMMARY/;
			print "<A href=\"$baseurl&ts=$tslist[$tsSelected]&g=$short\"><IMG style=\"margin-bottom: 2px; background-color: beige; padding: 2px\" src=\"$urn\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$short',CAPTION,'$tslist[$tsSelected]')\"></A> ";
		}

	# if g=col in query-string, show all available graphs in one column
	} elsif ($QryParm->{'g'} eq "col") {

		for my $g (@glist) {
			(my $urn  = $g) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
			(my $short = $g) =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
			$short =~ s/^$/SUMMARY/;
			print "<A href=\"$baseurl&ts=$tslist[$tsSelected]&g=$short\"><IMG style=\"margin-bottom: 2px; background-color: beige; padding: 2px\" src=\"$urn\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$short',CAPTION,'$tslist[$tsSelected]')\"></A><BR> ";
		}


	} else {
		# prepare additional links to eps, pdf and data
		my $addlinks = "";
		for my $i (0..$#elist) {
			if (-f $elist[$i]) {
				(my $surn = $elist[$i]) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
				$elist[$i] =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
				$elist[$i] =~ s/^$/$GRIDName/;
				if ($elist[$i] eq $QryParm->{'g'}) {
					$addlinks .= " <A href=\"$surn\"><IMG alt=\"$QryParm->{'g'}.eps\" src=\"/icons/feps.png\"></A> ";
				}
			}
		}
		for my $i (0..$#plist) {
			if (-f $plist[$i]) {
				(my $surn = $plist[$i]) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
				$plist[$i] =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
				$plist[$i] =~ s/^$/$GRIDName/;
				if ($plist[$i] eq $QryParm->{'g'}) {
					$addlinks .= " <A href=\"$surn\"><IMG alt=\"$QryParm->{'g'}.pdf\" src=\"/icons/fpdf.png\"></A> ";
				}
			}
		}
		for my $i (0..$#dlist) {
			if (-f $dlist[$i]) {
				(my $surn = $dlist[$i]) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
				$dlist[$i] =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_EXPORT}\/(.*)_.*$/$1/;
				$dlist[$i] =~ s/^$/$GRIDName/;
				##if ($dlist[$i] eq $QryParm->{'g'}) {
				if ( ($dlist[$i]=~m/$QryParm->{'g'}/i) ) {
					$addlinks .= " <A href=\"$surn\"><IMG alt=\"$QryParm->{'g'}.txt\" src=\"/icons/fdata.png\"></A> ";
				}
			}
		}
		# if a FORM is associated to the PROC, adds a link to the database interface
		if ($GRID{FORM} ne '') {
			my $FORM = new WebObs::Form($GRID{FORM});
			my $opt = ($QryParm->{'g'} eq $GRIDName ? "{$GRIDName}":uc($QryParm->{'g'}));
			$addlinks .= "<A href=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."?node=$opt\"><IMG alt=\"\" src=\"/icons/fdata.png\"></A> ";
		}

		if ( $QryParm->{'g'} ne $GRIDName && !(grep( /^$QryParm->{'g'}$/i, @SummaryList)) && $QryParm->{'g'} eq lc($QryParm->{'g'}) ) {
			my $ucg = uc($QryParm->{'g'});
			$addlinks .= " <A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=PROC.$GRIDName.$ucg\"><IMG alt=\"$QryParm->{'g'}\" src=\"/icons/fnode.png\"></A> ";
		}
		# finally plots the image !
		for my $g (@glist) {
			(my $map = $g) =~ s/\.png/\.map/;
			(my $urn  = $g) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
			$g =~ s/^$OUTG\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
			$g =~ s/^$/SUMMARY/;
			if ($g eq $QryParm->{'g'}) {
				print "$addlinks<BR>" if ($QryParm->{'header'} ne 'no');
				print "<IMG style=\"margin-bottom: 15px; margin-top: 5 px; background-color: beige;\" src=\"$urn\" usemap=\"#map\"><BR>";
				if (-e "$map") {
					my @htmlarea = readFile("$map");
					print "<map name=\"map\">@htmlarea</map>\n";
				}
			}
		}
	}
}
print "<BR>$go2top</BR>";

# ---- We're done !
print "</BODY>\n</HTML>\n";

sub outgHouseKeeping {
	# %DefinedNodes and @SummaryList must have been built
	if ( defined($WEBOBS{OUTG_STALENODES_DISPO}) ) {
		my @objects = ( glob("$OUTG/$WEBOBS{PATH_OUTG_GRAPHS}/*_*.eps"), glob("$OUTG/$WEBOBS{PATH_OUTG_EXPORT}/*_*.*") );
		for my $object (@objects) {
			my $prefix = basename($object); $prefix =~ /(.*)_.*/; $prefix = $1;
			if ( $WEBOBS{OUTG_STALENODES_DISPO} eq 'DELETE' && ($prefix ne "" || !defined($GRID{SUMMARYLIST})) && $prefix ne $GRIDName ) {
				if ( !(grep( /^$prefix$/i, keys(%DefinedNodes))) && !(grep( /^$prefix$/i, @SummaryList)) ) {
					qx(rm $object);
				}
			}
		}
	}
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

WebObs - 2012-2020 - Institut de Physique du Globe Paris

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
