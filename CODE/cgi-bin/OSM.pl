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

my $titre="";
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
		$titre = "$NODE{$sta}{ALIAS}: $NODE{$sta}{NAME}";
	}
	$latsum += $N{$sta}{LAT_WGS84};
	$lonsum += $N{$sta}{LON_WGS84};
	$n++;
}
if (scalar(@NID) == 2) {
	$lat = $latsum/$n;
	$lon = $lonsum/$n;
	$titre = $grid;
}

# ---- build the HTML page calling OSM API once loaded ----
#
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">","\n";
print <<'END';
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.8.0/dist/leaflet.css"
   integrity="sha512-hoalWLoI8r4UszCkZ5kL8vayOGVae1oxXe/2A4AO6J9+580uKHDO3JdHb7NzwwzK5xr/Fs0W40kiNHxM9vyTtQ=="
   crossorigin=""/>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.css">
<script src="https://unpkg.com/shpjs@latest/dist/shp.js" crossorigin=""></script>
<script src="https://unpkg.com/leaflet@1.8.0/dist/leaflet.js"
      integrity="sha512-BB3hKbKWOc9Ez/TAwyWxNXeoV9c1v6FIeYiBieIWkpLjauysF18NzgR1MBNBXf8/KABdlkX68nAhlwcDFLGPCQ=="
      crossorigin=""></script>
<script src='https://cdnjs.cloudflare.com/ajax/libs/leaflet.draw/1.0.4/leaflet.draw.js'></script>
<script src='https://openlayers.org/api/OpenLayers.js'></script>
<script type="text/javascript" src="https://stamen-maps.a.ssl.fastly.net/js/tile.stamen.js?v1.3.0"></script>
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js" type="text/javascript"></script>
END

print <<"END";
<HTML><HEAD><TITLE>$titre ($today)</TITLE>
<LINK rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
</HEAD>
<BODY>
<DIV id="map" style="height: ${height}px"></DIV>
<script type="text/javascript">
	var	esriAttribution = 'Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community';
	var stamenAttribution = 'Map tiles by <a href="http://stamen.com">Stamen Design</a>, <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a> &mdash; Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';
	var osmAttribution = 'Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';
	var terrain = L.tileLayer('https://stamen-tiles-{s}.a.ssl.fastly.net/terrain/{z}/{x}/{y}{r}.{ext}', {
		attribution: stamenAttribution,
		subdomains: 'abcd',
		minZoom: 0,
		maxZoom: 18,
		ext: 'png'
	});
	var watercolor = L.tileLayer('https://stamen-tiles-{s}.a.ssl.fastly.net/watercolor/{z}/{x}/{y}.{ext}', {
		attribution: stamenAttribution,
		subdomains: 'abcd',
		minZoom: 1,
		maxZoom: 18,
		ext: 'jpg'
	});
	var topo = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
		maxZoom: 17,
		attribution: osmAttribution});
	var satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
		attribution: esriAttribution});
	var osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    	attribution: osmAttribution,
		maxZoom: 19});
	var map = L.map('map', {
		center: [$lat, $lon],
		zoom: $WEBOBS{OSM_ZOOM_VALUE},
		layers: [terrain,topo,osm,watercolor,satellite]});
	var baseMaps = {
    	"Stamen Terrain": terrain,
    	"OpenTopoMap": topo,
    	"OpenStreetMap": osm,
    	"Stamen Watercolor": watercolor,
		"ESRI World Imagery": satellite,
	};
	var layerControl = L.control.layers(baseMaps).addTo(map);
	var markers = [];
	
	var editableLayers = new L.FeatureGroup();
	map.addLayer(editableLayers);
	
	var drawControl = new L.Control.Draw({
	  position: 'topright',
	  draw: {
		polyline: true,
		polygon: {
		  allowIntersection: false, \/\/ Restricts shapes to simple polygons 
		  drawError: {
		    color: '#e1e100', \/\/ Color the shape will turn when intersects 
		    message: \"<strong>Oh snap!<strong> you can\'t draw that!\" \/\/ Message that will show when intersect 
		  }
		},
		circle: true, \/\/ Turns off this drawing tool 
		rectangle: true,
		marker: true
	  },
	  edit: {
		featureGroup: editableLayers, \/\/REQUIRED!! 
		remove: true
	  }
	});

	map.addControl(drawControl);
	
	var outGeoJSON = '';
	var outWKT = "POINT("+$lat+" "+$lon+")";
	
	console.log(outGeoJSON);
	
	\/\/On Draw Create Event
	map.on(L.Draw.Event.CREATED, function(e) {
	  var type = e.layerType,
		layer = e.layer;

	  if (type === 'marker') {
		layer.bindPopup('LatLng: ' + layer.getLatLng().lat + ',' + layer.getLatLng().lng).openPopup();
	  }

	  editableLayers.addLayer(layer);
	  layerGeoJSON = editableLayers.toGeoJSON();
	  outGeoJSON = JSON.stringify(layerGeoJSON);

	  var wkt_options = {};
	  var geojson_format = new OpenLayers.Format.GeoJSON();
	  var testFeature = geojson_format.read(layerGeoJSON);
	  var wkt = new OpenLayers.Format.WKT(wkt_options);
	  var out = wkt.write(testFeature);
	  
      outWKT = out;
	});

	//On Draw Edit Event
	map.on(L.Draw.Event.EDITED, function(e) {
	  var type = e.layerType,
		layer = e.layer;

	  layerGeoJSON = editableLayers.toGeoJSON();
	  outGeoJSON = JSON.stringify(layerGeoJSON);

	  var wkt_options = {};
	  var geojson_format = new OpenLayers.Format.GeoJSON();
	  var testFeature = geojson_format.read(layerGeoJSON);
	  var wkt = new OpenLayers.Format.WKT(wkt_options);
	  var out = wkt.write(testFeature);

      outWKT = out;
	});

	\/\/On Draw Delete Event
	map.on(L.Draw.Event.DELETED, function(e) {
	  var type = e.layerType,
		layer = e.layer;

	  layerGeoJSON = editableLayers.toGeoJSON();
	  outGeoJSON = JSON.stringify(layerGeoJSON);

	  var wkt_options = {};
	  var geojson_format = new OpenLayers.Format.GeoJSON();
	  var testFeature = geojson_format.read(layerGeoJSON);
	  var wkt = new OpenLayers.Format.WKT(wkt_options);
	  var out = wkt.write(testFeature);

      outWKT = out;
      
	});
END

for (keys(%N)) {
	if (!($N{$_}{LAT_WGS84} eq "" && $N{$_}{LON_WGS84} eq "")
		&& ( ($opt ne "active" || (($N{$_}{END_DATE} ge $today || $N{$_}{END_DATE} eq "NA")
			&& ($N{$_}{INSTALL_DATE} le $today || $N{$_}{INSTALL_DATE} eq "NA"))))) {
		my $text = "<B>$N{$_}{ALIAS}: $N{$_}{NAME}</B><BR>"
			.($N{$_}{TYPE} ne "" ? "<I>($N{$_}{TYPE})</I><br>":"")
			."&nbspfrom <B>$N{$_}{INSTALL_DATE}</B>".($N{$_}{END_DATE} ne "NA" ? " to <B>$N{$_}{END_DATE}</B>":"")."<br>"
			."&nbsp;<B>$N{$_}{LAT_WGS84}&deg;</B>, <B>$N{$_}{LON_WGS84}&deg;</B>, <B>$N{$_}{ALTITUDE} m</B>";
		$text =~ s/\"//g;  # fix ticket #166
		print "var marker = L.marker([$N{$_}{LAT_WGS84}, $N{$_}{LON_WGS84}]).addTo(map);\n";
		print "marker.bindPopup(\"$text\").openPopup();\n";
		print "markers.push(marker);\n";
	}
}
# ---- if no node requested => map fits all nodes of grid
if (scalar(@NID) == 2) {
	print "var group = new L.featureGroup(markers);\n";
	print "map.fitBounds(group.getBounds().pad(0.1));\n";
	print "map.addLayer(markerClusters);\n";
} else {
	print "map.setView([$lat, $lon], $WEBOBS{OSM_ZOOM_VALUE});\n";
}
print "</script>\n";

print "<form action='geomNODE.pl' method='get' onsubmit=\"document.getElementById('geom').value=outWKT+';'+outGeoJSON+';$NODEName';window.close()\">"; #;window.close()
print "<strong>Pour enregistrer la couverture spatiale du NODE aux formats WKT et GeoJSON, cliquez ici: </strong><input id='geom' type='submit' name='geom' value='Sauvegarder'>";
print "</form>";

# ---- we're done ------------------------------------
print "\n</BODY>\n</HTML>\n";

__END__
=pod
=head1 AUTHOR(S)
François Beauducel
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
