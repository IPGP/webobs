#!/usr/bin/perl

=head1 NAME

fedit.pl

=head1 SYNOPSIS

http://..../fedit.pl?fname=fname[&action={edit|save}&tpl=tpl]

=head1 DESCRIPTION

Edit (create/update) a FORM specified by its fully qualified name, ie. fname.

When creating a new FORM (if name does not exist), fedit starts editing from a predefined template file: filename $WEBOBS{ROOT_CODE}/tplates/FORM.GENFORM or specific template identified by form.template argument.

To create a new FORM, user must have Admin rights for all FORMS. To update/delete an existing FORM, user must have Edit rights for the concerned FORM.

=head1 Query string parameters

=item fname=fname

	where fname should be unique.

=item action={save|edit}

	'edit' (default when action is not specified) to display edit html-form edit
	'save' internaly used to save the file after html-form edition

=item tpl=tpl

	where tpl is the template selected to create the new form

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
use File::Path qw(rmtree);
use File::Copy qw(copy);
use File::Temp ();
use File::Path qw(mkpath rmtree);
use HTML::Escape qw(escape_html);

use CGI;
my $cgi = new CGI;
$CGI::POST_MAX = 1024;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
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

# ---- local functions
#

# Return information when OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
}

# Return information when not OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

# Open an SQLite connection to the forms database
sub connectDbForms {
	return DBI->connect("dbi:SQLite:$WEBOBS{SQL_FORMS}", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) || die "Error connecting to $WEBOBS{SQL_FORMS}: $DBI::errstr";
}

sub count_inputs {
    my $count = 0;
    foreach(@_) {
        if ($_ =~ /(INPUT[0-9]{2}_NAME)/) {
            $count += 1;
        }
    }
    return $count;
}

# ---- misc inits
#
set_message(\&webobs_cgi_msg);
my $me = $ENV{SCRIPT_NAME};
my $formConfFile;       # file name of the form's configuration file
my $TS0;                # last modification time of the config file
my $editOK = 0;         # 1 if the user is allowed to edit the form
my $admOK = 0;          # 1 if the user is allowed to create new form
my @rawfile;            # raw content of the configuration file
my $FORMName;		# name of the form
my $text;
my $action;		# new|edit|save
my $newF;        	# 1 if we are creating a new form
my $delete;		# 1 to delete form
my $inputs;		# number which indicates how many inputs we are storing in this form
my $template;		# name of template wanted by user

# Read and check CGI parameters
$FORMName = $cgi->param('fname');
$action   = checkParam($cgi->param('action'), qr/(edit|save)/, 'action')  // "edit";
$text	  = $cgi->param('text') // '';	# used only in print FILE $text;
$TS0      = checkParam($cgi->param('ts0'), qr/^[0-9]*$/, "TS0")    // 0;
$delete   = checkParam($cgi->param('delete'), qr/^\d?$/, "delete") // 0;
$template = $cgi->param('tpl') // "";

# Read the list of all nodes
opendir my $nodeDH, $NODES{PATH_NODES}
	or die "Problem opening node list from '$NODES{PATH_NODES}': $!\n";
my @ALL_NODES = sort grep(!/^\./ && -d "$NODES{PATH_NODES}/$_",
						  readdir($nodeDH));
closedir($nodeDH)
	or die "Problem closing node list from '$NODES{PATH_NODES}': $!\n";

# codemirror configuration
my $CM_edit_theme = $WEBOBS{JS_EDITOR_EDIT_THEME} // "default";
my $CM_browsing_theme = $WEBOBS{JS_EDITOR_BROWSING_THEME} // "neat";
my $CM_language_mode = "cmwocfg";
my $CM_auto_vim_mode = $WEBOBS{JS_EDITOR_AUTO_VIM_MODE} // "yes";
my $post_url = "/cgi-bin/fedit.pl";

# ---- see what we've been called for and what the client is allowed to do
# ---- init general-use variables on the way and quit if something's wrong
#
$editOK = WebObs::Users::clientHasEdit(type => "authforms", name => "$FORMName");
$admOK = WebObs::Users::clientHasAdm(type => "authforms", name => "*");
if ( $editOK == 0 ) { die "$__{'Not authorized'}" }

my $formdir   = "$WEBOBS{PATH_FORMS}/$FORMName/";			# path to the form configuration file we are creating, editing or deleting
$formConfFile = "$formdir$FORMName.conf";

my @db_columns0 = ("id integer PRIMARY KEY AUTOINCREMENT", "trash boolean DEFAULT FALSE", "node text NOT NULL",
		   "edate datetime", "edate_min datetime",
		   "sdate datetime NOT NULL", "sdate_min datetime",
		   "users text NOT NULL");
my @db_columns1 = ("comment text", "tsupd text NOT NULL", "userupd text NOT NULL");

# ---- action is 'save'
#
if ($action eq 'save') {
	if (! -e $formConfFile) {
		# --- Form creation (config file does not exist)

		if (! -d $formdir and !mkdir($formdir)) {
			htmlMsgNotOK("fedit: error while creating directory $formdir: $!");
			exit;
		}
		if (open(FILE,">", $formConfFile) ) {
			print FILE u2l($text);
			close(FILE);
		} else {
			htmlMsgNotOK("fedit: error creating $formConfFile: $!");
			exit;
		}

		# --- connecting to the database in order to create a table with the name of the FORM
		my $dbh = connectDbForms();

		# --- checking if the table we want to edit exists
		my $tbl 	  = lc($FORMName);

		my $stmt = qq(select exists (select name from sqlite_master where type='table' and name='$tbl'););
		my $sth = $dbh->prepare( $stmt );
		my $rv = $sth->execute() or die $DBI::errstr;

		if ($sth->fetchrow_array() == 0) {	# if $sth->fetchrow_array() == 0, it means $tbl doe snot exists in the DB
			# --- creation of the DB table
			my @inputs = grep {/(INPUT[0-9]{2}_NAME)/} split(/\n/, $text);

			my @db_columns = @db_columns0;
			push(@db_columns, map { lc((split '_', $_)[0])." text" } @inputs);
			push(@db_columns, @db_columns1);

			my $stmt = "create table if not exists $tbl (".join(', ', @db_columns).")";
			#htmlMsgOK($stmt);
			my $sth = $dbh->prepare( $stmt );
			my $rv = $sth->execute() or die $DBI::errstr;
		} else {
			htmlMsgNotOK("Can't create the table !");
			exit;
		}

		htmlMsgOK("fedit: $FORMName created.");
		exit;
	} else {
		# --- connecting to the database in order to create a table with the name of the FORM
		my $dbh = connectDbForms();

		# --- checking if the table we want to edit exists
		my $tbl 	  = lc($FORMName);

		my $stmt = qq(select exists (select name from sqlite_master where type='table' and name='$tbl'););
		my $sth = $dbh->prepare( $stmt );
		my $rv = $sth->execute() or die $DBI::errstr;

		if ($sth->fetchrow_array() == 0) {	# if $sth->fetchrow_array() == 0, it means $tbl doe snot exists in the DB
			# --- creation of the DB table
			my @inputs = grep {/(INPUT[0-9]{2}_NAME)/} split(/\n/, $text);

			my @db_columns = @db_columns0;
			push(@db_columns, map { lc((split '_', $_)[0])." text" } @inputs);
			push(@db_columns, @db_columns1);

			my $stmt = "create table if not exists $tbl (".join(', ', @db_columns).")";
			my $sth = $dbh->prepare( $stmt );
			my $rv = $sth->execute() or die $DBI::errstr;
		}
		
		# now we know if the table exists
		# we want to look at the modification of $text
		my @inputs  = grep {/(INPUT[0-9]{2}_NAME)/} split(/\n/, $text);
		my $newKeys = $#inputs;
		my $oldKeys = count_inputs(readCfg($formConfFile));

		my $msg;
		if ($newKeys + 1 > $oldKeys) {
			$msg = "A new INPUT has been added to the FORM !";

			# --- connecting to the database in order to add the new INPUT to the DB 
			my @db_columns = @db_columns0;
			push(@db_columns, map { lc((split '_', $_)[0])." text" } @inputs);
			push(@db_columns, @db_columns1);

			my $stmt = "create table if not exists $tbl (".join(', ', @db_columns).")";
			my $sth = $dbh->prepare( $stmt );
			my $rv = $sth->execute() or die $DBI::errstr;
		} elsif ($newKeys + 1 < $oldKeys) {
			$msg = "You can't remove an INPUT !";
			htmlMsgNotOK($msg);
			exit;
		}

		if ($TS0 != (stat("$formConfFile"))[9]) { 
			htmlMsgNotOK("$FORMName $__{'has been modified while you were editing'}"); 
			exit; 
		}
		if ( sysopen(FILE, "$formConfFile", O_RDWR | O_CREAT) ) {
			unless (flock(FILE, LOCK_EX|LOCK_NB)) {
				warn "$me waiting for lock on $FORMName...";
				flock(FILE, LOCK_EX);
			}
			qx(cp -a $formConfFile $formConfFile~ 2>&1); 
			if ( $?  == 0 ) { 
				truncate(FILE, 0);
				seek(FILE, 0, SEEK_SET);
				$text =~ s{\r\n}{\n}g;   # 'cause js-serialize() forces 0d0a
				push(@rawfile,u2l($text));
				print FILE @rawfile ;
				close(FILE);
			} else {
				close(FILE);
				htmlMsgNotOK("$me couldn't backup $FORMName");
			}
		} else { htmlMsgNotOK("$me opening $FORMName - $!") }
		htmlMsgOK($msg);
		exit;
	}
}

# --- Form delete or update (config file already exists)

if ($delete == 1) {
	# --- Delete the form!

	# delete the dir/file first
	my $rmtree_errors;
	rmtree($formdir, {'safe' => 1, 'error' => \$rmtree_errors});
	if ($rmtree_errors  && @$rmtree_errors) {
		htmlMsgNotOK("fedit couldn't delete directory $formdir");
		print STDERR "fedit.pl: unable to delete directory $formdir: "
			.join(", ", @$rmtree_errors)."\n";
		exit;
	}
	htmlMsgOK("$FORMName deleted");
	exit;
}

# ---- action is 'edit' (default)
#
if ( -e "$formConfFile" ) {	# looking if the FORM already exists
	if ($editOK) {
		@rawfile = readFile($formConfFile);
		$TS0 = (stat($formConfFile))[9] ;
	}
}
else {	# we are creating a new FORM
	if ($admOK) {
		$formConfFile = "$WEBOBS{ROOT_CODE}/tplates/$template";
		@rawfile = readFile($formConfFile);
		$TS0 = (stat($formConfFile))[9] ;
		$newF = 1;
	}
}

# start building page
#
my $txt = l2u(escape_html(join("",@rawfile)));
my $titrePage = "$__{'Editing'} form";
if ( $newF == 1 ) { $titrePage = "$__{'Creating'} new form" }

#my $cm_edit = ($editOK || $admOK) ? 1 : 0;
my $cm_edit = 1;
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
 function delete_form()
 {
	if ( confirm("$__{'The FORM will be deleted. Are you sure?'}") ) {
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
	// postform() from cmtextarea.js will submit the form to $post_url
	console.log(document.formulaire);
	postform();
	//\$.post("/cgi-bin/fedit.pl", \$("#theform").serialize(), function(data) {
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
<input type="hidden" name="ts0" value="$TS0">
<input type="hidden" name="fname" value="$FORMName">
<input type=\"hidden\" name=\"action\" value=\"save\">
<input type="hidden" name="delete" value="0">
_EOD_

print "<H2>$titrePage $FORMName";
if ($newF == 0) {
	print " <A href=\"#\"><IMG src=\"/icons/no.png\" onClick=\"delete_form();\" title=\"$__{'Delete this form'}\"></A>";
}
print "</H2>\n";

# ---- Display file contents into a "textarea" so that it can be edited
print "<TABLE style=\"\">\n";
print "<TR><TD style=\"border:0;\">\n";
#print "<TEXTAREA class=\"editfmono\" id=\"tarea\" rows=\"30\" cols=\"80\" name=\"text\" dataformatas=\"plaintext\">$text</TEXTAREA><br>\n";
print "<TEXTAREA class=\"editfmono\" id=\"textarea-editor\" rows=\"30\" cols=\"80\" name=\"text\" dataformatas=\"plaintext\">$txt</TEXTAREA>\n";
print "<div id=\"statusbar\">$FORMName</div>\n";

print "</TD>\n<TD style=\"border:0; vertical-align:top\">\n";

# ---- Lists
my @lists  = grep {/(INPUT[0-9]{2}_TYPE)/} split(/\n/, $txt);

print "<FIELDSET><LEGEND>Lists</LEGEND>\n";

foreach(@lists) {
	if ($_ =~ /list:/) {
		$_ = (split /\: /, $_)[1];
		my $dir  = "$WEBOBS{PATH_FORMS}/$FORMName/";
		my $file = $dir.$_;
		if (-e $file) {
			$file = "CONF/FORMS/$FORMName/$_";
			print "<A href=\"/cgi-bin/xedit.pl?fs=$file\">$file</a>\n";
		} elsif ($template =~ /GENFORM/ && ! -e "$file"){
			if (! -d $dir and !mkdir($dir)) {
				print "fedit: error while creating directory $dir: $!";
			}
			qx(cp -a $WEBOBS{ROOT_CODE}/tplates/FORM_list.conf $file 2>&1);
			$file = "CONF/FORMS/$FORMName/$_";
			print "<A href=\"/cgi-bin/xedit.pl?fs=$file\">$file</a>\n";
		} else {
			my $suffix = lc((split /FORM\./, $template)[1]);
			if (! -d $dir and !mkdir($dir)) {
				print "fedit: error while creating directory $dir: $!";
			}
			qx(cp -a $WEBOBS{ROOT_CODE}/tplates/FORM_list$suffix.conf $file 2>&1);
			$file = "CONF/FORMS/$FORMName/$_";
			print "<A href=\"/cgi-bin/xedit.pl?fs=$file\">$file</a>\n";
		}
	}
}
print "</FIELDSET>\n";

print "</TD>\n";
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

Lucas Dassin, François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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


