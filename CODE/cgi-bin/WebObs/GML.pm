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
	my %gmlrec;
	my %gmlant;
	my @xml2;
	
#	my @xml2 = qx($WEBOBS{XML2_PRGM} < $file);
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
	#### Get useful values
	## Sitelog exemple
	#3.1  Receiver Type            : TRIMBLE NETR9
     #Satellite System         : GPS+GLO
     #Serial Number            : 5112K74575
     #Firmware Version         : 4.22
     #Elevation Cutoff Setting : 10 deg
     #Date Installed           : 2012-09-25T00:00Z
     #Date Removed             : 2019-08-02T00:00Z
     #Temperature Stabiliz.    : none
     #Additional Information   : Data availability : http://volobsis.ipgp.fr
     
	$gmlrec{model}  = findvalue('/geo:igsModelCode=',\@Rec);
	$gmlrec{satsys} = findvalue('/geo:satelliteSystem=',\@Rec);
	$gmlrec{sn}     = findvalue('/geo:manufacturerSerialNumber=',\@Rec);
	$gmlrec{vfirm}  = findvalue('/geo:firmwareVersion=',\@Rec);
	$gmlrec{cutoff} = findvalue('/geo:firmwareVersion=',\@Rec);
	$gmlrec{dinsta} = findvalue('/geo:firmwareVersion=',\@Rec);
	$gmlrec{dremov} = findvalue('/geo:firmwareVersion=',\@Rec);

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
	#### Get useful values
	## Sitelog exemple
	#4.1  Antenna Type             : TRM55971.00     NONE
     #Serial Number            : 1441112028
     #Antenna Reference Point  : BAM
     #Marker->ARP Up Ecc. (m)  :   0.0100
     #Marker->ARP North Ecc(m) :   0.0000
     #Marker->ARP East Ecc(m)  :   0.0000
     #Alignment from True N    : 0 deg
     #Antenna Radome Type      : NONE
     #Radome Serial Number     : 
     #Antenna Cable Type       : Coaxial TNC-TNC - Trimble LMR400
     #Antenna Cable Length     : 30 m
     #Date Installed           : 2012-09-25T00:00Z
     #Date Removed             : 2019-07-22T15:00Z
     #Additional Information   : (multiple lines)

	$gmlant{model}  = findvalue('/geo:igsModelCode=',\@Ant);
	$gmlant{sn}     = findvalue('/geo:manufacturerSerialNumber=',\@Ant);
	$gmlant{radome} = findvalue('/geo:igsModelCode=',\@Ant);
	$gmlant{alignN} = findvalue('/geo:igsModelCode=',\@Ant);
	$gmlant{lcable} = findvalue('/geo:igsModelCode=',\@Ant);
	$gmlrec{dinsta} = findvalue('/geo:firmwareVersion=',\@Rec);
	$gmlrec{dremov} = findvalue('/geo:firmwareVersion=',\@Rec);
			
	####### Misc Info
	my $domes = findvalue("$root/geo:siteIdentification/geo:iersDOMESNumber",\@xml2);
	
	## backslash because we need to output a reference
	# https://www.oreilly.com/library/view/perl-cookbook/1565922433/ch10s10.html
	return (\%gmlrec, \%gmlant);
}

sub gml2txt {
   my  $gmlfile = $_[0];
   my  $featsection = $_[1];

	## dollar sign ($) because we need to get references
	# https://www.oreilly.com/library/view/perl-cookbook/1565922433/ch10s10.html
	my ($gmlrec, $gmlant) = gmlread($gmlfile);

	my @outlines ;

	if ( $featsection == "rec" ) {
		push(@outlines,$gmlfile);
		my $recmodel = $gmlrec->{'model'};
		push(@outlines,"model: $recmodel \n");
		push(@outlines,"Serial number: $gmlrec->{'sn'}\n");
	}
	return @outlines;
	#### !!!! EXCEPTION HERE IF FILE NOT FOUND GMLFILE!!!!
	#### !!!! EXCEPTION HERE IF $featsection NOT FOUND !!!!


}

#my $p="/home/sakic/Downloads/ILAM00MTQ.xml";
#gml2txt($p,"rec");


#my $p="/home/sakic/Downloads/ILAM00MTQ.xml";
#(my %gmlant, my %gmlrec) = gmlread($p);
#print "\n";
#print "***** rec ********\n";
#print %gmlrec;
#print "\n";
#print "***** ant ********\n";
#print %gmlant;

1;
