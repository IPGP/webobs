#!/usr/bin/perl

=head1 NAME

postPLUVIO.pl 

=head1 SYNOPSIS

http://..../postPLUVIO.pl?.... voir 'Query string parameters'....

=head1 DESCRIPTION

Ce script permet la mise à jour des données de
pluviométrie de l'OVSG, fournis par le script "formPLUVIO.pl".
 
=head1 Configuration PLUVIO 

Voir 'showPLUVIO.pl' pour un exemple de fichier de configuration 'PLUVIO.conf':

=head1 Query string parameters

=over

=item B<id=>

=item B<annee=>

=item B<mois=>

=item B<site=>

=item couples B<d01= , v01=>  à  B<d31= , v31=>

=item B<oper=>

=item B<val=>

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

die "You can't edit PLUVIO reports." if (!clientHasEdit(type=>"authforms",name=>"PLUVIO"));

my $FORM = new WebObs::Form('PLUVIO');
my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
	my %N = $FORM->nodes($p);
	for my $n (keys(%N)) {
		push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
	}
	%Ns = (%Ns, %N);
}
my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

my $date;
my $heure;

# Recuperation des donnees du formulaire
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $annee = $cgi->param('annee');
my $mois  = $cgi->param('mois');
my $site  = $cgi->param('site');
my $d01   = $cgi->param('d01');
my $v01   = $cgi->param('v01');
my $d02   = $cgi->param('d02');
my $v02   = $cgi->param('v02');
my $d03   = $cgi->param('d03');
my $v03   = $cgi->param('v03');
my $d04   = $cgi->param('d04');
my $v04   = $cgi->param('v04');
my $d05   = $cgi->param('d05');
my $v05   = $cgi->param('v05');
my $d06   = $cgi->param('d06');
my $v06   = $cgi->param('v06');
my $d07   = $cgi->param('d07');
my $v07   = $cgi->param('v07');
my $d08   = $cgi->param('d08');
my $v08   = $cgi->param('v08');
my $d09   = $cgi->param('d09');
my $v09   = $cgi->param('v09');
my $d10   = $cgi->param('d10');
my $v10   = $cgi->param('v10');
my $d11   = $cgi->param('d11');
my $v11   = $cgi->param('v11');
my $d12   = $cgi->param('d12');
my $v12   = $cgi->param('v12');
my $d13   = $cgi->param('d13');
my $v13   = $cgi->param('v13');
my $d14   = $cgi->param('d14');
my $v14   = $cgi->param('v14');
my $d15   = $cgi->param('d15');
my $v15   = $cgi->param('v15');
my $d16   = $cgi->param('d16');
my $v16   = $cgi->param('v16');
my $d17   = $cgi->param('d17');
my $v17   = $cgi->param('v17');
my $d18   = $cgi->param('d18');
my $v18   = $cgi->param('v18');
my $d19   = $cgi->param('d19');
my $v19   = $cgi->param('v19');
my $d20   = $cgi->param('d20');
my $v20   = $cgi->param('v20');
my $d21   = $cgi->param('d21');
my $v21   = $cgi->param('v21');
my $d22   = $cgi->param('d22');
my $v22   = $cgi->param('v22');
my $d23   = $cgi->param('d23');
my $v23   = $cgi->param('v23');
my $d24   = $cgi->param('d24');
my $v24   = $cgi->param('v24');
my $d25   = $cgi->param('d25');
my $v25   = $cgi->param('v25');
my $d26   = $cgi->param('d26');
my $v26   = $cgi->param('v26');
my $d27   = $cgi->param('d27');
my $v27   = $cgi->param('v27');
my $d28   = $cgi->param('d28');
my $v28   = $cgi->param('v28');
my $d29   = $cgi->param('d29');
my $v29   = $cgi->param('v29');
my $d30   = $cgi->param('d30');
my $v30   = $cgi->param('v30');
my $d31   = $cgi->param('d31');
my $v31   = $cgi->param('v31');
my $oper  = $cgi->param('oper');
my $val   = $cgi->param('val');
my $idTraite = $cgi->param('id') || "";

# tampon date et oprateur
my $stamp = "[$today $oper]";
if (index($val,$stamp) eq -1) {$val = "$stamp $val"; };

# ----
my @lignes;
my $maxId = 0;
my $entete = u2l("Id|Annee|Mois|Site|D01|V01|D02|V02|D03|V03|D04|V04|D05|V05|D06|V06|D07|V07|D08|V08|D09|V09|D10|V10|D11|V11|D12|V12|D13|V13|D14|V14|D15|V15|D16|V16|D17|V17|D18|V18|D19|V19|D20|V20|D21|V21|D22|V22|D23|V23|D24|V24|D25|V25|D26|V26|D27|V27|D28|V28|D29|V29|D30|V30|D31|V31|Valider\n");
if (-e $fileDATA)  {
	# ---- lock-exclusive the data file during all update process
	#
	if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postPLUVIO waiting for lock on $fileDATA...";
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
			my $chaine = "$maxId|$annee|$mois|$site";
			for ("01".."31") {
				$chaine = $chaine."|".eval("\$d$_")."|".eval("\$v$_");
			}
			$chaine = $chaine."|$val\n";
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
			htmlMsgNotOK("postPLUVIO couldn't backup $fileDATA");
		}
	} else {
		htmlMsgNotOK("postPLUVIO opening - $!");
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

