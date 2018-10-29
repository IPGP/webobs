#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use WebObs::DBForm;
use Data::Dumper;

# test data presented as HTML querystring(s):
my $q1 = {  # the common IDS fields
			ts1 => '2014-07-08',   ts2 => '2014-07-04 15:55:20',
			node => 'SITE01', comment => 'blabla', hidden => 'N', 
			tsupd => '2014-07-09 09:30:00', userupd => 'DL' ,
			# the specific DATA fields
			val1 => 'val1 q1', val2 => 13, val3 => 0.5
		 };

my $q2 = {  # the common IDS fields
			ts1 => '2014-07',   ts2 => '2014-07-04 15:56',
			node => 'SITE02', comment => 'gnagna', hidden => 'N', 
			tsupd => '2014-07-09 09:31:00', userupd => '!' ,
			# the specific DATA fields
			val1 => 'val1q2', val2 => 11, val3 => 0.66
		 };

my $q3 = {  # the common IDS fields
			ts1 => '2014-07-09 11:11:11', ts2 => '2014-07-04 15:59:20',
			node => 'SITE01', comment => 'encore blabla', hidden => 'N', 
			tsupd => '2014-07-09 09:32:00', userupd => 'DL' ,
			# the specific DATA fields
			val1 => 'lorem ipsum', val2 => 12, val3 => 0.75
		 };

my $F = new WebObs::DBForm('DBF');
print $F->dump;

