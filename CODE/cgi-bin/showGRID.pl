#!/usr/bin/perl

=head1 NAME

showGRID.pl

=head1 SYNOPSIS

http://..../showGRID.pl?grid=gridtype.gridname[,nodes=][,coord=][,project=][,procparam=][,sortby=][,map=][,invalid=]

=head1 DESCRIPTION

Display a GRID

=head1 Query string parameters

grid=
 grid full name to display as gridtype.gridname

nodes=
 filter on the node activity status. Default value is DEFAULT_NODES_FILTER variable in GRIDS.rc. Options are:
   active  only active nodes (current time is between the start and end dates)
 inactive  only inactive nodes (end date in the past or start date in the future)
      all  all nodes

coord=
 specify the coordonates. Default value is DEFAULT_COORDINATES variable in GRIDS.rc. Options are:
  latlon  latitude and longitude
     utm  Universal Transverse Mercator projection (WGS84)
     xyz  geocentric X, Y and Z

project=
 show/hide the project column. Default value is DEFAULT_PROJECT_FILTER variable in GRIDS.rc. Options are:
   on
   off

procparam=
 show/hide the proc parameters columns. Default value is DEFAULT_PROCPARAM_FILTER variable in GRIDS.rc. Options are:
   on
   off

sortby=
 how to sort the grid events. Options are:
   event  sub-events are displayed below the parent event (default)
    date  all events in reversed chronological order

map=
 map number in case of submaps. Default is the main grid map.

invalid=
 show/hide invalid nodes. This option is for administrator level only.

=cut

use strict;
use warnings;

$|=1;
use File::Basename;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use File::Copy qw(copy);
use File::Find qw(find);
use List::Util qw(first);
use List::MoreUtils qw(uniq);
use Image::Info qw(image_info dim);
use Date::Parse;
use POSIX qw(strftime);

use WebObs::Config;
use WebObs::Grids;
use WebObs::Form;
use WebObs::Events;
use WebObs::Users;
use WebObs::Utils;
use WebObs::Search;
use WebObs::Wiki;
use WebObs::i18n;
use WebObs::Mapping;
use Locale::TextDomain('webobs');

# ---- init general-use variables on the way and quit if something's wrong
#
my $cgi = new CGI;
set_message(\&webobs_cgi_msg);
my $htmlcontents = "";  # HTML page that will be returned to the browser
my $editOK   = 0;       # 1 if the user is allowed to edit the grid
my $admOK    = 0;       # 1 if the user has admin rights in the grid
my $GRIDType = "";      # grid type ("PROC" or "VIEW")
my $GRIDName = "";      # name of the grid
my %GRID;               # structure describing the grid
my $theiaAuth = isok($WEBOBS{THEIA_USER_FLAG});

my @GID = split(/[\.\/]/, trim(checkParam($cgi->param('grid'),
            qr{^(VIEW|PROC)(\.|/)|[a-zA-Z0-9]+$}, "grid") // ''));
my $usrNodes = checkParam($cgi->param('nodes'), qr/^[a-zA-Z]*$/, 'nodes')
  // $GRIDS{DEFAULT_NODES_FILTER};
my $usrCoord = checkParam($cgi->param('coord'), qr/^[a-zA-Z]*$/, 'coord')
  // $GRIDS{DEFAULT_COORDINATES};
my $usrProject = checkParam($cgi->param('project'), qr/^(on|off)?$/, 'project')
  // $GRIDS{DEFAULT_PROJECT_FILTER};
my $usrProcparam = checkParam($cgi->param('procparam'),
    qr/^(on|off)?$/, 'procparam')
  // $GRIDS{DEFAULT_PROCPARAM_FILTER};
my $usrSortby = checkParam($cgi->param('sortby'), qr/^[a-z]*$/, 'sortby')
  // "event";
my $usrMap = checkParam($cgi->param('map'), qr/^[0-9]*$/, 'map') // '';
my $usrInvalid = checkParam($cgi->param('invalid'), qr/^(on|off)?$/, 'invalid') // "off";

if (scalar(@GID) == 2) {
    ($GRIDType, $GRIDName) = @GID;
    my %G;
    if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
    elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
    elsif  (uc($GRIDType) eq 'FORM') { %G = readForm($GRIDName) }
    if (%G) {
        %GRID = %{$G{$GRIDName}} ;
        if ( WebObs::Users::clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
            if ( WebObs::Users::clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
                $editOK = 1;
            }
            if ( WebObs::Users::clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
                $admOK = 1;
            }
        } else { die "You cannot display $GRIDType.$GRIDName"}
    } else { die "Couldn't get $GRIDType.$GRIDName configuration." }
} else { die "No valid GRID requested (NOT gridtype.gridname)." }

# ---- good, passed all checkings above
#
my $grid = "$GRIDType.$GRIDName";
my $isProc = ($GRIDType eq "PROC" ? '1':'0');
my $isForm = ($GRIDType eq "FORM" ? '1':'0');
my @procTS = ();
my $procOUTG;
my %authUsers;
if ($isProc) {
    %authUsers = WebObs::Users::resListAuth(type=>'authprocs',name=>$GRIDName);
    $procOUTG = '1' if ( -d "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/$WEBOBS{PATH_OUTG_GRAPHS}" );
    $procOUTG = 'events' if ( -d "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/$WEBOBS{PATH_OUTG_EVENTS}" );
    @procTS = split(/,/,$GRID{TIMESCALELIST});
} else {
    %authUsers = WebObs::Users::resListAuth(type=>'authviews',name=>$GRIDName);
    $usrProcparam = '';
}
my @domain = split(/\|/,$GRID{DOMAIN});

my $myself = "/cgi-bin/".basename($0)."?grid=$grid";
my $nbNodes = scalar(@{$GRID{NODESLIST}});
my $tbl = lc($GRIDName); # form table name
my $dbh;

my $titrePage = "";
my $editCGI = "/cgi-bin/nedit.pl";

$GRID{UTM_LOCAL} ||= '';
my %UTM = %{setUTMLOCAL($GRID{UTM_LOCAL})};
my $localCS = $UTM{GEODETIC_DATUM_LOCAL_NAME};

my $showType = (defined($GRIDS{SHOW_TYPE})
      && ($GRIDS{SHOW_TYPE} eq 'N')
      || (defined($GRID{TYPE}) && $GRID{TYPE} eq ""))
  ? 0 : 1;
my $showOwnr = (defined($GRIDS{SHOW_OWNER})
      && ($GRIDS{SHOW_OWNER} eq 'N')
      || (defined($GRID{OWNCODE}) && $GRID{OWNCODE} eq ""))
  ? 0 : 1;

my $today = strftime("%Y-%m-%d", localtime);

my $go2top = "&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";

my %CLBS = readCfg("$WEBOBS{ROOT_CODE}/etc/clb.conf");

# ---- Nodes status ---------------------
my $overallStatus = 1;
my $statusDB = $NODES{SQL_DB_STATUS} || "$WEBOBS{PATH_DATA_DB}/NODESSTATUS.db";
my $statusNODES;
if (-e $statusDB) {
    $dbh = DBI->connect("dbi:SQLite:$statusDB", "", "", {
            'AutoCommit' => 1,
            'PrintError' => 1,
            'RaiseError' => 1,
        }) || die "Error connecting to $statusDB: $DBI::errstr";
    $statusNODES = $dbh->selectall_arrayref(
        "select * from status where NODE like ? order by UPDATED asc",
        undef, "%$grid%");
    if (@$statusNODES == 0) {
        $overallStatus = 0;
    }
} else {
    $overallStatus = 0;
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
print "<TABLE width=100%><TR><TD style='border:0'>\n";
my $domain_title = ($#domain > 0 ? "#":$DOMAINS{$domain[0]}{NAME});
print "<H1 style=\"margin-bottom:6pt\"> $domain_title / $GRID{NAME}".($admOK ? " <A href=\"/cgi-bin/formGRID.pl?grid=$grid\"><IMG src=\"/icons/modif.png\"></A>":"")."</H1>\n";
print WebObs::Search::searchpopup();

my $ilinks = "[ ";
$ilinks .= "<A href=\"/cgi-bin/listGRIDS.pl?type=".lc($GRIDType)."\">".ucfirst(lc($GRIDType))."s</A>";
$ilinks .= " | <A href='#MYTOP' title=\"$__{'Find text in Grid'}\" onclick='srchopenPopup(\"+$GRIDType.$GRIDName\");return false'>\
               <img class='ic' src='/icons/search.png'></A>";
$ilinks .= " | <A href=\"/cgi-bin/gvTransit.pl?grid=$GRIDType.$GRIDName\"><IMG src=\"/icons/tmap.png\" \
               title=\"Tmap\" style=\"vertical-align:middle;border:0\"></A>";
$ilinks .= " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/$WEBOBS{CGI_OSM}?grid=$grid','$GRIDName','width="
  .($WEBOBS{OSM_WIDTH_VALUE}+15).",height="
  .($WEBOBS{OSM_HEIGHT_VALUE}+15).",toolbar=no,menubar=no,location=no')\">
        <IMG src=\"$WEBOBS{OSM_NODE_ICON}\" title=\"$WEBOBS{OSM_INFO}\" style=\"vertical-align:middle;border:0\"></A>";
if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
    $ilinks .= " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=kml')\" \
                   title=\"$WEBOBS{GOOGLE_EARTH_LINK_INFO}\"><IMG style=\"vertical-align:middle;border:0\" \
                   src=\"$WEBOBS{IMAGE_LOGO_GOOGLE_EARTH}\" alt=\"KML\"></A>\n";
}
$ilinks .= " | <A href=\"#SPECS\">$__{Specifications}</A>";
$ilinks .= " | <A href=\"#MAPS\">$__{'Location'}</A>";
$ilinks .= " | <A href=\"#INFO\">$__{'Information'}</A>";
$ilinks .= " | <A href=\"#PROJECT\">$__{'Project'}</A>";
$ilinks .= " | <A href=\"#EVENTS\">$__{'Events'}</A>";
$ilinks .= " | <A href=\"#REF\">$__{'References'}</A>";
$ilinks .= " | <A href=\"/cgi-bin/showTHEIA.pl\">$__{'Theia board'}</A>" if ($theiaAuth);
$ilinks .= " | <img src=\"/icons/refresh.png\" style=\"vertical-align:middle\" title=\"Refresh\" \
               onclick=\"document.location.reload(false)\">";
$ilinks .= " ]";
print "<P class=\"subMenu\"> <b>&raquo;&raquo;</b> $ilinks</P>";
print "</TD><TD width='82px' style='border:0;text-align:right'>".qrcode($WEBOBS{QRCODE_BIN},$WEBOBS{QRCODE_SIZE})."</TD></TR></TABLE>\n";

# ---- Objectives
#
my @desc;
my $fileDesc = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDType.$GRIDName"."$GRIDS{DESCRIPTION_SUFFIX}";
my $legacyfileDesc = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDName"."$GRIDS{DESCRIPTION_SUFFIX}";
if (-e $legacyfileDesc) {
    copy($legacyfileDesc, $fileDesc);
}
if (-e $fileDesc) {
    @desc = readFile($fileDesc);
}
$htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#descID');\">&nbsp;&nbsp;";
$htmlcontents .= "$__{'Purpose'}";
if ($editOK) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$GRIDS{DESCRIPTION_SUFFIX}\&grid=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
$htmlcontents .= "</div><div id=\"descID\"><BR>";
if ($#desc >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@desc))."</P>\n" }
$htmlcontents .= "</div></div>";
print $htmlcontents;

# ---- GRID's characteristics
#
print "<BR>";
$htmlcontents = "<A NAME=\"SPECS\"></A>";
$htmlcontents .= "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#specID');\">&nbsp;&nbsp;";
$htmlcontents .= "$__{'Specifications'}&nbsp;$go2top";
$htmlcontents .= "</div><div id=\"specID\">";

# should 'nodes' be called differently (than 'nodes'!) ?
my $snm = defined($GRID{NODE_NAME}) ? $GRID{NODE_NAME} : "$__{'node'}";
$htmlcontents .= "<TABLE width=\"100%\"><TR><TD style=\"border:0;vertical-align:top\"><UL>";
$htmlcontents .= "<LI>$__{'Grid code'}: <B class='code'>$grid</B></LI>\n";
# -----------
$htmlcontents .= "<LI>$__{'Description'}: <I>$GRID{DESCRIPTION}</I></LI>\n" if ($GRID{DESCRIPTION});
# -----------
foreach (@domain) {
    $htmlcontents .= "<LI>$__{'Domain'}: <A href=\"/cgi-bin/listGRIDS.pl?domain=$_\"><B>$DOMAINS{$_}{NAME}</B></A></LI>\n";
}
# -----------
if ($showOwnr && defined($GRID{OWNCODE})) {
    $htmlcontents   .= "<LI>$__{'Owner'}: <B>".(defined($OWNRS{$GRID{OWNCODE}}) ? $OWNRS{$GRID{OWNCODE}}:$GRID{OWNCODE})."</B></LI>\n"
}
if ($showType && $GRID{TYPE} ne "") {
    $htmlcontents .= "<LI>$__{'Type'}: <B>$GRID{TYPE}</B></LI>\n";
}
# -----------
# only for PROCs
if ($isProc) {

    my $form;

    # -----------
    if ($GRID{RAWFORMAT}) {
        $htmlcontents .= "<LI>$__{'Default data format'}: <B class='code'>$GRID{RAWFORMAT}</B></LI>\n";
        $htmlcontents .= "<LI>$__{'Default data source'}: <B>".($GRID{RAWDATA} // '')."</B></LI>\n";
        if ($GRID{RAWFORMAT} eq "genform" && defined($GRID{RAWDATA})) {
            $form = uc($GRID{RAWDATA});
        }
    }

    # -----------
    if (defined($GRID{URNDATA}) || $form ne "") {
        $htmlcontents .= "<LI>$__{'Access to rawdata'}: <B>";
        if ($form ne "") {
            $htmlcontents .= "<A href=\"/cgi-bin/showGENFORM.pl?form=$form\">$form database</A>";
        } else {
            $htmlcontents .= "<A href=\"$GRID{URNDATA}\">$GRID{URNDATA}</A>";
        }
        $htmlcontents .= "</B></LI>\n";
    }

    # -----------
    if (defined($GRID{EVENTS_FILE})) {
        $htmlcontents .= "<LI>$__{'Events File(s)'}:";
        foreach (split(/,/,$GRID{EVENTS_FILE})) {
            my $evtFile = basename("$_");
            my $dir = dirname("$_");
            my $loc = "";
            $loc = "DATA" if ($dir =~ /^$WEBOBS{ROOT_DATA}/);
            $loc = "CONF" if ($dir =~ /^$WEBOBS{ROOT_CONF}/);

            # will be editable only if located in DATA/ or CONF/ (xedit policy)
            if ($loc ne "" && $editOK) {
                $htmlcontents .= " <B><A href=\"/cgi-bin/xedit.pl?fs=$loc/$evtFile&tpl=events-template\">$loc/$evtFile</A></B>";
            } else {
                $htmlcontents .= " <B>$evtFile</B>";
            }
        }
        $htmlcontents .= "</LI>\n";
    }
}

# -----------
# only for FORMs
if ($isForm) {

    # connect to the database
    $dbh = connectDbForms();

    # get the total number or records
    my $stmt = "SELECT COUNT(id) FROM $tbl";
    my $sth = $dbh->prepare($stmt);
    my $rv = $sth->execute() or die $DBI::errstr;
    my @row = $sth->fetchrow_array();
    my $nbData = join('',@row);
    $sth->finish();

    # get the total number or records in trash
    $stmt = "SELECT COUNT(id) FROM $tbl WHERE trash=1";
    $sth = $dbh->prepare($stmt);
    $rv = $sth->execute() or die $DBI::errstr;
    @row = $sth->fetchrow_array();
    my $nbTrash = join('',@row);
    $sth->finish();

    my $urnData = "/cgi-bin/showGENFORM.pl?form=$GRIDName";
    $htmlcontents .= "<LI>$__{'Form structure:'} "
                    ."<B>".grep(/^INPUT.._NAME/,keys(%GRID))."</B> $__{'inputs'}, "
                    ."<B>".grep(/^OUTPUT.._NAME/,keys(%GRID))."</B> $__{'outputs'}, "
                    ."<B>".grep(/(IN|OUT)PUT../,split(/,/,join(',',($GRID{PROC_DATA_LIST},$GRID{PROC_ERROR_LIST},$GRID{PROC_CELL_LIST}))))."</B> $__{'proc exports'}"
                    ."</LI>\n";
    $htmlcontents .= "<LI>$__{'Form layout:'} <B>".grep(/^COLUMN.._LIST/,keys(%GRID))."</B> $__{'columns'},"
      ." <B>".grep(/^FIELDSET.._NAME/,keys(%GRID))."</B> $__{'fieldsets'}</LI>\n";
    $htmlcontents .= "<LI>$__{'First year of data:'} <B>$GRID{BANG}</B></LI>\n";
    $htmlcontents .= "<LI>$__{'Time zone for all records:'} <B>UTC".sprintf("%+03d",$GRID{TZ})."</B></LI>\n";
    $htmlcontents .= "<LI>$__{'Total number of records:'} <B>$nbData</B> ($__{'including'} <B>$nbTrash</B> $__{'in trash'})</LI>\n";
    $htmlcontents .= "<LI>$__{'Access to data'}: <A href=\"$urnData\"><IMG src='/icons/form.png' style='vertical-align:middle'></A></LI>\n";
}

# -----------
if (defined($GRID{URL})) {
    my @links = split(/;/,$GRID{URL});
    foreach (@links) {
        my @txt = split(/,/,$_);
        push(@txt,$txt[0]) if (index($_, ",") == -1);
        $htmlcontents .= "<LI>$__{'External link'}: <B><A href=\"$txt[1]\" target=\"_blank\">$txt[0]<\/A></B></LI>\n";
    }
}
$htmlcontents .= "</UL></TD>\n";

# -----------
# only for PROCs: link to output pages and time scale parameters
if ($isProc) {
    if (grep(/^FID_/,keys(%GRID))) {
        $htmlcontents .= "<TD style=\"border:0;text-align:right;vertical-align:top\"><TABLE><TR><TH colspan=2>$__{'Nodes Default FIDs'}</TH></TR>\n";
        foreach (grep(/^FID_/,sort(keys(%GRID)))) {
            $htmlcontents .= "<TR><TD>$_</TD><TD><B>$GRID{$_}</B></TD></TR>\n";
        }
        $htmlcontents .= "</TABLE></TD>\n";
    }
    if ($procOUTG) {
        my $urn = "/cgi-bin/showOUTG.pl?grid=PROC.$GRIDName";
        $htmlcontents .= "<TD style=\"border:0;text-align:right;vertical-align:top\"><TABLE><TR><TH>$__{'Proc Graphs'}</TH><TH>".join("</TH><TH>",@procTS)."</TH></TR>\n";
        if ($procOUTG eq "events") {
            $htmlcontents .= "<TR><TD align=\"right\">Events</TD><TD align=\"center\"><A href=\"$urn&amp;ts=events\"><B><IMG src=\"/icons/visu.png\"></B></A></TD></TR>\n";
        } else {
            foreach my $g ("",split(/,/,$GRID{SUMMARYLIST})) {
                my $outg = join('',map {$_ = "<TD align=\"center\"><A href=\"$urn&amp;ts=$_&amp;g=$g\"><B><IMG src=\"/icons/visu.png\"></B></A></TD>"} split(/,/,$GRID{TIMESCALELIST}));
                $htmlcontents .= "<TR><TD align=\"right\">".($g eq ""?"Overview":"$g")."</TD>$outg</TR>\n";
            }
        }
        if ($theiaAuth) {
            $htmlcontents .= "<TR><TD>$__{'Send to Theia'}\n";
            $htmlcontents .= join('', map { checkingTS($_,$GRID{THEIA_SELECTED_TS}) } @procTS);
            $htmlcontents .= "</TD></TR>";
        }
        $htmlcontents .= "</TABLE></TD>\n";
    }
    $htmlcontents .= "<TD style=\"border:0;text-align:right;vertical-align:top\"><TABLE><TR><TH>$__{'Proc Param.'}</TH><TH>".join("</TH><TH>",@procTS)."</TH></TR>\n";
    foreach ("Decimate","Cumulate","DateStr","MarkerSize","LineWidth","Status") {
        my @tsp = split(/,/,$GRID{uc($_)."LIST"});
        my $cells;
        if ($#tsp < 0) {
            $cells = "<TD align=\"center\" colspan=\"".($#procTS+1)."\"><I><SMALL>$__{'undefined'}</SMALL></I>";
        } else {
            push(@tsp, '&nbsp;' x ($#procTS-$#tsp)) if ($#tsp < $#procTS);
            $cells = "<TD align=\"center\"><B>".join("</B></TD><TD align=\"center\"><B>",@tsp)."</B>";
        }
        $htmlcontents .= "<TR><TD align=\"right\">$_</TD>$cells</TD></TR>\n";
    }
    $htmlcontents .= "</TABLE></TD>\n";
}

# -----------
# only for FORMs: table of input/output types
if ($isForm) {
        $htmlcontents .= tableStats('INPUT', \%GRID);
        $htmlcontents .= tableStats('OUTPUT', \%GRID);
        $htmlcontents .= "</TABLE></TD>\n";
}

$htmlcontents .= "</TR></TABLE>\n";
$htmlcontents .= "</div></div>";
print $htmlcontents;

# ---- Now the GRID's NODE(s)
# ---- first, submenu line for selections (list Active nodes, All,..., Coordinates type, etc....)
#
print "<BR>";
$htmlcontents = "<A name=\"NODES\"></A>";
$htmlcontents .= "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#nodesID');\">&nbsp;&nbsp;";
$htmlcontents .= "$nbNodes $snm".($nbNodes > 1 ? "s":"")."&nbsp;$go2top";
$htmlcontents .= "</div><div id=\"nodesID\">";

$htmlcontents .= "<P class=\"subTitleMenu\" style=\"margin-left: 5px\">";

my $procParm = '';
if ($isProc) {
    $procParm = "&amp;procparam=$usrProcparam";
}

# -- Nodes list submenu Nodes
$htmlcontents .= "$__{'Nodes'} [ ";
$htmlcontents .= ($usrNodes eq "active" ? "<B>$__{'Active'}</B>":"<A href=\"$myself&amp;nodes=active&amp;coord=$usrCoord&amp;project=$usrProject&amp;$procParm#NODES\">$__{'Active'}</A>");
$htmlcontents .= " | ";
$htmlcontents .= ($usrNodes eq "inactive" ? "<B>$__{'Inactive'}</B>":"<A href=\"$myself&amp;nodes=inactive&amp;coord=$usrCoord&amp;project=$usrProject&amp;$procParm#NODES\">$__{'Inactive'}</A>");
$htmlcontents .= " | ";
$htmlcontents .= ($usrNodes eq "all" ? "<B>$__{'All'}</B>":"<A href=\"$myself&amp;nodes=all&amp;coord=$usrCoord&amp;project=$usrProject$procParm#NODES\">$__{'All'}</A>");
if ( $admOK ) {
    $htmlcontents .= " | ".($usrInvalid eq "on" ? "<A href=\"$myself&amp;invalid=off&amp;coord=$usrCoord&amp;project=$usrProject&amp;nodes=$usrNodes$procParm#NODES\">$__{'Hide invalid'}</A>"
        :"<A href=\"$myself&amp;invalid=on&amp;coord=$usrCoord&amp;project=$usrProject&amp;nodes=$usrNodes$procParm#NODES\">$__{'Show invalid'}</A>");
}
$htmlcontents .= " ] ";

# -- Nodes list submenu Coordinates
$htmlcontents .= "- $__{Coordinates} [ "
  .($usrCoord eq "latlon" ? "<B>Lat/Lon</B>":"<A href=\"$myself&amp;project=$usrProject&amp;nodes=$usrNodes&amp;coord=latlon$procParm#NODES\">Lat/Lon</A>")." | "
  .($usrCoord eq "utm"    ? "<B>UTM</B>":"<A href=\"$myself&amp;project=$usrProject&amp;nodes=$usrNodes&amp;coord=utm$procParm#NODES\">UTM</A>");
if (defined($GRID{UTM_LOCAL}) && -e $GRID{UTM_LOCAL} ) {
    $htmlcontents .= " | ".($usrCoord eq "local" ? "<B>$localCS</B>":"<A href=\"$myself&amp;project=$usrProject&amp;nodes=$usrNodes&amp;coord=local$procParm#NODES\">$localCS</A>");
}
$htmlcontents .= " | "
  .($usrCoord eq "xyz"    ? "<B>XYZ</B>":"<A href=\"$myself&amp;project=$usrProject&amp;nodes=$usrNodes&amp;coord=xyz$procParm#NODES\">XYZ</A>");
$htmlcontents .= " ] - $__{Export} [";
$htmlcontents .= " <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=txt&amp;coord=$usrCoord&amp;nodes=$usrNodes')\" title=\"Exports TXT file\">TXT</A> |";
$htmlcontents .= " <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=csv&amp;coord=$usrCoord&amp;nodes=$usrNodes')\" title=\"Exports CSV file\">CSV</A>";
if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
    $htmlcontents .= " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=kml&amp;nodes=$usrNodes')\" title=\"Exports KML file\">KML</A>";
}
$htmlcontents .= " ] ";

# -- Nodes list submenu Proc paramaters
if ($isProc) {
    $htmlcontents .= "- $__{'Proc parameters'} [ "
      .($usrProcparam eq "on"  ? "<B>On</B>" :"<A href=\"$myself&amp;nodes=$usrNodes&amp;coord=$usrCoord&amp;project=$usrProject&amp;procparam=on#NODES\">On</A>")." | "
      .($usrProcparam ne "on" ? "<B>Off</B>":"<A href=\"$myself&amp;nodes=$usrNodes&amp;coord=$usrCoord&amp;project=$usrProject&amp;procparam=off#NODES\">Off</A>")." ] ";
}

# -- Nodes list submenu Project
if ( $CLIENT ne 'guest' ) {
    $htmlcontents .= "- $__{Project} [ "
      .($usrProject eq "on"  ? "<B>On</B>" :"<A href=\"$myself&amp;nodes=$usrNodes&amp;coord=$usrCoord&amp;project=on$procParm#NODES\">On</A>")." | "
      .($usrProject eq "off" ? "<B>Off</B>":"<A href=\"$myself&amp;nodes=$usrNodes&amp;coord=$usrCoord&amp;project=off$procParm#NODES\">Off</A>")." ] ";
}
$htmlcontents .= "</P>\n";

# ---- then, the Nodes' table
#
my $nbValides = 0;
my $nbNonValides = 0;
my $tcolor;
my %NODE;
my $newNODE = "<A href=\"/cgi-bin/$NODES{CGI_FORM}?node=$grid\"><IMG title=\"$__{'Create a new node'}\" src=\"/icons/new.png\"></A>";

#$htmlcontents .= "<TABLE width=\"100%\" style=\"margin-left: 5px\">";
$htmlcontents .= "<TABLE width=\"100%\" class=\"trData\"";
$htmlcontents .= "<TR>";
$htmlcontents .= ($editOK ? "<TH width=\"14px\" rowspan=2>".($admOK ? $newNODE:"")."</TH>":"")
  ."<TH rowspan=2>$__{'Alias'}</TH>"
  ."<TH rowspan=2 style=\"text-align: left\">$__{'Name'}</TH>"
  ."<TH colspan=3>$__{'Coordinates'}</TH><TH rowspan=2></TH>"
  ."<TH colspan=2>$__{'Lifetime and Validity'}</TH>"
  ."<TH rowspan=2>$__{'Type'}</TH>";
if ($CLIENT ne 'guest') {
    $htmlcontents .= "<TH rowspan=2>$__{'Nb<br>Evnt'}</TH>";
    $htmlcontents .= "<TH rowspan=2>$__{'Project'}</TH>" if ($usrProject eq "on");
}
$htmlcontents .= "<TH colspan=3>$__{'Proc Parameters'}</TH>" if ($usrProcparam eq 'on');
$htmlcontents .= "<TH rowspan=2></TH><TH colspan=".(@procTS).">$__{'Proc Graphs'}</TH>" if ($procOUTG);
if ($overallStatus) {
    my @tsp = split(/,/,$GRID{"STATUSLIST"});
    $htmlcontents .= "<TH rowspan=2></TH><TH colspan=3>$__{'Proc Status'} (".$procTS[first { $tsp[$_] eq '1' } reverse(0..$#tsp)].")</TH>";
}
$htmlcontents .= "<TH rowspan=2></TH><TH colspan=5>$__{'Form Information'}</TH>" if ($isForm);
$htmlcontents .= "</TR>\n<TR>";
if ($usrCoord eq "utm") {
    $htmlcontents .= "<TH>UTM Eastern (m)</TH><TH>UTM Northern (m)</TH><TH>$__{'Elev.'} (m)</TH>";
} elsif ($usrCoord eq "local") {
    $htmlcontents .= "<TH>Local TM Eastern (m)</TH><TH>Local TM Northern (m)</TH><TH>$__{'Elev.'} (m)</TH>";
} elsif ($usrCoord eq "xyz") {
    $htmlcontents .= "<TH>X (m)</TH><TH>Y (m)</TH><TH>Z (m)</TH>";
} else {
    $htmlcontents .= "<TH>$__{'Lat.'} (WGS84)</TH><TH>$__{'Lon.'} (WGS84)</TH><TH>$__{'Elev.'} (m)</TH>";
}
$htmlcontents .= "<TH>$__{'Start / Installation'}</TH><TH>$__{'End / Stop'}</TH>";
$htmlcontents .= "<TH>$__{'FID'}</TH><TH>$__{'Raw Format'}</TH><TH>$__{'Chan.'}</TH>" if ($usrProcparam eq 'on');
if ($procOUTG eq "events") {
    $htmlcontents .= "<TH>Events</TH>";
} elsif ($procOUTG) {
    $htmlcontents .= "<TH>".join("</TH><TH>",@procTS)."</TH>";
}
if ($overallStatus) {
    $htmlcontents .= "<TH>$__{'Last Data'} (TZ&nbsp;$GRID{TZ})</TH>"
                    ."<TH onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_node_sampling}')\">$__{'Sampl.'}</TH>"
                    ."<TH onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_node_status}')\">$__{'Status'}</TH>";
}
if ($isForm) {
    $htmlcontents .= "<TH>$__{'Raw Data'}</TH><TH>$__{'Nb Rec.'}</TH><TH>$__{'Last Record'} (TZ&nbsp;".sprintf("%+02d",$GRID{TZ}).")</TH>"
                    ."<TH onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_node_sampling}')\">$__{'Sampl.'}</TH>"
                    ."<TH onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{help_node_status}')\">$__{'Status'}</TH>";
}
$htmlcontents .= "</TR>\n";

for (@{$GRID{NODESLIST}}) {
    my $displayNode = 1;
    my $NODEName      = $_;
    my $NODENameLower = lc($NODEName);

    my %N = readNode($NODEName);
    %NODE = %{$N{$NODEName}};

    if (%NODE) {

        # is VALID ? do we display INVALID ?
        if (!isok($NODE{VALID})) {
            $tcolor="node-disabled";
            if ($usrInvalid ne "on") {
                $nbNonValides++;
                $displayNode = 0;
            }
        } else {
            $tcolor="node-active";
            $nbValides++;
        }

     # is NOT active if already 'ended' OR not yet 'installed' ? do we display ?
        if (isok($NODE{VALID}) && ($NODE{END_DATE} ne "NA" && $NODE{END_DATE} lt $today) || ($NODE{INSTALL_DATE} ne "NA" && $NODE{INSTALL_DATE} gt $today)) {
            $tcolor="node-inactive";
            if ($usrNodes eq "active") {
                $displayNode = 0;
            }
        } else {
            if ($usrNodes eq "inactive") {
                $displayNode = 0;
            }
        }

# trick: execute display logic even if we don't display, but html-comment out first
        $htmlcontents .= (!$displayNode ? "<!--":"");
        $htmlcontents .= "<TR class=\"$tcolor\">";
        $htmlcontents .= ($editOK ? "<TH><A href=\"/cgi-bin/formNODE.pl?node=$grid.$NODEName\"><IMG title=\"Edit node $NODEName\" src=\"/icons/modif.png\"></TH>":"");

        # Node's code and name
        my $lienNode="/cgi-bin/$NODES{CGI_SHOW}?node=$grid.$NODEName";
        $htmlcontents .= "<TD align=center><B>$NODE{ALIAS}</B></TD>";
        $htmlcontents .= "<TD nowrap><a href=\"$lienNode\"><B>$NODE{NAME}</B></a></TD>";

        # Node's localization
        if ($NODE{LAT_WGS84}==0 && $NODE{LON_WGS84}==0 && $NODE{ALTITUDE}==0) {
            $htmlcontents .= "<TD colspan=3> </TD>";
        } else {
            my $lat = sprintf("%.5f",$NODE{LAT_WGS84});
            my $lon = sprintf("%.5f",$NODE{LON_WGS84});
            my $alt = sprintf("%.0f",$NODE{ALTITUDE});
            if ($usrCoord eq "utm") {
                ($lat,$lon) = geo2utm($lat,$lon);
                $lat = sprintf("%.0f",$lat);
                $lon = sprintf("%.0f",$lon);
            } elsif ($usrCoord eq "local") {
                ($lat,$lon) = geo2utml($lat,$lon);
                $lat = sprintf("%.0f",$lat);
                $lon = sprintf("%.0f",$lon);
            } elsif ($usrCoord eq "xyz") {
                ($lat,$lon,$alt) = geo2cart($lat,$lon,$alt);
                $lat = sprintf("%.0f",$lat);
                $lon = sprintf("%.0f",$lon);
                $alt = sprintf("%.0f",$alt);
            }
            $htmlcontents .= "<TD align=\"center\" nowrap>$lat</TD><TD align=\"center\" nowrap>$lon</TD><TD align=\"center\" nowrap>$alt</TD>";
        }

        # Node's dates
        $htmlcontents .= "<TD></TD>";
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
        $htmlcontents .= "<TD align=\"center\">".($NODE{TYPE} // "")."</TD>";

        # #Interventions and Project file
        if ( $CLIENT ne 'guest' ) {
            my $textProj = "";
            my $pathInter="$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS}";
            my @interventions  = glob("$pathInter/$NODEName*.txt");

            #my $nbInter  = 0;
            #find(sub { $nbInter++ if /^$NODEName.*\.txt$/ }, $pathInter);
            $htmlcontents .= "<TD align=center><A href=\"/cgi-bin/showNODE.pl?node=$grid.$NODEName#EVENTS\">".scalar(@interventions)."</A></TD>";
            if ($usrProject eq "on") {
                my $fileProjName = $NODEName."_Projet.txt";
                my $fileProj = "$pathInter/$fileProjName";
                if ((-e $fileProj) && (-s $fileProj)) {
                    my @proj = readFile($fileProj);
                    @proj = grep(!/^$|^WebObs: /, @proj);
                    chomp(@proj);
                    if ($proj[0] =~ "|") {
                        my @pLigne = split(/\|/,$proj[0]);
                        my @listeNoms = split(/\+/,$pLigne[0]);
                        my $noms = join(", ",WebObs::Users::userName(@listeNoms));
                        my $titre = $pLigne[1];
                        shift(@proj);
                        if (defined($titre) && $titre ne "") {
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

        # Node's proc parameters
        if ($usrProcparam eq 'on') {
            $htmlcontents .= "<TD align=\"center\"><SPAN class=\"code\">".($NODE{"$grid.FID"} ? $NODE{"$grid.FID"} : $NODE{FID})."</SPAN></TD>"
              ."<TD align=\"center\">".($NODE{"$grid.RAWFORMAT"} ? $NODE{"$grid.RAWFORMAT"}
                : ($NODE{RAWFORMAT} ? $NODE{RAWFORMAT} : ($GRID{RAWFORMAT} // '')))."</TD>"
              ."<TD align=\"center\">";
            my %carCLB = readCLB("$grid.$NODEName");
            my $maxchid = ( sort { $carCLB{$a}{"nv"} <=> $carCLB{$b}{"nv"} } keys %carCLB )[-1];
            $htmlcontents .= "<A href=\"/cgi-bin/$CLBS{CGI_FORM}?node=$grid.$NODEName\">".$carCLB{$maxchid}{"nv"}."</A>";
            $htmlcontents .= "</TD>";
        }
        if ($procOUTG) {
            my $urn = "/cgi-bin/showOUTG.pl?grid=PROC.$GRIDName";
            $htmlcontents .= "<TD></TD>";
            if ($procOUTG eq "events") {
                $htmlcontents .= "<TD align=\"center\"><A href=\"$urn&amp;ts=events&amp;g=*/*/*/$NODEName\"><B><IMG src=\"/icons/visu.png\"></B></A></TD>\n";
            } else {
                $htmlcontents .= join('',map {$_ = "<TD align=\"center\">".( -e "$WEBOBS{ROOT_OUTG}/$grid/$WEBOBS{PATH_OUTG_GRAPHS}/".lc($NODEName)."_$_.png" ? "<A href=\"$urn&amp;ts=$_&amp;g=".lc($NODEName)."\"><B><IMG src=\"/icons/visu.png\"></B></A>":"" )."</TD>"} split(/,/,$GRID{TIMESCALELIST}))."\n";
            }
        }

        # NODE's status
        if ($overallStatus) {

           # Get the latest updated state for the node and print the information
            my $stState = (grep($_->[0] eq "$grid.$NODEName", @$statusNODES))[-1];
            if (defined($stState)) {
                my $bgcolEt = "";
                my $bgcolA = "";

                # $stState->[1] (Node status)
                if ($stState->[1] == $NODES{STATUS_STANDBY_VALUE}) { $bgcolEt = "status-standby"; $stState->[1] = "$__{Standby}"; }
                elsif ($stState->[1] < $NODES{STATUS_THRESHOLD_CRITICAL}) {
                    $stState->[1] .= " %";
                    if (defined($GRID{"TYPE"}) && $GRID{"TYPE"} eq "M") { $bgcolEt = "status-manual"; } else { $bgcolEt = "status-critical"; }
                }
                elsif ($stState->[1] >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolEt="status-ok"; $stState->[1] .= " %"; }
                else { $bgcolEt = "status-warning"; $stState->[1] .= " %"; }
                if (($stState->[1] eq "%") || ($stState->[1] eq ""))  { $bgcolEt = ""; $stState->[1] = " " }

                # $stState->[2] (Acquisition status)
                if ($stState->[2]  == $NODES{STATUS_STANDBY_VALUE}) { $bgcolA = "status-standby"; $stState->[2] = "$__{Standby}"; }
                elsif ($stState->[2] < $NODES{STATUS_THRESHOLD_CRITICAL}) { $bgcolA = "status-critical"; $stState->[2] .= " %"; }
                elsif ($stState->[2] >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolA = "status-ok"; $stState->[2] .= " %"; }
                else { $bgcolA = "status-warning"; $stState->[2] .= " %"; }
                if (($stState->[2] eq " %") || ($stState->[2] eq "")) { $bgcolA = ""; $stState->[2] = " " }

                # $stState->[3..5] (Date, Time and TZ of last measurement)
                # Display
                $htmlcontents .= "<TD></TD><TD align=\"center\" nowrap>".substr($stState->[3],0,16)."</TD>\n"; # Datetime of last data (limited to minute)
                if ($NODE{END_DATE} eq "NA" || $NODE{END_DATE} ge $today) {
                    $htmlcontents .= "<TD  align=\"center\" class=\"$bgcolA\"><B>$stState->[2]</B></TD>"
                      ."<TD  align=\"center\" class=\"$bgcolEt\"><B>$stState->[1]</B></TD>";
                } else {
                    $htmlcontents .= "<TD align=\"center\" colspan=\"2\"><I>$__{'Stopped'}</I></TD>";
                }
            } else {
                $htmlcontents .= "<TD colspan=\"4\"> </TD>";
            }
        }

        # Form information
        if ($isForm) {

            # get the total number or records for this node
            my $stmt = "SELECT COUNT(id) FROM $tbl WHERE trash=0 AND node='$NODEName'";
            my $sth = $dbh->prepare($stmt);
            my $rv = $sth->execute() or die $DBI::errstr;
            my @row = $sth->fetchrow_array();
            my $nbRec = join('',@row);
            $sth->finish();

            # get the last record for this node
            $stmt = "SELECT * FROM $tbl WHERE trash=0 AND node='$NODEName' ORDER BY edate DESC LIMIT 1";
            $sth = $dbh->prepare($stmt);
            $rv = $sth->execute() or die $DBI::errstr;
            @row = $sth->fetchrow_array();
            my ($ly,$lm,$ld,$lhr,$lmn) = datetime2array($row[4], $row[5]);
            my $lastRec = "$ly".($lm ? "-$lm":"").($ld ? "-$ld":"").($lhr ? " $lhr":"").($lmn ? ":$lmn":"");
            $sth->finish();
            my $lastdelay = $NODE{"$GRIDType.$GRIDName.LAST_DELAY"};
            my $acqrate = $NODE{"$GRIDType.$GRIDName.ACQ_RATE"};

            $htmlcontents .= "<TD></TD><TD align=\"center\"><A href=\"/cgi-bin/showGENFORM.pl?form=$GRIDName&node=$NODEName\" title=\"$__{'Access to form data'}\"><IMG src=\"/icons/form.png\"></A></TD>";
            $htmlcontents .= "<TD align=\"center\">$nbRec</TD>";
            $htmlcontents .= "<TD align=\"center\">$lastRec</TD>";

            if ($lastdelay ne "" && $acqrate ne "") {
                my $now = strftime('%Y-%m-%d %H:%M:%S',localtime(time));
                my @stDelay = date_duration($row[4],$row[5],$now,$now);
                my $stFields = 0;
                for (@row[12..$#row]) {
                    $stFields ++ if ($_ ne "");
                }
                my $stLastData = ($stDelay[0] > $lastdelay && $stDelay[1] > $lastdelay) ? sprintf("%03.0f",100*$stFields/($#row - 11)):"0";
                my $stAcqRate = sprintf("%03.0f",100*$nbRec*86400*$acqrate/(str2time($now) - str2time("$NODE{INSTALL_DATE} 00:00:00")));
                my $bgcolEt = "";
                my $bgcolA = "";

                # Node last data status
                if ($stLastData == $NODES{STATUS_STANDBY_VALUE}) { $bgcolEt = "status-standby"; $stLastData = "$__{Standby}"; }
                elsif ($stLastData < $NODES{STATUS_THRESHOLD_CRITICAL}) {
                    $stLastData .= " %";
                    $bgcolEt = "status-manual";
                }
                elsif ($stLastData >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolEt="status-ok"; $stLastData .= " %"; }
                else { $bgcolEt = "status-warning"; $stLastData .= " %"; }
                if (($stLastData eq "%") || ($stLastData eq ""))  { $bgcolEt = ""; $stLastData = " " }

                # Node acquisition status
                if ($stAcqRate  == $NODES{STATUS_STANDBY_VALUE}) { $bgcolA = "status-standby"; $stAcqRate = "$__{Standby}"; }
                elsif ($stAcqRate < $NODES{STATUS_THRESHOLD_CRITICAL}) { $bgcolA = "status-critical"; $stAcqRate .= " %"; }
                elsif ($stAcqRate >= $NODES{STATUS_THRESHOLD_WARNING}) { $bgcolA = "status-ok"; $stAcqRate .= " %"; }
                else { $bgcolA = "status-warning"; $stAcqRate .= " %"; }
                if (($stAcqRate eq " %") || ($stAcqRate eq "")) { $bgcolA = ""; $stAcqRate = " " }

                # Display
                if ($NODE{END_DATE} eq "NA" || $NODE{END_DATE} ge $today) {
                    $htmlcontents .= "<TD  align=\"center\" class=\"$bgcolA\"><B>$stAcqRate</B></TD>"
                      ."<TD  align=\"center\" class=\"$bgcolEt\"><B>$stLastData</B></TD>";
                } else {
                    $htmlcontents .= "<TD align=\"center\" colspan=\"2\"><I>$__{'Stopped'}</I></TD>";
                }
            } else {
                $htmlcontents .= "<TD colspan=\"2\"> </TD>";
            }

        }
        $htmlcontents .= "</TR>\n".(!$displayNode ? "-->":"");
    }
}
$htmlcontents .= "<TR><TH colspan=\"24\" class=\"th-bottom\"></TH></TR></TABLE>";
$htmlcontents .= "</div></div>";
print $htmlcontents;

# disconnect the DB
$dbh->disconnect() if ($isForm);

# ---- now the grid's MAPs
# only 1 map : *.png and its corresponding *.map
my $MAPpath = my $MAPurn = "";
$MAPpath = "$WEBOBS{ROOT_OUTG}/$grid/$WEBOBS{PATH_OUTG_MAPS}";

my $mapfile = $grid."_map".$usrMap;
if  ( -e "$MAPpath/$mapfile.png" ) {
    my @maps;
    my $i = 0;
    my @htmlarea;
    ( $MAPurn  = $MAPpath ) =~ s/$WEBOBS{ROOT_OUTG}/$WEBOBS{URN_OUTG}/g;
    if (opendir(my $dh, $MAPpath)) {
        @maps = grep { /.*_map\d*.png/ } readdir($dh);
        closedir($dh);
    }
    print "<BR>";
    print "<A NAME=\"MAPS\"></A>";
    print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#mapID');\">&nbsp;&nbsp;";
    print "$__{'Location'}&nbsp;$go2top";
    print "</div><div id=\"mapID\">";
    print "<P class=\"subTitleMenu\" style=\"margin-left: 5px\"> $__{Maps} [ ";
    foreach (sort @maps) {
        print "| " if ($i++);
        my @v = split(/_map|\./,$_);
        if ("$mapfile.png" eq $_) {
            print "<B>MAP$v[2]</B> ";
        } elsif ( $v[2] eq "" || exists $GRID{"MAP$v[2]_XYLIM"} ) {
            print "<A href=\"$myself&amp;nodes=$usrNodes&amp;coord=$usrCoord&amp;project=$usrProject&amp;map=$v[2]$procParm#MAPS\">MAP$v[2]</A> ";
        }
    }
    print " ] - Export [ <A href=\"$MAPurn/$mapfile.png\">PNG</A> | <A href=\"$MAPurn/$mapfile.eps\">EPS</A>";
    if ($WEBOBS{GOOGLE_EARTH_LINK} eq 1) {
        print " | <A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/nloc.pl?grid=$grid&format=kml&amp;nodes=$usrNodes')\" title=\"Exports KML file\">KML</A>";
    }
    print " ] </P>\n";
    print "<P style=\"text-align: center\"><IMG SRC=\"$MAPurn/$mapfile.png\" border=\"0\" usemap=\"#map\"></P>\n";
    if (-e "$MAPpath/$grid"."_map.map") {
        @htmlarea = readFile("$MAPpath/$mapfile.map");
        print "<map name=\"map\">@htmlarea</map>\n";
    }
    print "</div></div>\n";
}

# ----- Protocole

my $fileProtocole = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDType.$GRIDName"."$GRIDS{PROTOCOLE_SUFFIX}";
my $legacyfileProtocole = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDName"."$GRIDS{PROTOCOLE_SUFFIX}";
my @protocole = ("");
if (-e $legacyfileProtocole) {
    copy($legacyfileProtocole, $fileProtocole);
}
if (-e $fileProtocole) {
    @protocole = readFile($fileProtocole);
}
print "<BR>";
print "<A name=\"INFO\"></A>\n";
$htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#infoID');\">&nbsp;&nbsp;";
$htmlcontents .= "$__{'Information'}";
if ($editOK) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$GRIDS{PROTOCOLE_SUFFIX}\&grid=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
$htmlcontents .= "&nbsp;$go2top</div><div id=\"infoID\"><BR>";
if ($#protocole >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@protocole))."</P>\n" }
$htmlcontents .= "</div></div>";
print $htmlcontents;

# ---- Project
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
($myself = $ENV{REQUEST_URI}) =~ s/&_.*$//g ; # how I got called
$myself  =~ s/\bsortby(\=[^&]*)?(&|$)//g ;    # same but sortby= and _= removed

print "<BR><A name=\"EVENTS\"></A>\n";
print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#eventID');\">&nbsp;&nbsp;";
print "$__{'Events'}";
if ($editOK) { print "&nbsp;&nbsp;<A href=\"/cgi-bin/vedit.pl?action=new&object=$GRIDType.$GRIDName\"><img src=\"/icons/new.png\"></A>" }
print "&nbsp;$go2top</div><div id=\"eventID\"><BR>";
print "&nbsp;$__{'Sort by'} [ ".($usrSortby ne "event" ? "<A href=\"$myself&amp;sortby=event#EVENTS\">$__{'Event'}</A>":"<B>$__{'Event'}</B>")." | "
  .($usrSortby ne "date" ? "<A href=\"$myself&amp;sortby=date#EVENTS\">$__{'Date'}</A>":"<B>$__{'Date'}</B>")." ]<BR>\n";
my $htmlEvents = ($usrSortby =~ /event/i) ? eventsShow("events","$GRIDType.$GRIDName", $editOK) : eventsShow("date","$GRIDType.$GRIDName", $editOK);
print $htmlEvents;
print "</div></div>";

# ----- References / bibliographie
#
my $fileBib = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDType.$GRIDName"."$GRIDS{BIBLIO_SUFFIX}";
my $legacyfileBib = "$WEBOBS{PATH_GRIDS_DOCS}/$GRIDName"."$GRIDS{BIBLIO_SUFFIX}";
my @bib = ("");
if (-e $legacyfileBib) {
    copy($legacyfileBib, $fileBib);
}
if (-e $fileBib) {
    @bib = readFile($fileBib);
}
print "<BR>";
print "<A name=\"REF\"></A>\n";
$htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#bibID');\">&nbsp;&nbsp;";
$htmlcontents .= "$__{'References'}";
if ($editOK) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$GRIDS{BIBLIO_SUFFIX}&grid=$GRIDType.$GRIDName\"><img src=\"/icons/modif.png\"></A>" }
$htmlcontents .= "&nbsp;$go2top</div><div id=\"bibID\"><BR>";
if ($#bib >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@bib))."</P>\n" }
$htmlcontents .= "</div></div>";
print $htmlcontents;

# ----- Authorization access ------
print "<P class=\"subTitleMenu\" style=\"margin-top:20px\">$__{'Authorization access'} for <B>$GRIDType.$GRIDName</B>:";
print " administrators = <B>".join(", ", @{$authUsers{4}})."</B>;";
print " editors = <B>".join(", ", @{$authUsers{2}})."</B>;";
print " readers = <B>".join(", ", @{$authUsers{1}})."</B></P>\n";

# ---- We're done !
print "</BODY>\n</HTML>\n";

sub checkingTS {
    if ( $_[0] eq $_[1] ) {
        return "<TD><input type=\"checkbox\" checked=true disabled=\"disabled\" id=\"check_$_[0]\[\]\"/></TD>";
    } else {
        return "<TD><input type=\"checkbox\" disabled=\"disabled\" id=\"check_$_[0]\[\]\"/></TD>";
    }
}

sub checkingNODELIST {
    if ( $_[1] =~ /$_[0]/ ) {
        return "<TD align=center><input type=\"checkbox\" checked=true disabled=\"disabled\" id=\"check_$NODE{ALIAS}\[\]\"/></TD>";
    } else {
        return "<TD align=center><input type=\"checkbox\" disabled=\"disabled\" id=\"check_$NODE{ALIAS}\[\]\"/></TD>";
    }
}

# make a HTML table of (IN|OUT)PUT types
sub tableStats {
    my %G = %{$_[1]};
    my @f = sort(grep(/^$_[0].._NAME/i,keys(%G)));
    my @itypes;
    for (@f) {
        (my $key = $_) =~ s/_NAME/_TYPE/g;
        (my $type = $G{$key} ? $G{$key}:'numeric') =~ s/[\(:].*$//g;
        push(@itypes,$type);
    }
    my $txt = "<TD style='border:0;text-align:right;vertical-align:top'><TABLE class='trData'><TR><TH rowspan=2>$__{'Type:'}</TH>"
              .join("",map{"<TH rowspan=2>$_</TH>"} uniq(@itypes))."<TH colspan=3>Export n°</TH></TR>\n"
              ."<TR><TH>Data</TH><TH>Error</TH><TH>Cell</TH><TR>\n";
    for my $i (0..$#f) {
        (my $key = $f[$i]) =~ s/_NAME//g;
        my $unit = ( $G{$key."_UNIT"} ne "" ? " (".$G{$key."_UNIT"}.")":"" );
        (my $type = $G{$key} ? $G{$key}:'numeric') =~ s/[\(:].*$//g;
        $txt .= "<TR><TH>$key</TH>".join("",map {
                my $t = $_; "<TD align='center'>" . ($t eq $itypes[$i] ? "<B>".$G{$key."_NAME"}."</B>".$unit:"") . "</TD>"
            } uniq(@itypes))
                ."<TD align='center'><SPAN class='code'>".keyRank($key,$G{PROC_DATA_LIST})."</SPAN></TD>"
                ."<TD align='center'><SPAN class='code'>".keyRank($key,$G{PROC_ERROR_LIST})."</SPAN></TD>"
                ."<TD align='center'><SPAN class='code'>".keyRank($key,$G{PROC_CELL_LIST})."</SPAN></TD>"
                ."</TR>";
    }
    $txt .= "<TR><TH>Total</TH>".join("",map { my $t = $_; "<TD align='center'>" . grep(/^$t$/,@itypes) . "</TD>" } uniq(@itypes))
           ."<TD></TD><TD></TD><TD></TD></TR></TABLE></TD>\n";
    return $txt;
}

# count the rank position of KEY in the comma-separated string STR
sub keyRank {
    my $key = $_[0];
    my $str = ",$_[1]";
    my $n = "";

    if (grep(/$key/,$str)) {
        $str =~ s/$key.*$//g; # deletes string after $key
        $n = () = $str =~ /,/gi; # counts the number of commas
    }
    return $n;
}

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon, Lucas Dassin

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
