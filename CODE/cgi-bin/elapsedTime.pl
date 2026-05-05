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
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
my $cgi = new CGI;

use WebObs::Config;
use WebObs::Grids;
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

my $QryParm   = $cgi->Vars;
my $grid      = $QryParm->{'grid'}       // "";
my $name      = $QryParm->{'name'}       // "";
my $format    = $QryParm->{'format'}     // "[YY]:[DDD]:[hh]:[mm]";
my $size      = $QryParm->{'size'}       // "2rem";
my $labelsize = $QryParm->{'labelsize'}  // ".8rem";
my $debug     = $QryParm->{'debug'}      // "";

my $today = strftime('%F',localtime());

my $readOK;
my %GRID;
my @EVENTS;
my @E;
my @last;
my $startend = 'end';
my $comment;
my $datetime;

my ($GRIDType,$GRIDName) = split(/[\.\/]/, trim($grid));
if ( WebObs::Users::clientHasRead(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
    my %G;
    if     (uc($GRIDType) eq 'VIEW') { %G = readView($GRIDName) }
    elsif  (uc($GRIDType) eq 'PROC') { %G = readProc($GRIDName) }
    elsif  (uc($GRIDType) eq 'FORM') { %G = readForm($GRIDName) }
    if (%G) {
        %GRID = %{$G{$GRIDName}};
        foreach (split(/,/,$GRID{EVENTS_FILE})) {
            @E = readCfgFile($_);
            @E = grep(/(.*\|){4}$name\|/, @E) if ($name ne "");
            push(@EVENTS, @E);
        }
        if ($#EVENTS >= 0) {
            @EVENTS = sort @EVENTS;
            @last = split(/\|/, @EVENTS[-1]);
            $name = $last[4];
            $comment = ($last[5] ne "" ? "($last[5])":"");
            if ($last[1] eq "" || $last[1] gt $today) {
                $startend = 'start';
                $datetime = $last[0];
            } else {
                $datetime = $last[1];
            }
            $readOK = 1;
        }
    }
}

# print the javascript content
print "Content-type: application/javascript\n\n";

# ends here (return empty js content) if conditions are not met
if (!$readOK) {
    if ($debug) {
        print "container.innerHTML = ".join(" ",@E).";";
    }
    exit;
}

my ($y,$m,$d,$H,$M) = $datetime =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+)/;
my $epoch = timelocal(0,$M,$H,$d,$m-1,$y);

my @items = split(/:/,$format);
my %T = (
    'Y' => "$__{'years'}",
    'W' => "$__{'weeks'}",
    'D' => "$__{'days'}",
    'h' => "$__{'hours'}",
    'm' => "$__{'minutes'}",
    's' => "$__{'seconds'}",
);
foreach my $k (keys %T) {
    my $v = $T{$k};
    @items = map {
        s/\[$k+\]/['$v']/g;
        $_;
    } @items;
}
my $labels = join(",\n",@items);

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
        container.innerHTML = "<h3>$__{'Elapsed time since'} $__{$startend} $__{'of event'} $name $comment</h3><div id='clock'></div>";
        const start = $epoch * 1000;
        const { flipClock, elapsedTime, theme, css } = FlipClock;
        flipClock({
            parent: document.getElementById('clock'),
            face: elapsedTime({
                from: new Date(start),
                format: '$format'
            }),
            theme: theme({
                dividers: ':',
                labels: [
                    $labels
                ],
                css: css({
                    fontSize: '$size',
                })
            })
        });
        setTimeout(() => {
            document.querySelectorAll('#clock .flip-clock-label').forEach(el => {
                el.style.fontSize = '$labelsize';
                el.style.marginBottom = '0';
            });
        }, 0);
    });
})();
};

__END__

=pod

=head1 AUTHOR(S)

François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2026 - Institut de Physique du Globe Paris

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

