#!/usr/bin/perl
#
=head1 NAME

showREQ.pl

=head1 SYNOPSIS

http://..../cgi-bin/showREQ.pl

=head1 DESCRIPTION

Shows the list of results from html-form for 'B<Request for Graphs>'.

A submitted B<Request for Graphs> will have all of its results (outputs) files grouped into the
OUTR directory, under a subdirectory whose name uniquely identifies the Request:

	OUTR/YYYYMMDD_HHMMSS_HOSTNAME_UID
		REQUEST.rc
		PROC.PROCa/
			{exports,graphs,maps,logs}/
		....
		PROC.PROCz/
			{exports,graphs,maps,logs}/


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
use WebObs::i18n;

# ---- misc inits
#
set_message(\&webobs_cgi_msg);

my @reqlist;
my @reqs;
my $table;

my $myself = "/cgi-bin/".basename($0);
my %SCHED = readCfg($WEBOBS{CONF_SCHEDULER});
my $QryParm = $cgi->Vars;

map (push(@reqlist,$_), qx(find $WEBOBS{ROOT_OUTR} -type d -mindepth 1 -maxdepth 1));
chomp(@reqlist);

# ---- build/process the form HTML page
#
my $pagetitle = "$__{'Requests results'}";

print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<TITLE>$pagetitle</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\">

</HEAD>
<BODY style=\"background-color:#E0E0E0\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>";

print "<h2>$pagetitle</h2>";
print "<P class=\"subMenu\"><b>&raquo;&raquo;</b> [ Forms: "
."<a href=\"/cgi-bin/formREQ.pl\"><b>Procs</b></a> | "
."<a href=\"/cgi-bin/formGRIDMAPS.pl\"><b>Gridmaps</b></a> | "
."Users: "
.($QryParm->{'usr'} eq "all" ? "<a href=\"$myself\"><b>$CLIENT</b></a> | all":"$CLIENT | <a href=\"$myself?usr=all\"><b>all</b></a>")." | "
."<IMG src='/icons/refresh.png' style='vertical-align:middle' title='Refresh' onClick='document.location.reload(false)'>"
." ]</P>";

$table = "<TABLE><TR><TH>$__{'Date & Time'}</TH><TH>$__{'Host'}</TH><TH>$__{'User'}</TH><TH>$__{'Time Span'}</TH><TH>$__{'Params'}</TH>
	.<TH>$__{'Job'}</TH><TH>$__{'Graphs'}</TH><TH>$__{'Archive'}</TH><TH>$__{'Status'}</TH></TR>\n";

for (reverse sort @reqlist) {
	my $dir = my $reqdir = $_;
	$reqdir =~ s/$WEBOBS{ROOT_OUTR}\///;
	my ($date,$time,$host,$user) = split(/_/,$reqdir);
	my $date1 = qx(grep "^DATE1|" $dir/REQUEST.rc | sed -e "s/DATE1|//");
	my $date2 = qx(grep "^DATE2|" $dir/REQUEST.rc | sed -e "s/DATE2|//");
	my (@procs) = grep {-d} glob("$dir/{PROC.*,GRIDMAPS}");
	my $rowspan = scalar(@procs)+1;
	if ($user eq $CLIENT || (WebObs::Users::clientHasAdm(type=>"authprocs",name=>"$_") && $QryParm->{'usr'} eq "all")) {
		if (length($date)==8 && length($time)==6) {
			$date = substr($date,0,4)."-".substr($date,4,2)."-".substr($date,6,2);
			$time = substr($time,0,2).":".substr($time,2,2).":".substr($time,4,2);
		}
		$table .= "<TR>"
			."<TD rowspan='$rowspan' align=center>$date $time</TD>"
			."<TD rowspan='$rowspan' align=center>$host</TD>"
			."<TD rowspan='$rowspan' align=center>$user</TD>"
			."<TD rowspan='$rowspan' align=center>$date1 - $date2</TD>"
			."<TD rowspan='$rowspan' align=center><A href='$WEBOBS{URN_OUTR}/$reqdir/REQUEST.rc'>.rc</A></TD>";
		for (@procs) {
			$_ =~ s/$dir\///;
			(my $proc = $_) =~ s/PROC\.//;
			if (WebObs::Users::clientHasRead(type=>"authprocs",name=>"$proc") || $_ eq "GRIDMAPS") {
				$table .= "<TD align=center>$_</TD>"
					."<TD align=center><A href='/cgi-bin/showOUTR.pl?dir=$reqdir&grid=$_'><IMG src='/icons/visu.png'</A></TD>";
				my $archive = qx(ls $dir/$_.tgz);
				if ($archive eq ""){
					$table .= "<TD></TD>";
				} else {
					$table .= "<TD align=center><a download='$_' href='$WEBOBS{URN_OUTR}/$reqdir/$_.tgz'><img src='/icons/dwld.png'></a></TD>";
				}
				my $rreq = qx(sqlite3 $SCHED{SQL_DB_JOBS} "SELECT cmd,rc FROM runs WHERE jid<0 AND cmd LIKE '%$reqdir%' AND cmd LIKE '%$proc%';");
				chomp($rreq);
				if ($rreq eq "") {
					$table .= "<TD></TD>";
				} else {
					my ($rcmd,$rc) = split(/\|/,$rreq);
					if ($rc eq "0") {
						$table .= "<TD align=center bgcolor=green>OK</TD>";
					} elsif ($rc > 0) {
						$table .= "<TD align=center bgcolor=red>error</TD>";
					} else {
						$table .= "<TD align=center bgcolor=orange>wait...</TD>";
					}
				}
			}
			$table .= "</TR>\n<TR>";
		}
		if ($rowspan==1) {
			$table .= ("<TD style='background-color: #EEEEDD'></TD>" x 3)."</TD></TR>\n";
		}
	}
}

$table .= "</TABLE><BR><BR>\n";
print $table;

# ---- end HTML
#

print "\n</BODY>\n</HTML>\n";


__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel

=head1 COPYRIGHT

Webobs - 2012-2017 - Institut de Physique du Globe Paris

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
