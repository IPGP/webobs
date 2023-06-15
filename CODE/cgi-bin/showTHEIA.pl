#!/usr/bin/perl -w

=head1 NAME

showTHEIA.pl

=head1 SYNOPSIS

http://..../showTHEIA.pl

=head1 DESCRIPTION

Displays data associated to a producer.

A producer is associated to datasets which are associated to observations.

All known data associated to the producer are shown and can be edited to be send towards the Theia|OZCAR pivot model.

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use Image::Info qw(image_info dim);
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use POSIX qw(locale_h);
use locale;
use JSON;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::i18n;

# ---- display database-related text content
#print $cgi->header( -type => 'text/plain', -status => '200' );

# ---- connecting to the database
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;

#$dbh->disconnect();

# ---- display HTML content
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

# ---- JS content and functions
print <<"FIN";
<html><head>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link href="/css/wolb.css" rel="stylesheet" />
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript"></script>

<meta http-equiv="content-type" content="text/html; charset=utf-8">
</head>
<body>
<form action="/cgi-bin/postTHEIA.pl" id="formTHEIA" method="post">
FIN

# ---- start of producer table ----------------------------------------------------
#

# ---- extracting producer data
my $stmt = qq(SELECT * FROM producer;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}


print "<TABLE style=\"background: white;\" width=\"100%\">";
print "<TR><TH valign=\"middle\" width=\"5%\">Producer</TH>";
print "<TD colspan=\"2\">";
print "<TABLE width=\"100%\"><TR>"
		."<TH><SMALL>Identifier</SMALL></TH>"
		."<TH><SMALL>Name</SMALL></TH>"
		."<TH><SMALL>Title</SMALL></TH>"
		."<TH><SMALL>Description</SMALL></TH>"
		."<TH><SMALL>Objective</SMALL></TH>"
		."<TH><SMALL>Measured variables</SMALL></TH>"
		."<TH><SMALL>Email</SMALL></TH>"
		."<TH><SMALL>Contacts</SMALL></TH>"
		."<TH><SMALL>Funders</SMALL></TH>"
		."<TH><SMALL>Online resource</SMALL></TH></TR>";
		
my $contacts;
my $funders;
my $onlineRes;
		
while(my @row = $sth->fetchrow_array()) {
	$contacts  = join(',',split(/_,/,$row[7]));
	$funders   = join(',',split(/_,/,$row[8]));
	$onlineRes = join(',',split(/_,/,$row[9]));
	print "<TR><TD width=3% align=center><SMALL><A href=\"/cgi-bin/gridsMgr.pl\">$row[0]</A>"
			."<p><input type=\"hidden\" name=\"producerId\" value=\"$row[0]\"></input></p></SMALL></TD>"
			."<TD width=4% align=center><SMALL>$row[1]"
			."<p><input type=\"hidden\" name=\"name\" value=\"$row[1]\"></input></p></SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[2]"
			."<p><input type=\"hidden\" name=\"title\" value=\"$row[2]\"></input></p></SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[3]"
			."<p><input type=\"hidden\" name=\"description\" value=\"$row[3]\"></input></p></SMALL></TD>"
			."<TD width=21% align=center><SMALL>$row[4]"
			."<p><input type=\"hidden\" name=\"objectives\" value=\"$row[4]\"></input></p></SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[5]"
			."<p><input type=\"hidden\" name=\"measuredVariables\" value=\"$row[5]\"></input></p></SMALL></TD>"
			."<TD width=5% align=center><SMALL>$row[6]"
			."<p><input type=\"hidden\" name=\"email\" value=\"$row[6]\"></input></p></SMALL></TD>"
			."<TD width=8% align=center><SMALL>$contacts"
			."<p><input type=\"hidden\" name=\"contacts\"></input></p></SMALL></TD>"
			."<TD width=8% align=center><SMALL>$funders"
			."<p><input type=\"hidden\" name=\"fundings\"></input></p></SMALL></TD>"
			."<TD width=10% align=center><SMALL>$onlineRes";
			#."<p><input type=\"hidden\" name=\"onlineRes\"></input></p></SMALL></TD></TR>";
};

print "</TABLE></TD>\n";
print "</TH></TABLE>\n";
print "<BR><BR>\n";

# ---- start the creation of the JSON object ----------------------------------------------------
#
# ---- extracting producer data

$stmt = qq(SELECT * FROM producer, contacts, organisations;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my %producer;

while( my @row = $sth->fetchrow_array() ) {
	# ---- parsing contacts
	my @contacts;
	foreach(split(/_,/, $row[7])) {
		my %contact = (
			firstName => $row[11],
			lastName => $row[12],
			email => (split ':',$_)[1],
			role => (split ':',$_)[0],
		);
		push(@contacts, \%contact)
	}
	# ---- parsing fundings
	my @fundings;
	foreach(split(/_,/, $row[8])) {
		my %funding = (
			type => (split ':',$_)[0],
			iso3166 => "fr",
			idScanR => (split ':',$_)[1],
		);
		push(@fundings, \%funding)
	}
=pod
	# ---- parsing online resources
	my @resources;
	foreach(split(/_,/, $row[9])) {
		my %resource = (
			email => (split ':',$_)[1],
			role => (split ':',$_)[0],
		);
		push(@resources, \%resource)
	}
=cut
	%producer = (
		producerId => $row[0],
		name => $row[1],
		title => $row[2],
		description => $row[3],
		#objectives => $row[4],
		#measuredVariables => $row[5],
		email => $row[6],
		contacts => \@contacts,
		fundings => \@fundings,
		#onlineResource => \@resources
	);
	if ($row[4] ne "") {
		$producer{'objectives'} = $row[4];
	}
	if ($row[5] ne "") {
		$producer{'measuredVariables'} = $row[5];
	}
}

#print to_json $producer{'fundings'};

# ---- start of datasets table ----------------------------------------------------
#
# ---- extracting datasets data
$stmt = qq(SELECT * FROM datasets;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

print "<TABLE style=\"background: white;\" width=\"100%\">";
print "<TR><TH valign=\"middle\" width=\"5%\">Datasets</A></TH>";
print "<TD colspan=\"2\" style=\"display:block\">";
print "<TABLE width=\"100%\" style=\"margin:auto\"><TR>"
		."<TH><SMALL>Identifier</SMALL></TH>"
		."<TH valign=\"top\"><SMALL>Title</SMALL></TH>"
		."<TH><SMALL>Description</SMALL></TH>"
		."<TH><SMALL>Subject</SMALL></TH>"
		."<TH><SMALL>Creator</SMALL></TH>"
		."<TH><SMALL>Spatial coverage</SMALL></TH>"
		."<TH><SMALL>Provenance</SMALL></TH></TR>";

while(my @row = $sth->fetchrow_array()){
	my $nodeId  = (split '\.', $row[0]) [1];
	my $proc    = (split '_', (split '\.', $row[0]) [0]) [2];
	my $subject = join(',', split(/_/,$row[3]));
	print "<TR><TD width=15% align=center><SMALL><A href=\"/cgi-bin/formNODE.pl?node=PROC.$proc.$nodeId\">$row[0]</A></SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[1]</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[2]</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$subject</SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[4]</SMALL></TD>"
			."<TD width=12% align=center><SMALL>".substr($row[5], 0, 100)."</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[6]</SMALL></TD></TR>";
};

print "</TABLE></TD>\n";
print "</TR></TABLE>\n";
print "<BR><BR>\n";

#print encode_json \@datasets;

# ---- start of datasets table ----------------------------------------------------
#
# ---- extracting observations data
$stmt = qq(SELECT * FROM observations;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

print "<TABLE style=\"background: white;\" width=\"100%\">";
print "<TR><TH valign=\"middle\" width=\"5%\">Observations</TH>";
print "<TD colspan=\"2\" style=\"display:block\">";
print "<TABLE width=\"100%\" style=\"margin:auto\"><TR>"
		."<TH><SMALL>Identifier</SMALL></TH>"
		."<TH><SMALL>Processing level</SMALL></TH>"
		."<TH><SMALL>Data type</SMALL></TH>"
		."<TH><SMALL>Temporal extent</SMALL></TH>"
		."<TH><SMALL>Time series</SMALL></TH>"
		."<TH><SMALL>Observed property</SMALL></TH>"
		."<TH><SMALL>Station name</SMALL></TH>"
		."<TH><SMALL>Dataset</SMALL></TH>"
		."<TH><SMALL>Data file name</SMALL></TH></TR>";

while(my @row = $sth->fetchrow_array()){
	my $nodeId  = (split '_', (split '\.', $row[0]) [1]) [0];
	my $proc    = (split '_', (split '\.', $row[0]) [0]) [2];
	my $subject = join(',', split(/_/,$row[3]));
	print "<TR><TD width=12% align=center><SMALL><A href=\"/cgi-bin/formCLB.pl?node=PROC.$proc.$nodeId\">$row[0]</A></SMALL></TD>"
			."<TD width=6% align=center><SMALL>$row[1]</SMALL></TD>"
			."<TD width=6% align=center><SMALL>$row[2]</SMALL></TD>"
			."<TD width=12% align=center><SMALL>$row[3]</SMALL></TD>"
			."<TD width=4% align=center><SMALL>$row[4]</SMALL></TD>"
			."<TD width=8% align=center><SMALL>$row[5]</SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[6]</SMALL></TD>"
			."<TD width=12% align=center><SMALL>$row[7]</SMALL></TD>"
			."<TD width=8% align=center><SMALL>$row[8]</SMALL></TD></TR>";
};

# ---- start the creation of the JSON object ----------------------------------------------------
#
# ---- extracting observed_properties data

$stmt = qq(SELECT * FROM observations, observed_properties, sampling_features GROUP BY observations.identifier;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my @observations;

while( my @row = $sth->fetchrow_array() ) {
	# ---- data from observed_properties table
	my %observedProperty = (
		name => $row[10],
		unit => $row[11],
	);
	my @theiaCategories;
	foreach (split(',',$row[12])) {
		$_ =~ s/(\n)//g;
		push(@theiaCategories, $_);
	}
	$observedProperty{"theiaCategories"} = \@theiaCategories;

	#print $observation{'observedProperty'}{'theiaCategories'}->[0];
	# ---- data from sampling_features table
	my $geometry = (split ':', $row[$#row])[1];
	my $position = (split '\(|\)', $geometry)[1];
	my @coordinates = split(',', $position);
	$coordinates[0] = $coordinates[0] + 0;
	$coordinates[1] = $coordinates[1] + 0;
	my %geometry = (
		type => (split '\(|\)', $geometry)[0],
		coordinates => \@coordinates,
	);
	my %samplingFeature = (
		name => $row[6],
		geometry => \%geometry,
		type => "Feature",
		properties => {}
	);
	my %featureOfInterest = (
		samplingFeature => \%samplingFeature,
	);
	
	my %datafile = (
		name => $row[8],
	);
	my %result = (
		dataFile => \%datafile,
	);
	
	my %temporalExtent = (
		dateBeg => (split '/', $row[3])[0],
		dateEnd => (split '/', $row[3])[1],
	);
	
	my %observation = (
		observationId => $row[0],
		observedProperty => \%observedProperty,
		featureOfInterest => \%featureOfInterest,
		result => \%result,
		dataType => $row[2],
		timeSerie => \1,
		temporalExtent => \%temporalExtent,
		processingLevel => $row[1],
	);
	push(@observations, \%observation);
}

# ---- extracting datasets data

$stmt = qq(SELECT * FROM datasets;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my @datasets;

while( my @row = $sth->fetchrow_array() ) {
	my @contacts;
	foreach(split('_,',$row[4])) {
		my %contact = (
			firstName => "first",
			lastName  => "last",
			email => (split ':',$_)[1],
			role => (split ':',$_)[0],
		);
		push(@contacts, \%contact);
	}
	my $topicCategories = (split '_',$row[3])[0];
	my @topicCategories;
	foreach(split('_,',$topicCategories)){
		my $category = (split(':',$_))[1];
		$category =~ s/(\r\n)//g;
		push(@topicCategories,$category);
	}
	my %geometry = (
		type => JSON->new->utf8->decode($row[$#row-1])->{'type'},
		coordinates => JSON->new->utf8->decode($row[$#row-1])->{'coordinates'}
	);
	my %spatialExtent = (
		type => "Feature",
		properties => {},
		geometry => \%geometry,
	);
	# print JSON->new->utf8->decode($row[$#row-1])->{'type'};
	my %dataConstraint = (
		accessUseConstraint => "No conditions to access and use",
	);
	my %metadata = (
		title => $row[1],
		description => (split ':', $row[2])[1],
		datasetLineage => "datasetLineage",
		contacts => \@contacts,
		dataConstraint => \%dataConstraint,
		topicCategories => \@topicCategories,
		inspireTheme => (split '_inspireTheme:', $row[3])[1],
		spatialExtent => \%spatialExtent,
	);
	$metadata{'inspireTheme'} =~ s/(\r\n)//g;
	my %dataset = (
		datasetId => $row[0],
		metadata => \%metadata,
	);
	
	my @ds_obs;
	foreach(@observations) {
		if ($_>{'observationId'} =~ /$row[0]/){
			#print encode_json $_;
			push(@ds_obs, $_);
		}
	}
	#print encode_json $ds_obs[0];
	$dataset{'observations'} = \@ds_obs;
	push(@datasets, \%dataset);
}

#print encode_json \@datasets;

my %json = (
	producer => \%producer,
	datasets => \@datasets,
	version => "1.0",
);

my $filename = '/opt/webobs/CONF/file.json';
chmod 0755, $filename;
open(FH, '>', $filename) or die $!;

print FH encode_json \%json;

close(FH);

#print $observations[1]{'featureOfInterest'}{'samplingFeature'}{'geometry'}{'coordinates'};

print "</TABLE></TD>\n";
print "</TR></TABLE>\n";
print "<BR><BR>\n";

print <<"FIN";
<script>
	let text = \'{\"versions\" : \"1.0\", \"producer\" : {}, \"datasets\" : []}\';
	
	const obj = JSON.parse(text);
	//console.log(obj);

	function getFormData(\$form){
		var unindexed_array = \$form.serializeArray();
		var indexed_array = {};

		\$.map(unindexed_array, function(n, i){
		    indexed_array[n['name']] = n['value'];
		});

		return indexed_array;
	}
	
	function contactJSON(lists){
		var new_lists = [];
		lists.split(",").forEach(function(item){
			var sep_list = item.split(":");
			var obj = {email: sep_list[1], role: sep_list[0]}
			new_lists.push(obj)
		});
		return new_lists;
	}

	function funderJSON(lists){
		var new_lists = [];
		lists.split(",").forEach(function(item){
			var sep_list = item.split(":");
			var obj = {type: sep_list[0], idScanR: sep_list[1]}
			new_lists.push(obj)
		});
		return new_lists;
	}
	
	function createOBS(\$form) {
		console.log(\$form)
	}

	var \$form = \$("#formTHEIA");
	var data = getFormData(\$form);
	
	obj.producer = data
	obj.producer.contacts = contactJSON(\"$contacts\");
	obj.producer.fundings = funderJSON(\"$funders\");
	//console.log(obj.producer.contacts);

	// var formData = \$(\"#formTHEIA\").serialize();
	// console.log(formData);
	
	createOBS(\$form);
</script>
FIN

print "<p><input type=\"submit\" onclick=\"return false;\" name=\"valider\" value=\"Valider\"></p>";
print "</form>";
