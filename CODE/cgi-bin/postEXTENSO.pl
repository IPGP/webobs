#!/usr/bin/perl

=head1 NAME

postEXTENSO.pl 

=head1 SYNOPSIS

http://..../postEXTENSO.pl? 

=head1 DESCRIPTION

Ce script permet la mise à jour des données de
pluviométrie de l'OVSG, à partir de "formEXTENSO.pl".
 
=head1 Configuration EXTENSO 

Voir 'showEXTENSO.pl' pour un exemple de fichier configuration 'EXTENSO.conf'

=head1 Query string parameters

=item B<id=>

=item B<annee=>

=item B<mois=>

=item B<jour=>

=item B<hr=>

=item B<mn=>

=item B<site=>

=item B<oper=>

=item B<temp=>

=item B<meteo=>

=item B<ruban=>

=item B<offset=>

=item B<rem=>

=item B<val=>

=item B<f=> + B<c=> + B<v=> 

up to 9 '3-tuples' f,c,v

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

die "You can't edit EXTENSO reports." if (!clientHasEdit(type=>"authforms",name=>"EXTENSO"));

my $FORM = new WebObs::Form('EXTENSO');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);
my @donneeListe = ('1'..'9');	

my $date;
my $heure;

# Recuperation des donnees du formulaire
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $idTraite = $cgi->param('id') || "";
my $annee    = $cgi->param('annee');
my $mois     = $cgi->param('mois');
my $jour     = $cgi->param('jour');
my $hr       = $cgi->param('hr');
my $mn       = $cgi->param('mn');
my $site     = $cgi->param('site');
my @oper     = $cgi->param('oper');
my $operateurs = join("+",@oper);
my $temp     = $cgi->param('temp');
my $meteo    = $cgi->param('meteo');
my $ruban    = $cgi->param('ruban');
my $offset   = $cgi->param('offset');
my @d;
for (@donneeListe) {
	$d[$_-1][0] = $cgi->param('f'.$_);
	$d[$_-1][1] = $cgi->param('c'.$_);
	$d[$_-1][2] = $cgi->param('v'.$_);
}
my $rem = $cgi->param('rem');
my $val = $cgi->param('val');

my $date = "$annee-$mois-$jour";
my $heure = "$hr:$mn";
my @lignes;

# stamp date and staff
my $stamp = "[$today $CLIENT]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

my $maxId = 0;
my $entete = "ID|Date|Heure|Site|Opérateurs|Température|Météo|Ruban|Offset";
for (@donneeListe) { $entete = $entete."|F$_|C$_|V$_" }
$entete .= "|Remarques|Validation\n";

if (-e $fileDATA)  {
	# ---- lock-exclusive the data file during all update process
	#
	if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postEXTENSO waiting for lock on $fileDATA...";
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
					if ( ($idTraite eq "") || ($idTraite ne $id) ) { 
						push(@lignes,$_."\n") ;
					}
				}
			}
			$maxId++;
			my $chaine = u2l("$maxId|$date|$heure|$site|$operateurs|$temp|$meteo|$ruban|$offset");

			for (@donneeListe) {
				$chaine = $chaine."|$d[$_-1][0]|$d[$_-1][1]|$d[$_-1][2]";
			}
			$chaine = u2l($chaine."|$rem|$val\n");
			push(@lignes, $chaine);
			@lignes = reverse sort tri_date_avec_id @lignes;
			truncate(FILE, 0);
			seek(FILE, 0, SEEK_SET);
			print FILE $entete;
			print FILE @lignes ;
			close(FILE);
			htmlMsgOK();
		} else {
			close(FILE);
			htmlMsgNotOK("postEXTENSO couldn't backup $fileDATA");
		}
	} else {
		htmlMsgNotOK("postEXTENSO opening - $!");
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

