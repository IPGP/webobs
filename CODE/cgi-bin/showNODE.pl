#!/usr/bin/perl -w

=head1 NAME

showNODE.pl

=head1 SYNOPSIS

http://..../showNODE.pl?node=NODEID[,sortBy={event|date}]

=head1 DESCRIPTION

Displays data associated to a NODE identified by its fully qualified name (node=gridtype.gridname.nodename)

Although a NODE is an independent entity, a GRID-context (the 2 high level qualifiers of the
Although a NODE is an independent entity, a GRID-context (the 2 high level qualifiers of the
fully qualified nodename) is required
as a validation/authorization/reference information.

All known data associated to the NODE are shown, along with links for editing these data, according
to http-client authorizations for the GRID-context requested.

The GRID-context to display other related NODEs in this page are obtained via the WebObs::Grids::normNode()
function, that calls to showNode other nodes.

=head1 Query string parameters

 node=
 the fully qualified NODE name (gridtype.gridname.nodename)

 sortby=event
 view the node's events list ordered by date but also showing events/subevents relationships

 sortby=date
 view the node's events list ordered by date (subevents viewed as independent events).
 Optional, defaults to 'event'.

=cut


use strict;
use warnings;
use Time::Local;
use File::Basename;
use Image::Info qw(image_info dim);
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use POSIX qw(locale_h);
use locale;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Events;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Mapping;
use WebObs::Wiki;
use WebObs::GML;
use Locale::TextDomain('webobs');

# ---- inits ----------------------------------
set_message(\&webobs_cgi_msg);
setlocale(LC_NUMERIC, "C");
my $fileProjet="";
my $fileProjetName="";
my $fileMap="";
#OLD:my @listeFileInterventions;
my @listeDocumentsHsV=("");
my $pathVisu="";
my $editOK=0;
my $go2top = "&nbsp;&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";
my $today  = qx(date +\%Y-\%m-\%d);
chomp($today);

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
my %NODE;
my %allNodeGrids;
my %GRID;
my %FORM;
my $GRIDName  = my $GRIDType  = my $NODEName = my $RESOURCE = "";
my $QryParm   = $cgi->Vars;
my @NID = split(/[\.\/]/, trim($QryParm->{'node'}));
if (scalar(@NID) == 3) {
	($GRIDType, $GRIDName, $NODEName) = @NID;
	%allNodeGrids = WebObs::Grids::listNodeGrids(node=>$NODEName);
	if ("@{$allNodeGrids{$NODEName}}" =~ /\b$GRIDType\.$GRIDName\b/) {
		my %G;
		my %S = readNode($NODEName);
		%NODE = %{$S{$NODEName}};
		if (%NODE) {
			if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
			elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
			if (%G) {
				%GRID = %{$G{$GRIDName}} ;
				if ( clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
					$RESOURCE = "auth".lc($GRIDType)."s/$GRIDName";
					if ( clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
						$editOK = 1;
					}
					if ( clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
						$editOK = 2;
					}
				} else { die "You cannot view $NODEName in $GRIDType.$GRIDName context"}
			} else { die "$__{'Could not read'} $GRIDType.$GRIDName configuration" }
		} else { die "$__{'Could not read'} $__{'Node Configuration'}"}
	} else { die "$GRIDType.$GRIDName.$NODEName $__{'unknown'}" }
} else { die "$__{'Not a fully qualified node name (gridtype.gridname.nodename)'}" }

# ---- Looking for THEIA user flag
my $theiaAuth = isok($WEBOBS{THEIA_USER_FLAG});

my %allNodes = readNode;
my $NODENameLower = lc($NODEName);

# ---- went thru all above checks ... init node display
#
(my $myself   = $ENV{REQUEST_URI}) =~ s/&_.*$//g ; # how I got called
$myself       =~ s/\bsortby(\=[^&]*)?(&|$)//g ;    # same but sortby= and _= removed

my $cnfFile   = "$NODES{PATH_NODES}/$NODEName/$NODEName.cnf";  # where's my cnf just in case
( my $cnfUrn  = $cnfFile) =~ s/$WEBOBS{ROOT_SITE}/../g;        # and its urn after all

#OLD:$fileProjetName =  $NODEName."_Projet.txt";
#OLD:$fileProjet     = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS}/$fileProjetName";
$fileMap        = "$NODES{PATH_NODES}/$NODEName/$NODEName"."_map.png";

#OLD:@listeFileInterventions = qx(/usr/bin/find $NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS} -name "$NODEName*.txt" | grep -v Projet | sort -dr 2>/dev/null);
#OLD:chomp(@listeFileInterventions);
@listeDocumentsHsV = <{$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_DOCUMENTS},$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_SCHEMES}}/*_{Hh,Ss,vV}.*> ;   # check requirements with FB

my $cgiConf = "/cgi-bin/$NODES{CGI_FORM}?node=$GRIDType.$GRIDName.$NODEName";
my $cgiEtxt = "/cgi-bin/nedit.pl";

my $tz = "<I>(GMT".($NODE{TZ} ne "" ? " $NODE{TZ}":"").")</I>";
my %typeTele = readCfg("$NODES{FILE_TELE}");
my %typePos  = readCfg("$NODES{FILE_POS}");
my %rawFormats  = readCfg("$WEBOBS{ROOT_CODE}/etc/rawformats.conf");
my %FDSN     = WebObs::Grids::codesFDSN();

# parameters linked to a proc
my $desc = $NODE{"$GRIDType.$GRIDName.DESCRIPTION"} // $NODE{DESCRIPTION};
my $fdsn = trim($NODE{"$GRIDType.$GRIDName.FDSN_NETWORK_CODE"} // $NODE{FDSN_NETWORK_CODE});
my $fid = $NODE{"$GRIDType.$GRIDName.FID"} // $NODE{FID};
my $fids = join(" - ", map { my $v; ($v = $_) =~ s/$GRIDType\.$GRIDName\.//;
                             "$v: <SPAN class='code'>$NODE{$_}</SPAN> "; }
                            sort grep(/$GRIDType\.$GRIDName\.FID_|^FID_/, keys(%NODE)));
my $rawformat = $NODE{"$GRIDType.$GRIDName.RAWFORMAT"} // $NODE{RAWFORMAT};
my $rawdata = $NODE{"$GRIDType.$GRIDName.RAWDATA"} // $NODE{RAWDATA};
$rawdata =~ s/\$FID/$fid/g;
my $acqrate = $NODE{"$GRIDType.$GRIDName.ACQ_RATE"} // $NODE{ACQ_RATE};
my $acqdelay = $NODE{"$GRIDType.$GRIDName.LAST_DELAY"} // $NODE{LAST_DELAY};
my $chanlist = $NODE{"$GRIDType.$GRIDName.CHANNEL_LIST"} // $NODE{CHANNEL_LIST};
my @procTS = split(/,/,$GRID{TIMESCALELIST});

my $statusDB = $NODES{SQL_DB_STATUS};
if ($statusDB eq "") { $statusDB = "$WEBOBS{PATH_DATA_DB}/NODESSTATUS.db" };
my $statusNODE;
if (-e $statusDB) {
	$statusNODE = qx(sqlite3 $statusDB "select * from status where NODE like '%$QryParm->{'node'}%';");
	chomp($statusNODE);
}

$GRID{UTM_LOCAL} //= '';
my %UTM =  %WebObs::Mapping::UTM;

# ---- sort interventions by date / event stuff  -----------------------------------
#
$QryParm->{'sortby'} //= "event";
my $sortBy = $QryParm->{'sortby'};

my $nodeName = "$NODE{ALIAS}: $NODE{NAME}";
my $title = "$__{'Show node '}$nodeName";
$nodeName = "<SPAN style='text-decoration: line-through;text-decoration-thickness: 3px'>$nodeName</SPAN>" if (!isok($NODE{VALID}));

# ---- start HTML page ouput ------------------------------------------------
# ---------------------------------------------------------------------------
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print <<"FIN";
<html><head>
<title>$title</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript">
function checkRemove(file) {
	if (confirm (file + " $__{'to be deleted'}. $__{'Are you sure ?'}")) {
		\$.post("/cgi-bin/postEVENTNODE.pl", {delf: file}, function(data) {
			alert(data);
			window.location.reload();
		}
		);
   } else {
      return false;
   }
}
function askChanNb() {
	var nb = prompt(\"Please enter the number of channels\",\"3\");
	if (nb > 0) {
		document.form.nbc.value = nb;
	}
}

</script>
<meta http-equiv="content-type" content="text/html; charset=utf-8">

</head>
<body>
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/htmlFormsUtils.js" type="text/javascript"></script>
<script language="javascript" type="text/javascript" src="/js/wolb.js"></script>
<link href="/css/wolb.css" rel="stylesheet" />
FIN

# ---- Title Node Name and edition links if authorized ------------------------
#
print "<A NAME=\"MYTOP\"></A>";
print "<TABLE width=100%><TR><TD style='border:0'>\n";
print "<H1 style=\"margin-bottom:3pt\">$nodeName".($editOK ? " <A href='$cgiConf'><IMG src=\"/icons/modif.png\"></A>":"")
	.($editOK > 1 ? " <A href='$cgiConf&duplicate=1' title=\"$__{'Duplicate this node'}\"><IMG src=\"/icons/duplicate.png\"></A>":"")
	."</H1>\n";
print "<P class=\"subMenu\"> <B>&raquo;&raquo;</B> [";
if (uc($GRIDType) eq 'VIEW' || uc($GRIDType) eq 'PROC') {
	print " <A href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRIDS}?domain=$GRID{DOMAIN}&type=all\">$DOMAINS{$GRID{DOMAIN}}{NAME}</A> / "
		."<A href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=$GRIDType.$GRIDName\">$GRID{NAME}</A> |";
}
print " <A href=\"#PROJECT\">$__{Project}</A> | <A href=\"#EVENTS\">$__{Events}</A> "
	."| <IMG src='/icons/refresh.png' style='vertical-align:middle' title='Refresh' onClick='document.location.reload(false)'> ]</P>";

print "</TD><TD width='82px' style='border:0;text-align:right'>".qrcode($WEBOBS{QRCODE_SIZE})."</TD></TR></TABLE>\n";

my %CLBS = readCfg("$WEBOBS{ROOT_CODE}/etc/clb.conf");

print "<FORM name=form id=\"theform\" action=\"/cgi-bin/$CLBS{CGI_FORM}\">"
	."<INPUT type=\"hidden\" name=\"nbc\" value=\"3\">"
	."<INPUT type=\"hidden\" name=\"node\" value=\"$GRIDType.$GRIDName.$NODEName\">";

# ---- start of node table ----------------------------------------------------
#
print "<TABLE style=\"background: white;\">";

# ---- Row "Grids" ------------------------------------------------------------
#
print "<TR><TH valign=\"top\" width=\"10%\">Grids</TH>";
print "<TD colspan=\"2\"><B>$QryParm->{'node'}</B>";
for (@{$allNodeGrids{$NODEName}}) {
	my $fullnode = "$_.$NODEName";
	print "<BR><A href=\"/cgi-bin/$NODES{CGI_SHOW}?node=$fullnode\"><B>$fullnode</B></A>" if ($fullnode ne $QryParm->{'node'});
}
print "</TD></TR>\n";


# Row "type" ------------------------------------------------------------------
#
print "<TR><TH valign=\"top\">";
if ($editOK) {
	print "<A href=\"$cgiConf\">Type</A>";
} else {
	print "Type";
}
print "</TH><TD colspan=\"2\">$NODE{TYPE}</TD></TR>\n";

# Row "GNSS 9-code" ----------------------------------------------------
#
if ($NODE{GNSS_9CHAR}) {
	print "<TR><TH valign=\"top\">";
	if ($editOK) {
		print "<A href=\"$cgiConf\">GNSS 9-code</A>";
	} else {
		print "GNSS 9-code";
	}
	print "</TH><TD colspan=\"2\">$NODE{GNSS_9CHAR}</TD></TR>\n";
}

# Row "Lifetime" ----------------------------------------------------
#
my $installDate = $NODE{INSTALL_DATE};
my $endDate = $NODE{END_DATE};
my $txt = "$__{'Lifetime'}";
print "<TR><TH valign=\"top\">".($editOK ? "<a href=\"$cgiConf\">$txt</a>":$txt)."</TH>";
print "<TD colspan=\"2\">"
	."$__{'Started on'}: ".($installDate ne "NA" ? "<B>$installDate</B>":"?")
	." / ".($endDate ne "NA" ? "$__{'Ended on'}: <B>$endDate</B>":"Active")
	."</TD></TR>\n";

# Row "coordinates" and localization map --------------------------------------
#
if (!($NODE{LAT_WGS84}=="" && $NODE{LON_WGS84}=="" && $NODE{ALTITUDE}=="")) {
	my $lat = $NODE{LAT_WGS84};
	my $lon = $NODE{LON_WGS84};
	my $alt = $NODE{ALTITUDE};
	my ($e_utm,$n_utm,$utmzone) = geo2utm($lat,$lon);
	my $e_utml;
	my $n_utml;
	my $utml0;
	my $utml1;
	my $utml2;
	if (defined($GRID{UTM_LOCAL}) && -e $GRID{UTM_LOCAL} ) {
		($e_utml,$n_utml) = geo2utml($lat,$lon,$alt);
		$utml0 = "<BR>$UTM{GEODETIC_DATUM_LOCAL_NAME}:";
		$utml1 = sprintf("<BR>%6.0f",$e_utml);
		$utml2 = sprintf("<BR>%6.0f",$n_utml);
	}
	my $txt = $__{'Location'};

	# ---- link to OpenStreetMap
	# ------------------------
	my $map = "<A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/$WEBOBS{CGI_OSM}?grid=$GRIDType.$GRIDName.$NODEName','$NODEName',"
		."'width=".($WEBOBS{OSM_WIDTH_VALUE}+15).",height=".($WEBOBS{OSM_HEIGHT_VALUE}+50).",toolbar=no,menubar=no,location=no')\">"
		."<IMG src=\"$WEBOBS{OSM_NODE_ICON}\" title=\"$WEBOBS{OSM_INFO}\" style=\"vertical-align:middle;border:0\"></A>";

	# --- link KML Google Earth
	# -------------------------
	if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
		$map .= " <A href=\"#\" onClick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$GRIDType.$GRIDName.$NODEName&format=kml')\" title=\"$WEBOBS{GOOGLE_EARTH_LINK_INFO}\"><IMG style=\"vertical-align:middle;border:0\" src=\"$WEBOBS{IMAGE_LOGO_GOOGLE_EARTH}\" alt=\"KML\"></A>\n";
	}

	# ---- link to interactive map - IGN (A. Bosson)
	# ----------------------------------------------
	if ($WEBOBS{IGN_MAPI_LINK} eq 1) {
		$map .= " <A href=\"$WEBOBS{IGN_MAPI_LINK_URL}form?lon=$e_utm&lat=$n_utm\" title=\"".l2u($WEBOBS{IGN_MAPI_LINK_INFO})."\" target=\"_blank\"><IMG style=\"vertical-align:middle;border:0\" src=\"$WEBOBS{IMAGE_LOGO_IGN_MAPI}\" alt=\"".l2u($WEBOBS{IGN_MAPI_LINK_INFO})."\"></A>\n";
	}

	print "<TR><TH valign=\"top\">".($editOK ? "<A href=\"$cgiConf\">$txt</A>":$txt)."</TH>";
	print "<TD colspan=\"2\">";
	print "<TABLE width=\"100%\"><TR>"
		."<TH><SMALL>$__{'Date'}</SMALL></TH><TH><SMALL>$__{'Type'}</SMALL></TH>"
		."<TH><SMALL>$__{'Lat.'} ".($lat >= 0 ? "N":"S")." (WGS84)</SMALL></TH>"
		."<TH><SMALL>$__{'Lon.'} ".($lon >= 0 ? "E":"W")." (WGS84)</SMALL></TH>";
	my $alat = abs($lat);
	my $alon = abs($lon);
	print "<TH><SMALL>$__{'Alt.'} (m)</TH><TH align=right><SMALL>Transverse Mercator</SMALL></TH><TH><SMALL>$__{'East'} (m)</SMALL></TH><TH><SMALL>$__{'North'} (m)</SMALL></TH><TH></TH></TR>\n<TR>"
		."<TD align=center><SMALL>$NODE{POS_DATE}</SMALL></TD><TD align=center><SMALL>".u2l($typePos{$NODE{POS_TYPE}})."</SMALL></TD>"
		.sprintf("<TD><SMALL> <B>%9.6f &deg;<BR> %02d &deg; %07.4f '<BR> %02d &deg; %02d ' %05.2f \"</B></TD>",$alat,int($alat),($alat-int($alat))*60,$alat,($alat-int($alat))*60,($alat*60-int($alat*60))*60)
		.sprintf("<TD><SMALL> <B>%9.6f &deg;<BR> %02d &deg; %07.4f '<BR> %02d &deg; %02d ' %05.2f \"</B></TD>",$alon,int($alon),($alon-int($alon))*60,$alon,($alon-int($alon))*60,($alon*60-int($alon*60))*60)
		."<TD align=center><SMALL><B>$NODE{ALTITUDE}</B></TD>"
		."<TD align=right><SMALL>UTM$utmzone WGS84:$utml0</TD>"
		.sprintf("<TD align=center><SMALL><B>%6.0f$utml1</B></TD><TD align=center><SMALL><B>%6.0f$utml2</B></TD>",$e_utm,$n_utm)
		."<TD>$map</TD></TR></TABLE>\n";
	print "<BR><TABLE width='100%'><TR>";
	if (-e $fileMap) {
		my $tmp = basename($fileMap);
		print "<TD style=\"border:0\"><img src=\"$WEBOBS{URN_NODES}/$NODEName/$tmp\" alt=\"$__{'Location map'}\"></TD>";
	}
	# ---- Neighbour nodes
	# ----------------------------------------------
	if ($NODES{NEIGHBOUR_NODES_MAX} > 0) {
		# loads all existing nodes
		my %dist;
		my %deniv;
		my %bear;
		my %proj;
		for (keys(%allNodes)) {
			my %N = %{$allNodes{$_}};
			if (isok($N{VALID}) && (!isok($NODES{NEIGHBOUR_NODES_ACTIVE_ONLY}) || (($N{END_DATE} ge $today || $N{END_DATE} eq "NA")
				&& ($N{INSTALL_DATE} le $today || $N{INSTALL_DATE} eq "NA")))) {
				($dist{$_},$bear{$_}) = greatcircle($lat,$lon,$N{LAT_WGS84},$N{LON_WGS84});
				if ($alt != 0 && $N{ALTITUDE} != 0) {
					$deniv{$_} = $N{ALTITUDE} - $alt;
					$dist{$_} = sqrt($dist{$_}**2 + ($deniv{$_}/1000)**2);
				}
				$proj{$_} = $N{PROJECT};
			}
		}
		print "<TD valign=top style='border:0'><TABLE style='border-collapse:collapse'><TR>"
			."<TH width=10%><SMALL>$__{'Distance (beeline)'}</SMALL></TH><TH width=10%><SMALL>$__{'Elev. gain'}</SMALL></TH>"
			."<TH><SMALL>$__{'Neighbour nodes'}</SMALL></TH></TR>\n";
		my $n = 1;
		foreach (sort { $dist{$a} <=> $dist{$b} or $a cmp $b } keys %dist) {
			if ($_ ne $NODEName) {
				my $d = ($dist{$_}<1 ? sprintf("%8.0f&nbsp;m",1000*$dist{$_}):sprintf("%7.3f&nbsp;km",$dist{$_}));
				my $p = ($proj{$_} ? "&nbsp;<IMG src='/icons/attention.gif' border='0' title=\"$__{'This node has a project'}\">":"");
				print "<TR><TD align=right style='border:none'><SMALL>$d<IMG src=\"/icons/boussole/".lc(compass($bear{$_})).".png\" align=\"top\"></SMALL></TD>"
					."<TD align=right style='border:none'><SMALL>".sprintf("%+1.0f&nbsp;m&nbsp;",$deniv{$_})."</SMALL></TD>"
					."<TD style='border:none'><SMALL>".getNodeString(node=>$_, link=>'node')."$p</SMALL></TD></TR>\n";
				last if ($n++ == $NODES{NEIGHBOUR_NODES_MAX});
			}
		}
		print "</TABLE></TD>\n";
	}
	print "</TR></TABLE>\n</TD></TR>\n";
}


# Row "transmission" type and link to relay / data acquisition
#
if ($NODE{TRANSMISSION} ne "NA" && $NODE{TRANSMISSION} ne "") {
	my @trans = split(/ |,|\|/,$NODE{TRANSMISSION});
	chomp(@trans);
	my $txt = $__{'Transmission'};
	print "<TR><TH valign=\"top\">".($editOK ? "<A href=\"$cgiConf\">$txt</A>":$txt)."</TH>";
	my ($utype,$ujunk) = split(/\|/,$typeTele{$trans[0]}{name});
	print "<TD colspan=\"2\"><TABLE style='border-spacing:0;border:none'><TR><TD colspan=3 style='border:none'>Type: <B>".u2l($utype)."</B></TD></TR>";
	for (@trans[1 .. $#trans]) {
		my $distelev = "<TD colspan=2 style='border:none'>&ensp;</TD>";
		my $nodelink = "<B>$_</B> ($__{'unknown'})";
		if (exists $allNodes{$_}) {
			my %N = %{$allNodes{$_}};
			if (!($N{LAT_WGS84}=="" && $N{LON_WGS84}=="")) {
				my ($dist,$bear) = greatcircle($NODE{LAT_WGS84},$NODE{LON_WGS84},$N{LAT_WGS84},$N{LON_WGS84});
				my $deniv = "";
				if ($NODE{ALTITUDE} != 0 && $N{ALTITUDE} != 0) {
					$deniv = $N{ALTITUDE} - $NODE{ALTITUDE};
					$dist = sqrt($dist**2 + ($deniv/1000)**2);
				}
				my $d = ($dist<1 ? sprintf("%8.0f&nbsp;m",1000*$dist):sprintf("%7.3f&nbsp;km",$dist));
				$distelev = "<TD align=right style='border:none'><SMALL>&ensp;$d<IMG src=\"/icons/boussole/".lc(compass($bear)).".png\" align=\"top\"></SMALL></TD>"
					."<TD align=right style='border:none'><SMALL>(<I>&Delta;h</I>&nbsp;".sprintf("%+1.0f&nbsp;m",$deniv).")&nbsp;</SMALL></TD>";
			}
			$nodelink = getNodeString(node=>$_,link=>'node').($N{PROJECT} ? "&nbsp;<IMG src='/icons/attention.gif' border='0'>":"");
		}
		print "<TR>$distelev<TD style='border:none'><SMALL>$nodelink</SMALL></TD></TR>\n";
	}
	print "</TABLE></TD>\n";
	print "</TD></TR>\n";
}


# Row "proc": codes, status, data... -----------------
#
if (uc($GRIDType) eq 'PROC') {
	print "<TR><TH valign=\"top\" rowspan=5>";
	if ($editOK) { print "<A href=\"$cgiConf\">Proc</A>" }
	else { print "Proc" }
	printf "</TH><TD valign=\"top\" width=\"10%\"><B>";

	# --- parameters
	my $txt = "$__{'Parameters'}";
	if ($editOK > 1)    { print "<A href=\"$cgiEtxt?file=$NODEName.cnf&node=$GRIDType.$GRIDName.$NODEName&encode=iso\">$txt</A>" }
	elsif ($editOK) { print "<A href=\"$cnfUrn\">$txt</A>" }
	else { print "$txt" }
	print "</B></TD><TD>";
	#print "ID: <B>$NODEName</B>";
	print "FID: ".($fid ne "" ? "<SPAN class='code'>$fid</SPAN>":"<I>$__{undefined}</I>")."\n";
	print "<BR>Network: <B>$fdsn</B> ($FDSN{$fdsn})\n" if ($fdsn ne "");
	print "<BR>$fids" if ($fids ne "");
	print "<BR>Raw Format: $rawFormats{$rawformat}{supfmt} / <B>$rawformat</B> ($rawFormats{$rawformat}{name})" if ($rawformat ne "");
	print "<BR>Raw Data Source: <SPAN class='code'>$rawdata</SPAN>" if ($rawdata ne "");
	print "</TD></TR>\n";
	
	# --- description
	print "<TD valign=\"top\" width=\"10%\"><B>$__{'Description'}</B></TD><TD>$desc</TD></TR>\n";

	# --- status
	print "<TR><TD valign=\"top\" width=\"10%\"><B>$__{'Status'}</B></TD><TD style=\"text-align:left\">"
		."<TABLE><TR><TD style=\"border:0;text-align:left\">";
	print "Acquisition Period: ".($acqrate ne "" ? "<B>$acqrate</B> days":"not set")."</B><BR>";
	print "Acquisition Delay: ".($acqdelay ne "" ? "<B>$acqdelay</B> days":"not set")."</B><BR>";
	if ($statusNODE ne "") {
		my @status = split(/\|/,$statusNODE);
		my $bgcolEt = "";
		my $bgcolA = "";
		if ($status[1] == $NODES{STATUS_STANDBY_VALUE}) { $bgcolEt = "status-standby"; $status[1] = "Standby"; } # grey/gray
		elsif ($status[1] < $NODES{STATUS_THRESHOLD_CRITICAL}) { $bgcolEt = "status-critical"; $status[1] .= "%"; }
		elsif ($status[1] >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolEt = "status-ok"; $status[1] .= "%"; }
		else { $bgcolEt="status-warning";  $status[1] .= "%"; }
		if ($status[2]  == $NODES{STATUS_STANDBY_VALUE}) { $bgcolA = "status-standby"; $status[2] = "Standby"; }
		elsif ($status[2] < $NODES{STATUS_THRESHOLD_CRITICAL}) { $bgcolA = "status-critical"; $status[2] .= "%"; }
		elsif ($status[2] >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolA = "status-ok"; $status[2] .= "%"; }
		else { $bgcolA="status-warning";  $status[2] .= "%"; }
		print "<TD style=\"border:0;padding-left:20px\">$__{'Last status check on'} <B>$status[4]</B></TD>"; # Date  de l'analyse de l'etat
		if ($endDate eq "NA") {
			print "<TD style=\"text-align:center\" class=\"$bgcolA\" width=\"10%\">$__{'Sampl.'}: <B>$status[2]</B></TD>";
			print "<TD style=\"text-align:center\" class=\"$bgcolEt\" width=\"10%\">$__{'Status'}: <B>$status[1]</B></TD>";
		}
	}
	print "</TD></TR></TABLE></TR>\n";

	# data (data & graphs from proc)
	my $OUTG = "";
	if (-d "$WEBOBS{ROOT_OUTG}/PROC.$GRIDName" ) {
		$OUTG = "$WEBOBS{ROOT_OUTG}/PROC.$GRIDName";
	}
	my (@glist) = map { "$OUTG/$WEBOBS{PATH_OUTG_GRAPHS}/$NODENameLower\_$_.png" } @procTS;
	my (@dlist) = map { "$OUTG/$WEBOBS{PATH_OUTG_EXPORT}/$NODENameLower\_$_.txt" } @procTS;

	print "<TR><TD valign=\"top\"><B>$__{'Data'}</B></TH><TD>";
	if ($OUTG ne "" && isok($NODE{VALID}) && ($GRID{'URLDATA'} ne "" || $GRID{'FORM'} ne "" || $#glist >= 0 || $#dlist >= 0)) {
		print "<TABLE><TR><TD style=\"border:0\">";
		if ($GRID{'FORM'} ne "") {
			%FORM = readCfg("$WEBOBS{PATH_FORMS}/$GRID{'FORM'}/$GRID{'FORM'}.conf");
			my $txt = $FORM{TITLE} // "$__{'Data bank'}";
			my $url = "/cgi-bin/$FORM{CGI_SHOW}";
			print "$__{'Form'}: <A href=\"$url?form=$GRID{'FORM'}&site=$NODEName\"><B>$txt</B></A><BR>";
		}
		if ($GRID{'URLDATA'} ne "") {
			my $rep = "$GRID{'RAWDATA'}";
			print "$__{'Raw data'}: <A href=\"$rep\"><B>$rep</B></A><BR>";
			if ($#dlist >= 0) {
				print "$__{'ASCII data file(s)'}";
				for (@dlist) {
					my $z = basename $_;
					print "<A href='$rep/$z' type='text/css'><B>$z</B></A> "; # ??? type#
				}
				print "<BR>";
			}
		}
	 	if ($#glist >= 0) {
			print "$__{'Outputs'}: <A href=\"/cgi-bin/showOUTG.pl?grid=PROC.$GRIDName\"><B>$GRIDName</B></A><BR>";
		}
		print "</TD>\n";
	 	print "<TD style=\"border:0;padding-left:20px\">";
		for (@glist) {
			my $tmp = basename $_;
			chomp($tmp);
			my ($name,$ext) = split(/\./,$tmp);
			my ($node,$time) = split(/_/,$name);
			my $vignette = "PROC.$GRIDName/$WEBOBS{PATH_OUTG_GRAPHS}/$name.jpg";
			if (-e "$WEBOBS{ROOT_OUTG}/$vignette") {
				$vignette = "$WEBOBS{URN_OUTG}/$vignette";
				my $tmp2 = "/cgi-bin/showOUTG.pl?grid=PROC.$GRIDName&ts=$time&g=$node";
				my $message = "<b>$__{'Click to enlarge'}</B><br>";
				$message = $message."Image=$tmp<br>";
				print "<a href=\"$tmp2\"><img src=\"$vignette\" onMouseOut=\"nd()\" onmouseover=\"overlib('$message')\" alt=\"$vignette\"></a>";
			}
		}
	 	print "</TD></TR></TABLE>\n";
	}
	print "</TD></TR>\n";

	# channels (calibration file)
	my %carCLB = readCLB("$GRIDType.$GRIDName.$NODEName");
	print "<TR><TD valign=\"top\" width=\"10%\"><B>";
	my $txt = $__{'Channels'};
	if ($editOK) {
		if (scalar(keys %carCLB) >= 0) {
			print "<A href=\"/cgi-bin/$CLBS{CGI_FORM}?node=$GRIDType.$GRIDName.$NODEName\">$txt</A>";
		} else {
			print "<A href=\"#\" onclick=\"askChanNb();\$(this).closest('form').submit();\"><B>$txt</B></A>";
		}
	} else {
		print "$txt";
	}
	print "</B></TD><TD>";
	if (scalar(keys %carCLB) >= 0) {
		my @clbNote  = wiki2html(join("",readFile($CLBS{NOTES})));
		my %fieldCLB = readCfg($CLBS{FIELDS_FILE}, "sorted");
		unless ( isok($theiaAuth) ) { delete($fieldCLB{"THEIA_CATEGORY"}); }
		my @params;
		foreach my $k (sort { $fieldCLB{$a}{'_SO_'} <=> $fieldCLB{$b}{'_SO_'} } keys %fieldCLB) { push(@params, $k); }

		print "<TABLE><TR>";
		foreach my $k ( @params ) {
			print "<TH><SMALL>",$fieldCLB{$k}{"Name"}."</SMALL></TH>";
		}
		print "</TR>\n";
		my @select = split(/,/,$chanlist);
		my $dateCLB = "";
		my $sepCLB;
		foreach my $k (sort keys %carCLB) {
			my @chpCLB;
			foreach my $p ( @params ) { push(@chpCLB, $carCLB{$k}{$p}) }
			if ($#chpCLB < $#params) {
				push(@chpCLB, ("") x ($#params - $#chpCLB));
			}
			pop(@chpCLB) if ( !$theiaAuth && $#chpCLB > $#params );
			if ($dateCLB ne "" && $dateCLB ne $chpCLB[0]) {
				$sepCLB = "<TR><TH colspan=\"".(@params)."\"></TH></TR>\n";
				print $sepCLB;
			}
			$dateCLB = $chpCLB[0];
			my $active = "style=\"".($chpCLB[2] ~~ @select || $chanlist == "" ? "font-weight:bold":"color:gray")."\"";
			print "<TR><TD $active><SMALL>".join("</SMALL></TD><TD $active><SMALL>",@chpCLB)."</SMALL></TD></TR>";
		}
		print "$sepCLB</TABLE>\n";
		print "<BR><SMALL>@clbNote</SMALL>";
	} else {
		print "no channel defined";
	}
	print "</TD></TR>\n";
}


# Row "installation"
#
my $RinfoInstallFile = "installation.txt";
my $infoInstallFile = "$NODES{PATH_NODES}/$NODEName/$RinfoInstallFile";
my @infosInstallNode = ("");
if ((-e $infoInstallFile) && (-s $infoInstallFile != 0)) {
	@infosInstallNode = grep(!/^$/,readFile($infoInstallFile));
}
if ($editOK || $#infosInstallNode >=0) {
	print "<TR><TH valign=\"top\">";
	my $txt = $__{'Installation'};
	print ($editOK ? "<a href=\"$cgiEtxt?file=$RinfoInstallFile&node=$GRIDType.$GRIDName.$NODEName\">$txt</a>":$txt);
	print "</TH><TD colspan=\"2\">".wiki2html(join("",@infosInstallNode))."</TD></TR>\n";
}

# Row "M3G"
#
if ( $NODE{GNSS_9CHAR} && $NODE{M3G_AVAIABLE} ) {
	print "<TR><TH valign=\"top\">";
	my $txt = $__{'M3G GNSS Metadata'};
	my $gnss9char = $NODE{GNSS_9CHAR};
	my $gmlfile = "$NODES{PATH_NODES}/$NODEName/$gnss9char.xml";
	my $m3g_url_sitelog = $WEBOBS{'M3G_EXPORTLOG'}.$gnss9char;
	my $m3g_url_gml = $WEBOBS{'M3G_EXPORTXML'}.$gnss9char;
	my @rec;
	my $txt_rec = "<TR><TH>Receiver history feature</TH></TR><TR><TD>";
	my @ant;
	my $txt_ant = "<TR><TH>Antenna history feature</TH></TR><TR><TD>";
	
	my $m3g_link_sitelog = "<a href=".$m3g_url_sitelog.">Download $gnss9char sitelog on your local disk</a>";
	my $m3g_link_gml = "<a href=".$m3g_url_gml.">Download $gnss9char GeodesyML on your local disk</a>";

	if (-e $gmlfile) {
		@rec = gml2mmdtable($gmlfile,"gnssrec");
		chomp(@rec);
		$txt_rec = join("\n",@rec);
		@ant  = gml2mmdtable($gmlfile,"gnssant");
		chomp(@ant);
		$txt_ant = join("\n",@ant);
	}
	
	#### get geodesyML from M3G
	my $GetGml = "/cgi-bin/get_gml_m3g.pl";
	my $m3g_xml = "<a href=\"$GetGml?node=$GRIDType.$GRIDName.$NODEName\">Import GNSS metadata from M3G</a>";

	if ($editOK) {
		print "<A href=\"$cgiConf\">$txt</A>";
	} else {
		print "M3G GNSS Metadata</TH>";
	}	#print "</TH><TD colspan=\"2\">".join("<br>",$m3g_link_sitelog,$m3g_link_gml,$m3g_xml,$txt_rec,$txt_ant)."</TD></TR>\n";
	print "</TH><TD>".join("<br>",$m3g_link_sitelog,$m3g_link_gml,$m3g_xml)."<BR>\n";
	print "<TABLE><TR><TH>Receiver history feature</TH><TH>Antenna history feature</TH></TR><TR><TD>".wiki2html($txt_rec)."</TD><TD>".wiki2html($txt_ant)."</TD></TR></TABLE></TD>";
}



# Row "infos"
#
my $RinfoFile = "info.txt";
my $infoFile = "$NODES{PATH_NODES}/$NODEName/$RinfoFile";
my @txt = ("");
if ((-e $infoFile) && (-s $infoFile != 0)) {
	@txt = readFile("$infoFile");
}
if ($editOK) {
	print "<TR><TH valign=\"top\"><a href=\"$cgiEtxt?file=$RinfoFile&node=$GRIDType.$GRIDName.$NODEName\">$__{Information}</a></TH><TD colspan=\"2\">".wiki2html(join("",@txt))."</TD></TR>\n";
} elsif ($#txt >= 0) {
	print "<TR><TH valign=\"top\">$__{Information}</TH><TD colspan=\"2\">".wiki2html(join("",@txt))."</TD></TR>\n";
}

# Row "access"
#
my $RaccessFile="acces.txt";
my $accessFile="$NODES{PATH_NODES}/$NODEName/$RaccessFile";
@txt = ("");
if ((-e $accessFile) && (-s $accessFile != 0)) {
	@txt = readFile("$accessFile");
}
if ($editOK) {
	print "<TR><TH valign=\"top\"><a href=\"$cgiEtxt?file=$RaccessFile&node=$GRIDType.$GRIDName.$NODEName\">$__{Access}</a></TH><TD colspan=\"2\">".wiki2html(join("",@txt))."</TD></TR>\n";
} elsif ($#txt >= 0) {
	print "<TR><TH valign=\"top\">$__{Access}</TH><TD colspan=\"2\">".wiki2html(join("",@txt))."</TD></TR>\n";
}


# Rows "Features"
#
my @listeFinaleCarFiles=("");
my %lienNode;
my $lien_car;

# 1) create the 'final' list of features to be shown
# first insert 'parent' features from $NODES{FILE_NODES2NODES} for NODEName
my $pseudoFileName = "";
for my $key_link (keys %node2node) {
 	my @children_node_list = split(/\|/,$node2node{$key_link});
 	for (@children_node_list) {
 		if ( $_ eq $NODEName ) {
 			my @data = split(/\|/,$key_link);
 			my $parent_node = $data[0];
 			my $feature = $data[1];
			$pseudoFileName = "ISOF:$feature";
			$lienNode{$pseudoFileName} .= (exists($lienNode{$pseudoFileName}) ? "<br>":"").getNodeString(node=>$parent_node, link=>'node');
 		}
	}
}
push(@listeFinaleCarFiles,keys(%lienNode)) ;

# now add features defined in the $NODEName cnf file
my @listeCarFiles=split(/\||,/,$NODE{FILES_FEATURES});
for (@listeCarFiles) {
	my $carFileName = $_;
	my $carFile = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_FEATURES}/$carFileName.txt";
	my $key_link = $NODEName."|".$carFileName;
	$lienNode{$carFileName} = "";
	$lien_car = 0;
	if ( exists($node2node{$key_link}) ) {
		my @liste_liens=split(/\|/,$node2node{$key_link});
		for (@liste_liens) {
			if ( length($_) > 0 ) {
				$lienNode{$carFileName} .= ($lienNode{$carFileName} eq "" ? "" : "<br>").getNodeString(node=>$_, style=>'html', link=>'features')."</a>";
			}
		}
		if ( $lienNode{$carFileName} ne "" ) {
			$lienNode{$carFileName} .= "<br><br>";
		}
		$lien_car = 1;
	}
	#FB-was: if ((-e $carFile && (-s $carFile || $editOK)) || $lien_car == 1) {
	if ((-e $carFile || $editOK) || $lien_car == 1) {
		push(@listeFinaleCarFiles,$carFileName);
	}
}

# 2) build output from 'final' list of features
my $lignes=$#listeFinaleCarFiles;
my @carNode;
my $carFile;
if ($lignes > 0) {
	print "<TR><TH valign=\"top\" rowspan=\"$lignes\">";
	if ($editOK) {
		print "<A href=\"$cgiConf\">$__{Features}</A>";
	} else {
		print "$__{Features}";
	}
	print "</TH>";
	@listeFinaleCarFiles = grep(!/^$/, @listeFinaleCarFiles);
	for (@listeFinaleCarFiles) {
		my $carFileName = $_;
		if ( /^ISOF:/ ) {
			@carNode = $lienNode{$_};
			s/^ISOF://g;
			$carFileName = $_." of";
		} else {
			$carFile = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_FEATURES}/$carFileName.txt";
			@carNode = readFile($carFile);
			if ( "@carNode" eq "") {
				@carNode = ("&nbsp;");
			}
			@carNode = (wiki2html(join("",@carNode)));
		}
		print "<TR>" if ($_ ne $listeFinaleCarFiles[0]);
		if ($editOK && !($carFileName =~ / of$/)) {
			print "<TD valign=\"top\" width=\"10%\"><a href=\"$cgiEtxt?file=$NODES{SPATH_FEATURES}/$carFileName.txt&node=$GRIDType.$GRIDName.$NODEName\"><B>$carFileName</B></a></TD>\n";
		} else {
			print "<TD valign=\"top\" width=\"10%\"><B>$carFileName</B></TD>\n";
		}
		my $lien = (exists($lienNode{$carFileName}) ? $lienNode{$carFileName}:"");
		print "<TD>$lien@carNode</TD></TR>\n";
	}
}

# ---- PHOTOS,SCHEMAS,DOCUMENTS common stuff
#
my $Fpath = my $Furn = my $Tpath = my $Turn = "";
my $Fn = my $FInfo = my $TFn = "";
my $Fts = my $Fwh = "";
my $olmsg = "";

# Row "PHOTOS" ----------------------------------------------------------------
#
$Fpath   = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_PHOTOS}";
#FB-was: ( $Furn  = $Fpath) =~ s/$WEBOBS{ROOT_SITE}/../g;
( $Furn  = $Fpath) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
$Tpath   = "$Fpath/$NODES{SPATH_THUMBNAILS}";
qx(mkdir -p $Tpath) if (!-d $Tpath);

my @listePhotos   = <$Fpath/*.{jpg,jpeg,JPG,JPEG,HEIC}*> ;
#DL-was:my $uploadPHOTOS  = "$WEBOBS{CGI_UPLOAD}?node=$GRIDType.$GRIDName.$NODEName&doc=$NODES{SPATH_PHOTOS}";
my $uploadPHOTOS  = "$WEBOBS{CGI_UPLOAD}?object=$GRIDType.$GRIDName.$NODEName&doc=SPATH_PHOTOS";
if ($editOK) {
	print "<TR><TH valign=\"top\"><A NAME=\"MYPHOTOS\"></A><a href=\"$uploadPHOTOS\">$__{Photos}</a></TH><TD colspan=\"2\">";
} elsif ($#listePhotos >= 0) {
	print "<TR><TH valign=\"top\">$__{Photos}</TH><TD colspan=\"2\">";
}
chomp(@listePhotos);
if ($#listePhotos >= 0) {
	for (@listePhotos) {
		$Fn    = basename($_);
		$TFn = makeThumbnail($_, "x$NODES{THUMBNAILS_PIXV}", $Tpath, $NODES{THUMBNAILS_EXT});
		($Fts,$Fwh) = split(/\|/,getImageInfo($_));
		#FB-was: ( $Turn  = $TFn) =~ s/$WEBOBS{ROOT_SITE}/../g;
		( $Turn  = $TFn) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
		$olmsg = htmlspecialchars(__x("<b>Click to enlarge</B><br><i>Image=</i>{image}<br><i>Date=</i>$Fts<br><i>Size=</i>$Fwh",image=>$Fn));
		print "<img wolbset=\"MYPHOTOS\" wolbsrc=\"$Furn/$Fn\" src=\"$Turn\" onMouseOut=\"nd()\" onmouseover=\"overlib('$olmsg')\" border=\"0\" alt=\"".__x('Image {file}',file=>$Furn."/".$Fn)."\">\n";
		#print "<a href=\"$Furn/$Fn\" data-lightbox=\"$Fn\" title=\"$Fn\"><img src=\"$Turn\" onMouseOut=\"nd()\" onmouseover=\"overlib('$olmsg')\" border=\"0\" alt=\"".__x('Image {file}',file=>$Furn."/".$Fn)."\"></a>\n";
	}
}
if ($editOK || $#listePhotos >= 0) {
	print "</TD></TR>\n";
}

# Row "SCHEMES" ---------------------------------------------------------------
#
$Fpath  = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_SCHEMES}";
#FB-was: ($Furn  = $Fpath) =~ s/$WEBOBS{ROOT_SITE}/../g;
( $Furn  = $Fpath) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
$Tpath  = "$Fpath/$NODES{SPATH_THUMBNAILS}";
qx(mkdir -p $Tpath) if (!-d $Tpath);

my @listeSchemas  = <$Fpath/*.*> ;
#DL-was:my $uploadSCHEMAS = "$WEBOBS{CGI_UPLOAD}?node=$GRIDType.$GRIDName.$NODEName&doc=$NODES{SPATH_SCHEMES}";
my $uploadSCHEMAS = "$WEBOBS{CGI_UPLOAD}?object=$GRIDType.$GRIDName.$NODEName&doc=SPATH_SCHEMES";
if ($editOK) {
	print "<tr><TH valign=\"top\"><a href=\"$uploadSCHEMAS\">$__{Diagrams}</a></TH><TD colspan=\"2\">";
} elsif ($#listeSchemas >= 0) {
	print "<tr><TH valign=\"top\">$__{Diagrams}</TH><TD colspan=\"2\">";
}
chomp(@listeSchemas);
if ($#listeSchemas >= 0) {
	for (@listeSchemas) {
		$Fn    = basename($_);
		print "<a href=\"$Furn/$Fn\">";
		if ($NODES{THUMBNAILS_ON} eq 'ALL' ) {
			$TFn   = makeThumbnail($_, "x$NODES{THUMBNAILS_PIXV}", $Tpath, $NODES{THUMBNAILS_EXT});
			if ($TFn ne "") {
				#FB-was: ($Turn  = $TFn) =~ s/$WEBOBS{ROOT_SITE}/../g;
				($Fts,$Fwh) = split(/\|/,getImageInfo($_));
				( $Turn  = $TFn) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
				$olmsg = htmlspecialchars(__x("<b>Click to enlarge</B><br><i>Image=</i>{image}<br><i>Size=</i>$Fwh",image=>$Fn));
				print "<img src=\"$Turn\" onMouseOut=\"nd()\" onmouseover=\"overlib('$olmsg')\" border=\"0\" alt=\"".__x('Image {file}',file=>$Furn."/".$Fn)."\">";
			} else { print "$Fn<br>" }
		} else { print "$Fn<br>" }
		print "</a>\n";
	}
}
if ($editOK || $#listeSchemas >= 0) {
	print "</TD></TR>\n";
}

# Row "DOCUMENTS" -------------------------------------------------------------
#
$Fpath  = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_DOCUMENTS}";
#FB-was: ($Furn  = $Fpath) =~ s/$WEBOBS{ROOT_SITE}/../g;
( $Furn  = $Fpath) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
$Tpath  = "$Fpath/$NODES{SPATH_THUMBNAILS}";
qx(mkdir -p $Tpath) if (!-d $Tpath);

my @listeDocuments  = <$Fpath/*.*> ;
#DL-was:my $uploadDOCUMENTS = "$WEBOBS{CGI_UPLOAD}?node=$GRIDType.$GRIDName.$NODEName&doc=$NODES{SPATH_DOCUMENTS}";
my $uploadDOCUMENTS = "$WEBOBS{CGI_UPLOAD}?object=$GRIDType.$GRIDName.$NODEName&doc=SPATH_DOCUMENTS";
if ($editOK) {
	print "<tr><TH valign=\"top\"><a href=\"$uploadDOCUMENTS\">$__{Documents}</a></TH><TD colspan=\"2\">";
} elsif ($#listeDocuments >= 0) {
	print "<tr><TH valign=\"top\">$__{Documents}</TH><TD colspan=\"2\">";
}
chomp(@listeDocuments);
if ($#listeDocuments >= 0) {
	for (@listeDocuments) {
		$Fn    = basename($_);
		print "<a href=\"$Furn/$Fn\">";
		if ($NODES{THUMBNAILS_ON} eq 'ALL' ) {
			$TFn   = makeThumbnail($_, "x$NODES{THUMBNAILS_PIXV}", $Tpath, $NODES{THUMBNAILS_EXT});
			if ($TFn ne "") {
				#FB-was: ($Turn  = $TFn) =~ s/$WEBOBS{ROOT_SITE}/../g;
				( $Turn  = $TFn) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
				$olmsg = htmlspecialchars(__x("<b>Click to download</B><br>File={file}",file=>$Fn));
				print "<img src=\"$Turn\" onMouseOut=\"nd()\" onmouseover=\"overlib('$olmsg')\" border=\"0\" alt=\"".__x('Image {file}',file=>$Furn."/".$Fn)."\">";
			} else { print "$Fn<br>"; }
		} else { print "$Fn<br>"; }
		print "</a>\n";
	}
}
if ($editOK || $#listeDocuments >= 0) {
	print "</TD></TR>\n";
}
#
# ---- end of node table ------------------------------------------------------
print "</TABLE>";


# ---- Project ----------------------------------------------------------------
#
print "<BR><A name=\"PROJECT\"></A>\n";
print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#projID');\">&nbsp;&nbsp;";
print "$__{Project}";
if ($editOK) { print "&nbsp;&nbsp;<A href=\"/cgi-bin/vedit.pl?action=new&event=$NODEName\_Projet.txt&object=$GRIDType.$GRIDName.$NODEName\"><img src=\"/icons/modif.png\"></A>" }
print "&nbsp;$go2top</div><div id=\"projID\"><BR>";
my $htmlProj = projectShow("$GRIDType.$GRIDName.$NODEName", $editOK);
print $htmlProj;
print "</div></div>";

# ---- Events / interventions
#
print "<BR><A name=\"EVENTS\"></A>\n";
print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#eventID');\">&nbsp;&nbsp;";
print "$__{'Events'} $tz";
if ($editOK) { print "&nbsp;&nbsp;<A href=\"/cgi-bin/vedit.pl?action=new&object=$GRIDType.$GRIDName.$NODEName\"><img src=\"/icons/modif.png\"></A>" }
print "&nbsp;$go2top</div><div id=\"eventID\"><BR>";
print "&nbsp;$__{'Sort by'} [ ".($sortBy ne "event" ? "<A href=\"$myself&amp;sortby=event#EVENTS\">$__{'Event'}</A>":"<B>$__{'Event'}</B>")." | "
	.($sortBy ne "date" ? "<A href=\"$myself&amp;sortby=date#EVENTS\">$__{'Date'}</A>":"<B>$__{'Date'}</B>")." ]<BR>\n";
my $htmlEvents = ($sortBy =~ /event/i) ? eventsShow("events","$GRIDType.$GRIDName.$NODEName", $editOK) : eventsShow("date","$GRIDType.$GRIDName.$NODEName", $editOK);
print $htmlEvents;
print "</div></div>";

# --- we're done !!!!
print "</FORM><BR>\n</BODY>\n</HTML>\n";


__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon, Lucas Dassin

=head1 COPYRIGHT

WebObs - 2012-2022 - Institut de Physique du Globe Paris

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
