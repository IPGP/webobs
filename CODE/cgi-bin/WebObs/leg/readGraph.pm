#!/usr/bin/perl -w
# --- WEBOBS / Institut de Physique du Globe de Paris ----------
# Usage: This script reads the networks and routines configuration file
# It returns a large hash %graphStr with codes keys.
#
# 	- for general variables (disciplines, observatories and network type):
#		$graphStr{keydis_DISCIPLINE}
#		$graphStr{orddis_DISCIPLINE}
#		$graphStr{coddis_DISCIPLINE}
#		$graphStr{codobs_OBSERVATOIRE}
#		$graphStr{typereseau_TYPERESEAU}
#
#	- for all routine keys:
# 		$graphStr{key_ROUTINE} = value
#
#	- cross referencing with network 3-letter code ODT:
#		$graphStr{routine_ODT} = ROUTINE
#		$graphStr{netorder} = array of codes ODT (in order of the conf file)
#
# Authors: Didier Mallarino, revised by François Beauducel
# Created: 2005-10-07
# Modified: 2010-06-02 [FB+AB]
#
# ------------------- RCS Header -------------------------------
# $Header: /ipgp/webobs/WWW/cgi-bin/RCS/readGraph.pm,v 1.4 2007/05/21 23:32:13 beaudu Exp $
# $Revision: 1.4 $
# $Author: beaudu $
# --------------------------------------------------------------
#

#use i18n;

sub readGraphFile
{

	my %graphStr;
	my @liste;

	# --- Reads the file
	my $graphFile = $_[0];

	my @infoGenerales = ("");
	open(FILE, "<$graphFile") || die "WEBOBS: file $graphFile not found.\n";
	while(<FILE>) { push(@infoGenerales,$_); }
	close(FILE);

	chomp(@infoGenerales);
	@infoGenerales = grep(!/^#/, @infoGenerales);
	@infoGenerales = grep(!/^$/, @infoGenerales);

	# --- keys for "DISCIPLINE"
	@liste = grep (/^DISCIPLINE\|cod\|/, @infoGenerales);
	$liste[0] =~ s/^\w\*|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeCodesD = split(/,/,$liste[0]);

	@liste = grep (/^DISCIPLINE\|key\|/, @infoGenerales);
	$liste[0] =~ s/^\w*\|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeKeyD = split(/,/,$liste[0]);

	$i = 0;
	for (@listeCodesD) { my $cle = "keydis_$_"; $graphStr{$cle} = $listeKeyD[$i++]; }

	@liste = grep (/^DISCIPLINE\|ord\|/, @infoGenerales);
	$liste[0] =~ s/^\w*\|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeOrdD = split(/,/,$liste[0]);

	$i = 0;
	for (@listeCodesD) { my $cle = "orddis_$_"; $graphStr{$cle} = $listeOrdD[$i++]; }

	@liste = grep (/^DISCIPLINE\|nom\|/, @infoGenerales);
	$liste[0] =~ s/^\w*\|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeNomsD = split(/,/,$liste[0]);

	$i = 0;
	for (@listeCodesD) { my $cle = "codedis_$_"; $graphStr{$cle} = $listeNomsD[$i++]; }


	# --- keys for "TYPERESEAU"
	@liste = grep (/^TYPERESEAU\|key\|/, @infoGenerales);
	$liste[0] =~ s/^\w*\|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeKeyTR = split(/,/,$liste[0]);

	@liste = grep (/^TYPERESEAU\|nom\|/, @infoGenerales);
	$liste[0] =~ s/^\w*\|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeNomsTR = split(/,/,$liste[0]);

	$i = 0;
	for (@listeKeyTR) { my $cle = "typereseau_$_"; $graphStr{$cle} = $listeNomsTR[$i++]; }


	# --- keys for "OBSERVATOIRE"
	@liste = grep (/^OBSERVATOIRE\|cod\|/, @infoGenerales);
	$liste[0] =~ s/^\w\*|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeCodesO = split(/,/,$liste[0]);

	@liste = grep (/^OBSERVATOIRE\|nom\|/, @infoGenerales);
	$liste[0] =~ s/^\w\*|\w*\|//gi;
	$liste[0] =~ s/\'|{|}//gi;
	my @listeNomsO = split(/,/,$liste[0]);

	my %observatoire;
	$i = 0;
	for (@listeCodesO) { my $cle = "codeobs_$_"; $graphStr{$cle} = $listeNomsO[$i++]; }


	# --- all keys for networks/routines
	for (grep(!/^OBSERVATOIRE|^DISCIPLINE|^TYPERESEAU/,@infoGenerales)) {
		my ($res,$code,$value) = split (/\|/,$_);
		$value =~ s/\'//gi;
		my $cle = "$code\_$res";
		$graphStr{$cle} = $value;
	}


	# --- keys for network codes cross referencing
	my @netOrder;
	for (grep (/\|cod\|/, @infoGenerales)) {
	     my ($res,$code,$value) = split (/\|/,$_);
	     if (defined($graphStr{"net_$res"}) and $graphStr{"net_$res"} != 0) {
		 my $codeReseau = $graphStr{"obs_$res"}.$graphStr{"cod_$res"};
		 $graphStr{"routine_$codeReseau"} = $res;
		 push(@netOrder,$codeReseau);
	     }
	}
	$graphStr{"netorder"} = [ @netOrder ];
	    
	return %graphStr;
}

1;
