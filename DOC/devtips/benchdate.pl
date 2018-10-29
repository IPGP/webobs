#!perl
use strict;
use warnings;
use Benchmark qw(:all);
use POSIX qw(strftime mktime);


# -3 =approx. 3 seconds
cmpthese( -3, {
    'date'         => \&qxdate,
    'strftime'     => \&strf,
    });

sub qxdate {
   my $d = qx(date -d "2012-01-01" +"\%B \%Y"); chomp($d);
}
sub strf {
   # mktime(sec, min, hour, mday, mon, year, wday = 0, yday = 0, isdst = -1)
   my $t = mktime( 0, 0, 0, 1, 0, 112 );  my $d = strftime("%B %Y", localtime($t))
}

