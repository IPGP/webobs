package WebObs::i18n;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::i18n   
 
the legacy i18n.pm module, without the u2l() and l2u() subroutines 

=cut

use strict;
use WebObs::Config;
use Data::Dumper;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use CGI::Cookie;

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);

require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(cherche_langue aff_langues);
@EXPORT_OK  = qw();
$VERSION    = "1.00";

use Locale::Messages qw(:locale_h :libintl_h);
use Locale::TextDomain('webobs');
use POSIX qw (setlocale);

bindtextdomain "webobs" => $WEBOBS{ROOT_I18N}."/locales";
bind_textdomain_codeset 'webobs' => "UTF-8";

my $langue_defaut = $WEBOBS{LOCALE};
my $langue_utilisee;
my %cookies;
my $langue_cookie;

cherche_langue();

sub cherche_langue {
    my $langue = shift;
    if ( defined $langue and $langue ne "" ){
        $langue_utilisee = $langue;
    } else {
        %cookies = fetch CGI::Cookie;
        $langue_cookie = exists($cookies{'langue_webobs'}) ? $cookies{'langue_webobs'}->value : "";
        if ($langue_cookie ne "") {
            $langue_utilisee = $langue_cookie;
        } else {
            $langue_utilisee = $langue_defaut;
        }
    }
    setlocale (LC_ALL, $langue_utilisee);
    $ENV{LC_ALL}=$langue_utilisee;
}

sub aff_langues () {
    print '<pre style="background-color: #eee; text-align: left;">'.Dumper('Fichier : '.__FILE__,'Ligne : '.__LINE__,'$langue_defaut',$langue_defaut).'</pre>';
    print '<pre style="background-color: #eee; text-align: left;">'.Dumper('Fichier : '.__FILE__,'Ligne : '.__LINE__,'$langue_cookie',$langue_cookie).'</pre>';
    print '<pre style="background-color: #eee; text-align: left;">'.Dumper('Fichier : '.__FILE__,'Ligne : '.__LINE__,'$langue_utilisee',$langue_utilisee).'</pre>';
}

binmode STDOUT, ':raw'; # Needed to make it work in UTF-8 locales in Perl-5.8.
1;

__END__

=pod

=head1 AUTHOR

25 mai 2007 09:12:51 Alexis Bosson
 repackaged Didier Lafon

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
