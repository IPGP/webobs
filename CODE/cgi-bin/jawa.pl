#!/usr/bin/perl

use strict;
use WebObs::Config;
use DBI;
use CGI;
my $cgi = new CGI;

# get input parameters
my $QryParm   = $cgi->Vars;
$QryParm->{'s'}       ||= "%"; 
$QryParm->{'f'}       ||= "semua";


# open database
my $database = "$WEBOBS{ROOT_CODE}/etc/kamusjawa.db";
my $dsn = "DBI:SQLite:dbname=$database";
my $userid = "";
my $password = "";
my $tablename = "kata";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
	or die $DBI::errstr;
#print "Opened database successfully\n";

#my @field = ("INDONESIAN","NGOKO","KRAMA","KRAMA_INGGIL");
my $result = $dbh->prepare("SELECT * FROM $tablename WHERE 1=0");
$result->execute();
my @fields = @{ $result->{NAME} };

print $cgi->header(-charset=>'utf-8');
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n",
"<html><head><title>Kamus Indonesia/Jawa</title>\n",
"<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
"<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">\n";

print "</head>\n",
"<body style=\"font-size:16;background-attachment: fixed\">\n",
"<style>td,th { font-size:16; padding:5 }</style>",
"<FORM name=\"form\" action=\"/cgi-bin/jawa.pl\" method=\"get\">\n";

print "<INPUT type=\"text\" name=\"s\" width=\"30\" value=\"$QryParm->{'s'}\"> ";
print "<SELECT name=\"f\" size=\"1\">\n";
for ("-",@fields) {
	print "<OPTION value=\"$_\"".($QryParm->{'f'} eq $_ ? " selected":"").">".ucfirstword($_)."</OPTION>\n";
}
print "</SELECT>\n";
print " <INPUT type=\"submit\" value=\"Cari\"><BR>";

my $stmt = qq(SELECT * from $tablename where ($fields[0] like "%$QryParm->{'s'}%" OR $fields[1] like "%$QryParm->{'s'}%" OR $fields[2] like "%$QryParm->{'s'}%" OR $fields[3] like "%$QryParm->{'s'}%"););

foreach (@fields) {
	if ($QryParm->{'f'} eq $_) { $stmt = qq(SELECT * from $tablename where $_ like "%$QryParm->{'s'}%";); }
}

my $result = $dbh->prepare( $stmt );
my $rv = $result->execute() or die $DBI::errstr;
if($rv < 0){
	print $DBI::errstr;
}
#print "Operation done successfully\n";

# begins table
my $html = "<TABLE><TR>";
foreach (@fields) {
	$html .= "<TH>".ucfirstword($_)."</TH>";
}
my $n = 0;
while(my @row = $result->fetchrow_array()) {
	$html .= "<TR>";
	for my $i (0..3) {
		$html .= "<TD>".join('<BR>',split(/,/,$row[$i]))."</TD>";
	}
	$html .= "</TR>\n";
	$n ++;
}
$html .= "</TABLE>\n";

# evidences search string
if ($QryParm->{'s'} ne '%') {
	my $regexp = $QryParm->{'s'};
	$regexp =~ s/%/.*/g;
	$html =~ s/($regexp)/<span style="background-color: #E6FF5E">$1<\/span>/g;
}

$dbh->disconnect();

print "<P style=\"font-size:10\">$n kata.</P>\n";
if ($n > 0) {
	print "$html\n";
}
print "</FORM>\n</BODY>\n</HTML>\n";


sub ucfirstword {
	my $s = $_;
	$s =~ s/_/ /g;			# replaces _ by space
	$s =~ s/([\w']+)/\u\L$1/g;	# capitalizes first letter of words
	return $s;
}
