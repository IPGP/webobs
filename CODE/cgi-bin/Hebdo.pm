package Hebdo;

=head1 NAME

Hebdo - generates HEBDO html  

=head1 SYNOPSIS
 
 use Hebdo; 

 Hebdo::Params($SearchString, $EventType, $SortBy,$AllowEdit);
 Hebdo::Option(@option);
 Hebdo::Dates($DateCriteria, $Start, $End, @DateList);

 @resultingHTML = Hebdo::Html();

=head1 DESCRIPTION
 
This module generates required HTML code to display WebObs events,
as selected by the client. 

=cut

use strict;
use WebObs::Config;
use WebObs::Grids;
use WebObs::i18n;
use WebObs::Dates;
use WebObs::Utils;
use WebObs::Users;
use Locale::TextDomain('webobs');
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw/strftime/;
use File::Basename;
require Exporter;

our(@ISA, @EXPORT, $VERSION);
@ISA = qw(Exporter);
@EXPORT = qw(Params, Option, Dates, Html);

my $parametreSearch = "";
my $parametreType = "";
my $parametreTri = "";
my $AllowEdit = 0;
my @option;
my @dateListe;

my @feries = WebObs::Dates::readFeries();
my $Ctod   = time(); my @tod  = localtime($Ctod);
my $todayDate   = strftime('%F',@tod);
#----
my $jourSemaine = strftime('%w',@tod); 
my $year       = strftime('%Y',@tod); 
my $numeroSemaine = strftime('%V',@tod); 
my $moisActuel  = strftime('%Y-%m',@tod); 
my $displayTodayDate  = l2u(strftime('%A %d %B %Y',@tod)); 
my $displayAujourdhui = l2u(strftime("$__{'hebdo_long_date_format'}",@tod)); 
my $demainDate  = strftime("%F",localtime($Ctod+86400)); 
my $displayDemain = l2u(strftime("$__{'hebdo_long_date_format'}",localtime($Ctod+86400))); 
my $anneeMax = $year+1;
our $moisCalendrier = $moisActuel;
  
my $critereDate = "";
my $critereDebut = "";
my $critereFin = "";

my %HEBDO = readCfg("$WEBOBS{HEBDO_CONF}");

sub Hebdo::Params {
	($parametreSearch,$parametreType,$parametreTri,$AllowEdit) = @_;
}

sub Hebdo::Option {
	@option = @_;
}

sub Hebdo::Dates {
	my ($s, $i, $ii, $j, $jj, $d1, $d2);
	#--# ($critereDate,$critereDebut,$critereFin,@dateListe) = @_;
	my ($Qdate, $junk) = @_;
	
# requested date is "current week" 
# --------------------------------
if ("$Qdate" ~~ ['currentWeek','semaineCourante']) { 
  	my $lundi = $jourSemaine eq 1 ? "" : "last monday";
  	$critereDebut = qx(date -I -d "$lundi"); chomp($critereDebut);
  	$d1 = l2u(qx(date -d "$lundi" +"$__{'hebdo_date_format'}")); chomp($d1);
  	$critereFin = qx(date -I -d "sunday"); chomp($critereFin);
  	$d2 = l2u(qx(date -d "sunday" +"$__{'hebdo_date_format'}")); chomp($d2);
  	@option = ("interval","$__{'from'} $d1 $__{'to'} $d2 <i>($__{'week'} $numeroSemaine)</i>");
  	for (0..6) {
  		$jj = "$critereDebut $_ days";
  		$j = qx(date -I -d "$jj"); chomp($j);
  		push(@dateListe,$j);
  	}
}

# requested date is "a given week" 
# --------------------------------
elsif (substr($Qdate,4,1) eq "W") { 
  	my $week = substr($Qdate,5);
  	my $nbjour = 7 * ($week - 1);
  	$year = substr($Qdate,0,4);
  	$j = qx(date -d "$year-01-04" +"\%w\"); chomp($j);
  	$j = ($j+6)%7;
  	$critereDebut = qx(date -I -d "$year-01-04 $j days ago"); chomp($critereDebut);	
  	$critereDebut = qx(date -I -d "$critereDebut $nbjour days"); chomp($critereDebut);	
  	$d1 = l2u(qx(date -d "$critereDebut" +"$__{hebdo_date_format}")); chomp($d1);
  	$critereFin = qx(date -I -d "$critereDebut 6 days"); chomp($critereFin);
  	$d2 = l2u(qx(date -d "$critereFin" +"$__{hebdo_date_format}")); chomp($d2);
  	@option = ("interval","$__{'from'} $d1 $__{'to'} $d2 <i>($__{'week'} $week)</i>");
  	for (0..6) {
  		$jj = "$critereDebut $_ days";
  		$j = qx(date -I -d "$jj"); chomp($j);
  		push(@dateListe,$j);
  	}
  	if (substr($Qdate,0,4) == substr($critereDebut,0,4)) { $moisCalendrier = substr($critereDebut,0,7); }
  	else { $moisCalendrier = substr($critereFin,0,7); }
}

# requested date is "current month" or "given month"
# --------------------------------------------------
elsif (("$Qdate" eq "moisCourant") || (length($Qdate) eq 7)) {
  	if ("$Qdate" eq "moisCourant") { 
  		$critereDate = $moisActuel;
  	} else {                                 # ***** Requested Date = a given month
  		$critereDate = $Qdate;
  	}
  	$jj = l2u(qx(date -d "$critereDate-01" +"\%B \%Y")); chomp($jj);
  	@option = ("month","$jj");
  	if ("$parametreTri" eq "Calendar") {
  		$d1 = WebObs::Dates::lundi("$critereDate-01");
  		for (0..41) {
  			$jj = "$d1 $_ days";
  			$j = qx(date -I -d "$jj"); chomp($j);
  			if (($_ > 27) && ($_%7 == 0) && (substr($j,5,2) ne substr($critereDate,5,2))) {
  				last;
  			} else {
  				push(@dateListe,$j);
  			}
  		}
  	} else {
  		for (0..30) {
  			$jj = "$critereDate-01 $_ days";
  			$j = qx(date -I -d "$jj"); chomp($j);
  			if ($j =~ /$critereDate/) {
  				push(@dateListe,$j);
  			}
  		}
  	}
  	$moisCalendrier = $critereDate;
}

# requested date is "today" 
# --------------------------------
elsif ("$Qdate" eq "Today") { 
  	$critereDate = $todayDate;
  	@option = ("day","$displayAujourdhui");
  	@dateListe = "$todayDate";
}

# requested date is "tomorrow" 
# -----------------------------
elsif ("$Qdate" eq "Demain") { 
  	$critereDate = $demainDate;
  	@option = ("day","$displayDemain");
  	@dateListe = "$demainDate";
}

# requested date is "next days" 
# -----------------------------
elsif ("$Qdate" eq "aVenir") { 
  	$critereDate = $todayDate;
  	@option = ("future","$__{'from and after'} $displayTodayDate");
  	# faux "à venir" : 365 prochains jours... (en attendant de trouver comment récupérer la date max.. FB)
  	if ("$parametreTri" eq "Calendar") {
  		$d1 = WebObs::Dates::lundi("$critereDate");
  		for (0..377) {
  			$jj = "$d1 $_ days";
  			$j = qx(date -I -d "$jj"); chomp($j);
  			push(@dateListe,$j);
  		}
  	} else {
  		for (0..365) {
  			$jj = "$todayDate $_ days";
  			$j = qx(date -I -d "$jj"); chomp($j);
  			push(@dateListe,$j);
  		}
  	}
}

# requested date is "all" 
# -----------------------
elsif ("$Qdate" ~~ ['ALL','Tout']) {  
  	@option = ("all","$__{'all events since'} $HEBDO{BANG}");
  	for (0..365*($anneeMax-$HEBDO{BANG})) {
  		$jj = "$HEBDO{BANG}-01-01 $_ days";
  		$j = qx(date -I -d "$jj"); chomp($j);
  		push(@dateListe,$j);
  	}
}

# requested date is "preceeding n days" 
# -------------------------------------
elsif (substr($Qdate,0,1) eq "-") { 
  	my $nbjour = substr($Qdate,1);
  	$critereDebut = qx(date -I -d "$todayDate $nbjour days ago"); chomp($critereDebut);
  	$critereFin = $todayDate;
  	$d1 = l2u(qx(date -d "$critereDebut" +"$__{'hebdo_date_format'}")); chomp($d1);
  	$d2 = l2u(qx(date -d "$todayDate" +"$__{'hebdo_date_format'}")); chomp($d2);
  	@option = ("interval","$__{'from'} $d1 $__{'to'} $d2");
  	for (-$nbjour..0) {
  		$jj = "$todayDate $_ days";
  		$j = qx(date -I -d "$jj"); chomp($j);
  		push(@dateListe,$j);
  	}
  	$moisCalendrier = substr($critereDebut,0,7);;
}

# requested date is "a given year" 
# --------------------------------
elsif (length($Qdate) eq 4) {  
  	$critereDate = $Qdate;
  	@option = ("year","$__{'all the year'} $critereDate");
  	if ("$parametreTri" eq "Calendar") {
  		$d1 = WebObs::Dates::lundi("$critereDate-01-01");
  		for (0..377) {
  			$jj = "$d1 $_ days";
  			$j = qx(date -I -d "$jj"); chomp($j);
  			if (($_ > 27) && ($_%7 == 0) && (substr($j,0,4) ne substr($critereDate,0,4))) {
  				last;
  			} else {
  				push(@dateListe,$j);
  			}
  		}
  	} else {
  		for (0..365) {
  			$jj = "$critereDate-01-01 $_ days";
  			$j = qx(date -I -d "$jj"); chomp($j);
  			if ($j =~ /$critereDate/) {
  				push(@dateListe,$j);
  			}
  		}
  	}
  	$moisCalendrier = "$critereDate-01";
}

# requested date is "a given day" 
# -------------------------------
else { 
  	$critereDate = $Qdate;
  	$jj = qx(date -I -d "$critereDate"); chomp($jj);
  	$j = l2u(qx(date -d "$jj" +"$__{hebdo_long_date_format}")); chomp($j);
  	@option = ("day","$j");
  	@dateListe = "$jj";
  	$moisCalendrier = substr($jj,0,7);
}
}

sub Html {

	if (! WebObs::Users::clientHasRead(type=>'authmisc',name=>"HEBDO")) {
		die "You cannot display HEBDO";
	}

	##my %HEBDO = readCfg($WEBOBS{HEBDO_CONF});
	my $fileHebdo = "$HEBDO{FILE_NAME}";
	my %types = readCfg("$HEBDO{FILE_TYPE_EVENEMENTS}");

	my @contenu;
  
	my ($i, $ii, $m, $texte);
  	my $j0 = "9999-99-99";
  	my ($jourCal, $jourCalAffiche, $moisCalAffiche);
  	my (@evenement, %confSta, $nomSta, @str, @aliasSta);
  	my ($fileEvenement, $dateEvenement);

	# Title 
	push(@contenu, "<H2>$HEBDO{TITLE} : ");
	if ($parametreSearch ne "") {
		push(@contenu, "<i>\"$parametreSearch\"</i> ");
	}
	push(@contenu, "$option[1]</H2>");
	
	# Remove types if requested or those for which user has not read authorization 
	for (keys %types){
		delete $types{$_} if ($_ ne $parametreType && !($parametreType ~~ ['ALL','Tout','ALLnNODES','ToutReseaux']));
		delete $types{$_} if (! WebObs::Users::clientHasRead(type=>'authmisc',name=>"HEBDO_$_"));
	}
	my @allowedTypes = keys %types;

  	if ( -e $fileHebdo ) {
  
  		my @lignesFichier;
  		my @lignes;
  		my @lignesValides;
		@lignesFichier = WebObs::Config::readFile($fileHebdo);

		foreach (@lignesFichier) {
			my @champ = split(/\|/,$_);
			if ($champ[5] ~~ @allowedTypes) {
				push(@lignes,l2u($_));
			}
		}
  
  		# Filter lines on Search regexp if requested 
  		if ($parametreSearch ne "") {
  			@lignes = grep(/$parametreSearch/i,@lignes);
  		}
  		
  		# Integration of the NODE's events (FB, July 2007):
  		# ... we first add partial data from the event filename (date, place and type=NODES) to the table @lignes,
  		# in order to not read all the event files.
  		# Full data will be read only if selected for display
  		if ($parametreType ~~ ['NODES','Reseaux','ALLnNODES','ToutReseaux']) {
  			my @sta = qx(/bin/ls $NODES{PATH_NODES});
  			my @events;
  			my $event;
  			my $pathevent;
  			my $node;
  			for (@sta) {
  				$node = $_;  chomp($node);
				#FB-was: @events = qx(find $NODES{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS}/ -name '*.txt' -printf '%f|%p\n');
  				@events = qx(find $NODES{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS}/ -name '*.txt');
  				for (@events) {
					#FB-was: ($event,$pathevent) = split(/\|/,$_);  chomp($pathevent);
  					$pathevent = $_;  chomp($pathevent);
  					$event = basename($pathevent);
  					my ($st,$dt,$hr) = split(/_/,$event);
  					if ($dt ne "Projet.txt") { 
  						if ($hr =~ "NA") { $hr = ""; }
  						else { $hr = substr($hr,0,2).":".substr($hr,3,2); }
  						push(@lignes,"0|$dt|$hr|$dt||NODES|||$node|$pathevent");
  					}
  				}
  			}
  			@lignes = sort tri_date_avec_id @lignes;
  		}
  		
  		# tri par ordre chronologique (date + heure)
  		#@lignes = sort {
  		#	(split(/\|/,$a))[1] cmp (split(/\|/,$b))[1] ||
  		#	(split(/\|/,$a))[2] cmp (split(/\|/,$b))[2]
  		#} @lignes;
  		
  		@lignes = reverse(@lignes);
  
  		# Affichage avec tri par types
		#
  		if ($parametreTri eq "Type") {
			my $valid;
			for (keys(%types))
			{ 
				my $critereType = $_;
				my $critereAffiche = $types{$_}{Name};
				my $color = $types{$_}{RGB};
				my $critereLevel = $types{$_}{Level};
				$i = 0;
				# on filtre les lignes contenant le type recherché (fait gagner beaucoup de temps!!)
				@lignesValides = grep(/\|$critereType\|/,@lignes);
				for (@lignesValides) {
					my ($id,$dateDepart,$heureDepart,$dateFin,$heureFin,$type,$nom,$autres,$lieu,$objet) = split(/\|/,$_);
					$valid = 0;
	  
					if ("$option[0]" eq "day") {
						if (($dateDepart le $critereDate) && ($dateFin ge $critereDate)) { $valid = 1; }
					}
					elsif ("$option[0]" eq "month") {
						if ((substr($dateDepart,0,7) le $critereDate) && (substr($dateFin,0,7) ge $critereDate)) { $valid = 1; }
					}
					elsif ("$option[0]" eq "year") {
						if ((substr($dateDepart,0,4) le $critereDate) && (substr($dateFin,0,4) ge $critereDate)) { $valid = 1; }
					}
					elsif ("$option[0]" eq "interval") {
						if (($dateDepart le $critereFin) && ($dateFin ge $critereDebut)) { $valid = 1; }
					}
					elsif ("$option[0]" eq "future") {
						if (($dateDepart gt $critereDate) || ($dateFin gt $critereDate)) { $valid = 1; }
					}
					elsif ("$option[0]" eq "all") {
						# 
						$valid = 1;
					}
	  
					# on traite complètement la ligne si elle doit être affichée...
					if ($valid eq 1) {
						my $modif = "";
						if ($type ~~ ['NODES','Reseaux']) {
							# lecture du fichier d'événément
							if ($heureDepart eq "") { $dateEvenement = $dateDepart."_NA"; }
							else { $dateEvenement = $dateDepart."_".substr($heureDepart,0,2)."-".substr($heureDepart,3,2); }
							$fileEvenement = $objet;
							if (-e $fileEvenement) {
								@evenement = readFile($fileEvenement);
								($nom,$objet) = split(/\|/,"$evenement[0]");
								#$objet = $objet." - ".join("<br>",@evenement[1..$#evenement]);
							}
							%confSta = readNode("$lieu");
							($nomSta = $confSta{"$lieu"}{NAME}) =~ s/\"//g;
							my $normlieu = WebObs::Grids::normNode(node=>"..$lieu");
							if ( $normlieu ne "" && (WebObs::Users::clientHasEdit(type=>'authviews',name=>"$lieu") ||  WebObs::Users::clientHasEdit(type=>'authprocs',name=>"$lieu")) ) {
								$modif = "<A href=\"/cgi-bin/formEVENTNODE.pl?node=$normlieu&file=".basename($fileEvenement)."\"><img src=\"/icons/modif.gif\" title=\"Editer...\" border=0></A>";
							} 
							if ( $normlieu ne "" && (WebObs::Users::clientHasRead(type=>'authviews',name=>"$lieu") ||  WebObs::Users::clientHasRead(type=>'authprocs',name=>"$lieu")) ) {
								$lieu = "<A href=\"$NODES{CGI_SHOW}?node=$normlieu\">".$confSta{$lieu}{ALIAS}.": ".$nomSta."</A>";
							} else {
								$lieu = "$confSta{$lieu}{ALIAS}: $nomSta";
							}
						}
						my @noms = split(/\+/,$nom);
						my $listeNoms = join(',',WebObs::Users::userName(@noms));
						my $listeNomsOrg = $listeNoms;
	  
						if ("$autres" ne "") { $listeNoms="$listeNoms - $autres"; }  else { $listeNoms="$listeNoms"; }
	  
						my $afficheDate = "";
						if ("$dateDepart" eq "$dateFin") {
							if (("$heureDepart" eq "") && ("$heureFin" eq "")) { $afficheDate="$dateDepart"; } 
							elsif (("$heureDepart" ne "") && ("$heureFin" eq "")) { $afficheDate="$dateDepart ($heureDepart)"; } 
							elsif (("$heureDepart" eq "") && ("$heureFin" ne "")) { $afficheDate="$dateDepart (Fin prévue à: $heureFin)"; } 
							else { $afficheDate="$dateDepart ($heureDepart-$heureFin)"; } 
						} else {
							if (("$heureDepart" eq "") && ("$heureFin" eq "")) { $afficheDate="$dateDepart - $dateFin"; } 
							elsif (("$heureDepart" ne "") && ("$heureFin" eq "")) { $afficheDate="$dateDepart ($heureDepart) - $dateFin"; } 
							elsif (("$heureDepart" eq "") && ("$heureFin" ne "")) { $afficheDate="$dateDepart - $dateFin ($heureFin)"; } 
							else { $afficheDate="$dateDepart ($heureDepart) - $dateFin ($heureFin)"; } 
						}
	  
		  				if ( !($type ~~ ['NODES','Reseaux']) && ($AllowEdit && (WebObs::Users::clientHasEdit(type=>'authmisc',name=>"HEBDO_$type"))) ) {
	  						$modif="<a href=\"$HEBDO{CGI_FORM}?id=$id\"><img src=\"/icons/modif.gif\" title=\"Editer...\" border=0></a>";
	  					}
						my $txt = "<LI style=\"color:$types{$type}{RGB}\"><SPAN style=\"color:black\">";
						if ($types{$type}{Format} eq "ndol") {
							$txt .= "<B>$listeNoms</B> - [$afficheDate] - $objet - <I>$lieu</I>";
						} 
						elsif ($types{$type}{Format} eq "ndlo") {
							$txt .= "<B>$listeNoms</B> - [$afficheDate] - <I>$lieu</I> - $objet";
						}
						elsif ($types{$type}{Format} eq "ldon") {
							$txt .= "<B>$lieu</B> - [$afficheDate] - $objet - <I>$listeNoms</I>";
						}
						elsif ($types{$type}{Format} eq "dlon") {
							# if ("$parametreDate" eq "Today") { $afficheDate="Aujourd\'hui"; }
							$txt .= "<B>$afficheDate - $lieu</B> - $objet - <I>$listeNoms</I>";
						}
						elsif ($types{$type}{Format} eq "andol") {
							$txt .= "<B>$autres".($listeNomsOrg ne "" ? ($autres ne "" ? ", ":"")."$listeNomsOrg":"")."</B> - [$afficheDate] - $objet - <I>$lieu</I>";
							#$txt .= "<B>$autres".($listeNomsOrg ne "" && $autres ne "" ? ", ":"").($listeNomsOrg ne "" ? "$listeNomsOrg":"")."</B> - [$afficheDate] - $objet - <I>$lieu</I>";
						}
						elsif ($types{$type}{Format} eq "adon") {
							$txt .= "<B>$autres</B> - [$afficheDate] - $objet - [$listeNomsOrg]";
						} else {
							$txt .= "<B>$lieu</B> - [$afficheDate] - $objet - <I>$listeNoms</I>";
						} 
						$txt .= " $modif</SPAN></LI>\n"; 
						$texte .= $txt;
					}
					$i++;
				}
				if ("$texte" ne "") { 
					push(@contenu,"<H3><A name=\"$critereType\"></A>$critereAffiche</H3>\n<UL>$texte</UL>\n");
					$texte = "";
				}
			}

  		} elsif ("$parametreTri" eq "Date") {
  		# - - - - - - - - - - - - - - - - - - - - - - -
  		# Affichage avec tri par dates
  		# - - - - - - - - - - - - - - - - - - - - - - -
  		
  		for (@dateListe) { 
  			$jourCal = $_;
  			$i = 0;
  			# on filtre les lignes contenant la date recherchée (fait gagner beaucoup de temps, mais exclut les périodes à cheval sur l'interval)
  			# --> toutes les lignes retenues (@lignesValides) sont à afficher.
  			@lignesValides = grep(/\|$jourCal/,@lignes);
  			for (@lignesValides) {
  				my ($id,$dateDepart,$heureDepart,$dateFin,$heureFin,$type,$nom,$autres,$lieu,$objet) = split(/\|/,$_);
  				if (($_ ne "") && (($parametreType ~~ ['ALL','Tout','ALLnNODES','ToutReseaux']) || ($parametreType eq $type))) { 
  					my $modif="";
  					if ($type ~~ ['NODES','Reseaux']) {
  						# lecture du fichier d'événément
  						if ($heureDepart eq "") { $dateEvenement = $dateDepart."_NA"; }
  						else { $dateEvenement = $dateDepart."_".substr($heureDepart,0,2)."-".substr($heureDepart,3,2); }
  						$fileEvenement = $objet;
  						if (-e $fileEvenement) {
  							@evenement = readFile($fileEvenement);
  							($nom,$objet) = split(/\|/,"$evenement[0]");
  							#$objet = $objet." - ".join("<br>",@evenement[1..$#evenement]);
  						}
						%confSta = readNode("$lieu");
						($nomSta = $confSta{"$lieu"}{NAME}) =~ s/\"//g;
						my $normlieu = WebObs::Grids::normNode(node=>"..$lieu");
						if ( $normlieu ne "" && (WebObs::Users::clientHasEdit(type=>'authviews',name=>"$lieu") ||  WebObs::Users::clientHasEdit(type=>'authprocs',name=>"$lieu")) ) {
							$modif = "<A href=\"/cgi-bin/formEVENTNODE.pl?node=$normlieu&file=".basename($fileEvenement)."\"><img src=\"/icons/modif.gif\" title=\"Editer...\" border=0></A>";
						} 
						if ( $normlieu ne "" && (WebObs::Users::clientHasRead(type=>'authviews',name=>"$lieu") ||  WebObs::Users::clientHasRead(type=>'authprocs',name=>"$lieu")) ) {
							$lieu = "<A href=\"$NODES{CGI_SHOW}?node=$normlieu\">".$confSta{$lieu}{ALIAS}.": ".$nomSta."</A>";
						} else {
							$lieu = "$confSta{$lieu}{ALIAS}: $nomSta";
						}
  					}
  
  					my @noms = split(/\+/,$nom);
					my $listeNoms = join(',',WebObs::Users::userName(@noms));
					my $listeNomsOrg = $listeNoms;
  
  					if ($autres ne "") { $listeNoms="$listeNoms - $autres"; }  else { $listeNoms="$listeNoms"; }
  					my $afficheDate = "";
  					my $li = "<LI>";
  					
  					if ($dateDepart eq $dateFin) {
  						if (($heureDepart eq "") && ($heureFin eq "")) { $afficheDate = ""; } 
  						elsif (($heureDepart ne "") && ($heureFin eq "")) { $afficheDate = "$heureDepart"; } 
  						elsif (($heureDepart eq "") && ($heureFin ne "")) { $afficheDate = "Fin prévue à $heureFin"; } 
  						else { $afficheDate = "$heureDepart-$heureFin"; } 
  					} else {
  						if ($dateDepart ne $jourCal) {
  							$afficheDate="<i>since $dateDepart</i>";
  							$li = "<LI style=\"list-style-image:url(/icons/end.gif)\">";
  						} else {
  							$afficheDate="<i>until $dateFin</i>";
  							$li = "<LI style=\"list-style-image:url(/icons/start.gif)\">";
  						} 
  					}
  
		  			if ( !($type ~~ ['NODES','Reseaux']) && $AllowEdit && WebObs::Users::clientHasEdit(type=>'authmisc',name=>"HEBDO_$type") ) {
	  					$modif="<a href=\"$HEBDO{CGI_FORM}?id=$id\"><img src=\"/icons/modif.gif\" title=\"Edit...\" border=0></a>";
	  				}
  					my $txt="$li<B>$afficheDate</B> <SPAN class=typeHebdo style=\"color:$types{$type}{RGB};\">$types{$type}{Name}</SPAN> <I>$lieu</I> - $objet - $autres [$listeNomsOrg] $modif</LI>\n";
  
  #					if ((($dateDepart ge $jourCal) && ($dateDepart le $jourCal)) || (($dateFin ge $jourCal) && ($dateFin le $jourCal)) || (($dateDepart le $jourCal) && ($dateFin ge $jourCal)))
  					$texte = $texte.$txt;
  				}
  				$i++;
  			}
  			if ("$texte" ne "") {
  				# barre de séparation desmois...
  				if (substr($jourCal,0,7) gt $j0) {
  					$moisCalAffiche = l2u(qx(date -d $jourCal +"\%B \%Y")); chomp($moisCalAffiche);
  					push(@contenu,"<P class=\"monthHebdo\">$moisCalAffiche</P>");
  				}
  				$j0 = $jourCal;
  				$jourCalAffiche = l2u(qx(date -d $jourCal +"\%A \%-d \%B \%Y")); chomp($jourCalAffiche);
  				my $ff = "";
  				my @jf = grep(/$j0/,@feries);
  				if (length($jf[0]) > 0) {
  					my ($dd,$ss) = split(/\|/,$jf[0]);
  					chomp($ss);
  					$ff = "<I>($__{Holiday}: $ss)</I>";
  				}
  				push(@contenu,"<H3>$jourCalAffiche $ff</H3>\n<UL style=\"list-style-image:url(/icons/stop.gif)\">$texte</UL>\n");
  				$texte="";
  			}
  		}
  		
  		} else {
  			# - - - - - - - - - - - - - - - - - - - - - - -
  			# Affichage type calendrier
  			# - - - - - - - - - - - - - - - - - - - - - - -
  			push(@contenu,"<TABLE width=\"100%\" style=\"border:0; border-collapse:collapse; padding-bottom: 50px\"><TR>");
  			my $w = "";
  			if ($option[0] eq "day") { $w = "width=\"100%\""; }
  			#elsif (($option[0] eq "interval") || ($option[0] eq "month")) { $w = "width=\"14%%\""; }
  			else { $w = "width=\"14%%\""; }
  			my @tid =();
  			$ii = 0;
  
  			for (@dateListe) { 
  				$jourCal = $_;
  				$moisCalAffiche = l2u(qx(date -d $jourCal +"\%b \%Y")); chomp($moisCalAffiche);
  				my $jourPrecedent = qx(date -I -d "$jourCal 1 day ago");
  				my $jourSuivant = qx(date -I -d "$jourCal 1 day");
  				my $semainePrecedente = qx(date -d "$jourCal 1 day ago" +"\%GW\%V"); chomp($semainePrecedente);
  				my $semaineSuivante = qx(date -d "$jourCal 7 days" +"\%GW\%V"); chomp($semaineSuivante);
  				$i = 0;
  				$texte = "";
  
  				if ($ii%7 == 0) {
  					push(@contenu,"<TR><TD style=\"border:0;text-align:left\"><B>");
  					if ($option[0] eq "day") {
  						push(@contenu,"<A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$jourPrecedent\">&lArr;</A>
  							</B></TD><TD style=\"border:0;text-align:right\"><B>
  							<A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$jourSuivant\">&rArr;</A>
  							</B></TD></TR>\n");
  					} else {
  						push(@contenu,"<A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$semainePrecedente\">&lArr;
  						<I>$__{'week'} ".substr($semainePrecedente,5,2)."</I></A></B></TD>
  						<TD style=\"border:0\" colspan=5></TD><TD style=\"border:0;text-align:right\"><B>
  						<A href=\"$HEBDO{CGI_SHOW}?tri=$parametreTri&date=$semaineSuivante\">
  						<I>$__{'week'} ".substr($semaineSuivante,5,2)." &rArr;</I></A></B></TD>
  						</B></TD></TR>\n");
  					}
  				}
  
  				my @lignesTmp = @lignes;
  				# on filtre le type si nécessaire
  				@lignesValides =  ();
  				# on filtre les lignes conconcernées par la date recherchée
  				for (@lignesTmp) {
  					my ($id,$dateDepart,$heureDepart,$dateFin,$heureFin,$type,$nom,$autres,$lieu,$objet) = split(/\|/,$_);
  					if (($dateDepart le $jourCal) && ($dateFin ge $jourCal)	&& ($_ ne "")
  					&& (($parametreType ~~ ['ALL','Tout','ALLnNODES','ToutReseaux']) || ($parametreType eq $type))) { push(@lignesValides,$_); }
  				}
  				
  				# tri des événements par date début + heure
  				@lignesValides = reverse sort tri_date_avec_id @lignesValides;
  				
  				# le tableau @lignesValides contient tous les événements à afficher au jour $jourCal
  				for (@lignesValides) {
  					my $modif="";
  					$_ =~ s/\'/&rsquo;/g;
  					$_ =~ s/\"/&quot;/g;
  					my ($id,$dateDepart,$heureDepart,$dateFin,$heureFin,$type,$nom,$autres,$lieu,$objet) = split(/\|/,$_);
  					chomp($objet);
  					if ($type ~~ ['NODES','Reseaux']) {
  						# lecture du fichier d'événément
  						if ($heureDepart eq "") { $dateEvenement = $dateDepart."_NA"; }
  						else { $dateEvenement = $dateDepart."_".substr($heureDepart,0,2)."-".substr($heureDepart,3,2); }
  						$fileEvenement = $objet;
  						if (-e $fileEvenement) {
  							@evenement = readFile($fileEvenement);
  							($nom,$objet) = split(/\|/,"$evenement[0]");
  							chomp($objet);
  							#$objet = $objet." - ".join("<br>",@evenement[1..$#evenement]);
  						}
						%confSta = readNode("$lieu");
						($nomSta = $confSta{"$lieu"}{NAME}) =~ s/\"//g;

  						$objet =~ s/\'/&rsquo;/g; $objet =~ s/\"/&quot;/g;
  						$objet = "$confSta{$lieu}{ALIAS}: $objet";
  					}
  
  					my @noms = split(/\+/,$nom);
  					my $qui = "";
					my $listeNoms = join(',',WebObs::Users::userName(@noms));
					my $listeNomsOrg = $listeNoms;
  					if ($autres ne "") { $listeNoms="$listeNoms - $autres"; }  else { $listeNoms="$listeNoms"; }
  					if ("$option[0]" eq "day") {
  						$qui =  "$autres [$listeNomsOrg]";
  					} elsif ($nom ne "?") {
  						$qui = "$autres $nom";
  					}
  
  					my $afficheHeure = "";
  					my $afficheDate = "";
  					my $afficheObjet = $objet;
  					
  					if ($dateDepart eq $dateFin) {
  						if (($heureDepart eq "") && ($heureFin eq "")) {
  							$afficheDate = "";
  						}
  						elsif (($heureDepart ne "") && ($heureFin eq "")) {
  							$afficheDate = "$heureDepart";
  							$afficheHeure = "<B>$afficheDate</B>";
  						} 
  						elsif (($heureDepart eq "") && ($heureFin ne "")) {
  							$afficheDate = "fin prévue à $heureFin";
  						} 
  						else {
  							$afficheDate = "$heureDepart &rArr; $heureFin";
  							$afficheHeure = "<B>$afficheDate</B>";
  						} 
  					} else {
  						$afficheDate = "$dateDepart &rArr; $dateFin";
  					}
  						
		  			if ( $AllowEdit ) { 
						if ($type ~~ ['NODES','Reseaux']) {
							my $normlieu = WebObs::Grids::normNode(node=>"..$lieu");
							if ( $normlieu ne "" && (WebObs::Users::clientHasEdit(type=>'authviews',name=>"$lieu") ||  WebObs::Users::clientHasEdit(type=>'authprocs',name=>"$lieu")) ) {
								$modif = "onClick=document.location=\"/cgi-bin\/formEVENTNODE.pl?node=$normlieu&file=".basename($fileEvenement)."\"";
							}
							$lieu = "$confSta{$lieu}{ALIAS}: ".$nomSta;
						} elsif ( WebObs::Users::clientHasEdit(type=>'authmisc',name=>"HEBDO_$type") ) {
	  						$modif="onClick=document.location=\"$HEBDO{CGI_FORM}?id=$id\" ";
						} 
	  				}
  					my $txt;
  					my $popup = "onMouseOut=\"nd()\" onMouseOver=\"overlib('<b>$__{'Who'}:</b> $autres [$listeNomsOrg]<br><b>$__{'Subject'}:</b> $objet";
  					if ($afficheDate ne "") {
  						$popup = $popup."<br><b$__{'>Date'}:</b> $afficheDate";
  					}
  					$popup = $popup."<br><b>$__{'Place'}:</b> $lieu',CAPTION,'$types{$type}{Name}')\"";
  
  					#if ((("$option[0]" eq "interval") || ("$option[0]" eq "month") || ("$option[0]" eq "future")) && (($heureDepart eq "") || ($dateDepart ne $dateFin))) {
  					if (("$option[0]" ne "day") && (($heureDepart eq "") || ($dateDepart ne $dateFin))) {
  						$afficheObjet = substr($objet,0,20);
  						if (length($objet) > 20) { $afficheObjet = $afficheObjet."..."; }
  					}
  					# nouvel événement journalier inexistant dans la liste semaine: on ajoute au tableau @tid
  					if (length(grep(/^$id/,@tid) == 0) && (($heureDepart eq "") || ($dateDepart ne $dateFin))) {
  						push(@tid,$id);
  					}
  					while (($tid[$i] != $id) && ($dateDepart eq $jourCal) && ($i <= $#tid)) {
  						my @ntid;
  						for (my $n = 0; $n <= $#tid; $n++) {
  							if ($n != $i) { push(@ntid,$tid[$n]); }
  						}
  						@tid = @ntid;
  						$i++;
  					}
  					while (($tid[$i] != $id) && ($i <= $#tid) && ($dateDepart ne $jourCal)) {
  						if ("$option[0]" eq "inconnu") {
  							$txt = $txt."<TD style=\"border-color:white\">&nbsp;</TD>";
  						} else {
  							$txt = $txt."<TR><TD style=\"border-color:white\">&nbsp;</TD></TR>\n";
  						}
  						$i++;
  					}
  					if ("$option[0]" eq "inconnu") {
  						$txt = $txt."<TD style=\"background-color:$types{$type}{RGBlight}\" $popup $modif>&nbsp;</TD>";
  					} else {
  						$txt = $txt."<TR><TD style=\"background-color:$types{$type}{RGBlight}\" $popup $modif>$afficheHeure $afficheObjet $qui</TD></TR>\n";
  					}
  
  					$texte = $texte.$txt;
  					$i++;
  				}
  				if ("$option[0]" eq "day") {
  					$jourCalAffiche = ucfirst(l2u(qx(date -d $jourCal +"\%A \%-d \%B \%Y")));
  				} elsif ("$option[0]" eq "inconnu") {
  					$jourCalAffiche = ucfirst(l2u(qx(date -d $jourCal +"\%a \%-d")));
  				} else {
  					$jourCalAffiche = ucfirst(l2u(qx(date -d $jourCal +"\%a \%-d \%b")));
  				}
  				chomp($jourCalAffiche);
  				
  				my $ff = "";
  				my @jf = grep(/$jourCal/,@feries);
  				if (length($jf[0]) > 0) {
  					my ($dd,$ss) = split(/\|/,$jf[0]);
  					chomp($ss);
  					$ff = "style=\"color:red\" onMouseOut=\"nd()\" onMouseOver=\"overlib('F&Eacute;RI&Eacute;: $ss')\"";
  				}
  				if ($jourCal eq $todayDate) { $ff = $ff." style=\"background-color: #FFAAAA\""; }
  				#if (("$option[0]" eq "day") || ("$option[0]" eq "interval") || ("$option[0]" eq "month")) 
  				if ("$option[0]" ne "inconnu") {
  					push(@contenu,"<TD $w style=\"border:0;vertical-align:top\"><TABLE class=\"HebdoCal\" width=\"100%\"><TR><TH  $ff>$jourCalAffiche</TH></TR>\n$texte\n</TABLE></TD>\n");
  				} else {
  					if (substr($jourCal,8,2) eq "01") {
  						if ($i != 0) {
  							push(@contenu,"</TABLE></TD>\n");
  							$i = 0;
  							@tid = ();
  						}
  						if (substr($jourCal,5,2) eq "07") {
  							push(@contenu,"</TR><TR>\n");
  						}
  						push(@contenu,"<TD width=\"17%\" style=\"border:0;vertical-align:top\"><TABLE class=\"HebdoCal\" width=\"100%\"><TR><TH colspan=2>$moisCalAffiche</TH></TR>\n");
  					}
  					push(@contenu,"<TR><TH style=\"border:0\" $ff>$jourCalAffiche</TH><TD style=\"border:0\"><TABLE class=\"HebdoCal\" style=\"text-align:left\" width=\"100%\">$texte\n</TR></TABLE></TD></TR>\n");
  				}
  				$ii++;
  				#if ((("$option[0]" eq "day") || ("$option[0]" eq "interval") || ("$option[0]" eq "month") || ("$option[0]" eq "future")) && ($ii%7 == 0)) 
  				if ($ii%7 == 0) {
  					push(@contenu,"</TR><TR>\n");
  					$i = 0;
  					@tid = ();
  				}
  			}
  			push(@contenu,"</TR></TABLE>\n");
			push(@contenu,"<div style=\"margin-top:80px;\">&nbsp;</div>'\n");
  		}
  
  
  	} else {
  		push(@contenu,"<br>",'FILE NOT FOUND:  ',$fileHebdo,"<br>");  
  	}
  
  	return @contenu;
}

1;

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

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

