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
if (clientHasEdit(type=>"authmisc",name=>"CLB")) {
	if ($QryParm->{'node'} ne "") {
		my %S = readNode($QryParm->{'node'});
		%NODE = %{$S{$QryParm->{'node'}}};
		if (%NODE) {
			$fileDATA = "$NODES{PATH_NODES}/$QryParm->{'node'}/$QryParm->{'node'}.clb";
			%CLBS = readCfg($WEBOBS{CLB_CONF});
			if (%CLBS) {
				@fieldCLB = readCfg($CLBS{FIELDS_FILE});
				if (@fieldCLB) {
					$fileDATA = "$NODES{PATH_NODES}/$QryParm->{'node'}/$QryParm->{'node'}.clb";
				} else { htmlMsgNotOK("Couldn't read the calibration-files data-fields definition.") } 
			} else { htmlMsgNotOK("Couldn't read the calibration-files configuration.") }
		} else { die "Couldn't get $QryParm->{'node'} node configuration." }
	} else { htmlMsgNotOK("no node specified. ") }
} else { htmlMsgNotOK("You can't edit calibration files !") }

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
my $today  = qx(date -I); chomp($today);
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
	}
} else {
	htmlMsgNotOK("postCLB opening r/w - $!");
}

# --- return information when OK 
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
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

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014 - Institut de Physique du Globe Paris

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

