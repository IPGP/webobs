#!/usr/bin/perl

=head1 NAME

listGRIDS.pl

=head1 SYNOPSIS

http://..../listGRIDS.pl[?type={all | view | proc | form | sefran}][&domain=domspec]

=head1 DESCRIPTION

Displays GRIDS names and summary (specifications), grouped by DOMAINS, themselves ordered by their OOA (Order Of Appearance).
Default, when no type= specified, is to display all GRIDS (VIEWS, PROCS, FORMS, and SEFRAN)

=head1 Query string parameters

=over

=item B<type={all | view | proc | sefran}>

list B<all> GRIDS or B<view>s only or B<proc>s only or B<form>s only or B<sefran>s only

=item B<domain=domspec>

domspec := { domainCODE }
only list grids that belong to a domain

=back

=cut

use strict;
use warnings;

$|=1;
use CGI;
use Time::Local;
use File::Basename;
use File::Copy qw(copy);
use POSIX qw(strftime);
use Switch;

use WebObs::Config;
use WebObs::Grids;
use WebObs::Users;
use WebObs::Utils;
use WebObs::Search;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);

my $me = $ENV{SCRIPT_NAME};

my %GRID;
my %G;
my $GRIDName = my $GRIDType = my $RESOURCE = "";

my $subsetDomain = checkParam(scalar($cgi->param('domain')), qr/^[a-zA-Z0-9_-]*$/, "domain")  // "";
my $subsetType = checkParam(scalar($cgi->param('type')), qr/^[a-zA-Z0-9_-]*$/, "type") // "all";
$subsetType = 'all' if ( $subsetType ne 'proc' && $subsetType ne 'form' && $subsetType ne 'view' && $subsetType ne 'sefran');
my $wantViews   = ($subsetType eq 'all' || $subsetType eq 'view')   ? 1 : 0;
my $wantProcs   = ($subsetType eq 'all' || $subsetType eq 'proc')   ? 1 : 0;
my $wantForms   = ($subsetType eq 'all' || $subsetType eq 'form')   ? 1 : 0;
my $wantSefrans = ($subsetType eq 'all' || $subsetType eq 'sefran') ? 1 : 0;

my $showType = (defined($GRIDS{SHOW_TYPE}) && ($GRIDS{SHOW_TYPE} eq 'N')) ? 0 : 1;
my $showOwnr = (defined($GRIDS{SHOW_OWNER}) && ($GRIDS{SHOW_OWNER} eq 'N')) ? 0 : 1;

my $today = strftime("%Y-%m-%d", localtime);

my $editOK   = 0;
my $admVIEWS = 0;
my $admPROCS = 0;
my $admFORMS = 0;
my $descGridType = my $descGridName = my $descLegacy = "";

# Open an SQLite connection to the domains database
sub connectDbDomains {
    return DBI->connect("dbi:SQLite:$WEBOBS{SQL_DOMAINS}", "", "", {
            'AutoCommit' => 1,
            'PrintError' => 1,
            'RaiseError' => 1,
        }) || die "Error connecting to $WEBOBS{SQL_DOMAINS}: $DBI::errstr";
}

sub getDomains {

    # Return the (code, name) tuples from the domains table.
    # A domain code can be provided to only fetch this domain.
    # Returns a reference to list of array references.
    my $dbh = shift;
    my $domain = shift // '';
    my $where = '';
    my @bind_values = ();
    if ($domain) {
        $where = "where CODE = ?";
        push @bind_values, $domain;
    }
    my $q = "select CODE, NAME from $WEBOBS{SQL_TABLE_DOMAINS} $where order by OOA";
    return $dbh->selectall_arrayref($q, undef, @bind_values);
}

sub getDomainGrids {

    # Return the list of names of grids from the grids2domains table
    # for the provided type ('PROC', 'FORM' or 'VIEW') and domain code.
    # Returns a reference to a list of grid names.
    my $dbh = shift;
    my $type = shift;
    my $domain_code = shift;
    my $q = "select NAME from $WEBOBS{SQL_TABLE_GRIDS} "
      ."where TYPE = ? and DCODE = ? order by name";
    return $dbh->selectcol_arrayref($q, { 'Columns' => [1] },
        $type, $domain_code);
}

sub getDomainProcs {

    # Return the list of procs for a domain using getDomainGrids
    my $dbh = shift;
    my $domain_code = shift;
    return getDomainGrids($dbh, 'PROC', $domain_code);
}

sub getDomainForms {

    # Return the list of forms for a domain using getDomainGrids
    my $dbh = shift;
    my $domain_code = shift;
    return getDomainGrids($dbh, 'FORM', $domain_code);
}

sub getDomainViews {

    # Return the list of views for a domain using getDomainGrids
    my $dbh = shift;
    my $domain_code = shift;
    return getDomainGrids($dbh, 'VIEW', $domain_code);
}

sub getDomainSefrans {

    # Return the list of sefrans for a domain using getDomainGrids
    my $dbh = shift;
    my $domain_code = shift;
    return getDomainGrids($dbh, 'SEFRAN', $domain_code);
}

if ($subsetDomain ne '') {
    $descGridType = 'DOMAIN';
    $descGridName = $subsetDomain;
} else {
    $descGridType = 'GRIDS';
    switch ($subsetType) {
        case 'all' { $descGridName = 'ALL'; }
        case 'view' { $descGridName = 'VIEWS'; $descLegacy = 'VIEW.VIEWS'; }
        case 'proc' { $descGridName = 'PROCS'; $descLegacy = 'PROC.PROCS'; };
        case 'form' { $descGridName = 'FORMS'; $descLegacy = 'FORM.FORMS'; };
    }
}

# creation of new view, proc or form is allowed only if the user has admin authorization for ALL grids (views and/or procs and/or forms)
$admVIEWS = 1 if ( WebObs::Users::clientHasAdm(type=>"authviews",name=>"*") );
$admPROCS = 1 if ( WebObs::Users::clientHasAdm(type=>"authprocs",name=>"*") );
$admFORMS = 1 if ( WebObs::Users::clientHasAdm(type=>"authforms",name=>"*") );

# content edition is allowed only if the user has edit authorization for ALL grids (views, forms and procs)
$editOK = 1 if ( WebObs::Users::clientHasEdit(type=>"authviews",name=>"*")
    && WebObs::Users::clientHasEdit(type=>"authprocs",name=>"*")
    && WebObs::Users::clientHasEdit(type=>"authforms",name=>"*") );

# Regroup all database queries here for optimisation
my $dbh = connectDbDomains();
my $domains = getDomains($dbh, $subsetDomain);
my %domainProcs   = map(($_->[0] => []), @$domains);
my %domainForms   = map(($_->[0] => []), @$domains);
my %domainViews   = map(($_->[0] => []), @$domains);
my %domainSefrans = map(($_->[0] => []), @$domains);
for my $d (@$domains) {
    my ($code, $name) = @$d;
    push @{$domainProcs{$code}},   @{getDomainProcs($dbh, $code)}   if $wantProcs;
    push @{$domainForms{$code}},   @{getDomainForms($dbh, $code)}   if $wantForms;
    push @{$domainViews{$code}},   @{getDomainViews($dbh, $code)}   if $wantViews;
    push @{$domainSefrans{$code}}, @{getDomainSefrans($dbh, $code)} if $wantSefrans;
}
$dbh->disconnect();

# ---- Start HTML page
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">', "\n";
print "<HTML><HEAD><title>GRIDS</title>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">
<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>
<script language=\"JavaScript\" src=\"/js/htmlFormsUtils.js\" type=\"text/javascript\"></script>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/search.css\">
<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/listGRIDS.css\">";

print "</head><body onLoad=\"scrolldivHeight()\">";
print "<!-- overLIB (c) Erik Bosrup -->
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\" type=\"text/javascript\"></script>";

# ---- Title is = selected type (aka subsetType)
#
print "<A NAME=\"MYTOP\"></A>";
print "<H1 style=\"margin-bottom:6px\">";
print "$DOMAINS{$subsetDomain}{NAME} " if ($subsetDomain ne "");
print "$GRIDS{SHOW_GRIDS_TITLE}\n" if ($subsetType eq 'all');
print "Views" if ($subsetType eq 'view');
print "Procs" if ($subsetType eq 'proc');
print "Forms" if ($subsetType eq 'form');
print "Sefrans" if ($subsetType eq 'sefran');
print "</H1>\n";

# ---- Subtitle menu to other domains/grids displays
#
print "<P>»» [ <A href=\"/cgi-bin/vsearch.pl\"><IMG src=\"/icons/rsearch.png\" border=0 title=\"Search node's events\"></A> All";
print " ".($subsetType ne 'all' || $subsetDomain ne '' ? "<A href=\"$me\">Grids</A>":"<B>Grids</B>");
print " | ".($subsetType ne 'proc' || $subsetDomain ne '' ? "<A href=\"$me?type=proc\">Procs</A>":"<B>Procs</B>");
print " | ".($subsetType ne 'form' || $subsetDomain ne '' ? "<A href=\"$me?type=form\">Forms</A>":"<B>Forms</B>");
print " | ".($subsetType ne 'view' || $subsetDomain ne '' ? "<A href=\"$me?type=view\">Views</A>":"<B>Views</B>");
print " | ".($subsetType ne 'sefran' || $subsetDomain ne '' ? "<A href=\"$me?type=sefran\">Sefrans</A>":"<B>Sefrans</B>");
if ($subsetDomain eq '') {
    print " - Domains: ";
    print join(" | ", map("<A href=\"$me?domain=$_->[0]&type=$subsetType\">$_->[1]</A>", @$domains));
} else {
    print " - $DOMAINS{$subsetDomain}{NAME}";
    print " ".($subsetType ne 'all' ? "<A href=\"$me?domain=$subsetDomain\">Grids</A>":"<B>Grids</B>");
    print " | ".($subsetType ne 'proc' ? "<A href=\"$me?domain=$subsetDomain&type=proc\">Procs</A>":"<B>Procs</B>");
    print " | ".($subsetType ne 'form' ? "<A href=\"$me?domain=$subsetDomain&type=form\">Forms</A>":"<B>Forms</B>");
    print " | ".($subsetType ne 'view' ? "<A href=\"$me?domain=$subsetDomain&type=view\">Views</A>":"<B>Views</B>");
    print " | ".($subsetType ne 'sefran' ? "<A href=\"$me?domain=$subsetDomain&type=sefran\">Sefrans</A>":"<B>Sefrans</B>");
}
print " ]</P>";

# ---- Objectives (aka 'Purpose', 'description' of subsetType)
#
printdesc('Purpose','DESCRIPTION',$descGridType,$descGridName,$descLegacy,0,$editOK);

# ---- list subsetType grids, grouped by domains
#
print "<div id=\"noscrolldiv\">";
my @grids;
my $d = my $p = my $v = 0;
if (@$domains) {

    # ---- The invisible-until-triggered-by-js popups ;-)
    print "<a name=\"popupY\"></a>\n";
    print WebObs::Search::searchpopup();
    print geditpopup();
    print feditpopup();

    # ---- The GRIDS table
    #
    my $htmlcontents = "<CENTER><TABLE WIDTH=\"90%\" id=\"gtable\" style=\"vertical-align: top\">\n<TR>";

    if ($subsetDomain eq "") {
        $htmlcontents .= "<TH style=\"text-align: left\">";
        if (WebObs::Users::clientHasAdm(type=>"authmisc",name=>"*")) {
            $htmlcontents .= "&nbsp;<a href='/cgi-bin/gridsMgr.pl' title=\"$__{'Edit/Create a Domain/Producer'}\"><img class='ic' src='/icons/modif.png'></a>&nbsp;&nbsp;&nbsp;";
        }
        $htmlcontents .= "$__{'Domain'}</TH>";
    }
    $htmlcontents .= "<TH>$__{'Grid'}</TH>" if ($subsetType ne "");
    $htmlcontents .= "<TH style=\"text-align: left\"><a href='#popupY' title=\"$__{'Find text in Grids'}\" onclick='srchopenPopup(\"*ALL\");return false'><img class='ic' src='/icons/search.png'></a>";
    $htmlcontents .= "&nbsp;<a href='#popupY' title=\"$__{'Create a new Grid'}\" onclick='geditopenPopup();return false'><img class='ic' src='/icons/new.png'></a>" if ($admVIEWS || $admPROCS || $admFORMS);
    $htmlcontents .= "&nbsp;&nbsp;&nbsp;$__{'Name'}</TH>";
    $htmlcontents .= "<TH style=\"text-align: left\">$__{'Nodes'}</TH>";
    $htmlcontents .= "<TH style=\"text-align: left\">$__{'Type'}</TH>" if ($showType);
    $htmlcontents .= "<TH style=\"text-align: left\">$__{'Owner'}</TH>" if ($showOwnr);
    $htmlcontents .= "<TH>$__{'Graphs'}</TH>";
    $htmlcontents .= "<TH>$__{'Raw Data'}</TH>" if ($wantProcs || $wantSefrans || $wantForms);
    print "$htmlcontents</TR>\n";
    for my $d (@$domains) {
        my ($dc, $dn) = @$d;
        my @procs;
        my $ovl;
        if ($wantProcs) {
            @procs = grep(WebObs::Users::clientHasRead(type=>"authprocs", name=>$_), @{$domainProcs{$dc}});
        }
        my $np = scalar(@procs);
        push(@grids,map { "PROC.".$_."|$gridColor{PROC}" } @procs);

        my @forms;
        if ($wantForms) {
            @forms = grep(WebObs::Users::clientHasRead(type=>"authforms", name=>$_), @{$domainForms{$dc}});
        }
        my $nf = scalar(@forms);
        push(@grids,map { "FORM.".$_."|$gridColor{FORM}" } @forms);

        my @views;
        if ($wantViews) {
            @views = grep(WebObs::Users::clientHasRead(type=>"authviews", name=>$_), @{$domainViews{$dc}});
        }
        my $nv = scalar(@views);
        push(@grids,map { "VIEW.".$_."|$gridColor{VIEW}" } @views);

        my @sefrans;
        if ($wantSefrans) {
            @sefrans = grep(WebObs::Users::clientHasRead(type=>"authprocs", name=>$_),
                @{$domainSefrans{$dc}});
        }
        my $ns = scalar(@sefrans);
        push(@grids,map { "SEFRAN.".$_."|purple" } @sefrans);

        my $domrows = $np+$nv+$nf+$ns;
        my $olopt = ",FGCOLOR,'white'";
        if ( $domrows > 0 ) {
            print "<TR>";
            print "<TD rowspan=\"$domrows\" style=\"vertical-align: center\"><h2 class=\"h2gn\"><A href=\"$me?domain=$dc&type=$subsetType\">$dn</A></h2>" if ($subsetDomain eq "");
            print htmltrgrid('SEFRAN',\@sefrans);
            print htmltrgrid('PROC',\@procs);
            print htmltrgrid('FORM',\@forms);
            print htmltrgrid('VIEW',\@views);
        }
    }
    print "<TR><TH colspan=\"8\" class=\"th-bottom\"></TH></TR></TABLE></CENTER><BR>";
} else {
    print "<h3>** No domain defined or matching '$subsetDomain' **</h3>";
}
print "</div>\n";

# ---- Location (gridmaps thumbnails)
#
print "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#LocationID');\">&nbsp;&nbsp;";
print "$__{Location}&nbsp;&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A></div><div id=\"LocationID\"><P>";
foreach (@grids) {
    my ($g,$c,$n) = split(/\|/,$_);
    my $fimg = "$g/maps/".$g."_map.jpg";
    my ($gt,$gn) = split(/\./,$g);
    if (-e "$WEBOBS{ROOT_OUTG}/$fimg") {
        my $ovl = "onMouseOut=\"nd()\" onMouseOver=\"overlib('$n',CAPTION,'$g',BGCOLOR,'$c',FGCOLOR,'white')\"";
        print "<A href=\"/cgi-bin/".($gt eq 'SEFRAN' ? "sefran3.pl?s3=$gn#maps":"showGRID.pl?grid=$g#MAPS")."\" $ovl><IMG src=\"/OUTG/$fimg\"></A>";
    }
}
print "</P>\n</div></div>\n";

# ---- Protocole (aka 'Informations' of subsetType)
#
printdesc('Information','PROTOCOLE',$descGridType,$descGridName,$descLegacy,1,$editOK);

# ---- Bibiography (aka 'References' of subsetType)
#
printdesc('References','BIBLIO',$descGridType,$descGridName,$descLegacy,1,$editOK);

# ---- We're done !
print "</BODY>\n</HTML>\n";

# -----------------------------------------------------------------------------
# ---- sub to display an HTML <TR> line for a grid (SEFRAN, PROC, FORM, or VIEW)
# htmltrgrid('GRIDTYPE',\@ARRAY) returns an HTML string "<TR>...</TR>"

sub htmltrgrid {
    my $gt = $_[0];
    my @g = @{$_[1]};

    my $html = "";
    my %G;
    for my $gn (@g) {
        my $search = "";
        my $transit = "";
        my $edit = "";
        my $show = "";
        my $nn;
        my $visu = "&nbsp;";
        my $data = "&nbsp;";
        switch ($gt) {
            # ---
            case 'SEFRAN' {
                %G = readSefran($gn);
                # sefran3 resource is the associated MC3
                if (WebObs::Users::clientHasAdm(type=>"authprocs",name=>$G{$gn}{MC3_NAME})) {
                    $edit = "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=SEFRAN.$gn\" title=\"$__{'Edit Sefran'}\" ><img src='/icons/modif.png'></a>";
                }
                $show = "/cgi-bin/sefran3.pl?s3=$gn&header=1";
                $nn = (split('\|',$G{$gn}{CHANNELLIST}))."&nbsp;$__{'channels'}";
                if ( -d "$G{$gn}{ROOT}" ) {
                    $visu = "<A HREF=\"/cgi-bin/sefran3.pl?s3=$gn&header=1\"><IMG border=\"0\" alt=\"$gn\" SRC=\"/icons/visu.png\"></A>";
                }
                if (defined($G{$gn}{MC3_NAME}) && $G{$gn}{MC3_NAME} ne '') {
                    my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$G{$gn}{MC3_NAME}.conf");
                    $data = "<A HREF=\"/cgi-bin/mc3.pl?mc=$G{$gn}{MC3_NAME}\" title=\"$MC3{TITLE}\"><IMG border=\"0\" alt=\"$G{$gn}{MC3_NAME}\" SRC=\"/icons/form.png\"></A>";
                }
                last;
            }
            # ---
            case 'PROC' {
                %G = readProc($gn);
                if ( -d "$WEBOBS{ROOT_OUTG}/PROC.$gn/$WEBOBS{PATH_OUTG_GRAPHS}" ) {
                    $visu = "<A href=\"/cgi-bin/showOUTG.pl?grid=PROC.$gn\"><IMG border=\"0\" alt=\"$gn\" SRC=\"/icons/visu.png\"></A>";
                } elsif ( -d "$WEBOBS{ROOT_OUTG}/PROC.$gn/$WEBOBS{PATH_OUTG_EVENTS}" ) {
                    $visu = "<A href=\"/cgi-bin/showOUTG.pl?grid=PROC.$gn&ts=events\"><IMG border=\"0\" alt=\"$gn\" SRC=\"/icons/visu.png\"></A>";
                }
                if (defined($G{$gn}{URNDATA}) && $G{$gn}{URNDATA} ne '') {
                    $data = "<A href=\"$G{$gn}{URNDATA}\"><IMG border=\"0\" alt=\"\" SRC=\"/icons/data.png\"></A>";
                }
                next;
            }
            # ---
            case 'FORM' {
                %G = readForm($gn);
                if ( -d "$WEBOBS{ROOT_OUTG}/FORM.$gn/$WEBOBS{PATH_OUTG_MAPS}" ) {
                    $visu = "<A href=\"/cgi-bin/showOUTG.pl?grid=FORM.$gn&ts=map\"><IMG border=\"0\" alt=\"$gn\" SRC=\"/icons/map.png\"></A>";
                }
                $data = "<A href=\"/cgi-bin/showGENFORM.pl?form=$gn\"><IMG border=\"0\" alt=\"$gn\" SRC=\"/icons/form.png\"></A>";
                next;
            }
            # ---
            case 'VIEW' {
                %G = readView($gn);
                if ( -d "$WEBOBS{ROOT_OUTG}/VIEW.$gn/$WEBOBS{PATH_OUTG_MAPS}" ) {
                    $visu = "<A href=\"/cgi-bin/showOUTG.pl?grid=VIEW.$gn&ts=map\"><IMG border=\"0\" alt=\"$gn\" SRC=\"/icons/map.png\"></A>";
                }
                next;
            }
            # --- some common things for PROC/FORM/VIEW (switch fall-through)
            case /PROC|FORM|VIEW/ {
                $search = "<A href='#popupY' title=\"$__{'Find text in $gt'}\" onclick='srchopenPopup(\"+$gt.$gn\");return false'><IMG class='ic' src='/icons/search.png'></A>";
                $transit = "<A href=\"/cgi-bin/gvTransit.pl?grid=PROC.$gn\")><IMG src=\"/icons/tmap.png\"></A>";
                if (WebObs::Users::clientHasAdm(type=>"auth".lc($gt)."s",name=>$gn)) {
                    $edit = "&nbsp;<A href=\"/cgi-bin/formGRID.pl?grid=$gt.$gn\" title=\"$__{'Edit $gt'}\" ><img src='/icons/modif.png'></A>";
                }
                $show = "/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=$gt.$gn";
                $nn = @{$G{$gn}{NODESLIST}}."&nbsp;".(defined($G{$gn}{NODE_NAME}) ? $G{$gn}{NODE_NAME}:"node")
                      .(@{$G{$gn}{NODESLIST}} > 1 ? "s":"");
            }
        }
        
        # common for all grid type
        if (%G) {
            my $desc = $G{$gn}{DESCRIPTION} // "";
            my $ovl = "onMouseOut=\"nd()\" onMouseOver=\"overlib('$desc',CAPTION,'$gt.$gn',BGCOLOR, '$gridColor{$gt}',FGCOLOR,'white')\"";
            $html .= "<TR>" if ($gn ne $g[0]);
            $html .= "<TD $ovl style=\"text-align: center\"><SPAN class=\"gridtype-".lc($gt)."\">$gt</SPAN></TD>\n" if ($subsetType ne "");
            $html .= "<TD $ovl>$search$transit$edit&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"$show\">$G{$gn}{NAME}</A></TD>\n"
                    ."<TD $ovl>$nn</TD>\n";
            $html .= "<TD $ovl>".(defined($G{$gn}{TYPE}) ? $G{$gn}{TYPE} : "")."</TD>\n"  if ($showType);
            $html .= "<TD $ovl>".(defined($G{$gn}{OWNCODE}) ? (
                            defined($OWNRS{$G{$gn}{OWNCODE}}) ? $OWNRS{$G{$gn}{OWNCODE}} : $G{$gn}{OWNCODE}
                        ) : "")."</TD>\n"  if ($showOwnr);
            $html .= "<TD $ovl style=\"text-align:center\">$visu</TD>\n";
            $html .= "<TD $ovl style=\"text-align:center\">$data</A></TD>\n";
            for (@grids) { if (/^$gt.$gn/) { s/$/|$G{$gn}{NAME}/; last; } }
        }
        $html .= "</TR>\n";
    }
    return $html;
}

# -----------------------------------------------------------------------------
# ---- helper edit grid popup
sub geditpopup {

    # prepares a list of grid's templates
    my @tplates;
    my @gt;
    push(@gt,"VIEW") if ($admVIEWS);
    push(@gt,"PROC,SEFRAN") if ($admPROCS);
    push(@gt,"FORM") if ($admFORMS);
    my @tmp = glob("$WEBOBS{ROOT_CODE}/tplates/{".join(',',@gt)."}.*");
    foreach my $t (@tmp) {
        if (! -l $t) {
            my @conf = readCfg($t);
            next if (@conf == 1);  # readCfg returns [0] if the file is empty
            my %G = @conf;
            $t =~ s/$WEBOBS{ROOT_CODE}\/tplates\///;
            my ($gt,$gn) = split(/\./,$t);
            push(@tplates,"$gt|$gn|$G{DESCRIPTION}");
        }
    }

    my $SP = "";
    $SP .= "<div id=\"geditovly\" style=\"display:none\"></div>";
    $SP .= "<form id=\"geditoverlay_form\" style=\"display:none\">";
    $SP .= "<p><b><i>Create/edit a GRID</i></b></p>";
    $SP .= "<label for=\"geditN\">$__{'Grid type'}: <span class=\"small\">$__{'select a template'}</span></label>";
    $SP .= "  <select size=\"1\" id=\"geditT\" name=\"geditT\">\n";
    foreach (@tplates) {
        my ($gt,$gn,$gl) = split(/\|/,$_);
        my $sel = "";
        $sel = "selected" if (($subsetType eq 'all' && $gt eq 'VIEW') || ($gt eq uc($subsetType) && $gn eq 'DEFAULT'));
        $SP .= "  <option value=\"$gt.$gn\" $sel>$gt: $gl</option>\n";
    }
    $SP .= "  </select>\n";
    $SP .= "<br style=\"clear: left\"><br>";

    $SP .= "<label for=\"geditN\">$__{'Grid name'}: <span class=\"small\">$__{'short name (uppercase)'}</span></label>";
    $SP .= "  <input size=\"40\" id=\"geditN\" name=\"geditN\" value=\"\">\n";
    $SP .= "<br style=\"clear: left\"><br>";

    $SP .= "<p style=\"margin: 0px; text-align: center\">";
    $SP .= "<input type=\"button\" name=\"sendbutton\" value=\"$__{'Create'}\" onclick=\"geditsendPopup(); return false;\" style=\"font-weight:bold\" />";
    $SP .= "<input type=\"button\" value=\"cancel\" onclick=\"geditclosePopup(); return false\" />";
    $SP .= "</p>";
    $SP .= "</form>";
    return $SP;
}

# ---- helper edit form popup
sub feditpopup {

    # prepares a list of form's templates
    my $SP = "";
    $SP .= "<div id=\"feditovly\" style=\"display:none\"></div>";
    $SP .= "<form id=\"feditoverlay_form\" style=\"display:none\">";
    $SP .= "<p><b><i>Create/edit a FORM</i></b></p>";
    $SP .= "<label for=\"feditT\">$__{'Form type'}: <span class=\"small\">$__{'select a template'}</span></label>";
    my $tdir = "$WEBOBS{ROOT_CODE}/tplates";
    opendir my $dir, ($tdir) or die "Cannot open directory: $!";
    my @templates = sort grep (/FORM\./, readdir($dir));
    closedir $dir;
    $SP .= "  <select id=\"feditTpl\" name=\"feditT\" value=\"\">\n";    # select input, look into CODE/tplates to find the differents templates
    foreach my $f (@templates) {
        if ($f =~ /FORM\./) {
            my %cfg = readCfg("$tdir/$f");
            my $sel = ($f eq "FORM.GENFORM" ? "selected":"");
            $SP .= "<option value=\"$f\" $sel>$f: $cfg{NAME}</option>";
        }
    }
    $SP .= "</select>";
    $SP .= "<br style=\"clear: left\"><br>";
    $SP .= "<label for=\"feditN\">$__{'Form name'}: <span class=\"small\">$__{'short name (uppercase)'}</span></label>";
    $SP .= "  <input size=\"40\" id=\"feditN\" name=\"feditN\" value=\"\">\n";

    $SP .= "<p style=\"margin: 0px; text-align: center\">";
    $SP .= "<input type=\"button\" name=\"sendbutton\" value=\"$__{'Create'}\" onclick=\"feditsendPopup(); return false;\" style=\"font-weight:bold\" />";
    $SP .= "<input type=\"button\" value=\"cancel\" onclick=\"feditclosePopup(); return false;\" />";
    $SP .= "</p>";
    $SP .= "</form>";
    return $SP;
}

__END__

=pod

=head1 AUTHOR(S)

François Beauducel, Didier Lafon

=head1 COPYRIGHT

WebObs - 2012-2026 - Institut de Physique du Globe Paris

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
