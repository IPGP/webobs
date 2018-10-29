#!/usr/bin/perl
#---------------------------------------------------------------
# WEBOBS: formulaireFISSURO.pl ------------------------------------
# ------
# Usage: This script allows to edit data from fissurometry
# network of OVSG.
# 
# Author: François Beauducel, IPGP
# Created: 2009-08-31
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
# ---- External modules
use Webobs;
use readConf;
use readGraph;

# ----------------------------------------------------
# ---- Configuration files
my %WEBOBS = readConfFile;
$ENV{TZ} = "America/Guadeloupe";
my $tz_old = $ENV{TZ};
$ENV{LANG} = $WEBOBS{LOCALE};

my $titrePage = "&Eacute;dition - $WEBOBS{FISSURO_TITLE}";
my $titre2 = "Saisie de nouvelles donnÃ©es";
my $fileDATA = $WEBOBS{RACINE_DATA_DB}."/".$WEBOBS{FISSURO_FILE_NAME};
my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");
my @users = readUsers;
my @donneeListe = ('1'..'12');

# ---- Control of user validity
my $USER = $ENV{"REMOTE_USER"};
my $idUser = -1;
my $userTest = 1;
my $userLevel = -1;
my $userId;
my $nb = 0;
while ($nb <= $#users) {
	if ($USER ne "" && $USER eq $users[$nb][3] && $users[$nb][2] ge $WEBOBS{FISSURO_LEVEL}) {
		$idUser = $nb;
		$userTest = 0;
		$userId = $users[$nb][0];
	}
	$nb++;
}
if ($userTest != 0) { die "WEBOBS: Sorry, this form is not allowed."; }
if ($idUser ge 0) { $userLevel = $users[$idUser][2]; }


# ---- Read the data file
my @lignes;
if ( -e $fileDATA ) {
	open(FILE, "<$fileDATA") || die "WEBOBS: file $fileDATA not found.\n";
	tell(FILE);
	while(<FILE>) {
		push(@lignes,$_);
	}
	close(FILE);
}

# ---- Retrieve parameters (GET)
my $submitMode = 0;
my $jvs = "onLoad=\"calc();derniere_mesure()\"";
my @paramGET = $cgi->url_param();
my $parametreId;
if (grep(/submit/,@paramGET)) {
	$submitMode = 1;
	$titre2 = "Confirmation d'enregistrement";
	$jvs = "";
} elsif (grep(/id/,@paramGET)) {
	$parametreId = $cgi->url_param('id');
	$titre2 = "Modification donnÃ©e nÂ° $parametreId";
}

# ---- Begin HTML display
print "Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<HTML><HEAD>\n
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
	
<!--DEBUT DU CODE ROLLOVER 2-->
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/JavaScripts/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->
	
<!-- Affichage des bulles d'aide -->
<DIV ID=\"helpBox\"></DIV>
<!-- to avoid press ENTER validates the form -->
<script type=\"text/javascript\">
function stopRKey(evt) {
	  var evt = (evt) ? evt : ((event) ? event : null);
	  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
	  if ((evt.keyCode == 13) && (node.type==\"text\"))  {return false;}
}
document.onkeypress = stopRKey;
</script>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" $jvs>\n";
	
print "<TABLE width=\"100%\"><TR><TD style=\"border:0\">
<H1>$titrePage</H1>\n<H2>$titre2</H2>
</TD><TD style=\"border:0;vertical-align:top;text-align:right\">Utilisateur identifiÃ©:<BR>";
if ($idUser gt -1) {
	print "<B>$users[$idUser][1]</B><BR><I>(niveau $userLevel)</I>";
} else {
	print "login: <B>$USER</B>";
}
print "</TD></TR></TABLE>";


# ================================================================
# ==== A. Submit mode: process the form
if ($submitMode) {

	# --- Retrieve parameters (POST)
	my $id = $cgi->param('id');
	my $annee = $cgi->param('annee');
	my $mois = $cgi->param('mois');
	my $jour = $cgi->param('jour');
	my $hr = $cgi->param('hr');
	my $mn = $cgi->param('mn');
	my $site = $cgi->param('site');
	my @oper = $cgi->param('oper');
	my $operateurs = join("+",@oper);
	my $temp = $cgi->param('temp');
	my $meteo = $cgi->param('meteo');
	my $instr = $cgi->param('instr');
	my $comp = $cgi->param('comp');
	my @d;
	for (@donneeListe) {
		$d[$_-1][0] = $cgi->param('p'.$_);
		$d[$_-1][1] = $cgi->param('l'.$_);
		$d[$_-1][2] = $cgi->param('v'.$_);
	}
	my $rem = $cgi->param('rem');
	my $val = $cgi->param('val');

	my $date = "$annee-$mois-$jour";
	my $heure = "$hr:$mn";

	my $idData;

	# stamp date and staff
	my $today = qx(date -I); chomp($today);
	my $stamp = "[$today $users[$idUser][0]]";
	if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

	# ---- Creates a backup file
	my $fileBCKP = "$fileDATA.backup";
	if (-e $fileDATA) {
		print "<P>Lecture du fichier de donn&eacute;es: \"<B>$fileDATA</B>\".</P>\n";
		qx(cp -a $fileDATA $fileBCKP);
		print "<P>Cr&eacute;ation d'un fichier de sauvegarde: \"<B>$fileBCKP</B>\".</P>\n";
	}

	print "<P>Information de saisie: <B>$stamp</B>.</P>\n";
	
	if ($id ne "") {
		$idData = $id;
		print "<P>Modification d'une donn&eacute;e existante:</P>\n";
	} else {
		print "<P>Ajout d'une nouvelle donn&eacute;e:</P>\n";
	}

	# header
	my $entete = "ID|Date|Heure|Site|Opérateurs|Température|Météo|Instrument|Composante";
	for (@donneeListe) {
		$entete = $entete."|Perp$_|Para$_|Vert$_";
	}
	$entete = $entete."|Remarques|Validation\n";

	# rebuilts the data array
	my @donnees;
	my $idMax = 0;
	for (@lignes) {
		my @dd = split(/\|/,$_);
		if ($dd[0] > $idMax) {
			$idMax = $dd[0];
		}
		if ($dd[0] ne $id && $dd[0] > 0) {
			push(@donnees,$_);
		}
	}
	if ($id eq "") {
		$idData = $idMax+1;
	}
	my $nouveau = "$idData|$date|$heure|$site|$operateurs|$temp|$meteo|$instr|$comp";
	for (@donneeListe) {
		$nouveau = $nouveau."|$d[$_-1][0]|$d[$_-1][1]|$d[$_-1][2]";
	}
	$nouveau = u2l($nouveau."|$rem|$val\n");
	print "<TABLE><TR><TH>".join("</TH><TH>",split(/\|/,l2u($entete)))."</TH></TR>"
		."<TR><TD>".join("</TD><TD>",split(/\|/,l2u($nouveau)))."</TD></TR></TABLE>";

	# writes the new file
	open(FILE, ">$fileDATA") || die "WEBOBS: cannot write on file $fileDATA !";
	print FILE $entete;
	print FILE @donnees;
	print FILE $nouveau;
	close(FILE);
	print "<P>&Eacute;criture du fichier de donn&eacute;es: \"<B>$fileDATA</B>\".</P>\n";

	print "<HR><FORM action=\"input_button.htm\"><TABLE width=\"100%\"><TR>
		<TD style=\"border:0;text-align:center\"><input type=button name=lien value=\"Retour &agrave; WEBOBS\" onClick=\"document.location='/'\"></TD>";
	if ($id eq "") {
		print "<TD style=\"border:0;text-align:center\"><input type=button name=lien value=\"Poursuite de la saisie\" onClick=\"document.location='/cgi-bin/formulaireFISSURO.pl?date=$date&amp;heure=$heure&amp;oper=$operateurs'\"><br>
			(pr&eacute;s&eacute;lectionne m&ecirc;mes date et op&eacute;rateurs)</TD>";
	}
	print "<TD style=\"border:0;text-align:center\"><input type=button name=lien value=\"Affichage des donnÃ©es\" onClick=\"document.location='/cgi-bin/$WEBOBS{CGI_AFFICHE_FISSURO}'\"></TD>
		</TR></TABLE>\n";

	    
}
# ================================================================
# ==== B. Edit mode: edit the form
else {

	my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
	my @graphKeys = keys(%graphStr);
	my @reseaux = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_NETWORK}");
	my @typeInstr = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_TYPE}");
	my @typeComp = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_COMPONENT}");
	my @typeMeteo = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FISSURO_FILE_METEO}");
	my %nomMeteo;
	my @stations;
	my @codesListe;
	
	for (@reseaux) {
		my $codeRes = $_;
		chomp($codeRes);
		my @sta = qx(/bin/ls -d $WEBOBS{RACINE_DATA_STATIONS}/$codeRes*);
		my $res = $graphStr{"nom_".$graphStr{"routine_$codeRes"}};
		for (@sta) {
			my $s = substr($_,length($_)-8,7);
                	my %config = readConfStation($s);
			if ($config{VALIDE} && $config{DATA_FILE} ne "-") {
				push(@codesListe,"$s|$res / $config{ALIAS}: $config{NOM}");
				push(@stations,$s);
			}
		}
	}
	
	my $anneeActuelle = qx(date +\%Y);
	my @anneeListe = ($WEBOBS{FISSURO_BANG}..$anneeActuelle);
	my @moisListe = ('01'..'12');
	my @jourListe = ('01'..'31');
	my @heureListe = ('','00'..'23');
	my @minuteListe = ('','00'..'59');
	
	# ---- Retrieve the last data for Javascript preset
	# sort the data by date
	@lignes = reverse sort tri_date_avec_id @lignes;
	# very last available data
	my (@lastData) = split(/\|/,$lignes[$#lignes - 1]);
	# last measurement for each site
	my @lastMeasure;
	my $i;
	for ($i = 0; $i <= $#stations; $i++) {
		for (@typeComp) {
			my ($cmp,$nam) = split(/\|/,$_);
			my @tmp = grep(/\|$stations[$i]\|.*\|$cmp\|/,@lignes);
			my @ddd = split(/\|/,$tmp[$#tmp]);
			my @moy = (0,0,0);
			my @n = (0,0,0);
			for (@donneeListe) {
				if ($ddd[($_-1)*3+9] ne "") {
					$moy[0] += $ddd[($_-1)*3+9];
					$n[0]++; 
				}
				if ($ddd[($_-1)*3+10] ne "") {
					$moy[1] += $ddd[($_-1)*3+10];
					$n[1]++; 
				}
				if ($ddd[($_-1)*3+11] ne "") {
					$moy[2] += $ddd[($_-1)*3+11];
					$n[2]++; 
				}
			}
			if ($n[0] > 0) { $moy[0] /= $n[0]; }
			if ($n[1] > 0) { $moy[1] /= $n[1]; }
			if ($n[2] > 0) { $moy[2] /= $n[2]; }
			$lastMeasure[$i]{$cmp} = sprintf("\%s = %1.2f / %1.2f / %1.2f mm (\%s)",$ddd[8],$moy[0],$moy[1],$moy[2],$ddd[1]);
		}
	}
	
	# ---- Preset of form parameters
	my $sel_annee = qx(date +\%Y); chomp($sel_annee);
	my $sel_mois = qx(date +\%m); chomp($sel_mois);
	my $sel_jour = qx(date +\%d); chomp($sel_jour);
	my $sel_hr;
	my $sel_mn;
	my $sel_site;
	my $sel_meteo = "variable";
	my $sel_temp;
	my $sel_instr;
	my $sel_comp;
	my @sel_d;
	my @sel_oper = $users[$idUser][0];
	my $sel_rem;
	my $sel;
	
	
	# Retrieve parameters (GET)
	# - - - - - - - - - - - - - - - - - - - - - - -
	my ($id,$date,$heure,$site,$ope,$temp,$meteo,$instr,$comp,$rem,$val) = split(/\|/,"");
	my @d;
	
	# ---- new data: possible field preset (date and staff)
	if (grep(/date/,@paramGET)) {
		my $par = $cgi->url_param('date');
		if (length($par) == 10) {
			$sel_annee = substr($par,0,4);
			$sel_mois = substr($par,5,2);
			$sel_jour = substr($par,8,2);
		}
	}
	if (grep(/heure/,@paramGET)) {
		my $par = $cgi->url_param('heure');
		if (length($par) == 5) {
			$sel_hr = substr($par,0,2);
			$sel_mn = substr($par,3,2);
		}
	}
	if (grep(/oper/,@paramGET)) {
		my $par = $cgi->url_param('oper');
		if ($par ne "") {
			@sel_oper = split(/\ /,$par);	# note: GET replaces '+' by a space ("&oper=FB+JCK" => $par = "FB JCK")
		}
	}
	
	
	# ---- data modification: get all fields from data file
	if (grep(/id/,@paramGET)) {
		my @ligneId = grep(/^$parametreId\|/,@lignes);
		if (@ligneId ne "") {
			($id,$date,$heure,$site,$ope,$temp,$meteo,$instr,$comp,$d[0][0],$d[0][1],$d[0][2],$d[1][0],$d[1][1],$d[1][2],$d[2][0],$d[2][1],$d[2][2],$d[3][0],$d[3][1],$d[3][2],$d[4][0],$d[4][1],$d[4][2],$d[5][0],$d[5][1],$d[5][2],$d[6][0],$d[6][1],$d[6][2],$d[7][0],$d[7][1],$d[7][2],$d[8][0],$d[8][1],$d[8][2],$d[9][0],$d[9][1],$d[9][2],$d[10][0],$d[10][1],$d[10][2],$d[11][0],$d[11][1],$d[11][2],$rem,$val) = split (/\|/,$ligneId[0]);
			$sel_annee = substr($date,0,4);
			$sel_mois = substr($date,5,2);
			$sel_jour = substr($date,8,2);
			$sel_hr = substr($heure,0,2);
			$sel_mn = substr($heure,3,2);
			$sel_site = $site;
			$sel_meteo = lc($meteo);
			$sel_temp = $temp;
			$sel_instr = $instr;
			$sel_comp = $comp;
			@sel_oper = split(/\+/,$ope);
	
			@sel_d = @d;
			$sel_rem = l2u($rem);
			chomp($val);
		} else {
			$parametreId = "";
			$val = "";
		}
	}
	
	print "<BODY style=\"background-color:#E0E0E0\" onLoad=\"calc();derniere_mesure()\">
	<script type=\"text/javascript\">
	
	<!--
	
	function verif_formulaire()
	{
		var i;
		
		if(document.formulaire.hr.value == '') {
			alert('Veuillez indiquer une heure!');
			document.formulaire.hr.focus();
			return false;
		}
		if(document.formulaire.mn.value == '') {
			alert('Veuillez indiquer les minutes!');
			document.formulaire.mn.focus();
			return false;
		}
		if(document.formulaire.oper.value == '') {
			alert('Veuillez choisir au moins 1 opÃ©rateur dans la liste!');
			document.formulaire.oper.focus();
			return false;
		}
		if(document.formulaire.site.value == '') {
			alert('Veuillez spÃ©cifier le site de mesure!');
			document.formulaire.site.focus();
			return false;
		}
		if(document.formulaire.instr.value == '') {
			alert('Veuillez indiquer un instrument de mesure!');
			document.formulaire.instr.focus();
			return false;
		}
		if (document.formulaire.comp.value == '') {
			alert('Veuillez indiquer le fissurometre!');
			document.formulaire.comp.focus();
			return false;
		}
		if(document.formulaire.moy.value == 0) {
			alert('Veuillez indiquer au moins une mesure!');
			document.formulaire.p1.focus();
			return false;
		}
		
	}
	
	function calc()
	{
		var moyp = 0;
		var sigp = 0;
		var np = 0;
		var moyl = 0;
		var sigl = 0;
		var nl = 0;
		var moyv = 0;
		var sigv = 0;
		var nv = 0;
		var v;
		var i;
		var ns = '';
		var rouge = '#FF0000';
		var orange = '#FFD800';
		var vert = '#66FF66';
		var blanc = '#FFFFFF';
	
		for (i=0;i<formulaire.oper.length;i++) {
			if (formulaire.oper.options[i].selected) {
				if (ns != '') ns = ns + '\\n';
				ns = ns + formulaire.oper.options[i].value;
			}
		}
		formulaire.nomselect.value = ns;
		";
		
		for (@donneeListe) {
			print "if (formulaire.p$_.value != '') {
			v = formulaire.p$_.value*1;
			moyp += v; sigp += v*v; np++;
			}
			if (formulaire.l$_.value != '') {
			v = formulaire.l$_.value*1;
			moyl += v; sigl += v*v; nl++;
			}
			if (formulaire.v$_.value != '') {
			v = formulaire.v$_.value*1;
			moyv += v; sigv += v*v; nv++;
			}\n";
		}
	
		for ("p","l","v") {
			print "	if (n$_ > 0) {
			moy$_ = moy$_/n$_;
			sig$_ = 2*Math.sqrt(sig$_/n$_ - moy$_*moy$_);
		}
		formulaire.moy$_.value = moy$_.toFixed(2);
		formulaire.sig$_.value = sig$_.toFixed(2);
		formulaire.sig$_.style.background = vert;
		if (sig$_ > 0.2) formulaire.sig$_.style.background = orange;
		if (sig$_ > 1) formulaire.sig$_.style.background = rouge;";
		}
	print "}
	
	function derniere_mesure()
	{
		if (formulaire.comp.value == '' || formulaire.site.value == '') {
			formulaire.prevmes.value = '';
		} else {
			formulaire.prevmes.value = eval('formulaire.' + formulaire.site.value + '_' + formulaire.comp.value + '.value');
		}
	}
	window.captureEvents(Event.KEYDOWN);
	window.onkeydown = calc();
	//-->
	</script>";
	

	print "<FORM name=formulaire action=\"/cgi-bin/".basename($0)."?submit=\" method=post onSubmit=\"return verif_formulaire()\">";
	
	
	# Retrieve data ID if exists
	if ($parametreId ne "") {
	   print "<input type=\"hidden\" name=\"id\" value=\"$parametreId\">";
	}
	
	print "<input type=\"hidden\" name=\"user\" value=\"$userId\">\n";
	
	print "<TABLE width=\"100%\" style=border:0 onMouseOver=\"calc()\">
	<TR><TD style=border:0 valign=top nowrap>
	<H3>Date, site et op&eacute;rateurs</H3>
	<P class=parform>
	<B>Date: </b><select name=annee tabindex=1 size=\"1\">";
	for (@anneeListe) {
	    if ($_ == $sel_annee) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=mois tabindex=2 size=\"1\">";
	for (@moisListe) {
	    if ($_ == $sel_mois) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=jour tabindex=3 size=\"1\">";
	for (@jourListe) { 
	    if ($_ == $sel_jour) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	
	print "&nbsp;&nbsp;<b>Heure: </b><select name=hr tabindex=4 size=\"1\">";
	for (@heureListe) { 
	    if ($_ eq $sel_hr) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}      
	print "</select>";
	print " <select name=mn tabindex=5 size=\"1\">";
	for (@minuteListe) {
	    if ($_ eq $sel_mn) {
	       print "<option selected value=$_>$_</option>";
	    } else {
	       print "<option value=$_>$_</option>";
	    }
	}
	print "</select><BR>";
	print "<B>Site:</B> <select name=site tabindex=6 onMouseOut=\"nd()\" onmouseover=\"overlib('SÃ©lectionner le site')\" 
		onChange=\"derniere_mesure()\" size=\"1\"><option value=\"\"></option>\n";
	for (@codesListe) {
		my @cle = split(/\|/,$_);
		$sel = "";
		if ($cle[0] eq $sel_site) { $sel = "selected"; }
		print "<option $sel value=$cle[0]>$cle[1]</option>\n";
	}
	print "</select><BR>\n";
	
	# --- ajuste la taille du tableau des noms jusqu'à "Invité" inclus
	my ($invite) = grep { $users[$_][0] eq "?" } 0..$#users;
	$invite += 1;
	
	print "<b>Op&eacute;rateur(s): </b><select style=\"vertical-align:text-top\" onClick=\"calc()\" 
		onMouseOut=\"nd()\" onmouseover=\"overlib('Saisir les noms des op&eacute;rateurs; (maintenir CTRL pour une selection multiple)')\"
		name=oper tabindex=7 size=\"$invite\" multiple>";
	my $nb = 0;
	while ($nb <= $#users) {
		my $flag = 0;
		my $sel = "";
		for (@sel_oper) {
			if ($users[$nb][0] eq $_) {
				$flag = 1;
				last;
			}
		}
		if ($flag == 1) {
			$sel = "selected";
		}
		if (grep(/id/,@paramGET) || $users[$nb][2]>0) {
			print "<option $sel value=\"$users[$nb][0]\">$users[$nb][1]</option>\n";
		}
		$nb++;
	}
	print "</select> <textarea style=\"vertical-align:text-top;background-color:#E0E0E0;border:0;font-weight:bold;\" 
		readonly cols=\"20\" rows=\"$invite\" name=\"nomselect\" value=\"\"></textarea></p>";
	
	print "<H3>MÃ©tÃ©o et observations</H3>\n
	<P class=parform><table border=0><tr><td style=\"border:0\"><B>Description m&eacute;t&eacute;o:</td>";
	#print "<select name=meteo size=1 onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner un qualificatif repr&eacute;sentant la m&eacute;t&eacute;o')\">";
	for (@typeMeteo) {
		my $sel;
	        my ($cle,$nom,$ico,$ico2) = split(/\|/,$_);
		if ($cle eq $sel_meteo) { $sel = "checked"; }
		print "<td style=\"border:0\" onMouseOut=\"nd()\" onmouseover=\"overlib('$nom')\"><input type=radio name=meteo tabindex=8 $sel value=\"$cle\">",
			"<img src=\"/icons-webobs/meteo/$ico2\" style=\"background-color:black\" align=top $sel>&nbsp;</td>\n";
	}			
	print "</tr></table></P>\n";
	print "<P class=parform><B>TempÃ©rature de l'air</B> (en Â°C) = <input size=5 class=inputNum name=temp tabindex=9 value=\"$sel_temp\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de tempÃ©rature de l&apos;air')\"><BR>\n
	</select></P>\n";
	print "<P class=parform>
	<B>Observations</B>: <input size=60 name=rem tabindex=10 value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter vos observations')\"><BR>
	<B>Information de saisie:</B> $val
	<INPUT type=hidden name=val value=\"$val\"></P></TD>\n";
	
	print "<TD style=border:0 valign=top>
	<H3>Instrumentation et mesures</H3>\n";
	print "<P class=parform>
		<B>Instrument:</B> <select name=instr onMouseOut=\"nd()\" onmouseover=\"overlib('Choisir l`instrument utilis&eacute;')\">\n";
	for ("|",@typeInstr) {
		my @cle = split(/\|/,$_);
		my $sel = "";
		if ($cle[0] eq $sel_instr) { $sel = "selected"; }
	        print "<option $sel value=\"$cle[0]\">$cle[2] ".(($cle[0] ne "")?"(&plusmn; $cle[1] mm)":"")."</option>\n";
	}
	print "</select></P>\n
		<P class=parform><B>Composante:</B> <select name=comp onChange=\"derniere_mesure()\" 
		 onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner la composante mesur&eacute;e')\">\n";
	for ("|",@typeComp) {
		my @cle = split(/\|/,$_);
		my $sel = "";
		if ($cle[0] eq $sel_comp) { $sel = "selected"; }
	        print "<option $sel value=\"$cle[0]\">".(($cle[0] ne "")?"$cle[0] = $cle[1]":"")."</option>\n";
	}
	print "</select><TABLE cellspacing=0>\n";
	print "<TR><TD style=border:0></TD><TD style=\"border:0;text-align:center\"><B>Perp.</B></TD>
		<TD style=\"border:0;text-align:center\"><B>Para.</B></TD><TD style=\"border:0;text-align:center\"><B>Vert.</B></TD></TR>\n";
	for (@donneeListe) {
		print "<TR><TD style=\"border:0;text-align:right\">$_.</TD>";
		print "<TD style=border:0><input size=7 class=inputNum name=\"p$_\" tabindex=13 value=\"$sel_d[$_-1][0]\"
			onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de la mesure perpendiculaire (en mm)')\"></TD>";
		print "<TD style=border:0><input size=7 class=inputNum name=\"l$_\" tabindex=13 value=\"$sel_d[$_-1][1]\"
			onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de la mesure parall&egrave;le (en mm)')\"></TD>";
		print "<TD style=border:0><input size=7 class=inputNum name=\"v$_\" tabindex=13 value=\"$sel_d[$_-1][2]\"
			onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de la mesure verticale (en mm)')\"></TD>";
		print "</TR>\n";
	}
	
	print "<TR><TD style=\"border:0;text-align:right\"><B>Moyenne</B> (mm) = </TD>
		<TD style=border:0><input name=\"moyp\" size=7 readOnly class=inputNumNoEdit></TD>
		<TD style=border:0><input name=\"moyl\" size=7 readOnly class=inputNumNoEdit></TD>
		<TD style=border:0><input name=\"moyv\" size=7 readOnly class=inputNumNoEdit></TD>
		</TR>\n";
	print "<TR><TD style=\"border:0;text-align:right\"><B>2 &times; &Eacute;cart-type</B> (mm) =</TD>
		<TD style=border:0><input name=\"sigp\" size=7 readOnly class=inputNumNoEdit></TD>
		<TD style=border:0><input name=\"sigl\" size=7 readOnly class=inputNumNoEdit></TD>
		<TD style=border:0><input name=\"sigv\" size=7 readOnly class=inputNumNoEdit></TD>
		</TR></TABLE>\n";
	print "<P class=parform><B>Derni&egrave;re mesure du site:</B> <input name=\"prevmes\" size=50 readOnly style=\"background-color:#E0E0E0;border:0\"></P>\n";
	
	# Hidden variables
	for ($i = 0; $i <= $#stations; $i++) {
		for (@typeComp) {
			my ($cmp,$nam) = split(/\|/,$_);
			print "<input type=hidden name=\"$stations[$i]_$cmp\" value=\"$lastMeasure[$i]{$cmp}\">\n";
		}
	}
	
	print "</TD></TR>\n";
	
	print "<TR><TD style=border:0 colspan=2>";
	print "<P style=\"margin-top:20px;text-align:center\">
		<input type=\"submit\" value=\"Soumettre\">
		</P></FORM>";
	print "</TD></TR></TABLE>";
	print "<HR><P>Derni&egrave;re donn&eacute;e de la base: <b>$lastData[1] $lastData[2] $lastData[3] [$lastData[4]]</b></P>";
	
}

# --- End of the HTML page
print "<BR>\n@signature\n</BODY>\n</HTML>\n";
