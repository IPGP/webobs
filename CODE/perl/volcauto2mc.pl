#!/usr/bin/perl
#
# This script reads CSV values on its input, interprets each well formed line
# as an automatic volcanic event and insert it as a new event into the WebObs
# Main Courante if no other event already exists for this approximate date and
# time.
#
# The name of the MC to use (e.g. 'MC3') and the name of the SEFRAN to use
# (e.g. 'SEFRAN3') can be provided respectively as first and second parameter
# to the script. If empty or missing, default values defined in WEBOBS.rc as
# MC3_DEFAULT_NAME and SEFRAN3_DEFAULT_NAME are used.
#
# The main functions for this script are taken from the VolcAuto module and
# use classes defined in modules VolcAuto::MCFile and VolcAuto::MCEvent.
#

use 5.010;
use strict;
use warnings;

our $VERSION = '0.2';

use WebObs::Config qw(%WEBOBS);

use VolcAuto qw(create_mc3_lock remove_mc3_lock process_autovolc_csv);

BEGIN {

    # Suppress the default fatalsToBrowser from CGI::Carp
    $CGI::Carp::TO_BROWSER = 0;
}

# -----------------------------------------------------------------------------
# Read script parameters
#

# The MC and sefran name to use, if not the default ones
my $mc3_name = $ARGV[0] || $WEBOBS{'MC3_DEFAULT_NAME'};
my $sefran_name = $ARGV[1] || $WEBOBS{'SEFRAN3_DEFAULT_NAME'};

# -----------------------------------------------------------------------------
# Make sure the lock will be removed however the script is ended
#
END {

    # Remove the lock (if we've created it ourself)
    remove_mc3_lock($mc3_name);
}

# Handle Ctrl-c event (the END block will then be called)
$SIG{'INT'} = sub { say STDERR "SIGINT caught, exiting."; exit(130); };
$SIG{'PIPE'} = sub { say STDERR "SIGPIPE caught, exiting."; exit(141); };

# -----------------------------------------------------------------------------
# Main instructions

# Create the lock for the MC3
create_mc3_lock($mc3_name);

# Process CSV from STDIN
process_autovolc_csv($mc3_name, $sefran_name);
