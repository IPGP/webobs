 #!/usr/bin/perl

use DBI;
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser); # just to make it easier to see errors
use WebObs::Utils;

# ---- extracting data from OSM.pl
my $cgi = new CGI;

my $id = $cgi->param("Identifier");
my $name = $cgi->param("Name");
my $title = $cgi->param("Title");
my $desc = $cgi->param("Description");
my $email = $cgi->param("Email");
my $proj = $cgi->param("projectLeader");
my $data = $cgi->param("dat");
my $fund = $cgi->param('fnd');
my $obj = $cgi->param("Objective");
my $meas = $cgi->param("MeasuredVariable");
my $info = $cgi->param('inf');
my @names = $cgi->param;

# ---- send results back
print $cgi->header( -type => 'text/plain', -status => '200' );

# ---- managing the database
#=pod
my $driver   = "SQLite";
my $database = "/opt/webobs/CONF/WEBOBSMETA.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
print "Opened database successfully\n";
#print $fund."\n";

my $stmt = qq(CREATE TABLE IF NOT EXISTS producer
   (  Identifier        TEXT PRIMARY KEY NOT NULL,
      Name              TEXT NOT NULL,
      Title             TEXT NOT NULL,
      Description       TEXT NOT NULL,
      Objective         TEXT NOT NULL,
      MeasuredVariable  TEXT NOT NULL,
      Email             TEXT NOT NULL,
      Contacts          TEXT NOT NULL,
      Funders           TEXT NOT NULL,
      OnlineResource    TEXT NOT NULL););

my $rv = $dbh->do($stmt);
if($rv < 0) {
   print $DBI::errstr;
} else {
   print "Table created successfully\n";
}
#=pod
my $sth = $dbh->prepare('INSERT OR REPLACE INTO producer (Identifier,Name,Title,Description,Objective,MeasuredVariable,Email,Contacts,Funders,OnlineResource) VALUES (?,?,?,?,?,?,?,?,?,?);');
$sth->execute($id,$name,$title,$desc,$obj,$meas,$email,$proj,$fund,$info);

print "Records created successfully\n";
$dbh->disconnect();

print $cgi->end_html;
