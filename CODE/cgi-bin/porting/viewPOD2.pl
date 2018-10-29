#!/usr/bin/perl 
#
#
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use File::Find;
use Pod::Html;

my $cgi = new CGI;
my $pod = $cgi->param('pod') || '';

if ($pod) {
    my $fname = scan4($pod);
	if ($fname) {
		print "Content-type: text/html\n\n";
    	pod2html("--quiet","--css=/$WEBOBS{FILE_HTML_CSS}","--infile=$fname");
 	}
}

sub scan4 {
	my $what = $_[0];
    if ( -e $what ) { return $what }
    for (@INC) {
        if( -e "$_/$what.pm" ) { return "$_/$what.pm" }
        if( -e "$_/$what.pod") { return "$_/$what.pod" }
    }
    return '';
}

