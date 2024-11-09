#!/usr/bin/perl

=head1 NAME

fdsnws-event2mc3.pl

=head1 SYNOPSIS

 $ perl fdsnws-event2mc3.pl { update | check | dumper } [-s fdsn_src] [-f mc3-name] [-n sefran3-name]

=head1 DESCRIPTION

fdsnws-event2mc3 checks new events from an FDSN event webservice and, when necessary, updates
the MC3 database by creating new events entries. fdsnws-event2mc3 requires a command:

update
  Updates MC3 database

check
 checks MC3 database (read only)

dumper
 checks and dumps XML tree (read only)

An optional argument ( -s ) may specify the FDSN webservice server to be used. It
defaults to $WEBOBS{FDSNWS_EVENTS_URL}

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

# ---- create files with group permissions from the parent directory
umask 002;

my $old_locale = setlocale(LC_NUMERIC);
setlocale(LC_NUMERIC,'C');

# ---- default MC3 configuration
my $mc3 = $WEBOBS{MC3_DEFAULT_NAME};
my $fdsnws_server = '';
my $sefran3_name = $WEBOBS{SEFRAN3_DEFAULT_NAME};

# ---- help text when no arguments
if (@ARGV == 0) {
	print "WebObs FDSN event webservice to MC3 seismic bulletin\n\n",
		"Usage: $0 COMMAND [OPTIONS]\n\n",
		"\tThe script checks new events in FDSN event webservice and updates\n",
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
		"\t-s FDSN WebService server\n",
		"\t\tSpecifies FDSN WebService server to use (variable name FDSNWS_EVENTS_URL_server).Default is FDSNWS_EVENTS_URL in MC3 conf file.\n",
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
	if ( $opt =~ /-s/ ) {
		$opt = shift;
		if ( $opt ) {
			$fdsnws_server = $opt;
			print "-s option $fdsnws_server\n";
			$opt = shift || '';
		} else {
			print "invalid -s option\n";
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
# ---- FDSN WebService server
my $fdsnws_url = "";
my $fdsnws_search = "";
my $fdsnws_detail = "";
if (defined($MC3{FDSNWS_EVENTS_URL})) {
	$fdsnws_url = $MC3{FDSNWS_EVENTS_URL};
	($fdsnws_url,$fdsnws_detail) = split(/\?/,$fdsnws_url);
	$fdsnws_url = $fdsnws_url."?";
}
if (defined($MC3{FDSNWS_EVENTS_OPT})) {
	$fdsnws_search = $MC3{FDSNWS_EVENTS_OPT};
}
elsif (defined($MC3{FDSNWS_EVENTS_SEARCH})) {
	$fdsnws_search = $MC3{FDSNWS_EVENTS_SEARCH};
}
if (defined($MC3{FDSNWS_EVENTS_DETAIL})) {
	$fdsnws_detail = $MC3{FDSNWS_EVENTS_DETAIL};
}
if (length($fdsnws_server) > 0) {
	my $varname = "FDSNWS_EVENTS_URL_$fdsnws_server";
	$fdsnws_url = $MC3{$varname};
	($fdsnws_url,$fdsnws_detail) = split(/\?/,$fdsnws_url);
	$fdsnws_url = $fdsnws_url."?";
	$varname = "FDSNWS_EVENTS_OPT_$fdsnws_server";
	if (defined($MC3{$varname})) {
		$fdsnws_search = $MC3{$varname};
	}
	else {
		$varname = "FDSNWS_EVENTS_SEARCH_$fdsnws_server";
		if (defined($MC3{$varname})) {
			$fdsnws_search = $MC3{$varname};
		}
	}
	$varname = "FDSNWS_EVENTS_DETAIL_$fdsnws_server";
	if (defined($MC3{$varname})) {
		$fdsnws_detail = $MC3{$varname};
	}
}

if (! -d $MC3{SC3_EVENTS_ROOT} ) {
	print "creating $MC3{SC3_EVENTS_ROOT}\n";
	my @rcme = qx(mkdir -p $MC3{SC3_EVENTS_ROOT} );
}

# ---- gets the list of last events
my $starttime = POSIX::strftime('%Y-%m-%dT%H:%M:%S',gmtime(time-3600*24*$MC3{SC3_UPDATE_DAYS}));
my @last = sort(qx(curl -s -S --globoff "${fdsnws_url}${fdsnws_search}&format=text&orderby=time&starttime=$starttime" | egrep '^[^#]' | cut -d '|' -f 1));
chomp(@last);
print "checks $MC3{SC3_UPDATE_DAYS} last days ($#last events)...\n";

# checks if events exist in MC database
for (@last) {
	my $evt_id = $_;
	print "--- $evt_id ---\n";

	my $mc_path = "$MC3{ROOT}/*/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}*.txt";
	my @lines = qx(grep "${fdsnws_server}:\/\/${evt_id}" $mc_path|xargs echo -n);
	my $mc_file;

	if (@lines) {
		# event's ID already exists in MC: do nothing (for the moment...)
		$mc_file = "";
	} else {

		# -------------------------------------------------------------------------
		# event seems new: updates MC file

		my @tab;
		my $s;

		my @event = qx(curl -s -S --globoff "${fdsnws_url}${fdsnws_detail}&format=xml&eventid=$evt_id" | $WEBOBS{XML2_PRGM});

		$s = '/q:quakeml/eventParameters/event';
		foreach (@event) { s/^$s//g; }

		if ($arg =~ /dumper/) {
			print join('',@event);
		}
		chomp(@event);

		# --- gets event type
		my $evt_type = findvalue('/type=',\@event) // '';
		print "event type = $evt_type\n";
		if (grep(/^$evt_type$/,@blacklist_types)) {
			print "Warning: Event type '$evt_type' is blacklisted!\n";
		} else {

			# --- gets preferred origin ID
			my $evt_origID = findvalue('/preferredOriginID=',\@event);
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
			my $mcIDname = (split(/\//,$evt_mcID))[-3];
			my $mcIDym = (split(/\//,$evt_mcID))[-2];
			my $mcIDid = (split(/\//,$evt_mcID))[-1];

			# --- gets origin:depth
			my $evt_dep = findvalue('/depth/value=',\@origin);
			$evt_dep /=  1000 if ($evt_dep ne "");
			print "origin depth = ".($evt_dep ? "$evt_dep":"")."\n";

			# --- gets description:text
			my $evt_txt = findvalue('/description/text=',\@event);
			print "origin description = $evt_txt \n";

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
			my $evt_magID = findvalue('/preferredMagnitudeID=',\@event);

			my $evt_mag = '';
			my $evt_magtyp = '';
			my $evt_smag = '';
			my @magnitude;
			if ($evt_magID) {
				print "origin magnitude ID = $evt_magID\n";
				@magnitude = findnode('/magnitude',"/\@publicID=$evt_magID",\@event);
			} else {
				@magnitude = findnode('/magnitude','/\@publicID=',\@event);
				print "* Warning: no preferred magnitude! Takes first...\n";
			}
			if (@magnitude) {
				$evt_mag = findvalue('/mag/value=',\@magnitude);
				print "origin magnitude = $evt_mag\n";
				$evt_smag = $evt_mag;
				$evt_magtyp = findvalue('/type=',\@magnitude);
				print "origin magnitude type = $evt_magtyp\n";
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
					# --- check if $evt_mcID found
					if ($evt_mcID ne '' && $mcIDname eq $mc3 && $mcIDym eq "$mcy$mcm" && $mc_id == $mcIDid) {
						$newID = 0;
						my @txt = split(/\|/,$line);
						$txt[13] = "$fdsnws_server:\/\/$evt_id";
						# @txt last field already contains "\n"
						$line = join('|',@txt);
					}
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
				my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique|$sefran3_name|$fdsnws_server:\/\/$evt_id||$oper|$evt_magtyp$evt_mag $evt_txt\n";
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
