#!/usr/bin/perl

=head1 NAME

Show /OUTG contents for a GRID

=head1 SYNOPSIS

http://..../showOUTG.pl?grid=gridname[,ts=][,g=][,refresh=]

=head1 DESCRIPTION

Displays contents of OUTG directory for the GRID gridname (ie. gridType.gridName).
Optionaly specify the graph to display:

ts= can be any key defined in the GRID configuration TIMESCALELIST or 'map' or 'events'
g=  any key defined in SUMMARYLIST, or one of the NODE ID
    void (default) means an overview of all thumbnails for the first available timescale
    for a PROC, and map for a VIEW or FORM
    g=col shows all graphs in one column at full scale

    if ts=events, g=yyyy, g=yyyy/mm, g=yyyy/mm/dd, or g=yyyy/mm/dd/eventid to display 
    available events.
    g=*/*/*/eventid, g=yyyy/*/*/eventid, and g=yyyy/mm/*/eventid are authorized
    to address a specific event id.
    g=today, g=tomonth, g=toyear display today's, current month or current year available events
    void (default) is all event for the last available year


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
use File::Find;
use List::Util qw(uniq);
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
#    $strftime_encoding ? Encode::decode($strftime_encoding, &strftime) : &strftime;
#}

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
set_message(\&webobs_cgi_msg);
my %GRID;
my %G; my %P;
my $GRIDType = my $GRIDName = my $RESOURCE = my $OUTG = my $OUTR = "";
my @OUTGList;

my $QryParm   = $cgi->Vars;
my @GID = split(/[\.\/]/, trim($QryParm->{'grid'}));

my $OUTDIR = trim($QryParm->{'dir'});

# ---- what grid do we have to process ? any showstoppers ?
if (scalar(@GID) == 2) {
    ($GRIDType, $GRIDName) = @GID;
    if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
    elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
    elsif  (uc($GRIDType) eq 'FORM') { %G = readForm($GRIDName) }
    if (%G) {
        %GRID = %{$G{$GRIDName}};
        if ( WebObs::Users::clientHasRead(type=>"authprocs",name=>"$GRIDName") || WebObs::Users::clientHasRead(type=>"authviews",name=>"$GRIDName") ) {
            $RESOURCE = "authmisc/$GRIDName";
            if (-d "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName" ) {
                $OUTG = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName";
            } elsif ($OUTDIR eq "") { die "$__{'No outputs for'} $GRIDType.$GRIDName" }
        } else { die "$__{'Not authorized'} $GRIDName (read)"}
    } else { die "$__{'Could not read'} $GRIDType.$GRIDName configuration" }
} else { die "$__{'Not a valid GRID requested (NOT gridtype.gridname)'}" }


if (-d "$WEBOBS{ROOT_OUTR}/$OUTDIR/$GRIDType.$GRIDName" ) {
    $OUTR = "$WEBOBS{ROOT_OUTR}/$OUTDIR/$GRIDType.$GRIDName";
}

my $OUTD = $OUTDIR ? $OUTR : $OUTG;
my $urn_dir  = $OUTDIR ? $WEBOBS{URN_OUTR} : $WEBOBS{URN_OUTG};
my $root_dir = $OUTDIR ? $WEBOBS{ROOT_OUTR} : $WEBOBS{ROOT_OUTG};

# ---- good, passed all validity/authorization checkings above
# ---- grab additional arguments specifying which unique output we have to show
$QryParm->{'ts'}       ||= '';
$QryParm->{'g'}        ||= '';
$QryParm->{'refresh'}  ||= $GRID{DISPLAY_AUTOREFRESH_SECONDS};

if ($GRIDType eq 'VIEW' && $QryParm->{'ts'} eq '') { $QryParm->{'ts'} = 'map' }

if ($QryParm->{'g'} =~ s!^lastevent(\b|$)!!) {

    # "^lastevent" was removed from 'g':
    # replace it with the directory the 'lastevent' symlink links to.
    my $lastevent_dir = abs_path("$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/lastevent");

    # Remove ^$OUTD/events/ from the path to only keep "yyyy/mm/dd/eventid"
    my $OUTGabs = abs_path("$OUTD/$WEBOBS{PATH_OUTG_EVENTS}");
    $lastevent_dir =~ s!$OUTGabs/!!;

# Replace 'g' with this link and append the remaining of the original 'g', if any
# (so that both g=lastevent and g=lastevent/b3 work).
    $QryParm->{'g'} = $lastevent_dir.$QryParm->{'g'};
}

local $ENV{TZ} = "Etc/GMT".sprintf("%+d",-1*($GRID{TZ}));
my $now = strftime("%Y/%m/%d %H:%M:%S", localtime(time));
my $today = substr($now,0,10);
my $tomonth = substr($now,0,7);
my $toyear = substr($now,0,4);

$QryParm->{'g'} = $today if ($QryParm->{'g'} eq "today");
$QryParm->{'g'} = $tomonth if ($QryParm->{'g'} eq "tomonth");
$QryParm->{'g'} = $toyear if ($QryParm->{'g'} eq "toyear");


# ---- get the list of nodes currently belonging to grid
# ---- and the list of possible summary grid's summary filenames
my %DefinedNodes = listGridNodes(grid=>"$GRIDType.$GRIDName");
my @nlist = sort keys %DefinedNodes;
my @SummaryList  = split(/,/,$GRID{SUMMARYLIST});
outgHouseKeeping();

my %monthnames;
@monthnames{ map sprintf("%02d",$_), 1..12 } = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

# ---- Start HTML page
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<HTML><HEAD><title>OUTPUT for $GRIDType.$GRIDName</title>";
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
print "<TABLE width=100%><TR><TD style='border:0'>\n";
if ($QryParm->{'header'} ne 'no') {
    my $tsName = timescale_name($QryParm->{'ts'});
    print "<H1 style=\"margin-bottom:6pt\">$GRID{NAME}".($tsName ne "" ? " <I>($tsName)</I>":"")."</H1>\n";
}
my $go2top = "<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";

# ---- build the top-of-page outputs selection banner:
# 1st line for timescale selection
# 2nd line for output selection

# base url (string that is passed through all links)
my $baseurl = "/cgi-bin/showOUTG.pl?grid=$GRIDType.$GRIDName&refresh=$QryParm->{'refresh'}&header=$QryParm->{'header'}";

# count the number of "/" in the g= argument
(my $depth = $QryParm->{'g'}) =~ s/[^\/]//g;
$depth = length($depth);

print "<DIV id='selbanner' style='background-color: beige; padding: 5px; margin-bottom:10px;"
  .($QryParm->{'header'} eq 'no' ? " display:none":"")."'>";

# build $tslist = the list of defined timescales for proc from proc's configuration file
# and $tsSelected = index of the one currently selected (defaults to first item of $tslist)
my @tslist = split(/,/, $GRID{TIMESCALELIST});
my $tsSelected = 0 ;
my $tsHtml = "";
for my $i (0..$#tslist) {
    my $ts = $tslist[$i];
    my $tsName = timescale_name($ts);

    if ($QryParm->{'ts'} eq $tslist[$i] ) {
        $tsSelected = $i;
        $tsHtml .= " <B>$tsName</B> |";
    } else {
        $tsHtml .= " <B><A href=\"$baseurl&ts=$tslist[$i]&g=$QryParm->{'g'}\">$tsName</A></B> |";
    }
}
chop($tsHtml);

# build @elist = the list of available .eps graphs for timescale $tslist[$tsSelected]
my (@elist) = glob "$OUTD/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.eps";

# build @slist = the list of available .svg graphs for timescale $tslist[$tsSelected]
my (@slist) = glob "$OUTD/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.svg";

# build @plist = the list of available .pdf graphs for timescale $tslist[$tsSelected]
my (@plist) = glob "$OUTD/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.pdf";

# build @dlist = the list of available data/**.* for timescale $tslist[$tsSelected]
my (@dlist) = glob "$OUTD/$WEBOBS{PATH_OUTG_EXPORT}/*_$tslist[$tsSelected]*.*";

# build @ylist = the list of available events/* years
my (@ylist) = grep {-d} glob "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/????";

# build @ilist = the list of unique IDs in events/*/*/*/* subdirectories
my (@ilist) = uniq map { basename($_) } grep { -d } glob "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/*/*/*/*";

my $teHtml = "";
if ($QryParm->{'ts'} eq 'events' ) {
    if ($QryParm->{'g'} eq "") {
        $QryParm->{'g'} = $ylist[$#ylist];
        $QryParm->{'g'} =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_EVENTS}\///;
    }
    my $year = "";
    my ($y,$m,$d,$id) = split(/\//,$QryParm->{'g'});
    # links to available years
    foreach (@ylist) {
        $_ =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_EVENTS}\///;
        my $garg = $QryParm->{'g'};
        $year = $_ if ($garg =~ /^$_/);
        if ($garg =~ /^$_/ && $depth < 1) {
            $teHtml .= " $_ |";
        } else {
            if ($depth > 2 && grep(/$id/,@nlist)) { # event id is a node: keep it
                $garg = "$_/*/*/$id";
            } else {
                $garg = $_;
            }
            $teHtml .= " <A href=\"$baseurl&ts=events&g=$garg\"> $_</A> |";
        }
    }
    # links to available months in the year
    if ($year ne "") {
        my @amonths = map { basename($_) } grep {-d} glob "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/$year/*";
        $teHtml .= " $__{'Months of'} $year:";
        my ($y,$m,$d,$id) = split(/\//,$QryParm->{'g'});
        foreach (@amonths) {
            my $garg = $QryParm->{'g'};
            if ($depth > 1) {
                $garg =~ s|/[^/]*?/|/$_/|; # replace the month
                $garg =~ s|/[^/]*$|| if ($depth > 3); # remove image name
                $garg =~ s|/[^/]*$|| if ($depth > 2 && !grep(/$id/,@nlist)); # remove event id if not node
                $garg =~ s|^((?:[^/]*/){2})[^/]*(.*)|$1*$2| if ($depth > 1); # replace day by '*'
            } else {
                $garg = "$year/$_";
            }
            $teHtml .= " <A href=\"$baseurl&ts=events&g=$garg\">$monthnames{$_}</A>";
        }
    }
    # links to available days in the month
    if ($depth > 0 && $QryParm->{'g'} !~ /$year\/\*/) {
        my ($y,$m,$d,$id) = split(/\//,$QryParm->{'g'});
        my @mdays = map { basename($_) } grep {-d} glob "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/$y/$m/*";
        $teHtml .= " | $__{'Days of'} $monthnames{$m} $y:";
        foreach (@mdays) {
            my $garg = $QryParm->{'g'};
            $garg =~ s|/[^/]*$|| if ($depth > 3); # remove image name
            $garg =~ s|/[^/]*$|| if ($depth > 2 && !grep(/$id/,@nlist)); # remove event id if not node
            $garg =~ s|^((?:[^/]*/){2})[^/]*(.*)|$1$_$2| if ($depth > 1); # replace day
            $garg .= "/$_" if ($depth == 1); # add day
            $teHtml .= " <A href=\"$baseurl&ts=events&g=$garg\">$_</A>";
        }
    }
}

print "<B>»»</B> [ <A href=\"/cgi-bin/showGRID.pl?grid=$GRIDType.$GRIDName\"><B>".ucfirst(lc($GRIDType))."</B></A> ";
if ($QryParm->{'ts'} eq 'map' ) {
    print "| <B>$__{'Map'}</B> ";
} elsif (-d "$OUTD/$WEBOBS{PATH_OUTG_MAPS}") {
    print "| <B><A href=\"$baseurl&ts=map\">$__{'Map'}</A></B> ";
}
if (-d "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}") {
    print "| <B><A href=\"$baseurl&ts=events\">$__{'All Events'}</A></B> "
         ."| $teHtml ";

}
if ($#tslist >= 0 && -d "$OUTD/$WEBOBS{PATH_OUTG_GRAPHS}") {
    print "| $__{'Time scales:'} $tsHtml ";
}
print " | <img src=\"/icons/refresh.png\" style=\"vertical-align:middle;cursor:pointer\" title=\"Refresh\" onclick=\"document.location.reload(false)\"> ]\n";

# build @glist = the list of available .png graphs for timescale $tslist[$tsSelected]
# $glistHtml is the corresponding string of html hrefs to these graphs
# with each nodenames replaced with their alias if it is defined
my (@glist) = sort glob "$OUTD/$WEBOBS{PATH_OUTG_GRAPHS}/*_$tslist[$tsSelected]*.png";
my $glistHtml = "";
if ($QryParm->{'ts'} eq 'events' ) {
    # build @nlist = the list of available nodes (only if exist in event ID)
    for my $n (@nlist) {
        if (grep( /$n/i, @ilist)) {
            my $txt = $DefinedNodes{$n}{ALIAS};
            if ($QryParm->{'g'} =~ /$n$/) {
                $glistHtml .= " $txt |";
            } else {
                my $garg = $QryParm->{'g'};
                $garg = "$garg/*/*/$n" if ($depth < 1); # g=yyyy
                $garg = "$garg/*/$n" if ($depth == 1); # g=yyyy/mm
                $garg = "$garg/$n" if ($depth == 2); # g=yyyy/mm/dd
                $garg =~ s|^((?:[^/]*/){3}).*|$1$n| if ($depth > 2); # replace event ID 
                $glistHtml .= " <A href=\"$baseurl&ts=events&g=$garg\"><B>$txt</B></A> |";
            }
        }
    }
} else {
    my $lnk = "$baseurl&ts=$tslist[$tsSelected]&g=";
    $glistHtml .= " <A href=\"$lnk\"> Overview</A> | ";
    $glistHtml .= ($QryParm->{'g'} ne "col" ? "<A href=\"${lnk}col\">Column</A>":"Column")." |";
    for my $fpath (@glist) {
        my $gname = $fpath;
        $gname =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_$tslist[$tsSelected].*$/$1/;
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
chop($glistHtml); # removes last character (a pipe...)
if ($QryParm->{'ts'} ne 'map' ) {
    print "<BR>[ ".$glistHtml." ]\n" if ($glistHtml ne "");
}
print "</DIV>";
print "</TD><TD width='82px' style='border:0;text-align:right'>".qrcode($WEBOBS{QRCODE_BIN},$WEBOBS{QRCODE_SIZE})."</TD></TR></TABLE>\n";

# ---- now show the selected item
# -- case 'Map'
if ($QryParm->{'ts'} eq 'map') {

    # only 1 map : *.png and its corresponding *.map
    my $MAPpath = my $MAPurn = "";
    my @htmlarea;
    $MAPpath = "$root_dir/$GRIDType.$GRIDName/$WEBOBS{PATH_OUTG_MAPS}";
    ( $MAPurn  = $MAPpath ) =~ s/$root_dir/$urn_dir/g;

    my $mapname = "$GRIDType.$GRIDName"."_map";
    if ( -e "$MAPpath/$mapname.eps" ) {
        print "<A href=\"$MAPurn/$mapname.eps\"><IMG alt=\"$mapname.eps\" src=\"/icons/feps.png\"></A><BR>\n";
    }
    if  ( -e "$MAPpath/$mapname.png" ) {
        print "<IMG style=\"margin-bottom: 15px; background-color: beige;\" src=\"$MAPurn/$mapname.png\" usemap=\"#map\"><BR>\n";
        if (-e "$MAPpath/$mapname.map") {
            @htmlarea = readFile("$MAPpath/$mapname.map");
            print "<map name=\"map\">\n@htmlarea</map>\n";
        }
    }

    # -- case 'Events'
} elsif ($QryParm->{'ts'} eq 'events') {

# this lists files using complementary wildcards from g= YYYY[/MM[/DD[/EVENTID[/EVENTNAME]]]]

    # lists all files
    @plist = glob "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/$QryParm->{'g'}".("/*" x (4 - $depth)).".jpg";
    
    # build an hash of latest file in each event ID directory
    my %latest;
    if ($depth < 3) {
        for my $f (@ilist) {
            my @evt = grep { !-l && /\/$f\/[^\/]+\.jpg/} @plist;
            if ($#evt > 0) {
                $latest{$f} = sort { (stat($b))[9] <=> (stat($a))[9] } @evt;
            } else {
                $latest{$f} = $evt[0];
            }
        }
    }



    # target directory contains multiple files (and symlink pointing to last): displays existing thumbnails
    if ($#plist > 1) {
        my $month0 = "";
        my $dte0 = "";
        # target directory is not and event ID: will display only the most recent image for each event ID
        if ($depth < 3) {

        }
        for (@plist) {
            if ( ($depth < 3 && -l $_) || ($depth == 3 && ! -l $_)) {
                (my $JPGurn = $_) =~ s/$root_dir/$urn_dir/g;
                (my $EVENTid = $_) =~ s/$OUTD\/$WEBOBS{PATH_OUTG_EVENTS}\///g;
                if (-l $_) {
                    my $lnk = basename($_);
                    my $tgt = readlink($_);
                    $EVENTid =~ s/\Q$lnk\E/$tgt/g;
                }
                $EVENTid =~ s/\.jpg$//g;
                (my @evt) = split(/\//,$EVENTid);
                my $dte = l2u(strftime("%A %d %B %Y",0,0,0,$evt[2],$evt[1] - 1,$evt[0] - 1900));
                my $month = l2u(strftime("%B %Y",0,0,0,$evt[2],$evt[1] - 1,$evt[0] - 1900));
                my $msg = "ID: $evt[3]<BR>$evt[4]";
                if (($depth == 3 && $QryParm->{'g'} !~ m/\*/ && $month ne $month0) || ($depth == 2 && $QryParm->{'g'} !~ m/\*/) && $dte ne $dte0) {
                    print "<H2>$dte".($depth == 3 ? ": <I>$evt[3]</I>":"")."</H2>\n"; # date only if id not selected
                    $month0 = $month;
                    $dte0 = $dte;
                } elsif ($month ne $month0) {
                    print "<H2>$month".($depth > 2 ? ": <I>$evt[3]</I>":"")."</H2>\n";
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
                my $reqdir = ($OUTDIR ? "&dir=$OUTDIR" : "");
                print "<A href=\"$baseurl&ts=events&g=$target$reqdir\">",
                  "<IMG style=\"margin: 1px; background-color: beige; padding: 5px; border: 0$thumb\" src=\"$JPGurn\"",
                  "onMouseOut=\"nd()\" onMouseOver=\"overlib('$msg',CAPTION,'$dte')\"></A>\n";
            }
        }

# single file: displays .png (or .jpg) and links to other files (.eps,.pdf,.gse,.txt)
# note: @plist can content 1 file (direct access to the image), or 2 files (directory access = image + symlink)
    } elsif ($#plist >= 0) {
        my $addlinks = "";
        (my $short = $plist[0]) =~ s/\.jpg//g;
        (my $urn = $short) =~ s/$root_dir/$urn_dir/g;
        (my $EVENTid = $short) =~ s/$OUTD\/$WEBOBS{PATH_OUTG_EVENTS}\///g;
        (my @evt) = split(/\//,$EVENTid);
        my $dte = l2u(strftime("%A %d %B %Y",0,0,0,$evt[2],$evt[1] - 1,$evt[0] - 1900));
        # get the full list of images
        my @png_files = "";
        my $ydir = "$OUTD/$WEBOBS{PATH_OUTG_EVENTS}/$evt[0]";
        find(sub {
            return if -l $_;
            return unless /\.png$/i;
            push(@png_files, $File::Find::name);
        }, $ydir);
        @png_files = sort(@png_files);
        # extract the previous and next
        my $target = "$short.png";
        my $prev;
        my $next;
        my ($index) = grep { $png_files[$_] eq $target } 0 .. $#png_files;
        if (defined $index) {
            $prev = $index > 0            ? $png_files[$index - 1] : undef;
            $next = $index < $#png_files  ? $png_files[$index + 1] : undef;
            $prev =~ s/$OUTD\/$WEBOBS{PATH_OUTG_EVENTS}\/|\.png$//g if defined($prev);
            $next =~ s/$OUTD\/$WEBOBS{PATH_OUTG_EVENTS}\/|\.png$//g if defined($next);
            $addlinks .= (defined $prev ? "<A href=\"$baseurl&ts=events&g=$prev\"><IMG src=\"/icons/l13.png\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$prev',CAPTION,'Previous image')\"></A>":"")
                    .(defined $next ? "&nbsp;<A href=\"$baseurl&ts=events&g=$next\"><IMG src=\"/icons/r13.png\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$next',CAPTION,'Next image')\"></A>":"");
        }
        foreach ("eps","svg","pdf","gse","txt","kml") {
            if ( -e "$short.$_" ) {
                $addlinks .= " <A href=\"$urn.$_\"><IMG alt=\"$urn.$_\" src=\"/icons/f$_.png\"></A> ";
            }
        }

        # special case of .msg file (tremblemaps)
        if ( -e "$short.msg" ) {
            $addlinks .= " <A href=\"/cgi-bin/mailB3.pl?grid=$QryParm->{'grid'}&ts=events&g=$EVENTid\">"
              ."<IMG alt=\"$urn.msg\" src=\"/icons/fmail.png\"></A> ";
        }
        print "<H2>$dte: <I>$evt[3]&nbsp;/&nbsp;$evt[4]</I></H2>\n";
        print "$addlinks<BR>" if ($QryParm->{'header'} ne 'no');
        my $img = "$urn.png";
        if ( ! -f "$short.png" ) {
            $img = "$urn.jpg";
        }
        print "<IMG style=\"margin-bottom: 15px; background-color: beige; padding: 5px\" src=\"$img\"><BR>";
    }
    if ($QryParm->{'debug'}) {
        print "<P><B>now</B> $now, <B>ENV{TZ}</B> = $ENV{TZ}</P>\n";
        print "<P><B>nlist</B> (length=$#nlist) = ".join(", ", @nlist)."</P>\n";
        print "<P><B>ilist</B> (length=$#ilist) = ".join(", ", @ilist)."</P>\n";
        print "<P><B>plist</B> (length=$#plist) = ".join(", ", @plist)."</P>\n";
        print "<P><B>depth</B> = $depth</P>";
    }

    # -- case 'Timescales'
} else {

    # i.e "only display requested g= in query-string"
    # if none requested in query-string, show thumbnails of all available graphs
    if ($QryParm->{'g'} eq "") {

        for my $g (@glist) {
            (my $urn  = $g) =~ s/$root_dir/$urn_dir/g;
            $urn =~ s/\.png$/\.jpg/;
            (my $short = $g) =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
            $short =~ s/^$/SUMMARY/;
            print "<A href=\"$baseurl&ts=$tslist[$tsSelected]&g=$short\"><IMG style=\"margin-bottom: 2px; background-color: beige; padding: 2px\" src=\"$urn\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$short',CAPTION,'$tslist[$tsSelected]')\"></A> ";
        }

        # if g=col in query-string, show all available graphs in one column
    } elsif ($QryParm->{'g'} eq "col") {

        for my $g (@glist) {
            (my $urn  = $g) =~ s/$root_dir/$urn_dir/g;
            (my $short = $g) =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
            $short =~ s/^$/SUMMARY/;
            print "<A href=\"$baseurl&ts=$tslist[$tsSelected]&g=$short\"><IMG style=\"margin-bottom: 2px; background-color: beige; padding: 2px\" src=\"$urn\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$short',CAPTION,'$tslist[$tsSelected]')\"></A><BR> ";
        }

    } else {

        # prepare additional links to eps, svg, pdf and data
        my $addlinks = "";
        for my $i (0..$#elist) {
            if (-f $elist[$i]) {
                (my $surn = $elist[$i]) =~ s/$root_dir/$urn_dir/g;
                $elist[$i] =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
                $elist[$i] =~ s/^$/$GRIDName/;
                if ($elist[$i] eq $QryParm->{'g'}) {
                    $addlinks .= " <A href=\"$surn\"><IMG title=\"$QryParm->{'g'}.eps\" src=\"/icons/feps.png\"></A> ";
                }
            }
        }
        for my $i (0..$#slist) {
            if (-f $slist[$i]) {
                (my $surn = $slist[$i]) =~ s/$root_dir/$urn_dir/g;
                $slist[$i] =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
                $slist[$i] =~ s/^$/$GRIDName/;
                if ($slist[$i] eq $QryParm->{'g'}) {
                    $addlinks .= " <A href=\"$surn\"><IMG title=\"$QryParm->{'g'}.svg\" src=\"/icons/fsvg.png\"></A> ";
                }
            }
        }
        for my $i (0..$#plist) {
            if (-f $plist[$i]) {
                (my $surn = $plist[$i]) =~ s/$root_dir/$urn_dir/g;
                $plist[$i] =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
                $plist[$i] =~ s/^$/$GRIDName/;
                if ($plist[$i] eq $QryParm->{'g'}) {
                    $addlinks .= " <A href=\"$surn\"><IMG title=\"$QryParm->{'g'}.pdf\" src=\"/icons/fpdf.png\"></A> ";
                }
            }
        }
        for my $i (0..$#dlist) {
            if (-f $dlist[$i]) {
                (my $surn = $dlist[$i]) =~ s/$root_dir/$urn_dir/g;
                $dlist[$i] =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_EXPORT}\/(.*)_.*$/$1/;
                $dlist[$i] =~ s/^$/$GRIDName/;
                my $gts = $QryParm->{'g'}.'_'.$QryParm->{'ts'};
                if ( ($dlist[$i]=~m/^$QryParm->{'g'}/i) ) {
                    $addlinks .= " <A href=\"$surn\"><IMG title=\"$dlist[$i]\" src=\"/icons/fdata.png\"></A> ";
                }
            }
        }

        # if the PROC uses a default genform RAWFORMAT, adds a link to the database interface
        if ($GRID{RAWFORMAT} eq 'genform') {
            my $ucg = uc($QryParm->{'g'});
            my $opt = ( (grep { $_ eq $ucg } @{$GRID{NODESLIST}}) ? "&node=$ucg" : "" );
            $addlinks .= "<A href=\"/cgi-bin/showGENFORM.pl?form=$GRID{RAWDATA}$opt\"><IMG title=\"Access to FORM data\" src=\"/icons/form.png\"></A> ";
        }

        if ( $QryParm->{'g'} ne $GRIDName && !(grep( /^$QryParm->{'g'}$/i, @SummaryList)) && $QryParm->{'g'} eq lc($QryParm->{'g'}) ) {
            my $ucg = uc($QryParm->{'g'});
            $addlinks .= " <A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=PROC.$GRIDName.$ucg\"><IMG title=\"PROC.$GRIDName.$ucg\" src=\"/icons/fnode.png\"></A> ";
        }

        # finally plots the image !
        for my $g (@glist) {
            (my $map = $g) =~ s/\.png/\.map/;
            (my $urn  = $g) =~ s/$root_dir/$urn_dir/g;
            $g =~ s/^$OUTD\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
            $g =~ s/^$/SUMMARY/;
            if ($g eq $QryParm->{'g'}) {
                print "$addlinks<BR>" if ($QryParm->{'header'} ne 'no');
                print "<IMG style=\"margin-bottom: 15px; margin-top: 5 px; background-color: beige;\" src=\"$urn\" usemap=\"#map\"><BR>";
                if (-e "$map") {
                    my @htmlarea = readFile("$map");
                    print "<map name=\"map\">\n@htmlarea</map>\n";
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
        my @objects = ( glob("$OUTD/$WEBOBS{PATH_OUTG_GRAPHS}/*_*.eps"), glob("$OUTD/$WEBOBS{PATH_OUTG_EXPORT}/*_*.*") );
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

WebObs - 2012-2026 - Institut de Physique du Globe Paris

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
