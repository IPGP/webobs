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
# mc3_add: add MC3 entry
sub mc3_add {
        my ($mc3,$s3,$oper,$date,$type,$amp,$dur,$duree_sat,$nb_evts,$evt_SP,$station,$is_unique,$evt_id,$img,$comment) = @_;

        # ---- read config
        my %MC3 = readCfg("$WEBOBS{ROOT_CONF}/$mc3.conf");
        my %SEFRAN3 = readCfg("$WEBOBS{ROOT_CONF}/$s3.conf");

        # my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1||$evt_scode|1|$sefran3_name|lfdetect:$evt_id|$evt_img|$oper|$comment\n";
        # my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique|$sefran3_name|$fdsnws_server:\/\/$evt_id||$oper|$evt_magtyp$evt_mag $evt_txt\n";
        # my ($id_evt,$date,$heure,$type,$amplitude,$duree,$unite,$duree_sat,$nombre,$s_moins_p,$station,$arrivee,$suds,$qml,$event_img,$signature,$comment,$origin) = split(/\|/,$_);
        # my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique|$sefran3_name|$evt_y/$evt_m/$evt_d/$evt_id||$oper|\n";

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
  							# check if $evt_mcID found
  							if ($evt_mcID ne '') {
  								if ($mcIDname eq $mc3 && $mcIDym eq "$mcy$mcm" && $mc_id == $mcIDid) {
  									my @txt = split(/\|/,$line);
  									# Sanity check : we mustn't change a SC3 ID already stored in the MC3 file
  									if ( $txt[13] eq '' ) {
  										# Sanity check : we update the MC file only if the date of the event is the same (under $max_dts_sc3_mc3)
  										# It is necessary if the MC file has been corrupted or deleted and the new file doesn't have the same IDs than before, so we can't use the MC IDs stored in SC3
  										my $strp = DateTime::Format::Strptime->new(
  											pattern   => '%Y-%m-%d %H:%M:%S',
  											time_zone => 'UTC',
  										);
  										# Datetimes in XML and MC3 (truncated to second)
  										my $dt_qml = $strp->parse_datetime($evt_sdate." ".substr($evt_stime,0,8));
  										my $dt_mc = $strp->parse_datetime($txt[1]." ".substr($txt[2],0,8));
  										# Unix timestamps in XML and MC3
  										my $ts_qml=$dt_qml->epoch;
  										my $ts_mc=$dt_mc->epoch;
  										# Difference of timestamps : it must be under $max_dts_sc3_mc3
  										my $dts=abs($ts_qml-$ts_mc);
  										# If it's the same event
  										if ($dts < $max_dts_sc3_mc3) {
  											$newID = 0;
  											# Update Event ID
  											print "Replacing ID $txt[13] by $evt_y/$evt_m/$evt_d/$evt_id (dts $dts)\n";
  											$txt[13] = "$evt_y/$evt_m/$evt_d/$evt_id";
  											# @txt last field already contains "\n"
  											$line = join('|',@txt);
  										} else {
  											print "Same MC ID ($mc_id) but with different date : $evt_sdate $evt_stime (QML) != $txt[1] $txt[2] (MC)\n"
  										}
  									} else {
  											print "This MC ID ($mc_id) already has a SC3 ID ($txt[13]) !\n"
  									}
  								}
  							}
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
  					my $newline = "$mc_id|$evt_sdate|$evt_stime|$evt_type||$evt_dur|s|0|1|$evt_SP|$evt_scode|$evt_unique|$sefran3_name|$evt_y/$evt_m/$evt_d/$evt_id||$oper|\n";
  					print "$newline\n";
  					push(@lignes,$newline);
  				}

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

				# --- deletes lock file
				if (-e $lockFile) {
					unlink $lockFile;
				}
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_update: update MC3 existing entry
sub mc3_update {
        my ($s,$xml2) = @_;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_del: delete MC3 entry
sub mc3_del {
        my ($s,$xml2) = @_;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# mc3_trash: put MC3 entry to trash
sub mc3_trash {
        my ($s,$xml2) = @_;
}
