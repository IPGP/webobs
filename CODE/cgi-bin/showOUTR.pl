#!/usr/bin/perl

=head1 NAME

showOUTR.pl

=head1 SYNOPSIS

http://..../showOUTR.pl?dir=outdir[,grid=gridname]

=head1 DESCRIPTION

Displays contents of OUTR directory outdir for all available processed grids,
pointing initialy on the GRID gridname (ie. gridType.gridName) .

=cut

use strict;
use warnings;

$|=1;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

use WebObs::Config;
use WebObs::Grids;
use WebObs::Users qw($CLIENT clientHasAdm);
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
set_message(\&webobs_cgi_msg);
my %GRID;
my %G; my %P;
my $GRIDType = my $GRIDName = my $RESOURCE = my $OUTG = "";
my @GRIDList;
my @OUTGList;

my $QryParm   = $cgi->Vars;
my $OUTR;
my $OUTDIR = trim($QryParm->{'dir'});
my ($date,$time,$host,$user) = split(/_/,$OUTDIR);

# ---- check authorization: request owner or administrator
if ($user ne $CLIENT && !clientHasAdm(type=>"authprocs",name=>"*")) {
    die "Sorry, you're not the owner of this proc request.";
}

# ---- what grids do we have to process ?
my @GL = qx(find $WEBOBS{ROOT_OUTR}/$OUTDIR -type d \\( -name "PROC.*" -o -name "VIEW.*" -o -name "GRIDMAPS" \\) -maxdepth 1);
chomp(@GL);
foreach (@GL) {
    my $g = $_;
    $g =~ s/$WEBOBS{ROOT_OUTR}\/$OUTDIR\///;
    push(@GRIDList,$g);
}

$QryParm->{'g'}  ||= '';
$QryParm->{'grid'}  ||= $GRIDList[0];
($GRIDType, $GRIDName) = split(/[\.\/]/, trim($QryParm->{'grid'}));
if (-d "$WEBOBS{ROOT_OUTR}/$OUTDIR/$GRIDType.$GRIDName" ) {
    $OUTR = "$WEBOBS{ROOT_OUTR}/$OUTDIR/$GRIDType.$GRIDName";
} else { die "$__{'No outputs for'} $GRIDType.$GRIDName" }

if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
%GRID = %{$G{$GRIDName}} ;

# ---- good, we now have a grid defined and outputs to show

# ---- get the list of nodes currently belonging to grid
# ---- and the list of possible summary grid's summary filenames
my %DefinedNodes = listGridNodes(grid=>"$GRIDType.$GRIDName");
my @SummaryList  = split(/,/,$GRID{SUMMARYLIST});

# ---- Start HTML page
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<HTML><HEAD><title>OUTR for $OUTDIR</title>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";
print "</head><body>";
print "<!-- overLIB (c) Erik Bosrup --><div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\" type=\"text/javascript\"></script>";
print "<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>";
print "<script language=\"JavaScript\" src=\"/js/wolb.js\" type=\"text/javascript\"></script>";
print "<A NAME=\"MYTOP\"></A>";
print "<H1 style=\"margin-bottom:6pt\">$GRID{NAME}</H1>\n";
my $go2top = "<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";

# ---- build the top-of-page outputs selection banner:
# 1st line for GRID selection
# 2nd line for output selection
print "<DIV id='selbanner' style='background-color: beige; padding: 5px; margin-bottom:10px;'>";
print "<B>»»</B> [ <A href=\"/cgi-bin/showGRID.pl?grid=$GRIDType.$GRIDName\"><B>".ucfirst(lc($GRIDType))."</B></A>";
foreach (@GRIDList) {
    if ($QryParm->{'grid'} eq $_ ) {
        print " | <B>$_</B>";
    } else {
        print " | <B><A href=\"/cgi-bin/showOUTR.pl?dir=$QryParm->{'dir'}&grid=$_\">$_</A></B>";
    }
}
print " ]\n";

# build $elist = the list of available .eps graphs
my (@elist) = glob "$OUTR/$WEBOBS{PATH_OUTG_GRAPHS}/*_.eps";

# build $plist = the list of available .pdf graphs
my (@plist) = glob "$OUTR/$WEBOBS{PATH_OUTG_GRAPHS}/*_.pdf";

# build $dlist = the list of available data/**.* for timescale $tslist[$tsSelected]
my (@dlist) = glob "$OUTR/$WEBOBS{PATH_OUTG_EXPORT}/*_.*";

# build $glist = the list of available .png graphs for timescale $tslist[$tsSelected]
# $glistHtml is the corresponding string of html hrefs to these graphs
# with each nodenames replaced with their alias if it is defined
my (@glist) = glob "$OUTR/$WEBOBS{PATH_OUTG_GRAPHS}/*_.png";
my $glistHtml = "";
for my $fpath (@glist) {
    my $short = $fpath;
    $short =~ s/^$OUTR\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
    $short =~ s/^$/$GRIDName/;
    my $shorter = ($short eq $GRIDName ? "Summary":$short);
    if ($short ne $GRIDName && !(grep( /^$short$/i, @SummaryList)) ) {
        if ( grep( /^$short$/i, keys(%DefinedNodes)) ) {  # it's a node file AND node still in proc
            my $alias = getNodeString(node=>uc($short), style=>'alias');
            $shorter = $alias if ( $alias ne '' && $alias ne '-' );
        }
    }
    if ($QryParm->{'g'} eq $short) {
        $glistHtml .= " $shorter |";
    } else {
        $glistHtml .= " <A href=\"/cgi-bin/showOUTR.pl?dir=$QryParm->{'dir'}&grid=$GRIDType.$GRIDName&g=$short\"> $shorter</A> |";
    }
}
chop($glistHtml);
print "<BR><B>[ ".$glistHtml." ]</B>\n";
print "</DIV>";

# ---- now show the selected item

# i.e "only display requested g= in query-string"
# if none requested in query-string, use the first item of $glist
if ($QryParm->{'g'} eq "") {
    $QryParm->{'g'} = $glist[0];
    $QryParm->{'g'} =~ s/^$OUTR\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
    $QryParm->{'g'} =~ s/^$/$GRIDName/;
}

# prepare additional links to eps, pdf and data
my $addlinks = "";
for my $i (0..$#elist) {
    if (-f $elist[$i]) {
        (my $surn = $elist[$i]) =~ s/$WEBOBS{ROOT_OUTR}/$WEBOBS{URN_OUTR}/g;
        $elist[$i] =~ s/^$OUTR\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
        $elist[$i] =~ s/^$/$GRIDName/;
        if ($elist[$i] eq $QryParm->{'g'}) {
            $addlinks .= " <A href=\"$surn\"><IMG alt=\"$QryParm->{'g'}.eps\" src=\"/icons/feps.png\"></A> ";
        }
    }
}
for my $i (0..$#plist) {
    if (-f $plist[$i]) {
        (my $surn = $plist[$i]) =~ s/$WEBOBS{ROOT_OUTR}/$WEBOBS{URN_OUTR}/g;
        $plist[$i] =~ s/^$OUTR\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
        $plist[$i] =~ s/^$/$GRIDName/;
        if ($plist[$i] eq $QryParm->{'g'}) {
            $addlinks .= " <A href=\"$surn\"><IMG alt=\"$QryParm->{'g'}.pdf\" src=\"/icons/fpdf.png\"></A> ";
        }
    }
}
for my $i (0..$#dlist) {
    if (-f $dlist[$i]) {
        (my $surn = $dlist[$i]) =~ s/$WEBOBS{ROOT_OUTR}/$WEBOBS{URN_OUTR}/g;
        $dlist[$i] =~ s/^$OUTR\/$WEBOBS{PATH_OUTG_EXPORT}\/(.*)_.*$/$1/;
        $dlist[$i] =~ s/^$/$GRIDName/;
        ##if ($dlist[$i] eq $QryParm->{'g'}) {
        if ( ($dlist[$i]=~m/$QryParm->{'g'}/i) ) {
            $addlinks .= " <A href=\"$surn\"><IMG alt=\"$QryParm->{'g'}.txt\" src=\"/icons/fdata.png\"></A> ";
        }
    }
}
if ($QryParm->{'g'} ne $GRIDName && !(grep( /^$QryParm->{'g'}$/i, @SummaryList)) ) {
    my $ucg = uc($QryParm->{'g'});
    $addlinks .= " <A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=PROC.$GRIDName.$ucg\"><IMG alt=\"$QryParm->{'g'}\" src=\"/icons/fnode.png\"></A> ";
}
for my $g (@glist) {
    (my $map = $g) =~ s/\.png/\.map/;
    (my $urn  = $g) =~ s/$WEBOBS{ROOT_OUTR}/$WEBOBS{URN_OUTR}/g;
    $g =~ s/^$OUTR\/$WEBOBS{PATH_OUTG_GRAPHS}\/(.*)_.*$/$1/;
    $g =~ s/^$/$GRIDName/;
    if ($g eq $QryParm->{'g'}) {
        print "$addlinks<BR>";
        print "<IMG style=\"margin-bottom: 15px; background-color: beige; padding: 5px\" src=\"$urn\" usemap=\"#map\"><BR>";
        if (-e "$map") {
            my @htmlarea = readFile("$map");
            print "<map name=\"map\">@htmlarea</map>\n";
        }
    }
}

print "<BR>$go2top</BR>";

# ---- We're done !
print "</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

François Beauducel, Didier Lafon

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
