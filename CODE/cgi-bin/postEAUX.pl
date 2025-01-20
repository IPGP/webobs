#!/usr/bin/perl

=head1 NAME

postEAUX.pl 

=head1 SYNOPSIS

http://..../postEAUX.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

Ce script permet la mise à jour des données d'analyse des
eaux de l'OVSG, fournis par la page "formEAUX.pl".
 
=head1 Configuration EAUX 

Voir 'showEAUX.pl' pour un exemple de fichier configuration 'EAUX.conf'

=head1 Query string parameters

1 paramètre par champ d'un enregistrement du fichier données de EAUX : 

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

die "You can't edit EAUX reports." if (!clientHasEdit(type=>"authforms",name=>"EAUX"));

my $FORM = new WebObs::Form('EAUX');

my $fileDATA = $WEBOBS{PATH_DATA_DB}."/".$FORM->conf('FILE_NAME');

my $today = qx(date -I); chomp($today);

# ---- Recuperation des donnees du formulaire
# 
my $annee  = $cgi->param('annee');
my $mois   = $cgi->param('mois');
my $jour   = $cgi->param('jour');
my $hr     = $cgi->param('hr');
my $mn     = $cgi->param('mn');
my $site   = $cgi->param('site');
my $type   = $cgi->param('type');
my $tAir   = $cgi->param('tAir');
my $tSource= $cgi->param('tSource');
my $pH     = $cgi->param('pH');
my $cond   = $cgi->param('cond');
my $debit  = $cgi->param('debit');
my $niveau = $cgi->param('niveau');
my $rem    = $cgi->param('rem');
my $cLi    = $cgi->param('cLi');
my $cNa    = $cgi->param('cNa');
my $cK     = $cgi->param('cK');
my $cMg    = $cgi->param('cMg');
my $cCa    = $cgi->param('cCa');
my $cF     = $cgi->param('cF');
my $cCl    = $cgi->param('cCl');
my $cBr    = $cgi->param('cBr');
my $cNO3   = $cgi->param('cNO3');
my $cSO4   = $cgi->param('cSO4');
my $cHCO3  = $cgi->param('cHCO3');
my $cI     = $cgi->param('cI');
my $cSiO2  = $cgi->param('cSiO2');
my $d13C   = $cgi->param('d13C');
my $d18O   = $cgi->param('d18O');
my $dD     = $cgi->param('dD');

my $val    = $cgi->param('val');
my $oper   = $cgi->param('oper');
my $idTraite = $cgi->param('id') // "";
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
my $entete = u2l("ID|Date|Heure|Site|Type|Tair (°C)|Teau (°C)|pH|Débit (l/min)|Cond. (°C)|Niveau (m)|Li|Na|K|Mg|Ca|F|Cl|Br|NO3|SO4|HCO3|I|SiO2|d13C|d18O|dD|Remarques|Valider\n");

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
    unless (flock(FILE, LOCK_EX|LOCK_NB)) {
        warn "postEAUX waiting for lock on $fileDATA...";
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
        my $chaine = u2l("$newID|$date|$heure|$site|$type|$tAir|$tSource|$pH|$debit|$cond|$niveau|$cLi|$cNa|$cK|$cMg|$cCa|$cF|$cCl|$cBr|$cNO3|$cSO4|$cHCO3|$cI|$cSiO2|$d13C|$d18O|$dD|$rem|$val\n");
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
        htmlMsgNotOK("postEAUX couldn't backup $fileDATA ");
    }
} else {
    htmlMsgNotOK("postEAUX opening - $!");
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

