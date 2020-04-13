#!/usr/bin/perl
#
=head1 NAME

postREQ.pl

=head1 SYNOPSIS

jQuery.post(".../postREQ.pl", formREQ-form, result)

=head1 DESCRIPTION

Process a formREQ.pl B<Request for Graphs> input-form fields and submit the corresponding job(s) to
the WebObs scheduler:

1) Creates the Request's OUTR subdirectory B<YYYYMMDD_HHMMSS_HOSTNAME_$CLIENT>

2) Builds the B<REQUEST.rc> file: image of the formREQ's input-form fields to which is added $CLIENT's UID;
see REQUEST.rc below.

3) For each requested PROC name from formREQ.pl (ie. each p_* in query-string), builds the PROC's routine command line
and submits it to the WebObs scheduler for immediate execution, using
the scheduler's B<job-definition-string> submit command (see scheduler.pl perldoc). The
job-definition-string UID: parameter of each submit command will be identical to the REQUEST.rc UID.
Example of a job-definition-string :

	 XEQ1: Proc-SUBMIT_COMMAND,
	 XEQ2: OUTR-Path,
	 RES:  Proc-SUBMIT_RESOURCE,
	 LOGPATH: Job-LogPath,
	 UID:  $CLIENT's UID

4) Processes executed from B<Request for Graphs> may choose to send their own 'notification' event
to the WebObs PostBoard using perl's B<WebObs::Config::notify(msg)> or the B<matlab's notify(msg)> function.
The UID in REQUEST.rc file may be used as the notify's uid= parameter, to identify the WebObs client having submitted the Request.

This notification is, most of the time but not necessarily, used as their own 'end-of-job' mail, but should NOT
be confused with, and is in addition to, the automatically generated scheduler's submitrc.jid event.

=head1 USING THE NOTIFICATIONS SYSTEM

Things to remember about the WebObs notifications system within a PROC's routine wishing to use it to send email(s) about their
progress, end, and/or results:

1) Please read the B<postboard.pl perldoc> for 'Sending requests to PostBoard' (notifications) and 'Email' (notification contents and processing)

2) Sending a notification to trigger email(s) from a PROC's routine, requires the following definitions and actions:

	a) define an "event-id" identifying the notification so that PostBoard knows what to do with it: in this case, sending email
	to who with what subject. This has to be defined in the WEBOBSUSERS.db database - table "NOTIFICATIONS".

	b) each PROC's routine can thus have their own "event-id" defined (with specific mail subject, mail recipients) BUT they also can use
	the event-id "formreq." (don't forget the ending dot!), that is automatically defined as part of WebObs installation, and is intended to be
	a 'common/default' event-id for all 'Requests for Graphs' routines.

	c) The WebOb's UID (or GID) defined as the addressee (recipient) of email in the NOTIFICATIONS table for the "event-id", may be OVERIDDEN
	with a UID dynamically specified (ie. at PROC's routine run time) in the notification message itself (thru the uid= keyword, again read postboard.pl perldoc).
	As an example, a typical PROC's routine notification will use the UID parameter found in its REQUEST.rc file to build its notification uid= keyword
	(mainly because it references the WebObs $CLIENT's uid that submitted the PROC's request).

	d) the 'sender-id' specified in a notification has no special meaning to the system, except if it is a valid email address, in which case
	PostBoard will use it as the 'From:' mail's tag.

	e) the 'file=' keyword in the notification message can be used to specify a filename whose contents will be inserted in the generated email text.
	This is basically another (and optional) customization/standardization of the mail being sent from a PROC.

=head1 REQUEST.rc

	DATE1|
	DATE2|
	TZ|
	DATESTR|
	PPI|
	MARKERSIZE|
	LINEWIDTH|
	CUMULATE|
	DECIMATE|
	PLOTGRID|
	POSTSCRIPT|
	PDFOUTPUT|
	EXPORTS|
	ANONYMOUS|
	DEBUG|
	ORIGIN|
	UID|
	PROC.procname.key|  (optional, as many as given by formREQ.pl)

=head1 OUTR REQUEST subdirectory

	OUTR/YYYYMMDD_HHMMSS_HOSTNAME_UID
		REQUEST.rc
		PROC.PROCa/
			{exports,graphs,maps,logs}/
		....
		PROC.PROCz/
			{exports,graphs,maps,logs}/

=cut

use strict;
use warnings;
use File::Basename;
use CGI;
my $cgi = new CGI;
$CGI::POST_MAX = 1024;
use CGI::Carp qw(fatalsToBrowser set_message);
use Locale::TextDomain('webobs');
use POSIX qw/strftime/;
use IO::Socket;
$|=1;

# ---- webobs stuff
#
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::i18n;
use WebObs::Utils qw(u2l);
use Locale::TextDomain('webobs');
set_message(\&webobs_cgi_msg);

# ----
#
my %SCHED;
my @submiterrs;

my @tod = localtime();
my $now = strftime("%Y%m%d_%H%M%S",@tod);
my $box = ($ENV{REMOTE_HOST} ne '') ? "$ENV{REMOTE_HOST}" : "$ENV{REMOTE_ADDR}";

my $QryParm   = $cgi->Vars;
my @procnames = grep( /^p_/, keys %$QryParm );
map(s/^p_//g,@procnames);

my $reqpath  = "$WEBOBS{ROOT_OUTR}/$now"."_".$box."_"."$CLIENT";
my $reqfn    = "$reqpath/REQUEST.rc";

# ---- write output directory
# umask is mandatory to make directory writable for scheduler's job user
#
umask 0002;
if ( scalar(@procnames) !=0 ) {
	if (mkdir $reqpath) {
		if (schedconf()) {
			# one place for clientAuth ???
		} else { htmlMsg("$__{'Could not read scheduler conf.'}"); }
	} else { htmlMsg("$__{'Request aborted'}: $__{'Failed creating '} $reqpath");}
} else { htmlMsg("$__{'Request aborted'}: $__{'No PROC specified'}"); }


# ---- write the REQUEST.rc file from query-string
#
if ( (open REQ, ">$reqfn") ) {
	my $datestart= sprintf("%s-%s-%s %s:%s",
		$QryParm->{'startY'},$QryParm->{'startM'},$QryParm->{'startD'},$QryParm->{'startH'},$QryParm->{'startN'});
	my $dateend  = sprintf("%s-%s-%s %s:%s",
		$QryParm->{'endY'},$QryParm->{'endM'},$QryParm->{'endD'},$QryParm->{'endH'},$QryParm->{'endN'});
	$QryParm->{'postscript'} ||= "";
	$QryParm->{'exports'} ||= "";
	print REQ "=key|value\n";
	print REQ "DATE1|$datestart\n";
	print REQ "DATE2|$dateend\n";
	print REQ "TZ|".$QryParm->{'timezone'}."\n";
	print REQ "DATESTR|".$QryParm->{'datestr'}."\n";
	print REQ "PPI|".$QryParm->{'ppi'}."\n";
	print REQ "MARKERSIZE|".$QryParm->{'markersize'}."\n";
	print REQ "LINEWIDTH|".$QryParm->{'linewidth'}."\n";
	print REQ "CUMULATE|".$QryParm->{'cumulate'}."\n";
	print REQ "DECIMATE|".$QryParm->{'decimate'}."\n";
	print REQ "PLOTGRID|".$QryParm->{'gridon'}."\n";
	print REQ "POSTSCRIPT|".$QryParm->{'postscript'}."\n";
	print REQ "PDFOUTPUT|".$QryParm->{'pdfoutput'}."\n";
	print REQ "EXPORTS|".$QryParm->{'exports'}."\n";
	print REQ "ANONYMOUS|".$QryParm->{'anonymous'}."\n";
	print REQ "DEBUG|".$QryParm->{'debug'}."\n";
	print REQ "ORIGIN|".$QryParm->{'origin'}."\n";
	print REQ "UID|".$USERS{$CLIENT}{UID}."\n";
	foreach (grep { /^PROC./ } keys(%$QryParm)) { print REQ "$_|".u2l($QryParm->{$_})."\n" }
	close REQ;
} else {  htmlMsg("$__{'Request aborted'}: $__{'Failed creating '} $reqfn") }

# ---- submit a job for each PROC in requested proclist
#
my @submitreport;
for my $aProc (@procnames) {
	my %P = readProc($aProc);
	if (%P) {
		my $job="";
		my %PROC = %{$P{$aProc}};
		if (defined($PROC{SUBMIT_COMMAND}) && $PROC{SUBMIT_COMMAND} ne "") {
			my $logpath  = "/$now"."_".$box."_"."$CLIENT/PROC.$aProc";
			# $SELFREF can be used in the SUBMIT_COMMAND string to refer to the proc's name
			$PROC{SUBMIT_COMMAND} =~ s/\$SELFREF/$aProc/g;
			$job  = "XEQ1:$PROC{SUBMIT_COMMAND},LOGPATH:$logpath";
			$job .= ",XEQ2:$reqpath";
			$job .= ",RES:$PROC{SUBMIT_RESOURCE}" if ( defined($PROC{SUBMIT_RESOURCE}) && $PROC{SUBMIT_RESOURCE} ne "" );
			$job .= ",UID:$USERS{$CLIENT}{UID}" ;

			my $submitstatus = schedsubmit($job);
			if ( $submitstatus eq "submitted" ) {
				push(@submitreport,"$__{'submitted'}: $aProc\n  $reqpath\n");
			} else {
				push(@submitreport,"$__{'! NOT submitted'}: $aProc $submitstatus\n  $reqpath\n");
			}
		} else { push(@submitreport,"$__{'! Request aborted'}: $aProc undef SUBMIT_COMMAND\n") }
	} else { push(@submitreport,"$__{'! Request aborted'}: $aProc config read error\n") }
}

# ---- report submit statuses
#
my $alertText = join('',@submitreport);
htmlMsg($alertText);

# --- return information for javascript alert
sub htmlMsg {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0]";
	exit;
}

# ---- check/get scheduler configuration
# ----------------------------------------------------------------------------
sub schedconf {
    if (defined($WEBOBS{CONF_SCHEDULER}) && -e $WEBOBS{CONF_SCHEDULER} ) {
        %SCHED = readCfg($WEBOBS{CONF_SCHEDULER});
        return 1;
    } else { return 0 }
}

# ---- submit argument-string to scheduler on behalf of $CLIENT
# ----------------------------------------------------------------------------
sub schedsubmit {
	my $SCHEDSRV = "localhost";
	my $SCHEDROK = "job queued";
	my @gna;
    if ( scalar(@_) == 1 ) {
        my $UID = $USERS{$CLIENT}{UID};
        my $SCHEDREPLY = "";
        #DL-was (but always 0 from cgi):if ( scalar(@gna=qx(lsof -Pni :$SCHED{PORT})) > 1 ) {
            my $SCHEDSOCK  = IO::Socket::INET->new(Proto => 'udp', PeerPort => $SCHED{PORT}, PeerAddr => $SCHEDSRV );
            if ( $SCHEDSOCK ) {
                if ( $SCHEDSOCK->send("JOB $_[0]") ) {
                    if ( $SCHEDSOCK->recv($SCHEDREPLY, $SCHED{SOCKET_MAXLEN}) ) {
                        if ( $SCHEDREPLY =~ m/$SCHEDROK/i ) {
                            close($SCHEDSOCK);
                            return "submitted";
                        } else { close($SCHEDSOCK); return "unexpected answer = [$SCHEDREPLY] " }
                    } else { close($SCHEDSOCK); return "socket receive error" }
                } else { close($SCHEDSOCK); return "socket send error" }
            } else { return "create socket failed" }
        #DL-was:} else { return "scheduler not listening" }
    } else { return "nothing to submit"}
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2020 - Institut de Physique du Globe Paris

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
