#!/usr/bin/perl
#
# Presents a form to allow the current user to change its password in the
# htpasswd file.

=head1 NAME

changepassword.pl

=head1 SYNOPSIS

http://..../changepassword.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

Displays a form to allow the current user to change their password after verifying their current password.

=head1 Query string parameters

=over

=item B<current_password=>

=item B<new_password=>

=item B<new_password2=>

=cut

use strict;
use warnings;
use IPC::Open3;
use CGI;
use CGI::Carp;
use CGI::Carp qw(fatalsToBrowser set_message);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT userIsValid htpasswd_verify htpasswd_update);
use WebObs::Utils qw(isok);
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
my $cgi = new CGI;


##---- Script functions


sub print_head {
  print <<__EOD__;
Content-type: text/html

<!DOCTYPE html>
<html>
<head>
  <title>WebObs HTTP password change</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8">
  <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
  <script type="JavaScript" src="/js/jquery.js"></script>
  <script type="JavaScript" src="/js/htmlFormsUtils.js"></script>
  <style type="text/css">
  .form_elem {
    display: inline-block;
    vertical-align: middle;
    margin-bottom: 1em;
  }
  .form_label {
    width: 22em;
    text-align: right;
  }
  .alert-success, .alert-error, .alert-info, .alert-secondary {
    border-radius: .25rem;
    padding: 1em;
  }
  .alert-error {
      color: #721c24;
      background-color: #f8d7da;
      border: 1px solid #f5c6cb;
  }
  .alert-success {
      color: #155724;
      background-color: #d4edda;
      border-color: #c3e6cb;
  }
  .alert-info {
      color: #0c5460;
      background-color: #d1ecf1;
      border-color: #bee5eb;
  }
  .alert-secondary {
      color: #383d41;
      background-color: #e2e3e5;
      border-color: #d6d8db;
  }
  </style>
</head>
<body>
__EOD__
}


sub print_foot {
  print <<__EOD__;
</BODY>
</HTML>
__EOD__
}


sub print_form {
  my $submit_url = $cgi->url();
  my $min_length_msg = "";
    if ($WEBOBS{'HTPASSWORD_MIN_LENGTH'}) {
    $min_length_msg = sprintf($__{'Note: your password must be at least %s characters long.'},
      $WEBOBS{'HTPASSWORD_MIN_LENGTH'});
  }
  print <<__EOD__;
  <h2>$__{'Change your WebObs password'}</h2>
  <p>
  $__{'Please fill in the form below to update your WebObs password.'}
  $min_length_msg
  </p>

  <fieldset>
  <legend><h3>$__{'Update your password'}</h3></legend>

  <form class="chpass_form" name="changePass" id="changePass"
    method="POST" action="$submit_url">
  <div class="form_elem form_label">
      <label for="current_login">$__{'Your login name'}:</label>
  </div>
  <div class="form_elem form_input">
      <b>$CLIENT</b><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="current_password">$__{'Your current password'}:</label>
  </div>
  <div class="form_elem form_input">
      <input type="password" name="current_password" value=""/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="new_password">$__{'Your new password'}:</label>
  </div>
  <div class="form_elem form_input">
    <input type="password" name="new_password" value=""/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="new_password2">$__{'Your new password for verification'}:</label>
  </div>
  <div class="form_elem form_input">
      <input type="password" name="new_password2" value=""/><br>
  </div>
  <br>

  <div class="form_elem form_label">
  </div>
  <div class="form_elem form_input">
    <input type="submit" name="submit" value="$__{'Submit'}">
  </div>
  </form>
  </fieldset>
__EOD__
}


sub print_alert {
    my $alert_class = shift;
  my $msg = join(" ", @_);
  print <<__EOD__;
  <p class="$alert_class">
    $msg
  </p>
__EOD__
}

sub print_success {
  return print_alert("alert-success", @_);
}

sub print_error {
  return print_alert("alert-error", @_);
}

sub print_secondary {
  return print_alert("alert-secondary", @_);
}


##---- Main script
if ( ! userIsValid(user=>$CLIENT) ) {
  die "You cannot display this page.";
}
 
my $current_password = $cgi->param('current_password') // "";
my $new_password  = $cgi->param('new_password')        // "";
my $new_password2 = $cgi->param('new_password2')       // "";


# If ALLOW_HTPASSWORD_CHANGE is not set to true in WEBOBS.rc,
# we won't allow users to change their password.
if (!isok($WEBOBS{'ALLOW_HTPASSWORD_CHANGE'})) {
  print_head();
  print("<h2>$__{'Password change disabled'}</h2>\n");
  print_secondary($__{'Sorry, password change is disabled on this platform. Please contact your administrator.'});
  print_foot();
  exit(0);
}

# Special case for user 'guest' that is forbidden to change its password
if ($CLIENT eq "guest") {
  print_head();
  print("<h2>$__{'Password change forbidden'}</h2>\n");
  print_secondary($__{"Sorry, the special user 'guest' cannot change his password."});
  print_foot();
  exit(0);
}


# Print first part of the page
print_head();

if (not ($current_password and $new_password and $new_password2)) {
  # No argument provided: simply print the form
  print_form();

} elsif ($new_password ne $new_password2) {
    # The two version of the new password differ
  print_error($__{'Sorry, your new password does not match the second entry.'},
        $__{'Please try again below.'});
  print_form()

} elsif (length($new_password) < $WEBOBS{'HTPASSWORD_MIN_LENGTH'}) {
  # Password length too short
  print_error($__{'Sorry'},
    sprintf($__{'your password must be at least %s characters long'}.".",
        $WEBOBS{'HTPASSWORD_MIN_LENGTH'}));
  print_form()

} else {
    # $current_password, $new_password, and $new_password2 are provided
    # and $new_password equals $new_password2.

  if (htpasswd_verify($CLIENT, $current_password) != 0) {
    # The current password could not be verified
    print_error($__{'Sorry, your current password is incorrect.'},
          $__{'Please try again below.'});
    print_form()

  } elsif (htpasswd_update($CLIENT, $new_password) != 0) {
    # The update returned an error
    print_error($__{'Sorry, an error occured. Your password could not be updated.'});

  } else {
      # The password was changed
    print "<h2>$__{'Password updated'}</h2>\n";
    print_success($__{'Your password has been successfully updated!'});
    print "<p>".$__{'You will be asked for your new password on'}
        ." <a href=\"/cgi-bin/Welcome.pl\">".$__{'the next requested page'}."</a>.</p>\n";
  }
}

# Print last part of the page
print_foot();

__END__

=pod

=head1 AUTHOR(S)

Xavier Béguin

=head1 COPYRIGHT

Webobs - 2012-2024 - Institut de Physique du Globe Paris

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
