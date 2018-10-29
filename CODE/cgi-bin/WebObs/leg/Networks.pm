package WebObs::Networks;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Networks
 
Rebuid of readGraph.pm  

   More later ;-) 

=head1 GLOBAL VARIABLES

   %OBSRV 
   %DISCP 
   %NETWT

=cut

use strict;
use warnings;
use DBI;
use WebObs::Utils qw(u2l l2u);
use WebObs::Config qw(%WEBOBS readCfg);
    
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, %OBSRV, %DISCP, %NETWT, $OBSRV_LFN, $DISCP_LFN, $NETWT_LFN);
require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(%OBSRV %DISCP %NETWT readNet);
@EXPORT_OK  = qw(readGraph);
$VERSION    = "1.00";

my $obsrvname = "$WEBOBS{FILE_OBSERVATORIES}";
my $discpname = "$WEBOBS{FILE_DISCIPLINES}";
my $netwtname = "$WEBOBS{FILE_NETWORKSTYPES}";
my $NetworksDir = "$WEBOBS{PATH_NETWORKS}";
my $StationsDir = "$WEBOBS{RACINE_DATA_STATIONS}";

if (-e $obsrvname) {%OBSRV = readCfg($obsrvname); $OBSRV_LFN = "from $obsrvname (".(stat($obsrvname))[9].")";};
if (-e $discpname) {%DISCP = readCfg($discpname); $DISCP_LFN = "from $discpname (".(stat($discpname))[9].")";};
if (-e $netwtname) {%NETWT = readCfg($netwtname); $NETWT_LFN = "from $netwtname (".(stat($netwtname))[9].")";};

=pod

=head1 FUNCTIONS

=head2 readNet

Reads one or more 'networks' configurations into a HoH.

eg: %N = readNet("^S");     # all networks whose names starts in S
    $x = $N{SISMOHYP}{nom}  # value of 'nom' field of network SISMOHYP

Internally uses the WebObs::Networks::readNetNames subroutine defined below,
to select the networks. 

=cut 

sub readNet {
	my %ret;
	for my $f (readNetNames($_[0])) {
		my %tmp = readCfg($NetworksDir."/".$f);
		my $codereseau = $tmp{obs}.$tmp{cod};
		opendir(DIR, $StationsDir) or die "can't opendir $StationsDir: $!"; 
    	my @l = grep {/^($codereseau)/ && -d $StationsDir."/".$_} readdir(DIR);
		$tmp{'STA'} = \@l;
    	closedir(DIR);
		$ret{$f}=\%tmp; 
	}
	return %ret;
}

=pod 

=head2 readNetNames

Will list 'networks' defined in $WEBOBS{PATH_NETWORKS}. 

Input is optional, as it defaults to 'all networks' found in 
$WEBOBS{PATH_NETWORKS}. If it is specified, it will 
be used as a regexp to select some networks in $WEBOBS{PATH_NETWORKS}.

eg: @L = readNetNames("SISMO");  # all networks whose names contains SISMO

=cut 

sub readNetNames {
	#$_[0] will be used as a regexp
	my $net = $_[0] ? $_[0] : "^[^ ]{1,8}\$" ;

	opendir(DIR, $NetworksDir) or die "can't opendir $NetworksDir: $!"; 
    my @list = grep {/($net)/ && -f $NetworksDir."/".$_} readdir(DIR);
    closedir(DIR);
	return @list;
}

=pod 

=head2 newNet

=cut 

=pod 

=head2 readGraph

legacy -- generates that good?-old '%graphStr' structure 
however, order of appearance of networks codes in $graphStr{netorder} 
is NOT guaranteed to match what is was supposed to be (ie. order 
of appearance in the configuration file).

The 'old' description follows:

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

=cut 

sub readGraph {

	my %graphStr;
	my %N = readNet();

	for my $c (keys(%DISCP)) { 
		$graphStr{"keydis_".$c}  = $DISCP{$c}{keyword}; 
		$graphStr{"orddis_".$c}  = $DISCP{$c}{ord};
		$graphStr{"codedis_".$c} = $DISCP{$c}{name};
	}

	for my $c (keys(%NETWT)) { $graphStr{"typereseau_".$c}  = $NETWT{$c}; }

	for my $c (keys(%OBSRV)) { $graphStr{"codeobs_".$c}  = $OBSRV{$c}; }

	$graphStr{netorder} = [];
	for my $n (keys(%N)) {
		for my $k (keys (%{$N{$n}})) { $graphStr{$k."_".$n} = $N{$n}{$k}; }
		if ( defined($N{$n}{net}) and ($N{$n}{net} != 0) ) {
			my $codereseau = $N{$n}{obs}.$N{$n}{cod} ;
			$graphStr{"routine_$codereseau"} = $n;
			push(@{$graphStr{netorder}},$codereseau);
		}
	}

	return %graphStr;

}

1;

__END__

=pod

=head1 AUTHOR

Alexis Bosson, Francois Beauducel, Didier Mallarino, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012 - Institut de Physique du Globe Paris

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
				
