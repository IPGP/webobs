#!/usr/bin/perl

=head1 NAME

googleMAPS.pl

=head1 SYNOPSIS

http://..../googleMAPS.pl?...(see Query String parameters)....

=head1 DESCRIPTION

HTML page with Google Map for a GRID.

=head1 Query string parameters

node=
  gridtype.gridname.nodename  : map centered on nodename + all nodes of grid
  gridtype.gridname.nodename~ : map centered on nodename only

grid=
  gridtype.gridname           : map with all nodes of grid

today=
  forces a date (defaults to today)

nodes=
  { active | valid }

width=
height=
  defaulted to corresponding GOOGLE_MAPS_xxxx_VALUE key in WEBOBS.rc

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
my $fiches = $cgi->url_param('nodes');
my $width  = $cgi->url_param('width')  // $WEBOBS{GOOGLE_MAPS_WIDTH_VALUE};
my $height = $cgi->url_param('height') // $WEBOBS{GOOGLE_MAPS_HEIGHT_VALUE};
my $today  = $cgi->url_param('today')  // qx(date +\%Y-\%m-\%d);
chomp($today);

my $GRIDName  = my $GRIDType  = my $NODEName = my $msk = "";
my @NID = split(/[\.\/]/, trim($grid));
if (scalar(@NID) < 2) {
	die "No valid grid requested (NOT= gridtype.gridname[.node])." ;
}
($GRIDType, $GRIDName, $NODEName) = @NID;

# ---- get all nodenames of grid (only VALID)
my %N = listGridNodes(grid=>"$GRIDType.$GRIDName");

# ---- if requested nodename~ ==> remove all other nodes from grid
#if ($NODEName && $NODEName =~ m/~$/) {
#	$NODEName =~ s/~$// ;
#	@nodes = $NODEName;
#}
# ---- no node requested forces 1st of grid list to comply to processing below
#$NODEName ||= $nodes[0];

# ---- build the HTML page calling Google Maps once loaded ----
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<META http-equiv=\"content-type\" content=\"text/html; charset=utf-8\"\n>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\"\n>";
print "<script src=\"$WEBOBS{GOOGLE_MAPS_API}&amp;v=2&amp;key=$WEBOBS{GOOGLE_MAPS_API_KEY}\" type=\"text/javascript\"> </script>\n";
print "<script type=\"text/javascript\">
function onLoad() {
	if (GBrowserIsCompatible()) {
		var map = new GMap2(document.getElementById(\"Gmap\"));
		map.setMapType($WEBOBS{GOOGLE_MAPS_TYPE});
		map.addControl(new GLargeMapControl());
		map.addControl(new GMapTypeControl());
		map.addMapType(G_PHYSICAL_MAP);
		var bounds = new GLatLngBounds();
		var marker = [];
		var sta = [];";

my $i = 0;
for (keys(%N)) {
	#FB-was: my $sta = substr($_,length($_)-7);
	my $sta = $_;
	my %NODE = readNode($sta);
	print " dbg0=\"$sta\";";
	if (!($NODE{$sta}{LAT_WGS84} eq "" && $NODE{$sta}{LON_WGS84} eq "" && $NODE{$sta}{ALTITUDE} eq "")
		&& ( ($fiches ne "active" || (($NODE{$sta}{END_DATE} ge $today || $NODE{$sta}{END_DATE} eq "NA")
			&& ($NODE{$sta}{INSTALL_DATE} le $today || $NODE{$sta}{INSTALL_DATE} eq "NA"))))) {
		my $texte = "<div class=\"gmap_popup\"><B>$NODE{$sta}{ALIAS}: $NODE{$sta}{NAME}</B><BR>"
			.($NODE{$sta}{TYPE} ne "" ? "<I>($NODE{$sta}{TYPE})</I><br>":"")
			."&nbspfrom <B>$NODE{$sta}{INSTALL_DATE}</B>".($NODE{$sta}{END_DATE} ne "NA" ? " to <B>$NODE{$sta}{END_DATE}</B>":"")."<br>"
			."&nbsp;<B>$NODE{$sta}{LAT_WGS84}&deg;</B>, <B>$NODE{$sta}{LON_WGS84}&deg;</B>, <B>$NODE{$sta}{ALTITUDE} m</B></DIV>";
		$texte =~ s/\"//g;  # fix ticket #166
		print "
		var icon = new GIcon(G_DEFAULT_ICON);
		icon.image = '/icons/google/target".($NODE{$sta}{VALID} == 0 ? "_unvalid":"").".png';
		icon.iconSize = new GSize(16, 16);
		icon.iconAnchor = new GPoint(8, 8);
		var options = { icon: icon };
		sta[$i] = new GLatLng(".sprintf("%.5f, %.5f",$NODE{$sta}{LAT_WGS84}, $NODE{$sta}{LON_WGS84}).");
		marker[$i] = new GMarker(sta[$i],options);
		bounds.extend(sta[$i]);
		map.addOverlay(marker[$i]);
		GEvent.addListener(marker[$i], 'click', function() { marker[$i].openInfoWindowHtml(\"$texte\"); });";
		if ($sta eq $NODEName) {
			print "
			map.setCenter(sta[$i], $WEBOBS{GOOGLE_MAPS_ZOOM_VALUE});
			marker[$i].openInfoWindowHtml(\"$texte\", { maxWidth:300 });";
			$titre = "$NODE{$sta}{ALIAS}: $NODE{$sta}{NAME}";
		}
	}
	$i++;
}
# ---- if no node requested => map fits all nodes of grid
if (scalar(@NID) == 2) {
	print "
	map.setCenter(bounds.getCenter(), map.getBoundsZoomLevel(bounds));
	map.setMapType(G_PHYSICAL_MAP);";
	$titre = $grid;
}

print "
	}
}
</script>
<HTML><HEAD><TITLE>$titre ($today)</TITLE>
<LINK rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
</HEAD>
<BODY onLoad=\"onLoad()\">
<DIV id=\"Gmap\" style=\"width: ${width}px; height: ${height}px\"></DIV>";

# ---- we're done ------------------------------------
print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

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
