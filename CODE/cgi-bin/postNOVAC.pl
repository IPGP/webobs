#!/usr/bin/perl

=head1 NAME

postNOVAC.pl 

=head1 SYNOPSIS

http://..../postNOVAC.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

Ce script permet la mise à jour des données d'analyse des
eaux de l'OVSG, fournis par la page "formNOVAC.pl".
 
=head1 Configuration NOVAC 

Voir 'showNOVAC.pl' pour un exemple de fichier configuration 'NOVAC.conf'

=head1 Query string parameters

1 parametre par champ d'un enregistrement du fichier données deNOVAC : 

=over

=item B<id=>

=item B<annee=>

=item B<mois=>

=item B<jour=>

=item B<site=>

=item B<flux1=>

=item B<flux2=>

=item B<windSpeed=>

=item B<windSpeedSource=>

=item B<windDirection=>

=item B<windDirectionSource=>

=item B<compassDirection=>

=item B<coneAngle=>

=item B<tilt=>

=item B<plumeHeight=>

=item B<plumeHeightSource=>

=item B<offset=>

=item B<plumeCentre=>

=item B<plumeEdge1=>

=item B<plumeEdge2=>

=item B<plumeCompleteness=>

=item B<geomError=>

=item B<spectrometerError=>

=item B<scatteringError=>

=item B<windError=>

=item B<nbValidScans=>

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

die "You can't edit NOVAC reports." if (!clientHasEdit(type=>"authforms",name=>"NOVAC"));

my $FORM = new WebObs::Form('NOVAC');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# ------------------------------------------------------------
# ---- start of specific NOVAC form data retrieval -----------
# ------------------------------------------------------------
my $annee   = $cgi->param('annee');
my $mois    = $cgi->param('mois');
my $jour    = $cgi->param('jour');
my $site    = $cgi->param('site');
my $flux1   = $cgi->param('flux1');
my $flux2   = $cgi->param('flux2');
my $windSpeed = $cgi->param('windSpeed');
my $windSpeedSource = $cgi->param('windSpeedSource');
my $windDirection = $cgi->param('windDirection');
my $windDirectionSource = $cgi->param('windDirectionSource');
my $compassDirection = $cgi->param('compassDirection');
my $coneAngle = $cgi->param('coneAngle');
my $tilt = $cgi->param('tilt');
my $plumeHeight = $cgi->param('plumeHeight');
my $plumeHeightSource = $cgi->param('plumeHeightSource');
my $offset = $cgi->param('offset');
my $plumeCentre = $cgi->param('plumeCentre');
my $plumeEdge1 = $cgi->param('plumeEdge1');
my $plumeEdge2 = $cgi->param('plumeEdge2');
my $plumeCompleteness = $cgi->param('plumeCompleteness');
my $geomError = $cgi->param('geomError');
my $spectrometerError = $cgi->param('spectrometerError');
my $scatteringError = $cgi->param('scatteringError');
my $windError = $cgi->param('windError');
my $nbValidScans = $cgi->param('nbValidScans');
my $idTraite = $cgi->param('id') // "";
my $delete = $cgi->param('delete');

my $date   = $annee."-".$mois."-".$jour;

# ----

my @lignes;
my $maxId = 0;
my $msg = "";
my $newID;
my $entete = u2l("Id|Date|Site|Flux1|Flux2|WindSpeed|WindSpeedSource|WindDirection|WindDirectionSource|CompassDirection|ConeAngle|Tilt|PlumeHeight|PlumeHeightSource|Offset|PlumeCenter|PlumeEdge1|PlumeEdge2|PlumeCompleteness|GeomError|SpectrometerError|ScatteringError|WindError|NbValidScans\n");
# ------------------------------------------------------------
# ---- end of specific NOVAC form data retrieval -------------
# ------------------------------------------------------------

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postNOVAC waiting for lock on $fileDATA...";
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
		# ------------------------------------------------------------
		# ---- start of specific NOVAC data creation -----------------
		# ------------------------------------------------------------
		my $chaine = u2l("$newID|$date|$site|$flux1|$flux2|$windSpeed|$windSpeedSource|$windDirection|$windDirectionSource|$compassDirection|$coneAngle|$tilt|$plumeHeight|$plumeHeightSource|$offset|$plumeCentre|$plumeEdge1|$plumeEdge2|$plumeCompleteness|$geomError|$spectrometerError|$scatteringError|$windError|$nbValidScans\n");
		# ------------------------------------------------------------
		# ---- end of specific NOVAC data creation -------------------
		# ------------------------------------------------------------
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
		htmlMsgNotOK("postNOVAC couldn't backup $fileDATA ");
	}
} else {
	htmlMsgNotOK("postNOVAC opening - $!");
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

Francois Beauducel, Didier Lafon, Patrice Boissier

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

