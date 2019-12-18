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

The full user name.

=item B<login=>

The login chosen by the user.

=item B<pass=>

The password chosen by the user.

=item B<pass2=>

Again, the password chosen by the user, for double checking.

=item B<mail=>

The user's email address.

=item B<conditions=>

This value is 1 if the user checked the checkbox "I do accept the terms of
use".

=cut

use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Encode qw(decode encode);
use Fcntl ':flock';
use File::Basename;

# ---- webobs stuff
# -----------------
use WebObs::Config;
use WebObs::Utils;
use WebObs::Users qw(%USERS clientHasRead clientHasEdit clientHasAdm
					 htpasswd_update htpasswd_display);
use WebObs::i18n;
use Locale::TextDomain('webobs');

my $cgi = new CGI;
set_message(\&webobs_cgi_msg);


# ---- useful subroutines

sub send_ajax_content {
# Send Ajax response (as text/plain) for the dialog box show to the user
	my $msg = shift;
	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$msg";
}

sub uid_exists {
	# Returns 1 if the provided UID exists in the database, 0 otherwise
	my $dbh = shift;
	my $uid = shift;
	my $q = "select UID from $WEBOBS{SQL_TABLE_USERS} where UID = ?";
	my $row = $dbh->selectrow_arrayref($q, undef, $uid);
	return 1 if $row;
	return 0;
}


# List of accepted characters for the password for display to the user
# (should reflect the regex in javascript and checkParam call below)
my $passwd_accepted_chars = "!?=_#%@/()_=-";

my $action = checkParam($cgi->param('action'), qr/^\w*$/, 'action') // '';

# ---- called for 'process form' (POST request, action=reg) ?
# -----------------------------------------------------------
if ($action eq "reg") {
	# Note: parameters here must allow a lot of different characters,
	# but they are not used in a shell. We can be generous, but still
	# rather restrictive as the script is not protected by a password.

	# Full name: any letter in unicode, including diacritics + a few signs
	my $fullname = checkParam(decode("utf-8", scalar($cgi->param('name'))),
								qr/^[\p{Letter} ,'’-]+$/, 'name') // '';
	# Login: only ascii letters and digits
	my $login = checkParam($cgi->param('login'),
					qr/^\w*$/, 'login') // '';
	# Password: only letters & allowed special chars
	my $passwd = checkParam(decode("utf-8", scalar($cgi->param('pass'))),
					qr/^[\p{Letter}\d!\?=_#%@\/()_=-]*$/, 'pass') // '';
	# Email address: most chars that are allowed in specs (minus a few)
	my $mailaddr = checkParam($cgi->param('mail'),
					qr/^[\w@!#%&'_{}~;=\$\*\+\-\/\?\^\.\|]*$/, 'mail') // '';
	# Conditions: 0 or 1
	my $terms = checkParam($cgi->param('conditions'),  # 0 or 1
					qr/^(0|1)?$/, 'conditions') // '';
	# Confirmation message after successful registration
	my $confirm_msg = "Your request will be processed ASAP. An administrator"
						." should notify you on $mailaddr for confirmation.";

	# Crypt password (this does not use a shell)
	my $encpasswd = htpasswd_display($login, $passwd);

	# Write registration request to the reglog
	my $reglog = exists $WEBOBS{REGISTRATION_LOGFILE} ?
					$WEBOBS{REGISTRATION_LOGFILE} : "$WEBOBS{PATH_DATA_DB}/reglog";
	my $autoregister = (($WEBOBS{SQL_DB_USERS_AUTOREGISTER} =~ /^y/i)
						&& !defined($USERS{$login})) ? 1 : 0;
	my $reg_file;
	if (!open($reg_file, ">>$reglog")) {
		send_ajax_content("Error: could not write your registration request");
		print STDERR "register.pl: could not write registration request to"
						." $reglog: $!\n";
		exit;
	}
# Note: for better security, avoid spreading the encrypted password
# if we'll write it to htpasswd.
	print $reg_file encode("utf-8", $fullname)."|$login|$mailaddr|"
			.($autoregister ? "[password set in auth file]" : $encpasswd)."\n";
	close $reg_file or die "Could not write to registration file";

	if ($autoregister) {
		# Autoregistration is enabled: we insert a disabled user into the
		# database (she/he won't be able to see/do anything until an admin
		# changes the user validity to 'Y')

		my $dbh = DBI->connect("dbi:SQLite:$WEBOBS{SQL_DB_USERS}", "", "", {
			'AutoCommit' => 1,
			'PrintError' => 1,
			'RaiseError' => 1,
			}) or die "Error connecting to $WEBOBS{SQL_DB_USERS}: $DBI::errstr" ;

		# Create the default UID as first letters from full name
		my $DEFAULT_UID = "";
		for (split(/ |-/, $fullname)) {
			$DEFAULT_UID .= uc(substr($_,0,1));
		}
		# We try to use the default UID as UID
		my $UID = $DEFAULT_UID;
		# If UID already exists, add a suffix number until we find an available UID
		my $nu = 1;  # number of tries and potential UID suffix
		while (uid_exists($dbh, $UID)) {
			if ($nu == 100) {
				# Something is seriously wrong here
				print STDERR "register.pl error: unable to find an UID after 100 tries "
					."UID='$UID' fullname='$fullname' login='$login' mailaddr='$mailaddr'\n";
				# Don't use die as it would display plain text HTML
				send_ajax_content("Unable to register your request (no available UID), "
									."please contact the administrator.");
				exit 99;
			}
			$nu++;
			$UID = $DEFAULT_UID.$nu;
		}
		# Insert the new user in the database (will raise an exception on database error)
		# Use a bound query to let DBI do the escaping (to avoid security problems)
		my $q = "insert into $WEBOBS{SQL_TABLE_USERS} values(?, ?, ?, ?, 'N')";
		my $sth = $dbh->prepare($q);
		# Note: there is a (very) slight chance of race condition if someone
		# made a registration request for a user with the same UID in the last
		# microseconds since we last called uid_exists(), but IMO handling this
		# rarest case is not worth the complexity.
		$sth->execute($UID, $fullname, $login, $mailaddr);
		$dbh->disconnect();

		# Give an access to the new user
		if (htpasswd_update($login, $passwd) != 0) {
			send_ajax_content("Couldn't update htpasswd."
								." Please inform the administrator.");
			print STDERR "register.pl: unable to update htpasswd"
							." for login $login: $!\n";
			exit;
		}
	}  # end of "autoregistration"
	my $rcn = WebObs::Config::notify(
		"register.warning|$$|received request from $fullname ($login)");
	if ($rcn != 0 ) {
		send_ajax_content("Your request has been registered but WebObs "
							."administrators could not be notified.");
		print STDERR "register.pl: postboard notify error: rc=$rcn\n";
		exit;
	}

	# Send Ajax response (as text/plain) for the dialog box
	send_ajax_content($confirm_msg);
	exit;

}  # end of action == 'reg'


# REDIRECT_QUERY_STRING is not standard and won't work
# in some situations (at least on nginx).
if (($ENV{"REDIRECT_QUERY_STRING"} // '') =~ /\blogout\b/
	|| ($ENV{"REQUEST_URI"} // '') =~ /\?.*\blogout\b/)
{
	print $cgi->header(-type=>'text/html', -charset=>'utf-8');
	print <<__EOD__;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
	<head>
		<title>WebObs logout</title>
		<meta http-equiv="content-type" content="text/html; charset=utf-8">
		<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
	</head>
	<body>
		<img src="$WEBOBS{'LOGO_DEFAULT'}">
		<h2>You are now logged Out</h2>
	</body>
</html>
__EOD__
	exit;
}  # end of "if logout"


# ---- called for 'pseudo-logout' or 'display form'  
# -------------------------------------------------
my @charte = readFile("$WEBOBS{TERMSOFUSE}");

my $pass_restriction;
my $pass_minlength = 0;
if ($WEBOBS{'HTPASSWORD_MIN_LENGTH'}) {
	$pass_minlength = $WEBOBS{'HTPASSWORD_MIN_LENGTH'};
	$pass_restriction = "At least $pass_minlength characters";
} else {
	$pass_restriction = "Any characters";
}
$pass_restriction .= ", including:<br> <b>$passwd_accepted_chars</b>";


print $cgi->header(-type=>'text/html',-charset=>'utf-8');

print <<__EOD__;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
	<head>
		<title>WebObs registration form</title>
		<meta http-equiv="content-type" content="text/html; charset=utf-8">
		<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
		<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
		<link rel="stylesheet" type="text/css" href="/css/register.css">
		<script type="text/javascript">
		function postReg() {
		  var errors = [];  // keep tuples of [errmsg, element_to_focus]
		  if (document.form.name.value == "") {
			 errors.push(['you must enter your name', document.form.name]);
		  }
		  // Unicode classes are not supported on all browsers
		  //if (/^[\\p{Letter} ,'’-]*\$/.test(document.form.pass.value)) {
		  // As a workaround, we only support latin letters
		  else if (! /^[a-zA-Z\\u00C0-\\u017F ,'’-]+\$/.test(document.form.name.value)) {
			 errors.push(['the name uses forbidden characters', document.form.name]);
		  }
		  if (document.form.login.value == "") {
			 errors.push(['you must enter a login', document.form.login]);
		  } else if (! /^\\w+\$/.test(document.form.login.value)) {
			 errors.push(['the login user name uses forbidden characters', document.form.name]);
		  }
		  if (document.form.pass.value == "") {
			 errors.push(['you must choose a password', document.form.pass]);
		  }
		  else if (document.form.pass.value.length < $pass_minlength) {
			 errors.push(['your password must be at least $pass_minlength characters long', document.form.pass]);
		  }
		  // Unicode classes are not supported on all browsers
		  //else if (/^[\\p{Letter}!\\?=_#%@\\/()_=-]+]*\$/.document.form.pass.value) {
		  // Only support latin letters as a workaround
		  if (! /^[a-zA-Z0-9\\u00C0-\\u017F!\\?=_#%@\\/()_=-]*\$/.test(document.form.pass.value)) {
			 errors.push(['your password uses forbidden characters', document.form.pass]);
		  }
		  if (document.form.pass.value != document.form.pass2.value) {
			 errors.push(['the passwords differ', document.form.pass]);
		  }
		  if ((document.form.mail.value == "")
			  || !/\\S+@\\S+\\.\\S+/.test(document.form.mail.value)) {
			 errors.push(['you must enter your e-mail address', document.form.mail]);
		  }
		  if (document.form.conditions.checked == false) {
			 errors.push(['you must accept the terms of use', document.form.conditions]);
		  }
		  if (errors.length) {
			 var msg = 'Sorry, there is at least one error in your form.\\n\\n'
				   + 'Please correct the errors below and submit the form again:\\n';
			 var first_elem;
			 errors.forEach(function(item, index, array) {
				msg += '- ' + item[0] + '\\n';
				if (!first_elem) { first_elem = item[1] }
			 });
			 alert(msg);
			 first_elem.focus();
			 return false;
		  }
		  \$.post(\"/cgi-bin/register.pl\", \$(\"#register_form\").serialize(), function(data) {
		  alert(data);
		  //location.href = document.referrer;
		  history.go(-1);
		  });
		}
		</script>
	</head>
		<body>
			<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
			<script language="JavaScript" src="/js/overlib/overlib.js"></script>
			<!-- overLIB (c) Erik Bosrup -->
			<img src="$WEBOBS{'LOGO_DEFAULT'}">
			<h2>Access to $WEBOBS{WEBOBS_TITLE}</h2>
			<fieldset>
				<p>
					<b>Access to this website is restricted to registered staff
					members and associated researchers.</b>
				</p>
				<p>
					If you need access to this website, please read the
					<b>"Terms of Use"</b> then fill in and submit the
					<b>registration form</b> below.
				</p>
			</fieldset>
			<br>
			<fieldset>
				<legend><b>Terms of Use</b></legend>
				<p>@charte</p>
			</fieldset>
			<br>
			<fieldset>
			<legend><b>$WEBOBS{WEBOBS_TITLE} registration form</b></legend>
			<form name="form" id="register_form">
			  <input type="hidden" name="action" value="reg">
			  <label>$__{'Full name'}:<span class="small">First and last name</span></label>
			  <input type="text" name="name" maxlength="30" value=""/><br/>
			  <label>$__{'Login user name'}:<span class="small">Short lowercase single word</span></label>
			  <input type="text" name="login" maxlength="10" value=""/><br/>
			  <label>$__{'Password'}:<span class="small">Please choose a strong password</span></label>
			  <input onmouseout="nd()" onmouseover="overlib('$pass_restriction',CAPTION,'Please choose a strong password!')" type="password" name="pass" value=""/><br/>
			  <label>$__{'Password again'}:<span class="small"></span></label>
			  <input type="password" name="pass2" value=""/><br/>
			  <label>$__{'Email address'}:<span class="small">Valid e-mail needed</span></label>
			  <input type="text" name="mail" maxlength="80" value=""/><br/>
			  <br>
			  <label for="conditions">
			     $__{'I do accept the terms of use'}:<span class="small"></span>
			  </label>
			  <input type="checkbox" id="conditions" name="conditions" value="1">
			  <p style="clear: both; margin: 0px; text-align: center">
			    <input type="button" name="sendbutton" onclick="postReg(); return false;"
                  value="$__{'Submit'}">
			  </p>
			  </form>
			</fieldset>
	</body>
</html>
__EOD__

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel, Xavier Béguin

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

