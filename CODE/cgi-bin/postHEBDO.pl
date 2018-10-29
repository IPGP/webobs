#!/usr/bin/perl 
#
=head1 NAME

postHEBDO.pl 

=head1 SYNOPSIS

target of 'post' action from formHEBDO.pl 
 $.post("/cgi-bin/postHEBDO.pl", ....) 

=head1 DESCRIPTION

process html form from "formHEBDO" and update HEBDO file accordingly.

=cut

use strict;
use warnings;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

# ---- webobs stuff 
use WebObs::Config;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- HEBDO definitions and HEBDO file
my %HEBDO = readCfg($WEBOBS{HEBDO_CONF});
my $fileHebdo = "$HEBDO{FILE_NAME}";

# get & parse the http query string (url-param)
# -------------------------------------------------
my $efface      = $cgi->param('supprime');
my @nom         = $cgi->param('nom');
my $nomAutres   = $cgi->param('nomAutres');
my $anneeDepart = $cgi->param('anneeDepart');
my $moisDepart  = $cgi->param('moisDepart');
my $jourDepart  = $cgi->param('jourDepart');
my $anneeFin    = $cgi->param('anneeFin');
my $moisFin     = $cgi->param('moisFin');
my $jourFin     = $cgi->param('jourFin');
my $heureDepart = $cgi->param('heureDepart');
my $minDepart   = $cgi->param('minuteDepart');
my $heureFin    = $cgi->param('heureFin');
my $minFin      = $cgi->param('minuteFin');
my $dateNA      = $cgi->param('dateNA') || "";
my $typeEvnt    = $cgi->param('typeEvenement');
my $comment     = $cgi->param('commentEvenement');
my $lieuEvnt    = $cgi->param('lieuEvenement');
my $idTraite    = $cgi->param('id') || "";
my $timeDepart  = "";
my $timeFin     = "";

# ---- misc. init
my $nomPersonnel = join("+",@nom);
my $dateDepart = $anneeDepart."-".$moisDepart."-".$jourDepart;
if (($heureDepart eq "") || ($minDepart eq "")) { $timeDepart = ""; } else { $timeDepart = $heureDepart.":".$minDepart; }
my $dateFin = $anneeFin."-".$moisFin."-".$jourFin;
if (($heureFin eq "") || ($minFin eq "")) { $timeFin = ""; } else { $timeFin = $heureFin.":".$minFin; }
if ($dateNA eq "NA") { $dateDepart = "" ; $dateFin = ""; }

my @tod = localtime(); 
my $maxId = 0;
my $id = 0;
my @lines = '';
my $header = "Id|Date1|H1|Date2|H2|Type|OVSG|Autres|Lieu|Objet|*\n";
 
# ---- lock-exclusive the HEBDO file during all update process
#
if ( sysopen(FILE, "$fileHebdo", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postHEBDO waiting for lock on $fileHebdo...";
		flock(FILE, LOCK_EX);
	}
	# ---- backup HEBDO file (To Be Removed: lifecycle too short to be used in real recovery) 
	qx(cp -a $fileHebdo $fileHebdo~ 2>&1); 
	if ( $?  == 0 ) { 
		seek(FILE, 0, SEEK_SET);
		while (<FILE>) {
			my ($id) = split(/\|/,$_);
			if ($id =~ m/^[0-9]+$/) {
				if ($id > $maxId) { $maxId = $id }	
				#djl next if ( ($idTraite eq $id) && ($efface eq "oui") ); 
				if ( ($idTraite eq "") || ($idTraite ne $id) ) { 
					push(@lines,$_) ;
				}
			}
		}
		#if ($efface ne "oui") {
		if (!$efface) {
			$maxId++;
			my $newRec = u2l("$maxId|$dateDepart|$timeDepart|$dateFin|$timeFin|$typeEvnt|$nomPersonnel|$nomAutres|$lieuEvnt|$comment\n");
			push(@lines, $newRec);
			@lines = sort tri_date_avec_id @lines;
		} 
		truncate(FILE, 0);
		seek(FILE, 0, SEEK_SET);
		print FILE $header;
		print FILE @lines ;
		close(FILE);
		htmlMsgOK();
	} else {
		close(FILE);
		htmlMsgNotOK("postHEBDO couldn't backup $fileHebdo");
	}
} else {
	htmlMsgNotOK("postHEBDO opening - $!");
}

# --- return information when OK 
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	if ($idTraite ne "") { 
 		if (!$efface) { print "record #$idTraite has been updated (as #$maxId ."; }
 		else { print "record #$idTraite has been erased."; }
 	} else  { print "new record #$maxId has been created."; }
}

# --- return information when not OK
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

