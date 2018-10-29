#!/usr/bin/perl
use strict;
use FindBin;
use lib $FindBin::Bin; 
use Data::Dumper;
use Term::ReadLine;
#use POSIX;
use POSIX qw/strftime locale_h/;
#use CGI;

my $WOPTR = '/etc/webobs.d';
exit if(! -l $WOPTR);
my $WOLNK = qx(ls -l $WOPTR); chomp($WOLNK);
$WOLNK=~s/^.* (.* -> .*)$/$1/;

use WebObs::Config;
use WebObs::Users;

# Get system/environment information -------------------------------------------
# ------------------------------------------------------------------------------
my	@WOUSR  = getpwuid ($<); #($name, $passwd, $uid, $gid, $quota, $comment, $gcos, $dir, $shell)
my 	@localeIns  = qx(locale -a); chomp(@localeIns);
my 	$localeAll  = setlocale(LC_ALL);
my 	$localeNum  = setlocale(LC_NUMERIC);
my 	@i18nSup = qx(ls $WEBOBS{ROOT_I18N}/locales); chomp(@i18nSup);
my  $WOSYS  = qx(uname -osrv);
	$WOSYS .= "\"WebObs-$WEBOBS{WEBOBS_ID}\" $WEBOBS{VERSION} [$WOLNK]\n";
	$WOSYS .= "wsys pid $$ started $^T by $WOUSR[0] ($</$>) in ".qx(pwd)."\n";
    $WOSYS .= "Perl \$^V = $^V \n";
	$WOSYS .= "\$POSIX::VERSION = ".qq($POSIX::VERSION)."\n";
	$WOSYS .= "\$ENV{PATH} = $ENV{PATH}\n";
	$WOSYS .= "\@INC : ".join(":",@INC)."\n";
	$WOSYS .= "\n";
	$WOSYS .= "\$ENV{TZ} " . (defined($ENV{TZ}) ? "= $ENV{TZ}\n" : "undef\n");
	$WOSYS .= "POSIX::tzname = ".join(' ',POSIX::tzname())."\n";
	$WOSYS .= "/etc/localtime -> ".qx(tail -1 /etc/localtime); my $tnow = time;
	$WOSYS .= "qx(date) : ".qx(date +'%Y-%m-%d %H:%M:%S %Z (%z) %s');
	$WOSYS .= "localtime: ".strftime("%Y-%m-%d %H:%M:%S %Z (%z) %s ",localtime($tnow))."($tnow)\n";
	$WOSYS .= "gmtime   : ".strftime("%Y-%m-%d %H:%M:%S %s ",gmtime($tnow))."\n";
	$WOSYS .= "\n";
	$WOSYS .= "i18n Available/Installed: "; map {$WOSYS .= (grep /\Q$_/ , @localeIns) ? "$_ = S/I; " : "$_ = S/?; "} @i18nSup ; $WOSYS .= "\n";
	$WOSYS .= "%ENV      LC_ALL:".(defined($ENV{LC_ALL}) ? "$ENV{LC_ALL}; " : "undef; "); 
	$WOSYS .= "LANGUAGE:".(defined($ENV{LANGUAGE}) ? "$ENV{LANGUAGE}; " : "undef; "); 
	$WOSYS .= "LC_NUMERIC:".(defined($ENV{LC_NUMERIC}) ? "$ENV{LC_NUMERIC}; " : "undef; "); 
	$WOSYS .= "LC_MONETARY:".(defined($ENV{LC_MONETARY}) ? "$ENV{LC_MONETARY}; " : "undef; "); 
	$WOSYS .= "LANG:".(defined($ENV{LANG}) ? "$ENV{LANG}; " : "undef; "); 
	$WOSYS .= "\n";
	$WOSYS .= "setlocale LC_ALL:$localeAll"; $WOSYS .= ", LC_NUMERIC:$localeNum" unless ( $localeAll =~ /\QLC_NUMERIC/); $WOSYS .= "\n";
	$WOSYS .= "\n";
	$WOSYS .= sprintf("sprintf 1/10 + 1.5 = %g\n",1/10+1.5);
	use locale; $WOSYS .= sprintf("use locale; sprintf 1/10 + 1.5 = %g\n",1/10+1.5); no locale;
	my $old = setlocale(LC_NUMERIC,""); $WOSYS .= sprintf("setlocale(LC_NUMERIC,\"\"); sprintf 1/10 + 1.5 = %g\n",1/10+1.5); setlocale(LC_NUMERIC,$old);
	   $old = setlocale(LC_NUMERIC,""); use locale; $WOSYS .= sprintf("setlocale(LC_NUMERIC,\"\");use locale; sprintf 1/10 + 1.5 = %g\n",1/10+1.5); no locale; setlocale(LC_NUMERIC,$old);
	   $old = setlocale(LC_NUMERIC,"C"); $WOSYS .= sprintf("setlocale(LC_NUMERIC,\"C\"); sprintf 1/10 + 1.5 = %g\n",1/10+1.5); setlocale(LC_NUMERIC,$old);
	   $old = setlocale(LC_NUMERIC,"C"); use locale; $WOSYS .= sprintf("setlocale(LC_NUMERIC,\"C\");use locale; sprintf 1/10 + 1.5 = %g\n",1/10+1.5);no locale; setlocale(LC_NUMERIC,$old);

	if (defined $ENV{GATEWAY_INTERFACE}) {
		$WOSYS .= "\n";
		$WOSYS .= "REQUEST_URI: $ENV{REQUEST_URI}\n";
		$WOSYS .= "HTTP Server = $ENV{SERVER_NAME} [$ENV{SERVER_ADDR}:$ENV{SERVER_PORT}]\n";
		$WOSYS .= "     CGI = $ENV{GATEWAY_INTERFACE}\n";
		$WOSYS .= "     $ENV{SERVER_PROTOCOL} - $ENV{SERVER_SOFTWARE}\n";
		$WOSYS .= "HTTP User = $ENV{REMOTE_USER} - $ENV{REMOTE_HOST} [$ENV{REMOTE_ADDR}:$ENV{REMOTE_PORT}]\n";
		$WOSYS .= "     AuthType  = $ENV{AUTH_TYPE}\n";
		$WOSYS .= "     UserAgent = $ENV{HTTP_USER_AGENT}\n";
		$WOSYS .= "WEBOBS User = $CLIENT";
		use CGI;
		my $cgi = new CGI;
		$WOSYS =~ s/\n/<br>/g; $WOSYS =~ s/\s/&nbsp;/g; 
		print $cgi->header(-type=>'text/html',-charset=>'utf-8');
		print "<DIV style=\"font-family: monospace; color: white; background-color: black\">$WOSYS</DIV>";
		exit;
	}

print "\033[2J\033[0;0H"; #clear the screen & jump to 0,0
print $WOSYS;

