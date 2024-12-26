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

my $htmlcontents = "";
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
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
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
printdesc('Purpose','DESCRIPTION',$descGridType,$descGridName,$descLegacy);


# ---- list subsetType grids, grouped by domains
#
print "<div id=\"noscrolldiv\">";
	my $d = my $p = my $v = 0;
	if (@$domains) {

		# ---- The invisible-until-triggered-by-js popups ;-)
		print "<a name=\"popupY\"></a>";
		print WebObs::Search::searchpopup();
		print geditpopup();
		print feditpopup();

		# ---- The GRIDS table
		#
		print "\n<CENTER><TABLE WIDTH=\"90%\" id=\"gtable\" style=\"vertical-align: top\">\n";

		print "<TR>";
		if ($subsetDomain eq "") {
			print "<TH>";
			if (WebObs::Users::clientHasAdm(type=>"authmisc",name=>"*")) {
				print "&nbsp;<a href='/cgi-bin/gridsMgr.pl' title=\"$__{'Edit/Create a Domain/Producer'}\"><img class='ic' src='/icons/modif.png'></a>&nbsp;&nbsp;&nbsp;";
			}
			print "Domain</TH>";
		}
		print "<TH>Grid</TH>" if ($subsetType ne "");
		print "<TH><a href='#popupY' title=\"$__{'Find text in Grids'}\" onclick='srchopenPopup(\"*ALL\");return false'><img class='ic' src='/icons/search.png'></a>";
		if ($admVIEWS || $admPROCS || $admFORMS) {
			print "&nbsp;<a href='#popupY' title=\"$__{'Edit/Create a Grid'}\" onclick='geditopenPopup();return false'><img class='ic' src='/icons/modif.png'></a>"
		}
		print     "&nbsp;&nbsp;&nbsp;Name</TH>";
		print "<TH>Nodes</TH>";
		print "<TH>Type</TH>"  if ($showType);
		print "<TH>Owner</TH>" if ($showOwnr);
		print "<TH>Graphs</TH>";
		if ($wantProcs || $wantSefrans) {
			#	print "<a href='#popupY' title=\"$__{'Edit/Create a Form'}\" onclick='feditopenPopup(); return false;'><img class='ic' src='/icons/modif.png'></a>";
			print "<TH>Raw Data</TH>";
		}
		print "</TR>\n";
		for my $d (@$domains) {
			my ($dc, $dn) = @$d;
			my @procs;
			my $ovl;
			if ($wantProcs) {
				@procs = grep(WebObs::Users::clientHasRead(type=>"authprocs", name=>$_), @{$domainProcs{$dc}});
			}
			my $np = scalar(@procs);
			my @forms;
			if ($wantForms) {
				@forms = grep(WebObs::Users::clientHasRead(type=>"authforms", name=>$_), @{$domainForms{$dc}});
			}
			my $nf = scalar(@forms);
			my @views;
			if ($wantViews) {
				@views = grep(WebObs::Users::clientHasRead(type=>"authviews", name=>$_), @{$domainViews{$dc}});
			}
			my $nv = scalar(@views);
			my @sefrans;
			if ($wantSefrans) {
				@sefrans = grep(WebObs::Users::clientHasRead(type=>"authprocs", name=>$_),
                              @{$domainSefrans{$dc}});
			}
			my $ns = scalar(@sefrans);
			my $domrows = $np+$nv+$ns;
			if ( $domrows > 0 ) {
				print "<TR>";
				print "<TD rowspan=\"$domrows\" style=\"vertical-align: center\"><h2 class=\"h2gn\"><A href=\"$me?domain=$dc&type=$subsetType\">$dn</A></h2>" if ($subsetDomain eq "");
				if ( $ns > 0 ) {
					for my $vs (@sefrans) {
						my %G = readSefran($vs);
						if (%G) {
							print "<TR>" if ($vs ne $sefrans[0]);
							print "<TD style=\"text-align: center\">SEFRAN</TD>" if ($subsetType ne "");
							$ovl = " onMouseOut=\"nd()\" onMouseOver=\"overlib('".$G{$vs}{DESCRIPTION}."',CAPTION,'SEFRAN.$vs')\"";
							print "<TD $ovl>";
							if (WebObs::Users::clientHasEdit(type=>"authprocs",name=>$G{$vs}{MC3_NAME})) { print "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=SEFRAN.$vs\" title=\"$__{'Edit Sefran'}\" ><img src='/icons/modif.png'></a>" }
							print     "&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"/cgi-bin/sefran3.pl?s3=$vs&header=1\">$G{$vs}{NAME}</a>";
							print "</TD>";
							print "<TD>".(split('\|',$G{$vs}{CHANNELLIST}))." channels</TD>";
							print "<TD>".(defined($G{$vs}{TYPE}) ? $G{$vs}{TYPE} : "")."</TD>"  if ($showType);
							print "<TD>".(defined($G{$vs}{OWNCODE}) ?
										  (defined($OWNRS{$G{$vs}{OWNCODE}})
										   ? $OWNRS{$G{$vs}{OWNCODE}}
										   : $G{$vs}{OWNCODE}) : "")
									."</TD>"  if ($showOwnr);
							if ( -d "$G{$vs}{ROOT}" ) {
								print "<TD style=\"text-align:center\"><A HREF=\"/cgi-bin/sefran3.pl?s3=$vs&header=1\"><IMG border=\"0\" alt=\"$vs\" SRC=\"/icons/visu.png\"></A>";
							} else { print "<TD style=\"background-color: #EEEEDD\">&nbsp;" }
							print "</TD>";
							print "<TD style=\"text-align:center\">";
							if (defined($G{$vs}{MC3_NAME}) && $G{$vs}{MC3_NAME} ne '') {
								my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$G{$vs}{MC3_NAME}.conf");
								print "<A HREF=\"/cgi-bin/mc3.pl?mc=$G{$vs}{MC3_NAME}\" title=\"$MC3{TITLE}\"><IMG border=\"0\" alt=\"$G{$vs}{MC3_NAME}\" SRC=\"/icons/form.png\"></A>";
							}
							print "</TD>";
						}
						print "</TR>\n";
					}
				}
				if ( $np > 0 ) {
					for my $vp (@procs) {
						my %G = readProc($vp);
						if (%G) {
							print "<TR>" if ($vp ne $procs[0]);
							print "<TD style=\"text-align: center\">PROC</TD>" if ($subsetType ne "");
							$ovl = " onMouseOut=\"nd()\" onMouseOver=\"overlib('".$G{$vp}{DESCRIPTION}."',CAPTION,'PROC.$vp')\"";
							print "<TD $ovl><a href='#popupY' title=\"$__{'Find text in Proc'}\" onclick='srchopenPopup(\"+PROC.$vp\");return false'><img class='ic' src='/icons/search.png'></a>";
							print     "<a href='/cgi-bin/gvTransit.pl?grid=PROC.$vp')><img src=\"/icons/tmap.png\"></a>";
							if (WebObs::Users::clientHasEdit(type=>"authprocs",name=>$vp)) { print "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=PROC.$vp\" title=\"$__{'Edit Proc'}\" ><img src='/icons/modif.png'></a>" }
							print     "&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=PROC.$vp\">$G{$vp}{NAME}</a>";
							print "</TD>";
							print "<TD>".scalar(@{$G{$vp}{NODESLIST}})."&nbsp;";
							if (defined($G{$vp}{NODE_NAME})) { printf ("%s%s","$G{$vp}{NODE_NAME}",scalar(@{$G{$vp}{NODESLIST}})>1?"s":"") }
							else                            { printf ("node%s",scalar(@{$G{$vp}{NODESLIST}})>1?"s":"") }
							print "</TD>";
							print "<TD>".(defined($G{$vp}{TYPE}) ? $G{$vp}{TYPE} : "")
									."</TD>"  if ($showType);
							print "<TD>".(defined($G{$vp}{OWNCODE}) ?
										  (defined($OWNRS{$G{$vp}{OWNCODE}})
										   ? $OWNRS{$G{$vp}{OWNCODE}}
										   : $G{$vp}{OWNCODE}) : "")
									."</TD>"  if ($showOwnr);
							if ( -d "$WEBOBS{ROOT_OUTG}/PROC.$vp/$WEBOBS{PATH_OUTG_GRAPHS}" ) {
								print "<TD style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=PROC.$vp\"><IMG border=\"0\" alt=\"$vp\" SRC=\"/icons/visu.png\"></A>";
							} elsif ( -d "$WEBOBS{ROOT_OUTG}/PROC.$vp/$WEBOBS{PATH_OUTG_EVENTS}" ) {
								print "<TD  style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=PROC.$vp&ts=events\"><IMG border=\"0\" alt=\"$vp\" SRC=\"/icons/visu.png\"></A>";
							} else { print "<TD style=\"background-color: #EEEEDD\">&nbsp;" }
							print "</TD>";
							print "<TD style=\"text-align:center\">";
							if (defined($G{$vp}{FORM}) && $G{$vp}{FORM} ne '') {
								my %F = readCfg("$WEBOBS{PATH_FORMS}/$G{$vp}{FORM}/$G{$vp}{FORM}.conf");
								print "<A HREF=\"/cgi-bin/showGENFORM.pl?form=$G{$vp}{FORM}\" title=\"$F{TITLE}\"><IMG border=\"0\" alt=\"$G{$vp}{FORM}\" SRC=\"/icons/form.png\"></A>";
							} else {
								if (defined($G{$vp}{URNDATA}) && $G{$vp}{URNDATA} ne '') {
									print "<A HREF=\"$G{$vp}{URNDATA}\"><IMG border=\"0\" alt=\""
											.(defined($G{$vp}{FORM}) ? $G{$vp}{FORM} : "")
											."\" SRC=\"/icons/data.png\"></A>";
								}
							}
							print "</TD>";
						}
						print "</TR>\n";
					}
				}
				if ( $nf > 0 ) {
					for my $vf (@forms) {
						my %G = readForm($vf);
						if (%G) {
							print "<TR>" if ($vf ne $forms[0]);
							print "<TD style=\"text-align: center\">FORM</TD>" if ($subsetType ne "");
							$ovl = " onMouseOut=\"nd()\" onMouseOver=\"overlib('".$G{$vf}{DESCRIPTION}."',CAPTION,'FORM.$vf')\"";
							print "<TD $ovl><a href='#popupY' title=\"$__{'Find text in Form'}\" onclick='srchopenPopup(\"+FORM.$vf\");return false'><img class='ic' src='/icons/search.png'></a>";
							print     "<a href='/cgi-bin/gvTransit.pl?grid=FORM.$vf')><img src=\"/icons/tmap.png\"></a>";
							if (WebObs::Users::clientHasEdit(type=>"authforms",name=>$vf)) { print "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=FORM.$vf\" title=\"$__{'Edit Form'}\" ><img src='/icons/modif.png'></a>" }
							print     "&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=FORM.$vf\">$G{$vf}{NAME}</a>";
							print "</TD>";
							print "<TD>".scalar(@{$G{$vf}{NODESLIST}})."&nbsp;";
							if (defined($G{$vf}{NODE_NAME})) { printf ("%s%s","$G{$vf}{NODE_NAME}",scalar(@{$G{$vf}{NODESLIST}})>1?"s":"") }
							else                            { printf ("node%s",scalar(@{$G{$vf}{NODESLIST}})>1?"s":"") }
							print "</TD>";
							print "<TD>".(defined($G{$vf}{TYPE}) ? $G{$vf}{TYPE} : "")
									."</TD>"  if ($showType);
							print "<TD>".(defined($G{$vf}{OWNCODE}) ?
										  (defined($OWNRS{$G{$vf}{OWNCODE}})
										   ? $OWNRS{$G{$vf}{OWNCODE}}
										   : $G{$vf}{OWNCODE}) : "")
									."</TD>"  if ($showOwnr);
							if ( -d "$WEBOBS{ROOT_OUTG}/FORM.$vf/$WEBOBS{PATH_OUTG_MAPS}" ) {
								print "<TD style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=PROC.$vf\"><IMG border=\"0\" alt=\"$vf\" SRC=\"/icons/visu.png\"></A>";
							} else { print "<TD style=\"background-color: #EEEEDD\">&nbsp;" }
							print "</TD>";
							print "<TD style=\"text-align:center\">";
							print "<A HREF=\"/cgi-bin/showGENFORM.pl?form=$vf\"><IMG border=\"0\" alt=\"$vf\" SRC=\"/icons/form.png\"></A>";
							print "</TD>";
						}
						print "</TR>\n";
					}
				}
				if ( $nv > 0 ) {
					for my $vn (@views) {
						my %G = readView($vn);
						if (%G) {
							print "<TR>" if ($np > 0 || $vn ne $views[0]);
							print "<TD style=\"text-align: center\">VIEW</TD>";
							$ovl = " onMouseOut=\"nd()\" onMouseOver=\"overlib('".$G{$vn}{DESCRIPTION}."',CAPTION,'VIEW.$vn')\"";
							print "<TD $ovl><a href='#popupY' title=\"$__{'Find text in View'}\" onclick='srchopenPopup(\"+VIEW.$vn\");return false'><img class='ic' src='/icons/search.png'></a>";
							print     "<a href='/cgi-bin/gvTransit.pl?grid=VIEW.$vn')><img src=\"/icons/tmap.png\"></a>";
							if (WebObs::Users::clientHasEdit(type=>"authviews",name=>$vn)) { print "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=VIEW.$vn\" title=\"$__{'Edit View'}\" ><img src='/icons/modif.png'></a>" }
							print     "&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=VIEW.$vn\">$G{$vn}{NAME}</a>";
							print "<TD>".scalar(@{$G{$vn}{NODESLIST}})."&nbsp;";
							if (defined($G{$vn}{NODE_NAME})) { printf ("%s%s","$G{$vn}{NODE_NAME}",scalar(@{$G{$vn}{NODESLIST}})>1?"s":"") }
							else                            { printf ("node%s",scalar(@{$G{$vn}{NODESLIST}})>1?"s":"") }
							print "<TD>".(defined($G{$vn}{TYPE}) ?  $G{$vn}{TYPE} : "")."</TD>"
									if ($showType);
							print "<TD>".(defined($G{$vn}{OWNCODE})  ?
										  (defined($OWNRS{$G{$vn}{OWNCODE}})
										   ? $OWNRS{$G{$vn}{OWNCODE}}
										   : $G{$vn}{OWNCODE}) : "")
									."</TD>"  if ($showOwnr);
							if ( -d "$WEBOBS{ROOT_OUTG}/VIEW.$vn/$WEBOBS{PATH_OUTG_MAPS}" ) {
								print "<TD style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=VIEW.$vn\"><IMG border=\"0\" alt=\"$vn\" SRC=\"/icons/visu.png\"></A>";
							} else { print "<TD>&nbsp;" }
							print "</TD>";
							if ($wantProcs) {
								print "<TD style=\"background-color: #EEEEDD\"></TD>";
							}
						}
						print "</TR>\n";
					}
				}
			}
		}
		print "</TABLE></CENTER><BR>";
	} else {
		print "<h3>** No domain defined or matching '$subsetDomain' **</h3>";
	}
print "</div>\n";

# ---- Protocole (aka 'Informations' of subsetType)
#
printdesc('Information','PROTOCOLE',$descGridType,$descGridName,$descLegacy,1);

# ---- Bibiography (aka 'References' of subsetType)
#
printdesc('References','BIBLIO',$descGridType,$descGridName,$descLegacy,1);

# ---- We're done !
print "</BODY>\n</HTML>\n";

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# printdesc (title,suffix,type,name,legacy,[top])
sub printdesc {
	my @desc;
	my $editCGI = "/cgi-bin/gedit.pl";
	my $go2top = "";

	my $title = $_[0];
	my $suffix = $GRIDS{"$_[1]_SUFFIX"};
	my $type = $_[2];
	my $name = $_[3];
	my $fileDesc = "$WEBOBS{PATH_GRIDS_DOCS}/$type.$name$suffix";
	if ($_[4] ne '' &&  ! -e $fileDesc) {
		my $legacyfileDesc = "$WEBOBS{PATH_GRIDS_DOCS}/$_[4]$suffix";
		if (-e $legacyfileDesc) {
			copy($legacyfileDesc, $fileDesc);
		}
	}
	if (defined($_[5])) {
		$go2top = "&nbsp;&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";
	}

	if (-e $fileDesc) {
		@desc = readFile($fileDesc);
	}
	my $htmlcontents = "<div class=\"drawer\"><div class=\"drawerh2\" >&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#$_[1]ID');\">&nbsp;&nbsp;";
	$htmlcontents .= "$__{$title}";
	if ($editOK == 1) { $htmlcontents .= "&nbsp;&nbsp;<A href=\"$editCGI\?file=$suffix\&grid=$type.$name\"><img src=\"/icons/modif.png\"></A>" }
	$htmlcontents .= "$go2top</div><div id=\"$_[1]ID\"><BR>";
	if ($#desc >= 0) { $htmlcontents .= "<P>".WebObs::Wiki::wiki2html(join("",@desc))."</P>\n" }
	$htmlcontents .= "</div></div>\n";

	print $htmlcontents;
}

# -----------------------------------------------------------------------------
# ---- helper edit grid popup
sub geditpopup {
	# prepares a list of grid's templates
	my @tplates;
	my @gt;
	push(@gt,"VIEW") if ($admVIEWS);
	push(@gt,"PROC,SEFRAN") if ($admPROCS);
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

	$SP .= "<label for=\"geditN\">$__{'Grid mame'}: <span class=\"small\">$__{'short name (uppercase)'}</span></label>";
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
	$SP .= "  <select id=\"feditTpl\" name=\"feditT\" value=\"\">\n";	# select input, look into CODE/tplates to find the differents templates
	foreach my $f (@templates) {
		if ($f =~ /FORM\./) {
			my %cfg = readCfg("$tdir/$f");
			my $sel = ($f eq "FORM.GENFORM" ? "selected":"");
			$SP .= "<option value=\"$f\" $sel>$f: $cfg{TITLE}</option>";
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

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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
