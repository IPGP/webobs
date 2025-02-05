#!/usr/bin/perl -w

=head1 NAME

postFormData.pl

=head1 SYNOPSIS

http://..../postFormData.pl

=head1 DESCRIPTION

Compress form data (images, shapesfiles, ...)

=cut

use strict;
use warnings;
use CGI;
use IO::Compress::Zip qw(zip $ZipError);
use POSIX qw/strftime/;
my $cgi = new CGI;
$CGI::POST_MAX = 1024 * 1000 * 100;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Grids;
use WebObs::i18n;

# ---- get data from formGENFORM.pl
my $all = $cgi->param("all") || "";
my $csv  = $cgi->param("csv");
my $form = $cgi->param("form");
if ( $form eq "" ) {
    print CGI::header();
    print "No valid form found !\n";
    exit;
}

my $time     = strftime "%Y%m%d_%H%M%S", localtime time;
my $filename = $form . "_" . $time;
my $formdocs = $GRIDS{SPATH_FORMDOCS} || "FORMDOCS";
my $root     = "$WEBOBS{ROOT_DATA}/$formdocs";
my $source   = "$root/$form";
my $dest     = "/tmp/$filename.zip";
my $csvfile  = "/tmp/$filename.csv";

# ---- compress function
sub compressFormFiles {
    my $source = shift;
    my $dest   = shift;
    if ( $all ) {
        zip [ <$source/*/*/*.*>, $csvfile ] => $dest, FilterName => sub { s[(^$source/|tmp/)][] };
    } else {
        zip [ $csvfile ] => $dest, FilterName => sub { s[(^$source/|tmp/)][] };
    }
}

# ---- response header
print $cgi->header(
    -type       => "application/zip",
    -attachment => $filename . ".zip",
);

# ---- create csv file
open( CSVFILE, ">", $csvfile ) || die "problem opening $csvfile \n";
print CSVFILE $csv;
close(CSVFILE);

# ---- create archive
compressFormFiles( $source, $dest, $all ) or die "zip failed: $ZipError\n";

# ---- append compressed files to the response
open FILE, "<", $dest or die "can't open : $!";
binmode FILE;
while (<FILE>) {
    print $_;
}
close FILE;

# ---- cleanup
unlink $dest;
unlink $csvfile;

