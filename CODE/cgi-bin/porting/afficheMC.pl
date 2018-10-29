#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteurs: Didier Mallarino + Alexis Bosson + François Beauducel
# ------
# Usage: Ce script permet l'affichage de la Main Courante
# Il extrait les informations pertinentes de la
# base (fichiers texte) et genere une
# page HTML en fonction des parametres transmis.
#
# ------------------- RCS Header -------------------------------
# $Header: /ipgp/webobs/WWW/cgi-bin/RCS/afficheMC.pl,v 1.14 2007/05/29 21:17:56 bosson Exp bosson $
# $Revision: 1.14 $
# $Author: bosson $
# --------------------------------------------------------------


# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use File::Basename;
use Data::Dumper;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use i18n;
use Webobs;

# ----------------------------------------------------
# ---------- Module de configuration  ----------------
# ----------------------------------------------------
use readConf;
my %confStr=readConfFile;
# ----------------------------------------------------


# ---- signature pied de page
my @signature=readFile("$confStr{RACINE_DATA_WEB}/$confStr{FILE_SIGNATURE}");

# ----------------------------------------------------
# -------- Controle la validité de l'IP  -------------
# ----------------------------------------------------
use checkIP;
my $displayOnly=0;
my $IP=$ENV{REMOTE_ADDR};
my $ipTest=checkIP($IP);
if ($ipTest != 0) { $displayOnly=1; }

$|=1;
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# HTML Header et Titre
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
print $cgi->header(-charset=>'utf-8');
print <<"FIN";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8">
	<title>$confStr{MC_TITRE}</title>
	<link rel="stylesheet" type="text/css" href="/$confStr{FILE_CSS}">
	<style type="text/css">
	<!--
		th { font-size:8pt; border-width:0px; }
		td { font-size:8pt; border-width:0px; text-align:center }
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
	</style>
</head>
<body>
<div id="attente">Recherche des données, merci de patienter.</div>
<!--DEBUT DU CODE ROLLOVER 2-->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/JavaScripts/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->

FIN


# ----------------------------------------------------------------------------------
# ----------------- Fonction d'affichage de la Main Courante -----------------------
# ----------------------------------------------------------------------------------
sub affiche
{

	# Arguments et variables
	# - - - - - - - - - - - - - - - - - - - - - - - - -
	my $dateStart = $_[0];
	my $dateEnd = $_[1];
	my $selType = $_[2];
	my $selDuree = $_[3];
	my $selAmp = $_[4];
	my $selObs = $_[5];
	my $fileMC;
	my $dateLigne;
	my @lignes;
	my @titres;
	my @champs;
	my @hypo = ("");
	#my %dateModif;
	my $nb = 0;
	my @finalLignes;
	my $flagStart = 0;
	my $flagEnd = 0;
	my $nbLignesRetenues = 0;
	my @numeroLigneReel = ("");
	my $nosuds = "xxxxxxxx.xxx";
	#my $search = "style=\"background-color:#FFFF55\"";
	my $search = "class=\"searchResult\"";
	
	# - - - - - - - - - - - - - - - - - - - - - - -
	# Charge la liste communes pour B3
	# - - - - - - - - - - - - - - - - - - - - - - -
	my @listeCommunes = readCfgFile("$confStr{RACINE_FICHIERS_CONFIGURATION}/$confStr{SHAKEMAPS_COMMUNES_FILE}");
	my @b3_lon;
	my @b3_lat;
	my @b3_nam;
	my @b3_isl;
	my @b3_sit;
	my @b3_dat;
	my $i = 0;
	for (@listeCommunes) {
		my (@champs) = split(/\|/,$_);
		$b3_sit[$i] = $champs[0];
		$b3_lon[$i] = $champs[1];
		$b3_lat[$i] = $champs[2];
		$b3_nam[$i] = $champs[3];
		$b3_isl[$i] = $champs[4];
		$i++;
	}

	# - - - - - - - - - - - - - - - - - - - - - - -
	# Charge le fichier d'hypocentres
	# - - - - - - - - - - - - - - - - - - - - - - -
	my $fileHypo = $confStr{RACINE_FTP}."/".$confStr{SISMOHYP_PATH_FTP}."/".$confStr{SISMOHYP_HYPO_FILE};
	my @hypos = readFile($fileHypo);

	# - - - - - - - - - - - - - - - - - - - - - - -
	# Charge les fichiers de donnees (MC et HYPO)
	# - - - - - - - - - - - - - - - - - - - - - - -
	my $pathFileMC = $confStr{MC_RACINE}."/".$confStr{MC_PATH_FILES};
	for (substr($dateStart,0,4)..substr($dateEnd,0,4)) {
		my $y = $_;
		my $fileHypo2 = $confStr{RACINE_FTP}."/".$confStr{SISMOHYP_PATH_FTP}."/Global/$y"."_".$confStr{SISMOHYP_HYPO_FILE};
		if (-e $fileHypo2) {
			push(@hypos,readFile($fileHypo2));
		}
		for ("01".."12") {
			my $m = $_;
			push(@hypo,grep(/^$y$m/,@hypos));
			if ("$y-$m" ge substr($dateStart,0,7) && "$y-$m" le substr($dateEnd,0,7)) {
				$fileMC = $pathFileMC."/MC$y$m.txt";
				if (-e $fileMC) {
					#my @Info = stat($fileMC);
					my $tmp = "$y$m";
					#$dateModif{$tmp} = $Info[8];	
					push(@lignes,readCfgFile($fileMC));
					$nb = $#lignes;
				}
			}
		}
	}

	# - - - - - - - - - - - - - - - - - - - - - - -
	# Charge la ligne des titres
	# - - - - - - - - - - - - - - - - - - - - - - -
	my @ligneTitre;
	my $fileTitres = $confStr{RACINE_FICHIERS_CONFIGURATION}."/".$confStr{MC_FILE_TITRES_MAIN_COURANTE};
	@ligneTitre = readCfgFile($fileTitres);

	# - - - - - - - - - - - - - - - - - - - - - - -
	# Charge les codifications d'evenements
	# - - - - - - - - - - - - - - - - - - - - - - -
	my @typeEvnt;
	my %couleurEvnt;
	my %mdEvnt;
	my $fileEvnt = $confStr{RACINE_FICHIERS_CONFIGURATION}."/".$confStr{MC_FILE_CODES_SEISMES};
	@typeEvnt = readCfgFile("$fileEvnt");
	for (@typeEvnt) {
		my @liste = split(/\|/,$_);
		$couleurEvnt{$liste[0]}=$liste[2]; 
		$mdEvnt{$liste[0]} = $liste[3]; 
	}

	
	# Fonction de confirmation de la demande d'effacement
	# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	print <<"FIN";
<script type="text/javascript">
<!--
valFile0 = "$confStr{MC_RACINE}/$confStr{MC_PATH_FILES}/";
function confirmEffacement()
{
	for (var x=0; x<document.formEffacement.id_evt.length; x++) {
		if (document.formEffacement.id_evt[x].checked) { 
			valX = x;
			valLigne0 = document.formEffacement.id_evt[x].value;
			valTmp = valLigne0.split(",");
			valFile = valFile0 + "MC" + valTmp[0] + ".txt";
			valLigne = valTmp[1];
			//valModif = valTmp[2];
		}
	}
	document.formEffacement.id_evt[valX].value = valLigne;
	document.formEffacement.fileMC.value = valFile;
	//document.formEffacement.dateModif.value = valModif;
	//if (confirm ("Confirmez l'effacement ligne " + valLigne + " dans " + valFile + " [" + valModif + "]")) {
	if (confirm ("Confirmez l'effacement evenement " + valLigne + " dans " + valFile)) {
		return true;
	} else {
		document.formEffacement.id_evt[valX].value = valLigne0;
		document.formEffacement.fileMC.value = valFile0;
		return false;
	}
}

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


# - - - - - - - - - - - - - - - - - - - - - - -
# Le fichier est rangé en ordre inverse
# On inverse donc date de depart et de fin
# - - - - - - - - - - - - - - - - - - - - - - -
	if ($dateStart lt $dateEnd) {
		my $dateTmp = $dateStart;
		$dateStart = $dateEnd;
		$dateEnd = $dateTmp;
	}

# Optimisation: selection "grep" en premier (les plus rapides sur le tableau)

# Selection sur le type
# - - - - - - - - - - - - - 
	if (($selType ne "") && ($selType ne "ALL")) {
		@lignes = grep(/$selType/, @lignes)
	}

# Selection sur l'amplitude
# - - - - - - - - - - - - - 
	if (($selAmp ne "") && ($selAmp ne "ALL")) {
		@lignes = grep(/$selAmp/, @lignes)
	}

# Selection sur les observations (en fait tous les champs)
# - - - - - - - - - - - - - 
	if ($selObs ne "") {
		if (substr($selObs,0,1) eq "!") {
			my $regex = substr($selObs,1);
			@lignes = grep(!/$regex/i, @lignes);
		} else {
			@lignes = grep(/$selObs/i, @lignes);
		}
	}

# Selection sur les dates (de $dateStart a $DateEnd) et sur la duree
# - - - - - - - - - - - - - 
	my $l = 0;
	for (@lignes) {
		$l++;
		my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$nb_fichiers,$png,$operateur,$comment) = split(/\|/,$_);
		if ($unite eq "min") {
			$duree *= 60;
		}
		if (($date le $dateStart && $date ge $dateEnd) && ($selDuree eq "" || $selDuree eq "NA" || $selDuree eq "ALL" || $duree >= $selDuree)) {
			push(@finalLignes,$_);
			push(@numeroLigneReel,$l);
		}
	}

# Trier les donnees
# - - - - - - - - - - - - -
	@finalLignes = sort tri_date_avec_id @finalLignes;
	#@finalLignes = reverse sort @finalLignes;

# - - - - - - - - - - - - - - - - - - - - - - -
# Statistiques sur le nombre de séismes de chaque type
# - - - - - - - - - - - - - - - - - - - - - - -
	my $nbJours = (qx(date -d "$dateStart" +%s) - qx(date -d "$dateEnd" +%s))/86400 + 1;
	my %stat;
	for(@finalLignes)
	{
		if ( $_ ne "" ) {
			my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$nb_fichiers,$png,$operateur,$comment) = split(/\|/,$_);
			$stat{$type}+=$nombre;
		}
	} 
	print "<table><tr>";
	print "<td rowspan=2 style=\"border:0\"><b>Sélection:</b> ", $nbJours, " jours ";
	if ($nbJours > 365) {
		print "( ~ ",int($nbJours/365.25)." an(s) ",int(($nbJours%365.25)/30.4)," mois ) ";
	} elsif ($nbJours > 30) {
		print "( ~ ",int($nbJours/30.4)," mois ) ";
	}
	print "- <b>Statistiques:</b> </td>";
	for(sort(keys(%stat))) {
		print "<th><b>$_</b></th>";  
	}
	print "<th><b>Total</b></th></tr><tr>";
	my $total=0;
	for(sort(keys(%stat))) {
		print "<td>$stat{$_}</td>";  
		$total=$total+$stat{$_};

	}
	print "<td style=\"color:red;\"><b>$total</b></td></tr></table>",
		"</TD><TD style=\"border:0;text-align:right\"><A href=\"/$confStr{MC_PATH_WEB}/MC.png\"><IMG src=\"/$confStr{MC_PATH_WEB}/MC.jpg\"></A></TD>",
	"</TR></TABLE>",
	"<hr>";


# - - - - - - - - - - - - - - - - - - - - - - -
# Debut du tableau principal
# - - - - - - - - - - - - - - - - - - - - - - -


	print "<form name=\"formEffacement\" action=\"/cgi-bin/effaceMC.pl\" method=\"post\" onSubmit=\"return confirmEffacement()\">";
	print "<table class=\"trData\" width=\"100%\"><tr>";
	@titres = split(/\|/,$ligneTitre[0]);
	for(@titres) { 
		print "<th>$_</th>"; 
	}
	print "</tr>";


# - - - - - - - - - - - - - - - - - - - - - - -
# Affiche le contenu sous forme de tableau
# - - - - - - - - - - - - - - - - - - - - - - -
	for(@finalLignes)
	{
		if ( $_ ne "" )
		{
			my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$nb_fichiers,$png,$operateur,$comment) = split(/\|/,$_);
			my ($evt_annee4,$evt_mois,$evt_jour,$suds_jour,$suds_heure,$suds_minute,$suds_seconde,$suds_reseau) = split;
			my $diriaspei;
			my $dirTrigger;
			if (length($suds) < 11) { $suds = $nosuds; }
			if ($suds =~ "gwa") {
				($evt_annee4, $evt_mois, $suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a4 a2 a2 x a2 a2 a2 a2 x a3",$suds);
				$diriaspei = $confStr{PATH_SOURCE_SISMO_GWA}."/".$evt_annee4.$evt_mois.$suds_jour;
			} else {
				($suds_jour, $suds_heure, $suds_minute, $suds_seconde, $suds_reseau) = unpack("a2 a2 a2 a2 x a3",$suds);
				($evt_annee4,$evt_mois,$evt_jour) = split(/-/,$date);
				$diriaspei = $confStr{"PATH_SOURCE_SISMO_$suds_reseau"}."/".$evt_annee4.$evt_mois.$suds_jour;
			}
			$dirTrigger = "$confStr{SISMOCP_PATH_FTP}/$evt_annee4/".substr($evt_annee4,2,2)."$evt_mois";
			my @loca;
			my @suds_liste;
			my $suds_sans_seconde;
			my $suds_racine;
			my $suds_ext;
			my $suds2_pointe;
			if (length($suds)==12) {
				# ne prend que les premiers caractères du nom de fichier
				$suds_sans_seconde = substr($suds,0,7);
				@suds_liste = <$confStr{RACINE_FTP}/$dirTrigger/$suds_sans_seconde*>;
				@loca = grep(/ $suds_sans_seconde/,grep(/^$evt_annee4$evt_mois/,@hypo));
			} elsif (length($suds)==19) {
				$suds_racine = substr($suds,0,15);
				$suds_ext = substr($suds,16,3);
				$suds2_pointe = "${suds_racine}_a.${suds_ext}";
				@loca = grep(/ $suds_racine/,grep(/^$evt_annee4$evt_mois/,@hypo));
			}
			my @lat = ("");
			my @lon = ("");
			my @dep = ("");
			my @mag = ("");
			my @cod = ("");
			my @msk = ("");
			my @dat = ("");
			my @qua = ("");
			my @bcube = ("");
			my @nomB3 = ("");
			my $ii = 0;
			my $nomB3FTP = "";
			for (@loca) {
				$dat[$ii] = sprintf("%d-%02d-%02d %02d:%02d:%02.2f TU",substr($_,0,4),substr($_,4,2),substr($_,6,2),substr($_,9,2),substr($_,11,2),substr($_,14,5));
				$mag[$ii] = substr($_,47,5);
				$lat[$ii] = substr($_,20,2) + substr($_,23,5)/60;
				$lon[$ii] = substr($_,30,2) + substr($_,33,5)/60;
				$dep[$ii] = substr($_,39,6);
				$qua[$ii] = sprintf("%d phases - classe %s",substr($_,53,2),substr($_,80,1));
				$cod[$ii] = substr($_,83,5);
				if (substr($cod[$ii],2,1) ne "1") { $msk[$ii] = romain(substr($cod[$ii],2,1)); }
				$nomB3[$ii] = $confStr{SISMORESS_PATH_FTP}."/".substr($_,0,4)."/".substr($_,4,2)."/".substr($_,0,8)."T"
				.sprintf("%02.0f",substr($_,9,2)).sprintf("%02.0f",substr($_,11,2)).sprintf("%02.0f",substr($_,14,5))."_b3";

				# calcul de la distance epicentrale minimum (et azimut epicentre/villes)
				my $old_locale = setlocale(LC_NUMERIC);
				setlocale(LC_NUMERIC,'C');
				for (0..($#b3_lat - 1)) {
					my $dx = (-$lon[$ii] - $b3_lon[$_])*111.18*cos($lat[$ii]*0.01745);
					my $dy = ($lat[$ii] - $b3_lat[$_])*111.18;
					$b3_dat[$_] = sprintf("%06.1f|%g|%s|%s|%g",sqrt($dx**2 + $dy**2),atan2($dy,$dx),$b3_nam[$_],$b3_isl[$_],$b3_sit[$_]);
				}
				setlocale(LC_NUMERIC,$old_locale);
				my @dhyp = sort { $a cmp $b } @b3_dat;
				$bcube[$ii] = $dhyp[0];

				$ii++;
			}
			($duree_sat eq 0) and $duree_sat = " ";
			($s_moins_p eq 0) and $s_moins_p = " ";

			# mise en evidence du filtre
			my $typeAff = $type;
			if ($selObs ne "") {
				if (grep(/$selObs/i,$type)) {
					$typeAff =~ s/($selObs)/<span $search>$1<\/span>/ig;
				}
				if (grep(/$selObs/i,$station)) {
					$station =~ s/($selObs)/<span $search>$1<\/span>/ig;
				}
				if (grep(/$selObs/i,$comment)) {
					$comment =~ s/($selObs)/<span $search>$1<\/span>/ig;
				}
			}

			print "<tr><td nowrap><a href=\"frameMC".($suds =~ ".gwa" ? "2":"").".pl?f=/$diriaspei/$suds&amp;id_evt=$id_evt\" target=\"_blank\"><IMG src=\"/images/modif.gif\" border=0 title=\"&Eacute;diter...\"></a>";
			#print "<IMG src=\"/images/no.gif\" title=\"Effacer...\" onclick=\"checkRemove($id_evt)\">";
			my $tmp = "$evt_annee4$evt_mois";
			#print "<input name=\"id_evt\" type=\"radio\" value=\"$evt_annee4$evt_mois,$id_evt,$dateModif{$tmp}\"></td>";
			print "<input name=\"id_evt\" type=\"radio\" value=\"$evt_annee4$evt_mois,$id_evt\"></td>";
			my $t = $duree;
			if ($unite eq "min") {
				$t *= 60;
			} elsif ($unite eq "h") {
				$t *= 3600;
			}
			my $md;
			my $dist = 0;
			if ($s_moins_p eq "NA") {
				if ($type eq "VOLCTECT") {
					$dist = "3";
				}
			} else {
				$dist = sprintf("%.0f",8*$s_moins_p);
			}
			if ( ($mdEvnt{$type} == 1) and ($t gt 0) and ($dist gt 0) ) {
				$md = sprintf("%.1f",2*log($t)/log(10)+0.0035*$dist-0.87);
				print "<td style=\"color: gray;\">$md</td><td style=\"color: gray;\">$dist</td>";
			} else {
				print "<td>&nbsp;</td><td>&nbsp;</td>";
			}

			print "<td nowrap>&nbsp;$date&nbsp;</td>";

			print "<td nowrap>&nbsp;$heure&nbsp;</td>";

			print "<td nowrap>&nbsp;".($nombre gt 1 ? "<b>$nombre</b>" : $nombre)."&nbsp;&times;</td>";

			print "<td style=\"color:$couleurEvnt{$type}\"><b>$typeAff</b></td>";
			my $amplitude_texte = $amplitude eq "Sature" ? "<b>Saturé</b> ($duree_sat s)" : "$amplitude";
			my $amplitude_img = "/icons-webobs/signal_amplitude_".lc($amplitude).".png";
			print "<td nowrap style=\"text-align: left;\">$amplitude_texte</td>";

			print "<td>$duree&nbsp;$unite</td>";

			print "<td>".($s_moins_p eq "NA" ? "&nbsp;" : "$s_moins_p")."</td>";

			if ($arrivee eq "0") { print "<td>$station</td>"; }
			else { print "<td><b>$station</b></td>"; }

			print "<td>";
			if (length($suds)==12) {
				for(@suds_liste) { 
					print "<a href=\"$confStr{WEB_RACINE_FTP}/$dirTrigger/$_\"><img title=\"Pointés $_\" src=\"/icons-webobs/signal_pointe.png\" border=\"0\"></a>";
				}
			} elsif (-f "$confStr{RACINE_FTP}/$dirTrigger/$suds2_pointe") { 
				for my $lettre ("a".."z") {
					$suds2_pointe = "${suds_racine}_${lettre}.${suds_ext}";
					if (-f "$confStr{RACINE_FTP}/$dirTrigger/$suds2_pointe") { 
						print "<a href=\"$confStr{WEB_RACINE_FTP}/$dirTrigger/$suds2_pointe\"><img title=\"Pointés $suds2_pointe\" src=\"/icons-webobs/signal_pointe.png\" border=\"0\"></a>";
					}
				}
			} elsif (-f "$confStr{MC_PATH_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds") { 
				print "<a href=\"$confStr{MC_WEB_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds\" title=\"Signaux $suds\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
			} elsif (-f "$confStr{MC_PATH_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds") { 
				print "<a href=\"$confStr{MC_WEB_DESTINATION_SIGNAUX}/${evt_annee4}-${evt_mois}/$suds\" title=\"Signaux $suds\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
			} elsif (-f "$confStr{RACINE_SIGNAUX_SISMO}/$diriaspei/$suds") { 
				print "<a href=\"$confStr{WEB_RACINE_SIGNAUX}/$diriaspei/$suds\" title=\"Signaux $suds\"><img src=\"/icons-webobs/signal_non_pointe.png\" border=\"0\"></a>";
			} elsif ($suds eq $nosuds) {
				print "<img src=\"/icons-webobs/nofile.gif\" title=\"Pas de fichier\">";
			} else {
				print "<span style=\"font-size:6pt\">($suds)</span>";
			}
			print "</td>";

			print "<td>$nb_fichiers</td>";

			print "<td>";
			if (-e "$confStr{MC_RACINE}/$confStr{MC_PATH_IMAGES}/$evt_annee4/$evt_mois/$png") { 
				print "<a href=\"/$confStr{MC_PATH_WEB}/$confStr{MC_PATH_IMAGES}/$evt_annee4/$evt_mois/$png\" onClick=\"window.open('/$confStr{MC_PATH_WEB}/$confStr{MC_PATH_IMAGES}/$evt_annee4/$evt_mois/$png','SefraN','width=1300,height=700,scrollbars=yes'); return false;\"><img src=\"$amplitude_img\" border=\"0\" title=\"image du SefraN\" alt=\"image du SefraN\"></a>";
			}
			else {
				print "<img src=\"/icons-webobs/nofile.gif\" border=\"0\">";
			}

			print "</td><td>$operateur</td>";

			print "<td style=\"text-align:left;\"><i>$comment</i></td>";
			$ii = 0;
			# S'il y a au moins une localisation correspondant au suds
			for (@loca) {
				# S'il y en a plus d'une, elles sont mises sur des lignes en-dessous, qui ne r�petent pas les dates/heures
				if ($ii > 0) { print "</td></tr><tr><td colspan=16>"; }
				# Distance et direction d'apr�s B3
				my @b3 = split(/\|/,$bcube[$ii]);
				$b3[2] =~ s/\'/\`/g;
				my $town = $b3[2];
				if ($b3[4] != $confStr{SHAKEMAPS_COMMUNES_PLACE}) {
					$town = $b3[3];
				}
				my $dhyp = sqrt($b3[0]**2 + $dep[$ii]**2);
				my $pga = attenuation($mag[$ii],$dhyp);
				my $pgamax = $pga*$confStr{SHAKEMAPS_SITE_EFFECTS};
				my $dir=boussole($b3[1]);
				# Info-bulle avec les d�tails de la localisation
				print "<td nowrap style=\"color: gray;\" onMouseOut=\"nd()\" onMouseOver=\"overlib('"
					."Magnitude = <b>$mag[$ii]</b> - Code = <b>$cod[$ii]</b><br>"
					.sprintf("<b>%2.2f°N</b> - <b>%2.2f°W</b><br>",$lat[$ii],$lon[$ii])
					."Profondeur = <b>$dep[$ii] km</b><br>"
					."$qua[$ii]<br>"
					.sprintf("Calcul B3 moyen (max) &agrave;:<br><b>%s (%s)</b><br><b>%1.1f</b> (%1.1f) mg = <b>%s</b> (%s)",$b3[2],$b3[3],$pga,$pgamax,pga2msk($pga),pga2msk($pgamax))
					."',CAPTION,'$dat[$ii]')\">"
					#."<IMG src=\"/icons-webobs/hypo71.png\">"
					.sprintf("%1.0f km <img src=\"/icons-webobs/boussole/%s.png\" align=\"bottom\" alt=\"%s\"> %s<br>",$b3[0],lc($dir),$dir,$town)
					."</td><td style=\"color: gray;\">$mag[$ii]</td><td class=\"msk\">$msk[$ii]</td><td>";
				# Lien vers le B-Cube
				$nomB3FTP = $confStr{RACINE_FTP}."/".$nomB3[$ii];
				my $ext = "";
				if (-e "$nomB3FTP.pdf") {
					$ext = ".pdf";
				} elsif (-e "$nomB3FTP.png") {
					$ext = ".png";
				}
				if ($ext) {
					print "<A href=\"$confStr{WEB_RACINE_FTP}/$nomB3[$ii]$ext\"><IMG onMouseOut=\"nd()\" onMouseOver=\"overlib('<img src=&quot;$confStr{WEB_RACINE_FTP}/$nomB3[$ii].jpg&quot;',CAPTION,'Rapport B³',WIDTH,80)\" src=\"/icons-webobs/logo_b3.gif\" border=0></A>";
				}
				$ii++;
			}
			if ($ii == 0) { print "<td colspan=4>"; }
			print "</td></tr>\n";
			$nbLignesRetenues++;
		}
	}

	print "</table>\n";
	# champs caches qui seront remplis par le javascript
	print "<input type=\"hidden\" name=\"fileMC\" value=\"$confStr{MC_RACINE}/$confStr{MC_PATH_FILES}/\">";
	#print "<input type=\"hidden\" name=\"dateModif\" value=\"\">";
	print "<p><input type=\"submit\" value=\"Effacer la ligne sélectionnée\"></p>";
	print "</form>"; # ----- Fin du formulaire gerant l'effacement

	print "<br><hr><br>";
	print "<b>Nombre de lignes retenues / lues: </b>",$nbLignesRetenues," / ",$nb,"<br>";
	print "<b>Intervalle des dates: </b>[",$dateEnd," , ",$dateStart,"]<br>";
	print "<b>Critere de type: </b>",$selType,"<br>";
	print "<b>Durée supérieures à: </b>",$selDuree,"s <br>";

}

# ---------------------------------------------------------------
# ------------ MAIN ---------------------------------------------
# ---------------------------------------------------------------

# Definition des variables
# - - - - - - - - - - - - - - - - - - - - - - -
my $dt1 = "";
my $dt2 = "";
my $fileMC = "";
my $selectedYear1 = "";
my $selectedMonth1 = "";
my $selectedDay1 = "";
my $selectedYear2 = "";
my $selectedMonth2 = "";
my $selectedDay2 = "";
my $selectedType = "";
my $selectedDuree = "";
my $selectedAmplitude = "";
my $selectedObservation = "";
my @infoTexte;

# - - - - - - - - - - - - - - - - - - - - - - -
# Lit le texte d'introduction
# - - - - - - - - - - - - - - - - - - - - - - -
my $infoFileMC = $confStr{RACINE_DATA_WEB}."/".$confStr{MC_FILE_NOTES};
@infoTexte = readFile("$infoFileMC");

# - - - - - - - - - - - - - - - - - - - - - - -
# Recuperation des valeurs transmises
# - - - - - - - - - - - - - - - - - - - - - - -
my @parametres = $cgi->url_param();
my $valParams = join(" ",@parametres);
if (($valParams =~ /y1/) && ($valParams =~ /m1/) && ($valParams =~ /d1/) && ($valParams =~ /y2/) && ($valParams =~ /m2/) && ($valParams =~ /d2/))  {
	$selectedYear1 = $cgi->url_param('y1');
	$selectedMonth1 = $cgi->url_param('m1');
	$selectedDay1 = $cgi->url_param('d1');
	$selectedYear2 = $cgi->url_param('y2');
	$selectedMonth2 = $cgi->url_param('m2');
	$selectedDay2 = $cgi->url_param('d2');
	$dt1 = $selectedYear1."-".$selectedMonth1."-".$selectedDay1;
	$dt2 = $selectedYear2."-".$selectedMonth2."-".$selectedDay2;
} else {
	$dt1 = qx(date -u -d "$confStr{MC_DELAY} days ago" +"%Y-%m-%d");
	chomp($dt1);
	$selectedYear1 = substr($dt1,0,4);
	$selectedMonth1 = substr($dt1,5,2);
	$selectedDay1 = substr($dt1,8,2);
	$dt2 = qx(date -u +"%Y-%m-%d");
	chomp($dt2);
	$selectedYear2 = substr($dt2,0,4);
	$selectedMonth2 = substr($dt2,5,2);
	$selectedDay2 = substr($dt2,8,2);
}


if ($valParams =~ /type/) { 
	$selectedType=$cgi->url_param('type');
}

if ($valParams =~ /duree/) { 
	$selectedDuree=$cgi->url_param('duree');
}

if ($valParams =~ /amplitude/) { 
	$selectedAmplitude=$cgi->url_param('amplitude');
}

if ($valParams =~ /obs/) { 
	$selectedObservation=$cgi->url_param('obs');
}

my $anneeActuelle = qx(date +"%Y"); chomp($anneeActuelle);
my @mois=("01".."12");
my @jour=("01".."31");

# -----------------------------------------
# ----- FORMULAIRE DE SELECTION D'AFFICHAGE

print "<form name=\"formulaire\" action=\"/cgi-bin/$confStr{CGI_AFFICHE_MC}\" method=\"get\">";
print "<P class=\"boitegrise\" align=\"center\">Date d&eacute;but: ";

# ----- Boite Selection ANNEE1
print "<select name=\"y1\" size=\"1\" onChange=\"resetMois1()\">";
for ($confStr{MC_BANG}..$anneeActuelle) { 
	if ($_ == $selectedYear1) { 
		print "<option selected value=$_>$_</option>\n"; 
	} else {
		print "<option value=$_>$_</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection MOIS1
print " - <select name=\"m1\" size=\"1\" onChange=\"resetJour1()\">";
for (@mois) { 
	if ($_ == $selectedMonth1) { 
		print "<option selected value=$_>$_</option>\n"; 
	} else {
		print "<option value=$_>$_</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection JOUR1
print " - <select name=\"d1\" size=\"1\">";
for (@jour) { 
	if ($_ == $selectedDay1) {
		print "<option selected value=$_>$_</option>\n";
	} else {
		print "<option value=$_>$_</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection ANNEE2
print " Date fin: <select name=\"y2\" size=\"1\" onChange=\"resetMois2()\">";
for ($confStr{MC_BANG}..$anneeActuelle) { 
	if ($_ == $selectedYear2) { 
		print "<option selected value=$_>$_</option>\n"; 
	} else {
		print "<option value=$_>$_</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection MOIS2
print " - <select name=\"m2\" size=\"1\" onChange=\"resetJour2()\">";
for (@mois) { 
	if ($_ == $selectedMonth2) { 
		print "<option selected value=$_>$_</option>\n"; 
	} else {
		print "<option value=$_>$_</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection JOUR2
print " - <select name=\"d2\" size=\"1\">";
for (reverse(@jour)) { 
	if ($_ == $selectedDay2) {
		print "<option selected value=$_>$_</option>\n";
	} else {
		print "<option value=$_>$_</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection TYPE EVNT
my @typeEvnt;
my $fileEvnt = $confStr{RACINE_FICHIERS_CONFIGURATION}."/".$confStr{MC_FILE_CODES_SEISMES};
@typeEvnt = readCfgFile("$fileEvnt");
print " Type: <select name=\"type\" size=\"1\">";
print "<option selected value=\"ALL\">--</option>\n";
for (sort(@typeEvnt)) {
	my @liste=split(/\|/,$_);
	if ($liste[0] eq $selectedType) {
		print "<!-- ($liste[0])-($selectedType) -->";
		print "<option selected value=$liste[0]>$liste[1]</option>\n";
	} else {
		print "<option value=$liste[0]>$liste[1]</option>\n";
	}
}
print "</select>\n";

# ----- Boite Selection DUREE
print " Durée: <select name=\"duree\" size=\"1\">";
print "<option selected value=\"ALL\">--</option>";
for (10,20,30,40,50,60,80,100,120,150,180) {
	my $d;
	$d = sprintf("%d'%02d\"",int($_ / 60),($_ % 60));
	if ($_ eq $selectedDuree) {
		print "<option selected value=$_>$d</option>\n";
	} else {
		print "<option value=$_>$d</option>";
	}
}
print "</select>\n";

# ----- Boite Selection AMPLITUDE
print " Amplitude: <select name=\"amplitude\" size=\"1\">";
print "<option selected value=\"ALL\">--</option>";
for ("Faible", "Moyenne", "Forte", "Sature") {
	if ($_ eq $selectedAmplitude) {
		print "<option selected value=$_>$_</option>\n";
	} else {
		print "<option value=$_>$_</option>";
	}
}
print "</select>\n";

# ----- Boite Selection OBSERVATION
my $msg = "Le filtre fonctionne avec une <a href=http://perl.enstimac.fr/DocFr/perlretut.html target=_blank>expression rationnelle</a> (<i>regular expression</i>) et un grep qui ne tient pas compte de la casse. ".
"Pour la n&eacute;gation, ajouter un point d&rsquo;exclamation en d&eacute;but d&rsquo;expression. ".
"Conseil pour les accents: remplacer chaque caract&egrave;re sp&eacute;cial par un point et une &eacute;toile.".
"<hr><H3 aling=left>Exemples</H3><UL align=left>".
"<LI><B>volc</B> = tous les volcaniques <i>VOLCTECT</i>, <i>VOLCLP</i>, <i>VOLCEMB</i>, etc...".
"<LI><B>!TECT</B> = ne contient pas le mot <i>TECT</i>".
"<LI><B>r.*plique</B> = <i>R&eacute;plique</i> ou <i>replique</i>".
"<LI><B>saintes</B> = <i>saintes</i>, <i>SAINTES</i> ou encore <i>Saintes</i>".
"<LI><B>TBGZ|saintes</B> = <i>TBGZ</i> ou <i>saintes</i>".
"</UL>";
		     
print " Filtre: <input type=\"text\" name=\"obs\" size=15 value=\"$selectedObservation\" onMouseOut=\"nd()\" onmouseover=\"overlib('$msg',CAPTION, 'INFORMATIONS',STICKY,WIDTH,300)\">";
if ($selectedObservation ne "") {
	print "<img style=\"border:0;vertical-align:text-bottom\" src=\"/images/cancel.gif\" onClick=effaceFiltre()>";
}

print ' <input type="submit" value=" Afficher"></P>';
print "</form>";

# ----- FIN DU FORMULAIRE DE SELECTION
# -----------------------------------------

print "<TABLE width=\"100%\"><TR><TD style=\"border:0;text-align:left\">",
	"<H2>$confStr{MC_TITRE}</H2>",
	"<P>[ <A href=\"/\" target=\"_top\">Accueil</A> | <A href=\"#Note\">Note Explicative</A> | <A href=\"/$confStr{MC_PATH_WEB}/MC.png\">Graphe</A> ]</P>";

# Affichage de la Main Courante
# - - - - - - - - - - - - - - - - - - - - - - -
affiche ($dt1,$dt2,$selectedType,$selectedDuree,$selectedAmplitude,$selectedObservation);

# Affiche la note explicative
# - - - - - - - - - - - - - - - - - - - - - - -
print "<HR><A name=\"Note\"></A>";
print @infoTexte;
print "<HR>";

# Fin de la page
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
print <<"FIN";
<style type="text/css">
	#attente
	{
		display: none;
	}
</style>

<br>
@signature
</body>
</html>
FIN



