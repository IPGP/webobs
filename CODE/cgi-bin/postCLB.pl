#!/usr/bin/perl

=head1 NAME

postCLB.pl

=head1 SYNOPSIS

http://..../postCLB.pl?

=head1 DESCRIPTION

=head1 Query string parameters

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use Switch;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Grids;
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
$ENV{LANG} = $WEBOBS{LOCALE};

# ---- inits
my $GRIDName  = my $GRIDType  = my $NODEName = my $RESOURCE = "";
my %NODE;
my $fileDATA = "";
my %CLBS;
my @fieldCLB;
my @donnees;

my $Ctod  = time();  my @tod  = localtime($Ctod);
my $today = strftime('%F',@tod);

my $QryParm = $cgi->Vars;
$QryParm->{'node'}   //= "";

# ---- can we ? should we ? do we have all we need ?
#
($GRIDType, $GRIDName, $NODEName) = split(/[\.\/]/, trim($QryParm->{'node'}));
if ( $GRIDType eq "PROC" && $GRIDName ne "" ) {
	if ( !clientHasEdit(type=>"authprocs",name=>"$GRIDName")) {
		die "$__{'Not authorized'} (edit) $QryParm->{'node'}";
	}
	if ($NODEName ne "") {
		my %S = readNode($NODEName);
		%NODE = %{$S{$NODEName}};
		if (%NODE) {
			$fileDATA = "$NODES{PATH_NODES}/$NODEName/$QryParm->{'node'}.clb";
			%CLBS = readCfg("$WEBOBS{ROOT_CODE}/etc/clb.conf");
			@fieldCLB = readCfg($CLBS{FIELDS_FILE});
		} else { htmlMsgNotOK("Couldn't get $QryParm->{'node'} node configuration."); exit 1; }
	} else { htmlMsgNotOK("no node specified. "); exit 1; }
} else { htmlMsgNotOK("You can't edit calibration files !"); exit 1; }

my $nb      = $cgi->param('nb');
my $nbc     = $cgi->param('nbc');
my $action  = $cgi->param('action');

# ---- build data file from querystring !

my @dd; my @dh; my @dv; my @ds;
my $maxc = my $modify = 0;

for my $i ("1"..$nb) {
	my $y = $cgi->param('y'.$i);
	my $m = $cgi->param('m'.$i);
	my $d = $cgi->param('d'.$i);
	$dd[$i-1] = "$y-$m-$d";
	my $h = $cgi->param('h'.$i);
	my $n = $cgi->param('n'.$i);
	$dh[$i-1] = "$h:$n";
	for my $j ("1"..($#fieldCLB-1)) {
		$dv[$i-1][$j-1] = $cgi->param('v'.$i.'_'.$j);
	}
	$ds[$i-1] = $cgi->param('s'.$i);
	if ($dv[$i-1][0] > $maxc) {
		$maxc = $dv[$i-1][0];
	}
}

for ("1"..$nb) {
	my $i = ($_-1);
	my $ligne = "$dd[$i]|$dh[$i]";
	if ($nbc >= 10) {
		$dv[$i][0] = sprintf("%02d",$dv[$i][0]);
	}
	for ("0"..($#fieldCLB-2)) {
		$ligne .= "|$dv[$i][$_]";
	}
	if (($action eq "delete" && $ds[$i] ne "") || $dv[$i][0] > $nbc) {
		$modify = 1;
	} elsif ($dv[$i][0]) {
		push(@donnees,"$ligne\n");
	}
	if ($action eq "duplicate" && $ds[$i] ne "") {
		push(@donnees,"$ligne\n");
		$modify = 1;
	}
}
if ($nbc > $maxc) {
	for (($maxc+1)..$nbc) {
		my $s = $today;
		$s .= "|$fieldCLB[1][1]|$_";
		for (3..($#fieldCLB)) {
			switch ($_) {
				case 13 { $s .= "|$NODE{LAT_WGS84}" }
				case 14 { $s .= "|$NODE{LON_WGS84}" }
				case 15 { $s .= "|$NODE{ALTITUDE}" }
				else    { $s .= "|$fieldCLB[$_][1]" }
			}
		}
		push(@donnees,"$s\n");
	}
	$nb = $#donnees + 1;
	@donnees = sort(@donnees);
	$modify = 1;
}

# stamp (date and staff)
my $stamp  = "[$today $USERS{$CLIENT}{UID}]";
my $entete = "# WebObs - $WEBOBS{WEBOBS_ID} : calibration file $QryParm->{'node'}\n# $stamp\n";

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postCLB waiting for lock on $fileDATA...";
		flock(FILE, LOCK_EX);
	}
	# ---- backup file (To Be Removed: lifecycle too short to be used )
	if (-e $fileDATA) { qx(cp -a $fileDATA $fileDATA~ 2>&1); }
	# ---- rewrite all file from previously built '@donnees'
	if ( $?  == 0 ) {
		truncate(FILE, 0);
		seek(FILE, 0, SEEK_SET);
		print FILE $entete;
		for (@donnees) {
			print FILE u2l("$_");
		}
		close(FILE);
		if ($nbc == $maxc && $modify == 0) { htmlMsgOK(); }
		else                               { htmlMsgOK("auto reload edit form")}
	} else {
		close(FILE);
		htmlMsgNotOK("postCLB couldn't backup $fileDATA ");
		exit 1;
	}
} else {
	htmlMsgNotOK("postCLB opening r/w - $!");
	exit 1;
}

# --- return information when OK
sub htmlMsgOK {
	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	
	# --- connecting to the database
	my $driver   = "SQLite";
	my $database = $WEBOBS{SQL_METADATA};
	my $dsn = "DBI:$driver:dbname=$database";
	my $userid = "";
	my $password = "";
	my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
	   or die $DBI::errstr;
	
	my $station  = $GRIDName.'.'.$NODEName;
	my $dataset  = 'OBSE_DAT_'.$GRIDName.'.'.$NODEName;
	my $dataname = $NODEName.'_all.txt';
	
	foreach (@donnees) {
	    # observed properties table
        my @obs   = split(/[\|]/, $_);
        my $id    = $obs[6];
        my $name  = $obs[6];
        my $unit  = $obs[4];
        my $theia = $obs[$#obs];
        
        # observations table
        my $obsid    = 'OBSE_OBS_'.$GRIDName.'.'.$NODEName.'_'.$id;
        my @first_date = split(/ /,$obs[0]);
        my $first_year   = $first_date[0];
	    my $first_hour   = $first_date[3] || "00";
	    my $first_minute = $first_date[4] || "00";
	    my $first_second = $first_date[5] || "00";
	   
	    # read data file to know end date of observations
	    my $filepath = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/exports/$dataname";
	    open(FH, '<', $filepath) or die $!;
		my @last_date;
	    while (<FH>) { if ($_ !~ /NaN/) {@last_date = split(/ /,$_)} };
	    my $last_year   = $last_date[0];
	    my $last_month  = $last_date[1];
	    my $last_day    = $last_date[2];
	    my $last_hour   = $last_date[3] || "00";
	    my $last_minute = $last_date[4] || "00";
	    my $last_second = $last_date[5];
	    if ($last_second =~ /./) { $last_second = "00" };
	    
	    my $first_obs_date = "$first_year\T$first_hour:$first_minute:$first_second\Z";
	    my $last_obs_date = "$last_year-$last_month-$last_day\T$last_hour:$last_minute:$last_second\Z";
	    my $obs_date = "$first_obs_date/$last_obs_date";
	    
		# --- completing observed_properties table
		my $sth = $dbh->prepare('INSERT OR REPLACE INTO observed_properties (IDENTIFIER, NAME, UNIT, THEIACATEGORIES) VALUES (?,?,?,?);');
		$sth->execute($id, $name, $unit, $theia);
		
		my $sth = $dbh->prepare('INSERT OR REPLACE INTO observations (IDENTIFIER, TEMPORALEXTENT, STATIONNAME, OBSERVEDPROPERTY, DATASET, DATAFILENAME) VALUES (?,?,?,?,?,?);');
	    $sth->execute($obsid,$obs_date,$station,$id,$dataset,$dataname);
	}
	
	my $msg = $_[0] || "calibration file successfully updated !" ;
	print "$msg\n";
}

# --- return information when not OK
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon, Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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
