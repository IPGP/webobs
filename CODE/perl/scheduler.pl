#!/usr/bin/perl

=head1 NAME

scheduler.pl

=head1 SYNOPSIS

 $ perl scheduler.pl [-v] [-c config-filename]

   -v   : be verbose (default for shells/scheduler start command)
   -V   : be more verbose
   -n   : erase scheduler.log (if any) when starting
   -c   : specify a scheduler configuration file instead of the
          default WEBOBS 'CONF_SCHEDULER'

=head1 DESCRIPTION

=head2 OVERVIEW

B<WebObs Jobs Scheduler>. To be automatically (re)started and looping forever to
schedule/monitor executions of B<jobs> from the B<JOBS definitions table> and
from a dynamic B<JOBQ> queue of user-submitted jobs received on its dedicated UDP port.

B<WebObs Jobs Scheduler> records its activity + error messages in its $WEBOBS{ROOT_LOGS}/scheduler.log,
that is automatically saved as $WEBOBS{ROOT_LOGS}/YYYY-MM-DD.scheduler.log everyday.

B<shells/scheduler> is the command line interface used to start and send commands to the WebObs Jobs Scheduler ;
see its man page for help.

=head1 JOBS EXECUTION

The administrator-defined B<beat> is the scheduler's main loop rate at which jobs
are scanned and checked for required/possible execution.

Jobs defined in the B<JOBS DataBase table>, with their validity set to 'Y',
are B<candidates> for execution as soon as their
previous run time is older than their RUNINTERVAL, whatever their previous run return code was.

Jobs in the B<JOBQ> are immediately considered as B<candidates>,
and, should their execution be impossible at that time,
stay in the JOBQ, waiting to be processed on next beat: B<JOBQ> is a WAITQ from which jobs will be cancelled
after scheduler's variable CANCEL_SUBMIT seconds. Jobs validity flag is ignored (not checked)
for jobs submitted with 'submit jid=jjj' command.

B<Candidates> are moved to the RUNQ and get executed as parallel processes if they fullfill their execution criteria:
its B<resource> is free, and its B<cpu-loadavg threshold> is not reached.

A job's B<resource> , if defined, acts as a mutex lock to prevent concurrent execution of jobs.
A B<resource> is identified by its freely defined name (a string not containing double-dash, ie --). It may also
be defined as a set of individual resources (a '+' separated list of names): all of these resources must
be simultaneously free for the job to be executed.

B<Candidates> not moved to the RUNQ will be candidates again on the next
scheduler's beat; to avoid unnecessary overload and reporting, the scheduler may delay these jobs
from being candidates again by a small amount of seconds. Delay to be used are defined by LMISS_BIAS for LoadThreshold condition and
EMISS_BIAS for Enq-busy condition, in the scheduler's configuration. Set these to 0 to disabled delay.

=head2 CONFIGURATION PARAMETERS

The WebObs Jobs scheduler has configuration parameters stored in a file,
that is read once at scheduler load time. The configuration filename may be passed as an option
or automatically defaults to the filename pointed to by the B<CONF_SCHEDULER> key
in the common WebObs structure B<$WEBOBS>. The file is 'readCfg()' interpretable.

Changes to the configuration file are NOT dynamically read/used by the running scheduler;
scheduler.pl MUST be stopped/started to load new configuration values.

	# CONF_SCHEDULER|${ROOT_CONF}/scheduler.rc    # in WEBOBS.rc

	# scheduler.rc example configuration file
	#
	=key|value                                    # readCfg() specification
	BEAT|2                                        # find/start jobs each BEAT seconds
	MAX_CHILDREN|10                               # maximum simultaneous jobs running
	LISTEN_ADDR|localhost                         # client-command interface address
	PORT|7761                                     # client-command UDP port number
	SOCKET_MAXLEN|1500;                           # client-command max msg length
	SQL_DB_JOBS|$WEBOBS{ROOT_CONF}/WEBOBSJOBS.db  # sqlite DataBase name for JOBS table
	LOADAVG1_THRESHOLD|0.7                        # 1' max system load averages
	LOADAVG5_THRESHOLD|0.7                        # 5' =
	LOADAVG15_THRESHOLD|0.7                       #15' =
	PATH_STD|$WEBOBS{ROOT_CONF}/jobslogs          # root directory for all jobs STDOUT/ERR
	PATH_RES|$WEBOBS{ROOT_CONF}/res               # root directory for jobs resources (==ENQ ==LOCKS)
	DITTO_LOG_MAX|500                             # how many occurences of a msg to log before forcing a write
	DITTO_NTF_MAX|1000                            # how many occurences of a msg to notify before forcing a notify
	CANCEL_SUBMIT|3600                            # how long (seconds) a submited job can be waiting in JOBQ
	DAYS_IN_RUN|30                                # number of days that jobs stay in runs table
	LMISS_BIAS|10                                 # number of seconds to delay candidates not run because of load-threshold
	EMISS_BIAS|4                                  # number of seconds to delay candidates not run because of enq busy

=head2 JOBS DATABASE

Periodic jobs are defined in the scheduler's B<JOBS> table of the DataBase defined by B<SQL_DB_JOBS>.
A job is identified by its unique B<JID> and by its 3-tuple B<XEQ1 XEQ2 XEQ3> that form
the 'PROGRAM LIST' passed to 'exec' for job's execution (see 'exec' syntax in perldoc).
Each row of B<JOBS> is a single job definition consisting of the following columns/information:

	JID            char, unique jobid (length <= 20 chars, no blanks allowed),
	VALIDITY       char, Y|N : wether this definition is currently valid (Y), ie. processed or ignored
	XEQ1           text, 1st element of 'exec'
	XEQ2           text, 2nd element of 'exec'
	XEQ3           text, 3rd element of 'exec'
	RUNINTERVAL    int, how many seconds between two runs of the job
	MAXSYSLOAD     real, system load 5'-average above which the job shouldn't be executed
	LOGPATH        text, subdirectory of scheduler's PATH_STD to store job's STDOUT & STDERR
	LASTSTRTS      real, timestamp when last run was started

XEQ1, XEQ2 and XEQ3 can reference variables from WEBOBS.rc configuration. Such a reference
is coded $WEBOBS{key} (eg. $WEBOBS{MYXEQ1S}/matlab p1 p2).

Executing and executed jobs (aka 'runs') are kept in the summary/history B<RUNS> table.
Each row of B<RUNS> reflects one (1) execution of a job (identified by it's JID and KID) :

	JID            int,  unique jobid (see table B<JOBS>)
	KID            int,  linux process id forked by scheduler
	ORG            text, 'S' selected by Scheduler, 'R' selected on [user's] Request
	STARTTS        int,  time this run was started
	ENDTS          int,  time this run has ended
	CMD            text, executed command
	STDPATH        text, location of this run's stdout and stderr
	RC             int,  return code of this run
	RCMSG          text, text return code


=head2 COMMANDS

scheduler.pl, while processing/monitoring jobs definitions, also listens for
B<client-commands> on a dedicated B<UDP port> of the configured interface.
These commands either B<modify/query> the scheduler's configuration OR B<submit jobs>
to be immediately executed (if possible): ie. I<inserted> into the
current scheduling loop.

shells/scheduler is used to send these commands to scheduler.pl.
See its man page for help.

The following commands are understood by the WebObs Scheduler (all of these are case insensitive):

=over

=item B<JOB { JID=jid  | 'job-definition-string' }>

Submit a job for immediate execution, still checking for system load threshold.
The job is either a reference to a job in the job definition table 'jobs'  OR
a job dynamically defined inline with a job-definition-string.

1) reference to jobs table:  B<JID=jid>

2) a B<job-definition-string> is a comma-separated list of jobdef's I<keyword:value>
("keyword1:value,....,keywordN:value"), where allowed keywords are:

	XEQ1:, XEQ2:, XEQ3:           (same as jobs table columns)
	LOGPATH:, RES:, MAXSYSLOAD:   (same as jobs table columns)
	UID:                          (submitter uid to be used for end of job notification)

	Example:
	$ scheduler submit 'XEQ1:perl,XEQ2:/path/to/jobtst.pl,RES:mylock,UID:DL'

Each time a job-definition-string is submitted, the job will automatically be assigned a unique
numeric negative jid, for reporting/database identification purposes.

=item B<ENQ resource>

ENQ a resource. Scheduler's job resources may be shared by external processes. This feature makes it possible
to synchronize execution of scheduler's jobs with non-scheduler machine's activities and/or conditions.
Commands ENQ and DEQ are the only scheduler's entry points to this sharing mechanism.
Resources naming and (shared) usage are the responsibility of WebObs administrator. An ENQ'd resource  is marked with the
jid for which it was issued. For external processes the jid will be the scheduler's UDP client socket.

=item B<DEQ resource>

DEQ a resource. See ENQ command above. Caveat: currently, the jid for which a DEQ is issued does NOT have to be
the jid for which ENQ was issued.

=item B<CMD PAUSE>

Suspends the execution of the Scheduler (until resumed with CMD START)

=item B<CMD START>

Resumes excution of PAUSED Scheduler.

=item B<CMD VERBOSE>

Places Scheduler in 'verbose' mode (for debugging) if it wasn't started with this option.

=item B<CMD QUIET>

Cancels 'verbose' mode.

=item B<CMD STOP>

Stops the scheduler ! This command freezes any Scheduler inputs (DB and socket), waits
for its started jobs to end (if any), then stops (exits) scheduler.

=item B<CMD STATUS>

Requests summary status information from the Scheduler.

=back

=head2 JOBS OUTPUTS

A summary/history of jobs started by the Scheduler is maintained in table B<RUNS> of the DB $WEBOBS{SQL_DB_JOBS}.

Jobs can redirect/build their own STDOUT and STDERR, however the following rules are
implemented as a default behavior in the Scheduler:  All JOBS outputs (stdout and stderr) will be placed
in the common directory defined by B<PATH_STD>; in this directory the location
of each job's output (stdout and stderr) is derived from its B<LOGPATH> setting.

The following table shows B<LOGPATH> syntax (left) interpretation (right), where
any subdirectories defined in the path will be dynamically created if needed,
and pid is the job's pid.

	name					PATH_STD/name.std{out,err}
	name/					PATH_STD/name/pid.std{out,err}
	name/name/out			PATH_STD/name/name/name/out.std{out,err}
	<null>					PATH_STD/pid.std{out,err}

The following two rules apply to any one of the above syntaxes:

	>name					overwrite previous file with same name
	>>name					append to previous file with same name


The following B<tags> are also available in the name(s) you supply for easier
specification of unique log files:

	{TS}					replaced with job's start-timestamp
	{RTNE}					replaced with job's XEQ2 string, with any blanks (spaces) chars
							changed to '_' underscores.

=head2 NOTIFICATIONS

The scheduler currently send the following B<notifications events> to the WebObs B<Postboard> system
Following is the list of "event-name => situation" of these notifications:

	scheduler.critical  => system loadavg thresholds have been reached, before selecting candidates jobs
	scheduler.critical  => maximum # of process kids already running, before selecting candidates jobs
	scheduler.critical  => couldn't fork for executing a job
	scheduler.warning   => a job is candidate, but already in the runQ and its maxintances don't allow
	scheduler.warning   => a job is candidate, but its maxsysload has been reached
	scheduler.critical  => scheduler has been stopped from a 'STOP' command
	scheduler.critical  => scheduler has been killed (sigint received)
	submitrc.<jid>      => jid has ended (see postboard.pl documentation)

=head2 VERBOSITY

The following list which messages go to the scheduler log based on the verbosity setting.
These lists are indicative only; they might not be accurate/comprehensive.

messages logged, ignoring verbosity setting:

	- received commands
	- failed to fork a kid, failed to exec a kid
	- main loop drift > tick interval
	- maximum number of kids executing
	- locked job's resource
	- loadavg above job's threshold
	- all messages during the stop sequence

messages logged when verbosity on (-v or verbose cmd)

	- forked kids detailed info
	- reaper details
	- system's sysload warnings
	- enq and deq job's resources

messages logged when verbosity level 2 on (-V)

	- RUNQ status at each beat
	- CANDIDATES list at each beat
	- paused status and adjust-loop on each beat

=head2 SCHEDULER EXIT

1) Sending a STOP command to the scheduler is the way to cleanly stop the scheduler, waiting for termination of currently running kids,
and housekeeping.

2) Sending the scheduler SIGINT, SIGHUP or SIGTERM signals will internally mimic a clean STOP command, but without waiting for currently running kids to stop. On SIGINT and SIGHUP, the process exits with a code 1, while the code is 0 with SIGTERM.

3) Other signals are not caught by the scheduler. Their default behaviors of your system will get executed. This event will probably
cause the file LOGS/scheduler.pid to remain present, requiring that you delete it before restarting the scheduler.

4) Once successfully initialized/started, any internal (namely from DBSELECT and DBUPDATE routines) DB connection errors will result in
a log message and immediate exit, without waiting for kids termination.

5) When the scheduler starts it will automatically try to recover from a previous abnormal exit condition (ie. not a clean STOP exit):
any left over jobs' locks are released (free busy resources), and all jobs with no 'end-timestamp' in the RUNS history will be forced
'ended' as defined by the scheduler's configuration CLEANUP_RUNS parameter.

=cut

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use DateTime;
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime :signal_h :errno_h :sys_wait_h/;
use DBI;
use Getopt::Std;
use IO::Socket;
use File::Basename qw(basename fileparse);
use File::Copy qw/move/;
use File::Path qw/make_path/;
use feature qw(switch);

use WebObs::Config;

BEGIN {
	# Suppress the default fatalsToBrowser from CGI::Carp
	$CGI::Carp::TO_BROWSER = 0;
}

# ---- Read local time zone
our $local_tz = DateTime::TimeZone->new(name => 'local');

# ---- parse options
# ---- -v to be verbose, -c to specify configuration file
# -----------------------------------------------------------------------------
my %options;
getopts("Vvnc:",\%options);
my $verbose=0;

$verbose  = defined($options{v}) ? 1 : 0;
$verbose  = defined($options{V}) ? 1 : $verbose;
my $verbose2 = defined($options{V}) ? 1 : 0;
my $configf  = defined($options{c}) ? $options{c} : '';
my $newlog   = defined($options{n}) ? 1 : 0;

my $ME = basename($0);
$ME =~ s/\..*//;

# ---- initialize : tell'em who I am
# ----------------------------------------------------------------------------
if (!$WEBOBS{ROOT_LOGS}) {
	printf(STDERR "Cannot start: ROOT_LOGS not found in WebObs configuration\n");
	exit(1);
}

# Open log file
my $LOGNAME = "$WEBOBS{ROOT_LOGS}/$ME.log" ;
my $SAVELOGPATH = "$WEBOBS{ROOT_LOGS}/saved.$ME.log";
unlink($LOGNAME) if (-e $LOGNAME && $newlog);
if (! open(LOG, ">>$LOGNAME")) {
	print(STDERR "Cannot start: unable to open $LOGNAME: $!\n");
	exit(1);
}

# ---- initialize: internal structures
# -----------------------------------------------------------------------------
our $STRT = time;              # when I was started
our $STRTTS = strftime("%Y-%m-%d %H:%M:%S (UTC%z)",localtime($STRT)); # when I was started
our $PID = $$;				   # my own pid (parent of all running kids)
our $PUID= (getpwuid($<))[0];  # who am I after all
our $PAUSED = 0;			   # tick but don't schedule anything if PAUSED
our %kids;					   # 'running' kids hash: $kids{kid_pid} = internal kid_id
our $kidcmd;				   # command to be executed by currently forked kid
our $rid = 0;				   # a run id
our $dcd = 0;				   # ended kid_pid in the REAPER's waitpid loop
our $utick    = 1000000;	   # base tick (microseconds)
our $adjutick =  $utick;	   # utick adjusted for drift
our %CANDIDATES;			   # jobs, candidates for this 'tick' from DB and Q
our %RUNQ;					   # jobs, running ()
our %JOBRQ;					   # queued jobs requests (from udp submits)
our @CMDRQ;					   # queued cmds from udp client
our $JSTARTED=0;			   # number of jobs started so far, for this scheduler's session
our $JENDED=0;             	   # number of jobs ended so far, for this scheduler's session
our $CFGF='';                  # active configuration filename
our %SCHED;                    # active configuration
our $lldate = '';              # date of last record written to log
our $DynJid=-1;                # to allocate 'dynamic' jids to Q jobs (user input)
our $ncpus = 1;                # number of cpus (defaults to 1)
our $ELT = 0;                  # cumulated Estimated Loop Times in seconds
our $forcesavelog = 0;         # 1 upon receiving flog command
our $DITTO = "";               # ditto memory for log
our $DITTOCNT = 0;             # how many occurences of msg in $DITTO for log
our $DITTONTF = "";            # ditto memory for notifications
our $DITTONTFCNT = 0;          # how many occurences of msg in $DITTO for notifications
our %LMISS;                    # missed executions on Load thresholds
our %EMISS;                    # missed executions on Enq resource

select((select(LOG), $|=1)[0]);  # turn off buffering
logit("------------------------------------------------------------------------");

# ---- initialize: read scheduler configuration
# ---- command-line configuration file supersedes WEBOBS one
# -----------------------------------------------------------------------------
$CFGF = $configf if ($configf ne '' && -e $configf) ;
$CFGF = $WEBOBS{CONF_SCHEDULER} if ($CFGF eq '' && -e $WEBOBS{CONF_SCHEDULER});
%SCHED = readCfg($CFGF);
if ( scalar(keys(%SCHED)) <= 1 ) {
	logit("scheduler can't start: no or invalid configuration file");
	printf("scheduler can't start: no or invalid configuration file\n");
	myexit(1);
}
if ( !defined($SCHED{SQL_DB_JOBS}) ) {
	logit("scheduler can't start: no JOBS database");
	printf("scheduler can't start: no JOBS database\n");
	myexit(1);
}

# ---- UDP non-blocking socket, for incoming users requests
# -----------------------------------------------------------------------------
my $SOCK = IO::Socket::INET->new(
	'LocalAddr' => $SCHED{LISTEN_ADDR} || 'localhost',
	'LocalPort' => $SCHED{PORT},
	'Proto' => 'udp',
	'Blocking' => 0,
);
my $sock_desc = sprintf("UDP socket %s:%d", $SCHED{LISTEN_ADDR} || 'localhost',
						$SCHED{PORT});

if (!$SOCK)  {
	my $err = "scheduler[$$] cannot start because of $sock_desc error: $!";
	logit($err);
	printf($err);
	myexit(1);
}

# ---- system load averages access+interpretation setups
# -----------------------------------------------------------------------------
if (open FILE, "< /proc/cpuinfo") {
	$ncpus = scalar grep(/^processor\s+:/,<FILE>);
	close FILE;
}
our ($avg1,$avg5,$avg15) = 0;         # work-vars for sys load averages

# --- directory for daily backups of scheduler.log
# -----------------------------------------------------------------------------
system("mkdir -p $SAVELOGPATH");
if ( ! -d "$SAVELOGPATH" ) {
	logit("scheduler $$ won't start, couldn't mkdir $SAVELOGPATH: $? $!");
	printf("scheduler $$ won't start, couldn't mkdir $SAVELOGPATH: $? $!\n");
	myexit(1);
}

# --- root of all jobs' logs (STDOUT/STDERR redirections) directories
# -----------------------------------------------------------------------------
system("mkdir -p $SCHED{PATH_STD}");
if ( ! -d $SCHED{PATH_STD} ) {
	logit("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_STD}: $? $!");
	printf("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_STD}: $? $!\n");
	myexit(1);
}

# --- root of all jobs' 'resource' (enq=locks) directories
# -----------------------------------------------------------------------------
system("mkdir -p $SCHED{PATH_RES}");
if ( ! -d $SCHED{PATH_RES} ) {
	logit("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_RES}: $? $!");
	printf("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_RES}: $? $!\n");
	myexit(1);
}
system("rm -f $SCHED{PATH_RES}/*");

# ---- runs-history depth default
# -----------------------------------------------------------------------------
$SCHED{DAYS_IN_RUN} ||= 30; #days

# ---- maximum number of seconds that submitted jobs remain in JOBQ
# -----------------------------------------------------------------------------
$SCHED{CANCEL_SUBMIT} ||= 3600;

# ---- forces output of ditto accumulating msg (log and postboard)
# -----------------------------------------------------------------------------
$SCHED{DITTO_LOG_MAX} ||= 500;
$SCHED{DITTO_NTF_MAX} ||= 1000;

# ---- delays in seconds before a candidate, that can't be executed because of
# ---- cpuload threshold (LMISS) or resource busy (EMISS), can be candidate again
# -----------------------------------------------------------------------------
$SCHED{LMISS_BIAS} ||= 10;
$SCHED{EMISS_BIAS} ||= 4;

# ---- scheduler's loop, a multiple of base tick
# ----------------------------------------------------------------------------
$SCHED{BEAT} ||= 2;

# -----------------------------------------------------------------------------
# ---- scheduler's main process, stopped via SIGINT
# ---- or better still, by an external Q command 'STOP'
# -----------------------------------------------------------------------------
printf("scheduler PID=$PID started - logging to $LOGNAME - $PUID\n") if (-t STDOUT);
logit("scheduler started, listening on $sock_desc - PID=$PID CONFIG=$CFGF USER=$PUID");
logit(strftime("%Y-%m-%d %H:%M:%S %Z (%z)",localtime($STRT)));
logit("beat = $SCHED{BEAT} * ".($utick/1000000)." sec.");
logit("max parallel jobs = $SCHED{MAX_CHILDREN}");
logit("$ncpus cpu(s), load thresholds = $SCHED{LOADAVG1_THRESHOLD} (1'), $SCHED{LOADAVG5_THRESHOLD} (5'), $SCHED{LOADAVG15_THRESHOLD} (15')");
logit("jobs database = $SCHED{SQL_DB_JOBS}");
logit("jobs stdout/stderr to $SCHED{PATH_STD}/<job>");
logit("jobs resources in $SCHED{PATH_RES}/<jobres>");
logit("listening for DGRAM on port $SCHED{PORT}");
logit("days in runlog = $SCHED{DAYS_IN_RUN}");
logit("ditto reminder (log, notify) = $SCHED{DITTO_LOG_MAX}, $SCHED{DITTO_NTF_MAX}");
logit("TTL in JOBRQ = $SCHED{CANCEL_SUBMIT} sec.");
logit("missed runs biases (threshold, enq) = $SCHED{LMISS_BIAS}, $SCHED{EMISS_BIAS} sec.");

# Exit with error on INT and HUP signals
$SIG{INT} = $SIG{HUP} = \&exit_on_signal;

# Cleanly exit on TERM signal
$SIG{TERM} = sub { exit_on_signal('TERM', 0); };

# ---- pseudo REAPER to clean up the RUNS table :
# ---- make sure that all past runs are marked as ended for reporting purposes
# ---- since we have no more knowledge/control over them when (re)starting
if (defined($SCHED{CLEANUP_RUNS}) && $SCHED{CLEANUP_RUNS} ne '') {
	my ($zrc, $zmsg) = split(/,/, $SCHED{CLEANUP_RUNS});
	$zrc ||= 999;
	$zmsg ||= 'zombie';
	my $ztime = time;
	my $q = "UPDATE runs SET endts=$ztime,rc=$zrc,rcmsg='$zmsg' WHERE endts=0";

	my $dbh = db_connect($SCHED{SQL_DB_JOBS});
	if (not $dbh) {
		logit("Error connecting to $SCHED{SQL_DB_JOBS}: $DBI::errstr");
		myexit(1);
	}
	my $rv = $dbh->do($q);
	$rv = 0 if ($rv == 0E0);
	logit("cleaned up zombie runs: $rv");

	$dbh->disconnect()
		or warn "Got warning while disconnecting from $SCHED{SQL_DB_JOBS}: "
		        . $dbh->errstr;
}

# ---- loop forever handling commands and jobs to be started
# ----------------------------------------------------------

# SCHEDULING LOOP

	# wait (sleep) for next clock tick
	# start clock tick processing
	# decrement current BEAT count: it will trigger actual job scheduling when reaching 0
	# check the non-blocking UDP socket for clients' commands:
		# processes 'commands' and also queues 'job requests' in JOBRQ
	# leave (ignore) this tick if in PAUSE mode or not yet reach BEAT (not 0)
	# at each BEAT tick (BEAT = 0)
		# restore BEAT count
		# decrement time in JOBQ for all jobs there, cancel them if needed
		# triggers REAPER and ignore this tick if max number of forked kids reached
		# ignore this tick if current system load too high (SYSLOAD)
		# select candidate jobs for this BEAT tick from JOBRQ and JOBS DataBase
			#   all JOBRQ jobs
			# + DataBase jobs whose last 'run' is older than their defined RUNINTERVAL.
			# applying LMISS or EMISS biases to slow down 'candidate not forked loop'
		# loop thru all candidate jobs:
			# build job's execution command (kidcmd) as its XEQ1 + XEQ2 + XEQ3
			# insert into the RUNQ a candidate job that is allowed to be forked:
				# having its defined MAXSYSLOAD less than the current system load 5' average
				# may ENQ its defined resource
				# candidates not eligible to RUNQ and coming from JOBRQ will 'return' to JOBRQ
			# fork a kid to execute job
				# kid's code inherits from parent's variables at time of fork
				# kid's code triggers a system 'exec kidcmd'
			# links kid's pid to runQ's id (both ways) for the job just started
		# triggers REAPER that processes ended kids if any (non-blocking waitpid for kids)
			# cleanup kids'/job's references
			# update DataBase with 'last run' information for job
	# loop after adjusting next wait time (loop execution drift)

# Alert of the start of the scheduler (the same way we alert of its shutdown)
notifyit("scheduler.critical|$$|scheduler is starting");

our $BEAT = $SCHED{BEAT};
while (1) {

	my $psdmsg = sprintf ("%u %s wait %d (d=%f,beat=%d)", $$,$PAUSED?" paused":"",int($adjutick),$adjutick-int($adjutick),$BEAT);
	logit($psdmsg) if ($verbose2);
	usleep(int($adjutick));

	my $t0 = [gettimeofday];
	$BEAT-- if (!$PAUSED);

	UDPS();
	if (!$PAUSED && !$BEAT) {
		$BEAT = $SCHED{BEAT};
		TTLJOBRQ();
		if (REAPER() == $SCHED{MAX_CHILDREN}) {
			notifyit("scheduler.critical|$$|Maximum number of started processes reached");
			next;
		};
		if (SYSLOAD()) {
			notifyit("scheduler.critical|$$|Loadavg thresholds reached");
			next;
		}
		CANDIDATES();
		if ($verbose2) {
			logit(scalar(keys(%CANDIDATES))." candidate(s): ");
			for my $c (keys(%CANDIDATES)) {
				logit("  $CANDIDATES{$c}{JID}: $CANDIDATES{$c}{XEQ1} $CANDIDATES{$c}{XEQ2} $CANDIDATES{$c}{XEQ3} ");
			}
		}
		for my $rid (keys(%CANDIDATES)) {
			# build the actual command to be executed from components XEQx

			# no leading/trailing blanks in EACH components THEN derefrence $WEBOBS{} variables
			$CANDIDATES{$rid}{XEQ1} =~ s/^\s+|\s+$//g;
			$CANDIDATES{$rid}{XEQ2} =~ s/^\s+|\s+$//g;
			$CANDIDATES{$rid}{XEQ3} =~ s/^\s+|\s+$//g;

			my $kidcmd  = "$CANDIDATES{$rid}{XEQ1} $CANDIDATES{$rid}{XEQ2} $CANDIDATES{$rid}{XEQ3}";
			$kidcmd =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g;

			# check if eligible for RUNQ ?
			if ($CANDIDATES{$rid}{MAXSYSLOAD} <= $avg5) {
				logit("jid($CANDIDATES{$rid}{JID}) candidate but CpuLoad too high");
				notifyit("scheduler.warning|$$|Job [ $CANDIDATES{$rid}{JID} ] candidate but CpuLoad too high");
				if ($SCHED{LMISS_BIAS}>0) {
					$LMISS{$CANDIDATES{$rid}{JID}} = time;
				}
				next;
			}
			if (ENQ($CANDIDATES{$rid}{RES},$CANDIDATES{$rid}{JID}) == 1) {
				logit("jid($CANDIDATES{$rid}{JID}) candidate but Resource busy");
				if ($SCHED{EMISS_BIAS}>0) {
					$EMISS{$CANDIDATES{$rid}{JID}} = time;
				}
				next;
			}

			# candidate is eligible, remove it from JOBRQ if it came in that way
			if ($CANDIDATES{$rid}{ORG} eq "R") {
				logit("rid $rid jid($CANDIDATES{$rid}{JID}) candidate, removed from JOBRQ") if ($verbose);
				delete($JOBRQ{$rid})
			}

			# create the RUNQ structure for this job
			my $Qid = $rid;
			$RUNQ{$Qid}{kidcmd}  = $kidcmd;
			$RUNQ{$Qid}{kid}     = 0;
			$RUNQ{$Qid}{res}     = $CANDIDATES{$rid}{RES} ;
			$RUNQ{$Qid}{jid}     = $CANDIDATES{$rid}{JID};
			$RUNQ{$Qid}{uid}     = $CANDIDATES{$rid}{UID};
			$RUNQ{$Qid}{ORG}     = $CANDIDATES{$rid}{ORG};

			# take care of stdout/err redirections and targets
			my $redir = '>';
			(my $RTNE_ = $CANDIDATES{$rid}{XEQ2}) =~ s/\s+/_/g;
			$CANDIDATES{$rid}{LOGPATH} ||= $RTNE_ ;
			if ($CANDIDATES{$rid}{LOGPATH} =~ m/(^>{1,2})(.*)$/) {
				$redir = $1;
				$CANDIDATES{$rid}{LOGPATH} = $2;
			}

			$RUNQ{$Qid}{started} = time;
			$CANDIDATES{$rid}{LOGPATH} =~ s/\{TS\}/$RUNQ{$Qid}{started}/g ;
			$CANDIDATES{$rid}{LOGPATH} =~ s/\{RTNE\}/$RTNE_/g ;
			my ($logfn, $logfd) = fileparse($CANDIDATES{$rid}{LOGPATH});
			$logfd =~ s|/$||;  # Remove trailing slash from the dir
			$RUNQ{$Qid}{logfd} = $logfd;
			$RUNQ{$Qid}{logfn} = $logfn;

			# from now on we don't need the $CANDIDATES{$rid} anymore
			delete($CANDIDATES{$rid});
			make_path("$SCHED{PATH_STD}/$logfd");

			$RUNQ{$Qid}{kidcmd} =~ s/'/''/g;
			DBUPDATE("UPDATE jobs set laststrts=$RUNQ{$Qid}{started} WHERE jid='$RUNQ{$Qid}{jid}'");
			DBUPDATE("INSERT INTO runs (jid,org,startts,cmd,endts)"
				     ." VALUES ('$RUNQ{$Qid}{jid}', '$RUNQ{$Qid}{ORG}', $RUNQ{$Qid}{started}, '$RUNQ{$Qid}{kidcmd}', 0)");
			DBUPDATE("DELETE FROM runs WHERE startts<=$RUNQ{$Qid}{started}-($SCHED{DAYS_IN_RUN}*86400) AND endts <> 0 ");
			$JSTARTED++;

			my $kid = fork();
			if (!defined($kid)) {
				logit("$$ couldn't fork [ $kidcmd ] !");
				notifyit("scheduler.critical|$$|couldn't fork [ $kidcmd ]");
				next;
			}

			if ($kid == 0) {
				# Child code

				# Create a new process group for the current process
				setpgrp;

				my $log_basename = "$SCHED{PATH_STD}/$logfd/$logfn";
				my $merge_logs;
				my $output_name;
				my $run_path_ext;
				my $stdout_ext;

				if ($SCHED{'MERGE_JOB_LOGS'}
						and $SCHED{'MERGE_JOB_LOGS'} =~ /^\s*(?:y(?:es)?|1)\s*$/i) {
					$merge_logs = 1;
					$output_name = "STDOUT+STDERR";
					$run_path_ext = "log";
					$stdout_ext = "log";
				} else {
					$merge_logs = 0;
					$output_name = "STDOUT";
					$run_path_ext = "std{out,err}";
					$stdout_ext = "stdout";
				}

				open(STDOUT, $redir, "$log_basename.$stdout_ext")
					or die "Could not redirect STDOUT: $!";
				printf(STDOUT "\n*** %s WEBOBS JOB *** STARTED  %s [ %s ] ***\n\n", $output_name,
					   strftime("%Y-%m-%d %H:%M:%S", localtime($RUNQ{$Qid}{started})), $kidcmd);

				if ($merge_logs) {
					# stdout and stderr should be redirected to the same file
					open STDERR, ">&", \*STDOUT
						or die "Could not redirect STDERR to STDOUT: $!";;
				} else {
					# Default behaviour: stdout and stderr should be redirected to different files
					open STDERR, $redir, "$log_basename.stderr"
						or die "Could not redirect STDERR: $!";;
					printf(STDERR "\n*** STDERR WEBOBS JOB *** STARTED  %s [ %s ] ***\n\n",
						   strftime("%Y-%m-%d %H:%M:%S", localtime($RUNQ{$Qid}{started})), $kidcmd);
				}
				DBUPDATE("UPDATE runs SET kid=$$,stdpath='$redir $logfd/$logfn.$run_path_ext'"
						 ." WHERE jid='$RUNQ{$Qid}{jid}' AND startts=$RUNQ{$Qid}{started}");

				# alea jacta est ... one way ticket to the job !
				# exec may return on -1 (wrong attrs): force kid exit (so that reaper will see it)
				exec $kidcmd
					or logit("$$ couldn't exec [ $kidcmd ]: $? $!");

				# Exit if exec failed
				exit(-1);

			}  # end of if ($kid == 0)

			# Continuing with parent's code
			$RUNQ{$Qid}{kid} = $kid;            # link runQ element to kid pid
			$kids{$kid} = $Qid;                 # link kid pid list to runQ
			if ($verbose) {
				logit("forked $kid [ $kidcmd ] Q:$Qid,R(Q):$RUNQ{$Qid}{kid},K:$kids{$kid}");
				logit("logs $kid: $redir $logfd/$logfn.std{out,err}");
			}
			next;
		}  # end of for my $rid (keys(%CANDIDATES))

		REAPER();
		if ($verbose2) {
			logit("$$ runQ: ");
			for my $j (keys(%RUNQ)) {
				logit("  runQ $j : jid($RUNQ{$j}{jid}) pid=$RUNQ{$j}{kid} started=$RUNQ{$j}{started} cmd=$RUNQ{$j}{kidcmd}");
			}
		}

		my $tvi = tv_interval($t0);
		if (($adjutick = $utick - $tvi) <= 0) {
			logit("$$ drift >= $SCHED{TICK} !!!");
			$adjutick = 0;
		}
		$ELT += $tvi;
	}
}

# you should never get there !
myexit(99);

# -----------------------------------
# non-blocking wait for children exit
# -----------------------------------
sub REAPER {
	my @DBupdates;

	while (($dcd = waitpid(-1, &WNOHANG)) > 0) {
		my $dcdRC = ${^CHILD_ERROR_NATIVE}; # default, see below each case
		my $tend = time;
		my $dcdmsg = '';

		if ($? == -1) {
			$dcdmsg = sprintf (" failed to execute: $!");
		} elsif ($? & 127) {
			$dcdmsg = sprintf (" %s %d %s coredump","$dcd died with signal",($? & 127),($? & 128) ? '' : 'no');
		} else {
			$dcdRC = $? >> 8;
			$dcdmsg = sprintf ("*%d", $dcdRC);
		}

		my $dcdQid = $kids{$dcd};
		if ($dcdRC != 0) {
			notifyit("scheduler.critical|$$|Job $RUNQ{$dcdQid}{jid} started at $RUNQ{$dcdQid}{started} returned non-null code $dcdRC.\nError message was : $dcdmsg");
		}
		DBUPDATE("UPDATE runs SET endts=$tend,rc=$dcdRC,rcmsg=\"$dcdmsg\" WHERE jid=\"$RUNQ{$dcdQid}{jid}\" AND startts=$RUNQ{$dcdQid}{started}");

		my $notifytxt  = "submitrc.$RUNQ{$dcdQid}{jid}|$$|"
			."org=$RUNQ{$dcdQid}{ORG} rc=$dcdRC cmd=[ $RUNQ{$dcdQid}{kidcmd} ] log=[ $RUNQ{$dcdQid}{logfd}/$RUNQ{$dcdQid}{logfn}.std{out,err} ] ";
		if (defined($RUNQ{$dcdQid}{uid}) && $RUNQ{$dcdQid}{uid} ne '') {
			$notifytxt .= "uid=$RUNQ{$dcdQid}{uid}";
		}
		WebObs::Config::notify($notifytxt);

		$JENDED++;
		logit("reaper: kid($dcd), runQ($dcdQid), jid($RUNQ{$dcdQid}{jid})") if ($verbose);
		DEQ($RUNQ{$dcdQid}{res},$RUNQ{$dcdQid}{jid});
		delete $RUNQ{$dcdQid};
		delete $kids{$dcd};
	}
	return scalar(keys(%kids));
}

# ------------------------------
# Exit scheduler on STOP command
# ------------------------------
sub exit_after_jobs {
	$PAUSED = 2;  # Do not schedule new jobs
	logit("scheduler[$$]: stop requested, waiting for kid(s) to exit...");
	notifyit("scheduler.critical|$$|scheduler is shutting down as requested.");
	while (REAPER() != 0) { sleep(1); UDPS() };
	logit("kid(s) stopped. Exiting.");
	myexit(0);
}

# ------------------------
# Exit scheduler on signal
# ------------------------
sub exit_on_signal {
	my $signame = shift || '';
	my $exit_code = shift // 1;

	logit("caught a SIG$signame");
	notifyit("scheduler.critical|$$|scheduler stopping on signal $signame");
	my $ets = REAPER();   # any extra-terrestrial survivors ?
	logit("$ets kid(s) are still alive.") if ($ets>0);
	print("exiting on signal SIG$signame.") if (-t STDOUT);
	myexit($exit_code);
}

# ----------------------------------------------------------
# SYSLOAD true if system's loadavg > user-defined thresholds
# ----------------------------------------------------------
sub SYSLOAD {
	# ---- grab fresh system's loadavg figures
	if (open FILE, "< /proc/loadavg") {
		($avg1, $avg5, $avg15, undef, undef) = split / /, <FILE>;
		close FILE;
		# load averages in users's definitions are relative to 1 cpu;
		# fix /proc/loadavg values to match actual number of cpus
		$avg1 /= $ncpus; $avg5 /= $ncpus; $avg15 /= $ncpus;
		# ---- system's loadavg vs user thresholds
		if ($avg1>$SCHED{LOADAVG1_THRESHOLD} || $avg5>$SCHED{LOADAVG5_THRESHOLD} || $avg15>$SCHED{LOADAVG15_THRESHOLD}) {
			#logit(" $$ system load > threshold: $avg1/$SCHED{LOADAVG1_THRESHOLD}  $avg5/$SCHED{LOADAVG5_THRESHOLD}  $avg15/$SCHED{LOADAVG15_THRESHOLD}") if ($verbose);
			logit(" $$ system load > threshold") if ($verbose);
			return(1);
		}
	} else {
		logit("$$ cpu loadavg not refreshed: $!");
	}
	return(0);
}

# ----------------------------------------------------------
# CANDIDATES select all jobs that could be run now, from DB and Q
# ----------------------------------------------------------
sub CANDIDATES {
	%CANDIDATES = %{DBSELECT()};
	for my $key (keys %CANDIDATES) {
		usleep 1;
		my $art = time;
		$CANDIDATES{$art} = delete $CANDIDATES{$key};
	}

	for my $jtk (keys(%JOBRQ)) {
		my $jrq = $JOBRQ{$jtk}{REQ};
		$jrq =~ s/^\s+|\s+$//g;
		if ( $jrq =~ m/JID=\s*(.+)\s*/i ) {
			# a %CANDIDATES entry from a submit "jid=<job's id>"
			my $jrqid = $1;
			my %tmp = %{DBSELECT($jrqid)};
			if (defined($tmp{$jrqid})) {
				$CANDIDATES{$jtk} = delete $tmp{$jrqid};
			} else {
				logit("$$ deleting submitted job jid($jrqid): not defined");
				delete($JOBRQ{$jtk});
			}
		} else {
			# a %CANDIDATES entry from a submit "XEQ1:gnagna,XEQ2:blabla,..."
			if (JDPARSE($jtk) == 0) {
				logit("$$ deleting submitted job jid($JOBRQ{$jtk}{JID}): parse failed [ $jrq ]");
				delete($JOBRQ{$jtk});
			}
		}
	}
	# ignore JIDs for which exists a 'pending delay' due to a previous threshold OR enq condition
	for my $key (keys %CANDIDATES) {
		if (defined($LMISS{$CANDIDATES{$key}{JID}})) {
			if ($LMISS{$CANDIDATES{$key}{JID}} + $SCHED{LMISS_BIAS} >= time) {
				delete $CANDIDATES{$key};
			} else {
				delete $LMISS{$CANDIDATES{$key}};
			}
		}
		if (defined($EMISS{$CANDIDATES{$key}{JID}})) {
			if ($EMISS{$CANDIDATES{$key}{JID}} + $SCHED{EMISS_BIAS} >= time) {
				delete $CANDIDATES{$key};
			} else {
				delete $EMISS{$CANDIDATES{$key}};
			}
		}
	}
	return scalar(keys(%CANDIDATES));
}
# ----------------------------------------------------------
# helper: parse job definitions from Q (ie. user input)
# its JID (dynamic, negative) has been assigned when command was received
# parses user's string "XEQ1:'launch text',XEQ2:'routine text',XEQ3:'a1 a2',...."
# ----------------------------------------------------------
sub JDPARSE {
	my $jrq = $JOBRQ{$_[0]}{REQ};
	my @req = split(/,/,$jrq);
	my %KW  = map { split(/:/,$_,2) } @req;
	$KW{XEQ1} ||= '';
	$KW{XEQ2} ||= '';
	$KW{XEQ3} ||= '';
	$KW{MAXINSTANCES} ||= 0;
	$KW{MAXSYSLOAD}   ||= 0.8;
	$KW{LOGPATH}  ||= 'undef';
	$KW{RES} ||= '';
	$KW{UID} ||= '';
	$KW{ORG}  = 'R';
	if ("$KW{XEQ1}$KW{XEQ2}$KW{XEQ3}" ne "") {
		$CANDIDATES{$_[0]} = \%KW;
		$CANDIDATES{$_[0]}{JID} = $JOBRQ{$_[0]}{JID};
		return 1;
	}
	return 0;
}

# ----------------------------------------------------------
# TTLJOBRQ manages jobs time to live in JOBRQ (accepted wait)
# and cancels (removes) those jobs whose ttl drops below 0
# ----------------------------------------------------------
sub TTLJOBRQ {
	for my $j (keys(%JOBRQ)) {
		$JOBRQ{$j}{TTL} -= $SCHED{BEAT}*($utick/1000000);
		if ($JOBRQ{$j}{TTL} <= 0) {
			logit("cancelling TTL-expired waiting job jid($JOBRQ{$j}{JID}) [ $JOBRQ{$j}{REQ} ]");
			delete($JOBRQ{$j});
			delete($LMISS{$JOBRQ{$j}{JID}}) if (defined($LMISS{$JOBRQ{$j}{JID}}));
			delete($EMISS{$JOBRQ{$j}{JID}}) if (defined($EMISS{$JOBRQ{$j}{JID}}));
		}
	}
	return;
}

# ----------------------------------------------------------
# Open and return a connection to a SQLite database
#
# Usage example:
#   my $dbh = db_connect($WEBOBS{SQL_DB_POSTBOARD})
#     || die "Error connecting to $dbname: $DBI::errstr";
# ----------------------------------------------------------
sub db_connect {
	my $dbname = shift;
	return DBI->connect("dbi:SQLite:$dbname", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		})
}

# ----------------------------------------------------------
# reads all 'valid & ready' jobs from DataBase table JOBS
# OR just one JOB definition (wether or not valid and ready)
# if its job's ID (JID) is passed as argument
# ----------------------------------------------------------
sub DBSELECT {
	my $job_id = shift;
	my $origin;
	my $wclause;

	if ($job_id) {
		$origin  = "R";
		$wclause = "JID = '$job_id' ";
	} else {
		$origin  = 'S';
		#FWIW: +BEAT prevent accumulating shifts; cast(LASTSTRTS as int) would also act as floor(LASTSTRTS)
		$wclause = "strftime('%s', 'now')-LASTSTRTS+$BEAT >= RUNINTERVAL AND VALIDITY = 'Y' ";
	}

	my $dbh = db_connect($SCHED{SQL_DB_JOBS});
	if (not $dbh) {
		logit("Error connecting to $SCHED{SQL_DB_JOBS}: $DBI::errstr");
		myexit(1);
	}

	my $q = qq(SELECT JID,"$origin" as ORG,'' as RQ,RES,XEQ1,XEQ2,XEQ3,MAXSYSLOAD,LOGPATH)
		    .qq( FROM JOBS WHERE $wclause);
	# Return reference for future %CANDIDATES = %{$rs};
	my $ref = $dbh->selectall_hashref($q, 'JID');

	$dbh->disconnect()
		or warn "Got warning while disconnecting from $SCHED{SQL_DB_JOBS}: "
		        . $dbh->errstr;
	return $ref;
}

# ----------------------------------------------------------
# insert or update DB : execute SQL query passed in
# ----------------------------------------------------------
sub DBUPDATE {
	my $query = shift;
	return if not $query;

	my $dbh = db_connect($SCHED{SQL_DB_JOBS});
	if (not $dbh) {
		logit("Error connecting to $SCHED{SQL_DB_JOBS} for update: $DBI::errstr");
		return;
	}

	logit("Executing query [$query]") if ($verbose);
	my $rv = $dbh->do($query);  # This will die on error

	$dbh->disconnect()
		or warn "Got warning while disconnecting from $SCHED{SQL_DB_JOBS}: "
		        . $dbh->errstr;
	return $rv == 0E0 ? 0 : $rv;
}

# ----------------------------------------------------------
# ENQ a job's resource
# $_[0]=resource, $_[1]=jid
# $_[0] may be a + separated list of resources
# creates $SCHED{PATH_RES}/resource(s)--jid-ts file(s)
# returns 0 if success OR no args
# returns 1 if resource busy
# ----------------------------------------------------------
sub ENQ {
	if (defined($_[0]) && defined($_[1]) && $_[0] ne '') {
		my $ts  = strftime("%Y%m%d-%H%M%S",localtime(time));
		my @res = split(/\+/,$_[0]);
		foreach (@res) { s/^\s+|\s+$//g }

		# fails if one of requested resources is not free
		foreach (@res) {
			my @u = glob("$SCHED{PATH_RES}/$_--*");
			return 1 if scalar(@u) > 0;
		}

		# then actually enq all requested resources
		foreach (@res) {
			my $resource_file = "$SCHED{PATH_RES}/$_--$_[1]-$ts";
			open(my $f, '>', $resource_file)
				or die "Unable to create file '$resource_file': $!";
			close($f)
				or warn "Error while closing file '$resource_file': $!";
			logit("enq $_, jid($_[1])") if ($verbose);
		}
	}
	return 0
}

# ----------------------------------------------------------
# DEQ a job's resource
# $_[0]=resource, $_[1]=jid
# $_[0] may be a + separated list of resources
# delete $SCHED{PATH_RES}/resource(s)--* file(s)
# returns 0
# ** TBD: could check that only jid that ENQd can DEQ
# ----------------------------------------------------------
sub DEQ {
	if (defined($_[0]) && defined($_[1]) && $_[0] ne '') {
		foreach my $res (split(/\+/,$_[0])) {
			$res =~ s/^\s+|\s+$//g;
			my @g = glob("$SCHED{PATH_RES}/$res--*");
			if (@g) {
				unlink @g;
				logit("deq $res, jid($_[1])") if ($verbose);
			}
		}
	}
	return 0
}

# ----------------------------------------------------------
# UDPS receives incoming cmds/jobs on non-blocking socket
# ----------------------------------------------------------
sub UDPS {
	my $msg = '';
	my $cmd = '';
	my $ans = '';
	my $junk = '';

	# Read message from the UDFP socket, if any, or return
	$SOCK->recv($msg, $SCHED{SOCKET_MAXLEN}) or return;

	my $sock_client_id = $SOCK->peerhost().":".$SOCK->peerport();
	$msg =~ s/^\s+|\s+$//g;
	($cmd, $msg) = split / /, $msg, 2;
	$cmd ||= 'nil';
	$msg ||= 'nil' ;
	for ($cmd) {
		if (/^JOB/i && $msg) {
			my $timekey = time;
			$JOBRQ{$timekey}{REQ} = $msg;
			$JOBRQ{$timekey}{TTL} = $SCHED{CANCEL_SUBMIT};
			# assign a dynamic jid, even if overidden later because it appears to be a jid= command
			$DynJid = -1 if (--$DynJid < -10E9); # dynamic jid , -10**9 rollover
			$JOBRQ{$timekey}{JID} = "$DynJid";
			$ans = "request for job queued\n";
			next;
		}
		if (/^KILLJOB/i && $msg) {
			if (not $msg =~ /^kid=(\d+)$/) {
				$ans = "killjob command: invalid argument, should be 'kid=XXX'\n";
				next;
			}
			my $pid = $1;
			logit("killing job $pid") if ($verbose);
			my $count = kill 'TERM', $pid;
			if ($count > 0) {
				$ans = "job with pid = $pid has been killed. Please check!\n";
			} else {
				$ans = "ERROR: unable to kill job with pid = $pid. Please check the kid argument.\n";
			}
			next;
		}
		if (/^ENQ/i && $msg) {
			if (ENQ($msg,$sock_client_id)) {
				$ans = "busy $msg";
			} else {
				$ans = "ENQ'd $msg\n";
			}
			next;
		}
		if (/^DEQ/i && $msg) {
			if (DEQ($msg,$sock_client_id)) {
				$ans = "failed DEQ $msg";
			} else {
				$ans = "DEQ'd $msg\n";
			}
			next;
		}
		if (/CMD/i) {
			for ($msg) {
				if (/^PAUSE$/i && $PAUSED != 2) {
					$PAUSED = 1 ;
					$ans = "Paused\n";
					next;
				}
				if (/^RESUME$/i && $PAUSED != 2) {
					$PAUSED = 0;
					$ans = "Resumed\n";
					next;
				}
				if (/^RUNQ/i) {
					$ans = '';
					if (not %RUNQ) {
						$ans .= "No running jobs.\n";
						next;
					}
					for my $id (sort keys %RUNQ) {
						my $start_dt = DateTime->from_epoch(epoch => $id,
						                                    time_zone => $local_tz);
						$ans .= sprintf("RUNQ(%s) started on %s %s\n", $id,
										$start_dt->strftime('%F %T (UTC%z)'));
						for my $j (sort keys %{$RUNQ{$id}}) {
							$ans .= "   $j=";
							$ans .= defined($RUNQ{$id}{$j}) ? "$RUNQ{$id}{$j}\n" : "nil\n";
						}
					}
					next;
				}
				if (/^JOBQ/i) {
					$ans = '';
					if (not %JOBRQ) {
						$ans .= "No jobs in waiting queue.\n";
						next;
					}
					for my $j (sort keys (%JOBRQ)) {
						$ans .= "ttl=$JOBRQ{$j}{TTL} ".substr($JOBRQ{$j}{REQ},0,40)."...\n";
					}
					next;
				}
				if (/^QS/i) {
					my @jobq = map("$JOBRQ{$_}{JID}", sort(keys(%JOBRQ)));
					my @lmiss = sort(keys(%LMISS));
					my @emiss = sort(keys(%EMISS));
					my @runq = map("$RUNQ{$_}{jid} (pid $RUNQ{$_}{kid})",
					               sort(keys(%RUNQ)));
					my @enqs = map { s/$SCHED{PATH_RES}\///; s/--.*$//; $_; }
					               (sort glob("$SCHED{PATH_RES}/*"));

					$ans = "JOBQ: " . (@jobq ? join(', ', @jobq) : "none")
					       ."\nLMISS: " . (@lmiss ? join(', ', @lmiss) : "none")
					       ."\nEMISS: " . (@emiss ? join(', ', @emiss) : "none")
					       ."\nRUNQ: " . (@runq ? join(', ', @runq) : "none")
					       ."\nENQs: " . (@enqs ? join(', ', @enqs) : "none")
					       ."\n";
					next;
				}
				if (/^VERBOSE$/i && $PAUSED != 2) {
					$verbose = 1;
					$ans = "Verbose On\n";
					next;
				}
				if (/^QUIET$/i && $PAUSED != 2) {
					$verbose = 0;
					$ans = "Verbose Off\n";
					next;
				}
				if (/^FLOG$/i && $PAUSED != 2) {
					$forcesavelog = 1;
					$ans = "Log will be backed up on next write\n";
					next;
				}
				if (/^STOP$/i && $PAUSED != 2) {
					$ans = 'Stopping';
					my $nb_kids = keys(%kids);
					if ($nb_kids) {
						$ans .= " after waiting for $nb_kids job(s)"
								." to end: ".join(', ', keys(%kids));
					} else {
						$ans .= " now.";
					}
					$SOCK->send("$ans\n");
					logit("client ".$sock_client_id." sent [ $msg ]");
					exit_after_jobs();
					next;
				}
				if (/^STAT$/i) {
					my $now = time;
					$ans  = "STATTIME=".strftime("%Y-%m-%d %H:%M:%S (UTC%z)",localtime($now))."\n";
					my @enqs = glob("$SCHED{PATH_RES}/*");
					my @paused = ('No','Yes','Stopping...');
					$ans .= "STARTED=$STRTTS\n";
					$ans .= "PID=$PID\n";
					$ans .= "USER=$PUID\n";
					$ans .= "uTICK=$utick\n";
					$ans .= "BEAT=$SCHED{BEAT}\n";
					$ans .= sprintf("ELT=%.3f (%.2f%%)\n", $ELT, ($ELT*100)/($now-$STRT));
					$ans .= "LOG=$LOGNAME\n";
					$ans .= "JOBSDB=$SCHED{SQL_DB_JOBS}\n";
					$ans .= "JOBS STDio=$SCHED{PATH_STD}\n";
					$ans .= "JOBS RESource=$SCHED{PATH_RES}\n";
					$ans .= "PAUSED=$paused[$PAUSED]\n";
					$ans .= "#JOBSTART=$JSTARTED\n";
					$ans .= "#JOBSEND=$JENDED\n";
					$ans .= "KIDS=".scalar(keys(%kids))."\n";
					$ans .= "ENQs=".scalar(@enqs)."\n";
					next;
				}
				$ans = "command unknown or invalid at this time\n";
			}
			next;
		}
		$ans = "Unknown action '$_'.\n";
	}
	$SOCK->send($ans);
	logit("client ".$sock_client_id." sent [ $cmd $msg ]; reply ".length($ans)." bytes") if ($verbose);
}

# ----------------------------------------------------------
# write to scheduler's log
# ----------------------------------------------------------
sub logit {
	my ($logtxt) = @_;
	my $TS=[gettimeofday];
	my $ts=sprintf ("%s.%6.6s", strftime("%Y-%m-%d %H:%M:%S",localtime(@$TS[0])),@$TS[1]*100);
	my $tsdate=substr($ts,0,10);

	if (($lldate ne '' && $tsdate ne $lldate) || $forcesavelog == 1) {
		# it is time to save the log file and start a new one
		$forcesavelog = 0;
		close(LOG);
		(my $tsfn = $ts) =~ s| |-|g;
		my $rc = move("$LOGNAME", "$SAVELOGPATH/$tsfn");
		open LOG, ">>$LOGNAME";
		if ($rc == 0) {
			print LOG "$ts saved log to $SAVELOGPATH/$tsfn\n";
		} else {
			print LOG "$ts: Error: could not move file '$LOGNAME' to '$SAVELOGPATH/$tsfn'\n";
		}
	}

	if ($logtxt ne $DITTO) {
		if ($DITTO ne '' && $DITTOCNT != 0) {
			print LOG "$ts $DITTO (x$DITTOCNT)\n";
		}
		print LOG "$ts $logtxt\n";
		$DITTO = $logtxt;
		$DITTOCNT = 0;
	} else {
		if ($DITTOCNT++ == $SCHED{DITTO_LOG_MAX}-1) {
			print LOG "$ts $DITTO (x$DITTOCNT)\n";
			$DITTOCNT = 0;
		}
	}
	$lldate = $tsdate;
}

# ----------------------------------------------------------
# send notification to postboard
# ----------------------------------------------------------
sub notifyit {
	my ($ntftxt) = @_;
	my $ntf;

	if ($ntftxt ne $DITTONTF) {
		if ($DITTONTF ne '' && $DITTONTFCNT != 0){
			$ntf=sprintf ("%s (x%s)", $DITTONTF,$DITTONTFCNT);
			WebObs::Config::notify("$ntf");
		}
		$ntf=sprintf ("%s", $ntftxt);
		WebObs::Config::notify("$ntf");
		$DITTONTF = $ntftxt;
		$DITTONTFCNT = 0;
	} else {
		if ($DITTONTFCNT++ == $SCHED{DITTO_LOG_MAX}-1) {
			$ntf=sprintf ("%s (x%s)", $DITTONTF,$DITTONTFCNT);
			WebObs::Config::notify("$ntf");
			$DITTONTFCNT = 0;
		}
	}
}

# ----------------------------------------------------------
# clean exit with optional rc
# ----------------------------------------------------------
sub myexit {
	my $code = shift // 1;
	logit("scheduler[$$] exiting with code $code.");
	close(LOG);
	exit($code);
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon

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
