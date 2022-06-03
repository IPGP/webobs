#!/usr/bin/perl

=head1 NAME

showQRcode.pl

=head1 SYNOPSIS

http://..../showQRcode.pl

=head1 DESCRIPTION

HTML page with QR code of the referer URL.

=head1 Parameters

no query string parameters needed, but logos will be displayed on the side of
QR code, using the WEBOBS.rc variables:
	QRCODE_LOGOS|logo1,logo2,...

=cut

use strict;
use warnings;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use MIME::Base64;

my $title = "$ENV{HTTP_REFERER}";
my $qr = encode_base64(qx(qrencode -t SVG -o - "$ENV{HTTP_REFERER}"));
my $img = ($qr eq "" ? "":"<IMG height=\"400px\" src=\"data:image/svg+xml;base64,$qr\">");
my @logos = split(',',$WEBOBS{QRCODE_LOGOS});

print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">","\n";
print "<HTML><HEAD><TITLE>$title</TITLE></HEAD><BODY style=\"background-color: white;\">\n"
	."<TABLE width=\"100%\"><TR><TD width=\"400px\" style=\"border:0\">$img\n"
	."<P style=\"font-size:6pt;text-align:center\">$title</P></TD>"
	."<TD style=\"border:0;text-align:center\">";
for (@logos) {
	print "<P><IMG width=\"100px\" src=\"$_\"></P>";
}
print "</TD></TR></TABLE>\n"
	."</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

François Beauducel

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
