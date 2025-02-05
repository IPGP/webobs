#!/usr/bin/perl
#

use strict;
use warnings;
use POSIX qw/tcgetpgrp getpgrp/;

open LOG, ">fbgstd.log";
my $u = qx(lsof -a -p $$ -d0,1,2); print LOG "---- lsof:\n$u\n";
if (-t STDIN) { print LOG "---- -t STDIN true \n" } else { print LOG "---- -t STDIN false\n"}
if (-t STDOUT) { print LOG "---- -t STDOUT true \n" } else { print LOG "---- -t STDOUT false\n"}

#$u = qx(ps T -o pid,ppid,pgid,pgrp,user,args | grep $0);
$u = qx(ps -u $< f -o stat,pid,ppid,pgid,tpgid,tty,sid,user,args);
print LOG "---- ps:\n$u";
if (!open(TTY, "/dev/tty")) {
    print LOG "---- open /dev/tty failed\n";
} else {
    my $tpgrp = tcgetpgrp(fileno(*TTY));

    #my $tpgrp = tcgetpgrp(fileno(*STDIN));
    my $pgrp = getpgrp();
    print LOG "---- pgrp = $pgrp , tpgrp = $tpgrp ==> ";
    if ($tpgrp == $pgrp) {
        print LOG "foreground\n";
    } else {
        print LOG "background\n";
    }
}
close LOG;

#print "# Start script\n";
#print "\n    -> Waiting 2 seconds\n";
#sleep(2);
#print "\n    -> Waiting 2 seconds\n";
#sleep(2);
#print "# Exiting .. \n";
