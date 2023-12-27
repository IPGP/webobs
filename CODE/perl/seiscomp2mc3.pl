#!/usr/bin/perl

=head1 NAME

seiscomp2mc3.pl

=head1 SYNOPSIS

 $ perl seiscomp2mc3.pl { update | check | dumper } [-f mc3-name] [-n sefran3-name]

=head1 DESCRIPTION

seiscomp2mc3 checks new events in QuakeML SeisComP database and, when necessary, updates
the MC3 database by creating new events entries. seiscomp2mc3 requires a command:

update
  Updates MC3 database

check
 checks MC3 database (read only)

dumper
 checks and dumps XML tree (read only)

An optional argument ( -f ) may specify the MC3 configuration file to be used. It
defaults to $WEBOBS{ROOT_CONF}/$WEBOBS{MC3_DEFAULT_NAME}.conf

An optional argument ( -n ) may specify the SEFRAN3 name to be used. It
defaults to $WEBOBS{SEFRAN3_DEFAULT_NAME}

=head1 DEPENDENCIES

xml2
(binary from sources http://dan.egnor.name/xml2/ref)

=cut

use strict;
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use POSIX;

use WebObs::Config;
use WebObs::QML;
# Date parsing library
use DateTime::Format::Strptime;

# ---- create files with group permissions from the parent directory
umask 002;

my $old_locale = setlocale(LC_NUMERIC);
setlocale(LC_NUMERIC,'C');

# ---- default MC3 configuration
my $mc3 = $WEBOBS{MC3_DEFAULT_NAME};
my $sefran3_name = $WEBOBS{SEFRAN3_DEFAULT_NAME};

# Maximum difference between the dates of an event in SC3 and MC3 to update MC3 (seconds)
my $max_dts_sc3_mc3 = 90;

# ---- help text when no arguments
if (@ARGV == 0) {
	print "WebObs SeisComP to MC3 seismic bulletin\n\n",
		"Usage: $0 COMMAND [OPTIONS]\n\n",
		"\tThe script checks new events in QuakeML SeisComP database and updates\n",
		"\tif necessary the MC3 database by creating new events entries. List of\n",
		"\tavailable commands and options:\n\n",
		"\tupdate\n",
		"\t\tUpdates MC3 database.\n",
		"\tcheck\n",
		"\t\tchecks MC3 database (read only).\n",
		"\tdumper\n",
		"\t\tchecks and dumps XML tree (read only).\n",
		"\t-f MC3NAME\n",
		"\t\tSpecifies MC3 conf name. Default is MC3_DEFAULT_NAME in WEBOBS.conf.\n",
		"\t-n SEFRAN3 name\n",
		"\t\tSpecifies SEFRAN3 name to use as reference. Default is SEFRAN3_DEFAULT_NAME in WEBOBS.conf.\n",
		"\n\tFrancois Beauducel, IPGP <beauducel\@ipgp.fr>\n\n"
		;
	exit(0);
}

# ---- check for command and option
my $arg;
if (@ARGV > 0) {
	$arg = shift;
	if (!($arg =~ /update|check|dumper/)) {
		print "'$arg' invalid command\n";
		exit(1);
	}
	my $opt = shift || '';
	if ( $opt =~ /-f/ ) {
		$opt = shift;
		if ( $opt ) {
			if ( -e "$WEBOBS{ROOT_CONF}/$opt.conf" ) {
				$mc3 = $opt;
			} else {
				print "'$opt' does not exists\n";
				exit(1);
			}
		} else {
			print "invalid -f option\n";
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
my $oper = $MC3{SC3_USER};
my @blacklist_types = split(/,/,$MC3{SC3_EVENT_TYPES_BLACKLIST});

if (! -d $MC3{SC3_EVENTS_ROOT} ) {
	print "creating $MC3{SC3_EVENTS_ROOT}\n";
	my @rcme = qx(mkdir -p $MC3{SC3_EVENTS_ROOT} );
}

# ---- gets the list of last events
my @last = sort(qx(find $MC3{SC3_EVENTS_ROOT} -maxdepth 4 -name "$MC3{SC3_EVENTS_ID_PREFIX}*" -mtime -$MC3{SC3_UPDATE_DAYS}));
chomp(@last);
print "checks $MC3{SC3_UPDATE_DAYS} last days ($#last events)...\n";

# checks if events exist in MC database
for (@last) {
	my $name = $_;
	$name =~ s/$MC3{SC3_EVENTS_ROOT}\///;
	my ($evt_y,$evt_m,$evt_d,$evt_id) = split(/\//,$name);
	my $fullname = "$_/$evt_id.last.xml";
	print "--- checking $fullname ---\n";

	my $mc_path = "$MC3{ROOT}/*/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}*.txt";
	my @lines = qx(grep "$evt_id" $mc_path|cut -d'|' -f14|xargs echo -n);
	my $mc_file;

	if (@lines) {
		# event's ID already exists in MC: do nothing (for the moment...)
		$mc_file = "";
	} else {

		# -------------------------------------------------------------------------
		# event seems new: updates MC file
		print "new event : $evt_id\n";

		my @tab;
		my $s;

		my @event = qx($WEBOBS{XML2_PRGM} < $fullname);

		$s = '/seiscomp/EventParameters';
		foreach (@event) { s/^$s//g; }

		if ($arg =~ /dumper/) {
			print join('',@event);
		}
		chomp(@event);

		# --- gets event type
		my $evt_type = findvalue('/event/type=',\@event) // '';
		print "event type = $evt_type\n";
		if (grep(/^$evt_type$/,@blacklist_types)) {
			print "Warning: Event type '$evt_type' is blacklisted!\n";
		} else {

			# --- gets preferred origin ID
			my $evt_origID = findvalue('/event/preferredOriginID=',\@event);
			print "origin ID = $evt_origID\n";

			# --- selects preferred origin
			my @origin = findnode('/origin',"/\@publicID=$evt_origID",\@event);

			# --- gets origin:time
			my $evt_time = findvalue('/time/value=',\@origin);
			print "origin time = $evt_time\n";

			# --- gets origin:latitude
			my $evt_lat = findvalue('/latitude/value=',\@origin);
			print "origin latitude = ".($evt_lat ? "$evt_lat":"")."\n";

			# --- gets origin:longitude
			my $evt_lon = findvalue('/longitude/value=',\@origin);
			print "origin longitude = ".($evt_lon ? "$evt_lon":"")."\n";

			# --- gets origin:methodID
			my $evt_mcID = findvalue('/methodID=',\@origin) // '';
			print "origin methodID (MCID) = $evt_mcID\n";
			my ($mcIDname,$mcIDym,$mcIDid) = split(/\//,$evt_mcID);

			# --- gets origin:depth
			my $evt_dep = findvalue('/depth/value=',\@origin);
			print "origin depth = ".($evt_dep ? "$evt_dep":"")."\n";

			# --- gets origin:evaluationMode and origin:evaluationStatus
			my $evt_mode = findvalue('/evaluationMode=',\@origin);
			my $evt_status = findvalue('/evaluationStatus=',\@origin);
			if ($evt_status && $evt_status eq 'confirmed') {
				$evt_type = 'UNKNOWN';
			} else {
				$evt_type = 'AUTO';
			}

			print "origin mode = ".($evt_mode ? "$evt_mode":"")."\n";
			print "origin status = ".($evt_status ? "$evt_status":"")."\n";

			# --- gets preferred magnitude ID
			my $evt_magID = findvalue('/event/preferredMagnitudeID=',\@event);

			my $evt_mag = '';
			my $evt_smag = '';
			my @magnitude;
			if ($evt_magID) {
				print "origin magnitude ID = $evt_magID\n";
				@magnitude = findnode('/origin/magnitude',"/\@publicID=$evt_magID",\@event);
			} else {
				@magnitude = findnode('/origin/magnitude','/\@publicID=',\@event);
				print "* Warning: no preferred magnitude! Takes first...\n";
			}
			if (@magnitude) {
				$evt_mag = findvalue('/magnitude/value=',\@magnitude);
				print "origin magnitude = $evt_mag\n";
				$evt_smag = $evt_mag;
			} else {
				print "* Warning: no magnitude!\n";
			}


			# --- selects first pick
			# sorting pick:time:value = chronological order
			@tab = sort(findvalues('/pick/time/value=',\@event));
			my $evt_pick = $tab[0];
			my @pick = findnode('/pick',"/time/value=$evt_pick",\@event);
			my $evt_pickID = findvalue('/\@publicID=',\@pick);
			my $evt_sdate = substr($evt_pick,0,10) // '';
			my $evt_stime = substr($evt_pick,11,11) // '';
			$evt_stime =~ s/[A-Z]/0/g; # sometimes time value is "2012-05-07T18:46:53.7Z"
			my $NET = findvalue('/waveformID/@networkCode=',\@pick) // '';
			my $STA = findvalue('/waveformID/@stationCode=',\@pick) // '';
			my $LOC = findvalue('/waveformID/@locationCode=',\@pick) // '';
			my $CHA = findvalue('/waveformID/@channelCode=',\@pick) // '';
			my $evt_scode = "$NET.$STA.$LOC.$CHA";
			print "station pickID = $evt_pickID\n";
			print "station time = $evt_pick\n";
			print "station code = $evt_scode\n";


			my @arrival = findnode('/arrival',"/pickID=$evt_pickID",\@origin);

			my $evt_pha = '';
			my $evt_dist = '';
			my $evt_unique = 0;
			my $evt_SP = '';
			if (@arrival) {
				# --- unique arrival or not
				if (scalar(@arrival) == 1) {
					$evt_unique = 1;
				}

				# --- finds first station phase and distance (using "origin:arrival")
				$evt_pha = findvalue('/phase=',\@arrival);
				$evt_dist = findvalue('/distance=',\@arrival);
				$evt_dist *= 111 if ($evt_dist);
				print "station phase = $evt_pha\n";
				print "station distance = ".($evt_dist ? "$evt_dist":"")."\n";
				# --- computes S-P and duration from distance and magnitude
				$evt_SP = ($evt_dist ? sprintf("%1.2f",$evt_dist/8):"");
				print "station S-P = $evt_SP\n";
			} else {
				print "* Warning: no arrivals (phase, distance, S-P)!\n";
			}

			# --- computes duration from distance and magnitude
			my $evt_dur = '';
			if ($evt_smag && $evt_dist) {
				$evt_dur = sprintf("%1.2f",10 ** (($evt_smag - $evt_dist*0.0035 + 0.87)/2));
				print "station duration = $evt_dur\n";
				if ($evt_dur == 0) {
					$evt_dur = '';
				}
			} else {
				print "* Warning: no duration!\n";
			}

			# --- selects first station arrival (using "amplitude")
			my @amplitude = findnode('/amplitude',"/pickID=$evt_pickID",\@event);

			my $evt_samp = '';
			if (@amplitude) {
				# --- gets amplitude:value
				$evt_samp = findvalue('/amplitude/value=',\@amplitude);
				print "station amplitude = $evt_samp\n";
			} else {
				print "* Warning: no amplitude!\n";
			}

			if (!$evt_sdate) {
				# If the event doesn't have any picks, we get /origin/time/value (already stored in $evt_time)
				$evt_sdate = substr($evt_time,0,10) || '';
				$evt_stime = substr($evt_time,11,11) || '';
				$evt_stime =~ s/[A-Z]/0/g; # remove trailing "Z" in "2012-05-07T18:46:53.7Z"
			}


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
			# The date of the event is mandatory
			if (defined($mcy)) {
				$mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
				my @lignes;
				if (-e $mc_file)  {
					print "MC file: $mc_file ...";
					open(FILE, "<$mc_file") || Quit($lockFile," Problem to read $mc_file\n");
					while(<FILE>) {
						my $line = $_;
						my $line2=$line;
						chomp($line2);
						($mc_id) = split(/\|/,$line2);
						# Ignore blank lines
						if (defined($mc_id)) {
							# check if $evt_mcID found
							if ($evt_mcID ne '') {
								if ($mcIDname eq $mc3 && $mcIDym eq "$mcy$mcm" && $mc_id == $mcIDid) {
									my @txt = split(/\|/,$line);
									# Sanity check : we mustn't change a SC3 ID already stored in the MC3 file
									if ( $txt[13] eq '' ) {
										# Sanity check : we update the MC file only if the date of the event is the same (under $max_dts_sc3_mc3)
										# It is necessary if the MC file has been corrupted or deleted and the new file doesn't have the same IDs than before, so we can't use the MC IDs stored in SC3
										my $strp = DateTime::Format::Strptime->new(
											pattern   => '%Y-%m-%d %H:%M:%S',
											time_zone => 'UTC',
										);
										# Datetimes in XML and MC3 (truncated to second)
										my $dt_qml = $strp->parse_datetime($evt_sdate." ".substr($evt_stime,0,8));
										my $dt_mc = $strp->parse_datetime($txt[1]." ".substr($txt[2],0,8));
										# Unix timestamps in XML and MC3
										my $ts_qml=$dt_qml->epoch;
										my $ts_mc=$dt_mc->epoch;
										# Difference of timestamps : it must be under $max_dts_sc3_mc3
										my $dts=abs($ts_qml-$ts_mc);
										# If it's the same event
										if ($dts < $max_dts_sc3_mc3) {
											$newID = 0;
											# Update Event ID
											print "Replacing ID $txt[13] by $evt_y/$evt_m/$evt_d/$evt_id (dts $dts)\n";
											$txt[13] = "$evt_y/$evt_m/$evt_d/$evt_id";
											# @txt last field already contains "\n"
											$line = join('|',@txt);
										} else {
											print "Same MC ID ($mc_id) but with different date : $evt_sdate $evt_stime (QML) != $txt[1] $txt[2] (MC)\n"
										}
									} else {
											print "This MC ID ($mc_id) already has a SC3 ID ($txt[13]) !\n"
									}
								}
							}
							$maxID = abs($mc_id) if (abs($mc_id) > $maxID);
						}
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
					my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique|$sefran3_name|$evt_y/$evt_m/$evt_d/$evt_id||$oper|\n";
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
					# Sanity check : the columns number must always be 17 (empty lines are ignored)
					if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
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

				}
			} else {
				print "No date for this new event !";
			}
			if ($arg =~ /update/) {
				# --- deletes lock file
				if (-e $lockFile) {
					unlink $lockFile;
				}
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

François Beauducel, Didier Lafon

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
