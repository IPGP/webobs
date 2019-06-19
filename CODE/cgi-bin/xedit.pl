#!/usr/bin/perl 

=head1 NAME

xedit.pl 

=head1 SYNOPSIS

http://..../xedit.pl?fs=wokey[&action={save | edit}][&browse=1]

=head1 DESCRIPTION

WebObs configuration-file editor. 

=head1 QUERY STRING

=over 

=item fs={ wokey | wokey(ikey) | CONF/path | DATA/path }

B<wokey> is the $WEBOBS{key} whose value is the filename to be edited.
B<wokey(ikey)> is a 1-level indirection, where wokey is the $WEBOBS{key} that points to the configuration file that defines the ikey whose value is the filename to be edited.
In both cases, the target filename must reside in $WEBOBS{ROOT_CONF} or $WEBOBS{ROOT_DATA}; its WebObs' authorization resource name is B<authmisc.path> (see Users.pm for path-like resources)

	eg. : fs=CONF_NODES
	will browse/edit the CONF/file pointed to by $WEBOBS{CONF_NODES} 

	eg. : fs=CONF_NODES(FILE_NODES2NODES)
	will browse/edit the file pointed to by FILE_NODES2NODES in the file pointed to by $WEBOBS{CONF_NODES}

B<CONF/path> or B<DATA/path> is the filename to be edited, in $WEBOBS{ROOT_CONF} or $WEBOBS{ROOT_DATA} respectively; 
its WebObs' authorization resource name is B<authmisc.path> (see Users.pm for path-like resources)

=item action={save | edit}

	'edit' (default when action is not specified) to display edit html-form edit 
	'save' internaly used to save the file after html-form edition
	(other parameters are used along with 'save': ts0, txt)

=item browse=

When set to 1, forces B<browse> mode.

=back

=head1 EDITOR 

Editor area (textarea) is managed by CodeMirror, copyright (c) by Marijn Haverbeke and others, Distributed under an MIT license: http://codemirror.net/LICENSE .

Uses WebObs B<cmwocfg.js> for configuration files syntax highlighting. Better used 
with a theme having distinct colors for comment,keyword,operator,qualifier
such as ambiance.css. See Configuration Variables below. 

Uses Vim addon.

=head1 CONFIGURATION VARIABLES

Optional customization variables in B<WEBOBS.rc> are shown below with their default value:
(themes names are those from CodeMirror distribution, without their css suffix)   

	XEDIT_ETHEME|ambiance      # codemirror theme when editing
	XEDIT_BTHEME|neat          # codemirror theme when browsing
	XEDIT_VMODE|vim            # automatically enter vim mode or not (any other value)

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

my @lignes;
my $XEtheme = $WEBOBS{XEDIT_ETHEME} // "ambiance";
my $XBtheme = $WEBOBS{XEDIT_BTHEME} // "neat";
my $Vmode   = $WEBOBS{XEDIT_VMODE}  // "vim";

my $mode = "cmwocfg";

# ---- see what file has to be edited, and corresponding authorization for client
#
my $me = $ENV{SCRIPT_NAME}; 
my $QryParm   = $cgi->Vars;
my $fs     = $QryParm->{'fs'}     // "";
my $action = $QryParm->{'action'} // "edit";
my $txt    = $QryParm->{'txt'}    // "";
my $TS0    = $QryParm->{'ts0'}    // "";
my $fbrowse= $QryParm->{'browse'} // 0;

my $absfile ="";
my $relfile ="";
my $editOK = my $admOK = my $readOK = 0;
my $fsmsg = "";

if ($fs ne "") {
	if ($fs =~ /^CONF\//) {
		($absfile = $fs) =~ s/^CONF\//$WEBOBS{ROOT_CONF}\//; 
	} elsif ($fs =~ /^DATA\//) {
		($absfile = $fs) =~ s/^DATA\//$WEBOBS{ROOT_DATA}\//;
	} else {
		my @u = split(/[()]/, $fs);
		if (scalar(@u) == 2) { 
			my %l = readCfg($WEBOBS{$u[0]}); 
			$absfile = $l{$u[1]};
		} else { $absfile = "$WEBOBS{$fs}"; }
	}
	if (($relfile = $absfile) =~ s/^$WEBOBS{ROOT_CONF}\/+|^$WEBOBS{ROOT_DATA}\/+//) {
		$readOK = clientHasRead(type=>"authmisc",name=>"$relfile");
		if ( $readOK ) {
			if ( !$fbrowse ) {
				$editOK = clientHasEdit(type=>"authmisc",name=>"$relfile");
				$admOK  = clientHasAdm(type=>"authmisc",name=>"$relfile");
				unless (-e dirname($absfile) || !$admOK) { mkdir dirname($absfile) }
				if ( (!-e $absfile) && $admOK ) { qx(/bin/touch $absfile); $fsmsg="New file" }
				if ( (!$editOK) && (!-e $absfile) ) { die "$relfile $__{'not found'} or $__{'not authorized'}" }
			}
		} else { die "$relfile $__{'not authorized'}" }
	} else { die "$relfile $__{'Not a CONF/ nor DATA/ file'}" }
} else { die "$__{'No filename specified'}" }

# ---- action is 'save'
#
if ($action eq 'save') {
	if ($TS0 != (stat("$absfile"))[9]) { 
		htmlMsgNotOK("$relfile has been modified while you were editing !"); 
		exit; 
	}
	if ( sysopen(FILE, "$absfile", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "$me waiting for lock on $relfile...";
			flock(FILE, LOCK_EX);
		}
		qx(cp -a $absfile $absfile~ 2>&1); 
		if ( $?  == 0 ) { 
			truncate(FILE, 0);
			seek(FILE, 0, SEEK_SET);
			$txt =~ s{\r\n}{\n}g;   # 'cause js-serialize() forces 0d0a
			push(@lignes,$txt);
			print FILE @lignes ;
			close(FILE);
			htmlMsgOK($relfile);
		} else {
			close(FILE);
			htmlMsgNotOK("$me couldn't backup $relfile");
		}
	} else { htmlMsgNotOK("$me opening $relfile - $!") }
	exit;
}

# ---- action is 'edit' (default)
#
@lignes = readFile($absfile);
$TS0 = (stat($absfile))[9] ;
$txt = join("",@lignes);

# build html page
# - page, common
print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<STYLE type=\"text/css\">
	#ta {
		border:none;
	}
	#statusbar {
		border: solid 1px grey;
		background-color: grey;
		color: white;
		font-size: 12px;
	}
</STYLE>
<TITLE>WebObs xedit</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
";
# - page, codemirror defs
print "<link rel=\"stylesheet\" href=\"/js/codemirror/lib/codemirror.css\">
<link rel=\"stylesheet\" href=\"/js/codemirror/theme/$XEtheme.css\">
<link rel=\"stylesheet\" href=\"/js/codemirror/theme/$XBtheme.css\">
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/codemirror/lib/codemirror.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/$mode.js\"></script>
<!-- <script src=\"/js/codemirror/addon/scroll/simplescrollbars.js\"></script> -->
<script src=\"/js/codemirror/addon/search/searchcursor.js\"></script>
<!-- <link rel=\"stylesheet\" href=\"/js/codemirror/addon/scroll/simplescrollbars.css\"> -->
<script src=\"/js/codemirror/addon/dialog/dialog.js\"></script>
<link rel=\"stylesheet\" href=\"/js/codemirror/addon/dialog/dialog.css\">
<script src=\"/js/codemirror/keymap/vim.js\"></script>
";
# - page, xedit scripts
print "<script type=\"text/javascript\">
var XCB = {
	ETHEME: '$XEtheme',
	BTHEME: '$XBtheme',
	MODE:   '$mode',
	VMODE:  '$Vmode',
	READOK: $readOK,
	ADMOK:  $admOK,
	EDITOK: $editOK,
	ME:     '$me' 
};
</script>
<script src=\"/js/xedit.js\"></script>
";
print "</HEAD>\n";
# - page, body
print "<BODY style=\"background-color:#E0E0E0\" onLoad=\"document.formulaire.txt.focus()\">";
print <<html;
<script type=\"text/javascript\" >
</script>
html
# - page, edit or browse area
print "<h3>$relfile</h3>"; 
print "<form id=\"theform\" name=\"formulaire\" action=\"\" style=\"margin: 0px 0px 0px 10px; width: 600px;\">
<input type=\"hidden\" name=\"fs\" value=\"$fs\">
<input type=\"hidden\" name=\"action\" value=\"save\">
<input type=\"hidden\" name=\"ts0\" value=\"$TS0\">\n";

# - page, file contents textarea
print "<TEXTAREA id=\"ta\" name=\"txt\"";
print " readonly " if ($editOK || $admOK);
print ">$txt</TEXTAREA>\n";
print "<div id=\"statusbar\">$fsmsg</div>";
# - page, button(s) area
print "<p align=center>";
print "<input type=\"button\" id=\"bvim\" title=\"Vim On/Off\" value=\"$__{'Vim'}\" onClick=\"toggleVim();\">";
if ($editOK || $admOK) {
	print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
	print "<input type=\"button\" value=\"$__{'Save'}\" onClick=\"postform();\">";
} else {
	print "<input type=\"button\" name=lien value=\"$__{'Quit'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
}
print "</p>";
print "</form>";

# end page
print "\n</BODY>\n</HTML>\n";

# ---- helpers fns for returning 'save' information to client
#
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	#[FBnote: does not suppress alert() window...] print "$_[0] updated successfully !\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
	print "$_[0] updated successfully !\n";
}
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2019 - Institut de Physique du Globe Paris

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
