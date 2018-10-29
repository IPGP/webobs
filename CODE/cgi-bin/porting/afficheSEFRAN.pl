#!/usr/bin/perl
#---------------------------------------------------------------
# ------------- COMMENTAIRES -----------------------------------
# Auteur: Alexis Bosson, Francois Beauducel
# ------
# Usage: Script d'affichage et de depouillement du SEFRAN2
# 


# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use i18n;
use Webobs;

$|=1;
# ----------------------------------------------------
# -------- Fichiers de configurations ----------------
# ----------------------------------------------------
use readConf;
use readGraph;

# ----------------------------------------------------
# ----- Lecture des fichiers de configuration
my %WEBOBS = readConfFile;
my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
my @graphKeys = keys(%graphStr);
my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");
my @oper = readUsers;

# ----------------------------------------------------
# -------- Controle la validite de l'IP  -------------
# ----------------------------------------------------
use checkIP;
my $displayOnly = 0;
my $displayFlag = "private";
my $IP = $ENV{REMOTE_ADDR};
my $ipTest = checkIP($IP);
if ($ipTest != 0) {
	$displayOnly = 1;
	$displayFlag = "public";
}

# ---------------------------------------------------------------
# ------------ MAIN ---------------------------------------------
# ---------------------------------------------------------------

# ---------------------------------------------------------------
# Definition des variables

$ENV{TZ} = "America/Guadeloupe";
my $tz_old = $ENV{TZ};
$ENV{LANG} = $WEBOBS{LOCALE};

my $header = $cgi->url_param('header');
my $limite = $cgi->url_param('limite');
my $voies_classiques = $cgi->url_param('va');
if ($limite < 0) {
	$limite=1000;
}
my $date = $cgi->url_param('date');

my $prog ="/cgi-bin/$WEBOBS{CGI_AFFICHE_SEFRAN2}";

# ----- Jour et heure courants (en UTC)...
my $minute = qx(date --utc +\%M); chomp($minute);
my $heure = qx(date --utc +\%H); chomp($heure);
my $jour = qx(date --utc +\%d); chomp($jour);
my $mois = qx(date --utc +\%m); chomp($mois);
my $annee = qx(date --utc +\%Y); chomp($annee);
my $today = qx(date --utc -I); chomp($today);

my $titrePage = $WEBOBS{SEFRAN2_TITRE};
my @html;
my @csv;

my $affiche;
my $s;

my @dates;
for (0..($WEBOBS{GRAVURE_OLD_DATA_JOURS}+1)) {
	$s = qx(date -d "$today $_ days ago" +"\%Y-\%m-\%d"); chomp($s);
	push(@dates,$s);
}
my @listeHeures = reverse('00'..'23');
my %liste_limites = (
	0 => "Main courante",
	6 => "6 heures",
	12=>"12 heures",
	24=>"24 heures",
	168=>"1 semaine",
	1000=>"Tout"
);
my $largeur_image = $WEBOBS{MIX_DURATION_VALUE}*$WEBOBS{SEFRAN2_VALUE_SPEED}*$WEBOBS{SEFRAN_VALUE_PPI}/60+1;
my $hauteur_image = $WEBOBS{SEFRAN2_HEIGHT_INCH}*$WEBOBS{SEFRAN_VALUE_PPI}+1;
my $largeur_fleche = 50;
my $hauteur_titre = 20;

# ---------------------------------------------------------------
# Debut de l'affichage de la page

print $cgi->header(-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<html><head><title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">";

if (!$date) {
	print "<meta http-equiv=\"refresh\" content=\"30\">

	<script type=\"text/javascript\">
	<!--
	function sefran()
	{
		window.open('$prog?date=' + formulaire.ad_date.value + formulaire.ad_heure.value);
	}
	//-->
	</script>";
}

print <<html;
<style type="text/css">
html,body,td {
	padding: 0;
	margin: 0;
	border-collapse: collapse;
	border: 0;
}
body {
}
img.voies-permanentes {
	position: absolute;
}
html
if (! $voies_classiques) {
	print <<html;
img.voies-dynamiques {
	display: none;
}
#sefran:hover img.voies-dynamiques {
	display: block;
	position: fixed;
	z-index: 1;
	left: 0;
	top: 0;
}
html
}
print <<html;

table.sefran {
	margin-left: ${largeur_image}px;
}
td.bouton {
	font-size: 1.5em;
	font-weight: bold;
	}
td.rien,td.fin {
	color: white;
	text-align:center;
	padding: 1ex;
	border: 1px solid white;
	font-size: 15px;
	white-space:nowrap;
}
td.rien div,td.fin div {
	width: ${largeur_image}px;
}
td.rien {
	background-color: red;
}
td.recent {
	background-color: white;
	color: lightgray;
}
td.fin {
	background-color: white;
	color: lightblue;
}
.suds img
{
	border-bottom: 10px solid white;
}
.suds map:hover img
{
	border-bottom: 10px solid lightblue;
}
</style>
</head>
<body>
<!--DEBUT DU CODE ROLLOVER 2-->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/JavaScripts/overlib.js"></script>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->
html

# Cas de l'affichage d'une tranche horaire (depouillement)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if ($date) {
	# Year, month, day, hour pour l'heure courante affich�e (c) actuelle (a), r�cent (r), pr�cedente (p), suivante (s)
	my ($Yc,$mc,$dc,$Hc) = unpack("a4 a2 a2 a2",$date);
	use Data::Dumper;
	my ($Ya,$ma,$da,$Ha,$Ma,$Sa) = split('/',qx(date --utc +"%Y/%m/%d/%H/%M/%S"|xargs echo -n));
	my ($Yr,$mr,$dr,$Hr,$Mr,$Sr) = split('/',qx(date -d "10 minutes ago" --utc +"%Y/%m/%d/%H/%M/%S"|xargs echo -n));
	my ($Yp,$mp,$dp,$Hp,$Mp,$Sp) = split('/',qx(date -d "$Yc-$mc-$dc $Hc:00:00 1 hour ago" +"%Y/%m/%d/%H/%M/%S"|xargs echo -n));
	my ($Ys,$ms,$ds,$Hs,$Ms,$Ss) = split('/',qx(date -d "$Yc-$mc-$dc $Hc:00:00 1 hour" +"%Y/%m/%d/%H/%M/%S"|xargs echo -n));
	my $voies = "$WEBOBS{SEFRAN2_PATH_WEB}/$Yc$mc$dc/$WEBOBS{SEFRAN2_VOIES_IMAGE}";

	# construit la liste des images de l'heure (+ 1 image precedente + 1 image suivante)
	my @liste_png;


	push(@liste_png,sprintf("%s/%04d%02d%02d/%s/%04d%02d%02d%02d5900gwa.png",$WEBOBS{SEFRAN2_RACINE},$Yp,$mp,$dp,$WEBOBS{SEFRAN2_IMAGES_SUDS},$Yp,$mp,$dp,$Hp));
	my $i;
	for ($i=0;$i<60;$i++) {
		push(@liste_png,sprintf("%s/%04d%02d%02d/%s/%04d%02d%02d%02d%02d00gwa.png",$WEBOBS{SEFRAN2_RACINE},$Yc,$mc,$dc,$WEBOBS{SEFRAN2_IMAGES_SUDS},$Yc,$mc,$dc,$Hc,$i));
	}
	push(@liste_png,sprintf("%s/%04d%02d%02d/%s/%04d%02d%02d%02d0000gwa.png",$WEBOBS{SEFRAN2_RACINE},$Ys,$ms,$ds,$WEBOBS{SEFRAN2_IMAGES_SUDS},$Ys,$ms,$ds,$Hs));
	my $fin = 0;
	my $reload = 0;
	
	print "<div id=\"sefran\">";
	print "<img class=\"voies-permanentes\" src=\"/$voies\">\n";
	if (! $voies_classiques) {
		print "<img class=\"voies-dynamiques\" src=\"/$voies\">\n";
	}
	print "<TABLE class=\"sefran\"><tr>\n";
	print "<td class=\"bouton\"><a href=\"$prog?date=$Yp$mp$dp$Hp\">&lt;&lt;</a></td>\n";
	print "<td class=\"suds\">";
	for (@liste_png) {
		my $png = qx(basename $_); chomp $png;
		my ($Y,$m,$d,$H,$M,$S) = unpack("a4 a2 a2 a2 a2 a2",$png);
		if ( -f $_ ) {
			my $png_web = "/$WEBOBS{SEFRAN2_PATH_WEB}/$Y$m$d/$WEBOBS{SEFRAN2_IMAGES_SUDS}/$png";
			my $suds = substr($png,0,8)."_".substr($png,8,6).".".substr($png,14,3);
			my $suds_sig = "/$WEBOBS{PATH_SOURCE_SISMO_MIX}/".substr($png,0,8)."/$suds";

			print "<map name=\"$png\"><area href=\"#\" 
			onclick=\"window.open('$WEBOBS{CGI_MC_SEFRAN2}?f=$suds_sig','main courante $suds','width=1024,height=768,scrollbars=yes'); return false;\"
			onMouseOut=\"nd()\" onMouseOver=\"overlib('Lancer la Main Courante sur le fichier $suds',FGCOLOR,'#FFAAAA')\" shape=rect coords=\"0,0,121,20\" alt=\"Main courante $suds\"><area href=\"$WEBOBS{WEB_RACINE_SIGNAUX}/$suds_sig\" onMouseOut=\"nd()\" onMouseOver=\"overlib('Cliquer pour voir les signaux du fichier $suds')\" shape=rect coords=\"0,21,121,699\" alt=\"Signal $suds\">";
			print "<img border=0 width=$largeur_image height=$hauteur_image src=\"$png_web\" usemap=\"#$png\">";
			print "</map>";
		} elsif ( "$Y$m$d$H$M" >= "$Ya$ma$da$Ha$Ma") {
			if (!$fin) {
				print "</td><td style=\"padding: 0; vertical-align: top;\"><div style=\"margin-top:20px;margin-bottom: auto;\"><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"><br><img border=0 width=87 height=48 src=\"/images/aiguille.gif\"></div></td><td class=\"fin\"><div>Maintenant<br>$Ya-$ma-$da<br>$Ha:$Ma:$Sa UTC</div></td><td class=\"suds\">";
				if (!$reload) {
					print "<script>setTimeout('window.location.reload()',30000)</script>";
					$reload = 1;
				}
				$fin = 1;
			}
		} elsif ( "$Y$m$d$H$M" >= "$Yr$mr$dr$Hr$Mr") {
			print "</td><td class=\"rien recent\"><div><img border=0 width=50 height=50 src=\"/images/wait.gif\"><br>En cours<br>$Y-$m-$d<br>$H:$M:$S UTC</div></td><td class=\"suds\">";
			if (!$reload) {
				print "<script>setTimeout('window.location.reload()',30000)</script>";
				$reload = 1;
			}
		} else {
			print "</td><td class=\"rien\"><div>Pas d'image<br>$Y-$m-$d<br>$H:$M:$S UTC</div></td><td class=\"suds\">";
		}
	}
	print "</td>";
	if ($fin == 0) {
		print "<td align=center valign=middle style=\"border:0;font-variant:small-caps;font-weight:bold;font-size: 1.5em;\"><a href=\"$prog?date=$Ys$ms$ds$Hs\">&gt;&gt;</a></td>\n";
	}

	print "</tr></TABLE>";
	print "</div>";
	if ($voies_classiques) {
		print "<a href=\"$prog?date=$Ya$ma$da$Ha&va=0\">Afficher les voies dynamiquement</a>";
	} else {
		print "<a href=\"$prog?date=$Ya$ma$da$Ha&va=1\">Ne pas afficher les voies dynamiquement</a>";
	}
	print "</BODY></HTML>";
}

# Cas de l'affichage des vignettes (defaut)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
else {

	my $dernier_mc = qx(ls $WEBOBS{MC_RACINE}/$WEBOBS{MC_PATH_FILES}/*.txt|tail -n 1|xargs head -n 1|awk -F'[|:]' '{print \$2,\$3}');
	chomp($dernier_mc);

	# Debut du formulaire pour la selection de l'affichage
	# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	print "<TABLE>";

	if ($header) {
	print "<tr>
<td colspan=2 align=left style=\"border:0\"><h2>$titrePage</h2>
<p>[ <a href=\"/cgi-bin/afficheRESEAUX.pl?noaffiche=0\">R&eacute;seaux</a>
| <a href=\"/$WEBOBS{SEFRAN2_PATH_WEB}\">Fichiers</a> 
| <a href=\"/cgi-bin/afficheRESEAUX.pl?noaffiche=0\&discipline=S\">Sismologie</a> 
| <a href=\"/auto/sismohyp_visu.htm\">Hypocentres</a> 
| <a href=\"/auto/sismobul_visu.htm\">Bulletins</a> 
| <a href=\"/auto/sismocp_visu.htm\">Tambours CP</a> 
| <a href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_MC}\">Main Courante</a> 
| <a href=\"/$WEBOBS{MC_PATH_WEB}/MC.png\">Graphe MC</a> 
| <a href=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_SEFRAN}\">Ancien SEFRAN IASPEI</a> ]</p>
</td>
<td align=center style=\"border:0\"><h2>$annee-$mois-$jour<br>$heure:$minute UTC</h2></td>
</tr>";
	}

	print <<html;
	<FORM name="formulaire" action="" method="get">
	<tr><th>
	<select name="limite" size="1" onchange="submit();">
html

	for my $id_limite (sort { $a <=> $b } keys %liste_limites) { print "<option ".($limite==$id_limite?"selected ":"")."value=\"".$id_limite."\">".$liste_limites{$id_limite}."</option>\n"; }
	print <<html;
	</select>
	</th>
	<th colspan=2>
	Accès direct </b><select name="ad_date" size="1">
html

	for (@dates) { print "<option value=\"".substr($_,0,4).substr($_,5,2).substr($_,8,2)."\">$_</option>\n"; }
	print <<html;
	</select><select name="ad_heure" size="1">
html

	for (@listeHeures) { print "<option ".($_ eq $heure?"selected ":"")."value=$_>".sprintf("%02d à %02d UTC",$_,($_+1)%24)."</option>\n"; }
	print <<html;
	</select><input type=button value="Dépouillement" onClick="sefran()">
	<input type=hidden name="header" value="$header">
	</th></tr>
	</FORM>
html

my $nb_heures = 0;
my $aff_lim=0;
for (@dates) {
	my $dd = $_;
	my $da = substr($_,0,4);
	my $dm = substr($_,5,2);
	my $dj = substr($_,8,2);
	my $ddd = "$da$dm$dj";
	my $dt = l2u(qx(date -d $_ +"\%A \%-d \%B \%Y UTC"));
	my $nb_heures_jour=0;
	for (@listeHeures) {
		my $hh = $_;
		my $hl = ($hh-4)%24;
		if (($today ne $dd)||($heure ge $hh)) {
			if (
				(
					$limite != 0
					&&
					(
						$limite == 1000
						||
						++$nb_heures <= $limite
					)
				)
				||
				(
					$limite == 0
					&&
					(
						$dd." ".$hh ge $dernier_mc
					)
				)
			) {
				$nb_heures_jour++;
				my $f = "$ddd/images/$ddd$hh\_sefran.jpg";
				print "<TR><TD style=\"border:0\" align=center>$da-$dm-$dj<br><font size=\"4\"><b>$hh</b></font>h UTC</br>$hl\h AST</TD>";
				if (-e "$WEBOBS{SEFRAN2_RACINE}/$f") {
					#print "<TD style=\"border:0\"><A href=\"/$WEBOBS{SEFRAN2_PATH_WEB}/$ddd/$ddd$hh\_sefran.htm\" target=\"_blank\">
					print "<TD style=\"border:0\"><A href=\"$prog?date=$ddd$hh\" target=\"_blank\">
					<IMG src=\"/$WEBOBS{SEFRAN2_PATH_WEB}/$f\" border=\"1\">";
				} else {
					print "<TD style=\"border:0\" class=\"noImage\">pas d'image</TD></TR>\n";
				}
			}
		}
	}
	if ($nb_heures_jour > 0) {
		print "<TR><TD style=\"border:0\" colspan=2 class=daySefran>&uArr;&nbsp;&nbsp;$dt&nbsp;&nbsp;&uArr;</TD></TR>\n";
	}

}

	print "</TABLE><BR>";

	my @notes = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{SEFRAN2_FILE_NOTES}");
	print @notes;
	
	print "Résolution écran = <B>".($WEBOBS{SEFRAN2_VALUE_SPEED}*$WEBOBS{SEFRAN_VALUE_PPI}/60)." pixels/s</B><BR>
	Vitesse de défilement virtuelle = <B>$WEBOBS{SEFRAN2_VALUE_SPEED} \"/mn</B> (soit ".($WEBOBS{SEFRAN_VALUE_SPEED}*2.54)." cm/mn)<BR>
	</P>@signature</BODY></HTML>";
}

