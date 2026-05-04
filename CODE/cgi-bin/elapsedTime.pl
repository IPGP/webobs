#!/usr/bin/perl

=head1 NAME

elapedTime.pl

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 Query string parameters

 type=
 optional, specifies which language to use

=cut

use strict;
use warnings;
use Time::Local;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
my $cgi = new CGI;

use WebObs::Config;
use WebObs::Utils;
use WebObs::Users;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# if the client is not a valid user, ends here !!
if (!WebObs::Users::clientIsValid) {
    print $cgi->header(-type=>'text/html', -charset=>'utf-8');
    print "<H1>$WEBOBS{WEBOBS_ID}: $WEBOBS{VERSION}</H1>"
      ."Sorry, user '$USERS{$CLIENT}{LOGIN}' is not valid or is waiting for validation by an administrator...";
    exit(1);
}

print "Content-type: application/javascript\n\n";

my $date_str = '2026-04-12 19:10:00';
my $epoch = timelocal(0,10,19,12,3,2026);

print qq{
(function() {
    function loadScript(src, callback) {
        const s = document.createElement('script');
        s.src = src;
        s.onload = callback;
        document.head.appendChild(s);
    }

    loadScript('/js/FlipClock.umd.js', function() {
        const container = document.getElementById('clock-container');
        container.innerHTML = '<h3>Elapsed time since last eruption</h3><div id="clock"></div>';
        const start = $epoch * 1000;
        const { flipClock, elapsedTime, theme, css } = FlipClock;
        flipClock({
            parent: document.getElementById('clock'),
            face: elapsedTime({
                from: new Date(start),
                format: '[YY]:[DDD]:[hh]:[mm]'
            }),
            theme: theme({
                dividers: ':',
                labels: [
                    ['Years'],
                    ['Days'],
                    ['Hours'],
                    ['Minutes'],
                ],
                css: css({
                    fontSize: '2rem',
                    '.flip-clock-label': {
                        fontSize: '.5rem',
                        marginBottom: '0',
                    }
                })
            })
        });        
    });
})();
};

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel

=head1 COPYRIGHT

Webobs - 2012-2026 - Institut de Physique du Globe Paris

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

