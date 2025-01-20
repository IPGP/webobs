#!/usr/bin/perl 
#
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use File::Find;
use WebObs::Config;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Users qw(clientIsValid);

my $cgi = new CGI;

# --- ends here if the client is not valid
if ( !clientIsValid ) {
    die "$__{'die_client_not_valid'}";
}

my $mfile = $cgi->param('mfile') // '';
print $cgi->header(-type=>'text/plain',-charset=>'utf-8');
if ($mfile) {
    my $fname = "$WEBOBS{ROOT_CODE}/matlab/$mfile";
    print STDERR "** mfile = $fname **\n";
    if (-f $fname) {
        my @m = qx(sed -n '/^function/,/^[\s\r]*\$/p' $fname);
        print join('',@m);
    }
}

