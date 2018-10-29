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
use WebObs::Dates;
$|=1;

set_message(\&webobs_cgi_msg);

# ---- checks/defaults query-string elements 
my $QryParm   = $cgi->Vars;
$QryParm->{'action'}    ||= 'display';
$QryParm->{'scheduler'} ||= 'scheduler';
$QryParm->{'hourdepth'} ||= 4;
$QryParm->{'runsdate'}  ||= strftime("%Y-%m-%d", localtime(time));
my $hdepthdown = $QryParm->{'hourdepth'}/2;
my $hdepthup   = $QryParm->{'hourdepth'}*2;
my $today = strftime("%Y-%m-%d", localtime(time));

# ---- builds log and pid filenames
my $schedLog  = $QryParm->{'scheduler'}.".log";
my $schedPidF = $QryParm->{'scheduler'}.".pid";

# ----
my %SCHED;
my @qrs;
my $qjobs; my $qruns;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));

# ---- any reasons why we couldn't go on ?
if (defined($WEBOBS{ROOT_LOGS})) {
	#if ( -f "$WEBOBS{ROOT_LOGS}/$schedLog" ) {
		if (defined($WEBOBS{CONF_SCHEDULER}) && -e $WEBOBS{CONF_SCHEDULER} ) {
			%SCHED = readCfg($WEBOBS{CONF_SCHEDULER});
			if (! -e $SCHED{SQL_DB_JOBS} ) { die "Couldn't find jobs database"}
		} else { die "Couldn't find scheduler configuration" }
	#} else { die "Couldn't find log $WEBOBS{ROOT_LOGS}/$schedLog" }
} else { die "No ROOT_LOGS defined" }

# ---- now process special actions (delete all records for given date)
# ------------------------------------------------------------------------------
sub dbu {
	my $dbh = DBI->connect("dbi:SQLite:dbname=$SCHED{SQL_DB_JOBS}", '', '') or die "$DBI::errstr" ;
	my $rv = $dbh->do($_[0]);
	if ($rv == 0E0) {$rv = 0} 
	$dbh->disconnect();
	return $rv;
}

my $jobsrunsMsg='';

if ($QryParm->{'action'} eq 'delete') {
	my $startts = WebObs::Dates::ymdhms2s("$QryParm->{'runsdate'} 00:00:00");  
	my $rows = dbu("delete from runs where startts >= $startts and startts <= $startts-86399");
	$jobsrunsMsg  = $rows;
	$jobsrunsMsg .= ($rows >= 1) ? "  rows deleted " : "  no row deleted ";
	$jobsrunsMsg .= "for $QryParm->{'runsdate'}";
}

# ---- start html page
# --------------------
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print <<"EOHEADER";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Affichage de VIEW</title>
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
			} else { $schedstatus = "</span class=\"statusWNG\">STATUS NOT AVAILABLE (socket receive error)</span>"; }
		} else { $schedstatus = "</span class=\"statusWNG\">STATUS NOT AVAILABLE (socket send error)</span>"; }
	} else { $schedstatus = "</span class=\"statusWNG\">STATUS NOT AVAILABLE (create socket failed)</span>" }
} else { $schedstatus = "<span class=\"statusBAD\">JOBS SCHEDULER IS NOT RUNNING !</span>"}

# ---- dynamic 'timeline' scripts 
# -------------------------------
print "<script language=\"JavaScript\">";
	print "function setData() {\n";
	# ---- all jobs of runs table started in range [now-hourdepth , now] if runsdate = today
	# ---- all jobs of runs table started in range [runsdate23h59-hoursdepth, runsdate23h59] if runsdate not= today
	# ---- order by jid so that unique jid occurences appear on a single graph line
	my $timelineD1 = int(time());
	if ( $QryParm->{'runsdate'} ne $today ) { $timelineD1 = WebObs::Dates::ymdhms2s("$QryParm->{'runsdate'} 23:59:00"); }
	my $timelineD0 = $timelineD1 - ($QryParm->{'hourdepth'}*3600);
	$qruns  = "select jid,datetime(cast(startts as integer),'unixepoch','localtime'),";
	$qruns .= "datetime(cast(endts as integer),'unixepoch','localtime'),";
	$qruns .= "cmd, rc ";
	$qruns .= "from runs where startts >= $timelineD0 ";
	if ( $QryParm->{'runsdate'} ne $today ) { $qruns .= "and startts <= $timelineD1 "; }
	$qruns .= "order by jid, startts";
	@qrs   = qx(sqlite3 $SCHED{SQL_DB_JOBS} "$qruns");
	chomp(@qrs);

	my $dataX = my $Ytick = my $jid = 0;
	for (@qrs) {
		(my $ajid, my $astart, my $aend, my $acmd, my $arc) = split(/\|/,$_);
		if ($ajid != $jid) { # new jid: bump Ytick, otherwise don't bump
			$Ytick++; 
			$jid = $ajid;
			$acmd = "$jid-$acmd";
			if (length($acmd) > 40) { $acmd =substr($acmd,0,27)."..."; }
			print "options.yaxis.ticks[$Ytick-1] = [$Ytick, '$acmd'];\n";
		}
		my $acolor="";
		$astart =~ s/-/\//g;
		if (substr($aend,0,10) ne "1970-01-01") { 
			$aend =~ s/-/\//g;
			$acolor = ($arc == 0) ? "#318308" : "#C8350C";
		} else {
			$aend = strftime("%Y/%m/%d %H:%M:%S",localtime($timelineD1));
			$acolor = "#ED9D13";
		}
		print "data[$dataX] = {color: \"$acolor\", data: [ [(new Date(\"$astart\")).getTime()+TZoffset, $Ytick], [(new Date(\"$aend\")).getTime()+TZoffset, $Ytick] ] };\n";
		$dataX++;
	}
	if ( $dataX == 0 ) {
		# define dummy data, spanning all xaxis, in case we have no data (ie. @qrs was an empty set)
		#print "data[$dataX] = {color: \"#ffffff\", data: [ [(new Date($timelineD0*1000)).getTime()+TZoffset, $Ytick], [(new Date($timelineD1*1000)).getTime()+TZoffset, $Ytick] ] };\n";
		$Ytick++;
		print "options.yaxis.ticks[$Ytick-1] = [$Ytick, \"* no start *   \"];\n";
		print "data[$dataX] = {color: \"#5555ff\", data: [ [(new Date($timelineD0*1000)).getTime()+TZoffset, $Ytick], [(new Date($timelineD1*1000)).getTime()+TZoffset, $Ytick] ] };\n";
	}
	print "yticks=$Ytick;";
	print "options.xaxis.min = (new Date($timelineD0*1000)).getTime()+TZoffset;\n";
	print "options.xaxis.max = (new Date($timelineD1*1000)).getTime()+TZoffset;\n";
	# print "\$('#jsmsg').text()";
	# print "\$('#jsmsg').text(\"[ \"+(new Date(options.xaxis.min)).toISOString()+\" - \"+(new Date(options.xaxis.max)).toISOString()+\" ]\")";
	print "}\n";
print "</script>";

# ---- 'jobsruns' table 
# -------------------------------
my $jobsruns;
my $maxdcmdl = 70; # max string length for command in table
my $rdate = WebObs::Dates::ymdhms2s("$QryParm->{'runsdate'} 00:00:00");

$qruns  = "select jid,kid,org,datetime(cast(startts as integer),'unixepoch','localtime'),";
$qruns .= "datetime(cast(endts as integer),'unixepoch','localtime'),";
$qruns .= "cmd, stdpath, rc, rcmsg, (endts-startts) as elps ";
$qruns .= "from runs where startts >= $rdate and startts <= $rdate+86400 ";
$qruns .= "order by startts, jid";
@qrs   = qx(sqlite3 $SCHED{SQL_DB_JOBS} "$qruns");
chomp(@qrs);

for (@qrs) {
	my $elp;
	(my $djid, my $dkid, my $org, my $dstart, my $dend, my $dcmd, my $dstdpath, my $drc, my $drcmsg, my $elapsed) = split(/\|/,$_);
	if ( $dend =~ m/^1970.01.01/ ) {
		$dend = "";
		$elapsed = "";
	} else {
		my ($T,$ms)=split(/\./, ($elapsed));
		my @out = reverse($T%60, ($T/=60) % 60, ($T/=60) % 24, ($T/=24) );
		$elp = sprintf "%03d:%02d:%02d:%02d.%3.3s", @out, $ms;
	}
	my $bgcolor = "transparent";  
	if ( $drc ne '' ) {
		$bgcolor = "green"  if ( !($dend =~ m/^1970.01.01/) && $drc == 0 );
		$bgcolor = "bisque" if ( $dend =~ m/^1970.01.01/ );
		$bgcolor = "red"    if ( $drc > 0 );
	}
	if (length($dcmd) > $maxdcmdl) { my $s = ($maxdcmdl-5)/2; $dcmd = substr($dcmd,0,$s).'(...)'.substr($dcmd,-$s) }
	$jobsruns .= "<tr><td>$djid<td>$dkid<td>$org<td>$dstart<td>$dend<td>$dcmd";
	(my $zz = $dstdpath) =~ s/[>< ]//g; $jobsruns .= "<td><a href=\"/cgi-bin/schedulerLogs.pl?log=$zz\">$dstdpath</a>";
	$jobsruns .= "<td style=\"background-color: $bgcolor\">$drc<td>$drcmsg<td>$elp</tr>\n";
}
	
print "</head>";

# ---- the page 
# -------------
print <<"EOPAGE";
<body>
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript">
	function loadADate() {
		var dl = \$('#indate').val();
		location.href=\"/cgi-bin/schedulerRuns.pl?runsdate=\"+dl ;
	}
	function delADate() {
		var d1 = \$('#indate').val();
		var answer = confirm("do you really want to delete all records for "+d1+" ?");
		if (answer) {
			location.href=\"/cgi-bin/schedulerRuns.pl?action=delete&runsdate=\"+dl ;
		}
	}
</script>

<A NAME="MYTOP"></A>
<h2>WebObs Jobs Scheduler Runs</h2>
<P class="subMenu">[ <a href="#STATUS">Status</a> | <a href="#JOBSRUNS">Runs</a> | <a href="#TIMELINE">Timeline</a>  | &raquo; <a href="/cgi-bin/schedulerMgr.pl">Manager</a> | &laquo;&raquo; <a href="/cgi-bin/schedulerRuns.pl">Refresh</a>]</P>
<h3>Reports at $buildTS</h3>

<A NAME="STATUS"></A>
<div class="fieldspacer"></div>
<fieldset><legend class="smanlegend">Scheduler status</legend>
	<div class="status-container">
		<div class="schedstatus">$schedstatus</div>
	</div>
</fieldset>

<A NAME="JOBSRUNS"></A>
<div class="fieldspacer"><A href="#MYTOP"><img src="/icons/go2top.png"></A></div>
<fieldset><legend class="smanlegend">Runs</legend>
	<div style="padding: 5px; background: #BBB">
		<input type="button" value="hide/display" onclick="\$('div.jobsdefs-container').toggle();"/>
		&nbsp;&bull;&nbsp; date: 
		<input type="text" id="indate" name="indate" size="10" maxlength="10" value="$QryParm->{'runsdate'}">
		<input type="button" onclick="loadADate(); return false" value="show date" />
		<input type="button" onclick="delADate(); return false" value="delete date" />
		<span style="padding-left: 20px; color: red">$jobsrunsMsg</span>
	</div>
	<div class="jobsdefs-container" style="height: 300px; display: block;">
		<div class="jobsruns">
			<table class="jobsruns">
		    <thead><tr><th>jid<th>kid<th>org<th>started<th>ended<th>command<th>std path<th>RC<th>RCmsg<th>Elapsed</tr></thead>
			<tbody>
			$jobsruns
			</tbody>
			</table>
		</div>
	</div>
</fieldset>

<A NAME="TIMELINE"></A>
<div class="fieldspacer"><A href="#MYTOP"><img src="/icons/go2top.png"></A></div>
<fieldset><legend class="smanlegend">Timeline</A></legend>
	<div class="timeline-container">
		<div id="placeholder" class="timeline-placeholder"></div>
	</div>
	<div style="background: #BBB">
		span (hours):
		<span style="color: #318308;">
			<a href=\"/cgi-bin/schedulerRuns.pl?runsdate=$QryParm->{'runsdate'}&hourdepth=$hdepthdown\"><img src=\"/icons/d13.png\"></a><b>$QryParm->{'hourdepth'}</b>
			<a href=\"/cgi-bin/schedulerRuns.pl?runsdate=$QryParm->{'runsdate'}&hourdepth=$hdepthup\"><img src=\"/icons/u13.png\"></a>
		</span>
		<span id="jsmsg">
		</span>
	</div>
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


