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

print CGI::header(); ## for the print in HTML

# ---- init
#
my $me = $ENV{SCRIPT_NAME}; 
my $QryParm   = $cgi->Vars;
my $node   = $QryParm->{'node'}       // "";

my @NID = split(/[\.\/]/, trim($QryParm->{'node'}));

my $GRIDName = my $GRIDType = my $NODEName = "";
my %S;
my %NODE;

my $outfile ="";
my $outdir ="";


# ---- see what file has to be edited, and corresponding authorization for client
#
if (scalar(@NID) == 3) { 
	($GRIDType, $GRIDName, $NODEName) = @NID;
	my %S = readNode($NODEName);
	%NODE = %{$S{$NODEName}};
	
	print($ENV{M3G_EXPORTXML});
	
	my $m3g_url_gml = $WEBOBS{'M3G_EXPORTXML'}.$NODE{GNSS_9CHAR};

	### attempt to get the final local filename
	# my $m3g_url_log = "https://gnss-metadata.eu/sitelog/exportlog?station=".$NODE{GNSS_9CHAR};
	# my $response = HTTP::Tiny->new->get($m3g_url_gml);
	# print($m3g_url_log);
	# print($response->{'headers'}->{'content-disposition'});
		
	my $ff = File::Fetch->new(uri => $m3g_url_gml);
	$outdir = "$NODES{PATH_NODES}/$NODEName/";
	my $outfile = $ff->fetch( to => $outdir );
	
	if ($ff->error)
	{
		print "Something went wrong when downloading \n";
		print($m3g_url_gml);
		print "<form> <input type='button' value='Go back' onclick='history.back()'> </form>";
	} else {
		my $outfileok = $outdir . $NODE{GNSS_9CHAR} . '.xml';
		rename($outfile , $outfileok) or die ( "Error in renaming $outfile to $outfileok" );
	
		print "Metadata have been correctly downloaded in $outfileok";
		print($ENV{M3G_EXPORTXML});
		print "<form> <input type='button' value='Go back' onclick='history.back()'> </form>";
	}
	
} else { 
	die "$__{'Not a fully qualified node name (gridtype.gridname.nodename)'}" 
	}

