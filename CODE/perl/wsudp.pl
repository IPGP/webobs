#!/usr/bin/perl

=head1 NAME

wsudp.pl

=head1 SYNOPSIS

perl wsudp.pl 'msg=> [,...see ARGUMENTS below...]'

=head1 DESCRIPTION

This command line script sends a message to a UDP server, prints corresponding
reply from the server to stdout. It is mainly intended to be used as the
command line interface to the WebObs Scheduler.

This is merely a command line interface to the module function
WebObs::Scheduler::scheduler_client().

=head1 ARGUMENTS

Arguments are passed as a unique string made up of comma separated hash
'key=>value'.

Mandatory arguments:

    msg => message to be sent to server
    eg: msg=>"CMD STAT"

Optional arguments:

    host => server addr , used as socket PeerAddr
    default value: value of LISTEN_ADDR as set in the scheduler configuration,
                   or 'localhost' if this configuration is not set.

    port => server port , used as socket PeerPort
    default value: value of PORT as set in the scheduler configuration.

    max_length => maximum reply length , used in socket recv
    default value: value of SOCKET_MAXLEN as set in the scheduler
                   configuration.

    timeout => timeout , used as socket Timeout (in seconds)
    default value: 5 seconds

    For backward compatibility with older version, the 'll' option is accepted
    as an alias for 'max_length', and 'to' as an alias for 'timeout'.

=head1 OUTPUTS

Reply from server are sent to stdout.  In case of error, the error message
returned by WebObs::Scheduler::scheduler_client is printed to stderr.

Possible error message are (followed by lower level error message if any):

    wsudp.pl error: empty command: nothing to send
    wsudp.pl error: unable to create socket:
    wsudp.pl error: failed to send request:
    wsudp.pl error: failed to read answer:
    wsudp.pl error: connection timeout after Xs:

=head1 EXIT CODES

The script uses an exit code of 1 if the scheduler_client function returned an
error, 0 otherwise.

=cut

use strict;
use warnings;
use IO::Socket::INET;

use WebObs::Scheduler qw(scheduler_client);

sub usage {
    print <<"_EOD_";
Usage: perl $0 'msg=>"COMMAND"' ['option=>value' ...]

Send a message to a UDP server and print its reply to stdout.
Mainly used as the command line interface to the WebObs Scheduler.

Mandatory argument:

  msg => message to be sent to server

Options:

  host => <server addr>, used as socket PeerAddr
  default value: value of LISTEN_ADDR as set in the scheduler configuration,
                 or 'localhost' if this configuration is not set.

  port => <server port>, used as socket PeerPort
  default value: value of PORT as set in the scheduler configuration.

  max_length => <maximum reply length>, used in socket recv
  default value: value of SOCKET_MAXLEN as set in the scheduler configuration.

  timeout => <timeout>, used as socket Timeout (in seconds)
  default value: 5 seconds

  Reply from server are printed to stdout.  In case of error, the error message
  returned by WebObs::Scheduler::scheduler_client is printed to stderr.

Examples:

  $0 'msg => CMD QS'
  $0 'msg => CMD STAT' 'timeout => 2'

_EOD_
}

if (not @ARGV) {
    usage();
    exit(1);
}

# Options allowed on the command line as <opt> => <value>
# and the regexp the value must match.
my %opts_regexp = (
    'msg' => '[\w ]+',
    'host' => '[\w.-]+',
    'port' => '\d+',
    'timeout' => '\d+',
    'max_length' => '\d+',
  );

# Backward compatibility aliases for options
my %compat_aliases = (
    'to' => 'timeout',
    'll' => 'max_length',
  );

my %opts = ();

# Read and parse arguments from the command line as options
foreach my $arg (@ARGV) {

    # Read argument as "key => value"
    my ($k, $v) = $arg =~ /^\s*([a-z]+)\s*=>\s*(?:'|")?(.+?)(?:'|")?\s*$/;

    if (not $k) {
        print STDERR "Error: cannot read arguments, please check their format.\n";
        usage();
        exit(1);
    }

    # Apply any option name alias
    if ($compat_aliases{$k}) {
        $k = $compat_aliases{$k};
    }

    # Make sure option exists and its value has a valid format
    if (not $opts_regexp{$k} or $v !~ /$opts_regexp{$k}/) {
        print STDERR "Error: invalid argument or format '$arg'\n";
        exit(1);
    }

    # Explicitely reject duplicated options
    if ($opts{$k}) {
        print STDERR "Error: option '$k' defined more than once\n";
        exit(1);
    }
    $opts{$k} = $v;
}

# Submit the command and read the answer
my ($response, $error) = scheduler_client($opts{'msg'}, \%opts);

# Print the response
print $response;

# Use exit code of 1 in case of error, 0 otherwise
my $exit_code;
if ($error) {
    (my $script_name = $0) =~ s|^.*/||;
    print STDERR "$script_name error: $error\n";
    $exit_code = 1;
} else {
    $exit_code = 0;
}

exit($exit_code);

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon (original script)
Xavier Béguin (rewrite, deporting code to WebObs::Scheduler)

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

