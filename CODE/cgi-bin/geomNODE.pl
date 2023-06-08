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

# ---- send results back
print $cgi->header( -type => 'text/plain', -status => '200' );

# ---- extracting some data from the table producer
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
print "Opened database successfully\n";

my $stmt = qq(SELECT Identifier FROM producer;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

my $id = $sth->fetchrow_array();

# ---- prefixing the variables

my $wkt = 'wkt:'.$geom[0];
my $geo = $geom[1];
my $nod = $id.'_DAT_'.$geom[2];
=pod
# ---- managing the database
my $stmt = qq(CREATE TABLE IF NOT EXISTS datasets
   (  Identifier TEXT NOT NULL,
      wktgeom    TEXT NOT NULL,
      geojson    TEXT,
      FOREIGN KEY(Identifier) REFERENCES producer(Identifier))
      ;);

my $rv = $dbh->do($stmt);
if($rv < 0) {
   print $DBI::errstr;
} else {
   print "Table created successfully\n";
}
=cut
my $sth = $dbh->prepare('INSERT OR REPLACE INTO datasets (IDENTIFIER, SPATIALCOVERAGE) VALUES (?,?);');
$sth->execute($nod, $wkt);

print "Records created successfully\n";
#=pod
my $stmt = qq(SELECT Identifier FROM datasets;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}
=pod
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
=cut
print $cgi->end_html;
