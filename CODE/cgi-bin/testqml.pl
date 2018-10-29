#!/usr/bin/perl -w
use strict;
use QML;

my %QML = qmlorigin('/home/www/webobs-datatest/continu/sismo/sc3_events/2012/04/25/ovpf2012idst/ovpf2012idst.last.xml');

foreach(keys(%QML)) {
	print "$_ = $QML{$_}\n";
}
