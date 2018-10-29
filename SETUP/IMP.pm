
=head1 NAME

IMP.pm - Import a legacy network 

=cut

use strict;
use warnings;
use POSIX qw(strftime);
use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils qw(u2l l2u);
use File::Basename;

our $dry = 1;    # default is dry-run

our $LEG_PATH    = "~/sandbox/legwo";
our $LEG_RESEAUX = "$LEG_PATH/RESEAUX.conf";
our $LEG_NODES   = "$LEG_PATH";
our $FILE_DISCIPLINES = "$LEG_PATH/DISCIPLINES.conf";
our $FILE_OWNERS = "$LEG_PATH/OWNERS.conf";

our @infoGenerales = ("");
our ($graphFile, %G, $g, $t0);
our (@ol, @cl);

my $sep="="x60;
print( strftime("%F %R ",localtime(time())).$sep."\n");
print "The following commands are now available (numerics indicate sequence):\n";
print "  IMPORT0                 : initial base migration process: VIEWS,PROCS,NODES,FORMS\n";
print "  dryrun                  : toggle 'dry run' mode ON or OFF\n\n";

print "The following legacy data paths are in use:\n";
print "  FROM           : $LEG_PATH\n";
print "  FROM 'reseaux' : $LEG_RESEAUX\n";
print "  FROM NODES     : $LEG_NODES\n";

print "now logging to console AND IMP.stdout\n\n";
open (STDOUT, "| tee -ai IMP.stdout"); 
print( strftime("\n%F %R ",localtime(time())).$sep."\n");
printf ("dryrun now %s\n",($dry==1)?"ON":"OFF - at your own risk");

# call this to toggle 'dry-run' mode
#
sub dryrun {
	$dry ^= 1;
	print( "\n".strftime("%F %R ",localtime(time())));
	printf ("dryrun now %s\n\n",($dry==1)?"ON":"OFF - at your own risk");
}

# guess what ... 
sub IMPORT0 {  
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> IMP::MIGRATE0\n";
	$t0 = time;
	my (@liste, $i);
	$graphFile = $LEG_RESEAUX;
	printf("%+6d IMP.0 from %s\n", time-$t0, $graphFile);
	
	open(FILE, "<$graphFile") or die "open $graphFile failed: $!\n";
	while(<FILE>) { push(@infoGenerales,$_); }
	close(FILE);
	
	chomp(@infoGenerales);
	@infoGenerales = grep(!/^#/, @infoGenerales);
	@infoGenerales = grep(!/^$/, @infoGenerales);
	
	# "DISCIPLINE" --> DISCIPLINES.conf
	#
	printf("%+6d DISCIPLINES -> %s\n", time-$t0, $FILE_DISCIPLINES);
	my @listeMrkD = getTag("DISCIPLINE","mrk");
	my @listeCodesD = getTag("DISCIPLINE","cod");
	my @listeKeyD = getTag("DISCIPLINE","key");
	my @listeOrdD = getTag("DISCIPLINE","ord");
	my @listeNomsD = getTag("DISCIPLINE","nom");
	
	my @tlcodes = @listeCodesD;
	for $i (0..scalar(@tlcodes)) {
		if (exists($DISCP{$tlcodes[$i]})) { 
			print "imported discipline $tlcodes[$i] already exists...ignored\n"; 
			splice(@listeCodesD, $i, 1);
		}  
	}

	if (!$dry) {
		open(WRT, ">>$FILE_DISCIPLINES");
		$i = 0;
		for (@listeCodesD) {
			printf(WRT "%s|%s|%s|%s|%s\n",$listeCodesD[$i],$listeOrdD[$i],$listeKeyD[$i],$listeNomsD[$i],$listeMrkD[$i]);
			$i += 1;
		}
		close(WRT);
	} else { print "would update $FILE_DISCIPLINES with codes @listeCodesD\n" };
	
	# "OBSERVATOIRE" --> OWNERS.conf
	#
	printf("%+6d OBSERVATOIRES -> %s\n", time-$t0, $FILE_OWNERS);
	my @listeCodesO = getTag("OBSERVATOIRE","cod");
	my @listeNomsO = getTag("OBSERVATOIRE","nom");
	
	my @tlcodes = @listeCodesO;
	for $i (0..scalar(@tlcodes)) {
		if (exists($OWNRS{$tlcodes[$i]})) { 
			print "imported owner $tlcodes[$i] already exists...ignored\n"; 
			splice(@listeCodesO, $i, 1);
		}  
	}
	if (!$dry) {
		open(WRT, ">>$FILE_OWNERS");
		$i = 0;
		for (@listeCodesO) {
			printf(WRT "%s|%s\n",$listeCodesO[$i],$listeNomsO[$i]);
			$i += 1;
		}
		close(WRT);
	} else { print "would update $FILE_OWNERS with codes @listeCodesO\n" };

	# For the migration process, each FORM is identified by an existing 
	# "reseaux<Formname>.conf" file (eg. reseauxGaz.conf) that points to ID3 'networks'.
	# Create a subdirectory FORMNAME for each FORM, in $WEBOBS{PATH_FORMS} and 
	# a FORMNAME.conf file in it, built from the legacy WEBOBS.conf statements related to 
	# this FORM.
	# Then hash (%F) all the ID3 => FORMname relationships, to be later used in VIEWS and 
	# PROCS definitions of their 'frm' attribute 
	#
    my %F;
	my @formsconfs = qx(ls $LEG_PATH/reseaux*.conf);
	for my $f (@formsconfs) {
		chomp($f);
		# following $ucf assignment only under perl 5.14 ('r' modifier = non-destructive)
		#my $ucf = uc($f =~ s!$confpath/reseaux(.*).conf!$1!gr);
		my $ucf = uc($f);
		$ucf =~ s!$LEG_PATH/reseaux(.*).conf!$1!gi;

		# ID3 => FORM hash
		open(RDR, "<$f") or die "open $f failed: $!\n";
		while(<RDR>) {
			chomp;
			if (! /^#/) { $F{$_} = $ucf; }
		}
		close(RDR);

		# FORMNAME directory
		printf("%+6d creating %s\n", time-$t0, "$WEBOBS{PATH_FORMS}/$ucf");
		if ($dry) {print "would mkdir -p $WEBOBS{PATH_FORMS}/$ucf\n"} else { qx(mkdir -p $WEBOBS{PATH_FORMS}/$ucf) };
		# build the FORMNAME.conf from WEBOBS.conf related statements
		my $pgrep = " \"^$ucf"."_|_"."$ucf\" $LEG_PATH/WEBOBS.conf >$PATH_FORMS/$ucf/$ucf.conf";
		qx(grep -P $pgrep);
		# move the FORM associated files to the brand new FORM/FORMNAME directory
	    $pgrep = " \"^$ucf"."_FILE_.*\\\|.*.conf\" $LEG_PATH/WEBOBS.conf";
		my @l = qx(grep -P $pgrep);
		for (@l) {
			chomp;
			s/(^.*\|)//g;
			if ($dry) {print "would mv $LEG_PATH/$_ $WEBOBS{PATH_FORMS}/$ucf/\n"} else { qx(mv $LEG_PATH/$_ $WEBOBS{PATH_FORMS}/$ucf/) };
		}
	}

	# NETWORKS --> VIEWS/xxx and PROCS/xxx
	#
	for (grep(!/^OBSERVATOIRE|^DISCIPLINE|^TYPERESEAU/,@infoGenerales)) {
		my ($res,$code,$value) = split (/\|/,$_);
		$value =~ s/[\[\]{}']//g;     ### the quotes & brackets blind reaper ###
		$G{$res}{$code} = $value;
	}
	printf("%+6d Start processing %d 'networks'\n", time-$t0, scalar(keys %G));
	for $g (keys (%G)) {
		#
		# PROCS: legacy-network $g ==> PROCS/$g if it has 'ext' defined
		#
		if (defined($G{$g}{ext}) and length($G{$g}{ext}) > 2 ) {
			my @Existing = WebObs::Grids::listProcNames;
			if ( ! ($g ~~ @Existing)) {
				my $r;
				if ($dry) {print "would mkdir -p $PATH_PROCS/$g\n"} else { qx(mkdir -p $PATH_PROCS/$g) };
				my $path = "$PATH_PROCS/$g/$g.conf";
				printf("%+6d created %s \n", time-$t0, $path);
				my @out;
				no warnings "uninitialized";
				push(@out,"=key|value\n");
				push(@out,"# M2G.0 from $graphFile on ".strftime("%Y-%m-%d %H:%M:%S %z",localtime)."\n\n");
				push(@out,"NAME|$G{$g}{nom}\n");
				push(@out,"net|$G{$g}{net}\n");
				push(@out,"RAWDATA|$G{$g}{ftp}\n");
				push(@out,"TZ|$G{$g}{utc}\n");
				push(@out,"TIMESCALELIST|$G{$g}{ext}\n");
				push(@out,"DECIMATELIST|$G{$g}{dec}\n");
				push(@out,"CUMULATELIST|$G{$g}{cum}\n");
				push(@out,"DATESTRLIST|$G{$g}{fmt}\n");
				push(@out,"MARKERSIZELIST|$G{$g}{mks}\n");
				push(@out,"THUMBNAIL|$G{$g}{ico}\n");
				$r = index($G{$g}{ext},'xxx')!=-1 ? 1 : 0; push(@out,"REQUEST|$r\n");
				push(@out,"cro|TBD\n");
				push(@out,"URL|$G{$g}{lnk}\n");
				push(@out,"ddb|$G{$g}{ddb}\n");
				my $legacyID3 = "";
				my $dislist="";
				my $formslist="";
				# handle {obs} and {cod} that are arrays !
				@ol = split(',',$G{$g}{obs});
				@cl = split(',',$G{$g}{cod});
				for my $o (@ol) {
					for my $c (@cl) {
						if (length($o.$c) == 3) { 
							$legacyID3 .= $o.$c." ";
							$dislist .= substr($c,0,1)." ";
							foreach my $k (keys %F) {
								if ($o.$c eq $k) { 
									$formslist .= $F{$k}." " ;
									if ($dry) { print "would ln -s $WEBOBS{PATH_FORMS}/$F{$k} $WEBOBS{PATH_GRIDS2FORMS}/PROC.$g.$F{$k}\n"} else { qx(ln -s $WEBOBS{PATH_FORMS}/$F{$k} $WEBOBS{PATH_GRIDS2FORMS}/PROC.$g.$F{$k}) };
								}
							}
							migID3Stations('PROC', $g, $o.$c, 'UTC_DATA|'.$G{$g}{utc});
						}
					}
				}
				if ($legacyID3 ne "") { push(@out,"id3|$legacyID3\n");}
				if ($formslist ne "") { push(@out,"FORM|$formslist\n");}
				if ($dislist ne "")   { push(@out,"DOMAIN|$dislist\n");}
				if (!$dry) {
					open(WRT, ">$path");
					print WRT @out ; 
					close(WRT);
				}
			}
		} 
		#
		# VIEWS: legacy-network $g ==> VIEWS/$g if it has a non-zero 'net'
		#
		if (defined($G{$g}{net}) and $G{$g}{net} != 0) {
			my @Existing = WebObs::Grids::lisViewNames;
			if ( ! ($g ~~ @Existing)) {
				if (!defined($G{$g}{cod}) or !defined($G{$g}{obs})) {
					print "No ID3 (missing obs and/or cod) for $g ";
					# my $in = <STDIN>;
					# chomp($in);
					# if (length($in) != 3) {
						print " - $g skipped, NOT migrated\n";
						next;
					# }
					# $G{$g}{obs} = substr($in,0,1);
					# $G{$g}{cod} = substr($in,1,2);
				}
				if ($dry) {print "would mkdir -p $PATH_VIEWS/$g\n"} else { qx(mkdir -p $PATH_VIEWS/$g) };
				my $path = "$PATH_VIEWS/$g/$g.conf";
				printf("%+6d created %s\n", time-$t0, $path);
				my @out;
				no warnings "uninitialized";
				push(@out,"=key|value\n");
				push(@out,"# M2G.0 from $graphFile on ".strftime("%Y-%m-%d %H:%M:%S %z",localtime)."\n\n");
				push(@out,"NAME|$G{$g}{nom}\n");
				push(@out,"net|$G{$g}{net}\n");
				push(@out,"OWNCODE|$G{$g}{obs}\n");
				push(@out,"NODENAME|$G{$g}{snm}\n");
				push(@out,"NODESIZE|$G{$g}{ssz}\n");
				push(@out,"NODERGB|$G{$g}{rvb}\n");
				push(@out,"MAPLIST|$G{$g}{map}\n");
				push(@out,"URL|$G{$g}{htm}\n");
				push(@out,"DISPLAY|$G{$g}{web}\n"); 
				push(@out,"TYPE|$G{$g}{typ}\n");
				my $legacyID3 = "";
				my $dislist="";
				my $formslist="";
				# + handle {obs} and {cod} that are arrays !
				@ol = split(',',$G{$g}{obs});
				@cl = split(',',$G{$g}{cod});
				for my $o (@ol) {
					for my $c (@cl) {
						if (length($o.$c) == 3) { 
							$legacyID3 .= $o.$c." ";
							$dislist .= substr($c,0,1)." ";
							#foreach my $k (keys %F) {
							#	if ($o.$c eq $k) { 
							#		$formslist .= $F{$k}." "; 
							#		qx(ln -s $WEBOBS{PATH_FORMS}/$F{$k} $WEBOBS{PATH_GP2FORMS}/VIEW.$g.$F{$k});
							#	}
							#}
							migID3Stations('VIEW', $g, $o.$c, 'ACQ_RATE|'.$G{$g}{acq}, 'LAST_DELAY|'.$G{$g}{lst});
						}
					}
				}
				my $r = index($G{$g}{ext},'xxx')!=-1 ? 1 : 0; push(@out,"REQUEST|$r\n");
				if ($legacyID3 ne "") { push(@out,"id3|$legacyID3\n");}
				if ($formslist ne "") { push(@out,"FORM|$formslist\n");}
				if ($dislist ne "")   { push(@out,"DOMAIN|$dislist\n");}
				if (!$dry) {
					open(WRT, ">$path");
					print WRT @out ; 
					close(WRT);
				}
			}
		}
	} # end for $g (keys (%G)) 

	printf("\n\n%+6d M2G.0 summary:\n", time-$t0);
	printf("        ------------------\n");
	if (!$dry) {
		printf("%+8d forms\n",qx(ls -1 $PATH_FORMS | wc -l));
		printf("%+8d procs\n",qx(ls -1 $PATH_PROCS | wc -l));
		printf("%+8d views\n",qx(ls -1 $PATH_VIEWS | wc -l));
		printf("%+8d nodes\n",qx(ls -1 $PATH_NODES/*/*.cnf | wc -l));
		print qx(echo '\n\n---------------'$confpath/FORMS && ls $PATH_FORMS);
		print qx(echo '\n\n---------------'$confpath/PROCS && ls $PATH_PROCS);
		print qx(echo '\n\n---------------'$confpath/VIEWS && ls $PATH_VIEWS);
		for (qx(ls -1 $confpath/PROCS)) { chomp; print "----$PATH_PROCS/$_/$_.conf\n"; print qx(cat $PATH_PROCS/$_/$_.conf); print "\n"};
		for (qx(ls -1 $confpath/VIEWS)) { chomp; print "----$PATH_VIEWS/$_/$_.conf\n"; print qx(cat $PATH_VIEWS/$_/$_.conf); print "\n"};
		print "--------- FORMS\n\n"; for (qx(ls -1 $PATH_FORMS/*)) { print "$_"; };
	}

	printf("\n%+6d M2G.0 done.\n", time-$t0);
	#close(STDOUT); 

} 

sub MIGRATE_1_NODESXLATE {
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_1_NODESXLATE\n";
	$t0 = time;
	my $i = 0;
	my @files = <$PATH_NODES/*/*.cnf>;
	for (@files) {
		open RDR, "<$_" or die "Couldn't open in '$_': $!";
		my @f = <RDR>;
		close RDR;
		for (@f) {
			s/^NOM\|/NAME|/;              
			s/^FILES_CARACTERISTIQUES\|/FILES_FEATURES\|/;                                                                                                                                               
			s/^VALIDE\|/VALID\|/;
			# next 3 to change | to \| except first one
			s/^(.*?)\|/$1¤/;
			s/\|/\\\|/g;
			s/^(.*?)¤/$1\|/;
		}
		if ( $dry && ($i == 0 || $i == $#files) ) {
			print "Sample update for $_ :\n [\n @f \n]\n";
		}
		if (!$dry) {
			open WRT, ">$_" or die "Couldn't open out '$_': $!";
			for (@f) {
				print WRT $_;
			}
			close WRT;
		}
		print "$_ done\n";
		$i++;
	}
}

sub MIGRATE_1_FORMSCONF {
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_1_FORMSCONF\n";
	$t0 = time;
	my (@liste, $i);
	my @lsd = qx(ls -d $PATH_FORMS/*);
	chomp(@lsd);
	foreach (@lsd) { 
		s/.*FORMS\///g;
		my $form = $_;
		my $prefix = $form."_";
		open RDR, "<$PATH_FORMS/$form/$form.conf" or die "Couldn't open in $PATH_FORMS/$form/$form.conf : $!";
		my @f = <RDR>;
		close RDR;
		for (@f) {
			s/^CGI_AFFICHE_.*\|/CGI_SHOW|/;
			s/$prefix//;
		}
		unshift(@f, "=key|value\n"); # add the new readCfg format-specification
		if (!$dry) {
			open WRT, ">$PATH_FORMS/$form/$form.conf" or die "Couldn't open out $PATH_FORMS/$form/$form.conf : $!";
			for (@f) {
				print WRT $_;
			}
			close WRT;
		} else { print "would set [\n @f \n] "}
		print "$PATH_FORMS/$form/$form.conf done\n";
	}
}

sub MIGRATE_2_NODESFEATURES {
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_2_NODESFEATURES\n";
	$t0 = time;
	my @nodes = <$PATH_NODES/*>;
	chomp(@nodes);
	for my $n (@nodes) {
		if ($dry) { print "would mkdir -p $n/FEATURES\n"} else { qx(mkdir -p $n/FEATURES);}
		die "Couldn't create $n/FEATURES; $!" if ($?);
		my @files = qx(find $n -maxdepth 1 -not -name 'info.txt*' -not -name 'installation.txt*' -not -name 'type.txt*' -not -name 'acces.txt*' -name '*.txt*');
		die "Couldn't find txt's; $!" if ($?);
		chomp(@files);
		for my $f (@files) {
			if ($dry) { print "would mv $f $n/FEATURES/\n" } else { qx(mv $f $n/FEATURES/);} 
			die "Couldn't move $f to $n/FEATURES; $? " if ($?);
		}
		print "$n done\n";
	}
}

sub MIGRATE_3_FORMSNET2GRIDS {
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_3_FORMSNET2GRIDS\n";
	my @forms= <$PATH_FORMS/*> ;
	foreach (@forms) {
		if ($dry) { print "would  sed -ie 's/FILE_RESEAUX|/FILE_PROCS|/' $_/".basename($_).".conf\n" }
		else { qx(sed -ie 's/FILE_RESEAUX|/FILE_PROCS|/' $_/$_.conf") }
		my @file = <$_/reseaux*.conf> ;
		for my $fn (@file) {
			open RDR, "<$fn" or die "Couldn't open $fn : $!";
			my @f = <RDR>;
			close RDR;
			for (@f) { 
				next if m/^#/ ;
				next if m/^$/;
				chomp();
				my @res = qx(grep "id3\|$_" $PATH_PROCS/*/*.conf);
				if (scalar(@res) > 0) {
					$res[0] = basename($res[0]); 
					$res[0] =~ s/\.conf//;
					$res[0] =~ s/:.*$//g;
					chomp($res[0]);
					if ($dry) { print "would  sed -ie \'s/$_/$res[0]/\' $fn\n" }
					else { qx(sed -ie \'s/$_/$res[0]/\' $fn) }
				}
			}
		print "$fn done.\n";
		}
	}
}

sub MIGRATE_3_NORMNODES {
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_3_NORMNODES\n";
	print "> NOP\n";
}

sub MIGRATE_4_ALIASDASH {
# late request: NODEs having their 'ALIAS' or 'DATA_FILE' set to '-' should NOT be included in PROC(s)
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_4_ALIASDASH\n";
	$t0 = time;
	my @files = <$PATH_NODES/*/*.cnf>;   #/
	for (@files) {
		open RDR, "<$_" or die "Couldn't open in '$_': $!";
		my @f = <RDR>;
		close RDR;
		if (grep(/ALIAS\|-|DATA_FILE\|-/,@f) && grep(/PROC\|/,@f) ) {
			my $p = '';
			for (@f) { if (/PROC\|/) { $p = $_ } } ;
			chomp($p);
			if ($dry) {
				print "would sed -ie \'/PROC|/d\' $_" ;
				s/$PATH_NODES\/.*\///g; 
				s/\.cnf//g;
				print " + rm $PATH_GRIDS2NODES/PROC.*.$_\n" ;
			}
			else {
				qx( sed -ie \'/PROC|/d\' $_ );
				s/$PATH_NODES\/.*\///g; 
				s/\.cnf//g;
				qx( rm $PATH_GRIDS2NODES/PROC.*.$_ );
			}
		}
	}
}

sub MIGRATE_5_FID {
	print( "\n".strftime("%F %R ",localtime(time())));
	print "> M2G::MIGRATE_5_FID\n";
	$t0 = time;
	my $i = 0;
	my @files = <$PATH_NODES/*/*.cnf>;
	for (@files) {
		open RDR, "<$_" or die "Couldn't open in '$_': $!";
		my @f = <RDR>;
		close RDR;
		for (@f) {
			s/^DATA_FILE\|/FID|/;              
		}
		if ( $dry && ($i == 0 || $i == $#files) ) {
			print "Sample update for $_ :\n [\n @f \n]\n";
		}
		if (!$dry) {
			open WRT, ">$_" or die "Couldn't open out '$_': $!";
			for (@f) {
				print WRT $_;
			}
			close WRT;
		}
		print "$_ done\n";
		$i++;
	}
}



# helper function to extract DISCIPLINE & OBSERVATOIRE definitions
#
sub getTag {
	my($stanza, $tag) = @_;
	my @l = grep (/^($stanza)\|($tag)\|/, @infoGenerales);
	$l[0] =~ s/^\w\*|\w*\|//gi;
	$l[0] =~ s/\'|{|}//gi;
	return split(/,/,$l[0]);
}


# STATIONS (called from main process, for each grid/proc, for which 
# stations are identified by the 3 digits legacy code 'obs+cod'
# 3 arguments: PROC or VIEW ($type)
#              name of PROC or VIEW ($name)
#              id 3 digits to identify stations ($id3)
sub migID3Stations {
	my ($type, $name, $id3, $s1, $s2) = @_;
	opendir(DIR, $$WEBOBS{PATH_NODES}) or die "couldn't opendir $WEBOBS{PATH_NODES} : $!";
	my @dirs = grep {/^($id3)/ && -d $PATH_NODES."/".$_} readdir(DIR);
	closedir(DIR);
	my ($dir, $o);
	for $dir (@dirs) {
		if (open RDR, "<", $PATH_NODES."/".$dir."/".$dir.".conf") {
			if (!-e $PATH_NODES."/".$dir."/".$dir.".cnf") {
				printf("%+6d   new $PATH_NODES/$dir/$dir.cnf [%s]\n", time-$t0, $type);
				if (!$dry) {
					if (open WRT, ">", $PATH_NODES."/".$dir."/".$dir.".cnf") {
						print(WRT "=key|value\n");
						print(WRT "# M2G created on ".strftime("%Y-%m-%d %H:%M:%S %z",localtime)."\n\n");
						while (<RDR>) {                # use all existing lines, replacing ... 
							s/\s/\|/;                  # ... 1st blank with | delimiter 
							print(WRT $_);             # 
						}
						print(WRT "$type|$name\n");    # new link to PROC or GRID line
						print(WRT "$s1\n");
						if (defined($s2)) { print(WRT "$s2\n") };
						close(WRT);                    
						qx(ln -s $PATH_NODES/$dir $PATH_GRIDS2NODES/$type.$name.$dir);
					}
				}
			} else {
				printf("%+6d   upd $PATH_NODES/$dir/$dir.cnf [%s]\n", time-$t0, $type);
				if (!$dry) {
					my $typefound=0;
					do {
						local $^I='~';
						local @ARGV=($PATH_NODES."/".$dir."/".$dir.".cnf");
						while(<>){
							chomp;
							if (/^($type)\|(.*)/) {
								$_ = "$type|$2,$name\n";
								$typefound++;
							}
						$_ .= "\n";
						print;
						}	
					};
					if ($typefound == 0) {
						if (open WRT, ">>", $PATH_NODES."/".$dir."/".$dir.".cnf") {
							print(WRT "$type|$name\n");
							close(WRT);
						}
					}
					qx(rm $PATH_NODES/$dir/$dir.cnf~);
					qx(ln -s $PATH_NODES/$dir $PATH_GRIDS2NODES/$type.$name.$dir);
				}
			}
			close(RDR);
		}
	}
}

1;

__END__

=pod

=head1 AUTHOR

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012 - Institut de Physique du Globe Paris

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
				
