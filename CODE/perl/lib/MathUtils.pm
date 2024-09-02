package WebObs::MathUtils;

=head1 NAME

WebObs::MathUtils - Common cgi math utility functions  

=head1 SYNOPSIS

use WebObs::MathUtils

=head1 FUNCTIONS

=cut

use strict;
use warnings;

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);
require Exporter;
@ISA     = qw(Exporter);
@EXPORT  = qw(tri_date_avec_id romain boussole pga2msk attenuation);
$VERSION = "1.00";

=pod

=head2 tri_date_avec_id

=cut

sub tri_date_avec_id ($$) {
	#my $c = $a;
	#my $d = $b;
	my ($c,$d) = @_;
	# supprime le premier champ Id
	$c =~ s/^[\-0-9]+\|//;
	$d =~ s/^[\-0-9]+\|//;
	# remplace tous les champs vides par '00:00' pour que les événements sans heure apparaissent en premier
	$c =~ s/\|\|/00:00/;
	$d =~ s/\|\|/00:00/;
	return $d cmp $c;
}

=pod

=head2 romain

$romain = romain($decimal);

converts $decimal (range [0-10]) to roman. $decimal 0 yields X (10)   

Matlab equivalent: romanx.m

=cut

sub romain ($)
{
	my @msk = ("X","I","II","III","IV","V","VI","VII","VIII","IX");
	my $string = shift;
	return $msk[$string%10];
}

=pod

=head2 romain

$direction = boussole($azimut);

converts $azimut (in degrees) to geographic direction string (eg. ENE, SW, ...)   

Matlab equivalent: boussole.m

=cut

sub boussole ($)
{
       my @nsew = ('E','ENE','NE','NNE','N','NNW','NW','WNW','W','WSW','SW','SSW','S','SSE','SE','ESE');
       my $az = shift;
       $az = ($az*16/6.283)%16;
       return $nsew[$az];
}

=pod

=head2 pga2msk

$romanIMSK = pga2msk($acceleration);

Matlab equivalent: pga2msk.m

=cut

sub pga2msk ($)
{
	my @msk = ('I','I-II','II','II-III','III','III-IV','IV','IV-V','V','V-VI','VI','VI-VII','VII','VII-VIII','VIII','VIII-IX','IX','IX-X','X','X-XI','XI','XI-XII','XII');
	my $pga = shift;
	$pga = 2*(log($pga)*3/log(10) + 1.5) - 2;
	if ($pga < 0) { $pga = 0; }
	return $msk[$pga];
}


=pod

=head2 attenuation

=cut

sub attenuation ($$)
# Input: magnitude et distance hypocentrale (en km)
# Ouput: acceleration PGA (en g)
# Equivalent Matlab: attenuation.m
# Auteur: F. Beauducel, IPGP, 2009-06-24
{
	my ($mag,$hyp) = @_;
	if ($hyp < 5) { $hyp = 5; }
	my $pga = 1000*10**(0.620986*$mag - 0.00345256*$hyp - log($hyp)/log(10) - 3.374841);
	return $pga;
}


1;

__END__

=pod

=head1 AUTHOR

Alexis Bosson, Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014 - Institut de Physique du Globe Paris

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
