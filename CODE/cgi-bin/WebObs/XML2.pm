package WebObs::XML2;
#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# XML2.pm
# ------
# Perl module to parse XML2 strings
#
#
# Author: François Beauducel <beauducel@ipgp.fr>
# Created: 2012-04-30
# Updated: 2023-08-24
#--------------------------------------------------------------
use strict;


our(@ISA, @EXPORT, $VERSION);
require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(findvalue findvalues findnode findnodes);
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


#--------------------------------------------------------------------------------------------------------------------------------------
# findnodes: search for a particular array of tags and returns the wished one
# Slightly different from findnode designed for QML
# This one is designed for GeodesyML, but is should be polyvalent
# P Sakic - 2022-12-07
# Usage exemple:
# my @Rec = findnodes($root_rec,"/\@gml:id=","gnss-receiver-6011908e8ef7b",\@xml2);


sub findnodes {
    my ($root,$att_name,$att_val,$xml2) = @_;

	# substitute the question marks/dots with escaped equivalent signs (?)
	$att_name =~ s/\?/\\\?/g;
	$att_name =~ s/\./\\\./g;
	$att_val  =~ s/\?/\\\?/g;
	$att_val  =~ s/\./\\\./g;
	
		# we grep everything starting with the root
        my @tab = grep(/^$root/,@$xml2);
        if (@tab) {
				#for each line of the table of in the grepped elements:
				# clean the root prefix 
				# clean the \n 
				# add a double bar || before each block ID (att_name)
				# this is the trick to separate each block
                foreach (@tab) {
					s/^$root//g;
					s/\n//g;
					s/$att_name/\|\|$att_name/g;					
				}
				
				# create big strings: each field is separated with |, 
				# and each block separated with ||
				# we split wrt ||, and grep the right block ID (att_val)
				@tab = grep(/$att_val/,split(/\|\|/,join('|',@tab)));
				#print @tab; 
				# debug print above, make sure we have the correct block
				
				# we recreate a correct array, one field per element
                return split(/\|/,$tab[0]); #NB after the previous grep, @tab is a singleton (normally...) 
        } else {
                return;
        }
}


1;
