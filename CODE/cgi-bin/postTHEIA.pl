#!/usr/bin/perl -w

=head1 NAME

postNODE.pl

=head1 SYNOPSIS

http://..../postTHEIA.pl

=head1 DESCRIPTION

Create a JSON metadata file from the showTHEIA submitted informations.

=cut

use strict;
use warnings;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use JSON;
use Encode qw(decode encode);
use feature 'say';
use File::Temp qw/ tempfile tempdir /;
use File::Path qw(mkpath);

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

my $stmt = qq(SELECT * FROM producer);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my %producer;

while( my @row = $sth->fetchrow_array() ) {
	%producer = (
		producerId => $row[0],
		name => $row[1],
		title => $row[2],
		description => $row[3],
		email => $row[6]
	);
	if ($row[4] ne "") {
		$producer{'objectives'} = $row[4];
	}
	if ($row[5] ne "") {
		$producer{'measuredVariables'} = $row[5];
	}
	if ($row[9] ne "") {
    	# ---- parsing online resources
	    my %resource;
	    foreach(split(/_,/, $row[9])) {
		    my $typeUrl =(split '@',$_)[0];
		    my $url = (split '@',$_)[1];
		    if ($typeUrl =~ /download/) {
			    $resource{'urlDownload'} = $url;
		    } elsif ($typeUrl =~ /info/) {
			    $resource{'urlInfo'} = $url;
		    } elsif ($typeUrl =~ /doi/) {
			    $resource{'doi'} = $url;
		    }
	    }
	    $producer{'onlineResource'} = \%resource;
	}
	
	# ---- extracting contacts data

	my $stmt2 = qq(SELECT * FROM contacts;);
	my $sth2 = $dbh->prepare( $stmt2 );
	my $rv2 = $sth2->execute() or die $DBI::errstr;

	if($rv2 < 0) {
	   print $DBI::errstr;
	}
	
	my @contacts;
	
	while( my @row2 = $sth2->fetchrow_array() ) {
		if ($row2[4] eq $producer{'producerId'}) {
			# ---- parsing contacts
			my %contact = (
				firstName => decode("utf8",$row2[1]),
				lastName => decode("utf8",$row2[2]),
				email => $row2[0],
				role => $row2[3],
			);
			push(@contacts, \%contact);
		}
	}
	
	$producer{'contacts'} = \@contacts;
}

my $stmt = qq(SELECT * FROM organisations;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my @fundings;

while( my @row = $sth->fetchrow_array() ) {
	# ---- parsing fundings
	my %funding = (
		type => $row[0],
		iso3166 => $row[1],
		idScanR => $row[4],
		name => $row[3],
		acronym => $row[2],
	);
	push(@fundings, \%funding);
}
$producer{'fundings'} = \@fundings;

#print to_json $producer{'fundings'};

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
	# ---- parsing coordinates
	my $geometry = (split ':', $row[$#row])[1];
	my $position = (split '\(|\)', $geometry)[1];
	my @coordinates = split(',', $position);
	$coordinates[0] = $coordinates[0] + 0;
	$coordinates[1] = $coordinates[1] + 0;
	$coordinates[2] = $coordinates[2] + 0;
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

	my $topicCategories = (split '_',$row[3])[0];
	my @topicCategories;
	foreach(split('_,',$topicCategories)){
		my $category = (split(':',$_))[1];
		#$category =~ s/(\r\n)//g;
		push(@topicCategories,$category);
	}
	my %geometry = (
		type => JSON->new->utf8->decode($row[4])->{'type'},
		coordinates => JSON->new->utf8->decode($row[4])->{'coordinates'}
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
		description => $row[2],
		datasetLineage => $row[5],
		dataConstraint => \%dataConstraint,
		topicCategories => \@topicCategories,
		inspireTheme => (split '_inspireTheme:', $row[3])[1],
		spatialExtent => \%spatialExtent,
	);
	$metadata{'inspireTheme'} =~ s/(\r\n)//g;
	my %dataset = (
		datasetId => $row[0],
	);
	
	# ---- extracting contacts data

	my $stmt2 = qq(SELECT * FROM contacts;);
	my $sth2 = $dbh->prepare( $stmt2 );
	my $rv2 = $sth2->execute() or die $DBI::errstr;

	if($rv2 < 0) {
	   print $DBI::errstr;
	}
	
	my @contacts;
	
	while( my @row2 = $sth2->fetchrow_array() ) {
		if ($row2[4] eq $dataset{'datasetId'}) {
			# ---- parsing contacts
			my %contact = (
				firstName => decode("utf8",$row2[1]),
				lastName => decode("utf8",$row2[2]),
				email => $row2[0],
				role => $row2[3],
			);
			push(@contacts, \%contact);
		}
	}
	
	$metadata{'contacts'} = \@contacts;
	$dataset{'metadata'} = \%metadata;
	
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

# ---- creating the final json object

my %json = (
	producer => \%producer,
	datasets => \@datasets,
	version => "1.0",
);

#$dbh->disconnect();

my $dir = "$WEBOBS{PATH_TMP_WEBOBS}";
my $tempdir = tempdir();
mkpath("$dir$tempdir");
my $filename = "$json{'producer'}{'producerId'}_en.json";
my $filepath = "$dir$tempdir/$filename";
#print $cgi->header(-type=>'text/html',-charset=>'utf-8');
#print $filepath;
#print encode_json $json{'datasets'}->[0]{'metadata'}{'contacts'}; 
#print "\n";

chmod 0755, $filepath;
open(FH, '>', $filepath) or die $!;

print FH encode_json \%json;

close(FH);

#print encode_json \%json;
# ---- checking if the final json file is conform to the recommandations
my $output = "java -jar /home/lucas/Documents/donnees_webobs_obsera/JSON-schema-validation-0-jar-with-dependencies.jar ".$filepath;
#print qx($output);

if (qx($output) =~ /success/) {
	print "Content-Disposition: attachment; filename=\"$filename\";\nContent-type: text/json\n\n";
	print encode_json \%json;
} #elsif (qx($output) =~ /(not found|schema violations found|subschema)/) 
else {
	print $cgi->header(-type=>'text/html',-charset=>'utf-8');
	print "The JSON metadata file is not valid :\n".qx($output);
};

#print $observations[1]{'featureOfInterest'}{'samplingFeature'}{'geometry'}{'coordinates'};
   

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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
