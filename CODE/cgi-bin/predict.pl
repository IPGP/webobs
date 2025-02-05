#!/usr/bin/perl

=head1 NAME

predict.pl 
pse3
=head1 SYNOPSIS

http://..../predict.pl?... see query string parameters below ...

=head1 DESCRIPTION

Compute probabilities of seismic events. This script generates a json object of event-probability pair.


=head1 Query string parameters
 pse_root_conf= Path of configuration folder
 pse_pse_root_data= Path of data folder
 pse_algo_filepath= Script to run to send back predictions as a json object format.
 pse_conf_filename= Training configuration file to be used.
 pse_tmp_filepath= Temporary filepath to be used 
 datasource= Data source and format
 slinktool_prgm= slinktool
 year=,  month=,  day=,  hour=, minut=, second=, duration=
 verbatim=

=cut 

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use JSON;
use utf8;
use strict;
use warnings;

#use WebObs::Config;
#use WebObs::Utils;
#use WebObs::Users;
#use WebObs::i18n;
#use Locale::TextDomain('webobs'); 

my $cgi = CGI->new;
$cgi->charset('UTF-8');

my $pse_root_conf = $cgi->url_param('pse_root_conf');
my $pse_root_data = $cgi->url_param('pse_root_data');
my $pse_algo_filepath = $cgi->url_param('pse_algo_filepath');
my $pse_conf_filename = $cgi->url_param('pse_conf_filename');
my $pse_tmp_filepath = $cgi->url_param('pse_tmp_filepath');
my $datasource = $cgi->url_param('datasource');
my $slinktool_prgm = $cgi->url_param('slinktool_prgm');
my $year = $cgi->url_param('year');
my $month = $cgi->url_param('month');
my $day = $cgi->url_param('day');
my $hour = $cgi->url_param('hour');
my $minut = $cgi->url_param('minut');
my $second = $cgi->url_param('second');
my $duration = $cgi->url_param('duration');
my $verbatim = $cgi->url_param('verbatim');

print $cgi->header(-type => 'application/json', -charset => 'utf-8');
my $AAA = qx($pse_algo_filepath $pse_root_conf $pse_root_data $pse_tmp_filepath $pse_conf_filename '$datasource' $slinktool_prgm $year $month $day $hour $minut $second $duration $verbatim);
chomp($AAA);
print $AAA;

__END__

=pod

=head1 AUTHOR(S)

Lucie Van Nieuwenhuyze

=head1 COPYRIGHT

Webobs - 2012-2021 - Institut de Physique du Globe Paris

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

