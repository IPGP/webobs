#!/usr/bin/perl

=head1 NAME

index.pl

=head1 SYNOPSIS


=head1 DESCRIPTION

WEBOBS site entry point and navigation control.

Initial WebObs page (home page), reading its config/customization
parameters in the file pointed to by $WEBOBS{FILE_MENU}, sets up:

1) the fixed navigation menu bar as defined/configured in $WEBOBS{FILE_MENU}->{NAVIGATION} file.
Two formats are supported: the legacy 'rc' format and the 'html' format. Index.pl
uses the {NAVIGATION} filename extension to determine which format to use ('.rc' and '.html' respectively).
Formats are described below.

2) misc 'decoration' fields in the menu bar: WebObs release number, http-client's login,
logos and their href.

3) the site's pages iframe div. This iframe is then initially loaded with
the $WEBOBS{FILE_MENU}->{WELCOME} page.

=head1 Query string parameters

 langue=
 optional, specifies which language to use

 page=
 optional, overides the default $WEBOBS{FILE_MENU} welcome page

=head1 NAVIGATION FILE .rc FORMAT

 see the default 'menunav.rc' file;
 each line defines one (1) menu item:  [+|!|*]menu-text|menu-link

 where: + :     top level menu (always shown); also indicates that
                following line(s) define(s) the dropdown item(s)
                associated to this level, until next '+' line

        ! :     same as + but item only made available to administrator(s)

        * :     same as omitting this first character, but item only made available
		        to administrator(s)

        menu-text : item's name as displayed

        menu-link : item's href uri

 Accepts $WEBOBS{...} variable substitutions

 # comment-lines (# in column 1) are allowed; blank lines are ignored

=head1 NAVIGATION FILE .html FORMAT

 see the default 'menunav.html' file;
 html tags <ul> and <li> describing the dropdown menu tree

 an '*' in column 1 indicates that the line is reserved for WebObs administrators

=cut

use strict;
use warnings;
use POSIX qw(getpid strftime);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Cookie;
use CGI qw/:standard/;
my $cgi = new CGI;

use WebObs::Config;
use WebObs::Utils;
use WebObs::Users;
use WebObs::i18n;
use WebObs::MathUtils;
use Locale::TextDomain('webobs');


# if the client is not a valid user, ends here !!
if (!WebObs::Users::clientIsValid(user=>$USERS{$CLIENT})) {
 	print $cgi->header(-type=>'text/html', -charset=>'utf-8');
	print "<H1>$WEBOBS{VERSION}</H1>"
	."Sorry, user '$USERS{$CLIENT}{LOGIN}' is not valid or is waiting for validation by an administrator...";
	exit(1);
}

# ---- reads in configuration options ------------------
my %MENU = readCfg("$WEBOBS{FILE_MENU}");
my $logout = "login: <B>$USERS{$CLIENT}{FULLNAME}</B>";
my $lo = "";
if ($MENU{CLEAR_AUTHENTICATION_CACHE} ne "") {
	$lo = CGI->new->url();
	$lo =~ s/:\/\//:\/\/$MENU{CLEAR_AUTHENTICATION_CACHE}@/;
	$logout = "<A href=\"#\" title=\"LogOut\" onClick=\"logout('$USERS{$CLIENT}{LOGIN}','$lo?logout')\">login: <B>$USERS{$CLIENT}{FULLNAME}</B></A>";
}

# ---- language cookie management -----------------------
#
my %cookies = fetch CGI::Cookie;
my $langue_cookie = exists($cookies{'langue_webobs'}) ? $cookies{'langue_webobs'}->value : "";
my $langue_utilisee = "";
my $langue_cgi = defined($cgi->param('langue'))?$cgi->param('langue'):"";

if ( $langue_cgi =~ /^[a-zA-Z][a-zA-Z]/ && -d "$WEBOBS{ROOT_I18N}/locales/".($langue_cgi)."/LC_MESSAGES" ) {
	$langue_utilisee = $langue_cgi;
} elsif ( $langue_cookie =~ /^[a-zA-Z][a-zA-Z]/ && -d "$WEBOBS{ROOT_I18N}/locales/".($langue_cookie)."/LC_MESSAGES" ) {
	$langue_utilisee = $langue_cookie;
} else {
	$langue_utilisee = $WEBOBS{LOCALE};
}
if ( $langue_cookie ne $langue_utilisee ) {
	my $cookie1 = new CGI::Cookie(-name=>'langue_webobs',-value=>$langue_utilisee);
	print $cgi->header(-cookie=>[$cookie1],-charset=>"utf-8",-type=>'text/html');
} else {
	print $cgi->header(-charset=>"utf-8",-type=>'text/html');
}
cherche_langue($langue_utilisee);

# ---- language flags management -------------------------
#
my %nom_langue;
my @liste_langues;
for my $code_desc (split(/\|/,$WEBOBS{"LANGUAGE_LIST"})) {
	my ($code,$desc) = split(/:/,$code_desc);
	push(@liste_langues,$code);
	$nom_langue{$code}=$desc;
}
my $drapeaux="";
for my $la (@liste_langues) {
	$drapeaux .= '<a href="/cgi-bin/index.pl?langue='.$la.'"><img alt="'.$nom_langue{$la}.'" title="'.$nom_langue{$la}.'" class="'.($langue_utilisee eq $la?"actif":"inactif").'" src="/icons/langue/'.$la.'.png"></a>';
}
$drapeaux =~ s/'/\\'/g;

# ---- logos and links in nav bar -------------------------
#
my @liste_logos = split(/;/,$MENU{"LOGO_IMAGES"});
my @liste_url   = split(/;/,$MENU{"LOGO_URLS"});
my @liste_title = split(/;/,$MENU{"LOGO_TITLES"});
my $logos="";
for my $i (0..$#liste_logos) {
i	$logos .= "<a href=\"$liste_url[$i]\"><img src=\"$liste_logos[$i]\" alt=\"$liste_title[$i]\" title=\"$liste_title[$i]\"></a>";
}
$logos =~ s/'/\\'/g;

# ---- is the http client an admin ?
#
my $admOK = (WebObs::Users::clientHasAdm(name=>'*',type=>'authmisc')) ? 1 : 0;

# ---- menu bar and its dropdown menus --------------------
#
my $wmcss = my $menuhtml = "";

# loads main menu (all users)
my $menunav = "$MENU{NAVIGATION}";
my @menu = readCfgFile($menunav,"utf8");

# adds optional additionnal menus for GROUPS
my @groups = WebObs::Users::userListGroup($CLIENT);
my $group;
for (@groups) {
	$group = $_;
	chomp $group;
	push(@menu,readCfgFile("$WEBOBS{ROOT_CONF}/MENUS/$group","utf8"));
}

# adds optional additionnal menu for USER
push(@menu,readCfgFile("$WEBOBS{ROOT_CONF}/MENUS/$USERS{$CLIENT}{UID}","utf8"));

# legacy format .rc
if ( $menunav =~ m/.rc$/) {
	my $l1 = my $l2 = 0;
	$menuhtml = "<ul class=\"haut inactif\">";
	for (@menu) {
		my ($titre,$lien)=split(/\|/,$_);
		$lien =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g ;
		my $xtrn = ($lien =~ m/http.?:\/\//) ? " externe ": "";
		if (substr($titre,0,1) eq "+" || (substr($titre,0,1) eq "!" && $admOK)) {
			if ($l2==1) { $menuhtml .= "</ul>"; $l2 = 0; }
			if ($l1==1) { $menuhtml .= "</li>"; }
			$l1 = 1;
			$menuhtml .= "<li class=\"haut inactif $xtrn\"><a href=".(defined($lien)?"$lien":"").">".substr($titre,1)."</a>\n";
			next;
		}
		if ( substr($titre,0,1) eq "*" ){
			next if (! $admOK);
			$titre = substr($titre,1);
		}
		if ($l2==0) { $menuhtml .= "<ul class=\"bas inactif\">"; $l2 = 1; }
		$menuhtml .= "<li class=\"bas inactif $xtrn\"><a href=".(defined($lien)?"$lien":"").">$titre</a></li>\n";
	}
	if ($l2==1) { $menuhtml .= "</ul>"; }
	if ($l1==1) { $menuhtml .= "</li>"; }
	$menuhtml .="</ul>";
	$wmcss="wm2.css";

# new format .html (CSS)
} else {
	@menu = grep { $_ !~ /^\*/ } @menu if (! $admOK);
	for(@menu) {
		s/^\*//;
		s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g ;
		my $xtrn = ($_ =~ m/http.?:\/\//) ? " class=\"externe\" ": "";
		s/<a/<a$xtrn/g;
	}
	unshift(@menu, "\n<ul class=\"dropdown\">");
	push(@menu,"</ul>");
	$menuhtml = join("\n",@menu);
	$wmcss="wm2n.css";
}
# ---- 'signature' that will show up at bottom
#
my $year = WebObs::MathUtils::num2roman(strftime("%Y", localtime));
my $signature = join(' ', readFile("$MENU{SIGNATURE}"));
$signature =~ s/\(c\)|©/© $year,/g;

# ---- the optinal querystring 'page=' parameter may override the default Welcome page
#
my $iframepage = defined($cgi->param('page'))?$cgi->param('page'):"$MENU{WELCOME}";

# ---- now display the page ! -----------------------------
#
print <<"FIN";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
	<head>
		<meta http-equiv="content-type" content="text/html; charset=utf-8">
		<title>$WEBOBS{WEBOBS_TITLE}</title>
		<meta name="description" content="WebObs $WEBOBS{WEBOBS_ID}">
		<meta name="keywords" content="">
		<meta name="revisit-after" content="1days">
		<meta name="robot" content="NoIndex,NoFollow">
		<link href="icons/ipgp/logo_WebObs_C16.ico" rel="shortcut icon">
		<link rel="stylesheet" type=text/css href="/$WEBOBS{FILE_HTML_CSS}">
		<link rel="stylesheet" type=text/css href="/css/$wmcss">
		<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
		<script language="javascript" type="text/javascript" src="/js/wm.js"></script>
	</head>
	<body>
    <script type="text/javascript">
    if ( window.self !== window.top ) {
        window.top.location.href=window.location.href;
    }
    </script>
FIN
print <<"FIN";
		<div id="wm">
			<div id="ident">
				<div id="wmlogos">$logos</div>
				<div id="i0">
					<span id="identVer"><B>&nbsp;[$ENV{SERVER_NAME}]&nbsp;$WEBOBS{VERSION}</B></span>
					<span id="identLog" style="text-align:right">$logout</span>
					<span id="wmflags">$drapeaux</span>
					<div style="clear: right"></div>
				</div>
				<div class="menu" id="wmwrapnav">$menuhtml</div>
			</div>
		</div>
FIN
print <<"FIN";
		<div style="clear: both"></div>
		<iframe name="wmtarget" id="wmtarget" src="$iframepage" width="100%" height="100%" frameborder=0>no iframe!!</iframe>
		<!--<iframe name="wmtarget" id="wmtarget" width="100%" height="100%" frameborder=0>no iframe!!</iframe>-->
		<hr/>
		<div id="wmsig">$signature</div>
		<noscript><div id="nojsMsg">$__{'WebObs pages require JavaScript enabled'}</div></noscript>
	</body>
</html>
FIN

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2018 - Institut de Physique du Globe Paris

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
