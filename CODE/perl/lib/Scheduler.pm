package WebObs::Scheduler;

=encoding utf8

=head1 NAME

Package WebObs::Scheduler - common functions to contact the running
scheduler process and submit it with commands.

=head1 SYNOPSIS

	use WebObs::Scheduler qw(scheduler_client);
	my ($response, $error) = scheduler_client($opts{'msg'}, \%opts);

=head1 DESCRIPTION

This modules provides the functions to contact the scheduler daemon process,
submit it with commands, and read the response.

=head1 FUNCTIONS

=over

=item scheduler_client($command, \%opts)

Submit a command to the scheduler process listening on UDP.

=back

=cut

use strict;
use warnings;
use IO::Socket::INET;
require Exporter;

use WebObs::Config qw(%WEBOBS readCfg);

our(@ISA, @EXPORT, $VERSION);
@ISA     = qw(Exporter);
@EXPORT  = qw(scheduler_client);
$VERSION = "1.00";

# Read the scheduler configuration
my %SCHEDULER_CONF = readCfg($WEBOBS{'CONF_SCHEDULER'});

sub scheduler_client {

# Submit a command to the scheduler process listening on UDP.
#
# @parameters:
# $opts (hash reference)
#   A reference to a hash defining the following options (missing options
#   use sensible defaults):
#   'host'       : hostname where the scheduler is listening
#                  (default: 'localhost')
#   'port'       : UDP port used by the scheduler (default: $SCHEDULER_CONF{'PORT'})
#   'max_length' : maximum number of characters read while reading the
#                  scheduler response (default: $SCHEDULER_CONF{'SOCKET_MAXLEN'})
#   'timeout'    : timeout to use while contacting the scheduler
#                  (default: 5)
# $cmd (string)
#   The command to be submitted to the scheduler.
#
    my $cmd = shift;
    my $opts = shift || {};
    my ($response, $error);
    local $| = 1;  # autoflush

    if (not $cmd) {
        return ("", "empty command: nothing to send\n");
    }

    my %opts = (

        # Default values first
        'host' => $SCHEDULER_CONF{'LISTEN_ADDR'} || 'localhost',
        'port' => $SCHEDULER_CONF{'PORT'},
        'max_length' => $SCHEDULER_CONF{'SOCKET_MAXLEN'},
        'timeout' => 5,

        # Override with values from argument
        %$opts,
      );

    my $socket = IO::Socket::INET->new(
        'PeerAddr' => $opts{'host'},
        'PeerPort' => $opts{'port'},
        'Proto' => 'udp',
      );
    if (not $socket) {
        return ("", "unable to create socket: $!");
    }

    eval {
        local $SIG{'ALRM'} = sub { die 'Timed Out'; };
        alarm $opts{'timeout'};
        if ($socket->send($cmd)) {
            if (not $socket->recv($response, $opts{'max_length'})) {
                $error = "failed to read answer: $!";
            }
        } else {
            $error = "failed to send request: $!";
        }
      };
    alarm 0;
    if ($@ && $@ =~ /Timed Out/ ) {
        $error = "connection timeout after $opts{'timeout'}s";
    }
    $socket->close();
    return ($response, $error);
}

1;

__END__

=pod

=head1 AUTHORS

=over

=item Xavier Béguin

Updated version of scheduler_client and creation of this module.

=item Didier Lafon

Original version of the scheduler_client code (originally in wsudp.pl).

=back

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
