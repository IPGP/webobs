#!/usr/bin/perl -w

=head1 NAME

sendTHEIA.pl

=head1 SYNOPSIS

$ perl sendTHEIA.pl

=head1 DESCRIPTION

Create a JSON metadata file according to the NODEs and CHANNELs names written in theia.rc with showTHEIA and postTHEIA.
JSON metadata are validated and sent with associated data to Theia/OZCAR server.

=cut

use strict;
use warnings;
use POSIX qw/strftime/;
use JSON;
use Encode qw(decode encode);
use File::Path qw(make_path rmtree);
use IO::Compress::Zip qw(zip $ZipError);
use Try::Tiny;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;

my $today = strftime("%Y-%m-%dT%H:%M:%SZ", localtime);
my $datedir = strftime("%Y%m%d\_%H%M%S", localtime);

my $filename = "$WEBOBS{CONF_THEIA}";
my %conf = readCfg($filename);
my @nodes = split(/,/, $conf{NODES});
my @channels = split(/,/, $conf{CHANNELS});
my $GRIDType = "PROC";  # grid type ("PROC" in the THEIA case use)

# ---- connecting to the database
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;

# ---- local functions
# Compress $tmpdir's files into $zipfile without the whole path in the compress archive
sub compressTxtFiles {
    my $dataset = shift;
    my $dataName = (split /\_/, $dataset)[-1];
    my $tmpdir   = shift;
    zip [ <$tmpdir/*$dataName\_*.txt> ] => "$tmpdir/$dataset.zip",
      FilterName => sub { s[^$tmpdir/][] };
}

# ---- creating tmp and exports/theia directories if required
my $tmpdir = "$WEBOBS{PATH_TMP_WEBOBS}/theia";
my $theiadir = "$WEBOBS{ROOT_OUTE}/theia/$datedir";

if ( ! -e $tmpdir ) {
    make_path($tmpdir, {chmod => 0775});
}
if ( ! -e $theiadir ) {
    make_path($theiadir, {chmod => 0775});
}

my $json_validator_path = "$WEBOBS{ROOT_CODE}/bin/java/JSON-schema-validation-0-jar-with-dependencies.jar";
if ( ! -e $json_validator_path ) {
    die "Please install $json_validator_path\n";
}

my @zip_files;
my $empty; # checking if empty ref or not

# ---- start the creation of the JSON object ----------------------------------------------------
#
# ---- extracting producer data

my $stmt = qq(SELECT * FROM producer INNER JOIN contacts ON producer.identifier = contacts.related_id);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

my %producer;

while( my @row = $sth->fetchrow_array() ) {
    %producer = (
        producerId => $row[0],
        name => decode("utf8", $row[1]),
        title => decode("utf8", $row[2]),
        description => decode("utf8", $row[3]),
        email => $row[6]
      );
    if ($row[4] ne "") {
        $producer{'objectives'} = decode("utf8", $row[4]);
    }
    if ($row[5] ne "") {
        $producer{'measuredVariables'} = decode("utf8", $row[5]);
    }
    if ($row[9] ne "") {
        # ---- parsing online resources
        my %resource;
        foreach(split(/_,/, $row[9])) {
            my $typeUrl =(split '@', $_)[0];
            my $url = (split '@', $_)[1];
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

    my @contacts;

    while( my @row2 = $sth2->fetchrow_array() ) {
        if ($row2[4] eq $producer{'producerId'}) {
            # ---- parsing contacts
            my %contact = (
                firstName => decode("utf8", $row2[1]),
                lastName => decode("utf8", $row2[2]),
                email => $row2[0],
                role => $row2[3],
              );
            push(@contacts, \%contact);
        }
    }

    $producer{'contacts'} = \@contacts;
}

$stmt = qq(SELECT * FROM organisations;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

my @fundings;

while( my @row = $sth->fetchrow_array() ) {
    # ---- parsing fundings
    my %funding = (
        type => $row[0],
        iso3166 => $row[1],
        idScanR => $row[4],
        name => decode("utf8", $row[3]),
        acronym => $row[2],
      );
    push(@fundings, \%funding);
}
$producer{'fundings'} = \@fundings;

#print to_json $producer{'fundings'};

# ---- extracting observations data

my @observations;

foreach (@channels) {
    print "$_\n";
    $stmt  = "SELECT * FROM observations ";
    $stmt .= "INNER JOIN sampling_features ON observations.stationname = sampling_features.identifier ";
    $stmt .= "INNER JOIN observed_properties ON observations.observedproperty = observed_properties.identifier";
    $stmt .= " WHERE observations.identifier = '$_'";
    $stmt  = qq($stmt);
    $sth   = $dbh->prepare( $stmt );
    $rv    = $sth->execute() or die $DBI::errstr;

    while( my @row = $sth->fetchrow_array() ) {
        # print "\n", join(" ", @row[0 .. $#row-6]), "\n";
        # ---- data from observed_properties table
        my %observedProperty = (
            name => decode("utf8", $row[13]),
            unit => decode("utf8", $row[14])
          );

        my @theiaCategories;
        foreach (split(',', $row[15])) {
            $_ =~ s/(\n)//g;
            push(@theiaCategories, $_);
        }
        $observedProperty{"theiaCategories"} = \@theiaCategories;

        # print $observation{'observedProperty'}{'theiaCategories'}->[0];
        # ---- data from sampling_features table
        # ---- parsing coordinates
        my $geometry = (split ':', $row[11])[1];
        my $position = (split '\(|\)', $geometry)[1];
        my @coordinates = split(',', $position);
        $coordinates[0] += 0;
        my $lat = $coordinates[0];
        $coordinates[1] += 0;
        my $lon = $coordinates[1];
        $coordinates[2] += 0;
        my $alt = $coordinates[2];

        my @new_crds = ($coordinates[1], $coordinates[0]);

        my %geometry = (
            type => (split '\(|\)', $geometry)[0],
            coordinates => \@new_crds,
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
        my $GRIDName = (split /\./, $row[6])[0];
        my $NODEName = (split /\./, $row[6])[1];
        my $timescale = (split /\_/, $row[8])[-1];
        $timescale = (split /\./, $timescale)[0];
        my %datafile = (
            name => $producer{'producerId'}."_OBS_$GRIDName.$NODEName\_$observedProperty{'name'}.txt",
          );
        my %result = (
            dataFile => \%datafile,
          );

        # ---- now generating the .txt file
        my $dataname = "$NODEName\_$timescale.txt";
        my $filepath = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/exports/";
        my $chan_nb = 5 + $row[16];
        my $obsfile = "$tmpdir/$datafile{'name'}";

        # ---- generating .txt files for the observed properties
        # ---- header
        my $header = "#Date_of_extraction;$today;\n";
        $header .= "#Observation_ID;$row[0];\n";
        $header .= "#Dataset_title;;\n";
        $header .= "#Variable_name;".$row[5].";\n";
        $header .= "dateBeg;dateEnd;latitude;longitude;altitude;value;qualityFlags;\n";

        # ---- content
        my $cmd = qq(grep -v '^#' $filepath$dataname | awk -v lat="$lat" -v lon="$lon" -v alt="$alt" -v chan_nb="$chan_nb" '{
            printf \";%s-%s-%sT%s:%s:%sZ;%s;%s;%s;%s;\\n\", \$1,\$2,\$3,\$4,\$5,\$6,lat,lon,alt,\$chan_nb
        }');
        my $content = qx($cmd);
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
}

# ---- extracting datasets data

my @datasets;

foreach (@nodes) {
    print "$_\n";
    chomp($_);
    $stmt = qq(SELECT * FROM datasets WHERE datasets.identifier = '$_';);
    $sth = $dbh->prepare( $stmt );
    $rv = $sth->execute() or die $DBI::errstr;

    while( my @row = $sth->fetchrow_array() ) {
        my $datasetId = (split /_DAT_/, $row[0]) [1];
        (my $GRIDName, my $NODEName) = (split /\./, $datasetId);
        my %S = readNode($NODEName, "novsub");
        my %NODE = %{$S{$NODEName}};
        my $desc = $NODE{"$GRIDType.$GRIDName.DESCRIPTION"};

        my $topicCategories = (split '_', $row[2])[0];
        my @topicCategories;
        foreach(split('_,', $topicCategories)) {
            my $category = (split(':', $_))[1];
            push(@topicCategories, $category);
        }

        my %geometry;
        if ($row[3]) {
            try {
                %geometry = (
                    type => JSON->new->utf8->decode($row[3])->{'type'},
                    coordinates => JSON->new->utf8->decode($row[3])->{'coordinates'}
                );
            } catch {
                warn "Encoding error: $_";
            };
        }

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
            title => decode("utf8", $row[1]),
            datasetLineage => $row[4],
            dataConstraint => \%dataConstraint,
            topicCategories => \@topicCategories,
            inspireTheme => (split '_inspireTheme:', $row[2])[1],
            spatialExtent => \%spatialExtent,
          );
        $metadata{'inspireTheme'} =~ s/(\r\n)//g;
        $metadata{'description'} = u2l($desc);

        my %dataset = (
            datasetId => $row[0],
          );

        # ---- extracting contacts data
        my $stmt2 = qq(SELECT * FROM contacts;);
        my $sth2 = $dbh->prepare( $stmt2 );
        my $rv2 = $sth2->execute() or die $DBI::errstr;

        my @contacts;
        while( my @row2 = $sth2->fetchrow_array() ) {
            if ($row2[4] eq $dataset{'datasetId'}) {
                # ---- parsing contacts
                my %contact = (
                    firstName => decode("utf8", $row2[1]),
                    lastName => decode("utf8", $row2[2]),
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
            if (defined($_->{'observationId'})) {
                my $obsId = (split /\./, $_->{'observationId'})[1];
                $obsId = (split /\_/, $obsId)[0];
                my $datId = (split /\./, $row[0])[1];
                if ($obsId eq $datId) {
                    push(@ds_obs, $_);
                    my $filename = decode_json encode_json $_->{'result'}->{'dataFile'}->{'name'};

                    # ---- adding the title dataset into $filename
                    # ---- first we open $filename while creating a new $filename where we will write the line we want to insert
                    open my $in, '<', "$tmpdir/$filename" or die "Can't read old file: $!";
                    open my $out, '>', "$tmpdir/$filename.new" or die "Can't write new file: $!";
                    my $title = decode("utf8", $row[1]);
                    while( <$in> ) {
                        s/Dataset_title;/Dataset_title;$title/; # ---- writing the dataset title in the right row
                        print $out $_;
                    }
                    close $in;
                    close $out;
                    rename "$tmpdir/$filename.new", "$tmpdir/$filename";
                }
            }
        }

        #print encode_json $ds_obs[0];
        $dataset{'observations'} = \@ds_obs;

        #print scalar(@{$dataset{'observations'}}), "\n";
        $empty = $dataset{'observations'} ? "yup" : "nope";

        # ---- compressing observations files into OBSE_DAT_PROC.NODE.zip
        if ($empty eq "yup") {
            if (@{$dataset{'observations'}}) {
                push(@datasets, \%dataset);
                compressTxtFiles("$dataset{'datasetId'}", $tmpdir)
                # or die "$dataset{'datasetId'} needs to be associated with at least one observation !\n";
            } else {
                print "$datasetId was discarded. There are no observations for this dataset!\n";
            }
        } else {
            compressTxtFiles("$dataset{'datasetId'}", $tmpdir)
              or die "zip failed: $ZipError\n";
        }
    }
}

#print encode_json \@datasets;

# ---- creating the final json object

my %json = (
    producer => \%producer,
    datasets => \@datasets,
    version => "1.0",
  );

$dbh->disconnect();

$filename = "$json{'producer'}{'producerId'}_en.json";
my $filepath = "$tmpdir/$filename";

#print $cgi->header(-type=>'text/html', -charset=>'utf-8');
#print $filepath;
#print encode_json $json{'datasets'}->[0]{'metadata'}{'contacts'};
#print "\n";

chmod 0755, $filepath;
open(FH, '>', $filepath) or die $!;
print FH encode_json \%json;
close(FH);

#print encode_json \%json;

# ---- checking if the final json file is conform to the recommandations

my $output = qx(java -jar $json_validator_path $filepath);

# ---- Create a data archive

my $producerId = $producer{'producerId'};
my $zipfile   = $producerId . "_THEIA.zip";
if ( $output =~ /success/ ) {
    zip [ <$tmpdir/*DAT*.zip>, $filepath ] => "$theiadir/$zipfile",
      FilterName => sub { s[^$tmpdir/][] } or die "zip failed: $ZipError\n";
    rmtree($tmpdir);
} else {
    print "The JSON metadata file is not valid :\n".$output;
};

# ---- Send archive to Theia/OZCAR

if ( $output =~ /success/ ) {
    my $url = "https://in-situ.theia-land.fr/data/$producerId/new/";
    my $password = $WEBOBS{PASSWORD_THEIA};
    my $response = qx(curl -T "$theiadir/$zipfile" -u $producerId:$password -s -o /dev/null -w "%{http_code}" $url);
    if ( rindex($response,"2", 0) eq 0 ) {
        print "Data upload successful. Data are available at https://in-situ.theia-land.fr/data/OBSE/previous/", "\n";
    } else {
        print "Data upload failed: ", $response, "\n";
        die;
    }
}

#print $observations[1]{'featureOfInterest'}{'samplingFeature'}{'geometry'}{'coordinates'};

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin, Jérôme Touvier

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

=cut
