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
use POSIX qw/strftime/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use JSON;
use Encode qw(decode encode);
use feature 'say';
use File::Path qw(mkpath);
use IO::Compress::Zip qw(zip $ZipError) ;
use File::Glob ':glob';

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::i18n;

my $today = strftime("%Y-%m-%d\T%H:%M:%S\Z", localtime);

# ---- connecting to the database
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;

# ---- local functions
#

# Return information when OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
}

# Return information when not OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

# Compress $dir's files into $zipfile without the whole path in the compress archive
sub compressTxtFiles {
    my $dataset = shift ;
    my $NODEName = (split /\./, $dataset)[1];
    my $dir     = shift ;
    zip [ <$dir/*$NODEName*.txt> ] => "$dir/$dataset.zip",
        FilterName => sub { s[^$dir/][] } ;
}

# ---- creating tmp directory to stock files
my $dir = "$WEBOBS{PATH_TMP_WEBOBS}/theia";
mkpath($dir);
my @zip_files;

# ---- start the creation of the JSON object ----------------------------------------------------
#
# ---- extracting producer data

my $stmt = qq(SELECT * FROM producer INNER JOIN contacts ON producer.identifier = contacts.related_id);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my %producer;

while( my @row = $sth->fetchrow_array() ) {
	%producer = (
		producerId => $row[0],
		name => decode("utf8",$row[1]),
		title => decode("utf8",$row[2]),
		description => decode("utf8",$row[3]),
		email => $row[6]
	);
	if ($row[4] ne "") {
		$producer{'objectives'} = decode("utf8",$row[4]);
	}
	if ($row[5] ne "") {
		$producer{'measuredVariables'} = decode("utf8",$row[5]);
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
		name => decode("utf8",$row[3]),
		acronym => $row[2],
	);
	push(@fundings, \%funding);
}
$producer{'fundings'} = \@fundings;

#print to_json $producer{'fundings'};

# ---- extracting observations data

$stmt = qq(SELECT * FROM observations, sampling_features INNER JOIN observed_properties ON observations.observedproperty = observed_properties.identifier GROUP BY observations.identifier);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my @observations;

while( my @row = $sth->fetchrow_array() ) {
	# ---- data from observed_properties table
	my %observedProperty = (
		name => decode("utf8",$row[13]),
		unit => decode("utf8", $row[14])
	);

	my @theiaCategories;
	foreach (split(',',$row[15])) {
		$_ =~ s/(\n)//g;
		push(@theiaCategories, $_);
	}
	$observedProperty{"theiaCategories"} = \@theiaCategories;

	#print $observation{'observedProperty'}{'theiaCategories'}->[0];
	# ---- data from sampling_features table
	# ---- parsing coordinates
	my $geometry = (split ':', $row[11])[1];
	my $position = (split '\(|\)', $geometry)[1];
	my @coordinates = split(',', $position);
	$coordinates[0] = $coordinates[0] + 0;
	my $lat = $coordinates[0];
	$coordinates[1] = $coordinates[1] + 0;
	my $lon = $coordinates[1];
	$coordinates[2] = $coordinates[2] + 0;
	my $alt = $coordinates[2];
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
	
	my $GRIDType = 'PROC';
	my $GRIDName = (split /\./,$row[6])[0];
	my $NODEName = (split /\./,$row[6])[1];
	my %datafile = (
		name => $producer{'producerId'}."_OBS_$GRIDName.$NODEName\_$observedProperty{'name'}.txt",
	);
	my %result = (
		dataFile => \%datafile,
	);
	
	# ---- now generating the .txt file
	my $dataname = $NODEName."_all.txt";
	my $filepath = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/exports/";
	my $chan_nb = 5 + $row[16];
	my $obsfile = "$dir/$datafile{'name'}";

	# ---- generating .txt files for the observed properties
	# ---- header
	my $header = "#Date_of_extraction;$today;\n";
	$header .= "#Observation_ID;$row[0];\n";
	$header .= "#Dataset_title;;\n";
	$header .= "#Variable_name;".$row[5].";\n";
	$header .= "dateBeg;dateEnd;latitude;longitude;altitude;value;qualityFlags;\n";
	# ---- content
	my $content = "grep -v '^#' $filepath$dataname | awk 'FS=\" \" {print \";\"\$1\"-\"\$2\"-\"\$3\"T\"\$4\":\"\$5\"Z\",\"$lat\",\"$lon\",\"$alt\",\$$chan_nb\";\"}' OFS=\";\"";
	$content = qx($content);
	$header .= $content;
	open(FILE, '>', $obsfile);
	print FILE $header;
	close(FILE);

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
		title => decode("utf8",$row[1]),
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
		my $obsId = (split /\./,$_->{'observationId'})[1];
		my $datId = (split /\./,$row[0])[1];
		if ($obsId =~ /$datId/) {
			push(@ds_obs, $_);
			my $filename = decode_json encode_json $_->{'result'}->{'dataFile'}->{'name'};
			# ---- adding the title dataset into $filename
			# ---- first we open $filename while creating a new $filename where we will write the line we want to insert
			open my $in,  '<',  "$dir/$filename"      or die "Can't read old file: $!";
			open my $out, '>', "$dir/$filename.new" or die "Can't write new file: $!";
			my $title = decode("utf8",$row[1]);
			while( <$in> ){
				s/Dataset_title;/Dataset_title;$title/;	# ---- changing Dataset_title instances with Dataset_title;dataset title;
				print $out $_;
			}
			
			close $in;
			close $out;
			
			rename "$dir/$filename.new", "$dir/$filename";
		}
	}

	#print encode_json $ds_obs[0];
	$dataset{'observations'} = \@ds_obs;
	push(@datasets, \%dataset);
	# ---- compressing observations files into OBSE_DAT_PROC.NODE.zip
	compressTxtFiles("$dataset{'datasetId'}",$dir)
		or die "zip failed: $ZipError\n";
}

#print encode_json \@datasets;

# ---- creating the final json object

my %json = (
	producer => \%producer,
	datasets => \@datasets,
	version => "1.0",
);

#$dbh->disconnect();

my $filename = "$json{'producer'}{'producerId'}_en.json";
my $filepath = "$dir/$filename";
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
my $output = "java -jar $WEBOBS{ROOT_CODE}/bin/java/JSON-schema-validation-0-jar-with-dependencies.jar ".$filepath;
#print qx($output);

if (qx($output) =~ /success/) {
	push(@zip_files, $filepath);
	my $zip_files = \@zip_files;
	my $zipfile   = "$producer{'producerId'}_THEIA.zip";
	zip [ <$dir/*DAT*.zip>, $filepath ] => "$dir/$zipfile",
        FilterName => sub { s[^$dir/][] }
        or die "zip failed: $ZipError\n" ;
	print "Content-Disposition: attachment; filename=\"$zipfile\";\nContent-type: application/zip\n\n";
	open(FH, '<',"$dir/$zipfile") or die $!;
	while(<FH>){
		print $_;
	}
	close(FH);
	#print "Content-Disposition: attachment; filename=\"$filename\";\nContent-type: text/json\n\n";
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
