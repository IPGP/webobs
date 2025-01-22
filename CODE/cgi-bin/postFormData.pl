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

# get data from formGENFORM.pl
my $form = $cgi->param('form');

print $cgi->header(
    -type => 'application/zip',
    -attachment => 'test.zip',
);

my $root = "$WEBOBS{ROOT_DATA}/$GRIDS{SPATH_FORMDOCS}";
my $dest = "/tmp/$form.zip";
my $source = "$root/$form";

compressFormFiles($source, $dest) or die "zip failed: $ZipError\n";
open FILE, '<', $dest or die "can't open : $!";
binmode FILE;
while (<FILE>){
    print $_;
}
close FILE;
unlink $dest;


# ---- local functions
#

sub compressFormFiles {
    my $source = shift;
    my $dest = shift;
    zip [ <$source/*/*/*.*> ] => $dest, FilterName => sub { s[^$source/][] } ;
}

