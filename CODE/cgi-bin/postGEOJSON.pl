#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use JSON;

# Create a new CGI object
my $cgi = CGI->new;

# Read the JSON data
my $json_data = $cgi->param('POSTDATA');

# Decode the JSON data
my $data = decode_json($json_data);
my $filename = $data->{filename};
my $geojson = $data->{geojson};

# Save the GeoJSON data to a file
open(my $fh, '>', $filename) or die "Cannot open file: $!";
print $fh to_json($geojson);
close($fh);

# Send the response
print $cgi->header('application/json');
print to_json({ status => 'success', message => "GeoJSON data saved to $filename" });

