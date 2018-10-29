#!/usr/bin/perl

=head1 NAME

postBOJAP.pl 

=head1 SYNOPSIS

http://..../postBOJAP.pl?.... voir 'Query string parameters'.... 

=head1 DESCRIPTION

Ce script permet la mise à jour des données d'analyse des
boites japonaises de l'OVSG, fournies par le script "formBOJAP.pl".
 
=head1 Configuration BOJAP

Voir 'showBOJAP.pl' pour une exemple de fichier de configuration 'BOJAP.conf'

=head1 Query string parameters

1 paramètre par champ d'un enregistrement du fichier données de BOJAP :

=over

=item B<idTraite>

=item B<annee1>

=item B<mois1>

=item B<jour1>

=item B<hr1>

=item B<mn1>

=item B<annee2>

=item B<mois2>

=item B<jour2>

=item B<hr2>

=item B<mn2>

=item B<site>

=item B<rem>

=item B<cCl>

=item B<cCO2>

=item B<cSO4>

=item B<m1>

=item B<m2>

=item B<m3>

=item B<m4>

=item B<h2o>

=item B<koh>

=item B<oper>

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

die "You can't edit BOJAP reports." if (!clientHasEdit(type=>"authforms",name=>"BOJAP"));

my $FORM = new WebObs::Form('BOJAP');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# ---- Recuperation des donnees du formulaire
# 
my $annee1  = $cgi->param('annee1') || "";
my $mois1   = $cgi->param('mois1') || "";
my $jour1   = $cgi->param('jour1') || "";
my $hr1     = $cgi->param('hr1') || "";
my $mn1     = $cgi->param('mn1') || "";
my $annee2  = $cgi->param('annee2') || "";
my $mois2   = $cgi->param('mois2') || "";
my $jour2   = $cgi->param('jour2') || "";
my $hr2     = $cgi->param('hr2') || "";
my $mn2     = $cgi->param('mn2') || "";
my $site    = $cgi->param('site') || "";
my $rem     = $cgi->param('rem') || "";
my $cCl     = $cgi->param('cCl') || "";
my $cCO2    = $cgi->param('cCO2') || "";
my $cSO4    = $cgi->param('cSO4') || "";
my $m1      = $cgi->param('m1') || "";
my $m2      = $cgi->param('m2') || "";
my $m3      = $cgi->param('m3') || "";
my $m4      = $cgi->param('m4') || "";
my $h2o     = $cgi->param('h2o') || "";
my $koh     = $cgi->param('koh') || "";

my $oper    = $cgi->param('oper') || "";
my $val     = $cgi->param('val')  || "";
my $idTraite = $cgi->param('id') || "";

my $date1 = $annee1."-".$mois1."-".$jour1;
if ($hr1 ne "") { $hr1 = $hr1.":".$mn1; }
my $date2 = $annee2."-".$mois2."-".$jour2;
if ($hr2 ne "") { $hr2 = $hr2.":".$mn2; }
my $stamp = "[$today $oper]";
if (index($val,$stamp) eq -1) {$val = "$stamp $val"; };

# ----
my @lignes;
my $maxId = 0;
my $entete = u2l("Id|Date1|Heure1|Date2|Heure2|Site|C_Cl|C_C02|C_SO4|M1|M2|M3|M4|H2O|KOH|Remarques|Valider\n");
if (-e $fileDATA)  {

	# ---- lock-exclusive the data file during all update process
	#
	if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postBOJAP waiting for lock on $fileDATA...";
			flock(FILE, LOCK_EX);
		}
		# ---- backup BOJAP file (To Be Removed: lifecycle too short to be used ) 
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
			my $chaine = u2l("$maxId|$date1|$hr1|$date2|$hr2|$site|$cCl|$cCO2|$cSO4|$m1|$m2|$m3|$m4|$h2o|$koh|$rem|$val\n");
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
			htmlMsgNotOK("postBOJAP couldn't backup $fileDATA");
		}
	} else {
		htmlMsgNotOK("postBOJAP opening - $!");
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

