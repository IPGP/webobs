#!/usr/bin/perl

=head1 NAME

mseedreq.pl

=head1 SYNOPSIS

http://..../mseedreq.pl?... see query string parameters below ...

=head1 DESCRIPTION

Makes a request to SeedLink or ArcLink server to get miniseed data file. 
mseedreq.pl will decide to address SeedLink or ArcLink server depending on 
current time and $WEBOBS{ARCLINK_DELAY_HOURS} value.

Other server's parameters are taken from WEBOBS and SEFRAN3 configuration files.

=head1 Query string parameters

 s3=
  sefran3 configuration file; Defaults to $WEBOBS{ROOT_CONF}/$WEBOBS{SEFRAN3_DEFAULT_NAME}.conf

 streams=NET1.STA1.LOC1.CHA1,NET2.STA2.LOC2.CHA2[,...]
  specifies streams list; any missing information will be replaced by wildcards. 
  e.g.: streams=PF.RER,PF.BOR..EHZ
        streams=PF
 defaults to using SEFRAN3 defined channels

 all={0,1,2}
  0 or Default: request only specified streams
  1: request all existing channels of stations in streams
  2: request all existing channels in the data servers

 t1=yyyy,mm,dd,HH,MM,SS
  start date and time

 t2=yyyy,mm,dd,HH,MM,SS
  end date and time   
	
 ds=duration
  signal duration in seconds, in place of t2=

 NOTE: SS must be an integer value.

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use File::Temp qw(tempfile);
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use POSIX qw/strftime/;
use Switch;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::i18n;
use WebObs::IGN;
use Locale::TextDomain('webobs');

# ---- inits ----------------------------------
my $tmpdir = $WEBOBS{MSEEDREQ_TMP_DIR};
my $template = $WEBOBS{MSEEDREQ_TEMPLATE};
my $reqtemplate = 'request_XXXXX';
my $method;
my $host;

# ---- get query-string  parameters
my $s3  = $cgi->url_param('s3');
my $S   = $cgi->url_param('streams');
my $t1  = $cgi->url_param('t1');
my $t2  = $cgi->url_param('t2');
my $ds  = $cgi->url_param('ds');
my $all = $cgi->url_param('all');

# ---- loads requested Sefran3 configuration or default one
$s3 ||= $WEBOBS{SEFRAN3_DEFAULT_NAME};
my $s3conf = "$WEBOBS{ROOT_CONF}/$s3.conf";
my %SEFRAN3 = readCfg("$s3conf") if (-f "$s3conf");

# ---- data source parameters (or former variables by default)
my $alsrv = $SEFRAN3{ARCLINK_SERVER};
my $slsrv =  $SEFRAN3{SEEDLINK_SERVER};
my $delay = $SEFRAN3{ARCLINK_DELAY_HOURS};
my $aluser = $SEFRAN3{ARCLINK_USER};
my @datasrc = split(/;/,$SEFRAN3{DATASOURCE});
my $sltos = $SEFRAN3{SEEDLINK_SERVER_TIMEOUT_SECONDS};
my $slprgm = "$WEBOBS{PRGM_ALARM} ".($sltos > 0 ? $sltos:"5")." $WEBOBS{SLINKTOOL_PRGM}";

# ---- calculates time limit to choose which protocol to use
$delay = $datasrc[2] if ($#datasrc eq 2);
$delay = 0 if ($delay eq "" || $delay < 0);
my $limit = qx(date -u -d "$delay hour ago" +"\%Y,\%m,\%d,\%H,\%M,\%S" | xargs echo -n);
if ($limit lt $t1) {
	$method = 'SeedLink';
	if ($#datasrc eq 2) {
		if ($datasrc[0] =~ /^slink:/) {
			($slsrv = $datasrc[0]) =~ s/slink:\/\///g;
		}
		if ($datasrc[0] =~ /^arclink:/) {
			my @prot = split(/\?user=/,$datasrc[0]);
			($alsrv = $prot[0]) =~ s/arclink:\/\///g;
			if ($#prot > 0) {
				$aluser = $prot[1];
			}
			$method = 'ArcLink';
		}
	}
} else {
	$method = 'ArcLink';
	if ($#datasrc eq 2) {
		if ($datasrc[1] =~ /^arclink:/) {
			my @prot = split(/\?user=/,$datasrc[1]);
			($alsrv = $prot[0]) =~ s/arclink:\/\///g;
			if ($#prot > 0) {
				$aluser = $prot[1];
			}
		}
		if ($datasrc[1] =~ /^slink:/) {
			($slsrv = $datasrc[1]) =~ s/slink:\/\///g;
			$method = 'SeedLink';
		}
	}
}


# ---- decodes date and time
my ($y1,$m1,$d1,$h1,$n1,$s1) = split(/,/,$t1);

if (!$t2 && $ds > 0) {
	$t2 = qx(date -d "$y1-$m1-$d1 $h1:$n1:$s1 $ds second" +"\%Y,\%m,\%d,\%H,\%M,\%S" | xargs echo -n);
}
my ($y2,$m2,$d2,$h2,$n2,$s2) = split(/,/,$t2);

# ---- miniseed filename
my $datafile = "$y1$m1$d1$h1$n1$s1-$y2$m2$d2$h2$n2$s2";
my ($fh, $tmpfile) = tempfile($template, DIR => $tmpdir);

# ---- stream list
my @stream_list;
if ($S) {
	@stream_list = split(/,/,$S);
} else {
	my @channels = readCfgFile("$SEFRAN3{CHANNEL_CONF}");
	for (@channels) {
		my ($ali,$cod) = split(/\s+/,$_);
		push(@stream_list,$cod);
	}
}

# ---- decides which method to use
if ($method eq "SeedLink") {
	# SeedLink request
	$host = $slsrv;
	my $Q = qx($WEBOBS{SLINKTOOL_PRGM} -Q $host);
	my @stream_server = split(/\n/,$Q);
	my @streams;

	# all=2 : gets all available channels
	if ($all == 2) {
		@stream_list = ();
		for (@stream_server) {
			push(@stream_list,trim(substr($_,0,2)).".".trim(substr($_,3,5)).".".trim(substr($_,9,2)).".".substr($_,12,3));
		}
	}

	my $date1 = sprintf("%d/%02d/%02d %02d:%02d:%02.0f",$y1,$m1,$d1,$h1,$n1,$s1);
	my $date2 = sprintf("%d/%02d/%02d %02d:%02d:%02.0f",$y2,$m2,$d2,$h2,$n2,$s2);

	for (@stream_list) {
		my ($net,$sta,$loc,$cha) = split(/[\.:]/,$_);
		my @chan = grep(/$net *$sta *$loc *$cha/,@stream_server);

		if (@chan) {
			my $start = substr($chan[0],18,24);
			my $end = substr($chan[0],47,24);
			if ($start le $date1 && $end ge $date2) {
				if ($all) {
					$loc = "";
					$cha = "";
				}
				push(@streams,"$net\_$sta".($loc || $cha ? ":":"")."$loc$cha");
			}
		}
	}
	my $command = "$slprgm -S \"".join(',',@streams)."\" -tw $t1:$t2 -o $tmpfile $host";
	if (@streams) {
		qx($command);
	}
	$datafile .= "_$s3";

} else {
	# ArcLink request
	$host = $alsrv;
	$aluser = "wo" if ($aluser eq "");
	my ($fh, $reqfile) = tempfile($reqtemplate, DIR => $tmpdir);
	my @streams;

	# all=2 : gets all available channels
	if ($all == 2) {
		@streams = ("$t1 $t2 * * * *\n");
	} else {
		for (@stream_list) {
			my ($net,$sta,$loc,$cha) = split(/\./,$_);
			push(@streams,"$t1 $t2 ".($net ? $net:"*")." ".($sta ? $sta:"*")." ".($all==1 ? " * *":" $cha $loc")."\n");
		}
	}

	open(FILE, ">$reqfile") || die "$__{'Could not open'} $reqfile \n";
	print FILE @streams;
	close(FILE);

	my $command = "$WEBOBS{ARCLINKFETCH_PRGM} -u $aluser -a $alsrv -o $tmpfile $reqfile";
	qx($command);
	qx(rm -f $reqfile);
	$datafile .= '_arclink';

}

# ---- now format/display $tmpfile
#
my $size = -s "$tmpfile";
if (-f "$tmpfile" && $size > 0) {
	open(my $DLFILE, '<', "$tmpfile") || die "$__{'Could not open'}  $tmpfile \n";

	print "Content-Type:application/vnd.fdsn.mseed; name=\"$tmpfile\"\n";
	print "Content-Disposition: inline; filename=\"$datafile.$WEBOBS{MSEED_FILE_EXT}\"\n";
	print "Content-length: $size\n\n";

	binmode $DLFILE;
	print while <$DLFILE>;
	undef ($DLFILE);
} else {
	print $cgi->header(-charset=>'utf-8'),
		$cgi->start_html('WEBOBS'),
		$cgi->h3($__{'miniSEED file error'}),
		$cgi->p($__{'Sorry, there is no more data available for this request:'}),
		$cgi->ul(
			$cgi->li("Sefran3: <b>$s3</b>"),
			$cgi->li("Method: <b>$method</b>"),
			$cgi->li("Server: <b>$host</b>"),
			$cgi->li("Start time: <b>$t1</b>"),
			$cgi->li("Duration: <b>$ds s</b>"),
			$cgi->li("Streams: <b></b>")
		),
		$cgi->button(-name=>'Back to form',-onClick=>'history.back()'),
		$cgi->end_html();
}

# ---------------------------------------------
sub trim
{
    my $c = shift;
    $c =~ s/^\s+//;
    $c =~ s/\s+$//;
    return $c;
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2019 - Institut de Physique du Globe Paris

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

