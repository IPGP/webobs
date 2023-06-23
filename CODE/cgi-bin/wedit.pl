#!/usr/bin/perl 

=head1 NAME

wedit.pl 

=head1 SYNOPSIS

http://..../wedit.pl?file=filespec

=head1 DESCRIPTION

Edit the wiki or html file named <filespec> using the jquery plugin 'markitup', if client has Edit access to it.
The file is created if it does not exist AND client has Adm access.

New as of January, 18th 2016, also handles MultiMarkdown markup.
WebObs determines wether a file is a MultiMarkdown-coded file when this file starts with a Markdown-Metadata section:
ie. consecutive lines, starting at top of file, ended with a blank line, each line made up of
key:value pair. See MultiMarkdown Metadata documentation.

MultiMarkdown will now be the default formatting markup. Thus wedit.pl will 
add a pseudo Metadata section to each newly created wiki file, consisting of one
WebObs: MMD metadata.  

The authorization resource-name, in authwikis resource-type, that is checked for Edit/Adm access to the file,
is built from filespec following the 'path-like' resource-names rules as described in WebObs::Users.

	Example: 
	file = HTML/public/intro.wiki
	==> actual file = $WEBOBS{PATH_DATA_WEB}/HTML/public/intro.wiki
	==> resources   = authwikis.HTML/public/intro.wiki  OR
	                = authwikis.HTML/public  OR
					= authwikis.HTML/

=head1 Query string parameters

=over 

=item B<file=filespec>

	filespec := [relpath/]name
	filespec (with optional relpath) is relative to $WEBOBS{PATH_DATA_WEB}

=item B<action=>

	{ edit | save }
	'edit' (default when action is not specified) to enter html-form edit 
	'save' internaly used to save the file after html-form edition
	(other parameters are used along with 'save': ts0, txt, titre, html)

=back

=head1 Markitup customization

The JQuery plugin 'markitup' is customized for WebObs: 

A wiki editor, markitup namespace 'wiki' with 
CODE/js/markitup/sets/wiki/set.js and CODE/js/markitup/sets/wiki/style.css 

A MultMarkdown editor, markiptup namespace 'markdown' with
CODE/js/markitup/sets/markdown/set.js and CODE/js/markitup/sets/markdown/style.css

=cut

use strict;
use warnings;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff ----------------------------------
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# ---- init
#
my @lignes;
my $titrePage;
my $legacyhtml = 0;

my $me = $ENV{SCRIPT_NAME};
my $QryParm   = $cgi->Vars;
my $file   = $QryParm->{'file'}   // "";
my $action = $QryParm->{'action'} // "edit";
my $txt    = $QryParm->{'txt'}    // "";
my $TS0    = $QryParm->{'ts0'}    // "";
my $titre  = $cgi->param('titre') // "";
my $metain = $cgi->param('meta')  // "";
my $html   = $cgi->param('html')  // "";
my $conv   = $cgi->param('conv')  // "0";
my $absfile ="";
my $editOK = my $admOK = 0;
my $mmd = $WEBOBS{WIKI_MMD} // 'YES';
my $MDMeta = ($mmd ne 'NO') ? "WebObs: created by wedit  " : "";

# ---- see what file has to be edited, and corresponding authorization for client
# ---- new file (create) initialization 
#
if ($file ne "") {
	$absfile = "$WEBOBS{PATH_DATA_WEB}/$file";
	#?# $absfile =~ s/^\.\.?\///;
	$editOK = clientHasEdit(type=>"authwikis",name=>$file);
	$admOK  = clientHasAdm(type=>"authwikis",name=>$file);
	unless (-e dirname($absfile) || !$admOK) { mkdir dirname($absfile) }
	if ( (!-e $absfile) && $admOK ) { qx(echo "$MDMeta\n\n" > $absfile) } 
	if ( (!$editOK) && (!-e $absfile) ) { die "$file $__{'not found'} or $__{'not authorized'}" }
} else { die "$__{'No filename specified'}" }

# ---- action is 'save'
#
if ($action eq 'save') {
	if ($TS0 != (stat("$absfile"))[9]) { 
		htmlMsgNotOK("$file has been modified while you were editing !"); 
		exit; 
	}
	if ( sysopen(FILE, "$absfile", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "$me waiting for lock on $file...";
			flock(FILE, LOCK_EX);
		}
		qx(cp -a $absfile $absfile~ 2>&1); 
		if ( $?  == 0 ) { 
			truncate(FILE, 0);
			seek(FILE, 0, SEEK_SET);
			if ($conv eq "1") {
				$txt = WebObs::Wiki::wiki2MMD($txt);
				$txt = "WebObs: converted with wiki2MMD\n\n$txt";
			}
			if ($html == 1) {
				@lignes = ("TITRE_HTML|$titre\n");
			} elsif ($titre ne "") {
				@lignes = ("TITRE|$titre\n");
			}
			$txt = "$metain$txt";
			$txt =~ s{\r\n}{\n}g;   # 'cause js-serialize() forces 0d0a
			push(@lignes,$txt);
			print FILE @lignes ;
			close(FILE);
			htmlMsgOK($file);
		} else {
			close(FILE);
			htmlMsgNotOK("$me couldn't backup $file");
		}
	} else { htmlMsgNotOK("$me opening $file - $!") }
	exit;
}

# ---- action is 'edit' (default)
#
# read file (with lock) into @lignes 
@lignes = readFile($absfile);
$TS0 = (stat($absfile))[9] ;
chomp(@lignes);
# strip off and remember the first line's optional tags TITLE*
(my $x, my $y) = split(/\|/, $lignes[0]);
if ( $x eq "TITRE_HTML" ) {
	$titre = $y;
	shift(@lignes);
	$legacyhtml = 1;
}
if ( $x eq "TITRE" ) {
	$titre = $y;
	shift(@lignes);
}
# file contents as a string and determine markup type (WO or MMD)
$txt = join("\n",@lignes);
($txt, my $meta) = WebObs::Wiki::stripMDmetadata($txt);

# start building page
# 
print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<TITLE>Text edit form</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\">
function verif_formulaire()
{
    \$.post(\"$me\", \$(\"#theform\").serialize(), function(data) {
		   if (data != '') alert(data);
       	   location.href = document.referrer;	   
   	});
}
function convert2MMD()
{
	if (confirm(\"Presentation might be affected by conversion,\\nrequiring manual editing.\")) {
		\$(\"#theform\")[0].conv.value = \"1\";
		verif_formulaire();
	}
}
</script>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" onLoad=\"document.formulaire.texte.focus()\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- markitup -->
<script type=\"text/javascript\" src=\"/js/markitup/jquery.markitup.js\"></script>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/skins/markitup/style.css\" />
"; 
if (length($meta) > 0) {
	print "<script type=\"text/javascript\" src=\"/js/markitup/sets/markdown/set.js\"></script>
		   <link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/sets/markdown/style.css\" />";
} else {
	print "<script type=\"text/javascript\" src=\"/js/markitup/sets/wiki/set.js\"></script>
		   <link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/sets/wiki/style.css\" />";
}
print "<script type=\"text/javascript\" >
	\$(document).ready(function() {
		\$(\"#markItUp\").markItUp(mySettings);
	});
</script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>
";
print "<form id=\"theform\" name=\"formulaire\" action=\"\">
<input type=\"hidden\" name=\"file\" value=\"$file\">
<input type=\"hidden\" name=\"action\" value=\"save\">
<input type=\"hidden\" name=\"ts0\" value=\"$TS0\">
<input type=\"hidden\" name=\"conv\" value=\"0\">
<input type=\"hidden\" name=\"meta\" value=\"$meta\">\n";

print "<h2>$__{'Editing file'} \"$file\"</h2>";

# Display file contents into a markitup-textarea 
print "<TABLE><TR><TD style=\"border:0\">";
print "<P><B>$__{'Page title'}</B><BR><INPUT name=\"titre\" size=80 value=\"$titre\">";
print "<input onmouseout=\"nd()\" onmouseover=\"overlib('Check for full HTML content (disable the syntax interpreter).')\" name=\"html\" value=\"1\"".($legacyhtml ? " checked":"")." type=\"checkbox\"> 100% HTML</P>";
print "<P><TEXTAREA id=\"markItUp\" class=\"markItUp\" rows=\"30\" cols=\"110\" name=\"txt\" dataformatas=\"plaintext\">$txt</TEXTAREA></P></TD>\n";
print "</TR></TABLE>\n";
print "<p align=center>"; 
if (length($meta) == 0 && $mmd ne 'NO') {
	print "<input type=\"button\" name=lien value=\"$__{'> MMD'}\" onClick=\"convert2MMD();\" style=\"font-weight:normal\">";
}
print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"$__{'Save'}\" onClick=\"verif_formulaire();\">";
print "</p></form>";

# end page
print "\n</BODY>\n</HTML>\n";

# ---- helpers fns for returning 'save' information to client
#
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] updated successfully !\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
}
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2016 - Institut de Physique du Globe Paris

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
