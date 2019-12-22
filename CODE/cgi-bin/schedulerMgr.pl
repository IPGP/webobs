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
use IO::Socket;
use WebObs::Config;
use WebObs::Users;
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
if ( ! WebObs::Users::clientHasRead(type=>"authmisc",name=>"scheduler")) {
	die "You are not authorized" ;
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

# ---- now process special actions (insert, update or delete a job's definition)
# ------------------------------------------------------------------------------
sub dbu {
	my $dbh = DBI->connect("dbi:SQLite:dbname=$SCHED{SQL_DB_JOBS}", '', '') or die "$DBI::errstr" ;
	my $rv = $dbh->do($_[0]);
	if ($rv == 0E0) {$rv = 0} 
	$dbh->disconnect();
	return $rv;
}

$QryParm->{'jid'}         ||= "";
$QryParm->{'newjid'}      ||= "";
$QryParm->{'xeq1'}        ||= "";      
$QryParm->{'xeq2'}        ||= "";       
$QryParm->{'xeq3'}        ||= "";          
$QryParm->{'runinterval'} ||= "";   
$QryParm->{'maxsysload'}  ||= 0.7;  
$QryParm->{'logpath'}     ||= "";   
$QryParm->{'validity'}    ||= "Y";    
$QryParm->{'res'}         ||= "";    

$QryParm->{'xeq1'} =~ s/'/''/g;
$QryParm->{'xeq2'} =~ s/'/''/g;
$QryParm->{'xeq3'} =~ s/'/''/g;

my $jobsdefsMsg='';
my $jobsdefsMsgColor='black';
#DBcols: JID, VALIDITY, RES, XEQ1, XEQ2, XEQ3, RUNINTERVAL, MAXSYSLOAD, LOGPATH, LASTSTRTS

if ($admOK && $QryParm->{'action'} eq 'insert') {
	# query-string must contain all required DB columns values for an sql insert
	my $q = "insert into jobs values(\'$QryParm->{'jid'}\',\'$QryParm->{'validity'}\',\'$QryParm->{'res'}\',\'$QryParm->{'xeq1'}\',\'$QryParm->{'xeq2'}\',\'$QryParm->{'xeq3'}\',$QryParm->{'runinterval'},$QryParm->{'maxsysload'},\'$QryParm->{'logpath'}\',0)";
	my $rows = dbu($q);
	$jobsdefsMsg  = ($rows == 1) ? "  having inserted new job " : "  failed to insert new job ";  # $jobsdefsMsg .= $q;
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($editOK && $QryParm->{'action'} eq 'update') {
	# query-string must contain all required DB columns values for an sql update
	my $q = "update jobs set JID=\'$QryParm->{'newjid'}\', VALIDITY=\'$QryParm->{'validity'}\', RES=\'$QryParm->{'res'}\', XEQ1=\'$QryParm->{'xeq1'}\', XEQ2=\'$QryParm->{'xeq2'}\', XEQ3=\'$QryParm->{'xeq3'}\', RUNINTERVAL=$QryParm->{'runinterval'}, MAXSYSLOAD=$QryParm->{'maxsysload'}, LOGPATH=\'$QryParm->{'logpath'}\' where jid=\"$QryParm->{'jid'}\"";
	my $rows = dbu($q);
	$jobsdefsMsg  = ($rows == 1) ? "  having updated " : "  failed to update ";
	$jobsdefsMsg .= "jid $QryParm->{'jid'} ";   # $jobsdefsMsg .= $q;
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($admOK && $QryParm->{'action'} eq 'delete') {
	# query-string must contain the JID to be deleted from DB
	my $rows = dbu("delete from jobs where jid=\"$QryParm->{'jid'}\"");
	$jobsdefsMsg  = ($rows == 1) ? "  having deleted " : "  failed to delete ";
	$jobsdefsMsg .= "jid $QryParm->{'jid'}";
	$jobsdefsMsgColor  = ($rows == 1) ? "green" : "red";
}
if ($QryParm->{'action'} eq 'submit') {
	# query-string must contain the JID to be submitted to scheduler
	my $wsudprc = qx(perl /etc/webobs.d/../CODE/cgi-bin/wsudp.pl 'msg=>"job jid=$QryParm->{'jid'}"');
	$jobsdefsMsg  = "submit $QryParm->{'jid'} ".strftime("%H:%M:%S %z",localtime(int(time())))." : $wsudprc";
	$jobsdefsMsgColor  = ($wsudprc =~ /failed/) ? "red" : "green";
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
$qjobs  = "select JID,VALIDITY,RES,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXSYSLOAD,LOGPATH,LASTSTRTS ";
$qjobs .= "from jobs order by jid";
@qrs   = qx(sqlite3 $SCHED{SQL_DB_JOBS} "$qjobs");
chomp(@qrs);
my $jobsdefs='';
my $jobsdefsCount=0; my $jobsdefsCountValid=0; my $jobsdefsId='';
for (@qrs) {
	(my $djid, my $dvalid, my $dres, my $xeq1, my $xeq2, my $dxeq3, my $dintv, my $dmaxs, my $dlogp, my $dlstrun) = split(/\|/,$_);
	$dlstrun = strftime("%Y-%m-%d %H:%M:%S", localtime(int($dlstrun)));
	$jobsdefsCount++; $jobsdefsId="jdef".$jobsdefsCount ;
	$jobsdefsCountValid++ if ($dvalid eq 'Y');
	$jobsdefs .= "<tr id=\"$jobsdefsId\" class=\"".($dvalid eq 'Y' ? "jobsactive":"jobsinactive")."\"><td class=\"ic tdlock\">";
	# edition
	$jobsdefs .= "<a href=\"#JOBSDEFS\" onclick=\"openPopup($jobsdefsId);return false\"><img title=\"edit job\" src=\"/icons/modif.png\"></a>" if ($editOK);
	$jobsdefs .= "</td><td class=\"ic tdlock\">";
	# delete
	$jobsdefs .= "<a href=\"#\" onclick=\"postDelete($jobsdefsId);return false\"><img title=\"delete job\" src=\"/icons/no.png\"></a>" if ($admOK);
	$jobsdefs .= "</td><td class=\"ic tdlock\"><a href=\"#\" onclick=\"postSubmit($jobsdefsId);return false\"><img title=\"submit job\" src=\"/icons/submits.png\"></a></td>";
	$jobsdefs .= "<td>$djid</td><td>$dvalid</td><td>$dres</td><td>$xeq1</td><td>$xeq2</td><td>$dxeq3</td><td>$dintv</td><td>$dmaxs</td><td>$dlogp</td><td class=\"tdlock\">$dlstrun</td></tr>\n";
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
	<label for="validity">valid:<span class="small">Y=valid (=active)</span></label>
	<input type="text" id="validity" name="validity" value="N"/><br/>
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
		&nbsp;Jobs defined: <b>$jobsdefsCount</b> (currently valid: $jobsdefsCountValid) 
		<span id="jobsdefsMsg" style="padding-left: 20px; font-weight: bold; color: $jobsdefsMsgColor">$jobsdefsMsg</span>
	</div>
	<div class="jobsdefs-container">
		<div class="jobsdefs">
			<table class="jobsdefs">
			<thead><tr><th class="ic tdlock">
EOPAGE

if ($admOK) {
	print "<a href=\"#JOBSDEFS\" onclick=\"openPopup(-1);return false\"><img title=\"define a new job\" src=\"/icons/modif.png\"></a>"
} else {
	print "&nbsp;";
}
print "</th><th class=\"ic tdlock\">&nbsp;</th>";
print "</th><th class=\"ic tdlock\">&nbsp;</th>";

print <<"EOPAGE";
			<th>jid</th><th>V</th><th>res</th><th>xeq1</th><th>xeq2</th><th>xeq3</th><th>interval</th><th>load&le;</th><th>logpath</th><th class="tdlock">laststart</th>
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

Webobs - 2012-2019 - Institut de Physique du Globe Paris

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

