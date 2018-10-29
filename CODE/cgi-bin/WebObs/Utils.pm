package WebObs::Utils;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Utils

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Encode;
use File::Basename;

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);
require Exporter;
@ISA     = qw(Exporter);
@EXPORT  = qw(u2l l2u htmlspecialchars getImageInfo makeThumbnail trim ltrim rtrim tri_date_avec_id romain boussole pga2msk attenuation txt2htm url2target);
$VERSION = "1.00";

#--------------------------------------------------------------------------------------------------------------------------------------
=pod

=head2 u2l, l2u

 $latin = u2l("utf8-text");
 $utf = l2u("latin-text");

 uses legacy routines from i18n.pl for compatible behavior

=cut 

use Locale::Recode;
my $u2l = Locale::Recode->new (from => 'UTF-8', to => 'ISO-8859-15');
my $l2u = Locale::Recode->new (from => 'ISO-8859-15', to => 'UTF-8');
die $u2l->getError if $u2l->getError;
die $l2u->getError if $l2u->getError;

sub u2l ($) {
	my $texte = shift;
	$u2l->recode($texte) or die $u2l->getError;
	return $texte;
}

sub l2u ($) {
	my $texte = shift;
	$l2u->recode($texte) or die $l2u->getError;
	return $texte;
}

binmode STDOUT, ':raw'; # Needed to make it work in UTF-8 locales in Perl-5.8.

# -------------------------------------------------------------------------------------------------

=pod

=head2 htmlspecialchars

converts $textin B<" \< \>> to resp. html entities B<&quot; &lt; &gt;> : 

  $textout = htmlspecialchars($textin);

=cut

sub htmlspecialchars
{
	my $texte=$_[0];

	$texte =~ s/"/&quot;/g;
	$texte =~ s/</&lt;/g;
	$texte =~ s/>/&gt;/g;
#  	print "<div style=\"border: 1px dotted gray;\">".$texte."</div>";
	return $texte;
}


# -------------------------------------------------------------------------------------------------

=pod

=head2 makeThumbnail

  $thumbnail = makeThumbnail($srcFullName, $geometry, $thumbPath, $thumbExt);

If a thumbnail for $srcFullName doesn't already exists within directory $thumbPath,
tries to build and save one. 
$geometry is the ImageMagick's convert geometry parameter for -thumbnail option. 
$thumbExt is the thumbnail's filename extension.
Returns the full path to thumbnail if it has been created, or one was already present.
Returns "" otherwise (ie. thumbnail couldn't be created typically because 
ImageMagick couldn't do it, but also because of missing arguments !).

Example: 

 # tries to create /mypath/tothumbnails/image.jpg.png if not already exists
 #
 $thumb = makeThumbnail("/mypath/to/image.jpg", "x100", "/mypath/tothumbnails","png");
 if ($thumb ne "") { print "got a thumbnail !" }

=cut

sub makeThumbnail
{
	my $ret = "";
	my @needsel = (".pdf",".PDF");
	if (scalar(@_) == 4 ) {
		my ($img, $path) = fileparse($_[0]);
		my ($ext) = $img =~ /(\.[^.]+)$/;
		my $thumb = $_[2]."/".$img.".".$_[3];
		#DL-was:if ($ext ~~ @needsel) { $img .= '[0]' }  
		if (grep /\Q$ext/i , @needsel) { $img .= '[0]' }  
		if ( !-e $thumb ) {
			qx(/usr/bin/convert "$path$img" -thumbnail $_[1] "$thumb"  2>/dev/null);
			if ( $? == 0 ) {
				$ret = $thumb;
			}
		} else { $ret = $thumb }
	}
	return $ret;
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub getImageInfo
{
	my $ret = "",
	my $img = $_[0];
	if (-e $img) {
		$ret = qx(/usr/bin/identify -format "%[EXIF:DateTimeOriginal]|%G" "$img");
		chomp($ret);
	}
	return $ret;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Left trim function to remove leading whitespace
sub ltrim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}


#--------------------------------------------------------------------------------------------------------------------------------------
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

#--------------------------------------------------------------------------------------------------------------------------------------
sub romain ($)
# Input: intensite MSK (en numerique de 1 a 0 ou 10)
# Output: intensite MSK (en chiffres romains)
# Equivalent Matlab: romanx.m
{
	my @msk = ("X","I","II","III","IV","V","VI","VII","VIII","IX");
	my $string = shift;
	return $msk[$string%10];
}


#--------------------------------------------------------------------------------------------------------------------------------------
sub boussole ($)
# Input: azimut (en degres)
# Output: indication de direction geographique (chaine)
# Equivalent Matlab: boussole.m
{
       my @nsew = ('E','ENE','NE','NNE','N','NNW','NW','WNW','W','WSW','SW','SSW','S','SSE','SE','ESE');
       my $az = shift;
       $az = ($az*16/6.283)%16;
       return $nsew[$az];

}


#--------------------------------------------------------------------------------------------------------------------------------------
sub pga2msk ($)
# Input: acceleration (en mg)
# Output: niveau d'intensite MSK (en chiffres romains)
# Equivalent Matlab: pga2msk.m
# Auteur: F. Beauducel, IPGP, 2009-06-24
{
	my @msk = ('I','I-II','II','II-III','III','III-IV','IV','IV-V','V','V-VI','VI','VI-VII','VII','VII-VIII','VIII','VIII-IX','IX','IX-X','X','X-XI','XI','XI-XII','XII');
	my $pga = shift;
	$pga = 2*(log($pga)*3/log(10) + 1.5) - 2;
	if ($pga < 0) { $pga = 0; }
	return $msk[$pga];
}


#--------------------------------------------------------------------------------------------------------------------------------------
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

#--------------------------------------------------------------------------------------------------------------------------------------
sub url2target
{
	my $url = shift;
	if ($url =~ /^\/(index*)?$/) {
		return "_top";
	} elsif ($url =~ /^\//) {
		return "bas";
	} else {
		return "_blank";
	}
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
