#!/usr/bin/perl

=head1 NAME

formNODE.pl

=head1 SYNOPSIS

http://..../formNODE.pl?[node=NODEID]

=head1 DESCRIPTION

1) Edits an existing NODE when requested node is a fully qualified node name
(ie. node=gridtype.gridname.nodename).

2) Creates a new NODE when no nodename specified (ie. node=gridtype.gridname).

=head1 Query string parameters

 node=
 the fully qualified NODE name gridtype.gridname.nodename to update
 -or- gridtype.gridname to create a new NODE

=cut

use strict;
use File::Basename;
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024 * 10;
$CGI::DISABLE_UPLOADS = 1;
my $cgi = new CGI;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
my %NODE;
my %GRID;
my %allNodeGrids;
my @VIEWS;
my @PROCS;
my $adminOK = 0;
my $GRIDName  = my $GRIDType  = my $NODEName = my $RESOURCE = "";
my $newnode   = 0;
my $titre2 = "";
my $QryParm   = $cgi->Vars;

($GRIDType, $GRIDName, $NODEName) = split(/[\.\/]/, trim($QryParm->{'node'}));
if ( $GRIDType ne "" && $GRIDName ne "" ) {
	if ( clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) { $adminOK = 1 }
	if ($NODEName ne "") {
		%allNodeGrids = WebObs::Grids::listNodeGrids(node=>$NODEName);
		if ("$GRIDType.$GRIDName" ~~ @{$allNodeGrids{$NODEName}}) {
			my %G;
			my %S = readNode($NODEName,"novsub");
			%NODE = %{$S{$NODEName}};
			if (%NODE) {
				if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
				elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
				if (%G) {
					%GRID = %{$G{$GRIDName}} ;
					if ( !clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
						die "$__{'Not authorized'} (edit) $GRIDType.$GRIDName.$NODEName";
					}
				} else { die "$__{'Could not read'} $GRIDType.$GRIDName configuration" }
			} else { die "$__{'Could not read'} $__{'node configuration'} $NODEName" }
		} else { die "$GRIDType.$GRIDName.$NODEName unknown" }
	} else {
		if ( $adminOK == 1 ) {
			$newnode = 1;
		} else { die "$__{'Not authorized'} $__{'to create a node in'} $GRIDType.$GRIDName" }
	}
} else { die ("$__{'You cannot edit a NODE outside of GRID context'}")  }

# ---- went thru all above checks ... setup edit form
#
my $titrePage = "$__{'Node Configuration'}";
if ($newnode == 0) {
	$titre2 = "$__{'Editing'}"." <I>$GRIDType.$GRIDName.$NODEName</I>";
	if ( $adminOK == 1 && defined($NODES{PATH_NODE_TRASH}) && $NODES{PATH_NODE_TRASH} ne "") {
		$titre2 .= " <A href=\"#\"><IMG src=\"/icons/no.png\" onClick=\"delete_node();\" title=\"$__{'Delete this node'}\"></A>";
	}
} else {
	$titre2 = "$__{'New node'}";
}

my $Ctod = time(); my @tod  = localtime($Ctod);
my %typeTele = readCfg("$NODES{FILE_TELE}");
my %typePos  = readCfg("$WEBOBS{ROOT_CODE}/etc/postypes.conf");
my %rawFormats  = readCfg("$WEBOBS{ROOT_CODE}/etc/rawformats.conf");
my %FDSN = WebObs::Grids::codesFDSN();
my $referer = $QryParm->{'referer'} // $ENV{HTTP_REFERER};

# reads the node2node file (only lines associated to the current node)
my @n2n = readFile($NODES{FILE_NODES2NODES},qr/^$NODEName\|/);

# ---- initialize user input variables -----------------------
#      Name and codes
my $usrValid     = $NODE{VALID} // 0;
my $usrName      = $NODE{NAME}; $usrName =~ s/\"//g;
my $usrAlias     = $NODE{ALIAS};
my $usrType      = $NODE{TYPE};
my $usrDesc      = $NODE{DESCRIPTION};
my $usrProducer  = $NODE{PRODUCER};
my $usrCreator   = $NODE{CREATOR};
my $usrFirstName = $NODE{FIRSTNAME};
my $usrLastName  = $NODE{LASTNAME};
my $usrEmail     = $NODE{EMAIL};
my $usrTheme     = $NODE{THEME};
my $usrTopic     = $NODE{TOPICS};
my $usrLineage   = $NODE{LINEAGE};
#my $usrOrigin    = $NODE{ORIGIN};
my $usrTZ        = $NODE{TZ} // strftime("%z", localtime());
my $features     = $NODE{FILES_FEATURES} // "$__{'featureA,featureB,featureC'}";
my @feat = split(/,|\|/,$features);
#      proc parameters
my $usrFDSN      = $NODE{"$GRIDType.$GRIDName.FDSN_NETWORK_CODE"} // $NODE{FDSN_NETWORK_CODE};
my $usrUTC       = $NODE{"$GRIDType.$GRIDName.UTC_DATA"}          // $NODE{UTC_DATA};
my $usrACQ       = $NODE{"$GRIDType.$GRIDName.ACQ_RATE"}          // $NODE{ACQ_RATE};
my $usrDLY       = $NODE{"$GRIDType.$GRIDName.LAST_DELAY"}        // $NODE{LAST_DELAY};
my $usrDataFile  = $NODE{"$GRIDType.$GRIDName.FID"}               // $NODE{FID};
my @usrFID       = grep { $_ =~ /$GRIDType\.$GRIDName\.FID_|^FID_/ } keys(%NODE);
my $usrRAWFORMAT = $NODE{"$GRIDType.$GRIDName.RAWFORMAT"}         // $NODE{RAWFORMAT};
my $usrRAWDATA   = $NODE{"$GRIDType.$GRIDName.RAWDATA"}           // $NODE{RAWDATA}; $usrRAWDATA =~ s/\"/&quot;/g;
my $usrCHAN      = $NODE{"$GRIDType.$GRIDName.CHANNEL_LIST"}      // $NODE{CHANNEL_LIST};
#      Geographical position
my $usrLat       = $NODE{LAT_WGS84};
my $usrLatN      = ($usrLat >= 0 ? "N":"S");
$usrLat =~ s/^-//g; # computes the absolute value but avoiding the use of locale
my $usrLon       = $NODE{LON_WGS84};
my $usrLonE = ($usrLon >= 0 ? "E":"W");
$usrLon =~ s/^-//g;
my $usrAlt       = $NODE{ALTITUDE};
my $usrShpFile   = $NODE{SPATIAL_COVERAGE};
my $usrTypePos   = $NODE{POS_TYPE};
my $usrRAWKML    = $NODE{POS_RAWKML};
#      Transmission
my ($usrTrans,@usrTele) = split(/,| |\|/,$NODE{TRANSMISSION});
if ($usrTrans eq "NA") { $usrTrans = "0"; }
#      dates
my $usrYearE = my $usrYearC = my $usrYearP = "";
my $usrMonthE = my $usrMonthC = my $usrMonthP = "";
my $usrDayE = my $usrDayC = my $usrDayP = "";
my $usrTimeP = my $date = "";
#      install date = (the one defined or "" if NA) OR today
$date            = $NODE{INSTALL_DATE} // strftime('%Y-%m-%d',@tod);
if ($date eq "NA") { $date = "" }
($usrYearC,$usrMonthC,$usrDayC) = split(/-/,$date);
#      end date = (the one defined or "" if NA) OR ""
$date            = $NODE{END_DATE};
if ($date eq "NA") { $date = "" }
($usrYearE,$usrMonthE,$usrDayE) = split(/-/,$date);
#      positionning date = (the one defined or "" if NA) OR today
$date            = $NODE{POS_DATE} // strftime('%Y-%m-%d',@tod);
if ($date eq "NA") { $date = "" }
($usrYearP,$usrMonthP,$usrDayP,$usrTimeP) = split(/-|T/,$date);

# ---- parsing INSPIRE themes and topic categories for the select menu in the description part
my $inspireTheme = "/$WEBOBS{THEME}";
my @themes;
open(FH, '<', $inspireTheme) or die $!;

while(<FH>){
	chomp($_);
	push(@themes, $_);
}

close(FH);

my $topicCategories = "/$WEBOBS{TOPIC}";
my @topics;
open(FH, '<', $topicCategories) or die $!;

while(<FH>){
	chomp($_);
	push(@topics, $_);
}

close(FH);

my $creatorRoles = "/$WEBOBS{CREATOR}";
my @creators;
open(FH, '<', $creatorRoles) or die $!;

while(<FH>){
	chomp($_);
	push(@creators, $_);
}

close(FH);

# ---- Load the list of existing nodes
my @allNodes = qx(/bin/ls $NODES{PATH_NODES});
chomp(@allNodes);

my $infoFile   = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS}" // "";
my $accessFile = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_PHOTOS}" // "";

# ---- Things to populate select dropdown fields
my $currentYear = strftime('%Y',@tod);
my @yearListP = reverse($WEBOBS{BIG_BANG}..$currentYear+1,'');
my @yearListC = reverse($WEBOBS{BIG_BANG}..$currentYear+1,'');
my @yearListE = reverse($WEBOBS{BIG_BANG}..$currentYear+1,'');
my @monthList = ('','01'..'12');
my @dayList = ('','01'..'31');

my $text = "<B>$NODE{ALIAS}: $NODE{NAME}</B><BR>"
	.($NODE{TYPE} ne "" ? "<I>($NODE{TYPE})</I><br>":"")
	."&nbspfrom <B>$NODE{INSTALL_DATE}</B>".($NODE{END_DATE} ne "NA" ? " to <B>$NODE{END_DATE}</B>":"")."<br>"
	."&nbsp;<B>$NODE{LAT_WGS84}&deg;</B>, <B>$NODE{LON_WGS84}&deg;</B>, <B>$NODE{ALTITUDE} m</B>";
$text =~ s/\"//g;  # fix ticket #166

# ---- ready for HTML output now
#
print $cgi->header(
	-charset                     => 'utf-8',
	-access_control_allow_origin => 'http://localhost',
	),
$cgi->start_html("$__{'Node configuration form'}");

print <<"FIN";
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.6.0/leaflet.css" crossorigin=""/>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.6.0/leaflet.js" crossorigin=""></script>
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script language="javascript" type="text/javascript" src="/js/htmlFormsUtils.js"></script>
<script src="https://unpkg.com/shpjs\@latest/dist/shp.js" type="text/javascript"></script>
<script src="https://cdn.rawgit.com/calvinmetcalf/leaflet.shapefile/gh-pages/leaflet.shpfile.js" type="text/javascript"></script>
<script src="https://cdn.jsdelivr.net/gh/seabre/simplify-geometry\@master/simplifygeometry-0.0.2.js" type="text/javascript"></script>
<script type="text/javascript">

function postIt()
{
 var form = \$('#theform')[0];
 if(form.nouveau.value == 1 && form.message.value != "ok") {
   alert("NODE ID: Please enter a valid and new ID!");
   form.nodename.focus();
   return false;
 }
 if((/^[\\s]*\$/).test(form.fullName.value)) {
   alert("NAME: Please enter a full name (non-blank string)");
   form.fullName.focus();
   return false;
 }
 if(form.alias.value == "") {
   alert("ALIAS: Please enter a short name (non-blank string)");
   form.alias.focus();
   return false;
 }
 if(form.latwgs84.value != "" && (isNaN(form.latwgs84.value) || form.latwgs84.value < -90 || form.latwgs84.value > 90)) {
   alert("LATITUDE: Please enter a latitude value between -90 and +90, or leave blank");
   form.latwgs84.focus();
   return false;
 }
 if(form.latwgs84.value < 0 && form.latwgs84.value >= -90) {
   form.latwgs84.value = Math.abs(form.latwgs84.value);
   if (form.latwgs84n.value == "N") form.latwgs84n.value = "S";
   else form.latwgs84n.value = "N";
 }
 if(form.latwgs84.value == "" && (form.latwgs84min.value != "" || form.latwgs84sec.value != "")) {
   alert("LATITUDE: Please enter a value for degree or leave all fields blank");
   form.latwgs84.focus();
   return false;
 }
 if(form.lonwgs84.value != "" && (isNaN(form.lonwgs84.value) || form.lonwgs84.value < -180 || form.lonwgs84.value > 180)) {
   alert("LONGITUDE: Please enter a longitude value between -180 and +180, or leave blank");
   form.lonwgs84.focus();
   return false;
 }
 if(form.lonwgs84.value < 0 && form.lonwgs84.value >= -180) {
   form.lonwgs84.value = Math.abs(form.lonwgs84.value);
   if (form.lonwgs84e.value == "E") form.lonwgs84e.value = "W";
   else form.lonwgs84e.value = "E";
 }
 if(form.lonwgs84.value == "" && (form.lonwgs84min.value != "" || form.lonwgs84sec.value != "")) {
   alert("LONGITUDE: Please enter a value for degree or leave all fields blank");
   form.lonwgs84.focus();
   return false;
 }
 if(form.altitude.value != "" && isNaN(form.altitude.value)) {
   alert("ELEVATION: Please enter a number or leave blank");
   form.altitude.focus();
   return false;
 }
  if (form.SELs.options.length < 1) {
    alert(\"node MUST belong to at least 1 grid\");
    form.SELs.focus();
    return false;
  }

  for (var i=0; i<form.elements['allNodes'].length; i++) {
  	form.elements['allNodes'][i].disabled = true;
  }
  for (var i=0; i<form.SELs.length; i++) {
  	form.SELs[i].selected = true;
  }
  
  // Theia metadata part
  var selected = \$('#topicCats')[0].selectedOptions;
  var topics = [];
  for (var i=0; i<selected.length; i++) {
  	topics.push(selected[i].value);
  } form.topics.value = 'topicCategories:'+topics.join(',')+'_';
  
  // registering the NODE contacts metadata
  var roles = [];
  var firstNames = [];
  var lastNames = [];
  var emails = [];
  if (form.count_creator.value > 1) {
  	  for (var i=0; i<form.role.length; i++) {
	  	roles.push(form.role[i].value);
	  	firstNames.push(form.firstName[i].value);
	  	lastNames.push(form.lastName[i].value);
	  	emails.push(form.email[i].value);
	  } 
  	form.creators.value = roles.join(',') + '|' + firstNames.join(',') + '|' + lastNames.join(',') + '|' + emails.join(',');
  } else {form.creators.value = form.role.value + '|' + form.firstName.value + '|' + form.lastName.value + '|' + form.email.value}

	console.log(\$(\"#theform\"));
	if (\$(\"#theform\").hasChanged() || form.delete.value == 1 || form.locMap.value == 1) {
		form.node.value = form.grid.value + form.nodename.value.toUpperCase();
		if (document.getElementById("fidx")) {
			var fidx = document.getElementById("fidx").getElementsByTagName("div");
			for (var i=0; i<fidx.length; i++) {
				if (form.rawformat.value == "" || fidx[i].id.indexOf(form.rawformat.value + "-") == -1) {
					var nested = document.getElementById("input-" + fidx[i].id);
					nested.parentNode.removeChild(nested);
				}
			}
		}
		\$.post(\"/cgi-bin/postNODE.pl\", \$(\"#theform\").serialize(), function(data) {
		     if (data != '') alert(data);
			 if (form.refresh.value == 1) {
				 location.reload();
		     } else { location.href = form.referer.value; }
		})
		  .fail( function() {
		     alert( \"postNode couldn't execute\" );
		     location.href = document.referrer; });
	} else {
		alert(\"No changes, save ignored\");
		return false;
	}
}

function maj_rawformat() {
	var fidx = document.getElementById("fidx").getElementsByTagName("div"), fid;
	for (var i=0; i<fidx.length; i++) {
		if (document.form.rawformat.value != "" && fidx[i].id.indexOf(document.form.rawformat.value + "-") != -1) {
			fidx[i].style.display = "block";
		} else {
			fidx[i].style.display = "none";
		}
	}
}

function maj_transmission() {
	if (document.form.typeTrans.value==0) {
		document.getElementById("pathTrans").style.display="none";
	} else {
		document.getElementById("pathTrans").style.display="block";
	}
}

function checkNode() {
	document.form.nodename.value = document.form.nodename.value.toUpperCase();
	var nodeSyntax=/[^A-Za-z0-9\.@]+/;
	var ok = 1;
	var rouge = '#EE0000';
	var vert = '#66DD66';

	var node = document.form.nodename.value;
	if (nodeSyntax.test(node)) {
		ok = 0;
		document.form.message.value = "invalid char. !";
	} else {
		for (var i=0; i<document.form.elements['allNodes'].length; i++) {
			if (document.form.elements['allNodes'][i].value == node) {
				ok = 0;
				document.form.message.value = "already exists !";
			}
		}
	}
	if (ok==1) {
		document.form.nodename.style.background = vert;
		document.form.message.value = "ok";
		document.form.message.style.color = vert;
	} else {
		document.form.nodename.style.background = rouge;
		document.form.message.style.color = rouge;
	}
	if (document.form.nodename.value == "") {
		document.form.nodename.style.background = 'cornsilk';
		document.form.message.value = "";
	}
	if (document.form.nouveau.value == 0) {
		document.form.nodename.style.background = 'none';
		document.form.message.value = "";
	}
}

function latlonChange() {
	if (document.form.typePos.value == 3) {
		document.getElementById("rawKML").style.display = "block";
		document.form.anneeMesure.disabled = true;
		document.form.moisMesure.disabled = true;
		document.form.jourMesure.disabled = true;
	} else {
		document.getElementById("rawKML").style.display = "none";
		var today = new Date();
		var d  = today.getDate();
		document.form.jourMesure.disabled = false;
		document.form.jourMesure.value = (d < 10) ? '0' + d : d;
		var m = today.getMonth() + 1;
		document.form.moisMesure.disabled = false;
		document.form.moisMesure.value = (m < 10) ? '0' + m : m;
		var yy = today.getYear();
		document.form.anneeMesure.disabled = false;
		document.form.anneeMesure.value = (yy < 1000) ? yy + 1900 : yy;
	}
}

function fetchKML() {
	var credentials = btoa("webobs:0vpf1pgp");
	var auth = {
		'Origin': 'http://localhost',
		'Access-Control-Request-Method': 'POST',
		'Access-Control-Allow-Origin': 'http://localhost',
		'Authorization': `Basic \${credentials}`,
	};
	var url = "https://share.garmin.com/Feed/Share/6DOQM";
    return fetch(url, {
		credentials: 'include',
		mode: 'cors',
		headers: auth,
	})
        .then(response => response.text())
        .then(xmlString => \$.parseXML(xmlString))
        .then(data => console.log(data))
}

function fc() {
	\$(\"#theform\").formChanges();
}

function refresh_form()
{
	document.form.refresh.value = 1;
	postIt();
}

function delete_node()
{
	if ( confirm(\"The NODE will be deleted (and all its configuration, features, events, images and documents). You might consider unchecking the Valid checkbox as an alternative.\\n\\n Are you sure you want to move this NODE to trash ?\") ) {
		document.form.delete.value = 1;
		document.form.referer.value = '/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=$GRIDType.$GRIDName';
		postIt();
	} else {
		return false;
	}
}

// functions to make the interactive map works

function onMapClick(e) {
	/**
	 * Places a marker on the interactive map and fills the coordinates fields in the NODE form
	 * \@param {Event} e Click event
	 */
	var lat = e.latlng['lat'].toFixed(6);
	var lon = e.latlng['lng'].toFixed(6);
	// lat, lon = nsew(lat, lon);

	/* need to rework this function !
	var p = document.createElement('p');
	
	p.innerHTML = "<B>$NODE{ALIAS}: "+$NODE{NAME}+"</B><BR><I>($NODE{TYPE})</I><BR>&nbspfrom <B>$NODE{INSTALL_DATE}</B> to <B>$NODE{END_DATE}</B><BR>&nbsp;<B>"+lat+"&deg;</B>, <B>"+lon+"&deg;</B>, <B>$NODE{ALTITUDE} m</B>";
	var txt = p.innerHTML;
	if (typeof(marker) != "undefined") {
		map.removeLayer(marker);
	}
	
	marker.bindPopup(txt).openPopup();
	*/
	
	if (typeof(marker) != "undefined") {
		map.removeLayer(marker);
	}
	marker = L.marker([lat, lon]).addTo(map);
	document.form.latwgs84.value = ns(lat);
	document.form.lonwgs84.value = ew(lon);
	document.form.locMap.value = 1;	// added a third variable to make the DOM perceived the changes in the webpage when clicking on the interactive map

	document.form.typePos.value="1";
	return false;
}
function getLocation() {
	event.preventDefault();
	if (navigator.geolocation) {
		navigator.geolocation.getCurrentPosition(getCurrent, error);
	} else {
		alert('Geolocation is not supported by this browser');
	}
}
function getCurrent (pos) {
	/**
	 * Get the position of the current user and focus the map on it
	 */
	var lat = pos.coords.latitude;
	var lon = pos.coords.longitude;
	// lat, lon = nsew(lat, lon)
	
	document.form.latwgs84.value = ns(lat);
	document.form.lonwgs84.value = ew(lon);
	document.form.locMap.value = 1;

	map.flyTo([lat, lon], 18);
	document.form.typePos.value="2";
}
function error (err) {
	switch (err.code) {
		case err.TIMEOUT:
		break;
		case err.PERMISSION_DENIED:
		break;
		case err.POSITION_UNAVAILABLE:
		break;
		case err.UNKNOWN_ERROR:
		break;
	}
}
function nsew(lat, lon) {
	/**
	 * Synchronize leaflet location and WebObs geographic location form
	 * \@param {Number} lat Latitude
	 * \@param {Number} lon Longitude
	 */
	var ns = document.form.latwgs84n.value;
	var ew = document.form.lonwgs84e.value;
	
	if (lat < 0 && lon > 0 && ns == 'N') {
		document.form.latwgs84n.value = 'S';
		return -lat, lon;
	} else if (lat > 0 && lon < 0 && ew == 'E') {
		document.form.lonwgs84e.value = 'W';
		return lat, -lon;
	} else if (lat < 0 && lon < 0 && ns == 'N' && ew == 'E') {
		document.form.latwgs84n.value = 'S';
		document.form.lonwgs84e.value = 'W';
		return -lat, -lon;
	} else if (lat > 0 && lon > 0 && ns == 'N' && ew == 'W') {
		return lat, -lon;
	} else {
		return lat, lon;
	}
}
// Better use these 2 functions when modifying lat/lon form values by clicking on the map
function ns(lat) {
	var ns = document.form.latwgs84n.value;
	if (lat < 0 && ns == 'N') {
		document.form.latwgs84n.value = 'S';
		return -lat;
	} else if (lat < 0 && ns == 'S') {
		return -lat;
	} else if (lat > 0 && ns == 'S') {
		document.form.latwgs84n.value = 'N';
	} else {
		return lat;
	} 
}
function ew(lon) {
	var ew = document.form.lonwgs84e.value;
	if (lon < 0 && ew == 'E') {
		document.form.lonwgs84e.value = 'W';
		return -lon;
	} else if (lon < 0 && ew == 'W') {
		return -lon;
	} else if (lon > 0 && ew == 'W') {
		document.form.lonwgs84e.value = 'E';
		return lon;
	} else {
		return lon;
	}
}
function onInputWrite(e) {
	/**
	 * Zoom/dezoom the map following the number of decimals in the latitude and longitude fields
	 * \@param {Event} e Input event
	 */
	var lat = document.form.latwgs84.value;
	var lon = document.form.lonwgs84.value;

	if (lat.toString().includes('.')){
			var latZoom = lat.toString().split(".")[1].length;
	}
	if (lon.toString().includes('.')){
			var lonZoom = lon.toString().split(".")[1].length;
	}
	
	if (Math.min(latZoom, lonZoom) == 0) {
		map.flyTo([lat, lon], 4);
	} 
	if (Math.min(latZoom, lonZoom) == 1) {
		map.flyTo([lat, lon], 6);
	}
	if (Math.min(latZoom, lonZoom) == 2) {
		map.flyTo([lat, lon], 8);
	} 
	if (Math.min(latZoom, lonZoom) == 3) {
		map.flyTo([lat, lon], 12);
	}
	if (Math.min(latZoom, lonZoom) == 4) {
		map.flyTo([lat, lon], 14);
	}
	if (Math.min(latZoom, lonZoom) == 5) {
		map.flyTo([lat, lon], 16);
	}
	if (Math.min(latZoom, lonZoom) == 6) {
		map.flyTo([lat, lon], 18);
	}
}
function handleFiles() {	
	/**
	 * Read .zip shpfiles and calculate the bounding box coordinates of the spatial coverage of the shapefile
	 */
	var fichierSelectionne = document.getElementById('input').files[0];
	form.filename.value = fichierSelectionne.name;

	var fr = new FileReader();
	fr.onload = function () {
		shp(this.result).then(function(geojson) {
	  		console.log('loaded geojson:', geojson);
	  		
	  		/*for (var i = 0; i <= geojson.features.length-1; i++) {
	  			// applying a simplifcation algorithm (Douglas-Peucker) to reduce te number of coordinates in order to ease the exportation of the geometry
	  			var coordinates = simplifyGeometry(geojson.features[i].geometry.coordinates[0], 0.01);
	  			var lonLat = [];
	  			for (var j = 0; j <= coordinates.length-1; j++) {
	  				lonLat.push(coordinates[j][0] + ' ' + coordinates[j][1]);
	  			} outWKT.push('((' + lonLat + '))');
	  		} document.form.outWKT.value = 'wkt:MultiPolygon('+outWKT+')'; console.log(outWKT[0]);*/
	  		
			var shpfile = new L.Shapefile(geojson,{
				onEachFeature: function(feature, layer) {
					if (feature.properties) {
						layer.bindPopup(Object.keys(feature.properties).map(function(k) {
							return k + ": " + feature.properties[k];
						}).join("<br />"), {
							maxHeight: 200
						});
					}
				}
			});
			shpfile.addTo(map);
			// geojson.features = geojson.features[0];	// test with a Polygon;
			var geometry = JSON.stringify(getGeometry(geojson));
			console.log(geometry);
			document.form.outWKT.value = geometry;
	  })
	};
	fr.readAsArrayBuffer(fichierSelectionne);
}
function getGeometry(geojson) {
	/**
	 * Create a geoJSON object
	 * \@param  {GeoJSON} geojson  GeoJSON object with a given number of points
	 * \@return {GeoJSON} geometry GeoJSON object which has its coordinates corresponding to the bounding box of the geometry of the input
	 */
	var geometry = {"type":"", "coordinates":""};

	if (geojson.features.length > 1) {
		geometry.type = "MultiPolygon";
		var coordinates = [];
		
		for (var i = 0; i < geojson.features.length; i++) {
			coordinates.push([getBoundingBox(geojson.features[i].geometry.coordinates)]);
		} geometry.coordinates = coordinates; return geometry;
	} else {
		geometry.type = "Polygon";
		geometry.coordinates = [getBoundingBox(geojson.features.geometry.coordinates)];
		return geometry;
	}
}
function getBoundingBox(coordinates) {
	/**
	 * Calculate the bounding box of given coordinates
	 * \@param  {Array} coordinates Array of coordinates
	 * \@return {Array} The calculated bounding box as an array of coordinates
	 */
	var bounds = {}, coords, point, latitude, longitude;

    coords = coordinates;

	for (var j = 0; j < coords.length; j++) {
		longitude = coords[j][0];
    	latitude = coords[j][1];
    	bounds.xMin = bounds.xMin < longitude ? bounds.xMin : longitude;
    	bounds.xMax = bounds.xMax > longitude ? bounds.xMax : longitude;
		bounds.yMin = bounds.yMin < latitude ? bounds.yMin : latitude;
    	bounds.yMax = bounds.yMax > latitude ? bounds.yMax : latitude;
    }
    var coordinates = [bounds.xMin, bounds.xMax, bounds.yMin, bounds.yMax, bounds.xMin];
    return coordinates;
}

function addCreator() {
	/**
	 * Add a creator row to fill in the form
	 */
    var form = \$('#theform')[0];
	form.count_creator.value = parseInt(form.count_creator.value)+1;
	var new_div = document.createElement('div');
	new_div.id = 'new_creator'+form.count_creator.value;
    new_div.innerHTML = \$('#creator')[0].innerHTML;
    \$('#creator_add')[0].append(new_div);
}
function removeCreator() {
	/**
	 * Remove a creator row (if there are more than one row) to fill in the form
	 */
	var form = \$('#theform')[0];
	var id = '#new_creator'+form.count_creator.value;
	if (\$(id)[0] === null) {
		return false;
	} else if (form.count_creator.value > 1) {
		\$(id)[0].remove();
		form.count_creator.value -= 1;
	}
}
function showHideTheia(checkbox){
	const theia = document.getElementById("showHide");

	if (checkbox.checked == true) {
		theia.style.display = "none";
	} else {
		theia.style.display = "block";
	}
}

// creating and parametring the map for the geographic location choice

var	esriAttribution = 'Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community';
var stamenAttribution = 'Map tiles by <a href="http://stamen.com">Stamen Design</a>, <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a> &mdash; Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>contributors';
var osmAttribution = 'Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';
		
//Init Overlays
var overlays = {};
		
//Init BaseMaps
var basemaps = {
	'OpenStreetMaps': L.tileLayer(
		"https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
		{
			attribution: osmAttribution,
			minZoom: 2,
			maxZoom: 19,
			id: "osm"
		}
	),
	'Stamen-Terrain': L.tileLayer(
		'https://stamen-tiles-{s}.a.ssl.fastly.net/terrain/{z}/{x}/{y}{r}.{ext}',
		{
			attribution: stamenAttribution,
			minZoom: 2,
			maxZoom: 19,
			id: "stamen.terrain"
		}
	),
	'Stamen-Watercolor': L.tileLayer(
		'https://stamen-tiles-{s}.a.ssl.fastly.net/watercolor/{z}/{x}/{y}.{ext}',
		{
			attribution: stamenAttribution,
			minZoom: 2,
			maxZoom: 19,
			id: "stamen.watercolor"
		}
	),
	'OpenTopoMap': L.tileLayer(
		'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
		{
			attribution: osmAttribution,
			minZoom: 2,
			maxZoom: 19,
			id: "otm"
		}
	),
	'ESRIWorldImagery': L.tileLayer(
		'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
		{
			attribution: osmAttribution,
			minZoom: 2,
			maxZoom: 19,
			id: "esri.world"
		}
	)
};
		
//Map Options
var mapOptions = {
	zoomControl: false,
	attributionControl: false,
	center: [0, 0],
	zoom: 2,
	layers: [basemaps.OpenStreetMaps]
};
</script>

</head>

<body style="background-color:#E0E0E0" onLoad="maj_transmission();latlonChange();fc();checkNode();" id="formNode">
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="javascript" src="/js/overlib/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID="helpBox"></DIV>

FIN

print "<FORM id=\"theform\" name=\"form\" method=\"post\" action=\"\">\n";
# --- "Validity"
my $nodevalidity;
if (clientHasAdm(type=>"authmisc",name=>"NODES")) {
	$nodevalidity = "<P><input type=\"checkbox\"".(($usrValid == 1 || $newnode)?" checked":"")
		." name=\"valide\" value=\"NA\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'help_creationstation_valid'}')\">"
		."<b>$__{'Valid Node'}</b></P>";
} else {
	$nodevalidity = "<INPUT type=\"hidden\" name=\"valide\" value=\"NA\">";
}
print "<TABLE width=\"100%\">
	<TR><TD style=\"border:0\"><H1>$titrePage</H1>\n<H2>$titre2</H2>$nodevalidity</TD>
	<TD style=\"border:0; text-align:right\"></TD></TR>
	</TABLE>";

print "<INPUT type=\"hidden\" name=\"referer\" value=\"$referer\">\n";
print "<INPUT type=\"hidden\" name=\"refresh\" value=\"0\">\n";
print "<INPUT type=\"hidden\" name=\"delete\" value=\"0\">\n";
print "<INPUT type=\"hidden\" name=\"locMap\" value=\"0\">\n";
for (@allNodes) {
	print "<INPUT type=\"hidden\" name=\"allNodes\" value=\"$_\">\n";
}
print "<TABLE style=\"border:0\" width=\"100%\">";
print "<TR>";
	print "<TD style=\"border:0;vertical-align:top\" nowrap>";   # left column

	print "<FIELDSET><LEGEND>$__{'Name and Description'}</LEGEND>";
	# --- Codes, Name, Alias, Type
	print "<LABEL style=\"width:80px\" for=\"nodename\">$__{'Code/ID'}:</label>$GRIDType.$GRIDName.";
	if ($newnode == 1) {
		print "<INPUT id=\"nodename\" name=\"nodename\" size=\"20\" value=\"$NODEName\" onKeyUp=\"checkNode()\">";
	 	print "<INPUT size=\"15\" id=\"message\" name=\"message\" readOnly style=\"background-color:#E0E0E0;border:0\">";
		print "<INPUT type=\"hidden\" name=\"nouveau\" value=\"1\"\n>";
	} else {
		print "<INPUT readonly=\"readonly\" style=\"font-family:monospace;font-weight:bold;font-size:120%;background-color:transparent;border:none\" id=\"nodename\" name=\"nodename\" size=\"20\" value=\"$NODEName\"><BR>";
	 	print "<INPUT type=\"hidden\" name=\"message\" value=\"0\">";
	 	print "<INPUT type=\"hidden\" name=\"nouveau\" value=\"0\">";
	}
	print "<INPUT type=\"hidden\" name=\"grid\" value=\"$GRIDType.$GRIDName.\">";
	print "<INPUT type=\"hidden\" name=\"node\" value=\"$QryParm->{'node'}\">";
		print "<BR>";
		# --- Nom complet/TITLE
		print "<LABEL style=\"width:80px\" for=\"fullName\">$__{'Name'}:</LABEL>";
		print "<INPUT size=\"40\" value=\"$usrName\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_name}')\" name=\"fullName\" id=\"fullName\"><BR>";
		# --- ALIAS
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'Alias'}:</LABEL>";
		print "<INPUT size=\"15\" onMouseOut=\"nd()\" value=\"$usrAlias\" onmouseover=\"overlib('$__{help_creationstation_alias}')\" size=\"8\" name=\"alias\" id=\"alias\">&nbsp;&nbsp;<BR>";
		# --- TYPE
		print "<LABEL style=\"width:80px\" for=\"type\">$__{'Type'}:</LABEL>";
		print "<INPUT size=\"15\" onMouseOut=\"nd()\" value=\"$usrType\" onmouseover=\"overlib('$__{help_creationstation_type}')\" size=\"8\" name=\"type\" id=\"type\">&nbsp;&nbsp;<BR>";
		# --- DESCRIPTION
		print "<LABEL style=\"width:80px\" for=\"description\">$__{'Description'}:</LABEL>";
		print "<TEXTAREA rows=\"4\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_description}')\" cols=\"40\" name=\"description\" id=\"description\">$usrDesc<\/TEXTAREA>&nbsp;&nbsp;<BR>";
		# --- show THEIA fields ?
		print "<LABEL>show/hide THEIA metadata fields ?<INPUT type=\"checkbox\" name=\"show/hide\" onchange=\"showHideTheia(this)\"></LABEL>&nbsp;<BR><BR>";
		print "<DIV id=\"showHide\">";
		# --- PRODUCER
		print "<LABEL style=\"width:80px\" for=\"producer\">$__{'Producer'}:</LABEL>";
		print "<INPUT size=\"15\" onMouseOut=\"nd()\" value=\"$usrProducer\" onmouseover=\"overlib('$__{help_creationstation_producer}')\" size=\"8\" name=\"producer\" id=\"producer\">&nbsp;&nbsp;<BR>";
		# --- CREATOR
		print "<BUTTON style=\"text-align:center\" onclick=\"addCreator(); return false;\">Add a creator </BUTTON>";
		print "<BUTTON onclick=\"removeCreator(); return false;\">Remove a creator </BUTTON>";
		print "<INPUT type='hidden' name=\"count_creator\" value='1'></INPUT>";
		print "<INPUT type='hidden' name=\"creators\" value=''></INPUT>";
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'Creator'}:</LABEL><BR><BR>";
		print "<DIV id=\"creator\">";
		print "<SELECT onMouseOut=\"nd()\" value=\"$usrCreator\" onmouseover=\"overlib('$__{help_creationstation_creator}')\" name=\"role\" id=\"creator\" size=\"1\">";
		for (@creators) { print "<OPTION value=\"$_\">$_</option>\n"; }
		print "</SELECT>&nbsp;&nbsp";
		print "<INPUT size=\"8\" onMouseOut=\"nd()\" value=\"$usrFirstName\" placeholder=\"first name\" onmouseoverd=\"overlib('$__{help_creation_firstName}')\" name=\"firstName\" id=\"firstName\">&nbsp;&nbsp;";
		print "<INPUT size=\"8\" onMouseOut=\"nd()\" value=\"$usrLastName\" placeholder=\"last name\" onmouseoverd=\"overlib('$__{help_creation_lastName}')\" name=\"lastName\" id=\"lastName\">&nbsp;&nbsp;";
		print "<INPUT size=\"8\" onMouseOut=\"nd()\" value=\"$usrEmail\" placeholder=\"email\" onmouseoverd=\"overlib('$__{help_creation_email}')\" name=\"email\" id=\"email\">&nbsp;&nbsp;<BR></DIV>";
		print "<DIV id='creator_add'></DIV><BR>";
		# --- INSPIRE THEME
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'INSPIRE theme'}:</LABEL>";
		print "<SELECT onMouseOut=\"nd()\" value=\"$usrTheme\" onmouseover=\"overlib('$__{help_creationstation_subject}')\" name=\"theme\" id=\"theme\" size=\"1\">";
		for (@themes) { print "<OPTION value=\"$_\">$_</option>\n"; }
		print "</SELECT><BR>";
		# --- TOPIC CATEGORIES
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'Topic categories'}:</LABEL>";
		print "<INPUT type=\"hidden\" name=\"topics\">";
		print "<SELECT multiple onMouseOut=\"nd()\" value=\"$usrTopic\" onmouseover=\"overlib('$__{help_creationstation_subject}')\" id=\"topicCats\">";
		for (@topics) { print "<OPTION value=\"$_\">$_</option>\n"; }
		print "</SELECT><BR>";
		# --- Lineage
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'Lineage'}:</LABEL>";
		print "<INPUT size=\"40\" onMouseOut=\"nd()\" value=\"$usrLineage\" onmouseover=\"overlib('$__{help_creationstation_lineage}')\" size=\"8\" name=\"lineage\" id=\"lineage\">&nbsp;&nbsp;<BR>";
		print "</DIV>";
	print "</FIELDSET>";

	print "<FIELDSET><LEGEND>$__{'Lifetime and Events Time Zone'}</LEGEND>";
  	# --- Dates debut et fin
  	print "<TABLE>";
    	print "<TR>";
			print "<TD style=\"border:0;text-align:right\">";
    		print "<DIV class=parform>";
				print "<B>$__{'Start date'}:</b> <SELECT name=\"anneeDepart\" size=\"1\">";
				for ($usrYearC,@yearListC) { print "<OPTION".(($_ eq $usrYearC)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
				print " <SELECT name=\"moisDepart\" size=\"1\">";
				for (@monthList) { print "<OPTION".(($_ eq $usrMonthC)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
				print " <SELECT name=\"jourDepart\" size=\"1\">";
				for (@dayList) { 	print "<OPTION".(($_ eq $usrDayC)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT><BR>";
				print "<b>$__{'End date'}:</b> <SELECT name=\"anneeEnd\" size=\"1\">";
				for ($usrYearE,@yearListE) { print "<OPTION".(($_ eq $usrYearE)?" selected":"")." value=$_>$_</option>\n"; }
				print "<OPTION value=NA>NA</option>\n";
				print "</SELECT>";
				print " <SELECT name=\"moisEnd\" size=\"1\">";
				for (@monthList) { print "<option".(($_ eq $usrMonthE)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
				print " <SELECT name=\"jourEnd\" size=\"1\">";
				for (@dayList) { print "<option".(($_ eq $usrDayE)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
			print "</DIV></TD>";
			print "<TD align=center style=\"border:0\"></TD>";
			print "<TD style=\"border:0\">";
				# --- ALIAS
				print "<LABEL style=\"width:100px\" for=\"tz\">$__{'Time zone (h)'}:</LABEL>";
				print "<INPUT size=\"5\" onMouseOut=\"nd()\" value=\"$usrTZ\" onmouseover=\"overlib('$__{help_creationstation_tz}')\" size=\"8\" name=\"tz\" id=\"tz\">";
			print "</TD>";
		print "</TR>";
	print "</TABLE>\n";
	print "</FIELDSET>";

	# --- Features
	print "<FIELDSET><LEGEND>$__{'Features'}</LEGEND>";
	print "<INPUT size=\"60\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_spec}')\" name=\"features\" value=\"".join(',',@feat)."\">"
		."&nbsp;<IMG src=\"/icons/refresh.png\" align=\"top\" onClick=\"refresh_form();\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'help_creationstation_featrefresh'}')\"><BR><BR>";
	for (@feat) {
		print "<LABEL style=\"width:120px\" for=\"$_\">$_:</LABEL>";
		my $pat = qr/^$NODEName\|$_\|/;
		my @fnlist = grep(/$pat/,@n2n);
		my $fn = join(',',@fnlist);
		$fn =~ s/$NODEName\|$_\|//g;
		print "<INPUT size=\"30\" onMouseOut=\"nd()\" value=\"$fn\" name=\"$_\" onmouseover=\"overlib('$__{help_creationstation_n2n}')\"><BR>";
	}
	# edition of the node2node file needs an admin level
	#if (WebObs::Users::clientHasAdm(type => "auth".lc($GRIDType)."s", name => "*")) {
	#	print "<P><A href=\"/cgi-bin/cedit.pl?fs=CONF_NODES(FILE_NODES2NODES)\"><img src=\"/icons/modif.png\" border=\"0\">  $__{'Edit the node-features-nodes associations list'}</A></P>";
	#}
	print "</FIELDSET>";

	# --- Grids
	print "<FIELDSET><LEGEND>$__{'Associated Grids'}</LEGEND>\n";
	# --- (additional) GRIDS: VIEWs and PROCs
	# --- list only PROCs and VIEWs that client has AUTHEDIT to ...
	my @GL;
	#     ... all views and procs
	#FB-was: my @Lprocs = map("PROC.".basename($_), qx(ls -d $WEBOBS{PATH_PROCS}/*)); chomp(@Lprocs);
	#FB-was: my @Lviews = map("VIEW.".basename($_), qx(ls -d $WEBOBS{PATH_VIEWS}/*)); chomp(@Lviews);
	my @Lprocs = map("PROC.".basename($_), qx(find $WEBOBS{PATH_PROCS}/* -type d)); chomp(@Lprocs);
	my @Lviews = map("VIEW.".basename($_), qx(find $WEBOBS{PATH_VIEWS}/* -type d)); chomp(@Lviews);
	#     ... set client-and-its-groups where clause element, then query DB
	my $cid    = "$USERS{$CLIENT}{UID}";
	my $wc = " uid in (SELECT GID from $WEBOBS{SQL_TABLE_GROUPS} WHERE UID=\"$cid\") OR uid = \"$cid\" ";
	my @Aprocs = qx(sqlite3 -separator '.' $WEBOBS{SQL_DB_USERS} 'select "PROC",resource from $WEBOBS{SQL_TABLE_AUTHPROCS} where auth >= 2 and $wc');
	my @Aviews = qx(sqlite3 -separator '.' $WEBOBS{SQL_DB_USERS} 'select "VIEW",resource from $WEBOBS{SQL_TABLE_AUTHVIEWS} where auth >= 2 and $wc');
	chomp(@Aviews); chomp(@Aprocs);
	#     ... merge client-allowed-to VIEWS and PROCS into @GL
	if   ( ('VIEW.*') ~~ @Aviews ) { @GL = @Lviews }
	else                           { map { push(@GL,$_) if (($_) ~~ @Aviews) } @Lviews }
	if   ( ('PROC.*') ~~ @Aprocs ) { @GL = (@GL,@Lprocs) }
	else                           { map { push(@GL,$_) if (($_) ~~ @Aprocs) } @Lprocs }
	print "<TABLE border=\"0\" cellpadding=\"3\" cellspacing=\"0\" width=\"100%\">";
	print "<TR><TD style=\"border:0\">";
	print "<SELECT name=\"INs\" size=\"5\" MULTIPLE>";
	for (@GL) { if (! (($_) ~~ @{$allNodeGrids{$NODEName}}) ) { print "<option value=\"$_\">$_</option>\n" } }
	print "</SELECT></td>";
	print "<TD style=\"border:0;text-align:center;vertical-align:middle\">";
	print "<INPUT type=\"Button\" value=\"$__{Add} >>\" style=\"width:100px\" onClick=\"SelectMoveRows(document.form.INs,document.form.SELs)\"><br>";
	print "<BR>";
	print "<INPUT type=\"Button\" value=\"<< $__{Remove}\" style=\"width:100px\" onClick=\"javascript: if (document.form.SELs.options.length == 1) {alert('invalid remove: node MUST belong to at least 1 grid !');} else { SelectMoveRows(document.form.SELs,document.form.INs);}\">";
	print "</TD>";
	print "<TD style=\"border:0\">";
	print "<SELECT name=\"SELs\" size=\"5\" multiple style=\"font-weight:bold\">";
	if  ($newnode == 1) { print "<option selected value=\"$GRIDType.$GRIDName\">$GRIDType.$GRIDName</option>"; }
	for (@{$allNodeGrids{$NODEName}}) { print "<option selected value=\"$_\">$_</option>"; }
	print "</SELECT></td>";
	print "</TR>";
	print "</TABLE>";
	print "</FIELDSET>";

	print "</TD>\n";                                                                 # end left column
	print "<TD style=\"border:0;vertical-align:top;padding-left:40px\" nowrap>";   # right column

	# --- 'node' position (latitude, longitude & altitude)
	print "<FIELDSET><LEGEND>$__{'Geographic location'}</LEGEND>";
	print "<TABLE><TR>";
		print "<TD style=\"border:1;text-align:left\">";
			print "<DIV id='map' style=\"position: relative ;width: 347px; height: 347px\"></DIV>";
		print "</TD>";
		print "<TD style=\"border:1;text-align:left;rows:6;\">";
			print "<label>Auto-location :</label><button id=\"auto-loc\" style=\"position:relative;\">Locate me !</button>&nbsp;<BR>";
			print "<label for=\"latwgs84\">$__{'Latitude'}  WGS84:</label>";
			print "<input size=\"8\" class=inputNum value=\"$usrLat\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lat}')\" id=\"latwgs84\" name=\"latwgs84\" oninput=\"onInputWrite()\"><B>&#176;&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lat}')\" id=\"latwgs84min\" name=\"latwgs84min\"><B>'&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lat}')\" id=\"latwgs84sec\" name=\"latwgs84sec\"><B>\"&nbsp;</B>";
			print "<select name=\"latwgs84n\" size=\"1\">";
			for ("N","S") { print "<option".($usrLatN eq $_ ? " selected":"")." value=$_>$_</option>\n"; }
			print "</select><BR>\n";
			print "<label for=\"lonwgs84\">$__{'Longitude'}  WGS84:</label>";
			print "<input size=\"8\" class=inputNum value=\"$usrLon\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lon}')\" id=\"lonwgs84\" name=\"lonwgs84\" oninput=\"onInputWrite()\"><B>&#176;&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lon}')\" id=\"lonwgs84min\" name=\"lonwgs84min\"><B>'&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lon}')\" id=\"lonwgs84sec\" name=\"lonwgs84sec\"><B>\"&nbsp;</B>";
			print "<select name=\"lonwgs84e\" size=\"1\">";
			for ("E","W") { print "<option".($usrLonE eq $_ ? " selected":"")." value=$_>$_</option>\n"; }
			print "</select><BR>\n";
			print "<label for=\"altitude\">$__{'Elevation'}  (m):</label>";
			print "<input size=\"8\" class=inputNum value=\"$usrAlt\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_alt}')\" id=\"altitude\" name=\"altitude\"><BR>\n";
			# --- positioning date
			print "<label for=\"datePos\">Date:</label> <select name=\"anneeMesure\" size=\"1\">";
			for ($usrYearP,@yearListP) { print "<option".(($_ eq $usrYearP)?" selected":"")." value=$_>$_</option>\n";	}
			print "</select>";
			print " <select name=\"moisMesure\" size=\"1\">";
			for (@monthList) { print "<option".(($_ eq $usrMonthP)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"jourMesure\" size=\"1\">";
			for (@dayList) { print "<option".(($_ eq $usrDayP)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select><BR>";
			# --- Positioning type (unknown, map, GPS or auto)
			print "<label for=\"typePos\">Type: </label> "
				."<select name=\"typePos\" size=\"1\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_pos_type}')\">";
			for (sort(keys(%typePos))) { print  "<option".(($_ eq $usrTypePos) ? " selected ":"")." value=$_>$typePos{$_}</option>\n"; }
			print "</select><BR>";
			print "<DIV id=\"rawKML\" style=\"display:none\"><LABEL for=\"rawKML\">Raw KML: </LABEL>"
				." <INPUT name=\"rawKML\" size=\"40\" value=\"$usrRAWKML\">"
				."<IMG src='/icons/refresh.png' style='vertical-align:middle' title='Fetch KML' onClick='fetchKML()'></DIV>";
				
			# --- Importation of shpfile
			print "<INPUT type=\"hidden\" name=\"filename\"";
			print "<strong>To add a shapefile (.zip only) layer, click here: </strong><input type='file' id='input' onchange='handleFiles()' value=\"\"><br>";
			print "<INPUT type=\"hidden\" name=\"outWKT\" value=\"\"\n>";
				
		print "</TD>";
		print <<FIN;
		<script>
			var map = L.map('map', mapOptions);
			var popup = L.popup();
			map.on('click', onMapClick);
			
			document.getElementById("auto-loc").addEventListener('click', getLocation);
			// let suivi = navigator.geolocation.getCurrentPosition(getCurrent, error);
			
			if ( document.form.latwgs84.value !== "" || document.form.lonwgs84.value !== "" ) {
				var lat = document.form.latwgs84.value;
				var lon = document.form.lonwgs84.value;
				lat, lon = nsew(lat, lon);
				map.flyTo([lat, lon], 18);
				var marker = L.marker([lat, lon]).addTo(map);
				marker.bindPopup(\"$text\").openPopup();
			}
			
			var layerControl = L.control.layers(basemaps, overlays).addTo(map);
		</script>
FIN
	print "</TR></TABLE>";
	print "</FIELDSET>\n";

	# --- Transmission
	print "<FIELDSET><legend>$__{'Transmission'}</LEGEND>";
	print "<TABLE><TR>";
		print "<TD style=\"border:0;text-align:left\">";
			print "<LABEL for=\"typeTrans\">Type: </LABEL>";
			print "<SELECT onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_creationstation_tele_type}')\" id=\"typeTrans\" name=\"typeTrans\" size=\"1\" onChange=\"maj_transmission()\">";
			for (sort(keys(%typeTele))) {
				my $sel = "";
				if ( $_ eq "$usrTrans" ) { $sel = "selected" }
				print "<OPTION $sel value=\"$_\">$typeTele{$_}{name}</OPTION>";
			}
			print "</SELECT>\n";
		print "</TD>";
		print "<TD style=\"border:0\">";
			# Transmission path (acquisition + repeater list)
			print "<DIV id=\"pathTrans\" style=\"display:none\"><LABEL for=\"pathTrans\">$__{'Repeaters Path'}: </LABEL>";
			print "<INPUT onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_creationstation_tele_acq}')\" name=\"pathTrans\" size=\"40\" value=\"".join(',',@usrTele)."\"><br/></DIV>";
		print "</TD>";
	print "</TR></TABLE>";
	print "</FIELDSET>";

	# --- Procs parameters
	if (uc($GRIDType) eq "PROC") {
		print "<FIELDSET><LEGEND>$__{'Procs Parameters'}</LEGEND>";
		print "<TABLE><TR><TD style=\"border:0;text-align:left\" colspan=2>";
		print "<LABEL for=\"proc\">Proc name: </LABEL>";
		print "<B>$GRID{NAME}</B> (".(defined($GRID{NODESLIST}) ? scalar(@{$GRID{NODESLIST}}):"0")." nodes)<INPUT hidden id=\"proc\" name=\"proc\" value=\"\" style=\"background-color:transparent;border:none\"><BR><BR>\n";
		# --- RAWFORMAT list
		print "<LABEL for=\"RawFormat\">Raw format: </label> <select onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_rawformat}')\" name=\"rawformat\" size=\"1\" onChange=\"maj_rawformat()\">";
		my %rawfmt;
		my @fmtfid;
		for (keys(%rawFormats)) {
			$rawfmt{"$rawFormats{$_}{supfmt}-$_"} = $_;
			for (split(/,/,$rawFormats{$_}{FID})) {
				push(@fmtfid,"FID_$_") if (!grep(/^FID_$_$/,@fmtfid));
			}
		}
		for (sort(keys(%rawfmt))) {
			my $key = $rawfmt{$_};
			print  "<OPTION".($key eq $usrRAWFORMAT ? " selected ":"")." value=$key>".($key ? "$rawFormats{$key}{supfmt} {$key} ":"")."$rawFormats{$key}{name}</option>\n";
		}
		print "</SELECT><BR>\n";
		# --- RAWDATA
		print "<LABEL for=\"rawdata\">$__{'Raw data source'}: </label> <input size=\"60\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_rawdata}')\" type=\"text\" id=\"rawdata\" name=\"rawdata\" value=\"$usrRAWDATA\"/><br/>";
		# --- FDSN Network Code
		print "<LABEL for=\"fdsn\">Network code: </LABEL>";
		print "<SELECT name=\"fdsn\" id=\"fdsn\" size=\"1\" onMouseOut=\"nd()\" value=\"$usrFDSN\" onMouseOver=\"overlib('$__{help_creationstation_fdsn}')\">";
		for ("",sort(keys(%FDSN))) {
			print "<OPTION".((trim($_) eq trim($usrFDSN)) ? " selected ":"")." value=$_>".($_ ne "" ? "$_: ":"")."$FDSN{$_}</option>\n";
		}
		print "</SELECT><BR>\n";
		print "</TD>\n";
		# --- CHANNEL_LIST
		print "<TD rowspan=2 style=\"border:0;text-valign:top\">";
		print "<LABEL for=\"chanlist\">$__{'Channel list'}: </LABEL>";
		my $clbFile = "$NODES{PATH_NODES}/$NODEName/$GRIDType.$GRIDName.$NODEName.clb";
		$clbFile = "$NODES{PATH_NODES}/$NODEName/$NODEName.clb" if ( ! -e $clbFile ); # for backwards compatibility

		if (-s $clbFile != 0) {
			my @select = split(/,/,$usrCHAN);
			my @carCLB   = readCfgFile($clbFile);
			# make a list of available channels and label them with last Chan. + Loc. codes
			my %chan;
			for (@carCLB) {
				my (@chpCLB) = split(/\|/,$_);
				$chan{$chpCLB[2]} = "$chpCLB[3] ($chpCLB[6] $chpCLB[19])";
			}
			print "<SELECT name=\"chanlist\" multiple size=\"5\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_chanlist}')\" id=\"chanlist\">";
			for (sort{ $a <=> $b } (keys(%chan))) {
				print "<option".($_ ~~ @select || !defined($usrCHAN) ? " selected":"")." value=\"$_\">"."$_: $chan{$_}</option>\n";
			}
			print "</SELECT>";
		} else {
			print "no calibration file.";
		}
		print "</TD></TR>\n";
		# --- DATA (FID)
		print "<TR><TD style=\"border:0\">";
		print "<LABEL for=\"data\">FID:</LABEL>";
		print "<INPUT size=\"15\" value=\"$usrDataFile\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_fid}')\" name=\"data\" id=\"data\"><BR>\n";
		# --- DATA (FID_x)
		# first displays any user defined FID_x (that are NOT in the rawformats list)
		my @usrFIDshort = map {$_ =~ s/^$GRIDType\.$GRIDName\.//g; $_} @usrFID;
		for (sort @usrFID) {
			my $short = $_;
			$short =~ s/^$GRIDType\.$GRIDName\.//g;
			if (!grep(/^$short$/,@fmtfid)) {
				my $long = "$GRIDType.$GRIDName.$short";
				print "<label for=\"$short\">$short:</label><input size=\"15\" value=\"$NODE{$long}\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_fid}')\" name=\"$long\" id=\"data\"><BR>\n";
			}
		}
		# second adds all possible FID_x: visible for active RAWFORMAT, hidden for others
		print "<DIV id=\"fidx\">\n";
		for (keys(%rawFormats)) {
			my $key = $_;
			for (split(/,/,$rawFormats{$key}{FID})) {
				my $fid = "FID_$_";
				my $long = "$GRIDType.$GRIDName.$fid";
					my $disp = ($key eq $usrRAWFORMAT ? "block":"none");
					print "<DIV id=\"$key-$fid\" style=\"display: $disp\"><LABEL for=\"$fid\">$fid:</LABEL><INPUT id=\"input-$key-$fid\" size=\"15\" value=\"$NODE{$long}\" name=\"$fid\"><BR></DIV>\n";
			}
		}
		print "</DIV></TD>\n<TD style=\"border:0;text-align:right\">";
		print "<label for=\"utcd\">$__{'Time zone (h)'}: </label> <input size=\"9\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_proc_tz}')\" type=\"text\" id=\"utcd\" name=\"utcd\" value=\"$usrUTC\"/><br/>";
		print "<label for=\"acqr\">$__{'Acq. period (days)'}: </label> <input size=\"9\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_proc_acqrate}')\"type=\"text\" id=\"acqr\" name=\"acqr\" value=\"$usrACQ\"/><br/>";
		print "<label for=\"ldly\">$__{'Acq. delay (days)'}: </label> <input size=\"9\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_proc_acqdelay}')\"type=\"text\" id=\"ldly\" name=\"ldly\" value=\"$usrDLY\"/><br/>";
		print "</TD></TR></TABLE></FIELDSET><BR>\n";
	}
	# --- Propagates any other Proc's parameters (hidden)
	#	PROC.*.* = other proc's parameters
	#	^* = list of selected parameters formerly associated with all proc): they have been used at the begining of this script
	#	to fill the default values in form, but will be also propagated to all other associated procs (see postNODE.pl)
	for (keys(%NODE)) {
		if ( !($_ =~ /^$GRIDType\.$GRIDName\./)
			&& $_ =~ /^VIEW\.|^PROC\.|^FDSN_NETWORK_CODE$|^UTC_DATA$|^ACQ_RATE$|^RAWFORMAT$|^RAWDATA$|^CHANNEL_LIST$|^FID/ ) {
			print "<INPUT hidden name=\"$_\" value=\"$NODE{$_}\">";
		}
	}


	## # --- "Validity"
	## if ( clientHasAdm(type=>"authmisc",name=>"NODES")) {
  	## 	print "<P class=parform><input type=\"checkbox\"".(($usrValid == 1 || $newnode)?" checked":"")
  	## 		." name=\"valide\" value=\"NA\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Check to mark node as valid'}')\">"
  	## 		."<b>$__{'Valid Node'}</b></P>\n";
	## } else {
  	## 	print "<input type=\"hidden\" name=\"valide\" value=\"NA\">";
	## }

print "</TD></TR>";
print "<TR><TD style=border:0 colspan=2><HR>";
# --- buttons zone
print "<P align=center>";
print "<INPUT type=\"button\" value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
print "<INPUT type=\"button\" value=\"$__{'Save'}\" style=\"font-weight:bold\" onClick=\"postIt();\">";
print "</P></TD></TR></TABLE>";
print "</FORM>";

print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Mallarino, Alexis Bosson, Didier Lafon, Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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

