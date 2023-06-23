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
use DateTime;
use Data::Dumper;
use File::Path qw(make_path);
use File::Basename qw(dirname);
use FindBin;
use POSIX;
use HTTP::Tiny;
use XML::LibXML;
use XML::LibXML::XPathContext;
use WebObs::Config;
use QML;
use lib $FindBin::Bin;

# WebObs::Config forces errors in HTML, but this is not what we want here
# (use a BEGIN block to also intercept compile-time errors)
BEGIN {
	CGI::Carp::set_die_handler(\&CGI::Carp::realdie);
}

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

# Version lisant les fichiers
#sub is_event_in_mc {
#	# Tests if an event $event is present in a MC file matching $mc_glob.
#	#
#	# Returns 1 if a line is found with event colum matching $event.
#	# Returns 0 otherwise
#	#
#	my $event = shift;
#	my $mc_glob = shift;
#	my @mc_files = glob($mc_glob);
#	return 0 unless @mc_files;
#
#	for my $mc_path (@mc_files) {
#		open(my $mc, '<:encoding(ISO-8859-1)', $mc_path)
#			or die "Could not open file '$mc_path' $!";
#		
#		while (my $line = <$mc>) {
#			#return 1 if $events =~ $line;
#			my @row = split(/\|/, $line);
#			print "FOUND $event in $mc_path\n" if ($row[13] and $row[13] eq $event);
#			return 1 if ($row[13] and $row[13] eq $event);
#		}
#	}
#	return 0;
#}


sub get_mc_filename {
	# Return the name of the MC file for an event happening on $year-$month.
	my $mc3conf = shift;
	my $year = shift;
	my $month = shift;
	return sprintf("%s/%.4d/%s/%s%.4d%.2d.txt",
					$mc3conf->{ROOT}, $year, $mc3conf->{PATH_FILES},
					$mc3conf->{FILE_PREFIX}, $year, $month);
}


sub get_mc_file_list {
	# Returns the list of MC filenames (as absolute paths) where the relevant
	# events are to be read. Note: non existing MC files are silently skipped.
	# $mc3conf is the global %MC3 and $update_days should be $MC3{SC3_UPDATE_DAYS}
	my $mc3conf = shift;
	my $update_days = shift;
	my $now = DateTime->now('time_zone' => 'local');
	my $date = $now->clone()->subtract('days' => $update_days)->set('day' => 1);
	my @mc_files = ();

	while (DateTime->compare($date, $now) < 1) {
		# Add the filename to the list if it exists
		my $mc_filename = get_mc_filename($mc3conf, $date->year, $date->month);
		push(@mc_files, $mc_filename) if (-e $mc_filename);
		# Process next month
		$date = $date->add('months' => 1);
	}
	return \@mc_files;
}


sub load_mc_events {
	# Retourne la liste des événements (sous forme de hash
	# pour permettre une recherche de présence plus rapide).
	my $mc_file_list = shift;
	my %events = ();
	return {} unless @$mc_file_list;

	for my $mc_path (@$mc_file_list) {
		open(my $mc, '<:encoding(ISO-8859-1)', $mc_path)
			or die "Could not open file '$mc_path' $!";
		
		while (my $line = <$mc>) {
			# Skip empty line
			next unless $line;
			my @row = split(/\|/, $line);
			# Skip malformed line or older format
			next if (@row < 17);
			# Keep event ID in colum 13, if defined
			$events{$row[13]} = 1 if ($row[13]);
		}
	}
	return \%events;
}


sub check_fields_count {
	# Returns 1 if all lines in $mc_filename have $nb_col fields
	# using the '|' separator.
	# Returns 0 otherwise.
	my $mc_filename = shift;
	my $nb_col = shift;
	open(my $mc, '<:encoding(ISO-8859-1)', $mc_filename)
		or die "Could not open file '$mc_filename' $!";
	
	while (my $line = <$mc>) {
		return 0 if (scalar(split(/\|/, $line)) != $nb_col);
	}
	return 1;
}


sub fetch_or_die {
	# Fetches an URL and returns the content, or die with an error message.
	my $url = shift;
    my $response = HTTP::Tiny->new->get($url);
    if (!$response->{success}) {
        die "Could not fetch URL $url\n"
			."Got status $response->{status}: $response->{reasons}";
	}
	return $response->{content};
}


# ---- Read MC3 config
my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");
my $oper = $MC3{SC3_USER};
# list of blacklisted events (use an hash to quickly test the inclusion)
my %blacklist_types = map(($_ => 1), split(/,/, $MC3{SC3_EVENT_TYPES_BLACKLIST}));

# ---- Read FDSN WebService config
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
	make_path($MC3{SC3_EVENTS_ROOT})
		|| die "Could not create directory '$MC3{SC3_EVENTS_ROOT}' $!";
}


# ---- Get the list of last events
#my $starttime = POSIX::strftime('%Y-%m-%dT%H:%M:%S',gmtime(time-3600*24*$MC3{SC3_UPDATE_DAYS}));
my $starttime = DateTime->now('time_zone' => 'local')
					->subtract('days' => $MC3{SC3_UPDATE_DAYS})
					->strftime("%Y-%m-%dT%H:%M:%S");
print "Fetching events since $starttime from ${fdsnws_url}...\n";
my $lastEventsText = fetch_or_die("${fdsnws_url}${fdsnws_search}&format=text&orderby=time&starttime=$starttime");

# Split lines to an array, removing the header line
my @lastEvents = grep(!/^#/, split(/\n/, $lastEventsText));
# Only keep the ID of each event
my @lastEventsID = map((split(/\|/, $_))[0], @lastEvents);

print "Loading events from the MC for the last $MC3{SC3_UPDATE_DAYS} days...\n";
my $mc_events = load_mc_events(get_mc_file_list(\%MC3, $MC3{SC3_UPDATE_DAYS}));

print "Checking events for the last $MC3{SC3_UPDATE_DAYS} days (".scalar(@lastEventsID)." events)...\n";


# Check if each event exists in MC database, and add it if needed
for my $evt_id (@lastEventsID) {
	print "--- $evt_id ---\n";

	if (!$mc_events->{"$fdsnws_server://$evt_id"}) {
		# Event ID does not exists in MC: update the MC file

		# Fetch event info from the web service
		#my $event_url = "${fdsnws_url}${fdsnws_detail}&format=xml&eventid=$evt_id";
		#my $dom = XML::LibXML->load_xml(location => $event_url);
		#my $xpc = XML::LibXML::XPathContext->new($dom);
		#$xpc->registerNs('q', 'http://quakeml.org/xmlns/bed/1.2');

		my @event = qx(curl -s --globoff "${fdsnws_url}${fdsnws_detail}&format=xml&eventid=$evt_id" | $WEBOBS{XML2_PRGM});
		for (@event) { s{^/q:quakeml/eventParameters/event}{}g; };  # Remove prefix in xml2 output

		if ($arg =~ /dumper/) {
			print join('',@event);
		}
		chomp(@event);

		# --- Get event type
		#print "Found type = ".$xpc->findvalue("//q:event/q:type")."\n";
		my $evt_type = findvalue('/type=',\@event) // '';
		print "event type = $evt_type\n";
		if ($blacklist_types{$evt_type}) {
			print "Event type '$evt_type' is blacklisted. Skipping.\n";
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
			my @tab = sort(findvalues('/pick/time/value=',\@event));
			my $evt_pick = $tab[0] || '';
			if (!$evt_pick) {
				print "* Warning: no pick in event, ignoring event.\n";
				next;
			}

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
				# --- create lock file or die
				if (-e $lockFile) {
					#my $lockWho = qx(cat $lockFile | xargs echo -n);
					open(my $lock, "<$lockFile") || Quit($lockFile, "Could not read file $lockFile\n");
					my $lockOwner = <$lock>;
					close($lock);
					chomp $lockOwner;
					die "WEBOBS: MC is presently edited by $lockOwner ...";
				} else {
					#my $retLock = qx(echo "$oper" > $lockFile);
					open(my $lock, ">$lockFile") || Quit($lockFile, "Could not open file $lockFile for writing\n");
					print $lock "$oper\n";
					close($lock);
				}
			}

			my $mc_id;
			my $newID = 1;
			my $maxID = 0;

			# --- reads MC file
			my ($mcy,$mcm) = split(/-/,$evt_sdate);
			#my $mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
			my $mc_file = get_mc_filename(\%MC3, $mcy, $mcm);
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
					#qx(mkdir -p `dirname $mc_file`);
					my $mc_dir = dirname($mc_file);
					# Note: make_path calls carp() or croak() in case of error
					eval { make_path($mc_dir); };
					if ($@) { Quit($lockFile, "Could not create directory '$mc_dir': $@"); }
					open(my $mc, ">$mc_file") || Quit($lockFile, "Could not create file '$mc_file'\n");
					print $mc ("");
					close($mc);
					$mc_id = 1;
				}
			}

			# --- outputs for MC
			if ($newID > 0) {
				$mc_id = $maxID + 1;
				#my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1||$evt_scode|$evt_unique|$sefran3_name|$fdsnws_server:\/\/$evt_id||$oper|$evt_magtyp$evt_mag $evt_txt\n";
				my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique|$sefran3_name|$fdsnws_server:\/\/$evt_id||$oper|$evt_magtyp$evt_mag $evt_txt\n";
				print "$newline\n";
				push(@lignes,$newline);
			}


			if ($arg =~ /update/) {
				@lignes = sort Sort_date_with_id(@lignes);

				# Temporary file for sanity check before replacing
				my $mc_file_temp="$mc_file.tmp";
				# Open temporary file for writing
				open(my $temp_mc_file, ">$mc_file_temp") || Quit($lockFile, "Could not write to file $mc_file_temp !\n");
				# Write the updated lines
				print $temp_mc_file @lignes;
				close($temp_mc_file);
				# Sanity check : the columns number must always be 17
				if (check_fields_count($mc_file, 17)) {
					# Test passed, the file isn't corrupted
					# The update should have increased the file size
					if ( -s $mc_file_temp >= -s $mc_file ) {
						# The file size is increased
						# Replace the old file by the new one
						if (rename($mc_file_temp, $mc_file)) {
							print "MC file: $mc_file updated\n";
						} else {
							Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
						}
					}
				} else {
					print "Problem with updated file : bad columns count ! Not replacing file $mc_file !\n";
				}

				# --- deletes lock file
				if (-e $lockFile) {
					unlink $lockFile;
				}
			}
		}  # end of else (event is not backlisted)
	}  # end of if event is not in MC
}  # end of for each FDSNWS event in the last month

setlocale(LC_NUMERIC,$old_locale);


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
