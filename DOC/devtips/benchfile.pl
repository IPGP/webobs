#!perl
use strict;
use warnings;

use File::Slurp qw(slurp);
use Tie::File;
use Benchmark qw(:all);
use vars qw($scalar);

#chomp( my $file = `perldoc -l perlfaq5` );
$file = '/home/didier/wobs/DATA/HEBDO.DAT';
print "file is $file\n";
$scalar = slurp( $file );

cmpthese( 1000, {
    'Chas.'          => \&chas,
    'Schwern'        => \&schwern,
    'brian'          => \&brian,
    'Chas. modified' => \&chas_modified,
    'Chas. sane'     => \&chas_sane,
    'drewk'          => \&drewk,
    'drewk2'         => \&drewk2,
    });

sub drewk {
   my @arr = split(/\n/, $scalar);
   my @found;
   for(my $i=0; $i<=$#arr; $i+=10){
    #  print "drewk[$i] $arr[$i]\n";
      push @found, $arr[$i];
    }
}
sub drewk2 {
   my $i=0;
   my @found;
   foreach(split(/\n/, $scalar)) {
      next if $i++ % 10;
#      print "drewk2[$i] $_\n";
      push @found, $_;
   }
}
sub schwern {
    my $count = 0;
    my @found;
    while($scalar =~ /\G(.*)\n/g) {
        next if $count++ % 10 != 0;
#       print "schwern[$count] $1\n";
        push @found, $1;
        }
    }

sub chas {
    open my $fh, "<", \$scalar;

    tie my @lines, "Tie::File", $fh
        or die "could not tie in-memory file: $!";

    my $i = 0;
    my @found = ();
    while (defined $lines[$i]) {
        # print "chas[$i]: $lines[$i]\n";
        push @found, $lines[$i];
        } continue {
            $i += 10;
        }   
    }

sub chas_modified {
    open my $fh, "<", \$scalar;

    tie my @lines, "Tie::File", $fh
        or die "could not tie in-memory file: $!";

    my $highest_multiple = int( $#lines / 10 ) ;
    my @found = @lines[ map { $_ * 10  - ($_?1:0) } 0 .. $highest_multiple ]; 
    #print join "\n", @found;
    }

sub chas_sane {
    open my $fh, "<", \$scalar;

    my @found;
    while (my $line = <$fh>) {
        if ($. == 1 or not $. % 10) {
            #print "chas_sane[$.] $line";
            push @found, $_;
            }
        }
    }

sub brian {
    open my $fh, '<', \$scalar;
    my @found = scalar <$fh>;
    while( <$fh> ) {
        next if $. % 10;
        #print "brian[$.] $_";
        push @found, $_;
        }
    }
