#!/usr/bin/perl

use DBI;
use strict;

my $driver   = "SQLite";
my $database = "/home/lucas/webobs/SETUP/WEBOBSGEOMETRY.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
print "Opened database successfully\n";

my $stmt = qq(DROP TABLE IF EXISTS datasets);
my $rv = $dbh->do($stmt);

my $stmt = qq(CREATE TABLE IF NOT EXISTS datasets
   (ID INT PRIMARY KEY     NOT NULL,
      IDENTIFIER           TEXT    NOT NULL,
      WKTGEOM              TEXT     NOT NULL,
      GEOJSON              TEXT NOT NULL););

my $rv = $dbh->do($stmt);
if($rv < 0) {
   print $DBI::errstr;
} else {
   print "Table created successfully\n";
}
$dbh->disconnect();

#!/usr/bin/perl

use DBI;
use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser); # just to make it easier to see errors

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Utils;
use Locale::TextDomain('webobs');

my $cgi = new CGI;

my $geom = $cgi->url_param('geom');
my @geom = split(/[\;]/, trim($geom));
my $wkt = 'wkt:'.$geom[0];
my $geo = $geom[1];

# send results back to jQuery
print $cgi->header( -type => 'text/plain', -status => '200' );

my $driver = "SQLite";
my $database = "/home/lucas/webobs/SETUP/WEBOBSGEOMETRY.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
    or die $DBI::errstr;

print "$wkt\n";
print "Opened database successfully\n";
=pod
my $stmt = qq(INSERT INTO datasets (Identifier, SpatialCoverage) VALUES ('OBSE_DAT_GGWBDQCK', 'wkt:slt'+$geom););
#my $rv = $dbh->do($stmt) or die $DBI::errstr;

my $stmt = qq(SELECT * FROM datasets;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

while(my @row = $sth->fetchrow_array()) {
      print "Identifier = ". $row[0] . "\n";
      print "SpatialCoverage =  ". $row[1] ."\n\n";
}
=cut

#my $stmt = qq(PRAGMA temp_store_directory = '/tmp/sqlite';);
#my $rv = $dbh->do($stmt) or die $DBI::errstr;

my $stmt = qq(UPDATE datasets)

my $stmt = qq(DELETE from DATASETS where Identifier='OBSE_DAT_GGWBDQCK';);
my $rv = $dbh->do($stmt) or die $DBI::errstr;

my $sth = $dbh->prepare('INSERT INTO datasets VALUES (?, ?, ?)');
$sth->execute('OBSE_DAT_GGWBDQCK',$wkt, $geo);

#my $stmt = qq(DELETE from DATASETS where Identifier='OBSE_DAT_GGWBDQCK';);
#my $rv = $dbh->do($stmt) or die $DBI::errstr;

print "Operation done successfully\n";
$dbh->disconnect();

print $cgi->end_html;
