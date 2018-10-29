#!/usr/bin/perl -w

use strict;
use File::Basename;

sub checkIP
{
	my $remoteIP = $_[0];
	my ($id1,$id2,$id3,$id4) = split (/\./,$remoteIP);
	my $rangeIP=$id1.".".$id2.".".$id3; 
	if (
		(
			# Martinique
			$rangeIP eq "195.83.190"
			|| (
				# Guadeloupe
				$rangeIP eq "195.83.189"
				# sans DHCP ou CDSA
				&& ($id4 < 150 || $id4 > 230)
			)
		)
		# Local
		|| ($rangeIP eq "127.0.0")
	) { 
		# Adresse IP interne : OK
		return 0
	} else {
		# Adresse IP externe : accès refusé ou lecture seule
		#return 1
		
		# NOUVEAU: checkIP renvoie toujours 0 depuis l'identification par login
		return 0
	}

}

1;

