#!/usr/bin/perl

=head1 NAME

showNODES.pl

=head1 SYNOPSIS

http://..../showNODES.pl

=head1 DESCRIPTION

Displays all known NODES as a matrix: row=node, column=GRID node belongs to

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

# get all NODEs configurations !!
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
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_WMCSS}">
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

print "<TABLE width=\"100%\"><TR><TD style=\"border:0;vert-align:top\"><H1>$WEBOBS{WEBOBS_ID}: $__{'All nodes'}</H1></TD>\n";
my $nv = scalar(grep { $_ =~ /^VIEW/ } @T);
my $np = scalar(grep { $_ =~ /^PROC/ }@T);
my $tot = keys %N;
print "<TD style=\"border:0;text-align:right\"><TABLE>";
print "<TR><TD style=\"border:0;text-align:right\"><B>$nv</B></TD><TD style=\"border:0\">views</TD></TR>";
print "<TR><TD style=\"border:0;text-align:right\"><B>$np</B></TD><TD style=\"border:0\">procs</TD></TR>";
print "<TR><TD style=\"border:0;text-align:right\"><B>$tot</B></TD><TD style=\"border:0\">$__{'nodes'}</TD></TR></TABLE>\n";
print "</TD></TR></TABLE><P></P>\n";

# ---- build matrix as a <TABLE>
print "<DIV class=\"nodetbl\">";
print "<TABLE cellspacing=0>\n";
	print "<THEAD>";
	my $oddeven = "even"; my $what = 'view';
	$row = "<TR><TH></TH>";
	for (@T) {
		$what = ($_ =~ m/^VIEW./) ? 'view' : 'proc';
		$row .= "<TH class=\"skew $what $oddeven\"><div><span>$_</span></div></TH>";
		$oddeven = $oddeven eq "even" ? "odd" : "even";
	}
	print "$row\n";
	print "</THEAD>";

	print "<TBODY>";
	for my $node (sort keys(%N)) {
		my $oddeven = "even";
		$row = "<TR><TD class=\"nodeid\">$node</TD>";
		for (@T) {
			$what = ($_ =~ m/^VIEW./) ? 'view' : 'proc';
			if ($_ ~~ @{$N{$node}}) {
				my $link = "\"$NODES{CGI_SHOW}?node=$_.$node\"";
				$row .= "<TD class=\"otimes $what $oddeven\"><a href=$link>&cir;</a></TD>" 
			}
			else {
				$row .= "<TD class=\"oempty $what $oddeven\">&empty;</TD>"
			}
			$oddeven = $oddeven eq "even" ? "odd" : "even";
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

Webobs - 2012-2024 - Institut de Physique du Globe Paris

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
