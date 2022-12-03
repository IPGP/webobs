#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# XML2.pm
# ------
# Perl module to parse XML2 strings
#
#
# Author: François Beauducel <beauducel@ipgp.fr>
# Created: 2012-04-30
# Updated: 2022-11-09
#--------------------------------------------------------------
use strict;

our(@ISA, @EXPORT, $VERSION);
require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(findvalue findvalues findnode);
$VERSION    = "1.00";

#--------------------------------------------------------------------------------------------------------------------------------------
# findvalues: search for particular tag and returns array of all selected data
sub findvalues {
        my ($s,$xml2) = @_;

        my @tab = grep(/^$s/,@$xml2);
        if (@tab) {
                foreach (@tab) { s/^$s//g; }
                return @tab;
        } else {
                return;
        }
}


#--------------------------------------------------------------------------------------------------------------------------------------
# findvalue: search for particular tag and returns the first selected data
sub findvalue {
        my ($s,$xml2) = @_;

        my @tab = grep(/^$s/,@$xml2);
        if (@tab) {
                my $val = $tab[0];
                $val =~ s/^$s//g;
                $val =~ s/\n//g;
                return $val;
        } else {
                return "";
        }
}


#--------------------------------------------------------------------------------------------------------------------------------------
# findnode: search for a particular array of tags and returns the first selected array
sub findnode {
        my ($root,$s,$xml2) = @_;

	$s =~ s/\?/\\\?/g;
	$s =~ s/\./\\\./g;
        my @tab = grep(/^$root/,@$xml2);
        if (@tab) {
                foreach (@tab) {
			s/^$root//g;
			s/\n//g;
		}
                @tab = grep(/$s/,split(/\|\|/,join('|',@tab)));
                return split(/\|/,$tab[0]);
        } else {
                return;
        }
}

1;
