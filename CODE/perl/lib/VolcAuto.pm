#!/usr/bin/perl
#
# This module regroup functions used to reads CSV values in the input stream,
# interprets each well formed line as an automatic volcanic event and insert it
# as a new event into the WebObs Main Courante (if no other event already
# exists).
#

package VolcAuto;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.3';

use File::Basename qw(basename);
use Locale::TextDomain('webobs');
use Try::Tiny;

use WebObs::Config qw(%WEBOBS);

use VolcAuto::MCFile;
use VolcAuto::MCEvent;

use Exporter qw(import);
our @EXPORT_OK = qw(debug_log err_log write_whole_file create_mc3_lock
                    remove_mc3_lock autovt2mc process_autovolc_csv);

BEGIN {
    # Suppress the default fatalsToBrowser from CGI::Carp
    $CGI::Carp::TO_BROWSER = 0;
}


# -----------------------------------------------------------------------------
# Configuration and initialisation
#

# Separator character in the input CSV lines
my $INPUT_SEPARATOR = ",";

# Operator id to use in the MC for new automatic events
my $AUTOVOLC_UID = 'VOLC';

# Event type to use in the MC for new automatic events
my $AUTOVOLC_TYPE = 'VOLCAUTO';


# Set DEBUG to 1 to see additional messages on stderr
my $DEBUG = $ENV{'DEBUG'} // 1;

# Whether or not we created the lock file ourself
my $lock_created = 0;

# Set LANG to locale
$ENV{LANG} = $WEBOBS{LOCALE};

# Name of the script (for use in debug output)
my $SCRIPT_NAME = basename($0);


# -----------------------------------------------------------------------------
# Subroutines
#

#
# Log message to stderr if DEBUG is true
#
sub debug_log {
    my $msg = shift;

    say STDERR "[DEBUG] $msg" if ($DEBUG);
}


# -----------------------------------------------------------------------------
# Log message to stderr if DEBUG is true
#
sub err_log {
    my $msg = shift;

    say STDERR "$SCRIPT_NAME: $msg";
}


# -----------------------------------------------------------------------------
# Read the whole content of a file
#
# Parameters:
#   string: the filename representing the lockfile
#
# Return value:
#   string: the content of the file
#
sub read_whole_file {
    my $file_name = shift;

    open(my $file, $file_name)
        or die "Could not open '$file_name' for reading: $!";

    my $file_content = do {
        local $/;  # Enter slurp mode
        <$file>;   # Read and return the whole file
    };

    close($file)
        or warn "Error while closing $file_name: $!";

    return $file_content;
}


# -----------------------------------------------------------------------------
# Write/Overwrite the whole content of a file
#
# Parameters:
#   string: the filename where to write
#   string: the content to write to the file
#
# Return value:
#   undef
#
sub write_whole_file {
    my $file_name = shift;
    my $file_content = shift;

    open(my $file, ">", $file_name)
        or die "Could not open '$file_name' for reading: $!";

    print $file $file_content;

    close($file)
        or warn "Error while closing $file_name: $!";
}


# -----------------------------------------------------------------------------
# Create a non-blocking lock for the MC3
# (Using the WebObs™ way™, i.e. with race condition included.)
#
# Parameters:
#   string: the name of the MC that will be modified (e.g. 'MC3')
#
# Return value:
#   undef
#
sub create_mc3_lock {
    my $mc3_name = shift;

    # The lock file for the MC3: MUST be the same as used in other scripts
    my $lock_file = "$WEBOBS{PATH_TMP_WEBOBS}/$mc3_name.lock";

    # Try to acquire the lock $try_count times before giving up.
    my $try_count = 3;
    # Wait $wait seconds between tries
    my $wait = 2;

    while ($try_count--) {
        last if (not -e $lock_file);

        my $lock_owner = read_whole_file($lock_file);
        chomp $lock_owner;
        err_log(sprintf("MC is currently being locked by %s,"
                        ." retrying in %d seconds...",
                        $lock_owner, (3 - $try_count) * $wait));
        sleep((3 - $try_count) * $wait);
    }

    if (-e $lock_file) {
        err_log("could not acquire lock '$lock_file', aborting.");
        exit(2);
    }
    write_whole_file($lock_file, $AUTOVOLC_UID);
    $lock_created = 1;
}


# -----------------------------------------------------------------------------
# Remove the lock file for the MC3
#
# Parameters:
#   string: the name of the MC that was to be modified (e.g. 'MC3')
#
# Return value:
#   undef
#
sub remove_mc3_lock {
    my $mc3_name = shift;

    # The lock file for the MC3: MUST be the same as used in other scripts
    my $lock_file = "$WEBOBS{PATH_TMP_WEBOBS}/$mc3_name.lock";
    my $warn_if_missing = shift // 1;

    # Proceed only if we created the lock
    return unless ($lock_created);

    if (-e $lock_file) {
        unlink $lock_file
            or warn "Error removing lock file '$lock_file': $!";
    } elsif ($warn_if_missing) {
        warn "Error removing lock file '$lock_file': file is missing!";
    }
}


# -----------------------------------------------------------------------------
# Return a VolcAuto::MCEvent object built from the data taken from a line of
# the CVS file, using additional fixed values.
#
# Parameters:
#   string: a CSV line generated by the volcanic event detector
#   string: the name of the MC to use (e.g. 'MC3')
#   integer: the id of the event in the MC
#   string: the name of the Sefran the event should be linked to
#
# Return value:
#   VolcAuto::MCEvent object: the event corresponding to the provided CSV line
#
sub autovt2mc {
    my $CSV_line = shift;
    my $mc3_name = shift;
    my $event_id = shift;
    my $sefran_name = shift;

    my ($tmpl_id, $date, $time, $corr, $station, $mag)
        = map { s/^\s+|\s+$//gr } split(/$INPUT_SEPARATOR/, $CSV_line);

    my $comment = sprintf('VT classe %d - %.2d%%', $tmpl_id, $corr * 100);
    if ($mag and $mag ne 'NaN') {
        $comment .= ' - MLv ' . $mag;
    }

    return VolcAuto::MCEvent->new({
        'mc3_name' => $mc3_name,
        'id' => $event_id,
        'date' => $date,
        'time' => $time,
        'type' => $AUTOVOLC_TYPE,
        'amplitude' => '',
        'duration' => 5,
        'unit' => 's',
        'sefran_name' => $sefran_name // undef,
        'station' => $station,
        'comment' => $comment,
        'operator' => $AUTOVOLC_UID,
    });
}


# -----------------------------------------------------------------------------
# Read CSV lines from STDIN and process them
#
# Parameters:
#   string: the name of the MC to use (e.g. 'MC3')
#   string: the name of the Sefran the event should be linked to
#
# Return value:
#   undef
#
sub process_autovolc_csv {
    my $mc3_name = shift;
    my $sefran_name = shift;

    my $mc;
    my $mc_month;

    while (my $line = <STDIN>) {
        # Remove the trailing new line
        chomp $line;

        # Ignore comments and blank lines
        next if $line =~ /^\s*(#|$)/;

        # Parse CSV line
        my $vt_event;
        $vt_event = autovt2mc($line, $mc3_name, 0, $sefran_name);
        try {
            # Create the event with temporary id 0
            $vt_event = autovt2mc($line, $mc3_name, 0, $sefran_name);
        } catch {
            # The event is not well formed (some column is missing)
            debug_log("skipping malformed line '$line'");
            $vt_event = undef;
        };
        next unless $vt_event;

        # If processing a line from a different month,
        # load the new MC file
        if (not $mc_month or $mc_month ne $vt_event->ym) {
            $mc_month = $vt_event->ym;

            $mc->write_file() if ($mc);
            $mc = VolcAuto::MCFile->new($vt_event->{'datetime'}->year,
                                        $vt_event->{'datetime'}->month,
                                        $mc3_name,
                                        $sefran_name);
        }

        # Set proper id for the event
        $vt_event->{'id'} = $mc->{'last_id'} + 1;

        # Add event to the MC (if no similar event already exists)
        $mc->add_event($vt_event);
    }

    $mc->write_file() if ($mc);
}

1;
