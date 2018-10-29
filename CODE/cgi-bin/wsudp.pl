#!/usr/bin/perl

=head1 NAME

wsudp.pl 

=head1 SYNOPSIS

perl wsudp.pl 'msg=> [,...see ARGUMENTS below...]'

=head1 DESCRIPTION

Sends a message to a UDP server, prints corresponding reply from the server to stdout.
Mainly used as the command line interface to WebObs Scheduler's. Could be used as a generic UDP client 
since it doesn't rely on WebObs definitions nor libraries, and doesn't parse/interpret strings sent and 
received to/from the contacted server. 

=head1 ARGUMENTS

Arguments are passed as a unique string made up of comma separated hash 'key=>value'. 

Mandatory arguments:

	msg => message to be sent to server
	eg: msg=>"CMD STAT" 

Mandatory wsudp arguments with defaults:

	host => server addr , used as sockect PeerAddr
	default: host=>"localhost"

	port => server port , used as sockect PeerPort
	default: 7761

	ll => maximum reply length , used in socket recv 
	default: ll=>1500  

	to => timeout , used as socket Timeout (in seconds)
	default: to=>5

=head1 OUTPUTS

Reply from server and/or error messages are sent to stdout.

Error messages:

	wsudp failed nothing to send
	wsudp failed create:
	wsudp failed send:
	wsudp failed received: 
	wsudp failed timeout:

=cut

use strict;
use warnings;
use IO::Socket::INET;

my $resp = '';
$|=1;

my %dfts = ( host => 'localhost', port => 7761, msg => undef, to => 5, ll => 1500 );
my $opts = { %dfts, eval($ARGV[0]), }; 

if ($opts->{msg} && $opts->{msg} ne '') {
	if (my $socket=new IO::Socket::INET->new(PeerAddr => $opts->{host}, PeerPort=>$opts->{port}, Proto=>'udp')) {
		eval {
			local $SIG{ALRM} = sub { die 'Timed Out'; };
			alarm $opts->{to};
			if ($socket->send($opts->{msg})) {
				if ($socket->recv($resp, $opts->{ll})) {
					print "$resp";
				} else { print("wsudp failed received: $@ $!\n")}
			} else { print("wsudp failed send: $@ $!\n")}
			alarm 0;
		};
		alarm 0;
		print "wsudp failed timeout: $opts->{to}s\n" if ( $@ && $@ =~ /Timed Out/ );
		$socket->close();
	} else { print("wsudp failed create: $@ $!\n") }
} else { print("wsudp failed nothing to send\n") }

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

