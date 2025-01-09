
=head1 NAME

M2G.pm - Migrate Webobs to new Grid system

=head1 SYNOPSIS

console session (interactive): in "..../webobs/trunk/CODE/cgi-bin" : 

  use lib "..../webobs/trunk/SETUP"
  use M2G;
  <then commands ... see below>  

as a batch command: 

  ..../perl M2G [do] {REAPER|MIGRATE0|...}

if the keyword 'do' is specified the command will actually be executed !
otherwise, this will be a dry-run of the command.

=head1 DESCRIPTION

Migrate configuration files to the new 'grid' design. New files are 
created and old ones preserved as much as possible. M2G is an upgraded
version of [Mig2Grids.pm, Sept.2012] for new functionalities/definitions
and execution from browser.

M2G assumes you're initially starting from a 'typical' Webobs base setup:

 1)a configuration directory (the one usually pointed to by /etc/webobs symbolic link)
 defined with the $confpath variable in M2G: 
   - WEBOBS.conf file
   - RESEAUX.conf file
   - any reseaux*.conf files (typically)

 2)a data directory (for NODES configurations), defined with the $datapath variable in M2G:
   - your-path-to-webobs-site-data/DATA/STATIONS 

=head1 M2G COMMANDS

=head2 dryrun

       toggle dry-run between ON and OFF  

=head2 REAPER

       clean up a previous MIGRATE0 run generated files (except FORMS) 

=head2 MIGRATE0

M2G.0  : the initial migration procedure

    - from reseaux to GRIDS (PROCS, VIEWS, FORMS)
    - from STATIONS to NODES

=head2 MIGRATE_1_FORMSCONF

M2G.1F : (1=follow M2G.0) further adapt FORMS parameters

    - changes in each /etc/webobs/FORMS/FORMNAME/FORMNAME.conf
    - remove name of form that prefix each variables defined in this *.conf
    - eg. for FORMS/EAUX, EAUX.conf has variables "EAUX_something" : change to "something"
    - & standardize CGIs variables names (ie. CGI_AFFICHAGE_* ==> CGI_SHOW)

=head2 MIGRATE_1_NODESXLATE

M2G.1NX: (1=follow M2G.0) 

    - some translations to english + 
    - force escape | (\|) (i.e except first |)  

=head2 MIGRATE_2_NODESFEATURES

M2G.2NF: (2=follow M2G.1--) 

    - move all NODE's non-system *.txt to new FEATURES subdirectory of NODE

=head2 MIGRATE_3_FORMSNET2GRIDS

M2G.3FN: (3=follow M2G.2--) 

    - scan newly created FORMS directories for files with filename like 'reseauxFORMNAME.conf'
    - these are supposed to contain pointers to 'old reseaux' names (ID3, one per line) that 
    - will be changed to corresponding VIEW.VIEWNAME. Such corresponding viewnames are found
    - by scanning the new VIEWS directory for matching 'id3' in their *.conf file. 

=head2 MIGRATE_3_NORMNODES

M2G.3NN: (2=follow M2G.2N-)  NOT IMPLEMENTED YET

    - normalize (ie. change to 'gridtype.gridname.nodename') all nodenames
    - in NODES2NODES.rc and node's .cnf (TRANSMISSION values)
    - IMPORTANT: once this migration is done, you'll want to
    - check/fix all cgis that are using WebObs::Grids::normNode(): they 
    - could be appending now useless (and error prone) '.' to nodenames
    - when calling WebObs::Grids::normNode(); 

=head2 MIGRATE_4_ALIASDASH

M2G.4AD: (4=follow M2G.3--)

    - remove NODEs from PROC when either of their ALIAS or DATA_FILE field is 
    - set up as '-' (dash). PROC field in NODEs' cnf is removed and 
    - any GRIDS2NODES/PROC.*.NODE symbolic link is also deleted

=head2 MIGRATE_5_FID

M2G.5FD: (5=follow M2G.4--)

    - change 'DATA_FILE' key to 'FID' in all NODEs' cnf

=head2 MIGRATE_6_PROCKEYS and MIGRATE_6_VIEWKEYS

M2G.6GK: (6=follow M2G.5--)

    - change resp. rename keys in PROCS and VIEWS *.conf

=head1 OVERVIEW OF CHANGES TO WEBOBS

- $WEBOBS{FILE_MATLAB_CONFIGURATION} is abandonned and replaced with:

  - $WEBOBS{FILE_OWNERS} from 'OBSERVATOIRES' definitions
  - $WEBOBS{FILE_DISCIPLINES} from 'DISCIPLINE' definitions
  - one or two (1 or 2) conf files for each so-called 'network' as its definitions
    require: a 'network' now is a GRID, either 'VIEW' or 'PROC'  
    - /VIEWS hold conf files for 'views' grids ie. 'networks' with 'net' > 0
    - /PROCS hold conf files for 'procedures' grids ie. 'networks' with 'ext' defined
  - new attributes are defined for VIEWS and PROCS: 'own', 'req' and 'frm'
    (cgi-bin-driven "user's input procedures" will now be known as FORMS ('frm') 
    
- STATIONS are now NODES, with corresponding conf files 'revisited' as implied by grids changes:
  - these new conf files are created with a '.cnf' extension to allow 
    coexistence with older version (.conf) during the migration phase
  - new parameters added (eg. pointers to view and proc)
  - parameter names translated to english where required
  - force usage of | as keyword/value delimiter to match the (also) new
    readCfg (read configuration files) standard !

- Populate the $WEBOBS{PATH-GRIDS2NODES} folder of pointers (symbolic LINKS 
  PROC.NAME.NODENAME and VIEW.NAME.NODENAME) to NODE folders. 

=head1 Usage Notes

- M2G DOESN'T USE any WEBOBS.conf configuration file (either old or new). Paths to 
  directories involved in the migratin process are HARD-CODED below ! You may 
  want to override default paths defined. 

- M2G may be run as many times as required assuming legacy directories/definitions
  are still accessible. The following rules apply for destination directories:

  - VIEWS/ , PROCS/ and GRIDS2NODES directories are created by M2G if needed
  - VIEWS/ and PROCS/ contents are overwritten by Mig2Grids if needed, 
    preserving any other contents from other runs of Mig2Grids
  - The contents (symbolic links) of GRIDS2NODES/ directory on entry to Mig2Grids  
    ARE NOT purged by Mig2Grids. 
  - Any existing new stations' *.cnf files ARE NOT purged

- Preceeding rules applying to new directories and files allow for incremental
  creation of new structure. However, full migration might be needed, forcing any 
  previous attempts to create new structure to be cleaned up: this is where you'll 
  want to use the REAPER function, purging all new grids system dir/files that 
  might have been generated so far. 

- Some commands could have been grouped together, or suggested order might have been different.
  However, it has been choosen to strictly follow the order in which they were initially 
  needed, designed and tested. 

=cut

use strict;
use warnings;
use POSIX qw(strftime);
use WebObs::Utils qw(u2l l2u);
use File::Basename;
## use WebObs::Config qw(%WEBOBS readCfg);

our $dry = 1;    # default is dry-run

#our $confpath = "/etc/webobs.d";
#our $datapath = "/etc/webobs.d/DATA";
our $confpath = "/home/lafon/sandbox/wieaux/CONF";
our $datapath = "/home/lafon/sandbox/wieaux";
our $PATH_NODES = "$datapath";

our $PATH_VIEWS = "$confpath/VIEWS";
our $PATH_PROCS = "$confpath/PROCS";
our $PATH_FORMS = "$confpath/FORMS";
our $PATH_GRIDS2NODES = "$confpath/GRIDS2NODES";
our $PATH_GRIDS2FORMS = "$confpath/GRIDS2FORMS";
our $FILE_DISCIPLINES = "$confpath/DISCIPLINES.conf";
our $FILE_OWNERS = "$confpath/OWNERS.conf";
our $FILE_N2N = "$confpath/NODES2NODES.rc";

our $LEG_RESEAUX = "$confpath/RESEAUX.conf";

our @infoGenerales = ("");
our ($graphFile, %G, $g, $t0);
our (@ol, @cl);

# batch if arguments on command line ---------------------------------------
if (@ARGV) {
    my ($op1,$op2) = @ARGV;
    $dry = 1;
    if ($op1 eq 'do') { $op1 = $op2; $dry = 0 }
    my %act = (REAPER => \&REAPER,
        MIGRATE0 => \&MIGRATE0,
        MIGRATE_1_FORMSCONF => \&MIGRATE_1_FORMSCONF,
        MIGRATE_1_NODESXLATE => \&MIGRATE_1_NODESXLATE,
        MIGRATE_2_NODESFEATURES => \&MIGRATE_2_NODESFEATURES,
        MIGRATE_3_FORMSNET2GRIDS => \&MIGRATE_3_FORMSNET2GRIDS,
        MIGRATE_4_ALIASDASH => \&MIGRATE_4_ALIASDASH,
        MIGRATE_5_FID => \&MIGRATE_5_FID,
        MIGRATE_6_PROCKEYS => \&MIGRATE_6_PROCKEYS,
        MIGRATE_6_VIEWKEYS => \&MIGRATE_6_VIEWKEYS);
    if ( defined($act{$op1}) ) {
        print "dry = $dry , command = $op1\n";
        $act{$op1}->();
        warn() if $@;
    }
    exit;
}

# woc interactive, system setups -----------------------------------------------
# log to screen and file
## qx(rm $confpath/mig2grids.stdout); 
my $sep="="x60;
print( strftime("%F %R ",localtime(time())).$sep."\n");
print "The following commands are now available (numerics indicate sequence):\n";
print "  REAPER                  : cleanup previous M2G (step MIGRATE0 ONLY !) generated files if any\n";
print "  MIGRATE0                : initial base migration process: VIEWS,PROCS,FORMS\n";
print "  MIGRATE_1_FORMSCONF     : all [formname].conf files syntax upgrade (keys syntax)\n";
print "  MIGRATE_1_NODESXLATE    : all [node].cnf files syntax upgrade (keys syntax, |'s escape)\n";
print "  MIGRATE_2_NODESFEATURES : all nodes non-system *.txt moved to new FEATURES subdir\n";
print "  MIGRATE_3_FORMSNET2GRIDS: all forms reseaux*.conf have their reseaux changed to grid name(s)\n";
print "  MIGRATE_4_ALIASDASH     : references to PROC(s) from a NODE having either ALIAS or DATA_FILE set to '-' is removed\n";
print "  MIGRATE_5_FID           : all [node].cnf files have their DATA_FILE key changed to FID\n";
print "  MIGRATE_6_PROCKEYS      : all [proc].conf keys rename\n";
print "  MIGRATE_6_VIEWKEYS      : all [view].conf keys rename\n";
print "  dryrun                  : toggle 'dry run' mode ON or OFF\n\n";

print "The following paths are in use:\n";
print "  FROM/TO CONFIG      : $confpath\n";
print "  FROM 'old' reseaux  : $LEG_RESEAUX\n";
print "  TO 'new' VIEWS      : $PATH_VIEWS\n";
print "  TO 'new' PROCS      : $PATH_PROCS\n";
print "  TO 'new' FORMS      : $PATH_FORMS\n";
print "  FROM/TO DATA        : $PATH_NODES\n";

print "now logging to console AND $confpath/M2G.stdout\n\n";
open (STDOUT, "| tee -ai $confpath/M2G.stdout");
print( strftime("\n%F %R ",localtime(time())).$sep."\n");
printf ("dryrun now %s\n",($dry==1)?"ON":"OFF - at your own risk");

# call this to toggle 'dry-run' mode
#
sub dryrun {
    $dry ^= 1;
    print( "\n".strftime("%F %R ",localtime(time())));
    printf ("dryrun now %s\n\n",($dry==1)?"ON":"OFF - at your own risk");
}

# cleanup previous M2G generated files if any.
# This DOES NOT ERASE the FORMS directory and its contents
sub REAPER {
    print( "\n".strftime("%F %R ",localtime(time())));
    print "> M2G::REAPER\n";
    my $cmd="rm -rf ";
    print "purging VIEWS/ PROCS/ GRIDS2*/ ...\n";
    print $dry?"would $cmd $PATH_VIEWS\n":qx($cmd $PATH_VIEWS);
    print $dry?"would $cmd $PATH_PROCS\n":qx($cmd $PATH_PROCS);

    #print qx($cmd $WEBOBS{PATH_FORMS}); #cannot easily be undone
    print $dry?"would $cmd $PATH_GRIDS2NODES\n":qx($cmd $PATH_GRIDS2NODES);
    print $dry?"would $cmd $PATH_GRIDS2FORMS\n":qx($cmd $PATH_GRIDS2FORMS);
    print "purging NODES *.cnf* ...\n";
    print $dry?"would $cmd $PATH_NODES/*/*.cnf\n":qx($cmd $PATH_NODES/*/*.cnf);
    print $dry?"would $cmd $PATH_NODES/*/*.cnf~\n":qx($cmd $PATH_NODES/*/*.cnf~);
    print "Reaper done.\n";
}

# guess what ... 
sub MIGRATE0 {
    print( "\n".strftime("%F %R ",localtime(time())));
    print "> M2G::MIGRATE0\n";
    $t0 = time;
    my (@liste, $i);
    $graphFile = $LEG_RESEAUX;
    printf("%+6d M2G.0 from %s\n", time-$t0, $graphFile);

    open(FILE, "<$graphFile") or die "open $graphFile failed: $!\n";
    while(<FILE>) { push(@infoGenerales,$_); }
    close(FILE);

    chomp(@infoGenerales);
    @infoGenerales = grep(!/^#/, @infoGenerales);
    @infoGenerales = grep(!/^$/, @infoGenerales);

    print $dry?"would mkdir -p $PATH_VIEWS\n":qx(mkdir -p $PATH_VIEWS);
    print $dry?"would mkdir -p $PATH_PROCS\n":qx(mkdir -p $PATH_PROCS);
    print $dry?"would mkdir -p $PATH_FORMS\n":qx(mkdir -p $PATH_FORMS);
    print $dry?"would mkdir -p $PATH_GRIDS2NODES\n":qx(mkdir -p $PATH_GRIDS2NODES);
    print $dry?"would mkdir -p $PATH_GRIDS2FORMS\n":qx(mkdir -p $PATH_GRIDS2FORMS);

    # "DISCIPLINE" --> DISCIPLINES.conf
    #
    printf("%+6d DISCIPLINES -> %s\n", time-$t0, $FILE_DISCIPLINES);
    my @listeMrkD = getTag("DISCIPLINE","mrk");
    my @listeCodesD = getTag("DISCIPLINE","cod");
    my @listeKeyD = getTag("DISCIPLINE","key");
    my @listeOrdD = getTag("DISCIPLINE","ord");
    my @listeNomsD = getTag("DISCIPLINE","nom");

    if (!$dry) {
        open(WRT, ">$FILE_DISCIPLINES");
        printf(WRT "%s\n","=key|ord|keyword|name|marker");
        printf(WRT "# M2G.0 from %s on %s\n\n",$graphFile,strftime("%Y-%m-%d %H:%M:%S %z",localtime));
        $i = 0;
        for (@listeCodesD) {
            printf(WRT "%s|%s|%s|%s|%s\n",$listeCodesD[$i],$listeOrdD[$i],$listeKeyD[$i],$listeNomsD[$i],$listeMrkD[$i]);
            $i += 1;
        }
        close(WRT);
    } else { print "would build $FILE_DISCIPLINES with codes @listeCodesD\n" };

    # "OBSERVATOIRE" --> OWNERS.conf
    #
    printf("%+6d OBSERVATOIRES -> %s\n", time-$t0, $FILE_OWNERS);
    my @listeCodesO = getTag("OBSERVATOIRE","cod");
    my @listeNomsO = getTag("OBSERVATOIRE","nom");

    if (!$dry) {
        open(WRT, ">$FILE_OWNERS");
        printf(WRT "%s\n","=key|value");
        printf(WRT "# M2G.0 from %s on %s\n\n",$graphFile,strftime("%Y-%m-%d %H:%M:%S %z",localtime));
        $i = 0;
        for (@listeCodesO) {
            printf(WRT "%s|%s\n",$listeCodesO[$i],$listeNomsO[$i]);
            $i += 1;
        }
        close(WRT);
    } else { print "would build $FILE_OWNERS with codes @listeCodesO\n" };

# For the migration process, each FORM is identified by an existing 
# "reseaux<Formname>.conf" file (eg. reseauxGaz.conf) that points to ID3 'networks'.
# Create a subdirectory FORMNAME for each FORM, in $WEBOBS{PATH_FORMS} and 
# a FORMNAME.conf file in it, built from the legacy WEBOBS.conf statements related to 
# this FORM.
# Then hash (%F) all the ID3 => FORMname relationships, to be later used in VIEWS and 
# PROCS definitions of their 'frm' attribute 
#
    my %F;
    my @formsconfs = qx(ls $confpath/reseaux*.conf);
    for my $f (@formsconfs) {
        chomp($f);

# following $ucf assignment only under perl 5.14 ('r' modifier = non-destructive)
#my $ucf = uc($f =~ s!$confpath/reseaux(.*).conf!$1!gr);
        my $ucf = uc($f);
        $ucf =~ s!$confpath/reseaux(.*).conf!$1!gi;

        # ID3 => FORM hash
        open(RDR, "<$f") or die "open $f failed: $!\n";
        while(<RDR>) {
            chomp;
            if (! /^#/) { $F{$_} = $ucf; }
        }
        close(RDR);

        # FORMNAME directory
        printf("%+6d creating %s\n", time-$t0, "$PATH_FORMS/$ucf");
        if ($dry) {print "would mkdir -p $PATH_FORMS/$ucf\n"} else { qx(mkdir -p $PATH_FORMS/$ucf) };

        # build the FORMNAME.conf from WEBOBS.conf related statements
        my $pgrep = " \"^$ucf"."_|_"."$ucf\" $confpath/WEBOBS.conf >$PATH_FORMS/$ucf/$ucf.conf";
        qx(grep -P $pgrep);

       # move the FORM associated files to the brand new FORM/FORMNAME directory
        $pgrep = " \"^$ucf"."_FILE_.*\\\|.*.conf\" $confpath/WEBOBS.conf";
        my @l = qx(grep -P $pgrep);
        for (@l) {
            chomp;
            s/(^.*\|)//g;
            if ($dry) {print "would mv $confpath/$_ $PATH_FORMS/$ucf/\n"} else { qx(mv $confpath/$_ $PATH_FORMS/$ucf/) };
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
        if (defined($G{$g}{ext}) and length($G{$g}{ext}) > 2) {
            my $r;
            if ($dry) {print "would mkdir -p $PATH_PROCS/$g\n"} else { qx(mkdir -p $PATH_PROCS/$g) };
            my $path = "$PATH_PROCS/$g/$g.conf";
            printf("%+6d created %s \n", time-$t0, $path);
            my @out;
            no warnings "uninitialized";
            push(@out,"=key|value\n");
            push(@out,"# M2G.0 from $graphFile on ".strftime("%Y-%m-%d %H:%M:%S %z",localtime)."\n\n");
            push(@out,"nom|$G{$g}{nom}\n");
            push(@out,"net|$G{$g}{net}\n");
            push(@out,"ftp|$G{$g}{ftp}\n");
            push(@out,"utc|$G{$g}{utc}\n");
            push(@out,"ext|$G{$g}{ext}\n");
            push(@out,"dec|$G{$g}{dec}\n");
            push(@out,"cum|$G{$g}{cum}\n");
            push(@out,"fmt|$G{$g}{fmt}\n");
            push(@out,"mks|$G{$g}{mks}\n");
            push(@out,"ico|$G{$g}{ico}\n");
            $r = index($G{$g}{ext},'xxx')!=-1 ? 1 : 0; push(@out,"req|$r\n");
            push(@out,"cro|TBD\n");
            push(@out,"lnk|$G{$g}{lnk}\n");
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
                                if ($dry) { print "would ln -s $PATH_FORMS/$F{$k} $PATH_GRIDS2FORMS/PROC.$g.$F{$k}\n"} else { qx(ln -s $PATH_FORMS/$F{$k} $PATH_GRIDS2FORMS/PROC.$g.$F{$k}) };
                            }
                        }
                        migID3Stations('PROC', $g, $o.$c, 'UTC_DATA|'.$G{$g}{utc});
                    }
                }
            }
            if ($legacyID3 ne "") { push(@out,"id3|$legacyID3\n");}
            if ($formslist ne "") { push(@out,"frm|$formslist\n");}
            if ($dislist ne "")   { push(@out,"dis|$dislist\n");}
            if (!$dry) {
                open(WRT, ">$path");
                print WRT @out ;
                close(WRT);
            }
        }
        #
        # VIEWS: legacy-network $g ==> VIEWS/$g if it has a non-zero 'net'
        #
        if (defined($G{$g}{net}) and $G{$g}{net} != 0) {
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
            push(@out,"nom|$G{$g}{nom}\n");
            push(@out,"net|$G{$g}{net}\n");
            push(@out,"own|$G{$g}{obs}\n");
            push(@out,"snm|$G{$g}{snm}\n");
            push(@out,"ssz|$G{$g}{ssz}\n");
            push(@out,"rvb|$G{$g}{rvb}\n");
            push(@out,"map|$G{$g}{map}\n");
            push(@out,"htm|$G{$g}{htm}\n");
            push(@out,"web|$G{$g}{web}\n");
            push(@out,"typ|$G{$g}{typ}\n");
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
  #    if ($o.$c eq $k) { 
  #        $formslist .= $F{$k}." "; 
  #        qx(ln -s $WEBOBS{PATH_FORMS}/$F{$k} $WEBOBS{PATH_GP2FORMS}/VIEW.$g.$F{$k});
  #    }
  #}
                        migID3Stations('VIEW', $g, $o.$c, 'ACQ_RATE|'.$G{$g}{acq}, 'LAST_DELAY|'.$G{$g}{lst});
                    }
                }
            }
            my $r = index($G{$g}{ext},'xxx')!=-1 ? 1 : 0; push(@out,"req|$r\n");
            if ($legacyID3 ne "") { push(@out,"id3|$legacyID3\n");}
            if ($formslist ne "") { push(@out,"frm|$formslist\n");}
            if ($dislist ne "")   { push(@out,"dis|$dislist\n");}
            if (!$dry) {
                open(WRT, ">$path");
                print WRT @out ;
                close(WRT);
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
        if ($?) { print "Couldn't create $n/FEATURES; $!" ; next }
        my @files = qx(find $n -maxdepth 1 -not -name 'info.txt*' -not -name 'installation.txt*' -not -name 'type.txt*' -not -name 'acces.txt*' -name '*.txt*');
        die "Couldn't find txt's; $!" if ($?);
        chomp(@files);
        for my $f (@files) {
            if ($dry) { print "would mv $f $n/FEATURES/\n" } else { qx(mv "$f" "$n/FEATURES/");}
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
        my $formname = basename($_);
        if ($dry) { print "would  sed -ie 's/FILE_RESEAUX|/FILE_PROCS|/' $_/".basename($_).".conf\n" }
        else { qx(sed -ie 's/FILE_RESEAUX|/FILE_PROCS|/' $_/$formname.conf) }
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

sub MIGRATE_6_PROCKEYS {
    print( "\n".strftime("%F %R ",localtime(time())));
    print "> M2G::MIGRATE_6_PROCKEYS\n";
    $t0 = time;
    my $i = 0;
    my @files = <$PATH_PROCS/*/*.conf>;
    for (@files) {
        open RDR, "<$_" or die "Couldn't open in '$_': $!";
        my @f = <RDR>;
        close RDR;
        my $ixd=0; $ixd++ until($f[$ixd] =~ /^cro/); splice(@f, $ixd, 1);
        for (@f) {
            s/^cum\|/CUMULATELIST\|/;
            s/^dec\|/DECIMATELIST\|/;
            s/^dis\|/DOMAIN|/;
            s/^ext\|/TIMESCALELIST|/;
            s/^fmt\|/DATESTRLIST\|/;
            s/^frm\|/FORM\|/;
            s/^ftp\|/RAWDATA\|/;
            s/^ico\|/THUMBNAIL\|/;
            s/^lnk\|/URL\|/;
            s/^mks\|/MARKERSIZELIST\|/;
            s/^nom\|/NAME\|/;
            s/^req\|/REQUEST\|/;
            s/^utc\|/TZ\|/;
            s/^STA\|/NODESLIST\|/;
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

sub MIGRATE_6_VIEWKEYS {
    print( "\n".strftime("%F %R ",localtime(time())));
    print "> M2G::MIGRATE_6_VIEWKEYS\n";
    $t0 = time;
    my $i = 0;
    my @files = <$PATH_VIEWS/*/*.conf>;
    for (@files) {
        open RDR, "<$_" or die "Couldn't open in '$_': $!";
        my @f = <RDR>;
        close RDR;
        for (@f) {
            s/^dis\|/DOMAIN|/;
            s/^htm\|/URL|/;
            s/^map\|/MAPLIST\|/;
            s/^nom\|/NAME\|/;
            s/^own\|/OWNCODE\|/;
            s/^req\|/REQUEST\|/;
            s/^rvb\|/NODERGB\|/;
            s/^snm\|/NODENAME\|/;
            s/^ssz\|/NODESIZE\|/;
            s/^typ\|/TYPE\|/;
            s/^web\|/DISPLAY\|/;
            s/^STA\|/NODESLIST\|/;
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
    opendir(DIR, $PATH_NODES) or die "couldn't opendir $PATH_NODES : $!";
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

