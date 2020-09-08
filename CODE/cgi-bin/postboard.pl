#!/usr/bin/perl

=head1 NAME

postboard.pl

=head1 SYNOPSIS

 $ perl postboard.pl [-v] [-c]

 -v   : be verbose
 -c   : force fifo cleanup on entry, otherwise will process pending messages in fifo

=head1 OVERVIEW

Receives requests from clients' processes thru the Named Pipe (FIFO) defined
with $WEBOBS{POSTBOARD_NPIPE} configuration parameter.

Requests are strings representing the 4-tuple B<"timestamp|event-name|sender-id|message"> where:

1) B<event-name> is the key to the 'notifications' table row(s) that defines what functions (email and/or action) will be triggered by PostBoard for this event;
its 'validity' column indicates whether a row is actually selectable (ie. valid/active): 'Y' = 'Yes, selectable' or 'N' = 'No, ignore'.

The 'email' function is triggered when column 'Uid' is not '-';

The 'action' function is triggered when column 'Action' is not '-'.

2) B<sender-id> and B<message> interpretation/usage depends on the triggered function (mail or action).
See below.

3) B<timestamp> is the time when notification was sent to postboard = number of seconds since the Epoch UTC
(ie. the perl's time function returned value).

=head1 SENDING REQUESTS TO POSTBOARD

The following functions are available to developers:

1) from perl, B<WebObs::Config::notify("event-name|sender-id|message")> is used to send a notification to postboard.pl.
It automatically prefixes your request with the timestamp (now).

2) from matlab, B<notify('event-name|sender-id|message')> is available (notify.m) to send a notification to postboard.pl.
It automatically prefixes your request with the timestamp (now).

The 'notify.pl' perl script may also be used for test purposes from the command line:
B<perl notify.pl "event-name|sender-id|message">

=head1 EMAIL

B<message> will be parsed to send a mail to the WebObs userid or groupid specified in column 'Uid', of the valid/active B<event-name> row(s)
of the 'notifications' table, using the $WEBOBS{POSTBOARD_MAILER} agent.

If B<sender-id> looks like an email address, it will be used to override the 'from' header of the email being sent.

B<message> syntax is B<[text][keyword=value[keyword=value...]]> where:

	1) text is any string you want to be embedded in the mail contents
	   blanks are allowed
	   | (pipes) , \n , are forbidden.
	   it is optional and stops when a keyword= string is encountered (see below) or end of string

	2) available optional keywords in B<message> for any event-name:
	   uid= a_webobs_uid_or_gid     : redefines (ie. overrides), if it is valid, the addressee's uid (or gid)
	   file= an_absolute_filename>  : includes the contents of filename in the mail

	3) available optional keywords in B<message> for the 'submitrc.jid' event-name (only used by the WebObs scheduler,
	   but listed here for reference as you MUST avoid using them in your own text string):
	   org= , log= , cmd= , rc=

Example: perl script notifying an occurence of 'myevent', defined in 'notification' table as myevent,Y,UID,mysubject,-,- :

	WebObs::Config::notify("myevent|dummy|my message with a file file=/opt/webobs/OUTR/requestid/mail.msg");
	will result in the following email:
		From: webobs@webobsaddr
		To: UID-mailaddr
		Subject: [WEBOBS_ID] mysubject
		User-Agent: Mutt/1.x.xx (2000-01-01)
		my message with a file
		<contents of file /opt/webobs/OUTR/requestid/mail.msg>

=head1 ACTION

Column 'Action' is used as a command to be executed (using the Perl blocking 'system' instruction) to which B<message>
will be appended (thus acting as argument(s) to the command executed).

Column Uid and B<sender-id> are irrelevant for this 'action' processing.

=head1 EVENTS NAMING CONVENTIONS

	event-name    = string[.[string]]
	string        = any alphanumeric string with no blank and no .,*?!/\(){};+
	string.string = aka 'majorname.minorname' form of event-name

'majorname.minorname' is used to define specific actions for each 'majorname.minorname' events AND
also common actions applying to all of them using B<majorname.> event (don't forget the ending dot!).

=head1 SUBMITRC. SPECIAL EVENT

The event B<'submitrc.jid'> is an exception to the standard email message processing by PostBoard used
internally by the WebObs scheduler (see scheduler.pl documentation) to notify end-of-job events:

1) the WebObs Scheduler automatically emits a B<submitrc.jid> when job B<jid> ends:

	notify("submitrc.jid|$$|org={S|R} rc={returncode} log={jid-std-logpath} uid={$CLIENTuid}")

2) you control the B<submitrc.jid> email activation along with its default addressee with
specific and/or global definitions of respectively B<submitrc.jid> and/or B<submitrc.> in the
'notifications' table. Postboard will merge these definitions with the message keywords value to built the mail
(addressee,subject,contents) and send it.

3) about the addressee Uid: the uid/gid in the 'notification' table definition acts, in this case, as the 'default' uid/gid
to which mail is sent when this uid/gid cannot be delivered by the scheduler (no uid= or 'uid=' in the message); eg: this may happen
for some standalone submit commands issued (anonymously from WebObs point of view) from the linux console.

4) Example: a submit "job-definition-string" command sent to the scheduler (see scheduler.pl doc) and the corresponding mail sent:

	$ scheduler submit 'XEQ1:perl,XEQ2:/path/to/jobtst.pl,RES:mylock,LOGPATH:/var/log/webobs/jobtst,UID:DL'
	will built/sent the following email:
		From: scheduleruid@webobsaddr
		To: DL-mailaddr
		Subject: [WebObs-WEBOBS_ID] request -8 has ended
		User-Agent: Mutt/1.x.xx (2000-01-01)
		Job = perl /path/to/jobtst.pl
		Ended with rc=0
		Log = /var/log/webobs/jobtst

=head1 NOTES

Note: length of "timestamp|event-name|sender-id|message" should be < system's PIPE_BUF
(guarantees fifo write atomicity with O_NONBLOCK disabled).

Note: Mail subject is automatically prefixed with "[WebObs-$WEBOBS{WEBOBS_ID}]" by postboard.

Note: POSTBOARD_MAILER, if defined, should be set to B<mutt>, the only supported
mail user-agent today (March 2013).

Internals Note: WebObs::Config::notify() translates \n character to 0x00 in request when
writing to fifo. Postboard translates them back when read.

=cut

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime :signal_h :errno_h :sys_wait_h mkfifo/;
use IO::File;
use DBI;
use Getopt::Std;
use File::Basename;

use WebObs::Config;
use WebObs::Users;

BEGIN {
	# Suppress the default fatalsToBrowser from CGI::Carp
	$CGI::Carp::TO_BROWSER = 0;
}

# ---- parse options
# ---- -v to be verbose, -c to start with a clean npipe (ignoring pending msgs)
# -----------------------------------------------------------------------------
my %options;
getopts("vc",\%options);
my $verbose = defined($options{v}) ? 1 : 0;
my $clean   = defined($options{c}) ? 1 : 0;

my $ME = basename($0);
$ME =~ s/\..*//;

# ---- initialize : pid file and logging
# ----------------------------------------------------------------------------
if (!$WEBOBS{ROOT_LOGS}) {
	printf(STDERR "Cannot start: ROOT_LOGS not found in WebObs configuration\n");
	exit(98);
}

# Open log file
my $LOGNAME = "$WEBOBS{ROOT_LOGS}/$ME.log" ;
if (! open(LOG, ">>", $LOGNAME)) {
	print(STDERR "Cannot start: unable to open $LOGNAME: $!\n");
	exit(98);
}
select((select(LOG), $|=1)[0]);  # turn off buffering
logit("------------------------------------------------------------------------");

# ---- is fifo name defined ?
# ----------------------------------------------------------------------------
if (!defined($WEBOBS{POSTBOARD_NPIPE})) {
	logit("Can't start: no POSTBOARD_NPIPE definition in WebObs configuration");
	printf("Can't start: no POSTBOARD_NPIPE definition in WebObs configuration\n");
	exit(98);
}

# ---- should we (re)-create fifo (when missing or -c(lean) requested) ?
# ----------------------------------------------------------------------------
my $TS=0;
my $FIFO = $WEBOBS{POSTBOARD_NPIPE};
unlink $FIFO if (-p $FIFO && $clean);
if (! -p $FIFO) {
	umask 0011;
	if (! mkfifo($FIFO, 0777)) {
		logit("Can't start: couldn't mkfifo $FIFO: $!");
		printf("Can't start: couldn't mkfifo $FIFO: $!\n");
		exit(98);
	}
}

# ---- need to tell someone when I'm taken down !
# ----------------------------------------------------------------------------
$SIG{INT} = end_on_sig("$ME interrupted.", 99);
$SIG{TERM} = end_on_sig("$ME terminated.", 0);
$SIG{__WARN__} = sub { my $msg = shift; logit("warning: $msg"); };

# ---- open the pipe (fifo input Q) and loop forever
# ---------------------------------------------------------------------------
open(FIFO, "+< $FIFO") or die "Couldn't open $FIFO : $!\n";
logit("WEBOBS PostBoard PID=$$ now listening on opened $FIFO");
print("PostBoard PID=$$ now listening on $FIFO\n") if (-t STDOUT);

while (1) {

	my $queued = <FIFO>;       # input looks like "timestamp | event-name | emitting-pid | message"
	$queued =~ tr/\0/\n/;      # x00 assumed instead of \n in pipe, translate back
	chomp $queued;
	#?? todo: check for queued enclosed in my defined-delimiters ==> my implementation of boundaries to
	#?? validate non-interleaved msg from other writing-ends ???
	my @REQ = split(/\|/, $queued);

	# The message argument may be empty (in case of action without argument).
	if (@REQ == 3) {
		push(@REQ, '');
	}

	if (@REQ != 4) {
		logit("ignoring invalid request [@REQ]");
		next;
	}

	WebObs::Users::refreshUsers();

	# shorten the message just for verbose mode display
	my $shortreq3 = (length($REQ[3]) > 33) ? substr($REQ[3],0,15)."...".substr($REQ[3],-15) : $REQ[3];
	$shortreq3 =~ s/\n/<lf>/g;
	logit("got event [$REQ[1]] from $REQ[2] saying [$REQ[0] - $shortreq3]") if ($verbose);
	my $sql = my $eventclause = '';
	my $validclause = " validity = 'Y' ";

	# ---- process emailing if we know how to do it and have mailid(s) for this event $REQ[1]
	if (defined($WEBOBS{POSTBOARD_MAILER})) {
		$WEBOBS{POSTBOARD_MAILER_OPTS} ||= '';
		$WEBOBS{POSTBOARD_MAILER_DEFSUBJECT} ||= "notify";

		my $allMails = fetch_emails($REQ[1]);

		if (not @$allMails) {
			logit("no mailing for [$REQ[1]] in table $WEBOBS{SQL_TABLE_NOTIFICATIONS}") if ($verbose);
		} else {

			for my $row (@$allMails) {

				my @oneMAIL = @$row;
				my @oneREQ  = @REQ; # save original request (maybe overkill)

				# Parse the incoming request's message ($oneREQ[3]): look for special keywords
				# Message syntax is: [any text][keyword=[value-allowing-embedded-blanks]...]
				#                    no | allowed in message; no keyword in 'any text' of course
				# $px will be set to 'any text'
				# %sp will gather parsed keywords as $sp{'keyword='} = 'value' (trimmed)
				my $re = join('|', ('rc', 'cmd', 'log', 'uid', 'org', 'file', 'subject', 'attach'));
				my ($px, %sp) = map { s/^\s+|\s+$//gr } split(/((?:$re)=)\s*/, $oneREQ[3]);

				# Any event's message can override defaults found in table 'notifications'
				#  uid=
				if ($sp{'uid='}) {
					if ($USERIDS{$sp{'uid='}}) {
						$oneMAIL[0] = $sp{'uid='};
					} else {
						logit("warning: ignoring unknown recipient uid in $oneREQ[3]");
					}
				}
				#  subject=
				if (defined($sp{'subject='})) {
					$oneMAIL[1] = $sp{'subject='};
				}
				#  attach=
				if (defined($sp{'attach='})) {
					$oneMAIL[2] = $sp{'attach='};
				}

				# Intercept the special 'submitrc.jid' event for special email formatting
				if ($oneREQ[1] =~ s/^submitrc\.//) {
					$oneREQ[3] = "";  # create a brand new $oneREQ[3] for normal mail processing below
					if (defined($sp{'org='}) && $sp{'org='} =~ m/^R/) {
						# it is an end-of-request (submit) :
						$oneMAIL[1] = "request $oneREQ[1] has ended";
						$oneREQ[3] .= "request submitted by ";
						$oneREQ[3] .= $sp{'uid='} ? "$sp{'uid='}\n" : "* unspecified uid *\n" ;
					} else {
						# it is an end-of-scheduled job :
						$oneMAIL[1] = "scheduled job $oneREQ[1] has ended";
						# ignore this mail (ie. do NOT send) if an rc-condition is not met
						next if (defined($sp{'rc='}) && !rccond($oneMAIL[4],$sp{'rc='}));
					}
					if (defined($sp{'cmd='})) {
						$oneREQ[3] .= "Command = $sp{'cmd='}\n";
					}
					if (defined($sp{'rc='})) {
						$oneREQ[3] .= "Ended with rc=$sp{'rc='}\n";
					}
					if (defined($sp{'log='})) {
						$sp{'log='} =~ s/[\[\] ]//g;
						$oneREQ[3] .= "Log = $WEBOBS{ROOT_URL}/cgi-bin/index.pl?page=/cgi-bin/schedulerLogs.pl?log=$sp{'log='}\n";
					}
					if ($px ne '') {
						$oneREQ[3] .= "\n$px\n";
					}
				} else {
					# event other than '^submitrc\.'
					$oneREQ[3] = $px  if ($px);
				}

				# Continue with mail processing
				my $allAddrs = fetch_email_addrs($oneMAIL[0]);

				if (not @$allAddrs) {
					logit("error: recipient uid/gid '$oneMAIL[0]' "
					      ."not found in database, aborting mailing.");
				} else {
					my $addrlist = join(' ', map { $_->[0] } @$allAddrs);
					if (not $addrlist) {
						logit("warning: no email address defined for recipient"
						      ." uid/gid '$oneMAIL[0]', aborting mailing.");
					} else {
						my $options  = $WEBOBS{POSTBOARD_MAILER_OPTS};
							if ($oneMAIL[1] and $oneMAIL[1] ne '-') {
								$options .= " -s \'[WebObs-$WEBOBS{WEBOBS_ID}] $oneMAIL[1]\'";
							} else {
								$options .= " -s \'[WebObs-$WEBOBS{WEBOBS_ID}] $WEBOBS{POSTBOARD_MAILER_DEFSUBJECT}\'";
							}
							if ($oneMAIL[2] and $oneMAIL[2] ne '-' and -e $oneMAIL[2]) {
								$options .= " -a \'$oneMAIL[2]\'";
							}
						if ($oneREQ[2] =~ m/^([^.@]+)(\.[^.@]+)*@(([^.@]+\.)+([^.@]+))$/) {
							my $domain = $3;
							my $fulln = '';
							for my $login (keys(%USERS)) {
								if ($USERS{$login}{EMAIL} =~ m/^$oneREQ[2]/) {
									$fulln = $USERS{$login}{FULLNAME};
								}
							}
							if ($fulln ne '') {
								$options .= qq( -e 'set from="$fulln <$oneREQ[2]>"');
							}
						}
						my $tmp_email_body = sprintf ("$WEBOBS{PATH_TMP_APACHE}/WOPB.$$.%16.6f", time);
						if (open(my $body_file, ">", $tmp_email_body)) {
							print $body_file "$oneREQ[3]" ;
							if ($sp{'file='} && -f "$sp{'file='}") {
								print $body_file "\n", read_file($sp{'file='});
							}
							close $body_file
								or logit("warning: an error occurred while closing $tmp_email_body");
							logit("executing '$WEBOBS{POSTBOARD_MAILER} $options -- $addrlist < $tmp_email_body'") if ($verbose);
							system("$WEBOBS{POSTBOARD_MAILER} $options -- $addrlist < $tmp_email_body");
							if ($?) { logit("error: mailing failed: $?") }
							unlink($tmp_email_body);
						} else {
							logit("error: couldn't open temporary file for mailing: $?");
						}
					} # end we have non-empty email address(es) for this mail
				} # end we have recipient(s) for this mail
			} # end for each mail
		} # we have mailing(s) in table for this event
	} # end we know how to mail from config setting

	# ---- process action(s) if we have any for this event
	my $allActions = fetch_actions($REQ[1]);

	if (@$allActions) {
		for my $action (@$allActions) {
			my $cmd = sprintf("%s %s", $action->[0], $REQ[3]);
			logit("executing action '$cmd'") if ($verbose);
			system($cmd);
			if ($?) { logit("action command [$cmd] failed: $?: $!") }
		}
	} else {
		logit("no actions for [$REQ[1]] in table $WEBOBS{SQL_TABLE_NOTIFICATIONS}") if ($verbose);
	}

}  # end of while (1)

endit(99);


# Function definitions --------------------------------------------------------

sub db_connect {
	# Open a connection to a SQLite database
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


sub get_subscriptions_clause {
	# Build and return the SQL 'where' clause to select subscriptions
	# corresponding to the event.
	my $event_name = shift;
	my $where;

	if ($event_name =~ m/^submitrc\.(.*)$/) {
		# Event is 'submitrc.{something}': grab subscriptions for
		# 'submitrc.', 'submitrc.rc*', and 'submitrc.something.rc*'
		return "(event = 'submitrc.' OR event LIKE 'submitrc.rc%' OR event LIKE 'submitrc.$1.rc%')";
	}
	if ($event_name =~ m/^([^\.]*)\.(.*)$/) {
		# Event is 'majorid.{minorid}': grab 'majorid.' + 'majorid.minorid' subscriptions
		return "(event = '$event_name' OR event = '$1.')";
	}
	# Event is 'majorid': grab 'majorid' subscriptions
	return "event = '$event_name'";
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


sub fetch_emails {
	# Return the list of email subscriptions for an event
	my $event_name = shift;
	my $where_event = get_subscriptions_clause($event_name);
	my $q = "SELECT uid,mailsubject,mailattach,validity,event"
	        ." FROM $WEBOBS{SQL_TABLE_NOTIFICATIONS}"
	        ." WHERE uid != '-' AND validity = 'Y' AND $where_event";

	return fetch_all($WEBOBS{SQL_DB_POSTBOARD}, $q);
}


sub fetch_actions {
	# Return the list of actions for an event
	my $event_name = shift;
	my $where_event = get_subscriptions_clause($event_name);
	my $q = "SELECT action FROM $WEBOBS{SQL_TABLE_NOTIFICATIONS}"
	        ." WHERE action != '-' AND validity = 'Y' AND $where_event";

	return fetch_all($WEBOBS{SQL_DB_POSTBOARD}, $q);
}


sub fetch_email_addrs {
	# Return the list of email addresses for a user or a group
	my $id = shift;  # user or group id
	my $q = "SELECT email FROM $WEBOBS{SQL_TABLE_USERS}"
	        ." WHERE uid = '$id'"
	        ." OR uid IN (SELECT uid FROM groups WHERE gid='$id')";

	return fetch_all($WEBOBS{SQL_DB_USERS}, $q);
}



# ----------------------------------------------------------
# read mail contents from a file into a scalar
# ----------------------------------------------------------
sub read_file {
	my $filename = shift;
	my $file;
	my $content = "";
	if (not (defined($filename) && open($file, $filename))) {
		logit("warning: couldn't read $filename");
		return;
	}
	local $/ = undef;
	$content = <$file>;
	close($file) or logit("warning: an error occured while closing $filename");
	return $content;
}

# ----------------------------------------------------------
# evaluate an rc-condition of a submitrc subscription
# syntax:  rccond ( subscription-definition, returncode)
# where: subscription-definition=  submitrc.{.minor}.rcOPvalue
#        OP= {==, !=, <=, >=}
# 'No argument', 'no condition' and 'argument syntax errors' evaluate to true(1)
# eg: rccond ('submitrc.jidx.rc>=0, 0) returns true (1)
# ----------------------------------------------------------
sub rccond {
	return 1 if (@_ != 2);
	return eval "($_[1] $1 $2)"?1:0 if ($_[0] =~ m/submitrc\..*rc([=><!]{2})(\d*)$/);
	return 1;
}

# ----------------------------------------------------------
# write to log
# ----------------------------------------------------------
sub logit {
	my ($logText) = @_;
	my $TS=[gettimeofday];
	$logText = sprintf ("%s.%-6s %s", strftime("%Y-%m-%d %H:%M:%S",localtime(@$TS[0])),@$TS[1],$logText);
	print LOG "$logText\n";
}

# ----------------------------------------------------------
# return a signal handler that exits the script
# ----------------------------------------------------------
sub end_on_sig {
	my $msg = shift;
	my $code = shift // 1;
	return sub {
		print "$msg\n" if (-t STDOUT);
		logit($msg);
		endit($code);
	}
}

# ----------------------------------------------------------
# clean exit
# ----------------------------------------------------------
sub endit {
	my $exit_code = shift // 99;
	close(FIFO);
	close(LOG);
	exit($exit_code);
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014 - Institut de Physique du Globe Paris

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

