#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# relayMgr.pl
# ------
# Usage: controls relays in order to perform ON/OFF orders
#
# Author: Patrice Boissier <boissier@ipgp.fr>
# Created: 2021-07-06
#---------------------------------------------------------------
#

use strict;
use File::Basename;
use Data::Dumper;
use Time::Local;
use Time::Piece;
use POSIX qw/strftime/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use HTML::Entities;
use Encode;
use DateTime qw( );
use Net::Telnet ();

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm $CLIENT);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::Wiki;
use WebObs::QML;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# ---- check client's authorization(s) ----------------------------------------
# TODO : based on Main Courante at the moment
die "$__{'Not authorized'} Gestion des relais" if (!clientHasAdm(type=>"authprocs",name=>"RELAY"));

# ---- 1st parse query parameters for configuration file and debug option -----
#
my $QryParm  = $cgi->Vars;
$QryParm->{'debug'}     ||= "";
$QryParm->{'send'}     ||= "";
$QryParm->{'sent'}     ||= "";
$QryParm->{'action'}     ||= "nothing";

# ---- Relay parameters - IP - TCP Port - Command1 - Command2 - Sleep----------
#
# TODO : add status command : "?" or "?RLY"
# TODO : add prompt format for status command. '/[01]{8}$/' for 8 ports relay and '/>[01]{4}$/' for 4 ports relay
# TODO : add a prefix for the output for 4 ports relay : '>' (no prefix for 8 ports relay)
my %relayParams;
$relayParams{'ber_camerairt_reboot'} = ['10.10.5.254','6001','RLY61','RLY60',5,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.CAMERAS.RPVBERCIRT"];
$relayParams{'ber_cameraovpf_reboot'} = ['10.10.5.254','6001','RLY11','RLY10',5,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.CAMERAS.RPVBERC"];
$relayParams{'ber_vent_off'} = ['10.10.5.254','6001','RLY21','',0,"http://195.83.188.56/cgi-bin/relayMgr.pl?sent=yes"];
$relayParams{'ber_vent_on'} = ['10.10.5.254','6001','RLY20','',0,"http://195.83.188.56/cgi-bin/relayMgr.pl?sent=yes"];
$relayParams{'ber_relaintr_off'} = ['10.10.5.254','6001','RLY81','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.RELAIS.RATBERR"];
$relayParams{'ber_relaintr_on'} = ['10.10.5.254','6001','RLY80','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.RELAIS.RATBERR"];
$relayParams{'ber_phonie_off'} = ['10.10.5.254','6001','RLY70','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.RELAIS.RATBERR"];
$relayParams{'ber_phonie_on'} = ['10.10.5.254','6001','RLY71','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.RELAIS.RATBERR"];
$relayParams{'bas_phonie_off'} = ['10.10.2.1','6001','S40','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.RELAIS.RATBASR"];
$relayParams{'bas_phonie_on'} = ['10.10.2.1','6001','S41','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.RELAIS.RATBASR"];
$relayParams{'hdl_camera_off'} = ['192.168.11.41','6001','S31','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.CAMERAS.RPVHDLC"];
$relayParams{'hdl_camera_on'} = ['192.168.11.41','6001','S30','',0,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.CAMERAS.RPVHDLC"];
$relayParams{'cboh_camera_reboot'} = ['10.10.30.20','6001','S11','S10',5,"http://195.83.188.56/cgi-bin/vedit.pl?action=new&object=VIEW.CAMERAS.RPVCBOH"];

if ($QryParm->{'send'} eq "Envoyer" && $QryParm->{'action'} ne "nothing") {
	my $statusBefore;
	my $statusAfter;
	my $statusReboot;
	if( exists($relayParams{$QryParm->{'action'}}) ) {
		my $telnetClient = new Net::Telnet (
			Host => $relayParams{$QryParm->{'action'}}[0],
			Port => $relayParams{$QryParm->{'action'}}[1],
			Timeout => "4",
			#Prompt => '/\?$/',         # Specific prompt for relay activation
			#Prompt => '/[01]{8}$/',     # Specific prompt for status
		);

		my $commandStatus = "?RLY";
		#$telnetClient->cmd(
		#	String => $commandStatus,
		#	Prompt => '/[01]{8}$/',
		#);
		#$statusBefore = $telnetClient->last_prompt;

		sleep(1);

		my $command = $relayParams{$QryParm->{'action'}}[2];
		$telnetClient->cmd(
			String => $command,
			Prompt => '/\?$/',
			Errmode => "return",
		);

		#sleep(1);

		#$telnetClient->cmd(
		#	String => $commandStatus,
		#	Prompt => '/[01]{8}$/',
		#);
		#$statusAfter = $telnetClient->last_prompt;

		if ($relayParams{$QryParm->{'action'}}[4] > 0) {
			sleep($relayParams{$QryParm->{'action'}}[4]);
			$command = $relayParams{$QryParm->{'action'}}[3];
			$telnetClient->cmd(
				String => $command,
				Prompt => '/\?$/',
				Errmode => "return",
			);

			#sleep(1);

			#$telnetClient->cmd(
			#	String => $commandStatus,
			#	Prompt => '/[01]{8}$/',
			#);
			#$statusReboot = $telnetClient->last_prompt;
		}

		print "Location: $relayParams{$QryParm->{'action'}}[5]\n\n";
#		print $cgi->header(-charset=>'utf-8');
#		print <<"PART1";
#<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
#<html>
#  <head>
#    <meta http-equiv="content-type" content="text/html; charset=utf-8">
#    <title>Gestion des relais</title>
#    <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
#  </head>
#  <body>
#    <h1>Commande des relais</h1>
#    <p>
#      Send : $QryParm->{'send'}<br>
#      Action : $QryParm->{'action'}<br>
#      IP : $relayParams{$QryParm->{'action'}}[0]<br>
#      TCP Port : $relayParams{$QryParm->{'action'}}[1]<br>
#      Command1 : $relayParams{$QryParm->{'action'}}[2]<br>
#      Command2 : $relayParams{$QryParm->{'action'}}[3]<br>
#      Sleep : $relayParams{$QryParm->{'action'}}[4]<br>
#      Etat initial : $statusBefore<br>
#      Etat apres la commande 1 : $statusAfter<br>
#      Etat final : $statusBefore<br>
#  </body>
#</html>
#PART1

	}
} else {
	print $cgi->header(-charset=>'utf-8');
	print <<"PART1";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8">
    <title>Gestion des relais</title>
    <link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
    <script>
      function validateCommand(){
        if(!confirm("Attention, vous allez lancer une commande sur un relai. Etes-vous sur?")) {
          return false;
        } else {
          return true;
	}
      }
    </script>
  </head>
  <body>
  <h1>Commande des relais</h1>
PART1
	if ($QryParm->{'sent'} eq "yes") {
		print "<h2>Commande envoy&eacute;e avec succ&eacute;s</h2>";
	}
	print <<"PART2";
    <table>
    <form action="relayMgr.pl" onsubmit="return validateCommand()" method="GET">
      <tr><th>Application</th><th>Commande ON</th><th>Commande OFF</th><th>Commande Reboot</th></tr>
      <tr><th>Piton de Bert</th><th>&nbsp;</th><th>&nbsp;</th><th>&nbsp;</th></tr>
      <tr>
        <td>Camera Bert IRT</td>
	<td>&nbsp;</td>
	<td>&nbsp;</td>
        <td class="status-warning">
          <input type="radio" id="ber_camerairt_reboot" name="action" value="ber_camerairt_reboot">
	</td>
      </tr>
      <tr>
        <td>Camera Bert OVPF</td>
	<td>&nbsp;</td>
	<td>&nbsp;</td>
        <td class="status-warning">
          <input type="radio" id="ber_cameraovpf_reboot" name="action" value="ber_cameraovpf_reboot">
	</td>
      </tr>
PART2
	if (clientHasAdm(type=>"authprocs",name=>"RELAYADM")) {
		print <<"PART3";

      <tr>
        <td>Capteur de vent de BERT (IRT)</td>
        <td class="status-ok">
          <input type="radio" id="ber_vent_on" name="action" value="ber_vent_on">
	</td>
        <td class="status-critical">
          <input type="radio" id="ber_vent_off" name="action" value="ber_vent_off">
	</td>
	<td>&nbsp;</td>
      </tr>
      <tr>
        <td>Relai analogique de NTR</td>
        <td class="status-ok">
          <input type="radio" id="ber_relaintr_on" name="action" value="ber_relaintr_on">
	</td>
        <td class="status-critical">
          <input type="radio" id="ber_relaintr_off" name="action" value="ber_relaintr_off">
	</td>
	<td>&nbsp;</td>
      </tr>
PART3
	}
	print <<"PART4";
      <tr>
        <td>Relai phonie de Bert</td>
        <td class="status-ok">
          <input type="radio" id="ber_phonie_on" name="action" value="ber_phonie_on">
	</td>
        <td class="status-critical">
          <input type="radio" id="ber_phonie_off" name="action" value="ber_phonie_off">
	</td>
	<td>&nbsp;</td>
      </tr>

      <tr><th colspan=4>Piton des Basaltes</th></tr>
      <tr>
        <td>Relai phonie de Basaltes</td>
        <td class="status-ok">
          <input type="radio" id="bas_phonie_on" name="action" value="bas_phonie_on">
	</td>
        <td class="status-critical">
          <input type="radio" id="bas_phonie_off" name="action" value="bas_phonie_off">
	</td>
	<td>&nbsp;</td>
      </tr>
      <tr>
        <td>Relai radio SDIS de Basaltes</td>
        <td class="status-ok">
          <input type="radio" id="bas_sdis_on" name="action" value="bas_sdis_on">
	</td>
        <td class="status-critical">
          <input type="radio" id="bas_sdis_off" name="action" value="bas_sdis_off">
	</td>
	<td>&nbsp;</td>
      </tr>

      <tr><th colspan=4>Hubert Delisle</th></tr>
      <tr>
        <td>Camera de HDL</td>
        <td class="status-ok">
          <input type="radio" id="hdl_camera_on" name="action" value="hdl_camera_on">
	</td>
        <td class="status-critical">
          <input type="radio" id="hdl_camera_off" name="action" value="hdl_camera_off">
	</td>
	<td>&nbsp;</td>
      </tr>

      <tr><th colspan=4>Cratere Bory</th></tr>
      <tr>
        <td>Camera IR de Cratere Bory OVPF</td>
	<td>&nbsp;</td>
	<td>&nbsp;</td>
        <td class="status-warning">
          <input type="radio" id="cboh_camera_reboot" name="action" value="cboh_camera_reboot">
	</td>
      </tr>
    </table>

      <input type="submit" name="send" value="Envoyer"/></p>
    </form>
  </body>
</html>
PART4
}
