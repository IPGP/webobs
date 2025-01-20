#!/usr/bin/perl

=head1 NAME

training.pl

=head1 SYNOPSIS



=head1 DESCRIPTION

Learning phase of seismic events predictions. This script generates the learning and the database from the main-courante.


=head1 Query string parameters
         date1= Start date of the database seismic event
         date2= End date of the database seismic event
            s3= Sefran3 name
          conf= Filename of general configuration file

=cut

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use JSON;
use utf8;
use strict;
use warnings;

use WebObs::Config;
use WebObs::Users qw(clientHasAdm);

my $cgi = CGI->new;
$cgi->charset('UTF-8');

# ---- loads arguments
my ($date1, $date2, $s3, $conf) = @ARGV;

# ---- loads requested Sefran3 configuration or default one
my %SEFRAN3 = readCfg("$WEBOBS{ROOT_CONF}/$s3.conf");
my $debug = $SEFRAN3{DEBUG};

# ---- loads MC3 configuration: requested or Sefran's or default
my $mc3 = $SEFRAN3{MC3_NAME};
my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");

# ---- must have admin auth to run
if (clientHasAdm(type=>"authprocs",name=>"MC") || clientHasAdm(type=>"authprocs",name=>"$mc3")) {
    die "Sorry, you must have administrator right on $mc3 to run this script.";
}

# ---- Download csv database from the WebObs main-courante
# manage auto-login to webobs
my $netrc = $WEBOBS{NETRC_FILE};
my $opt = (-e $netrc ? "--netrc-file '$netrc'":"");

# split dates
my $y1 = substr($date1, 0,4);
my $m1 = substr($date1, 4,2);
my $d1 = substr($date1, 6,2);
my $h1 = substr($date1, 8,2);
my $y2 = substr($date2, 0,4);
my $m2 = substr($date2, 4,2);
my $d2 = substr($date2, 6,2);
my $h2 = substr($date2, 8,2);

my $url = " '$WEBOBS{ROOT_URL}/cgi-bin/mc3.pl?slt=0&y1=$y1&m1=$m1&d1=$d1&h1=$h1&y2=$y2&m2=$m2&d2=$d2&h2=$h2&type=ALL&duree=ALL&ampoper=eq&amplitude=ALL&obs=&locstatus=0&located=0&mc=$mc3&dump=bul&newts=&graph=movsum'";

my $download_catalogue = "curl -v $opt -o $MC3{PSE_TMP_CATALOGUE} $url";
print "$download_catalogue" if ($debug);
qx($download_catalogue);

# ---- build filter catalogue filename
my $filename_new_catalogue  = substr(qx(cat $conf | jq .learning.catalogue_filename),1,-2);
my $new_catalogue = "$MC3{PSE_ROOT_DATA}/catalogue/$filename_new_catalogue";

# ---- select events classes
my $events_file = $MC3{EVENT_CODES_CONF};
my $events = qx(grep "^[^#=]" $events_file| cut -d '|' -f1,10  | grep ".*1\$"| cut -d '|' -f1 |tr '\n' ' ');

# ---- filter catalogue
my $filter_catalogue_algo ="$WEBOBS{ROOT_CODE}/python/Catalogue/catalogue.py";
print "$filter_catalogue_algo" if ($debug);
qx($filter_catalogue_algo $MC3{PSE_TMP_CATALOGUE} $new_catalogue $events);

# ---- launch training phase
my $verbatim = 3;
my $stdout = qx($WEBOBS{ROOT_CODE}/python/AAA/USECASE3_REAL_TIME_SPARSE_CLASSIFICATION_TRAINING.py $MC3{PSE_ROOT_CONF} $MC3{PSE_ROOT_DATA} $MC3{PSE_TMP_FILEPATH} $conf $SEFRAN3{DATASOURCE} $WEBOBS{SLINKTOOL_PRGM} $verbatim);
print $stdout if ($debug);

#print "$MC3{PSE_CONF_FILENAME} \n";

__END__

=pod

=head1 AUTHOR(S)

Lucie Van Nieuwenhuyze, François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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
