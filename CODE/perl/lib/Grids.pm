package WebObs::Grids;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

 use WebObs::Grids;

** see functions descriptions below **

=head1 THE GRIDS SYSTEM

=head2 GRIDS

=head2 PROCS

=head2 VIEWS

=head2 FORMS

=head2 NODES

=cut

use strict;
use warnings;
use File::Basename;
use WebObs::Utils qw(trim isok);
use WebObs::Config qw(%WEBOBS readCfg readCfgFile readFile u2l l2u);
use WebObs::Users qw(clientHasRead);
use POSIX qw(strftime);

#our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, %OWNRS, %DOMAINS, %DISCP, %GRIDS, %NODES);
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, %OWNRS, %DOMAINS, %GRIDS, %NODES, %node2node);
require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(%OWNRS %DOMAINS %NODES %GRIDS %node2node readDomain readGrid readSefran readProc readForm readView readNode listNodeGrids listGridNodes parentEvents getNodeString normNode readCLB);
$VERSION    = "1.00";

%DOMAINS = readDomain();

if (-e $WEBOBS{FILE_OWNERS}) {
    %OWNRS = readCfg($WEBOBS{FILE_OWNERS});
}

#FB-was: if (-e $WEBOBS{FILE_DISCIPLINES}) { %DISCP = readCfg($WEBOBS{FILE_DISCIPLINES}); }

if (-e $WEBOBS{CONF_NODES}) {
    %NODES = readCfg($WEBOBS{CONF_NODES});
}

if (-e $WEBOBS{CONF_GRIDS}) {
    %GRIDS = readCfg($WEBOBS{CONF_GRIDS});
}

# %node2node: hash key = 'parentnode|feature', hash value = 'childnode' or 'childnode1|childnode2|...'
if (-e $NODES{FILE_NODES2NODES}) {
    my @file_node2node = readCfgFile("$NODES{FILE_NODES2NODES}");
    for (@file_node2node) {
        if ($_ =~ /.+\|.+\|.+/) {
            my ($parent_node,$feature,$children_node) = split(/\|/,$_);
            my $key_link = $parent_node."|".$feature;
            $node2node{$key_link} .= (exists($node2node{$key_link}) ? "|":"").$children_node;
        }
    }
}

=pod

=head1 FUNCTIONS

=head2 readDomain

Reads all 'domains' configurations into a HoH.

    %D = readDomain;     # reads all DOMAINS
    $n = $D{S}{NAME}     # value of 'NAME' field of domain S
    $o = $D{S}{OOA};     # value of 'OOA' (Order of Appearence) field of domain S

=cut

sub readDomain {
    my %ret;
    my @dom = qx(sqlite3 $WEBOBS{SQL_DOMAINS}  "select CODE,OOA,NAME from $WEBOBS{SQL_TABLE_DOMAINS} order by OOA");
    chomp(@dom);
    for (@dom) {
        my @tmp = split(/\|/,$_);
        $ret{$tmp[0]}{OOA} = $tmp[1];
        $ret{$tmp[0]}{NAME} = $tmp[2];
    }
    return %ret;
}

=pod

=head2 readProc

Reads one or more 'procs' configurations into a HoH.
Adds uppercase NODESLIST hash key to point to the list of linked-to NODES for a PROC.
Adds DOMAIN code from grids2domains db
Adds FORM code if proc is linked to any form

    %N = readProc("^S");           # all PROCS whose names start in S
    $x = $N{SISMOHYP}{NAME}        # value of 'NAME' field of SISMOHYP proc
    $d = $N{SISMOHYP}{DOMAIN}      # value of 'DOMAIN' field of SISMOHYP proc
    @s = $N{CGPSWI}{NODESLIST}     # list of linked-to nodes for CGPSWI proc
    @f = $N{SOURCES}{FORM}         # optional linked-to form for SOURCES proc

Internally uses WebObs::listProcNames.

=cut

sub readProc {
    my %ret;
    for my $f (listProcNames($_[0])) {
        my %tmp = readCfg("$WEBOBS{PATH_PROCS}/$f/$f.conf",@_[1..$#_]);

        # --- get list of associated NODES
        opendir(DIR, "$WEBOBS{PATH_GRIDS2NODES}");
        my @lSn = grep {/^PROC\.($f)\./ && -l $WEBOBS{PATH_GRIDS2NODES}."/".$_} readdir(DIR);
        foreach (@lSn) {s/^PROC\.($f)\.//g};
        @lSn =  sort {$a cmp $b} @lSn ;
        $tmp{'NODESLIST'} = \@lSn;
        closedir(DIR);

        # --- get list of associated FORMS
        opendir(DIR, "$WEBOBS{PATH_GRIDS2FORMS}");
        my @lSf = grep {/^PROC\.($f)\./ && -l $WEBOBS{PATH_GRIDS2FORMS}."/".$_} readdir(DIR);
        foreach (@lSf) {s/^PROC\.($f)\.//g};
        $tmp{'FORM'} = $lSf[0];    #NOTE: keeps only the first FORM
        closedir(DIR);

        # --- get DOMAIN
        my @qx = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "select DCODE from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = 'PROC' and NAME = '$f'");
        chomp(@qx);
        $tmp{'DOMAIN'} = join('|',@qx);
        $ret{$f}=\%tmp;
    }
    return %ret;
}

=pod

=head2 readForm

Reads one or more 'forms' configurations into a HoH.
Adds uppercase NODESLIST hash key to point to the list of linked-to NODES for a FORM.
Adds DOMAIN code from grids2domains db

    %N = readForm("^S");           # all FORMS whose names start in S
    $x = $N{SOURCES}{NAME}        # value of 'NAME' field of SOURCES form
    $d = $N{SOURCES}{DOMAIN}      # value of 'DOMAIN' field of SISMOHYP form
    @s = $N{EXTENSO}{NODESLIST}     # list of linked-to nodes for EXTENSO form

Internally uses WebObs::listFormNames.

=cut

sub readForm {
    my %ret;
    for my $f (listFormNames($_[0])) {
        my %tmp = readCfg("$WEBOBS{PATH_FORMS}/$f/$f.conf",@_[1..$#_]);

        # --- get list of associated NODES
        opendir(DIR, "$WEBOBS{PATH_GRIDS2NODES}");
        my @lSn = grep {/^FORM\.($f)\./ && -l $WEBOBS{PATH_GRIDS2NODES}."/".$_} readdir(DIR);
        foreach (@lSn) {s/^FORM\.($f)\.//g};
        @lSn =  sort {$a cmp $b} @lSn ;
        $tmp{'NODESLIST'} = \@lSn;
        closedir(DIR);

        # --- get DOMAIN
        my @qx = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "select DCODE from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = 'FORM' and NAME = '$f'");
        chomp(@qx);
        $tmp{'DOMAIN'} = join('|',@qx);
        $ret{$f}=\%tmp;
    }
    return %ret;
}

=pod

=head2 readSefran

Reads one or more 'sefrans' configurations into a HoH.
Adds DOMAIN code from grids2domains db
Adds CHANNELLIST from CHANNEL_CONF file

    %N = readSefran("^S");         # all Sefrans whose names start with a S
    $x = $N{SEFRAN3}{NAME}         # value of 'NAME' field of SEFRAN3 sefran
    $d = $N{GEOSCOPE}{DOMAIN}      # value of 'DOMAIN' field of GEOSCOPE sefran

Internally uses WebObs::listSefranNames.

=cut

sub readSefran {
    my %ret;
    for my $f (listSefranNames($_[0])) {
        my %tmp = readCfg("$WEBOBS{PATH_SEFRANS}/$f/$f.conf");
        $tmp{NAME} ||= $tmp{TITRE};

        # --- get channels list
        my @ch = readCfgFile(exists($tmp{CHANNEL_CONF}) ? "$tmp{CHANNEL_CONF}":"$WEBOBS{PATH_SEFRANS}/$f/channels.conf");
        my @st;
        for (@ch) {
            my ($ali,$cod) = split(/\s+/,$_);
            push(@st,$ali);
        }
        $tmp{'CHANNELLIST'} = join('|',@st);

        # --- get DOMAIN
        my @qx = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "select DCODE from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = 'SEFRAN' and NAME = '$f'");
        chomp(@qx);
        $tmp{'DOMAIN'} = join('|',@qx);
        $ret{$f}=\%tmp;
    }
    return %ret;
}

=pod

=head2 readView

Reads one or more 'views' configurations into a HoH.
Adds uppercase NODESLIST hash key to point to the list of linked-to NODES for a VIEW
Adds DOMAIN code from grids2domains db

See readProc for similar usage examples

Internally uses WebObs::listViewNames.

=cut

sub readView {
    my %ret;
    for my $f (listViewNames($_[0])) {
        my %tmp = readCfg("$WEBOBS{PATH_VIEWS}/$f/$f.conf");
        opendir(DIR, "$WEBOBS{PATH_GRIDS2NODES}");
        my @l = grep {/^VIEW\.($f)\./ && -l $WEBOBS{PATH_GRIDS2NODES}."/".$_} readdir(DIR);
        foreach (@l) {s/^VIEW\.($f)\.//g};
        @l =  sort {$a cmp $b} @l ;
        $tmp{'NODESLIST'} = \@l;
        closedir(DIR);
        my @qx = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "select DCODE from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = 'VIEW' and NAME = '$f'");
        chomp(@qx);
        $tmp{'DOMAIN'} = $qx[0];
        $ret{$f}=\%tmp;
    }
    return %ret;
}

=pod

=head2 readGrid

Reads one single 'grid' configuration into a hash. Argument must be GridType.GridName.
Adds uppercase NODESLIST hash key to point to the list of linked-to NODES for a GRID
Adds DOMAIN code from grids2domains db

=cut

sub readGrid {
    my %ret;
    my %tmp;
    my $f = $_[0];
    my ($gt,$gn) = split(/\./,$f);
    my $z = "PATH_${gt}S";
    %tmp = readCfg("$WEBOBS{$z}/$gn/$gn.conf");
    opendir(DIR, "$WEBOBS{PATH_GRIDS2NODES}");
    my @l = grep {/^$f\./ && -l $WEBOBS{PATH_GRIDS2NODES}."/".$_} readdir(DIR);
    foreach (@l) {s/^$f\.//g};
    @l =  sort {$a cmp $b} @l ;
    $tmp{'NODESLIST'} = \@l;
    closedir(DIR);
    my @qx = qx(sqlite3 $WEBOBS{SQL_DOMAINS} "select DCODE from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = '$gt' and NAME = '$gn'");
    chomp(@qx);
    $tmp{'DOMAIN'} = $qx[0];
    $ret{$f}=\%tmp;
    return %ret;

}

=pod

=head2 readNode

Reads one or more 'nodes' configurations into a HoH. Option "nowovsub" will
avoid WEBOBS.rc variable substitution.

Internally uses WebObs::listNodeNames.

=cut

sub readNode {
    my %ret;
    for my $f (listNodeNames($_[0])) {
        my %tmp = readCfg("$NODES{PATH_NODES}/$f/$f.cnf","escape",@_[1..$#_]);

        #FB-legacy: if TYPE not defined and old type.txt exists, loads it
        if (!$tmp{TYPE}) {
            my $typ = "$NODES{PATH_NODES}/$f/type.txt";
            if ((-e $typ) && (-s $typ != 0)) {
                $tmp{TYPE} = trim(join("",readFile($typ)));
            }
        }
        $tmp{PROJECT} = 1 if (-s "$NODES{PATH_NODES}/$f/$NODES{SPATH_INTERVENTIONS}/${f}_Projet.txt");

        #substitutes possible decimal comma to point for numerics
        $tmp{LAT_WGS84} =~ s/,/./g;
        $tmp{LON_WGS84} =~ s/,/./g;

        #FB-legacy: removes escape characters in feature's list
        $tmp{FILES_FEATURES} =~ s/\\,/,/g;
        $tmp{FILES_FEATURES} =~ s/\\\|/,/g;

        # removes trailing blanks in each features
        $tmp{FILES_FEATURES} = join(",",map {trim($_)} split(/[,\|]/,$tmp{FILES_FEATURES}));

        $ret{$f}=\%tmp;
    }
    return %ret;
}

=pod

=head2 listViewNames

Returns a list of names of 'VIEWS' defined in $WEBOBS{PATH_VIEWS}.

Input is optional, as it defaults to 'all views'. If it is specified,
it will be used as a regexp to select view names.

  @L = listViewNames("^GPS");  # all views named GPS*

=cut

sub listViewNames {

    #$_[0] will be used as a regexp
    my $filter = defined($_[0]) ? $_[0] : "^[^\.]";
    opendir(DIR, $WEBOBS{PATH_VIEWS}) or die "can't opendir $WEBOBS{PATH_VIEWS}: $!";
    my @list = grep {/($filter)/ && -d $WEBOBS{PATH_VIEWS}."/".$_} readdir(DIR);
    closedir(DIR);
    my @finallist;
    for (@list) {
        push(@finallist, $_) if (WebObs::Users::clientHasRead(name=>$_,type=>'authviews'));
    }
    return @finallist;
}

=pod

=head2 listProcNames

Returns a list of names of 'PROCS' defined in $WEBOBS{PATH_PROCS}.

Input is optional, as it defaults to 'all procs'. If it is specified,
it will be used as a regexp to select proc names.

  @L = listProcNames("^SISMO");  # all procs named SISMO*

=cut

sub listProcNames {

    #$_[0] will be used as a regexp
    my $filter = defined($_[0]) ? $_[0] : "^[^\.]";
    opendir(DIR, $WEBOBS{PATH_PROCS}) or die "can't opendir $WEBOBS{PATH_PROCS}: $!";
    my @list = grep {/($filter)/ && -d $WEBOBS{PATH_PROCS}."/".$_} readdir(DIR);
    closedir(DIR);
    my @finallist;
    for (@list) {
        push(@finallist, $_) if (WebObs::Users::clientHasRead(name=>$_,type=>'authprocs'));
    }
    return @finallist;
}

=pod

=head2 listFormNames

Returns a list of names of 'FORMS' defined in $WEBOBS{PATH_FORMS}.

Input is optional, as it defaults to 'all forms'. If it is specified,
it will be used as a regexp to select form names.

  @L = listFormNames("^WATERS");  # all forms named WATERS*

=cut

sub listFormNames {

    #$_[0] will be used as a regexp
    my $filter = defined($_[0]) ? $_[0] : "^[^\.]";
    opendir(DIR, $WEBOBS{PATH_FORMS}) or die "can't opendir $WEBOBS{PATH_FORMS}: $!";
    my @list = grep {/($filter)/ && -d $WEBOBS{PATH_FORMS}."/".$_} readdir(DIR);
    closedir(DIR);
    my @finallist;
    for (@list) {
        push(@finallist, $_) if (WebObs::Users::clientHasRead(name=>$_,type=>'authforms'));
    }
    return @finallist;
}

=pod

=head2 listSefranNames

Returns a list of names of 'SEFRAN3' found in $WEBOBS{ROOT_CONF}.

Input is optional, as it defaults to 'all sefrans'. If it is specified,
it will be used as a regexp to select proc names.

  @L = listSefranNames("^SEFRAN3_");  # all sefrans named SEFRAN3_*

=cut

sub listSefranNames {

    #$_[0] will be used as a regexp
    my $filter = defined($_[0]) ? $_[0] : "^[^\.]";
    opendir(DIR, $WEBOBS{PATH_SEFRANS}) or die "can't opendir $WEBOBS{PATH_SEFRANS}: $!";
    my @list = grep {/($filter)/ && -d $WEBOBS{PATH_SEFRANS}."/".$_} readdir(DIR);
    closedir(DIR);
    my @finallist;
    for (@list) {
        my $mc = qx(grep -E "^MC3_NAME\\|" $WEBOBS{PATH_SEFRANS}/$_/$_.conf);
        chomp($mc);
        $mc =~ s/^MC3_NAME\|//g;
        push(@finallist, $_) if (WebObs::Users::clientHasRead(name=>$mc,type=>'authprocs'));
    }
    return @finallist;
}

=pod

=head2 listNodeNames

Returns a list of names of 'NODES' defined in $NODES{PATH_NODES}.

Input is optional, as it defaults to 'all nodes'. If it is specified,
it will be used as a regexp to select node names.

  @L = listNodeNames("^GSB");  # all nodes like GSB*

=cut

sub listNodeNames {

    #$_[0] will be used as a regexp
    my $filter = defined($_[0]) ? $_[0] : "^[^\.]";
    opendir(DIR, $NODES{PATH_NODES}) or die "can't opendir $NODES{PATH_NODES}: $!";
    my @list = grep {/($filter)/ && -d $NODES{PATH_NODES}."/".$_} readdir(DIR);
    closedir(DIR);
    return @list;
}

=pod

=head2 listNodeGrids

 %HoA = listNodeGrids(node=>'nodename' [, type=>{'VIEW'|'PROC|FORM'}]

Returns a hash of list of grids (of type type) a node belongs to.

node will default to all known nodes in $NODES{PATH_NODES}. If
specified, will be used as a regexp to select node(s).

type, if not specified, will default to ALL grid types (ie. VIEW and PROC).


 %HoA = listNodeGrids(node=>'GSAT');
 print join('+',keys(%HoA));    # maybe "GSATDB1+GSATHM0+GSATHM1"
 print scalar(@{$HoA{GSATDB1}}) # maybe 2 ie. number of grids for GSATDB1
 print "@{$HoA{GSATDB1}}";      # maybe "PROC.name1 VIEW.name2"


=cut

sub listNodeGrids {
    my %KWARGS = @_;
    my $filterT = $KWARGS{type} && $KWARGS{type} =~ /^VIEW|PROC|FORM$/ ? $KWARGS{type} : '';
    my $filterS = $KWARGS{node} ? $KWARGS{node} : undef;

    my @s = listNodeNames($filterS);
    my $g = "$WEBOBS{PATH_GRIDS2NODES}/";
    my %rs;
    foreach (@s) {
        my @l = grep(s{$g/}{}g, <$g/$filterT*$_>);
        $rs{$_}=[grep(s{\.[^.]*$}{}, @l)];
    }
    return %rs;
}

=pod

=head2 listNameGrids

 %H = listNameGrids

returns a hash of grid names:

 print $H{VIEW.GPSWI};      # maybe "GPS Network West-Indies"
 print $H{PROC.SOURCES};    # maybe "Hot Springs Water Analysis"

=cut

sub listNameGrids {
    my %rs;
    my $n;
    my %tmp;
    my @V = listViewNames;
    foreach (@V) {
        $n = "VIEW.$_";
        %tmp = readCfg("$WEBOBS{PATH_VIEWS}/$_/$_.conf");
        $rs{$n} = $tmp{'NAME'};
    }
    my @P = listProcNames;
    foreach (@P) {
        $n = "PROC.$_";
        %tmp = readCfg("$WEBOBS{PATH_PROCS}/$_/$_.conf");
        $rs{$n} = $tmp{'NAME'};
    }
    return %rs;
}

=pod

=head2 listGridNodes

 %H  = listGridNodes( grid=>'[gridtype.]gridname' [,valid=>1] [,active=>{today|isodate|isodateStart:isodateEnd}] )

Returns a hash of hashes of ALIAS, NAME and FID of all or valid-only nodes for a grid.
Optionaly limit this list to nodes that are 'active' on a given date.
Grid may be specified either as 'gridtype.gridname' or 'gridname'.

Note1: valid nodes are those with their $node{VALID}=1.

Note2: an active node on date D is a node for which D falls between $node{INSTALL_DATE} and $node{END_DATE}.
'active' date may also be specidfied as a range 'isodateStart:isodateEnd' (: acts as delimiter); the node
is then considered 'active' if one of isodateStart and isodateEnd (or both) fall(s) between $node{INSTALL_DATE} and $node{END_DATE}.

 # all nodes ids for PROC.BOJAP grid:
 %H = listGridNodes(grid=>'PROC.BOJAP');
 print keys(%H);

 # show full names of all valid nodes of PROC.BOJAP that are active today
 %H = listGridNodes(grid=>'PROC.BOJAP', valid=>1, active=>today);
 for (keys(%H)) { print "$_ : $H{$_}{NAME}\n" }
 # dump previous %H (2 nodes matching criteria)
 p Dumper \%H;
 $VAR1 = {
           'GSBACQ0' => {
                         'NAME' => '"Acq sismique Très Large Bande"',
                         'FID' => 'HOU',
                         'ALIAS' => 'GUAD'
                        },
           'GSBDHS0' => {
                         'NAME' => '"Morne Mazeau, Deshaies"',
                         'FID' => 'DHS',
                         'ALIAS' => 'DHS'
                        }
         };

=cut

sub listGridNodes {
    use Time::Piece;
    my %KWARGS = @_;
    my $grid  = $KWARGS{grid} ? $KWARGS{grid} : undef;
    my $valid = $KWARGS{valid} ? $KWARGS{valid} : undef;
    my $acton = $KWARGS{active} ? $KWARGS{active} : undef;
    my $today = my $deb = my $fin = '';
    if (defined($acton))  {
        $today = strftime( '%Y-%m-%d', localtime );
        ($deb,$fin) = split(/:/,$acton);
        if (!$fin) {$fin = $deb}
        $deb =~ s/today/$today/;
        $fin =~ s/today/$today/;
        eval { $deb = Time::Piece->strptime($deb,"%Y-%m-%d") }; if ($@) { $deb = Time::Piece->strptime("","%Y-%m-%d") }

# FIX: 2038 for Perl 32-bits dates; WAS: eval { $fin = Time::Piece->strptime($fin,"%Y-%m-%d") }; if ($@) { $fin = Time::Piece->strptime("9999","%Y-%m-%d") }
        eval { $fin = Time::Piece->strptime($fin,"%Y-%m-%d") }; if ($@) { $fin = Time::Piece->strptime("2038","%Y-%m-%d") }
    }
    my %vlist;
    if (defined($grid)) {
        $grid = ($grid =~ /\./) ? $grid : "*.$grid";
        my @list = qx (ls -L $WEBOBS{PATH_GRIDS2NODES}/$grid.*/*.cnf 2>/dev/null);
        chomp(@list);
        for my $n (@list) {
            my $tINS = my $tEND = '';
            my %tmp = readCfg("$n");
            next if ( defined($valid) && $valid ne $tmp{VALID} ) ;
            if ( defined($acton) ) {

#  Time::Piece->strptime(<date>, "%Y-%m-%d") accepts either %Y, %Y-%m or %Y-%m-%d (fills with '01' as necessary)
                eval { $tINS = Time::Piece->strptime($tmp{INSTALL_DATE}, "%Y-%m-%d") } ; if ($@) { $tINS = Time::Piece->strptime("","%Y-%m-%d") }

# FIX: 2038 for Perl 32-bits dates; WAS: eval { $tEND = Time::Piece->strptime($tmp{END_DATE}, "%Y-%m-%d") }     ; if ($@) { $tEND = Time::Piece->strptime("9999","%Y-%m-%d") }
                eval { $tEND = Time::Piece->strptime($tmp{END_DATE}, "%Y-%m-%d") }     ; if ($@) { $tEND = Time::Piece->strptime("2038","%Y-%m-%d") }
                next if ( ($deb < $tINS) && ($fin < $tINS) );
                next if ( ($deb > $tEND) && ($fin > $tEND) );
            }
            $vlist{ basename($n,'.cnf') } = { ALIAS => $tmp{ALIAS} , NAME => $tmp{NAME}, FID => $tmp{FID} };
        }
    }
    return %vlist;
}

=pod

=head2 normNode

 $normNode = normNode( node=>'[gridtype].[gridname].nodename' );

Returns a 'normalized' NODE name (ie. fully qualified as "gridtype.gridname.nodename")
from an 'incomplete' NODE name, with gridtype VIEW preferred. normNode() can also
be seen/used as a 'default' grid selector for an unqualified nodename.

Returns null ("") if no normalized node is found.
 !!When more than one normalized node name exist, the first one from their reverse alphabetical
list is returned, thus making any valid VIEW come first.

Input node is an 'incomplete' node-name (ie. missing a valid grid identifier) where a
dot ('.') is a required placeholder for each missing grid qualifier (either gridtype or gridname).

normNode may be used as a nodename validity (ie. well-formed AND existing) checker.

=cut

sub normNode {
    my %KWARGS = @_;
    my $node = $KWARGS{node} ? $KWARGS{node} : '';
    my $ret = "";
    if ($node) {
        $node =~ s/\./*./g;
        my @l = qx(ls -dr $WEBOBS{PATH_GRIDS2NODES}/$node 2>/dev/null);
        chomp(@l);
        if (scalar(@l) > 0) {$ret = basename($l[0])}
    }
    return $ret;
}

=pod

=head2 getNodeString

 $text = getNodeString(node=>'nodename' [,style={'alias'|'short'|'html'}] [,link={'node'|'features'}] );

Returns a string identifying NODE 'node', formatted in one of the predefined styles
available: 'alias', 'short' or 'html', with link to: 'node' or 'features'.

'style' outputs: ('html' is the default style when none is specified)

 alias    : ALIAS
 short    : ALIAS: NAME
 html     : <b>ALIAS</b>: NAME <i>TYPE</i>

'link' outputs:

 node     : <a href="...">NODE</a>
 features : <a href="...">NODE</a> +featureA +featureB +featureC

Does NOT use WebObs::Grids::readNode() to save unecessary/expensive directory scans
and type.txt file-reads ...

=cut

sub getNodeString
{
    my %KWARGS = @_;
    my $node  = $KWARGS{node} ? $KWARGS{node} : '';
    my $style = $KWARGS{style} && $KWARGS{style} =~ /^alias|^short|^html/ ? $KWARGS{style} : 'html';
    my $link =  $KWARGS{link} && $KWARGS{link} =~ /^node|^features/ ? $KWARGS{link} : '';

    my $text = "";
    my $sub = "";
    if ($node ne "" && -f "$NODES{PATH_NODES}/$node/$node.cnf") {
        my %N = readCfg("$NODES{PATH_NODES}/$node/$node.cnf");
        if (isok($N{VALID})) {
            my $nnode = normNode(node=>"..$node");
            no warnings "uninitialized";
            if ($style eq 'alias')    { $text = $N{ALIAS} }
            if ($style eq 'short')    { $text = "$N{ALIAS}: $N{NAME}" }
            if ($style eq 'html')     { $text = "<b>$N{ALIAS}</b>: $N{NAME}".($N{TYPE} ne "" && $N{TYPE} ne "-" ? " <i>($N{TYPE})</i>":"") }
            if ($link eq 'node')      { $text = ($nnode ne "" ? "<A href=\"$NODES{CGI_SHOW}?node=$nnode\">$text</A>":"<SPAN title=\"orphan node $node\">$text</SPAN>"); }
            if ($link eq 'features') {
                $text = ($nnode ne "" ? "<A href=\"$NODES{CGI_SHOW}?node=$nnode\">$text</A> ":"<SPAN title=\"orphan node $node\">$text</SPAN>");
                if ($N{FILES_FEATURES} ne "") {
                    $text = "<img src=\"/icons/drawersmall.png\" onClick=\"toggledrawer('\#ID_$node')\">&nbsp;".$text."\n"
                      ."<div id=\"ID_$node\"><table class=\"fof\">";
                    for my $feature (split(/,/,$N{FILES_FEATURES})) {
                        my $f = "$NODES{PATH_NODES}/$node/$NODES{SPATH_FEATURES}/$feature.txt";
                        my $htm;
                        if (exists $node2node{"$node|$feature"}) {
                            for (split(/\|/,$node2node{"$node|$feature"})) {
                                $htm .= getNodeString(node=>$_, link=>'node')."<br>" if ($_ ne "");
                            }
                        }
                        if (-f $f) {
                            my @feat = readFile($f);
                            $htm .= WebObs::Wiki::wiki2html(join("",@feat));
                            $htm =~ s/<br><br>/<br>/ig;
                        }
                        $sub .= "<tr><th class=\"fof\"><b>$feature</b></td><td class=\"fof\">".$htm."</td></tr>" if ($htm ne "");
                    }
                    $text .= $sub."</table></div>";
                }
            }
            use warnings;
        }
    }
    return $text;
}

=pod

=head2 parentEvents

 $pevents = parentEvents($eventFileName);

Knowing that events are represented by their subpath/file names,
returns an html-tagged string representing the list of parent events
to which $eventFileName belongs. Returns "" if no such list.

=cut

sub parentEvents ($)
{
    my $eventFile = shift;
    my $parent = "";
    my @subParent = split(/\//,$eventFile);
    if ($#subParent > 0) {
        $parent = join("/",@subParent[0..($#subParent-1)]);
    } else {
        return "";
    }

    my $station = substr($eventFile,0,7);
    my $txt = "";
    my @x = split(/\//,$parent);
    for (my $i=$#x;$i>=0;$i--) {
        my $f = "$NODES{PATH_NODES}/$station/$NODES{SPATH_INTERVENTIONS}/".join("/",@x[0..$i]).".txt";
        my ($s,$d,$h) = split(/_/,$x[$i]);
        $h =~ s/-/:/;
        my $t = "???";
        if (-e $f) {
            my @xx = readFile($f);
            chomp(@xx);
            my $o;
            ($o,$t) = split(/\|/,$xx[0]);
        }
        $txt .= " \@ <B>$t</B> ($d".($h ne "NA" ? " $h":"").")";
    }
    return $txt;
}

=pod

=head2 codesFDSN

Returns a hash of FDSN networks codes.

 %H = codesFDSN();
 print $H{AA}      # "Anchorage Strong Motion Network"

This function reads/parses the
CODE/etc/fdsncodes.csv file for networks codes as assigned by the FDSN archive
(IRIS DMC). To update, use:

wget http://www.iris.edu/ds/nodes/dmc/services/network-codes/?type=csv -O CODE/etc/fdsncodes.csv

It appends and possibly overwrites codes from local configuration file CONF/networkcode.csv

=cut

sub codesFDSN {
    my %codes;
    my @FDSN = readFile("$WEBOBS{ROOT_CODE}/etc/fdsncodes.csv",'^[^#].*');
    chomp(@FDSN);

    # process CSV file, result from IRIS web-service
    # Example:
    # AA,'Anchorage Strong Motion Network',
    for (@FDSN) {
        my ($cle,$val) = split(/,/,$_);
        $val =~ s/^'//;
        $val =~ s/'$//;
        $codes{trim($cle)} = $val;
    }

    # overwrites with optional local configuration file
    my @NET = readFile("$NODES{FILE_NETWORKS}",'^[^#].*');
    chomp(@NET);
    for (@NET) {
        my ($cle,$val) = split(/,/,$_);
        $val =~ s/^'//;
        $val =~ s/'$//;
        if (defined $codes{trim($cle)}) {
            $codes{trim($cle)} = "$val !! overwritten FDSN \"$codes{trim($cle)}\" !!";
        } else {
            $codes{trim($cle)} = $val;
        }
    }

    return %codes;
}

=pod
=head2 readCLB
Reads calibration file of a node (fullid) and return an HoH
=cut

sub readCLB {
    my $node = shift;
    my %data;
    my ($GRIDType, $GRIDName, $NODEName) = split(/\./, $node);

    my $file = "$NODES{PATH_NODES}/$NODEName/$GRIDType.$GRIDName.$NODEName.clb"; # standard CLB file name
    my $legclb = "$NODES{PATH_NODES}/$NODEName/$NODEName.clb";
    $file = $legclb if ( ! -e $file && -e $legclb); # for backwards compatibility
    (my $autoclb = $file) =~ s/\.clb/_auto.clb/; # auto-generated CLB
    $file = $autoclb if ( -e $autoclb && ! -s $file );
    if ( -s $file ) {
        %data = readCfg($file);
    }
    return %data;
}

1;

__END__

=pod

=head1 AUTHOR

François Beauducel, Didier Lafon

=head1 COPYRIGHT

WebObs - 2012-2025 - Institut de Physique du Globe Paris

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
