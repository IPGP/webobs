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
sub gmlread {
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
		#print $id_rec;
		## Get Last receiver Node
		my @Rec = findnodes($root_rec,"/\@gml:id=",$id_rec,\@xml2);
		#print @Rec;
		## Get useful values
		$gml{rec_model}  = findvalue('/geo:igsModelCode=',\@Rec);
		$gml{rec_sn}     = findvalue('/geo:manufacturerSerialNumber=',\@Rec);
		$gml{rec_vfirm}  = findvalue('/geo:firmwareVersion=',\@Rec);
		$gml{rec_satsys} = findvalue('/geo:satelliteSystem=',\@Rec);
		
		###### Antenna
		## root path for the Antenna
		my $root_ant = "$root/geo:gnssAntenna/geo:GnssAntenna";
		## XML id of the last Antenna
		my @IdsAnt = findvalues("$root_ant/\@gml:id=",\@xml2);
		my $id_ant = @IdsAnt[-1];
		$id_ant =~ s/^\s+|\s+$//g ; # very important, id must be trimmed
		## Get Last Antenna Node
		my @Ant = findnodes($root_ant,"/\@gml:id=",$id_ant,\@xml2);
		#print @Ant,@IdsAnt;
		## Get useful values
		$gml{ant_model}  = findvalue('/geo:igsModelCode=',\@Ant);
		$gml{ant_sn}     = findvalue('/geo:manufacturerSerialNumber=',\@Ant);
		
		
		####### Misc Info
		my $domes = findvalue("$root/geo:siteIdentification/geo:iersDOMESNumber",\@xml2);

		print %gml;
	}

	return %gml;
	
}

my $p="/home/sakic/Downloads/ILAM00MTQ.xml";
gmlread($p);

1;
