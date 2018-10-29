#!/usr/bin/perl

=head1 NAME

wdir.pl 

=head1 SYNOPSIS

http://..../cgi-bin/wdir.pl?dir=&del=

=head1 DESCRIPTION

$WEBOBS{PATH_DATA_WEB} files management. 

Navigates subdirectories of $WEBOBS{PATH_DATA_WEB}, allowing user to 
create/edit files or subdirectories, edit files (wedit.pl), view files (wpage.pl)
or delete files (wdir.pl itself). 

Uses 'authwikis' resources for authorizations. 

=head1 Query string parameters 

dir=  defaults to WIKI
 $WEBOBS{PATH_DATA_WEB} subdirectory

del=  file to be deleted

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
use File::Path qw(make_path remove_tree);

my $myname = "$ENV{SCRIPT_NAME}";
my $abs = "$WEBOBS{PATH_DATA_WEB}";
my $aFile    = "";
my $editALL  = 0;
my $QryParm  = $cgi->Vars;
my $dir      = $QryParm->{'dir'} || "WIKI";
my $del      = $QryParm->{'del'};
my $sdir     = $QryParm->{'sdir'};
$dir =~ s|^/+||;		# remove leading /
$dir =~ s|/?$|/|;		# make sure ending /
$dir =~ s|/+|/|g;		# condense successive /
my @tree = split(/\//, $dir);
my $updir = scalar(@tree) > 1 ? join('/',splice(@tree,0,$#tree)) : "";
my $absdir = "$abs/$dir";
my $dh;

if ( ! -e $absdir ) { die "$dir $__{'is invalid'}" ; }

# del file first if requested
if ($del ne "" && -e $absdir.$del) {
	if (WebObs::Users::clientHasAdm(type=>'authwikis',name=>$dir) ) {
		unlink $absdir.$del if (-f $absdir.$del);	
		remove_tree $absdir.$del if (-d $absdir.$del);	
	}
}
# then handle subdir creation
if ($sdir ne "" && ! -e $absdir.$sdir) {
	if (WebObs::Users::clientHasAdm(type=>'authwikis',name=>$dir) ) {
		make_path($absdir.$sdir);	
	}
}

# ---- 'dir' directory list ---------------- --------------------------------- 

opendir $dh, $absdir or die "$__{'Could not open'} dir '$dir': $!";
my @files = grep { !/^\.\.?$|~$/ } readdir $dh;
closedir $dh;
@files = sort {$a cmp $b} @files;

if ( WebObs::Users::clientHasEdit(type=>'authwikis',name=>'*') ) {
	$editALL = 1;
}

# ---- create the HTML now ! ------------------------------------------------- 
#
print "Content-type: text/html\n\n";
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<head>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/wdir.js\"></script>
<title>WebObs Wikis</title>
<meta http-equiv=Content-Type content=\"text/html; charset=utf-8\">
<style>.link {cursor: pointer} td {border: none} tr.trhigh:hover {border: 1px solid grey}</style>
</head>
<BODY>";

print "<h2>$dir</h2>";
print "<DIV ID=\"dirWikiDiv\" style=\"width:100%; font-size: 11px; font-style: monospace;\">";
print "<fieldset>";
print "<TABLE style='width: 100%'>";
# new file + new subdir row
if ( ($editALL == 1) || WebObs::Users::clientHasAdm(type=>'authwikis',name=>$dir) ) {
	print "<TR style='background-color: lightgrey; margin-bottom: 6px'>";
	print "<TD style='width: 20px; padding: 5px 0px'></TD>";
	print "<TD style='width: 20px; padding: 5px 0px'></TD>";
	print "<TD style='padding: 5px 0px'>";
		print "<span style=\"margin-right: 6px\" id=\"clicknewfile\" class=\"link\" onClick=\"newFile('$dir');return false;\"><img title=\"edit new file\" src=\"/icons/modif.png\"></span>";
		print "<input style=\"margin-right: 24px\" type=\"text\" id=\"newfile\" name=\"newfile\" onClick=\"selFile('$dir')\" value=\"--$__{'new filename'}--\"/>";
		print "<span style=\"margin-right: 6px\" id=\"clicknewsdir\" class=\"link\" onClick=\"newSdir('$dir');return false;\"><img title=\"create folder\" src=\"/icons/foldr.png\"></span>";
		print "<input style=\"margin-right: 24px\" type=\"text\" id=\"newsdir\" name=\"newsdir\" onClick=\"selSdir('$dir')\" value=\"--$__{'new folder'}--\"/>";
	print "</TD>";
	print "</TR>";
}
# updir rows first
if ($updir ne "") {
	print "<TR class=\"trhigh\">";
	if (-d "$abs/$updir" && WebObs::Users::clientHasRead(type=>'authwikis',name=>$updir) ) {
		print "<TD></TD><TD></TD><TD><A href=\"$myname?dir=$updir\"><B>..</B></A></TD>";
	}
	print "</TR>";
}
# subdirs rows 
for $aFile (@files) {
	print "<TR class=\"trhigh\">";
	if (-d "$absdir/$aFile") {
		if ( WebObs::Users::clientHasRead(type=>'authwikis',name=>$aFile) ) {
			print "<TD></TD>";
			print "<TD style='width:20px'><img class=\"link\" title=\"delete\" onClick=\"delFile('$dir','$aFile');return false;\" src=\"/icons/no.png\"></TD>";
			print "<TD><A href=\"$myname?dir=$dir/$aFile\"><B>$aFile/</B></A></TD>";
		}
	}
	print "</TR>";
}
# files rows 
for $aFile (@files) {
	print "<TR class=\"trhigh\">";
	if (-f "$absdir/$aFile") {
		my $title = qx(head -n1 $absdir/$aFile);
		if (grep(/^TITRE.*\|/,$title)) { $title =~ s/^TITRE.*\|//; $title="($title)"} else { $title = ""; }
		if ( ($editALL == 1) || WebObs::Users::clientHasEdit(type=>'authwikis',name=>$aFile) ) {
			print "<TD style='width:20px'><A href=\"/cgi-bin/wedit.pl?file=$dir/$aFile\"><img title=\"edit\" src=\"/icons/modif.png\"></A></TD>";
			print "<TD style='width:20px'><img class=\"link\" title=\"delete\" onClick=\"delFile('$dir','$aFile');return false;\" src=\"/icons/no.png\"></TD>";
		}
		if ( WebObs::Users::clientHasRead(type=>'authwikis',name=>$aFile) ) {
			print "<TD><A href=\"/cgi-bin/wpage.pl?file=$dir/$aFile&css=wpage.css\"><B>$aFile</B></A>  $title</TD>";
		}
	}
	print "</TR>";
}
print "</TABLE>";
print "</fieldset>";
print "</DIV>\n";
print "<br><br>";

# -------- closing tags -----------------------------------------------------
print "</BODY></HTML>";

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

