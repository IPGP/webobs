#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime :signal_h :errno_h :sys_wait_h/;

my $kidcmd; my $dcd; my $dcdRC; my $dcdmsg; my $drc;
my $redir = ">";
open (MYLOG, '>>/home/lafon/sandbox/sfork.log');
print MYLOG "---------------------------------\n";
$drc = qx(rm -rf /home/lafon/sandbox/sfork.out /home/lafon/sandbox/sfork.err );

##print "enter cmd: ";
##$kidcmd = <STDIN> ; chomp($kidcmd);

#$kidcmd="export MATLABPATH=/data1/webobs/CODE/matlab;export LANG=fr_FR.ISO8859-1;matlab -nodisplay -r 'locastat;quit'";
#$kidcmd="export MATLABPATH=/data1/webobs/CODE/matlab;/home/lafon/sandbox/doout";
#$kidcmd="matlab -nodisplay -nojvm -r \"system(sprintf('lsof -a -p %d -d0,1,2',feature('GetPid')));quit\" ";
#$kidcmd="matlab -nodisplay -r 'quit'";
$kidcmd="matlab -nodisplay <<< 'disp(datestr(now));exit(16)'";

my $kid = fork();
if (!defined($kid)) {
    print MYLOG "$$ couldn't fork [ $kidcmd ] !\n";
}
if ($kid == 0) { # kid's code
    $drc = qx(lsof -a -p $$ -d0,1,2);
    print MYLOG "$drc\n";

    #open STDOUT, $redir, "/home/lafon/sandbox/sfork.out"; 
    #open STDERR, $redir, "/home/lafon/sandbox/sfork.err";
    open(STDOUT, $redir, "/home/lafon/sandbox/sfork.out") or die "Can't redirect STDOUT: $!";
    open(STDERR, $redir, "/home/lafon/sandbox/sfork.err") or die "Can't redirect STDERR: $!";
    exec "$kidcmd"  or logit("$$ couldn't exec [ $kidcmd ]: $!");
} else {         # parent's code continued
    print MYLOG "forked $kid [ $kidcmd ]\n";
    my $done=0;
    while (!$done) {
        usleep(int(300000));
        my $t0 = [gettimeofday];
        while (($dcd = waitpid(-1, &WNOHANG)) > 0) {
            my $dcdRC = $?; # default, see below each case
            my $dcdmsg = '';
            if ($? == -1) { $dcdmsg = sprintf (" failed to execute: $!"); }
            elsif ($? & 127) {
                $dcdmsg = sprintf (" %s %d %s coredump","$dcd died with signal",($? & 127),($? & 128) ? '' : 'no');
            }
            else {
                $dcdRC = $? >> 8;
                $dcdmsg = sprintf (" %s %d","$dcd exited with ", $dcdRC);
            }

            #print "reaper: kid($dcd) ?=$?, dcdRC=$dcdRC\n" ;
            $done=1;
        }
    }
    print MYLOG "reaper done.\n";
}
close MYLOG;

