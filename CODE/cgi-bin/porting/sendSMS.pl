#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------------- WEBOBS -----------------------------------
# Script: sensSMS.pl
# Purpose: send SMS messages
#
# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use Time::Local;
use File::Basename;
use CGI qw/:standard/;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);

use Webobs;
use readConf;

my %WEBOBS = readConfFile;

my $titrePage = $__{'Send SMS messages'};

my $user = "Unknown";
if (defined(url_param('mvouser'))) {
	$user = "MVO/".url_param('mvouser');
} elsif (defined(param('user'))) {
	$user = param('user');
} else {
	die("User isn't defined");
# 	$user = "MVO/Director";
}
use CGI qw/:standard/;
my %labels = (
			'collapse'=>'Collapse (partial or major)',
			'ash'=>'Ash plume',
			'other'=>'Other (no template)',
			'test'=>'Test of this system'
		);
# my %texts = (
# 			'collapse'=>'A [partial/major] collapse occured at [HH:MM] UTC directed to [SE/SW]',
# 			'ash'=>'An ash plume raising to [7000m] has been observed at [HH:MM] UTC directed to [SE/SW]',
# 			'other'=>'Please select a template above or type free text',
# 			'test'=>'TEST TEST TEST This is a TEST TEST TEST'
# 		);
my $JSCRIPT=<<END;
texts = new Array();
texts['collapse']='A [partial/major] collapse occured at [HH:MM] UTC directed to [SE/SW]';
texts['ash']='An ash plume raising to [7000m] has been observed at [HH:MM] UTC directed to [SE/SW]';
texts['other']='Free text message';
texts['test']='TEST TEST TEST of the MVO->OVSG warning system.';
function apply_template(sel) {
	document.forms[0].message.value=texts[sel.value];
}
END

print header(-charset=>"utf-8"), start_html(-title=>$titrePage,-style=>"/pub/sms.css",-script=>$JSCRIPT), h1($titrePage);
if (request_method() eq 'POST') {
	my $message = param('message')."\n".$user;
# 	print Dump(),p,
# 	"Your name is ",em(param('user')),p,
# 	"The types are: ",em(join(", ",param('type'))),p,
	print qx($WEBOBS{RACINE_TOOLS_SHELLS}/alerte_sms_webobs "$message");
	print h2("Message sent"),
	p,
	"Your message :",pre($message),
	p,
	"was sent to the following phone numbers : $WEBOBS{SMS_LISTE_TELEPHONES}";
} else {
	print start_form,
# p($__{'Sending user'},$user),
	hidden('user',$user),
	p("From : $user"),
	p($__{'Message template'},
		popup_menu(
			-name=>'type',
			-values=>[
			'other',
			'collapse',
			'ash',
			'test'
			],
			-labels=> \%labels,
			-onChange=>'apply_template(this)'
		)
	),
	p($__{'SMS Message'}, textarea('message',"Please select a template above or enter free text",4,40)),
	submit,
	end_form;
}

print end_html;
