use strict;
use warnings;

my $fichier_source = 'source.csv';
my $fichier_dest   = 'nouveau.csv';

open my $source, '<', $fichier_source or die "Impossible d'ouvrir $fichier_source: $!";
open my $dest, '>', $fichier_dest or die "Impossible d'ouvrir $fichier_dest: $!";

my $en_tete = "Colonne1,Colonne2\n";
print $dest $en_tete;

#my $ligne = <$source>;

# Copie source vers dest en mode binaire
my $buffer;
while (read($source, $buffer, 4096)) {
    print $dest $buffer;
}

close $source;
close $dest;

