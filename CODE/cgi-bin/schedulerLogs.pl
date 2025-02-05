#!/usr/bin/perl

=head1 NAME

schedulerLogs.pl 

=head1 SYNOPSIS

url:  .../cgi-bin/schedulerLogs.pl?log=

=head1 DESCRIPTION

displays a job's log identified by its full filename passed via the 'log=' argument of query-string, 
OR the scheduler's log itself if log=SCHED or log is not specified. 

=cut

use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw/strftime/;
use Locale::TextDomain('webobs');
use WebObs::i18n;
use WebObs::Config;
use WebObs::Users qw(clientIsValid);

my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

set_message(\&webobs_cgi_msg);
my $QryParm = $cgi->Vars;

# --- ends here if the client is not valid
if ( !clientIsValid ) {
    die "$__{'die_client_not_valid'}";
}

my %SCHED;
my $logname;

# ---- what's the 'system' scheduler log ?
$QryParm->{'scheduler'} ||= 'scheduler';
my $schedLog  = $QryParm->{'scheduler'}.".log";

# ---- any reasons why we couldn't go on ?
# ----------------------------------------
if (defined($WEBOBS{ROOT_LOGS})) {
    if ( -f "$WEBOBS{ROOT_LOGS}/$schedLog" ) {
        if (defined($WEBOBS{CONF_SCHEDULER}) && -e $WEBOBS{CONF_SCHEDULER} ) {
            %SCHED = readCfg($WEBOBS{CONF_SCHEDULER});
        } else { die "Couldn't find scheduler configuration" }
    } else { die "Couldn't find log $WEBOBS{ROOT_LOGS}/$schedLog" }
} else { die "No ROOT_LOGS defined" }

# ---- which log to display, defaulting to 'system' scheduler's log
$QryParm->{'log'}       ||= "SCHED";
$logname = "$SCHED{PATH_STD}/$QryParm->{'log'}";
$logname = "$WEBOBS{ROOT_LOGS}/$schedLog" if ( $QryParm->{'log'} eq "SCHED" );

# ---- show the log 
my @results=qx(bash -c "cat $logname");
foreach (@results) {
    s/\n/<br>/g;
    s/\s/&nbsp;/g;
}

print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print <<"EOHEADER";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Scheduler Logs</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/schedulerLogs.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript">
	\$(document).ready(function() {
		\$('#wrapper').scrollTop(\$('#wrapper')[0].scrollHeight);
	});
</script>
</head>
EOHEADER

my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));
print <<"EOPAGE";
<body style="min-height: 600px;">
<DIV id="logname">
$logname - $buildTS
<IMG src="/icons/refresh.png" style="vertical-align:middle" title="Refresh" onClick="document.location.reload(false)">
<INPUT class="butfloat" type=button value="Exit" onClick="history.go(-1);">
<!-- <INPUT class="butfloat" type=button value="Scheduler Log" onClick="location.href='/cgi-bin/schedulerLogs.pl?log=SCHED';">-->
</DIV>
<DIV id="wrapper">
	@results
</DIV>
EOPAGE

exit;

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon

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

