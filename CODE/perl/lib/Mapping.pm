package WebObs::Mapping;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

 use WebObs::Mapping;
 print $WebObs::Mapping::UTM{GEODETIC_DATUM_LOCAL_NAME};
 # or:
 my %U = %{setUTMLOCAL($GRID{UTM_LOCAL})};
 print %U{GEODETIC_DATUM_LOCAL_NAME}; # specific definition for grid $GRID

=head1 DESCRIPTION

Mapping geodetic subroutines to convert geographic coordinates (WGS84 Lat,Lon) to UTM or cartesian geocentric.
Main subroutines are B<geo2utm> (WGS84), B<geo2utml> (local datum) and B<geo2cart>.

WebObs::Mapping sets up its %UTM hash defining required computation parameters.
As a default, at WebObs::Mapping load time, %UTM is initialized with the contents of
the site's required global definitions found in $WEBOBS{UTM_LOCAL} file. Scripts
using WebObs::Mapping may provide their own definitions via a call to setUTMLOCAL(name-of-specific-definitions-file).
In case this file can't be loaded, WebObs::Mapping uses the default site's definitions.

Typically, specific WebObs::Mapping definitions are associated to any GRID, via its own
configuration parameter UTM_LOCAL pointing to its own definitions file.

=head1 REFERENCES

 Author: François Beauducel, IPGP
     Created:  2009-10-21 (translated from Matlab 2003 author's toolbox)
	 Updated:  2022-05-29

 I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
 I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
 I.G.N., Transformation entre systèmes géodésiques, Service de Géodésie et Nivellement, http://www.ign.fr, 1999/2002.

=cut

use strict;
use warnings;
use Math::Trig;
use Math::Complex;
use WebObs::Config;
use WebObs::XML2;

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, %UTM);
require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(setUTMLOCAL geo2utm geo2utml geo2cart greatcircle compass);
$VERSION    = "1.01";

$ENV{"LC_NUMERIC"} = "C";
%UTM = ();
setUTMLOCAL();    # load default, not presuming later setUTMLOCAL calls by user

=pod

=head1 FUNCTIONS

=cut

=pod

=head2 setUTMLOCAL

Sets the %UTM structure with the contents of $utmfilename (if provided and exists)
or with the contents of $WEBOBS{UTM_LOCAL} -the default definitions- (if it exists).
Returns %UTM address if loaded successfully, 0 otherwise.

	print "OK" if ( setUTMLOCAL($utmfilename) ); # try load $utmfilename or default settings

	print Dumper setUTMLOCAL();                  # try load + dump the default UTM settings

=cut

sub setUTMLOCAL {
	if ($_[0] && -e "$_[0]") {
		%UTM = ();
		%UTM = readCfg($_[0]);
	}
	else {
		if ((exists $WEBOBS{UTM_LOCAL}) && -e $WEBOBS{UTM_LOCAL}) {
			%UTM = ();
			%UTM = readCfg($WEBOBS{UTM_LOCAL}) ;
		}
	}
	if (scalar(keys(%UTM))) { return \%UTM }
	else                    { return 0 }
}

=pod

=head2 ign0001

Calcul de la latitude isométrique

	$L = IGN0001(PHi,E);  # $L = altitude isométrique (PHI = latitude, E = première excentricité de l'ellpsoide)

	References:
	I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.

=cut

sub ign0001 {

	my $p = shift;
	my $e = shift;

	# Jeux d'essai
	#$e = 0.08199188998; $p = 0.872664626;
	my $l = log(tan(pi/4 + $p/2)*(((1.0 - $e*sin($p))/(1.0 + $e*sin($p)))**($e/2)));
	return $l;
}

=pod

=head2 ign0009

#IGN0009 Transformation de coordonnées géographiques ellipsoidales en coordonnées cartésiennes.
#       [X,Y,Z]=IGN0009(LAM,PHI,HE,A,E) renvoie les coordonnées cartésiennes X,Y,Z à
#       partir des paramètres:
#           LAM = longitude par rapport au méridien origine
#           PHI = latitude
#           HE = hauteur au dessus de l'ellipsoide
#           A = demi-grand axe de l'ellipsoide
#           E = première excentricité de l'ellipsoide
#
#       Autre algorithme utilisé: IGN0021

#   References:
#       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0009 {
	my $l = shift;
	my $p = shift;
	my $he = shift;
	my $a = shift;
	my $e = shift;

	my $N = ign0021($p,$a,$e);

	my $x = ($N + $he)*cos($p)*cos($l);
	my $y = ($N + $he)*cos($p)*sin($l);
	my $z = ($N*(1 - $e*$e) + $he)*sin($p);

	return ($x,$y,$z);
}


=pod

=head2 ign0012

#IGN0012 Transformation de coordonnées cartésiennes en coordonnées géographiques.
#       [LAM,PHI,HE]=IGN0012(X,Y,Z,A,E) renvoie les coordonnées géographiques LAM
#       (longitude par rapport au méridien origine), PHI (latitude) et HE (auteur ellipsoidale)
#       à partir des paramètres:
#           X,Y,Z = coordonnées cartésiennes
#           A = demi-grand axe de l'ellipsoide
#           E = première excentricité de l'ellipsoide

#   References:
#       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-14

=cut

sub ign0012 {
	my $x = shift;
	my $y = shift;
	my $z = shift;
	my $a = shift;
	my $e = shift;


	# Jeu d'essai
	#$a = 6378249.2; $e = 0.08248325679; $x = 6376064.695; $y = 111294.623; $z = 128984.725;

	my $EPS = 1e-11;	# EPS = tolérance de convergence, en rad
	my $IMAX = 10;               # Imax = nombre maximum d'itérations

	my $R = sqrt($x*$x + $y*$y);
	my $l = 2*atan($y/($x + $R));
	my $p;
	my $h;
	my $p0 = atan($z/sqrt($x*$x + $y*$y*(1 - ($a*$e*$e)/sqrt($x*$x + $y*$y + $z*$z))));
	my $p1;
	my $i = 0;
	my $fin = 0;
	while ($i < $IMAX && !$fin) {
		$i++;
		$p1 = atan(($z/$R)/(1 - ($a*$e*$e*cos($p0))/($R*sqrt(1 - $e*$e*sin($p0)**2))));
		my $res = abs($p1-$p0);
		if ($res < $EPS) {
			$fin = 1;
		}
		$p0 = $p1;
	}
	if ($fin) {
		$p = $p1;
		$h = $R/cos($p) - $a/sqrt(1 - $e*$e*sin($p)**2);
	}

	return ($l,$p,$h);

}


=pod

=head2 ign0013b

#IGN0013B Transformation de coordonnées à 7 paramètres ntre 2 systèmes - passage "inverse".
#       V=IGN0013B(TX,TY,TZ,D,RX,RY,RZ,U) renvoie le vecteur de coordonnées cartésiennes
#       dans le système 2 V = [VX,VY,VZ] à partir des paramètres:
#           TX = translation suivant l'axe des x (de 2 vers 1)
#           TY = translation suivant l'axe des y (de 2 vers 1)
#           TZ = translation suivant l'axe des z (de 2 vers 1)
#           D = facteur d'échelle (de 2 vers 1)
#           RX = angle de rotation autour de l'axe des x, en rad (de 2 vers 1)
#           RY = angle de rotation autour de l'axe des y, en rad (de 2 vers 1)
#           RZ = angle de rotation autour de l'axe des z, en rad (de 2 vers 1)
#           U = [UX,UY,UZ] = vecteur de coordonnées cartésiennes dans le sytème 2

#   References:
#       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0013b {
	my $tx = shift;
	my $ty = shift;
	my $tz = shift;
	my $d = shift;
	my $rx = shift;
	my $ry = shift;
	my $rz = shift;
	my $ux = shift;
	my $uy = shift;
	my $uz = shift;

	my @v;

	# jeux d'essai
	#$u = [4154005.81,-80587.328,4823289.532]; $tx = -69.4; $ty = 18; $tz = 452.2; $d = -3.21e-6; $rx = 0; $ry = 0; $rz = 0.00000499358;

	$v[0] = ($tx - $ux)*($d - 1) + ($tz - $uz)*$ry - ($ty - $uy)*$rz;
	$v[1] = ($ty - $uy)*($d - 1) + ($tx - $ux)*$rz - ($tz - $uz)*$rx;
	$v[2] = ($tz - $uz)*($d - 1) + ($ty - $uy)*$rx - ($tx - $ux)*$ry;

	return @v;
}

=pod

=head2 ign0021

#IGN0021 Calcul de la grande normale de l'ellipsoide.
#       N=IGN0009(PHI,A,E) renvoie la grande normale N à partir des paramètres:
#           PHI = latitude
#           A = demi-grand axe de l'ellipsoide
#           E = première excentricité de l'ellipsoide
#
#       Autre algorithme utilisé: IGN0021

#   References:
#       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0021 {
	my $p = shift;
	my $a = shift;
	my $e = shift;

	my $n =  $a/sqrt(1 - $e*$e*sin($p)**2);

	return $n;
}


=pod

=head2 ign0025

#IGN0025 Calcul des coefficients pour arc de méridien
#       C=IGN0025(E) renvoie un vecteur C de 5 coefficients à partir du paramètre:
#           E = première excentricité de l'ellispoide

#   References:
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0025 {
	my $e = shift;
	# Jeux d'essai
	#$e = 0.08199188998;

	my @c;
	$c[0] = -175.0/16384*$e**8 - 5.0/256*$e**6 - 3.0/64*$e**4 - 1.0/4*$e**2 + 1;
	$c[1] = -105.0/4096*$e**8 - 45.0/1024*$e**6 - 3.0/32*$e**4 - 3.0/8*$e**2;
	$c[2] = 525.0/16384*$e**8 + 45.0/1024*$e**6 + 15.0/256*$e**4;
	$c[3] = -175.0/12288*$e**8 - 35.0/3072*$e**6;
	$c[4] = 315.0/131072*$e**8;

	return @c;
}


=pod

=head2 ign0026

#IGN0026 Calcul de l'abscisse curviligne sur l'arc de méridien pour une latitude donnée.
#       BET=IGN0026(PHI,C) renvoie l'abscisse curviligne BET à partir des paramètres:
#           PHI = latitude
#           C = tableau de 5 coefficients pour arc de méridien

#   References:
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0026 {
	my $p = shift;
	my @c = shift;

	my $b = $c[0]*$p + $c[1]*sin(2*$p) + $c[2]*sin(4*$p) + $c[3]*sin(6*$p) + $c[4]*sin(8*$p);

	return $b;
}


=pod

=head2 ign0028

#IGN0028 Calcul des coefficients pour la projection Mercator Transverse
#       C=IGN0028(E) renvoie un vecteur C de 5 coefficients à partir du paramètre:
#           E = première excentricité de l'ellispoide

#   References:
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0028 {
	my $e = shift;
	# Jeux d'essai
	#$e = 0.08199188998;

	my @c;
	$c[0] = -175.0/16384*$e**8 - 5.0/256*$e**6 - 3.0/64*$e**4 - 1.0/4*$e**2 + 1;
	$c[1] = -901.0/184320*$e**8 - 9.0/1024*$e**6 - 1.0/96*$e**4 + 1.0/8*$e**2;
	$c[2] = -311.0/737280*$e**8 + 17.0/5120*$e**6 + 13.0/768*$e**4;
	$c[3] = 899.0/430080*$e**8 + 61.0/15360*$e**6;
	$c[4] = 49561.0/41287680*$e**8;

	return @c;

}


=pod

=head2 ign0030

#IGN0030 Transformation de coordonnées géographiques en coordonnées projection Mercator Transverse.
#       [X,Y]=IGN0030(LC,N,XS,YS,E,LAM,PHI) renvoie les coordonnées en projection
#       Transverse Mercator X et Y à partir des paramètres:
#           LC = longitude origine par rapport au méridien origine
#           N = rayon de la sphère intermédiaire
#           XS,YS = constantes sur X, Y
#           E = première excentricité de l'ellipsoide
#           LAM = longitude
#           PHI = latitide
#
#       Autres algorithmes utilisés: IGN0001, IGN0028; IGN0052

#   References:
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13

=cut

sub ign0030 {
	my $lc = shift;
	my $n = shift;
	my $xs = shift;
	my $ys = shift;
	my $e = shift;
	my $l = shift;
	my $p = shift;

	# Jeux d'essai
	#$lc = -0.05235987756; $n = 6375697.8456; $xs = 500000; $ys = 0; $e = 0.08248340004; $l = -0.0959931089; $p = 0.6065019151;

	my @c = ign0028($e);
	my $L = ign0001($p,$e);
	my $P = asin(sin($l - $lc)/cosh($L));
	my $LS = ign0001($P,0);
	$L = atan(sinh($L)/cos($l - $lc));

	my $z = Math::Complex->new($L,$LS);
	my $Z = $n*$c[0]*$z + $n*($c[1]*sin(2*$z) + $c[2]*sin(4*$z) + $c[3]*sin(6*$z) + $c[4]*sin(8*$z));

	my $x = $Z->Im() + $xs;
	my $y = $Z->Re() + $ys;

	return ($x,$y);

}


=pod

=head2 ign0052

#IGN0052 Détermination des paramètres de calcul pour la projection Mecator Transverse.
#       [LC,N,XS,YS]=IGN0052(A,E,K0,L0,P0,X0,Y0) renvoie la longitude origine LC, le
#       rayon de la sphère intermédiaire N et les constances XS et YS à partir des paramètres:
#           A = demi-grand axe de l'ellipsoide
#           E = première excentricité de l'ellipsoide
#           K0 = facteur d'échelle au point d'origine
#           L0 = longitude origine par rapport au méridien origine
#           P0 = latitude du point origine
#           X0,Y0 = coordonnées en projection du point origine
#
#       Autres algorithmes utilisés: IGN0025, IGN0026

#   References:
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-13
#   Updated : 2003-01-13


=cut

sub ign0052 {
	my $a = shift;
	my $e = shift;
	my $k0 = shift;
	my $l0 = shift;
	my $p0 = shift;
	my $x0 = shift;
	my $y0 = shift;

	# Jeux d'essai
	#$a = 6377563.3963; $e = 0.08167337382; $k0 = 0.9996012; $l0 = -0.03490658504; $p0 = 0.85521133347; $x0 = 400000; $y0 = -100000;

	my $lc = $l0;
	my $n = $k0*$a;
	my $xs = $x0;
	my @C = ign0025($e);
	my $B = ign0026($p0,@C);
	my $ys = $y0 - $n*$B;

	return ($lc,$n,$xs,$ys);
}


=pod

=head2 geo2utm

#GEO2UTM Conversion coordonnées WGS84 géographiques à UTM20
#       ENU=GEO2UTMWGS(LL) retourne une matrice de coordonnées UTM [E N]
#       avec E = Est (m), N = Nord (m), à partir d'une matrice
#       de coordonnées géographiques [LAT LON] avec LAT = latitude (degrés),
#       LON = longitude (degrés).

#   References:
#       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#       I.G.N., Transformation entre systèmes géodésiques, Service de Géodésie et Nivellement, http://www.ign.fr, 1999/2002.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-12-02
#   Updated : 2004-04-27

=cut

sub geo2utm {
	my $p1 = shift;
	my $l1 = shift;
	my $D0 = 180/pi;
	my ($F0,$K0,$P0,$L0,$X0,$Y0) = utmwgs($p1,$l1);

	# Définition des constantes
	my $A1 = $UTM{ELLIPSOID_WGS84_SEMIMAJOR_AXIS};	# WGS84 demi grand axe
	my $F1 = 1/$UTM{ELLIPSOID_WGS84_INVERSE_FLATTENING};	# WGS84 aplatissement

	# Conversion des données
	$P0 /= $D0;
	my $B1 = $A1*(1 - $F1);
	my $E1 = sqrt(($A1*$A1 - $B1*$B1)/($A1*$A1));

	$p1 = $p1/$D0;        # Phi = Latitude (rad)
	$l1 = $l1/$D0;        # Lambda = Longitude (rad)

	# Transformation Géographiques => UTM20 (WGS84)
	my ($LC,$N,$XS,$YS) = ign0052($A1,$E1,$K0,$L0,$P0,$X0,$Y0);
	my ($e,$n) = ign0030($LC,$N,$XS,$YS,$E1,$l1,$p1);


	return ($e,$n,$F0);
}


=pod

=head2 geo2utml

#GEO2UTMSA Conversion coordonnées géographiques WGS84 à UTM local (Ste-Anne pour Guadeloupe)
#       ENU=GEO2UTMSA(LLH) retourne une matrice de coordonnées UTM [E N U]
#       avec E = Est (m), N = Nord (m), U = Altitude (m), à partir d'une matrice
#       de coordonnées géographiques [LAT LON ELE] avec LAT = latitude (degrés),
#       LON = longitude (degrés) et ELE = hauteur ellipsoidale (km).

#   Bibliographie:
#       I.G.N., Changement de système géodésique: Algorithmes, Notes Techniques NT/G 80, janvier 1995.
#       I.G.N., Projection cartographique Mercator Transverse: Algorithmes, Notes Techniques NT/G 76, janvier 1995.
#       I.G.N., Transformation entre systèmes géodésiques, Service de Géodésie et Nivellement, http://www.ign.fr, 1999/2002.
#   Author: F. Beauducel, OVSG-IPGP
#   Created : 2003-01-10
#   Updated : 2004-04-27

=cut

sub geo2utml {
	my $p1 = shift;
	my $l1 = shift;
	my $h1 = shift;

	# Définition des constantes
	my $D0 = 180/pi;
	my $A1 = $UTM{ELLIPSOID_WGS84_SEMIMAJOR_AXIS};	# WGS84 demi grand axe
	my $F1 = 1/$UTM{ELLIPSOID_WGS84_INVERSE_FLATTENING};	# WGS84 aplatissement
	my $A2 = $UTM{ELLIPSOID_LOCAL_SEMIMAJOR_AXIS};	# HAYFORD 1909 demi grand axe
	my $F2 = 1/$UTM{ELLIPSOID_LOCAL_INVERSE_FLATTENING};	# HAYFORD 1909 aplatissement
	my ($F0,$K0,$P0,$L0,$X0,$Y0) = utm($p1,$l1);

	my $TX = $UTM{GEODETIC_LOCAL2WGS84_TRANSLATION_X};               # HAYFORD 1909 => WGS84 : Translation X (m)
	my $TY = $UTM{GEODETIC_LOCAL2WGS84_TRANSLATION_Y};                 # HAYFORD 1909 => WGS84 : Translation Y (m)
	my $TZ = $UTM{GEODETIC_LOCAL2WGS84_TRANSLATION_Z};               # HAYFORD 1909 => WGS84 : Translation Z (m)
	my $D = $UTM{GEODETIC_LOCAL2WGS84_SCALE_FACTOR};              # HAYFORD 1909 => WGS84 : Facteur d'échelle (ppm)
	my $RX = $UTM{GEODETIC_LOCAL2WGS84_ROTATION_X}*pi/(180*3600);  # HAYFORD 1909 => WGS84 : Rotation X (")
	my $RY = $UTM{GEODETIC_LOCAL2WGS84_ROTATION_Y}*pi/(180*3600); # HAYFORD 1909 => WGS84 : Rotation Y (")
	my $RZ = $UTM{GEODETIC_LOCAL2WGS84_ROTATION_Z}*pi/(180*3600);  # HAYFORD 1909 => WGS84 : Rotation Z (")

	# Conversion des données
	my $B1 = $A1*(1 - $F1);
	my $E1 = sqrt(($A1*$A1 - $B1*$B1)/($A1*$A1));
	my $B2 = $A2*(1 - $F2);
	my $E2 = sqrt(($A2*$A2 - $B2*$B2)/($A2*$A2));

	$p1 = $p1/$D0;        # Phi = Latitude (rad)
	$l1 = $l1/$D0;        # Lambda = Longitude (rad)

	# Transformation Géographiques => Cartésiennes WGS84
	my ($x1,$y1,$z1) = ign0009($l1,$p1,$h1,$A1,$E1);

	# Transformation par similitude 3D à 7 paramètres WGS84 => HAYFORD 1909
	my ($x2,$y2,$z2) = ign0013b($TX,$TY,$TZ,$D,$RX,$RY,$RZ,$x1,$y1,$z1);

	# Transformation Cartésiennes => Géographiques (HAYFORD 1909)
	my ($l2,$p2,$h2) = ign0012($x2,$y2,$z2,$A2,$E2);

	# Transformation Géographiques => UTM20 (HAYFORD 1909)
	my ($LC,$N,$XS,$YS) = ign0052($A2,$E2,$K0,$L0,$P0,$X0,$Y0);
	my ($e2,$n2) = ign0030($LC,$N,$XS,$YS,$E2,$l2,$p2);

	return ($e2,$n2,$F0);
}

=pod

=head2 utmwgs

Returns UTM WGS84 parameters (zone, false easting and northing) from latitude and longitude

=cut

sub utmwgs {
	my $p1 = shift;
	my $l1 = shift;

	my $D0 = 180/pi;
	my $F0 = $UTM{UTM_ZONE};		# utm zone
	my $K0 = $UTM{UTM_SCALE_FACTOR};	# scale factor (0.9996)
	if ($F0 le 0) {
		#$F0 = int(($l1 + 183)/6);
		$F0 = int(($l1 + 183)/6 + .5);
	}
	my $L0 = (6*$F0 - 183)/$D0;	# longitude origin (rad)
	my $P0 = 0;			# latitude origin (rad) / UTM20 = 0
	my $X0 = 500000;		# false easting
	my $Y0 = 0;			# false northing
	if ($p1 lt 0) {
		$Y0 = 10000000;
	}

	return ($F0,$K0,$P0,$L0,$X0,$Y0);
}

=pod

=head2 utm

returns UTM parameters (zone, false easting and northing) from latitude and longitude

=cut

sub utm {
	my $p1 = shift;
	my $l1 = shift;

	my $D0 = 180/pi;
	#my $F0 = int(($l1 + 183)/6);			# UTM zone
	my $F0 = int(($l1 + 183)/6 + .5);       # UTM zone
	my $K0 = $UTM{UTM_LOCAL_SCALE_FACTOR};	# scale factor
	my $L0 = $UTM{UTM_LOCAL_MERIDIAN_ORIGIN}/$D0;	# longitude origin (rad)
	my $P0 = 0;			# latitude origin (rad) / UTM20 = 0
	my $X0 = $UTM{UTM_LOCAL_FALSE_EASTING};		# false easting
	my $Y0 = 0;			# false northing
	if ($p1 lt 0) {
		$Y0 = 10000000;
	}

	return ($F0,$K0,$P0,$L0,$X0,$Y0);
}


=pod

=head2 geo2cart

#GEO2CART Geodetic WGS84 to cartesian geocentric coordinates
#   Author: F. Beauducel, IPGP

=cut

sub geo2cart {
	my $p1 = shift;
	my $l1 = shift;
	my $h1 = shift;
	my $D0 = 180/pi;

	# Définition des constantes
	my $A1 = $UTM{ELLIPSOID_WGS84_SEMIMAJOR_AXIS};	# WGS84 demi grand axe
	my $F1 = 1/$UTM{ELLIPSOID_WGS84_INVERSE_FLATTENING};	# WGS84 aplatissement

	# Conversion des données
	my $B1 = $A1*(1 - $F1);
	my $E1 = sqrt(($A1*$A1 - $B1*$B1)/($A1*$A1));

	# Transformation Géographiques (WGS84) => géocentriques
	my ($x,$y,$z) = ign0009($l1/$D0,$p1/$D0,$h1,$A1,$E1);


	return ($x,$y,$z);
}


=pod

=head2 greatcircle

#	greatcircle(lat1,lon1,lat2,lon2) computes the distance (in km) between two
#	geographic coordinates lat/lon (greatcircle Haversin formula). It returns
#	also the bear angle (in °).
#
#	Reference: modified from greatcircle.m by F. Beauducel, IPGP

=cut

sub greatcircle {
	my $k = pi/180;

	my $lat1 = shift;
	my $lon1 = shift;
	my $lat2 = shift;
	my $lon2 = shift;

	my $dlat = ($lat2 - $lat1)*$k;
	my $dlon = ($lon2 - $lon1)*$k;

	my $rearth = 6371;	# volumetric Earth radius (in km)

	my $dist = $rearth*2*asin(sqrt(sin($dlat/2)**2 + cos($lat1*$k)*cos($lat2*$k)*sin($dlon/2)**2));
	my $bear = atan2(sin($dlon)*cos($lat2*$k),cos($lat1*$k)*sin($lat2*$k) - sin($lat1*$k)*cos($lat2*$k)*cos($dlon))/$k;

	return $dist, $bear;
}

=pod

=head2 compass

#	compass(azimuth) returns a short string indicating geographical orientation from azimuth in
#	degrees from North, clockwise

=cut
sub compass {
       my @nesw = ('N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSW','SW','WSW','W','WNW','NW','NNW');
       my $az = shift;
       $az = ($az*16/360)%16;
       return $nesw[$az];

}


=pod

=head2 KMLfeed

#	KMLfeed(URL) dowloads a KML string from URL and returns latitude, longitude,
#	altitude, and timestamp.

=cut

sub KMLfeed {

	my $url = shift;
	my ($lat, $lon, $alt, $date);

	if ($url =~ /^http/) {
		my @kml = qx(curl -s "$url" | $WEBOBS{XML2_PRGM});
		my $root = '/q:quakeml/eventParameters/event';
		my $pos = findvalue("$root/Point/coordinates=",\@kml);
		($lon,$lat,$alt) = split(/,/,$pos);
		$date = findvalue("$root/TimeStamp/when=",\@kml);
	}

	return $lat, $lon, $alt, $date;
}

1;

__END__

=pod

=head1 AUTHOR

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2022 - Institut de Physique du Globe Paris

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
