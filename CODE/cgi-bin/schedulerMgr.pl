#!/usr/bin/perl

=head1 NAME

schedulerMgr.pl

=head1 SYNOPSIS

/cgi-bin/schedulerMgr.pl?....see query string list below ....

=head1 DESCRIPTION

Builds html page for WebObs' scheduler Manager. This page contains
the following two areas:

the B<jobs scheduler status> , showing the scheduler's status information as dynamically obtained
from the scheduler's built-in UDP commands handler (CMD STAT)

the B<jobs definitions table> , from which client can insert/update/delete WebObs jobs

=head1 Query string parameters

An empty query-string acts as I</cgi-bin/schedulerMgr.pl?action=display>

=over

=item B<scheduler=>

internal/debug use only: the name of the WebObs scheduler process from which configuration and pid filenames are built.

=item B<action=>

{ display | insert | update | delete | submit } . Defaults to 'display' . 'update', 'delete' and 'submit' require a 'jid'

=item B<jid=>

Jobs definition table "job's ID" that is the target of 'update' , 'delete' or 'submit' actions.

=item B<newjid>, B<res>, B<xeq1=>, B<xeq2=>, B<xeq3>, B<interval=>, B<maxload=>, B<valid=>

the values for the correponding columns in the 'jid' (which can be replaced with 'newjid') row of the JOBS definition table.

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
use Try::Tiny;
use IO::Socket;
use WebObs::Config;
use WebObs::Users;
use WebObs::Scheduler qw(scheduler_client);
$|=1;

set_message(\&webobs_cgi_msg);

# ---- checks/defaults query-string elements
my $QryParm   = $cgi->Vars;
$QryParm->{'action'}    ||= 'display';
$QryParm->{'scheduler'} ||= 'scheduler';

# ---- builds scheduler's log and pid filenames
my $schedLog  = $QryParm->{'scheduler'}.".log";
my $schedPidF = $QryParm->{'scheduler'}.".pid";

# ----
my %SCHED;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));

# ---- any reasons why we couldn't go on ?
# ----------------------------------------
if ( ! WebObs::Users::clientHasRead(type=>"authmisc",name=>"scheduler")) {
	die "You are not authorized to access the Scheduler" ;
}
my $editOK = my $admOK = 0;
$admOK  = 1 if (WebObs::Users::clientHasAdm(type=>"authmisc",name=>"scheduler"));
$editOK = 1 if (WebObs::Users::clientHasEdit(type=>"authmisc",name=>"scheduler"));

if (defined($WEBOBS{ROOT_LOGS})) {
	# if ( -f "$WEBOBS{ROOT_LOGS}/$schedLog" ) {
		if (defined($WEBOBS{CONF_SCHEDULER}) && -e $WEBOBS{CONF_SCHEDULER} ) {
			%SCHED = readCfg($WEBOBS{CONF_SCHEDULER});
			if (! -e $SCHED{SQL_DB_JOBS} ) { die "Couldn't find jobs database"}
		} else { die "Couldn't find scheduler configuration" }
	#} else { die "Couldn't find log $WEBOBS{ROOT_LOGS}/$schedLog" }
} else { die "No ROOT_LOGS defined" }


# Function definitions --------------------------------------------------------

sub db_connect {
	# Open a connection to a SQLite database using RaiseError.
	#
	# Usage example:
	#   my $dbh = db_connect($WEBOBS{SQL_DB_POSTBOARD})
	#     || die "Error connecting to $dbname: $DBI::errstr";
	#
	my $dbname = shift;
	return DBI->connect("dbi:SQLite:$dbname", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		})
}

sub execute_query {
	# Connect to a database and run the given SQL statement,
	# raising an error if anything goes wrong.
	my $dbname = shift;
	my $query = shift;

	my $dbh = db_connect($dbname);
	if (not $dbh) {
		logit("Error connecting to $dbname: $DBI::errstr");
		return;
	}
	my $rv;
	try {
		$rv = $dbh->do($query);
	} catch {
		# Catch errors in update as they are handled in the script.
        # Note: $sth->err and $DBI::err are true if error was from DBI.
		# Try::Tiny puts the error into $_
        warn "Error while executing query '$query': $_";
	};
	$dbh->disconnect()
		or warn "Got warning while disconnecting from $dbname: "
				. $dbh->errstr;

	return $rv == 0E0 ? 0 : $rv;
}

sub fetch_all {
	# Connect to a database, run the given SQL statement, and
	# return a reference to an array of array references.
	my $dbname = shift;
	my $query = shift;

	my $dbh = db_connect($dbname);
	if (not $dbh) {
		logit("Error connecting to $dbname: $DBI::errstr");
		return;
	}
	# Will raise an error if anything goes wrong
	my $ref = $dbh->selectall_arrayref($query);

	$dbh->disconnect()
		or warn "Got warning while disconnecting from $dbname: "
				. $dbh->errstr;
	return $ref;
}



# ---- Read CGI parameters
# ------------------------------------------------------------------------------
$QryParm->{'jid'}         ||= "";
$QryParm->{'newjid'}      ||= "";
$QryParm->{'xeq1'}        ||= "";
$QryParm->{'xeq2'}        ||= "";
$QryParm->{'xeq3'}        ||= "";
$QryParm->{'runinterval'} ||= "";
$QryParm->{'maxsysload'}  ||= 0.7;
$QryParm->{'logpath'}     ||= "";
$QryParm->{'validity'}    ||= "N";
$QryParm->{'res'}         ||= "";

$QryParm->{'xeq1'} =~ s/'/''/g;
$QryParm->{'xeq2'} =~ s/'/''/g;
$QryParm->{'xeq3'} =~ s/'/''/g;


# ---- now process special actions (insert, update or delete a job's definition)
# ------------------------------------------------------------------------------
my $jobsdefsMsg='';
my $jobsdefsMsgColor='black';
#DBcols: JID, VALIDITY, RES, XEQ1, XEQ2, XEQ3, RUNINTERVAL, MAXSYSLOAD, LOGPATH, LASTSTRTS

if ($admOK && $QryParm->{'action'} eq 'insert') {
	# query-string must contain all required DB columns values for an sql insert
	my $q = "INSERT INTO jobs VALUES('$QryParm->{'jid'}','$QryParm->{'validity'}',"
	        ."'$QryParm->{'res'}','$QryParm->{'xeq1'}','$QryParm->{'xeq2'}',"
	        ."'$QryParm->{'xeq3'}',$QryParm->{'runinterval'},"
	        ."$QryParm->{'maxsysload'},'$QryParm->{'logpath'}',0)";
	my $rows = execute_query($SCHED{SQL_DB_JOBS}, $q);
	$jobsdefsMsg  = ($rows == 1)
		? "  having inserted new job "
		: "  failed to insert new job ";
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($editOK && $QryParm->{'action'} eq 'update') {
	# query-string must contain all required DB columns values for an sql update
	my $q = "UPDATE jobs SET JID='$QryParm->{'newjid'}', VALIDITY='$QryParm->{'validity'}',"
	        ." RES='$QryParm->{'res'}', XEQ1='$QryParm->{'xeq1'}', XEQ2='$QryParm->{'xeq2'}',"
	        ." XEQ3='$QryParm->{'xeq3'}', RUNINTERVAL=$QryParm->{'runinterval'},"
	        ." MAXSYSLOAD=$QryParm->{'maxsysload'}, LOGPATH='$QryParm->{'logpath'}'"
	        ." WHERE jid=\"$QryParm->{'jid'}\"";
	my $rows = execute_query($SCHED{SQL_DB_JOBS}, $q);
	$jobsdefsMsg  = ($rows == 1) ? "  having updated " : "  failed to update ";
	$jobsdefsMsg .= "jid $QryParm->{'jid'} ";   # $jobsdefsMsg .= $q;
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($admOK && $QryParm->{'action'} eq 'delete') {
	# query-string must contain the JID to be deleted from DB
	my $rows = execute_query($SCHED{SQL_DB_JOBS},
	                         "DELETE FROM jobs WHERE jid='$QryParm->{'jid'}'");
	$jobsdefsMsg  = ($rows == 1) ? "  having deleted " : "  failed to delete ";
	$jobsdefsMsg .= "jid $QryParm->{'jid'}";
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($QryParm->{'action'} eq 'submit') {
	# query-string must contain the JID to be submitted to scheduler
	my ($response, $error) = scheduler_client("job jid=$QryParm->{'jid'}");
	my $timestamp = strftime("%H:%M:%S %z", localtime(int(time())));
	$jobsdefsMsg  = "submit $QryParm->{'jid'} run at $timestamp : $response"
	                .($error ? " got error '$error'" : "");
	$jobsdefsMsgColor  = $error ? "red" : "green";
}


# ---- start html page
# --------------------
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print <<"EOHEADER";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Scheduler Manager</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/transit.css">
<link rel="stylesheet" type="text/css" href="/css/scheduler.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/flot/jquery.flot.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/scheduler.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/htmlFormsUtils.js" type="text/javascript"></script>
EOHEADER

# ---- scheduler status
# ---------------------
my $schedstatus= "";
my $SCHEDSRV   = "localhost";
my $SCHEDREPLY = "";
if (glob("$WEBOBS{ROOT_LOGS}/*sched*.pid")) {
	my $SCHEDSOCK  = IO::Socket::INET->new(Proto => 'udp', PeerPort => $SCHED{PORT}, PeerAddr => $SCHEDSRV );
	if ( $SCHEDSOCK ) {
		if ( $SCHEDSOCK->send("CMD STAT") ) {
			if ( $SCHEDSOCK->recv($SCHEDREPLY, $SCHED{SOCKET_MAXLEN}) ) {
				my @xx = split(/(?<=\n)/,$SCHEDREPLY);
				my @td1 = map {$_ =~ s/\n/<br>/; $_} (grep { /STARTED=|PID=|USER=|uTICK=|BEAT=|PAUSED=/ } @xx);
				s/PAUSED=1/<span class=\"statusWNG\">PAUSED=1<\/span>/ for @td1;
				my @td2 = map {$_ =~ s/\n/<br>/; $_} (grep { /#JOBSTART=|#JOBSEND=|KIDS=|ENQs=/ } @xx);
				my @td3 = map {$_ =~ s/\n/<br>/; $_} (grep { /LOG=|JOBSDB=|JOBS STDio=|JOBS RESource=/ } @xx);
				$schedstatus = "<table><tr valign=\"top\"><td class=\"status statusOK\">@td1<td class=\"status\">@td2<td class=\"status\">@td3</table>"
				#$schedstatus = "$SCHEDREPLY";
				#$schedstatus =~ s/\n/<br>/g;
			} else { $schedstatus = "</div class=\"status statusWNG\">STATUS NOT AVAILABLE (socket receive error)</div>"; }
		} else { $schedstatus = "</div class=\"status statusWNG\">STATUS NOT AVAILABLE (socket send error)</div>"; }
	} else { $schedstatus = "</div class=\"status statusWNG\">STATUS NOT AVAILABLE (create socket failed)</div>" }
} else { $schedstatus = "<div class=\"status statusBAD\">JOBS SCHEDULER IS NOT RUNNING !</div>"}

# ---- 'jobsdefs' table
# ---------------------
my $job_def_list = fetch_all($SCHED{SQL_DB_JOBS},
	 "select JID,VALIDITY,RES,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXSYSLOAD,LOGPATH,LASTSTRTS "
     . "from jobs order by jid");
my $jobsdefs = '';
my $jobsdefsCount = 0;
my $jobsdefsCountValid = 0;
my $jobsdefsId = '';

for my $job (@$job_def_list) {
	my ($djid, $dvalid, $dres, $xeq1, $xeq2, $dxeq3, $dintv, $dmaxs, $dlogp, $dlstrun) = @$job;

	$dlstrun = strftime("%Y-%m-%d %H:%M:%S", localtime(int($dlstrun)));
	$jobsdefsCount++;
	$jobsdefsId="jdef".$jobsdefsCount;
	$jobsdefsCountValid++ if ($dvalid eq 'Y');

	my $tr_class = ($dvalid eq 'Y' ? "jobsactive" : "jobsinactive");
	my $delete_link = "";
	if ($admOK) {
		$delete_link = qq{<a href="#" onclick="postDelete($jobsdefsId);return false">}
			.qq{<img title="delete job" src="/icons/no.png"></a>};
	}
	my $edit_link = "";
	if ($editOK) {
		$edit_link = qq{<a href="#JOBSDEFS" onclick="openPopup($jobsdefsId);return false">}
		             .qq{<img title="edit job" src="/icons/modif.png"></a>};
	}
	$jobsdefs .= qq{
	<tr id="$jobsdefsId" class="$tr_class">
	  <td class="ic tdlock">$edit_link</td>
	  <td class="ic tdlock">$delete_link</td>
	  <td class="ic tdlock"><a href="#" onclick="postSubmit($jobsdefsId);return false">
	    <img title="submit job" src="/icons/submits.png"></a>
	  </td>
	  <td>$djid</td>
	  <td align=center>$dvalid</td>
	  <td>$dres</td>
	  <td>$xeq1</td>
	  <td>$xeq2</td>
	  <td>$dxeq3</td>
	  <td align=right>$dintv</td>
	  <td align=center>$dmaxs</td>
	  <td>$dlogp</td>
	  <td class="tdlock" nowrap>$dlstrun</td>
	</tr>
	};
}

print "</head>";

# ---- the page
# -------------
print "<body style=\"min-height: 600px;\">";
print "<!-- overLIB (c) Erik Bosrup -->";
print "<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>";
print "<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\" type=\"text/javascript\"></script>";

print "<A NAME=\"MYTOP\"></A>";
print "<h1>WebObs Jobs Scheduler Manager</h1>";
print "<h3>Reports at $buildTS</h3>";
my $ilinks = "[ ";
$ilinks .= "<a href=\#STATUS\>Status</a>";
$ilinks .= " | <a href=\#JOBSDEFS\>Jobs Definitions</a>";
$ilinks .= " | <a href=\"/cgi-bin/schedulerRuns.pl\">Runs</a>";
$ilinks .= " | <a href=\"/cgi-bin/schedulerMgr.pl\"><img src=\"/icons/refresh.png\"></a>";
$ilinks .= " ]";
print "<P class=\"subMenu\"> <b>&raquo;&raquo;</b> $ilinks</P>";

print <<"EOPAGE";
<A NAME="STATUS"></A>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#statID');">
Scheduler status
</div>
	<div id="statID" class="status-container" style="background-color: white">
		<div class="schedstatus">$schedstatus</div>
	</div>
</div>

<BR>
<A NAME="JOBSDEFS"></A>
	<div id="ovly" style="display: none"></div>
	<form id="overlay_form" style="display:none">
	<input type="hidden" name="jid" value="">
	<input type="hidden" name="action" value="">
	<p><b><i>Edit job definition</i></b></p>
	<label for="newjid">jid:<span class="small">unique name &le;20chars</span></label>
	<input type="text" id="newjid" name="newjid" value=""/><br/>
	<label for="res">resource:<span class="small">exclusive lock</span></label>
	<input type="text" id="res" name="res" value=""/><br/>
	<label for="xeq1">xeq1:<span class="small">environment cmd</span></label>
	<input type="text" id="xeq1" name="xeq1" value=""/><br/>
	<label for="xeq2">xeq2:<span class="small">procedure</span></label>
	<input type="text" id="xeq2" name="xeq2" value=""/><br/>
	<label for="xeq3">xeq3:<span class="small">post procedure</span></label>
	<input type="text" id="xeq3" name="xeq3" value=""/><br/>
	<label for="runinterval">interval:<span class="small">seconds from last run</span></label>
	<input type="text" id="runinterval" name="runinterval" value=""/><br/>
	<label for="maxsysload">maxsysload:<span class="small">prevent run above %cpu</span></label>
	<input type="text" id="maxsysload" name="maxsysload" value="0.8"/><br/>
	<label for="logpath">logpath:<span class="small">stdout/err subdir</span></label>
	<input type="text" id="logpath" name="logpath" value=""/><br/>
	<label for="validity">active:<span class="small">check to activate job</span></label>
	<input type="checkbox" id="validity" name="validity" value="Y"/><br/>
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopup(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>
</div>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#defsID');">
Jobs definitions&nbsp;<A href="#MYTOP"><img src="/icons/go2top.png"></A>
</div>
<div id="defsID">
	<div style="background: #BBB; margin: 4px 2px;">
		&nbsp;Jobs defined: <b>$jobsdefsCount</b> (currently activated: <b>$jobsdefsCountValid</b>)
		<span id="jobsdefsMsg" style="padding-left: 20px; font-weight: bold; color: $jobsdefsMsgColor">$jobsdefsMsg</span>
	</div>
	<div class="jobsdefs-container">
		<div class="jobsdefs">
			<table class="jobsdefs">
			<thead><tr><th class="ic tdlock" rowspan=2>
EOPAGE

if ($admOK) {
	print "<a href=\"#JOBSDEFS\" onclick=\"openPopup(-1);return false\"><img title=\"define a new job\" src=\"/icons/modif.png\"></a>"
} else {
	print "&nbsp;";
}
print "</th><th class=\"ic tdlock\" rowspan=2>&nbsp;</th>";
print "</th><th class=\"ic tdlock\" rowspan=2>&nbsp;</th>";

print <<"EOPAGE";
			<th rowspan=2>JID</th><th rowspan=2 align=center>A</th><th rowspan=2>Resource</th><th colspan=3 align=center>Job command</th>
			<th rowspan=2 align=right>Interval<br>(s)</th><th rowspan=2 align=center>Max.<br>load</th><th rowspan=2>Log Path</th>
			<th class="tdlock" rowspan=2>Last Start</th></tr><tr><th>xeq1</th><th>xeq2</th><th>xeq3</th>
			</tr></thead>
			<tbody>
			$jobsdefs
			</tbody>
			</table>
		</div>
	</div>
</div>

EOPAGE

print "<br>\n</body>\n</html>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel

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
