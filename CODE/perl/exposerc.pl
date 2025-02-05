#!/usr/bin/perl

=head1 NAME

exposerc.pl 

=head1 SYNOPSIS

perl exposerc.pl {sep {keyPrefix {key2rc}}}

=head1 DESCRIPTION

To be called from a bash script that needs to 'expose' the WEBOBS.rc variables 
or the variables from the file pointed to by the WEBOBS.rc's key2rc variable (one level indirection).
'exposed' variables are returned as '{keyPrefix}Key{sep}Value'

I<sep> is the key value separator, defaults to '>'. 
I<keyPrefix> string is prefixed to each key, defaults to 'WO__'.
I<key2rc> is the key from WEBOBS.rc that is supposed to point to the actual file that we 
want the keys exposed. 

example from a bash script exporting WEBOBS.rc variables following WEBOBS' readCfg rules: 

    oIFS=${IFS}; IFS=$'\n'
    LEXP=($(perl /etc/webobs.d/../CODE/cgi-bin/exposerc.pl '=' 'WO__'))
    for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done
    IFS=${oIFS}

example from a bash script exportng $WEBOBS{CONF_SCHEDULER} file's variables : 

    oIFS=${IFS}; IFS=$'\n'
    LEXP=($(perl /etc/webobs.d/../CODE/cgi-bin/exposerc.pl '=' 'SC__' 'CONF_SCHEDULER'))
    for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done
    IFS=${oIFS}

=cut

use strict;
use FindBin;
use lib $FindBin::Bin;
use WebObs::Config;

my ($sep,$prefix,$ptr) = @ARGV;
$sep    ||= '>';    $sep    =~ s/^\s+|\s+$//g ;
$prefix ||= 'WO__'; $prefix =~ s/^\s+|\s+$//g ;
$ptr    ||= '';     $ptr    =~ s/^\s+|\s+$//g ;

if ( $ptr eq '' ) {
    for (keys(%WEBOBS)) {
        printf ("%s%s%s%s\n", $prefix, $_, $sep, $WEBOBS{$_});

        #[XB-r1240:] printf ("%s%s%s'%s'\n", $prefix, $_, $sep, $WEBOBS{$_}); 
    }
} else {
    if (defined($WEBOBS{$ptr})) {
        my %TGT = readCfg($WEBOBS{$ptr});
        for (keys(%TGT)) {
            printf ("%s%s%s%s\n", $prefix, $_, $sep, $TGT{$_}) ;

            #[XB-r1240:] printf ("%s%s%s'%s'\n", $prefix, $_, $sep, $TGT{$_}) ;
        }
    }
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

