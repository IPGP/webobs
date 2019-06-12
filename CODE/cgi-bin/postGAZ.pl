#!/usr/bin/perl

=head1 NAME

postGAZ.pl 

=head1 SYNOPSIS

http://..../postGAZ.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

Ce script permet la mise à jour des données d'analyse des
eaux de l'OVSG, fournis par la page "formGAZ.pl".
 
=head1 Configuration GAZ 

Voir 'showGAZ.pl' pour un exemple de fichier configuration 'GAZ.conf'

=head1 Query string parameters

1 paramètre par champ d'un enregistrement du fichier données de GAZ : 

=over

=item B<id=>

=item B<annee=>

=item B<mois=>

=item B<jour=>

=item B<hr=>

=item B<mn=>

=item B<site=>

=item B<type=>

=item B<tAir=>

=item B<tSource=>

=item B<pH=>

=item B<cond=>

=item B<debit=>

=item B<niveau=>

=item B<rem=>

=item B<cLi=>

=item B<cNa=>

=item B<cK=>

=item B<cMg=>

=item B<cCa=>

=item B<cF=>

=item B<cCl=>

=item B<cBr=>

=item B<cNO3=>

=item B<cSO4=>

=item B<cHCO3=>

=item B<cI=>

=item B<d13C=>

=item B<d18O=>

=item B<dD=>

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

die "You can't edit GAZ reports." if (!clientHasEdit(type=>"authforms",name=>"GAZ"));

my $FORM = new WebObs::Form('GAZ');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# ---- Recuperation des donnees du formulaire
# 
my $annee = $cgi->param('annee');
my $mois  = $cgi->param('mois');
my $jour  = $cgi->param('jour');
my $hr    = $cgi->param('hr');
my $mn    = $cgi->param('mn');
my $site  = $cgi->param('site');
my $tFum  = $cgi->param('tFum');
my $pH    = $cgi->param('pH');
my $debit = $cgi->param('debit');
my $Rn    = $cgi->param('Rn');
my $type  = $cgi->param('type');
my $H2    = $cgi->param('H2');
my $He    = $cgi->param('He');
my $CO    = $cgi->param('CO');
my $CH4   = $cgi->param('CH4');
my $N2    = $cgi->param('N2');
my $H2S   = $cgi->param('H2S');
my $Ar    = $cgi->param('Ar');
my $CO2   = $cgi->param('CO2');
my $SO2   = $cgi->param('SO2');
my $O2    = $cgi->param('O2');
my $d13C  = $cgi->param('d13C');
my $d18O  = $cgi->param('d18O');
my $rem   = $cgi->param('rem');

my $val    = $cgi->param('val');
my $oper   = $cgi->param('oper');
my $idTraite = $cgi->param('id') // '';
my $delete = $cgi->param('delete');

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
my $entete = u2l("Id|Date|Heure|Site|Tfum|pH|Debit|Rn|Amp|H2|He|CO|CH4|N2|H2S|Ar|CO2|SO2|O2|d13C|d18O|Observations|Valider\n");

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postGAZ waiting for lock on $fileDATA...";
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
		my $chaine = u2l("$newID|$date|$heure|$site|$tFum|$pH|$debit|$Rn|$type|$H2|$He|$CO|$CH4|$N2|$H2S|$Ar|$CO2|$SO2|$O2|$d13C|$d18O|$rem|$val\n");
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
		htmlMsgNotOK("postGAZ couldn't backup $fileDATA ");
	}
} else {
	htmlMsgNotOK("postGAZ opening - $!");
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

