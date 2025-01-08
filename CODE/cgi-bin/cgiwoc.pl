#!/usr/bin/perl

=head1 NAME

cgiwoc.pl 

=head1 SYNOPSIS

http://...../CODE/cgi-bin/cgiwoc.pl?cmd=

=head1 DESCRIPTION

Executes a woc command (specified by cmd=) and formats the woc output lines as html: 
all output lines in a DIV, with '\n' translated to '<br>' and spaces translated to '&nbsp;'

If no cmd= specified, it will default to 'cmd=help'.

cgiwoc.pl is part of the html-based woc execution/display page, ie.: 

    1) html/cgiwoc.html to start html-base woc, setting up page with
    2) css/cgiwoc.css 
    3) js/cgiwoc.js to call (ajax load) cgiwoc.pl and add output DIV to page,
    taking care of scrolling

=cut

use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw/strftime/;
use WebObs::Users qw(clientHasAdm);

my $cgi = new CGI;
my $QryParm = $cgi->Vars;
$QryParm->{'cmd'}    ||= "help";

# MUST have admin level (authmisc woc 4)
if ( ! clientHasAdm(type=>"authmisc",name=>"woc")) {
    die "Sorry, you cannot display this page.";
}

my @results = qx( perl ../perl/woc.pl $QryParm->{'cmd'});
foreach (@results) {
    s/\n/<br>/g;
    s/\s/&nbsp;/g;
}
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "<DIV>@results</DIV>";
exit;

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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

