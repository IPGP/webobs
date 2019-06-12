#!/usr/bin/perl 

=head1 NAME

viewMAN.pl 

=head1 SYNOPSIS

 cgi-bin/viewMAN.pl?man={man.1-filename}

=head1 DESCRIPTION

Builds an HTML page to display a man page  

=cut

use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use File::Find;
use WebObs::Config;

my $cgi = new CGI;
my $man = $cgi->param('man') // '';
$man = $man.".1";
$man =~ s/^.*\//..\/..\/DOC\//g;

print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
print "<html><head><title>webobs manpages</title>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/viewman.css\">";
#print "<style>body {background: url(\"/icons/ipgp/logo_OVS.op15.png\") no-repeat fixed white;}</style>";
print "</head>";

if ( -f $man ) {
	mkdir("$WEBOBS{ROOT_DATA}/tmp"); chdir("$WEBOBS{ROOT_DATA}/tmp");
	##my @h = qx(groff -T html $man);
	my @h = qx(man2html $man);
	my $groffbody=0; while (! $groffbody) { my $x=shift @h; $groffbody=1 if $x =~ "<BODY>" }
	my $groffbody=0; while (! $groffbody) { my $x=pop   @h; $groffbody=1 if $x =~ "</BODY>" }
	for (@h) { print $_; }
} else {
	print "<body><H2>man page $man not found</h2>";
}

print "</body></html>";

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

