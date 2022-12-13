#!/usr/bin/perl 

use strict;
use warnings;
use File::Basename;
use File::Fetch;
#use MIME::Head;
use HTTP::Tiny;

use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

## ---- webobs stuff ----------------------------------
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

print CGI::header();
print "Hello World";

# ---- init
#
my @lignes;

my $me = $ENV{SCRIPT_NAME}; 
my $QryParm   = $cgi->Vars;
my $node   = $QryParm->{'node'}       // "";
my $file   = $QryParm->{'file'}       // "";
my $action = $QryParm->{'action'}     // "edit";
my $txt    = $QryParm->{'txt'}        // "";
my $TS0    = $QryParm->{'ts0'}        // "";
my $metain = $QryParm->{'meta'}       // "";
my $conv   = $cgi->param('conv')      // "0";
my $encode = $cgi->param('encode')  // "utf8";
my $gmlfile = $cgi->param('gmlfile')  // "utf8";
my $gmlfeat = $cgi->param('gmlfeat')  // "utf8";

$txt = "$metain$txt";
my @NID = split(/[\.\/]/, trim($QryParm->{'node'}));

my $GRIDName = my $GRIDType = my $NODEName = "";
my $outfile ="";
my $outdir ="";
my $editOK = my $admOK = 0;
my $mmd = $WEBOBS{WIKI_MMD} // 'YES';
my $MDMeta = ($mmd ne 'NO') ? "WebObs: created by nedit  " : "";
my %NODE;


# ---- see what file has to be edited, and corresponding authorization for client
#
if (scalar(@NID) == 3) { 
	($GRIDType, $GRIDName, $NODEName) = @NID;
	my %S = readNode($NODEName);
	%NODE = %{$S{$NODEName}};
	
	my $m3g_url_gml = "https://gnss-metadata.eu/sitelog/exportxml?station=".$NODE{GNSS_9CHAR};

	### attempt to get the final filename
	# my $m3g_url_log = "https://gnss-metadata.eu/sitelog/exportlog?station=".$NODE{GNSS_9CHAR};
	# my $response = HTTP::Tiny->new->get($m3g_url_gml);
	# print($m3g_url_log);
	# print($response->{'headers'}->{'content-disposition'});
		
	my $ff = File::Fetch->new(uri => $m3g_url_gml);
	$outdir = "$NODES{PATH_NODES}/$NODEName/";
	my $outfile = $ff->fetch( to => $outdir ) or die $ff->error;
	
	rename($outfile , $outdir . $NODE{GNSS_9CHAR} . '.xml') or die ( "Error in renaming" );
	
	#### !!!!! Implement here the EXCEPTION handeling and a backup copy !!!!!!
#	} else { die "$__{'No filename specified'}" }
} else { die "$__{'Not a fully qualified node name (gridtype.gridname.nodename)'}" }

