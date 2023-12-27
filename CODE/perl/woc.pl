#!/usr/bin/perl

=head1 NAME

woc.pl  WebObs Console 

=head1 SYNOPSIS

 starting console interactive session:
 $ woc.pl 

 starting console batch execution:
 $ woc.pl  a-woc-command 

=head1 DESCRIPTION

B<woc> (webobs console) is the tool to query/display/update internal WebObs structures.
Initially built as a developer's set of debugging tools, B<woc> also contains some WebObs-administrator's tools. 

B<woc> can be run in B<interactive mode>, interpreting/executing woc-commands at the console's WOC prompt, or 
B<batch mode>, executing a single woc-command passed as argument. Woc is also available from a WebObs html-site
page thru the use of the woc.html/woc.js interface. 

=cut

# System requirements ----------------------------------------------------------
# ------------------------------------------------------------------------------
use strict;
use FindBin;
use lib $FindBin::Bin; 
use Data::Dumper;
use Term::ReadLine;
use POSIX;
use POSIX qw/strftime locale_h/;

our $WOPTR = '/etc/webobs.d';
exit if(! -l $WOPTR);
our $WOLNK = qx(ls -l $WOPTR); chomp($WOLNK);
$WOLNK=~s/^.* (.* -> .*)$/$1/;

use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Users;
use WebObs::Form;
our %SCHED;
if (defined($WEBOBS{CONF_SCHEDULER}) && -e $WEBOBS{CONF_SCHEDULER}) 
	{ %SCHED = readCfg($WEBOBS{CONF_SCHEDULER}) }

#$SIG{'INT'} = 'hINT';
$SIG{__WARN__} = 'hWARN';

my $cmd = my $op = my $obj = my $k = my $l = '';
my (@obj, @L, @F);
our $mode = 'interactive';

# WOC commands definitions/vectors ---------------------------------------------
# ------------------------------------------------------------------------------
my %vectors =
	( 
		'%WEBOBS'    => {'rtne' => \&dwebobs,  'seq' =>  10, 'auth' => 'R' ,'help' => '%WEBOBS [key]         : dump %WEBOBS key or all'},
		'-%WEBOBS'   => {'rtne' => \&rwebobs,  'seq' =>  20, 'auth' => 'R' ,'help' => '-%WEBOBS value        : which %WEBOBS key(s) holds value'},
		'%OWNERS'    => {'rtne' => \&downers,  'seq' =>  30, 'auth' => 'R' ,'help' => '%OWNERS               : dump all %OWNRS'},
		'%DISCP'     => {'rtne' => \&ddiscp,   'seq' =>  40, 'auth' => 'R' ,'help' => '%DISCP [discp]        : dump %DISCP discp discipline or all'},
		'%USERS'     => {'rtne' => \&dusers,   'seq' =>  50, 'auth' => 'A' ,'help' => '%USERS [login]        : dump %USERS login or all'},
		'authres'    => {'rtne' => \&authres,  'seq' =>  55, 'auth' => 'A' ,'help' => 'authres               : list all \'named\' auth resources'},
		'user'       => {'rtne' => \&dbuser,   'seq' =>  60, 'auth' => 'A' ,'help' => 'user login            : query DB USERS for login'},
		'newuser'    => {'rtne' => \&siuser,   'seq' =>  70, 'auth' => 'A' ,'help' => 'newuser               : add a user'},
		'newgroup'   => {'rtne' => \&sigroup,  'seq' =>  75, 'auth' => 'A' ,'help' => 'newgroup              : add a users group'},
		'deluser'    => {'rtne' => \&sruser,   'seq' =>  80, 'auth' => 'A' ,'help' => 'deluser               : delete a user'},
		'delgroup'   => {'rtne' => \&srgroup,  'seq' =>  85, 'auth' => 'A' ,'help' => 'delgroup              : delete a users group'},
		'grant'      => {'rtne' => \&siauth,   'seq' =>  90, 'auth' => 'A' ,'help' => 'grant auth            : grant access in auth table'},
		'auth'       => {'rtne' => \&duauth,   'seq' => 100, 'auth' => 'A' ,'help' => 'auth login            : dump login authorizations'},
		'%NODES'     => {'rtne' => \&dnodesc,  'seq' => 110, 'auth' => 'R' ,'help' => '%NODES [key]          : dump %NODES key or all'},
		'proc'       => {'rtne' => \&dproc,    'seq' => 120, 'auth' => 'R' ,'help' => 'proc [proc]           : dump PROC proc or all'},
		'form'       => {'rtne' => \&dform,    'seq' => 125, 'auth' => 'R' ,'help' => 'form [form]           : dump FORM form or all'},
		'view'       => {'rtne' => \&dview,    'seq' => 130, 'auth' => 'R' ,'help' => 'view [view]           : dump VIEW view or all'},
		'node'       => {'rtne' => \&dstatn,   'seq' => 140, 'auth' => 'R' ,'help' => 'node [node]           : dump NODE node or list node names'},
		'newnode'    => {'rtne' => \&dnnode,   'seq' => 145, 'auth' => 'R' ,'help' => 'newnode node as other : define a new node as othernode'},
		'delnode'    => {'rtne' => \&drmnode,  'seq' => 146, 'auth' => 'R' ,'help' => 'delnode node          : delete a node'},
		'nodegrids'  => {'rtne' => \&dstatg,   'seq' => 150, 'auth' => 'R' ,'help' => 'nodegrids [node]      : list grids referencing node'},
		'nodedev'    => {'rtne' => \&ddev,     'seq' => 155, 'auth' => 'A' ,'help' => 'nodedev [node]        : list features+devices for node (or all dev)' },
		'statnodes'  => {'rtne' => \&statnodes,'seq' => 157, 'auth' => 'R' ,'help' => 'statnodes             : statistics on node+grids' },
		'readcfg'    => {'rtne' => \&rc,       'seq' => 190, 'auth' => 'R' ,'help' => 'readcfg file          : readCfg file' },
		'dbjobs'     => {'rtne' => \&dbjobs,   'seq' => 195, 'auth' => 'A' ,'help' => 'dbjobs                : list all jobs definitions' },
		'newjob'     => {'rtne' => \&sijob,    'seq' => 196, 'auth' => 'A' ,'help' => 'newjob                : add a job definition' },
		'dbruns'     => {'rtne' => \&dbruns,   'seq' => 200, 'auth' => 'A' ,'help' => 'dbruns                : list all jobs last run info' },
		'sys'        => {'rtne' => \&sys,      'seq' => 300, 'auth' => 'R' ,'help' => 'sys                   : print system information' },
#		'!'          => {'rtne' => \&xsys,     'seq' => 310, 'auth' => 'A' ,'help' => '! cmd                 : exec shell cmd (WebObs vars single-quoted for interpolation)' },
#		'='          => {'rtne' => \&xsys,     'seq' => 310, 'auth' => 'A' ,'help' => '= expr                : exec perl expr (interactive mode only)' },
		'dd'         => {'rtne' => \&dd,       'seq' => 320, 'auth' => 'A' ,'help' => 'dd                    : keys of main hashes and their occurence' },
		'ddxref'     => {'rtne' => \&ddx,      'seq' => 321, 'auth' => 'A' ,'help' => 'ddxref                : keys of main hashes + their occurence + xref' },
		'help'       => {'rtne' => \&dhelp,    'seq' => 400, 'auth' => 'R' ,'help' => 'help                  : this help text !' },
		'quit'       => {'rtne' => \&bye,      'seq' => 410, 'auth' => 'R' ,'help' => 'quit                  : make a guess !' },
	);

# Get system/environment information -------------------------------------------
# ------------------------------------------------------------------------------
our @WOCusr  = getpwuid ($<); #($name, $passwd, $uid, $gid, $quota, $comment, $gcos, $dir, $shell)
our @localeIns  = qx(locale -a); chomp(@localeIns);
our $localeAll  = setlocale(LC_ALL);
our $localeNum  = setlocale(LC_NUMERIC);
our @i18nSup = qx(ls $WEBOBS{ROOT_I18N}/locales); chomp(@i18nSup);
our $WOCSYS  = qx(uname -osrv);
	$WOCSYS .= "\"WebObs-$WEBOBS{WEBOBS_ID}\" $WEBOBS{VERSION} [$WOLNK]\n";
	$WOCSYS .= "woc pid $$ started $^T by $WOCusr[0] ($</$>) in ".qx(pwd)."\n";
    $WOCSYS .= "Perl \$^V = $^V \n";
	$WOCSYS .= "\$ENV{PATH} = $ENV{PATH}\n";
	$WOCSYS .= "\@INC : ".join(":",@INC)."\n";
	$WOCSYS .= "\$POSIX::VERSION = ".qq($POSIX::VERSION)."\n";
	$WOCSYS .= "POSIX::tzname = ".join(' ',POSIX::tzname())."\n";
	$WOCSYS .= "\$ENV{TZ} " . (defined($ENV{TZ}) ? "= $ENV{TZ}\n" : "undefined\n");
	$WOCSYS .= "/etc/localtime -> ".qx(tail -1 /etc/localtime); my $tnow = time;
	$WOCSYS .= "local now: ".strftime("%Y-%m-%d %H:%M:%S %Z (%z) %s ",localtime($tnow))."($tnow)\n";
	$WOCSYS .= "UTC   now: ".strftime("%Y-%m-%d %H:%M:%S %s ",gmtime($tnow))."\n";
	$WOCSYS .= "Environment    LC_ALL:$ENV{LC_ALL}, LANGUAGE:$ENV{LANGUAGE}, LC_NUMERIC:$ENV{LC_NUMERIC}, LANG:$ENV{LANG}\n";
	$WOCSYS .= "Perl setlocale LC_ALL:$localeAll"; $WOCSYS .= ", LC_NUMERIC:$localeNum" unless ( $localeAll =~ /\QLC_NUMERIC/); $WOCSYS .= "\n";
	$WOCSYS .= "i18n Available/Installed: "; map {$WOCSYS .= (grep /\Q$_/ , @localeIns) ? "$_ = S/I; " : "$_ = S/?; "} @i18nSup ; $WOCSYS .= "\n";
	$WOCSYS .= sprintf("UMASK %03o\n",umask);
	if (defined $ENV{GATEWAY_INTERFACE}) {
		$WOCSYS .= "$ENV{REQUEST_URI}\n";
		$WOCSYS .= "HTTP Server = $ENV{SERVER_NAME} [$ENV{SERVER_ADDR}:$ENV{SERVER_PORT}]\n";
		$WOCSYS .= "     CGI = $ENV{GATEWAY_INTERFACE}\n";
		$WOCSYS .= "     $ENV{SERVER_PROTOCOL} - $ENV{SERVER_SOFTWARE}\n";
		$WOCSYS .= "HTTP User = $ENV{REMOTE_USER} - $ENV{REMOTE_HOST} [$ENV{REMOTE_ADDR}:$ENV{REMOTE_PORT}]\n";
		$WOCSYS .= "     AuthType  = $ENV{AUTH_TYPE}\n";
		$WOCSYS .= "     UserAgent = $ENV{HTTP_USER_AGENT}\n";
		$WOCSYS .= "WEBOBS User = $CLIENT";
	}

# WOC batch mode if arguments on command line ----------------------------------
# interpret/execute these args as a single woc command and quit
# ------------------------------------------------------------------------------
#our @opt = @ARGV;
chomp(@ARGV); 
our @opt = $#ARGV ? @ARGV : split(' ',$ARGV[0]);
if (@opt) {
	$mode = 'batch';
	($op,@obj) = @opt;  
	exit if ($op eq '=');  # ignore this one !!
	if ( defined($vectors{$op}) ) {
		eval { &{$vectors{$op}{rtne}} (@obj) };
		warn() if $@;
	}
	exit;
}

# WOC interactive mode system setups -------------------------------------------
# - init console read loop
# - init auto completion 
# ------------------------------------------------------------------------------
our $WOCmyname = $0;
our @WOCmyargs = @ARGV;
our $WOCtmpprefx = glob("~/tmpwoc");
our $WOCwd = qx(pwd); chomp($WOCwd);
our $term = new Term::ReadLine 'WebObs Console';
#our $prompt = "\x1b[38;5;24m<WOC> ";
our $prompt = "<WOC> ";
our $OUT = $term->OUT || \*STDOUT;

my $attribs = $term->Attribs;
$attribs->{completion_function} = sub {
	my ($text, $line, $start) = @_;
	my @from = keys(%vectors);
	if ($line =~ /^w /) {@from = keys(%WebObs::Config::WEBOBS)}
	if ($line =~ /^d /) {@from = keys(%WebObs::Grids::DISCP)}
	if ($line =~ /^u /) {@from = keys(%WebObs::Users::USERS)}
	return grep(/^$text/, @from);	
};

# Signal Handlers -------------------------------------------------------------- 
# ------------------------------------------------------------------------------
sub hINT {
    print("Use q at <WOC> prompt to quit!\n");
	return;
}
sub hWARN {
	my($signal) = @_;
	$signal =~ s/\.\.\.caught at.*//g; 
    #print("\x1b[38;5;88mWOC caught $signal");
    print("*** WOC caught $signal");
}

# yes/no from user -------------------------------------------------------------
# ------------------------------------------------------------------------------
sub yesno {
	my $a = "";
	while ($a !~ m/[YN]$/) { 
		$a = $term->readline("Y/N ? ");
	}
	return $a;
}

# ------------------------------------------------------------------------------
# WOC interactive, Read-Evaluate-Process Woc Command ---------------------------
# ------------------------------------------------------------------------------
print "\033[2J\033[0;0H"; #clear the screen & jump to 0,0
print "WOC version 1.6, D.Lafon Apr2013\n";
print "At WOC prompt: command , 'help', or 'quit' \n\n";
#print "\n$WOCSYS\n";

while ( defined ($cmd = $term->readline($prompt)) ) {
	chomp($cmd);
	$cmd =~ s/(\s)+/ /g; 
	$cmd =~ s/^[\s]+//g;
	($op,@obj) = split(' ',$cmd);
	if (defined($vectors{$op}) ) {
		if ($op eq '=') {         # ignore vector for this one !
			my $obj = join(' ',@obj); 
			print "== $obj\n"; 
			$obj .= ";print '\n'"; # to flush expr output if any
			eval $obj;
		}	
		else {
			eval { &{$vectors{$op}{rtne}} (@obj) };
			warn() if $@;
			$term->addhistory($cmd) if /\S/;
		}
	}
}
# End Read-Evaluate-Process Woc Command ----------------------------------------


# ------------------------------------------------------------------------------
# help command : print from vectors 
# ------------------------------------------------------------------------------
sub dhelp {
	for ( sort {$vectors{$a}->{seq} <=> $vectors{$b}->{seq}} keys %vectors ) {
		my $l = $vectors{$_};
		printf( "%s\n", $l->{help} );
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# system information command: dump system string
# ------------------------------------------------------------------------------
sub sys {
	print "\n$WOCSYS\n";
}

# ------------------------------------------------------------------------------
# WOC Out Of Date (ie. conf file changes occurred): I can restart myself
# ------------------------------------------------------------------------------
sub ood {
	if ( $mode eq 'interactive' ) {
		print "WOC now out of date, Y to restart\n";
		if (yesno() == 'Y') {
			exec( $^X, $WOCmyname, @WOCmyargs);
		}
		print "\n";
	}
}

# ------------------------------------------------------------------------------
# get out of here  
# ------------------------------------------------------------------------------
sub bye {
	print "Bye.\n\n" ;
	exit(0);
}

# ------------------------------------------------------------------------------
# execute a system command, with hash variable double-interpolation  
# ------------------------------------------------------------------------------
sub xsys {
	my @obj = @_;
	my $obj = join(' ',@obj);
	$obj = eval qq!"$obj"!;
	print "!= $obj\n";
	system($obj);
	printf ("!rc= 0x%.2X\n",$?); 
}

# ------------------------------------------------------------------------------
# dump WEBOBS global ----------------------------------------------------------
# ------------------------------------------------------------------------------
sub dwebobs {
	if (defined($WebObs::Config::WEBOBS_LFN)) {print "[[ \%WEBOBS $WebObs::Config::WEBOBS_LFN ]]\n"}
	 if (defined($_[0])) {@L = grep(/$_[0]/, (sort (keys(%WebObs::Config::WEBOBS)))) }
	else                 {@L = (sort (keys(%WebObs::Config::WEBOBS))) } 
	for (@L) { print "\$WEBOBS\{$_\} => $WebObs::Config::WEBOBS{$_}\n" }
	print "\n"; 
}

# ------------------------------------------------------------------------------
# 'reverse' dump WEBOBS global : which key holds a value ----------------------
# ------------------------------------------------------------------------------
sub rwebobs { 
	if (defined($WebObs::Config::WEBOBS_LFN)) {print "[[ \%WEBOBS $WebObs::Config::WEBOBS_LFN ]]\n"}
	my $re = $_[0];
	for (keys(%WebObs::Config::WEBOBS)) { 
		if ($WebObs::Config::WEBOBS{$_} =~ /$re/) {
			print "\$WEBOBS\{$_\} => $WebObs::Config::WEBOBS{$_}\n" ;
		}
	}
	print "\n"; 
}

# ------------------------------------------------------------------------------
# raw dump of the hash generated by readCfg on a file -------------------------
# ------------------------------------------------------------------------------
sub rc {
	no strict;
	$_[0] =~ s/[\$](.*)[\{](.*?)[\}]/$$1{$2}/g;
	use strict;
	# try to figure out whether hash or array can be read
	if (-e $_[0]) {
		print "$_[0]\n";
		my @tag=qx(grep -P '^=key' $_[0]);
		if ($tag[0]) {
			my %F = readCfg($_[0]);
			print Dumper(\%F) if (%F);
		} else {
			my @F = readCfg($_[0]);
			print Dumper(\@F) if (@F);
		}
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# dump %USERS global ----------------------------------------------------------
# ------------------------------------------------------------------------------
sub dusers { 
	if (defined($WebObs::Users::USERS_LFN)) {print "[[ \%USERS $WebObs::Users::USERS_LFN ]]\n"}
	if (defined($_[0])) {@L = grep(/$_[0]/, keys(%WebObs::Users::USERS))}
	else                {@L = keys(%WebObs::Users::USERS)}
	for $l (@L) { 
		print "\$USERS\{$l\} => $WebObs::Users::USERS{$l}\n" ;
		for ( keys(%{$WebObs::Users::USERS{$l}}) ) {
			print "   $_ ==> $WebObs::Users::USERS{$l}{$_}\n";
		}
	}
	print "\n" 
}

# ------------------------------------------------------------------------------
# list a user's authorizations ------------------------------------------------
# ------------------------------------------------------------------------------
sub duauth {
	if (defined($_[0])) {
		my %A = WebObs::Users::userListAuth($_[0]);
		for (keys(%A)) { print "$_ =>\n"; for ($A{$_}) { for (@$_) {print "   @$_\n" } } };
		#print Dumper \%A;
	}
}

# ------------------------------------------------------------------------------
# dump %OWNRS global ----------------------------------------------------------
# ------------------------------------------------------------------------------
sub downers { 
	if (defined($WebObs::Grids::OWNRS_LFN)) {print "[[ \%OWNRS $WebObs::Grids::OWNRS_LFN ]]\n"}
	for (keys(%WebObs::Grids::OWNRS)) { print "\$OWNRS\{$_\} => $WebObs::Grids::OWNRS{$_}\n" }
	print "\n"; 
}

# ------------------------------------------------------------------------------
# dump %DISCP global ----------------------------------------------------------
# ------------------------------------------------------------------------------
sub ddiscp { 
	if (defined($WebObs::Grids::DISCP_LFN)) {print "[[ \%DISCP $WebObs::Grids::DISCP_LFN ]]\n"}
	if (defined($_[0])) {@L = grep(/$_[0]/, keys(%WebObs::Grids::DISCP))}
	else                {@L = keys(%WebObs::Grids::DISCP)}
	for $l (@L) { 
		print "\$DISCP\{$l\} => $WebObs::Grids::DISCP{$l}\n" ;
		for ( keys(%{$WebObs::Grids::DISCP{$l}})) {
			print "   $_ ==> $WebObs::Grids::DISCP{$l}{$_}\n";
		}
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# dump a PROC grid ------------------------------------------------------------
# ------------------------------------------------------------------------------
sub dproc {
	my $net;
	if (!defined($_[0])) { 
		my @net =  WebObs::Grids::listProcNames();
		for (@net) { print "$_\n" }
	}
	else {
		my %net = WebObs::Grids::readProc($_[0]); 
		for $l (keys(%net)) { 
			print "$l\n" ;
			for ( keys(%{$net{$l}}) ) {
				if (($_ eq 'NODESLIST')) { 
					my $addr = $net{$l}{$_}; my @w = @$addr;
					print "   $_ ==>\n";
					for (my $i=0;$i<$#w;$i+=3) {
						print "           $w[$i] $w[$i+1] $w[$i+2]\n";
					}
				} else {	
					print "   $_ ==> $net{$l}{$_}\n";
				}
			}
		}	
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# dump a FORM -----------------------------------------------------------------
# ------------------------------------------------------------------------------
sub dform {
	if (!defined($_[0])) { 
		my @lf =  qx(ls $WEBOBS{PATH_FORMS});
		chomp(@lf);
		for (@lf) { print "$_\n" }
	}
	else {
		my $F = new WebObs::Form($_[0]); 
		print $F->dump;
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# dump a VIEW grid ------------------------------------------------------------
# ------------------------------------------------------------------------------
sub dview {
	my $net;
	if (!defined($_[0])) { 
		my @net =  WebObs::Grids::listViewNames();
		for (@net) { print "$_\n" }
	}
	else {
		my %net = WebObs::Grids::readView($_[0]); 
		for $l (keys(%net)) { 
			print "$l\n" ;
			for ( keys(%{$net{$l}}) ) {
				if ($_ eq 'NODESLIST') { 
					my $addr = $net{$l}{$_}; my @w = @$addr;
					print "   $_ ==>\n";
					for (my $i=0;$i<$#w;$i+=3) {
						print "           $w[$i] $w[$i+1] $w[$i+2]\n";
					}
				} else {	
					print "   $_ ==> $net{$l}{$_}\n";
				}
			}
		}	
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# dump NODES configuration ------------------------------------------------
# ------------------------------------------------------------------------------
sub dnodesc {
	if (defined($WebObs::Grids::NODES_LFN)) {print "[[ \%NODES $WebObs::Grids::NODES_LFN ]]\n"}
	if (defined($_[0])) {@L = grep(/$_[0]/, keys(%WebObs::Grids::NODES))}
	else                {@L = keys(%WebObs::Grids::NODES)}
	for (@L) { print "\$NODES\{$_\} => $WebObs::Grids::NODES{$_}\n" }
	print "\n"; 
}

# ------------------------------------------------------------------------------
# dump a NODE -------------------------------------------------------------
# ------------------------------------------------------------------------------
sub dstatn {
	my $nodes;
	if (!defined($_[0])) { 
		my @nodes =  WebObs::Grids::listNodeNames();
		for (my $i=0; $i<scalar(@nodes);$i+=8) { print join('  ',@nodes[$i..$i+7]),"\n"}
	}
	else {
		my %node = WebObs::Grids::readNode($_[0]); 
		for $l (keys(%node)) { 
			print "$l\n" ;
			for ( keys(%{$node{$l}}) ) {
				print "   $_ ==> $node{$l}{$_}\n";
			}
		}	
	}
	print "\n";
}

# ------------------------------------------------------------------------------
# list grids for node(s) ---------------------------------------------------
# ------------------------------------------------------------------------------
sub dstatg {
	my %s = WebObs::Grids::listNodeGrids(node=>$_[0]);
	for  (keys(%s)) {
		print "$_ :\n";
		if (scalar(@{$s{$_}}) == 0) { print "  not in any grid\n"}
		else {
			for (@{$s{$_}}) { print "  $_\n" } 
		}
		print "\n" 
	}
}

# ------------------------------------------------------------------------------
# list all authorization 'named' resources ----------------------------------
# ------------------------------------------------------------------------------
sub authres {
	my @q = qx(sqlite3 -separator '' $WEBOBS{SQL_DB_USERS} 'select "$WEBOBS{SQL_TABLE_AUTHPROCS} / ",RESOURCE  from $WEBOBS{SQL_TABLE_AUTHPROCS} where RESOURCE != "*"');
	if ($?) { warn(($?>>8)." - @q"); return; }
	print @q,"\n" if (scalar(@q) >0); 
	my @q = qx(sqlite3 -separator '' $WEBOBS{SQL_DB_USERS} 'select "$WEBOBS{SQL_TABLE_AUTHVIEWS} / ",RESOURCE  from $WEBOBS{SQL_TABLE_AUTHVIEWS} where RESOURCE != "*"');
	if ($?) { warn(($?>>8)." - @q"); return; }
	print @q,"\n" if (scalar(@q) >0);
	my @q = qx(sqlite3 -separator '' $WEBOBS{SQL_DB_USERS} 'select "$WEBOBS{SQL_TABLE_AUTHFORMS} / ",RESOURCE  from $WEBOBS{SQL_TABLE_AUTHFORMS} where RESOURCE != "*"');
	if ($?) { warn(($?>>8)." - @q"); return; }
	print @q,"\n" if (scalar(@q) >0);
	my @q = qx(sqlite3 -separator '' $WEBOBS{SQL_DB_USERS} 'select "$WEBOBS{SQL_TABLE_AUTHWIKIS} / ",RESOURCE  from $WEBOBS{SQL_TABLE_AUTHWIKIS} where RESOURCE != "*"');
	if ($?) { warn(($?>>8)." - @q"); return; }
	print @q,"\n" if (scalar(@q) >0);
	my @q = qx(sqlite3 -separator '' $WEBOBS{SQL_DB_USERS} 'select "$WEBOBS{SQL_TABLE_AUTHMISC} / ",RESOURCE  from $WEBOBS{SQL_TABLE_AUTHMISC} where RESOURCE != "*"');
	if ($?) { warn(($?>>8)." - @q"); return; }
	print @q,"\n" if (scalar(@q) >0);

	print "\n";
}

# ------------------------------------------------------------------------------
# user info from sql ----------------------------------------------------------
# ------------------------------------------------------------------------------
sub dbuser {
	my $u = $_[0] ? $_[0] : '';
	if ($u ne '' && defined($USERS{$u}{LOGIN})) {
		my $v = $USERS{$u}{UID};
		my @q = qx(sqlite3 -list -separator ',' $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_USERS} where login = '$u' order by login");
		if ($?) { warn(($?>>8)." - @q"); return; }
		print @q;
		print "\n$WEBOBS{SQL_TABLE_AUTHPROCS}: ";
		my @q = qx(sqlite3 -column $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_AUTHPROCS} where uid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
		print "\n$WEBOBS{SQL_TABLE_AUTHVIEWS}: ";
		my @q = qx(sqlite3 -column $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_AUTHVIEWS} where uid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
		print "\n$WEBOBS{SQL_TABLE_AUTHFORMS}: ";
		my @q = qx(sqlite3 -column $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_AUTHFORMS} where uid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
		print "\n$WEBOBS{SQL_TABLE_AUTHWIKIS}: ";
		my @q = qx(sqlite3 -column $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_AUTHWIKIS} where uid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
		print "\n$WEBOBS{SQL_TABLE_AUTHMISC}: ";
		my @q = qx(sqlite3 -column $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_AUTHMISC} where uid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
		print "\n$WEBOBS{SQL_TABLE_GROUPS} :";
		my @q = qx(sqlite3 -column $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_GROUPS} where uid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
		print "\n$WEBOBS{SQL_TABLE_NOTIFICATIONS} :";
		my @q = qx(sqlite3 -list $WEBOBS{SQL_DB_USERS} "select * from $WEBOBS{SQL_TABLE_NOTIFICATIONS} where mailid = '$v' order by 1");
		if ($?) { warn(($?>>8)." - @q"); return; }
		if (scalar(@q) >0 ) { print "\n@q" } else { print "None\n"}; 
	} else {
		my @q = qx(sqlite3 -column -header $WEBOBS{SQL_DB_USERS} "select LOGIN, UID from $WEBOBS{SQL_TABLE_USERS}");
		if ($?) { warn(($?>>8)." - @q"); return; }
		print @q;
	}
}

# ------------------------------------------------------------------------------
# insert new user -------------------------------------------------------------
# ------------------------------------------------------------------------------
sub siuser {
	return if ( $mode eq 'batch' && $_[0] eq "" ) ;
	dbinsert($WEBOBS{SQL_DB_USERS}, $WEBOBS{SQL_TABLE_USERS},$_[0]);
}

# ------------------------------------------------------------------------------
# insert new group -------------------------------------------------------------
# ------------------------------------------------------------------------------
sub sigroup {
	return if ( $mode eq 'batch' && $_[0] eq "" ) ;
	dbinsert($WEBOBS{SQL_DB_USERS}, $WEBOBS{SQL_TABLE_GROUPS},$_[0]);
}

# ------------------------------------------------------------------------------
# delete a user ---------------------------------------------------------------
# ------------------------------------------------------------------------------
sub sruser {
	if (defined($_[0]) && ($_[0] ne "")) {
		my $q = "delete from $WEBOBS{SQL_TABLE_USERS} where login = $_[0]";
		print "= $q\n";
		if (yesno() eq 'Y') {
			my @q = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$q" 2>&1);
			if ($?) { warn(($?>>8)." - @q"); return } else {print Dumper @q }
			ood();
		}

	}
}

# ------------------------------------------------------------------------------
# delete a group ---------------------------------------------------------------
# ------------------------------------------------------------------------------
sub srgroup {
	if (defined($_[0]) && ($_[0] ne "")) {
		my $q = "delete from $WEBOBS{SQL_TABLE_GROUPS} where gid = $_[0]";
		print "= $q\n";
		if (yesno() eq 'Y') {
			my @q = qx(sqlite3 $WEBOBS{SQL_DB_GROUPS} "$q" 2>&1);
			if ($?) { warn(($?>>8)." - @q"); return } else {print Dumper @q }
			ood();
		}

	}
}

# ------------------------------------------------------------------------------
# insert new authorization ----------------------------------------------------
# ------------------------------------------------------------------------------
sub siauth {
	my ($table, $row) = @_;
	return if ( $table eq '' );
	return if ( $mode eq 'batch' && $row eq "" ) ;
	dbinsert($WEBOBS{SQL_DB_USERS}, $table, $row);
}

# ------------------------------------------------------------------------------
# jobs definitions from db   ---------------------------------------------------
# ------------------------------------------------------------------------------
sub dbjobs {
	if ( defined($SCHED{SQL_DB_JOBS}) ) { 
		my @q = qx(sqlite3 -line $SCHED{SQL_DB_JOBS} "select JID,VALIDITY,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXSYSLOAD,LOGPATH from JOBS ORDER by JID");
		if ($?) { warn(($?>>8)." - @q"); return; }
		print @q;
	}
}

# ------------------------------------------------------------------------------
# insert new job   -------------------------------------------------------------
# ------------------------------------------------------------------------------
sub sijob {
	return if ( $mode eq 'batch' && $_[0] eq "" ) ;
	dbinsert($SCHED{SQL_DB_JOBS}, "JOBS", $_[0]);
}

# ------------------------------------------------------------------------------
# jobs last run info from db   -------------------------------------------------
# ------------------------------------------------------------------------------
sub dbruns {
	if ( defined($SCHED{SQL_DB_JOBS}) ) { 
		my @q = qx(sqlite3 -column -column -header $SCHED{SQL_DB_JOBS} "select JID,datetime(STARTTS,'unixepoch') as STARTED,datetime(ENDTS,'unixepoch') as ENDED,round(ENDTS-STARTTS,3) as ELAPSED, CMD,STDPATH,RC,RCMSG from RUNS order by STARTTS,JID");
		if ($?) { warn(($?>>8)." - @q"); return; }
		print @q;
	}
}

# ------------------------------------------------------------------------------
# inspect DEVICES the way it is handled by showNODE-----------------------------
# ------------------------------------------------------------------------------
sub ddev {
	# legacy code to create %liste_liens_fiches : NODES links to other nodes 
	my @conf_liens_stations = readCfgFile("$NODES{FILE_NODES2NODES}");
	my %liste_liens_fiches;   
	my $station_parente_old = "";
	my $caracteristique_old = "";
	my $i = 0;
	for (@conf_liens_stations) {
		my ($station_parente,$caracteristique,$station_fille)=split(/\|/,$_);
		if ( $station_parente."|".$caracteristique ne $station_parente_old."|".$caracteristique_old ) {
			$i = 0;
		}
		my $nom_lien = $station_parente."|".$caracteristique;
		$liste_liens_fiches{$nom_lien} .= ($i++==0?"":"|").$station_fille;
		$station_parente_old = $station_parente;
		$caracteristique_old = $caracteristique;
	}

	if ($_[0]) {

		my $NODEName = $_[0];
		my $hits = 0;

		print "$NODEName occurences in $NODES{FILE_NODES2NODES} :\n";
		for ( sort keys(%liste_liens_fiches) ) {
			my $temp = $_."==>".$liste_liens_fiches{$_};
			if ( $temp =~ m/$NODEName/g ) { print "  $temp\n"; $hits++ }
		}
		if ($hits == 0) { print"  NONE!\n"; }
        else {
			$hits = 0;
			# legacy showNODE code for 'parents'  
			print "$NODEName is a feature of other node in $NODES{FILE_NODES2NODES} :\n";
			my $liens_fiches_parentes = "";
			for my $nom_lien (keys %liste_liens_fiches) {
				my @liste_fiches_filles = split(/\|/,$liste_liens_fiches{$nom_lien});
				for (@liste_fiches_filles) {
					if ( $_ eq $NODEName ) {
						my @data = split(/\|/,$nom_lien);
						print "  $data[1] of $data[0]\n";
						$hits++;
					}
				}
			}
			if ($hits == 0) { print"  NONE!\n"; }

			my %NODE = readNode($NODEName);
			my $editOK = 1;
			# legacy showNODE code "other nodes from NODE's features"
			my @listeCarFiles=split(/\|/,$NODE{$_[0]}{FILES_FEATURES});
			$hits = 0;
			print "$NODEName has feature(s) in $NODEName.cnf :\n";
			for (@listeCarFiles) { print "  '$_'" ; $hits++ }
			if ($hits == 0) { print"  NONE!"; }
			print ("\n");

			if ($hits > 0) {
				my @listeFinaleCarFiles;
				my $flag=0;
				my %lienNode;
				# for each defined features in NODEName.cnf ONLY:
				for (@listeCarFiles) {
					my $carFileName=$_;
					my $carFile="$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_FEATURES}/$carFileName.txt";
					my $nom_lien = $NODEName."|".$carFileName;
					$lienNode{$carFileName} = "";
					my $lien_car = 0;
					# if this feature appears in $NODES{FILE_NODES2NODES} ONLY:
					# mark this feature as defined in $NODES{FILE_NODES2NODES} (lien_car = 1)
					# enter all 'child' nodes definitions for this feature in %lienNode
					if ( exists($liste_liens_fiches{$nom_lien}) ) {
						my @liste_liens=split(/\|/,$liste_liens_fiches{$nom_lien});
						for (@liste_liens) {
							if ( length($_) > 0 ) {
								$lienNode{$carFileName} .= $_;
								if ( getNodeString(node=>$_) eq "") { $lienNode{$carFileName} .=  " (no NodeString) "}
								else { $lienNode{$carFileName} .= " " }
								# $lienNode{$carFileName} .= ($lienNode{$carFileName} eq "" ? "" : "\n").getNodeString(node=>$_);
							}
						}
						#if ( $lienNode{$carFileName} ne "" ) {
						#	$lienNode{$carFileName} .= "\n\n";
						#}	
						$lien_car = 1;
					}
					printf ("  %s  %s $NODES{FILE_NODES2NODES} , %s\n",$carFileName,($lien_car==1)?"in ":"not in" ,(-e $carFile)?"has $carFile":"has no txt file"); 
					if ((-e $carFile && (-s $carFile || $editOK == 1)) || $lien_car == 1) { 
						push(@listeFinaleCarFiles,$carFileName);
					}
      				print "  + $lienNode{$carFileName}\n" if ($lienNode{$carFileName} ne "");
				}
				printf ("%s feature(s) could show up in showNODE\n",$#listeFinaleCarFiles+1);
				for (@listeFinaleCarFiles) { print "  $_" }
			}
		}
	}
	print("\n"); 
}

# ------------------------------------------------------------------------------
# data dictionary for main hashes, + occurences -----------------------------
# ------------------------------------------------------------------------------
sub dd {
	my $oldDumperSortkeys = $Data::Dumper::Sortkeys;
	my $oldDumperVarname  = $Data::Dumper::Varname;
	$Data::Dumper::Sortkeys = 1;

	my ($nV, %keysView) = ddcore(\&WebObs::Grids::listViewNames, \&WebObs::Grids::readView, "VIEWS");
	my ($nP, %keysProc) = ddcore(\&WebObs::Grids::listProcNames, \&WebObs::Grids::readProc,"PROCS");
	my ($nN, %keysNode) = ddcore(\&WebObs::Grids::listNodeNames, \&WebObs::Grids::readNode,"NODES");

	$Data::Dumper::Sortkeys = $oldDumperSortkeys;
	$Data::Dumper::Varname  = $oldDumperVarname;
	print("\n"); 
}

# ------------------------------------------------------------------------------
# data dictionary XREF for main hashes                  ------------------------
# ------------------------------------------------------------------------------
sub ddx {
	
	my $oldDumperSortkeys = $Data::Dumper::Sortkeys;
	my $oldDumperVarname  = $Data::Dumper::Varname;
	$Data::Dumper::Sortkeys = 1;

	my ($nV, %keysView) = ddxcore(\&WebObs::Grids::listViewNames, \&WebObs::Grids::readView,"VIEWS");
	ddxrevcore(\%keysView, "views");

	my ($nV, %keysProc) = ddxcore(\&WebObs::Grids::listProcNames, \&WebObs::Grids::readProc,"PROCS");
	ddxrevcore(\%keysProc, "procs");

	my ($nV, %keysNode) = ddxcore(\&WebObs::Grids::listNodeNames, \&WebObs::Grids::readNode,"NODES");
	ddxrevcore(\%keysNode, "nodes");

	my %keysWO; 
	for my $i (keys(%WEBOBS)) { 
			if (!exists($keysWO{$i})) { $keysWO{$i}{cgibin} = join(" ",REKCGI($i));
			                            $keysWO{$i}{matlab} = join(" ",REKMAT($i)); 
										} 
		} 
	print "\n";
	$Data::Dumper::Varname = 'WEBOBS';
	print Dumper \%keysWO;
	ddxrevcore(\%keysWO, "webobs");

#	print"\n**************************************************************\n";
#	print"* xrefs might NOT be comprehensive lists. They are built     *\n";
#	print"* using naming/coding conventions & also scan comments.      *\n";
#	print"* cgi: 'key' looked for in {key} or {'key'} case insensitive.*\n";
#	print"* mat: 'key' looked for in xx.key, xx 1 or 2 uppercase alpha.*\n";
#	print"**************************************************************\n";
}

# woc internal helpers functions for dd* commands
# -----------------------------------------------
# get number of hash keys and occurences of their keys
sub ddcore {
	my %GKs;
	my ($a1, $a2, $txt) = @_;
	my @L = &$a1();
	for my $i (@L) {
		my %g = &$a2($i);
		for (keys(%{$g{$i}})) { 
			if (exists($GKs{$_})) { $GKs{$_}++ } 
			else                  { $GKs{$_} = 1 }
		} 
	}
	print "\n";
	print scalar(@L)." $txt scanned:\n";
	$Data::Dumper::Varname = $txt;
	print Dumper \%GKs;
	return (scalar(@L), %GKs);
}
# get keys occurences in cgi-bins and matlab 
sub ddxcore {
	my %GKs;
	my ($a1, $a2, $txt) = @_;
	my @L = &$a1();
	for my $i (@L) { 
		my %g = &$a2($i); 
		for (keys(%{$g{$i}})) { 
			if (!exists($GKs{$_})) { $GKs{$_}{cgibin} = join(" ",REKCGI($_)); 
			                         $GKs{$_}{matlab} = join(" ",REKMAT($_));
								   } 
		} 
	}
	print "\n";
	print scalar(@L)." $txt scanned:\n";
	$Data::Dumper::Varname = $txt;
	print Dumper \%GKs;
	return(scalar(@L), %GKs);
}
# get keys reverse xref
sub ddxrevcore{
	my $addr = $_[0];
	my %cgi; my %mat;
	for my $k (keys(%$addr)) { 
		for (split(/ /,$$addr{$k}{cgibin})) { 
			if ($cgi{$_}) {$cgi{$_} .= " ".$k} 
			else {$cgi{$_} = $k } 
		}  
		for (split(/ /,$$addr{$k}{matlab})) { 
			if ($mat{$_}) {$mat{$_} .= " ".$k} 
			else {$mat{$_} = $k } 
		}  
	}
	print "\n";
	print scalar(keys(%cgi))." cgis referencing $_[1]:\n";
	$Data::Dumper::Sortkeys = 1;
	$Data::Dumper::Varname = 'CGIs';
	print Dumper \%cgi;
	print "\n";
	print scalar(keys(%mat))." matlabs referencing $_[1]:\n";
	$Data::Dumper::Sortkeys = 1;
	$Data::Dumper::Varname = 'MATLABs';
	print Dumper \%mat;
}
# internal helper to find 'Key' used in CGIs (*.p{l,m})
sub REKCGI {
	my $r  = '"\{[\'\"]*';
	   $r .= $_[0];
	   $r .= '[\'\"]*\}"' ;
    my @qr = qx(grep -P -i -r -l $r $WEBOBS{ROOT_CODE}/cgi-bin/* | grep -v -P "affic|traite|formul|\.svn|\/leg.*\/");
	map {s/$WEBOBS{ROOT_CODE}\/cgi-bin\///} @qr;
	chomp(@qr);
	return @qr;
}

# internal helper to find 'Key' used in matlab (*.m)
sub REKMAT {
	my $r  = '"[A-Z\(\)]{1,2}\.';
	   $r .= $_[0];
	   $r .= '"' ;
    my @qr = qx(grep -P -r -l $r $WEBOBS{ROOT_CODE}/matlab/*);
	map {s/$WEBOBS{ROOT_CODE}\/matlab\///} @qr;
	chomp(@qr);
	return @qr;
}

# ------------------------------------------------------------------------------
# stats on nodes, starting from 'raw/system' nodes' directory list 
# (it would be tempting using only listNodeGrids() but this is NOT
# what we look for ... we're after some kind of integrity checking)
# ------------------------------------------------------------------------------
sub statnodes {
	my @nodes_dir;
	my @nodes_nogrid;
	my @nodes_noview;
	my @nodes_noproc;
	opendir(DIR, $NODES{PATH_NODES});
	while (readdir DIR) { push(@nodes_dir, $_) if (substr($_,0,1) ne '.') }
	closedir DIR;
	foreach (@nodes_dir) {
		my %HoA = WebObs::Grids::listNodeGrids(node=>$_);
		push(@nodes_nogrid,$_) and next if ( (!%HoA) || scalar(@{$HoA{$_}})==0);
		#push(@nodes_noproc,$_) if (! (/^PROC.*/ ~~ @{$HoA{$_}}) );
		push(@nodes_noproc,$_) if (! grep(/^PROC.*/, @{$HoA{$_}}) );
		push(@nodes_noview,$_) if (! grep(/^VIEW.*/, @{$HoA{$_}}) );
	}
	printf (" %5u node directories\n",$#nodes_dir+1);
	printf (" %5u node%s no grid\n",$#nodes_nogrid+1,($#nodes_nogrid+1>1)?"s have":" has");
	for (my $i=0; $i<scalar(@nodes_nogrid);$i+=8) { print "       ",join('  ',@nodes_nogrid[$i..$i+7]),"\n"}
	printf (" %5u node%s no proc\n",$#nodes_noproc+1,($#nodes_noproc+1>1)?"s have":" has");
	for (my $i=0; $i<scalar(@nodes_noproc);$i+=8) { print "       ",join('  ',@nodes_noproc[$i..$i+7]),"\n"}
	printf (" %5u node%s no view\n",$#nodes_noview+1,($#nodes_noview+1>1)?"s have":" has");
	for (my $i=0; $i<scalar(@nodes_noview);$i+=8) { print "       ",join('  ',@nodes_noview[$i..$i+7]),"\n"}
	print ("\n");
}

# ------------------------------------------------------------------------------
# dnnode define a new node           -------------------------------------------
# ------------------------------------------------------------------------------
sub dnnode {
	chomp @_;
	if (defined($_[0]) && ($_[0] ne "")) {
		my ($gt,$gn,$nn) = split(/\.|\//,$_[0]);
		if ($nn ne "") {
			if (-d "$NODES{PATH_NODES}/$nn") {
				print "$nn already exists\n";
			} else {
				if ( $_[1] =~ m/as|from/i && defined($_[2]) && $_[2] ne "") {
					if ( ! -d "$NODES{PATH_NODES}/$_[2]" ) {
						print "$_[2] does not exist\n";
					} else {
						qx(mkdir $NODES{PATH_NODES}/$nn );
						if ( $? == 0) {
							qx (ln -s $NODES{PATH_NODES}/$nn $WEBOBS{PATH_GRIDS2NODES}/$gt.$gn.$nn 2>/dev/null);
							if ( $? == 0 ) {
								qx(cp $NODES{PATH_NODES}/$_[2]/$_[2].cnf $NODES{PATH_NODES}/$nn/$nn.cnf 2>/dev/null);
								if ($? ne 0) {
									qx(rm -f $WEBOBS{PATH_GRIDS2NODES}/$gt.$gn.$nn); #rollback
									qx(rm -rf $NODES{PATH_NODES}/$nn); #rollback
								} else {
									qx(sed -i -e 's/\(^NAME.*|\|^ALIAS.*|\|^FDSN.*|\|TRANSMISSI.*|\).*/\1/' $NODES{PATH_NODES}/$nn/$nn.cnf);
								}
							} else {
								qx(rm -rf $NODES{PATH_NODES}/$nn); #rollback
							}
						} else {
							print "couldn't mkdir $NODES{PATH_NODES}/$nn\n";
						}
					}
				} else {
					print "need a 'from node' clause\n";
				}
			}
		}
		else { print "need gridtype.gridname.nodename1 from nodename2\n" }
	}
}

# ------------------------------------------------------------------------------
# drmnode delete a node              -------------------------------------------
# ------------------------------------------------------------------------------
sub drmnode {
	chomp @_;
	if (defined($_[0]) && ($_[0] ne "")) {
		if (-d "$NODES{PATH_NODES}/$_[0]") {
			qx(rm -f $WEBOBS{PATH_GRIDS2NODES}/*.*.$_[0]);
			qx(rm -rf $NODES{PATH_NODES}/$_[0]);
		}
	}
}

# ------------------------------------------------------------------------------
# dbinsert insert a row into a table -------------------------------------------
# ------------------------------------------------------------------------------
sub dbinsert {
	my $q;
	my ($db, $table, $row) = @_;
	my @q = qx(sqlite3 -noheader -list -separator ',' $db "PRAGMA table_info($table)");
	chomp(@q);
	my @qt = @q;
	foreach (@q)  { s/^.*?\,(.*?)\,.*$/$1/g }
	foreach (@qt) { s/^.*?\,.*?\,(.*?)\,.*$/$1/g }
	for my $i (0..$#q) {if ($qt[$i] eq 'text') {$q[$i] = "'".$q[$i]."'";}} ;
	if ($row eq '') {
		if ($mode eq 'interactive') {
			print "enter new row as: ".join(',',@q)."\n";
			$q = $term->readline("> ");
		}
	} else {
		$q = $row;
	}
	$q = "insert into $table values($q)";
	print "= $q\n";
	if ($mode eq 'interactive') {
		return if (yesno() ne 'Y') 
	}
	@q = qx(sqlite3 $db "$q" 2>&1);
	if ($?) { warn(($?>>8)." - @q"); return } else {print Dumper @q }
	ood();
}

__END__

=pod

=head1 COMMANDS 

The following list of B<woc> commands is also available by entering B<help> on woc's command line.
Square brackets denote optional parameters.

=over 

=item B<%WEBOBS [key]>

dump %WEBOBS key or all keys - [key] is a regular expression.

	<WOC> %WEBOBS POSTB
	[[ %WEBOBS from /etc/webobs.d/WEBOBS.conf (1371052936) + /etc/webobs.d/WEBOBS.rc (1371114257) ]]
	$WEBOBS{POSTBOARD_MAILER} => mutt
	$WEBOBS{POSTBOARD_MAILER_DEFSUBJECT} => test
	$WEBOBS{POSTBOARD_MAILER_OPTS} => -nx
	$WEBOBS{POSTBOARD_NPIPE} => /tmp/WEBOBSNP
	$WEBOBS{SQL_DB_POSTBOARD} => /data1/webobs/CONF/WEBOBSUSERS.db

=item B<-%WEBOBS value>  

which %WEBOBS key(s) holds value - value is a regular expression

	<WOC> -%WEBOBS WEBOBSUSERS
	[[ %WEBOBS from /etc/webobs.d/WEBOBS.conf (1371052936) + /etc/webobs.d/WEBOBS.rc (1371114257) ]]
	$WEBOBS{SQL_DB_POSTBOARD} => /data1/webobs/CONF/WEBOBSUSERS.db
	$WEBOBS{SQL_DB_USERS} => /data1/webobs/CONF/WEBOBSUSERS.db

=item B<%OWNERS> 

dump all %OWNRS hash

	<WOC> %OWNERS
	$OWNRS{B} => MVO
	$OWNRS{M} => OVSM
	$OWNRS{R} => OVPF
	$OWNRS{I} => IPGP

=item B<%USERS [login]>

dump %USERS entry for login or all

	<WOC> %USERS webobs
	[[ %USERS DB /data1/webobs/CONF/WEBOBSUSERS.db (1371053050) TABLE users ]]
	$USERS{webobs} => HASH(0x866eae0)
	UID ==> !
	FULLNAME ==> WebObs Owner
	EMAIL ==> webhost@somewhere.org
	LOGIN ==> webobs

=item B<authres>

list all authorizations resources as "resourceType / resourceName". This does NOT list 
all possible resources as used by WebObs programs, but ONLY those currently
defined (active) in the database. 

	<WOC> authres
	authprocs / HEBDO
	authprocs / HEBDOTout
	...

=item B<dbuser login>

query USERS database for login , ie. user definition + its current authorizations + its user-group(s)

	<WOC> dbuser webobs
	!,WebObs Owner,webobs,webobs@somewhere.org
	authprocs: 
	!           *           4         
	authviews: 
	!           *           4         
	.... 
	groups :
	+BASE       ! 

=item B<newuser>

add (define) a new user

	<WOC> newuser
	enter new row as: 'UID','FULLNAME','LOGIN','EMAIL'
	> 'JD','John Doe','jdoe','john.doe@somewhere.org'
	= insert into users values('JD','John Doe','jdoe','john.doe@somewhere.org')
	Y/N ? Y

=item B<deluser>

delete a user

	<WOC> deluser jdoe
	= delete from users where login = jdoe
	Y/N ? Y

=item B<newgroup>

add (define) a new user's group

	<WOC> newgroup
	enter new row as: 'GID',UID
	> 'myowngroup','DL'
	= insert into groups values('myowngroup','DL')
	Y/N ? Y

=item B<delgroup>

delete a user's group

	<WOC> delgroup group
	= delete from group where gid = group
	Y/N ? Y

=item B<grant auth>

define an access record into the 'auth' authorization table, ie. grant Read or Edit or Adm authorization to 
a userid for a resourceName of the resourceType 'auth'. 

	<WOC> grant authprocs
	enter new row as: 'UID','RESOURCE',AUTH
	> 'JD','SOURCES',4
	= insert into authprocs values('JD','SOURCES',4)
	Y/N ? Y

=item B<auth login>

another way to look at authorizations granted to 'login' user. 

	<WOC> auth webobs
	authprocs =>
	* 4
	authviews =>
	* 4
	authmisc =>
	* 4
	authforms =>
	* 4
	authwikis =>
	* 4

=item B<%NODES [key]> 

dump %NODES key or all keys - [key] is a regular expression

	<WOC> %NODES
	$NODES{SPATH_SCHEMES} => SCHEMAS
	$NODES{FILE_NODES2NODES} => /data1/webobs/CONF/nodes2nodes.rc
	$NODES{CGI_FORM} => formNODE.pl
	.....
	$NODES{SPATH_DOCUMENTS} => DOCUMENTS

=item B<proc [proc]>

dump a PROC proc or list all PROCs

	<WOC> proc
	SOURCES
	CGPSWI

	<WOC> proc SO
	SOURCES
	ddb ==> CGI_AFFICHE_EAUX
	net ==> 304
	THUMBNAIL ==> 1
	....
	FORM ==> EAUX

=item B<form [form]>

dump a FORM form or list all FORMS. Form is dump using the Form object's dump method 
(ie. my $F = new WebObs::Form($_[0]); print $F->dump; )

	<WOC> form EAUX
	Form EAUX
	Form configuration path: /data1/woz/CONF/FORMS/EAUX
	FILE_NAME => EAUX.DAT
	BANG => 1797
	FILE_TYPE => typeSitesEaux.conf
	TITLE => Databank of waters chemical analysis
	CGI_POST => postEAUX.pl
	CGI_SHOW => showEAUX.pl
	CGI_FORM => formEAUX.pl
	FILE_RAPPORTS => rapportsEaux.conf
	FILE_CSV_PREFIX => OVSG_EAUX
	Form data file is: /data1/woz/DATA/DB/EAUX.DAT
	Related proc(s): SOURCES(Soufrière Hot Springs Analysis)

=item B<view [view]>

dump a VIEW view or list all VIEWS

=item B<node [node]>

dump a NODE node or list all NODES names

	<WOC> node
	GCSBJN1  WDCBIM0  WDCMPOM  WDCDHS0  WDCTDB0  WDCABD0  WDCDSD0  WDCCBE0
	DJLTEST  JTATEST  WDCILAM  GCSBCM1  WDCMGL0

=item B<nodegrids [node]>

list all GRIDS referenced by a NODE node, or all GRIDS of all NODES

	<WOC> nodegrids GCSBCM1
	GCSBCM1 :
	PROC.SOURCES
	VIEW.SOURCES

=item B<nodedev [node]>

list nodes2node.rc for NODE node 

=item B<statnodes>

statistics on node+grids

	<WOC> statnodes 
	    13 node directories
	     2 nodes have no grid
	       DJLTEST  JTATEST            
	     0 node has no proc
	     0 node has no view

=item B<newnode gridtype.gridname.newnode {from|as} othernode>

attempt to create 'newnode' and associate it to grid 'gridtype.gridname'. 
CONF/GRIDS2NODES reference and NODE/newnode are created. 
newnode.cnf will be a copy of 'othernode.cnf'. 

=item B<delnode node>

delete node 'node'. Deletes all references to 'node' in CONF/GRIDS2NODES and the NODE/node directory.

=item B<readcfg file>

dump file using readCfg. Well-known WebObs hash (such as %WEBOBS, %USERS,...) keys may be used in place of 'file'.
Example: 

	<WOC> %WEBOBS HEBDO
	[[ %WEBOBS from /etc/webobs.d/WEBOBS.conf (1381419055) + /etc/webobs.d/WEBOBS.rc (1381471427) ]]
	$WEBOBS{HEBDO_CONF} => /data1/woz/CONF/HEBDO.conf

	<WOC> readcfg $WEBOBS{HEBDO_CONF}
	/data1/woz/CONF/HEBDO.conf
	$VAR1 = {
	'FILE_NAME' => '/data1/woz/DATA/DB/HEBDO.DAT',
	'BANG' => '2001',
	'FILE_TYPE_EVENEMENTS' => '/data1/woz/CONF/HEBDOtypes.conf',
	'CGI_FORM' => 'formHEBDO.pl',
	'DEFAULT_TRI' => 'Calendar',
	'DEFAULT_DATE' => 'semaineCourante',
	'TITLE' => 'Hebdo',
	'CGI_POST' => 'postHEBDO.pl',
	'CGI_SHOW' => 'showHEBDO.pl',
	'DEFAULT_TYPE' => 'Tout'
	};

=item B<dbjobs>

list all jobs definitions known to the scheduler.

	<WOC> dbjobs
	JID = 1
	VALIDITY = N
	XEQ1 = $WEBOBS{JOB_MLNODISPLAY} 
	XEQ2 = -r "locastat;exit(0)"
	XEQ3 = 
	RUNINTERVAL = 86400
	MAXSYSLOAD = 0.7
	LOGPATH = locastat

	JID = 2 
	....


=item B<newjob>

add a job definition

=item B<dbruns>

list all jobs last-run info 

=item B<sys>

print system/WebObs information  

=item B<! cmd>

exec a shell cmd (WebObs vars single-quoted for interpolation) 

=item B<= expr>

exec a perl expression (interactive mode only) 

=item B<dd>

keys of main hashes and their occurence 

=item B<ddxref>

keys of main hashes + their occurence + cross-reference 

=item B<help>

this help text ! 

=item B<quit>

make a guess ! 

=back

=head1 AUTHOR

Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014/2013 - Institut de Physique du Globe Paris

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

