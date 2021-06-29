#!/usr/bin/perl

=head1 NAME

postSOILSOLUTION.pl

=head1 SYNOPSIS

http://..../postSOILSOLUTION.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

Updates the data file for rain water chemical analysis,
called by "formSOILSOLUTION.pl".

=head1 Configuration SOILSOLUTION

See 'showSOILSOLUTION.pl' for an example of configuration file 'SOILSOLUTION.conf'

=head1 Query string parameters
parameters from each field:

=over

=item B<id=>

=item B<y1=>

=item B<m1=>

=item B<d1=>

=item B<hr1=>

=item B<mn1=>

=item B<y2=>

=item B<m2=>

=item B<d2=>

=item B<hr2=>

=item B<mn2=>

=item B<site=>

=item B<depth=>

=item B<level=>

=item B<pH=>

=item B<cond=>

=item B<rem=>

=item B<cNa=>

=item B<cK=>

=item B<cMg=>

=item B<cCa=>

=item B<cCl=>

=item B<cNO3=>

=item B<cSO4=>

=item B<cHCO3=>

=item B<cSiO2=>

=item B<cDOC=>

=item B<val=>

=item B<oper=>

=item B<delete=> { 0 | 1 | 2 }
 - void or 0 = modify data
  - 1 = to/from trash (changes sign of ID, ID<0 = in trash)
   - 2 = delete (removes from database)

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- standard FORMS inits ----------------------------------

die "You can't edit SOILSOLUTION reports." if (!clientHasEdit(type=>"authforms",name=>"SOILSOLUTION"));

my $FORM = new WebObs::Form('SOILSOLUTION');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# ---- Get the data from the form
#
my $y1     = $cgi->param('y1');
my $m1     = $cgi->param('m1');
my $d1     = $cgi->param('d1');
my $hr1    = $cgi->param('hr1');
my $mn1    = $cgi->param('mn1');
my $y2     = $cgi->param('y2');
my $m2     = $cgi->param('m2');
my $d2     = $cgi->param('d2');
my $hr2    = $cgi->param('hr2');
my $mn2    = $cgi->param('mn2');
my $site   = $cgi->param('site');
my $depth  = $cgi->param('depth');
my $level  = ($cgi->param('level') ne "" ? "1":"0");
my $pH     = $cgi->param('pH');
my $cond   = $cgi->param('cond');
my $rem    = $cgi->param('rem');
my $cNa    = $cgi->param('cNa');
my $cK     = $cgi->param('cK');
my $cMg    = $cgi->param('cMg');
my $cCa    = $cgi->param('cCa');
my $cHCO3  = $cgi->param('cHCO3');
my $cCl    = $cgi->param('cCl');
my $cNO3   = $cgi->param('cNO3');
my $cSO4   = $cgi->param('cSO4');
my $cSiO2  = $cgi->param('cSiO2');
my $cDOC   = $cgi->param('cDOC');

my $val    = $cgi->param('val');
my $oper   = $cgi->param('oper');
my $idTraite = $cgi->param('id') // "";
my $delete = $cgi->param('delete');

my $date1 = $y1."-".$m1."-".$d1;
my $date2 = $y2."-".$m2."-".$d2;
my $time1 = ($hr1 ne "" ? "$hr1:$mn1":"");
my $time2 = ($hr2 ne "" ? "$hr2:$mn2":"");
my $stamp = "[$today $oper]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

# ----

my @lines;
my $maxId = 0;
my $msg = "";
my $newID;
my $header = u2l("ID|Date2|Time2|Site|Date1|Time1|Depth (cm)|Level|pH|Cond. (µS)|Na (ppm)|K (ppm)|Mg (ppm)|Ca (pmm)|HCO3 (ppm)|Cl (ppm)|NO3 (ppm)|SO4 (ppm)|SiO2 (ppm)|DOC (ppm)|Comments|Valid\n");

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postSOILSOLUTION waiting for lock on $fileDATA...";
		flock(FILE, LOCK_EX);
	}
	# ---- backup file (To Be Removed: lifecycle too short to be used )
	if (-e $fileDATA) { qx(cp -a $fileDATA $fileDATA~ 2>&1); }
	if ( $?  == 0 ) {
		seek(FILE, 0, SEEK_SET);
		while (<FILE>) {
	   		chomp($_);
			my ($id) = split(/\|/,$_);
			if ($id =~ m/^[0-9]+$/) {
				if ($id > $maxId) { $maxId = $id }
				if (($idTraite ne $id)) {
					push(@lines,$_."\n") ;
				}
			}
		}
		if ($idTraite ne "") {
			if ($delete > 0) {
				# effacement: changement de signe de l'ID
				$newID = -($idTraite);
				$msg = "Delete/recover existing record #$idTraite (in/from trash).";
			} else {
				$newID = $idTraite;
				$msg = "Record #$idTraite has been updated.";
			}
		} else {
			$newID = ++$maxId;
			$msg = "new record #$newID has been created.";
		}
		my $string = u2l("$newID|$date2|$time2|$site|$date1|$time1|$depth|$level|$pH|$cond|$cNa|$cK|$cMg|$cCa|$cHCO3|$cCl|$cNO3|$cSO4|$cSiO2|$cDOC|$rem|$val\n");
		if ($delete < 2) {
			push(@lines, $string);
		} else {
			$msg = "Record #$idTraite has been definitively deleted !";
		}
		@lines = sort tri_date_avec_id @lines;
		truncate(FILE, 0);
		seek(FILE, 0, SEEK_SET);
		print FILE $header;
		print FILE @lines ;
		close(FILE);
		htmlMsgOK();
	} else {
		close(FILE);
		htmlMsgNotOK("postSOILSOLUTION couldn't backup $fileDATA ");
	}
} else {
	htmlMsgNotOK("postSOILSOLUTION opening - $!");
}

# --- return information when OK
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$msg";
}

# --- return information when not OK
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel

=head1 COPYRIGHT

Webobs - 2012-2021 - Institut de Physique du Globe Paris

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
