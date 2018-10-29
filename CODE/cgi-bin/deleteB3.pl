#!/usr/bin/perl
#
# This script is a quick fix to help delete a B3 file to force its
# regeneration. It is called using a link from the daybook ("Main Courante"),
# and simply removes files corresponding to the requestion B3 from the
# <OUTG_DIR>/PROC.<B3_PROC_NAME>/events/YYYY/MM/DD/<sc3eventid>/ directory.
# The next run of the B3 proc will then regenerate the B3 with the updated events
# parameters.
#

##----------------------------------------------------------------------------
# Modules and configuration
#

use strict;
use warnings;
use POSIX qw(strftime);

# Read CGI parameters
use CGI;
my $q = CGI->new;
my $b3_name = $q->param('b3');
my $mc3 = $q->param('mc');

if (not ($b3_name and $mc3)) {
  show_error($q, "missing CGI parameter.");
  exit(0);
}

# Read webobs configuration
use WebObs::Config qw(readCfg);
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
our %MC3 = readCfg("$WebObs::Config::WEBOBS{ROOT_CONF}/$mc3.conf");


##----------------------------------------------------------------------------
# Subroutines
#

# Subroutine that deletes the files corresponding to the requested B3.
sub delete_b3_files {
  my $b3_file = shift;
  # $b3_file will be, e.g. 2016/07/11/ovsg2016nnij/20160711T065809_b3_MLv44_manual
  my $files_glob = "$WebObs::Config::WEBOBS{'ROOT_OUTG'}/PROC.$MC3{'TREMBLEMAPS_PROC'}/events/$b3_file.*";
  my $rc = unlink glob $files_glob;
  if (not $rc) {
		print STDERR strftime("[%c]", localtime())." $ENV{'SCRIPT_NAME'}: unlink glob $files_glob error: $!\n";
		return 1;
	}
  return 0;
}


# Print a very simple confirmation page
# (You'll have to translate it if needed).
sub show_confirmation_page {
  my ($q, $b3_file) = @_;
  my $b3_filename = $b3_file;
  $b3_filename =~ s|.*/||;

  print $q->header(-type => "text/html", -charset => "utf-8");
  print $q->start_html(-title => "B3 Removal successful"),
      $q->h1("B-cube supprimé"),
      $q->p("Les fichiers correspondant au b-cube ",$q->em("$b3_filename.*")," ont bien été supprimés.",
            "Veuillez patienter environ 2 minutes pour sa regénération."),
      $q->p("Vous pouvez maintenant fermer cette fenêtre.");
      #$q->p({-style => "font-size: smaller"},
      #      $q->em("Attention"), " <insert additional information here>");
}


# Returns a HTML forbidden page with a 403 status code.
sub show_unauthorized {
  my $q = shift;
  print $q->header(-type => "text/html",
                   -status => "403 Forbidden",
                   -charset => "utf-8");
  print $q->start_html(-title => "B3 Removal unauthorized"),
      $q->h1("Removal forbidden"),
      $q->p("Sorry, you don't have the rights to remove the B³.
            Contact your webobs administrator.");
}


# Prints an error to the web server log file and
# returns an HTML error page with a 500 status code.
sub show_error {
  my ($q, $msg) = @_;
  print STDERR strftime("[%c]", localtime())." $ENV{'SCRIPT_NAME'}: $msg \n" if ($msg);
  print $q->header(-type => "text/html",
                   -status => "500 Script error",
                   -charset => "utf-8");
  print $q->start_html(-title => "B3 Removal error"),
      $q->h1("An error occured"),
      $q->p("Sorry, an error occured while removing the B³ file !"),
      $q->p("Contact your webobs administrator, and see your web server logs
        for more information.");
}


##----------------------------------------------------------------------------
# Main actions
#

# Verify consistancy and authorization
if (not (clientHasEdit(type=>"authprocs",name=>"MC") || clientHasEdit(type=>"authprocs",name=>"$mc3")
         || clientHasAdm(type=>"authprocs",name=>"MC") || clientHasAdm(type=>"authprocs",name=>"$mc3"))) {
  show_unauthorized($q);
  exit(0);
}

# Delete the file
if (delete_b3_files($b3_name) != 0) {
  show_error($q);
  exit(0);
}

# Confirm removal of B3
show_confirmation_page($q, $b3_name);


