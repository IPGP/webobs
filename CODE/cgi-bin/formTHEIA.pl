#!/usr/bin/perl

=head1 NAME

formTHEIA.pl

=head1 SYNOPSIS

http://..../formTHEIA.pl

=head1 DESCRIPTION

Edits data to send to the Theia/OZCAR pivot model.

=cut

use strict;
use File::Basename;
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024 * 10;
$CGI::DISABLE_UPLOADS = 1;
my $cgi = new CGI;

# ---- ready for HTML output now
#
print $cgi->header(
	-charset                     => 'utf-8',
	-access_control_allow_origin => 'http://localhost',
	),
$cgi->start_html("$__{'Theia data form'}");

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Mallarino, Alexis Bosson, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2022 - Institut de Physique du Globe Paris

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

