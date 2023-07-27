#!/usr/bin/perl -w

=head1 NAME

showTHEIA.pl

=head1 SYNOPSIS

http://..../showTHEIA.pl?object=object[,id=Identifier,action=delete]

 object=
 producer, dataset or observation.
 
 id=
 Identifier of the above object.

 delete=
 if present delete the row.

=head1 DESCRIPTION

Displays data associated to a producer.

A producer is associated to datasets. A dataset is associated to observations. An observation is an observed property sampled at a given location and associated to a datafile.

A dataset corresponds to a NODE in WebObs. An observation corresponds to a row in the calibration file of a given NODE in WebObs

All known data associated to the producer are shown and can be edited to be send towards the Theia|OZCAR pivot model which convert into a JSON file the metadata, ready to get send to the Theia data portal.

=cut

use strict;
use warnings;
use Time::Local;
use File::Basename;
use Image::Info qw(image_info dim);
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Data::Dumper;
use POSIX qw(locale_h);
use locale;
use JSON;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users;
use WebObs::i18n;

# ---- checking if user has authorisation to create a JSON metadata file.
# ----------------------------------------
if ( ! WebObs::Users::clientHasAdm(type=>"authmisc",name=>"grids")) {
	die "You are not authorized" ;
}

# ---- Gathering query informations
#
my $QryParm    = $cgi->Vars;    # used later; todo: replace cgi->param's below
my $object	   = $cgi->param('object')    // '';
my $identifier = $cgi->param('id')        // '';
my $action     = $cgi->param('action')    // '';

# ---- connecting to the database
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;
   
# ---- if action=delete, the field with the id=Identifier will be erased from the metadata panel 
# ---- note that the deletion of a dataset means the deletion of ALL the observations related to that dataset in the panel

if ($action eq "delete") {
	my $stmt = qq(DELETE FROM $object WHERE identifier = \"$identifier\");
	my $rv = $dbh->do("PRAGMA foreign_keys = ON;");
	my $sth = $dbh->prepare( $stmt );
	my $rv = $sth->execute() or die $DBI::errstr;

	if($rv < 0) {
	   print $DBI::errstr;
	}
	
	if ($object = "datasets") {
	    $stmt = qq(DELETE FROM datasets WHERE identifier LIKE \"$identifier%\");
	    $rv = $dbh->do("PRAGMA foreign_keys = ON;");
	    $sth = $dbh->prepare( $stmt );
	    $rv = $sth->execute() or die $DBI::errstr;

	    if($rv < 0) {
	       print $DBI::errstr;
	    }
	}
}

# ---- display HTML content
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

# ---- JS content and functions
print <<"FIN";
<html><head>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link href="/css/wolb.css" rel="stylesheet" />
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript"></script>

<meta http-equiv="content-type" content="text/html; charset=utf-8">
</head>
<body>
<form action="/cgi-bin/postTHEIA.pl" id="formTHEIA" method="post">
FIN

# ---- extracting producer data
my $stmt = qq(SELECT * FROM producer;);
my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

# ---- creating the panel
print "<TABLE style=\"background: white;\" width=\"100%\">";
print "<TR><TH valign=\"middle\" width=\"5%\">Producer</TH>";
print "<TD colspan=\"2\">";
print "<TABLE width=\"100%\"><TR>"
		."<TH><IMG \"title=\"edition\" src=\"/icons/modif.png\"></TH>"
		."<TH></TH>"
		."<TH><SMALL>Identifier</SMALL></TH>"
		."<TH><SMALL>Name</SMALL></TH>"
		."<TH><SMALL>Title</SMALL></TH>"
		."<TH><SMALL>Description</SMALL></TH>"
		."<TH><SMALL>Objective</SMALL></TH>"
		."<TH><SMALL>Measured variables</SMALL></TH>"
		."<TH><SMALL>Email</SMALL></TH>"
		."<TH><SMALL>Contacts</SMALL></TH>"
		."<TH><SMALL>Funders</SMALL></TH>"
		."<TH><SMALL>Online resource</SMALL></TH></TR>";
		
my $contacts;
my $funders;
my @onlineRes;
		
while(my @row = $sth->fetchrow_array()) {
	$contacts  = join(', ',split(/_,/,$row[7]));
	$funders   = join(', ',split(/_,/,$row[8]));
	@onlineRes = split(/_,/,$row[9]);
	foreach (@onlineRes) {
		$_ = (split '@', $_)[1];
	}
	my $onlineRes = join(', ', @onlineRes);
	print "<TR><TD width=1%><A href=\"/cgi-bin/gridsMgr.pl\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit producer\" src=\"/icons/modif.png\"></A></TD>"
			."<TD width=1%><A id=$row[0] class=\"producer\" onclick=\"deleteRow(this);\" href=\"#\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" title=\"delete producer\" src=\"/icons/no.png\"></A></TD>"
			."<TD width=3% align=center><SMALL>$row[0]&nbsp&nbsp</SMALL></TD>"
			."<p><input type=\"hidden\" name=\"producerId\" value=\"$row[0]\"></input></p></SMALL></TD>"
			."<TD width=4% align=center><SMALL>$row[1]"
			."<p><input type=\"hidden\" name=\"name\" value=\"$row[1]\"></input></p></SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[2]"
			."<p><input type=\"hidden\" name=\"title\" value=\"$row[2]\"></input></p></SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[3]"
			."<p><input type=\"hidden\" name=\"description\" value=\"$row[3]\"></input></p></SMALL></TD>"
			."<TD width=21% align=center><SMALL>$row[4]"
			."<p><input type=\"hidden\" name=\"objectives\" value=\"$row[4]\"></input></p></SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[5]"
			."<p><input type=\"hidden\" name=\"measuredVariables\" value=\"$row[5]\"></input></p></SMALL></TD>"
			."<TD width=5% align=center><SMALL>$row[6]"
			."<p><input type=\"hidden\" name=\"email\" value=\"$row[6]\"></input></p></SMALL></TD>"
			."<TD width=8% align=center><SMALL>$contacts"
			."<p><input type=\"hidden\" name=\"contacts\"></input></p></SMALL></TD>"
			."<TD width=8% align=center><SMALL>$funders"
			."<p><input type=\"hidden\" name=\"fundings\"></input></p></SMALL></TD>"
			."<TD width=10% align=center><SMALL>$onlineRes"
			."<p><input type=\"hidden\" name=\"onlineRes\"></input></p></SMALL></TD></TR>";
};

print "</TABLE></TD>\n";
print "</TH></TABLE>\n";
print "<BR><BR>\n";

# ---- extracting datasets data
$stmt = qq(SELECT * FROM datasets;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}
# ---- creating the panel
print "<TABLE style=\"background: white;\" width=\"100%\">";
print "<TR><TH valign=\"middle\" width=\"5%\">Datasets</A></TH>";
print "<TD colspan=\"2\" style=\"display:block\">";
print "<TABLE width=\"100%\" style=\"margin:auto\"><TR>"
		."<TH><IMG \"title=\"edition\" src=\"/icons/modif.png\"></TH>"
		."<TH></TH>"
		."<TH><SMALL>Identifier</SMALL></TH>"
		."<TH valign=\"top\"><SMALL>Title</SMALL></TH>"
		."<TH><SMALL>Description</SMALL></TH>"
		."<TH><SMALL>Subject</SMALL></TH>"
		."<TH><SMALL>Spatial coverage</SMALL></TH>"
		."<TH><SMALL>Provenance</SMALL></TH></TR>";

while(my @row = $sth->fetchrow_array()){
	my $nodeId  = (split '\.', $row[0]) [1];
	my $proc    = (split '_', (split '\.', $row[0]) [0]) [2];
	my $subject = join(',', split(/_/,$row[3]));
	print "<TR><TD width=1%><A href=\"/cgi-bin/formNODE.pl?node=PROC.$proc.$nodeId\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit dataset\" src=\"/icons/modif.png\"></A></TD>"
			."<TD width=1%><A id=$row[0] class=\"datasets\" onclick=\"deleteRow(this);\" href=\"#\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" title=\"delete dataset\" src=\"/icons/no.png\"></A></TD>"
			."<TD width=15% align=center><SMALL>$row[0]</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[1]</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[2]</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$subject</SMALL></TD>"
			."<TD width=12% align=center><SMALL>".substr($row[4], 0, 100)."</SMALL></TD>"
			."<TD width=14% align=center><SMALL>$row[5]</SMALL></TD></TR>";
};

print "</TABLE></TD>\n";
print "</TR></TABLE>\n";
print "<BR><BR>\n";

# ---- extracting observations data
$stmt = qq(SELECT * FROM observations;);
$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}
# ---- creating the panel
print "<TABLE style=\"background: white;\" width=\"100%\">";
print "<TR><TH valign=\"middle\" width=\"5%\">Observations</TH>";
print "<TD colspan=\"2\" style=\"display:block\">";
print "<TABLE width=\"100%\" style=\"margin:auto\"><TR>"
		."<TH><IMG \"title=\"edition\" src=\"/icons/modif.png\"></TH>"
		."<TH></TH>"
		."<TH><SMALL>Identifier</SMALL></TH>"
		."<TH><SMALL>Processing level</SMALL></TH>"
		."<TH><SMALL>Data type</SMALL></TH>"
		."<TH><SMALL>Temporal extent</SMALL></TH>"
		."<TH><SMALL>Time series</SMALL></TH>"
		."<TH><SMALL>Observed property</SMALL></TH>"
		."<TH><SMALL>Station name</SMALL></TH>"
		."<TH><SMALL>Dataset</SMALL></TH>"
		."<TH><SMALL>Data file name</SMALL></TH></TR>";

while(my @row = $sth->fetchrow_array()){
	my $nodeId  = (split '_', (split '\.', $row[0]) [1]) [0];
	my $proc    = (split '_', (split '\.', $row[0]) [0]) [2];
	my $subject = join(',', split(/_/,$row[3]));
	print "<TR><TD width=1%><A href=\"/cgi-bin/formCLB.pl?node=PROC.$proc.$nodeId\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit dataset\" src=\"/icons/modif.png\"></A></TD>"
			."<TD width=1%><A id=$row[0] class=\"observations\" onclick=\"deleteRow(this);\" href=\"#\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" title=\"delete observation\" src=\"/icons/no.png\"></A></TD>"
			."<TD width=12% align=center><SMALL>$row[0]</SMALL></TD>"
			."<TD width=6% align=center><SMALL>$row[1]</SMALL></TD>"
			."<TD width=6% align=center><SMALL>$row[2]</SMALL></TD>"
			."<TD width=12% align=center><SMALL>$row[3]</SMALL></TD>"
			."<TD width=4% align=center><SMALL>$row[4]</SMALL></TD>"
			."<TD width=8% align=center><SMALL>$row[5]</SMALL></TD>"
			."<TD width=10% align=center><SMALL>$row[6]</SMALL></TD>"
			."<TD width=12% align=center><SMALL>$row[7]</SMALL></TD>"
			."<TD width=8% align=center><SMALL>$row[8]</SMALL></TD></TR>";
};

print "</TABLE></TD>\n";
print "</TR></TABLE>\n";
print "<BR><BR>\n";

print <<"FIN";
<script>
	function deleteRow(element) {
		if (confirm(\"Do you really want to delete \"+element.id+\" ?\")) {
			element.href=\"/cgi-bin/showTHEIA.pl?object=\"+element.className+\"&id=\"+element.id+\"&action=delete\";
		} else {
			console.log(element);
			console.log(\"/cgi-bin/showTHEIA.pl?object=\"+element.className+\"&id=\"+element.id+\"&action=delete\");
		}
	}
</script>
FIN

print "<p><input type=\"submit\" onclick=\"\" name=\"valider\" value=\"Valider\"></p>";
print "</form>";

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
