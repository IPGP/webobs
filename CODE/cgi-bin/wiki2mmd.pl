#!/usr/bin/perl 

=head1 NAME

wiki2mmd.pl 

=head1 SYNOPSIS

wiki2mmd.pl wikifile

=head1 DESCRIPTION

Utility to convert a WebObs legacy wiki-coded file to MultiMarkdown-coded file.
Converted file is printed to STDOUT.

=cut

use strict;
use warnings;
use File::Basename;
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

use WebObs::Config;
use WebObs::Wiki;

my $mmd = $WEBOBS{WIKI_MMD} || 'YES';
if ($mmd eq 'NO') {
	print "Can't convert, configuration says WIKI_MMD|NO\n"; exit;
}


my $file   = $ARGV[0] || "";
my $txt    = "";
my $titre  = "";
my @lines;

if ($file ne "") {
	if (!open(FILE, "<$file")) { print "Couldn't read $file\n"; exit; }
	@lines = <FILE>;
	close FILE;
} else { print "No filename specified\n"; exit; }

# convert if needed, print to stdout
#
$lines[0] =~ /^TITRE.*\n/ and $titre = $lines[0] and shift(@lines);
($txt, my @meta) = WebObs::Wiki::stripMDmetadata(join("",@lines));
if (scalar(@meta) == 0) { 
	$txt = wiki2MMD($txt);
	print($titre) if ($titre ne ""); 
	print "WebObs: converted with wiki2mmd.pl\n\n$txt\n";
} else { 
	print "$file already MMD\n" 
} 
exit;

