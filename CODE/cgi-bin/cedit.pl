#!/usr/bin/perl 

=head1 NAME

cedit.pl 

=head1 SYNOPSIS

http://..../cedit.pl?fs=wokey[&action={save | edit} ]

=head1 DESCRIPTION

Configuration-file editor. Browse/Edit the file pointed to by the WEBOBS.rc key <wokey> 

=head1 Query string parameters

=over 

=item fs={ wokey | wokey(indkey) }

    wokey is a WEBOBS.rc key, that points to the full-path-filename to be edited.
    wokey(indkey) is a 1-level indirection, where wokey points to someind file key <indkey> that points to the full-path-filename to be edited

    target full-path-filename must reside in $WEBOBS{CONF_NODES}
    authorization resource is authmisc.subpath/filename (see Users.pm for path-like resource names)

    eg. : fs=CONF_NODES
    will browse/edit the file pointed to by $WEBOBS{CONF_NODES} 

    eg. : fs=CONF_NODES(FILE_NODES2NODES)
    will browse/edit the file pointed to by FILE_NODES2NODES in the file pointed to by $WEBOBS{CONF_NODES}

=item action={save | edit}

    'edit' (default when action is not specified) to display edit html-form edit 
    'save' internaly used to save the file after html-form edition
    (other parameters are used along with 'save': ts0, txt)

=back

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

# ---- see what file has to be edited, and corresponding authorization for client
#
my $me = $ENV{SCRIPT_NAME};
my $QryParm   = $cgi->Vars;
my $fs     = $QryParm->{'fs'} // "";
my $action = $QryParm->{'action'} // "edit";
my $txt    = $QryParm->{'txt'} // "";
my $TS0    = $QryParm->{'ts0'} // "";

my $absfile ="";
my $relfile ="";
my $editOK = my $admOK = my $readOK = 0;
my $fsmsg = "";

if ($fs ne "") {

    #my @u = split(/->/,$fs);
    my @u = split(/[()]/, $fs);
    if (scalar(@u) == 2) {
        my %l = readCfg($WEBOBS{$u[0]});
        $absfile = $l{$u[1]};
    } else { $absfile = "$WEBOBS{$fs}"; }
    if ( $absfile =~ /^$WEBOBS{ROOT_CONF}\//) {
        ($relfile = $absfile) =~ s/^$WEBOBS{ROOT_CONF}\/+//;
        $readOK = clientHasRead(type=>"authmisc",name=>"$relfile");
        if ( $readOK ) {
            $editOK = clientHasEdit(type=>"authmisc",name=>"$relfile");
            $admOK  = clientHasAdm(type=>"authmisc",name=>"$relfile");
            unless (-e dirname($absfile) || !$admOK) { mkdir dirname($absfile) }
            if ( (!-e $absfile) && $admOK ) { qx(/bin/touch $absfile); $fsmsg="$relfile created empty" }
            if ( (!$editOK) && (!-e $absfile) ) { die "$relfile $__{'not found'} or $__{'not authorized'}" }
        } else { die "$relfile $__{'not authorized'}" }
    } else { die "$relfile $__{'Not a CONF/ file'}" }
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
            push(@lignes,u2l($txt));
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
chomp(@lignes);
$txt = l2u(join("",@lignes));

# start building page
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
    }
</STYLE>
<TITLE>Text edit form</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\">
function verif_formulaire()
{
    \$.post(\"$me\", \$(\"#theform\").serialize(), function(data) {
           if (data != '') alert(data);
              //location.href = document.referrer;
           history.go(-1);
       });
}
</script>
</HEAD>
<BODY onLoad=\"document.formulaire.txt.focus()\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\" >
    \$(document).ready(function() {
    });
</script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>
";
print "<form id=\"theform\" name=\"formulaire\" action=\"\">
<input type=\"hidden\" name=\"fs\" value=\"$fs\">
<input type=\"hidden\" name=\"action\" value=\"save\">
<input type=\"hidden\" name=\"ts0\" value=\"$TS0\">\n";

print "<h2>$__{'Editing file'} \"$relfile\"</h2>";

# Display file contents into a textarea 
print "<TABLE><TR><TD style=\"border:0\">";
if ($editOK || $admOK) {
    print "<TR><TD><TEXTAREA id=\"ta\" class=\"editfmono\" rows=\"25\" cols=\"100\" name=\"txt\" dataformatas=\"plaintext\">$txt</TEXTAREA></TD></TR>\n";
    print "<TR><TD id=\"statusbar\">Edit | $fsmsg</TD></TR>";
} else {
    print "<TR><TD><TEXTAREA readonly id=\"ta\" class=\"editfmono\" rows=\"25\" cols=\"100\" name=\"txt\" dataformatas=\"plaintext\">$txt</TEXTAREA></TD></TR>\n";
    print "<TR><TD id=\"statusbar\">Browse | $fsmsg</TD></TR>";
}
print "</TABLE>\n";

# button(s) area
print "<p align=center>";
if ($editOK || $admOK) {
    print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
    print "<input type=\"button\" value=\"$__{'Save'}\" onClick=\"verif_formulaire();\">";
} else {
    print "<input type=\"button\" name=lien value=\"$__{'Quit'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
}
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
