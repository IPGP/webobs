#!/usr/bin/perl 
#
#
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use File::Find;
use Pod::Html;
use WebObs::Config;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Users qw(clientIsValid);

my $cgi = new CGI;

# --- ends here if the client is not valid
if ( !clientIsValid ) {
    die "$__{'die_client_not_valid'}";
}

my $pod = $cgi->param('pod') // '';
if ($pod) {
    my $fname = scan4($pod);
    if ($fname) {

        #print "Content-type: text/html\n\n";
        print $cgi->header(-charset=>'utf-8');
        mkdir("$WEBOBS{PATH_TMP_APACHE}/viewpod");  # just in case
        chdir("$WEBOBS{PATH_TMP_APACHE}/viewpod");
        pod2html("--quiet","--css=/css/viewpod.css","--infile=$fname");
    }
}

sub scan4 {
    my $what = $_[0];
    my $wd = qx(pwd); chomp($wd);
    if ( -e $what ) { return "$wd/$what" }
    for (@INC) {
        if( -e "$_/$what.pm" ) { return "$_/$what.pm" }
        if( -e "$_/$what.pod") { return "$_/$what.pod" }
    }
    return '';
}

