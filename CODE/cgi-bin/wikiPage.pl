#!/usr/bin/perl

=head1 NAME

wikiPage.pl 

=head1 SYNOPSIS

http://..../cgi-bin/wikiPage.pl?file=

=head1 DESCRIPTION

Interprets the contents of the requested file as a mix of html tags and WebObs's
wiki-language tags, to build and display a WebObs' style html page. 
Resulting HTML tags are placed in a full-width <DIV id="wikiDiv">.   

See WebObs:Wiki::wiki2html for wiki language specifications.

=head1 Query string parameters 

file=
  file to be interpreted/displayed. If not found, wikiPage will try to locate it 
  in $WEBOBS{PATH_USERS_WIKI} or $WEBOBS{PATH_USERS_HTML} in this order.

=cut

use strict;
use warnings;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

use WebObs::Config;
use WebObs::Wiki;
use WebObs::i18n;
use WebObs::Users;
use Locale::TextDomain('webobs');

$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

my @lines;
my $editor;

my $QryParm   = $cgi->Vars;
my $file = $QryParm->{'file'} // "";


my $bfn = basename($file);
$bfn =~ s/\..*$//;
if (!WebObs::Users::clientHasRead(type=>'authwikis',name=>"*")
	&& !WebObs::Users::clientHasRead(type=>'authwikis',name=>$bfn)) {
	die "$__{'Not authorized'}";
}

# ---- read the requested wiki page ------------------------------------------ 
if ($file ne "") {
	if (! -f $file) {
		$file="$WEBOBS{PATH_USERS_WIKI}/$file" if (-f "$WEBOBS{PATH_USERS_WIKI}/$file"); 
		$file="$WEBOBS{PATH_USERS_HTML}/$file" if (-f "$WEBOBS{PATH_USERS_HTML}/$file"); 
	}
	open(RDR, "<$file") || die " couldn't open $file\n";
	push (@lines,$_) while(<RDR>); 
	close RDR;
} else { die " missing page name\n"; }

# ---- legacy 1st line processing =? title and html/nothtml switch -- TBD --- 
my $html  = 0;
my $titre = "";
if ($lines[0] =~ /^TITRE_HTML\|/) {
	$titre = substr($lines[0],11);
	$html = 1;
}
if ($lines[0] =~ /^TITRE\|/) {
	$titre = substr($lines[0],6);
}
shift(@lines) if ($titre ne "");
chomp($titre);

# ---- define/display a link to editor when permitted ------------------------
if (WebObs::Users::clientHasEdit(type=>'authwikis',name=>"*") || WebObs::Users::clientHasEdit(type=>'authwikis',name=>"$bfn")) {
	$editor  = "<P align=\"right\">"; 
	$editor .= "<A href=\"/cgi-bin/editMIU.pl?file=$file&rn=authwikis.$bfn\">"; 
	$editor .= "<B>$__{'Edit this page'}</B></A></P>";
}

# ---- create the HTML now ! ------------------------------------------------- 
#
# -------- common tags, scripts, css ....
print "Content-type: text/html\n\n";
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<head>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<title>$titre</title>
<meta http-equiv=Content-Type content=\"text/html; charset=utf-8\">
</head>
<BODY>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID=\"helpBox\"></DIV>
<DIV ID=\"editlink\">$editor</DIV>";

# -------- html or wiki things from input $file, in its own DIV ------------
print "<DIV ID=\"wikiDiv\" style=\"width:100%\">";   # TBD: a specific css file ?
if ($titre ne "") {
	print "<H1>$titre</H1>";
}
if ($html) {
	print @lines;
} else {
	print WebObs::Wiki::wiki2html(join("",@lines));
}
print "</DIV>\n";

# -------- closing tags -----------------------------------------------------
print "</BODY></HTML>";


__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Mallarino, Didier Lafon

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

