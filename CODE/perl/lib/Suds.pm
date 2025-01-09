package WebObs::Suds;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Suds - SUDS related functions  

=head1 FUNCTIONS

=cut

use strict;
use warnings;

require WebObs::Config;

=pod

=head2 demain

=cut 

sub demain
{
    my $annee = shift;
    my $mois = shift;
    my $jour = shift;
    ($annee,$mois,$jour) = split(/-/,qx(date -d "$annee-$mois-$jour 1 day" +\%Y-\%m-\%d|tr -d '\n'));
    return ($annee,$mois,$jour);
}

=pod

=head2 minute_suivante

=cut 

sub minute_suivante
{
    my $annee = shift;
    my $mois = shift;
    my $jour = shift;
    my $heure = shift;
    my $minute = shift;
    my $seconde = shift;
    ($annee,$mois,$jour,$heure,$minute,$seconde) = split(/-/,qx(date -d "$annee-$mois-$jour $heure:$minute:$seconde 1 minute" +\%Y-\%m-\%d-\%H-\%M-\%S|tr -d '\n'));
    return ($annee,$mois,$jour,$heure,$minute,$seconde);
}

=pod

=head2 dateFichierSuds

=cut 

sub dateFichierSuds
{
    my $suds = shift;
    if (length(basename($suds)) == 12) {

        #IASPEI
    } elsif (length(basename($suds)) == 19) {

        #SUDS2
    } elsif (length(basename($suds)) == 21) {

        #SUDS2 avec suffixe
    }
}

=pod

=head2 fichierSudsSuivants

=cut 

sub fichiersSudsSuivants
{
    my $suds = shift;
    my $nb_suds = shift;
    my @liste_suds;
    if (length(basename($suds)) == 12) {

        # IASPEI
        my $longueur_nom_iaspei = length($WebObs::WEBOBS{PATH_SOURCE_SISMO_GUA})+2;
        my ($annee4, $mois, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_iaspei a4 a2 a2 x3 a2 a2 a2 a2 x a3",$suds);
        my ($annee4lendemain,$moislendemain,$jourlendemain) = demain($annee4,$mois,$jour);
        my $chemin_date="$WebObs::WEBOBS{RACINE_SIGNAUX_SISMO}/$WebObs::WEBOBS{PATH_SOURCE_SISMO_GUA}/$annee4$mois$jour/";
        my $chemin_lendemain="$WebObs::WEBOBS{RACINE_SIGNAUX_SISMO}/$WebObs::WEBOBS{PATH_SOURCE_SISMO_GUA}/$annee4lendemain$moislendemain$jourlendemain";
        ( -d $chemin_lendemain ) or $chemin_lendemain="";
        $nb_suds--;
        push(@liste_suds,split(/\n/, qx(find $chemin_date $chemin_lendemain -type f -print|sort|fgrep -A$nb_suds $suds)));
    } elsif (length(basename($suds)) == 19) {

        # SUDS2
        my $longueur_nom_gwa = length($WebObs::WEBOBS{PATH_SOURCE_SISMO_GWA})+11;
        push(@liste_suds,$WebObs::WEBOBS{RACINE_SIGNAUX_SISMO}.$suds);
        for(my $i = 1; $i < $nb_suds; $i++) {
            my ($annee4, $mois, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_gwa a4 a2 a2 x a2 a2 a2 x a3",$suds);
            ($annee4, $mois, $jour, $heure, $minute, $seconde) = minute_suivante($annee4, $mois, $jour, $heure, $minute, $seconde);
            $suds = "/$WebObs::WEBOBS{PATH_SOURCE_SISMO_GWA}/$annee4$mois$jour/$annee4$mois${jour}_$heure$minute$seconde.$extension";
            push(@liste_suds,$WebObs::WEBOBS{RACINE_SIGNAUX_SISMO}.$suds);
        }
    }
    return @liste_suds;
}

=pod

=head2 fusion_suds

=cut 

sub fusion_suds
{
    my $suds = shift;
    my $nb_suds = shift;
    my @liste_suds = fichiersSudsSuivants($suds,$nb_suds);
    my $dest_dir = qx(mktemp -d -p /tmp fusion_suds.XXXXXXXXXX);
    chomp($dest_dir);
    my $dest = $dest_dir."/".basename($suds);
    print qx($WebObs::WEBOBS{RACINE_TOOLS_SHELLS}/sudsjoin_multiple $dest @liste_suds);
    return ($dest_dir,$dest);
}

=pod

=head2 Fonctions SUDS IASPEI

=head2 imagesSudsMC

=head2 fichierSudsImage

=head2 fichierSuds

=head2 infosSuds

=head2 imageVoiesSefran

=head2 Fonctions SUDS EARTHWORM

=head2 imagesSuds2MC

=head2 fichierSuds2Image 
renvoi le nom du fichier SUDS a partir du nom de l'image Sefran2

=head2 fichiersSuds2

=head2 infosSuds2

=head2 imageVoiesSefran2

=cut 

sub imagesSudsMC
{
    my $suds_debut = shift;
    my $nb_suds = $WebObs::WEBOBS{MC_NOMBRE_FICHIERS_IMAGES} - 2;

    my $longueur_nom_iaspei = length($WebObs::WEBOBS{PATH_SOURCE_SISMO_GUA})+2;
    my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $extension;
    ($annee4, $mois, $jour, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_iaspei a4 a2 a2 x a2 a2 a2 a2 x a3",$suds_debut);

    my $annee2 = substr($annee4,2,2);
    my $racineImage = $annee2.$mois.$jour.$heure.$minute.$seconde;
    my $image = $racineImage.".png";
    my ($annee4lendemain,$moislendemain,$jourlendemain) = demain($annee4,$mois,$jour);
    my $repDate = $annee4.$mois.$jour;
    my $repDateLendemain = $annee4lendemain.$moislendemain.$jourlendemain;

    my $pathSrcImg="$WebObs::WEBOBS{SEFRAN_RACINE}/$repDate/$WebObs::WEBOBS{SEFRAN_IMAGES_SUDS}";
    my $pathSrcImgLendemain="$WebObs::WEBOBS{SEFRAN_RACINE}/$repDateLendemain/$WebObs::WEBOBS{SEFRAN_IMAGES_SUDS}";
    ( -d $pathSrcImgLendemain ) or $pathSrcImgLendemain="";

    my $car_debut_fichier = length("$WebObs::WEBOBS{SEFRAN_RACINE}/");
    my $imageMC = "$annee4/$mois/$annee2$mois$jour$heure$minute$seconde.png";
    return $imageMC,split(/\n/, qx(find $pathSrcImg $pathSrcImgLendemain -type f -print|sort|grep -A$nb_suds $racineImage|cut -c$car_debut_fichier-));
}

sub fichierSudsImage
{
    my $imageSuds = shift;
    my $longueur_nom_suds = length($WebObs::WEBOBS{SEFRAN_IMAGES_SUDS})+2;
    my $annee4; my $mois; my $jour; my $annee2; my $heure; my $minute; my $seconde; my $reseau; my $ext;
    ($annee4,$mois,$jour,$annee2,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x a4 a2 a2 x$longueur_nom_suds a2 a2 a2 a2 a2 a2 a3 x a3",$_;
    my $var = "PATH_SOURCE_SISMO_".$reseau;
    return "$WebObs::WEBOBS{$var}/$annee4$mois$jour/$jour$heure$minute$seconde.$reseau";
}

sub fichiersSuds
{
    my @imagesSuds = @_;
    my @fichiersSuds;
    for (@imagesSuds) {
        push(@fichiersSuds,$WebObs::WEBOBS{RACINE_SIGNAUX_SISMO}."/".fichierSudsImage($_));
    }
    return @fichiersSuds;
}

sub infosSuds
{
    my $imageSuds = shift;
    my $id_fichier = shift;
    my $longueur_nom_suds = length($WebObs::WEBOBS{SEFRAN_IMAGES_SUDS})+2;
    my $annee4; my $mois; my $jour; my $annee2; my $heure; my $minute; my $seconde; my $reseau; my $ext;
    ($annee4,$mois,$jour,$annee2,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x a4 a2 a2 x$longueur_nom_suds a2 a2 a2 a2 a2 a2 a3 x a3",$_;
    return "Date (début) : <b>$annee4/$mois/$jour</b><br>Heure (début) : <b>$heure:$minute:$seconde</b><br>Réseau : $reseau<br>Fichier n° : <b>$id_fichier</b>";
}

sub imageVoiesSefran
{
    my $suds_debut = shift;
    my $longueur_nom_iaspei = length($WebObs::WEBOBS{PATH_SOURCE_SISMO_GUA})+2;
    my $annee4GU; my $moisGU; my $jourGU; my $heureGU; my $minuteGU; my $secondeGU; my $extensionGU;
    ($annee4GU, $moisGU, $jourGU, $jourGU, $heureGU, $minuteGU, $secondeGU, $extensionGU) = unpack "x$longueur_nom_iaspei a4 a2 a2 x a2 a2 a2 a2 x a3",$suds_debut;
    my $repDate = $annee4GU.$moisGU.$jourGU;
    return "$repDate/$WebObs::WEBOBS{SEFRAN_VOIES_IMAGE}";
}

sub imagesSuds2MC
{
    my $suds_debut = shift;
    my $nb_suds = $WebObs::WEBOBS{MC_NOMBRE_FICHIERS_IMAGES_SEFRAN2} - 2;
    my $longueur_nom_gwa = length($WebObs::WEBOBS{PATH_SOURCE_SISMO_GWA})+11;

    my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $extension;
    ($annee4, $mois, $jour, $heure, $minute, $seconde, $extension) = unpack("x$longueur_nom_gwa a4 a2 a2 x a2 a2 a2 x a3",$suds_debut);

    my $annee2 = substr($annee4,2,2);
    my $racineImage = $annee4.$mois.$jour.$heure.$minute.$seconde;
    my $image = $racineImage.".png";
    my ($annee4lendemain,$moislendemain,$jourlendemain) = demain($annee4,$mois,$jour);
    my $repDate = $annee4.$mois.$jour;
    my $repDateLendemain = $annee4lendemain.$moislendemain.$jourlendemain;

    my $pathSrcImg="$WebObs::WEBOBS{SEFRAN2_RACINE}/$repDate/$WebObs::WEBOBS{SEFRAN2_IMAGES_SUDS}";
    my $pathSrcImgLendemain="$WebObs::WEBOBS{SEFRAN2_RACINE}/$repDateLendemain/$WebObs::WEBOBS{SEFRAN2_IMAGES_SUDS}";
    ( -d $pathSrcImgLendemain ) or $pathSrcImgLendemain="";

    my $car_debut_fichier = length("$WebObs::WEBOBS{SEFRAN2_RACINE}/");
    my $imageMC = "$annee4/$mois/$annee2$mois$jour$heure$minute$seconde.png";
    return $imageMC,split(/\n/, qx(find $pathSrcImg $pathSrcImgLendemain -type f -print|sort|grep -A$nb_suds $racineImage|cut -c$car_debut_fichier-));
}

sub fichierSuds2Image
{
    my $imageSuds = shift;
    my $longueur_nom_suds = length($WebObs::WEBOBS{SEFRAN_IMAGES_SUDS})+11;
    my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $reseau; my $ext;
    ($annee4,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x$longueur_nom_suds a4 a2 a2 a2 a2 a2 a3 x a3",$_;
    return "$WebObs::WEBOBS{PATH_SOURCE_SISMO_GWA}/$annee4$mois$jour/$annee4$mois$jour\_$heure$minute$seconde.$reseau";
}

sub fichiersSuds2
{
    my @imagesSuds = @_;
    my @fichiersSuds;
    for (@imagesSuds) {
        push(@fichiersSuds,$WebObs::WEBOBS{RACINE_SIGNAUX_SISMO}."/".fichierSuds2Image($_));
    }
    return @fichiersSuds;
}

sub infosSuds2
{
    my $imageSuds = shift;
    my $id_fichier = shift;
    my $longueur_nom_suds = length($WebObs::WEBOBS{SEFRAN_IMAGES_SUDS})+11;
    my $annee4; my $mois; my $jour; my $heure; my $minute; my $seconde; my $reseau; my $ext;
    ($annee4,$mois,$jour,$heure,$minute,$seconde,$reseau,$ext) = unpack "x$longueur_nom_suds a4 a2 a2 a2 a2 a2 a3 x a3",$_;
    return "Date (début) : <b>$annee4-$mois-$jour</b><br>Heure (début) : <b>$heure:$minute:$seconde</b><br>Réseau : $reseau<br>Fichier n° : <b>$id_fichier</b>";
}

sub imageVoiesSefran2
{
    my $suds_debut = shift;
    my $longueur_nom_iaspei = length($WebObs::WEBOBS{PATH_SOURCE_SISMO_MIX})+11;
    my $annee4GU; my $moisGU; my $jourGU; my $heureGU; my $minuteGU; my $secondeGU; my $extensionGU;
    ($annee4GU, $moisGU, $jourGU, $heureGU, $minuteGU, $secondeGU, $extensionGU) = unpack "x$longueur_nom_iaspei a4 a2 a2 x a2 a2 a2 x a3",$suds_debut;
    my $repDate = $annee4GU.$moisGU.$jourGU;
    return "$repDate/$WebObs::WEBOBS{SEFRAN2_VOIES_IMAGE}";
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
