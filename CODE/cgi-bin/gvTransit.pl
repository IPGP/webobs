#!/usr/bin/perl

=head1 NAME

gvTransit.pl 

=head1 SYNOPSIS

http://..../gvTransit.pl?grid=normgrid

=head1 DESCRIPTION

Grid diagram using GraphViz directed graph.

=head1 Query string parameters

=over

=item B<grid=normgrid>

Grid normalized name to be displayed

=back

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use WebObs::Config;
use WebObs::Grids;
use WebObs::Users;
use WebObs::Utils;
use GraphViz;
$|=1;

set_message(\&webobs_cgi_msg);

my $gv;

sub nodeURL {
    if ( $_[0] ) {
        if ( $_[0] =~ m/^\w+\.\w+\.\w+$/ ) { return "/cgi-bin/$NODES{CGI_SHOW}?node=$_[0]" }
        if ( $_[0] =~ m/^\w+\.\w+$/ ) { return "/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=$_[0]" }
        if ( $_[0] =~ m/^\w+$/ ) {
            my $tmp = normNode(node => "..$_[0]");
            if ($tmp ne "") { return "/cgi-bin/$NODES{CGI_SHOW}?node=$tmp" }
        }
    }
    return ""
}

# ---- helper: grow a tree (nodes, edges and clusters) from $rootname 
#
sub tree {
    my ($rootname, $cluster, $ar, $clusterthru, $Nthru, $tc);
    if (scalar(@_) == 3) { ($rootname, $cluster, $ar) = @_;}
    if (scalar(@_) == 5) { ($rootname, $cluster, $ar, $clusterthru, $Nthru) = @_;}
    my @array=@$ar;
    $gv->add_node($rootname, style=>'filled', color=>'white');
    for my $Nn (@array) {
        my $tmp = nodeURL($Nn);

#$gv->add_node($Nn, style=>'filled', color=>'white', cluster=>$$cluster, URL => "$tmp");
        $gv->add_node($Nn, cluster=>$$cluster, URL => "$tmp");
        if (defined($clusterthru)) {
            $tmp = nodeURL($Nthru);

#$gv->add_node($Nthru, style=>'filled', color=>'white', cluster=>$$clusterthru, URL => "$tmp");
            $gv->add_node($Nthru, cluster=>$$clusterthru, URL => "$tmp");
            $tc = $$clusterthru->{color};
            $gv->add_edge("$rootname" => "$Nthru", dir => 'none',  color=>$tc);
            $gv->add_edge("$Nthru" => "$Nn", dir => 'none', color=>$tc);
        } else {
            $tc = $$cluster->{color};
            $gv->add_edge("$rootname" => "$Nn", dir => 'none', color=>$tc);
        }
    }
}

# ---- Main
#
my $svg = "";
my $dbg = "";
my %G;
my %S;
my %GRID;
my $GRIDType = my $GRIDName = "";
my %NODE;
my @tl; my @tl2;

my $QryParm   = $cgi->Vars;
my @GID = split(/[\.\/]/, trim($QryParm->{'grid'}));
if (scalar(@GID) == 2) {
    ($GRIDType, $GRIDName) = @GID;
    if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
    elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
    elsif  (uc($GRIDType) eq 'FORM') { %G = readForm($GRIDName) }
    if (%G) {
        %GRID = %{$G{$GRIDName}} ;
        if ( ! WebObs::Users::clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
            die "You cannot display $GRIDType.$GRIDName"
        }
    } else { die "Couldn't get $GRIDType.$GRIDName configuration." }
} else { die "No valid GRID requested (NOT gridtype.gridname)." }

# ---- fine, passed all checkings
#

# ---- clusters draw styles
#
my $cluster_node   = {style=>'filled', fillcolor=>'#DDDDDD',  color=>'#DDDDDD'};
my $cluster_trans  = {style=>'filled', fillcolor=>'#8888AA',  color=>'#8888AA'};
my $cluster_2trans = {style=>'filled', fillcolor=>'#DDDDDD',  color=>'#8888AA'};
my $cluster_isof   = {style=>'filled', fillcolor=>'#AA8888',  color=>'#AA8888'};
my $cluster_2isof  = {style=>'filled', fillcolor=>'#DDDDDD',  color=>'#88CC88'};
my $cluster_has    = {style=>'filled', fillcolor=>'#AAAA88',  color=>'#AAAA88'};
my $cluster_2has   = {style=>'filled', fillcolor=>'#DDDDDD',  color=>'#AAAA88'};
my $cluster_procs  = {style=>'filled', fillcolor=>'#C16E76',  color=>'#C16E76'}; # firebrick 2/3
my $cluster_views  = {style=>'filled', fillcolor=>'#559855',  color=>'#559855'}; # darkgreen 2/3
my $cluster_forms  = {style=>'filled', fillcolor=>'#FFB255',  color=>'#FFB255'}; # darkorange 2/3

my $legend  = "<table border=\"0\" style=\"border-collapse: separate; padding: 0 5px\">";
$legend .= "<tr><td style=\"background-color:$cluster_node->{'color'}\">$GRIDType.$GRIDName nodes</td>";
$legend .= "<td style=\"background-color:$cluster_trans->{'color'}\">transmission nodes</td>";
$legend .= "<td style=\"background-color:$cluster_isof->{'color'}\">'is feature of' nodes</td>";
$legend .= "<td style=\"background-color:$cluster_has->{'color'}\">'has feature' nodes</td>";
$legend .= "<td style=\"background-color:$cluster_views->{'color'}\">associated views</td>";
$legend .= "<td style=\"background-color:$cluster_procs->{'color'}\">associated procs</td>";
$legend .= "<td style=\"background-color:$cluster_forms->{'color'}\">associated forms</td>";
$legend .= "</table>";

# ---- build a directed graph starting from a WebObs' VIEW (aka root-VIEW)
#

my $rankdir = 'TB';
$gv = GraphViz->new(layout => 'dot', rankdir => $rankdir, name => "$GRIDType$GRIDName", node => { height=>'.10', width=>'0.3',  fontsize=>'8', color=>'none', shape =>'plaintext'}, stylesheet => "/css/transit.css");

# first tree = GRIDName -> all of its NODES (valid and active today)

my %H = listGridNodes(grid=>"$GRIDType.$GRIDName", valid=>1, active=>'today');
my @gs  = keys(%H);
tree("$GRIDType.$GRIDName", \$cluster_node, \@gs);

# next trees = for each root-GRID's NODE, find associated NODES that 
# belong themselves to GRIDS. Show this associated GRIDS

for my $Nn (@gs) {
    my %N = readNode($Nn);
    if (%N) {
        my %NODE = %{$N{$Nn}};

        # associated VIEWS from NODE's list of "transmission nodes"
        if (defined($NODE{TRANSMISSION})) {
            $NODE{TRANSMISSION} =~ s/(^[0-9][,]?)?//;
            for (split(/\|/,$NODE{TRANSMISSION})) {
                next if ( (!defined($QryParm->{'iref'})) && $_ ~~ $GRID{NODESLIST} );
                @tl = qx(ls -d $WEBOBS{PATH_GRIDS2NODES}/VIEW.*.$_ 2>/dev/null);
                for (@tl) {s/$WEBOBS{PATH_GRIDS2NODES}\/(.*)\..*$/$1/g;}
                chomp(@tl);
                tree($Nn, \$cluster_trans, \@tl, \$cluster_2trans, $_);
            }
        }

        # associated VIEWS from NODE's list from nodes2nodes.rc with NODE as RHS
        for (qx(grep ".*\|.*\|$Nn" $WEBOBS{ROOT_CONF}/nodes2nodes.rc)) {
            chomp($_);
            my($n1,$junk) = split(/\|/,$_);
            next if ( (!defined($QryParm->{'iref'})) && $n1 ~~ $GRID{NODESLIST} );
            @tl = qx(ls -d $WEBOBS{PATH_GRIDS2NODES}/VIEW.*.$n1 2>/dev/null);
            for (@tl) {s/$WEBOBS{PATH_GRIDS2NODES}\/(.*)\..*$/$1/g;}
            chomp(@tl);
            tree($Nn, \$cluster_isof, \@tl, \$cluster_2isof, $n1);
        }

        # associated VIEWS from NODE's list from nodes2nodes.rc with NODE as LHS
        for (qx(grep "$Nn\|.*\|.*" $WEBOBS{ROOT_CONF}/nodes2nodes.rc)) {
            chomp($_);
            my($junka,$junkb,$n1) = split(/\|/,$_);
            $n1 =~ s/^(.*)[\n\t\r]$/$1/g;
            next if ( (!defined($QryParm->{'iref'})) && $n1 ~~ $GRID{NODESLIST} );
            @tl = qx(ls -d $WEBOBS{PATH_GRIDS2NODES}/VIEW.*.$n1 2>/dev/null);
            for (@tl) {s/$WEBOBS{PATH_GRIDS2NODES}\/(.*)\..*$/$1/g;}
            chomp(@tl);
            tree($Nn, \$cluster_has, \@tl, \$cluster_2has, $n1);
        }

# associated PROCS and VIEWS from NODE's configuration lists of PROCS and VIEWS
# these ones rely on PROC| and VIEW| variables in NODE's conf: might not be defined
#@tl = grep {s/(.*)/PROC.$1/ && $_ ne "$GRIDType.$GRIDName"} split(/,/,$NODE{PROC});
#tree($Nn, \$cluster_procs, \@tl) if (scalar(@tl) > 0);
#@tl = grep {s/(.*)/VIEW.$1/ && $_ ne "$GRIDType.$GRIDName"} split(/,/,$NODE{VIEW});
#tree($Nn, \$cluster_views, \@tl) if (scalar(@tl) > 0);

 # associated PROCS and VIEWS from NODE's configuration lists of PROCS and VIEWS
 # these ones use listNodeGrids() that costs more but is safer
        my %HoA;
        %HoA = listNodeGrids(node=>$Nn,type=>'PROC');
        @tl = grep { $_ ne "$GRIDType.$GRIDName"} @{$HoA{$Nn}};
        tree($Nn, \$cluster_procs, \@tl) if (scalar(@tl) > 0);
        %HoA = listNodeGrids(node=>$Nn,type=>'VIEW');
        @tl = grep { $_ ne "$GRIDType.$GRIDName"} @{$HoA{$Nn}};
        tree($Nn, \$cluster_views, \@tl) if (scalar(@tl) > 0);
        %HoA = listNodeGrids(node=>$Nn,type=>'FORM');
        @tl = grep { $_ ne "$GRIDType.$GRIDName"} @{$HoA{$Nn}};
        tree($Nn, \$cluster_forms, \@tl) if (scalar(@tl) > 0);
    }
}
$svg = $gv->as_svg;

# Uncomment for debugging
#$dbg = $gv->as_debug;
$svg =~ s/<\?xml.*>[\n]*//;
$svg =~ s/<!DOCTYPE.*[\n].*>[\n]*//;

print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print <<"FIN";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>GRID diagram</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/transit.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
</head>
<body>
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>
FIN
if (defined($QryParm->{'iref'})) { print "iref set" }

if (defined($svg)) {

#djl-TBD: remove all attributes 'style=' so that FF can apply css rules .... 
#djl-TBD: fontsize only used here (ie. at svg build time) as it participate in nodes' polygon sizes! 
    print "<h3>$GRIDType.$GRIDName</h3>\n";
    print "<DIV class=\"gvTlegend\">";
    print "$GRIDType.$GRIDName root nodes are those <i>valid</i> and <i>active</i> today<BR>";
    print "$legend";
    print "</DIV><BR>\n";
    print "<DIV style=\"border: 1px solid grey;\">";
    print $svg;
    print "</DIV>";
} else {die "Unable to create svg for ".$GRIDType.$GRIDName}

if ($dbg) {
    open(WRT, ">$WEBOBS{PATH_TMP_APACHE}/gv");
    print(WRT $dbg);
    close(WRT);
}
print "<br>\n</body>\n</html>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon

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

