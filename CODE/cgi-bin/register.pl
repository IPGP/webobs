#!/usr/bin/perl

=head1 NAME

register.pl 

=head1 SYNOPSIS

http://..../register.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

This script must be reachable/executable from any http client (ie. not subject to Apache's Authentication
rules). It may also be used as the Apache's target document in case of 401 error. 
 
=head1 Query string parameters

=over

=item B<action=>

'reg' or 'disp' (default)

=item B<name=>

=item B<login=>

=item B<pass=>

=item B<pass2=>

=item B<mail=>

=item B<conditions=>

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

# ---- webobs stuff
# -----------------
use WebObs::Config;
use WebObs::Users qw(%USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- called for 'process form' (POST request, action=reg) ?
# -----------------------------------------------------------
if ( $cgi->param('action') eq "reg" ) {
	my $fullname = $cgi->param('name')  || 	'';
	my $login    = $cgi->param('login') || '';
	my $pswd     = $cgi->param('pass')  || '';
	#my $pswd2    = $cgi->param('pass2') || '';
	my $mailaddr = $cgi->param('mail')  || '';
	my $terms    = $cgi->param('conditions') || '';
	my $msg      = "Your request will be processed asap. A mail will be sent to $mailaddr for confirmation.";
	
	$login =~ s/(["' ()\$#\\])/\\$1/g;
	$pswd  =~ s/(["' ()\$#\\])/\\$1/g;
	my $encpswd = `/usr/bin/htpasswd -nsb $login $pswd`;
	# remove the two new lines htpasswd adds after its result.
	chomp $encpswd; chomp $encpswd;


	if (open(FILE,">>$WEBOBS{PATH_DATA_DB}/reglog")) { 
		print FILE "$fullname|$login|$mailaddr|$encpswd\n";
		close FILE;
		if ($WEBOBS{SQL_DB_USERS_AUTOREGISTER} =~ /^y/i && !defined($USERS{$login})) {
			# makes the UID: First letters from full name
			my @FL;
			for (split(/ |-/, $fullname)) {
				push(@FL, uc(substr($_,0,1)));
			}
			my $UID = join("",@FL);
			my $dbh = DBI->connect("dbi:SQLite:dbname=$WEBOBS{SQL_DB_USERS}", '', '') or die "$DBI::errstr" ;
			my $rv = 0;
			my $nu = 1;
			# if UID already exists, add a suffix number... 
			while ($rv eq 0) {
				my $q = "insert into $WEBOBS{SQL_TABLE_USERS} values(\'$UID\',\'$fullname\',\'$login\',\'$mailaddr\',\'N\')";
				$rv = $dbh->do($q);
				$rv = 0 if ($rv == 0E0); 
				if ($rv eq 0) {
					$nu++;
					$UID .= $nu;
				}
			}
			$dbh->disconnect();

			# gives an htaccess to the new user !
			if (open(FILE,">>$WEBOBS{ROOT_CONF}/htpasswd")) {
				print FILE "\n$encpswd\n";
				close FILE;
			} else {
				$msg = "Couldn't register htpasswd ($!). Please inform administrator.";
			}

		}
		if ( (my $rcn = WebObs::Config::notify("register.warning|$$|received request from $fullname ($login)")) != 0 ) {
			$msg = "WebObs administrator notify error rc=$rcn";
		}
	} else { 
		$msg= "Couldn't register: reglog ($!). Please retry later." 
	}

 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$msg"; 

} else {
# ---- called for 'pseudo-logout' or 'display form'  
# -------------------------------------------------
	my @charte=readFile("$WEBOBS{TERMSOFUSE}");
	print $cgi->header(-type=>'text/html',-charset=>'utf-8');
	print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
		  "<html><head><title>WebObs registration form</title>\n",
		  "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
		  "<script language=\"javascript\" type=\"text/javascript\" src=\"/js/jquery.js\"></script>\n",
		  "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n",
		  "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/register.css\">\n";

	if ($ENV{"REDIRECT_QUERY_STRING"} =~ /logout/) {
		print "</head>\n";
		print "<body>\n";
			print "<img src=\"/icons/ipgp/logo_WebObs_C110.png\">";
			print "<h2>Logged Out !</h2>";
		print "</body>\n";
	} else {
print <<EOSCRIPT;
		<script type="text/javascript">
		function postReg() {
		  if (document.form.name.value == "") {
			 alert('Please enter your name!');
			 document.form.name.focus();
			 return false;
		  }
		  if (document.form.login.value == "") {
			 alert('Please enter login!');
			 document.form.login.focus();
			 return false;
		  }
		  if (document.form.pass.value == "") {
			 alert('Please enter your password!');
			 document.form.pass.focus();
			 return false;
		  }
		  if (document.form.pass.value != document.form.pass2.value) {
			 alert('Passwords differ. ');
			 document.form.pass.focus();
			 return false;
		  }
		  if (document.form.mail.value == "") {
			 alert('Please enter your e-mail address!');
			 document.form.mail.focus();
			 return false;
		  } else {
			 adresse = document.form.mail.value;
			 var re = /\\S+@\\S+\\.\\S+/;
			 if (! re.test(adresse)) {
			 	alert('Please enter a valid e-mail address.');
				return false;
			 }
		  }
		  if (document.form.conditions.checked == false) {
			 alert('You must accept the terms ! ');
			 document.form.conditions.focus();
			 return false;
		  }
		  \$.post(\"/cgi-bin/register.pl\", \$(\"#register_form\").serialize(), function(data) {
		  alert(data);
		  //location.href = document.referrer;
		  history.go(-1);
		  });
		}
		</SCRIPT>
EOSCRIPT
	print "</head>\n";
		print "<body>\n";
			print "<img src=\"/icons/ipgp/logo_IPGP_C110.png\"><img src=\"/icons/ipgp/logo_WebObs_C110.png\">";
			print "<h2>Access to $WEBOBS{WEBOBS_TITLE}</h2>";
			print "<fieldset>";
			print "<b>Access to this website is restricted to registered staff members and associated researchers.</b>";
			print "<br>";
			print "If you need access to this website, please read the <b>\"Terms of Use\"</b> then fill in and submit the <b>registration form</b> below.";
			print "</fieldset>";
			print "<br>";
			print "<fieldset>";
			print "<legend><b>Terms of Use</b></legend>";
			print "<p>@charte</p>";
			print "</fieldset>";
			print "<br>";
			print "<fieldset>";
			print "<legend><b>$WEBOBS{WEBOBS_TITLE} registration form</b></legend>";
			print "<FORM name=\"form\" id=\"register_form\">";
			print "<input type=\"hidden\" name=\"action\" value=\"reg\">";
			print "<label>$__{'Full name'}:<span class=\"small\">First and last name</span></label>",
				  "<input type=\"text\" name=\"name\" maxlength=\"30\" value=\"\"/><br/>\n",
				  "<label>$__{'Login user name'}:<span class=\"small\">Short lowercase single word</span></label>",
				  "<input type=\"text\" name=\"login\" maxlength=\"10\" value=\"\"/><br/>\n",
				  "<label>$__{'Password'}:<span class=\"small\">no restriction (!)</span></label>",
				  "<input type=\"password\" name=\"pass\" value=\"\"/><br/>\n",
				  "<label>$__{'Password again'}:<span class=\"small\"></span></label>",
				  "<input type=\"password\" name=\"pass2\" value=\"\"/><br/>\n",
				  "<label>$__{'Email address'}:<span class=\"small\">Valid e-mail needed</span></label>",
				  "<input type=\"text\" name=\"mail\" maxlength=\"80\" value=\"\"/><br/>\n",
				  "<br>\n",
				  "<label>$__{'I do accept the terms of use'}:<span class=\"small\"></span></label>",
				  "<input type=\"checkbox\" name=\"conditions\" value=\"1\">\n",
				  "<p style=\"clear: both; margin: 0px; text-align: center\">",
					  "<input type=\"button\" name=\"sendbutton\" onclick=\"postReg(); return false;\" value=\"$__{'Submit'}\">",
				  "</p>\n";
			print "</FORM>";
			print "</fieldset>";
			print "";
		print "</body>";
	}
	print "</html>";
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel

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

