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
use utf8;
binmode(STDOUT, ":encoding(UTF-8)");

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
my $date_field_count = 6;  # yyyy mm dd HH MM SS

my @selected_nodes;
foreach (@nodes) {
    if ($_ =~ /(OBSE_DAT_)(.+\..+)/) {
        my $name = $2;
        if (grep { index($_, $name) != -1 } @channels) {
            push(@selected_nodes, $_);
        }
    }
}

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
    my @files = glob("$tmpdir/*$dataName*.txt");

    if (@files) {
        zip [ @files ] => "$tmpdir/$dataset.zip", FilterName => sub { s[^$tmpdir/][] } or die "zip failed: $ZipError\n";
        # Suppression des fichiers après archivage
        foreach my $file (@files) {
            unlink $file or warn "Impossible de supprimer $file: $!";
        }
    }
    return 1;
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

# ---- start the creation of the JSON object ----------------------------------------------------
#
# ---- extracting producer data

my $stmt = qq(SELECT * FROM producer INNER JOIN contacts ON producer.identifier = contacts.related_id);
my $sth = $dbh->prepare($stmt);
$sth->execute() or die $DBI::errstr;

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
            my $typeUrl = (split '@', $_)[0];
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
    my $sth2 = $dbh->prepare($stmt2);
    $sth2->execute() or die $DBI::errstr;

    my @contacts;

    while ( my @row2 = $sth2->fetchrow_array() ) {
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
$sth = $dbh->prepare($stmt);
$sth->execute() or die $DBI::errstr;

my @fundings;

while ( my @row = $sth->fetchrow_array() ) {
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
my @colnames; # Liste de chaque variable sélectionnée avec son unité

foreach (@channels) {
    print "$_\n";

    $stmt  = "SELECT o.identifier, o.processinglevel, o.datatype, o.temporalextent, o.observedproperty, o.stationname, o.datafilename, sf.geometry, op.name, op.unit, op.theiacategories ";
    $stmt .= "FROM observations AS o ";
    $stmt .= "INNER JOIN sampling_features AS sf ON o.stationname = sf.identifier ";
    $stmt .= "INNER JOIN observed_properties AS op ON o.identifier = op.identifier ";
    $stmt .= "WHERE o.identifier = '$_'";
    $stmt  = qq($stmt);
    $sth   = $dbh->prepare($stmt);
    $sth->execute() or die $DBI::errstr;

    while ( my @row = $sth->fetchrow_array() ) {
        # print "\n", join(" ", @row[0 .. $#row]), "\n";

        # ---- data from observed_properties table
        my $name = decode("utf-8", $row[8]);
        my $unit = decode("utf-8", $row[9]);
        my %observedProperty = (
            name => html_sup_sub_to_unicode($name),
            unit => (defined $unit && $unit ne "") ? $unit : "N/A",
          );
        push @colnames, $name . "(" . $unit . ")";

        my @theiaCategories;
        foreach (split(',', $row[10])) {
            $_ =~ s/(\n)//g;
            push(@theiaCategories, $_);
        }
        $observedProperty{"theiaCategories"} = \@theiaCategories;
        # print $observation{'observedProperty'}{'theiaCategories'}->[0];

        # ---- data from sampling_features table
        # ---- parsing coordinates
        my $geometry = (split ':', $row[7])[1];
        my $position = (split '\(|\)', $geometry)[1];
        my @coordinates = map { sprintf("%.7f", $_) } split(',', $position);
        $coordinates[0] += 0;
        $coordinates[1] += 0;
        my $alt = $coordinates[2];

        my @new_crds = ($coordinates[1], $coordinates[0]);
        if ($alt) {
            $coordinates[2] += 0;
            push @new_crds, $coordinates[2];
        }

        my %geometry = (
            type => (split '\(|\)', $geometry)[0],
            coordinates => \@new_crds,
          );
        my %samplingFeature = (
            name => $row[5],
            geometry => \%geometry,
            type => "Feature",
            properties => {},
          );
        my %featureOfInterest = (
            samplingFeature => \%samplingFeature,
          );

        my $GRIDName = (split /\./, $row[5])[0];
        my $NODEName = (split /\./, $row[5])[1];
        my %datafile = (
            name => $row[6],
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
}

# ---- extracting datasets data

my @datasets;

foreach (@selected_nodes) {
    print "$_\n";
    chomp($_);
    $stmt = qq(SELECT * FROM datasets WHERE datasets.identifier = '$_';);
    $sth = $dbh->prepare($stmt);
    $sth->execute() or die $DBI::errstr;

    while ( my @row = $sth->fetchrow_array() ) {
        my $datasetId = (split /_DAT_/, $row[0]) [1];
        (my $GRIDName, my $NODEName) = (split /\./, $datasetId);
        my %S = readNode($NODEName, "novsub");
        my %G = readProc($GRIDName);
        my %NODE = %{$S{$NODEName}};
        my %GRID = $G{$GRIDName} ? %{$G{$GRIDName}} : ("THEIA_SELECTED_TS" => "all");

        my $topicCategories = (split '_', $row[2])[0];
        my @topicCategories;
        foreach (split('_,', $topicCategories)) {
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

        my $desc = $NODE{"$GRIDType.$GRIDName.DESCRIPTION"};
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
        my $sth2 = $dbh->prepare($stmt2);
        $sth2->execute() or die $DBI::errstr;

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
                }
            }
        }

        #print encode_json $ds_obs[0];
        $dataset{'observations'} = \@ds_obs;

        #print scalar(@{$dataset{'observations'}}), "\n";

        # ---- now generating the .txt file
        my $timescale = $GRID{"THEIA_SELECTED_TS"};
        my $input_file = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/exports/$NODEName\_$timescale.txt";
        my $output_file = "$tmpdir/OBSE_MULTIOBS_$GRIDName.$NODEName\_$timescale.txt";
        open my $in, '<', $input_file or die "Impossible d'ouvrir $input_file: $!";
        open my $out, '>:encoding(UTF-8)', $output_file or die "Impossible de créer $output_file: $!";

        # Nouvelle entête
        my $observationIds = join(";", map { $_->{'observationId'} } @ds_obs);
        my @variables = map { $_->{'observedProperty'}{'name'} } @ds_obs;
        my $vars = join(";", map { "value_" . ($_+1) } 0..$#variables);

        my @position = @{ $ds_obs[0]->{'featureOfInterest'}{'samplingFeature'}{'geometry'}{'coordinates'} };
        while (scalar(@position) < 3) {
            push @position, "";
        }
        my $pos = join(";", @position);

        my ($title) = $dbh->selectrow_array("SELECT TITLE FROM datasets WHERE IDENTIFIER = ?", undef, "OBSE_DAT_$GRIDName.$NODEName");
        $title = "" unless defined $title;

        print $out "#Date_of_extraction;$today\n";
        print $out "#Observation_ID;$observationIds\n";
        print $out "#Dataset_title;$title\n";
        print $out "#Variable_name;" . join(";", @variables) . "\n";
        print $out "date_begin;date_end;latitude;longitude;altitude;$vars;qualityFlags\n";

        # Lire et transformer chaque ligne du fichier d'entrée vers le fichier de sortie
        my $header;
        my %dejavu;
        my @indices;
        while (<$in>) {
            chomp;
            if (/^#yyyy\s+mm\s+dd\s+HH\s+MM\s+SS/) {
                $header = $_;
                # Extrait, après le champ de date, chaque variable avec son unité
                $header =~ s/#yyyy mm dd HH MM SS //g;
                my @vars = $header =~ /[^)]*\)/g;
                @vars = map { s/^\s+|\s+$//g; $_ } @vars;
                @vars = map { proc_variable_to_html($_) } @vars;
                # On cherche les indices correspondant aux variables sélectionnées
                for my $i (0 .. $#vars) {
                    if (grep { $_ eq $vars[$i] } @colnames) {
                        push @indices, $i + $date_field_count;
                    }
                }
            }

            next if $_ =~ /^\s*#/;
            my @rows = split;
            next unless @rows >= $date_field_count + 1;

            # Extraire la date et l'heure
            my ($yyyy, $mm, $dd, $HH, $MM, $SS) = @rows[ 0 .. ($date_field_count-1) ];
            my $date_end = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $yyyy, $mm, $dd, $HH, $MM, $SS);

            next if $dejavu{$date_end};
            $dejavu{$date_end} = 1;

            my @values = map { $rows[$_] } @indices;
            @values = map { $_ eq "NaN" ? "" : $_ } @values;
            # Extraire les variables
            my $values = join(";", @values);
            print $out ";$date_end;$pos;$values;\n";
        }

        close $in;
        close $out;

        # ---- compressing observations files into OBSE_DAT_PROC.NODE.zip
        if (@{$dataset{'observations'}}) {
            push(@datasets, \%dataset);
            compressTxtFiles("$dataset{'datasetId'}", $tmpdir)
        } else {
            print "$datasetId was discarded. There are no observations for this dataset!\n";
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
open(my $fh, '>', $filepath) or die $!;
print $fh encode_json \%json;
close($fh);

#print encode_json \%json;

# ---- checking if the final json file is conform to the recommandations

my $output = qx(java -jar $json_validator_path $filepath);

# ---- Create a data archive

my $producerId = $producer{'producerId'};
my $zipfile = $producerId . "_THEIA.zip";
zip [ <$tmpdir/*DAT*.zip>, $filepath ] => "$theiadir/$zipfile",
  FilterName => sub { s[^$tmpdir/][] } or die "zip failed: $ZipError\n";
rmtree($tmpdir);

if ( $output !~ /success/ ) {
    die "The JSON metadata file is not valid :\n" . $output;
}

# ---- Send archive to Theia/OZCAR

if ( $output =~ /success/ ) {
    my $url = "https://in-situ.theia-land.fr/data/$producerId/new/";
    my $password = $WEBOBS{PASSWORD_THEIA};
    my $response = qx(curl -T "$theiadir/$zipfile" -u $producerId:$password -s -o /dev/null -w "%{http_code}" $url);
    if ( rindex($response, "2", 0) eq 0 ) {
        print "Data upload successful. Data are available at https://in-situ.theia-land.fr", "\n";
    } else {
        die "Data upload failed: ", $response, "\n";
    }
}

#print $observations[1]{'featureOfInterest'}{'samplingFeature'}{'geometry'}{'coordinates'};

sub html_sup_sub_to_unicode {
    my ($html) = @_;

    # Superscripts
    my @sup_digits = qw(⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹);
    my %sup = map { $_ => $sup_digits[$_] } 0..9;
    $sup{'+'} = '⁺';
    $sup{'-'} = '⁻';

    # Subscripts
    my @sub_digits = qw(₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉);
    my %sub = map { $_ => $sub_digits[$_] } 0..9;
    $sub{'+'} = '₊';
    $sub{'-'} = '₋';

    # Remplacement des tags
    $html =~ s{<sup>([^<]+)</sup>}{join '', map {$sup{$_} // $_} (split //, $1)}ge;
    $html =~ s{<sub>([^<]+)</sub>}{join '', map {$sub{$_} // $_} (split //, $1)}ge;

    return $html;
}

sub proc_variable_to_html {
    my ($name) = @_;

    # Remplacement des indices (_{}) et des exposants (^{}) par des tags html
    $name =~ s/_\{(.*?)\}/<sub>$1<\/sub>/g;
    $name =~ s/\^\{(.*?)\}/<sup>$1<\/sup>/g;
    return $name;
}

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
