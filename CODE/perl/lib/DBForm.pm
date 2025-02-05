package WebObs::DBForm;

=head1 SYNOPSIS

DBForm Perl object: interface to a WebObs 'Form' SQLite DataBase  

	use WebObs::DBForm;
	$F = new WebObs::DBForm('yourFormName');

	CONF/FORMS/yourFormName/yourFormName.conf   -->  DATA/DB/yourFormName.db
	                       /yourFormName.ddl

=head1 DEVELOPPER NOTES 

- update table = delete + insert

- ts1 and ts2 pseudo-timestamps are nullable; ie. [YYYY[-MM[-DD[ HH[:MM[:SS]]]]]]

- Q: the 1-to-1 IDS-DATA relationship: easier for data definition/documentation, but not necesarily required for performances 

- Q: DB connection is alive from object creation time to object destruction time; compare with a connect/disconnect for each request ?

- Q: define the additional configuration files (functional definitions, constants, etc ...) as DB tables ?

- TBD: please re-assess sql-injection and lock level

- TBD: mod. cols: 1) return columns  (_icols & _dcols) ; 2) return exact cols of select (suppress hidden and data.id !)
3) reorder select : id,ts1,ts2,node,**data**,comment,upd-stuff ; 4) longnames/shornames : $F->cols vs $F->{cols}

=head1 USING DBForm OBJECT

	## Path to DBFORMSdirectory/thisform
	print $F->{path};        # eg: /webobs/site/path/to/dbforms/DBF     

	## full name of DBFORM's database file
	print $F->{dbname};      # eg: /webobs/site/DATA/DB/DBF.db

	## access the DBFORM's DataBase Handle (presumably to issue your own sql queries?)
	$F->{dbh}

	## any parameter from DBFORM's conf file
	print $F->conf(BANG);    # eg: 2000

	## last DBFORM's sql-related method call error
	print $F->{errstr}

	## the sql select where clause (no leading 'and')
	$F->{where} = " ids.node = 'MYNODE' ";       # select for MYNODE only
	$F->{where} = " ids.ts1 like '2014-07%' or ids.ts1 is null "; # only Jul 2014 or unknown date1   
	$F->{where} = " ids.id = 25 ";               # select unique row 25 ($F->select(25) would do the same)         
	# the default {where} is : " ids.hidden = 'N' " (check, may change over releases)

	## the sql select order by clause 
	$F->{order} = " order by ids.node,data.val1 ASC ";   
	# the default {order} is : " ORDER BY ids.ts1 ASC" (check, may change over releases)

	## read and process all rows
	$F->select;
	if (! $self->{errstr}) {
		while ( my $row = $F->fetch ) { 
			print Dumper $row;
		}
	}

	## processing a single row $row returned by 'fetch' method
	## $row is a reference to a hash of columnName => value
	## null sql values are Perl's undef
	if ($row->{columnName}) {  do sthg, $row->{columnName} is the value }
	else { do your own defaulting/processing for such undef value}

	## returns array of column names that have been used in select
	print $F->cols;         # eg: (id,ts1,.....,val1,val2,val3)

	## insert a row from an Html QueryString parameters hash 
	## the QueryString hash reference is your CGI's  $cgi->Vars
	## also returns a scalar = the inserted row id on success 
	$QS = $cgi->Vars;
	$i = $F->insert($QP);
	if ($F->{errstr)) { your own error processing, $F->{errstr} containing the error string }

	## delete the row ID=10
	$F->delete(10);

	## get array of CHECK constraints in DATA table
	print map { "$_\n" } $F->datachecks;
	# eg: val2 > 10
	#     val3 between 0.0 and 1.0

	## get list of all procs pointing to this FORM, along with their 'long' name
	%P = $F->procs
	print $P{SOURCES};                 #eg: 'Analyse Sources Thermales'
	map { print "$_ ... " } keys(%P);  #eg: 'TRACAGE2010 ... SOURCES ...' 

	## get all NODEs (and its ALIAS,NAME and FID) of a PROC pointing to this FORM 
	%N = $F->nodes(SOURCES); 
	map {print "$_ ... "} keys(%N);    #eg: GCSGAL1 ... GCSTAR1 ... GCSACQ0 ...  
	print $N{GCSGAL1}{ALIAS};          #eg: 'GA'

	## dump the DBFORM object
	print $F->dump; 

=head1 DBFORM CONFIGURATION

A DBFORM is defined by its configuration file: $WEBOBS{PATH_FORMS}/DBFORMName/DBFORMName.conf  

	=key|value
	BANG|2000
	DBNAME|DBF.db
	TITLE|DB-based Form Model  
	FILE_CSV_PREFIX|DBF

=head1 DBFORM DB SCHEMA

A DBFORM DataBase ( $WEBOBS{PATH_DATA_DB}/DBNAME ) has the following basic structure:

	Required TABLE 'ids'
	* note: ts1, ts2 not timestamps because of required nullable components
	------------------
	id       INTEGER PRIMARY KEY AUTOINCREMENT,
	ts1      TEXT,
	ts2      TEXT,
	node     TEXT NOT NULL,
	comment  TEXT,
	hidden   TEXT DEFAULT 'N',
	tsupd    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	userupd  TEXT NOT NULL DEFAULT '!'

    Required TABLE 'data' example
	* note: data fields may not be all known at once, so define them then as 'nullable'
	---------------------------
	id       INTEGER REFERENCES ids(id) ON DELETE CASCADE ON UPDATE CASCADE
	val1     TEXT
	val2     INTEGER CHECK(val2 > 10)
	val3     REAL CHECK(val3 BETWEEN 0.0 AND 1.0)

=cut

use strict;
use warnings;
use DBI;
use WebObs::Config;
use WebObs::Grids;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

# DBFORM constructor
sub new {
    my ( $class, $Name ) = @_;
    my $self  = {};

    # name : Form name
    die "Missing form name" if !defined($Name);
    $self->{name} = $Name;

    # path : path to configs dir
    $self->{path}  = "$WEBOBS{PATH_FORMS}/$Name";

    # conf : full path to this config
    die "No configuration found for $Name" if (! -e $self->{path}."/$Name.conf");
    $self->{conf}  = { readCfg($self->{path}."/$Name.conf") };

    # dbname : database name - create if needed and ddl is available
    $self->{dbname}  = "$WEBOBS{PATH_DATA_DB}/".$self->{conf}{DBNAME};
    if (! -e $self->{dbname}) {
        die "No database and no ddl to create it for $Name" if (! -e $self->{path}."/$Name.ddl");
        xddl($self->{dbname}, $self->{path}."/$Name.ddl");
    }

    # _procs : PROCS referencing this form
    opendir(DIR, "$WEBOBS{PATH_GRIDS2FORMS}");
    my @Ps = grep { s/\.$Name$//g && s/^PROC\.//g } readdir(DIR) ;
    for my $proc ( @Ps ) {
        my %P = readProc($proc);
        $self->{_procs}{$proc} = $P{$proc}{NAME} ;
    }
    closedir(DIR);

    # dbh  : DB Handle from connect to DB
    my %dbattr = ( RaiseError => 0, PrintError => 0 );
    $self->{dbh} = DBI->connect("dbi:SQLite:$self->{dbname}","","",\%dbattr)
      or die "couldn't connect to $self->{dbname}: $DBI::errstr\n";
    $self->{dbh}->do("pragma foreign_keys = ON");

    # _icols , _dcols : resp. hash of IDS and DATA columns' info
    $self->{_icols} = $self->{dbh}->selectall_hashref("pragma table_info(ids)","cid") ;
    $self->{_dcols} = $self->{dbh}->selectall_hashref("pragma table_info(data)","cid");

    # the sql 'where' clause used by select method (without leading "and")
    $self->{where} = " ids.hidden = 'N' ";

    # the sql 'order by' clause used by select method
    $self->{order} = " ORDER BY ids.ts1 ASC";

    bless $self, $class;
    return $self;
}

# system's resource mngt might use DESTROY: make sure we disconnect from DB  
sub DESTROY {
    my $self = shift;
    $self->{sth}->finish   if ($self->{sth});
    $self->{dbh}->disconnect if $self->{dbh};
}

# get the configuration parameter named $k
sub conf {
    my ($self, $k) = @_;
    return $self->{conf}{$k} if (defined($k));
}

# select all rows or row matching the optional $id (ie. column 'id') argument
# following a call to 'select', the 'fetch' method is used to retrieve 
# results one row at a time. 
sub select {
    my ($self, $id) = @_;
    undef($self->{errstr}) if ($self->{errstr});
    undef($self->{cols}) if ($self->{cols});
    $self->{sth}->finish if ($self->{sth});
    my $where = ($self->{where} && $self->{where} ne "") ? " and $self->{where} " : "";
    $where .= (defined($id)) ? " AND ids.id = $id " : "";

    $self->{cols}  = join(',', map { "ids.$self->{_icols}{$_}{name}"  } sort keys($self->{_icols})) . ","  ;
    $self->{cols} .= join(",", map { "data.$self->{_dcols}{$_}{name}"  } grep { $self->{_dcols}{$_}{name} !~ /ID/ } sort keys($self->{_dcols}));

    my $stmt  =  "SELECT $self->{cols} FROM ids, data WHERE ids.id = data.id $where $self->{order}";

    if ($self->{sth} = $self->{dbh}->prepare($stmt)) {
        if (! $self->{sth}->execute) { $self->{errstr} = "failed to execute: $DBI::errstr"; }
    } else { $self->{errstr} = "failed to prepare: $DBI::errstr"; }
    return;
}

# fetch next single row of a previously 'select' result set
# returns a reference to a hash of column => value
sub fetch {
    my $self = shift;
    undef($self->{errstr}) if ($self->{errstr});
    return $self->{sth}->fetchrow_hashref if ($self->{sth});
}

# returns array of column-names used in last select
sub cols {
    my ($self, $k) = @_;
    return grep { s/^.*\.// } split(/,/,$self->{cols}) if ($self->{cols});
}

# insert : insert row from a CGI query-parameters reference $QP ($QP = $cgi->Vars)
# returns ID of new row if successfull, -1 otherwise with {errstr} 
sub insert {
    my ($self, $QP) = @_;
    undef($self->{errstr}) if ($self->{errstr});
    $self->{sth}->finish if ($self->{sth});
    my $value = my $id = '';
    my $cIDS = my $cDATA = my $vIDS = my $vDATA = my $val = "";

# scanning all defined columns, build the cols and values lists of the insert statement : 
# only the columns found in QueryString (ie: colname=val); quote values when needed;  
    for (sort keys($self->{_icols})) {
        next if ($_ == 0); # ignore 1st col that must be ID
        $val = $QP->{$self->{_icols}{$_}{name}} || undef ;
        next if ( !defined($val) );
        $cIDS .= "$self->{_icols}{$_}{name},";
        if ( uc($self->{_icols}{$_}{type}) eq 'TEXT' || uc($self->{_icols}{$_}{type}) eq 'TIMESTAMP' ) {
            $vIDS .= "'".$val."'," ;
        } else { $vIDS .= $val."," }
    }
    $cIDS =~ s/,$//; $vIDS =~ s/,$//; # remove extra trailing comma
    for (sort keys($self->{_dcols})) {
        next if ($_ == 0); # ignore 1st col that must be ID
        $val = $QP->{$self->{_dcols}{$_}{name}} || undef ;
        next if ( !defined($val) );
        $cDATA .= "$self->{_dcols}{$_}{name},";
        if ( uc($self->{_dcols}{$_}{type}) eq 'TEXT' || uc($self->{_dcols}{$_}{type}) eq 'TIMESTAMP' ) {
            $vDATA .= "'".$val."'," ;
        } else { $vDATA .= $val."," }
    }
    $cDATA =~ s/,$//; $vDATA =~ s/,$//; # remove extra trailing comma

    # inserts transaction  
    my $i1 = "INSERT INTO ids($cIDS) VALUES($vIDS)";
    $self->{dbh}->begin_work();
    eval {
        local $self->{dbh}->{RaiseError} = 1;
        $self->{dbh}->do($i1);
        $id = $self->{dbh}->last_insert_id(undef, undef, qw(ids id));
        my $i2 = "INSERT INTO data(id,$cDATA) VALUES($id,$vDATA)\n";
        $self->{dbh}->do($i2);
        $self->{dbh}->commit();
      };
    if ($@) {
        $self->{errstr} = "insert aborted: $@";
        $id = -1;
        eval { $self->{dbh}->rollback };
    }
    return $id;
}

# get an array of all CHECKS constraints in table DATA
sub datachecks {
    my $self = shift;
    my $row = $self->{dbh}->selectrow_array("SELECT sql FROM sqlite_master WHERE type='table' and name='data' ;");
    return ($row =~ m/check.*\((.*)\)/g);
}

# delete data : delete row matching $id (ie. column 'id')
# delete ID from both 'ids' and 'data' table (using on cascade)
sub delete {
    my ($self, $id) = @_;
    undef($self->{errstr}) if ($self->{errstr});
    $self->{sth}->finish if ($self->{sth});
    if (defined($id)) {
        $self->{dbh}->do("DELETE FROM ids WHERE id=$id");
        $self->{errstr} = $self->{dbh}->errstr() if ($self->{dbh}->err());
    }
    return;
}

# get PROC(s) of this FORM as a hash of their 'long' name (NAME)
sub procs {
    my ($self) = @_;
    return %{$self->{_procs}} if ($self->{_procs});
}

# get valid nodes of a PROC of this FORM, returned as a hash of their NAME, ALIAS and FID 
sub nodes {
    my ($self, $proc) = @_;
    undef($self->{errstr}) if ($self->{errstr});
    if (defined($proc)) {
        if (! $proc ~~ [ map "$_", keys(%{$self->{_procs}})] ) {
            my %L = listGridNodes(grid=>"PROC.$proc", valid=>1);
            return %L;
        } else {
            $self->{errstr} = "$proc not in ".$self->{name}."\n" ;
        }
    } else {
        $self->{errstr} = "no proc requested\n" if (!defined($proc));
    }
}

# get a dump of this DBFORM as a string
# usage: print $F->dump
sub dump {
    my ($self) = @_;
    my $dmp = '';
    $dmp .= sprintf( "Name: %s\n", $self->{name} );
    $dmp .= sprintf( "Configuration: %s\n", $self->{path} );
    map { $dmp .= sprintf "  $_ => $self->{conf}{$_}\n" } keys %{ $self->{conf}};
    $dmp .= sprintf( "Database: %s\n", $self->{dbname} );
    $dmp .= sprintf( "  specific columns: %s\n", join(', ', map { $self->{_dcols}{$_}{name}."($self->{_dcols}{$_}{type})" } sort keys($self->{_dcols})) );
    $dmp .= sprintf( "  number of rows: %s\n", $self->{dbh}->selectrow_array( "SELECT COUNT(*) FROM ids") );
    $dmp .= "Related PROC(s): ";
    for ( keys(%{$self->{_procs}}) ) {
        $dmp .= sprintf("  %s(%s) ", $_, $self->{_procs}{$_});
    }
    $dmp .= "\n";
    return $dmp;
}

# execute a DDL file $ddl for DataBase $db
# ** not requiring db connection **
sub xddl {
    my ($db, $ddl) = @_;
    my @qrs = qx(sqlite3 $db < $ddl);
}

1;

__END__

=pod

=head1 AUTHOR

Didier Lafon

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
				
