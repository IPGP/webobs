#!/usr/bin/perl

=head1 NAME

scheduler.pl

=head1 SYNOPSIS

 $ perl scheduler.pl [-v] [-c config-filename]

   -v   : be verbose
   -V   : be more verbose
   -n   : erase scheduler.log (if any) when starting 
   -c   : specify a scheduler configuration file instead of the 
          default WEBOBS 'CONF_SCHEDULER' 

=head1 DESCRIPTION

B<WebObs Jobs Scheduler>. To be automatically (re)started and looping forever to 
schedule/monitor executions of B<jobs> from the B<JOBS DataBase table> and 
from dynamic submit requests that it may receive on its dedicated UDP port. 

=head2 CONFIGURATION PARAMETERS

The WebObs Jobs scheduler has configuration parameters stored in a file,
that is read once at scheduler load time. The configuration filename may be passed as an option
or automatically defaults to the filename pointed to by the B<CONF_SCHEDULER> key 
in the common WebObs structure B<$WEBOBS>. The file is 'readCfg()' interpretable. 

	# CONF_SCHEDULER|${ROOT_CONF}/scheduler.rc    # in WEBOBS.rc

	# scheduler.rc example configuration file 
	#
	=key|value                                    # readCfg() specification
	BEAT|2                                        # find/start jobs each BEAT seconds
	MAX_CHILDREN|10                               # maximum simultaneous jobs running
	PORT|7761                                     # client-commands UDP port number
	SOCKET_MAXLEN|1500;                           # client-command max msg length
	SQL_DB_JOBS|$WEBOBS{ROOT_CONF}/WEBOBSJOBS.db  # sqlite DataBase name for JOBS table
	LOADAVG1_THRESHOLD|0.7                        # 1' max system load averages 
	LOADAVG5_THRESHOLD|0.7                        # 5' =
	LOADAVG15_THRESHOLD|0.7                       #15' =
	PATH_STD|$WEBOBS{ROOT_CONF}/jobslogs          # root directory for all jobs STDOUT/ERR
	PATH_RES|$WEBOBS{ROOT_CONF}/res               # root directory for jobs resources (==ENQ ==LOCKS)

=head2 JOBS DATABASE

Periodic jobs are defined in the scheduler's B<JOBS> table of the DataBase defined by B<SQL_DB_JOBS>.
A job is identified by its unique B<JID> and by its 3-tuple B<XEQ1 XEQ2 XEQ3> that form
the 'PROGRAM LIST' passed to 'exec' for job's execution (see 'exec' syntax in perldoc). 
Each row of B<JOBS> is a single job definition consisting of the following columns/information: 

	JID            int, unique jobid assigned by the system when inserting a job defintion
	VALIDITY       char, Y|N : wether this definition is currently valid (Y), ie. processed or ignored
	XEQ1           text, 1st element of 'exec' 
	XEQ2           text, 2nd element of 'exec'
	XEQ3           text, 3rd element of 'exec'
	RUNINTERVAL    int, how many seconds between two runs of the job
	MAXINSTANCES   int, 0 = allow concurrent instances of job, 1 = only 1 instance running
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

Scheduler.pl, while processing/monitoring jobs definitions, also listens for B<client-commands> on a dedicated B<UDP port>. 
These commands either B<modify/query> the scheduler's configuration OR B<submit jobs> 
to be immediately executed (if possible): ie. I<inserted> into the 
current scheduling loop. 

A utility script B<jobq.pl> is available to send one command at a time to the active WebObs Scheduler.
See its perldoc for help.

The following commands are understood by the WebObs Scheduler (all of these are case insensitive):

=over

=item B<JOB { JID=jid  | 'job-definition-string }>

Submit a job defined in JOBS table as I<jid> to the Scheduler for immediate execution if possible.

-or- Submit job defined by job-definition-string eg. 'XEQ1:perl, XEQ2:somepgm.pl, XEQ3:5' 

=item B<CMD PAUSE>

Suspends the execution of the Scheduler (until resumed with CMD START)

=item B<CMD START>

Resumes excution of PAUSED Scheduler.

=item B<CMD VERBOSE> 

Places Scheduler in 'verbose' mode (for debugging) if it wasn't started with this option.

=item B<CMD QUIET>

Cancels 'verbose' mode.

=item B<CMD STOP>

Stops the Scheduler ! This command freezes any Scheduler inputs (DB and socket), waits 
for its started jobs to end (if any), then stps Scheduler process. 

=item B<CMD STAT>

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
(event-name => situation) :

	scheduler.critical  => system loadavg thresholds have been reached, before selecting candidates jobs
	scheduler.critical  => maximum # of process kids already running, before selecting candidates jobs
	scheduler.critical  => couldn't fork for executing a job
	scheduler.warning   => a job is candidate, but already in the runQ and its maxintances don't allow
	scheduler.warning   => a job is candidate, but its maxsysload has been reached
	scheduler.critical  => scheduler has been stopped from a 'STOP' command
	scheduler.critical  => scheduler has been killed (sigint received)

=cut

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin; 
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime :signal_h :errno_h :sys_wait_h/;
use DBI;
use Getopt::Std;
use IO::Socket;
use File::Basename;
use File::Path qw/make_path/;
use feature qw(switch);

use WebObs::Config;

# ---- parse options
# ---- -v to be verbose, -c to specify configuration file 
# -----------------------------------------------------------------------------
my %options;
getopts("Vvnc:",\%options);
my $verbose=0;
#fixJul -v and -V conflict
$verbose  = defined($options{v}) ? 1 : 0;
$verbose  = defined($options{V}) ? 1 : $verbose;
my $verbose2 = defined($options{V}) ? 1 : 0;
my $configf  = defined($options{c}) ? $options{c} : '';
my $newlog   = defined($options{n}) ? 1 : 0;

my $ME = basename($0); $ME =~ s/\..*//;

# ---- initialize : tell'em who I am 
# ----------------------------------------------------------------------------
if (!defined($WEBOBS{ROOT_LOGS})) {
	printf("Can't start: no ROOT_LOGS in WebObs configuration\n");
	exit(1);
}
if ( -f "$WEBOBS{ROOT_LOGS}/$ME.pid" ) {
	printf("Can't start: already running\n");
	exit(1);
}
my @junk = qx(echo $$ >$WEBOBS{ROOT_LOGS}/$ME.pid);

my $LOGNAME = "$WEBOBS{ROOT_LOGS}/$ME.log" ;
unlink($LOGNAME) if (-e $LOGNAME && $newlog);
if (! (open LOG, ">>$LOGNAME") ) { 
	print "Can't start: couldn't open $LOGNAME: $!\n";
	unlink("$WEBOBS{ROOT_LOGS}/$ME.pid");
	exit(1);
}
select((select(LOG), $|=1)[0]);  # turn off buffering
logit("------------------------------------------------------------------------");

# ---- initialize: internal structures 
# -----------------------------------------------------------------------------
our $STRTTS = strftime("%Y-%m-%d %H:%M:%S",localtime(time)); # when I was started 
our $PID = $$;				   # my own pid (parent of all running kids)
our $PUID= qx(id -un);chomp($PUID); # who am I after all 
our $PAUSED = 0;			   # tick but don't schedule anything if PAUSED
our %kids;					   # 'running' kids hash: $kids{kid_pid} = internal kid_id 
our $kidcmd;				   # command to be executed by currently forked kid
our $jid = 0;				   # currently processed job id
our $dcd = 0;				   # ended kid_pid in the REAPER's waitpid loop
our $utick    = 1000000;	   # base tick (microseconds)
our $adjutick =  $utick;	   # utick adjusted for drift
our %CANDIDATES;			   # jobs, candidates for this 'tick' from DB and Q 
our %RUNQ;					   # jobs, running ()
our @JOBRQ;					   # queued jobs from udp client
our @CMDRQ;					   # queued cmds from udp client
our $JSTARTED=0;			   # number of jobs started so far, for this scheduler's session
our $JENDED=0;             	   # number of jobs ended so far, for this scheduler's session
our $CFGF='';                  # active configuration filename 
our %SCHED;                    # active configuration 
our $TS=0;                     # timestamp
our $DynJid=-1;                # to allocate 'dynamic' jids to Q jobs (user input)


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
our $SOCK = IO::Socket::INET->new(LocalPort => $SCHED{PORT},Proto => 'udp',Blocking => 0);
if ( !$SOCK )  { 
	logit("scheduler $$ won't start, UDP socket $SCHED{PORT} error: $? $!"); 
	printf("scheduler $$ won't start, UDP socket $SCHED{PORT} error: $? $!\n"); 
	myexit(1);
}
	
# ---- system load averages access+interpretation setups   
# -----------------------------------------------------------------------------
our $ncpus = 1;            # number of cpus (defaults to 1)
if (open FILE, "< /proc/cpuinfo") {
	$ncpus = scalar grep(/^processor\s+:/,<FILE>);
	close FILE;
	$SCHED{LOADAVG1_THRESHOLD} *= $ncpus;     # user specs adapted to # of cpus 
	$SCHED{LOADAVG5_THRESHOLD} *= $ncpus;     # user specs adapted to # of cpus
	$SCHED{LOADAVG15_THRESHOLD} *= $ncpus;    # user specs adapted to # of cpus
}
our ($avg1,$avg5,$avg15) = 0;         # work-vars for sys load averages

# --- root of all jobs' logs (STDOUT/STDERR redirections) directories
# -----------------------------------------------------------------------------
if (system("mkdir -p $SCHED{PATH_STD}")) {  
	logit("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_STD}: $? $!"); 
	printf("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_STD}: $? $!\n"); 
	myexit(1);
}

# --- root of all jobs' 'resource' (enq=locks) directories
# -----------------------------------------------------------------------------
if (system("mkdir -p $SCHED{PATH_RES}")) {  
	logit("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_RES}: $? $!"); 
	printf("scheduler $$ won't start, couldn't mkdir $SCHED{PATH_RES}: $? $!\n"); 
	myexit(1);
}

# -----------------------------------------------------------------------------
# ---- scheduler's main process, stopped via SIGINT 
# ---- or better still, by an external Q command 'STOP'
# -----------------------------------------------------------------------------
logit("scheduler started - PID=$PID CFG=$CFGF USR=$PUID"); 
if (-t STDOUT) { printf("scheduler PID=$PID started - logging to $LOGNAME - $PUID\n"); }
logit("beat = $SCHED{BEAT} * ".($utick/1000000)." sec.");
logit("max parallel jobs = $SCHED{MAX_CHILDREN}"); 
logit("$ncpus cpu(s), load thresholds = $SCHED{LOADAVG1_THRESHOLD} (1'), $SCHED{LOADAVG5_THRESHOLD} (5'), $SCHED{LOADAVG15_THRESHOLD} (15')");
logit("jobs database = $SCHED{SQL_DB_JOBS}");
logit("jobs stdout/stderr to $SCHED{PATH_STD}/<job>");
logit("jobs resources in $SCHED{PATH_RES}/<jobres>");
logit("listening for DGRAM on port $SCHED{PORT}");

$SCHED{BEAT} ||= 2; # job select+fork beat (multiple of tick)

$SIG{INT} = $SIG{TERM} = $SIG{KILL} = \&LEAVE;

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
		# leave (ignore) this tick if current system load too high (SYSLOAD)
		# leave (ignore) this tick if max number of forked kids already reached
		# select candidate jobs for this BEAT tick from JOBRQ and JOBS DataBase
			#   all JOBRQ jobs 
			# + DataBase jobs whose last 'run' is older than their defined RUNINTERVAL 
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

our $BEAT = $SCHED{BEAT};  
while (1) {

	my $psdmsg = sprintf ("%u %s wait %d (d=%f,beat=%d)", $$,$PAUSED?" paused":"",int($adjutick),$adjutick-int($adjutick),$BEAT);
	if ($verbose2) { logit($psdmsg) }
	usleep(int($adjutick));
	my $t0 = [gettimeofday];
	$BEAT-- if (!$PAUSED);
	UDPS();                        
	if (!$PAUSED && !$BEAT) {
		$BEAT = $SCHED{BEAT};
		if (SYSLOAD()) { WebObs::Config::notify("scheduler.critical|$$|Loadavg thresholds reached"); next }                        
		if (REAPER() == $SCHED{MAX_CHILDREN}) { WebObs::Config::notify("scheduler.critical|$$|Maximum number of started processes reached"); next }; 
		CANDIDATES();
		if ($verbose2) {
			logit(scalar(keys(%CANDIDATES))." candidate(s): ");
			map {logit("  $CANDIDATES{$_}{JID}: $CANDIDATES{$_}{XEQ1} $CANDIDATES{$_}{XEQ2} $CANDIDATES{$_}{XEQ3} ")} keys(%CANDIDATES);
		}
		for my $jid (keys(%CANDIDATES)) {
			my $maxRunQid = (reverse sort keys %RUNQ)[0] || 0;
			# no leading/trailing blanks in command components
			$CANDIDATES{$jid}{XEQ1} =~ s/^\s+|\s+$//g; $CANDIDATES{$jid}{XEQ2} =~ s/^\s+|\s+$//g; $CANDIDATES{$jid}{XEQ3} =~ s/^\s+|\s+$//g;
			# command components can reference $WEBOBS{} variables: dereference now
			$CANDIDATES{$jid}{XEQ1} =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g;
			$CANDIDATES{$jid}{XEQ2}  =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g;
			$CANDIDATES{$jid}{XEQ3}     =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g;
			my $kidcmd  = "$CANDIDATES{$jid}{XEQ1} $CANDIDATES{$jid}{XEQ2} $CANDIDATES{$jid}{XEQ3}";
			# check if eligible for RUNQ ? if NOT and coming from JOBRQ: return to JOBRQ
			if ( $CANDIDATES{$jid}{MAXSYSLOAD} <= $avg5 ) { logit("candidate but loadavg too high: $jid"); 
			                                                WebObs::Config::notify("scheduler.warning|$$|Job [ $kidcmd ] candidate but loadavg too high"); 
			                                                if ( $CANDIDATES{$jid}{ORG} eq "R" && $CANDIDATES{$jid}{RQ} ne '' ) { push(@JOBRQ, $CANDIDATES{$jid}{RQ}) }
															next; 
														  }
			if ( ENQ($CANDIDATES{$jid}{RES},$jid) == 1 )  { logit("candidate but resource busy: $jid");
			                                                if ( $CANDIDATES{$jid}{ORG} eq "R" && $CANDIDATES{$jid}{RQ} ne '' ) { push(@JOBRQ, $CANDIDATES{$jid}{RQ}) }
				                                            next;
                                                          }
			if ( $CANDIDATES{$jid}{MAXINSTANCES} > 0 )    { my $jcnt = 0;
			                                                for (keys(%RUNQ)) { $jcnt += 1 if ($RUNQ{$_}{jid} == $jid) }
															if ($jcnt >= $CANDIDATES{$jid}{MAXINSTANCES} ) {
																logit("candidate but maxinstances reached: $jid");
			                                                	if ( $CANDIDATES{$jid}{ORG} eq "R" && $CANDIDATES{$jid}{RQ} ne '' ) { push(@JOBRQ, $CANDIDATES{$jid}{RQ}) }
				                                            	next;
															}
			                                              }
			$maxRunQid = 0 if (++$maxRunQid > 2**31);  # 2**31 integer rollover
			my $Qid = $maxRunQid;  
			$RUNQ{$Qid}{kidcmd}  = $kidcmd;
			$RUNQ{$Qid}{kid}     = 0;
			$RUNQ{$Qid}{res}     = $CANDIDATES{$jid}{RES} ;
			$RUNQ{$Qid}{jid}     = $jid;
			# take care of stdout/err redirections and targets ...
			my $redir = '>'; 
			(my $RTNE_ = $CANDIDATES{$jid}{XEQ2}) =~ s/\s+/_/g;
			$CANDIDATES{$jid}{LOGPATH} ||= $RTNE_ ;
			if ($CANDIDATES{$jid}{LOGPATH} =~ m/(^>{1,2})(.*)$/) { $redir = $1; $CANDIDATES{$jid}{LOGPATH} = $2; } 
			$RUNQ{$Qid}{started} = time;
			$CANDIDATES{$jid}{LOGPATH} =~ s/\{TS\}/$RUNQ{$Qid}{started}/g ;
			$CANDIDATES{$jid}{LOGPATH} =~ s/\{RTNE\}/$RTNE_/g ;
			my ($logfn,$logfd) = fileparse($CANDIDATES{$jid}{LOGPATH});
			make_path("$SCHED{PATH_STD}/$logfd");
			# moved up to have DB and logpath match, but would be better if closer to fork !! : $RUNQ{$Qid}{started} = time;
			$RUNQ{$Qid}{kidcmd} =~ s/'/''/g; 
			DBUPDATE("UPDATE jobs set laststrts=$RUNQ{$Qid}{started} WHERE jid=$RUNQ{$Qid}{jid} ");
			DBUPDATE("INSERT INTO runs (jid,org,startts,cmd,endts) values($RUNQ{$Qid}{jid},\"$CANDIDATES{$jid}{ORG}\",$RUNQ{$Qid}{started},'$RUNQ{$Qid}{kidcmd}',0) ");
			$JSTARTED++;
			my $kid = fork();                 
			if (!defined($kid)) { 
				logit("$$ couldn't fork [ $kidcmd ] !"); 
				WebObs::Config::notify("scheduler.critical|$$|couldn't fork [ $kidcmd ]"); 
				next; 
			}
			if ($kid == 0) { # kid's code
				$logfn ||= $$; # fall back -- last chance for a unique name (?)
				open STDOUT, $redir, "$SCHED{PATH_STD}/$logfd/$logfn.stdout"; 
				open STDERR, $redir, "$SCHED{PATH_STD}/$logfd/$logfn.stderr";
				printf (STDOUT "\n*** %s %s %s ***\n\n","STDOUT WEBOBS JOB *** STARTED ",strftime("%Y-%m-%d  %H:%M:%S",localtime($RUNQ{$Qid}{started}))," [ $kidcmd ]");
				printf (STDERR "\n*** %s %s %s ***\n\n","STDERR WEBOBS JOB *** STARTED ",strftime("%Y-%m-%d  %H:%M:%S",localtime($RUNQ{$Qid}{started}))," [ $kidcmd ]");
				DBUPDATE("UPDATE runs set kid=$$,stdpath=\"$redir $logfd/$logfn.std{out,err}\" WHERE jid=$RUNQ{$Qid}{jid} AND startts=$RUNQ{$Qid}{started} ");
				# alea jacta est ... one way ticket to the job !
				exec $kidcmd or logit("$$ couldn't exec [ $kidcmd ]: $!");
				#?? array avoid intermed. shell ?? exec  $Akidcmd[0] ($Akidcmd[1], $Akidcmd[2]) or printf ("%16.6f %s",time,"$$ couldn't exec [ $kidcmd ]: $!");
			} else {         # parent's code continued                                 
				#$logfn ||= $kid;				    # strictly equivalent to '$logfn ||= $$' in kid's code !;
				$RUNQ{$Qid}{kid} = $kid;            # link runQ element to kid pid
				$kids{$kid} = $Qid;                 # link kid pid list to runQ
				if ($verbose) {
					logit("forked $kid [ $kidcmd ] Q:$Qid,R(Q):$RUNQ{$Qid}{kid},K:$kids{$kid}");
					logit("logs $kid: $redir $logfd/$logfn.std{out,err}");
				}
				next;
			}
		}
		REAPER();    
		if ($verbose2) {
			logit("$$ runQ: ");
			map {logit("  runQ $_ : jid=$RUNQ{$_}{jid} pid=$RUNQ{$_}{kid} started=$RUNQ{$_}{started} cmd=$RUNQ{$_}{kidcmd}")} keys(%RUNQ);
		}
		if ( ($adjutick = $utick - tv_interval($t0)) <= 0 ) {
			logit("$$ drift >= $SCHED{TICK} !!!");
			$adjutick = 0;
		}
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
		#my $dcdRC = $?; # default, see below each case
		my $dcdRC = ${^CHILD_ERROR_NATIVE}; # default, see below each case
		my $tend = time;
		my $dcdmsg = '';
		if ($? == -1) { $dcdmsg = sprintf (" failed to execute: $!"); }
		elsif ($? & 127) { 
			$dcdmsg = sprintf (" %s %d %s coredump","$dcd died with signal",($? & 127),($? & 128) ? '' : 'no');
		}                                                                             
		else {
			$dcdRC = $? >> 8;
			$dcdmsg = sprintf ("*%d", $dcdRC);
		}
		my $dcdQid = $kids{$dcd}; 
		DBUPDATE("UPDATE runs SET endts=$tend,rc=$dcdRC,rcmsg=\"$dcdmsg\" WHERE jid=$RUNQ{$dcdQid}{jid} AND startts=$RUNQ{$dcdQid}{started}");
		$JENDED++;
		#logit("$dcdmsg") if ($verbose);
		logit("reaper: kid($dcd), runQ($dcdQid), jid($RUNQ{$dcdQid}{jid})") if ($verbose);
		DEQ($RUNQ{$dcdQid}{res});
		delete $RUNQ{$dcdQid};
		delete $kids{$dcd};
	}
	return scalar(keys(%kids));
}

# ----------------------------------
# Exiting scheduler == either:
#   SIGINTx handler 
#   WebObs STOP command (udp client)
# ----------------------------------
sub LEAVE {
	my $signame = shift || '';
	if ($signame ne '') { 
		logit("$$ caught a SIG$signame signal"); 
		my $ets = REAPER();   # any extra-terrestrial survivors ?
		logit("$ets kid(s) out there !") if ($ets>0) ;  
		logit("$$ killed");
		WebObs::Config::notify("scheduler.critical|$$|scheduler killed (sigint)"); 
		myexit(1);
	}
	else { # not a signal
		$PAUSED = 1;   # not quite necessary, we're in the parent's main loop !!
		logit("$$ waiting for kid(s) to end ..."); 
		while ( REAPER() != 0 ) { sleep(1); } ; 
		logit("$$ stopped");
		WebObs::Config::notify("scheduler.critical|$$|scheduler stopped (quit command)"); 
		myexit(0);
	}
}

# ----------------------------------------------------------
# SYSLOAD true if system's loadavg > user-defined thresholds  
# ----------------------------------------------------------
sub SYSLOAD {
	# ---- grab fresh system's loadavg figures 
	if ( open FILE, "< /proc/loadavg" ) { 
		($avg1, $avg5, $avg15, undef, undef) = split / /, <FILE>;
		close FILE;
		# ---- system's loadavg vs user thresholds 
		if ( $avg1>$SCHED{LOADAVG1_THRESHOLD} || $avg5>$SCHED{LOADAVG5_THRESHOLD} || $avg15>$SCHED{LOADAVG15_THRESHOLD}) {
			logit(" $$ system load > threshold: $avg1/$SCHED{LOADAVG1_THRESHOLD}  $avg5/$SCHED{LOADAVG5_THRESHOLD}  $avg15/$SCHED{LOADAVG15_THRESHOLD}") if ($verbose);   
			return(1);
		}
	} else { logit("$$ ignoring loadavg: $!") }
	return(0);
}

# ----------------------------------------------------------
# CANDIDATES select all jobs that could be run now, from DB and Q   
# ----------------------------------------------------------
sub CANDIDATES {
	%CANDIDATES = %{DBSELECT()};

	my $jrq;
	while ( @JOBRQ ) {
		$jrq= shift @JOBRQ;
		$jrq =~ s/^\s+|\s+$//g;
		if ( $jrq =~ m/JID=\s*([0-9]*)\s*/i ) {
			# a %CANDIDATES entry from a user request "jid=<job's id>" 
			my $jrqid = $1;
			my %tmp = %{DBSELECT($jrqid)};
			@CANDIDATES{keys %tmp} = values %tmp;
			logit("$$ recvd Q JOB JID=$jrqid: "); 
			map { logit("$_=>$tmp{$_} ")} keys(%tmp); 	
		} else {
			my $tj = JDPARSE($jrq);
			if ( $tj ) { logit("$$ recvd Q JOB, jid=$tj = $jrq ") } 
			else {logit("$$ recvd Q JOB, parse failed: $jrq ")}
		}
	}
	return scalar(keys(%CANDIDATES));
}
# ----------------------------------------------------------
# helper: parse job definitions from Q (ie. user input)
# user must enter "XEQ1:'launch text',XEQ2:'routine text',XEQ3:'a1 a2',...."
# ----------------------------------------------------------
sub JDPARSE {
	my %KW = split /[:,]/, $_[0];
	$KW{XEQ1} ||= ''; 
	$KW{XEQ2} ||= ''; 
	$KW{XEQ3} ||= '';
	$KW{MAXINSTANCES} ||= 0;
	$KW{MAXSYSLOAD}   ||= 0.8;
	$KW{LOGPATH}  ||= 'undef';
	$KW{RES} ||= '';
	$KW{RQ}   = $_[0];
	$KW{ORG}  = 'R';
	if ( "$KW{XEQ1}$KW{XEQ2}$KW{XEQ3}" ne "" ) {
		$DynJid = -1 if (--$DynJid < -2**30);  # integer rollover
		$KW{JID} = $DynJid;
		$CANDIDATES{$KW{JID}} = \%KW;
		return $KW{JID};
	}
	return 0;
}

# ----------------------------------------------------------
# reads all 'valid & ready' jobs from DataBase table JOBS
# OR just one JOB definition (wether or not valid and ready)
# if its job's ID (JID) is passed as argument
# ----------------------------------------------------------
sub DBSELECT {
	my ($rs, $dbh, $sql, $sth);
	my $origin = my $wclause = ''; 
	if ( defined($_[0]) ) {
		$origin  = "R";
		$wclause = "JID = $_[0] ";
	} else {
		$origin  = 'S';
		$wclause = "strftime('%s','now')-LASTSTRTS > RUNINTERVAL AND VALIDITY = 'Y' ";
	}
	$dbh = DBI->connect( "dbi:SQLite:".$SCHED{SQL_DB_JOBS},"","")
		or die "DB error connecting to ".$SCHED{SQL_DB_JOBS}.": ".DBI->errstr;
	$dbh->{PrintError} = 1; 
	$dbh->{RaiseError} = 1; 
	$sql  = "SELECT JID,\"$origin\" as ORG,'' as RQ, RES, XEQ1,XEQ2,XEQ3,MAXINSTANCES,MAXSYSLOAD,LOGPATH";
	$sql .=	" FROM JOBS WHERE $wclause"; 
	$sth = $dbh->prepare($sql);
	$sth->execute();
	$rs = $sth->fetchall_hashref('JID');
	$dbh->disconnect;
	#%CANDIDATES = %{$rs};
	return $rs;
}

# ----------------------------------------------------------
# insert or update DB : execute SQL query passed in
# ----------------------------------------------------------
sub DBUPDATE {
	if ($_[0]) {
			my $stmt = $_[0];
			logit("$stmt") if ($verbose);
			my $dbh = DBI->connect( "dbi:SQLite:".$SCHED{SQL_DB_JOBS},"","")
				or die "DB error connecting to ".$SCHED{SQL_DB_JOBS}.": ".DBI->errstr;
			$dbh->{PrintError} = 1; $dbh->{RaiseError} = 1; 
			my $rv  = $dbh->do($stmt); 
			#if (!defined($rv) || $rv == 0) { printf ("%16.6f %s",time,"failed to update DB for jid $RUNQ{$dcdQid}{jid}\n") }
			$dbh->disconnect;
			return $rv;
	}
}

# ----------------------------------------------------------
# ENQ a job's resource
# ** doesn't have to be system 'atomic', 
#    there's only 1 user/thread enqueing a resource: me !
# returns 0 if success (enq) or no resource defined
# returns 1 if resource busy (exists) 
# ----------------------------------------------------------
sub ENQ {
	if ( defined($_[0]) && defined($_[1]) && $_[0] ne '' ) {
		my $ts  = strftime("%Y-%m-%d %H:%M:%S",localtime(time));
		my $g = "$SCHED{PATH_RES}"."/"."$_[0]";
		if ( -e $g ) { return 1 }
		else         { logit("jid=".$_[1]." enq ".$_[0]." ($g)") if ($verbose); qx(echo $_[1]:$ts >$g) }
	}
	return 0
}

# ----------------------------------------------------------
# DEQ a job's resource
# ----------------------------------------------------------
sub DEQ {
	if ( defined($_[0]) && $_[0] ne '' ) {
		my $g = "$SCHED{PATH_RES}"."/"."$_[0]";
		if ( -e $g ) { logit("deq ".$_[0]) if ($verbose); unlink $g }
		if ( -e $g ) { return 1 }
	}
	return 0
}

# ----------------------------------------------------------
# UDPS receives incoming cmds/jobs on non-blocking socket
# ----------------------------------------------------------
sub UDPS {
	my $msg = my $cmd = my $ans = my $junk = '';
	if ( $SOCK->recv($msg, $SCHED{SOCKET_MAXLEN}) ) {
		$msg =~ s/^\s+|\s+$//g;
		logit("client ".$SOCK->peerhost.":".$SOCK->peerport." sent [ $msg ]") if($verbose);
		($cmd,$msg,$junk)=split(' ',$msg);
		given ($cmd) {
			when (/^JOB/i ) {
				push(@JOBRQ, $msg);
				$ans = 'Job Queued';
			} 
			when (/CMD/i) {
				given ($msg) { 
					when (/^PAUSE$/i) { 
						$PAUSED = 1 ;
						$ans = 'Pause requested';
					}
					when (/^START$/i) { 
						$PAUSED = 0;
						$ans = 'Pause off';
					}
					when (/^RUNQ/i) { 
						$ans = '';
						for my $id (keys %RUNQ) { $ans .= "$id=$RUNQ{$id}\n"; for (keys %{$RUNQ{$id}}) {$ans .= "..$_=$RUNQ{$id}{$_}\n"} }
					}
					when (/^JOBQ/i) { 
						$ans = '';
						for my $id (@JOBRQ) { $ans .= "$id\n"; }
					}
					when (/^VERBOSE$/i) { 
						$verbose = 1;
						$ans = 'Verbose On';
					}	
					when (/^QUIET$/i) { 
						$verbose = 0;
						$ans = 'Verbose Off';
					}
					when (/^STOP$/i) {
						$ans = 'Stopping now';
						$SOCK->send($ans);
						LEAVE();
					}
					when (/^STAT$/i) {
						$ans  = "STATTIME=".strftime("%Y-%m-%d %H:%M:%S",localtime(time))."\n";
						my @enqs = glob("$SCHED{PATH_RES}/*");
						$ans .= "STARTED=$STRTTS\n";
						$ans .= "PID=$PID\n";
						$ans .= "USER=$PUID\n";
						$ans .= "uTICK=$utick\n";
						$ans .= "BEAT=$SCHED{BEAT}\n";
						$ans .= "LOG=$LOGNAME\n";
						$ans .= "JOBSDB=$SCHED{SQL_DB_JOBS}\n";
						$ans .= "JOBS STDio=$SCHED{PATH_STD}\n";
						$ans .= "JOBS RESource=$SCHED{PATH_RES}\n";
						$ans .= "PAUSED=$PAUSED\n";
						$ans .= "#JOBSTART=$JSTARTED\n";
						$ans .= "#JOBSEND=$JENDED\n";
						$ans .= "KIDS=".scalar(keys(%kids))."\n";
						$ans .= "ENQs=".scalar(@enqs)."\n";
					}
					default { $ans = "unknown cmd"; }
				}
			} 
			default { $ans = "Huh?"; }
		}
		$SOCK->send($ans);
	}
}

# ----------------------------------------------------------
# write to scheduler's log 
# ----------------------------------------------------------
sub logit {
	my ($logText) = @_;
	my $TS=[gettimeofday];
	$logText = sprintf ("%s.%-6s %s", strftime("%Y-%m-%d %H:%M:%S",localtime(@$TS[0])),@$TS[1],$logText);
	print LOG "$logText\n";
}

sub myexit {
	close(LOG);
	unlink("$WEBOBS{ROOT_LOGS}/$ME.pid");
	exit($_[0]);
}

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

