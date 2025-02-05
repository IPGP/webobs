#!/usr/bin/perl

=head1 NAME

nloc.pl

=head1 SYNOPSIS

http://..../cgi-bin/nloc.pl?grid=[,nodes=][,coord=][,projet=]

=head1 DESCRIPTION

Dump NODE's location list in different formats.

=head1 Query string parameters

grid=
  gridtype.gridname[.nodeid] : all nodes of a grid or single node

nodes=
  { all | active | valid }
  default is all existing nodes.

today=
  forces a reference date for active nodes, format YYYY[-MM[-DD]] (default is today)
  must be used together with nodes=active

format=
  { txt | csv | kml }
  txt returns a tab-delimited text file of nodes (default)
  csv returns a semicolon-delimited text file of nodes (Excel compatible)
  kml returns a KML file of nodes (Google Earth compatible)

coord=
  { geo | utm | local | xyz }
  for txt and csv formats, specifies the type of coordinates:
  geo is latitude,longitude,altitude WGS84 (default)
  utm is eastern,northern,altitude UTM WGS84 (Universal Transverse Mercator)
  local is UTM in a local geodetic system (see UTM.rc)
  xyz is geocentric X,Y,Z coordinates (in m)
=cut

use strict;
use CGI;
use Switch;

use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Mapping;
use WebObs::Users qw(clientHasRead);

my $cgi = new CGI;

my $grid   = $cgi->url_param('grid');
my $nodes = $cgi->url_param('nodes');
my $today  = $cgi->url_param('today')  // qx(date +\%Y-\%m-\%d);
chomp($today);
my $format  = $cgi->url_param('format');
my $coord  = $cgi->url_param('coord');

my $file = "WEBOBS-$WEBOBS{WEBOBS_ID}.$grid";

my $GRIDName  = my $GRIDType  = my $NODEName = my $msk = "";
my @NID = split(/[\.\/]/, trim($grid));
($GRIDType, $GRIDName, $NODEName) = @NID;
if ( scalar(@NID) < 2 || !($GRIDType =~ /^PROC|VIEW/i) ) {
    die "No valid grid requested (NOT= gridtype.gridname[.node])." ;
}

# user must have read authorization to use this function
if ( ! clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
    die "Sorry, you cannot display this page.";
}

# ---- get all nodenames of grid (only VALID)
my %N = listGridNodes(grid=>"$GRIDType.$GRIDName");
my %G;
my %GRID;
if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
if (%G) {
    %GRID = %{$G{$GRIDName}} ;
} else {
    die "$grid does not exist."
}

switch (lc($format)) {
    case 'kml' {
        print $cgi->header(-type=>'application/vnd.google-earth.kml+xml', -attachment=>"$file.kml",-charset=>'utf-8');
        print "<?xml version=\"1.0\" encoding=\"UTF-8\"?><kml xmlns=\"http://earth.google.com/kml/2.0\">\n";
        print "<Document>\n<Style id=\"webobs\">
        <IconStyle>
            <color>ff1313f3</color>
            <scale>1.0</scale>
            <Icon>\n<href>http://maps.google.com/mapfiles/kml/shapes/triangle.png</href></Icon>
        </IconStyle>
        <LabelStyle>
            <scale>1</scale>
        </LabelStyle>
        </Style>\n";
        if (scalar(@NID)==2) {
            print "<Folder>\n<name>$grid</name>\n";
        }
    }
    case 'csv' {
        print $cgi->header(-type=>'text/csv', -attachment=>"$file.csv",-charset=>'utf-8');
        print "ALIAS;NAME;LATITUDE;LONGITUDE;ELEVATION;START_DATE;END_DATE;ACTIVE\r\n";
    }
    else {
        print $cgi->header(-type=>'text/csv', -attachment=>"$file.txt",-charset=>'utf-8');
    }
}

for (keys(%N)) {
    my $sta = $_;
    if ( scalar(@NID)==2 || $sta eq $NODEName ) {
        my %NODE = readNode($sta);
        my $active = (($NODE{$sta}{END_DATE} ge $today || $NODE{$sta}{END_DATE} eq "NA")
              && ($NODE{$sta}{INSTALL_DATE} le $today || $NODE{$sta}{INSTALL_DATE} eq "NA"));
        if (!($NODE{$sta}{LAT_WGS84} eq "" && $NODE{$sta}{LON_WGS84} eq "" && $NODE{$sta}{ALTITUDE} eq "") && (($nodes ne "active" || $active))) {
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

            switch (lc($format)) {
                case 'kml' {
                    print "<Placemark id=\"$sta\">
    <name>$alias : $name</name>
    <ExtendedData>
        <Data name=\"active\">
            <value>$active</value>
        </Data>
        <Data name=\"start\">
            <value>$start</value>
        </Data>
        <Data name=\"end\">
            <value>$end</value>
        </Data>
    </ExtendedData>
    <description>
        <![CDATA[<i>$type</i><br>$DOMAINS{$GRID{DOMAIN}}{NAME} / $GRID{NAME}<br><small>($GRIDType.$GRIDName.$sta)</small>]]>
    </description>
    <open>1</open>\n<styleUrl>#webobs</styleUrl>
    <Point>
        <coordinates>$NODE{$sta}{LON_WGS84},$NODE{$sta}{LAT_WGS84},$NODE{$sta}{ALTITUDE}</coordinates>
    </Point>
</Placemark>\n";
                }
                case 'csv' {
                    print "\"$alias\";$name;$lat;$lon;$alt;$start;$end;$active\r\n";
                }
                else {
                    print "$alias\t$name\t$lat\t$lon\t$alt\t$start\t$end\t$active\r\n";
                }
            }
        }
    }
}

if (lc($format) eq 'kml') {
    if (scalar(@NID)==2) {
        print "</Folder>\n";
    }
    print "</Document>\n</kml>\n";
}

exit;

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2022 - Institut de Physique du Globe Paris

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
