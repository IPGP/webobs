#!/usr/bin/perl -w

# ---------------------------------------------------------------
# ------------ traceLog -----------------------------------------
# ---------------------------------------------------------------
# Affiche le contenu du fichier defini dans le fichier de configuration
# Affichage d'une note dinformations generales sur les stations (cas de l'affichage complet)
# - - - - - - - - - - - - - - - - - - - - - - -
sub traceLog
{
   # ---- Variables de la date courante
   my ($secondes, $minutes, $heures, $jour_mois, $mois, $annee, $jour_semaine, $jour_calendaire, $heure_ete) = localtime(time);
   my $Y=$annee+1900;
   my $M=$mois+1;
   if ($M < 10) {$M="0".$M; }
   my $D=$jour_mois;
   if ($D < 10) {$D="0".$D; }
   
   my $fn=shift;
   my $msg=shift;
   open(LOG, ">>$logFile") || die "fichier $logFile non trouvé\n";
   if ($msg eq "S") { print LOG "\n$Y-$M-$D $heures:$minutes:$secondes - $fn: ***** START *****\n"; }
   elsif ($msg eq "E") { print LOG "$Y-$M-$D $heures:$minutes:$secondes - $fn: ***** END *****\n\n"; }
   else { print LOG "$heures:$minutes:$secondes - $fn: $msg\n"; }
   close LOG;
}

1;
