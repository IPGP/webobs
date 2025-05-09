#!/usr/bin/perl

=head1 NAME
OSM.pl
=head1 SYNOPSIS
http://..../OSM.pl?...(see Query String parameters)....
=head1 DESCRIPTION
HTML page with OpenStreetMap for a GRID.
=head1 Query string parameters
grid=
  gridtype.gridname           : map with all nodes of grid
  gridtype.gridname.nodename  : map centered on nodename + all nodes of grid
today=
  forces a date (defaults to today)
nodes=
  { active | valid }
width=
height=
  defaulted to corresponding OSM_xxxx_VALUE key in WEBOBS.rc
=cut

use strict;
use warnings;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Mapping;

my $title="";
my @nodes;

# ---- what have we been called with ? ---------------
#
my $grid   = $cgi->url_param('grid');
my $opt    = $cgi->url_param('nodes');
my $width  = $cgi->url_param('width')  // $WEBOBS{OSM_WIDTH_VALUE};
my $height = $cgi->url_param('height') // $WEBOBS{OSM_HEIGHT_VALUE};
my $today  = $cgi->url_param('today')  // qx(date +\%Y-\%m-\%d);
chomp($today);

my $GRIDName  = my $GRIDType  = my $NODEName = my $msk = "";
my @NID = split(/[\.\/]/, trim($grid));
if (scalar(@NID) < 2) {
    die "No valid grid requested (NOT= gridtype.gridname[.node])." ;
}
($GRIDType, $GRIDName, $NODEName) = @NID;

# ---- get all nodenames of grid (only VALID) and fullfill a HoH
my %N = listGridNodes(grid=>"$GRIDType.$GRIDName");

# lat/lon to center the map
my $lat = my $lon = "";
my $latsum = my $lonsum = my $n = 0;
for (keys(%N)) {
    my $sta = $_;
    my %NODE = readNode($sta);
    $N{$sta}{LAT_WGS84} = $NODE{$sta}{LAT_WGS84};
    $N{$sta}{LON_WGS84} = $NODE{$sta}{LON_WGS84};
    $N{$sta}{ALTITUDE}  = $NODE{$sta}{ALTITUDE};
    $N{$sta}{INSTALL_DATE}  = $NODE{$sta}{INSTALL_DATE};
    $N{$sta}{END_DATE}  = $NODE{$sta}{END_DATE};
    $N{$sta}{TYPE}  = $NODE{$sta}{TYPE};
    if ($sta eq $NODEName) {
        $lat = $N{$sta}{LAT_WGS84};
        $lon = $N{$sta}{LON_WGS84};
        $title = "$NODE{$sta}{ALIAS}: $NODE{$sta}{NAME}";
    }
    $latsum += $N{$sta}{LAT_WGS84};
    $lonsum += $N{$sta}{LON_WGS84};
    $n++;
}
if (scalar(@NID) == 2) {
    $lat = $latsum/$n;
    $lon = $lonsum/$n;
    $title = $grid;
}

# --- Importation of shpfile
# --- First we check if a geojson already exists in the NODE dir
my $geojsonFile;
if ($NODEName) {
    $geojsonFile = "$WEBOBS{PATH_NODES}/$NODEName/$NODEName.geojson";
} else {
    $geojsonFile = "$WEBOBS{PATH_GRIDS}/$GRIDType.$GRIDName.geojson";
}
my $geojsonData;
if (-e $geojsonFile) {
    open(FH, '<', $geojsonFile);
    while(<FH>){
        $geojsonData = "$_";
    }
    close(FH);
}

# ---- build the HTML page calling OSM API once loaded ----
#
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">","\n";
print <<"END";
<HTML><HEAD><TITLE>$title ($today)</TITLE>
<link rel="stylesheet" href="/css/leaflet.css" />
<link rel="stylesheet" href="/css/leaflet.draw.css" />
<script src="/js/leaflet.js"></script>
<script src="/js/leaflet.draw.js"></script>
<script src="/js/shp.min.js"></script>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">

</HEAD>
<BODY>
<DIV id="map" style="height: ${height}px"></DIV>
<br><strong>Add a shapefile layer: </strong> <input type="file" id="shapefile-input" accept=".geojson, .json, .zip, .shz">
<button id="save" style="float: right;">Save</button>
<br><span id="status" style="color: green; float: right;"></span>
<script type="text/javascript">
    var esriAttribution = 'Tiles &copy; <b>Esri</b>, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community';
    var osmAttribution = 'Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';
    var topo = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
        maxZoom: 17,
        attribution: osmAttribution
    });
    var satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        attribution: esriAttribution
    });
    var osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: osmAttribution,
        maxZoom: 19
    });
    var map = L.map('map', {
        center: [$lat, $lon],
        zoom: $WEBOBS{OSM_ZOOM_VALUE},
        layers: [osm, topo, satellite]
    });
    var baseMaps = {
        "OpenStreetMap": osm,
        "OpenTopoMap": topo,
        "ESRI World Imagery": satellite,
    };
    var layerControl = L.control.layers(baseMaps).addTo(map);
    L.control.scale().addTo(map);
    var markers = [];

    // Create a layer group for editable elements
    var drawnItems = new L.FeatureGroup().addTo(map);

    // Load GeoJSON data
    if ("$geojsonFile") {
        var geojson = createShp($geojsonData);
        geojson.addTo(drawnItems);
    }

    // Initialize the drawing control with the editing option
    var drawControl = new L.Control.Draw({
        edit: {
            featureGroup: drawnItems
        },
        draw: {
            circle: false
        }
    });
    map.addControl(drawControl);

    // Add an event handler for newly created layers
    map.on("draw:created", function(e) {
        drawnItems.addLayer(e.layer);
    });

    function createShp(geojson) {
        var shpfile = L.geoJson(geojson, {
            onEachFeature: function(feature, layer) {
                drawnItems.addLayer(layer);
                var popupcontent = [];
                for (var prop in feature.properties) {
                    popupcontent.push(prop + ": " + feature.properties[prop]);
                }
                layer.bindPopup(popupcontent.join("<br />"));
            }
        });
        return shpfile;
    }

    // Save GeoJSON data
    document.getElementById("save").addEventListener("click", function() {
        var drawnItemsJson = drawnItems.toGeoJSON();
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "postGEOJSON.pl", true);
        xhr.onreadystatechange = function() {
            if (this.readyState == 4 && this.status == 200) {
                var openerURL = window.opener.location.href;
                if (openerURL.includes("formNODE.pl")) {
                    if (window.opener) {
                        window.opener.location.reload();
                    }
                    window.close();
                } else {
                    document.getElementById("status").innerHTML = JSON.parse(this.responseText)["message"];
                    setTimeout(() => {
                        document.getElementById("status").innerHTML = "";
                    }, 3000);
                }
            }
        };
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({
            filename: "$geojsonFile",
            geojson: drawnItemsJson
        }));
    });

    function loadShapefile(file) {
        var reader = new FileReader();
        reader.onload = function(event) {
            shp(event.target.result).then(function(geojson) {
                createShp(geojson);
            });
        };
        reader.readAsArrayBuffer(file);
    }

    function loadGeoJSON(file) {
        var reader = new FileReader();
        reader.onload = function(event) {
            createShp(JSON.parse(event.target.result));
        };
        reader.readAsText(file);
    }

    // Event listener to file selector button
    document.getElementById("shapefile-input").addEventListener("change", function(event) {
        var file = event.target.files[0];
        if (file) {
            if (file.name.endsWith("json")) {
                loadGeoJSON(file);
            } else {
                loadShapefile(file);
            }
        }
    })
END

for (keys(%N)) {
    if (!($N{$_}{LAT_WGS84} eq "" && $N{$_}{LON_WGS84} eq "")
        && ( ($opt ne "active" || (($N{$_}{END_DATE} ge $today || $N{$_}{END_DATE} eq "NA")
                    && ($N{$_}{INSTALL_DATE} le $today || $N{$_}{INSTALL_DATE} eq "NA")))) ) {
        my $text = "<B>$N{$_}{ALIAS}: $N{$_}{NAME}</B>"
          .($N{$_}{TYPE} ne "" ? "<br><I>($N{$_}{TYPE})</I>":"")
          .($N{$_}{INSTALL_DATE} ne "NA" ? "<br>&nbspfrom <B>$N{$_}{INSTALL_DATE}</B>".($N{$_}{END_DATE} ne "NA" ? " to <B>$N{$_}{END_DATE}</B>":""):"")
          ."<br>&nbsp;<B>".sprintf("%+02.5f",$N{$_}{LAT_WGS84})."&deg;N</B>, <B>".sprintf("%+03.5f",$N{$_}{LON_WGS84})."&deg;E</B>"
          .($N{$_}{ALTITUDE} ne "" ? ", <B>$N{$_}{ALTITUDE} m</B>":"");
        $text =~ s/\"//g;  # fix ticket #166
        if (scalar(@NID) != 2 & $NODEName ne $_) {
            print "var marker = L.circleMarker([$N{$_}{LAT_WGS84}, $N{$_}{LON_WGS84}], {radius: 6, color: '#4080F7'}).addTo(map);\n";
        } else {
            print "var marker = L.circleMarker([$N{$_}{LAT_WGS84}, $N{$_}{LON_WGS84}], {radius: 8, color: 'red'}).addTo(map);\n";
        }
        print "marker.bindPopup(\"$text\");\n";
        print "markers.push(marker);\n";
    }
}

# ---- if no node requested => map fits all nodes of grid
if (scalar(@NID) == 2) {
    print "var group = new L.featureGroup(markers);\n";
    print "map.fitBounds(group.getBounds().pad(0.1));\n";
} else {
    print "map.setView([$lat, $lon], $WEBOBS{OSM_ZOOM_VALUE});\n";
}
print "</script>\n";

# ---- we're done ------------------------------------
print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)
François Beauducel, Lucas Dassin

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
