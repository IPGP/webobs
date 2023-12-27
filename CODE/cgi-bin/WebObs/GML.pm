#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# GML.pm
# ------
# Perl module to import GeodesyML files
#
# Authors: Pierre Sakic <sakic@ipgp.fr>
# Created: 2022-12-07
#--------------------------------------------------------------s
use strict;
use WebObs::XML2;
#--------------------------------------------------------------
sub gmlarray2nodearray {
	#
	# Convert **reference** XML/GeodesyML array 
	# (imported with xml2 buildin fct)
	# to
	# a "Node Array" i.e. one device change
	# OR
	# a list of Node Arrays if 'all' is used as index
	
	### Inputs
	my @GmlArray = @{$_[0]}; # an **reference** GeodesyML array parsed with XML2 Linux bin
	my $nodename = $_[1]; # rec, ant, etc....
	my $idx      = $_[2]; # node index, we recommend -1 (last one per default)
	                      # OR
	                      # 'all' to get all the nodes
	my $root ;
	my $root0 ;
	
	$root0 = '/geo:GeodesyML/geo:siteLog';

	if ( $nodename eq "rec" ) {
		$root = "$root0/geo:gnssReceiver/geo:GnssReceiver";
	} elsif ( $nodename eq "ant" ) {
		$root = "$root0/geo:gnssAntenna/geo:GnssAntenna";
	} else { 
		die ("nodename not defined !!") 
	}

	## get all ids for all nodes
	my @Ids = findvalues("$root/\@gml:id=",\@GmlArray);

	## Case 1: we want all nodes (idx == "all")
	if ( $idx eq "all" ){ 
		my  @NodesList;
		my $id;
		foreach $id (@Ids){
			$id =~ s/^\s+|\s+$//g ; # very important, id must be trimmed
			## Get the Node we want
			my @Node = findnodes($root,"/\@gml:id=",$id,\@GmlArray);
			## stack it
			push(@NodesList,[ @Node ]); # [] are very important, to force Node as a list
			}
		return @NodesList;

	## Case 2: we want a specific node (idx € int)	
	} else {             
		## find id of the node we want
		my $id = @Ids[$idx];
		$id =~ s/^\s+|\s+$//g ; # very important, id must be trimmed
		## Get the Node we want
		my @Node = findnodes($root,"/\@gml:id=",$id,\@GmlArray);
		return @Node;
	}	
}

sub rec_nodearray2hash {
	#
	# Convert a **reference** Receiver Node Array 
	# (created with gmlarray2nodearray)
	# to
	# a hash (i.e. a dict-like)
	#
	my @Rec = @{$_[0]};
	my %hashrec;
	     
	$hashrec{model}  = findvalue('/geo:igsModelCode=',\@Rec);
	$hashrec{satsys} = findvalue('/geo:satelliteSystem=',\@Rec);
	$hashrec{sn}     = findvalue('/geo:manufacturerSerialNumber=',\@Rec);
	$hashrec{vfirm}  = findvalue('/geo:firmwareVersion=',\@Rec);
	$hashrec{cutoff} = findvalue('/geo:elevationCutoffSetting=',\@Rec);
	$hashrec{dinsta} = findvalue('/geo:dateInstalled=',\@Rec);
	$hashrec{dremov} = findvalue('/geo:dateRemoved=',\@Rec);
	
	return %hashrec;
}

sub ant_nodearray2hash {
	#
	# Convert a **reference** Antenna Node Array
	# (created with gmlarray2nodearray)
	# to
	# a hash (i.e. a dict-like)
	#
	my @Ant = @{$_[0]};
	my %hashant;
    
	$hashant{model}  = findvalue('/geo:igsModelCode=',\@Ant);
	$hashant{sn}     = findvalue('/geo:manufacturerSerialNumber=',\@Ant);
	$hashant{radome} = findvalue('/geo:antennaRadomeType=',\@Ant);
	$hashant{alignN} = findvalue('/geo:alignmentFromTrueNorth=',\@Ant);
	$hashant{lcable} = findvalue('/geo:antennaCableLength=',\@Ant);
	$hashant{dinsta} = findvalue('/geo:dateInstalled=',\@Ant);
	$hashant{dremov} = findvalue('/geo:dateRemoved=',\@Ant);
	
	return %hashant;
}

sub gmlread_feature {
	#
	# Wrapper function  
	#
	# Convert a XML/GeodesyML file
	# to
	# **reference** hashes (rec, ant, misc) 
	# for the CURRENT instrumentation
	#
	my $file = $_[0];
	my %hashrec;
	my %hashant;
	my %hashmisc;
	my @Gml;
	
	if ( not -f $file)
	{
		die "$file not found"
	}
	
	#### HARDCODED XML2
#	my @Gml = qx($WEBOBS{XML2_PRGM} < $file);
	my @Gml = qx(/usr/bin/xml2 < $file);

	###### Receiver
	my @Rec = gmlarray2nodearray(\@Gml,"rec",-1);
	%hashrec = rec_nodearray2hash(\@Rec);

	###### Antenna
	my @Ant = gmlarray2nodearray(\@Gml,"ant",-1);
	%hashant = ant_nodearray2hash(\@Ant);
			
	####### Misc Info
	## common root path
	my $rootdomes = '/geo:GeodesyML/geo:siteLog/geo:siteIdentification/geo:iersDOMESNumber';
	$hashmisc{'domes'} = findvalue("$rootdomes",\@Gml);
	
	## backslash because we need to output a reference
	# https://www.oreilly.com/library/view/perl-cookbook/1565922433/ch10s10.html
	return (\%hashrec, \%hashant, \%hashmisc);
}

sub gml2mmdfeature {
	#
	# Wrapper function  
	#
	# Convert a XML/GeodesyML file
	# to
	# a WebObs markdown feature text for the CURRENT instrumentation
	#
    my  $gmlfile = $_[0];
    my  $featsection = $_[1];
   

	if ( not -f $gmlfile)
	{
		die "$gmlfile not found"
	}

	## dollar sign ($) because we need to get references
	# https://www.oreilly.com/library/view/perl-cookbook/1565922433/ch10s10.html
	my ($hashrec, $hashant, $hashmisc) = gmlread_feature($gmlfile);

	my @outlines ;

	# here we need $hashrec->{'blabla'} and not simply $hashrec{'blabla'}
	# because $hashrec is a reference of a hash
	# abd not a hash it self
	if ( $featsection eq "gnssrec" ) {
		push(@outlines,"//Model//: $hashrec->{'model'} \n");
		push(@outlines,"Satellite system: $hashrec->{'satsys'}\n");
		push(@outlines,"Serial number: $hashrec->{'sn'}\n");
		push(@outlines,"Firmware version: $hashrec->{'vfirm'} \n");
		push(@outlines,"Date installed: $hashrec->{'dinsta'}\n");
		push(@outlines,"Date removed: $hashrec->{'dremov'}\n");
	} elsif ( $featsection eq "gnssant" ) {
		push(@outlines,"Model: $hashant->{'model'} \n");
		push(@outlines,"Radome: $hashant->{'radome'} \n");
		push(@outlines,"Serial number: $hashant->{'sn'}\n");
		push(@outlines,"Alignment from North: $hashant->{'alignN'} \n");
		push(@outlines,"Cable length (m): $hashant->{'lcable'} \n");
		push(@outlines,"Date installed: $hashant->{'dinsta'}\n");
		push(@outlines,"Date removed: $hashant->{'dremov'}\n");		
	}

	return @outlines;
	#### !!!! EXCEPTION HERE IF FILE NOT FOUND GMLFILE!!!!
	#### !!!! EXCEPTION HERE IF $featsection NOT FOUND !!!!

}

sub gml2mmdtable {
   #
   # Wrapper function  
   #
   # Convert a XML/GeodesyML file
   # to
   # a WebObs markdown table for the COMPLETE history
   #
   my  $gmlfile = $_[0];
   my  $featsection = $_[1];
   
	if ( not -f $gmlfile)
	{
		die "$gmlfile not found"
	}
   
   my @outlines;
   ### add the "meta" line, thus the text is considered as MarkDown
   push(@outlines,"WebObs: converted with wiki2MMD\n\n");
   
   	#### HARDCODED XML2
#	my @Gml = qx($WEBOBS{XML2_PRGM} < $file);
	my @Gml = qx(/usr/bin/xml2 < $gmlfile);
   
   	###### Receiver
   	if ( $featsection eq "gnssrec" ) {
		push(@outlines,"| Date installed       | Date removed         | Model            | Satellite system | Serial number | Firmware version |\n");
		push(@outlines,"| ---------------------------------------------------------------------------------------------------------------------|\n");
		#my @RecList = [ gmlarray2nodearray(\@Gml,"rec",-1) ];
		my @RecList = gmlarray2nodearray(\@Gml,"rec","all");
		my $Rec;	
		foreach $Rec ( @RecList ){
			my %hashrec;
			%hashrec = rec_nodearray2hash($Rec);
			my $line = sprintf("|%22s|%22s|%18s|%18s|%15s|%18s|",$hashrec{'dinsta'},$hashrec{'dremov'},$hashrec{'model'},$hashrec{'satsys'},$hashrec{'sn'},$hashrec{'vfirm'});
			push(@outlines,$line);
		}
	} elsif ( $featsection eq "gnssant" ) {
		
		push(@outlines,"| Date installed       | Date removed         | Model            | Radome | Serial number | N. Align. (°) | Cable len. (m) |\n");
		push(@outlines,"| -------------------------------------------------------------------------------------------------------------------------|\n");
		#my @AntList = [ gmlarray2nodearray(\@Gml,"ant",-1) ];
		my @AntList = gmlarray2nodearray(\@Gml,"ant","all");
		my $Ant;	
		foreach $Ant ( @AntList ){
			my %hashant;
			%hashant = ant_nodearray2hash($Ant);
			my $line = sprintf("|%22s|%22s|%18s|%8s|%15s|%16s|%16s|",$hashant{'dinsta'},$hashant{'dremov'},$hashant{'model'},$hashant{'radome'},$hashant{'sn'},$hashant{'alignN'},$hashant{'lcable'});
			push(@outlines,$line);
		}
	}

	return @outlines;
}

sub gml2date {
	
}

1;
