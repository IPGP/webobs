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
# ---- domains values
$QryParm->{'code'}      ||= "";
$QryParm->{'ooa'}       ||= "";
$QryParm->{'name'}      ||= "";
$QryParm->{'grid'}      ||= "";
$QryParm->{'marker'}    ||= "";
$QryParm->{'OLDcode'}   ||= "";
$QryParm->{'OLDgrid'}   ||= "";
# ---- producer values
$QryParm->{'id'}        ||= "";
$QryParm->{'pname'}     ||= "";
$QryParm->{'title'}     ||= "";
$QryParm->{'desc'}      ||= "";
$QryParm->{'objective'} ||= "";
$QryParm->{'meas_var'}  ||= "";
$QryParm->{'email'}     ||= "";
$QryParm->{'projectLeader'}  ||= "";
$QryParm->{'funders'}   ||= "";
$QryParm->{'resources'} ||= "";
my $authtable = "";
$authtable = $WEBOBS{SQL_TABLE_DOMAINS} if ($QryParm->{'tbl'} eq "domain") ;
$authtable = $WEBOBS{SQL_TABLE_PRODUCER} if ($QryParm->{'tbl'} eq "producer") ;
$authtable = $WEBOBS{SQL_TABLE_PGRIDS} if ($QryParm->{'tbl'} eq "grids2producers") ;


# ---- managing the single quote in SQLite3 query
# -----------------------------------------------------------------------------
my $title     = $QryParm->{'title'};
$title =~ s/'/''/g;
my $desc      = $QryParm->{'desc'};
$desc =~ s/'/''/g;
my $objective = $QryParm->{'objective'};
$objective =~ s/'/''/g;
my $meas_var  = $QryParm->{'meas_var'};
$meas_var =~ s/'/''/g;

# ---- process (execute) sql insert new row into table 'tbl'
# -----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'insert') {
	# query-string must contain all required DB columns values for an sql insert
	my $q='';
	my $rows;
	if ($QryParm->{'tbl'} eq "domain") {
		$q = "insert into $WEBOBS{SQL_TABLE_DOMAINS} values(\'$QryParm->{'code'}\',\'$QryParm->{'ooa'}\',\'$QryParm->{'name'}\',\'$QryParm->{'marker'}\')";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
		my $rows = dbu($WEBOBS{SQL_DOMAINS},$q);
	} elsif ($QryParm->{'tbl'} eq "producer") {
		$q = "insert into $WEBOBS{SQL_TABLE_PRODUCER} values(\'$QryParm->{'id'}\',\'$QryParm->{'pname'}\',\'$title\',\'$QryParm->{'desc'}\',\'$QryParm->{'objective'}\',\'$QryParm->{'meas_var'}\',\'$QryParm->{'email'}\',\'$QryParm->{'projectLeader'}\',\'$QryParm->{'funders'}\',\'$QryParm->{'resources'}\')";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
		my $rows = dbu($WEBOBS{SQL_METADATA},$q);
	} else { die "$QryParm->{'action'} for unknown table"; }
	$$refMsg  .= ($rows == 1) ? "  having inserted new $QryParm->{'tbl'} " : $QryParm->{'title'}."  failed to insert new $QryParm->{'tbl'}";
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows == 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql update a row of table 'tbl'
# ----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'update') {
	# query-string must contain all required DB columns values for an sql insert
	my $q='';
	my $rows;
	if ($QryParm->{'tbl'} eq "domain") {
		$q = "update $WEBOBS{SQL_TABLE_DOMAINS} set CODE=\'$QryParm->{'code'}\', OOA=\'$QryParm->{'ooa'}\', NAME=\'$QryParm->{'name'}\', MARKER=\'$QryParm->{'marker'}\'";
		$q .= " WHERE CODE=\'$QryParm->{'OLDcode'}\'";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
		my $rows = dbu($WEBOBS{SQL_DOMAINS},$q);
	} elsif ($QryParm->{'tbl'} eq "producer"){
		$q = "update $WEBOBS{SQL_TABLE_PRODUCER} set IDENTIFIER=\'$QryParm->{'id'}\', NAME=\'$QryParm->{'pname'}\', TITLE=\'$QryParm->{'title'}\', DESCRIPTION=\'$QryParm->{'desc'}\', OBJECTIVE=\'$QryParm->{'objective'}\', MEASUREDVARIABLES=\'$QryParm->{'meas_var'}\', EMAIL=\'$QryParm->{'email'}\', CONTACTS=\'$QryParm->{'projectLeader'}\', FUNDERS=\'$QryParm->{'funders'}\', RESOURCES=\'$QryParm->{'resources'}\'";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
		my $rows = dbu($WEBOBS{SQL_METADATA},$q);
	} else { die "$QryParm->{'action'} for unknown table"; }
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
	my $rows = dbuow($WEBOBS{SQL_DOMAINS},$q0,$q1,$q2,$q3);
	$domainMsg  .= ($rows >= 1 || $q2 eq "") ? "  having updated $WEBOBS{SQL_TABLE_GRIDS} " : "  failed to update $WEBOBS{SQL_TABLE_GRIDS}";
	$domainMsg  .= " $lastDBIerrstr";
	$domainMsgColor  = ($rows >= 1 || $q2 eq "") ? "green" : "red";
}
# ---- process (execute) sql update table 'grids2producers' after user insert or update
# ----------------------------------------------------------------------------
if (($QryParm->{'action'} eq 'insert' || $QryParm->{'action'} eq 'update') && $QryParm->{'tbl'} eq "producer") {
	my @grids = $cgi->param('grid');
	my $q0 = "insert into $WEBOBS{SQL_TABLE_PGRIDS} values (\'+++\',\'\',\'$QryParm->{'id'}\')";
	my $q1 = "delete from $WEBOBS{SQL_TABLE_PGRIDS} WHERE PID=\'$QryParm->{'id'}\' AND TYPE != \'+++\'";
	my $q2 = "";
	if (@grids > 0 && $grids[0] ne "") {
		my @values = map { "(\'".join("\',\'",split(/\./,$_))."\',\'$QryParm->{'id'}\')" } @grids ;
		$q2 = "insert or replace into $WEBOBS{SQL_TABLE_PGRIDS} VALUES ".join(',',@values);
	} 
	my $q3 = "delete from $WEBOBS{SQL_TABLE_PGRIDS} WHERE PID=\'$QryParm->{'id'}\' AND TYPE = \'+++\'";
	my $rows = dbuow($WEBOBS{SQL_METADATA},$q0,$q1,$q2,$q3);
	$domainMsg  .= ($rows >= 1 || $q2 eq "") ? "  having updated $WEBOBS{SQL_TABLE_PGRIDS} " : "  failed to update $WEBOBS{SQL_TABLE_PGRIDS}";
	$domainMsg  .= " $lastDBIerrstr";
	$domainMsgColor  = ($rows >= 1 || $q2 eq "") ? "green" : "red";
}
=pod
# ---- process (execute) sql update table 'contacts' after user insert or update
# ----------------------------------------------------------------------------
if (($QryParm->{'action'} eq 'insert' || $QryParm->{'action'} eq 'update') && $QryParm->{'tbl'} eq "producer") {
	my @grids = $cgi->param('grid');
	my $q0 = "insert into $WEBOBS{SQL_TABLE_CONTACTS} values (\'+++\',\'\',\'$QryParm->{'id'}\')";
	my $q1 = "delete from $WEBOBS{SQL_TABLE_CONTACTS} WHERE PID=\'$QryParm->{'id'}\' AND TYPE != \'+++\'";
	my $q2 = "";
	if (@grids > 0 && $grids[0] ne "") {
		my @values = map { "(\'".join("\',\'",split(/\./,$_))."\',\'$QryParm->{'id'}\')" } @grids ;
		$q2 = "insert or replace into $WEBOBS{SQL_TABLE_CONTACTS} VALUES ".join(',',@values);
	} 
	my $q3 = "delete from $WEBOBS{SQL_TABLE_CONTACTS} WHERE PID=\'$QryParm->{'id'}\' AND TYPE = \'+++\'";
	my $rows = dbuow($WEBOBS{SQL_METADATA},$q0,$q1,$q2,$q3);
	$domainMsg  .= ($rows >= 1 || $q2 eq "") ? "  having updated $WEBOBS{SQL_TABLE_CONTACTS} " : "  failed to update $WEBOBS{SQL_TABLE_CONTACTS}";
	$domainMsg  .= " $lastDBIerrstr";
	$domainMsgColor  = ($rows >= 1 || $q2 eq "") ? "green" : "red";
}
# ---- process (execute) sql update table 'organisations' after user insert or update
# ----------------------------------------------------------------------------
if (($QryParm->{'action'} eq 'insert' || $QryParm->{'action'} eq 'update') && $QryParm->{'tbl'} eq "producer") {
	my @grids = $cgi->param('grid');
	my $q0 = "insert into $WEBOBS{SQL_TABLE_ORGANISATIONS} values (\'+++\',\'\',\'$QryParm->{'id'}\')";
	my $q1 = "delete from $WEBOBS{SQL_TABLE_ORGANISATIONS} WHERE PID=\'$QryParm->{'id'}\' AND TYPE != \'+++\'";
	my $q2 = "";
	if (@grids > 0 && $grids[0] ne "") {
		my @values = map { "(\'".join("\',\'",split(/\./,$_))."\',\'$QryParm->{'id'}\')" } @grids ;
		$q2 = "insert or replace into $WEBOBS{SQL_TABLE_ORGANISATIONS} VALUES ".join(',',@values);
	} 
	my $q3 = "delete from $WEBOBS{SQL_TABLE_ORGANISATIONS} WHERE PID=\'$QryParm->{'id'}\' AND TYPE = \'+++\'";
	my $rows = dbuow($WEBOBS{SQL_METADATA},$q0,$q1,$q2,$q3);
	$domainMsg  .= ($rows >= 1 || $q2 eq "") ? "  having updated $WEBOBS{SQL_TABLE_ORGANISATIONS} " : "  failed to update $WEBOBS{SQL_TABLE_ORGANISATIONS}";
	$domainMsg  .= " $lastDBIerrstr";
	$domainMsgColor  = ($rows >= 1 || $q2 eq "") ? "green" : "red";
} 
=cut
# ---- process (execute) sql delete a row of table 'tbl'
# ------------------------------------------------------
if ($QryParm->{'action'} eq 'delete') {
	my $q='';
	my $rows;
	# query-string must contain all required DB columns values for an sql insert
	if ($QryParm->{'tbl'} eq "domain") {
		$q = "delete from $WEBOBS{SQL_TABLE_DOMAINS}";
		$q .= " WHERE CODE=\'$QryParm->{'code'}\'";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
		my $rows = dbu($WEBOBS{SQL_DOMAINS},$q);
	} elsif ($QryParm->{'tbl'} eq "producer") {
		$q = "delete from $WEBOBS{SQL_TABLE_PRODUCER}";
		$q .= " WHERE IDENTIFIER=\'$QryParm->{'id'}\'";
		$refMsg = \$domainMsg; $refMsgColor = \$domainMsgColor;
		my $rows = dbu($WEBOBS{SQL_METADATA},$q);
	} else { die "$QryParm->{'action'} for unknown table"; }
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

# ---- build 'producer' table result rows
# -----------------------------------------------------------------------------
my $qproducers  = "select IDENTIFIER,p.NAME,TITLE,DESCRIPTION,OBJECTIVE,MEASUREDVARIABLES,EMAIL,CONTACTS,FUNDERS,ONLINERESOURCE,group_concat(TYPE || '.' || g.NAME) AS $WEBOBS{SQL_TABLE_PGRIDS}";
$qproducers .= " from $WEBOBS{SQL_TABLE_PRODUCER} p left join $WEBOBS{SQL_TABLE_PGRIDS} g on (IDENTIFIER = g.PID)";
$qproducers .= " group by IDENTIFIER";
@qrs = qx(sqlite3 $WEBOBS{SQL_METADATA} "$qproducers");
chomp(@qrs);
my $pproducers = '';
my $pproducersCount = 0;
my $pproducersId = '';
for (@qrs) {
	(my $pproducers_did, my $pproducers_name, my $pproducers_title, my $pproducers_desc, my $pproducers_objective, my $pproducers_meas, my $pproducers_email, my $pproducers_contacts, my $pproducers_funders, my $pproducers_res, my $pproducers_grids) = split(/\|/,$_);
	$pproducersCount++; $pproducersId="p_udef".$pproducersCount;
	$pproducers .= "<tr id=\"$pproducersId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"openPopupProducer($pproducersId,'$WEBOBS{SQL_TABLE_PRODUCER}');return false\"><img title=\"edit producer\" src=\"/icons/modif.png\"></a>";
	$pproducers .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"postDeleteProducer($pproducersId);return false\"><img title=\"delete producer\" src=\"/icons/no.png\"></a>";
	$pproducers .= "<td>$pproducers_did</td><td nowrap>$pproducers_name</td><td>$pproducers_title</td><td>$pproducers_desc</td><td>$pproducers_objective</td><td>$pproducers_meas</td><td>$pproducers_email</td><td>$pproducers_contacts</td><td>$pproducers_funders</td><td>$pproducers_res</td><td>".join(", ",$pproducers_grids)."</td></tr>\n";
}

# ---- read 'typeOrganisation' table in WEBOBSMETA.db
# -----------------------------------------------------------------------------
my $driver   = "SQLite";
my $database = "/opt/webobs/CONF/WEBOBSMETA.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
#print "Opened database successfully\n";

my $stmt = qq(SELECT type, name FROM typeOrganisation;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my @types;
my @names;

while(my @row = $sth->fetchrow_array()) {
	my $type = $row[0];
	my $name = $row[1];
    push(@types, $type);
    push(@names, $name);
}

my $stmt = qq(SELECT type, name FROM typeResource;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my @resources;
my @resNames;

while(my @row = $sth->fetchrow_array()) {
	my $resource = $row[0];
	my $resName = $row[1];
    push(@resources, $resource);
    push(@resNames, $resName);
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
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#id1');">
Domains&nbsp;$go2top
</div>
<div id="id1">
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

<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#id2');">
Producers&nbsp;$go2top
</div>
<div id="id2">
	<div id="domainMsg" style="font-weight: bold; color: $domainMsgColor">&bull; $domainMsg</div><br/>
	<form id="overlay_form_producer" class="overlay_form" style="display:none">
	<input type="hidden" name="action" value="">
	<input type="hidden" name="tbl" value="">
	<input type="hidden" name="OLDcode" value="">
	<input type="hidden" name="OLDgrid" value="">
	
	<!-- Champs obligatoires du formulaire -->
	<p><b><i>Edit producer definition</i><span class="small">Mandatory fields</span></b></p>
	<label>Identifier:<span class="small"></span></label>
	<input type="text" name="id" value=""/><br/>
	<label>Name:<span class="small"></span></label>
	<input type="text" name="pname" value=""/><br/>
	<label>Title:<span class="small"></span></label>
	<input type="text" name="title" value=""/><br/>
	<label>Description:<span class="small"></span></label>
	<input type="text" name="desc" value=""/><br/><br/>
	<label>Email:<span class="small"></span></label>
	<input type="text" name="email" value=""/><br/><br/>
	<label>Contacts:<span class="small">Project leader</span></label>
	<input type="text" name="projectLeader" value=""/><br/><br/>
	<label>Contacts:</label>
	<button onclick="addMgr();return false;">Add a data manager</button>
	<button onclick="removeMgr();return false;">Remove a data manager</button></br></br>
	<input type='hidden' name="mgr" value='0'></input>
	<div id='div_mgr'></div>
	<label>Funders:</label>
	<button onclick="addFnd();return false;">Add a funder</button>
	<button onclick="removeFnd();return false;">Remove a funder</button></br></br>
	<input type='hidden' name="count_fnd" value='1'></input>
	<input type='hidden' name='funders' value=''></input>
	<div id='div_fnd'>
		<label>Funder:<span class="small">Type</span></label>
		<select name="typeFunders">
			<option value=$types[0]>$names[0]</option>
            <option value=$types[1]>$names[1]</option>
            <option value=$types[2]>$names[2]</option>
            <option value=$types[3]>$names[3]</option>
            <option value=$types[4]>$names[4]</option>
            <option value=$types[5]>$names[5]</option>
            <option value=$types[6]>$names[6]</option>
            <option value=$types[7]>$names[7]</option>
		</select>
		<label>Funder:<span class="small">Organisation name</span></label>
		<input type='text' name="nameFunders"></input>
		<label>Funder:<span class="small">Organisation ScanR ID</span></label>
		<input type='text' name="scanRFunders"></input>
	</div>
	<div id='div_fnd_2'></div>
	
	<label for="gid">Grid(s):<span class="small">associated grid(s)<br>Ctrl for multiple</span></label>
	<select name="grid" id="grid" size="5" multiple>$selgrids</select><br/>
	<p style="margin: 0px; text-align: center">
	
	<!-- Champs recommandés du formulaire -->
	<p><b><i>Edit producer definition</i><span class="small">Recommended fields</span></b></p>
	<label>Objective:<span class="small"></span></label>
	<input type="text" name="objective" value=""/><br/>
	<label>Measured variables:<span class="small"></span></label>
	<input type="text" name="meas_var" value=""/><br/>
	
	<!-- Champs optionnels du formulaire -->
	<p><b><i>Edit producer definition</i><span class="small">Optional fields</span></b></p>
	<label>Online resources:</label>
	<button onclick="addRes();return false;">Add a resource</button>
	<button onclick="removeRes();return false;">Remove a resource</button></br></br>
	<input type='hidden' name="res" value='1'></input>
	<input type='hidden' name='resources' value=''></input>
	<div id='div_res'>
		<label>Online resource:<span class="small">Type</span></label>
		<select name='typeRes'>
			<option value=$resources[0]>$resNames[0]</option>
            <option value=$resources[1]>$resNames[1]</option>
            <option value=$resources[2]>$resNames[2]</option>
            <option value=$resources[3]>$resNames[3]</option>
		</select>
		<label>Online resource:<span class="small">URL</span></label>
		<input type='text' name='nameRes'></input>
	</div>
	<div id='div_res_2'></div>
	
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopupProducer(); return false; " /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	
	</form>
	<fieldset id="producers-field"><legend><b>Producers</b></legend>
		<div style="background: #BBB">
			<b>$pproducersCount</b> producers defined
		</div>
		<div class="dproducers-container">
			<div class="dproducers">
				<table class="dproducers">
				<thead><tr><th style=\"width:12px\"><a href="#IDENT" onclick="openPopupProducer(-1);return false"><img title="define a new producer" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Id</th><th>Name</th><th>Title</th><th>Description</th><th>Objective</th><th>MeasuredVariables</th><th>Email</th><th>Contacts</th><th>Funders</th><th>Resources</th><th>Grids</th>
				</tr></thead>
				<tbody>
				$pproducers
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
	$lastDBIerrstr = "";;
	my $dbh = DBI->connect("dbi:SQLite:dbname=".$_[0], '', '') or die "$DBI::errstr" ;
	my $rv = $dbh->do($_[1]);
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
	my $dbh = DBI->connect("dbi:SQLite:dbname=".$_[0],{AutoCommit => 0, RaiseError => 1,}) or die "$DBI::errstr" ;
	eval {
		$dbh->do($_[1]);
		$dbh->do($_[2]);
		$rv = $dbh->do($_[3]) if ($_[3] ne "");
		$dbh->do($_[4]);
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
