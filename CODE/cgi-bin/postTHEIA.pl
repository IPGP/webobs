#!/usr/bin/perl -w

=head1 NAME

postNODE.pl

=head1 SYNOPSIS

http://..../postTHEIA.pl

=head1 DESCRIPTION

Process Theia|OCZAR Update from showTHEIA submitted info

=head1 Query string parameters

=cut

use strict;
use warnings;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use JSON;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::i18n;

# ---- connecting to the database
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
   
# ---- start the creation of the JSON object ----------------------------------------------------
#
# ---- extracting producer data

my $stmt = qq(SELECT * FROM producer, contacts, organisations;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

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

my $filename = "$WEBOBS{ROOT_CONF}/$json{'producer'}{'producerId'}_en.json";
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "The JSON metadata file has been successfully created at ".$filename." !";
chmod 0755, $filename;
open(FH, '>', $filename) or die $!;

print FH encode_json \%json;

close(FH);

#print $observations[1]{'featureOfInterest'}{'samplingFeature'}{'geometry'}{'coordinates'};
   
$dbh->disconnect();
