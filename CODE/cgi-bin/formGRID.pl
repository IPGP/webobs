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
 where gridtype either VIEW or PROC.  

type=gridtype.template
 where gridtype either VIEW or PROC.  
 
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
my $newG    = 0;        # 1 if we are creating a new grid
my @rawfile;            # raw content of the configuration file
my $GRIDType = "";      # grid type ("PROC" or "VIEW")
my $GRIDName = "";      # name of the grid
my %GRID;               # structure describing the grid
my $domain;             # the domain of the grid
my $template;           # the template for a new grid
my %FORMS;              # titles of existing forms
my $form = "";          # the form ID of the grid (if any)
my %gridnodeslist;      # IDs of nodes associated with the grid

# Read and check CGI parameters
my $type = checkParam($cgi->param('type'),
			qr{^((VIEW|PROC)(\.|/)[a-zA-Z0-9_]+)?$}, 'type') // "";
my $grid = checkParam($cgi->param('grid'),
			qr{^(VIEW|PROC)(\.|/)[a-zA-Z0-9_]+$}, 'grid');
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
	@GID = map { uc($_) } @GID;
	($GRIDType, $GRIDName) = @GID;
	if ($GRIDType eq 'VIEW') {
		$gridConfFile = "$WEBOBS{PATH_VIEWS}/$GRIDName/$GRIDName.conf";
	}
	if ($GRIDType eq 'PROC') {
		$gridConfFile = "$WEBOBS{PATH_PROCS}/$GRIDName/$GRIDName.conf";
	}
	if ($type ne '') {
		$template = "$WEBOBS{ROOT_CODE}/tplates/$type";
	} else {
		$template = "$WEBOBS{ROOT_CODE}/tplates/$GRIDType.DEFAULT";
	}
	if ( -e "$gridConfFile" ) {
		if ( WebObs::Users::clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
			@rawfile = readFile($gridConfFile);
			$gridConfFileMtime = (stat($gridConfFile))[9] ;
			$editOK = 1;
		}
		if (uc($GRIDType) eq 'VIEW') { %GRID = readView($GRIDName) };
		if (uc($GRIDType) eq 'PROC') { %GRID = readProc($GRIDName) };
	}
	else {
		if ( WebObs::Users::clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"*")) {
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
	$domain = $GRID{'DOMAIN'};
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

print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<TITLE>Text edit form</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/htmlFormsUtils.js\"></script>
<script type=\"text/javascript\">
function delete_grid()
{
	if ( confirm(\"$__{'The GRID will be deleted (but not associated nodes). Are you sure ?'}\") ) {
		document.formulaire.delete.value = 1;
		\$.post(\"/cgi-bin/postGRID.pl\", \$(\"#theform\").serialize(), function(data) {
			if (data != '') alert(data);
			location.href = document.referrer;	   
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
	\$.post(\"/cgi-bin/postGRID.pl\", \$(\"#theform\").serialize(), function(data) {
		if (data != '') alert(data);
		location.href = document.referrer;	   
	});
}
</script>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" onLoad=\"document.formulaire.text.focus()\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>
";

print "<FORM id=\"theform\" name=\"formulaire\" action=\"\">";
print "<input type=\"hidden\" name=\"ts0\" value=\"$gridConfFileMtime\">\n";
print "<input type=\"hidden\" name=\"grid\" value=\"$grid\">\n";
print "<input type=\"hidden\" name=\"delete\" value=\"0\">\n";

print "<H2>$titrePage $GRIDType.$GRIDName";
if ($newG == 0) {
	print " <A href=\"#\"><IMG src=\"/icons/no.png\" onClick=\"delete_grid();\" title=\"$__{'Delete this grid'}\"></A>";
}
print "</H2>\n";

# ---- Display file contents into a "textarea" so that it can be edited
print "<TABLE><TR><TD style=\"border:0\">";
print "<P><TEXTAREA class=\"editfmono\" id=\"tarea\" rows=\"30\" cols=\"80\" name=\"text\" dataformatas=\"plaintext\">$text</TEXTAREA></P></TD>\n";
print "<TD style=\"border:0;vertical-align:top\">";
print "<FIELDSET><LEGEND>Domain</LEGEND><P><select name=\"domain\" size=\"1\">\n";
for (keys %DOMAINS) {
	print "<option value=\"$_\"".($domain eq $_ ? " selected":"").">{$_}: $DOMAINS{$_}{NAME}</option>\n";
}
print "</select></P></FIELDSET>\n";
if ($GRIDType eq "PROC") {
	print "<FIELDSET><LEGEND>Form</LEGEND><P><select name=\"form\" size=\"1\">\n";
	print "<option value=\"\"> --- none --- </option>\n";
	for (keys(%FORMS)) {
		print "<option value=\"$_\"".($form eq $_ ? " selected":"").">{$_}: $FORMS{$_}</option>\n";
	}
	print "</select></P></FIELDSET>\n";
}
print "<FIELDSET><LEGEND>Associated nodes</LEGEND>";
print "<TABLE border=\"0\" cellpadding=\"3\" cellspacing=\"0\" width=\"100%\">";
print "<TR><TD>";
print "<SELECT name=\"INs\" size=\"10\" multiple style=\"font-family:monospace;font-size:110%\">";
for my $nodeId (@ALL_NODES) { 
	if (!exists $gridnodeslist{$nodeId}) {
		print "<option value=\"$nodeId\">$nodeId</option>\n";
	}
}
print "</SELECT></td>";
print "<TD align=\"center\" valign=\"middle\">";
print "<INPUT type=\"Button\" value=\"Add >>\" style=\"width:100px\" onClick=\"SelectMoveRows(document.formulaire.INs,document.formulaire.SELs)\"><br>";
print "<br>";
print "<INPUT type=\"Button\" value=\"<< Remove\" style=\"width:100px\" onClick=\"SelectMoveRows(document.formulaire.SELs,document.formulaire.INs)\">";
print "</TD>";
print "<TD>";
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

print "</TD>\n</TR>\n";
print "<TR><TD style=\"border:0\"></TD>\n";
print "<TD style=\"border:0\"><P align=center>";
print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"$__{'Save'}\" onClick=\"verif_formulaire();\" style=\"font-weight:bold\">";
print "</P></TD></TR>";
print "</TABLE>\n";
print "</FORM>\n";

# ---- end HTML
#  
print "\n</BODY>\n</HTML>\n";

__END__

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

