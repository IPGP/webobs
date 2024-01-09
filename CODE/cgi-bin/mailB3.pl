#!/usr/bin/perl
#
# Form to send emails of B3 reports

=head1 NAME

mailB3.pl

=head1 SYNOPSIS

http://..../mailB3.pl?.... see 'Query string parameters'....

=head1 DESCRIPTION

Displays a form to manage data to send from a B3 report (felt earthquake), an event output of proc tremblemaps.

=head1 Query string parameters

=over

=item B<grid=>

=item B<ts=events>

=item B<g=>

=cut

use strict;
use warnings;
use CGI;
use CGI::Carp;
use CGI::Carp qw(fatalsToBrowser set_message);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT clientIsValid clientHasEdit);
use WebObs::Utils qw(isok trim l2u u2l);
use WebObs::Grids;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
my $q = new CGI;
my $grid = $q->param('grid');
my $ts = $q->param('ts');
my $g = $q->param('g');

my ($GRIDType, $GRIDName) = split(/\./,$grid);

# before continuing, verify consistancy and authorization
if (not (clientHasEdit(type=>"authprocs",name=>"$GRIDName"))) {
  print_head();
  print("<h2>$__{'Unauthorized action'}</h2>\n");
  print_secondary("Sorry, you cannot use this script on $grid. Please contact your administrator.");
  print_foot();
  exit(0);
}

my $operator_name = "$USERS{$CLIENT}{FULLNAME}";
my $operator_email = "$USERS{$CLIENT}{EMAIL}";

##---- Script functions

sub print_head {
  print <<__EOD__;
Content-type: text/html

<!DOCTYPE html>
<html>
<head>
  <title>Mail B3 reports</title>
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
    width: 15em;
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
  my $submit_url = $q->url();

  my %P = readCfg("$WEBOBS{ROOT_CONF}/PROCS/$GRIDName/$GRIDName.conf");
  my ($y,$m,$d,$id,$evt) = split(/\//,$g);
  my ($evt_y,$evt_m,$evt_d,$evt_H,$evt_M,$evt_S,$evt_loc) = unpack("a4a2a2xa2a2a2xa*",$evt);
  my $b3 = "$WEBOBS{'ROOT_OUTG'}/$grid/$ts/$g";
  my $b3_urn = "$WEBOBS{'URN_OUTG'}/$grid/$ts/$g"; 
  my $evt_email = $P{TRIGGER_EMAIL};
  my $evt_subject = $P{TRIGGER_SUBJECT};
  my $report_email = $P{REPORT_EMAIL};
  my ($evt_latitude,$evt_longitude,$evt_magnitude,$evt_department,$evt_region);
  my $report_file = "$evt.pdf";
  my $report_subject = "$P{REPORT_SUBJECT}";
  my $report_message;
    
  # reads needed information from the event
  my $triggerOK = 1;
  my $trigger_check = 'checked';
  my $evt_origin = "$evt_y/$evt_m/$evt_d $evt_H:$evt_M:$evt_S";
  if (-e "$b3.json") {

  } elsif (-e "$b3.gse") {
    my @gse = readFile("$b3.gse");
    $evt_latitude = trim(substr($gse[9],25,9));
    $evt_longitude = trim(substr($gse[9],34,9));
    $evt_magnitude = trim(substr($gse[9],74,4));
    ($evt_region,$evt_department) = split(/ \(|\)/,l2u(trim($gse[12])));
    $evt_department = $P{REGION} if ($evt_department eq "");
  } else {
    $triggerOK = 0;
    $trigger_check = 'disabled';
  }

  if (-e "$b3.msg") {
    my @msg = readFile("$b3.msg");
    $report_message = l2u(join("",@msg))."\n\n$P{REPORT_FOOTNOTE}\n";
  }
  print_secondary("Sorry, event $evt does not have json or gse file info. Will not be able to send the trigger email.") if (!$triggerOK);

  print <<__EOD__;
  <table><tr><td stype="border:2"><img src="$b3_urn.jpg"></td>
  <td style="border:0;padding-left:10px"><h2>$__{'Send felt earthquake report information'}</h2>
  <p>Event origin: <b>$evt_y-$evt_m-$evt_d $evt_H:$evt_M:$evt_S UT</b></p>
  <p>Event ID/name: <b>$id/$evt_loc</b></p>
  <p>Operator: <b>"$operator_name" &lt;$operator_email&gt;</b></p>
  </td></tr></table>
  
  <form class="chpass_form" name="changePass" id="changePass"
    method="POST" action="$submit_url">
  
  <table><tr><td style="border:0; vertical-align:top">
  <fieldset>
  <legend><h3><input type="checkbox" name="send_trigger" value="Y" $trigger_check\>$__{'Send trigger email'}</h3></legend>

  <div class="form_elem form_label">
      <label for="trigger_email">$__{'Destination email'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="trigger_email" value="$evt_email"/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="trigger_subject">$__{'Trigger email subject'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="trigger_subject" value="$evt_subject"/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_time">$__{'Event time (UT)'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="event_time" value="$evt_origin"/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_latitude">$__{'Event latitude'}:</label>
  </div>
  <div class="form_elem form_input">
    <input name="event_latitude" value="$evt_latitude"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_longitude">$__{'Event longitude'}:</label>
  </div>
  <div class="form_elem form_input">
    <input name="event_longitude" value="$evt_longitude"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_magnitude">$__{'Event magnitude'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="event_magnitude" value="$evt_magnitude"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_department">$__{'Event department'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="event_department" value="$evt_department"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_region">$__{'Event region'}:</label>
  </div>
  <div class="form_elem form_input">
      <input size=40 name="event_region" value="$evt_region"/><br>
  </div>
  </fieldset>

  </td><td style="border:0; vertical-align:top">
  
  <fieldset>
  <legend><h3><input type="checkbox" name="send_report" value="Y" checked>$__{'Send full report'}</h3></legend>

  <div class="form_elem form_label">
      <label for="report_email">$__{'Destination email'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="report_email" value="$report_email"/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="report_file">$__{'Attached file name'}:</label>
  </div>
  <div class="form_elem form_input">
      <input type="hidden" name="report_file" value="$b3.pdf"/>
      <b>$report_file</b><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="report_subhect">$__{'Report subject'}:</label>
  </div>
  <div class="form_elem form_input">
      <input size=80 name="report_subject" value="$report_subject"/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="report_message">$__{'Report message'}:</label>
  </div>
  <div class="form_elem form_input">
    <textarea name="report_message" type="text" cols=80 rows="10"/>$report_message</textarea><br>
  </div>
  <br>
  </fieldset>
  </td></tr>
  <tr><td style="border:0;text-align:center" colspan=2>

  <div class="form_elem form_input">
    <p><input type="submit" name="submit" style="font-weight: bold" value="$__{'Send emails'}"></p>
  </div>
  </td></tr></table>
  
  </form>
  
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

# Print first part of the page
print_head();

if ($q->param('send_trigger') eq '' and $q->param('send_report') eq '') {
  # No action provided (from the form): simply print the form
  print_form();

} else {
  # send trigger email
  if ($q->param('send_trigger')) {
    my $mail_address = $q->param('trigger_email');
    my $mail_subject = $q->param('trigger_subject');
    my $mail_content = "Time: ".$q->param('event_time')."\n\n"
                       ."Latitude: ".$q->param('event_latitude')."\n\n"
                       ."Longitude: ".$q->param('event_longitude')."\n\n"
                       ."Magnitude: ".$q->param('event_magnitude')."\n\n"
                       ."Departement: ".u2l($q->param('event_department'))."\n\n"
                       ."Region: ".u2l($q->param('event_region'))."\n\n";
    my $cmd = "export REPLYTO=$operator_email;echo \"$mail_content\" | mutt -s \"$mail_subject\" $mail_address";
   system($cmd);
  }

  print "<h2>$__{'Emails sent'}</h2>\n";
  print_success($__{'Emails have been successfully sent!'});
}

# Print last part of the page
print_foot();

__END__

=pod

=head1 AUTHOR(S)

François Beauducel

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
