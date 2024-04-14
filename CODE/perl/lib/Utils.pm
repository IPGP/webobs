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
@EXPORT  = qw(u2l l2u htmlspecialchars getImageInfo makeThumbnail trim ltrim
            rtrim tri_date_avec_id isok romain pga2msk attenuation txt2htm tex2utf
            qrcode url2target checkParam);
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
	my $txt=$_[0];

	$txt =~ s/"/&quot;/g;
	$txt =~ s/'/&rsquo;/g;
	$txt =~ s/</&lt;/g;
	$txt =~ s/>/&gt;/g;
#  	print "<div style=\"border: 1px dotted gray;\">".$txt."</div>";
	return $txt;
}


# -------------------------------------------------------------------------------------------------

=pod

=head2 tex2utf

converts any TeX characters in $textin into UTF-8 character:

  $textout = tex2utf($textin);

=cut

sub tex2utf
{
	my $text = $_[0];

	$text =~ s/\\pm/±/g;
	$text =~ s/\\approx/≈/g;
	$text =~ s/\\pi/π/g;
	$text =~ s/\\mu/µ/g;
	$text =~ s/\\Omega/Ω/g;
	$text =~ s/\\Sigma/∑/g;
	$text =~ s/\\copyright/©/g;
	$text =~ s/\\partial/∂/g;
	$text =~ s/\\lt/</g;
	$text =~ s/\\gt/>/g;
	return $text;
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
			qx(/usr/bin/convert "$path$img" -thumbnail $_[1] -background white -alpha remove "$thumb" 2>/dev/null);
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
sub isok ($)
{
    my $ok = shift;
    return ($ok =~ /^(Y|YES|OK|ON|1|TRUE)/i ? 1:0);
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
sub qrcode ($)
{
    use MIME::Base64;
    my $s = shift;
    return "" if ($s eq "");
    my $url = "http://$ENV{HTTP_HOST}$ENV{REQUEST_URI}";
	my $qr = encode_base64(qx(qrencode -s $s -o - "$url"));
    my $img = ($qr eq "" ? "":"<A href=\"#\" onclick=\"javascript:window.open('/cgi-bin/showQRcode.pl','$url',"
		."'width=600,height=450,toolbar=no,menubar=no,status=no,location=no')\"><IMG src=\"data:image/png;base64,$qr\"></A>");
    return $img;
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


# -------------------------------------------------------------------------------------------------

=pod

=head2

Check that a value matches a pattern, otherwise die with an error message. This
should be used to check CGI parameters security.

Examples:

	# Pass a scalar parameter:
	my $param = checkParam($q->param('myparam'), qr/^[0-9A-Za-z_-]+i$/", "myparam");

	# This is actually the same as:
	my $param = checkParam(scalar($q->param('myparam')), qr/^[0-9A-Za-z_-]+$/", "myparam");

	# A list of param should be passed by reference:
	my $param = checkParam([$q->param('myparam')], qr/^[\w_-]+$/, "myparamlist");

	# The param name is only used in the error message and is optional
	my $param = checkParam($q->param('myparam'), qr/^[0-9]*$/);

Notes:

- Remember to always match the whole string in the regular expression, i.e.
expression should ALWAYS start with "^" and end with "$" (unless you really
know what you are doing, otherwise the check will be useless and your security
will be at risk).

- also remember to use a regular expression that match the empty string if your
parameter is allowed to be empty (in which you will usually provide a default
value).  In the following example, the default value "default" will never be
set and an error will be raised if no value are provided for the CGI parameter
'myparam':
	my $param = checkParam($q->param('myparam'), qr/^[0-9]+$/) // "default";
Use this instead:
	my $param = checkParam($q->param('myparam'), qr/^[0-9]*$/) // "default";

=cut

sub checkParam ($$;$) {
	# Parameters:
	#
	# $value (string or ARRAY ref, in a forced scalar context):
	#   The values to test. If an array ref, all elements of the array must
	#   match the pattern. Note: this cannot be a constant (e.g. 1, or "str")
	# $pattern (regex pattern):
	#   The pattern to test the value against (should match the whole value
	#   from start to end of string). Should ALWAYS match the whole string
	#   (qr/^...$/), or it would completely defeat the security check.
	# $param_name (string), optional:
	#   The error message to use with die of value does not match
	#
	# Exception:
	#   Dies with $error_msg if $value does not match pattern.
	# Returns:
	#   $value
	#
	my $value = shift;
	my $pattern = shift;
	my $param_name = shift // '';
	my $error_msg;
	my $want_array = ref($value) eq "ARRAY" ? 1 : 0;
	my @values = $want_array ? @$value : ($value);
	return unless defined $value;

	if ($param_name) {
		$error_msg = "Error: bad value for parameter '$param_name', cannot continue.";
	} else {
		$error_msg = "Error: bad parameter value, cannot continue.";
	}

	for my $v (@values) {
		die $error_msg unless ($v =~ $pattern);
	}
	return $want_array ? @values : $value;
}


1;

__END__

=pod

=head1 AUTHOR

Alexis Bosson, Francois Beauducel, Didier Lafon

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
