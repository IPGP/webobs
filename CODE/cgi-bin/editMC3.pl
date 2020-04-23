#!/usr/bin/perl 

=head1 NAME

sefran3.pl

=head1 SYNOPSIS

http://..../editMC3.pl? ... see query string parameters below ...

=head1 DESCRIPTION

Process "Main Courante" editor form

=head1 Query string parameters

 s3=

 mc3=

 id_evt_modif=

 delete= { 0 | 1 | 2 }
 - void or 0 = modify data
 - 1 = to/from trash (changes sign of ID, ID<0 = in trash)
 - 2 = delete (removes from database)

 operator=

 date=

 secEvnt=

 typeEvnt=

 arrivee=

 dureeEvnt=

 uniteEvnt=

 dureeSatEvnt=

 amplitudeEvnt=

 stationEvnt=

 comment=

 impression=

 replay=

 nbrEvnt=

 smoinsp=

 imageSEFRAN=

 newSC3=

 idSC3= MC2 compatibility

 fileNameSUDS= MC2 compatibility

 transfert= MC2 compatibility

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw(strftime);
use List::Util qw(first);
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use WebObs::IGN;
use WebObs::Wiki;
use Locale::TextDomain('webobs');
use IO::Socket;

# ---- inits ----------------------------------
set_message(\&webobs_cgi_msg);
$|=1;
$ENV{LANG} = $WEBOBS{LOCALE};
my $editOK = 0;
my @image_list;

# ---- get query-string  parameters
my $s3       = $cgi->url_param('s3');
my $mc3      = $cgi->url_param('mc');
my $id_evt_modif = $cgi->param('id_evt');
my $date     = $cgi->param('date');
my $delete   = $cgi->param('effaceEvenement') // 0;
my $operator     = $cgi->param('nomOperateur');
my $dateEvnt = $cgi->param('dateEvenement');
my ($anneeEvnt,$moisEvnt,$jourEvnt,$heureEvnt,$minEvnt) = split(/-|:|\ /,$dateEvnt);
my $secEvnt  = $cgi->param('secondeEvenement');
   $secEvnt  = sprintf("%05.2f",$secEvnt);
   $secEvnt  =~ s/,/\./;   # because of potential coma as decimal separator with printf
my $typeEvnt = $cgi->param('typeEvenement');
my $arrivee  = $cgi->param('arriveeUnique');
my $dureeEvnt = $cgi->param('dureeEvenement');
my $uniteEvnt = $cgi->param('uniteEvenement');
my $dureeSatEvnt = $cgi->param('saturationEvenement');
my $amplitudeEvnt = $cgi->param('amplitudeEvenement');
my $stationEvnt = $cgi->param('stationEvenement');
my ($netEvnt,$staEvnt,$chaEvnt,$locEvnt) = split(/\./,$stationEvnt);
my $comment  = $cgi->param('commentEvenement');
my $impression = $cgi->param('impression');
my $replay   = $cgi->param('replay');
my $dateCourante=$anneeEvnt."-".$moisEvnt."-".$jourEvnt;
my $nbrEvnt  =  $cgi->param('nombreEvenement');
my $smoinsp  =  $cgi->param('smoinsp');
my $imageSEFRAN =  $cgi->param('imageSEFRAN');
my $newSC3   = $cgi->param('newSC3event') // 0;

# compatibility with MC2
my $idSC3     = $cgi->param('files');
my $fileNameSUDS = $cgi->param('fileNameSUDS');
my $transfert = $cgi->param('transfert');

# ---- loads requested Sefran3 configuration or default one
$s3 ||= $WEBOBS{SEFRAN3_DEFAULT_NAME};
my %SEFRAN3 = readCfg("$WEBOBS{ROOT_CONF}/$s3.conf");

# ---- loads requested MC3 configuration file or default one
$mc3 ||= $WEBOBS{MC3_DEFAULT_NAME};
my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");

# ------------------------------------------------------------------
# !!!!!!!!!!!!!!  MC3 non-blocking LOCK !!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ------------------------------------------------------------------
my $lockFile = "/tmp/.$mc3.lock";
if (-e $lockFile) {
	my $lockWho = qx(cat $lockFile | xargs echo -n);
	die "$__{'File is currently being edited'} $__{'by'} $lockWho ...";
} else {
	my $retLock = qx(echo "$operator" > $lockFile);
}

# ---- starts HTML page display
# ------------------------------------------------------------------
print $cgi->header(-type=>"text/html;charset=utf-8"),
      $cgi->start_html("Editing $MC3{TITLE}");
print "<BODY>";
print $cgi->h2("Editing $MC3{TITLE}");

# calculates number of minute-images that include signal
#
my @durations = readCfgFile("$MC3{DURATIONS_CONF}");
my ($key,$nam,$val) = split(/\|/,join('',grep(/^$uniteEvnt/,@durations)));
my $nb_images = int(($dureeEvnt*$val + $secEvnt)/60 + 1);
if ($nb_images > $MC3{IMAGES_MAX_CAT}) {
	$nb_images = $MC3{IMAGES_MAX_CAT};
}

# full path filename MC
#
my $mc_filename = "$MC3{ROOT}/$anneeEvnt/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$anneeEvnt$moisEvnt.txt";

# MC image filename (to be saved)
# NOTE: overwrite possible $imageSEFRAN value (in case of date/time event modification)
#
$imageSEFRAN = sprintf("%4d%02d%02d%02d%02d%02.0f.png",$anneeEvnt,$moisEvnt,$jourEvnt,$heureEvnt,$minEvnt,$secEvnt);
#FB-was: my $imageMC = "$MC3{ROOT}/$anneeEvnt/$MC3{PATH_IMAGES}/$anneeEvnt$moisEvnt/$MC3{FILE_PREFIX}$imageSEFRAN";
my $imageMC = "$MC3{ROOT}/$anneeEvnt/$MC3{PATH_IMAGES}/$anneeEvnt$moisEvnt/$imageSEFRAN";

# if MC file exists, back it up
#
my @lignes;
if (-s $mc_filename)  {

	# Read current file
	print "<P><B>Existing file:</B> $mc_filename ...";
	open(my $mcfile, "<$mc_filename") || Quit($lockFile,"$__{'Could not open'} $mc_filename\n");
	while(<$mcfile>) {
		chomp;
		push(@lignes, $_) if $_;
	}
	close($mcfile);
	print "imported.</P>";

	# Write to backup file
	# Note: writing to a file is quickier than loading File::Copy in a CGI mode.
	my $mc_bak_filename = $mc_filename.".backup";
	open(my $mcfile_bak, ">$mc_bak_filename") || Quit($lockFile,"$__{'Could not create'} $mc_bak_filename\n");
	{
		# Use a block to locally modify $, and $\ in order to re-add a newline
		# respectively after each line and at the end of the list.
		$, = $\ = "\n";
		print $mcfile_bak @lignes;
	}
	close($mcfile_bak);
	print "<P><B>Backup file:</B> $mc_bak_filename</P>\n";

} else {

	qx(mkdir -p -m 775 `dirname $mc_filename`);
	open(my $mcfile, ">$mc_filename") || Quit($lockFile,"$__{'Could not create'} $mc_filename\n");
	print $mcfile ("");
	close($mcfile);
}

my $id_evt;

# case A) existing event (modification or delete): reads all but concerned ID
#
if ($id_evt_modif) {
	# Get the event from @lignes
	my @ligne = grep { /^$id_evt_modif\|/ } @lignes;
	# Remove the event from @lignes
	@lignes = grep { $_ !~ /^$id_evt_modif\|/ } @lignes;
	if ($delete > 0) {
		# move to / remove from trash: change sign of ID value
		$id_evt = -($id_evt_modif);
		print "<P><B>Delete/recover existing event (in/from trash):</B> $id_evt</P>";
	} else {
		$id_evt = $id_evt_modif;
		print "<P><B>Modifying existing event:</B> $id_evt</P>";
		# read existing line
		my @line_values = split(/\|/,@ligne[0]);
		@image_list = split(/,/,@line_values[14]);
		# check if previous image was at the same minute
		my $idx = first { substr($imageSEFRAN,0,-6) eq substr($image_list[$_],0,-6) } 0..$#image_list;
		if(defined $idx) {
			# if found, update image name
			splice(@image_list,$idx,1,$imageSEFRAN);
		}
		else {
			# otherwise, add to the list
			my @new_image_list = $imageSEFRAN;
			push(@new_image_list, @image_list);
			@image_list = @new_image_list;
		}
	}
# case B) new event: reads all and compute next ID
#
} else {
	my $max = 0;
	foreach (@lignes) {
		# Only consider lines starting with a (possibly negative) numeric id
		if (/^\-?(\d+)\|/) {
			$max = $1  if ($1 > $max);
		}
	}
	$id_evt = $max + 1;
	print "<P><B>New event:</B> $id_evt</P>";
	@image_list = $imageSEFRAN;
}

# In case of add/modify/trash: new data line is written, in other case definitive delete
#
if ($delete < 2) {
	my $timestamp = strftime "%Y%m%dT%H%M%S", gmtime;
	my $chaine = "$id_evt|$anneeEvnt-$moisEvnt-$jourEvnt|$heureEvnt:$minEvnt:$secEvnt"
		."|$typeEvnt|$amplitudeEvnt|$dureeEvnt|$uniteEvnt|$dureeSatEvnt|$nbrEvnt|$smoinsp|$stationEvnt|$arrivee"
		."|$fileNameSUDS|$idSC3|".join(',', @image_list)."|$operator/$timestamp|$comment";
	push(@lignes, u2l($chaine));
}

# Create the new file
# chronological sort is needed to make faster display of Sefran3
@lignes = sort tri_date_avec_id (@lignes);

open(my $mcfile, ">$mc_filename") || Quit($lockFile,"$mc_filename $__{'not found'}\n");
{
	# Use a block to locally modify $, and $\ in order to re-add a newline
	# respectively after each line and at the end of the list.
	$, = $\ = "\n";
	print $mcfile @lignes;
}
close($mcfile);

my $retCHMOD = qx (/bin/chmod 664 $mc_filename);

# ------------------------------------------------------------------
# !!!!!!!!!!!!!!  MC3 unlock            !!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ------------------------------------------------------------------
if (-e $lockFile) {
	unlink $lockFile;
} else {
	print $cgi->b("$__{'unlink lockfile error'} $lockFile !"),"<br>";
}

# prepare new SeisComP event

my $newQML;
if ($newSC3 > 0) {
	print "<P>Creating a new SC3 ID...</P>";

	$newQML = "<?xml version=\"1.0\"?><!DOCTYPE WO2SC3 SYSTEM \"wo2sc3.dtd\">
	<webObs>
		<moduleDescription>
			<id>$MC3{WO2SC3_MOD_ID}</id>
			<type>$MC3{WO2SC3_MOD_TYPE}</type>
		</moduleDescription>
		<eventDescription>
			<mcid>$mc3/$anneeEvnt$moisEvnt/$id_evt</mcid>
			<date>$anneeEvnt/$moisEvnt/$jourEvnt</date>
			<time>$heureEvnt:$minEvnt:$secEvnt</time>
			<station>$staEvnt</station>
			<network>$netEvnt</network>
			<duration>$dureeEvnt</duration>
			<sminusp>$smoinsp</sminusp>
			<amplitude>$amplitudeEvnt</amplitude>
			<operator>$operator</operator>
			<type>$typeEvnt</type>
			<comment>$comment</comment>
		</eventDescription>
	</webObs>";
}


# Prepare the text for print
# - - - - - - - - - - - - - - - - - - - - - - - - -
my $signalSature = $amplitudeEvnt;
if ($dureeSatEvnt > 0) {
	$signalSature = "Sature ($dureeSatEvnt s)";
}

my $err = 0;
my $textePourImage = "$anneeEvnt-$moisEvnt-$jourEvnt $heureEvnt:$minEvnt:$secEvnt ($operator) $typeEvnt ($dureeEvnt $uniteEvnt) $stationEvnt $signalSature - $comment";

# search for image files
# - - - - - - - - - - - - - - - - - - - - - - - - -

if ($delete == 2) {
	print "<p><b>Erase image(s)/b>... ";
  for (@image_list) {
    my $imgMC = "$MC3{ROOT}/$anneeEvnt/$MC3{PATH_IMAGES}/$anneeEvnt$moisEvnt/$_";
    qx(rm -f $imgMC);
  }
	print "Done.</p>";
} else {
	print '<p><b>Looking for images to be concatenated</b>...<UL> ';

	my @imagesPNG;
	my $voies;
	my $i;
	for ($i = 0; $i < $nb_images; $i++) {
		my ($Y,$m,$d,$H,$M) = split('/',qx(date -d '$dateEvnt $i minute' +"%Y/%m/%d/%H/%M"|xargs echo -n));
		my $f = sprintf("%s/%4d/%04d%02d%02d/%s/%04d%02d%02d%02d%02d00.png",$SEFRAN3{ROOT},$Y,$Y,$m,$d,$SEFRAN3{PATH_IMAGES_MINUTE},$Y,$m,$d,$H,$M);
		if (-f $f) {
			push(@imagesPNG,$f);
			print "<LI>$f</LI>\n";
		}
		if ($i == 0) {
			$voies = sprintf("%s/%4d/%04d%02d%02d/%s/%04d%02d%02d%02d_voies.png",$SEFRAN3{ROOT},$Y,$Y,$m,$d,$SEFRAN3{PATH_IMAGES_HEADER},$Y,$m,$d,$H);
		}
	}

	print '</UL>Done.</p>';

	# Concatenation and tag of images
	if (scalar(@imagesPNG)) {
		print '<p><b>Concatenating images</b>... ';
		qx(mkdir -p `dirname $imageMC`);
		my $cmd = "$WEBOBS{PRGM_CONVERT} +append $voies ".join(" ",@imagesPNG)." $imageMC";
		(system($cmd) == 0) or $err=1;
		# adds meta-data...
		my $tag = " -set mc3:id '$id_evt'"
			 ." -set mc3:ymd '$anneeEvnt-$moisEvnt-$jourEvnt'"
			 ." -set mc3:hms '$heureEvnt:$minEvnt:$secEvnt'"
			 ." -set mc3:type '$typeEvnt'"
			 ." -set mc3:amplitude '$amplitudeEvnt'"
			 ." -set mc3:duration '$dureeEvnt'"
			 ." -set mc3:unit '$uniteEvnt'"
			 ." -set mc3:saturation '$dureeSatEvnt'"
			 ." -set mc3:number '$nbrEvnt'"
			 ." -set mc3:sminusp '$smoinsp'"
			 ." -set mc3:station '$stationEvnt'"
			 ." -set mc3:unique '$arrivee'"
			 ." -set mc3:source '$fileNameSUDS'"
			 ." -set mc3:eventid '$idSC3'"
			 ." -set mc3:image '$imageSEFRAN'"
			 ." -set mc3:operator '$operator'";
			 #." -set MC3_comment '$comment'";
		$cmd = "$WEBOBS{PRGM_CONVERT} $imageMC $tag $imageMC";
		system($cmd);
		# processes the comment independently (because of potential problem with content)
		$comment =~ s/%/%%/g;
		$comment =~ s/"/\\"/g;
		$cmd = "$WEBOBS{PRGM_CONVERT} $imageMC -set mc3:comment \"$comment\" $imageMC";
		system($cmd);
		print 'Done.</p>';
		print "<P><B>Image saved as:</B> $imageMC</P>";


		if ($impression) {
			print '<p><b>Printing</b>... ';
			print qx($WEBOBS{ROOT_CODE}/shells/impression_image "$MC3{PRINTER}" "$imageMC" "$textePourImage");
			print 'Done.</p>';
		}
	}
}

# - - - - - - - - - - - - - - - - - - - - - - - - -
if ($err == 0) {
	print "<script language=\"javascript\">";
		print "window.opener.location.reload();";
	if ($replay) {
		print "window.location='/cgi-bin/$WEBOBS{CGI_SEFRAN3}?date=$date&replay=$id_evt';";
	} else {
		# for Firefox: opens a "false" window to be allowed to close it...
		print "window.open('','_parent','');window.close();";
	}
	print "</script>\n";
} else {
	print $cgi->h3("Error occured !");
}

print $cgi->end_html();


# --- Send the new event to TCP socket

print STDERR "** newSC3 = $newSC3 **\n";
print STDERR "** PeerHost => $MC3{WO2SC3_HOSTNAME}, PeerPort => $MC3{WO2SC3_PORT} **\n";
if ($newSC3 > 0) {
	# flush after every write
	$| = 1;

	my ($socket,$client_socket);

	# creating object interface of IO::Socket::INET modules which internally creates
	# socket, binds and connects to the TCP server running on the specific port.
	$socket = new IO::Socket::INET (
		PeerHost => $MC3{WO2SC3_HOSTNAME},
		PeerPort => $MC3{WO2SC3_PORT},
		Proto => 'tcp',
	) or print STDERR "ERROR in Socket Creation : $!\n";

	#print "TCP Connection Success.\n";

	# read the socket data sent by server.
	#$data = <$socket>;
	# we can also read from socket through recv()  in IO::Socket::INET
	# $socket->recv($data,1024);
	#print "Received from Server : $data\n";

	# write on the socket to server.
	#print $socket "$newQML\n";
	# we can also send the data through IO::Socket::INET module,
	if ($socket) {
		$socket->send($newQML);
		#sleep (10);
		$socket->close();
	}

}

# ---------------------------------------------------------------------
sub Quit
{
	if (-e $_[0]) {
		unlink $_[0];
	}
	die "WEBOBS: $_[1]";
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

Acknowledgments:

traitementMC2.pl [2004-2009] by Didier Mallarinio, Francois Beauducel and Alexis Bosson

afficheSEFRAN.pl [2009] by Alexis Bosson and Francois Beauducel

frameMC2.pl and formulaireMC2.pl [2004-2009] by Didier Mallarino, Francois Beauducel and Alexis Bosson

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
