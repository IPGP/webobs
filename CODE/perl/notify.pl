#!/usr/bin/perl

=head1 NAME

notify.pl

=head1 SYNOPSIS

 $ perl notify.pl cmd 

=head1 DESCRIPTION

Sends B<notifications requests> to the WebObs B<postboard> named pipe.  

Just a perl command-line interface to the WebObs::Config::notify routine.
See the latter for documentation. 

=cut

use strict;
use warnings;
use WebObs::Config;

my $rc = WebObs::Config::notify($ARGV[0]);
if ( $rc == 0) {
    printf ("Sent.\n");
    exit(0);
} else {
    if ($rc == 98) { printf ("Can't start: no POSTBOARD_NPIPE definition in WebObs configuration\n"); }
    if ($rc == 96) { printf ("Couldn't open $WEBOBS{POSTBOARD_NPIPE}: $? $!\n"); }
    if ($rc == 97) { printf ("Missing argument, nothing to notify.\n"); }
    if ($rc == 99) { printf ("Invalid argument format, not a notify request\n"); }
    exit($rc);
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

