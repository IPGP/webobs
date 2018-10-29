#!/usr/bin/perl

=head1 NAME

postRIVERS.pl 

=head1 SYNOPSIS

http://..../postRIVERS.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

This script allows the update of Obsera river analysis data,
sent by "formRIVERS.pl" page.
 
=head1 Configuration RIVERS 

See 'showRIVERS.pl' for a configuration file 'RIVERS.conf' example

=head1 Query string parameters

1 parameter per record field of the RIVERS datafile : 

=over

=item B<id=>

=item B<annee=>

=item B<mois=>

=item B<jour=>

=item B<hr=>

=item B<mn=>

=item B<site=>

=item B<level=>

=item B<type=>

=item B<flacon=>

=item B<tRiver=>

=item B<suspendedLoad=>

=item B<rem=>

=item B<pH=>

=item B<cond25=>

=item B<cond=>

=item B<cNa=>

=item B<cK=>

=item B<cMg=>

=item B<cCa=>

=item B<cHCO3=>

=item B<cCl=>

=item B<cSO4=>

=item B<cSiO2=>

=item B<cDOC=>

=item B<dPOC=>

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

die "You can't edit RIVERS reports." if (!clientHasEdit(type=>"authforms",name=>"RIVERS"));

my $FORM = new WebObs::Form('RIVERS');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# ---- Recuperation des donnees du formulaire
# 
my $annee        = $cgi->param('annee');
my $mois         = $cgi->param('mois');
my $jour         = $cgi->param('jour');
my $hr           = $cgi->param('hr');
my $mn           = $cgi->param('mn');
my $site         = $cgi->param('site');
my $level        = $cgi->param('level');
my $type         = $cgi->param('type');
my $flacon       = $cgi->param('flacon');
my $tRiver       = $cgi->param('tRiver');
my $suspendedLoad= $cgi->param('suspendedLoad');
my $rem          = $cgi->param('rem');
my $pH           = $cgi->param('pH');
my $cond25       = $cgi->param('cond25');
my $cond         = $cgi->param('cond');
my $cNa          = $cgi->param('cNa');
my $cK           = $cgi->param('cK');
my $cMg          = $cgi->param('cMg');
my $cCa          = $cgi->param('cCa');
my $cHCO3        = $cgi->param('cHCO3');
my $cCl          = $cgi->param('cCl');
my $cSO4         = $cgi->param('cSO4');
my $cSiO2        = $cgi->param('cSiO2');
my $cDOC         = $cgi->param('cDOC');
my $cPOC         = $cgi->param('cPOC');

my $val          = $cgi->param('val');
my $oper         = $cgi->param('oper');
my $idTraite     = $cgi->param('id') || "";
my $delete       = $cgi->param('delete');

my $date   = $annee."-".$mois."-".$jour;
my $heure  = "";
if ($hr ne "") { $heure = $hr.":".$mn; }
my $stamp = "[$today $oper]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

# ----

my @lignes;
my $maxId = 0;
my $msg = "";
my $newID;
my $entete = u2l("ID|Date|Hour|Site|Level|Type|Flask|Twater (°C)|Suspended Load|pH|Conductivity at 25°C|Conductivity|Na|K|Mg|Ca|HCO3|Cl|SO4|SiO2|DOC|POC|Comment|Validate\n");

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postRIVERS waiting for lock on $fileDATA...";
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
					push(@lignes,$_."\n") ;
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
		my $chaine = u2l("$newID|$date|$heure|$site|$level|$type|$flacon|$tRiver|$suspendedLoad|$pH|$cond25|$cond|$cNa|$cK|$cMg|$cCa|$cHCO3|$cCl|$cSO4|$cSiO2|$cDOC|$cPOC|$rem|$val\n");
		if ($delete < 2) {
			push(@lignes, $chaine);
		} else {
			$msg = "Record #$idTraite has been definitively deleted !";
		}
		@lignes = sort tri_date_avec_id @lignes;
		truncate(FILE, 0);
		seek(FILE, 0, SEEK_SET);
		print FILE $entete;
		print FILE @lignes ;
		close(FILE);
		htmlMsgOK();
	} else {
		close(FILE);
		htmlMsgNotOK("postRIVERS couldn't backup $fileDATA ");
	}
} else {
	htmlMsgNotOK("postRIVERS opening - $!");
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

Francois Beauducel, Didier Lafon, Jean-Marie Saurel

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

