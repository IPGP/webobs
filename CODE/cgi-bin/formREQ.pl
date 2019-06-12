#!/usr/bin/perl 
#
=head1 NAME

formREQ.pl 

=head1 SYNOPSIS

http://..../formREQ.pl

=head1 DESCRIPTION

Builds/Manages the input html-form for 'B<Request for Graphs>' and processes it with postREQ.pl.
A B<Request for Graphs> is the execution of one or more PROC's routine(s), sharing the same set of
B<Date-span and Parameters>.  

Available PROCS routines are those defined by a non-blank SUBMIT_COMMAND parameter PROCS' configuration files
(ie. CONF/PROC/PROCname/PROCName.conf files). 

Date-span and Parameters (that will eventually be written to a REQUEST.rc file by postREQ.pl)
are presented to the user with default values taken from a B<template>: $WEBOBS{ROOT_CODE}/tplates/request-template .  

A submitted B<Request for Graphs> will have all of its results (outputs) files grouped into the
OUTR directory, under a subdirectory whose name uniquely identifies the Request: 

	OUTR/YYYYMMDD_HHMMSS_HOSTNAME_UID
		REQUEST.rc  
		PROC.PROCa/
			{exports,graphs,maps,logs}/
		....
		PROC.PROCz/
			{exports,graphs,maps,logs}/

See postREQ.pl documentation for further Request's execution/parameters description.

=head1 RELATED PROC CONFIGURATION PARAMETERS

PROC's configuration parameters related to B<Request for Graphs> are 1) those prefixed with B<SUBMIT_'> and 
2) the unique B<REQUEST_KEYLIST>

B<SUBMIT_COMMAND> is the routine execution command line, ie. equivalent to the value of a XEQ1:
keyword in a scheduler's job-definition-string (see scheduler.pl doc) and, as such,
supporting $WEBOBS parametres substitution.

B<SUBMIT_RESOURCE> is the optional routine execution mutex name (process lock).

	Example: 
	SUBMIT_COMMAND|$WEBOBS{JOB_MCC} superproc $SELFREF -
	SUBMIT_RESOURCE|proc1

B<REQUEST_KEYLIST> is used to specify a list of comma-separated keys of existing parameters, that will be
presented to the user so that (s)he will have a chance to overwrite corresponding values for request execution.
Such parameters will be appended to the REQUEST.rc file as 'PROC.procname.originalKey|user's value'

	Example:
	PARAM1|10
	PARAM2|200
	REQUEST_KEYLIST|PARAM1,PARAM2
	will eventually appear in REQUEST.rc as:
	PROC.THISPROC.PARAM1|11       (user's input 11)
	PROC.THISPROC.PARAM2|200      (user's didn't overwrite value)

=head1 DATE SPAN AND PARAMETERS 

Date span:

	A start date 
	An end date

Parameters:

	TZ
	DATESTR
	PPI
	MARKERSIZE
	LINEWIDTH
	PLOTGRID
	CUMULATE
	DECIMATE
	PDFOUTPUT
	POSTSCRIPT
	EXPORTS

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
my @tod = localtime();
my $QryParm   = $cgi->Vars;

my %SCHED;
my @procavailable;
my @proclist;
my %P;

# ---- Things to populate select dropdown fields 
my $year = strftime('%Y',@tod);
my @yearList = reverse($WEBOBS{BIG_BANG}..$year+1);
my @monthList = ('01'..'12');
my @dayList = ('01'..'31');
my @hourList = ('00'..'23');
my @minuteList = ('00'..'59');

# ---- dates
#      default to full previous month
my @tm = gmtime(time); 
$tm[3] = 1;
my ($usrYearE,$usrMonthE,$usrDayE) = split(/-/,strftime("%Y-%m-%d",@tm));
if ($tm[4]==0) { $tm[5]--; $tm[4] = 11;} else { $tm[4]--; }
my ($usrYearS,$usrMonthS,$usrDayS) = split(/-/,strftime("%Y-%m-%d",@tm));

map (push(@procavailable,basename($_,".conf")), qx(grep -l '^SUBMIT_COMMAND|.*' $WEBOBS{PATH_PROCS}/*/*.conf ));
chomp(@procavailable);
if (scalar(@procavailable)>0) {
	foreach (@procavailable) {
		push(@proclist,$_) if (WebObs::Users::clientHasRead(type=>"authprocs",name=>"$_"));
	}
} else { die "$__{'No PROCS eligible for requests submission.'}" }

if (scalar(@proclist)==0) { die "$__{'No PROC eligible for this user. Please ask an administrator.'}" }

# ---- read in default values for initializing
# ---- form fields used for request.rc creation
my %REQDFLT;
my $reqdflt = "$WEBOBS{ROOT_CODE}/tplates/request-template";
if (-e $reqdflt ) {
	%REQDFLT = readCfg($reqdflt)
}

# ---- passed all checkings above ...
# ---- build/process the form HTML page
#
my $pagetitle = "$__{'PROC Request'}";

print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<TITLE>$pagetitle</TITLE>
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<script type=\"text/javascript\">

function selProc(proc) {
	obj = \"#pkeysdrawer\"+proc;
	//toggle to show/hide; prop(disabled) to (not)serialize in post
	//all inputs of a proc must start as  display:none AND disabled
	\$(obj).toggle();
	\$(obj).find('input').each( function(){ \$(this).prop('disabled',!\$(this).prop('disabled')) });
}

function checkForm()
{
	var d1 = document.formulaire.startY.value.concat(document.formulaire.startM.value,document.formulaire.startD.value,document.formulaire.startH.value,document.formulaire.startN.value);
	var d2 = document.formulaire.endY.value.concat(document.formulaire.endM.value,document.formulaire.endD.value,document.formulaire.endH.value,document.formulaire.endN.value);
	if (d1 >= d2) {
		alert(\"End date must not be before Start date!\");
		return false;
	}
	var checkboxes = document.formulaire.querySelectorAll(\"input[type=checkbox]\");
	var requestprocs = 0;
	for (index = 0; index < checkboxes.length; ++index) {
		if (checkboxes[index].name.substring(0, 2) == \"p_\" && checkboxes[index].checked) {
			requestprocs++;
		}
	}
	if (requestprocs == 0) {
		alert(\"You must select at least one PROC to execute...\");
	} else {
		postIt();
	}
}
function postIt()
{
	\$.post(\"/cgi-bin/postREQ.pl\", \$(\"#theform\").serialize(), function(data) {
		alert(data);
	});
}
function preSet()
{
	var now = new Date;
	if (document.formulaire.preset.value == \"fullmonth\") {
		document.formulaire.endY.value = now.getUTCFullYear();
		document.formulaire.endM.value = ('0' + (now.getUTCMonth() + 1)).substr(-2);
		document.formulaire.endD.value = \"01\";
		document.formulaire.endH.value = \"00\";
		document.formulaire.endN.value = \"00\";
		document.formulaire.startY.value = now.getUTCFullYear();
		if (now.getUTCMonth() > 0) {
			document.formulaire.startM.value = ('0' + now.getUTCMonth()).substr(-2);
		} else {
			document.formulaire.startY.value -= 1;
			document.formulaire.startM.value = \"12\";
		}
		document.formulaire.startD.value = \"01\";
		document.formulaire.startH.value = \"00\";
		document.formulaire.startN.value = \"00\";
	}
	if (document.formulaire.preset.value == \"fullyear\") {
		document.formulaire.startY.value = now.getUTCFullYear() - 1;
		document.formulaire.startM.value = \"01\";
		document.formulaire.startD.value = \"01\";
		document.formulaire.startH.value = \"00\";
		document.formulaire.startN.value = \"00\";
		document.formulaire.endY.value = now.getUTCFullYear();
		document.formulaire.endM.value = \"01\";
		document.formulaire.endD.value = \"01\";
		document.formulaire.endH.value = \"00\";
		document.formulaire.endN.value = \"00\";
	}
	if (document.formulaire.preset.value == \"currentyear\") {
		document.formulaire.startY.value = now.getUTCFullYear();
		document.formulaire.startM.value = \"01\";
		document.formulaire.startD.value = \"01\";
		document.formulaire.startH.value = \"00\";
		document.formulaire.startN.value = \"00\";
		document.formulaire.endY.value = now.getUTCFullYear() + 1;
		document.formulaire.endM.value = \"01\";
		document.formulaire.endD.value = \"01\";
		document.formulaire.endH.value = \"00\";
		document.formulaire.endN.value = \"00\";
	}
}
</script>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" onLoad=\"document.formulaire.origin.value=window.location.protocol + '//' + window.location.hostname + (window.location.port ? (':' + window.location.port) : '');preSet();document.formulaire.timezone.focus();\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>";

print "<h2>$pagetitle</h2>";
print "<P class=\"subMenu\"> <b>&raquo;&raquo;</b> [ <a href=\"/cgi-bin/showREQ.pl\">Results</a> ]</P>";

print "<form id=\"theform\" name=\"formulaire\" action=\"\">";

print "<TABLE style=\"border:0\" width=\"100%\">";
print "<TR>";
	print "<TD style=\"border:0;vertical-align:top;\" nowrap>";   # left column 

	# ---- Display list of PROCS that are eligible for requests
	print "<fieldset><legend>$__{'Available PROCS'}</legend>";
	print "<div style=\"overflow-y: scroll;height: 400px\">";
	for my $p (@proclist) {
		%P = readProc($p);
		my $nn = scalar(@{$P{$p}{NODESLIST}});
		print "<INPUT type=\"checkbox\" name=\"p_$p\" title=\"$p\" onclick=\"selProc('$p')\" value=\"0\"> <B>{$p}:</B> $P{$p}{NAME} (<B>$nn</B> node".($nn>1?"s":"").")<BR>\n";
		print pkeys($p,\%P);
	}
	print "</div>";
	print "</TD>\n";                                             # end left column

	print "<TD style=\"border:0;vertical-align:top\" nowrap>";   # right column 

	print "<fieldset><legend>$__{'Date and time span (UT)'}</legend>"; 
	#	DATE1|  DATE2|
  	print "<TABLE>";
    	print "<TR>";
		print "<TD style=\"border:0;text-align:right\">";
    		print "<div class=parform>";
			print "<B>$__{'Start date'}:</b> <select name=\"startY\" size=\"1\">";
			for (@yearList) { print "<option".(($_ eq $usrYearS)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"startM\" size=\"1\">";
			for (@monthList) { print "<option".(($_ eq $usrMonthS)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"startD\" size=\"1\">";
			for (@dayList) { 	print "<option".(($_ eq $usrDayS)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " &nbsp;&nbsp; <select name=\"startH\" size=\"1\">";
			for (@hourList) { 	print "<option value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"startN\" size=\"1\">";
			for (@minuteList) { 	print "<option value=$_>$_</option>\n"; }
			print "</select><BR>";
			print "<b>$__{'End date'}:</b> <select name=\"endY\" size=\"1\">";
			for (@yearList) { print "<option".(($_ eq $usrYearE)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"endM\" size=\"1\">";
			for (@monthList) { print "<option".(($_ eq $usrMonthE)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"endD\" size=\"1\">";
			for (@dayList) { print "<option".(($_ eq $usrDayE)?" selected":"")." value=$_>$_</option>\n"; }
			print "</select>";
			print " &nbsp;&nbsp; <select name=\"endH\" size=\"1\">";
			for (@hourList) { 	print "<option value=$_>$_</option>\n"; }
			print "</select>";
			print " <select name=\"endN\" size=\"1\">";
			for (@minuteList) { 	print "<option value=$_>$_</option>\n"; }
			print "</select>";
		print "</div></TD>";
		print "<TD style=\"border:0\"></TD>";
		print "<TD align=center style=\"border:0\">$__{'Preset dates'} <select name=\"preset\" size=\"1\" onChange=\"preSet()\">";
		print "<option value=\"\" selected></option>\n";
		print "<option value=\"fullmonth\">$__{'Last full month'}</option>\n";
		print "<option value=\"fullyear\">$__{'Last full year'}</option>\n";
		print "<option value=\"currentyear\">$__{'Current year'}</option>\n";
		print "</select></TD>";
	print "</TR>";
	print "</TABLE>\n";
	print "</fieldset>";

	my %datestr = readCfg("$WEBOBS{ROOT_CODE}/etc/dateformats.conf");
	my @ppis = split(',',$WEBOBS{REQ_PPI_LIST} //= '75,100,150,300,600');
	my @marks = split(',',$WEBOBS{REQ_MARKERSIZE_LIST} //= '1,2,4,6,10,15,20');
	my @linew = split(',',$WEBOBS{REQ_LINEWIDTH_LIST} //= '0.1,0.25,0.5,1,1.5,2,3');

	print "<fieldset><legend>$__{'Output parameters'}</legend>"; 
  	print "<TABLE>";
    	print "<TR>";
		print "<TD style=\"border:0\">";
	#	TZ|
		print "<label style=\"width:80px\" for=\"timezone\">$__{'TZ (+/-H)'}:</label>";
		print "<input id=\"timezone\" name=\"timezone\" size=\"5\" value=\"$REQDFLT{TZ}\"><BR>&nbsp;<BR>";
	#	DATESTR|
		print "<label style=\"width:80px\" for=\"datestr\">$__{'Date format'}:</label>";
		print "<select id=\"datestr\" name=\"datestr\" size=\"1\">";
		for (keys(%datestr)) { print "<OPTION".(($_ eq "-1")?" selected":"")." value=\"$_\">$datestr{$_}</OPTION>" }; 
		print "</select><BR>&nbsp;<BR>";
	#	CUMULATE|
		print "<label style=\"width:80px\" for=\"cumulate\">$__{'Cumulate'}:</label>";
		print "<input id=\"cumulate\" name=\"cumulate\" size=\"5\" value=\"$REQDFLT{CUMULATE}\"> $__{'days'}<BR>&nbsp;<BR>";
	#	DECIMATE|
		print "<label style=\"width:80px\" for=\"decimate\">$__{'Decimate'}:</label>";
		print "1/<input id=\"decimate\" name=\"decimate\" size=\"5\" value=\"$REQDFLT{DECIMATE}\"><BR>&nbsp;<BR>";
	#	MARKERSIZE|
		print "<label style=\"width:80px\" for=\"markersize\">$__{'Marker size'}:</label>";
		print "<select id=\"markersize\" name=\"markersize\" size=\"1\">";
		for (@marks) { print "<OPTION".(($_ eq $REQDFLT{MARKERSIZE})?" selected":"")." value=\"$_\">$_ pt</OPTION>" }; 
		print "</select><BR>&nbsp;<BR>";
	#	LINEWIDTH|
		print "<label style=\"width:80px\" for=\"linewidth\">$__{'Line width'}:</label>";
		print "<select id=\"linewidth\" name=\"linewidth\" size=\"1\">";
		for (@linew) { print "<OPTION".(($_ eq $REQDFLT{LINEWIDTH})?" selected":"")." value=\"$_\">$_ pt</OPTION>" }; 
		print "</select><BR>&nbsp;<BR>";
		print "</TD><TD style=\"border:0\">";
	#	PPI|
		print "<label style=\"width:80px\" for=\"ppi\">$__{'PPI'}:</label>";
		print "<select id=\"ppi\" name=\"ppi\" size=\"1\">";
		for (@ppis) { print "<OPTION".(($_ eq $REQDFLT{PPI})?" selected":"")." value=\"$_\">$_</OPTION>" }; 
		print "</select><BR>&nbsp;<BR>";
	#	PLOTGRID|
		print "<label style=\"width:80px\" for=\"gridon\">$__{'Grid'}:</label>";
		print "<input id=\"gridon\" name=\"gridon\" type=\"checkbox\" value=\"1\"".($REQDFLT{PLOTGRID}==1 ? " checked":"")."><BR>&nbsp;<BR>";
	#	PDFOUTPUT|
		print "<label style=\"width:80px\" for=\"pdfoutput\">$__{'PDF'}:</label>";
		print "<input id=\"pdfoutput\" name=\"pdfoutput\" type=\"checkbox\" value=\"1\"".($REQDFLT{PDFOUTPUT}==1 ? " checked":"")."><BR>&nbsp;<BR>";
	#	EXPORTS|
		print "<label style=\"width:80px\" for=\"exports\">$__{'Exports'}:</label>";
		print "<input id=\"exports\" name=\"exports\" type=\"checkbox\" value=\"1\"".($REQDFLT{EXPORTS}==1 ? " checked":"")."><BR>&nbsp;<BR>";
		print "</TD>";

	print "</TR>";
	print "</TABLE>\n";
	print "</fieldset>";
	print "</TD>\n";                                             # end right column

print "</TR></TABLE>\n";
print "<P align=center>"; 
print "<input type=\"button\" name=lien value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"$__{'Submit'}\" onClick=\"checkForm();\" style=\"font-weight:bold\">";
print "<input type=\"hidden\" id=\"origin\" name=\"origin\" value=\"\">";
print "</P>";

print "</form>";

# ---- end HTML
#  
print "\n</BODY>\n</HTML>\n";

# ---- build a div for a proc's keylist input fields
# (args: procName, \%procConf)
sub pkeys {
	my ($pn,$PP) = @_;
	if (defined($pn) && defined($PP->{$pn}{REQUEST_KEYLIST})) {
		my $div = "<div id='pkeysdrawer$pn' class='pkeysdrawer' style='display: none'>";
		foreach (split(/,/,$PP->{$pn}{REQUEST_KEYLIST})) {
			s/^\s+|\s+$//g;
			$div .= sprintf("<label for='PROC.%s.%s'>%s:</label>",$pn,$_,$_);
			$div .= sprintf("<input disabled id='PROC.%s.%s' name='PROC.%s.%s' maxlength='200' size='30' value='%s'><br>",$pn,$_,$pn,$_,defined($PP->{$pn}{$_})?$PP->{$pn}{$_}:"");
		}
		$div .= "</div>";
		return $div;
	}
	return "" ; # no request_keylist
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

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

