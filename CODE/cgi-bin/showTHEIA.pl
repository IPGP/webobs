#!/usr/bin/perl -w

=head1 NAME

showTHEIA.pl

=head1 SYNOPSIS

http://..../showTHEIA.pl

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
$CGI::POST_MAX = 1024 * 1000;
use Data::Dumper;
use POSIX qw(locale_h);
use locale;
use JSON;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Grids;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Search;
use WebObs::i18n;

# ---- checking if user has authorisation to create a JSON metadata file.
# ----------------------------------------
if ( ! WebObs::Users::clientHasAdm(type=>"authmisc",name=>"grids")) {
    die "You are not authorized" ;
}

# ---- init general-use variables on the way and quit if something's wrong
#
my $GRIDType = "PROC";  # grid type ("PROC" in the THEIA case use)
my $GRIDName = my $NODEName = "";      # name of the grid
my %GRID;               # structure describing the grid
my %NODE;

# ---- connecting to the database
my $driver   = "SQLite";
my $database = $WEBOBS{SQL_METADATA};
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
  or die $DBI::errstr;

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
    $funders   = join(', ',split(/_,/,$row[8]));
    @onlineRes = split(/_,/,$row[9]);
    foreach (@onlineRes) {
        $_ = (split '@', $_)[1];
    }
    my $onlineRes = join(', ', @onlineRes);

    # ---- extracting datasets contacts data
    my $stmt2 = qq(SELECT * FROM contacts WHERE related_id = '$row[0]';);
    my $sth2 = $dbh->prepare( $stmt2 );
    my $rv2 = $sth2->execute() or die $DBI::errstr;

    if($rv2 < 0) {
        print $DBI::errstr;
    }

    my @contacts;
    while(my @row2 = $sth2->fetchrow_array()){
        push(@contacts, "($row2[3]) ".$row2[1]." ".$row2[2].": ".$row2[0]);
    }
    print "<TR><TD width=1%><A href=\"/cgi-bin/gridsMgr.pl\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit producer\" src=\"/icons/modif.png\"></A></TD>"
      ."<TD width=1%><A id=$row[0] class=\"producer\" onclick=\"alert(\"deprecated feature\");\" href=\"#\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" title=\"delete producer\" src=\"/icons/no.png\"></A></TD>"
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
      ."<TD width=8% align=center><SMALL>".(join "\n", @contacts)
      ."<p><input type=\"hidden\" name=\"contacts\"></input></p></SMALL></TD>"
      ."<TD width=8% align=center><SMALL>$funders"
      ."<p><input type=\"hidden\" name=\"fundings\"></input></p></SMALL></TD>"
      ."<TD width=10% align=center><SMALL>$onlineRes"
      ."<p><input type=\"hidden\" name=\"onlineRes\"></input></p></SMALL></TD></TR>";
};

print "</TABLE></TD>\n";
print "</TH></TABLE>\n";
print "<BR><BR>\n";

# ---- get previous choices
my $filename = "$WEBOBS{CONF_THEIA}";
my %conf = readCfg($filename);
my @nodes = split(/,/, $conf{NODES});
my @channels = split(/,/, $conf{CHANNELS});
my %processing_level = ("Raw data" => 0, "Quality-controlled data" => 1, "Derived products" => 2);

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
  ."<TH><SMALL>Creator(s)</SMALL></TH>"
  ."<TH><SMALL>Spatial coverage</SMALL></TH>"
  ."<TH><SMALL>Provenance</SMALL></TH></TR>";

while(my @row = $sth->fetchrow_array()){
    my $datasetId = (split /_DAT_/, $row[0]) [1];
    ($GRIDName, $NODEName) = (split /\./, $datasetId);
    my %S = readNode($NODEName, "novsub");
    my %NODE = %{$S{$NODEName}};
    my $desc = $NODE{"$GRIDType.$GRIDName.DESCRIPTION"};

    if ( clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")  || clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName") ){
        my $subject = join(',', split(/_/,$row[2]));

        # ---- extracting datasets contacts data
        my $stmt2 = qq(SELECT * FROM contacts WHERE related_id LIKE '$row[0]%';);
        my $sth2 = $dbh->prepare( $stmt2 );
        my $rv2 = $sth2->execute() or die $DBI::errstr;

        if($rv2 < 0) {
            print $DBI::errstr;
        }

        my @contacts;
        while(my @row2 = $sth2->fetchrow_array()){
            push(@contacts, $row2[1]." ".$row2[2].": ".$row2[0]);
        }

        print "<TR class=\"node\" id=$row[0]><TD width=1%><A href=\"/cgi-bin/formNODE.pl?node=PROC.$GRIDName.$NODEName\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit dataset\" src=\"/icons/modif.png\"></A></TD>"
          ."<TD width=1%><A class=\"datasets\" onclick=\"deleteRow(this);\" href=\"#\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" title=\"delete dataset\" src=\"/icons/no.png\"></A></TD>"
          ."<TD width=15% align=center><SMALL>$row[0]</SMALL></TD>"
          ."<TD width=14% align=center><SMALL>$row[1]</SMALL></TD>"
          ."<TD width=14% align=center><SMALL>$desc</SMALL></TD>"
          ."<TD width=14% align=center><SMALL>$subject</SMALL></TD>"
          ."<TD width=12% align=center><SMALL>".join(', ', @contacts)."</SMALL></TD>"
          ."<TD width=14% align=center><SMALL>$row[3]</SMALL></TD>"
          ."<TD width=14% align=center><SMALL>$row[4]</SMALL></TD></TR>";
    } else {
        print "<TR class=\"node\" id=$row[0]>"
          ."<TD width=1%><A href=\"/cgi-bin/formNODE.pl?node=PROC.$GRIDName.$NODEName\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit dataset\" src=\"/icons/modif.png\"></A></TD>"
          ."<TD width=1%><A class=\"datasets\" onclick=\"deleteRow(this);\" href=\"#\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" title=\"delete dataset\" src=\"/icons/no.png\"></A></TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."<TD>No access to $GRIDName.$NODEName !</TD>"
          ."</TR>";
    }
};

print "</TABLE></TD>\n";
print "</TR></TABLE>\n";
print "<BR><BR>\n";

# ---- extracting observations data
$stmt = "SELECT observations.*, observed_properties.theiacategories ";
$stmt .= "FROM observations INNER JOIN observed_properties ON observations.observedproperty = observed_properties.identifier";
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
  ."<TH><SMALL>Data file name</SMALL></TH>"
  ."<TH><SMALL><a href=\"https://in-situ.theia-land.fr/skosmos/theia_ozcar_thesaurus/en/\" target=\"_blank\">THEIA category</SMALL></TH></TR>";

while(my @row = $sth->fetchrow_array()){
    my $datasetId = $row[7];
    my $channelId = $row[5];
    ($GRIDName, $NODEName) = (split /\./, $datasetId);
    $GRIDName = (split /_DAT_/, $GRIDName)[1];
    if ( clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")  || clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName") ) {
        my $subject = join(',', split(/_/,$row[3]));
        print "<TR class=\"channel\" id=$row[0]><TD width=1%><A href=\"/cgi-bin/formCLB.pl?node=PROC.$GRIDName.$NODEName\"><IMG style=\"display:block;margin-left:auto;margin-right:auto;\" \"title=\"edit dataset\" src=\"/icons/modif.png\"></A></TD>";
        print $row[0] ~~ @channels ? "<TD width=1%><input type='checkbox' checked></TD>" : "<TD width=1%><input type='checkbox'></TD>";
        print "<TD width=12% align=center><SMALL>$row[0]</SMALL></TD>"
          ."<TD width=6%  align=center><select>";
        foreach my $k (keys %processing_level) { print "<option value=$processing_level{$k}".(($k eq $row[1]) ? " selected" : "").">$k</option>\n"; }
        print "</select></TD>"
          ."<TD align=center><SMALL>$row[2]</SMALL></TD>"
          ."<TD align=center><SMALL>$row[3]</SMALL></TD>"
          ."<TD align=center><SMALL>$row[4]</SMALL></TD>"
          ."<TD align=center><SMALL>$row[5]</SMALL></TD>"
          ."<TD align=center><SMALL>$row[6]</SMALL></TD>"
          ."<TD align=center><SMALL>$row[7]</SMALL></TD>"
          ."<TD align=center><SMALL>$row[8]</SMALL></TD>"
          ."<TD align=center><SMALL><input name=theia size=35 value=$row[9]></SMALL></TD></TR>";
    } else {
        print "<TR class=\"node\" id=$row[0]>"
          ."<TD colspan='12'>No access to $GRIDName.$NODEName\_$channelId !</TD>"
          ."</TR>";
    }
};

print "</TABLE></TD>\n";
print "</TR></TABLE>\n";
print "<BR><BR>\n";

print "<input type=\"hidden\" name=\"nodes\">";
print "<input type=\"hidden\" name=\"channels\">";
print "<input type=\"hidden\" name=\"allChannels\">";

print <<"FIN";
<script>
    function deleteRow(element) {
        /**
         * Delete a row from the THEIA metadata resume board (but the metadata are still saved in the database !).
         * \@param {element} element DOM element (e.g. the "delete" sign)
         */
        const form = document.forms[0];
        var row = element.parentNode.parentNode;
        const nodes = document.getElementsByClassName('node');
        const channels = document.getElementsByClassName('channel');
        if (confirm(\"Do you really want to delete \"+row.id+\" ?\")) {
            const newNodes = [];
            row.remove();
            Array.from(nodes).forEach((node) => newNodes.push(node.id.split('.')[1]));
            newNodes.join(',');
            Array.from(channels).forEach( (chan) => { if (chan.id.split(/[\.|\_]/)[3] == row.id.split('.')[1]) {chan.remove();} } );
            form.nodes.value = newNodes;
        }
    }

    function gather() {
        /**
         * Gather the rows ids to send the list of datasets and observations to postTHEIA.pl.
         */
        const form = document.forms[0];
        
        const nodes = document.getElementsByClassName('node');
        const nodeList = [];
        Array.from(nodes).forEach((node) => nodeList.push(node.id));
        nodeList.join(',');
        form.nodes.value = nodeList;
        
        const channels = document.getElementsByClassName('channel');
        const channelList = [];
        const allChannelList = [];
        Array.from(channels).forEach((channel) => {
            if (channel.querySelector("input").checked) {
                channelList.push(channel.id);
            }
            var cs = channel.querySelector("select");
            var ci = channel.querySelector("input[name='theia']");
            allChannelList.push([channel.id, cs.options[cs.selectedIndex].text, ci.value].join('|'));
        });
        channelList.join(',');
        allChannelList.join(',');
        form.channels.value = channelList;
        const allChannels = "";
        form.allChannels.value = allChannelList;
    }
</script>
FIN

print "<p><input type=\"submit\" onclick=\"gather(); console.log(form.nodes.value); console.log(form.channels.value);\" name=\"valider\" value=\"Valider\"></p>";
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
along with this progra  m.  If not, see <http://www.gnu.org/licenses/>.

=cut
