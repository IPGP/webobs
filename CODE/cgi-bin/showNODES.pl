#!/usr/bin/perl

=head1 NAME

showNODES.pl

=head1 SYNOPSIS

http://..../showNODES.pl

=head1 DESCRIPTION

Displays all known NODES as a matrix: row=node, column=GRID node belongs to

=head1 Authorizations

Authorization concerns the associated grid resource. A minimum read level is needed to see the node in the table.

=cut

use strict;
use warnings;

use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);
use WebObs::Config;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Grids;
use WebObs::Users qw($CLIENT clientIsValid clientHasRead);

# --- ends here if the client is not valid
if ( !clientIsValid ) {
    die "$__{'die_client_not_valid'}";
}

# get all GRIDs with a minimum read auth
my @T;
for (sort(WebObs::Grids::listViewNames())) {
    push(@T, "VIEW.$_") if (clientHasRead(type=>"authviews",name=>"$_"));
}
for (sort(WebObs::Grids::listProcNames())) {
    push(@T, "PROC.$_") if (clientHasRead(type=>"authprocs",name=>"$_"));
};
for (sort(WebObs::Grids::listFormNames())) {
    push(@T, "FORM.$_") if (clientHasRead(type=>"authforms",name=>"$_"));
};

# get all NODE IDs with grid association
my %N = WebObs::Grids::listNodeGrids();
my $row = "";

# ---- start HTML page output
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print <<"FIN";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Nodes Map</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/shownodes.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript">
\$(document).ready(function() {
    \$('.nodetbl table tr').hover(
        function(e) {
            \$(this).addClass("hover");
        },
        function(e) {
            \$(this).removeClass("hover");
        }
    );
});
</script>
</head>
<body>
FIN

# ---- title and global stats
print "<TABLE width=\"100%\"><TR><TD style=\"border:0;vert-align:top\"><H1>$WEBOBS{WEBOBS_ID}: $__{'All nodes'}</H1></TD>\n";
print "<TD style=\"border:0;text-align:right\"><TABLE width=\"100%\">";
print "<TR><TD style=\"border:0;text-align:right\"><B>".(grep { $_ =~ /^VIEW/ } @T)."</B></TD><TD style=\"border:0\">views</TD></TR>\n";
print "<TR><TD style=\"border:0;text-align:right\"><B>".(grep { $_ =~ /^PROC/ } @T)."</B></TD><TD style=\"border:0\">procs</TD></TR>\n";
print "<TR><TD style=\"border:0;text-align:right\"><B>".(grep { $_ =~ /^FORM/ } @T)."</B></TD><TD style=\"border:0\">forms</TD></TR>\n";
print "<TR><TD style=\"border:0;text-align:right\"><B>".(keys %N)."</B></TD><TD style=\"border:0\">$__{'nodes'}</TD></TR>\n";
print "<TR><TD style=\"border:0;text-align:right\"><B>".(grep(/^1$/,map { @{$_} == 0 } values %N))."</B></TD><TD style=\"border:0\">$__{'orphan nodes'}</TD></TR>\n";
print "</TABLE></TD></TR></TABLE>\n";

# ---- build matrix as a <TABLE>
print "<DIV class=\"nodetbl\">";
print "<TABLE cellspacing=0>\n";
print "<THEAD>";
my $what;
my $oddeven = "even";
$row = "<TR><TH></TH>";
for (@T) {
    $what = ($_ =~ m/^PROC./ ? 'proc':($_ =~ m/^FORM./ ? 'form':'view'));
    $row .= "<TH class=\"skew $what $oddeven\"><div><span>$_</span></div></TH>";
    $oddeven = $oddeven eq "even" ? "odd" : "even";
}
print "$row\n";
print "</THEAD>\n";

print "<TBODY>";
for my $node (sort keys(%N)) {
    my $oddeven = "even";
    $row = "<TR><TD class=\"nodeid\">$node</TD>";
    if (@{$N{$node}}) {
        for (@T) {
            $what = ($_ =~ m/^PROC./ ? 'proc':($_ =~ m/^FORM./ ? 'form':'view'));
            if ($_ ~~ @{$N{$node}}) {
                my $link = "\"$NODES{CGI_SHOW}?node=$_.$node\"";
                $row .= "<TD class=\"otimes $what $oddeven\"><a href=$link>&cir;</a></TD>"
            }
            else {
                $row .= "<TD class=\"oempty $what $oddeven\">&empty;</TD>"
            }
            $oddeven = $oddeven eq "even" ? "odd" : "even";
        }
    } else {
        $row .= "<TD class=\"oorphan\" colspan=\"".(@T)."\"></TD></TR>\n";
    }
    print $row;
}
print "</TBODY>";
print "</TABLE>";
print "</DIV>\n";

# ---- we're done
print "</body></html>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel

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
