#!/usr/bin/perl

=head1 NAME

formEXTENSO.pl 

=head1 SYNOPSIS

http://..../formEXTENSO?[id=]

=head1 DESCRIPTION

This script to edit a data record from extensometry network of OVSG.
 
=head1 EXTENSO configuration

See showEXTENSO.pl for an example of an 'EXTENSO.conf' file.  

=head1 Query string parameter

=over

=item B<id=>

record number (id). If omitted, assume we're creating a new record. 

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

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- standard FORMS inits ----------------------------------

die "You can't edit EXTENSO reports." if (!clientHasEdit(type=>"authforms",name=>"EXTENSO"));

my $FORM = new WebObs::Form('EXTENSO');
my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
    my %N = $FORM->nodes($p);
    for my $n (sort keys(%N)) {
        push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
    }
    %Ns = (%Ns, %N);
}

my $QryParm   = $cgi->Vars;

# --- DateTime inits defaults ---------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $sel_jour  = strftime('%d',@tod);
my $sel_mois  = strftime('%m',@tod);
my $sel_annee = strftime('%Y',@tod);
my $anneeActuelle = strftime('%Y',@tod);
my $sel_hr    = strftime('%H',@tod);
my $sel_mn    = strftime('%M',@tod);
my $today     = strftime('%F',@tod);

# ---- specific FORM inits -----------------------------------
my @html;
my $titre2 = (defined($QryParm->{id})) ? "Modification donn&eacute;es id=n&deg; $QryParm->{id}" : "Saisie de nouvelles donn&eacute;es";
my $s;
my %nomMeteo;
my $nbData = 9;
my @donneeListe = ('1'.."$nbData");

my @meteo    = readCfgFile($FORM->path."/".$FORM->conf('FILE_METEO'));
my @vent     = readCfgFile($FORM->path."/".$FORM->conf('FILE_WIND'));

my @vitres   = ("0|Ouverte","1|Ferm�e");

$ENV{LANG} = $WEBOBS{LOCALE};

# ---- Variables des menus 
my @anneeListe = ($FORM->conf('BANG')..$anneeActuelle);
my @moisListe  = ('01'..'12');
my @jourListe  = ('01'..'31');
my @heureListe = ('','00'..'23');
my @minuteListe= ('','00'..'59');

# ---- Read the data file to retrieve most recent measurements
#
my ($lignes, $dataTS) = $FORM->data;
@$lignes = reverse sort tri_date_avec_id @$lignes;

# most recent measurements from last data line in file  
my (@lastData) = split(/\|/, @$lignes[$#$lignes -1 ]); # -1 because of header after reverse

# last measurements for each site (stations)
my @lastMeasure;
my $i = 0;
for my $st (keys(%Ns)) {

    #djl-was: my @tmp = grep(/\|$stations[$i]\|/,@$lignes);
    my @tmp = grep(/\|$st\|/,@$lignes);
    my @ddd = split(/\|/,$tmp[$#tmp]);
    my $moy = 0;
    my $n = 0;
    for (@donneeListe) {
        if ($ddd[($_-1)*3+8] ne "") {
            $moy += $ddd[($_-1)*3+9] + $ddd[($_-1)*3+10];
            $n++;
        }
    }
    if ($n != 0) { $moy /= $n; }
    $lastMeasure[$i] = sprintf("%1.2f mm (%s)",$ddd[7]+$ddd[8]+$moy,$ddd[1]);
    $i++;
}

# ---- init some other defaults ---------------------------
my $sel_meteo  = "variable";
my $sel_offset = $lastData[8];
my @sel_oper   = $USERS{$CLIENT}{UID};
my $sel_site   = my $sel_temp = my $sel_ruban  = "";
my @sel_d = my @sel_v ="" ;
my $sel_rem    = my $sel = "";
my ($id,$date,$heure,$site,$ope,$temp,$meteo,$ruban,$offset,$rem,$val);
$id=$date=$heure=$site=$ope=$temp=$meteo=$ruban=$offset=$rem=$val = "";
my @d;

# ---- date and staff (oper) in querystring may override defaults (resp. today & client)
if ( defined($QryParm->{date}) && length($QryParm->{date}) == 10 ) {
    $sel_annee = substr($QryParm->{date},0,4);
    $sel_mois  = substr($QryParm->{date},5,2);
    $sel_jour  = substr($QryParm->{date},8,2);
}
if (defined($QryParm->{oper})) {
    @sel_oper = split(/\ /,$QryParm->{oper});	# note: GET replaces '+' with a space
}

# ---- if an id is passed in querystring, override defaults with data file for this id 
if (defined($QryParm->{id})) {
    my @ligneId = grep(/^$QryParm->{id}\|/,@$lignes);
    if (@ligneId ne "") {
        ($id,$date,$heure,$site,$ope,$temp,$meteo,$ruban,$offset,$d[0][0],$d[0][1],$d[0][2],$d[1][0],$d[1][1],$d[1][2],$d[2][0],$d[2][1],$d[2][2],$d[3][0],$d[3][1],$d[3][2],$d[4][0],$d[4][1],$d[4][2],$d[5][0],$d[5][1],$d[5][2],$d[6][0],$d[6][1],$d[6][2],$d[7][0],$d[7][1],$d[7][2],$d[8][0],$d[8][1],$d[8][2],$rem,$val) = split (/\|/,$ligneId[0]);
        $sel_annee = substr($date,0,4);
        $sel_mois  = substr($date,5,2);
        $sel_jour  = substr($date,8,2);
        $sel_hr    = substr($heure,0,2);
        $sel_mn    = substr($heure,3,2);
        $sel_site  = $site;
        $sel_meteo = lc($meteo);
        $sel_temp  = $temp;
        $sel_ruban = $ruban;
        $sel_offset= $offset;
        @sel_oper  = split(/\+/,$ope);

# each of the 9 measurements in file is a 3-tuple (fenetre,cadran,vent).
# for input (& matching new equipments) we show/accept the 2-tuple (fenetre,cadran)
# as a single input field (representing fenetre+cadran). 
# following loop builds input fields from these 3-tuples,
# ATT: null 2-tuple ARE null input (not zero)
        for ($i = 0; $i<9; $i++) {
            if (!($d[$i][0] eq "" && $d[$i][1] eq "")) {
                $sel_d[$i] = $d[$i][0] + $d[$i][1];
                $sel_d[$i] =~ tr/,/./;
            } else { $sel_d[$i] = "" }
            $sel_v[$i] = $d[$i][2];
        }
        $sel_rem = l2u($rem);
        chomp($val);
    }
}

# ---- Begin HTML display
my $jvs = "onLoad=\"calc();derniere_mesure()\"";

print "Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<HTML><HEAD>\n
<title>".$FORM->conf('TITLE')."</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/comma2point.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<DIV ID=\"helpBox\"></DIV>

<!-- avoid validating the form when pressing ENTER -->
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

print "<H1>".$FORM->conf('TITLE')."</H1>\n<H2>$titre2</H2>";

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
		alert('Veuillez choisir au moins 1 op&eacute;rateur dans la liste!');
		document.formulaire.oper.focus();
		return false;
	}
	if(document.formulaire.site.value == '') {
		alert('Veuillez sp&eacute;cifier le site de mesure!');
		document.formulaire.site.focus();
		return false;
	}
	if(document.formulaire.ruban.value == '') {
		alert('Veuillez indiquer une valeur de ruban!');
		document.formulaire.ruban.focus();
		return false;
	}
	if (document.formulaire.ruban.value/25 % 1 != 0) {
		alert('La valeur du ruban doit etre multiple de 25 mm!');
		document.formulaire.ruban.focus();
		return false;
	}
	if(document.formulaire.moy.value == 0) {
		alert('Veuillez indiquer au moins une mesure!');
		document.formulaire.f1.focus();
		return false;
	}
	
	for (i=1;i<=9;i++) {
		//djl missing c:if (eval('document.formulaire.c' + i.toFixed(0) + '.value') >= 1) {
		//djl missing c:	alert('La valeur du cadran #' + i.toFixed(0) + ' doit etre inferieure a 1 !');
		//djl missing c:	eval('document.formulaire.c' + i.toFixed(0) + '.focus()');
		//djl missing c:	return false;
		//djl missing c:}
		if (eval('document.formulaire.f' + i.toFixed(0) + '.value') != '' && eval('document.formulaire.v' + i.toFixed(0) + '.value') == '') {
			alert('Veuillez indiquer la force du vent pour la mesure #' + i.toFixed(0) + ' !');
			eval('document.formulaire.v' + i.toFixed(0) + '.focus()');
			return false;
		}
	}
    \$.post(\"/cgi-bin/".$FORM->conf('CGI_POST')."\", \$(\"#theform\").serialize(), function(data) {
	   //var contents = \$( data ).find( '#contents' ).text(); 
	   alert(data);
	   document.location=\"/cgi-bin/".$FORM->conf('CGI_SHOW')."\";
	   }
	);
}

function calc()
{
	var moy = 0;
	var sig = 0;
	var n = 0;
	var v = 0;
	var i;
	var ns = '';
	var rouge = '#FF0000';
	var orange = '#FFD800';
	var vert = '#66FF66';
	var blanc = '#FFFFFF';

	for (i=0;i<formulaire.oper.length;i++) {
		if (formulaire.oper.options[i].selected) {
			if (ns != '') ns = ns + '+';
			ns = ns + formulaire.oper.options[i].value;
		}
	}
	formulaire.nomselect.value = ns;
	
	if (formulaire.ruban.value/25 % 1 != 0) {
		formulaire.ruban.style.background = rouge;
	} else {
		formulaire.ruban.style.background = blanc;
	}
	
	for (i=1;i<=$nbData;i++) {
		if (formulaire['f' + i].value != '') {
			v = formulaire.offset.value*1 + formulaire.ruban.value*1 + formulaire['f' + i].value*1;
			moy += v; sig += v*v; n++;
		}
	}

	if (n != 0) {
		moy = moy/n;
		sig = 2*Math.sqrt(sig/n - moy*moy);
	}
	formulaire.moy.value = moy.toFixed(2);
	formulaire.sig.value = sig.toFixed(2);
	formulaire.sig.style.background = vert;
	if (sig > 1) {
		formulaire.sig.style.background = orange;
	}
	if (sig > 2) {
		formulaire.sig.style.background = rouge;
	}
}

function propagate_wind()
{
	var vv = '';
	for (i=1;i<=$nbData;i++) {
		if (vv == '' && formulaire['v' + i].value != '') { vv = formulaire['v' + i].value; }
	}
	if (vv != '') {
		for (i=1;i<=$nbData;i++) {
			if (formulaire['v' + i].value == '') { formulaire['v' + i].value = vv; }
		}
	}
	
}

function derniere_mesure()
{
	formulaire.prevmes.value = eval('formulaire.' + formulaire.site.value + '.value');
}
window.captureEvents(Event.KEYDOWN);
window.onkeydown = calc();
//-->
</script>";

print "<FORM name=formulaire id=\"theform\" action=\"\">";

# Retrieve data ID if exists
if (defined($QryParm->{id})) {
    print "<input type=\"hidden\" name=\"id\" value=\"$QryParm->{id}\">";
}

print "<input type=\"hidden\" name=\"user\" value=\"$CLIENT\">\n";

print "<TABLE style=border:0 onMouseOver=\"calc()\"><TR>";
print "<TD style=border:0 valign=top nowrap>
	<fieldset><legend>Date, site et op&eacute;rateurs</legend>
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
print "<B>Site:</B> <select name=site tabindex=6 onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner le site')\"
		onChange=\"derniere_mesure()\" size=\"1\"><option value=\"\"></option>\n";
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    $sel = "";
    if ($cle[0] eq $sel_site) { $sel = "selected"; }
    print "<option $sel value=$cle[0]>$cle[1]</option>\n";
}
print "</select><BR>\n";

print "<p><b>Op&eacute;rateur(s): </b>";
print "<select name=\"oper\" size=\"10\" multiple style=\"vertical-align:text-top\" onClick=\"calc()\"
	      onMouseOut=\"nd()\" onmouseover=\"overlib('Select names of people involved; (hold CTRL key for multiple selection)')\">\n";
my %ku;
for (keys(%USERS)) { $ku{$USERS{$_}{FULLNAME}} = $_; }
for (sort(keys(%ku))) {
    print "<option".($USERS{$ku{$_}}{UID} ~~ @sel_oper ? " selected":"")
      ." value=$USERS{$ku{$_}}{UID}>$USERS{$ku{$_}}{FULLNAME}</option>\n";
}

#FB-was: for my $ulogin (sort keys(%USERS)) {
#FB-was:	my $sel = "";
#FB-was:	if ($USERS{$ulogin}{UID} ~~ @sel_oper) { $sel = ' selected '}
#FB-was:	print "<option $sel value=\"$USERS{$ulogin}{UID}\">$USERS{$ulogin}{FULLNAME}</option>\n";
#FB-was:}
print "</select>";

#djl-del: print "<textarea style=\"vertical-align:text-top; background-color:#E0E0E0;border:0;font-weight:bold;\" 
#djl-del: 	readonly cols=\"20\" rows=\"10\" name=\"nomselect\" value=\"\"></textarea></p>";
# currently read or selected people 
print "<P><INPUT style=\"border:none\" type=\"text\" readonly name=\"nomselect\" size=\"40\" value=\"\"
	      onMouseOut=\"nd()\" onmouseover=\"overlib('currently selected people')\">\n";
print "</fieldset>\n";

print "<fieldset><legend>M&eacute;t&eacute;o et Observations</legend>\n
		<P class=parform><table border=0><tr><td style=\"border:0\"><B>Description m&eacute;t&eacute;o:</td>";

#print "<select name=meteo size=1 onMouseOut=\"nd()\" onmouseover=\"overlib('S&eacute;lectionner un qualificatif repr&eacute;sentant la m&eacute;t&eacute;o')\">";
for (@meteo) {
    my $sel;
    my ($cle,$nom,$ico,$ico2) = split(/\|/,$_);
    if ($cle eq $sel_meteo) { $sel = "checked"; }
    print "<td style=\"border:0\" onMouseOut=\"nd()\" onmouseover=\"overlib('$nom')\"><input type=radio name=meteo tabindex=8 $sel value=\"$cle\">",
      "<img src=\"/icons/meteo/$ico2\" style=\"background-color:black\" align=top $sel>&nbsp;</td>\n";
}
print "</tr></table></P>\n";

print "<P class=parform><B>Temp&eacute;rature de l'air</B> (en &deg;C) = <input size=5 class=inputNum name=temp tabindex=9 value=\"$sel_temp\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur de temp&eacute;rature de l&apos;air')\"><BR>\n
		</select></P>\n";
print "<P class=parform>
	<B>Observations</B>: <input size=60 name=rem tabindex=10 value=\"$sel_rem\" onMouseOut=\"nd()\" onmouseover=\"overlib('Noter vos observations')\"><BR>
	<B>Information de saisie:</B> $val
	<INPUT type=hidden name=val value=\"$val\"></P>";
print "</fieldset></TD>\n";

print "<TD style=border:0 valign=top>
	<fieldset><legend>Mesures de distance (mm)</legend>\n";
print "<P class=parform>
		<B>Offset extensom&egrave;tre</B> (en mm) <input size=7 class=inputNum name=offset tabindex=11 value=\"$sel_offset\"
			onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Modifier &eacute;ventuellement l&rsquo;offset')\"><BR>\n
		<B>Ruban:</B> (en mm) <input size=5 class=inputNum name=\"ruban\" tabindex=12 value=\"$sel_ruban\"
			onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Entrer la valeur du ruban (multiple de 25 mm!)')\"><BR>\n
		<B>Mesures:</B> (mm)<BR>";
for my $ix (@donneeListe) {

#djl-was: print "$_. <input size=5 class=inputNum name=\"f$_\" tabindex=13 value=\"$sel_d[$_-1]\" 
#djl-was: print "$_."; 
    print "$ix.";
    if ($#sel_d > 0) { print " <input size=5 class=inputNum name=\"f$ix\" tabindex=13 value=\"$sel_d[$ix-1]\"" }
    else             { print " <input size=5 class=inputNum name=\"f$ix\" tabindex=13 value=\"\"" }
    print "onKeyUp=\"calc()\" onMouseOut=\"nd()\" onmouseover=\"overlib('Pour l\\'extenso TELEMAC entrer la somme de la fen&ecirc;tre (partie enti&egrave;re) et du cadran (fraction) en mm')\">";
    print " <select onMouseOut=\"nd()\" onmouseover=\"overlib('Sélectionner la force du vent')\" name=\"v$ix\" tabindex=13 size=\"1\" onChange=\"propagate_wind()\">\n";

#djl-was: for ("|",@vent) {  #removing | needs init'ing @vent to a default value 
    for (("|",@vent)) { #djl: assumes @vent is not empty -- see | above
        my @cle = split(/\|/,$_);
        my $sel = "";

        #djl-was: if ($cle[0] eq $sel_v[$_-1]) { $sel = "selected"; }
        if ($#sel_v > 0 && $cle[0] eq $sel_v[$ix-1]) { $sel = "selected"; }
        print "<option $sel value=\"$cle[0]\">$cle[1]</option>\n";
    }
    print "</select><BR>\n";
}
print "</P>\n";

print "<P class=parform><B>Moyenne</B> (mm) = <input name=\"moy\" size=7 readOnly class=inputNumNoEdit>
	<B>2 &times; &Eacute;cart-type</B> (mm) = <input name=\"sig\" size=4 readOnly class=inputNumNoEdit></P>\n";
print "<P class=parform><B>Derni&egrave;re mesure du site</B> = <input name=\"prevmes\" size=25 readOnly style=\"background-color:#E0E0E0;border:0\"></P>\n";

# Hidden variables
$i = 0;
for (keys(%Ns)) {
    print "<input type=hidden name=\"$_\" value=\"$lastMeasure[$i]\">\n";
    $i++;
}
print "</fieldset>";
print "</TD></TR>\n";

print "<TR><TD style=border:0 colspan=2>";
print "<P style=\"margin-top:20px;text-align:center\">";
print "<input type=\"button\" name=lien value=\"Annuler\" onClick=\"document.location='/cgi-bin/".$FORM->conf('CGI_SHOW')."'\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"Soumettre\" onClick=\"verif_formulaire();\">";
print "</TD></TR></TABLE>";
print "</FORM>";

print "<HR><P>Derni&egrave;re donn&eacute;e de la base: <b>$lastData[1] $lastData[2] $lastData[3] [$lastData[4]]</b></P>";

# --- End of the HTML page
print "<BR>\n</BODY>\n</HTML>\n";

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

