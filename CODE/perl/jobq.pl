#!/usr/bin/perl

=head1 NAME

 jobq.pl  

=head1 SYNOPSIS

 $ perl jobq.pl [-v] [-c file] [-m cmd]  

=head1 DESCRIPTION

B<-m cmd> : sends B<cmd> to the WebObs Job Scheduler (scheduler.pl). 

'cmd' is either 1) a submit request (job) or 2) a scheduler internal command.
See the scheduler.pl perldoc for an up-to-date description of cmd.  

=cut

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin; 
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime :signal_h :errno_h :sys_wait_h/;
use IO::Socket;
use Getopt::Std;
use WebObs::Config;

#fixJul added FindBin 

# ---- parse options
# ---- -v to be verbose, -c to specify configuration file, -m cmd to send 
# -----------------------------------------------------------------------------
my %options;
getopts("vc:m:",\%options);
my $verbose = defined($options{v}) ? 1 : 0;
my $configf = defined($options{c}) ? $options{c} : '';
my $msg     = defined($options{m}) ? $options{m} : '';

# ---- read scheduler configuration
# ---- command-line configuration file supersedes WEBOBS one
# -----------------------------------------------------------------------------
our %SCHED;
if ($configf ne '' && -e $configf) { %SCHED = readCfg($configf) }
else { if (defined($WEBOBS{CONF_SCHEDULER})) { %SCHED = readCfg($WEBOBS{CONF_SCHEDULER}) }}
if ( scalar(keys(%SCHED)) <= 1 ) { 
	printf ("%16.6f %s",time,"can't start: no|invalid configuration file\n");
	exit(1);
}

# ---- send command / receive reply from scheduler
# ----------------------------------------------------------------------------
my $SOCK = undef;
my $server = "localhost"; 
my $TIMEOUT=5;

# create socket 
$SOCK = IO::Socket::INET->new(Proto => 'udp', PeerPort  => $SCHED{PORT}, PeerAddr  => $server );
if ( !$SOCK ) {
	printf "couldn't create socket on port $SCHED{PORT}\n";
	exit(2);
}
# send / receive
if ( $SOCK->send($msg) ) {
	if ( $SOCK->recv($msg, $SCHED{SOCKET_MAXLEN}) ) { 
		print "Server ".$SOCK->peerhost.":".$SOCK->peerport." replied:\n$msg\n";
	} else {
		print "socket recv error\n";
		exit(3);
	}
} else {
	print "socket send error\n";
	exit(3);
}
exit(0);

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

