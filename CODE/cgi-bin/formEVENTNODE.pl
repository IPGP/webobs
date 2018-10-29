#!/usr/bin/perl -w

=head1 NAME

formEVENTNODE.pl 

=head1 SYNOPSIS

http://..../formEVENTNODE.pl?[file=][,subevent=][,node=NODEID]

=head1 DESCRIPTION

Create and/or edit an Event File for a node. 

=head1 Query string parameters

 file=

 subevent=

 node=  
 the fully qualified NODE name gridtype.gridname.nodename 

=head1 EVENT FILE FORMAT

First line identifies userids involved in intervention (event):  

  userId1[+userId2[+userIdn....]][|short event description]

  eg.:  AB+BC+CD|Installation

The rest of the file is free format, but will be submitted to the webobs wiki parser/interpreter
when sent as html for display. 

=cut

use strict;
use File::Basename;
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
my $cgi = new CGI;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# 'guest' client is not authorized ... all others are !
#  could (should?) be changed to checking a specific webobs resource !
if (substr($USERS{$CLIENT}{UID},0,1) eq "?" || !WebObs::Users::clientHasEdit(type=>'authmisc',name=>"NODES")) {
	die "$__{'Not authorized'} (for editing)" 
}

my $Qfile    = $cgi->param('file') || "";
my $Qnode    = $cgi->param('node') || "";
my $Qsubevnt = $cgi->param('subevent') || "";

# ---- some times  ;-)
my $Ctod = time();  my @tod = localtime($Ctod);
my $sel_Year  = strftime('%Y',@tod);
my $sel_Month = strftime('%m',@tod);
my $sel_Day   = strftime('%d',@tod);
my $sel_Hour  = strftime('%H',@tod);
my $sel_Min   = strftime('%M',@tod);
my $anneeActuelle = strftime('%Y',@tod);
my @anneeListe    = ($WEBOBS{BIG_BANG}..$anneeActuelle+1);
my $date          = "";
my $time          = "";

my @moisListe = ('01'..'12');
my @jourListe = ('01'..'31');
my @heureListe = ("NA",'00'..'23');
my @minsec = ('NA','00'..'59');

my $fileInterventions = "";
my $fileVersion = "";
my $nouveau = 1;

# ---- define where lines from the event file will be read in 
# ---- tricky init to first and only line, with CLIENT's id, in case we're creating a new event
# ---- otherwise this line will be overidden by actual event file contents ....
my @lignes = $USERS{$CLIENT}{UID};

my $titrePage = "$__{'Editing'} $__{'new event'}";
# ---- if file= is requested, derive both node and subevent from it
# ---- (overidding node= and subevent= from query-string if they're present)
if ($Qfile ne "") {
	$nouveau = 0;
	$titrePage = "$__{'Editing'} $__{'Event'}";
	my @parent = split(/\//,$Qfile);
	if ($#parent > 0) {
		$Qsubevnt = join("/",@parent[0..($#parent-1)]);
	}
	my ($nomFichier,$extensionFile) = split(/\./,basename($Qfile));
	if ($nomFichier =~ /Projet/) {
		my $trash = "";
		($Qnode,$trash) = split(/_/,$nomFichier);
	} else {
		($Qnode,$date,$time,$fileVersion) = split(/_/,$nomFichier);
		($sel_Year,$sel_Month,$sel_Day) = split(/-/,$date);
		($sel_Hour,$sel_Min) = split(/-/,$time);
	}
	$fileInterventions = "$NODES{PATH_NODES}/$Qnode/$NODES{SPATH_INTERVENTIONS}/$Qfile";
	if ($nomFichier =~ /Projet/ && !(-e $fileInterventions)) {
		qx(touch $fileInterventions);
	}
	if (-e $fileInterventions)  {
		@lignes = readFile($fileInterventions);
		@lignes = grep(!/^$/, @lignes);
	} else {
		die "$Qfile $__{'not found'}\n";
	}
}

# ---- Get all known nodes 
my @nodes = qx(/bin/ls $NODES{PATH_NODES});
chomp(@nodes);

# ---- start building html page/form 
# 
print "Content-type: text/html\n\n
<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n
<HTML><HEAD>\n
<title>$titrePage</title>\n
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">\n
<!-- markitup -->
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\" src=\"/js/markitup/jquery.markitup.js\"></script>
<script type=\"text/javascript\" src=\"/js/markitup/sets/wiki/set.js\"></script>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/skins/markitup/style.css\" />
<link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/sets/wiki/style.css\" />
<script type=\"text/javascript\" >
	\$(document).ready(function() {
		\$(\"#markItUp\").markItUp(mySettings);
	});
</script>
<!-- overLIB (c) Erik Bosrup -->
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<DIV ID=\"helpBox\"></DIV>

</HEAD>
<BODY style=\"background-color:#E0E0E0\" onLoad=\"calc();document.formulaire.titre.focus()\">

<script type=\"text/javascript\">
<!--

function verif_formulaire()
{
	if (document.formulaire.node.value == '') {
		alert('$__{'select'} $__{'a node from list'}');
		document.formulaire.node.focus();
		return false;
	}
	if (document.formulaire.oper.value == '') {
		alert('$__{'select'} $__{'at least one name'}');
		document.formulaire.oper.focus();
		return false;
	}
    \$.post(\"/cgi-bin/postEVENTNODE.pl\", \$(\"#theform\").serialize(), function(data) {
	   alert(data);
       location.href = document.referrer;	   
	   //history.go(-1);;
	   }
	);
}

function calc()
{
	var i;
	var ns ='';

	for (i=0;i<formulaire.oper.length;i++) {
		if (formulaire.oper.options[i].selected) {
			if (ns != '') ns = ns + '+';
			ns = ns + formulaire.oper.options[i].value;
		}
	}
	document.formulaire.nomselect.value = ns;

	if (formulaire.cp.checked) formulaire.mv.checked = false;
}

//-->
</script>";

print "<TABLE width=\"100%\"><TR><TD style=\"border:0\">";
print "<H1>$titrePage</H1>\n";
if ($Qnode eq "") {
	print "<h2>Select a node ...</h2>"; #djl-TBD: questionnable as the only H2 !!!
} else {
	print "<h2>".getNodeString(node=>$Qnode)."</h2>";
}
print "</TD></TR></TABLE>";

print "<FORM name=\"formulaire\" id=\"theform\" action=\"\">";
print "<TABLE  style=border:0>";
print "<tr>";
print "<td style=border:0;vertical-align:top>";
# Displays the nodes list (when no Qnode specified)
if ($Qnode eq "") {
	print "<P><B>$__{'Node'}:</B> <select onMouseOut=\"nd()\" onmouseover=\"overlib('Select a node')\" name=\"node\" size=\"1\">";
	for ("",@nodes) {
		print "<option title=\"$_\" value=\"$_\">".getNodeString(node=>$_,style=>'short')."</option>"; 
	}
	print "</select></p>";
} else {
	print "<P><B>ID:</B>$Qnode</P>
	<input type=\"hidden\" name=\"node\" value=\"$Qnode\">";
}

# Displays the parent event for sub-event
if ($Qsubevnt ne "") {
	print "<P><B>$__{'Parent'}:</B>";
	if ($Qfile ne "") {
		print parentEvents($Qfile);
	} else {
		print parentEvents($Qsubevnt."/".$Qnode);
	}
	print "</P>\n";
}

print "<input type=\"hidden\" name=\"file\" value=\"$Qfile\">
	<input type=\"hidden\" name=\"subevent\" value=\"$Qsubevnt\">
	<input type=\"hidden\" name=\"version\" value=\"$fileVersion\">";

# Selection of date and time of event
if ($Qnode eq "" || !($Qfile =~ /Projet/)) {
	print "<p><b>$__{'Date'}: </b><select name=\"anneeDepart\" size=\"1\">";
	for (@anneeListe) {
		if ($_ == $sel_Year) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=\"moisDepart\" size=\"1\">";
	for (@moisListe) {
		if ($_ == $sel_Month) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <select name=\"jourDepart\" size=\"1\">";
	for (@jourListe) { 
		if ($_ == $sel_Day) { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select>";
	print " <b>$__{'Time'}: </b><select name=\"heureDepart\" size=\"1\">";
	for (@heureListe) { 
		if ($_ eq "$sel_Hour") { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}      
	print "</select>";
	print " <select name=\"minuteDepart\" size=\"1\">";
	for (@minsec) {
		if ($_ eq "$sel_Min") { print "<option selected value=$_>$_</option>"; } else { print "<option value=$_>$_</option>"; }
	}
	print "</select> $fileVersion";
} else {
	print "<input type=\"hidden\" name=\"anneeDepart\">\n
		<input type=\"hidden\" name=\"moisDepart\">\n
		<input type=\"hidden\" name=\"jourDepart\">\n
		<input type=\"hidden\" name=\"heureDepart\">\n
		<input type=\"hidden\" name=\"minuteDepart\">\n";
}

if ($Qnode eq "") {
	print "&nbsp;&nbsp;<input type=\"checkbox\" ";
	if ($Qfile =~ /Projet/) {
		print "checked ";
	}
	print "name=\"projet\" value=\"\" onClick=\"calc()\" onMouseOut=\"nd()\" 
		onmouseover=\"overlib('$__{'Select to define a project (ATT: only one project per node)'}')\"> <b>$__{'Project'}</b> ($__{'without date'})";
} elsif ($Qfile =~ /Projet/) {
	print "<b>$__{'Project'}</b> ($__{'without date'}) <input type=\"hidden\" name=\"projet\" value=\"OK\">";
}
print "</p>";
# Process 1st line of event: people involved to @peopleIDs and short description to $titre 
my @peopleIDs;
my $titre = "";
chomp(@lignes);
if(index($lignes[0],"|") >= 0) {
	my @pLigne = split(/\|/,$lignes[0]);
	@peopleIDs = split(/\+/,$pLigne[0]);
	if ($#pLigne > 0) {
		$titre = $pLigne[1];
		$titre =~ s/\"/\'\'/g;
	}
} else {
	@peopleIDs = split(/\+/,$lignes[0]);
}

# remove 1st line to make rest of lines a long string to edit
shift(@lignes);
my $texte = join("\n",@lignes);

# intervention (event) title
print "<P><B>$__{'Title'}:</B> <INPUT type=\"text\" name=\"titre\" value=\"$titre\" size=\"80\" 
      onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Event title (ATT: do not use | (pipe))'}')\"></p>\n";
	print "<p><b>$__{'Content'}:</b><br><TEXTAREA id=\"markItUp\" class=\"markItUp\" rows=\"20\" cols=\"100\" name=\"commentaires\" dataformatas=\"plaintext\">$texte</TEXTAREA></P></TD>\n";
print "</td>";

# people select area
print "<td style=\"border:0;vertical-align:top\" nowrap>";
print "<p><b>$__{'Author(s)'}: </b>";
print "<select name=\"oper\" size=\"15\" multiple style=\"vertical-align:text-top\" onClick=\"calc()\" 
      onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Select names of people involved (hold CTRL key for multiple selections)'}')\">\n";
for my $ulogin (sort keys(%USERS)) {
	my $sel = "";
	if ($USERS{$ulogin}{UID} ~~ @peopleIDs) { $sel = ' selected '}
	print "<option $sel value=\"$USERS{$ulogin}{UID}\">$USERS{$ulogin}{FULLNAME}</option>\n";
}
print "</select>";
print "</p>\n";
# currently read or selected people 
print "<P><INPUT style=\"border:none\" type=\"text\" readonly name=\"nomselect\" size=\"40\" value=\"".join('+',@peopleIDs)."\"
      onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'currently selected people'}')\">\n";
print "</TD>";
print "</TR>\n";

# actions! 
print "<tr><td style=\"border:0;vertical-align:bottom\">\n";

	print "<TABLE style=\"width: 100%; text-align: center;\">";
	# email notification 
	print "<tr><td style=\"border: none\">\n";
	print "&nbsp;&nbsp;<input type=\"checkbox\" name=\"notify\" value=\"OK\""
	 	 ."onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Send an e-mail to inform Webobs users'}')\"> <b>$__{Notify}</b> (email)";
	print "</td>\n";
	# Copy/move to another node 
	print "<td style=\"border: none\">\n";
	if ($Qnode ne "" && !($Qfile =~ /Projet/)) {
		@nodes = grep(!/^$Qnode/,@nodes);
		print "<P  style=\"margin: 20px\">";
		print "<input name=\"cp\" type=\"checkbox\" value=\"OK\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Duplicate this event into another node'}')\" onClick=\"calc()\"> <B>$__{'Copy'}</B> ";
		if ($nouveau == 0) {
			print "$__{'or'} <input name=\"mv\" type=\"checkbox\" value=\"OK\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{'Move this event to another node'}')\" onClick=\"calc()\"> <B>$__{'Move'}</B> ";
		}
		print "<br>$__{'to node'}  
			<select onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Select the target node'}')\" name=\"mvcpStation\" size=\"1\">";
		for ("",@nodes) {
			##perf## print "<option title=\"$_\" value=\"$_\">".getNodeString(node=>$_)."</option>"; 
			print "<option title=\"$_\" value=\"$_\">$_</option>"; 
		}
		print "</select></p>";
	}
	print "</td></tr>\n";
	# submits
	print "<tr><td colspan=\"2\">\n";
		print "<p style=\"margin: 20px\">";
		print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
		print "<input type=\"button\" value=\"$__{'Submit'}\" onClick=\"verif_formulaire();\">";
	print "</td></tr>";
	print "</TABLE>";

print "</td>";
print "</TR></TABLE>\n";

print "</p></FORM>";
print "</td></tr></table>";

# ---- we did it !
#
print "<BR>\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

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

