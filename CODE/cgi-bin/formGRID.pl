#!/usr/bin/perl
#
=head1 NAME

formGRID.pl

=head1 SYNOPSIS

http://..../formGRID.pl?grid=gridtype.gridname[,type=gridtype.template]

=head1 DESCRIPTION

Edit (create/update) a GRID specified by its fully qualified name, ie. gridtype.gridname.

When creating a new GRID (if name does not exist), formGRID starts editing from a predefined template file for the gridtype: filename $WEBOBS{ROOT_CODE}/tplates/<gridtype>_DEFAULT or specific template identified by gridtype.template argument.

To create a new GRID, user must have Admin rights for all VIEWS or PROCS. To update an existing GRID, user must have Edit rights for the concerned GRID.

=head1 QUERY-STRING

grid=gridtype.gridname
 where gridtype either VIEW, PROC, or SEFRAN.

type=gridtype.template
 where gridtype either VIEW, PROC, or SEFRAN.

=head1 EDITOR

Editor area (textarea) is managed by CodeMirror, copyright (c) by Marijn
Haverbeke and others, Distributed under an MIT license:
http://codemirror.net/LICENSE .

Uses WebObs B<cmwocfg.js> for configuration files syntax highlighting. Better used
with a theme having distinct colors for comment,keyword,operator,qualifier
such as ambiance.css. See Configuration Variables below.

Uses Vim addon.

=head1 CONFIGURATION VARIABLES

Optional customization variables in B<WEBOBS.rc> are shown below with their default value:
(themes names are those from CodeMirror distribution, without their css suffix)

    JS_EDITOR_EDIT_THEME|default    # codemirror theme when editing
    JS_EDITOR_BROWSING_THEME|neat   # codemirror theme when browsing
    JS_EDITOR_AUTO_VIM_MODE|no      # automatically enter vim mode or not (any other value)
                                    #  True if value is 'true' or 'yes' (case insensitive),
                                    #  False for any other value.
=cut

use strict;
use warnings;
use File::Basename;
use CGI;
my $cgi = new CGI;
$CGI::POST_MAX = 1024;
use CGI::Carp qw(fatalsToBrowser set_message);
use Locale::TextDomain('webobs');
use POSIX qw/strftime/;

# ---- webobs stuff
#
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Form;
use WebObs::Utils;
use WebObs::i18n;

# ---- misc inits
#
set_message(\&webobs_cgi_msg);
my $gridConfFile;       # file name of the grid's configuration file
my $gridConfFileMtime;  # last modification time of the config file
my $editOK  = 0;        # 1 if the user is allowed to edit the grid
my $admOK = 0;          # 1 if the user is allowed to administrate the grid
my $newG    = 0;        # 1 if we are creating a new grid
my @rawfile;            # raw content of the configuration file
my $GRIDType = "";      # grid type ("PROC", "VIEW", or "SEFRAN")
my $GRIDName = "";      # name of the grid
my %GRID;               # structure describing the grid
my @domain;             # the domain array of the grid
my $template;           # the template for a new grid
my %FORMS;              # titles of existing forms
my $form = "";          # the form ID of the grid (if any)
my %gridnodeslist;      # IDs of nodes associated with the grid

# codemirror configuration
my $CM_edit_theme = $WEBOBS{JS_EDITOR_EDIT_THEME} // "default";
my $CM_browsing_theme = $WEBOBS{JS_EDITOR_BROWSING_THEME} // "neat";
my $CM_language_mode = "cmwocfg";
my $CM_auto_vim_mode = $WEBOBS{JS_EDITOR_AUTO_VIM_MODE} // "yes";
my $post_url = "/cgi-bin/postGRID.pl";

# Read and check CGI parameters
my $type = checkParam($cgi->param('type'),
			qr{^((VIEW|PROC|SEFRAN)(\.|/)[a-zA-Z0-9_]+)?$}, 'type') // "";
my $grid = checkParam($cgi->param('grid'),
			qr{^(VIEW|PROC|SEFRAN)(\.|/)[a-zA-Z0-9_]+$}, 'grid');
my @GID = split(/[\.\/]/, $grid);


# Read the list of all forms
opendir my $formDH, $WEBOBS{PATH_FORMS}
	or die "Problem opening form list from '$WEBOBS{PATH_FORMS}': $!\n";
my @ALL_FORMS = grep(!/^\./ && -d "$WEBOBS{PATH_FORMS}/$_", readdir($formDH));
closedir($formDH)
	or die "Problem closing form list from '$WEBOBS{PATH_FORMS}': $!\n";

# Load form titles into %FORMS
for my $f (@ALL_FORMS) {
	my $F = new WebObs::Form("$f");
	$FORMS{"$f"} = $F->conf('TITLE');
}

# Read the list of all nodes
opendir my $nodeDH, $NODES{PATH_NODES}
	or die "Problem opening node list from '$NODES{PATH_NODES}': $!\n";
my @ALL_NODES = sort grep(!/^\./ && -d "$NODES{PATH_NODES}/$_",
						  readdir($nodeDH));
closedir($nodeDH)
	or die "Problem closing node list from '$NODES{PATH_NODES}': $!\n";


# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
if (scalar(@GID) == 2) {
	my $auth;
	@GID = map { uc($_) } @GID;
	($GRIDType, $GRIDName) = @GID;
	if ($GRIDType eq 'SEFRAN') {
		$gridConfFile = "$WEBOBS{PATH_SEFRANS}/$GRIDName/$GRIDName.conf";
		$auth = 'procs';
	}
	if ($GRIDType eq 'VIEW') {
		$gridConfFile = "$WEBOBS{PATH_VIEWS}/$GRIDName/$GRIDName.conf";
		$auth = 'views';
	}
	if ($GRIDType eq 'PROC') {
		$gridConfFile = "$WEBOBS{PATH_PROCS}/$GRIDName/$GRIDName.conf";
		$auth = 'procs';
	}
	if ($type ne '') {
		$template = "$WEBOBS{ROOT_CODE}/tplates/$type";
	} else {
		$template = "$WEBOBS{ROOT_CODE}/tplates/$GRIDType.DEFAULT";
	}
	$editOK = WebObs::Users::clientHasEdit(type => "auth".$auth, name => "$GRIDName") || WebObs::Users::clientHasEdit(type => "auth".$auth, name => "MC");
	$admOK = WebObs::Users::clientHasAdm(type => "auth".$auth, name => "*");
	if ( -e "$gridConfFile" ) {
		if ($editOK) {
			@rawfile = readFile($gridConfFile);
			$gridConfFileMtime = (stat($gridConfFile))[9] ;
			$editOK = 1;
		}
		if (uc($GRIDType) eq 'SEFRAN') { %GRID = readSefran($GRIDName) };
		if (uc($GRIDType) eq 'VIEW') { %GRID = readView($GRIDName) };
		if (uc($GRIDType) eq 'PROC') { %GRID = readProc($GRIDName) };
	}
	else {
		if ($admOK) {
			$gridConfFile = $template;
			@rawfile = readFile($gridConfFile);
			$gridConfFileMtime = (stat($gridConfFile))[9] ;
			$editOK = 1;
			$newG = 1;
		}
	}

} else { die "$__{'Not a valid GRID requested (NOT gridtype.gridname)'}" }
if ( $editOK == 0 ) { die "$__{'Not authorized'}" }

if (!$newG) {
	%GRID = %{$GRID{$GRIDName}};
	@domain = split(/\|/, $GRID{'DOMAIN'});
	$form = $GRID{'FORM'} || '' if ($GRIDType eq "PROC");
	# Build a hash to efficiently test the presence of a node ID later
	%gridnodeslist = map(($_ => 1), @{$GRID{'NODESLIST'}});
}

# ---- good, passed all checkings above
#
# ---- start HTML
#
my $text = l2u(join("",@rawfile));
my $titrePage = "$__{'Editing'} grid";
if ( $newG == 1 ) { $titrePage = "$__{'Creating'} new grid" }

my $cm_edit = ($editOK || $admOK) ? 1 : 0;
print <<_EOD_;
Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<HTML>
<HEAD>
 <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
 <TITLE>Text edit form</TITLE>

 <link rel="stylesheet" href="/js/codemirror/lib/codemirror.css">
 <!-- <link rel=\"stylesheet\" href=\"/js/codemirror/addon/scroll/simplescrollbars.css\"> -->
_EOD_

if ($CM_edit_theme != "default") {
	print " <link rel=\"stylesheet\" href=\"/js/codemirror/theme/$CM_edit_theme.css\">\n";
}
if ($CM_browsing_theme != "default" && $CM_edit_theme != $CM_browsing_theme) {
	print " <link rel=\"stylesheet\" href=\"/js/codemirror/theme/$CM_browsing_theme.css\">\n";
}

print <<_EOD_;
 <link rel="stylesheet" href="/css/codemirror-wo.css">

 <script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
 <script language="javascript" type="text/javascript" src="/js/htmlFormsUtils.js"></script>
 <script language="javascript" type="text/javascript" src="/js/codemirror/lib/codemirror.js"></script>
 <script language="javascript" type="text/javascript" src="/js/$CM_language_mode.js"></script>
 <!-- <script src=\"/js/codemirror/addon/scroll/simplescrollbars.js\"></script> -->
 <script src="/js/codemirror/addon/search/searchcursor.js"></script>
 <script src="/js/codemirror/addon/dialog/dialog.js"></script>
 <link rel="stylesheet" href="/js/codemirror/addon/dialog/dialog.css">
 <script src="/js/codemirror/keymap/vim.js"></script>
 <script type=\"text/javascript\">
  // Configuration used in cmtextarea.js
  var CODEMIRROR_CONF = {
	READWRITE_THEME: '$CM_edit_theme',
	READONLY_THEME: '$CM_browsing_theme',
	LANGUAGE_MODE: '$CM_language_mode',
	AUTO_VIM_MODE: '$CM_auto_vim_mode',
	EDIT_PERM: $cm_edit,
	FORM: '#theform',
	POST_URL: '$post_url',
  };
 </script>
 <script src="/js/cmtextarea.js"></script>

 <script type="text/javascript">
 function delete_grid()
 {
	if ( confirm("$__{'The GRID will be deleted (but not associated nodes). Are you sure?'}") ) {
		document.formulaire.delete.value = 1;
		\$.post("$post_url", \$("#theform").serialize(), function(data) {
			if (data != '') alert(data);
			location.href = "$GRIDS{CGI_SHOW_GRIDS}";
		});
	} else {
		return false;
	}
}
function verif_formulaire()
{
	for (var i=0; i<document.formulaire.SELs.length; i++) {
		document.formulaire.SELs[i].selected = true;
	}
	if (document.formulaire.domain.value == '') {
		if ( !confirm("$__{'No associated domain: the grid will be hidden. Are you sure?'}") ) return false;
	}
	// postform() from cmtextarea.js will submit the form to $post_url
	postform();
	//\$.post("/cgi-bin/postGRID.pl", \$("#theform").serialize(), function(data) {
	//	if (data != '') alert(data);
	//	location.href = document.referrer;
	//});
}
 </script>
</HEAD>
<BODY style="background-color:#E0E0E0" onLoad="document.formulaire.text.focus()">
<!-- <script type="text/javascript" src="/js/jquery.js"></script> -->
<!-- overLIB (c) Erik Bosrup -->
<script language="JavaScript" src="/js/overlib/overlib.js"></script>
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<div id="helpbox"></div>

<FORM id="theform" name="formulaire" action="">
<input type="hidden" name="ts0" value="$gridConfFileMtime">
<input type="hidden" name="grid" value="$grid">
<input type="hidden" name="delete" value="0">
_EOD_

print "<H2>$titrePage $GRIDType.$GRIDName";
if ($newG == 0) {
	print " <A href=\"#\"><IMG src=\"/icons/no.png\" onClick=\"delete_grid();\" title=\"$__{'Delete this grid'}\"></A>";
}
print "</H2>\n";

# ---- Display file contents into a "textarea" so that it can be edited
print "<TABLE style=\"\">\n";
print "<TR><TD style=\"border:0;\">\n";
#print "<TEXTAREA class=\"editfmono\" id=\"tarea\" rows=\"30\" cols=\"80\" name=\"text\" dataformatas=\"plaintext\">$text</TEXTAREA><br>\n";
print "<TEXTAREA class=\"editfmono\" id=\"textarea-editor\" rows=\"30\" cols=\"80\" name=\"text\" dataformatas=\"plaintext\">$text</TEXTAREA>\n";
print "<div id=\"statusbar\">$GRIDType.$GRIDName</div>\n";

print "</TD>\n";

# ---- Domains
print "<TD style=\"border:0; vertical-align:top\">";
print "<FIELDSET><LEGEND>$__{'Domain'}</LEGEND><SELECT name=\"domain\" size=\"10\" multiple>\n";
foreach my $d (sort(keys(%DOMAINS))) {
	print "<option value=\"$d\"".(grep(/^$d$/, @domain) ? " selected":"").">{$d}: $DOMAINS{$d}{NAME}</option>\n";
}
print "</SELECT></FIELDSET>\n";
#[DEBUG:] print "<p>domain = +".join('+',@domain)."+</p>";

# ---- Forms
if ($GRIDType eq "PROC") {
	print "<FIELDSET><LEGEND>$__{'Form'}</LEGEND><SELECT name=\"form\" size=\"1\">\n";
	print "<option value=\"\"> --- none --- </option>\n";
	for (sort(keys(%FORMS))) {
		print "<option value=\"$_\"".($form eq $_ ? " selected":"").">{$_}: $FORMS{$_}</option>\n";
	}
	print "</SELECT></FIELDSET>\n";
}

# ---- Nodes
if ($GRIDType eq "PROC" || $GRIDType eq "VIEW") {
	print "<FIELDSET><LEGEND>$__{'Available/Associated nodes'}</LEGEND>";
	print "<TABLE cellpadding=\"3\" cellspacing=\"0\" style=\"border:0\">";
	print "<TR><TD style=\"border:0\">";
	print "<SELECT name=\"INs\" size=\"10\" multiple style=\"font-family:monospace;font-size:110%\">";
	for my $nodeId (@ALL_NODES) {
		if (!exists $gridnodeslist{$nodeId}) {
			print "<option value=\"$nodeId\">$nodeId</option>\n";
		}
	}
	print "</SELECT></RD>";
	print "<TD align=\"center\" valign=\"middle\" style=\"border:0\">";
	print "<INPUT type=\"Button\" value=\"Add >>\" style=\"width:100px\" onClick=\"SelectMoveRows(document.formulaire.INs,document.formulaire.SELs)\"><br>";
	print "<br>";
	print "<INPUT type=\"Button\" value=\"<< Remove\" style=\"width:100px\" onClick=\"SelectMoveRows(document.formulaire.SELs,document.formulaire.INs)\">";
	print "</TD>";
	print "<TD style=\"border:0\">";
	print "<SELECT name=\"SELs\" size=\"10\" multiple style=\"font-family:monospace;font-size:110%;font-weight:bold\">";
	if (!$newG) {
		for my $nodeId (sort @{$GRID{NODESLIST}}) {
			print "<option value=\"$nodeId\">$nodeId</option>";
		}
	}
	print "</SELECT></td>";
	print "</TR>";
	print "</TABLE>";
	print "</FIELDSET>";
} else {
	print "<INPUT name=\"SELs\" type=\"hidden\" value=\"-\">";
}
# ---- Sefrans
if ($GRIDType eq "SEFRAN") {
	my $chconf = (exists($GRID{CHANNEL_CONF}) && -e $GRID{CHANNEL_CONF} ? "$GRID{CHANNEL_CONF}":"$WEBOBS{PATH_SEFRANS}/$GRIDName/channels.conf");
	qx(cp $WEBOBS{ROOT_CODE}/tplates/SEFRAN_channels.conf $chconf) if (! -e "$chconf");
	$chconf =~ s|^.*/CONF/|CONF/|g;
	print "<FIELDSET><LEGEND>Sefran Channels</LEGEND>\n";
	print "<A href=\"/cgi-bin/xedit.pl?fs=$chconf\">$chconf</a>\n";
	print "</FIELDSET>\n";
}

print "</TD>\n</TR>\n";
print "<TR><TD style=\"border:0\">\n";

# Vim mode checkbox
print <<_EOD_;
	<div class="js-editor-controls">
		<input type="checkbox" id="toggle-vim-mode" title="$__{'Check to enable vim mode in the editor'}" onClick="toggleVim()">
		<label for="toggle-vim-mode" id="toggle-vim-mode-label" title="$__{'Check to enable vim mode in the editor'}">$__{'Use vim mode'}</label>
	</div>
	</TD>
_EOD_

# Form buttons
print <<_EOD_;
 <TD style="border: 0">
  <p align=center>
   <input type="button" name="lien" value="$__{'Cancel'}" onClick="history.go(-1)">
   <input type="button" class=\"submit-button\" value="$__{'Save'}" onClick="verif_formulaire();">
  </p>
 </TD>
</TR>
</TABLE>
</FORM>
_EOD_

# ---- end HTML
#
print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon, Xavier Béguin

=head1 COPYRIGHT

Webobs - 2012-2022 - Institut de Physique du Globe Paris

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
