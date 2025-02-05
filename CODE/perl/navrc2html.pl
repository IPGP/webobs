#!/usr/bin/perl
#
# WebObs helper
# quick and dirty conversion from menunav.rc to menunav.html
#
use strict;
use warnings;

chomp(my @menu = <>);

my $l1 = my $l2 = 0;

for (@menu) {
    next if(/^[ ]*#/ || /^$/);
    my ($titre,$lien)=split(/\|/,$_);

    #	$lien =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g ;
    #	my $xtrn = ($lien =~ m/http.?:\/\//) ? " externe ": "";
    if (substr($titre,0,1) eq "+" || substr($titre,0,1) eq "!") {
        if ($l2==1) { print "    </ul>\n"; $l2 = 0; }
        if ($l1==1) { print "</li>\n"; }
        $l1 = 1;
        if (substr($titre,0,1) eq "!") { print "*" }
        print "<li><a href=".(defined($lien)?"\"$lien\"":"\"#\"").">".substr($titre,1)."</a>\n";
        next;
    }
    if ($l2==0) { print "    <ul>\n"; $l2 = 1;}
    if ( substr($titre,0,1) eq "*" ){ print "*" ; $titre = substr($titre,1) }
    if ($l2==1) { print "    ";}
    print "    <li><a href=".(defined($lien)?"\"$lien\"":"\"#\"").">$titre</a></li>\n";
}
if ($l2==1) { print "    </ul>\n"; }
if ($l1==1) { print "</li>\n"; }

exit

