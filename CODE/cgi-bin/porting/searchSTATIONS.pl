#!/usr/bin/perl -w
#---------------------------------------------------------------
# ------------------- WEBOBS -----------------------------------
# Script: searchSTATIONS.pl
# Purpose: search for word or expression into the files/stations
#	database, with options (in particular the date interval).
#
# Authors: Didier Mallarino, François Beauducel
# Created: 2004
# Modified: 2010-06-04
#
# --------------------------------------------------------------

# Utilisation des modules externes
# - - - - - - - - - - - - - - - - - - - - - - -
use strict;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use Image::Info qw(image_info dim);

use Webobs;
use readConf;
use readGraph;

# ---------- Lecture des fichiers de configuration
my %WEBOBS = readConfFile;
my %graphStr = readGraphFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{FILE_MATLAB_CONFIGURATION}");
my @graphKeys = keys(%graphStr);
my @signature = readFile("$WEBOBS{RACINE_DATA_WEB}/$WEBOBS{FILE_SIGNATURE}");
my @notes = readFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{STATIONS_FILE_FILTRE_NOTES}");
chomp(@notes);
my @fieldCLB = readCfgFile("$WEBOBS{RACINE_FICHIERS_CONFIGURATION}/$WEBOBS{CLB_FIELDS_FILE}");
my $editOK = 0;
my @users = testOper;
if (@users ne ("")) {
	if ($users[2] > 2) {
		$editOK = 1;
	}
} else {
	$editOK = 1;
}

# ---------------------------------------------------------------
# ------------ MAIN ---------------------------------------------
# ---------------------------------------------------------------

my $titrePage = $__{'Search for WEBOBS events/information'};

print $cgi->header(-charset=>"utf-8"),
	$cgi->start_html($titrePage);

print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_CSS}\">
<style type=\"text/css\">
<!--
	li { margin-bottom:3pt; margin-top:6pt; }
        #attente
        {
		color: gray;
		background: white;
		margin: 0.5em;
		padding: 0.5em;
		font-size: 1.5em;
		border: 1px solid gray;
	}
-->
</style>
		    
</HEAD>
<!-- ********** DEBUT DU BODY ************ -->
<BODY style=\"background-attachment: fixed\">
<div id=\"attente\">$__{'Searching for data, please wait'}...</div>

<!--DEBUT DU CODE ROLLOVER 2-->
<DIV id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></DIV>
<SCRIPT language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></SCRIPT>
<!-- overLIB (c) Erik Bosrup -->
<!--FIN DU CODE ROLLOVER 2-->";

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


# ---- Generation de la liste des stations 
my @stations = qx(/bin/ls $WEBOBS{RACINE_DATA_STATIONS});
chomp(@stations);

# Recuperation des parametres de la ligne de commande
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
my @parametres = $cgi->param();
my $valParams = join(" ",@parametres);
my $searchW;
my $reseau = "ALL";
my $entireW;
my $majmin;
my $extend;
my $netinfo;
my $stainfo;
my $clbinfo;
my $evtinfo;
my $year1;
my $month1;
my $day1;
my $anneeActuelle = qx(date +\%Y);  chomp($anneeActuelle);
my $year2;
my $month2;
my $day2;
my @listeAnnees = reverse($WEBOBS{BIG_BANG}..$anneeActuelle);

if ($valParams =~ /reseau/) {
	$reseau = $cgi->param('reseau');
}
if ($valParams =~ /searchW/) {
	$searchW = $cgi->param('searchW');
	$entireW = $cgi->param('entireW');
	$majmin = $cgi->param('majmin');
	$extend = $cgi->param('extend');
	$netinfo = $cgi->param('netinfo');
	$stainfo = $cgi->param('stainfo');
	$evtinfo = $cgi->param('evtinfo');
	$clbinfo = $cgi->param('clbinfo');
	$year1 = $cgi->param('year1');
	$month1 = $cgi->param('month1');
	$day1 = $cgi->param('day1');
	$year2 = $cgi->param('year2');
	$month2 = $cgi->param('month2');
	$day2 = $cgi->param('day2');
} else {
	$netinfo = "OK";
	$stainfo = "OK";
	$evtinfo = "OK";
	$clbinfo = "OK";
}


# Si l'option entireW n'est pas sélectionnée, remplacement des espaces par | (fonction OU) par similarité avec Google
#if ($entireW eq "") {
#	$searchW =~ s/\ /\|/g;
#}

# Affichage du formulaire de recherche
# - - - - - - - - - - - - - - - - - - - - - - - - -
print "<FORM name=\"formulaire\" action=\"/cgi-bin/searchSTATIONS.pl\" method=\"post\">\n
	<TABLE width=\"100%\"><TR><TD style=\"border:0;text-align:center\" class=\"boitegrise\">";
print "<B>$__{'Network'}:</B> <select onMouseOut=\"nd()\" onmouseover=\"overlib('".$__{'Select a network'}."')\"
	name=\"reseau\" size=\"1\">\n";
my @subStationList;
my @subReseauList;
my %codesReseaux;
my @listFiles;
my @reseaux;
for (grep(/routine_/,@graphKeys)) {
	my $code = substr($_,length($_)-3,3);
	push(@reseaux,$code);
        my $cle2 = $graphStr{"nom_".$graphStr{$_}};
        $codesReseaux{$cle2} = $code;
}
print "<option value=\"ALL\" ".(($reseau eq "ALL")?" selected":"").">-- $__{'All the networks'} --</option>\n";
my @tri_clefs = sort keys %codesReseaux;
foreach (@tri_clefs) {
	my $cle = $codesReseaux{$_};
	my @net = grep(/^$cle/,@stations);	# seuls les réseaux avec au moins 1 fiche sont proposés dans la liste
	if ($#net >= 0) {
        	print "<option value=\"$cle\" ".(($reseau eq $cle)?" selected":"").">$_ ($cle)</option>\n";
	}
}
print "</select><BR>";
print "<INPUT type=\"checkbox\" name=\"netinfo\"".($netinfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include network description'}."')\"><B>$__{'Network info'}</B>\n
	<INPUT type=\"checkbox\" name=\"stainfo\"".($stainfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include file/station description'}."')\"><B>$__{'Sheet info'}</B>\n
	<INPUT type=\"checkbox\" name=\"clbinfo\"".($clbinfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include calibration file'}."')\"><B>CLB</B>\n
	<INPUT type=\"checkbox\" name=\"evtinfo\"".($evtinfo eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\"onmouseover=\"overlib('".$__{'Include file/station dated events'}."')\"><B>$__{'Sheet events'}</B>\n
	<BR>";
my $msg = l2u(join("",@notes));

print "<B>$__{'Starting date'}:</B> <SELECT name=\"year1\" size=\"1\">";
for ("",@listeAnnees) {
	print "<OPTION".(($year1 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
}
print "</SELECT>\n<SELECT name=\"month1\" size=\"1\">";
for ("","01".."12") {
	print "<OPTION".(($month1 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
}
print "</SELECT>\n<SELECT name=\"day1\" size=\"1\">";
for ("","01".."31") {
	print "<OPTION".(($day1 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
}
print "</SELECT>\n<B>$__{'Ending date'}:</B> <SELECT name=\"year2\" size=\"1\">";
for ("",@listeAnnees) {
        print "<OPTION".(($year2 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
}
print "</SELECT>\n<SELECT name=\"month2\" size=\"1\">";
for ("","01".."12") {
        print "<OPTION".(($month2 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
}
print "</SELECT>\n<SELECT name=\"day2\" size=\"1\">";
for ("","01".."31") {
        print "<OPTION".(($day2 eq $_)?" selected":"")." value=\"$_\">$_</OPTION>";
}
print "</SELECT></TD>\n";
print "<TD style=\"border:0\" class=\"boitegrise\"><B>$__{'Word/Expression'}:</B> <input size=\"30\" name=\"searchW\" value=\"$searchW\"><BR>\n";
print "<input type=\"checkbox\" name=\"entireW\"".($entireW eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\" onmouseover=\"overlib('".$__{'Select to match entire word'}."')\"><B>$__{'Entire word'}</B>\n
	<input type=\"checkbox\" name=\"majmin\"".($majmin eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\" onmouseover=\"overlib('".$__{'Select to match word case'}."')\"<B>$__{'Upper/lower case'}</B>\n
	<input type=\"checkbox\" name=\"extend\"".($extend eq "OK" ? " checked":"")." value=\"OK\" onMouseOut=\"nd()\" onmouseover=\"overlib('i".$__{'Select to display the entire text (not only fitting lines)'}."')\"><B>$__{'Display Entire text'}</B><BR>\n";
print "</TD>";
print "<TD style=\"border:0;text-align:center\" class=\"boitegrise\"><input type=\"submit\" value=\"$__{'Search'}\"></TD>\n";
print "<TD style=\"border:0;text-align:right\" width=\"1%\" class=\"boitegrise\" onMouseOut=\"nd()\" onmouseover=\"overlib('$msg', CAPTION, 'INFORMATIONS', STICKY, WIDTH, 400)\">?</TD></TR></TABLE></P></FORM>\n";

if ($searchW ne "") {
	my $resultOK = 0;
	my $grepOptions = "-s -E";
	if ($entireW eq "OK") { $grepOptions = "-w ".$grepOptions; }
	if ($majmin ne "OK") { $grepOptions = "-i ".$grepOptions; }
	print "<!-- ParamÃ¨tres ($searchW-$reseau) - Mode RÃ©sultat -->\n";
	if ($reseau ne "ALL" && $reseau ne "") {
		@subStationList = grep(/^$reseau/,@stations);
		@subReseauList = ($reseau);
	} else {
		@subStationList = @stations;
		@subReseauList = @reseaux;
	}

	# --- recherche dans les pages réseaux
	for (@subReseauList) {
		my $reseauCode = $_;
		my $discipline = substr($reseauCode,1,1);
		my $reseauRoutine = lc($graphStr{"routine_$reseauCode"});
		my $pathReseau = $WEBOBS{RACINE_DATA_WEB}."/".$reseauRoutine."_";
		my @searchInfo;
		my $texte = "";
		@listFiles = qx(/bin/ls $pathReseau*.$WEBOBS{EXTENSION_DATA_WEB} 2>/dev/null);
		if ($#listFiles >= 0 && $netinfo eq "OK") {
			@searchInfo = qx(/bin/grep -l $grepOptions "$searchW" $pathReseau*.$WEBOBS{EXTENSION_DATA_WEB});
			chomp(@searchInfo);
			for (@searchInfo) {
				my $fileInfos = $_;
				my ($file,$ext) = split(/\./,basename($_));
				my @info = grep(!/^$/, readFile($fileInfos));	# lit le fichier et vire les lignes vides
				chomp(@info);
				my $modif = "";
    				if ($editOK == 1) {
					$modif = "<a href=\"/cgi-bin/editTXT.pl?src=$reseauCode&amp;file=$fileInfos\"><img src=\"/icons-webobs/modif.gif\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
				}
				$texte .= "<LI><P class=\"titleEvent\"><b>".uc($file)."</b> ($__{'Network info'}) $modif</P>\n";
				if ($extend eq "") {
					@info = (qx(/bin/grep $grepOptions "$searchW" $fileInfos));
					for (@info) {
						$texte .= "<BLOCKQUOTE class=\"contentPartialEvent\">".txt2htm($_)."</BLOCKQUOTE>\n";
					}
				} else {
					$texte .= "<BLOCKQUOTE class=\"contentEvent\">".txt2htm(join("\n",@info))."</BLOCKQUOTE>\n";
				}
				$texte .= "</LI>\n";
				$resultOK = 1;
			}
		}
		if ($texte ne "") {
			$texte = $graphStr{"codedis_$discipline"}." / ".$graphStr{"nom_".$graphStr{"routine_$reseauCode"}}."</A></H3><UL>$texte\n</UL>";
			$texte =~ s/($searchW)/<span class="searchResult">$1<\/span>/gi;
			print "<HR><H3><A HREF=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_RESEAUX}?reseau=$reseauCode\">".$texte;
		}
	}
   
	# --- recherche dans les fiches
	for (@subStationList) {
		chomp($_);
		my $stationName = ($_);
		my %STATION = readConfStation($stationName);
		my $pathStation = "$WEBOBS{RACINE_DATA_STATIONS}/$stationName";
		my @searchInfo;
		my $fileCLB = "$pathStation/$stationName.clb";
		my @searchCLB;
		my @searchEvent;
		my $texte = "";

		# --- recherche dans les fichiers d'infos
		@listFiles = qx(/bin/ls $pathStation/*.txt 2>/dev/null);
		if ($#listFiles >= 0 && $STATION{VALIDE} > 0 && $stainfo eq "OK"
			&& ($STATION{INSTALL_DATE} eq "NA" || $STATION{INSTALL_DATE} le "$year2-$month2-$day2" || $year2 eq "")
			&& ($STATION{END_DATE} eq "NA" || $STATION{END_DATE} ge "$year1-$month1-$day1" || $year1 eq "")) {
			@searchInfo = qx(/bin/grep -l $grepOptions "$searchW" $pathStation/*.txt);
			chomp(@searchInfo);
			for (@searchInfo) {
				my $fileInfos = $_;
				my ($file,$ext) = split(/\./,basename($_));
				my @info = grep(!/^$/, readFile($fileInfos));	# lit le fichier et vire les lignes vides
				chomp(@info);
				my $modif = "";
    				if ($editOK == 1) {
					$modif = "<a href=\"/cgi-bin/editTXT.pl?src=$stationName&amp;file=$fileInfos\"><img src=\"/icons-webobs/modif.gif\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
				}
				$texte .= "<LI><P class=\"titleEvent\"><b>".uc($file)."</b> ($__{'Sheet info'}) $modif</P>\n";
				if ($extend eq "") {
					@info = (qx(/bin/grep $grepOptions "$searchW" $fileInfos));
					for (@info) {
						$texte .= "<BLOCKQUOTE class=\"contentPartialEvent\">".txt2htm($_)."</BLOCKQUOTE>\n";
					}
				} else {
					$texte .= "<BLOCKQUOTE class=\"contentEvent\">".txt2htm(join("\n",@info))."</BLOCKQUOTE>\n";
				}
				$texte .= "</LI>\n";
				$resultOK = 1;
			}
      		}
		
		# --- recherche dans le fichier CLB
		if (-e $fileCLB) {
			@searchCLB = qx(/bin/grep -l $grepOptions "$searchW" $fileCLB);
			my $CLB = "";
			if ($#searchCLB >= 0 && $STATION{VALIDE} > 0 && $clbinfo eq "OK") {
				my @info = grep(!/^#/, readFile($fileCLB));
				chomp(@info);
				my $modif = "";
    				if ($editOK == 1) {
					$modif = "<a href=\"/cgi-bin/$WEBOBS{CGI_EDIT_CLB}?station=$stationName\"><img src=\"/icons-webobs/modif.gif\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
				}
				$CLB .= "<LI><P class=\"titleEvent\"><b>Calibration File</b> (".basename($fileCLB).") $modif</P>\n";
				if ($extend eq "") {
					@info = (qx(/bin/grep $grepOptions "$searchW" $fileCLB));
					chomp(@info);
					$CLB .= "<BLOCKQUOTE class=\"contentPartialEvent\">";
				} else {
					$CLB .= "<BLOCKQUOTE class=\"contentEvent\">";
				}
				$CLB .= "<TABLE><TR>";
				for (@fieldCLB) {
					my @clb = split(/\|/,$_);
					$CLB .= "<TH>$clb[2]</TH>";
				}
				$CLB .= "</TR>\n";
				for (@info) {
					my @clb = split(/\|/,$_);
					if ($clb[0] le "$year2-$month2-$day2" || $year2 eq "") {
						$CLB .= "<TR>";
						for (@clb) {
							$CLB .= "<TD>$_</TD>";
						}
						$CLB .= "</TR>\n";
						$resultOK = 1;
					}
				}
				$CLB .= "</TABLE></BLOCKQUOTE></LI>\n";
				if ($resultOK) {
					$texte .= $CLB;
				}
			}
		}
       
       # --- recherche dans les événements datés
       my $pathInterventions = "$pathStation/$WEBOBS{STATIONS_INTERVENTIONS_FILE_PATH}";
       #@listFiles = qx(/bin/ls $pathInterventions/*.txt 2>/dev/null);
       @listFiles = qx(/usr/bin/find $pathInterventions -name "$stationName*.txt" 2>/dev/null);

       if ($#listFiles >= 0 && $evtinfo eq "OK") {
          my @searchEvent;
	  for (@listFiles) {
	  	my $g = qx(/bin/grep -l $grepOptions "$searchW" $_);
		chomp($g);
		if ($g ne "") {
			push (@searchEvent,$g);
		}
	  }
          for (reverse @searchEvent) {
             my $file = substr($_,length($pathInterventions)+1);
	     chomp($file);
	     my @dd = split(/_/,basename($_));
	     my $date = "";
	     my $heure = "";
	     if ($dd[1] =~ "Projet") {
	     	$date = "Projet";
	     } else {
	        $date = $dd[1];
	     	if ($dd[2] !~ "NA") {
	     		$heure = substr($dd[2],0,2).":".substr($dd[2],3,2);
		}
	     } 
	     if (($year1 eq "" || $date ge "$year1-$month1-$day1") && ($year2 eq "" || $date le "$year2-$month2-$day2")) {
		my $fileInterventions = "$pathInterventions/$file";
		my @intervention = grep(!/^$/, readFile($fileInterventions));	# lit le fichier et vire les lignes vides
		chomp(@intervention);
		my @pLigne = split(/\|/,$intervention[0]);		# ligne de titre/operateurs
		my @listeNoms = split(/\+/,$pLigne[0]);
		my $noms = join(", ",nomOperateur(@listeNoms));
		my $titre = $pLigne[1];
		shift(@intervention);
		my $modif = "";
    		if ($editOK == 1) {
			$modif = "<a href=\"/cgi-bin/formulaireINTERVENTIONS_STATIONS.pl?file=$file\"><img src=\"/icons-webobs/modif.gif\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
		}
		$texte .= "<LI><P class=\"titleEvent\"><b>$titre</b> $date $heure <I>($noms)</I> $modif</P>\n"
			 ."<P class=\"subEvent\">".parentEvents($file)."</P>\n";
		if ($extend eq "") {
			# lit le fichier sans la première ligne (opérateurs|titre)
			@intervention = (qx(/bin/sed '1d' $fileInterventions | /bin/grep $grepOptions "$searchW"));
			for (@intervention) {
				$texte .= "<BLOCKQUOTE class=\"contentPartialEvent\">".txt2htm($_)."</BLOCKQUOTE>\n";
			}
		} else {
			$texte .= "<BLOCKQUOTE class=\"contentEvent\">".txt2htm(join("\n",@intervention))."</BLOCKQUOTE>\n";
		}
		$texte .= "</LI>\n";
		$resultOK = 1;
	     }
          }
       }
       if ($texte ne "") {
	$texte = genereNomFiche($stationName,1)."</A></H3><UL>$texte\n</UL>";
	$texte =~ s/($searchW)/<span class="searchResult">$1<\/span>/gi;
	print "<HR><H3><A HREF=\"/cgi-bin/$WEBOBS{CGI_AFFICHE_STATION}?id=$stationName\">".$texte;
       }
   }
   if ($resultOK == 0) {
   	print "<H3>Pas de r&eacute;sultat.</H3>\n";
   }
} else {
	print "<HR>\n";
}



# - - - - - - - - - - - - - - - - - - - - - - -
print "<style type=\"text/css\">
       #attente { display: none; }
       </style>\n
       @signature\n
	</body></div> </html>";



