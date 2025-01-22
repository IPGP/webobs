package WebObs::Utils;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Utils

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use POSIX;
use Encode;
use File::Basename;

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);
require Exporter;
@ISA     = qw(Exporter);
@EXPORT  = qw(u2l l2u htmlspecialchars getImageInfo makeThumbnail trim ltrim
  rtrim tri_date_avec_id datediffdays isok romanx pga2msk attenuation num2roman txt2htm tex2utf
  roundsd htm2frac qrcode url2target checkParam mean median std);
$VERSION = "1.00";

#------------------------------------------------------------------------------
# [FB-comment 2025-01-22]: these 2 functions will disapear in the future since 
#  we plan to use UTF-8 only in all conf files (needs a migration process)
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

# -------------------------------------------------------------------------------------------------
sub u2l ($) {
    my $texte = shift;
    # converts some characters in HTML since they don't exist in latin
    $texte =~ s/σ/&sigma;/g;
    $u2l->recode($texte) or die $u2l->getError;
    return $texte;
}

# -------------------------------------------------------------------------------------------------
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
    my $txt = $_[0];
    my $re = $_[1];

    $txt =~ s/"/&quot;/g;
    $txt =~ s/'/\\'/g;
    $txt =~ s/</&lt;/g;
    $txt =~ s/>/&gt;/g;

    #      print "<div style=\"border: 1px dotted gray;\">".$txt."</div>";
    $txt =~ s/($re)/<b>$1<\/b>/g if ($re ne "");
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
# sort array of strings in the form "ID|yyyy-mm-dd|HH:MM|..." on date and time (second and third column)
# (for use with mc3.pl)
sub tri_date_avec_id ($$) {
    my ($c,$d) = @_;

    # removes first column (ID)
    $c =~ s/^[\-0-9]+\|//;
    $d =~ s/^[\-0-9]+\|//;

    # replaces empty time by '00:00' so events without time appear first
    $c =~ s/\|\|/00:00/;
    $d =~ s/\|\|/00:00/;
    return $d cmp $c;
}

#--------------------------------------------------------------------------------------------------------------------------------------
#
sub datediffdays {
    use DateTime::Duration;

    my ($y1,$m1,$d1,$h1,$n1,$s1) = split(/[- :]/,$_[0]);
    my ($y2,$m2,$d2,$h2,$n2,$s2) = split(/[- :]/,$_[1]);
    my $dt1 = DateTime->new(
        year   => $y1,
        month  => $m1,
        day    => $d1,
        hour   => $h1,
        minute => $n1,
        second => $s1,
        time_zone => 'local',
      );
    my $dt2 = DateTime->new(
        year   => $y2,
        month  => $m2,
        day    => $d2,
        hour   => $h2,
        minute => $n2,
        second => $s2,
        time_zone => 'local',
      ) + DateTime::Duration->new(seconds => "1"); # add 1 second

    my $dur = $dt2->subtract_datetime_absolute($dt1);

    #return "$dt1,$dt2";
    return sprintf("%1.0f", ($dur->in_units('seconds'))/86400);
}

#--------------------------------------------------------------------------------------------------------------------------------------
# Returns true for some known strings
sub isok ($)
{
    my $ok = shift;
    return ($ok =~ /^(Y|YES|OK|ON|1|TRUE)/i ? 1:0);
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub romanx ($)

  # Input: intensity MSK (numerical from 1 to 0 or 10)
  # Output: intensity MSK (in roman numbers)
  # Proc equivalent: matlab/romanx.m
{
    my @msk = ("X","I","II","III","IV","V","VI","VII","VIII","IX");
    my $string = shift;
    return $msk[$string%10];
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub pga2msk ($)

  # Input: ground acceleration (in mg)
  # Output: intensity level MSK (in roman numbers)
  # Proc equivalent matlab/pga2msk.m
  # Author: F. Beauducel, IPGP, 2009-06-24
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
  # Proc equivalent: matlab/attenuation.m
  # Author: F. Beauducel, IPGP, 2009-06-24
{
    my ($mag,$hyp) = @_;
    if ($hyp < 5) { $hyp = 5; }
    my $pga = 1000*10**(0.620986*$mag - 0.00345256*$hyp - log($hyp)/log(10) - 3.374841);
    return $pga;
}

#--------------------------------------------------------------------------------------------------------------------------------------

=pod
=head2 num2roman
$roman = num2roman($number);
converts integer (range [1-4999]) to roman string.
Proc equivalent: matlab/num2roman.m
# Author: F. Beauducel, IPGP
=cut

sub num2roman ($)
{
    my @r = (["I","X","C","M"],["V","L","D"," "," "]);
    my $n = shift;
    my $x;

    for my $i (reverse(0 .. floor(log10($n)))) {
        my $ii = int($n/10**$i);
        $x .= $r[0][$i] x $ii if ($ii < 4 || ($ii == 4 && $i == 3));
        $x .= $r[0][$i] if ($ii == 9 || ($ii == 4 && $i < 3));
        $x .= $r[1][$i].($r[0][$i] x ($ii - 5)) if ($ii >= 4 && $ii <= 8 && $i != 3);
        $x .= $r[0][$i+1] if ($ii == 9);
        $n -= $ii*10**$i;
    }
    return $x;
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub roundsd

  # Round with significant digits
  # Proc equivalent: matlab/roundsd.m
  # Author: F. Beauducel, IPGP
{
    my ($x, $n) = @_;
    $n = 1 if ($n eq "" || $n < 1);
    return 0 if ($x == 0);
    my $e = floor(log(abs($x))/log(10) - $n + 1);
    my $og = 10**abs($e);
    if ($e > 0) {
        return floor($x/$og + 0.5)*$og;
    } else {
        return floor($x*$og + 0.5)/$og;
    }
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub mean {
    my (@array) = @_;
    my $sum;
    foreach (@array) {
        $sum += $_;
    }
    return ( $sum / @array );
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub median {
    my (@array) = sort { $a <=> $b } @_;
    my $center = @array / 2;
    if ( scalar(@array) % 2 ) {
        return ( $array[$center] );
    } else {
        return ( mean( $array[$center - 1], $array[$center] ) );
    }
}

#--------------------------------------------------------------------------------------------------------------------------------------
sub std {
    my (@array) = @_;
    my ( $sum2, $avg ) = ( 0, 0 );
    $avg = mean(@array);
    foreach my $elem (@array) {
        $sum2 += ( $avg - $elem )**2;
    }
    return ( sqrt( $sum2 / ( @array - 1 ) ) );
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
# format a fraction 'a/b' using html table and cell border so it looks like a real fraction
# Author: F. Beauducel, IPGP
sub htm2frac
{
    my $s = shift;
    if ($s =~ /[^< ]\//) {
        my ($n, $d) = split(/[^< ]\//,$s);
        return "<table align=center><th style=\"border:0;border-bottom-style:solid;border-bottom-width:1px;text-align:center\">$n</th><tr><tr><th style=\"border:0;text-align:center\">$d</th></tr></table>";
    } else {
        return $s;
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

Alexis Bosson, François Beauducel, Didier Lafon

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
