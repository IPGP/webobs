#!/usr/bin/perl -w

=head1 NAME

postNODE.pl

=head1 SYNOPSIS

http://..../postTHEIA.pl?nodes=nodes,channels=channels

=head1 DESCRIPTION

Write in theia.rc the selected nodes and channels to send to the THEIA|OZCAR data portal.

=head1 Query string parameters

 nodes=
 the NODEs names that we want to send the metadata to THEIA.
 
 channels=
 the CHANNELs names that we want to send the metadata to THEIA.

=cut

use strict;
use warnings;
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
use POSIX qw/strftime/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024 * 1000;
use feature 'say';

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::i18n;
use WebObs::Utils;

# receiving the nodes and channels selected from the showTHEIA.pl resume board
my $QryParm  = $cgi->Vars;
my @nodes    = split(/,/, $QryParm->{'nodes'});
my @channels = split(/,/, $QryParm->{'channels'});

# ---- local functions
#

# Return information when OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" if (isok($WEBOBS{CGI_CONFIRM_SUCCESSFUL}));
	exit;
}
# Return information when not OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgNotOK {
	close(FILE);
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "(create/)update FAILED !\n $_[0] \n";
	exit;
}

my $filename = "$WEBOBS{CONF_THEIA}";   # the theia.rc configuration file where we will write the id of the selected nodes and channels
my @lines;                              # we will write the content of the file theia.rc in this variable

push(@lines,"=key|value\n");            # first line of theia.rc
push(@lines,"NODES|".join(',', @nodes)."\n");
push(@lines,"CHANNELS|".join(',', @channels));

if ( sysopen(FILE, "$filename", O_RDWR | O_CREAT) ) {
    unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postTHEIA waiting for lock on $filename...";
		flock(FILE, LOCK_EX);
	}

    truncate FILE, 0;
    print FILE @lines;
	close(FILE);
} else { htmlMsgNotOK("$filename $!") }

htmlMsgOK("$filename has been edited !");

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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
