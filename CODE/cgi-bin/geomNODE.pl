#!/usr/bin/perl

use DBI;
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser); # just to make it easier to see errors
use WebObs::Utils;

# ---- extracting data from OSM.pl
my $cgi = new CGI;

my $geom = $cgi->url_param('geom');
my @geom = split(/[\;]/, trim($geom));
my $wkt = 'wkt:'.$geom[0];
#my $wkt = 'wkt';
my $geo = $geom[1];
#my $geo = 'geo3';
my $nod = 'OBSE_DAT_'.$geom[2];
#my $nod = 'nod2';

# ---- send results back
print $cgi->header( -type => 'text/plain', -status => '200' );

# ---- managing the database
my $driver   = "SQLite";
my $database = "/home/lucas/webobs/SETUP/WEBOBSMETA.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
print "Opened database successfully\n";

my $stmt = qq(CREATE TABLE IF NOT EXISTS datasets
   (  IDENTIFIER TEXT PRIMARY KEY NOT NULL,
      WKTGEOM    TEXT NOT NULL,
      GEOJSON    TEXT NOT NULL););

my $rv = $dbh->do($stmt);
if($rv < 0) {
   print $DBI::errstr;
} else {
   print "Table created successfully\n";
}
#=pod
my $sth = $dbh->prepare('INSERT OR REPLACE INTO datasets (IDENTIFIER, WKTGEOM, GEOJSON) VALUES (?,?,?);');
$sth->execute($nod, $wkt, $geo);

print "Records created successfully\n";
#=cut
#=pod
my $stmt = qq(SELECT * FROM DATASETS;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

while(my @row = $sth->fetchrow_array()) {
      #print "ID = ". $row[0] . "\n";
      print "IDENTIFIER = ". $row[0] ."\n";
      print "WKTGEOM = ". $row[1] ."\n";
      print "GEOJSON = ". $row[2] ."\n\n";
}
#=cut
#$stmt = qq(DROP TABLE datasets);
#$rv = $dbh->do($stmt);
$dbh->disconnect();

print $cgi->end_html;
