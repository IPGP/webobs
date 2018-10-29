#!/usr/bin/perl -I../cgi-bin
use strict;
use WebObs::Config;
for (keys(%WEBOBS)) { print "export WEBOBS_$_=\"$WEBOBS{$_}\"\n" }

