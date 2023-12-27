package WebObs::Dates;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Dates
 
@daysoff = WebObs::Dates::readFeries(conf=>"daysoff-definition-file", 
                                     year=>2012);  

@calhtml = WebObs::Dates::Calendar(month=>'2012-12',
                                   ptri=>'Calendar',
								   today=>'2012-12-31');

$monday = WebObs::Dates::lundi('2012-09-14');

($minggu,$pasaran) = WebObs::Dates::Weton('2012-09-14');

=head1 DEFINITIONS

=head3 The days-off definition file

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use WebObs::Config;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use Data::Dumper;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use CGI::Cookie;

# Find out if Calendar() can use Date::Calc or has to use our own hack
our $HACK_DATE_CALC = 0 ;
eval { require Date::Calc; };
$HACK_DATE_CALC = 1 if (! $@) ; 

=pod

=head2 readFeries 

readFeries returns a list of dates corresponding to days off for the present
year or a specific year, based on the definitions of a configuration file.

@daysoff = readFeries(conf=>'path/to/daysoff.conf-file', year=>2000)

conf=> defaults to $WEBOBS{FILE_DAYSOFF}
year=> defaults to current year

Because some dates depend on Easter Sunday, the script uses "Date::Calc" Perl module
If it is not installed (ie. $HACK_DATE_CALC true), it computes the date with a simple formula.

=cut

sub readFeries
{
	my $s;

	my %KWARGS = @_;
	my $file = $KWARGS{conf} ? $KWARGS{conf} : $WEBOBS{FILE_DAYSOFF};
	my $year = $KWARGS{year} ? $KWARGS{year} : strftime('%Y',localtime());

	my @data = ("");
	my @feries = ("");

	# ---- Lecture du fichier de conf
	open(FILE, "<$file") || die "readFeries couldn't open $file\n";
	while(<FILE>) { push(@data,l2u($_)); }
	close(FILE);

	@data = grep(!/^(#|$)/, @data);

	my($pqy,$pqm,$pqd);
	if ($HACK_DATE_CALC) {
		eval { ($pqy,$pqm,$pqd)=Date::Calc::Easter_Sunday($year); };
	} else {
		my $H = (19*($year%19) + int($year/100) - int($year/400) - int((8*int($year/100) + 13)/25) + 15)%30;
		my $I = (int($H/28)*int(29/($H + 1)) * int((21 - $year%19)/11) - 1)*int($H/28) + $H;
		my $J = (int($year/4) + $year + $I + 2 + int($year/400) - int($year/100))%7;
		my $D = $I - $J;
		($pqy,$pqm,$pqd) = split(/\//,strftime('%Y/%m/%d',localtime(timelocal(0,0,0,28,2,$year-1900) + $D*86400))); # Easter Sunday
	}
	for (@data) {
		my ($dt,$dn) = split(/\|/,$_);
		chomp($dn);
		if ($dt =~ /^\$Y-/) {
			$dt =~ s/\$Y/$year/g;
			$s=$dt;
			# Easter Sunday (dimanche de Pâques)
		} elsif ($dt =~ /^\$PQ /) {
			$dt =~ s/\$PQ //g;
			if ($HACK_DATE_CALC) {
				eval { $s = sprintf("%04d-%02d-%02d",Date::Calc::Add_Delta_Days($pqy,$pqm,$pqd,$dt)); };
			} else {
				$s = strftime('%Y-%m-%d',localtime(timelocal(0,0,0,$pqd,$pqm-1,$pqy-1900) + $dt*86400));
			}
			# Nth weekday of the month (nième jour de la semaine dans le mois)
		} elsif ($dt =~ /^\$NWM /) {
			$dt =~ s/\$NWM //g;
			my ($mm,$dw,$nn) = split(/ /,$dt);
			if ($HACK_DATE_CALC) {
				eval { $s = sprintf("%04d-%02d-%02d",Date::Calc::Nth_Weekday_of_Month_Year($year,$mm,$dw,$nn)); };
			} else {
				$s = "";
			}
		}
		push(@feries,"$s|$dn");
	}
	return @feries;
}

=pod

=head2 Calendar

returns an array of html code to display a month calendar, handling daysoff (jours feries)

This function is closely related to WebOb's HEBDO.

eg. @calhtml = WebObs::Dates::Calendar(month=>'2012-12',ptri=>'Calendar',today=>'2012-12-31');

=cut

sub Calendar
{
	my @tod = localtime();
	my %HEBDO = readCfg("$WEBOBS{HEBDO_CONF}");
	my %KWARGS = @_;
	my $moisCalendrier = $KWARGS{month} ? $KWARGS{month} : strftime('%Y-%m',@tod);
	my $parametreTri   = $KWARGS{ptri}  ? $KWARGS{ptri}  : $HEBDO{DEFAULT_TRI};
	my $todayDate      = $KWARGS{today} ? $KWARGS{today} : strftime('%Y-%m-%d',@tod);
  	my (@contenu,$j,$s);
  
  	my $anneeCalendrier = substr($moisCalendrier,0,4);
	my @feries = readFeries(year=>$anneeCalendrier);
  	my $displayMoisCalendrier = l2u(qx(date -d "$moisCalendrier-01" +"\%B \%Y")); chomp($displayMoisCalendrier);
  	my $moisPrecedent = qx(date -d "$moisCalendrier-01 1 month ago" +"\%Y-\%m");
  	my $moisSuivant = qx(date -d "$moisCalendrier-01 1 month" +"\%Y-\%m");
  	my $lundiCalendrier = WebObs::Dates::lundi("$moisCalendrier-01");
  
  	push(@contenu,"<TABLE class=\"calendar\"><TR>
  	<TH><B><A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$moisPrecedent\">&lArr;</A></B></TH> 
  	<TH colspan=6><B><A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$moisCalendrier\">$displayMoisCalendrier</A></B></TH>
  	<TH><B><A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$moisSuivant\">&rArr;</A></B></TH>
  	</TR>\n<TR><TH></TH>");
  	push(@contenu,"<TH>".join("</TH><TH>",split(/,/,"$__{'hebdo_weekday_first_letter'}"))."</TH>");
  	# il faut balayer 6 semaines pour Ãªtre sÃ»r d'avoir le mois complet dans toutes les situations...
  	for (0..41) {
  		$j = qx(date -I -d "$lundiCalendrier $_ days"); chomp($j);
  		if (($_ % 7) == 0) {
  			if (($_ != 0) && (substr($j,5,2) ne substr($moisCalendrier,5,2))) {
  				last;
  			} else {
  				#$s = qx(date -d "$j" +"\%W"); chomp($s);
  				# permet de choisir le nÂ° semaine suivant l'annÃ©e du calendrier (derniÃ¨re semaine Y ou premiÃ¨re semaine Y+1)
  				if (substr($j,0,4) != $anneeCalendrier) { $s = qx(date -d "$j 6 days" +%V); }
  				else { $s = qx(date -d "$j" +%V); }
  				chomp($s);
  				#push(@contenu,"</TR>\n<TR><TH class=\"CalendarWeek\" onClick=\"window.location='$HEBDO{CGI_SHOW}?date=${anneeCalendrier}w$s'\">$s</TH>");
  				push(@contenu,"</TR>\n<TR><TH class=\"CalendarWeek\"><A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=${anneeCalendrier}W$s\">$s</A></TH>");
  			}
  		}
  		if (substr($j,5,2) ne substr($moisCalendrier,5,2)) {
  			$s = "class=\"CalendarOutMonth\"";
  		} else {
  			$s = "class=\"CalendarInMonth\"";
  			if (($_%7) >= 5) { $s = "class=\"CalendarWeekend\""; }
  			my @jf = grep(/$j/,@feries);
  			if (@jf and length($jf[0]) > 0) {
  				my ($dd,$ss) = split(/\|/,$jf[0]);
  				chomp($ss);
  				$ss =~ s/\'/&rsquo;/g;
  				$ss =~ s/\"/&quot;/g;
  				$s = "class=\"CalendarFerie\" onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{Holiday}: <b>$ss</b>')\"";
  			}
  		}
  		if ($j eq $todayDate) { $s = "class=\"CalendarToday\""; }
  		push(@contenu,"<TD $s onClick=\"window.location='$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$j'\">".sprintf("%1.0f",substr($j,8,2))."</TD>");
  	}
  	push(@contenu,"</TR></TABLE>");
  
  	return @contenu;
}

=pod

=head2 DCalendar

returns an array of html code to display a month calendar, handling daysoff.
Newer version of Calendar function.  

 @calhtml = WebObs::Dates::DCalendar(month=>"2012-12",url=>/cgi-bin/somecgi.pl?arg1="foo"&arg2="bar"');

 @calhtml = WebObs::Dates::DCalendar(url=>'/cgi-bin/showHEBDO.pl?tri="Calendar"');

=cut

sub DCalendar {
	my @tod     = localtime();
	my %KWARGS  = @_;
	my ($nowY, $nowM, $nowD) = split(/ /,strftime('%Y %m %d',@tod));
	my ($YY, $MM, $DD) = $KWARGS{month} ? split(/-/,"$KWARGS{month}-01") : ($nowY, $nowM, $nowD );
	my $url = $KWARGS{url} ? $KWARGS{url} : "";
	my @feries = readFeries(year=>$YY);
  	my (@html,$w);
  
  	my $DOW1  = qx(date -d "$YY-$MM-01" +'%u'); chomp($DOW1);
  	my $nextM = ($MM == 12) ?  1 : sprintf("%02d",$MM+1); my $nextY = $YY+1 ;
  	my $prevM = ($MM == 1)  ? 12 : sprintf("%02d",$MM-1); my $prevY = $YY-1 ;
	my $days  = qx(date -d "$nextY-$nextM-1 yesterday" +'%d'); chomp($days);
  	my $th1 = qx(date -d "$YY-$MM-01" '+%b %Y'); chomp($th1);
	my $th2 = qx(locale -k LC_TIME | awk 'BEGIN {FS=";"} /^abday=/ { for(i=2;i<=7;i++){ printf "%2.2s ",\$i}; printf "%2.2s",substr(\$1,8,2)}') ;
	chomp($th2);

	push(@html,"<table class=\"Dcalnd\"><tr class=\"t1\"><th><A href=\"$url&date=$prevY-$MM\">&laquo;</A>");
	push(@html,"<th><A href=\"$url&date=$YY-$prevM\">&lsaquo;</A><th colspan=4>$th1");
	push(@html,"<th><A href=\"$url&date=$YY-$nextM\">&rsaquo;</A><th><A href=\"$url&date=$nextY-$MM\">&raquo;</A></tr>\n");
	push(@html,"<tr class=\"t2\"><th><th colspan=7>$th2</tr>\n");
	
	$w = qx(date -d "$YY-$MM-01" +'%-V'); chomp($w);
	push(@html,sprintf("<tr><td class=\"week\"><A href=\"$url&date=${YY}W%02d\">%02d</A>",$w,$w));
	
	for (my $ix = 1; $ix <= $DOW1-1; $ix++) { push(@html,"<td>") }

	my $ixW = $DOW1; my $ixM = 1;
	while ( $ixM <= $days ) {
		my $class=""; my $hattr="";
		my $aDay = sprintf("$YY-$MM-%02s",$ixM);
		if ( $aDay eq "$nowY-$nowM-$nowD" ) { $class .= "today " }
		if (($ixW%8) >= 6) { $class .= "SD "; } 
		my @jf = grep(/$aDay/,@feries);
		if (@jf and length($jf[0]) > 0) {
			my ($dd,$ss) = split(/\|/,$jf[0]); chomp($ss);
			$ss =~ s/\'/&rsquo;/g; $ss =~ s/\"/&quot;/g;
			$class .= "off "; 
			$hattr = "onMouseOut=\"nd()\" onMouseOver=\"overlib('$__{Holiday}: <b>$ss</b>')\" ";
		}
		
		push(@html,sprintf("<td class=\"%s\" %s><A href=\"$url&date=${aDay}\">%2d</A>",$class,$hattr,$ixM)); 
		if ( ++$ixM <= $days ) {
			if ( $ixW >= 7 ) {
				$w = qx(date -d "$YY-$MM-$ixM" +'%-V'); chomp($w);
				push(@html,sprintf("\n<tr><td class=\"week\"><A href=\"$url&date=${YY}W%02d\">%02d  </A>",$w,$w));
				$ixW = 0;
			}
		}
		$ixW++;
	}
	for (my $ix = 1; $ix <= 8-$ixW; $ix++) { push(@html,"<td>") }
	push(@html,"</tr></table>");
	return @html;
}

#fixJul added ymdhms2s

=pod

=head2 ymdhms2s

ymdhms2s(from-date)

returns the number of seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC) from YYYY-MM-DD[HH:MM:SS] date string.
Any character is accepted as from-date delimiters, but these must be present.
HH:MM:SS is optional and defaults 00:00:00.
from-date is treated as local timestamp (ie. conversion is using Time::Local::localtime).
ymdhms returns -1 if from-date cannot be parsed.

eg. $secs = ymdhms2s('2012-09-15');  # $secs = 1347660000, equivalent to qx(date -d 2012-09-15 '+%s')

eg. $secs = WebObs::Dates::ymdhms2s('2012-09-15 10:25:02')  # secs = 1347697502

=cut

sub ymdhms2s 
{
	my($s) = @_;
	my($year, $month, $day, $hour, $minute, $second);

	if ($s =~ m{^\s*(\d{1,4})\W*0*(\d{1,2})\W*0*(\d{1,2})\W*0*(\d{0,2})\W*0*(\d{0,2})\W*0*(\d{0,2})}x) {
		$year = $1;  $month = $2;   $day = $3;
		$hour = $4;  $minute = $5;  $second = $6;
		$hour ||= 0;  $minute ||= 0;  $second ||= 0;   # default hms = 00:00:00
		$year = ($year<100 ? ($year<70 ? 2000+$year : 1900+$year) : $year);
		return timelocal($second,$minute,$hour,$day,$month-1,$year);  
	}
	return -1;
}

=pod

=head2 lundi

returns ISO date of the last monday before the given date YYYY-MM-DD (or YYYY/MM/DD)

eg. $monday = lundi('2012-09-14');  # $monday = 2012-09-10 

=cut

sub lundi
{
	my ($y,$m,$d) = split(/[-\/]/,shift);
	
	my $j = strftime('%w',0,0,0,$d,$m-1,$y-1900);
	$j = ($j+6)%7;
	my $lundi = strftime('%Y-%m-%d',localtime(timelocal(0,0,0,$d,$m-1,$y-1900) - $j*86400));
	chomp($lundi);
	
	return $lundi;
}

=pod

=head2 weton 

=cut

sub weton {
	my ($year,$month,$day) = split(/-/,shift);

	my @pasaran = ('Pon','Wagé','Kliwon','Legi','Pahing');
	my @minggu = ('Senèn','Selasa','Rebo','Kemis','Jemuwah','Setu','Akad');

	my $sec = strftime('%s',0,0,0,$day,$month-1,$year-1900) - strftime('%s',0,0,0,1,0,70);
	my $ndays = int($sec/86400) + 3500*35;
	my $p = ($ndays+1)%5;
	my $m = ($ndays+3)%7;
	
	#return l2u(sprintf("%s %s",$minggu[$m],$pasaran[$p]));
	return sprintf("%s %s",$minggu[$m],$pasaran[$p]);
}

1;

__END__

=pod

=head1 AUTHOR

François Beauducel, Didier Lafon  

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
