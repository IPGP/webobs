#!/usr/bin/perl

use strict;
use warnings;

my ($p, @rest) = @ARGV;
my $parent = getppid;
print time . " entered jobtester $$ from $parent\n";
print time . " $$ args are ".join(' ',@ARGV)."\n";
print time . " $$ now sleeping for $p seconds\n";
sleep($p);
exit $p;
