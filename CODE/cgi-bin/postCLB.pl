#!/usr/bin/perl

=head1 NAME

postCLB.pl

=head1 SYNOPSIS

http://..../postCLB.pl?

=head1 DESCRIPTION

=head1 Query string parameters

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use Switch;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Grids;
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);
$ENV{LANG} = $WEBOBS{LOCALE};

# ---- inits
my $GRIDName = my $GRIDType = my $NODEName = my $RESOURCE = "";
my %NODE;
my %GRID;
my $fileDATA = "";
my %CLBS;
my %fieldCLB;
my @donnees;

my $Ctod = time();
my @tod = localtime($Ctod);
my $today = strftime('%F',@tod);

my $QryParm = $cgi->Vars;
$QryParm->{'node'} //= "";

# ---- can we ? should we ? do we have all we need ?
#
($GRIDType, $GRIDName, $NODEName) = split(/[
.\/]/, trim($QryParm->{'node'}));
if ( $GRIDType eq "PROC" && $GRIDName ne "" ) {
    if ( !clientHasEdit(type=>"authprocs",name=>"$GRIDName")) {
        die "$__{'Not authorized'} (edit) $QryParm->{'node'}";
    }
    if ($NODEName ne "") {
        my %S = readNode($NODEName);
        my %G = readProc($GRIDName);
        %NODE = %{$S{$NODEName}};
        %GRID = %{%G{$GRIDName}};
        if (%NODE) {
            $fileDATA = "$NODES{PATH_NODES}/$NODEName/$QryParm->{'node'}.clb";
            %CLBS = readCfg("$WEBOBS{ROOT_CODE}/etc/clb.conf");
            %fieldCLB = readCfg($CLBS{FIELDS_FILE}, "sorted");
        } else { htmlMsgNotOK("Couldn't get $QryParm->{'node'} node configuration."); exit 1; }
    } else { htmlMsgNotOK("no node specified. "); exit 1; }
} else { htmlMsgNotOK("You can't edit calibration files !"); exit 1; }

my $nb      = $cgi->param('nb');
my $nbc     = $cgi->param('nbc');
my $action  = $cgi->param('action');

my @params;
foreach my $k (sort { $fieldCLB{$a}{'_SO_'} <=> $fieldCLB{$b}{'_SO_'} } keys %fieldCLB) {
    push(@params, $k);
}
my $params_str = join '|', @params;
my $max_index = scalar(keys %fieldCLB);

# ---- build data file from querystring !

my @dd; my @dh; my @dv; my @ds;
my $maxc = my $modify = 0;

for my $i ("1"..$nb) {
    my $y = $cgi->param('y'.$i);
    my $m = $cgi->param('m'.$i);
    my $d = $cgi->param('d'.$i);
    $dd[$i-1] = "$y-$m-$d";
    my $h = $cgi->param('h'.$i);
    my $n = $cgi->param('n'.$i);
    $dh[$i-1] = "$h:$n";
    for my $j ("1"..$max_index-2) {
        $dv[$i-1][$j-1] = $cgi->param('v'.$i.'_'.$j);
    }
    $ds[$i-1] = $cgi->param('s'.$i);
    if ($dv[$i-1][0] > $maxc) {
        $maxc = $dv[$i-1][0];
    }
}

for ("1"..$nb) {
    my $i = ($_-1);
    my $ligne = "$dd[$i]|$dh[$i]";
    if ($nbc >= 10) {
        $dv[$i][0] = sprintf("%02d", $dv[$i][0]);
    }
    for ("0"..$max_index-3) {
        $ligne .= "|$dv[$i][$_]";
    }
    if (($action eq "delete" && $ds[$i] ne "") || $dv[$i][0] > $nbc) {
        $modify = 1;
    } elsif ($dv[$i][0]) {
        push(@donnees,"$ligne\n");
    }
    if ($action eq "duplicate" && $ds[$i] ne "") {
        push(@donnees,"$ligne\n");
        $modify = 1;
    }
}

if ($nbc > $maxc) {
    for (($maxc+1)..$nbc) {
        my $s = $today;
        $s .= "|$fieldCLB{'TIME'}{'Default'}|$_";
        foreach my $k ( @params ) {
            if    ($k eq "la") { $s .= "|$NODE{LAT_WGS84}" }
            elsif ($k eq "lo") { $s .= "|$NODE{LON_WGS84}" }
            elsif ($k eq "al") { $s .= "|$NODE{ALTITUDE}" }
            elsif (not $k ~~ ["DATE", "TIME", "nv"]) { $s .= "|$fieldCLB{$k}{'Default'}" }
        }

        push(@donnees,"$s\n");
    }
    $nb = $#donnees + 1;
    $modify = 1;
}

@donnees = sort(@donnees);

# stamp (date and staff)
my $stamp  = "[$today $USERS{$CLIENT}{UID}]";
my $entete = "# WebObs - $WEBOBS{WEBOBS_ID} : calibration file $QryParm->{'node'}\n# $stamp\n=key|$params_str\n";

# ---- looking after THEIA user flag
my $theiaAuth = $WEBOBS{THEIA_USER_FLAG};

if ( isok($theiaAuth) ) {

    # --- connecting to the database
    my $driver   = "SQLite";
    my $database = $WEBOBS{SQL_METADATA};
    my $dsn = "DBI:$driver:dbname=$database";
    my $userid = "";
    my $password = "";
    my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;

    # reading the NODEName dataset row to get the producer id
    my $stmt = qq(SELECT identifier FROM datasets WHERE identifier LIKE "\%$GRIDName.$NODEName");
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;

    if($rv < 0) {
        print $DBI::errstr;
    }

    my $producerId;
    while( my @row = $sth->fetchrow_array() ) {
        $producerId = (split /_/, $row[0])[0];
    }

    my $station   = $GRIDName.'.'.$NODEName;
    my $dataset   = "$producerId\_DAT_$GRIDName.$NODEName";
    my $dataname  = "$producerId\_OBS_$GRIDName.$NODEName\_$GRID{THEIA_SELECTED_TS}.txt";
    my $extension = "$NODEName\_$GRID{THEIA_SELECTED_TS}.txt";
    my $filepath;

    foreach (@donnees) {

        # observed_properties table
        my @obs   = split(/[\|]/, $_);
        my $id    = $obs[3];
        my $name  = $obs[3];
        my $unit  = $obs[4];
        my $chan  = $obs[2];
        my $theia = "";

        my $stmt2  = "SELECT theiacategories FROM observed_properties WHERE name='$name'";
        my $sth2   = $dbh->prepare( qq($stmt2) );
        my $rv2  = $sth2->execute();
        while(my @row = $sth2->fetchrow_array()) { $theia = $row[0]; }

        # observations table
        my $obsid        = "$producerId\_OBS_$GRIDName.$NODEName\_$id";
        my @first_date   = split(/ /,$obs[0]);
        my $first_year   = $first_date[0];
        my $first_hour   = $first_date[3] || "00";
        my $first_minute = $first_date[4] || "00";
        my $first_second = $first_date[5] || "00";

        # read data file to know end date of observations
        $filepath = "$WEBOBS{ROOT_OUTG}/$GRIDType.$GRIDName/exports/$extension";
        if ( -e $filepath) {
            my $first_date = "grep -v '^#' $filepath | head -n1";
            my @first_date = split(/ /, qx($first_date));
            my $last_date  = "grep -v '^#' $filepath | tail -n1";
            my @last_date  = split(/ /, qx($last_date));

            my $first_year   = $first_date[0];
            my $first_month  = $first_date[1];
            my $first_day    = $first_date[2];
            my $first_hour   = $first_date[3] || "00";
            my $first_minute = $first_date[4] || "00";
            my $first_second = $first_date[5];
            if ($first_second =~ /./) { $first_second = "00" };

            my $last_year   = $last_date[0];
            my $last_month  = $last_date[1];
            my $last_day    = $last_date[2];
            my $last_hour   = $last_date[3] || "00";
            my $last_minute = $last_date[4] || "00";
            my $last_second = $last_date[5];
            if ($last_second =~ /./) { $last_second = "00" };

            my $first_obs_date = "$first_year-$first_month-$first_day\T$first_hour:$first_minute:$first_second\Z";
            my $last_obs_date = "$last_year-$last_month-$last_day\T$last_hour:$last_minute:$last_second\Z";
            my $obs_date = "$first_obs_date/$last_obs_date";

            # --- completing observed_properties table
            my $sth = $dbh->prepare('INSERT OR REPLACE INTO observed_properties (IDENTIFIER, NAME, UNIT, THEIACATEGORIES,CHANNEL_NB) VALUES (?,?,?,?,?);');
            $sth->execute($id, $name, $unit, $theia, $chan);

            $sth = $dbh->prepare('INSERT OR REPLACE INTO observations (IDENTIFIER, TEMPORALEXTENT, STATIONNAME, OBSERVEDPROPERTY, DATASET, DATAFILENAME) VALUES (?,?,?,?,?,?);');
            $sth->execute($obsid, $obs_date, $station, $id, $dataset, $dataname);
        } else {

            #htmlMsgFileNotOK("$filepath does not exists (yet) !");
            #exit 1;
        }
    }
    $dbh->disconnect();
}

# ---- lock-exclusive the data file during all update process
#
if ( sysopen(FILE, "$fileDATA", O_RDWR | O_CREAT) ) {
    unless (flock(FILE, LOCK_EX|LOCK_NB)) {
        warn "postCLB waiting for lock on $fileDATA...";
        flock(FILE, LOCK_EX);
    }

    # ---- backup file (To Be Removed: lifecycle too short to be used )
    if (-e $fileDATA) { qx(cp -a $fileDATA $fileDATA~ 2>&1); }

    # ---- rewrite all file from previously built '@donnees'
    if ( $? == 0 ) {
        truncate(FILE, 0);
        seek(FILE, 0, SEEK_SET);
        print FILE $entete if (@donnees);
        my $id = 1;
        for (@donnees) {
            print FILE u2l("$id|$_");
            $id++;
        }
        close(FILE);
        if ($nbc == $maxc && $modify == 0) { htmlMsgOK(); }
        else                               { htmlMsgOK("auto reload edit form")}
    } else {
        close(FILE);
        htmlMsgNotOK("postCLB couldn't backup $fileDATA ");
        exit 1;
    }
} else {
    htmlMsgNotOK("postCLB opening r/w - $!");
    exit 1;
}

# --- return information when OK and registering metadata in the metadata database
sub htmlMsgOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    my $msg = $_[0] || "calibration file successfully updated !" ;
    print "$msg\n";
}

# --- return information when not OK
sub htmlMsgNotOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    print "Update FAILED !\n $_[0] \n";
}

# --- return information when not OK
sub htmlMsgFileNotOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    print "$_[0] \n";
}

__END__

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon, Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

=cut
