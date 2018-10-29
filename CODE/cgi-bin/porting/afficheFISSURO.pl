#!/usr/bin/perl
#---------------------------------------------------------------
# WEBOBS: afficheFISSURO.pl ------------------------------------
# ------
# Usage: This script allows to display data from extensometry
# network of OVSG, with possibility of selecting dates interval,
# site or any string filter, and editing the data (if user level
# is sufficient).
# 
# Author: Fran�ois Beauducel, IPGP
# Created: 2009-08-18
# Modified: 2012-03-17
#---------------------------------------------------------------


use strict;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use i18n;

# ----------------------------------------------------
# ----- External modules
use Webobs;
use readConf;
use readGraph;

# ----------------------------------------------------
# ----- Configuration files reading
my %WEBOBS = readConfFile;
my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
my @graphKeys = keys(%graphStr);
my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");
my @operateurs = readUsers;
$ENV{TZ} = "America/Guadeloupe";
my $tz_old = $ENV{TZ};
$ENV{LANG} = $WEBOBS{LOCALE};

	
# ----------------------------------------------------
# ----- Control for user validity
my $USER = $ENV{"REMOTE_USER"};
my $idUser = -1;
my $userTest = 1;
my $nb = 0;
while ($nb <= $#operateurs) {
	if ($USER ne "" && $USER eq $operateurs[$nb][3]) {
		$idUser = $nb;
		$userTest = 0;
	} elsif ($USER eq "") {
		# Le site �tant prot�g� par htpasswd, les clients sans login sont en acquisition => OK
		$userTest = 0;
		$USER = "visu";
	}
	$nb++;
}

my $displayOnly = 1;
my $userLevel = -1;
if ($idUser ge 0) { $userLevel = $operateurs[$idUser][2]; }
if ($userLevel ge $WEBOBS{FISSURO_LEVEL}) { $displayOnly = 0; }


# ---------------------------------------------------------------

my @html;
my @csv;

my $affiche;
my $s;
my $i;
my $j;

my @reseaux = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_NETWORK}");
my @meteo = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_METEO}");
my @type = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_TYPE}");
my @comp = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_COMPONENT}");
my @stations;
my %stationsRes;
my @cleRes;
my %nomMeteo;
my %iconeMeteo;
my %operStat;
my @operNb;

my $dateStart = "";
my $dateEnd = "";
my $fileMC = "";
my $selectedYear1 = "";
my $selectedMonth1 = "";
my $selectedDay1 = "";
my $selectedYear2 = "";
my $selectedMonth2 = "";
my $selectedDay2 = "";
my $selectedSite = "";
my $selectedFilter = "";
my $today = qx(date -I); chomp($today);
my $fileCSV = "OVSG_FISSURO_$today.csv";

my $afficheSite;
my $afficheDates;
my $anneeActuelle = qx(date +"%Y"); chomp($anneeActuelle);
my @mois=("01".."12");
my @jour=("01".."31");

my $titrePage = $WEBOBS{FISSURO_TITLE};
my $fileDATA = $WEBOBS{RACINE_DATA_DB}."/".$WEBOBS{FISSURO_FILE_NAME};

# ---- Read the data file
my @lignes;
if (-e $fileDATA) {
	open(FILE, "<$fileDATA") || die "WEBOBS: file $fileDATA not found.\n";
	tell(FILE);
	while(<FILE>) { 
		push(@lignes,l2u($_)); 
	}
	close(FILE);
}
my $nbData = $#lignes -1;

# Sort data by date
@lignes = reverse sort tri_date_avec_id @lignes;

# Retrieve the last date (for default display)
my (@dd) = split(/\|/,$lignes[$#lignes - 1]);
my $lastDate = $dd[1];

# ---------------------------------------------------------------
# ---- Retrieve transmitted parameters (GET)
my @parametres = $cgi->url_param();
my $valParams = join(" ",@parametres);

if (($valParams =~ /y1/) && ($valParams =~ /m1/) && ($valParams =~ /d1/) && ($valParams =~ /y2/) && ($valParams =~ /m2/) && ($valParams =~ /d2/))  {
        $selectedYear1 = $cgi->url_param('y1');
        $selectedMonth1 = $cgi->url_param('m1');
        $selectedDay1 = $cgi->url_param('d1');
        $selectedYear2 = $cgi->url_param('y2');
        $selectedMonth2 = $cgi->url_param('m2');
        $selectedDay2 = $cgi->url_param('d2');
        $dateStart = $selectedYear1."-".$selectedMonth1."-".$selectedDay1;
        $dateEnd = $selectedYear2."-".$selectedMonth2."-".$selectedDay2;
	my $nbJours = (qx(date -d "$dateEnd" +%s) - qx(date -d "$dateStart" +%s))/86400 + 1;
	$afficheDates = "<b>$dateStart</b> &agrave; <b>$dateEnd</b> ($nbJours jours)";
} else {
	$dateEnd = qx(date -d "$lastDate" +"%Y-%m-%d");
	chomp($dateEnd);
	$selectedYear2 = substr($dateEnd,0,4);
	$selectedMonth2 = substr($dateEnd,5,2);
	$selectedDay2 = substr($dateEnd,8,2);
	$dateStart = qx(date -d "$dateEnd $WEBOBS{FISSURO_DELAY} days ago" +"%Y-%m-%d");
	chomp($dateStart);
	$selectedYear1 = substr($dateStart,0,4);
	$selectedMonth1 = substr($dateStart,5,2);
	$selectedDay1 = substr($dateStart,8,2);
	$afficheDates = "<b>$dateStart</b> &agrave; <b>$dateEnd</b> (d&eacute;faut = $WEBOBS{FISSURO_DELAY} derniers jours de mesures)";
}

if ($valParams =~ /site/) { 
	$selectedSite = $cgi->url_param('site');
} else {
	$selectedSite = "Tout";
}

if ($valParams =~ /obs/) { 
        $selectedFilter = $cgi->url_param('obs');
}       

if ($valParams =~ /affiche/) { 
	$affiche = $cgi->url_param('affiche');
}


# @csv contains string for data export (.csv file)

push(@csv,"Content-Disposition: attachment; filename=\"$fileCSV\";\nContent-type: text/csv\n\n");

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
	
	# Fonctions javascript du formulaire
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        print <<"FIN";
	<script type="text/javascript">
	<!--
	function resetMois1()
	{
		document.formulaire.m1.value = "01";
	        document.formulaire.d1.value = "01";
	}

	function resetJour1()
	{
	        document.formulaire.d1.value = "01";
	}

	function resetMois2()
	{
	        document.formulaire.m2.value = "12";
	        document.formulaire.d2.value = "31";
	}

	function resetJour2()
	{
	        document.formulaire.d2.value = "31";
	}

	function effaceFiltre()
	{
		document.formulaire.obs.value = "";
	}
   

	//-->
	</script>
FIN
							   

}

# ---- Construction of networks/stations list
for (@reseaux) {
	my $codeRes = $_;
	chomp($codeRes);
	my @sta = qx(/bin/ls -d $WEBOBS{RACINE_DATA_STATIONS}/$codeRes*);
	my $res = $graphStr{"nom_".$graphStr{"routine_$codeRes"}};
	push(@cleRes,"$codeRes|-- r&eacute;seau $res --");
	for (@sta) {
		$s = substr($_,length($_)-8,7);
		my %config = readConfStation($s);
		$stationsRes{$s} = $config{ALIAS};
		if ($config{VALIDE} && $config{DATA_FILE} ne "-") {
			push(@cleRes,"$s|&nbsp;$stationsRes{$s}: $config{NOM}");
		}
	}
	push(@stations,@sta);
}

for (@meteo) {
	my ($cle,$nom,$ico) = split(/\|/,$_);
	$nomMeteo{$cle} = $nom;
	$iconeMeteo{$cle} = $ico;
}

# ---- Optimisation: "grep" selection first (faster)

# Selection on string filter (all fields)
if ($selectedFilter ne "") {
	if (substr($selectedFilter,0,1) eq "!") {
		my $regex = substr($selectedFilter,1);
		@lignes = grep(!/$regex/i, @lignes);
	} else {
		@lignes = grep(/$selectedFilter/i, @lignes);
	}
}

# Selection on network / site
if ($selectedSite ne "" && $selectedSite ne "Tout") {
	@lignes = grep(/\|$selectedSite/, @lignes);
} 

# Selection on dates (from $dateStart to $DateEnd)
my @finalLignes;
my $l = 0;
for (@lignes) {
	my (@dd) = split(/\|/,$_);
	if ($dd[0] ne "ID" && $dd[1] ge $dateStart && $dd[1] le $dateEnd) {
		push(@finalLignes,$_);
	}
	$l++;
}


# Form for display selection
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if ($affiche ne "csv") {
	print("<FORM name=\"formulaire\" action=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_FISSURO}\" method=\"get\">",
	"<P class=\"boitegrise\" align=\"center\">",
	"<B>Date d&eacute;but: ");
	# ----- YEAR1
	print "<select name=\"y1\" size=\"1\" onChange=\"resetMois1()\">";
	for ($WEBOBS{FISSURO_BANG}..$anneeActuelle) {
	        if ($_ == $selectedYear1) {
	                print "<option selected value=$_>$_</option>\n";
	        } else {
	                print "<option value=$_>$_</option>\n";
	        }
	}
	print "</select>\n";

	# -----MONTH1
	print " - <select name=\"m1\" size=\"1\" onChange=\"resetJour1()\">";for (@mois) {
		if ($_ == $selectedMonth1) {
			print "<option selected value=$_>$_</option>\n";
		} else {
			print "<option value=$_>$_</option>\n";
		}
	}
	print "</select>\n";

	# ----- DAY1
	print " - <select name=\"d1\" size=\"1\">";
	for (@jour) {
		if ($_ == $selectedDay1) {
			print "<option selected value=$_>$_</option>\n";
		} else {
			print "<option value=$_>$_</option>\n";
		}
	}
	print "</select>\n";

	# ----- YEAR2
	print " Date fin: <select name=\"y2\" size=\"1\" onChange=\"resetMois2()\">";
	for ($WEBOBS{FISSURO_BANG}..$anneeActuelle) {
        	if ($_ == $selectedYear2) {
	                print "<option selected value=$_>$_</option>\n";
		} else {
	                print "<option value=$_>$_</option>\n";
		}
	}
	print "</select>\n";

	# ----- MONTH2
	print " - <select name=\"m2\" size=\"1\" onChange=\"resetJour2()\">";
	for (@mois) {
	        if ($_ == $selectedMonth2) {
	                print "<option selected value=$_>$_</option>\n";
	        } else {
	                print "<option value=$_>$_</option>\n";
	        }
	}
	print "</select>\n";

	# ----- DAY2
	print " - <select name=\"d2\" size=\"1\">";
	for (reverse(@jour)) {
	        if ($_ == $selectedDay2) {
	                print "<option selected value=$_>$_</option>\n";
	        } else {
	                print "<option value=$_>$_</option>\n";
	        }
}
	print "</select>\n",
	"<select name=\"site\" size=\"1\">";
	for ("Tout|Tous les sites",@cleRes) { 
		my ($val,$cle) = split (/\|/,$_);
		if ("$val" eq "$selectedSite") {
			print("<option selected value=$val>$cle</option>\n");
			$afficheSite = "$cle ($val)";
		} else {
			print("<option value=$val>$cle</option>\n");
		}
	}
	print "</select>";

	# ----- FILTER
	my $msg = "Le filtre fonctionne avec une <a href=http://perl.enstimac.fr/DocFr/perlretut.html target=_blank>expression rationnelle</a> ".
	"(<i>regular expression</i>) et un grep qui ne tient pas compte de la casse. ".
	"Pour la n&eacute;gation, ajouter un point d&rsquo;exclamation en d&eacute;but d&rsquo;expression. ".
	"Le filtre s&rsquo;applique &agrave; toute la ligne de donn&eacute;s: date, site, commentaire,... et valeurs num&eacute;riques.";

	print " Filtre: <input type=\"text\" name=\"obs\" size=15 value=\"$selectedFilter\" onMouseOut=\"nd()\" onmouseover=\"overlib('$msg',CAPTION,'INFORMATIONS',STICKY,WIDTH,300,TIMEOUT,3000)\">";
	if ($selectedFilter ne "") {
        	print "<img style=\"border:0;vertical-align:text-bottom\" src=\"/images/cancel.gif\" onClick=effaceFiltre()>";
	}

	print ' <input type="submit" value=" Afficher">';
	
	if ($displayOnly ne 1) {
		print(" - Entrer de <a href=\"/cgi-bin/formulaireFISSURO.pl\" target=\"_blank\">nouvelles données</a>.");
	}
	print "</B></P></FORM>\n",
	"<H2>$titrePage</H2>\n",
	"Intervalle des dates: $afficheDates<br>",
	"Sites sélectionnés: <B>$afficheSite</B><BR>";
	if ($selectedFilter ne "") {
		print "Filtre: &laquo;&nbsp;<B>$selectedFilter</B>&nbsp;&raquo;<BR>";
	}
}

my ($id,$date,$heure,$site,$ope,$tAir,$tMeteo,$instr,$comp,$rem,$val) = split(/\|/,"");
my @d;
my @nd = (0..11);
my $entete;
my $texte = "";
my $modif;
my $efface;
my $lien;
my $fmt = "%0.4f";
my $aliasSite;

$entete = "<TR>";
if ($displayOnly ne 1) {
	$entete = $entete."<TH rowspan=2></TH>";
}
$entete = $entete."<TH rowspan=2>Date</TH><TH rowspan=2>Heure</TH><TH rowspan=2>Site</TH>"
	."<TH colspan=3>M&eacute;tadonn&eacute;es</TH>"
	."<TH rowspan=2>Composante</TH>"
	."<TH colspan=12>Mesures (mm): Perpendiculaire (Serrage) / Parall&egrave;le (Jeu Dextre) / Vertical (Mont&eacute;e Est)</TH>"
	."<TH colspan=2>Statistiques</TH><TH rowspan=2></TH></TR>\n"
	."<TR><TH>Tair<br>(°C)</TH><TH>M&eacute;t&eacute;o</TH>"
	."<TH>Instr.</TH>";
for ("1".."12") {
$entete = $entete."<TH>D<sub>$_</sub></TH>";
}
$entete = $entete."<TH><SPAN style=\"text-decoration:overline\"><I>x</I></SPAN><br>(mm)</TH><TH>2&sigma;<br>(mm)</TH></TR>\n";

push(@csv,l2u("Date;Heure;Code;Site;Operateurs;Temp. Air (�C);Meteo;Instr.;Num.;Serrage/Perp. (mm);S_perp (mm);Jeu Dextre/Para. (mm);S_para (mm);Montee Est/Vert. (mm);S_vert (mm);Remarques\n"));

for(@finalLignes) {
	($id,$date,$heure,$site,$ope,$tAir,$tMeteo,$instr,$comp,$d[0][0],$d[0][1],$d[0][2],$d[1][0],$d[1][1],$d[1][2],$d[2][0],$d[2][1],$d[2][2],$d[3][0],$d[3][1],$d[3][2],$d[4][0],$d[4][1],$d[4][2],$d[5][0],$d[5][1],$d[5][2],$d[6][0],$d[6][1],$d[6][2],$d[7][0],$d[7][1],$d[7][2],$d[8][0],$d[8][1],$d[8][2],$d[9][0],$d[9][1],$d[9][2],$d[10][0],$d[10][1],$d[10][2],$d[11][0],$d[11][1],$d[11][2],$rem,$val) = split(/\|/,$_);
	$tMeteo = lc($tMeteo);
	chomp($val);
	my $err;
	for (@type) {
		my ($tpi,$tpe,$tpn) = split(/\|/,$_);
		if ($tpi eq $instr) { $err = $tpe; }
	}
	# trie les donn�es pour mettre les champs vides � la fin...
	#@d = sort { ($a eq "") <=> ($b eq "") } @d;
	my @DM = (0,0,0);
	my @DS = (0,0,0);
	my @n = (0,0,0);
	for $i(@nd) {
		for $j(0..2) {
			if ($d[$i][$j] ne "") {
				$DM[$j] +=  $d[$i][$j];		# $DM = momentanément somme des x
				$DS[$j] += ($d[$i][$j])**2;	# $DS = momentanément somme des x²
				$n[$j]++;
			}
		}
	}
	for $j(0..2) {
		if ($n[$j] > 0) {
			$DM[$j] = $DM[$j]/$n[$j];					# $DM = moyenne mesure
			$DS[$j] = 2 * sqrt($DS[$j]/$n[$j] - ($DM[$j]*$DM[$j]));	# $DS = 2 * écart-type
			if ($DS[$j] < $err) {
				$DS[$j] = $err;
			}
			$DM[$j] = sprintf("%1.2f",$DM[$j]);
			$DS[$j] = sprintf("%1.2f",$DS[$j]);
		} else {
			$DS[$j] = "";
		}
	}

	if ($stationsRes{$site}) {
		$aliasSite = "$stationsRes{$site}";
	} else {
		$aliasSite = $site;
	}
	my @listenoms = split(/\+/,$ope);
	my $noms = join(", ",nomOperateur(@listenoms));
	for (@listenoms) {
		$operStat{$_} += 1;
	}

	$lien = "<A href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_STATION}?id=$site\"><B>$aliasSite</B></A>";
	$modif = "<a href=\"/cgi-bin/formulaireFISSURO.pl?id=$id\"><img src=\"/images/modif.gif\" title=\"Editer...\" border=0></a>";
	$efface = "<img src=\"/images/no.gif\" title=\"Effacer...\" onclick=\"checkRemove($id)\">";

	$texte = $texte."<TR>";
	if ($displayOnly ne 1) {
		$texte = $texte."<TD nowrap>$modif</TD>";
	}
	$texte = $texte."<TD nowrap align=center>$date</TD><TD align=center>$heure</TD><TD align=center>$lien</TD>"
		."<TD align=center>$tAir</TD><TD align=center>";
	if ($iconeMeteo{$tMeteo} ne "") {
		$texte = $texte."<IMG src=\"/icons-webobs/meteo/$iconeMeteo{$tMeteo}\" title=\"$nomMeteo{$tMeteo}\">";
	}
	$texte = $texte."</TD>"
		."<TD align=center>$instr</TD>"
		."<TD align=center><TABLE cellspacing=0 width=\"100%\"><TD rowspan=3 style=border:0>&nbsp;<B>$comp</B>&nbsp;</TD>"
		."<TD style=border:0><I>Perp.</I></TD></TR>"
		."<TR><TD style=border:0><I>Para.</I></TD></TR><TR><TD style=border:0><I>Vert.</I></TD></TR></TABLE></TD>";
	for (@nd) {
		if ($d[$_][0] ne "" || $d[$_][1] ne "" ||$d[$_][2] ne "") {
		$texte = $texte."<TD align=right><TABLE cellspacing=0>"
			."<TR><TD style=border:0 align=right>".(($d[$_][0] ne "") ? sprintf("%1.2f",$d[$_][0]) : "&nbsp;")."</TD></TR>"
			."<TR><TD style=border:0 align=right>".(($d[$_][1] ne "") ? sprintf("%1.2f",$d[$_][1]) : "&nbsp;")."</TD></TR>"
			."<TR><TD style=border:0 align=right>".(($d[$_][2] ne "") ? sprintf("%1.2f",$d[$_][2]) : "&nbsp;")."</TD></TR>"
			."</TABLE></TD>";
		} else {
			$texte = $texte."<TD>&nbsp;</TD>";
		}
	}
	$texte = $texte."<TD align=center><TABLE cellspacing=0 width=\"100%\">";
	for $j(0..2) {
		$texte = $texte. "<TR><TD class=tdResult style=border:0>$DM[$j]</TD></TR><TR>";
	}
	$texte = $texte."</TABLE></TD><TD align=center><TABLE cellspacing=0 width=\"100%\">";
	for $j(0..2) {
		if ($DS[$j] > 1) {
			$texte = $texte."<TD class=tdResult style=\"border:0;background-color:#FFAAAA\">$DS[$j]</TD></TR>";
		} elsif ($DS[$j] > 0.2 ) {
			$texte = $texte."<TD class=tdResult style=\"border:0;background-color:#FFEBAA\">$DS[$j]</TD></TR>";
		} else {
			$texte = $texte."<TD class=tdResult style=border:0>$DS[$j]</TD></TR>";
		}
	}
	$texte = $texte."</TABLE></TD>\n";
	my $infoRem = "";
	my $infoImg = "";
	if ($rem ne "") {
		$rem =~ s/\'/&rsquo;/g;
		$rem =~ s/\"/&quot;/g;
		$infoRem = "$rem<br>___<br>";
		$infoImg = "<IMG src=\"/images/attention.gif\" border=0>";
	}
	$texte = $texte."<TD onMouseOut=\"nd()\" onMouseOver=\"overlib('$infoRem<i>Op&eacute;rateurs:</i> $noms<br>___<br><i>Saisie:</i> $val',CAPTION,'Observations $aliasSite')\">$infoImg</TD></TR>\n";
	push(@csv,"$date;$heure;$site;$aliasSite;$ope;$tAir;$tMeteo;$instr;$comp;$DM[0];$DS[0];$DM[1];$DS[1];$DM[2];$DS[2];\"".u2l($rem)."\"\n");
}

push(@html,"Nombre de données affichées = <B>".($#finalLignes + 1)."</B> / $nbData</P>\n",
	"<P>Télécharger un fichier texte/Excel de ces données: <A href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_FISSURO}?affiche=csv&y1=$selectedYear1&m1=$selectedMonth1&d1=$selectedDay1&y2=$selectedYear2&m2=$selectedMonth2&d2=$selectedDay2&site=$selectedSite&obs=$selectedFilter\"><B>$fileCSV</B></A></P>\n");

push(@html,"<TABLE class=\"trData\" width=\"100%\">$entete\n$texte\n$entete\n</TABLE>",
	   "\n<P>Type de mesure: ");
for (@type) {
	my ($tpi,$tpe,$tpn) = split(/\|/,$_);
	push(@html,"<B>$tpi</B> = $tpn (&plusmn; $tpe mm), ");
}
push(@html,"</P><P>Composantes: ");
for (@comp) {
	my ($tpi,$tpn) = split(/\|/,$_);
	push(@html,"<B>$tpi</B> = $tpn, ");
}

if ($affiche eq "csv") {
	print @csv;
} else {
	print @html;
	for ($nb=0;$nb<$#operateurs;$nb++) {
		$operNb[$nb] = sprintf("%5d x %s",$operStat{$operateurs[$nb][0]},$operateurs[$nb][1]);
	}
	@operNb = reverse(sort(grep(!/   0 x/,@operNb)));
	print "<P align=right><SPAN onMouseOut=\"nd()\" onMouseOver=\"overlib('".join("<br>",@operNb)."',CAPTION,'Top op&eacute;rateurs',ABOVE)\"><small>?</small></SPAN></P>";
	
	print "<style type=\"text/css\">
		#attente { display: none; }
	</style>\n
	<BR>\n@signature\n</BODY>\n</HTML>\n";
}

