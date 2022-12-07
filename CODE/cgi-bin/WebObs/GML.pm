#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# GML.pm
# ------
# Perl module to import GeodesyML files
#
# Authors: Pierre Sakic <sakic@ipgp.fr>
# Created: 2022-12-07
#--------------------------------------------------------------
use strict;
use WebObs::XML2;

#--------------------------------------------------------------------------------------------------------------------------------------
# qmlvalues: returns origin and magmitude preferred values from XML2 arrayd
sub gmlorigin {
	my $file = $_[0];
	my %gml;
	my @xml2;
	
	if (-e $file) {
#		my @xml2 = qx($WEBOBS{XML2_PRGM} < $file);

		my @xml2 = qx(/usr/bin/xml2 < $file);
		my $root = '/geo:GeodesyML/geo:siteLog';
		my $root_rec = "$root/geo:gnssReceiver/geo:GnssReceiver";
		my $domes = findvalue("$root/geo:siteIdentification/geo:iersDOMESNumber",\@xml2);
		
		
		my @IdsRec = findvalues('/geo:GeodesyML/geo:siteLog/geo:gnssReceiver/geo:GnssReceiver/@gml:id=',\@xml2);
		my $id_rec = @IdsRec[-1];
		my @Rec = findnode('/geo:GeodesyML/geo:siteLog/geo:gnssReceiver/geo:GnssReceiver',"/\@gml:id=gnss-receiver-6011908e8ef7b",\@xml2);
		
		my $rec_satsys = findvalue('/geo:satelliteSystem=',\@Rec);
		my $rec_satsys = findvalue('/geo:satelliteSystem=',\@Rec);
		
		print $id_rec;		
		print $satsys;
		print $id_rec;
		print @Rec;
		
		#my @Rec   = findvalues("$root_rec",\@xml2);
		#print $#Rec +1;
	}

	return @xml2;
	
}

my $p="/home/sakic/Downloads/ILAM00MTQ.xml";
gmlorigin($p);

1;
