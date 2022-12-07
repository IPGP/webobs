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
		
		## common root path
		my $root = '/geo:GeodesyML/geo:siteLog';
		
		###### Receiver
		## root path for the Receiver
		my $root_rec = "$root/geo:gnssReceiver/geo:GnssReceiver";
		## XML id of the last Receiver
		my @IdsRec = findvalues("$root_rec/\@gml:id=",\@xml2);
		my $id_rec = @IdsRec[-1];
		$id_rec =~ s/^\s+|\s+$//g ; # very important, id must be trimmed
		## Get Last receiver Node
		my @Rec = findnode($root_rec,"/\@gml:id=$id_rec",\@xml2);
		## Get useful values
		$gml{rec_model}   = findvalue('/geo:igsModelCode=',\@Rec);
		$gml{rec_serialn} = findvalue('/geo:manufacturerSerialNumber=',\@Rec);
		$gml{rec_vfirm}   = findvalue('/geo:firmwareVersion=',\@Rec);
		$gml{rec_satsys}  = findvalue('/geo:satelliteSystem=',\@Rec);
		
		###### Antenna
		## root path for the Antenna
		my $root_ant = "$root/geo:gnssAntenna/geo:GnssAntenna";
		## XML id of the last Antenna
		my @IdsRec = findvalues("$root_rec/\@gml:id=",\@xml2);
		my $id_rec = @IdsRec[-1];
		$id_rec =~ s/^\s+|\s+$//g ; # very important, id must be trimmed
		## Get Last receiver Node
		my @Rec = findnode($root_rec,"/\@gml:id=$id_rec",\@xml2);
		## Get useful values
		$gml{rec_model}   = findvalue('/geo:igsModelCode=',\@Rec);
		$gml{rec_serialn} = findvalue('/geo:manufacturerSerialNumber=',\@Rec);
		$gml{rec_vfirm}   = findvalue('/geo:firmwareVersion=',\@Rec);
		$gml{rec_satsys}  = findvalue('/geo:satelliteSystem=',\@Rec);
		
		
		#print @Rec;

		my $domes = findvalue("$root/geo:siteIdentification/geo:iersDOMESNumber",\@xml2);

		print $gml{rec_model};
		
		#my @Rec   = findvalues("$root_rec",\@xml2);
		#print $#Rec +1;
	}

	return @xml2;
	
}

my $p="/home/sakic/Downloads/ILAM00MTQ.xml";
gmlorigin($p);

1;
