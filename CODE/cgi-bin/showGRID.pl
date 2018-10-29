#!/usr/bin/perl 

=head1 NAME

showGRID.pl 

=head1 SYNOPSIS

http://..../showGRID.pl?grid=gridtype.gridname[,nodes=][,coord=][,projet=]

=head1 DESCRIPTION

Display a GRID

=cut

use strict;
use warnings;

$|=1;
use Time::Local;
use File::Basename;
use Data::Dumper;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Image::Info qw(image_info dim);

use WebObs::Config;
use WebObs::Grids;
use WebObs::Events;
use WebObs::Users;
use WebObs::Utils;
use WebObs::Search;
use WebObs::Wiki;
use WebObs::i18n;
use WebObs::IGN;
use Locale::TextDomain('webobs');

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
set_message(\&webobs_cgi_msg);
my $htmlcontents = "";
my $editOK   = 0;
my $admOK    = 0;
my $seeInvOK = 0;
my %GRID;
my %G;
my $GRIDName  = my $GRIDType = my $RESOURCE = "";

my $QryParm   = $cgi->Vars;
my @GID = split(/[\.\/]/, trim($QryParm->{'grid'})); 
$QryParm->{'nodes'}    ||= $GRIDS{DEFAULT_NODES_FILTER};
$QryParm->{'coord'}    ||= $GRIDS{DEFAULT_COORDINATES};
$QryParm->{'projet'}   ||= $GRIDS{DEFAULT_PROJECT_FILTER};
$QryParm->{'sortby'}   ||= "event";  

if (scalar(@GID) == 2) {
	($GRIDType, $GRIDName) = @GID;
	if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
	elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
	if (%G) {
		%GRID = %{$G{$GRIDName}} ;
		if ( WebObs::Users::clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
			$RESOURCE = "auth".lc($GRIDType)."s/$GRIDName";
			if ( WebObs::Users::clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
				$editOK = 1;
			}
			if ( WebObs::Users::clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
				$admOK = 1;
			}
			if ( WebObs::Users::clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"SEEINVALIDNODES") ) {
				$seeInvOK = 1;
			}
		} else { die "You cannot display $GRIDType.$GRIDName"}
	} else { die "Couldn't get $GRIDType.$GRIDName configuration." }
} else { die "No valid GRID requested (NOT gridtype.gridname)." } 

# ---- good, passed all checkings above 
#
my $grid = "$GRIDType.$GRIDName";
my $myself = "/cgi-bin/".basename($0)."?grid=$grid";
my $GRIDNameLower = lc($GRIDName);
my $nbNodes = scalar(@{$GRID{NODESLIST}});

my $fileProjet = "";
my $afficheStations = "OK";
my $titrePage = "";
my $spanDis;
my $editCGI = "/cgi-bin/gedit.pl";

$GRID{UTM_LOCAL} ||= '';
my %UTM = %{setUTMLOCAL($GRID{UTM_LOCAL})};
my $localCS = $UTM{GEODETIC_DATUM_LOCAL_NAME};

my $showType = (defined($GRIDS{SHOW_TYPE}) && ($GRIDS{SHOW_TYPE} eq 'N') || ($GRID{TYPE} eq "")) ? 0 : 1;
my $showOwnr = (defined($GRIDS{SHOW_OWNER}) && ($GRIDS{SHOW_OWNER} eq 'N') || ($GRID{OWNCODE} eq "")) ? 0 : 1;

my $today = qx(/bin/date +\%Y-\%m-\%d);
chomp($today);

my $txt;
my $go2top = "&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";

# ---- Nodes status ---------------------
my $overallStatus = "OK";
my $statusDB = $NODES{SQL_DB_STATUS};
if ($statusDB eq "") { $statusDB = "$WEBOBS{PATH_DATA_DB}/NODESSTATUS.db" };
my @statusNODES;
if (-e $statusDB) {
	@statusNODES = qx(sqlite3 $statusDB "select * from status where NODE like '%$grid%';");
	chomp(@statusNODES);
}
if (scalar(@statusNODES) == 0) {	
	$overallStatus = "NOK";
} 

# ---- Start HTML page 
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<HTML><HEAD><title>$titrePage</title>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";
print "<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>";
print "<script language=\"JavaScript\" src=\"/js/htmlFormsUtils.js\" type=\"text/javascript\"></script>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/search.css\">";
print "</head><body>";
print "<!-- overLIB (c) Erik Bosrup -->
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\" type=\"text/javascript\"></script>";
print "<script language=\"javascript\" type=\"text/javascript\" src=\"/js/wolb.js\"></script>
<link href=\"/css/wolb.css\" rel=\"stylesheet\" />";

# ---- header (GRID name) and internal links within page
#
print "<A NAME=\"MYTOP\"></A>";
print "<H1 style=\"margin-bottom:6pt\"> $DOMAINS{$GRID{DOMAIN}}{NAME} / $GRID{NAME}".($admOK ? " <A href=\"/cgi-bin/formGRID.pl?grid=$grid\"><IMG src=\"/icons/modif.png\"></A>":"")."</H1>\n";
print WebObs::Search::searchpopup();
#if ($admOK == 1) { print "<A class=\"gridname\" href=\"/cgi-bin/formGRID.pl?grid=$grid\">{$grid}</A>"; }

my $ilinks = "[ ";
$ilinks .= "<A href=\"/cgi-bin/listGRIDS.pl?type=$GRIDType\">".ucfirst(lc($GRIDType))."s</A>";
$ilinks .= " | <A href='#MYTOP' title=\"$__{'Find text in Grid'}\" onclick='srchopenPopup(\"+$GRIDType.$GRIDName\");return false'><img class='ic' src='/icons/search.png'></A>";
$ilinks .= " | <A href=\"/cgi-bin/gvTransit.pl?grid=$GRIDType.$GRIDName\"><IMG src=\"/icons/tmap.png\" title=\"Tmap\" style=\"vertical-align:middle;border:0\"></A>";
$ilinks .= " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/$WEBOBS{CGI_GOOGLE_MAPS}?grid=$grid','$GRIDName','width="
		.($WEBOBS{GOOGLE_MAPS_WIDTH_VALUE}+15).",height="
		.($WEBOBS{GOOGLE_MAPS_HEIGHT_VALUE}+15).",toolbar=no,menubar=no,location=no')\">
		<IMG src=\"$WEBOBS{GOOGLE_MAPS_ICON}\" title=\"$WEBOBS{GOOGLE_MAPS_LINK_INFO}\" style=\"vertical-align:middle;border:0\"></A>";
if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
	$ilinks .= " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=kml')\" title=\"$WEBOBS{GOOGLE_EARTH_LINK_INFO}\"><IMG style=\"vertical-align:middle;border:0\" src=\"$WEBOBS{IMAGE_LOGO_GOOGLE_EARTH}\" alt=\"KML\"></A>\n";
}
$ilinks .= " | <A href=\"#CARACTERISTIQUES\">$__{Specifications}</A>";
$ilinks .= " | <A href=\"#CARTES\">$__{'Location'}</A>";
$ilinks .= " | <A href=\"#INFORMATIONS\">$__{'Information'}</A>";
$ilinks .= " | <A href=\"#PROJECT\">$__{'Project'}</A>";
$ilinks .= " | <A href=\"#EVENTS\">$__{'Events'}</A>";
$ilinks .= " | <A href=\"#BIBLIO\">$__{'References'}</A>";
$ilinks .= " ]";
print "<P class=\"subMenu\"> <b>&raquo;&raquo;</b> $ilinks";

# ---- Objectives
#
my @desc;
my $fileDesc = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDType.$GRIDName"."$GRIDS{DESCRIPTION_SUFFIX}";
my $legacyfileDesc = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDName"."$GRIDS{DESCRIPTION_SUFFIX}";
if (-e $legacyfileDesc) { qx(cp $legacyfileDesc $fileDesc) }
if (-e $fileDesc) { 
	@desc = readFile($fileDesc);
}
$htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#descID');\">&nbsp;&nbsp;"; 
	$htmlcontents .= "$__{'Purpose'}";
	if ($editOK == 1) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$GRIDS{DESCRIPTION_SUFFIX}\&grid=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
	$htmlcontents .= "</div><div id=\"descID\"><BR>";
	if ($#desc >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@desc))."</P>\n" }
	$htmlcontents .= "</div></div>";
print $htmlcontents;


# ---- GRID's characteristics 
#
print "<BR>";
$htmlcontents = "<A NAME=\"CARACTERISTIQUES\"></A>";
$htmlcontents .= "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#specID');\">&nbsp;&nbsp;"; 
	$htmlcontents .= "$__{'Specifications'}&nbsp;$go2top";
	$htmlcontents .= "</div><div id=\"specID\">";
		# should 'nodes' be called differently (than 'nodes'!) ? 
		my $snm = defined($GRID{NODE_NAME}) ? $GRID{NODE_NAME} : "$__{'node'}";
		$htmlcontents .= "<UL>";
		# -----------
		$htmlcontents .= "<LI>$__{'Domain'}: <A href=\"/cgi-bin/listGRIDS.pl?domain=$GRID{DOMAIN}\"><B>$DOMAINS{$GRID{DOMAIN}}{NAME}</B></A></LI>\n"; 
		# -----------
		if ($showOwnr && defined($GRID{OWNCODE})) { 
			$htmlcontents   .= "<LI>$__{'Owner'}: <B>".(defined($OWNRS{$GRID{OWNCODE}}) ? $OWNRS{$GRID{OWNCODE}}:$GRID{OWNCODE})."</B></LI>\n" 
		} 
		# -----------
		$htmlcontents .= "<LI>\"$snm\" : <B>$nbNodes</B>";
		if ($admOK) { 
			$htmlcontents .= " [ "
				."<A href=\"/cgi-bin/formGRID.pl?grid=$grid\">$__{'Associate existing node(s)'}</A> | "
				."<A href=\"/cgi-bin/$NODES{CGI_FORM}?node=$grid\">$__{'Create a new node'}</A> "
				."]";
		}
		$htmlcontents   .= "</LI>";
		if ($showType) { $htmlcontents .= "<LI>$__{'Type'}: <B>$GRID{TYPE}</B></LI>\n" }
		# -----------
		# 'old' ddb-key superseeded: use FORM (FORMS) definitions instead!  
		if (defined($GRID{'FORM'})) {
			my %FORM = readCfg("$WEBOBS{'PATH_FORMS'}/$GRID{'FORM'}/$GRID{'FORM'}.conf");
			if (%FORM) {
				my $urnData = (defined($FORM{'CGI_SHOW'})) ? "/cgi-bin/$FORM{'CGI_SHOW'}?node={$GRIDName}" : "";
				my $txtData = (defined($FORM{'TITLE'})) ? $FORM{'TITLE'} : "";
				$htmlcontents .= "<LI>Associated FORM: <B><A href=\"$urnData\">$txtData</A></B></LI>\n";
			}
		} 
		# -----------
		if (defined($GRID{URNDATA})) {
			my $urnData = "$GRID{URNDATA}";
			$htmlcontents .= "<LI>$__{'Access to data {RAWDATA}'}: <B><A href=\"$urnData\">$urnData</A></B></LI>\n";
		} 
		# -----------
		my $urn = '';
		if ( -d "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/$WEBOBS{PATH_OUTG_GRAPHS}" ) { 
			my $ext = $GRID{TIMESCALELIST};
			$urn = "/cgi-bin/showOUTG.pl?grid=PROC.$GRIDName";
			$htmlcontents .= "<LI>$__{'Graphical routine'}: <B><A href=\"$urn\">$GRIDName</A></B> ($ext)</LI>\n";
		} elsif ( -d "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/$WEBOBS{PATH_OUTG_EVENTS}" ) { 
			$urn = "/cgi-bin/showOUTG.pl?grid=PROC.$GRIDName&ts=events";
			$htmlcontents .= "<LI>$__{'Graphical routine'}: <B><A href=\"$urn\">$GRIDName</A></B> (events)</LI>\n";
		} 
		# -----------
		if (defined($GRID{URL})) {
			my $txt = $GRID{URL};
			$txt =~ s/^(.*),(.*)/ <a href=\"$2\">$1<\/a>/g;
			$htmlcontents .= "<LI>$__{'External link(s)'}: <B>$txt</B></LI>\n";
		} 
		$htmlcontents .= "</UL>\n";
	$htmlcontents .= "</div></div>";
print $htmlcontents;


# ---- Now the GRID's NODE(s) 
# ---- first, submenu line for selections (list Active nodes, All,..., Coordinates type, etc....)
#
print "<BR>";
$htmlcontents = "<A NAME=\"STATIONS\"></A>";
$htmlcontents .= "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#nodesID');\">&nbsp;&nbsp;"; 
	$htmlcontents .= "$__{'List of'} $snm(s)&nbsp;$go2top";
	$htmlcontents .= "</div><div id=\"nodesID\">";

		$htmlcontents .= "<P class=\"subTitleMenu\" style=\"margin-left: 5px\">";

		$htmlcontents .= "$__{'Nodes'} [ ";
		if ($QryParm->{'nodes'} eq "active") {
			$htmlcontents .= "<B>$__{'Active'}</B>" ;
		} else {
			$htmlcontents .= "<A href=\"$myself&amp;nodes=active&amp;coord=$QryParm->{'coord'}&amp;projet=$QryParm->{'projet'}&amp;#STATIONS\">$__{'Active'}</A>";
		}
		if ( $seeInvOK ) {
			$htmlcontents .= " | ".($QryParm->{'nodes'} eq "valid" ? "<B>$__{'Valid'}</B>":"<A href=\"$myself&amp;?coord=$QryParm->{'coord'}&amp;projet=$QryParm->{'projet'}&amp;nodes=valid#STATIONS\">$__{'Valid'}</A>");
		}
		$htmlcontents .= " | ".($QryParm->{'nodes'} eq "all" ? "<B>$__{'All'}</B>":"<A href=\"$myself&amp;coord=$QryParm->{'coord'}&amp;projet=$QryParm->{'projet'}&amp;nodes=all#STATIONS\">$__{'All'}</A>")." ] ";

		$htmlcontents .= "- $__{Coordinates} [ "
				.($QryParm->{'coord'} eq "latlon" ? "<B>Lat/Lon</B>":"<A href=\"$myself&amp;projet=$QryParm->{'projet'}&amp;nodes=$QryParm->{'nodes'}&amp;coord=latlon#STATIONS\">Lat/Lon</A>")." | "
				.($QryParm->{'coord'} eq "utm"    ? "<B>UTM</B>":"<A href=\"$myself&amp;projet=$QryParm->{'projet'}&amp;nodes=$QryParm->{'nodes'}&amp;coord=utm#STATIONS\">UTM</A>");
		if (defined($GRID{UTM_LOCAL}) && -e $GRID{UTM_LOCAL} ) {
			$htmlcontents .= " | ".($QryParm->{'coord'} eq "local" ? "<B>$localCS</B>":"<A href=\"$myself&amp;projet=$QryParm->{'projet'}&amp;nodes=$QryParm->{'nodes'}&amp;coord=local#STATIONS\">$localCS</A>");
		}
		$htmlcontents .= " | "
				.($QryParm->{'coord'} eq "xyz"    ? "<B>XYZ</B>":"<A href=\"$myself&amp;projet=$QryParm->{'projet'}&amp;nodes=$QryParm->{'nodes'}&amp;coord=xyz#STATIONS\">XYZ</A>");
		$htmlcontents .= " ] - $__{Export} [";
		$htmlcontents .= " <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=txt&amp;coord=$QryParm->{'coord'}&amp;nodes=$QryParm->{'nodes'}')\" title=\"Exports TXT file\">TXT</A> |";
		$htmlcontents .= " <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=csv&amp;coord=$QryParm->{'coord'}&amp;nodes=$QryParm->{'nodes'}')\" title=\"Exports CSV file\">CSV</A>";
		if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
			$htmlcontents .= " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=kml&amp;nodes=$QryParm->{'nodes'}')\" title=\"Exports KML file\">KML</A>";
		}
		$htmlcontents .= " ] ";
		if ( $CLIENT ne 'guest' ) {
			$htmlcontents .= "- $__{Project} [ "
					.($QryParm->{'projet'} eq "on"  ? "<B>On</B>" :"<A href=\"$myself&amp;nodes=$QryParm->{'nodes'}&amp;coord=$QryParm->{'coord'}&amp;projet=on#STATIONS\">On</A>")." | "
					.($QryParm->{'projet'} eq "off" ? "<B>Off</B>":"<A href=\"$myself&amp;nodes=$QryParm->{'nodes'}&amp;coord=$QryParm->{'coord'}&amp;projet=off#STATIONS\">Off</A>")." ] ";
		}
		$htmlcontents .= "</P>\n";

		# ---- then, the Nodes' table
		#
		my $nbValides=0;
		my $nbNonValides=0;
		my $tcolor;
		my %NODE;

		#$htmlcontents .= "<TABLE width=\"100%\" style=\"margin-left: 5px\">";
		$htmlcontents .= "<TABLE width=\"100%\">";
		$htmlcontents .= "<TR>";
			$htmlcontents .= ($editOK ? "<TH width=\"14px\"></TH>":"")."<TH>$__{'Alias'}</TH><TH>$__{'Name'}</TH>";
			if ($QryParm->{'coord'} eq "utm") {
				$htmlcontents .= "<TH>UTM Eastern (m)</TH><TH>UTM Northern (m)</TH><TH>$__{'Elev.'} (m)</TH>";
			} elsif ($QryParm->{'coord'} eq "local") {
				$htmlcontents .= "<TH>Local TM Eastern (m)</TH><TH>Local TM Northern (m)</TH><TH>$__{'Elev.'} (m)</TH>";
			} elsif ($QryParm->{'coord'} eq "xyz") {
				$htmlcontents .= "<TH>X (m)</TH><TH>Y (m)</TH><TH>Z (m)</TH>";
			} else {
				$htmlcontents .= "<TH>$__{'Lat.'} (WGS84)</TH><TH>$__{'Lon.'} (WGS84)</TH><TH>$__{'Elev.'} (m)</TH>";
			}
			$htmlcontents .= "<TH>$__{'Start / Installation'}</TH><TH>$__{'End / Stop'}</TH><TH>$__{'Type'}</TH>";
			if ($CLIENT ne 'guest') {
				$htmlcontents .= "<TH>$__{'Nb Evnt'}</TH>";
				if ($QryParm->{'projet'} eq "on") {
					$htmlcontents .= "<TH>$__{'Project'}</TH>";
				}
			}
			if ( $overallStatus eq "OK" ) { $htmlcontents .= "<TH>$__{'Last Data'} (TZ $GRID{TZ})</TH><TH onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_node_sampling}')\">$__{'Sampl.'}</TH><TH onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_node_status}')\">$__{'Status'}</TH>"; }
		$htmlcontents .= "</TR>\n";

		for (@{$GRID{NODESLIST}}) {
			my $displayNode = 1;
			my $NODEName      = $_;
			my $NODENameLower = lc($NODEName);

			my %N = readNode($NODEName);
			%NODE = %{$N{$NODEName}};

			if (%NODE) {

				# is VALID ? do we display INVALID ?
				if ($NODE{VALID} == 0) {
					$tcolor="node-disabled";
					if ($QryParm->{'nodes'} eq "valid" || !$seeInvOK) {
						$nbNonValides++;
						$displayNode = 0;
					}
				} else {
					$tcolor="node-active";
					$nbValides++;
				}

				# is NOT active if already 'ended' OR not yet 'installed' ? do we display ?
				if ($NODE{VALID} && ($NODE{END_DATE} ne "NA" && $NODE{END_DATE} lt $today) || ($NODE{INSTALL_DATE} ne "NA" && $NODE{INSTALL_DATE} gt $today)) {
					$tcolor="node-inactive";
					if ($QryParm->{'nodes'} eq "active") {
						$displayNode = 0;
					}
				}

				# trick: execute display logic even if we don't display, but html-comment out first
				$htmlcontents .= (!$displayNode ? "<!--":"");
				$htmlcontents .= "<TR class=\"$tcolor\">";
				$htmlcontents .= ($editOK ? "<TH><A href=\"/cgi-bin/formNODE.pl?node=$grid.$NODEName\"><IMG title=\"Edit node\" src=\"/icons/modif.png\"></TH>":"");
				# Node's code and name
				my $lienNode="/cgi-bin/$NODES{CGI_SHOW}?node=$grid.$NODEName";
				$htmlcontents .= "<TD align=center><SPAN class=\"code\">$NODE{ALIAS}</SPAN></TD><TD nowrap><a href=\"$lienNode\"><B>$NODE{NAME}</B></a></TD>";

				# Node's localization
				if ($NODE{LAT_WGS84}==0 && $NODE{LON_WGS84}==0 && $NODE{ALTITUDE}==0) {
					$htmlcontents .= "<TD colspan=3> </TD>";
				} else {
					my $lat = sprintf("%.5f",$NODE{LAT_WGS84});
					my $lon = sprintf("%.5f",$NODE{LON_WGS84});
					my $alt = sprintf("%.0f",$NODE{ALTITUDE});
					if ($QryParm->{'coord'} eq "utm") {
						($lat,$lon) = geo2utm($lat,$lon);
						$lat = sprintf("%.0f",$lat);
						$lon = sprintf("%.0f",$lon);
					} elsif ($QryParm->{'coord'} eq "local") {
						($lat,$lon) = geo2utml($lat,$lon);
						$lat = sprintf("%.0f",$lat);
						$lon = sprintf("%.0f",$lon);
					} elsif ($QryParm->{'coord'} eq "xyz") {
						($lat,$lon,$alt) = geo2cart($lat,$lon,$alt);
						$lat = sprintf("%.0f",$lat);
						$lon = sprintf("%.0f",$lon);
						$alt = sprintf("%.0f",$alt);
					}
					$htmlcontents .= "<TD align=\"center\" nowrap>$lat</TD><TD align=\"center\" nowrap>$lon</TD><TD align=\"center\" nowrap>$alt</TD>";
				}

				# Node's dates
				if ($NODE{INSTALL_DATE} eq "NA") {
					$htmlcontents .= "<TD> </TD>";
				} else {
					$htmlcontents .= "<TD align=\"center\" nowrap>$NODE{INSTALL_DATE}</TD>";
				}
				if ($NODE{END_DATE} eq "NA") {
					$htmlcontents .= "<TD> </TD>";
				} else {
					$htmlcontents .= "<TD align=\"center\" nowrap>$NODE{END_DATE}</TD>";
				}

				# Node's type
				$htmlcontents .= "<TD>$NODE{TYPE}</TD>";

				# #Interventions and Project file 
				if ( $CLIENT ne 'guest' ) { 
					my $textProj = "";
					my $pathInter="$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS}";
					my $nbInter  = qx(/usr/bin/find $pathInter -name "$NODEName*.txt" | wc -l);
					$htmlcontents .= "<TD align=center>$nbInter</TD>";
					if ($QryParm->{'projet'} eq "on") {
						my $fileProjName = $NODEName."_Projet.txt";
						my $fileProj = "$pathInter/$fileProjName";
						if ((-e $fileProj) && (-s $fileProj)) {
							my @proj = readFile($fileProj);
							@proj = grep(!/^$/, @proj);
							chomp(@proj);
							if ($proj[0] =~ "|") {
								my @pLigne = split(/\|/,$proj[0]);
								my @listeNoms = split(/\+/,$pLigne[0]);
								my $noms = join(", ",WebObs::Users::userName(@listeNoms));
								my $titre = $pLigne[1];
								shift(@proj);
								if ($titre ne "") {
									$textProj = "<b>$titre</b>";
								}
								if ($noms ne "") {
									$textProj = $textProj." <I>($noms)</I>";
								}
								if ($textProj ne "") {
									$textProj = $textProj."<br>";
								}
							}
							$textProj = $textProj.WebObs::Wiki::wiki2html(join("\n",@proj));
						}
						$htmlcontents .= "<TD>$textProj</TD>";
					}
				}

				# NODE's status 
				if ( $CLIENT ne 'guest' ) {
					if ($overallStatus eq "OK" ) {
						my @tmpStState = grep(/$grid\.$NODEName/,@statusNODES);
						my @stState = split(/\|/,$tmpStState[$#tmpStState]);
						if ($#stState >= 0) {
							my $bgcolEt = "";
							my $bgcolA = "";
							# $stState[1] (Node status)
							if ($stState[1] == $NODES{STATUS_STANDBY_VALUE}) { $bgcolEt = "status-standby"; $stState[1] = "$__{Standby}"; }
							elsif ($stState[1] < $NODES{STATUS_THRESHOLD_CRITICAL}) {
								$stState[1] .= " %";
								if ($GRID{"TYPE"} eq "M") { $bgcolEt = "status-manual"; } else { $bgcolEt = "status-critical"; }
							}
							elsif ($stState[1] >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolEt="status-ok"; $stState[1] .= " %"; }
							else { $bgcolEt = "status-warning"; $stState[1] .= " %"; }
							if (($stState[1] eq "%") || ($stState[1] eq ""))  { $bgcolEt = ""; $stState[1] = " " }
							# $stState[2] (Acquisition status)
							if ($stState[2]  == $NODES{STATUS_STANDBY_VALUE}) { $bgcolA = "status-standby"; $stState[2] = "$__{Standby}"; }
							elsif ($stState[2] < $NODES{STATUS_THRESHOLD_CRITICAL}) { $bgcolA = "status-critical"; $stState[2] .= " %"; }
							elsif ($stState[2] >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolA = "status-ok"; $stState[2] .= " %"; }
							else { $bgcolA = "status-warning"; $stState[2] .= " %"; }
							if (($stState[2] eq " %") || ($stState[2] eq "")) { $bgcolA = ""; $stState[2] = " " }
							# $stState[3..5] (Date, Time and TZ of last measurement)
							# Display 
							$htmlcontents .= "<TD align=\"center\" nowrap>$stState[3]</TD>\n"; # Date de l'analyse de l'etat
							if ($NODE{END_DATE} eq "NA" || $NODE{END_DATE} ge $today) {
								$htmlcontents .= "<TD  align=\"center\" class=\"$bgcolA\"><B>$stState[2]</B></TD>"
										."<TD  align=\"center\" class=\"$bgcolEt\"><B>$stState[1]</B></TD>";
							} else {
								$htmlcontents .= "<TD align=\"center\" colspan=\"2\"><I>$__{'Stopped'}</I></TD>";
							}
						} else {
							$htmlcontents .= "<TD colspan=\"3\"> </TD>";
						}
					}
				}
				$htmlcontents .= "</TR>\n".(!$displayNode ? "-->":"");
			}
		}
		$htmlcontents .= "</TABLE>";
	$htmlcontents .= "</div></div>";
print $htmlcontents;


# ---- now the grid's MAPs
# only 1 map : *.png and its corresponding *.map
my $MAPpath = my $MAPurn = "";
my @maps;
my $i = 0;
my @htmlarea;
$MAPpath = "$WEBOBS{ROOT_OUTG}/$grid/$WEBOBS{PATH_OUTG_MAPS}";
( $MAPurn  = $MAPpath ) =~ s/$WEBOBS{ROOT_SITE}/../g;
if (opendir(my $dh, $MAPpath)) {
	@maps = grep { /.*_map\d*.png/ } readdir($dh);
	closedir($dh);
}

my $mapfile = $grid."_map".$QryParm->{'map'};
if  ( -e "$MAPpath/$mapfile.png" ) {
	print "<BR>";
	print "<A NAME=\"CARTES\"></A>";
	print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#mapID');\">&nbsp;&nbsp;"; 
	print "$__{'Location'}&nbsp;$go2top";
	print "</div><div id=\"mapID\">";
	print "<P class=\"subTitleMenu\" style=\"margin-left: 5px\"> $__{Maps} [ ";
	foreach (@maps) {
		if ($i++) { print "| "; }
		my @v = split(/_map|\./,$_);
		if ("$mapfile.png" eq $_) {
			print "<B>MAP$v[2]</B> ";
		} else {
			print "<A href=\"$myself&amp;nodes=$QryParm->{'nodes'}&amp;coord=$QryParm->{'coord'}&amp;projet=$QryParm->{'projet'}&amp;map=$v[2]#CARTES\">MAP$v[2]</A> ";
		}
	}
	print " ] - Export [ <A href=\"$MAPurn/$mapfile.png\">PNG</A> | <A href=\"$MAPurn/$mapfile.eps\">EPS</A>";
	if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
		print " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=kml&amp;nodes=$QryParm->{'nodes'}')\" title=\"Exports KML file\">KML</A>";
	}
	print " ] </P>\n";
	print "<P style=\"text-align: center\"><IMG SRC=\"$MAPurn/$mapfile.png\" border=\"0\" usemap=\"#map\"></P>\n";
	if (-e "$MAPpath/$grid"."_map.map") {
		@htmlarea = readFile("$MAPpath/$mapfile.map");
		print "<map name=\"map\">@htmlarea</map>\n";
	}
	print "</div></div>\n";
}

# ----- Fichier Protocole

my $fileProtocole = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDType.$GRIDName"."$GRIDS{PROTOCOLE_SUFFIX}";
my $legacyfileProtocole = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDName"."$GRIDS{PROTOCOLE_SUFFIX}";
my @protocole = ("");
if (-e $legacyfileProtocole) { qx(cp $legacyfileProtocole $fileProtocole) }
if (-e $fileProtocole) { 
	@protocole = readFile($fileProtocole);
}
print "<BR>";
print "<A name=\"INFORMATIONS\"></A>\n";
$htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#infoID');\">&nbsp;&nbsp;"; 
	$htmlcontents .= "$__{'Information'}";
	if ($editOK == 1) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$GRIDS{PROTOCOLE_SUFFIX}\&grid=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
	$htmlcontents .= "&nbsp;$go2top</div><div id=\"infoID\"><BR>";
	if ($#protocole >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@protocole))."</P>\n" }
	$htmlcontents .= "</div></div>";
print $htmlcontents;

# ---- Project ----------------------------------------------------------------
# 
print "<BR><A name=\"PROJECT\"></A>\n";
print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#projID');\">&nbsp;&nbsp;"; 
print "$__{Project}";
if ($editOK) { print "&nbsp;&nbsp;<A href=\"/cgi-bin/vedit.pl?action=new&event=$GRIDName\_Projet.txt&object=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
print "&nbsp;$go2top</div><div id=\"projID\"><BR>";
my $htmlProj = projectShow("$GRIDType.$GRIDName", $editOK);
print $htmlProj;
print "</div></div>";
    
# ---- Events / interventions
# 
(my $myself   = $ENV{REQUEST_URI}) =~ s/&_.*$//g ; # how I got called 
$myself       =~ s/\bsortby(\=[^&]*)?(&|$)//g ;    # same but sortby= and _= removed
my $sortBy = $QryParm->{'sortby'};

print "<BR><A name=\"EVENTS\"></A>\n";
print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#eventID');\">&nbsp;&nbsp;"; 
print "$__{'Events'}";
if ($editOK) { print "&nbsp;&nbsp;<A href=\"/cgi-bin/vedit.pl?action=new&object=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
print "&nbsp;$go2top</div><div id=\"eventID\"><BR>";
print "&nbsp;$__{'Sort by'} [ ".($sortBy ne "event" ? "<A href=\"$myself&amp;sortby=event#EVENTS\">$__{'Event'}</A>":"<B>$__{'Event'}</B>")." | "
	.($sortBy ne "date" ? "<A href=\"$myself&amp;sortby=date#EVENTS\">$__{'Date'}</A>":"<B>$__{'Date'}</B>")." ]<BR>\n";
my $htmlEvents = ($sortBy =~ /event/i) ? eventsShow("events","$GRIDType.$GRIDName", $editOK) : eventsShow("date","$GRIDType.$GRIDName", $editOK);
print $htmlEvents;
print "</div></div>";

# ----- Fichier Bibliographie
#
my $fileBib = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDType.$GRIDName"."$GRIDS{BIBLIO_SUFFIX}";
my $legacyfileBib = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDName"."$GRIDS{BIBLIO_SUFFIX}";
my @bib = ("");
if (-e $legacyfileBib) { qx(cp $legacyfileBib $fileBib) }
if (-e $fileBib) { 
	@bib = readFile($fileBib);
}
print "<BR>";
print "<A name=\"BIBLIO\"></A>\n";
$htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#bibID');\">&nbsp;&nbsp;"; 
	$htmlcontents .= "$__{'References'}";
	if ($editOK == 1) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$GRIDS{BIBLIO_SUFFIX}&grid=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
	$htmlcontents .= "&nbsp;$go2top</div><div id=\"bibID\"><BR>";
	if ($#bib >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@bib))."</P>\n" }
	$htmlcontents .= "</div></div>";
print $htmlcontents;

# ---- We're done !
print "</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

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

