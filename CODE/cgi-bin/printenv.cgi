#!/usr/bin/perl

print "Content-type: text/html\n\n";
print "<pre>\n";

foreach $key (sort keys(%ENV)) {
    print "$key = $ENV{$key}<p>";
}
print "</pre>\n";
