#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use File::Basename;
use CGI;
print "Content-Type: application/json\n\n";

# Path to the GNSS files
my $folder_path = "../files_stations/";

# List the files in the folder
my @files = glob("$folder_path/*.txt");

# Storage variables
my %results;           # To store the results data
my %station_info;      # To store information about stations
my @periods;           # To store periods
my $proc = "";         # Processing information
my @column_names;      # Column names for the data

# Iterate over each file in the folder
foreach my $file (@files) {
    my $file_name = basename($file);  # Get the base name of the file
    
    # Open the file for reading
    open my $file_handle, '<', $file or die encode_json({ "error" => "Unable to open file: $file_name" });
    my @file_content = grep { $_ ne "" } <$file_handle>;  # Read the file content and remove empty lines
    close $file_handle;

    # Initialize metadata variables
    my ($node_code, $node_name, $node_url, $node_lat, $node_lon, $node_elevation) = (undef, undef, undef, undef, undef, undef);

    # Read the header section of the file
    foreach my $line (@file_content) {
        $line = trim($line);  # Trim whitespace from the line
        if ($line =~ /PROC:/) {
            $proc = extract_value($line);  # Extract process information
            $proc =~ s/[{}]//g;  # Remove curly braces
        } elsif ($line =~ /NODE\.FID:/) {
            $node_code = extract_value($line);  # Extract node code
        } elsif ($line =~ /NODE\.NAME:/) {
            $node_name = extract_value($line);  # Extract node name
            $node_name =~ s/[^a-zA-Z0-9\s\-\_]/_/g;
        } elsif ($line =~ /NODE\.LAT_WGS84:/) {
            $node_lat = $line =~ /NODE\.LAT_WGS84:/ ? 0 + extract_value($line) : undef;  # Extract latitude
        } elsif ($line =~ /NODE\.LON_WGS84:/) {
            $node_lon = $line =~ /NODE\.LON_WGS84:/ ? 0 + extract_value($line) : undef;  # Extract longitude
        } elsif ($line =~ /NODE\.ALTITUDE:/) {
            $node_elevation = $line =~ /NODE\.LON_WGS84:/ ? 0 + extract_value($line) : undef;  # Extract elevation
        } elsif ($line =~ /NODE\.URL:/) {
            $node_url = extract_value($line);  # Extract URL
        } elsif ($line =~ /PROC\.MODELTIME_PERIOD_DAY:/) {
            @periods = map { int($_) } split(',', extract_value($line));  # Extract time periods
        } elsif ($line =~ /yyyy mm dd/) {
            @column_names = split(/\s+/, $line);  # Extract column names (date format)
            last;  # Exit the loop once we have the column names
        }
    }

    # Store station information
    $station_info{$file_name} = {
        "code"      => $node_code,
        "name"      => $node_name,
        "latitude"  => $node_lat,
        "longitude" => $node_lon,
        "elevation" => $node_elevation,
        "url"       => $node_url
    };

    # Read GNSS data from the file
    foreach my $line (@file_content) {
        $line = trim($line);  # Trim whitespace from the line
        next if $line =~ /^#/;  # Skip comment lines
        next if $line =~ /yyyy mm dd/;  # Skip header line

        # Split the line into values based on whitespace
        my @values = split(/\s+/, $line);
        next if scalar @values < scalar @column_names;  # Ensure the number of values matches the number of columns

        # Extract date components
        my ($year, $month, $day, $hour, $minute, $second) = @values[0..5];
        my $date = sprintf("%04d-%02d-%02d", $year, $month, $day);  # Format date

        # Initialize results for the given date if not already created
        $results{$date} //= {};  

        # Initialize vectors hash
        my %vectors;
        foreach my $index (0..$#periods) {
            my $index_offset = 6 + $index * 6;
            my @vector = @values[$index_offset..$index_offset + 2];  # Extract vector values
            my @error = @values[$index_offset + 3..$index_offset + 5];  # Extract error values
            
            # Replace "NaN" with 0 and convert to numbers
            for my $i (0..2) {
                $vector[$i] = ($vector[$i] eq "NaN") ? 0 : 0 + $vector[$i];  # Convert "NaN" to 0
                $error[$i]  = ($error[$i] eq "NaN")  ? 0 : 0 + $error[$i];   # Convert "NaN" to 0
            }

            # Store the vectors and errors for each period
            $vectors{$periods[$index]} = {
                "vector" => \@vector,
                "error"  => \@error
            };
        }

        # Store the vectors and station position for the current date
        $results{$date}{$file_name} = {
            "vectors" => \%vectors,
            "position" => {
                "lat"       => $node_lat,
                "lon"       => $node_lon,
                "elevation" => $node_elevation
            }
        };
    }
}

# Output the final JSON response
print encode_json({
    "proc"      => $proc,
    "stations"  => \%station_info,
    "periods"   => \@periods,
    "data"      => \%results
});

# Utility function to trim whitespace from a string
sub trim {
    my ($string) = @_;
    $string =~ s/^\s+|\s+$//g;  # Remove leading and trailing whitespace
    return $string;
}

# Utility function to extract the value after the colon in a key-value line
sub extract_value {
    my ($line) = @_;
    return trim((split(":", $line, 2))[1]);  # Extract and trim the value part
}
