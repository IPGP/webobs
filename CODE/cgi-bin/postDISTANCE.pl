#!/usr/bin/perl

=head1 NAME

postDISTANCE.pl 

=head1 SYNOPSIS

http://..../postDISTANCE.pl?.... voir 'Query string parameters'.... 

=head1 DESCRIPTION

Ce script permet la mise à jour des données de
distancemétrie de l'OVSG, à partir du script "formDISTANCE.pl".
 
=head1 Configuration DISTANCE 

Voir 'showDISTANCE.pl' pour un exemple de fichier configuration 'DISTANCE.conf'

=head1 Query string parameters

1 paramètre par champ d'un enregistrement du fichier données de DISTANCE :

=over 

=item B<id>

=item B<annee>

=item B<mois>

=item B<jour>

=item B<hr>

=item B<mn>

=item B<site>

=item B<aemd>

=item B<pAtm>

=item B<tAir>

=item B<HR>

=item B<nebul>

=item B<vitre>

=item B<D0>

=item B<d01> to B<d20>

=item B<oper>

=item B<rem>

=item B<val>

=back

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
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- standard FORMS inits ----------------------------------

die "You can't edit DISTANCE reports." if (!clientHasEdit(type=>"authforms",name=>"DISTANCE"));

my $FORM = new WebObs::Form('DISTANCE');
my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# Recuperation des donnees du formulaire
# 
my $annee  = $cgi->param('annee');
my $mois   = $cgi->param('mois');
my $jour   = $cgi->param('jour');
my $hr     = $cgi->param('hr');
my $mn     = $cgi->param('mn');
my $site   = $cgi->param('site');
my $aemd   = $cgi->param('aemd');
my $pAtm   = $cgi->param('pAtm');
my $tAir   = $cgi->param('tAir');
my $HR     = $cgi->param('HR');
my $nebul  = $cgi->param('nebul');
my $vitre  = $cgi->param('vitre');
my $D0     = $cgi->param('D0');
my $d01    = $cgi->param('d01');
my $d02    = $cgi->param('d02');
my $d03    = $cgi->param('d03');
my $d04    = $cgi->param('d04');
my $d05    = $cgi->param('d05');
my $d06    = $cgi->param('d06');
my $d07    = $cgi->param('d07');
my $d08    = $cgi->param('d08');
my $d09    = $cgi->param('d09');
my $d10    = $cgi->param('d10');
my $d11    = $cgi->param('d11');
my $d12    = $cgi->param('d12');
my $d13    = $cgi->param('d13');
my $d14    = $cgi->param('d14');
my $d15    = $cgi->param('d15');
my $d16    = $cgi->param('d16');
my $d17    = $cgi->param('d17');
my $d18    = $cgi->param('d18');
my $d19    = $cgi->param('d19');
my $d20    = $cgi->param('d20');
my $oper   = $cgi->param('oper');
my $rem    = $cgi->param('rem');
my $val    = $cgi->param('val');
my $idTraite = $cgi->param('id') // "";

my $date   = "$annee-$mois-$jour";
my $heure  = "$hr:$mn";
my $stamp  = "[$today $oper]";
if (index($val,$stamp) eq -1) {$val = "$stamp $val"; };

# ----
my @d;
my @lignes;
my $maxId = 0;
my $entete = u2l("Id|Date|Heure|Site|AEMD|Patm (mmHg)|Tair (°C)|H.R. (%)|Nébulosité|Vitre|D0|d01|d02|d03|d04|d05|d06|d07|d08|d09|d10|d11|d12|d13|d14|d15|d16|d17|d18|d19|d20|Remarques|Valide\n");
if (-e $fileDATA)  {

	# ---- lock-exclusive the data file during all update process
	#
	if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postDISTANCE waiting for lock on $fileDATA...";
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
					#djl next if ( ($idTraite eq $id) && ($efface eq "oui") ); 
					if ( ($idTraite eq "") || ($idTraite ne $id) ) { 
						push(@lignes,$_."\n") ;
					}
				}
			}
			$maxId++;
			my $chaine = "$maxId|$date|$heure|$site|$aemd|$pAtm|$tAir|$HR|$nebul|$vitre|$D0";
			for ('01'..'20') {
				$chaine = $chaine."|".eval("\$d$_");
			}
			$chaine = $chaine."|$rem|$val\n";
			push(@lignes, $chaine);
			@lignes = sort tri_date_avec_id @lignes;
			truncate(FILE, 0);
			seek(FILE, 0, SEEK_SET);
			print FILE $entete;
			print FILE @lignes ;
			close(FILE);
			htmlMsgOK();
		} else {
			close(FILE);
			htmlMsgNotOK("postDISTANCE couldn't backup $fileDATA");
		}
	} else {
		htmlMsgNotOK("postDISTANCE opening - $!");
	}
}

# --- return information when OK 
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	if ($idTraite ne "") { 
 		print "record #$idTraite has been updated (as #$maxId)"; 
 	} else  { print "new record #$maxId has been created."; }
}

# --- return information when not OK
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

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

