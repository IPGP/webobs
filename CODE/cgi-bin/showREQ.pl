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
  <meta http-equiv=\"refresh\" content=\"60\">
</HEAD>
<BODY>
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>";

print "<h1>$pagetitle</h1>";
print "<P class=\"subMenu\"><b>&raquo;&raquo;</b> [ $__{'Request Forms:'} "
  ."<a href=\"/cgi-bin/formREQ.pl\"><b>Procs</b></a> | "
  ."<a href=\"/cgi-bin/formGRIDMAPS.pl\"><b>Gridmaps</b></a> | "
  ."Users: "
  .($QryParm->{'usr'} eq "all" ? "<a href=\"$myself\"><b>$CLIENT</b></a> | all":"$CLIENT | <a href=\"$myself?usr=all\"><b>all</b></a>")." | "
  ."<IMG src='/icons/refresh.png' style='vertical-align:middle;cursor:pointer' title='Refresh' onClick='document.location.reload(false)'>"
  ." ]</P>";

$table = "<TABLE><TR><TH>$__{'Date & Time'}</TH><TH>$__{'Host'}</TH><TH>$__{'User'}</TH><TH>$__{'Time Span'}</TH><TH>$__{'Params'}</TH>
    .<TH>$__{'Job logs'}</TH><TH>$__{'Status'}</TH><TH>$__{'Graphs'}</TH><TH>$__{'Archive'}</TH></TR>\n";

for (reverse sort @reqlist) {
    my $dir = my $reqdir = $_;
    $reqdir =~ s|$WEBOBS{ROOT_OUTR}/||;
    my ($date,$time,$host,$user) = split(/_/,$reqdir);
    my $date1 = qx(grep -a "^DATE1|" $dir/REQUEST.rc | sed -e "s/DATE1|//");
    my $date2 = qx(grep -a "^DATE2|" $dir/REQUEST.rc | sed -e "s/DATE2|//");
    my (@procs) = grep {-d} glob("$dir/{PROC.*,GRIDMAPS}"); # first list of procs from output directories
    $_ =~ s|$dir/|| for @procs; # keeps only the PROC.NAME part
    my @procreq = qx(grep -a "^PROC\." $dir/REQUEST.rc | sed -e "s/\.[^.]*|.*//"); # second list of procs from the request parameters
    chomp(@procreq);
    push(@procs,@procreq); # merging output directories and request parameters
    @procs = do { my %seen; grep { !$seen{$_}++ } @procs }; # uniq
    my $rowspan = scalar(@procs);
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
          ."<TD rowspan='$rowspan' align=center><A href='$WEBOBS{URN_OUTR}/$reqdir/REQUEST.rc'><IMG src='/icons/params.png'></A></TD>";
        for (@procs) {
            (my $proc = $_) =~ s/PROC\.//;
            if (WebObs::Users::clientHasRead(type=>"authprocs",name=>"$proc") || $_ eq "GRIDMAPS") {
                my $rreq = qx(sqlite3 $SCHED{SQL_DB_JOBS} "SELECT cmd,stdpath,rc FROM runs WHERE jid<0 AND cmd LIKE '%$reqdir%' AND cmd LIKE '%$proc%';");
                chomp($rreq);
                if ($rreq eq "") {
                    $table .= ("<TD></TD>" x 2);
                } else {
                    my ($rcmd,$rlog,$rc) = split(/\|/,$rreq);
                    my $log_filename = $rlog =~ s/^[><] +//r;
                    my $log_name = $log_filename =~ s|/$reqdir/||r;
                    $table .= "<TD align=center><A href='/cgi-bin/schedulerLogs.pl?log=$log_filename'>$log_name</a></TD>";
                    if ($rc eq "0") {
                        $table .= "<TD align=center bgcolor=green>OK</TD>";
                    } elsif ($rc > 0) {
                        $table .= "<TD align=center bgcolor=red>error</TD>";
                    } else {
                        $table .= "<TD align=center bgcolor=orange>wait...</TD>";
                    }
                }
                $table .= "<TD align=center>".(-d "$dir/$_" ? "<A href='/cgi-bin/showOUTR.pl?dir=$reqdir&grid=$_'><IMG src='/icons/visu.png'</A>":"")."</TD>";
                $table .= "<TD align=center>".(-e "$dir/$_.tgz" ? "<A download='$_' href='$WEBOBS{URN_OUTR}/$reqdir/$_.tgz'><img src='/icons/dwld.png'></A>":"")."</TD>";
            } else {
                $table .= "<TD colspan=4></TD>";
            }
            $table .= "</TR>\n<TR>";
        }
        $table .= "<TD colspan=9 style='background-color: #EEEEDD'></TD></TR>\n";
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

François Beauducel, Baptiste Camus

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
