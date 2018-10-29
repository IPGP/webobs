#!/usr/bin/perl 

=head1 NAME

WebObs.pm  

=head1 DESCRIPTION

Webobs perl cgi utils  

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use File::Basename;
use i18n;

our %WEBOBS   = ( readCfg("/home/lafon/webobs/trunk/CONFIG/DL/WEBOBS.conf"), 
                  readCfg("/home/lafon/webobs/trunk/CONFIG/DL/WEBOBS.rc") );

use readGraph;

my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
my @graphKeys = keys(%graphStr);
my @users = readOperFile($WEBOBS{RACINE_FICHIERS_CONFIGURATION}."/".$WEBOBS{FILE_OPERATEURS},0);
my %userWEBOBS = readUser($ENV{"REMOTE_USER"});

my %nomOp;
for (0..$#users) {
        $nomOp{$users[$_][0]} = $users[$_][1];
}

=pod

B<readFile>
reads file contents into an array. All lines are read unfiltered/unchanged
 Input: required file name
 Output: an array, $array[i] is (i+1)th line of file

=cut 

sub readFile
{
	my $configFile=$_[0];
	my @contenu;
	if (-f $configFile) {
		open(FILE, "<$configFile") || die "WEBOBS: couldn't open file $configFile.\n";
		while(<FILE>) { push(@contenu,$_); }
		close(FILE);
	}
	return @contenu;
}

=pod

B<readCfgFile>
reads file contents into an array, converting lines to UTF8, 
and removing commented lines (# in col1), blank lines, and all \r (CR).
 Input: required file name
 Output: an array

=cut 

sub readCfgFile
{
	my $configFile=$_[0];
	my @contenu  = ("");
	open(FILE, "<$configFile") || die "WEBOBS: couldn't open file $configFile.\n";
	while(<FILE>) {
		$_ =~ s/\r//g;
		chomp($_);
		push(@contenu,l2u($_));
	}
	close(FILE);
	@contenu = grep(!/^#/, @contenu);
	@contenu = grep(!/^$/, @contenu);
	return @contenu;
}

=pod

B<readConfFile>
This script allows to read the main WEBOBS configuration
file "WEBOBS.conf", and returns a large hash %confStr containing
all configuration keys and values pairs.

With an optional argument, it reads any .conf file located in the
default Webobs configuration directory /etc/webobs that is defined
by a symbolic link pointing to the local configuration path, i.e.:
/etc/webobs -> /ipgp/webobs/CONFIG

file contents to hash, 
line = key|value read to  $hash{key}=value

 Input: file name
 Output: an array

=cut 

sub dlTBDreadConfFile
{
        my $webobs = 'WEBOBS.conf';
        if (@_) {
                $webobs = "$_[0]";
        }
        # --- defines the default Webobs configuration path
        my $configFile = "/etc/webobs/$webobs";

        my @config = ("");
        my %confStr;
        open(FILE, "<$configFile") || die "WEBOBS: file $configFile not found.\n";
        while(<FILE>) { push(@config,$_); }
        close(FILE);
        @config = grep(!/^#/, @config);
        @config = grep(!/^$/, @config);
        for (@config) {
                my ($cle,$val)=split(/\|/,$_);
                $val = substr($_,length($cle)+1);
                chomp($val);
                $confStr{$cle} = $val;
        }
        return %confStr;
}

=pod

B<readKeyFile>
file contents to hash, each line = key|value, $hash{key}=value
it's a readCfgFile + key|value parsing to a hash  
(+ duplicated l2u conversion ie. already done in readCfgFile) 
(+ key|value parsing better than readConfFile)

=cut

sub readKeyFile
{
	my @contenu = readCfgFile($_[0]);
	my %config;
	for (@contenu) {
		my ($cle,$val) = split(/\|/,$_);
		if ($cle ne "") {
			$config{$cle} = l2u($val);
		}
	}
	return %config;
}

=pod

B<readCfg>

reads in a configuration file (not necessarily in standard configuration directory),
removing comments (anything following a #), blank lines, all CRs, returning either:
 - a hash if file contains a definition line "=key|value"
 - a hash of has if file contains a definition line "=key|value1....|valueN 
 - an array of array if no definition line present
 Input: file name
 Output: Hash or HoH or AoA

=cut

sub readCfg
{
        my $fn = (@_) ? $_[0] : "/etc/webobs/WEBOBS.conf";
	my (@df, @wrk, $i, %H, @A);
        open(FILE, "<$fn") || die "WEBOBS readCfg: couldn't open >$fn<\n";
        while (<FILE>) {
		s/(?<!\\)#.*//g;            # remove comments (everything after unescaped-#)
#                s/#.*$//g;                  # remove comments
                s/(^\s+)||(\s+$)//g;        # remove leading & trailing blanks
		s/\r//g;                    # remove all CRs not only in CRLF
                next if /^$/ ;              # ignore empty lines
		if (m/=([^ ]*)/) {          # got a definition line ?
			@df = split(/\|/);  # save it
			next;               # and forget it
		}
#		@wrk = split(/\|/);          # explode std line components 
		@wrk = split(/(?<!\\)\|/);  # parse using unescaped-| as delimiter
		s/\\//g for(@wrk);          # remove escape chars (\)
		if (@df == 2) {             # key|value ?
			$H{$wrk[0]} = $wrk[1];
			next;
		}
		if (@df > 2) {              # key|val1|...|valN ?
			for ($i = 1; $i < @df; $i++) {
				$H{$wrk[0]}{$df[$i]} = $wrk[$i];
			}
			next;
		}
		push(@A, [@wrk]);
        }
        if (@A) { return @A; }
        if (%H) { return %H; }
}

=pod

B<readUser>

=cut

sub readUser
# Input: login
# Ouput: hash of user specifications
# Author: F. Beauducel, IPGP, 2010-06-24
{
	my %user;
	my $login = "";
	if ($#_ >= 0) { $login = $_[0]; }
	my $nb = 0;
	while ($nb <= $#users) {
	        if ($login ne "" && $login eq $users[$nb][3]) {
			$user{ID} = $users[$nb][0];
			$user{NAME} = $users[$nb][1];
			$user{LEVEL} = $users[$nb][2];
			$user{LOGIN} = $users[$nb][3];
			$user{EMAIL} = $users[$nb][4];
			$user{BIRTHDAY} = $users[$nb][5];
			$user{NOTIFY} = $users[$nb][6];
		}
		$nb++;
	}

	return %user;
}

=pod

B<readOperFile>

=cut

#--------------------------------------------------------------------------------------------------------------------------------------
# Usage: Ce script permet de lire le fichier des opérateurs "Operateurs.conf"
#	readOperFile(filename,valide)
#	filename = nom du fichier "Operateurs.conf"
#	valide (optionnel) = niveau minimal de l'utilisateur
#
sub readOperFile
{
	my $operateursFile = $_[0];
	my $filtre = $_[1];
	if ($filtre eq "") { $filtre = 0; }
	my @data = ("");
	my @operateurs;
	open(FILE, "<$operateursFile") || die "WEBOBS: file $operateursFile not found.\n";
	while(<FILE>) { push(@data,l2u($_)); }
	close(FILE);
	@data = grep(!/^#/, @data);
	@data = grep(!/^$/, @data);
	my $nb = 0;
	for (@data) {
		chomp($_);
		my @champs = split(/\|/,$_);
		if ($champs[2] ge $filtre) {
			$operateurs[$nb][0]=$champs[0];
			$operateurs[$nb][1]=$champs[1];
			$operateurs[$nb][2]=$champs[2];
			$operateurs[$nb][3]=$champs[3];
			$operateurs[$nb][4]=$champs[4];
			$operateurs[$nb][5]=$champs[5];
			$operateurs[$nb][6]=$champs[6];
			$nb++;
		}
	}
	return @operateurs;
}

=pod

B<readUsers>

=cut

sub readUsers
# Input: aucun
# Ouput: array opérateurs
# Auteur: F. Beauducel, IPGP, 2009-09-27
{
	return @users;
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub htmlspecialchars
{
	my $texte=$_[0];

	$texte =~ s/"/&quot;/g;
	$texte =~ s/</&lt;/g;
	$texte =~ s/>/&gt;/g;

#  	print "<div style=\"border: 1px dotted gray;\">".$texte."</div>";
	return $texte;
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub genereNomFiche
{
	my $code_station = $_[0];
	my $simplifie = $_[1];
	my $texte = "";
	if ($code_station ne "") {
		my %config = readConfStation($code_station);
		my $format = $simplifie eq 1 ? "$config{RESEAU} / \%s: \%s" : "<b>\%s</b>: \%s <i>(\%s)</i>";
		$texte = sprintf($format,$config{ALIAS},$config{NOM},$config{TYPE});
		$texte =~ s/ /Â /g;
	}
	return $texte;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Left trim function to remove leading whitespace
sub ltrim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub demain
{
	my $annee = shift;
	my $mois = shift;
	my $jour = shift;
	($annee,$mois,$jour) = split(/-/,qx(date -d "$annee-$mois-$jour 1 day" +\%Y-\%m-\%d|tr -d '\n'));
	return ($annee,$mois,$jour);
}
sub minute_suivante
{
	my $annee = shift;
	my $mois = shift;
	my $jour = shift;
	my $heure = shift;
	my $minute = shift;
	my $seconde = shift;
	($annee,$mois,$jour,$heure,$minute,$seconde) = split(/-/,qx(date -d "$annee-$mois-$jour $heure:$minute:$seconde 1 minute" +\%Y-\%m-\%d-\%H-\%M-\%S|tr -d '\n'));
	return ($annee,$mois,$jour,$heure,$minute,$seconde);
}

sub dateFichierSuds
{
	my $suds = shift;
	if (length(basename($suds)) == 12) {
		#IASPEI
	} elsif (length(basename($suds)) == 19) {
		#SUDS2
	} elsif (length(basename($suds)) == 21) {
		#SUDS2 avec suffixe
	}
}

sub fichiersSudsSuivants
{
	my $suds = shift;
	my $nb_suds = shift;
	my @liste_suds;
	if (length(basename($suds)) == 12) {
		# IASPEI
		my $longueur_nom_iaspei = length($WEBOBS{PATH_SOURCE_SISMO_GUA})+2;
		my ($annee4, $mois, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_iaspei a4 a2 a2 x3 a2 a2 a2 a2 x a3",$suds);
		my ($annee4lendemain,$moislendemain,$jourlendemain) = demain($annee4,$mois,$jour);
		my $chemin_date="$WEBOBS{RACINE_SIGNAUX_SISMO}/$WEBOBS{PATH_SOURCE_SISMO_GUA}/$annee4$mois$jour/";
		my $chemin_lendemain="$WEBOBS{RACINE_SIGNAUX_SISMO}/$WEBOBS{PATH_SOURCE_SISMO_GUA}/$annee4lendemain$moislendemain$jourlendemain";
		( -d $chemin_lendemain ) or $chemin_lendemain="";
		$nb_suds--;
		push(@liste_suds,split(/\n/, qx(find $chemin_date $chemin_lendemain -type f -print|sort|fgrep -A$nb_suds $suds)));
	} elsif (length(basename($suds)) == 19) {
		# SUDS2
		my $longueur_nom_gwa = length($WEBOBS{PATH_SOURCE_SISMO_GWA})+11;
		push(@liste_suds,$WEBOBS{RACINE_SIGNAUX_SISMO}.$suds);
		for(my $i = 1; $i < $nb_suds; $i++) {
			my ($annee4, $mois, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_gwa a4 a2 a2 x a2 a2 a2 x a3",$suds);
			($annee4, $mois, $jour, $heure, $minute, $seconde) = minute_suivante($annee4, $mois, $jour, $heure, $minute, $seconde);
			$suds = "/$WEBOBS{PATH_SOURCE_SISMO_GWA}/$annee4$mois$jour/$annee4$mois${jour}_$heure$minute$seconde.$extension";
			push(@liste_suds,$WEBOBS{RACINE_SIGNAUX_SISMO}.$suds);
		}
	}
	return @liste_suds;
}

sub fusion_suds
{
	my $suds = shift;
	my $nb_suds = shift;
	my @liste_suds = fichiersSudsSuivants($suds,$nb_suds);
	my $dest_dir = qx(mktemp -d -p /tmp fusion_suds.XXXXXXXXXX);
	chomp($dest_dir);
	my $dest = $dest_dir."/".basename($suds);
	print qx($WEBOBS{RACINE_TOOLS_SHELLS}/sudsjoin_multiple $dest @liste_suds);
	return ($dest_dir,$dest);
}
#--------------------------------------------------------------------------------------------------------------------------------------
# Fonctions SUDS IASPEI
#--------------------------------------------------------------------------------------------------------------------------------------
sub imagesSudsMC
{
	my $suds_debut = shift;
	my $nb_suds = $WEBOBS{MC_NOMBRE_FICHIERS_IMAGES} - 2;

	my $longueur_nom_iaspei = length($WEBOBS{PATH_SOURCE_SISMO_GUA})+2;
	my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $extension;
	($annee4, $mois, $jour, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_iaspei a4 a2 a2 x a2 a2 a2 a2 x a3",$suds_debut);

	my $annee2 = substr($annee4,2,2);
	my $racineImage = $annee2.$mois.$jour.$heure.$minute.$seconde;
	my $image = $racineImage.".png";
	my ($annee4lendemain,$moislendemain,$jourlendemain) = demain($annee4,$mois,$jour);
	my $repDate = $annee4.$mois.$jour;
	my $repDateLendemain = $annee4lendemain.$moislendemain.$jourlendemain;

	my $pathSrcImg="$WEBOBS{SEFRAN_RACINE}/$repDate/$WEBOBS{SEFRAN_IMAGES_SUDS}";
	my $pathSrcImgLendemain="$WEBOBS{SEFRAN_RACINE}/$repDateLendemain/$WEBOBS{SEFRAN_IMAGES_SUDS}";
	( -d $pathSrcImgLendemain ) or $pathSrcImgLendemain="";

	my $car_debut_fichier = length("$WEBOBS{SEFRAN_RACINE}/");
	my $imageMC = "$annee4/$mois/$annee2$mois$jour$heure$minute$seconde.png";
	return $imageMC,split(/\n/, qx(find $pathSrcImg $pathSrcImgLendemain -type f -print|sort|grep -A$nb_suds $racineImage|cut -c$car_debut_fichier-));
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub fichierSudsImage
{
	my $imageSuds = shift;
	my $longueur_nom_suds = length($WEBOBS{SEFRAN_IMAGES_SUDS})+2;
	my $annee4; my $mois; my $jour; my $annee2; my $heure; my $minute; my $seconde; my $reseau; my $ext;
	($annee4,$mois,$jour,$annee2,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x a4 a2 a2 x$longueur_nom_suds a2 a2 a2 a2 a2 a2 a3 x a3",$_;
	my $var = "PATH_SOURCE_SISMO_".$reseau;
	return "$WEBOBS{$var}/$annee4$mois$jour/$jour$heure$minute$seconde.$reseau";
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub fichiersSuds
{
	my @imagesSuds = @_;
	my @fichiersSuds;
	for (@imagesSuds) {
		push(@fichiersSuds,$WEBOBS{RACINE_SIGNAUX_SISMO}."/".fichierSudsImage($_));
	}
	return @fichiersSuds;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub infosSuds
{
	my $imageSuds = shift;
	my $id_fichier = shift;
	my $longueur_nom_suds = length($WEBOBS{SEFRAN_IMAGES_SUDS})+2;
	my $annee4; my $mois; my $jour; my $annee2; my $heure; my $minute; my $seconde; my $reseau; my $ext;
	($annee4,$mois,$jour,$annee2,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x a4 a2 a2 x$longueur_nom_suds a2 a2 a2 a2 a2 a2 a3 x a3",$_;
	return "Date (dÃ©but) : <b>$annee4/$mois/$jour</b><br>Heure (dÃ©but) : <b>$heure:$minute:$seconde</b><br>RÃ©seau : $reseau<br>Fichier nÂ° : <b>$id_fichier</b>";
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub imageVoiesSefran
{
	my $suds_debut = shift;
	my $longueur_nom_iaspei = length($WEBOBS{PATH_SOURCE_SISMO_GUA})+2;
	my $annee4GU; my $moisGU; my $jourGU; my $heureGU; my $minuteGU; my $secondeGU; my $extensionGU;
	($annee4GU, $moisGU, $jourGU, $jourGU, $heureGU, $minuteGU, $secondeGU, $extensionGU) = unpack "x$longueur_nom_iaspei a4 a2 a2 x a2 a2 a2 a2 x a3",$suds_debut;
	my $repDate = $annee4GU.$moisGU.$jourGU;
	return "$repDate/$WEBOBS{SEFRAN_VOIES_IMAGE}";
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Fonctions SUDS EARTHWORM
#--------------------------------------------------------------------------------------------------------------------------------------
sub imagesSuds2MC
{
	my $suds_debut = shift;
	my $nb_suds = $WEBOBS{MC_NOMBRE_FICHIERS_IMAGES_SEFRAN2} - 2;
	my $longueur_nom_gwa = length($WEBOBS{PATH_SOURCE_SISMO_GWA})+11;

	my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $extension;
	($annee4, $mois, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_gwa a4 a2 a2 x a2 a2 a2 x a3",$suds_debut);

	my $annee2 = substr($annee4,2,2);
	my $racineImage = $annee4.$mois.$jour.$heure.$minute.$seconde;
	my $image = $racineImage.".png";
	my ($annee4lendemain,$moislendemain,$jourlendemain) = demain($annee4,$mois,$jour);
	my $repDate = $annee4.$mois.$jour;
	my $repDateLendemain = $annee4lendemain.$moislendemain.$jourlendemain;

	my $pathSrcImg="$WEBOBS{SEFRAN2_RACINE}/$repDate/$WEBOBS{SEFRAN2_IMAGES_SUDS}";
	my $pathSrcImgLendemain="$WEBOBS{SEFRAN2_RACINE}/$repDateLendemain/$WEBOBS{SEFRAN2_IMAGES_SUDS}";
	( -d $pathSrcImgLendemain ) or $pathSrcImgLendemain="";

	my $car_debut_fichier = length("$WEBOBS{SEFRAN2_RACINE}/");
	my $imageMC = "$annee4/$mois/$annee2$mois$jour$heure$minute$seconde.png";
	return $imageMC,split(/\n/, qx(find $pathSrcImg $pathSrcImgLendemain -type f -print|sort|grep -A$nb_suds $racineImage|cut -c$car_debut_fichier-));
}

#--------------------------------------------------------------------------------------------------------------------------------------
# renvoi le nom du fichier SUDS a partir du nom de l'image Sefran2
sub fichierSuds2Image
{
	my $imageSuds = shift;
	my $longueur_nom_suds = length($WEBOBS{SEFRAN_IMAGES_SUDS})+11;
	my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $reseau; my $ext;
	($annee4,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x$longueur_nom_suds a4 a2 a2 a2 a2 a2 a3 x a3",$_;
	return "$WEBOBS{PATH_SOURCE_SISMO_GWA}/$annee4$mois$jour/$annee4$mois$jour\_$heure$minute$seconde.$reseau";
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub fichiersSuds2
{
	my @imagesSuds = @_;
	my @fichiersSuds;
	for (@imagesSuds) {
		push(@fichiersSuds,$WEBOBS{RACINE_SIGNAUX_SISMO}."/".fichierSuds2Image($_));
	}
	return @fichiersSuds;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub infosSuds2
{
	my $imageSuds = shift;
	my $id_fichier = shift;
	my $longueur_nom_suds = length($WEBOBS{SEFRAN_IMAGES_SUDS})+11;
	my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $reseau; my $ext;
	($annee4,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x$longueur_nom_suds a4 a2 a2 a2 a2 a2 a3 x a3",$_;
	return "Date (dÃ©but) : <b>$annee4-$mois-$jour</b><br>Heure (dÃ©but) : <b>$heure:$minute:$seconde</b><br>RÃ©seau : $reseau<br>Fichier nÂ° : <b>$id_fichier</b>";
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub imageVoiesSefran2
{
	my $suds_debut = shift;
	my $longueur_nom_iaspei = length($WEBOBS{PATH_SOURCE_SISMO_MIX})+11;
	my $annee4GU; my $moisGU; my $jourGU; my $heureGU; my $minuteGU; my $secondeGU; my $extensionGU;
	($annee4GU, $moisGU, $jourGU, $heureGU, $minuteGU, $secondeGU, $extensionGU) = unpack "x$longueur_nom_iaspei a4 a2 a2 x a2 a2 a2 x a3",$suds_debut;
	my $repDate = $annee4GU.$moisGU.$jourGU;
	return "$repDate/$WEBOBS{SEFRAN2_VOIES_IMAGE}";
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub tri_date_avec_id ($$) {
	#my $c = $a;
	#my $d = $b;
	my ($c,$d) = @_;
	# supprime le premier champ Id
	$c =~ s/^[\-0-9]+\|//;
	$d =~ s/^[\-0-9]+\|//;
	# remplace tous les champs vides par '00:00' pour que les Ã©vÃ©nements sans heure apparaissent en premier
	$c =~ s/\|\|/00:00/;
	$d =~ s/\|\|/00:00/;
	return $d cmp $c;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub romain ($)
# Input: intensite MSK (en numerique de 1 a 0 ou 10)
# Output: intensite MSK (en chiffres romains)
# Equivalent Matlab: romanx.m
# Auteur: F. Beauducel, IPGP, 2008
{
	my @msk = ("X","I","II","III","IV","V","VI","VII","VIII","IX");
	my $string = shift;
	return $msk[$string%10];
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub boussole ($)
# Input: azimut (en degres)
# Output: indication de direction geographique (chaine)
# Equivalent Matlab: boussole.m
# Auteur: F. Beauducel, IPGP, 2009-06-24
{
       my @nsew = ('E','ENE','NE','NNE','N','NNW','NW','WNW','W','WSW','SW','SSW','S','SSE','SE','ESE');
       my $az = shift;
       $az = ($az*16/6.283)%16;
       return $nsew[$az];

}


#--------------------------------------------------------------------------------------------------------------------------------------
sub pga2msk ($)
# Input: acceleration (en mg)
# Output: niveau d'intensite MSK (en chiffres romains)
# Equivalent Matlab: pga2msk.m
# Auteur: F. Beauducel, IPGP, 2009-06-24
{
	my @msk = ('I','I-II','II','II-III','III','III-IV','IV','IV-V','V','V-VI','VI','VI-VII','VII','VII-VIII','VIII','VIII-IX','IX','IX-X','X','X-XI','XI','XI-XII','XII');
	my $pga = shift;
	$pga = 2*(log($pga)*3/log(10) + 1.5) - 2;
	if ($pga < 0) { $pga = 0; }
	return $msk[$pga];
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub attenuation ($$)
# Input: magnitude et distance hypocentrale (en km)
# Ouput: acceleration PGA (en g)
# Equivalent Matlab: attenuation.m
# Auteur: F. Beauducel, IPGP, 2009-06-24
{
	my ($mag,$hyp) = @_;
	if ($hyp < 5) { $hyp = 5; }
	my $pga = 1000*10**(0.620986*$mag - 0.00345256*$hyp - log($hyp)/log(10) - 3.374841);
	return $pga;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub readConfStation ($)
# Input: code station
# Ouput: %config (hash) comportant la configuration de la fiche (clef du .conf)
#	+ $config{DISCIPLINE} = nom de la discipline
#	+ $config{RESEAU} = nom du réseau
#	+ $config{TYPE} = contenu "type.txt"
# Equivalent partiel Matlab: readst.m
# Auteur: F. Beauducel, IPGP, 2009-06-25
{
	my $station = shift;
	my %config;
	my $confFile = "$WEBOBS{RACINE_DATA_STATIONS}/$station/$station.conf";
	my $typeFile = "$WEBOBS{RACINE_DATA_STATIONS}/$station/type.txt";
	if ((-e $confFile) && (-s $confFile != 0)) {
		my @configStation = readCfgFile($confFile);
		for (@configStation) {
			my @data = ("");
			if ($_ =~ /"/) {
				@data = split(/"/,$_);
				chop($data[0]);
			} else {
				@data = split(/ \s*/,$_);
			}
			if ($#data > 0) {
				$config{$data[0]} = $data[1];
			} else {
				$config{$data[0]} = "";
			}
		}
	}
	if ((-e $typeFile) && (-s $typeFile != 0)) {
		$config{TYPE} = trim(join("",readFile($typeFile)));
	}
	$config{DISCIPLINE} = $graphStr{"codedis_".substr($station,1,1)};
	$config{RESEAU} = $graphStr{"nom_".$graphStr{"routine_".substr($station,0,3)}};
	return %config;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub nomOperateur
# Input: initiales operateur (unique ou tableau)
# Ouput: nom complet operateur
# Auteur: F. Beauducel, IPGP, 2009-06-25
{
	my @nom;
	my $i = 0;
	for (@_) {
		$nom[$i] = $nomOp{$_};
		$i++;
	}
	return @nom;
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub testOper
# Input: aucune (utilise la variable d'environnement REMOTE_USER)
# Output: tableau des caracteristiques de l'operateur identifie
# Auteur: F. Beauducel, IPGP, 2009-09-20
{
        my $USER = $ENV{"REMOTE_USER"};
        my $id = -1;
        my $nb = 0;
        while ($nb <= $#users) {
               if ($USER ne "" && $USER eq $users[$nb][3]) {
                        $id = $nb;
                }
                $nb++;
        }
        if ($id != -1) {
                # [FB]: pas trouvé comment renvoyer simplement la ligne $id du tableau 2 dimensions @users !!
                return ($users[$id][0],$users[$id][1],$users[$id][2],$users[$id][3],$users[$id][4],$users[$id][5]);
        } else {
                return ("");
        }
}
				
#--------------------------------------------------------------------------------------------------------------------------------------
sub codeFDSN
# Input: aucun
# Ouput: hash des noms complets = codeFDSN{code}
# Auteur: F. Beauducel, IPGP, 2009-09-23
{
	my %noms;
	my @FDSN = readFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FDSN_NETWORKS_FILE}");
	chomp(@FDSN);
	# extrait les lignes avec les codes 2 lettres + 7 espaces + nom réseau
	@FDSN = grep(s/(^\w\w)\ {7}/$1\t/,@FDSN);
	for (@FDSN) {
		my ($cle,$val) = split(/\t/,$_);
		$noms{$cle} = $val;
	}
	return %noms;
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub parentEvents ($)
# Input: nom de fichier événement (avec possibles sous-répertoires)
# Ouput: chaîne présentant la liste des événements parents
# Auteur: F. Beauducel, IPGP, 2009-10-13
{
	my $eventFile = shift;
	my $parent = "";
	my @subParent = split(/\//,$eventFile);
	if ($#subParent > 0) {
		$parent = join("/",@subParent[0..($#subParent-1)]);
	} else {
		return "";
	}

	my $station = substr($eventFile,0,7);
	my $txt = "";
	my @x = split(/\//,$parent);
	for (my $i=$#x;$i>=0;$i--) {
		my $f = "$WEBOBS{RACINE_DATA_STATIONS}/$station/$WEBOBS{STATIONS_INTERVENTIONS_FILE_PATH}/".join("/",@x[0..$i]).".txt";
		my ($s,$d,$h) = split(/_/,$x[$i]);
		$h =~ s/-/:/;
		my $t = "???";
		if (-e $f) {
			my @xx = readFile($f);  
			chomp(@xx);
			my $o;
			($o,$t) = split(/\|/,$xx[0]);
		}
		$txt .= " \@ <B>$t</B> ($d".($h ne "NA" ? " $h":"").")";
	}
	return $txt;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub txt2htm
# Input: chaine texte avec retours charriots et mise en forme simplifiee
# Ouput: chaine texte avec balises html
# Auteur: F. Beauducel, IPGP, 2009-09-03
{
	my $txt = $_[0];

	$txt =~ s/\cM\n/\n/g;

	# --- liste a puces => <ul></ul>
	$txt =~ s/^-/\n-/;	# necessaire pour reperer le debut de la liste
	$txt =~ s/([^\n]$)/$1\n/;	# necessaire pour reperer la fin de la liste
	$txt =~ s/\n-((?:.|\n)+?)\n([^-]|$)/\n<ul><li>$1<\/ul>$2/g;
	# --- puces => <li>
	$txt =~ s/\n-/<li>/g;
	# --- [lien web]{/} => <a href></a>
	$txt =~ s/\[(.*?)]\{(.*?)\}/<a href="$2">$1<\/a>/g;
	# --- lien station {{ODTXXXn}}
	$txt =~ s/\{{(.{7})\}\}/<b><a href="\/cgi-bin\/$WEBOBS{CGI_AFFICHE_STATION}\?id=$1">$1<\/a><\/b>/g;

	if ($userWEBOBS{LEVEL} >= 6) {
		# --- lien vers fichiers WEBOBS (fichiers ne commençant pas par "/" = déjà dans un lien)
		$txt =~ s/\b(?<!\/)(\w+\.conf\b)/<a href="$WEBOBS{WEB_RACINE_WEBOBS}\/CONFIG\/$1">$1<\/a>/g;
		$txt =~ s/\b(?<!\/)(\w+\.m)\b/<a href="$WEBOBS{WEB_RACINE_WEBOBS}\/TOOLS\/MATLAB\/$1">$1<\/a>/g;
		$txt =~ s/\b(?<!\/)(\w+\.p[l|m]\b)/<a href="$WEBOBS{WEB_RACINE_WEBOBS}\/WWW\/cgi-bin\/$1">$1<\/a>/g;
	}

	# --- nettoyage du fichier (pour eviter que les fichiers avec balises html soient remplis de <br>...)
	$txt =~ s/>\s*</></g;
	$txt =~ s/>\n/>/g;
	$txt =~ s/<br>\n/\n/ig;
	# --- retours charriots => <br> (après cette substitution, les syntaxes s'appliquent éventuellement sur plusieurs lignes)
	$txt =~ s/\n/<br>/g;
	# --- ** gras ** => <b></b>
	#$txt =~ s/\*\*\b(.+?)\b\*\*/<b>$1<\/b>/g;	# les deux \b imposent une frontiere de mot... trop restrictif ?
	$txt =~ s/\*\*(.*?)\*\*/<b>$1<\/b>/g;
	# --- // italique // => <i></i>
	$txt =~ s/(http|https|ftp|file):\/\//$1:_DoubleSlash_/g;	# remplace les // des adresses URL...
	$txt =~ s/\/\/(.*?)\/\//<i>$1<\/i>/g;
	$txt =~ s/_DoubleSlash_/\/\//g;					# remet les // ...
	# --- __ souligne __ => <u></u>
	$txt =~ s/__(.*?)__/<u>$1<\/u>/g;
	# --- "" citation "" => <blockquote></blockquote>
	$txt =~ s/""(.*?)""/<blockquote class="typewriter">$1<\/blockquote>/g;

	return $txt;
}

sub url2target
{
	my $url = shift;
	if ($url =~ /^\/(index*)?$/) {
		return "_top";
	} elsif ($url =~ /^\//) {
		return "bas";
	} else {
		return "_blank";
	}
}


1;

__END__

=pod

=head1 AUTHOR

Alexis Bosson, Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012 - Institut de Physique du Globe Paris

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
