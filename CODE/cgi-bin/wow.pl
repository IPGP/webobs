#!/usr/bin/perl

=head1 NAME

wow.pl 

=head1 SYNOPSIS

curl -su userid:password 'webobsURL/wow.pl?F=functionName(functionArgs){&F=...}'

=head1 DESCRIPTION

http to remotely query WebObs objects and definitions, reserved for WebObs admins.

=pod

=head1 FUNCTIONS

=head2 SYNTAX 

	curl -u userid:password  'siteUrl/wow.pl?F=functionCall{&F=functionCall}'

	functionCall := functionName(functionArgs)
	functionName := webobs | grids | proc | view | nodes | node | nloc
	functionArgs := argument {, argument {, argument ...} }

	argument     := functionName-specific
	argument     := nodeSpecs
	argument     := filter (regexp to select configuration variables)

	nodeSpecs    := nodeName{|nodeName{|nodeName}...}
	nodeSpecs    := grid{|validonly|active}

	grid         := gridType.gridName
	validonly    := 0 | 1
	active       := today | YYYY-MM-DD | YYYY-MM-DD:YYYY-MM-DD

=cut

use strict;
use CGI;

use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::IGN;

my $cgi = new CGI;
my @out = '';
my $attachFn = "WEBOBS-$WEBOBS{WEBOBS_ID}-wow";

# ---- vectors functionNames to their subroutine
#
my %vectors =
	( 
		'webobs'    => \&do_webobs ,
		'grids'     => \&do_grids ,
		'proc'      => \&do_dumpproc ,
		'view'      => \&do_dumpview ,
		'node'      => \&do_dumpnode ,
		'nodes'     => \&do_listnodes ,
		'nloc'      => \&do_nloc ,
	);

# main loop, if user (CLIENT) is authorized
# process each requested function "functionName" in query-string : F=functionName(functionArgs) ;
# all functions must return their output as an array whose 1st element is the required http header
if (WebObs::Users::clientHasAdm(type=>"authmisc",name=>"users")) {
	my @funs = $cgi->param('F');
	my @funout;
	for my $fun (@funs) {
		$fun =~ /(.*)\((.*)\)/ ; 
		my $f = $1; my @fargl = split(/,/,$2);
		if (exists($vectors{$f})) {
			eval { @funout = &{$vectors{$f}} (@fargl) }
		}
	}
	map { print "$_" } @funout;
	print "\n";
}
exit;

# ---- F= functions' vectored subroutines -------------------------------------
#

=pod

=head2 webobs(filter)

dump WEBOBS.rc contents as $WEBOBS{name}=value , where name(s) match filter.

	$ curl -su user:pass 'webobs.site/cgi-bin/wow.pl?F=webobs(SCHED)'
	$WEBOBS{CONF_SCHEDULER}=/opt/webobs/CONF/scheduler.rc

=cut

sub do_webobs {
	my @out;
	my $regexp = $_[0] || ".*";
	push(@out, $cgi->header(-type=>'text/html', -attachment=>"$attachFn.txt", -charset=>'utf-8') );
	my @L = grep {/$regexp/} sort (keys(%WebObs::Config::WEBOBS));
	map { push(@out, "\$WEBOBS{$_}=$WebObs::Config::WEBOBS{$_}\n") } @L;
	return @out;
}

=pod

=head2 grids(filter)

dump GRIDS.rc contents as $GRIDS{name}=value , where name(s) match filter

	$ curl -su user:pass 'webobs.site/cgi-bin/wow.pl?F=grids(SPATH_)'
	$GRIDS{SPATH_DOCUMENTS}=DOCUMENTS
	$GRIDS{SPATH_FEATURES}=FEATURES
	$GRIDS{SPATH_INTERVENTIONS}=INTERVENTIONS
	...etc...

=cut

sub do_grids {
	my @out;
	my $regexp = $_[0] || ".*";
	push(@out, $cgi->header(-type=>'text/html', -attachment=>"$attachFn.txt", -charset=>'utf-8') );
	my @L = grep {/$regexp/} sort (keys(%WebObs::Grids::GRIDS));
	map { push(@out, "\$GRIDS{$_}=$WebObs::Grids::GRIDS{$_}\n") } @L;
	return @out;
}

=pod

=head2 proc(procname{,filter})

dump procname.rc contents as PROC.procname{name}=value, with names(s) ordered alphabetically.
Optional filter to select the dumped name(s).

	$ curl -su user:pass 'webobs.site/cgi-bin/wow.pl?F=proc(CGPSWI,COPYRIGHT)'
	PROC.CGPSWI{COPYRIGHT}=OVS/IPGP

=cut

sub do_dumpproc {
	my @out;
	push(@out, $cgi->header(-type=>'text/html', -attachment=>"$attachFn.txt", -charset=>'utf-8') );
	if (exists($_[0])) { 
		my %proc = WebObs::Grids::readProc($_[0]);
		for my $l (keys(%proc)) { 
			for ( sort(keys(%{$proc{$l}})) ) {
				next if (exists($_[1]) && !/$_[1]/);
				my $var = $proc{$l}{$_};
				if (ref($var) eq 'ARRAY') {
					push(@out, "PROC.$l\{$_\}=".join(",",@{$var})."\n");
				} else {
					push(@out, "PROC.$l\{$_\}=$var\n");
				}
			}
		}	
	}
	return @out;
}


=pod

=head2 view(viewname{,filter})

dump viewname.rc contents as VIEW.viewname{name}=value, with names(s) ordered alphabetically.
Optional filter to select the dumped name(s).

	$ curl -su user:pass 'webobs.site/cgi-bin/wow.pl?F=view(CGPSWI,^TYPE|^NAME)'
	VIEW.CGPSWI{NAME}=GNSS West Indies
	VIEW.CGPSWI{TYPE}=

=cut

sub do_dumpview {
	my @out;
	push(@out, $cgi->header(-type=>'text/html', -attachment=>"$attachFn.txt", -charset=>'utf-8') );
	if (exists($_[0])) { 
		my %view = WebObs::Grids::readView($_[0]);
		for my $l (keys(%view)) { 
			for ( sort(keys(%{$view{$l}})) ) {
				next if (exists($_[1]) && !/$_[1]/);
				my $var = $view{$l}{$_};
				if (ref($var) eq 'ARRAY') {
					push(@out, "VIEW.$l\{$_\}=".join(",",@{$var})."\n");
				} else {
					push(@out, "VIEW.$l\{$_\}=$var\n");
				}
			}
		}	
	}
	return @out;
}

=pod

=head2 node(nodeSpecs,nodeFilter)

dump node(s) configuration file(s) (*cnf) contents as nodename{name}=value ,
for all nodes matching nodeSpecs. Only variables whose names match nodeFilter are dumped.

	$ curl -su user:pass 'webobs.site/cgi-bin/wow.pl?F=node(PROC.CGPSWI|1|today)'
	WDCABD0{ALIAS}=ABD0
	WDCABD0{ALTITUDE}=12
	...
	WDCBIM0{ALIAS}=BIM0
	...
	WDCCBE0{ALIAS}=CBE0
	...

=cut

sub do_dumpnode {
	my @out;
	push(@out, $cgi->header(-type=>'text/html', -attachment=>"$attachFn.txt", -charset=>'utf-8') );
	if (exists($_[0])) {
		my $re = (exists($_[1])) ? $_[1] : ".*";
		for my $n (h_listnodes($_[0])) {
			my %node = WebObs::Grids::readNode($n);
			for my $l (keys(%node)) {
				grep { /$re/ && push(@out, "$l\{$_\}=$node{$l}{$_}\n") } sort(keys(%{$node{$l}}));
			}	
		}
	}
	return @out;
}

=pod

=head2 nodes(nodeSpecs)

list nodes (ie. nodenames) matching nodeSpecs

	$ curl -su user:pass 'webobs.site/cgi-bin/wow.pl?F=nodes(PROC.CGPSWI)'
	WDCABD0
	WDCBIM0
	WDCCBE0
	...etc...

=cut

sub do_listnodes {
	my @out;
	push(@out, $cgi->header(-type=>'text/html', -attachment=>"$attachFn.txt", -charset=>'utf-8') );
	if (exists($_[0])) {
		map { push(@out, "$_\n") } h_listnodes($_[0]);
	}
	return @out;
}

=pod

=head2 nloc(nodeSpecs,coord,format)

dump locations of nodes of a grid in different formats.

	nodeSpecs must be of the form grid{|validonly|active} (ie. nodes list not allowed).

	coord :=   geo | utm | local | xyz 
		for txt and csv formats, specifies the type of coordinates:
		geo is latitude,longitude,altitude WGS84 (default)
		utm is eastern,northern,altitude UTM WGS84 (Universal Transverse Mercator)
		local is UTM in a local geodetic system (see UTM.rc)
		xyz is geocentric X,Y,Z coordinates (in m)

	format :=   txt | csv | kml 
		txt returns a tab-delimited text file of nodes (default)
		csv returns a semicolon-delimited text file of nodes (Excel compatible)
		kml returns a KML file of nodes (Google Earth compatible) 

=cut

sub do_nloc {
	my @out;
	if (exists($_[0])) {
		my @grid = h_nspecgrid($_[0]);
		if (@grid) {
			my %G; my %GRID;
			if (uc($grid[0]) eq 'VIEW') { %G = readView($grid[1]) }
			elsif (uc($grid[0]) eq 'PROC') { %G = readProc($grid[1]) }
			if (%G) { %GRID = %{$G{$grid[1]}} }
			my $coord = exists($_[1]) ? $_[1] : 'geo';
			my $fmt   = exists($_[2]) ? $_[2] : 'txt';
			my @N = h_listnodes($_[0]);
			if ( $fmt =~ /kml/i ) {
				push(@out, $cgi->header(-type=>'application/vnd.google-earth.kml+xml', -attachment=>"$attachFn.kml",-charset=>'utf-8'));
				push(@out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><kml xmlns=\"http://earth.google.com/kml/2.0\">\n");
				push(@out, "<Document>\n<Style id=\"webobs\">
				<IconStyle>
					<color>ff1313f3</color>
					<scale>1.0</scale>
					<Icon>\n<href>http://maps.google.com/mapfiles/kml/shapes/triangle.png</href></Icon>
				</IconStyle>
				<LabelStyle>
					<scale>1</scale>
				</LabelStyle>
				</Style>\n");
				push(@out, "<Folder>\n<name>$grid[0].$grid[1]</name>\n"); 
			}
			if ( $fmt =~ /csv/i ) {
				push(@out, $cgi->header(-type=>'text/csv', -attachment=>"$attachFn.csv",-charset=>'utf-8'));
			}
			if ( $fmt =~ /txt/i ) {
				push(@out, $cgi->header(-type=>'text/csv', -attachment=>"$attachFn.txt",-charset=>'utf-8'));
			}
			for my $sta (@N) {
				my %NODE = readNode($sta);
				if (!($NODE{$sta}{LAT_WGS84} eq "" && $NODE{$sta}{LON_WGS84} eq "" && $NODE{$sta}{ALTITUDE} eq "")) {
					my $alias = $NODE{$sta}{ALIAS};
					my $name = $NODE{$sta}{NAME};
					my $type = $NODE{$sta}{TYPE};
					my $start = $NODE{$sta}{INSTALL_DATE};
					my $end = $NODE{$sta}{END_DATE};
					my $lat = $NODE{$sta}{LAT_WGS84};
					my $lon = $NODE{$sta}{LON_WGS84};
					my $alt = $NODE{$sta}{ALTITUDE};
					if ($coord eq "utm") {
						($lat,$lon) = geo2utm($lat,$lon);
						$lat = sprintf("%.0f",$lat);
						$lon = sprintf("%.0f",$lon);
					} elsif ($coord eq "local") {
						($lat,$lon) = geo2utml($lat,$lon);
						$lat = sprintf("%.0f",$lat);
						$lon = sprintf("%.0f",$lon);
					} elsif ($coord eq "xyz") {
						($lat,$lon,$alt) = geo2cart($lat,$lon,$alt);
						$lat = sprintf("%.0f",$lat);
						$lon = sprintf("%.0f",$lon);
						$alt = sprintf("%.0f",$alt);
					}
		
					if ( $fmt =~ /kml/i ) {
						push(@out, "<Placemark id=\"$sta\">\n<name>$alias : $name</name>\n");
						push(@out, "<description><![CDATA[<i>$type</i><br>$DOMAINS{$GRID{DOMAIN}}{NAME} / $GRID{NAME}<br><small>($grid[0].$grid[1].$sta)</small>]]></description>\n");
						push(@out, "<open>1</open>\n<styleUrl>#webobs</styleUrl>\n");
						push(@out, "<Point><coordinates>$NODE{$sta}{LON_WGS84},$NODE{$sta}{LAT_WGS84},$NODE{$sta}{ALTITUDE}</coordinates></Point>\n</Placemark>\n");
					}
					if ( $fmt =~ /csv/i ) {
						push(@out, "\"$alias\";$name;$lat;$lon;$alt;$start;$end\r\n");
					}
					if ( $fmt =~ /txt/i ) {
						push(@out, "$alias\t$name\t$lat\t$lon\t$alt\t$start\t$end\n");
					}
				}
			}
			if ( $fmt =~ /kml/i) { 
				push(@out, "</Folder>\n");
				push(@out, "</Document>\n</kml>\n");
			}
		}
	}
	return @out;
}

# ---- internal helper functions -----------------------------------------------
#

sub h_listnodes {
	# argument is a [nodeSpecs], ie:
	#   := nodeName{|nodeName{|nodeName}...} 
	#   := grid{|validonly|active}
	# returns an array of nodeNames matching argument
	if (exists($_[0])) {
		my $nodeSpecs = trim($_[0]);
		my @nodeSpecs = split(/\|/,$nodeSpecs);
		my @firstel = split(/\./,$nodeSpecs[0]);
		if (scalar(@firstel) == 2) { # if 1st element looks like a normalized grid (gridtype.gridname)
			$nodeSpecs[1] = 0 if !exists($nodeSpecs[1]); # not validonly (ie. all)
			$nodeSpecs[2] = '' if !exists($nodeSpecs[2]); # no (act as not defined) active date 
			my %N = listGridNodes(grid=>$nodeSpecs[0],valid=>$nodeSpecs[1],active=>$nodeSpecs[2]);
			#return map { "$nodeSpecs[0].$_"} sort keys(%N); # use for normalized nodenames
			return sort keys(%N);
		} else {                     # if 1st element is not a normalized grid
			return grep { -d "$WEBOBS{PATH_NODES}/$_" } sort @nodeSpecs; # return existing nodes only
		}
	}
}

sub h_nspecgrid {
	# argument is a [nodeSpec]
	# returns array (gridtype,gridname) if it is looks like a normalized gridname, undef otherwise
	if (exists($_[0])) {
		my $nodeSpecs = trim($_[0]);
		my @nodeSpecs = split(/\|/,$nodeSpecs);
		my @firstel = split(/\./,$nodeSpecs[0]);
		return @firstel if (scalar(@firstel ==2));
	}
	return undef;
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2015 - Institut de Physique du Globe Paris

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

