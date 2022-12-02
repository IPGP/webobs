#!/usr/bin/perl

=head1 NAME

schedulerRuns.pl

=head1 SYNOPSIS

/cgi-bin/schedulerRuns.pl?....see query string list below ....

=head1 DESCRIPTION

Builds html page to display scheduler's runs log for a (selectable) DAY.
The page includes the following 3 areas:
1) the scheduler current status
2) the runs table tabular view for a given day
3) a timeline representation of the runs table

=head1 Query string parameters

=over

=item B<scheduler=>

internal/debug use only: the name of the WebObs scheduler process from which configuration and pid filenames are built.

=item B<runsdate=>

YYYY-MM-DD specifying DAY to be displayed. Defaults to today.

=item B<jid=>

job ID to display. Defaults to all jobs.

=item B<hourdepth>

numeric value representing the timeline depth in hours. Defaults to 4.

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
use WebObs::Users;
use WebObs::Dates;
use WebObs::Scheduler qw(scheduler_client);
$|=1;

set_message(\&webobs_cgi_msg);

# ---- checks/defaults query-string elements
my $QryParm   = $cgi->Vars;
$QryParm->{'action'}    ||= 'display';
$QryParm->{'scheduler'} ||= 'scheduler';
$QryParm->{'hourdepth'} ||= 4;
$QryParm->{'runsdate'}  ||= strftime("%Y-%m-%d", localtime(time));
$QryParm->{'jid'}       ||= '';
my $hdepthdown = $QryParm->{'hourdepth'}/2;
my $hdepthup   = $QryParm->{'hourdepth'}*2;
my $today = strftime("%Y-%m-%d", localtime(time));

# ---- builds log and pid filenames
my $schedLog  = $QryParm->{'scheduler'}.".log";
my $schedPidF = $QryParm->{'scheduler'}.".pid";

# ----
my %SCHED;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));

# ---- any reasons why we couldn't go on ?
if ( ! WebObs::Users::clientHasRead(type=>"authmisc",name=>"scheduler")) {
	die "You are not authorized to access the Scheduler" ;
}
my $admOK = 0;
$admOK  = 1 if (WebObs::Users::clientHasAdm(type=>"authmisc",name=>"scheduler"));
if (defined($WEBOBS{ROOT_LOGS})) {
	#if ( -f "$WEBOBS{ROOT_LOGS}/$schedLog" ) {
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

# ---- now process special actions (delete all records for given date)
# ------------------------------------------------------------------------------
my $jobsrunsMsg='';

if ($QryParm->{'action'} eq 'delete') {
	my $startts = WebObs::Dates::ymdhms2s("$QryParm->{'runsdate'} 00:00:00");
	my $rows = execute_query($SCHED{SQL_DB_JOBS},
	   "DELETE FROM runs WHERE startts >= $startts AND startts <= $startts-86399");
	$jobsrunsMsg  = $rows . ($rows >= 1) ? "  rows deleted " : "  no row deleted "
	                ."for $QryParm->{'runsdate'}";
}
if ($QryParm->{'action'} eq 'killjob') {
	# query-string must contain the PID to be submitted to scheduler
	my $cmd = "killjob kid=$QryParm->{'kid'}";
	my ($response, $error) = scheduler_client($cmd);
	my $timestamp = strftime("%H:%M:%S %z", localtime(int(time())));
	$jobsrunsMsg = "$cmd run at $timestamp : $response"
	               .($error ? " got error '$error'" : "");
}


# ---- start html page
# --------------------
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print <<"EOHEADER";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Scheduler Runs</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/transit.css">
<link rel="stylesheet" type="text/css" href="/css/scheduler.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/flot/jquery.flot.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/flot/jquery.flot.canvas.min.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/flot/jquery.flot.time.min.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/flot/jquery.flot.selection.js"></script>
<script language="JavaScript" src="/js/scheduler.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/htmlFormsUtils.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/tables.js" type="text/javascript"></script>
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
			} else { $schedstatus = "</div class=\"status statusWNG\">STATUS NOT AVAILABLE (socket receive error)</div>"; }
		} else { $schedstatus = "</div class=\"status statusWNG\">STATUS NOT AVAILABLE (socket send error)</div>"; }
	} else { $schedstatus = "</div class=\"status statusWNG\">STATUS NOT AVAILABLE (create socket failed)</div>" }
} else { $schedstatus = "<div class=\"status statusBAD\">JOBS SCHEDULER IS NOT RUNNING !</div>"}

# ---- dynamic 'timeline' scripts
# -------------------------------
# ---- all jobs of runs table started in range [now-24hours , now] if runsdate = today
# ---- all jobs of runs table started in range [runsdate23h59-24hours, runsdate23h59] if runsdate not= today
# ---- order by jid so that unique jid occurences appear on a single graph line
my $timelineD1 = int(time());
if ( $QryParm->{'runsdate'} ne $today ) { $timelineD1 = WebObs::Dates::ymdhms2s("$QryParm->{'runsdate'} 23:59:00"); }
my $timelineD0 = 	$timelineD1 - 86400;
my $query_timeline_runs = "SELECT jid, DATETIME(cast(startts as integer),'unixepoch','localtime'),"
		. " CASE WHEN endts != 0 THEN DATETIME(CAST(endts AS INTEGER), 'unixepoch', 'localtime') ELSE NULL END,"
		. " cmd, rc FROM runs"
		. " WHERE startts >= $timelineD0"
		. ($QryParm->{'runsdate'} ne $today ? " AND startts <= $timelineD1" : "")
		. " ORDER BY jid, startts";
my $timeline_run_list = fetch_all($SCHED{SQL_DB_JOBS}, $query_timeline_runs);
print "<script language=\"JavaScript\">";
print "function setData() {\n";

my $dataX = 0;
my $Ytick = 0;
my $latest_timeline_jid = 0;

# Print the timeline from the jobs
for my $job_run (@$timeline_run_list) {
	my ($job_jid, $job_start, $job_end, $job_cmd, $job_rc) = @$job_run;

	if ($QryParm->{'jid'} eq "" || $QryParm->{'jid'} eq $job_jid) {
		my $job_color = "";

		# Running jobs have an undefined end date
		my $is_running = not defined($job_end);

		if ($job_jid ne $latest_timeline_jid) {
			# New job to plot: bump Ytick to use a new line
			$Ytick++;
			$latest_timeline_jid = $job_jid;
			print "options.yaxis.ticks[$Ytick-1] = [$Ytick, '$job_jid'];\n";
		}
		$job_start =~ s/-/\//g;
		if ($is_running) {
			# Running job: use a yellowish activity line
			$job_end = strftime("%Y/%m/%d %H:%M:%S", localtime($timelineD1));
			$job_color = "#ED9D13";
		} else {
			$job_end =~ s/-/\//g;
			if ($job_rc == 0) {
				# Successful return code: use a green activity line
				$job_color = "#318308";
			} else {
				# Use a red activity line
				$job_color = "#C8350C";
			}
		}
		# Print the javascript line defining a job activity in the timeline
		print qq(data[$dataX] = {color: "$job_color", data: [ [(new Date("$job_start")), $Ytick], [(new Date("$job_end")), $Ytick] ] };\n);
		$dataX++;
	}
}
if ($dataX == 0) {
	# define dummy data, spanning all xaxis, in case we have no data (ie. @$timeline_run_list was an empty set)
	$Ytick++;
	print "options.yaxis.ticks[$Ytick-1] = [$Ytick, \"* no start *   \"];\n";
	print "data[$dataX] = {color: \"#5555ff\", data: [ [(new Date($timelineD0*1000)), $Ytick], [(new Date($timelineD1*1000)), $Ytick] ] };\n";
}
print "yticks=$Ytick".($Ytick == 1 ? "+1":"").";"; # needs to add an Ytick in case of single job
print "options.xaxis.min = (new Date($timelineD0*1000));\n";
print "options.xaxis.max = (new Date($timelineD1*1000));\n";
print "}\n";
print "</script>\n";
print "</head>\n";


# ---- List of available days in the 'runs' database table
# --------------------------------------------------------
my @run_day_list = map { $_->[0] } (@{fetch_all($SCHED{SQL_DB_JOBS},
	"SELECT DISTINCT(DATE(CAST(startts AS INTEGER), 'unixepoch', 'localtime'))"
	." FROM runs ORDER BY 1 DESC")});


# ---- Prepare the HTML table of job runs for selected day
# --------------------------------------------------------
my $jobsruns;
my $maxdcmdl = 70; # max string length for command in table
my $rdate = WebObs::Dates::ymdhms2s("$QryParm->{'runsdate'} 00:00:00");
my @jid_list;

my $query_runs  = "SELECT jid, kid, org, DATETIME(CAST(startts AS INTEGER), 'unixepoch', 'localtime'),"
		. " CASE WHEN endts != 0 THEN DATETIME(CAST(endts AS INTEGER), 'unixepoch', 'localtime') ELSE NULL END,"
		. " cmd, stdpath, rc, rcmsg, endts - startts AS elps FROM runs"
		. " WHERE startts >= $rdate AND startts <= $rdate+86400"
		. " ORDER BY startts, jid";
my $run_list = fetch_all($SCHED{SQL_DB_JOBS}, $query_runs);

# Prepare the rows of the job run table
for my $run (@$run_list) {
	my ($job_jid, $job_kid, $org, $job_start, $job_end,
	    $job_cmd, $job_stdpath, $job_rc, $job_rcmsg, $elapsed) = @$run;

	push(@jid_list, $job_jid) unless grep{$_ eq $job_jid} @jid_list;

	if ($QryParm->{'jid'} eq "" || $QryParm->{'jid'} eq $job_jid) {

		my $elapsed_column = '';
		my $bgcolor = "transparent";
		# Running jobs have an undefined end date
		my $is_running = not defined($job_end);

		if ($is_running) {
			$job_rc = '';
			$job_rcmsg = '';
			$job_end = 'Running';
		} else {
			my ($seconds, $ms) = split(/\./, ($elapsed));
			my @time = reverse($seconds%60, ($seconds/=60) % 60, ($seconds/=60) % 24, ($seconds/=24) );
			$elapsed_column = sprintf "%03d:%02d:%02d:%02d.%3.3s", @time, $ms;
			# Return code shows success: use a green background in the RC column
			$bgcolor = ($job_rc == 0 ? "green":"red");
		}

		if (length($job_cmd) > $maxdcmdl) {
			my $s = ($maxdcmdl-5)/2;
			$job_cmd = substr($job_cmd,0,$s).'(...)'.substr($job_cmd,-$s);
		}
		$job_start =~ s/^.* //;
		$job_end =~ s/^.* //;
		$jobsruns .= qq(<tr><td class="ic tdlock">);
		if ($is_running && $admOK) {
			$jobsruns .= qq(<a href="#" onclick="postKill($job_kid);return false"><img title="kill job" src="/icons/no.png"></a>);
		}
		$jobsruns .= qq(</td><td>$job_jid<td>$job_kid<td>$org<td>$job_start<td>$job_end<td>$job_cmd);
		my $log_filename = $job_stdpath =~ s/^[><] +//r;
		$jobsruns .= qq(<td><a href="/cgi-bin/schedulerLogs.pl?log=$log_filename">$log_filename</a>);
		$jobsruns .= qq(<td style="background-color: $bgcolor;text-align:center">$job_rc<td>$job_rcmsg<td>$elapsed_column</tr>\n);
	}
}


# ---- Print the rest of the page
# -------------------------------
print <<"EOP1";
<body>
<!-- overLIB (c) Erik Bosrup
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>
-->
<script language="JavaScript" type="text/javascript">
	\$(document).ready(function() {
		\$('div.jobsdefs-container').scrollTop(\$('div.jobsdefs-container')[0].scrollHeight);
	});
	function reload() {
		var dl = \$('#indate').val();
		var j = \$('#injid').val();
		location.href=\"/cgi-bin/schedulerRuns.pl?runsdate=\"+dl+"&jid="+j ;
	}
EOP1
if ($admOK) {
	print <<"EOP2";
	function delADate() {
		var d1 = \$('#indate').val();
		var answer = confirm("do you really want to delete all records for "+d1+" ?");
		if (answer) {
			location.href=\"/cgi-bin/schedulerRuns.pl?action=delete&runsdate=\"+d1 ;
		}
	}
EOP2
}
print <<"EOP3";
</script>

<A NAME="MYTOP"></A>
<h1>WebObs Jobs Scheduler Runs</h1>
<h3>Reports request at $buildTS</h3>
<P class="subMenu"> <b>&raquo;&raquo;</b> [ <a href="#STATUS">Status</a> | <a href="#JOBSRUNS">Runs</a> | <a href="#TIMELINE">Timeline</a> | <a href="/cgi-bin/schedulerMgr.pl">Manager</a> | <a href="/cgi-bin/schedulerLogs.pl?log=SCHED">Log</a> | <a href="/cgi-bin/schedulerRuns.pl"><img src="/icons/refresh.png"></a>]</P>

<BR>
<A NAME="STATUS"></A>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png">
Scheduler status
</div>
	<div class="status-container">
		<div class="schedstatus">$schedstatus</div>
	</div>
</div>

<BR>
<A NAME="JOBSRUNS"></A>
<div class="drawer">
<div class="drawerh2">&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#runsID');">
Runs <small><sub>($buildTS)</sub></small>
&nbsp;&nbsp;<A href="#MYTOP"><img src="/icons/go2top.png"></A>
&nbsp;<img src="/icons/refresh.png" title="Refresh" onClick=\"d=new Date().getTime();location.href='/cgi-bin/schedulerRuns.pl?'+d+'#JOBSRUNS'\">
</div>
	<div id="runsID">
		<div style="padding: 5px; background: #DDDDDD">
EOP3
			print "&nbsp;&bull;&nbsp; Job: ";
			print "<select id=\"injid\" name=\"injid\" size=\"1\" maxlength=\"10\" onChange=\"reload(); return false\">";
			for my $jid ("", sort @jid_list) {
				my $selected = "";
				if ($jid eq $QryParm->{'jid'}) {
					$selected = 'selected="selected"';
				}
				print "<option value=\"$jid\" $selected>".($jid ne "" ? $jid:"--- all ---")."</option>\n";
			}
			print "</select> ";
			print "&nbsp;&bull;&nbsp; Date: ";
			print "<select id=\"indate\" name=\"indate\" size=\"1\" maxlength=\"10\" onChange=\"reload(); return false\">";
			for my $day (@run_day_list) {
				my $selected = "";
				if ($day eq $QryParm->{'runsdate'}) {
					$selected = 'selected="selected"';
				}
				print qq{<option value="$day" $selected>$day</option>\n};
			}
			print "</select>";
			if ($admOK) {
				print "<input type='button' onclick='delADate(); return false' value='delete date' />";
			}
print <<"EOP4";
			<span style="padding-left: 20px; color: red;font-weight:bold">$jobsrunsMsg</span>
		</div>
		<div class="jobsdefs-container" style="height: 300px; display: block;">
			<div class="jobsruns">
				<table class="jobsruns" id="t1">
				<thead><tr><th></th>
				<th onclick="sortTable('t1',1)"><img src="/icons/sort_both.svg"> JID</th>
				<th onclick="sortTable('t1',2)"><img src="/icons/sort_both.svg"> Kid</th>
				<th onclick="sortTable('t1',3)"><img src="/icons/sort_both.svg"> Org</th>
				<th onclick="sortTable('t1',4)"><img src="/icons/sort_both.svg"> Started</th>
				<th onclick="sortTable('t1',5)"><img src="/icons/sort_both.svg"> Ended</th>
				<th onclick="sortTable('t1',6)"><img src="/icons/sort_both.svg"> Command</th>
				<th onclick="sortTable('t1',7)"><img src="/icons/sort_both.svg"> Logs</th>
				<th onclick="sortTable('t1',8)" align=center><img src="/icons/sort_both.svg"> RC</th>
				<th onclick="sortTable('t1',9)"><img src="/icons/sort_both.svg"> RCmsg</th>
				<th onclick="sortTable('t1',10)"><img src="/icons/sort_both.svg"> Elapsed</th>
				</tr></thead>
				<tbody>
				$jobsruns
				</tbody>
				</table>
			</div>
		</div>
	</div>
</div>

<BR>
<A NAME="TIMELINE"></A>
<div class="drawer">
<div class="drawerh2">&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#tlID');">
Timeline <small><sub>($buildTS)</sub></small>
&nbsp;&nbsp;<A href="#MYTOP"><img src="/icons/go2top.png"></A>
&nbsp;<img src="/icons/refresh.png" title="Refresh" onClick=\"d=new Date().getTime();location.href='/cgi-bin/schedulerRuns.pl?'+d+'#TIMELINE'\"></A>
</div>
	<div id="tlID">
		<div class="timeline-container">
			<div id="placeholder" class="timeline-placeholder"></div>
		</div>
		<div style="background: #BBB">
			click & drag on graph to zoom in &nbsp;or&nbsp;
			<a href=\"#\" onclick=\"plotall();return false;\">here to zoom out</a><br>
			<a id=\"tlsavelink\" href=\"#\"><img src=\"/icons/d13.png\">download timeline image</a>
			<span id="jsmsg"></span>
		</div>
</div>
EOP4

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
