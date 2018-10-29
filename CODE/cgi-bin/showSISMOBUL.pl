#!/usr/bin/perl
#
=head1 NAME

showSISMOBUL.pl 

=head1 SYNOPSIS

http://..../showSISMOBUL.pl? ... see query string definitions below ...

=head1 DESCRIPTION

Ce script permet l'affichage des bulletins sismologiques et leur conversion
dans l'ancien format .GUA (sans retour charriot)

=head1 Query string parameters

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# ---- standard FORMS inits ----------------------------------
# FORMPATH here to allow for relative paths in config file

die "You can't view SISMOBUL." if (!clientHasRead(type=>"authforms",name=>"SISMOBUL"));

my $FORMPATH = "$WEBOBS{PATH_FORMS}/SISMOBUL";
my %FORM = readCfg("$FORMPATH/SISMOBUL.conf");



########djl: here I am .

my @grids    = readCfgFile("$FORMPATH/$FORM{FILE_PROCS}");

my $displayOnly = 1;
$displayOnly = 0 if (clientHasEdit(type=>"authforms",name=>"SISMOBUL")) ;

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $jour  = strftime('%d',@tod); 
my $mois  = strftime('%m',@tod); 
my $annee = strftime('%Y',@tod);
my $moisActuel = strftime('%Y-%m',@tod);
my $displayMoisActuel = strftime('%B %Y',@tod);
my $today = strftime('%F',@tod);

# ---- my inits --------------------------------------------

my @html;
my @csv;

my $affiche;
my $s;
my $i;
my @nomMois = ("janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre");

# sélection des stations utilisées et récupération des alias (réseaux sources + érosion)
my @reseaux = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{SISMOBUL_FILE_RESEAUX}");
#my @types = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{PLUVIO_FILE_TYPE}");
my %stationsRes;
my @cleRes;


$ENV{TZ} = "America/Guadeloupe";
my $tz_old = $ENV{TZ};
$ENV{LANG} = $WEBOBS{LOCALE};

# ----- Mois précédent...
my $moisP = qx(date -d "1 month ago" +\%m); chomp($moisP);
my $anneeP = qx(date -d "1 month ago" +\%Y); chomp($anneeP);

# ---- Variables de tris
my $parametreAnnee;
my $parametreMois;
my $parametreSite;
my $afficheMois;
my $afficheSite;
my $critereDate = "";
my $unite;
my @cleParamAnnee;
for ($WEBOBS{SISMOBUL_BANG}..$anneeP) {
	push(@cleParamAnnee,"$_|$_");
}
my @cleParamMois;
for ('01'..'12') {
	$s = l2u(qx(date -d "$anneeP-$_-01" +"%B")); chomp($s);
	push(@cleParamMois,"$_|$s");
}

my @cleParamSite;

my $titrePage = $WEBOBS{SISMOBUL_TITLE};
my $pathDATA = $WEBOBS{RACINE_FTP}."/".$WEBOBS{SISMOBUL_PATH_NAME};


# ---------------------------------------------------------------
# Récuperation des paramètres transmis (GET)
# ---------------------------------------------------------------
my @option = ();
my $msgFinal;
my @parametres=$cgi->url_param();
my $valParams = join(" ",@parametres);

if ($valParams =~ /annee/) { 
   $parametreAnnee=$cgi->url_param('annee');
   $msgFinal = $msgFinal." & annee=$parametreAnnee";
} else {
   $msgFinal = "Pas (ou Mauvais) paramètre d'année - Option forcée à <i>année en cours</i>";
   $parametreAnnee = $anneeP;
}

if ($valParams =~ /mois/) { 
   $parametreMois=$cgi->url_param('mois');
   $msgFinal = $msgFinal." & mois=$parametreMois";
} else {
   $msgFinal = $msgFinal." & Mois non transmis - Option forcée à <i>mois en cours</i>";
   $parametreMois = $moisP;
}

if ($valParams =~ /affiche/) { 
   $affiche=$cgi->url_param('affiche');
}

my $fileDATA = "$pathDATA/$parametreAnnee/$parametreAnnee-$parametreMois.TXT";
my $fileCSV = "OVSG_$parametreAnnee-$parametreMois.BUL";

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/dat\n\n");

if ($affiche ne "csv") {
	print $cgi->header(-charset=>'utf-8');
	print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
	"<html><head><title>$titrePage</title>\n",
	"<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
	"<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_CSS}\">\n";
	
	print "<style type=\"text/css\">
	<!--
		#attente
		{
			 color: gray;
			 background: white;
			 margin: 0.5em;
			 padding: 0.5em;
			 font-size: 1.5em;
			 border: 1px solid gray;
		}
		.pre {
			font-family: monospace;
			white-space:pre;
			border: 1px solid lightgray;
			margin-left: 2px;
		}
		.debug {
			color: gray;
		}
	-->
	</style>\n";

	print "</head>\n",
	"<body style=\"background-attachment: fixed\">\n",
	"<div id=\"attente\">Recherche des données, merci de patienter.</div>",
	"<!--DEBUT DU CODE ROLLOVER 2-->\n",
	"<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n",
	"<script language=\"JavaScript\" src=\"/JavaScripts/overlib.js\"></script>\n",
	"<!-- overLIB (c) Erik Bosrup -->\n",
	"<!--FIN DU CODE ROLLOVER 2-->\n";
}


for (@reseaux) {
	my $codeRes = $_;
	chomp($codeRes);
	my @sta = qx(/bin/ls -d $WEBOBS{RACINE_DATA_STATIONS}/$codeRes*);
	my $res = $graphStr{"nom_".$graphStr{"routine_$codeRes"}};
	push(@cleRes,"$codeRes|- réseau $res -");
	for (@sta) {
		$s = substr($_,length($_)-8,7);
		my %config = readConfStation($s);
		$stationsRes{$s} = $config{ALIAS};
		if ($stationsRes{$s} ne "-") {
			push(@cleRes,"$s|$stationsRes{$s}");
		}
	}
}

# Debut du formulaire pour la selection de l'affichage
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if ($affiche ne "csv") {
	print("<FORM name=\"formulaire\" action=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_SISMOBUL}\" method=\"get\">",
	"<P class=\"boitegrise\" align=\"center\">",
	"<B>Sélectionner: <select name=\"annee\" size=\"1\">\n");
	for (reverse(@cleParamAnnee)) { 
		my ($val,$cle) = split (/\|/,$_);
		if ("$val" eq "$parametreAnnee") { print("<option selected value=$val>$cle</option>\n"); } 
		else { print("<option value=$val>$cle</option>\n"); }
	}
	print("</select>\n",
	"<select name=\"mois\" size=\"1\">");
	for (@cleParamMois) { 
		my ($val,$cle) = split (/\|/,$_);
		if ("$val" eq "$parametreMois") {
			print("<option selected value=$val>$cle</option>\n");
			$afficheMois = $cle;
		} else {
			print("<option value=$val>$cle</option>\n");
		}
	}
	print("</select>\n",
	" <input type=\"submit\" value=\"Afficher\">");
	print "</B></P></FORM>\n",
	"<H2>$titrePage</H2>\n",
	"<P>Intervalle sélectionné: <B>$afficheMois $parametreAnnee</B><BR>",
	"<B>Fichier:</B> $fileDATA</P>";
}

# ---- Lecture du fichier de données (dans tableau @lignes)
my @lignes;
my @debuts_lignes = "";
$i = 0;
open(FILE, "<$fileDATA") || die "fichier $fileDATA  non trouvé\n";
$debuts_lignes[0] = tell(FILE);
while(<FILE>) { 
	$i++;
	$debuts_lignes[$i] = tell(FILE);
	my $old_fin=$/;
	$/="\n";chomp;
	$/="\r";chomp;
	$/="\r\n";chomp;
	$/=$old_fin;
	push(@lignes,l2u($_)); 
}
close(FILE);
my $nbData = @lignes - 1;


my $entete;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $txt = "";
my $fmt = "%0.4f";
my $car10 = "                 10";
my $aliasSite;
my ($sta,$php,$tps,$phs,$dis,$dur,$com) = split(/\|/,"");

# Ligne d'en-tête du tableau de données
$entete = "<TR><TH>Station</TH>"
	."<TH>Phase P</TH>"
	."<TH>Temps d'arrivée</TH>"
    ."<TH>Phase S</TH>"
	."<TH>Distance</TH>"
	."<TH>Durée<br>(s)</TH>"
	."<TH>Commentaire</TH>"
	."<TH>TXT</TH>"
	."</TR>\n";

# Tableau de données
$i = 0;
my $nbLignesRetenues = 0;
for(@lignes) {
	if (substr($_,0,length($car10)) ne $car10) { 

		$sta = substr($_,0,4);
		$php = substr($_,4,4);
		$tps = substr($_,9,15);
		$phs = substr($_,30,10);
		$dis = substr($_,99,4);
		$dur = substr($_,70,5);
		$com = substr($_,75,23);

	if ($stationsRes{$sta}) {
			$aliasSite = "$stationsRes{$sta}";
		} else {
			$aliasSite = $sta;
		}

		$lien = "<A href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_STATION}?id=$sta\"><B>$aliasSite</B></A>";

# 			my $ligne_txt = substr($sta,0,3).$php.$tps.substr($phs,0,6).substr($phs,9,1)."    ".$com.substr($dur,1,4).$dis;
			my $ligne_txt = sprintf("%3s%4s%15s%6s%1s    %23s%4s%4s", substr($sta,0,3), $php, $tps, substr($phs,0,6), substr($phs,9,1), $com, substr($dur,1,4), $dis);
		$texte = $texte."<TR><TD align=center><span class=pre>$lien</span><span class=\"debug pre\">".substr($sta,0,3)."</span></TD>"
			."<TD align=center><span class=pre>$php</span></TD>"
			."<TD align=center><span class=pre>$tps</span></TD>"
			."<TD align=center><span class=pre>$phs</span><span class=\"debug pre\">".substr($phs,0,6)."</span><span class=\"debug pre\">".substr($phs,9,1)."</span></TD>"
			."<TD align=center><span class=pre>$dis</span></TD>"
			."<TD align=center><span class=pre>$dur</span><span class=\"debug pre\">".substr($dur,1,4)."</span></TD>"
			."<TD align=center><span class=pre>$com</span></TD>"
			."<TD align=center><span class=\"debug pre\">$ligne_txt</span></TD>"
			."</TR>\n";
		$txt.=$ligne_txt;
# 		$txt = $txt.substr($sta,0,3).$php.$tps.substr($phs,0,6).substr($phs,9,1)."    ".$com.substr($dur,1,4).$dis."\n";
# 		$texte .= "<tr><td colspan=7><pre>".$ligne_txt."</pre></td></tr>";
		
		$nbLignesRetenues++;
	} else {
		$texte = $texte."<TR><TH colspan=8>&nbsp;</TH></TR>\n";
	}
	$i++;
}

push(@html,"Nombre de données affichées = <B>$nbLignesRetenues</B> / $nbData.</P>\n",
	"<P>Télécharger le bulletin au format GUA (Martinique): <A href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_SISMOBUL}?affiche=csv&annee=$parametreAnnee&mois=$parametreMois\"><B>$fileCSV</B></A></P>\n",
"<pre>sprintf(\"%3s%4s%15s%6s%1s    %23s%4s%4s\", substr(\$sta,0,3), \$php, \$tps, substr(\$phs,0,6), substr(\$phs,9,1), \$com, substr(\$dur,1,4), \$dis)</pre>");

if ($texte ne "") {
	push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>\n");
}

if ($affiche eq "csv") {
	push(@csv,$txt);
	print @csv;
} else {
	print @html;
	print "<style type=\"text/css\">
		#attente { display: none; }
	</style>\n
	<BR>\n@signature\n</BODY>\n</HTML>\n";
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

