#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# MC3.pm
# ------
# Perl module to update MC3 file
#
#
# Authors: François Beauducel <beauducel@ipgp.fr>, Jean-Marie Saurel <saurel@ipgp.fr>
# Created: 2022-07-05
# Updated:
#--------------------------------------------------------------
use strict;

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_write: write MC3 file
sub mc3_write {
  my ($mc_file,@lignes,$lockFile) = @_;

  @lignes = sort Sort_date_with_id(@lignes);

  # Temporary file for sanity check before replacing
  my $mc_file_temp="$mc_file.tmp";
  # Open temporary file for writing
  open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
  # Write the updated lines
  print FILE @lignes;
  close(FILE);
  # Sanity check : the columns number must always be 17 (empty lines are ignored)
  if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
    # Test passed, the file isn't corrupted
    # The update should have increased the file size
    if ( -s $mc_file_temp >= -s $mc_file ) {
      # The file size is increased
      # Replace the old file by the new one
      if ( system("mv $mc_file_temp $mc_file") == 0 ) {
        print "MC file: $mc_file updated\n";
      } else {
        Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
      }
    }
  } else {
    print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
  }
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_add: add MC3 entry
sub mc3_add {
  my ($mc3,$s3,$oper,$date,$type,$amp,$dur,$duree_sat,$nb_evts,$evt_SP,$station,$is_unique,$evt_id,$img,$comment) = @_;
  my ($evt_sdate, $evt_stime) = split('T', $date)

  # ---- read config
  my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");
  my %SEFRAN3 = readCfg("$WEBOBS{ROOT_CONF}/$s3.conf");

  my $lockFile = "/tmp/.$mc3.lock";

	# --- checks lock file
	if (-e $lockFile) {
		my $lockWho = qx(cat $lockFile | xargs echo -n);
		die "WEBOBS: MC is presently edited by $lockWho ...";
	} else {
		my $retLock = qx(echo "$oper" > $lockFile);
	}

	my $mc_id;
	my $newID = 1;
	my $maxID = 0;

	# --- reads MC file
	my ($mcy,$mcm) = split(/-/,$date);
	# The date of the event is mandatory
	if (defined($mcy)) {
		$mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
		my @lignes;
		if (-e $mc_file)  {
			print "MC file: $mc_file ...";
			open(FILE, "<$mc_file") || Quit($lockFile," Problem to read $mc_file\n");
			while(<FILE>) {
				my $line = $_;
				my $line2=$line;
				chomp($line2);
				($mc_id) = split(/\|/,$line2);
				# Ignore blank lines
				if (defined($mc_id)) {
					$maxID = abs($mc_id) if (abs($mc_id) > $maxID);
				}
				push(@lignes,$line);
			}
			close(FILE);
			print " imported (max ID = $maxID).\n";
		} else {
			# MC file does not exist: need to create directory and empty file.
			if ($arg =~ /update/) {
				qx(mkdir -p `dirname $mc_file`);
				open(FILE, ">$mc_file") || Quit($lockFile,"Problem to create new file $mc_file\n");
				print FILE ("");
				close(FILE);
				$mc_id = 1;
			}
		}

		# --- outputs for MC
		if ($newID > 0) {
			$mc_id = $maxID + 1;

      my $unite = '';
      my @durations = readCfgFile("$MC3{DURATIONS_CONF}");
      foreach $duration (@durations) {
        my ($key,$nam,$val) = split(/\|/,@duration);
        if ($dur > $val) {
          $evt_dur = $dur / $val;
          $unite = $key;
        }
      }


			my @image_list = $img;
      my $timestamp = strftime "%Y%m%dT%H%M%S", gmtime;
			my $newline = "$mc_id|$evt_sdate|$evt_stime|$type|$amp|$evt_dur"
        ."|$unite|$duree_sat|$nb_evts|$evt_SP|$station|$is_unique"
        ."|$sefran3_name|$evt_id|".join(',', @image_list)."|$oper/$timestamp|$comment\n";
			print "$newline\n";
			push(@lignes,$newline);
		}

	# 	@lignes = sort Sort_date_with_id(@lignes);
  #
	# 	# Temporary file for sanity check before replacing
	# 	my $mc_file_temp="$mc_file.tmp";
	# 	# Open temporary file for writing
	# 	open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
	# 	# Write the updated lines
	# 	print FILE @lignes;
	# 	close(FILE);
	# 	# Sanity check : the columns number must always be 17 (empty lines are ignored)
	# 	if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
	# 		# Test passed, the file isn't corrupted
	# 		# The update should have increased the file size
	# 		if ( -s $mc_file_temp >= -s $mc_file ) {
	# 			# The file size is increased
	# 			# Replace the old file by the new one
	# 			if ( system("mv $mc_file_temp $mc_file") == 0 ) {
	# 				print "MC file: $mc_file updated\n";
	# 			} else {
	# 				Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
	# 			}
	# 		}
	# 	} else {
	# 		print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
	# 	}
    mc3_write($mc_file,@lignes,$lockFile);
	}

	# --- deletes lock file
	if (-e $lockFile) {
		unlink $lockFile;
	}
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_update: update MC3 existing entry
sub mc3_update {
  my ($mc3,$s3,$oper,$mcIDid,$date,$type,$amp,$dur,$duree_sat,$nb_evts,$evt_SP,$station,$is_unique,$evt_id,$img,$com) = @_;

  # ---- read config
  my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");
  my %SEFRAN3 = readCfg("$WEBOBS{ROOT_CONF}/$s3.conf");

  my $lockFile = "/tmp/.$mc3.lock";

  # --- checks lock file
  if (-e $lockFile) {
    my $lockWho = qx(cat $lockFile | xargs echo -n);
    die "WEBOBS: MC is presently edited by $lockWho ...";
  } else {
    my $retLock = qx(echo "$oper" > $lockFile);
  }

  # --- reads MC file
  my ($mcy,$mcm) = split(/-/,$date);
  # The date of the event is mandatory
  if (defined($mcy)) {
    $mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
    my @lignes;
    if (-e $mc_file)  {
      # Read current file
    	print "<P><B>Existing file:</B> $mc_file ...";
    	open(FILE, "<$mc_file") || Quit($lockFile,"$__{'Could not open'} $mc_file\n");
    	while(<FILE>) {
    		chomp;
    		push(@lignes, $_) if $_;
    	}
    	close(FILE);
    	print "imported.</P>";

      # existing event (modification): reads all but concerned ID
      #
      if ($mcIDid) {
      	# Get the event from @lignes
      	my @ligne = grep { /^$mcIDid\|/ } @lignes;
      	# Remove the event from @lignes
      	@lignes = grep { $_ !~ /^$mcIDid\|/ } @lignes;
    		$id_evt = $mcIDid;
    		print "<P><B>Modifying existing event:</B> $id_evt</P>";
    		# read existing line
        my ($id_evt,$isodateEvnt,$typeEvnt,$amplitudeEvnt,$dureeEvnt,$uniteEvnt,$dureeSatEvnt,$nbrEvnt,$smoinsp,$stationEvnt,$arrivee,$fileNameSUDS,$idSC3,$imglist,$oper_timestamp,$comment) = split(/\|/,@ligne[0]);
    		@image_list = split(/,/,$imglist);
    		# check if there is an existing image with the same minute
    		my $idx = first { substr($img,0,-6) eq substr($image_list[$_],0,-6) } 0..$#image_list;
    		if(defined $idx) {
    			# if found, update image name
    			splice(@image_list,$idx,1,$img);
    		}
    		else {
    			# otherwise, add to the list
    			my @new_image_list = $img;
    			push(@new_image_list, @image_list);
    			@image_list = @new_image_list;
    		}
      }
      if !($date eq '') {
        $isodateEvnt = $date;
      }
      if !($type eq '') {
        $typeEvnt = $type;
      }
      if !($amp eq '') {
        $amplitudeEvnt = $amp;
      }
      if !($dur eq '') {
        my $unite = '';
        my @durations = readCfgFile("$MC3{DURATIONS_CONF}");
        foreach $duration (@durations) {
          my ($key,$nam,$val) = split(/\|/,@duration);
          if ($dur > $val) {
            $evt_dur = $dur / $val;
            $unite = $key;
          }
        }
        $dureeEvnt = $dur;
        $uniteEvnt = $unite;
      }
      if !($duree_sat eq '') {
        $dureeSatEvnt = $duree_sat;
      }
      if !($nb_evts eq '') {
        $nbrEvnt = $nb_evts;
      }
      if !($evt_SP eq '') {
        $smoinsp = $evt_SP;
      }
      if !($station eq '') {
        $stationEvnt = $station;
      }
      if !($is_unique eq '') {
        $arrivee = $is_unique;
      }
      if !($evt_id eq '') {
        $idSC3 = $evt_id;
      }
      if !($oper eq '') {
        my $timestamp = strftime "%Y%m%dT%H%M%S", gmtime;
        $oper_timestamp = "$oper/$timestamp";
      }
      if !($com eq '') {
        $comment = $com;
      }

      my $chaine = "$id_evt|$isodateEvnt|$typeEvnt|$amplitudeEvnt|$dureeEvnt|$uniteEvnt"
    		."|$dureeSatEvnt|$nbrEvnt|$smoinsp|$stationEvnt|$arrivee"
    		."|$fileNameSUDS|$idSC3|".join(',', @image_list)."|$oper_timestamp|$comment";
    	push(@lignes, u2l($chaine));
    }

    # @lignes = sort Sort_date_with_id(@lignes);
    #
    # # Temporary file for sanity check before replacing
    # my $mc_file_temp="$mc_file.tmp";
    # # Open temporary file for writing
    # open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
    # # Write the updated lines
    # print FILE @lignes;
    # close(FILE);
    # # Sanity check : the columns number must always be 17 (empty lines are ignored)
    # if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
    #   # Test passed, the file isn't corrupted
    #   # The update should have increased the file size
    #   if ( -s $mc_file_temp >= -s $mc_file ) {
    #     # The file size is increased
    #     # Replace the old file by the new one
    #     if ( system("mv $mc_file_temp $mc_file") == 0 ) {
    #       print "MC file: $mc_file updated\n";
    #     } else {
    #       Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
    #     }
    #   }
    # } else {
    #   print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
    # }
    mc3_write($mc_file,@lignes,$lockFile);
  }

  # --- deletes lock file
  if (-e $lockFile) {
    unlink $lockFile;
  }
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_del: delete MC3 entry
sub mc3_del {
  my ($mc3,$mcIDid,$oper) = @_;

  # ---- read config
  my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");

  my $lockFile = "/tmp/.$mc3.lock";

  # --- checks lock file
  if (-e $lockFile) {
    my $lockWho = qx(cat $lockFile | xargs echo -n);
    die "WEBOBS: MC is presently edited by $lockWho ...";
  } else {
    my $retLock = qx(echo "$oper" > $lockFile);
  }

  # --- reads MC file
  my ($mcy,$mcm) = split(/-/,$date);
  # The date of the event is mandatory
  if (defined($mcy)) {
    $mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
    my @lignes;
    if (-e $mc_file)  {
      # Read current file
      print "<P><B>Existing file:</B> $mc_file ...";
      open(FILE, "<$mc_file") || Quit($lockFile,"$__{'Could not open'} $mc_file\n");
      while(<FILE>) {
        chomp;
        push(@lignes, $_) if $_;
      }
      close(FILE);
      print "imported.</P>";

      # existing event (modification): reads all but concerned ID
      #
      if ($mcIDid) {
        # Get the event from @lignes
        my @ligne = grep { /^$mcIDid\|/ } @lignes;
        # Remove the event from @lignes
        @lignes = grep { $_ !~ /^$mcIDid\|/ } @lignes;
      }
      # @lignes = sort Sort_date_with_id(@lignes);
      #
      # # Temporary file for sanity check before replacing
      # my $mc_file_temp="$mc_file.tmp";
      # # Open temporary file for writing
      # open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
      # # Write the updated lines
      # print FILE @lignes;
      # close(FILE);
      # # Sanity check : the columns number must always be 17 (empty lines are ignored)
      # if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
      #   # Test passed, the file isn't corrupted
      #   # The update should have increased the file size
      #   if ( -s $mc_file_temp >= -s $mc_file ) {
      #     # The file size is increased
      #     # Replace the old file by the new one
      #     if ( system("mv $mc_file_temp $mc_file") == 0 ) {
      #       print "MC file: $mc_file updated\n";
      #     } else {
      #       Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
      #     }
      #   }
      # } else {
      #   print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
      # }
      mc3_write($mc_file,@lignes,$lockFile);
    }
    # --- deletes lock file
    if (-e $lockFile) {
      unlink $lockFile;
    }
  }
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_trash: put MC3 entry to trash
sub mc3_trash {
  my ($mc3,$mcIDid,$oper) = @_;

  # ---- read config
  my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");

  my $lockFile = "/tmp/.$mc3.lock";

  # --- checks lock file
  if (-e $lockFile) {
    my $lockWho = qx(cat $lockFile | xargs echo -n);
    die "WEBOBS: MC is presently edited by $lockWho ...";
  } else {
    my $retLock = qx(echo "$oper" > $lockFile);
  }

  # --- reads MC file
  my ($mcy,$mcm) = split(/-/,$date);
  # The date of the event is mandatory
  if (defined($mcy)) {
    $mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
    my @lignes;
    if (-e $mc_file)  {
      # Read current file
      print "<P><B>Existing file:</B> $mc_file ...";
      open(FILE, "<$mc_file") || Quit($lockFile,"$__{'Could not open'} $mc_file\n");
      while(<FILE>) {
        chomp;
        push(@lignes, $_) if $_;
      }
      close(FILE);
      print "imported.</P>";

      # existing event (modification): reads all but concerned ID
      #
      if ($mcIDid) {
        # Get the event from @lignes
        my @ligne = grep { /^$mcIDid\|/ } @lignes;
        # Remove the event from @lignes
        @lignes = grep { $_ !~ /^$mcIDid\|/ } @lignes;

        # move to / remove from trash: change sign of ID value
        if ($mcIDid > 0) {
          $id_evt = -($mcIDid);
      		print "<P><B>Put existing event into trash:</B> $id_evt</P>";
        }
        else {
          print "<P><B>Cannot put existing event in trash (already in trash):</B> $id_evt</P>";
        }
      }
      # @lignes = sort Sort_date_with_id(@lignes);
      #
      # # Temporary file for sanity check before replacing
      # my $mc_file_temp="$mc_file.tmp";
      # # Open temporary file for writing
      # open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
      # # Write the updated lines
      # print FILE @lignes;
      # close(FILE);
      # # Sanity check : the columns number must always be 17 (empty lines are ignored)
      # if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
      #   # Test passed, the file isn't corrupted
      #   # The update should have increased the file size
      #   if ( -s $mc_file_temp >= -s $mc_file ) {
      #     # The file size is increased
      #     # Replace the old file by the new one
      #     if ( system("mv $mc_file_temp $mc_file") == 0 ) {
      #       print "MC file: $mc_file updated\n";
      #     } else {
      #       Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
      #     }
      #   }
      # } else {
      #   print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
      # }
      mc3_write($mc_file,@lignes,$lockFile);
    }
    # --- deletes lock file
    if (-e $lockFile) {
      unlink $lockFile;
    }
  }
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_untrash: recover MC3 entry from trash
sub mc3_untrash {
  my ($mc3,$mcIDid,$oper) = @_;

  # ---- read config
  my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");

  my $lockFile = "/tmp/.$mc3.lock";

  # --- checks lock file
  if (-e $lockFile) {
    my $lockWho = qx(cat $lockFile | xargs echo -n);
    die "WEBOBS: MC is presently edited by $lockWho ...";
  } else {
    my $retLock = qx(echo "$oper" > $lockFile);
  }

  # --- reads MC file
  my ($mcy,$mcm) = split(/-/,$date);
  # The date of the event is mandatory
  if (defined($mcy)) {
    $mc_file = "$MC3{ROOT}/$mcy/$MC3{PATH_FILES}/$MC3{FILE_PREFIX}$mcy$mcm.txt";
    my @lignes;
    if (-e $mc_file)  {
      # Read current file
      print "<P><B>Existing file:</B> $mc_file ...";
      open(FILE, "<$mc_file") || Quit($lockFile,"$__{'Could not open'} $mc_file\n");
      while(<FILE>) {
        chomp;
        push(@lignes, $_) if $_;
      }
      close(FILE);
      print "imported.</P>";

      # existing event (modification): reads all but concerned ID
      #
      if ($mcIDid) {
        # Get the event from @lignes
        my @ligne = grep { /^$mcIDid\|/ } @lignes;
        # Remove the event from @lignes
        @lignes = grep { $_ !~ /^$mcIDid\|/ } @lignes;

    		# move to / remove from trash: change sign of ID value
        if ($mcIDid < 0) {
          $id_evt = -($mcIDid);
      		print "<P><B>Recover existing event from trash:</B> $id_evt</P>";
        }
        else {
          print "<P><B>Cannot recover existing event from trash (not in trash):</B> $id_evt</P>";
        }
      }
      # @lignes = sort Sort_date_with_id(@lignes);
      #
      # # Temporary file for sanity check before replacing
      # my $mc_file_temp="$mc_file.tmp";
      # # Open temporary file for writing
      # open(FILE, ">$mc_file_temp") || Quit($lockFile,"Problem with file $mc_file_temp !\n");
      # # Write the updated lines
      # print FILE @lignes;
      # close(FILE);
      # # Sanity check : the columns number must always be 17 (empty lines are ignored)
      # if (system("awk -F'|' 'NF>0&&NF!=17{exit 1}' $mc_file") == 0) {
      #   # Test passed, the file isn't corrupted
      #   # The update should have increased the file size
      #   if ( -s $mc_file_temp >= -s $mc_file ) {
      #     # The file size is increased
      #     # Replace the old file by the new one
      #     if ( system("mv $mc_file_temp $mc_file") == 0 ) {
      #       print "MC file: $mc_file updated\n";
      #     } else {
      #       Quit($lockFile,"Problem while replacing file $mc_file by $mc_file_temp!\n");
      #     }
      #   }
      # } else {
      #   print "Problem with updated file : bad columns number ! Not replacing file $mc_file !\n";
      # }
      mc3_write($mc_file,@lignes,$lockFile);
    }
    # --- deletes lock file
    if (-e $lockFile) {
      unlink $lockFile;
    }
  }
}
