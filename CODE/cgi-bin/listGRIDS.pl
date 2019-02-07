#!/usr/bin/perl 

=head1 NAME

listGRIDS.pl 

=head1 SYNOPSIS

http://..../listGRIDS.pl[?type={all | view | proc}][&domain=domspec]

=head1 DESCRIPTION

Displays GRIDS names and summary (specifications), grouped by DOMAINS, themselves ordered by their OOA (Order Of Appearance).
Default, when no type= specified, is to display all GRIDS (VIEWS and PROCS)

=head1 Query string parameters

=over

=item B<type={all | view | proc}>

list B<all> GRIDS or B<view>s only or B<proc>s only

=item B<domain=domspec>

domspec := { domainCODE }
only list grids that belong to a domain 

=back

=cut

use strict;
use warnings;

$|=1;
use Time::Local;
use File::Basename;
use Data::Dumper;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use Switch;

use WebObs::Config;
use WebObs::Grids;
use WebObs::Users;
use WebObs::Utils;
use WebObs::Search;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

my $me = $ENV{SCRIPT_NAME};

my %GRID;
my %G;
my $GRIDName = my $GRIDType = my $RESOURCE = "";

my $QryParm  = $cgi->Vars;
my $subsetDomain = $QryParm->{'domain'}   || "";
my $subsetType   = lc($QryParm->{'type'}) || 'all';
   $subsetType   = 'all' if ( $subsetType ne 'proc' && $subsetType ne 'view');

my $showType = (defined($GRIDS{SHOW_TYPE}) && ($GRIDS{SHOW_TYPE} eq 'N')) ? 0 : 1;
my $showOwnr = (defined($GRIDS{SHOW_OWNER}) && ($GRIDS{SHOW_OWNER} eq 'N')) ? 0 : 1;

my $today = qx(/bin/date +\%Y-\%m-\%d);
chomp($today);

my $htmlcontents = "";
my $editOK   = 0;
my $descGridType = my $descGridName = my $descLegacy = "";

if ($subsetDomain ne '') {
	$descGridType = 'DOMAIN';
	$descGridName = $subsetDomain;
} else {
	$descGridType = 'GRIDS';
	switch ($subsetType) {
		case 'all' { $descGridName = 'ALL'; }
		case 'view' { $descGridName = 'VIEWS'; $descLegacy = 'VIEW.VIEWS'; }
		case 'proc' { $descGridName = 'PROCS'; $descLegacy = 'PROC.PROCS'; };
	}
}

# gets the domains list
my $Wclause = ($subsetDomain ne "") ? " where CODE = '$subsetDomain' " : " "; 
my @domains = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "select CODE,NAME from $WEBOBS{SQL_TABLE_DOMAINS} $Wclause order by OOA");
chomp(@domains);

# edition is allowed only if the user has edit authorization for ALL grids (views and procs)
if ( WebObs::Users::clientHasEdit(type=>"authviews",name=>"*") && WebObs::Users::clientHasEdit(type=>"authprocs",name=>"*")) {
	$editOK = 1
};

# ---- Start HTML page 
#
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<HTML><HEAD><title>GRIDS</title>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";
print "<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>";
print "<script language=\"JavaScript\" src=\"/js/htmlFormsUtils.js\" type=\"text/javascript\"></script>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/search.css\">";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/listGRIDS.css\">";
print "</head><body onLoad=\"scrolldivHeight()\">";

# ---- Title is = selected type (aka subsetType)
#
print "<A NAME=\"MYTOP\"></A>";
print "<H1 style=\"margin-bottom:6px\">";
	print "$DOMAINS{$subsetDomain}{NAME} " if ($subsetDomain ne "");
	print "$GRIDS{SHOW_GRIDS_TITLE}\n" if ($subsetType eq 'all');
	print "Views" if ($subsetType eq 'view');
	print "Procs" if ($subsetType eq 'proc');
print "</H1>\n";

# ---- Subtitle menu to other domains/grids displays
#
print "<P>»» [ <A href=\"/cgi-bin/vsearch.pl\"><IMG src=\"/icons/rsearch.png\" border=0 title=\"Search node's events\"></A> All";
print " ".($subsetType ne 'all' || $subsetDomain ne '' ? "<A href=\"$me\">Grids</A>":"<B>Grids</B>");
print " | ".($subsetType ne 'proc' || $subsetDomain ne '' ? "<A href=\"$me?type=proc\">Procs</A>":"<B>Procs</B>");
print " | ".($subsetType ne 'view' || $subsetDomain ne '' ? "<A href=\"$me?type=view\">Views</A>":"<B>Views</B>");
if ($subsetDomain eq '') {
	print " - Domains:";
	for (@domains) {
		my ($dc,$dn) = split(/\|/,$_);
		print " ".($_ ne $domains[0] ? "| ":"")."<A href=\"$me?domain=$dc&type=$subsetType\">$dn</A>";
	}
} else {
	print " - $DOMAINS{$subsetDomain}{NAME}";
	print " ".($subsetType ne 'all' ? "<A href=\"$me?domain=$subsetDomain\">Grids</A>":"<B>Grids</B>");
	print " | ".($subsetType ne 'proc' ? "<A href=\"$me?domain=$subsetDomain&type=proc\">Procs</A>":"<B>Procs</B>");
	print " | ".($subsetType ne 'view' ? "<A href=\"$me?domain=$subsetDomain&type=view\">Views</A>":"<B>Views</B>");
}
print " ]</P>";

# ---- Objectives (aka 'Purpose', 'description' of subsetType) 
#
printdesc('Purpose','DESCRIPTION',$descGridType,$descGridName,$descLegacy);


# ---- list subsetType grids, grouped by domains
#
print "<div id=\"noscrolldiv\">";
	my $d = my $p = my $v = 0;
	if ( $#domains >= 0) {

		# ---- The invisible-until-triggered-by-js popups ;-)
		print "<a name=\"popupY\"></a>";
		print WebObs::Search::searchpopup();
		print geditpopup();
		
		# ---- The GRIDS table
		#
		print "\n<CENTER><TABLE WIDTH=\"90%\" id=\"gtable\" style=\"vertical-align: top\">\n";

		print "<TR>";
		print "<TH>Domain</TH>" if ($subsetDomain eq "");
		print "<TH>Grid</TH>" if ($subsetType ne "");
		print "<TH><a href='#popupY' title=\"$__{'Find text in Grids'}\" onclick='srchopenPopup(\"*ALL\");return false'><img class='ic' src='/icons/search.png'></a>";
		if (WebObs::Users::clientHasAdm(type=>"authviews",name=>"*") && WebObs::Users::clientHasAdm(type=>"authprocs",name=>"*") ) { 
			print "&nbsp;<a href='#popupY' title=\"$__{'Edit/Create a Grid'}\" onclick='geditopenPopup();return false'><img class='ic' src='/icons/modif.png'></a>" 
		}
		print     "&nbsp;&nbsp;&nbsp;Name</TH>";
		print "<TH>Nodes</TH>";
		print "<TH>Type</TH>"  if ($showType);
		print "<TH>Owner</TH>" if ($showOwnr);
		print "<TH>Graphs</TH>";
		print "<TH>Raw Data</TH>" if ($subsetType eq 'all' || $subsetType eq 'proc');
		print "</TR>\n";
		for $d (@domains) {
			my ($dc,$dn) = split(/\|/,$d);
			my @procs;
			if ($subsetType eq 'all' || $subsetType eq 'proc') {
				@procs = qx(sqlite3 $WEBOBS{SQL_DOMAINS} \"select TYPE,NAME from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = 'PROC' and DCODE = '$dc' order by name\");
				chomp(@procs);
				@procs = grep {my @gna=split(/\|/,$_); WebObs::Users::clientHasRead(type=>"authprocs",name=>$gna[1])} @procs;
			}
			my $np = scalar(@procs);
			my @views;
			if ($subsetType eq 'all' || $subsetType eq 'view') {
				@views = qx(sqlite3 $WEBOBS{SQL_DOMAINS} \"select TYPE,NAME from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = 'VIEW' and DCODE = '$dc' order by name\");
				chomp(@views);
				@views = grep {my @gna=split(/\|/,$_); WebObs::Users::clientHasRead(type=>"authviews",name=>$gna[1])} @views;
			}
			my $nv = scalar(@views);
			my $domrows = $np+$nv;
			if ( $domrows > 0 ) {
				print "<TR>";
				#print "<TD rowspan=\"$domrows\" style=\"vertical-align: center\"><h2 class=\"h2gn\">$dn <sup>($dc)</sup></h2>";
				print "<TD rowspan=\"$domrows\" style=\"vertical-align: center\"><h2 class=\"h2gn\"><A href=\"$me?domain=$dc&type=$subsetType\">$dn</A></h2>" if ($subsetDomain eq "");
				if ( $np > 0 ) {
					for $p (@procs) {
						my ($dp,$vp) = split(/\|/,$p);
						my %G = readProc($vp);
						if (%G) {
							print "<TR>" if ($p ne $procs[0]);
							print "<TD style=\"text-align: center\">PROC</TD>" if ($subsetType ne "");
							print "<TD><a href='#popupY' title=\"$__{'Find text in Proc'}\" onclick='srchopenPopup(\"+PROC.$vp\");return false'><img class='ic' src='/icons/search.png'></a>";
							print     "<a href='/cgi-bin/gvTransit.pl?grid=PROC.$vp')><img src=\"/icons/tmap.png\"></a>";
							if (WebObs::Users::clientHasEdit(type=>"authprocs",name=>$vp)) { print "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=PROC.$vp\" title=\"$__{'Edit Proc'}\" ><img src='/icons/modif.png'></a>" }
							print     "&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=PROC.$vp\">$G{$vp}{NAME}</a>";
							print "</TD>";
							print "<TD>".scalar(@{$G{$vp}{NODESLIST}})."&nbsp;";
							if (defined($G{$vp}{NODE_NAME})) { printf ("%s%s","$G{$vp}{NODE_NAME}",scalar(@{$G{$vp}{NODESLIST}})>1?"s":"") }
							else                            { printf ("node%s",scalar(@{$G{$vp}{NODESLIST}})>1?"s":"") }
							print "</TD>";
							print "<TD>$G{$vp}{TYPE}</TD>"  if ($showType);
							print "<TD>".(defined($OWNRS{$G{$vp}{OWNCODE}}) ? $OWNRS{$G{$vp}{OWNCODE}}:$G{$vp}{OWNCODE})."</TD>"  if ($showOwnr);
							if ( -d "$WEBOBS{ROOT_OUTG}/PROC.$vp/$WEBOBS{PATH_OUTG_GRAPHS}" ) {
								print "<TD style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=PROC.$vp\"><IMG border=\"0\" alt=\"$vp\" SRC=\"/icons/visu.png\"></A>";
							} elsif ( -d "$WEBOBS{ROOT_OUTG}/PROC.$vp/$WEBOBS{PATH_OUTG_EVENTS}" ) {
								print "<TD  style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=PROC.$vp&ts=events\"><IMG border=\"0\" alt=\"$vp\" SRC=\"/icons/visu.png\"></A>";
							} else { print "<TD style=\"background-color: #EEEEDD\">&nbsp;" }
							print "</TD>";
							print "<TD style=\"text-align:center\">";
							if (defined($G{$vp}{FORM}) && $G{$vp}{FORM} ne '') {
								my %F = readCfg("$WEBOBS{PATH_FORMS}/$G{$vp}{FORM}/$G{$vp}{FORM}.conf");
								print "<A HREF=\"/cgi-bin/$F{CGI_SHOW}?node={$vp}\" title=\"$F{TITLE}\"><IMG border=\"0\" alt=\"$G{$vp}{FORM}\" SRC=\"/icons/form.png\"></A>";
							} else { 
								if (defined($G{$vp}{URNDATA}) && $G{$vp}{URNDATA} ne '') {
									print "<A HREF=\"$G{$vp}{URNDATA}\"><IMG border=\"0\" alt=\"$G{$vp}{FORM}\" SRC=\"/icons/data.png\"></A>";
								} 
							}
							print "</TD>";
						}
						print "</TR>\n"; 
					}
				}
				if ( $nv > 0 ) {
					for $v (@views) {
						my ($dv,$vn) = split(/\|/,$v);
						my %G = readView($vn);
						if (%G) {
							print "<TR>" if ($np > 0 || $v ne $views[0]);
							print "<TD style=\"text-align: center\">VIEW</TD>";
							print "<TD><a href='#popupY' title=\"$__{'Find text in View'}\" onclick='srchopenPopup(\"+VIEW.$vn\");return false'><img class='ic' src='/icons/search.png'></a>";
							print     "<a href='/cgi-bin/gvTransit.pl?grid=VIEW.$vn')><img src=\"/icons/tmap.png\"></a>";
							if (WebObs::Users::clientHasEdit(type=>"authviews",name=>$vn)) { print "&nbsp;<a href=\"/cgi-bin/formGRID.pl?grid=VIEW.$vn\" title=\"$__{'Edit View'}\" ><img src='/icons/modif.png'></a>" }
							print     "&nbsp;&nbsp;<a style=\"font-weight: bold\" href=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=VIEW.$vn\">$G{$vn}{NAME}</a>";
							print "<TD>".scalar(@{$G{$vn}{NODESLIST}})."&nbsp;";
							if (defined($G{$vn}{NODE_NAME})) { printf ("%s%s","$G{$vn}{NODE_NAME}",scalar(@{$G{$vn}{NODESLIST}})>1?"s":"") } 
							else                            { printf ("node%s",scalar(@{$G{$vn}{NODESLIST}})>1?"s":"") }
							print "<TD>$G{$vn}{TYPE}</TD>"  if ($showType);
							print "<TD>".(defined($OWNRS{$G{$vn}{OWNCODE}}) ? $OWNRS{$G{$vn}{OWNCODE}}:$G{$vn}{OWNCODE})."</TD>"  if ($showOwnr);
							if ( -d "$WEBOBS{ROOT_OUTG}/VIEW.$vn/$WEBOBS{PATH_OUTG_MAPS}" ) {
								print "<TD style=\"text-align:center\"><A HREF=\"/cgi-bin/showOUTG.pl?grid=VIEW.$vn\"><IMG border=\"0\" alt=\"$vn\" SRC=\"/icons/visu.png\"></A>";
							} else { print "<TD>&nbsp;" }
							print "</TD>";
							if ($subsetType eq 'all' || $subsetType eq 'proc') {
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
		if (-e $legacyfileDesc) { qx(cp $legacyfileDesc $fileDesc) }
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
	#FB-was: my @tmp = qx(ls $WEBOBS{ROOT_CODE}/tplates/{VIEW,PROC}.*);
	my @tmp = qx(ls $WEBOBS{ROOT_CODE}/tplates/VIEW.* $WEBOBS{ROOT_CODE}/tplates/PROC.*);
	chomp(@tmp);
	foreach (@tmp) {
		my $t = $_;
		my %G = readCfg($t);
		$t =~ s/$WEBOBS{ROOT_CODE}\/tplates\///;
		my ($gt,$gn) = split(/\./,$t);
		push(@tplates,"$gt|$gn|".u2l($G{NAME}));
	}

	my $SP = "";
	$SP .= "<div id=\"geditovly\" style=\"display:none\"></div>";
	$SP .= "<form id=\"geditoverlay_form\" style=\"display:none\">";
	$SP .= "<p><b><i>Create/edit a GRID</i></b></p>";
	$SP .= "<label for=\"geditN\">$__{'Grid Type'}: <span class=\"small\">select a template</span></label>";
	$SP .= "  <select size=\"1\" id=\"geditT\" name=\"geditT\">\n";
	foreach (@tplates) {
		my ($gt,$gn,$gl) = split(/\|/,$_);
		my $sel = "";
		$sel = "selected" if (($subsetType eq 'all' && $gt eq 'VIEW') || ($gt eq uc($subsetType) && $gn eq 'DEFAULT'));
		$SP .= "  <option value=\"$gt.$gn\" $sel>$gt: $gl</option>\n";
	}
	$SP .= "  </select>\n";
	$SP .= "<br style=\"clear: left\"><br>";

	$SP .= "<label for=\"geditN\">$__{'Grid Name'}: <span class=\"small\">short name (uppercase)</span></label>";
	$SP .= "  <input size=\"40\" id=\"geditN\" name=\"geditN\" value=\"\">\n";
	$SP .= "<br style=\"clear: left\"><br>";

	$SP .= "<p style=\"margin: 0px; text-align: center\">";
	$SP .= "<input type=\"button\" name=\"sendbutton\" value=\"$__{'Edit'}\" onclick=\"geditsendPopup(); return false;\" style=\"font-weight:bold\" />";
	$SP .= "<input type=\"button\" value=\"cancel\" onclick=\"geditclosePopup(); return false\" />";
	$SP .= "</p>";
	$SP .= "</form>";
	return $SP;
}

__END__

=pod

=head1 AUTHOR(S)

François Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2016 - Institut de Physique du Globe Paris

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

