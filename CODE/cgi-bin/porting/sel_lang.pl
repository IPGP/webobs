#!/usr/bin/perl
# Auteur:	Alexis Bosson
# Fonction:	Définition de la langue
# Créé le:	ven 25 mai 2007 15:45:30 AST
# <25 mai 2007 15:45:30 Alexis Bosson>

use CGI qw/:standard/;
use CGI::Cookie;
my $cgi = new CGI;
use i18n;
use POSIX qw(getpid :locale_h);

my $langue_cgi = $cgi->param('langue');
my %cookies = fetch CGI::Cookie;
my $langue_cookie = exists($cookies{'langue_webobs'}) ? $cookies{'langue_webobs'}->value : "";
if ( $langue_cookie ne $langue_cgi ) {
	$cookie1 = new CGI::Cookie(-name=>'langue_webobs',-value=>$langue_cgi);
	print header(-cookie=>[$cookie1],-type=>"text/html;charset=utf-8");
} else {
	print header(-cookie=>[$cookie1],-type=>"text/html;charset=utf-8");
}
cherche_langue($langue_cgi);
print $cgi->start_html(__("Language selection")), $cgi->h1(__('Language selection'));
aff_langues();
print p(__('The current language is NAME_OF_GETTEXT_LANGUAGE. Please select your preferred language:'));

print ul(
	{ style => "border: 3px dotted gray" },
	li(a({href=>"sel_lang.pl?langue=fr_FR"},"Français fr_FR")),
	li(a({href=>"sel_lang.pl?langue=en_US"},"English US")),
);
print ul(
	{ style => "color: gray" },
	li(a({href=>"sel_lang.pl?langue=fr"},"Français fr")),
	li(a({href=>"sel_lang.pl?langue=fr_CA"},"Français fr_CA")),
	li(a({href=>"sel_lang.pl?langue=en"},"English")),
	li(a({href=>"sel_lang.pl?langue=en_GB"},"English GB")),
	li(a({href=>"sel_lang.pl?langue=nl"},"Néerlandais")),
	li(a({href=>"sel_lang.pl?langue=de"},"Allemand")),
	li(a({href=>"sel_lang.pl?langue=zh_CN"},"Chinois cantonais")),
	li(a({href=>"sel_lang.pl?langue=vi"},"Vietnamien")),
	li(a({href=>"sel_lang.pl?langue=uk"},"Ukrainien"))
);


# cherche_langue($langue_cgi);
print div(
	{ style => "border: 3px dotted gray" },
	p($__{"Hello, world!"}),
	p(__x("This program is running as process number {pid}.", pid => getpid()))
);

# vi:enc=utf-8:
