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
my %typePos  = readCfg("$NODES{FILE_POS}");
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
my $usrGnss9char = $NODE{GNSS_9CHAR};
my $m3g_check    = $NODE{M3G_AVAIABLE};
my $usrAlt       = $NODE{ALTITUDE};
my $usrTypePos   = $NODE{POS_TYPE};
#      Transmission
my ($usrTrans,@usrTele) = split(/,| |\|/,$NODE{TRANSMISSION});
if ($usrTrans eq "NA") { $usrTrans = "0"; }
#      dates
my $usrYearE = my $usrYearC = my $usrYearP = "";
my $usrMonthE = my $usrMonthC = my $usrMonthP = "";
my $usrDayE = my $usrDayC = my $usrDayP = my $date = "";
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
($usrYearP,$usrMonthP,$usrDayP) = split(/-/,$date);

# ---- Load the list of existing nodes
my @allNodes = qx(/bin/ls $NODES{PATH_NODES});
chomp(@allNodes);

my $infoFile   = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS}" // "";
my $accessFile = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_PHOTOS}" // "";

# ---- Things to populate select dropdown fields
my $anneeActuelle = strftime('%Y',@tod);
my @anneeListeP = reverse($WEBOBS{BIG_BANG}..$anneeActuelle+1,'');
my @anneeListeC = reverse($WEBOBS{BIG_BANG}..$anneeActuelle+1,'');
my @anneeListeE = reverse($WEBOBS{BIG_BANG}..$anneeActuelle+1,'');
my @moisListe = ('','01'..'12');
my @jourListe = ('','01'..'31');

# ---- ready for HTML output now
#
print $cgi->header(-charset=>"utf-8"),
$cgi->start_html("$__{'Node configuration form'}");

print <<"FIN";
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script language="javascript" type="text/javascript" src="/js/htmlFormsUtils.js"></script>
<script type="text/javascript">

function postIt()
{
 if(document.formulaire.nouveau.value == 1 && document.formulaire.message.value != "ok") {
   alert("NODE ID: Please enter a valid and new ID!");
   document.formulaire.nodename.focus();
   return false;
 }
 if((/^[\\s]*\$/).test(document.formulaire.fullName.value)) {
   alert("NAME: Please enter a full name (non-blank string)");
   document.formulaire.fullName.focus();
   return false;
 }
 if(document.formulaire.alias.value == "") {
   alert("ALIAS: Please enter a short name (non-blank string)");
   document.formulaire.alias.focus();
   return false;
 }
 if(document.formulaire.latwgs84.value != "" && (isNaN(document.formulaire.latwgs84.value) || document.formulaire.latwgs84.value < -90 || document.formulaire.latwgs84.value > 90)) {
   alert("LATITUDE: Please enter a latitude value between -90 and +90, or leave blank");
   document.formulaire.latwgs84.focus();
   return false;
 }
 if(document.formulaire.latwgs84.value < 0 && document.formulaire.latwgs84.value >= -90) {
   document.formulaire.latwgs84.value = Math.abs(document.formulaire.latwgs84.value);
   if (document.formulaire.latwgs84n.value == "N") document.formulaire.latwgs84n.value = "S";
   else document.formulaire.latwgs84n.value = "N";
 }
 if(document.formulaire.latwgs84.value == "" && (document.formulaire.latwgs84min.value != "" || document.formulaire.latwgs84sec.value != "")) {
   alert("LATITUDE: Please enter a value for degree or leave all fields blank");
   document.formulaire.latwgs84.focus();
   return false;
 }
 if(document.formulaire.lonwgs84.value != "" && (isNaN(document.formulaire.lonwgs84.value) || document.formulaire.lonwgs84.value < -180 || document.formulaire.lonwgs84.value > 180)) {
   alert("LONGITUDE: Please enter a longiture value between -180 and +180, or leave blank");
   document.formulaire.lonwgs84.focus();
   return false;
 }
 if(document.formulaire.lonwgs84.value < 0 && document.formulaire.lonwgs84.value >= -180) {
   document.formulaire.lonwgs84.value = Math.abs(document.formulaire.lonwgs84.value);
   if (document.formulaire.lonwgs84e.value == "E") document.formulaire.lonwgs84e.value = "W";
   else document.formulaire.lonwgs84e.value = "E";
 }
 if(document.formulaire.lonwgs84.value == "" && (document.formulaire.lonwgs84min.value != "" || document.formulaire.lonwgs84sec.value != "")) {
   alert("LONGITUDE: Please enter a value for degree or leave all fields blank");
   document.formulaire.lonwgs84.focus();
   return false;
 }
 if(document.formulaire.altitude.value != "" && isNaN(document.formulaire.altitude.value)) {
   alert("ELEVATION: Please enter a number or leave blank");
   document.formulaire.altitude.focus();
   return false;
 }
  if (document.formulaire.SELs.options.length < 1) {
    alert(\"node MUST belong to at least 1 grid\");
    document.formulaire.SELs.focus();
    return false;
  }

  for (var i=0; i<document.formulaire.elements['allNodes'].length; i++) {
  	document.formulaire.elements['allNodes'][i].disabled = true;
  }
  for (var i=0; i<document.formulaire.SELs.length; i++) {
  	document.formulaire.SELs[i].selected = true;
  }

	if (\$(\"#theform\").hasChanged() || document.formulaire.delete.value == 1) {
		document.formulaire.node.value = document.formulaire.grid.value + document.formulaire.nodename.value.toUpperCase();
		if (document.getElementById("fidx")) {
			var fidx = document.getElementById("fidx").getElementsByTagName("div");
			for (var i=0; i<fidx.length; i++) {
				if (document.formulaire.rawformat.value == "" || fidx[i].id.indexOf(document.formulaire.rawformat.value + "-") == -1) {
					var nested = document.getElementById("input-" + fidx[i].id);
					nested.parentNode.removeChild(nested);
				}
			}
		}
		\$.post(\"/cgi-bin/postNODE.pl\", \$(\"#theform\").serialize(), function(data) {
		     if (data != '') alert(data);
			 if (document.formulaire.refresh.value == 1) {
				 location.reload();
		     } else { location.href = document.formulaire.referer.value; }
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
		if (document.formulaire.rawformat.value != "" && fidx[i].id.indexOf(document.formulaire.rawformat.value + "-") != -1) {
			fidx[i].style.display = "block";
		} else {
			fidx[i].style.display = "none";
		}
	}
}

function maj_transmission() {
	if (document.formulaire.typeTrans.value==0) {
		document.getElementById("pathTrans").style.display="none";
	} else {
		document.getElementById("pathTrans").style.display="block";
	}
}

function checkNode() {
	document.formulaire.nodename.value = document.formulaire.nodename.value.toUpperCase();
	var nodeSyntax=/[^A-Za-z0-9\.@]+/;
	var ok = 1;
	var rouge = '#EE0000';
	var vert = '#66DD66';

	var node = document.formulaire.nodename.value;
	if (nodeSyntax.test(node)) {
		ok = 0;
		document.formulaire.message.value = "invalid char. !";
	} else {
		for (var i=0; i<document.formulaire.elements['allNodes'].length; i++) {
			if (document.formulaire.elements['allNodes'][i].value == node) {
				ok = 0;
				document.formulaire.message.value = "already exists !";
			}
		}
	}
	if (ok==1) {
		document.formulaire.nodename.style.background = vert;
		document.formulaire.message.value = "ok";
		document.formulaire.message.style.color = vert;
	} else {
		document.formulaire.nodename.style.background = rouge;
		document.formulaire.message.style.color = rouge;
	}
	if (document.formulaire.nodename.value == "") {
		document.formulaire.nodename.style.background = 'cornsilk';
		document.formulaire.message.value = "";
	}
	if (document.formulaire.nouveau.value == 0) {
		document.formulaire.nodename.style.background = 'none';
		document.formulaire.message.value = "";
	}
}

function latlonChange() {
	var today = new Date();
	var d  = today.getDate();
	document.formulaire.jourMesure.value = (d < 10) ? '0' + d : d;
	var m = today.getMonth() + 1;
	document.formulaire.moisMesure.value = (m < 10) ? '0' + m : m;
	var yy = today.getYear();
	document.formulaire.anneeMesure.value = (yy < 1000) ? yy + 1900 : yy;
}

function fc() {
	\$(\"#theform\").formChanges();
}

function refresh_form()
{
	document.formulaire.refresh.value = 1;
	postIt();
}

function delete_node()
{
	if ( confirm(\"The NODE will be deleted (and all its configuration, features, events, images and documents). You might consider unchecking the Valid checkbox as an alternative.\\n\\n Are you sure you want to move this NODE to trash ?\") ) {
		document.formulaire.delete.value = 1;
		document.formulaire.referer.value = '/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=$GRIDType.$GRIDName';
		postIt();
	} else {
		return false;
	}
}
</script>

</head>

<body style="background-color:#E0E0E0" onLoad="maj_transmission();fc();checkNode();" id="formNode">
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="javascript" src="/js/overlib/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID="helpBox"></DIV>

FIN

print "<FORM id=\"theform\" name=\"formulaire\" action=\"\">\n";
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
for (@allNodes) {
	print "<INPUT type=\"hidden\" name=\"allNodes\" value=\"$_\">\n";
}
print "<TABLE style=\"border:0\" width=\"100%\">";
print "<TR>";
	print "<TD style=\"border:0;vertical-align:top\" nowrap>";   # left column

	print "<FIELDSET><LEGEND>$__{'Names and Description'}</LEGEND>";
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
		# --- Nom complet
		print "<LABEL style=\"width:80px\" for=\"fullName\">$__{'Name'}:</LABEL>";
		print "<INPUT size=\"40\" value=\"$usrName\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_name}')\" name=\"fullName\" id=\"fullName\"><BR>";
		# --- ALIAS
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'Alias'}:</LABEL>";
		print "<INPUT size=\"15\" onMouseOut=\"nd()\" value=\"$usrAlias\" onmouseover=\"overlib('$__{help_creationstation_alias}')\" size=\"8\" name=\"alias\" id=\"alias\">&nbsp;&nbsp;<BR>";
		# --- TYPE
		print "<LABEL style=\"width:80px\" for=\"alias\">$__{'Type'}:</LABEL>";
		print "<INPUT size=\"40\" onMouseOut=\"nd()\" value=\"$usrType\" onmouseover=\"overlib('$__{help_creationstation_type}')\" size=\"8\" name=\"type\" id=\"type\">&nbsp;&nbsp;<BR>";
	print "</FIELDSET>";

	print "<FIELDSET><LEGEND>$__{'Lifetime and Events Time Zone'}</LEGEND>";
  	# --- Dates debut et fin
  	print "<TABLE>";
    	print "<TR>";
			print "<TD style=\"border:0;text-align:right\">";
    		print "<DIV class=parform>";
				print "<B>$__{'Start date'}:</b> <SELECT name=\"anneeDepart\" size=\"1\">";
				for ($usrYearC,@anneeListeC) { print "<OPTION".(($_ eq $usrYearC)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
				print " <SELECT name=\"moisDepart\" size=\"1\">";
				for (@moisListe) { print "<OPTION".(($_ eq $usrMonthC)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
				print " <SELECT name=\"jourDepart\" size=\"1\">";
				for (@jourListe) { 	print "<OPTION".(($_ eq $usrDayC)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT><BR>";
				print "<b>$__{'End date'}:</b> <SELECT name=\"anneeEnd\" size=\"1\">";
				for ($usrYearE,@anneeListeE) { print "<OPTION".(($_ eq $usrYearE)?" selected":"")." value=$_>$_</option>\n"; }
				print "<OPTION value=NA>NA</option>\n";
				print "</SELECT>";
				print " <SELECT name=\"moisEnd\" size=\"1\">";
				for (@moisListe) { print "<option".(($_ eq $usrMonthE)?" selected":"")." value=$_>$_</option>\n"; }
				print "</SELECT>";
				print " <SELECT name=\"jourEnd\" size=\"1\">";
				for (@jourListe) { print "<option".(($_ eq $usrDayE)?" selected":"")." value=$_>$_</option>\n"; }
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
	print "<INPUT type=\"Button\" value=\"$__{Add} >>\" style=\"width:100px\" onClick=\"SelectMoveRows(document.formulaire.INs,document.formulaire.SELs)\"><br>";
	print "<BR>";
	print "<INPUT type=\"Button\" value=\"<< $__{Remove}\" style=\"width:100px\" onClick=\"javascript: if (document.formulaire.SELs.options.length == 1) {alert('invalid remove: node MUST belong to at least 1 grid !');} else { SelectMoveRows(document.formulaire.SELs,document.formulaire.INs);}\">";
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
		print "<TD style=\"border:0;text-align:left\">";
			print "<label for=\"latwgs84\">$__{'Latitude'}  WGS84:</label>";
			print "<input size=\"10\" class=inputNum value=\"$usrLat\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lat}')\" id=\"latwgs84\" name=\"latwgs84\"><B>&#176;&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lat}')\" id=\"latwgs84min\" name=\"latwgs84min\"><B>'&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lat}')\" id=\"latwgs84sec\" name=\"latwgs84sec\"><B>\"&nbsp;</B>";
			print "<select name=\"latwgs84n\" size=\"1\">";
			for ("N","S") { print "<option".($usrLatN eq $_ ? " selected":"")." value=$_>$_</option>\n"; }
			print "</select><BR>\n";
			print "<label for=\"lonwgs84\">$__{'Longitude'}  WGS84:</label>";
			print "<input size=\"10\" class=inputNum value=\"$usrLon\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lon}')\" id=\"lonwgs84\" name=\"lonwgs84\"><B>&#176;&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lon}')\" id=\"lonwgs84min\" name=\"lonwgs84min\"><B>'&nbsp;</B>";
			print "<input size=\"6\" class=inputNum value=\"\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_lon}')\" id=\"lonwgs84sec\" name=\"lonwgs84sec\"><B>\"&nbsp;</B>";
			print "<select name=\"lonwgs84e\" size=\"1\">";
			for ("E","W") { print "<option".($usrLonE eq $_ ? " selected":"")." value=$_>$_</option>\n"; }
			print "</select><BR>\n";
			print "<label for=\"altitude\">$__{'Elevation'}  (m):</label>";
			print "<input size=\"10\" class=inputNum value=\"$usrAlt\" onChange=\"latlonChange()\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_alt}')\" id=\"altitude\" name=\"altitude\">";
			print "</select><BR>\n";
		print "</TD>";
		print "<TD style=\"border:0\">";
			# --- positioning date
			print "<label for=\"datePos\">Date:</label> <select name=\"anneeMesure\" size=\"1\">";
			for ($usrYearP,@anneeListeP) { print "<option".(($_ eq $usrYearP)?" selected":"")." value=$_>$_</option>\n";	}
			print "</select>";
			print " <select name=\"moisMesure\" size=\"1\">";
			for (@moisListe) { print "<option".(($_ eq $usrMonthP)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"jourMesure\" size=\"1\">";
			for (@jourListe) { print "<option".(($_ eq $usrDayP)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select><BR>";
			# --- Positioning type (GPS, Map (Carte) ou Inconnu)
			print "<label for=\"typePos\">Type: </label> <select onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_pos_type}')\" name=\"typePos\" size=\"1\">";
			for (sort(keys(%typePos))) { print  "<option".(($_ eq $usrTypePos) ? " selected ":"")." value=$_>$typePos{$_}</option>\n"; }
			print "</select>";
		print "</TD>";
	print "</TR></TABLE>";
	print "</FIELDSET>\n";

	# --- GNSS-specific information
	print "<FIELDSET><legend>$__{'GNSS-specific information'}</LEGEND>";
	print "<TABLE><TR>";
		print "<TD style=\"border:0;text-align:left\">";
			print "<label for=\"gnss_9char\">$__{'GNSS 9 char. code'} :</label>";
			print "<input size=\"10\" value=\"$usrGnss9char\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_creationstation_gnss_9char}')\" id=\"gnss_9char\" name=\"gnss_9char\">";
			print "</select><BR>\n";
			print "<label for=\"m3g_check\">$__{'M3G availability'} :</label>";
			if ( $m3g_check ) {
				print "<input type=\"checkbox\" id=\"m3g_check\" name=\"m3g_check\" value=\"NA\"  onmouseover=\"overlib('$__{help_creationstation_m3g_check}')\" checked>";
			} else {
				print "<input type=\"checkbox\" id=\"m3g_check\" name=\"m3g_check\" value=\"NA\"  onmouseover=\"overlib('$__{help_creationstation_m3g_check}')\">";
			}
			print "</select><BR>\n";
		print "</TD>";
	print "</TR></TABLE>";
	print "</FIELDSET>";

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

Francois Beauducel, Didier Mallarino, Alexis Bosson, Didier Lafon

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
