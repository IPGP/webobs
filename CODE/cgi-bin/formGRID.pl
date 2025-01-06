#!/usr/bin/perl
#
=head1 NAME

formGRID.pl

=head1 SYNOPSIS

http://..../formGRID.pl?grid=gridtype.gridname[&tpl=gridtype.template]

=head1 DESCRIPTION

Edit (create/update) a GRID specified by its fully qualified name, ie. gridtype.gridname.

When creating a new GRID (if name does not exist), formGRID starts editing from a predefined template file for the gridtype: filename $WEBOBS{ROOT_CODE}/tplates/<gridtype>_DEFAULT or specific template identified by gridtype.template argument.

To create a new GRID, user must have Admin rights for all VIEWS, PROCS, or FORMS. To update an existing GRID, user must have Edit rights for the concerned GRID.

=head1 QUERY-STRING

=item grid=gridtype.gridname
	where gridtype either VIEW, PROC, FORM, or SEFRAN.

=item action={edit|save|delete}
	'edit' (default when action is not specified) to display edit html-form edit
	'save' internaly used to save the file after html-form edition
	'delete' if present and =1, deletes the GRID.

=item tpl=gridtype.template
	where template is the template selected to create the new grid, and  gridtype
	either VIEW, PROC, FORM, or SEFRAN.

=item text=
	inline text to be saved under file= filename

=item ts0=
	if present, interpreted as being the grid's configuration 'last-modified timestamp' at the time
	the user entered the modification form (formGRID). If the current 'last-modified timestamp'
	is more recent than ts0, abort current update !

=item domain=
	specifies the DOMAINs (list).

=item SELs=
	associated NODES list.

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
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
use File::Basename;
use File::Copy qw(copy);
use File::Path qw(rmtree);
use POSIX qw/strftime/;
use List::MoreUtils qw(uniq);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff
#
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Form;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');


# ---- local functions
#

# Return information when OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgOK {
	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" ;
}

# Return information when not OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

# Print a DB error message to STDERR and show it to the user
sub htmlMsgDBError {
	my ($dbh, $errmsg) = @_;
	print STDERR $errmsg.": ".$dbh->errstr;
	htmlMsgNotOK($errmsg);
}

# Open an SQLite connection to the domains database
sub connectDbDomains {
	return DBI->connect("dbi:SQLite:$WEBOBS{SQL_DOMAINS}", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) || die "Error connecting to $WEBOBS{SQL_DOMAINS}: $DBI::errstr";
}

# Delete any existing GRIDS to NODES symbolic links and creates the required links
sub update_grid2nodes_links {
	my $GRIDType = shift;
	my $GRIDName = shift;
	my $SELs_ref = shift;
	if ($GRIDType =~ /^PROC|VIEW|FORM$/) {
		unlink(glob("$WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.*"));
		for my $nodeid (@$SELs_ref) {
			symlink("$NODES{PATH_NODES}/$nodeid",
				"$WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.$nodeid")
		}
	}
}

# Update the domains in database
# Note: seems better to delete+insert than update (in case of corrupted DB)
sub update_grid2domains {
	my $GRIDType = shift;
	my $GRIDName = shift;
	my $domains_ref = shift;

   my $dbh = connectDbDomains();
   my ($q, $rows);
   $q = "delete from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = ? and NAME = ?";
   $rows = $dbh->do($q, undef, $GRIDType, $GRIDName);
   if (!$rows) {
	     htmlMsgDBError($dbh, "formGRID: unable to delete grid"
						." $GRIDType.$GRIDName for update into domains");
   exit;
   }
   $q = "insert into $WEBOBS{SQL_TABLE_GRIDS} VALUES(?, ?, ?)";
	for my $domain (@$domains_ref) {
      $rows = $dbh->do($q, undef, $GRIDType, $GRIDName, $domain);
      if (!$rows || $rows == 0) {
	        htmlMsgDBError($dbh, "formGRID: unable to insert grid"
					  ." $GRIDType.$GRIDName into domain $domain");
	      exit;
      }
   }
   $dbh->disconnect();
}

# Extract INPUTs from FORM's conf
sub get_inputs {
    my %inputs;
    foreach(@_) {
        if ($_ =~ /(INPUT[0-9]{2}_NAME)/) {
           $inputs{$_} = 1;
        }
    }
    return %inputs;
}

# ---- misc inits
#
set_message(\&webobs_cgi_msg);
my $gridConfFile;       # file name of the grid's configuration file
my $gridConfFileMtime;  # last modification time of the config file
my $editOK = 0;         # 1 if the user is allowed to edit the grid
my $admOK = 0;          # 1 if the user is allowed to administrate the grid
my $newG    = 0;        # 1 if we are creating a new grid
my @rawfile;            # raw content of the configuration file
my $GRIDType = "";      # grid type ("PROC", "VIEW", "FORM", or "SEFRAN")
my $GRIDName = "";      # name of the grid
my %GRID;               # structure describing the grid
my @domain;             # the domain array of the grid
my $text;
my $template;           # the template for a new grid
my %FORMS;              # titles of existing forms
my $form = "";          # the form ID of the grid (if any)
my %gridnodeslist;      # IDs of nodes associated with the grid

# codemirror configuration
my $CM_edit_theme = $WEBOBS{JS_EDITOR_EDIT_THEME} // "default";
my $CM_browsing_theme = $WEBOBS{JS_EDITOR_BROWSING_THEME} // "neat";
my $CM_language_mode = "cmwocfg";
my $CM_auto_vim_mode = $WEBOBS{JS_EDITOR_AUTO_VIM_MODE} // "yes";
my $post_url = "/cgi-bin/formGRID.pl";

# Read and check CGI parameters
my $action   = checkParam($cgi->param('action'),
			qr/(edit|save|delete)/, 'action')  // "edit";
my $tpl = checkParam($cgi->param('tpl'),
			qr{^((VIEW|PROC|FORM|SEFRAN)(\.|/)[a-zA-Z0-9_]+)?$}, 'tpl') // "";
my $grid = checkParam($cgi->param('grid'),
			qr{^(VIEW|PROC|FORM|SEFRAN)(\.|/)[a-zA-Z0-9_]+$}, 'grid');
my @GID = split(/[\.\/]/, $grid);


# Read the list of all forms
opendir my $formDH, $WEBOBS{PATH_FORMS}
	or die "Problem opening form list from '$WEBOBS{PATH_FORMS}': $!\n";
my @ALL_FORMS = grep(!/^\./ && -d "$WEBOBS{PATH_FORMS}/$_", readdir($formDH));
closedir($formDH)
	or die "Problem closing form list from '$WEBOBS{PATH_FORMS}': $!\n";

# Load form titles into %FORMS
for my $f (@ALL_FORMS) {
	if (-e "$WEBOBS{PATH_FORMS}/$f/$f.conf") {
		my $F = new WebObs::Form("$f");
		$FORMS{"$f"} = $F->conf('TITLE');
	}
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
	if ($GRIDType eq 'FORM') {
		$gridConfFile = "$WEBOBS{PATH_FORMS}/$GRIDName/$GRIDName.conf";
		$auth = 'forms';
	}
	if ($tpl ne '') {
		$template = "$WEBOBS{ROOT_CODE}/tplates/$tpl";
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
		if (uc($GRIDType) eq 'FORM') { %GRID = readForm($GRIDName) };
	}
	else {
		if ($admOK) {
			@rawfile = readFile($template);
			$editOK = 1;
			$newG = 1;
		}
	}

} else { die "$__{'Not a valid GRID requested (NOT gridtype.gridname)'}" }

# ---- ends here if client is not authorized
if (!$editOK) { die "$__{'Sorry, you must have an edit level to modify'} ".$cgi->param('grid')."." }

# ---- good, passed all checkings above
#

# ===========================================================================
if ($action eq 'delete') {

	if (!$admOK) { die "$__{'Sorry, you must have an admin level to delete'} ".$cgi->param('grid')."." };

	# delete the dir/file first
	my $dir = dirname($gridConfFile);
	my $rmtree_errors;
	rmtree($dir, {'safe' => 1, 'error' => \$rmtree_errors});
	if ($rmtree_errors  && @$rmtree_errors) {
		htmlMsgNotOK("formGRID couldn't delete directory $dir");
		print STDERR "formGRID.pl: unable to delete directory $dir: "
			.join(", ", @$rmtree_errors)."\n";
		exit;
	}
	# NOTE: this removes the grid from tables,
	# but not in the nodes association conf files...
	unlink(glob("$WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.*"));
	my $dbh = connectDbDomains();
	my $q = "delete from $WEBOBS{SQL_TABLE_GRIDS}"
			." where TYPE = ? and NAME = ?";
	my $rows = $dbh->do($q, undef, $GRIDType, $GRIDName);
	if (!$rows || $rows == 0) {
		htmlMsgDBError($dbh, "formGRID: unable to delete grid"
						  ." $GRIDType.$GRIDName into domains");
		exit;
	}
	$dbh->disconnect();
	htmlMsgOK("$grid deleted");
	exit;

}


# ===========================================================================
if ($action eq 'save') {

	my @tod = localtime();

	$text = scalar($cgi->param('text')) // '';  # used only in print FILE $text;
	@domain = checkParam([$cgi->multi_param('domain')], qr/^[a-zA-Z0-9_-]*$/,
			"domain");
	my $TS0 = checkParam($cgi->param('ts0'), qr/^[0-9]*$/, "TS0") // 0;
	my @SELs = checkParam([$cgi->multi_param('SELs')],
				qr/^[0-9A-Za-z_-]+$/, "SELs");

	my $griddir = dirname($gridConfFile);

	if (! -e $gridConfFile) {
		# --- Grid creation (config file does not exist)

		if (!-d $griddir and !mkdir($griddir)) {
			htmlMsgNotOK("formGRID: error while creating directory $griddir: $!");
			exit;
		}
		if ( open(FILE,">$gridConfFile") ) {
			print FILE u2l($text);
			close(FILE);
		} else {
			htmlMsgNotOK("formGRID: error creating $gridConfFile: $!");
			exit;
		}
		update_grid2domains($GRIDType, $GRIDName, \@domain);
		update_grid2nodes_links($GRIDType, $GRIDName, \@SELs);

		htmlMsgOK("formGRID: $grid created.");
		exit;
	}

	# --- Grid update (config file already exists)

	# Additional integrity check: abort if file has changed
	# (well actually, if its last-modified timestamp has changed!)
	# since the client opened it to enter his(her) modification(s)
	if ($TS0 != (stat("$gridConfFile"))[9]) {
		htmlMsgNotOK("$gridConfFile has been modified while you were editing ! Please retry later...");
		exit;
	}


	# Use an exclusive lock on the config file during the process
	if (!sysopen(FILE, "$gridConfFile", O_RDWR | O_CREAT)) {
		# Unable to open the configuration file
		htmlMsgNotOK("formGRID: error opening $gridConfFile: $!");
		exit;
	}
	unless(flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "formGRID: waiting for lock on $gridConfFile...";
		flock(FILE, LOCK_EX);
	}

	# Backup the configuration file (To Be Removed: lifecycle too short)
	local $File::Copy::Recursive::CopyLink = 0;
	if (copy($gridConfFile, "$gridConfFile~") != 1) {
		# Unable to backup of the configuration file
		close(FILE);
		htmlMsgNotOK("formGRID: couldn't backup $gridConfFile");
		exit;
	}

	# Write the updated configuration to the configuration file
	truncate(FILE, 0);
	seek(FILE, 0, SEEK_SET);
	print FILE u2l($text);
	close(FILE);

	# Update domains and links to nodes and forms
	update_grid2domains($GRIDType, $GRIDName, \@domain);
	update_grid2nodes_links($GRIDType, $GRIDName, \@SELs);

	htmlMsgOK("formGRID: $grid updated");
	exit;

}


# ===========================================================================
# if we reached this point it's the default edit action...
if (!$newG) {
	%GRID = %{$GRID{$GRIDName}};
	@domain = split(/\|/, $GRID{'DOMAIN'});
	$form = $GRID{'FORM'} || '' if ($GRIDType eq "PROC");
	# Build a hash to efficiently test the presence of a node ID later
	%gridnodeslist = map(($_ => 1), @{$GRID{'NODESLIST'}});
}

# ---- start HTML
#
my $text = l2u(join("",@rawfile));
my $title = ($newG == 1 ? "$__{'Creating new grid'}":"$__{'Editing grid'}");

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
		document.formulaire.action.value = 'delete';
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
	//\$.post("$post_url", \$("#theform").serialize(), function(data) {
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
<input type="hidden" name="action" value="save">
_EOD_

print "<H2>$title $GRIDType.$GRIDName";
if ($admOK && !$newG) {
	print " <A href=\"#\"><IMG src=\"/icons/no.png\" onClick=\"delete_grid();\" title=\"$__{'Delete this grid'}\"></A>";
}
print "</H2>\n";

# ---- Display file contents into a "textarea" so that it can be edited
print "<TABLE style=\"\">\n";
print "<TR><TD style=\"border:0;\">\n";
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

# ---- Form lists
if ($GRIDType eq "FORM") {
	my @lists  = grep {/_TYPE\|list:/} split(/\n/, $text);
	@lists = uniq(map {s/^.*\|list:\s*(.*)$/$1/g; $_} @lists);	

	print "<FIELDSET><LEGEND>$__{'Associated lists'}</LEGEND>\n<UL style=\"margin-top:0; margin-bottom:0\">";

	foreach (@lists) {
		$_ = trim($_);
		my $tdir = "$WEBOBS{ROOT_CODE}/tplates"; 
		my $fdir  = "$WEBOBS{PATH_FORMS}/$GRIDName";
		if (! -d $fdir and !mkdir($fdir)) {
			print "fedit: error while creating directory $fdir: $!";
		}
		my $file = "$fdir/$_";
		if ((! -e $file) && -e "$tdir/$_") {
			# if the file exists only in the template directory, copy it
			qx(cp $tdir/$_ $file 2>&1);
		} elsif (! -e $file) {
			# if the file does not exist anywhere, copy the generic FORM_list
			qx(cp $tdir/FORM_list.conf $file 2>&1);
		}
		print "<LI><A href=\"/cgi-bin/xedit.pl?fs=CONF/FORMS/$GRIDName/$_\">$_</A></LI>\n";
	}
	print "</UL></FIELDSET>\n";
}

# ---- Nodes
if ($GRIDType =~ /^PROC|VIEW|FORM$/) {
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

François Beauducel, Didier Lafon, Xavier Béguin

=head1 COPYRIGHT

WebObs - 2012-2025 - Institut de Physique du Globe Paris

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
