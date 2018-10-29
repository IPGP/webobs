#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- WEBOBS -----------------------------------
# seiscomp2mc.pl
# ------
# Usage: see included help
#
# Dependencies:
# 	xml2
# 	(binary from sources http://dan.egnor.name/xml2/ref)
# 
# Author: Francois Beauducel
# Created: 2012-04-26
# Updated: 2012-05-23


use strict;
use POSIX;


my $old_locale = setlocale(LC_NUMERIC);
setlocale(LC_NUMERIC,'C');

# ----------------------------------------------------
use QML;
use readConf;
my %WEBOBS = readConfFile;

my $mc3 = $WEBOBS{MC3_DEFAULT_CONF};


if (@ARGV > 0) {
	if (!($ARGV[0] =~ /update|check|dumper/)) {
		print "$0: '$ARGV[0]' invalid command.\n";
		exit(1);
	}
}

if (@ARGV == 0) {
	print 	"NAME\n\tWEBOBS - SeisComP to MC3 seismic bulletin\n\n",
		"SYNOPSIS\n\tseiscomp2mc COMMAND [OPTIONS]\n\n",
		"DESCRIPTION\n",
		"\tThe script checks new events in QuakeML SeisComP database and updates\n",
		"\tif necessary the MC3 database by creating new events entries. List of\n",
		"\tavailable commands and options:\n\n",
		"\tupdate\n",
		"\t\tUpdates MC3 database.\n",
		"\tcheck\n",
		"\t\tchecks MC3 database (read only).\n",
		"\tdumper\n",
		"\t\tchecks and dumps XML tree (read only).\n",
		"\t-f=MC3NAME\n",
		"\t\tSpecifies MC3 conf name. Default is MC3_DEFAULT_CONF in WEBOBS.conf.\n",
		"\nAUTHOR\n\tFrancois Beauducel, IPGP <beauducel\@ipgp.fr>\n\n"
		;
	exit(0);
}

my $commandline = "$0 ".join(" ",@ARGV);
my $arg = shift;

if (grep(/-f=/,$arg)) {
	$mc3 = join('',grep(/-f=/,$arg));
	$mc3 =~ s/-f=//;
}

my %MC3 = readConfFile("$mc3.conf");
my $oper = $MC3{SC3_USER};

# gets the list of last events
my @last = sort(qx(find $MC3{SC3_EVENTS_ROOT} -maxdepth 4 -name "$MC3{SC3_EVENTS_ID_PREFIX}" -mtime -$MC3{SC3_UPDATE_DAYS}));
chomp(@last);
print "checks $MC3{SC3_UPDATE_DAYS} last days ($#last events)...\n";

# checks if events exist in MC database
for (@last) {
	my $name = $_;
	$name =~ s/$MC3{SC3_EVENTS_ROOT}\///;
	my ($evt_y,$evt_m,$evt_d,$evt_id) = split(/\//,$name);
	my $fullname = "$_/$evt_id.last.xml";
	print "--- $fullname ---\n";

	my $mc_path = "$MC3{ROOT}/*/$MC3{PATH_FILES}/*.txt";
	my @lines = qx(grep "$evt_id" $mc_path|xargs echo -n);
	my $mc_file;

	if (@lines) {
		# event's ID already exists in MC: do nothing (for the moment...)
		$mc_file = "";
	} else {

		# -------------------------------------------------------------------------
		# event seems new: updates MC file

		my @tab;
		my $s;

		my @event = qx(xml2 < $fullname);

		$s = '/seiscomp/EventParameters';
		foreach (@event) { s/^$s//g; }

		if ($arg =~ /dumper/) {
			print join('',@event);
		}
		chomp(@event);

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
		print "origin latitude = $evt_lat\n";

		# --- gets origin:longitude
		my $evt_lon = findvalue('/longitude/value=',\@origin);
		print "origin longitude = $evt_lon\n";

		# --- gets origin:depth
		my $evt_dep = findvalue('/depth/value=',\@origin);
		print "origin depth = $evt_dep\n";

		# --- gets origin:evaluationMode and origin:evaluationStatus
		my $evt_mode = findvalue('/evaluationMode=',\@origin);
		my $evt_status = findvalue('/evaluationStatus=',\@origin);
		my $evt_type;
		if ($evt_mode eq 'manual') {
			$evt_type = 'UNKNOWN';
		} else {
			$evt_type = 'AUTO';
		}

		print "origin mode = $evt_mode\n";
		print "origin status = $evt_status\n";

		# --- gets preferred magnitude ID
		my $evt_magID = findvalue('/event/preferredMagnitudeID=',\@event);

		my $evt_mag;
		my $evt_smag;
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
		my $evt_sdate = substr($evt_pick,0,10);
		my $evt_stime = substr($evt_pick,11,11);
		$evt_stime =~ s/[A-Z]/0/g; # sometimes time value is "2012-05-07T18:46:53.7Z"
		my $evt_scode = findvalue('/waveformID/@networkCode=',\@pick).".".
				findvalue('/waveformID/@stationCode=',\@pick).".".
				findvalue('/waveformID/@locationCode=',\@pick).".".
				findvalue('/waveformID/@channelCode=',\@pick);
		print "station pickID = $evt_pickID\n";
		print "station time = $evt_pick\n";
		print "station code = $evt_scode\n";
		

		my @arrival = findnode('/arrival',"/pickID=$evt_pickID",\@origin);

		my $evt_pha;
		my $evt_dist;
		my $evt_unique = 0;
		my $evt_SP;
		if (@arrival) {
			# --- unique arrival or not
			if (scalar(@arrival) == 1) {
				$evt_unique = 1;
			}

			# --- finds first station phase and distance (using "origin:arrival")
			$evt_pha = findvalue('/phase=',\@arrival);
			$evt_dist = findvalue('/distance=',\@arrival) * 111;
			print "station phase = $evt_pha\n";
			print "station distance = $evt_dist\n";
			# --- computes S-P and duration from distance and magnitude
			$evt_SP = sprintf("%1.2f",$evt_dist/8);
			print "station S-P = $evt_SP\n";
		} else {
			print "* Warning: no arrivals (phase, distance, S-P)!\n";
		}

		# --- computes duration from distance and magnitude
		my $evt_dur;
		if ($evt_smag && $evt_dist) {
			$evt_dur = sprintf("%1.2f",10 ** (($evt_smag - $evt_dist*0.0035 + 0.87)/2));
			print "station duration = $evt_dur\n";
		} else {
			print "* Warning: no duration!\n";
		}

		# --- selects first station arrival (using "amplitude")
		my @amplitude = findnode('/amplitude',"/pickID=$evt_pickID",\@event);
		
		my $evt_samp;
		if (@amplitude) {
			# --- gets amplitude:value
			$evt_samp = findvalue('/amplitude/value=',\@amplitude);
			print "station amplitude = $evt_samp\n";
		} else {
			print "* Warning: no amplitude!\n";
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

		# --- reads MC file
		my ($mcy,$mcm) = split(/-/,$evt_sdate);
		$mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
		my @lignes;
		if (-e $mc_file)  {
			print "MC file: $mc_file ...";
			open(FILE, "<$mc_file") || Quit($lockFile," Problem to read $mc_file\n");
			while(<FILE>) { push(@lignes,$_); }
			close(FILE);
			print " imported.\n";

			# Creation d'un backup
			#my $fileMCTrtBckp = $fileMC.".backup";
			#open(FILE, ">$fileMCTrtBckp") || Quit($lockFile," Probleme sur le fichier $fileMCTrtBckp\n");
			#print FILE @lignes;
			#close(FILE);
			#print "<P><B>Copie de sauvegarde:</B> $fileMCTrtBckp</P>\n";

			# --- calculates the new ID
			my $max = 0;
			for (@lignes) {
				($mc_id) = split(/\|/,$_);
				if (abs($mc_id) > $max) {
					$max = abs($mc_id);
				}
			}
			$mc_id = $max + 1;
		} else {
			if ($arg =~ /update/) {
				qx(mkdir -p `dirname $mc_file`);
				open(FILE, ">$mc_file") || Quit($lockFile,"Problem to create new file $mc_file\n");
				print FILE ("");
				close(FILE);
				$mc_id = 1;
			}
		}

		# --- outputs for MC
		my $newline;
		#$newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique||$evt_y/$evt_m/$evt_d/$evt_id||$oper|\n";
		$newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1||$evt_scode|$evt_unique||$evt_y/$evt_m/$evt_d/$evt_id||$oper|\n";
		print "$newline\n";



		if ($arg =~ /update/) {
			push(@lignes,$newline);
			@lignes = sort Sort_date_with_id(@lignes);

			open(FILE, ">$mc_file") || Quit($lockFile,"Problem with file $mc_file !\n");
			print FILE @lignes;
			close(FILE);

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


