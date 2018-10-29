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

{ display | insert | update | delete } . Defaults to 'display' . 'update' and 'delete' require a 'jid' 

=item B<jid=>

numeric value indicating the Jobs definition table "job's ID" that is the target of 'update' or 'delete' actions.

=item B<res>, B<xeq1=>, B<xeq2=>, B<xeq3>, B<interval=>, B<maxinst=>, B<maxload=>, B<valid=>

the values for the correponding columns in a 'jid' row of the JOBS definition table.

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
my @qrs;
my $qjobs; my $qruns;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));

# ---- any reasons why we couldn't go on ?
# ----------------------------------------
if (defined($WEBOBS{ROOT_LOGS})) {
	# if ( -f "$WEBOBS{ROOT_LOGS}/$schedLog" ) {
		if (defined($WEBOBS{CONF_SCHEDULER}) && -e $WEBOBS{CONF_SCHEDULER} ) {
			%SCHED = readCfg($WEBOBS{CONF_SCHEDULER});
			if (! -e $SCHED{SQL_DB_JOBS} ) { die "Couldn't find jobs database"}
		} else { die "Couldn't find scheduler configuration" }
	#} else { die "Couldn't find log $WEBOBS{ROOT_LOGS}/$schedLog" }
} else { die "No ROOT_LOGS defined" }

# ---- now process special actions (insert, update or delete a job's definition)
# ------------------------------------------------------------------------------
sub dbu {
	my $dbh = DBI->connect("dbi:SQLite:dbname=$SCHED{SQL_DB_JOBS}", '', '') or die "$DBI::errstr" ;
	my $rv = $dbh->do($_[0]);
	if ($rv == 0E0) {$rv = 0} 
	$dbh->disconnect();
	return $rv;
}

$QryParm->{'jid'}          ||= "";                    
$QryParm->{'xeq1'}     ||= "";      
$QryParm->{'xeq2'}      ||= "";       
$QryParm->{'xeq3'}         ||= "";          
$QryParm->{'runinterval'}  ||= "";   
$QryParm->{'maxinstances'} ||= 1;    
$QryParm->{'maxsysload'}   ||= 0.7;  
$QryParm->{'logpath'}      ||= "";   
$QryParm->{'validity'}     ||= "Y";    
$QryParm->{'res'}          ||= "";    

my $jobsdefsMsg='';
my $jobsdefsMsgColor='black';
#DBcols: JID, VALIDITY, RES, XEQ1, XEQ2, XEQ3, RUNINTERVAL, MAXINSTANCES, MAXSYSLOAD, LOGPATH, LASTSTRTS

if ($QryParm->{'action'} eq 'insert') {
	# query-string must contain all required DB columns values for an sql insert
	my $q = "insert into jobs values(null,\'$QryParm->{'validity'}\',\'$QryParm->{'res'}\',\'$QryParm->{'xeq1'}\',\'$QryParm->{'xeq2'}\',\'$QryParm->{'xeq3'}\',$QryParm->{'runinterval'},$QryParm->{'maxinstances'},$QryParm->{'maxsysload'},\'$QryParm->{'logpath'}\',0)";
	my $rows = dbu($q);
	$jobsdefsMsg  = ($rows == 1) ? "  having inserted new job" : "  failed to insert new job"; # $jobsdefsMsg .= $q;
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($QryParm->{'action'} eq 'update') {
	# query-string must contain all required DB columns values for an sql update
	my $q = "update jobs set  VALIDITY=\'$QryParm->{'validity'}\', RES=\'$QryParm->{'res'}\', XEQ1=\'$QryParm->{'xeq1'}\', XEQ2=\'$QryParm->{'xeq2'}\', XEQ3=\'$QryParm->{'xeq3'}\', RUNINTERVAL=$QryParm->{'runinterval'},  MAXINSTANCES=$QryParm->{'maxinstances'}, MAXSYSLOAD=$QryParm->{'maxsysload'}, LOGPATH=\'$QryParm->{'logpath'}\'  where jid=$QryParm->{'jid'}";
	my $rows = dbu($q);
	$jobsdefsMsg  = ($rows == 1) ? "  having updated " : "  failed to update ";
	$jobsdefsMsg .= "jid $QryParm->{'jid'}";  # $jobsdefsMsg .= $q;
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($QryParm->{'action'} eq 'delete') {
	# query-string must contain the JID to be deleted from DB
	my $rows = dbu("delete from jobs where jid=$QryParm->{'jid'}");
	$jobsdefsMsg  = ($rows == 1) ? "  having deleted " : "  failed to delete ";
	$jobsdefsMsg .= "jid $QryParm->{'jid'}";
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
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
			} else { $schedstatus = "</span class=\"statusWNG\">STATUS NOT AVAILABLE (socket receive error)</span>"; }
		} else { $schedstatus = "</span class=\"statusWNG\">STATUS NOT AVAILABLE (socket send error)</span>"; }
	} else { $schedstatus = "</span class=\"statusWNG\">STATUS NOT AVAILABLE (create socket failed)</span>" }
} else { $schedstatus = "<span class=\"statusBAD\">JOBS SCHEDULER IS NOT RUNNING !</span>"}

# ---- 'jobsdefs' table 
# ---------------------
$qjobs  = "select JID,VALIDITY,RES,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXINSTANCES,MAXSYSLOAD,LOGPATH,LASTSTRTS ";
$qjobs .= "from jobs order by jid";
@qrs   = qx(sqlite3 $SCHED{SQL_DB_JOBS} "$qjobs");
chomp(@qrs);
my $jobsdefs='';
my $jobsdefsCount=0; my $jobsdefsId='';
for (@qrs) {
	(my $djid, my $dvalid, my $dres, my $xeq1, my $xeq2, my $dxeq3, my $dintv, my $dmaxi, my $dmaxs, my $dlogp, my $dlstrun) = split(/\|/,$_);
	$dlstrun = strftime("%Y-%m-%d %H:%M:%S", localtime(int($dlstrun)));
	$jobsdefsCount++; $jobsdefsId="jdef".$jobsdefsCount ;
	$jobsdefs .= "<tr id=\"$jobsdefsId\"><td class=\"tdlock\"><a href=\"#\" onclick=\"openPopup($jobsdefsId);return false\"><img title=\"edit job\" src=\"/icons/modif.gif\"></a>";
	$jobsdefs .= "<td class=\"tdlock\"><a href=\"#\" onclick=\"postDelete($jobsdefsId);return false\"><img title=\"delete job\" src=\"/icons/no.gif\"></a>";
	$jobsdefs .= "<td class=\"tdlock\">$djid<td>$dvalid<td>$dres<td>$xeq1<td>$xeq2<td>$dxeq3<td>$dintv<td>$dmaxi<td>$dmaxs<td>$dlogp<td class=\"tdlock\">$dlstrun</tr>\n";
}

print "</head>";

# ---- the page 
# -------------
print <<"EOPAGE";
<body style="min-height: 600px;">
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>

<A NAME="MYTOP"></A>
<h2>WebObs Jobs Scheduler Manager</h2>
<P class="subMenu">[ <a href="#STATUS">Status</a> | <a href="#JOBSDEFS">Jobs Definitions</a> | &raquo; <a href="/cgi-bin/schedulerRuns.pl">Runs</a> | &laquo;&raquo; <a href="/cgi-bin/schedulerMgr.pl">Refresh</a> ]</P>
<h3>Reports at $buildTS</h3>

<A NAME="STATUS"></A>
<div class="fieldspacer"></div>
<fieldset><legend class="smanlegend">Scheduler status</legend>
	<div class="status-container">
		<div class="schedstatus">$schedstatus</div>
	</div>
</fieldset>

<A NAME="JOBSDEFS"></A>
<div class="fieldspacer"><A href="#MYTOP"><img src="/icons/go2top.png"></A></div>
<fieldset><legend class="smanlegend">Jobs definitions</A></legend>
	<div style="background: #BBB">
		jobs defined: <b>$jobsdefsCount</b>
		<span id="jobsdefsMsg" style="padding-left: 20px; font-weight: bold; color: $jobsdefsMsgColor">$jobsdefsMsg</span>
	</div>
	<div class="jobsdefs-container">
		<div class="jobsdefs">
			<table class="jobsdefs">
		    <thead><tr><th class="tdlock"><a href="#" onclick="openPopup(-1);return false"><img title="define a new job" src="/icons/modif.gif"></a>
			<th class="tdlock">&nbsp;
			<th class="tdlock">jid<th>valid<th>res<th>xeq1<th>xeq2<th>xeq3<th>interval<th>//<th>threshold<th>logpath<th class="tdlock">laststart
			</tr></thead>
			<tbody>
			$jobsdefs
			</tbody>
			</table>
		</div>
	</div>
	<div id="ovly" style="display: none"></div>
	<form id="overlay_form" style="display:none">
	<input type="hidden" name="jid" value="">
	<input type="hidden" name="action" value="">
	<p><b><i>Edit job definition</i></b></p>
	<label>resource:<span class="small">exclusive lock</span></label>
	<input type="text" name="res" value=""/><br/>
	<label>xeq1:<span class="small">environment cmd</span></label>
	<input type="text" name="xeq1" value=""/><br/>
	<label>xeq2:<span class="small">procedure</span></label>
	<input type="text" name="xeq2" value=""/><br/>
	<label>xeq3:<span class="small">post procedure</span></label>
	<input type="text" name="xeq3" value=""/><br/>
	<label>interval:<span class="small">seconds from last run</span></label>
	<input type="text" name="runinterval" value=""/><br/>
	<label>maxinstances:<span class="small">1=multiple instances</span></label>
	<input type="text" name="maxinstances" value="1"/><br/>
	<label>maxsysload:<span class="small">prevent run above %cpu</span></label>
	<input type="text" name="maxsysload" value="0.8"/><br/>
	<label>logpath:<span class="small">stdout/err subdir</span></label>
	<input type="text" name="logpath" value=""/><br/>
	<label>valid:<span class="small">Y=valid (=active)</span></label>
	<input type="text" name="validity" value="Y"/><br/>
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopup(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>
</fieldset>

EOPAGE

print "<br>\n</body>\n</html>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon

=head1 COPYRIGHT

Webobs - 2012 - Institut de Physique du Globe Paris

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

