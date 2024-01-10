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
use JSON;

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

my $submit_url = $q->url();
my $operator_name = "$USERS{$CLIENT}{FULLNAME}";
my $operator_email = "$USERS{$CLIENT}{EMAIL}";

my %P = readCfg("$WEBOBS{ROOT_CONF}/PROCS/$GRIDName/$GRIDName.conf");
my $mutt_options = "$P{MUTT_OPTIONS}";

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
  </script>
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

  my ($y,$m,$d,$id,$evt) = split(/\//,$g);
  my ($evt_y,$evt_m,$evt_d,$evt_H,$evt_M,$evt_S,$evt_loc) = unpack("a4a2a2xa2a2a2xa*",$evt);
  my $b3 = "$WEBOBS{'ROOT_OUTG'}/$grid/$ts/$g";
  my $b3_urn = "$WEBOBS{'URN_OUTG'}/$grid/$ts/$g"; 
  my $evt_email = $P{TRIGGER_EMAIL};
  my $evt_subject = $P{TRIGGER_SUBJECT};
  my $report_email = $P{REPORT_EMAIL};
  my ($evt_latitude,$evt_longitude,$evt_magnitude,$evt_depth,$evt_department,$evt_region);
  my $report_file = "$evt.pdf";
  my $report_subject = "$P{REPORT_SUBJECT}";
  my $report_message;
    
  # reads needed information from the event
  my $triggerOK = 1;
  my $trigger_check = 'checked';
  my $evt_origin = "$evt_y/$evt_m/$evt_d $evt_H:$evt_M:$evt_S";
  if (-e "$b3.json") {
    my %json = %{decode_json(l2u(join("",readFile("$b3.json"))))};
    $evt_latitude = $json{'latitude'};
    $evt_longitude = $json{'longitude'};
    $evt_depth = $json{'depth'};
    $evt_magnitude = $json{'magnitude'};
    $evt_department = l2u($json{'department'});
    $evt_region = l2u($json{'region'});

  } elsif (-e "$b3.gse") {
    my @gse = readFile("$b3.gse");
    $evt_latitude = trim(substr($gse[9],25,9));
    $evt_longitude = trim(substr($gse[9],34,9));
    $evt_depth = trim(substr($gse[9],47,7));
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
  <p>$__{'Event origin'}: <b>$evt_y-$evt_m-$evt_d $evt_H:$evt_M:$evt_S UT</b></p>
  <p>$__{'Event ID/name'}: <b>$id/$evt_loc</b></p>
  <p>$__{'Operator'}: <b>"$operator_name" &lt;$operator_email&gt;</b></p>
  </td></tr></table>
  
  <form class="chpass_form" name="changePass" id="changePass"
    method="POST" action="$submit_url">
  <input type="hidden" name="grid" value="$grid"/>
  
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
      <label for="event_time">$__{'Origin time (UT)'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="event_time" value="$evt_origin"/><br/>\n
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_latitude">$__{'Latitude'}:</label>
  </div>
  <div class="form_elem form_input">
    <input name="event_latitude" value="$evt_latitude"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_longitude">$__{'Longitude'}:</label>
  </div>
  <div class="form_elem form_input">
    <input name="event_longitude" value="$evt_longitude"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_depth">$__{'Depth (km)'}:</label>
  </div>
  <div class="form_elem form_input">
    <input name="event_depth" value="$evt_depth"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_magnitude">$__{'Magnitude'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="event_magnitude" value="$evt_magnitude"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_department">$__{'Department'}:</label>
  </div>
  <div class="form_elem form_input">
      <input name="event_department" value="$evt_department"/><br>
  </div>
  <br>

  <div class="form_elem form_label">
      <label for="event_region">$__{'Region'}:</label>
  </div>
  <div class="form_elem form_input">
      <input size=40 name="event_region" value="$evt_region"/><br>
  </div>
  </fieldset>

  </td><td style="border:0; vertical-align:top">
  
  <fieldset>
  <legend><h3><input type="checkbox" name="send_report" value="Y" checked>$__{'Send the B3 report'}</h3></legend>

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
    <textarea name="report_message" type="text" cols=80 rows="12"/>$report_message</textarea><br>
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
  print "<h2>$__{'Sending emails'}</h2>\n";
  my $replyto = "export REPLYTO=$operator_email";

  # send trigger email
  if ($q->param('send_trigger')) {
    my $mail_address = $q->param('trigger_email');
    my $mail_subject = $q->param('trigger_subject');
    my $mail_content = "Time: ".$q->param('event_time')."\n"
                       ."Latitude: ".$q->param('event_latitude')."\n"
                       ."Longitude: ".$q->param('event_longitude')."\n"
                       ."Depth: ".$q->param('event_depth')."\n"
                       ."Magnitude: ".$q->param('event_magnitude')."\n"
                       ."Department: ".u2l($q->param('event_department'))."\n"
                       ."Region: ".u2l($q->param('event_region'))."\n";
    my $cmd = "$replyto;echo \"$mail_content\" | mutt -s \"$mail_subject\" $mutt_options $mail_address $operator_email";
    if ( ! system($cmd) ) {
      print_success($__{'Trigger email has been successfully sent!'});
    } else {
      print_error($__{'Sorry, an error occured during report email sending. Please contact an administator.'});
    }
  }

  # send report email
  if ($q->param('send_report')) {
    my $mail_address = $q->param('report_email');
    my $mail_subject = u2l($q->param('report_subject'));
    my $mail_content = u2l($q->param('report_message'));
    my $mail_attach = $q->param('report_file');
    my $cmd = "$replyto;echo \"$mail_content\" | mutt -s \"$mail_subject\" -a \"$mail_attach\" -b \"$mail_address\" $mutt_options -- $operator_email";
    if ( ! system($cmd) ) {
      print_success($__{'Report email has been successfully sent!'});
    } else {
      print_error($__{'Sorry, an error occured during report email sending. Please contact an administator.'});
    }
  }

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
