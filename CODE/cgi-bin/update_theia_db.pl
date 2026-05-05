#!/usr/bin/perl -w

=head1 NAME

update_theia_db.pl

=head1 SYNOPSIS

$ perl update_theia_db.pl

=head1 DESCRIPTION

=head1 Query string parameters

=cut

use strict;
use warnings;
use CGI;
use Encode qw(decode);
use utf8;
binmode(STDOUT, ":utf8");

sub update_theia_db {

    # ---- webobs stuff
    use WebObs::Config;
    use WebObs::Grids;
    use WebObs::Utils;

    # ---- inits
    my $GRIDName = my $NODEName = my $RESOURCE = my $producerId = "";
    my $GRIDType = "PROC";

    # --- connecting to the database
    my $driver   = "SQLite";
    my $database = $WEBOBS{SQL_METADATA};
    my $dsn      = "DBI:$driver:dbname=$database";
    my $userid   = "";
    my $password = "";
    my $dbh      = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;

    # reading datasets
    my $stmt = qq(SELECT identifier FROM datasets);
    my $sth = $dbh->prepare($stmt);
    $sth->execute() or die $DBI::errstr;

    while( my @row = $sth->fetchrow_array() ) {
        # print "$row[0]\n";
        if ($row[0] =~ /^([^_]+)_([^_]+)_([^.]+)\.([^.]+)$/) {
            ($producerId, $GRIDName, $NODEName) = ($1, $3, $4);
        } else {
            print "No valid id $row[0]\n";
            next;
        }

        my %G = readProc($GRIDName);
        if (! %G) {
            print "Couldn't get $GRIDName PROC configuration\n";
            exit 1;
        }
        my %GRID = %{$G{$GRIDName}};
        next unless defined $GRID{THEIA_SELECTED_TS} && length $GRID{THEIA_SELECTED_TS};

        my $id        = 0;
        my $station   = $GRIDName.'.'.$NODEName;
        my $dataset   = "$producerId\_DAT_$GRIDName.$NODEName";
        my $dataname  = "$producerId\_MULTIOBS_$GRIDName.$NODEName\_$GRID{THEIA_SELECTED_TS}.txt";
        my $extension = "$NODEName\_$GRID{THEIA_SELECTED_TS}.txt";
        my $root_id   = "$producerId\_OBS_$GRIDName.$NODEName\_";
        my $filepath  = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/exports/$extension";

        if ( -e $filepath ) {
            # read data file to know end date of observations
            my $first_date = "grep -v '^#' $filepath | head -n1";
            my @first_date = split(/ /, qx($first_date));
            my $last_date  = "grep -v '^#' $filepath | tail -n1";
            my @last_date  = split(/ /, qx($last_date));

            my $first_year   = $first_date[0];
            my $first_month  = $first_date[1];
            my $first_day    = $first_date[2];
            my $first_hour   = $first_date[3] || "00";
            my $first_minute = $first_date[4] || "00";
            my $first_second = $first_date[5] =~ /./ ? "00" : $first_date[5];

            my $last_year   = $last_date[0];
            my $last_month  = $last_date[1];
            my $last_day    = $last_date[2];
            my $last_hour   = $last_date[3] || "00";
            my $last_minute = $last_date[4] || "00";
            my $last_second = $last_date[5] =~ /./ ? "00" : $last_date[5];

            my $first_obs_date = "$first_year-$first_month-$first_day"."T"."$first_hour:$first_minute:$first_second"."Z";
            my $last_obs_date  = "$last_year-$last_month-$last_day"."T"."$last_hour:$last_minute:$last_second"."Z";
            my $obs_date       = "$first_obs_date/$last_obs_date";

            # Lire l'entête du fichier d'export de la PROC
            open my $in, '<:raw', $filepath or die "Impossible d'ouvrir $filepath: $!";
            my $header;
            while (<$in>) {
                chomp;
                if (/^#yyyy\s+mm\s+dd\s+HH\s+MM\s+SS/) {
                    $header = $_;
                    last;
                }
            }
            close($in);

            # Extrait, après le champ de date, chaque variable avec son unité (séparément)
            $header =~ s/#yyyy mm dd HH MM SS //g;
            my @variables = $header =~ /([^(]+)\(([^)]*)\)/g;
            @variables = map { s/^\s+|\s+$//g; $_ } @variables;

            my @properties;
            my @observations;
            while (my ($name, $unit) = splice(@variables, 0, 2)) {
                my $oid  = $root_id . ++$id;
                $unit = decode("iso-8859-1", $unit);
                $name = decode("iso-8859-1", $name);
                $name = proc_variable_to_html($name);
                push @properties, [$oid, $name, $unit];
                push @observations, [$oid, $obs_date, $station, $name, $dataset, $dataname];
            }

            my @columns = qw(identifier name unit);
            update_meta($dbh, "observed_properties", \@columns, \@properties);

            @columns = qw(identifier temporalextent stationname observedproperty dataset datafilename);
            update_meta($dbh, "observations", \@columns, \@observations);

            # cleanup
            my $pos = length($root_id) + 1;
            $dbh->do("DELETE FROM observed_properties WHERE identifier LIKE '$root_id%' AND CAST(SUBSTR(identifier, $pos) AS INTEGER) > ?", undef, $id);
            $dbh->do("DELETE FROM observations WHERE identifier LIKE '$root_id%' AND CAST(SUBSTR(identifier, $pos) AS INTEGER) > ?", undef, $id);
        }
    }
    $dbh->disconnect();
    return 1;
}

sub update_meta {
    my ($db_handle, $table, $columns, $data) = @_;
    my @columns = @$columns;
    my @data = @$data;
    my $key_column = "identifier";

    my @set_columns = grep { $_ ne $key_column } @columns;
    my $set_clause = join(", ", map { "$_=excluded.$_" } @set_columns);
    my $conflict_clause = "ON CONFLICT($key_column) DO UPDATE SET $set_clause";
    my $placeholders = join(", ", ("?") x scalar @columns);
    my $sql = "INSERT INTO $table (" . join(", ", @columns) . ") VALUES ";
    $sql .= join(", ", map { "($placeholders)" } @data);
    $sql .= " $conflict_clause";

    my @params;
    foreach my $row (@data) {
        push @params, @$row;
    }

    my $sth = $db_handle->prepare($sql);
    $sth->execute(@params);
    return 1;
}

sub proc_variable_to_html {
    my ($name) = @_;

    # Remplacement des indices (_{}) et des exposants (^{}) par des tags html
    $name =~ s/_\{(.*?)\}/<sub>$1<\/sub>/g;
    $name =~ s/\^\{(.*?)\}/<sup>$1<\/sup>/g;
    return $name;
}

# ---- display HTML content
my $cgi = CGI->new;
print $cgi->header('text/html');
print $cgi->start_html("Theia database update");
if (update_theia_db()) {
    print "Theia database updated successfully !\n";
} else {
    print "Theia database updated failed !\n";
}
print $cgi->end_html;

