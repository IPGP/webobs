#!/usr/bin/perl

=head1 NAME

gridsMgr.pl

=head1 SYNOPSIS

/cgi-bin/gridsMgr.pl?....see query string below ....

=head1 DESCRIPTION

Builds html page for WebObs' grids Manager. Displays all 'DOMAINS' DataBase tables and
provides maintenance functions on these tables: insert new rows, delete rows, updates rows.

First apply the maintenance function (action+tbl) if requested, then build page to display all tables.

=head1 QUERY-STRING PARAMETERS

=over

=item B<action=>

One of { display | insert | update | delete } . Defaults to 'display' .
'insert', 'update' and 'delete' require a 'tbl' (table to act upon).

=item B<tbl=>

{ domain | notification | proc | view | form | wiki | misc } .

=item B<code=>, B<name=>, B<ooa=>, B<marker=>

Any, depending on requested maintenance function (action+tbl)

=back

=cut

use strict;
use warnings;
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime/;
use File::Basename;
use File::Path qw/make_path/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use DBI;
use IO::Socket;
use WebObs::Config;
use WebObs::Grids;
$|=1;

set_message(\&webobs_cgi_msg);

# ---- checks/defaults query-string elements
my $QryParm   = $cgi->Vars;
$QryParm->{'action'}    ||= 'display';

# ---- some globals
my $go2top = "&nbsp;&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";
my @qrs;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));
my $domainMsg="$buildTS ";
my $domainMsgColor='black';
my $refMsg = my $refMsgColor = "";
my $lastDBIerrstr = "";

# ---- any reasons why we couldn't go on ?
# ----------------------------------------
if ( ! WebObs::Users::clientHasAdm(type=>"authmisc",name=>"grids")) {
	die "You are not authorized" ;
}

# ---- parse/defaults query string
# -----------------------------------------------------------------------------
$QryParm->{'action'}    ||= "display";
$QryParm->{'tbl'}       ||= "";
$QryParm->{'code'}      ||= "";
$QryParm->{'ooa'}       ||= "";
$QryParm->{'name'}      ||= "";
$QryParm->{'grid'}      ||= "";
$QryParm->{'marker'}    ||= "";
$QryParm->{'OLDcode'}   ||= "";
$QryParm->{'OLDgrid'}   ||= "";
my $authtable = "";
$authtable = $WEBOBS{SQL_TABLE_DOMAINS} if ($QryParm->{'tbl'} eq "domain") ;

# ---- process (execute) sql insert new row into table 'tbl'
# -----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'insert') {
	# query-string must contain all required DB columns values for an sql insert
	my $q='';
	if ($QryParm->{'tbl'} eq "domain") {
		$q = "insert into $WEBOBS{SQL_TABLE_DOMAINS} values(\'$QryParm->{'code'}\',\'$QryParm->{'ooa'}\',\'$QryParm->{'name'}\',\'$QryParm->{'marker'}\')";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
	} else { die "$QryParm->{'action'} for unknown table"; }
	my $rows = dbu($q);
	$$refMsg  .= ($rows == 1) ? "  having inserted new $QryParm->{'tbl'} " : "  failed to insert new $QryParm->{'tbl'}";
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows == 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql update a row of table 'tbl'
# ----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'update') {
	# query-string must contain all required DB columns values for an sql insert
	my $q='';
	if ($QryParm->{'tbl'} eq "domain") {
		$q = "update $WEBOBS{SQL_TABLE_DOMAINS} set CODE=\'$QryParm->{'code'}\', OOA=\'$QryParm->{'ooa'}\', NAME=\'$QryParm->{'name'}\', MARKER=\'$QryParm->{'marker'}\'";
		$q .= " WHERE CODE=\'$QryParm->{'OLDcode'}\'";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
	} else { die "$QryParm->{'action'} for unknown table"; }
	my $rows = dbu($q);
	$$refMsg  .= ($rows == 1) ? "  having updated $QryParm->{'tbl'} " : "  failed to update $QryParm->{'tbl'}";
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows == 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql update table 'grids2domains' after user insert or update
# ----------------------------------------------------------------------------
if (($QryParm->{'action'} eq 'insert' || $QryParm->{'action'} eq 'update') && $QryParm->{'tbl'} eq "domain") {
	my @grids = $cgi->param('grid');
	my $q0 = "insert into $WEBOBS{SQL_TABLE_GRIDS} values (\'+++\',\'\',\'$QryParm->{'code'}\')";
	my $q1 = "delete from $WEBOBS{SQL_TABLE_GRIDS} WHERE DCODE=\'$QryParm->{'code'}\' AND TYPE != \'+++\'";
	my $q2 = "";
	if (@grids > 0 && $grids[0] ne "") {
		my @values = map { "(\'".join("\',\'",split(/\./,$_))."\',\'$QryParm->{'code'}\')" } @grids ;
		$q2 = "insert or replace into $WEBOBS{SQL_TABLE_GRIDS} VALUES ".join(',',@values);
	}
	my $q3 = "delete from $WEBOBS{SQL_TABLE_GRIDS} WHERE DCODE=\'$QryParm->{'code'}\' AND TYPE = \'+++\'";
	my $rows = dbuow($q0,$q1,$q2,$q3);
	$domainMsg  .= ($rows >= 1 || $q2 eq "") ? "  having updated $WEBOBS{SQL_TABLE_GRIDS} " : "  failed to update $WEBOBS{SQL_TABLE_GRIDS}";
	$domainMsg  .= " $lastDBIerrstr";
	$domainMsgColor  = ($rows >= 1 || $q2 eq "") ? "green" : "red";
}
# ---- process (execute) sql delete a row of table 'tbl'
# ------------------------------------------------------
if ($QryParm->{'action'} eq 'delete') {
	my $q='';
	# query-string must contain all required DB columns values for an sql insert
	if ($QryParm->{'tbl'} eq "domain") {
		$q = "delete from $WEBOBS{SQL_TABLE_DOMAINS}";
		$q .= " WHERE CODE=\'$QryParm->{'code'}\'";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
	} else { die "$QryParm->{'action'} for unknown table"; }
	my $rows = dbu($q);
	$$refMsg  .= ($rows >= 1) ? "  having deleted in $QryParm->{'tbl'} " : "  failed to delete in $QryParm->{'tbl'}";
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows >= 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql delete
# ---------------------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'deleteU') {
	if ($QryParm->{'tbl'} eq "group") {
		my $q = "delete from $WEBOBS{SQL_TABLE_GROUPS} where GID=\'$QryParm->{'gid'}\'";
		my $rows = dbu($q);
		$domainMsg  .= ($rows >= 1) ? "  having deleted $QryParm->{'tbl'}" : "  failed to delete $QryParm->{'tbl'}";
		$domainMsg  .= " $lastDBIerrstr";
		$domainMsgColor  = ($rows >= 1) ? "green" : "red";
	}
}

# ---- start html page
# --------------------
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print <<"EOHEADER";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Grids Manager</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/grids.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/grids.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/htmlFormsUtils.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript">
\$(document).ready(function(){
Gscriptname = \"$ENV{SCRIPT_NAME}\"; // required by grids.js
});
</script>
</head>
EOHEADER

# ---- build grids 'select dropdowns contents'
# -----------------------------------------------------------------------------
#[FBnote:] listing grids from grids2domains table does not see orphan grids
#my $qugrids  = "select distinct(TYPE || '.' || NAME) from $WEBOBS{SQL_TABLE_GRIDS} order by NAME";
#@qrs   = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "$qugrids");
#chomp(@qrs);
#my $selgrids = ""; map { $selgrids .= "<option>$_</option>" } @qrs;

# get all existing GRIDs
my @T;
push(@T, map({"VIEW.$_"} sort(WebObs::Grids::listViewNames())));
push(@T, map({"PROC.$_"} sort(WebObs::Grids::listProcNames())));
push(@T, map({"SEFRAN.$_"} sort(WebObs::Grids::listSefranNames())));
my $selgrids = ""; map { $selgrids .= "<option>$_</option>" } @T;


# ---- build 'domains' table result rows
# -----------------------------------------------------------------------------
my $qdomains  = "select CODE,OOA,d.NAME,MARKER,group_concat(TYPE || '.' || g.NAME) AS $WEBOBS{SQL_TABLE_GRIDS}";
$qdomains .= " from $WEBOBS{SQL_TABLE_DOMAINS} d left join $WEBOBS{SQL_TABLE_GRIDS} g on (d.CODE = g.DCODE)";
$qdomains .= " group by d.CODE order by d.OOA";
@qrs = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "$qdomains");
chomp(@qrs);
my $ddomains = '';
my $ddomainsCount = 0;
my $ddomainsId = '';
for (@qrs) {
	(my $ddomains_did, my $ddomains_order, my $ddomains_name, my $ddomains_marker, my $ddomains_grids) = split(/\|/,$_);
	$ddomainsCount++; $ddomainsId="udef".$ddomainsCount;
	$ddomains .= "<tr id=\"$ddomainsId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"openPopupDomain($ddomainsId,'$WEBOBS{SQL_TABLE_DOMAINS}');return false\"><img title=\"edit domain\" src=\"/icons/modif.png\"></a>";
	$ddomains .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"postDeleteDomain($ddomainsId);return false\"><img title=\"delete domain\" src=\"/icons/no.png\"></a>";
	$ddomains .= "<td>$ddomains_did</td><td>$ddomains_order</td><td nowrap>$ddomains_name</td><td>$ddomains_marker</td><td>".join(", ",split(/,/,$ddomains_grids))."</td></tr>\n";
}



# ---- assemble the page
# -----------------------------------------------------------------------------
print <<"EOPART1";
<body style="min-height: 600px;">
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>

<A NAME="MYTOP"></A>
<h1>WebObs Grids Manager</h1>

<P class="subMenu"> <b>&raquo;&raquo;</b> [ <a href="#DOMAIN">Domain</a> | <a href="/cgi-bin/listGRIDS.pl">All Grids</a> ]</P>
<br>

<div id="ovly" style="display: none"></div>

<A NAME="IDENT"></A>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#idID');">
Domains&nbsp;$go2top
</div>
<div id="idID">
	<div id="domainMsg" style="font-weight: bold; color: $domainMsgColor">&bull; $domainMsg</div><br/>
	<form id="overlay_form_domain" class="overlay_form" style="display:none">
	<input type="hidden" name="action" value="">
	<input type="hidden" name="tbl" value="">
	<input type="hidden" name="OLDcode" value="">
	<input type="hidden" name="OLDgrid" value="">
	<p><b><i>Edit domain definition</i></b></p>
	<label>Id:<span class="small">Code (short)</span></label>
	<input type="text" name="code" value=""/><br/>
	<label>Name:<span class="small">Domain name</span></label>
	<input type="text" name="name" value=""/><br/>
	<label>Rank:<span class="small">display order</span></label>
	<input type="text" name="ooa" value=""/><br/>
	<label>Marker:<span class="small">marker symbol</span></label>
	<input type="text" name="marker" value=""/><br/>
	<label for="gid">Grid(s):<span class="small">associated grid(s)<br>Ctrl for multiple</span></label>
	<!--<input type="text" name="grid" id="grid" value=""/><br/>-->
	<select name="grid" id="grid" size="5" multiple>$selgrids</select><br/>
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopupDomain(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>
	<fieldset id="domains-field"><legend><b>Domains</b></legend>
		<div style="background: #BBB">
			<b>$ddomainsCount</b> domains defined
		</div>
		<div class="ddomains-container">
			<div class="ddomains">
				<table class="ddomains">
				<thead><tr><th style=\"width:12px\"><a href="#IDENT" onclick="openPopupDomain(-1);return false"><img title="define a new domain" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Id</th><th>Rank</th><th>Name</th><th>Marker</th><th>Grids</th>
				</tr></thead>
				<tbody>
				$ddomains
				</tbody>
				</table>
			</div>
		</div>
	</fieldset>

</div>
</div>
EOPART1

print "</TR></TABLE>";
print "</div>";
print "</div>";

# ---- That's all folks: end html
print "<br>\n</body>\n</html>\n";
exit;

# ---- helper: execute the non-select sql statement in $_[0]
# ------------------------------------------------------------------------------
sub dbu {
	$lastDBIerrstr = "";
	my $dbh = DBI->connect("dbi:SQLite:dbname=$WEBOBS{SQL_DOMAINS}", '', '') or die "$DBI::errstr" ;
	my $rv = $dbh->do($_[0]);
	$rv = 0 if ($rv == 0E0);
	$lastDBIerrstr = sprintf("(%d row%s) %s",$rv,($rv<=1)?"":"s",$DBI::errstr);
	$dbh->disconnect();
	return $rv;
}

# ---- helper: execute the sql unit of work made up of $_[0]...$_[3] sql statements
# ------------------------------------------------------------------------------
sub dbuow {
	$lastDBIerrstr = "";
	my $rv = 0;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$WEBOBS{SQL_DOMAINS}", '', '',{AutoCommit => 0, RaiseError => 1,}) or die "$DBI::errstr" ;
	eval {
		$dbh->do($_[0]);
		$dbh->do($_[1]);
		$rv = $dbh->do($_[2]) if ($_[2] ne "");
		$dbh->do($_[3]);
		$rv = 0 if ($rv == 0E0);
		$lastDBIerrstr = sprintf("(%d row%s) %s",$rv,($rv<=1)?"":"s",$DBI::errstr);
		$dbh->commit();
	};
	if ($@) {
        $rv = 0;
		$lastDBIerrstr = sprintf("(0 row) %s",$@);
		$dbh->rollback();
	}
	$dbh->disconnect();
	return $rv;
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel

=head1 COPYRIGHT

Webobs - 2019 - Institut de Physique du Globe Paris

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
