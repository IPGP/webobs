#!/usr/bin/perl 
#
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use File::Find;
use WebObs::Config;

my $cgi = new CGI;
my $mfile = $cgi->param('mfile') // '';

print $cgi->header(-type=>'text/plain',-charset=>'utf-8');
if ($mfile) {
	my $fname = "$WEBOBS{ROOT_CODE}/matlab/$mfile";
	print STDERR "** mfile = $fname **\n";
	if (-f $fname) {
		my @m = qx(sed -n '/^function/,/^\$/p' $fname);
		print join('',@m);
	}
}

