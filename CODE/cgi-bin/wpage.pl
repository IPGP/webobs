#!/usr/bin/perl

=head1 NAME

wpage.pl 

=head1 SYNOPSIS

http://..../cgi-bin/wpage.pl?file=filespec&css=

=head1 DESCRIPTION

Interprets the contents of the requested file as a mix of html tags and WebObs's
wiki-language tags, to build and display a WebObs' style html page. 
Resulting HTML is placed in a full-width <DIV id="wikiDiv">.   

See WebObs:Wiki::wiki2html for wiki language specifications.

The authorization resource-name, in authwikis resource-type, that is checked for Read access to the file,
is built from filespec following the 'path-like' resource-names rules as described in WebObs::Users.

	Example: 
	file = HTML/public/intro.wiki
	==> actual file = $WEBOBS{PATH_DATA_WEB}/HTML/public/intro.wiki
	==> resources   = authwikis.HTML/public/intro.wiki  OR
	                = authwikis.HTML/public  OR
					= authwikis.HTML/

=head1 Query string parameters 

file=filespec
	file to be interpreted/displayed.
	B<filespec := [relpath/]name> 
	filespec (with optional relpath) is relative to $WEBOBS{PATH_DATA_WEB}

css=cssfile
	user-defined css file to include in output page; must be located in WebObs css directory

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

my @lines;
my $editor;
my $absfile;
my $editOK;
my $titre="";
my $html;

my $QryParm   = $cgi->Vars;
my $file = $QryParm->{'file'} // "";
my $css  = $QryParm->{'css'}  // "";

if ($file ne "") {
    $absfile = "$WEBOBS{PATH_DATA_WEB}/$file";
    if ( -e $absfile ) {
        $editOK = WebObs::Users::clientHasEdit(type=>"authwikis",name=>$file);
        if ( WebObs::Users::clientHasRead(type=>'authwikis',name=>$file) ) {
            open(RDR, "<$absfile") || die "couldn't open $file";
            push (@lines,$_) while(<RDR>);
            close RDR;
            $html = 0;
            if ($lines[0] =~ /^TITRE_HTML\|/) {
                $titre = substr($lines[0],11);
                shift(@lines);
                $html = 1;
            }
            if ($lines[0] =~ /^TITRE\|/) {
                $titre = substr($lines[0],6);
                shift(@lines);
            }
            chomp($titre);
            if ( $editOK ) {
                $editor  = "<P align=\"right\">";
                $editor .= "<A href=\"/cgi-bin/wedit.pl?file=$file\">";
                $editor .= "<B>$__{'Edit this page'}</B></A></P>";
            }
        } else { die "$__{'Not authorized'}" }
    } else { die "$file $__{'not found'}" }
} else { die "$__{'No filename specified'}" }

print "Content-type: text/html\n\n";
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<head>";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/$css\">" if ($css) ;
print "<script language=\"JavaScript\" src=\"/js/jquery.js\" type=\"text/javascript\"></script>";
print "<script language=\"JavaScript\" src=\"/js/htmlFormsUtils.js\"></script>";
print "<title>$titre</title>
<meta http-equiv=Content-Type content=\"text/html; charset=utf-8\">
</head>
<BODY>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<DIV ID=\"helpBox\"></DIV>
<DIV ID=\"editlink\">$editor</DIV>";
print "<DIV ID=\"wikiDiv\" style=\"width:100%\">";
if ($titre ne "") {
    print "<H1>$titre</H1>";
}
if ($html) {
    print @lines;
} else {
    print WebObs::Wiki::wiki2html(join("",@lines));
}
print "</DIV>\n";
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

