#!/usr/bin/perl

=head1 NAME

wsudp.pl

=head1 SYNOPSIS

perl wsudp.pl 'msg=> [,...see ARGUMENTS below...]'

=heAd1 DESCRIPTION

This command line script sends a message to a UDP server, prints corresponding
reply from the server to stdout. Mainly used as the command line interface to
the WebObs Scheduler.

=head1 ARGUMENTS

Arguments are passed as a unique string made up of comma separated hash
'key=>value'.

Mandatory arguments:

	msg => message to be sent to server
	eg: msg=>"CMD STAT"

Mandatory wsudp arguments with defaults:

	host => server addr , used as socket PeerAddr
	default: host=>"localhost"

	port => server port , used as socket PeerPort
	default: 7761

	ll => maximum reply length , used in socket recv
	default: ll=>1500

	to => timeout , used as socket Timeout (in seconds)
	default: to=>5

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


# Options allowed on the command line as <opt> => <value>
# and the regexp the value must match.
my %opts_regexp = (
	'msg' => '[\w ]+',
	'host' => '[\w.-]+',
	'port' => '\d+',
	'to' => '\d+',
	'll' => '\d+',
);

my %opts = ();

# Read and parse arguments from the command line as options
foreach my $arg (@ARGV) {

	# Read argument as "key => value"
	my ($k, $v) = $arg =~ /^\s*([a-z]+)\s*=>\s*(?:'|")?(.+?)(?:'|")?\s*$/;

	# Make sure option exists and its value has a valid format
	if (not $opts_regexp{$k} or $v !~ /$opts_regexp{$k}/) {
		print STDERR "Error: invalid argument '$arg'\n";
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

