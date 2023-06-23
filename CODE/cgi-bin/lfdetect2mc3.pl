#!/usr/bin/perl

=head1 NAME

lfdetect2mc3.pl

=head1 SYNOPSIS

 $ perl lfdetect2mc3.pl { update | check } -f mc3-name -d lfdetect_dir [-n sefran3-name]

=head1 DESCRIPTION

lfdetect2mc3 checks new events from an FDSN event webservice and, when necessary, updates
the MC3 database by creating new events entries. lfdetect2mc3 requires a command:

update
  Updates MC3 database

check
 checks MC3 database (read only)

An argument ( -d ) specify the lfdetect output directory to look into

An optional argument ( -f ) may specify the MC3 configuration file to be used. It
defaults to $WEBOBS{ROOT_CONF}/$WEBOBS{MC3_DEFAULT_NAME}.conf

An optional argument ( -n ) may specify the SEFRAN3 name to be used. It
defaults to $WEBOBS{SEFRAN3_DEFAULT_NAME}

=head1 DEPENDENCIES


=cut

use strict;
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use POSIX;

use WebObs::Config;
use QML;
use MC3;

# ---- create files with group permissions from the parent directory
umask 002;

my $old_locale = setlocale(LC_NUMERIC);
setlocale(LC_NUMERIC,'C');

# ---- default MC3 configuration
my $mc3 = $WEBOBS{MC3_DEFAULT_NAME};
my $lfdetect_dir = '';
my $sefran3_name = $WEBOBS{SEFRAN3_DEFAULT_NAME};

# ---- help text when no arguments
if (@ARGV == 0) {
	print "WebObs lfdetect to MC3 seismic bulletin\n\n",
		"Usage: $0 COMMAND [OPTIONS]\n\n",
		"\tThe script checks new events in lfdetect output directory and updates\n",
		"\tif necessary the MC3 database by creating new events entries. List of\n",
		"\tavailable commands and options:\n\n",
		"\tupdate\n",
		"\t\tUpdates MC3 database.\n",
		"\tcheck\n",
		"\t\tchecks MC3 database (read only).\n",
		"\t-f MC3NAME\n",
		"\t\tSpecifies MC3 conf name. Default is MC3_DEFAULT_NAME in WEBOBS.conf.\n",
		"\t-d lfdetect output directory\n",
		"\t\tSpecifies lfdetect output directory to look for events.\n",
		"\t-n SEFRAN3 name\n",
		"\t\tSpecifies SEFRAN3 name to use as reference. Default is SEFRAN3_DEFAULT_NAME in WEBOBS.conf.\n",
		"\n\tFrançois Beauducel, Jean-Marie Saurel, WEBOBS/IPGP\n\n"
		;
	exit(0);
}

# ---- check for command and option
my $arg;
if (@ARGV > 0) {
	$arg = shift;
	if (!($arg =~ /update|check/)) {
		print "'$arg' invalid command\n";
		exit(1);
	}
	my $opt = shift || '';
	if ( $opt =~ /-f/ ) {
		$opt = shift;
		if ( $opt ) {
			if ( -e "$WEBOBS{ROOT_CONF}/$opt.conf" ) {
				$mc3 = $opt;
        $opt = shift || '';
			} else {
				print "'$opt' does not exists\n";
				exit(1);
			}
		} else {
			print "invalid -f option\n";
			exit(1);
		}
	}
	if ( $opt =~ /-d/ ) {
		$opt = shift;
		if ( $opt ) {
			$lfdetect_dir = $opt;
			print "-d option $lfdetect_dir\n";
			$opt = shift || '';
		} else {
			print "invalid -d option\n";
			exit(1);
		}
	}
	if ( $opt =~ /-n/ ) {
		$opt = shift;
		if ( $opt ) {
			$sefran3_name = $opt;
			print "-n option $sefran3_name\n";
			$opt = shift || '';
		} else {
			print "invalid -n option\n";
			exit(1);
		}
	}
}

# ---- read config
my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");
my $oper = 'LF_detect';

# ---- gets the list of last events
my @last = sort(qx(find $lfdetect_dir -maxdepth 1 -mindepth 1 -type d -mtime -$MC3{SC3_UPDATE_DAYS}));
chomp(@last);
print "checks $MC3{SC3_UPDATE_DAYS} last days ($#last events)...\n";

# checks if events exist in MC database
for (@last) {
	my $name = $_;
	$name =~ s/$lfdetect_dir\///;
	my $fullname = "$_/$name.txt";
	my $surfwave = "$_/$name.surface_waves.txt";
	print "--- checking $fullname ---\n";

	my $mc_path = "$MC3{ROOT}/*/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}*.txt";
	my @lines = qx(grep "lfdetect:${name}" $mc_path|xargs echo -n);
	my $mc_file;

	if (@lines) {
		# event's ID already exists in MC: do nothing (for the moment...)
		$mc_file = "";
	} else {

		# -------------------------------------------------------------------------
		# event seems new: updates MC file
		print "new event : $name\n";

		my @tab;
		my $s;

		my $event = qx(tail -n 1 $fullname);

		my ($evt_scode,$evt_id,$evt_start,$evt_end,$evt_dur,$evt_max,$evt_snr,$evt_period,$evt_rms) = split(' ',$event);
		my $evt_sdate = substr($evt_start,0,10) // '';
		my $evt_stime = substr($evt_start,11,11) // '';
		my $evt_img = "$evt_id.png";

		my $evt_type = 'AUTOVLF';

		my $lockFile = "/tmp/.$mc3.lock";

		if ($arg =~ /update/) {
			# --- checks lock file
			if (-e $lockFile) {
				my $lockWho = qx(cat $lockFile | xargs echo -n);
				die "WEBOBS: MC is presently edited by $lockWho ...";
			} else {
				my $retLock = qx(echo "$oper" > $lockFile);
			}
			}

		my $mc_id;
		my $newID = 1;
		my $maxID = 0;

		# --- reads MC file
		my ($mcy,$mcm) = split(/-/,$evt_sdate);
		$mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
		my @lignes;
		if (-e $mc_file)  {
			print "MC file: $mc_file ...";
			open(FILE, "<$mc_file") || Quit($lockFile," Problem to read $mc_file\n");
			while(<FILE>) {
				my $line = $_;
				($mc_id) = split(/\|/,$line);
				$maxID = abs($mc_id) if (abs($mc_id) > $maxID);
				push(@lignes,$line);
			}
			close(FILE);
			print " imported (max ID = $maxID).\n";
		} else {
			# MC file does not exist: need to create directory and empty file.
			if ($arg =~ /update/) {
				qx(mkdir -p `dirname $mc_file`);
				open(FILE, ">$mc_file") || Quit($lockFile,"Problem to create new file $mc_file\n");
				print FILE ("");
				close(FILE);
				$mc_id = 1;
			}
		}

		# --- outputs for MC
		if ($newID > 0) {
			$mc_id = $maxID + 1;
			my $comment;
			my $comment_VLF = "VLF SNR=$evt_snr, period=$evt_period";
			if (-e $surfwave) {
				my ($tele_OTime, $tele_coord, $tele_mag, $tele_text) = split(/\|/, qx(cat $surfwave | tr -d '\n'));
				$comment = "$comment_VLF, possible surf. waves from EQ $tele_text, $tele_mag at $tele_OTime";
			}
			else {
				$comment = "$comment_VLF";
			}
			my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1||$evt_scode|1|$sefran3_name|lfdetect:$evt_id|$evt_img|$oper|$comment\n";
			print "$newline\n";
			push(@lignes,$newline);
		}


		if ($arg =~ /update/) {
			@lignes = sort Sort_date_with_id(@lignes);

			# Temporary file for sanity check before replacing
			my $mc_file_temp="$mc_file.tmp";
			# Open temporary file for writing
			open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
			# Write the updated lines
			print FILE @lignes;
			close(FILE);
			# Sanity check : the columns number must always be 17
			if (system("awk -F'|' 'NF!=17{exit 1}' $mc_file") == 0) {
				# Test passed, the file isn't corrupted
				# The update should have increased the file size
				if ( -s $mc_file_temp >= -s $mc_file ) {
					# The file size is increased
					# Replace the old file by the new one
					if ( system("mv $mc_file_temp $mc_file") == 0 ) {
						print "MC file: $mc_file updated\n";
					} else {
						Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
					}
				}
			} else {
				print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
			}

			# --- deletes lock file
			if (-e $lockFile) {
				unlink $lockFile;
			}
		}
	}

	setlocale(LC_NUMERIC,$old_locale);
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub Sort_date_with_id ($$) {
        my ($c,$d) = @_;

        # removes the first field (ID)
        $c =~ s/^[\-0-9]+\|//;
        $d =~ s/^[\-0-9]+\|//;

        return $d cmp $c;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub Quit
{
	if (-e $_[0]) {
		unlink $_[0];
	}
	die "WEBOBS: $_[1]";
}

__END__

=pod

=head1 AUTHOR(S)

François Beauducel, Didier Lafon, Jean-Marie Saurel

=head1 COPYRIGHT

Webobs - 2012-2017 - Institut de Physique du Globe Paris

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
