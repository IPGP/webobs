#!/usr/bin/perl -w

=head1 NAME

postNODE.pl

=head1 SYNOPSIS

http://..../postNODE.pl?....see query string list below ....

=head1 DESCRIPTION

Process NODE Update or Create from formNODE submitted info

=head1 Query string parameters

 node=
 the fully qualified NODE name (ie. gridtype.gridname.nodename) to create or update

 delete=
 if present and =1, deletes the NODE.

 acqr=
 ACQ_RATE|  configuration value

 utcd=
 UTC_DATA|  configuration value

 ldly=
 LAST_DELAY|  configuration value

 data=
 FID|  configuration value - string

 rawformat=
 RAWFORMAT|  configuration value - string

 rawdata=
 RAWDATA|  configuration value - string

 chanlist=
 CHANNEL_LIST|  list of selected channels - comma-separated integers

 anneeD=
 INSTALL_DATE|  configuration value - year component

 moisD=
 INSTALL_DATE|  configuration value - month component

 jourD=
 INSTALL_DATE|  configuration value - day component

 anneeE=
 END_DATE|  configuration value - year component

 moisE=
 END_DATE|  configuration value - month component

 jourE=
 END_DATE|  configuration value - day component

 validite=
 VALID|  configuration value - {0 | 1 | "NA"}

 alias=
 ALIAS|  configuration value - string

 type=
 TYPE|  configuration value - string

 fullName=
 NAME|  configuration value - string

 fdsn=
 FDSN_NETWORK_CODE|  configuration value - string

 lat=
 LAT_WGS84|  configuration value

 lon=
 LON_WGS84|  configuration value

 alt=
 ALTITUDE|  configuration value

 anneeP=
 POS_DATE|  configuration - year component

 moisP=
 POS_DATE|  configuration - month component

 jourP=
 POS_DATE|  configuration - day component

 typePos=
 POS_TYPE|  configuration value

 rawKML=
 POS_RAWKML|  configuration value (URL)

 features=
 FILES_FEATURES|  configuration value - string file1[|file2[....|filen]]

 typeTrans=
 TRANSMISSION|  configuration value - string type

 pathTrans=
 TRANSMISSION|  configuration value component - string

 SELs=
 PROC| and VIEW| configuration lists

=cut

use strict;
use File::Basename;
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
use POSIX qw/strftime/;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX = 1024 * 1000;
$CGI::DISABLE_UPLOADS = 1;
my $cgi = new CGI;

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');


# ---- Above all we need a fully-qualified NODE from an authorized client
#
my $delete = $cgi->param('delete') // 0;
my $GRIDName  = my $GRIDType  = my $NODEName = "";
my @lines;
($GRIDType, $GRIDName, $NODEName) = split(/[\.\/]/, trim($cgi->param('node')));
if ( $GRIDType ne "" && $GRIDName ne "" && $NODEName ne "") {
	if ( $delete && !clientHasAdm(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName") ) {
		htmlMsgNotOK("You cannot delete $GRIDType.$GRIDName.$NODEName");
	}
	if ( !clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName") ) {
		htmlMsgNotOK("You cannot edit $GRIDType.$GRIDName.$NODEName");
	}
} else { htmlMsgNotOK ("Invalid NODE (".$cgi->param('node').") posted for create/update/delete")  }

# ---- checking if user is a THEIA user and if he wants to save data in metadatabase
#
my $theiaAuth = $WEBOBS{THEIA_USER_FLAG};
my $saveAuth   = $cgi->param('saveAuth')	// '';

# ---- where are the NODE's directory and NODE's conf file ?
my %allNodeGrids = WebObs::Grids::listNodeGrids(node=>$NODEName);
my $nodepath = "$NODES{PATH_NODES}/$NODEName";
my $nodefile = "$nodepath/$NODEName.cnf";
my $n2nfile = "$NODES{FILE_NODES2NODES}";

# ---- If deleting NODE, do not wait for further information
#
my $producer   = $cgi->param('producer')    // '';	# information needed to delete the NODE's related row in the metadata DB

if ($delete) {
	# NOTE: this removes only the node directory, association to grids and node feature associations
	qx(/bin/mkdir -p $NODES{PATH_NODE_TRASH});
	qx(/bin/rm -rf $NODES{PATH_NODE_TRASH}/$NODEName);
	if (system("/bin/mv $nodepath $NODES{PATH_NODE_TRASH}/") == 0) {
		unlink glob "$WEBOBS{PATH_GRIDS2NODES}/*.*.$NODEName";
		#system("/bin/rm -f $WEBOBS{PATH_GRIDS2NODES}/*.*.$NODEName");
		# reads all but feature children nodes
		@lines = readFile($NODES{FILE_NODES2NODES},qr/^(?!$NODEName\|)/);
		saveN2N(@lines);
		
		if ( isok($theiaAuth) and isok($saveAuth) ) {
			# --- connecting to the database
			my $driver   = "SQLite";
			my $database = $WEBOBS{SQL_METADATA};
			my $dsn 	 = "DBI:$driver:dbname=$database";
			my $userid 	 = "";
			my $password = "";
			my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
		    	or die $DBI::errstr;
			
			my $stmt = qq(delete from datasets WHERE datasets.identifier = "$producer\_DAT_$GRIDName.$NODEName");
			my $sth = $dbh->prepare( $stmt );
			my $rv = $sth->execute() or die $DBI::errstr;

			if($rv < 0) {
			   print $DBI::errstr;
			}
			
			$dbh->disconnect();
		}
	} else {
		htmlMsgNotOK("postNODE couldn't move directory $nodepath to trash... [$!]");
	}
	htmlMsgOK("$GRIDType.$GRIDName.$NODEName\n deleted");
	exit;
}

# ---- What are we supposed to do ?: find it out in the query string
#
my $QryParm    = $cgi->Vars;    # used later; todo: replace cgi->param's below
my $acqr       = $cgi->param('acqr')        // '';
my $utcd       = $cgi->param('utcd')        // '';
my $ldly       = $cgi->param('ldly')        // '';
my $anneeD     = $cgi->param('anneeDepart') // '';
my $moisD      = $cgi->param('moisDepart')  // '';
my $jourD      = $cgi->param('jourDepart')  // '';
my $anneeE     = $cgi->param('anneeEnd')    // '';
my $moisE      = $cgi->param('moisEnd')     // '';
my $jourE      = $cgi->param('jourEnd')     // '';
my $validite   = $cgi->param('valide')      // '';
my $alias      = $cgi->param('alias')       // '';
my $type       = $cgi->param('type')        // '';
my $desc       = $cgi->param('description') // ''; $desc =~ s/\<\<//g;
my $creator    = $cgi->param('creators')    // '';
my $theme      = $cgi->param('theme')       // '';
my @roles	   = $cgi->param('role');
my @firstNames = $cgi->param('firstName');
my @lastNames  = $cgi->param('lastName');
my @emails	   = $cgi->param('email');
my @topics     = $cgi->param('topics');
my $lineage    = $cgi->param('lineage')     // '';
my $tz         = $cgi->param('tz')          // '';
my $data       = $cgi->param('data')        // '';
my $rawformat  = $cgi->param('rawformat')   // '';
my $rawdata    = $cgi->param('rawdata')     // '';
my @chanlist   = $cgi->param('chanlist');
my $name       = $cgi->param('fullName')    // '';
my $fdsn       = $cgi->param('fdsn')        // '';
my $latN       = $cgi->param('latwgs84n')   // '';
my $lat        = $cgi->param('latwgs84')    // '';
my $latmin     = $cgi->param('latwgs84min') // '';
my $latsec     = $cgi->param('latwgs84sec') // '';
my $lonE       = $cgi->param('lonwgs84e')   // '';
my $lon        = $cgi->param('lonwgs84')    // '';
my $lonmin     = $cgi->param('lonwgs84min') // '';
my $lonsec     = $cgi->param('lonwgs84sec') // '';
my $spatialcov = $cgi->param('outWKT')      // '';
my $geojson    = $cgi->param('geojson')     // '';
my $filename   = $cgi->param('filename')    // '';
my $alt        = $cgi->param('altitude')    // '';
my $gnss_9char = $cgi->param('gnss_9char')  // '';
my $m3g_check  = $cgi->param('m3g_check')   // '';
my $anneeP     = $cgi->param('anneeMesure') // '';
my $moisP      = $cgi->param('moisMesure')  // '';
my $jourP      = $cgi->param('jourMesure')  // '';
my $typePos    = $cgi->param('typePos')     // '';
my $rawKML     = $cgi->param('rawKML')      // '';
my $features   = $cgi->param('features')    // '';
$features =~ s/\|/,/g;
my %n2n;
for (split(',',lc($features))) {
	$n2n{$_} = $cgi->param($_) if $cgi->param($_) ne '';
}
my $typeTrans = $cgi->param('typeTrans')   // '';
$typeTrans =~ s/\|/,/g;
my $typeTele  = $cgi->param('pathTrans')   // '';
if ($typeTele ne "") { $typeTrans = "$typeTrans,$typeTele"; }
my @SELs      = $cgi->param('SELs');

# ---- pre-set actions to be run soon under control of
# ---- lock-exclusive on the configuration file.
# ----

# ---- Dates must be ISO: YYYY, YYYY-MM or YYYY-MM-DD, otherwise "NA"
my $dateInstall = "NA";
if ($anneeD ne "") {
	$dateInstall = sprintf ("%s%s%s",$anneeD,($moisD eq "")?"":"-$moisD",($jourD eq "")?"":"-$jourD")
}
my $dateEnd = "NA";
if ($anneeE ne "") {
	$dateEnd = sprintf ("%s%s%s",$anneeE,($moisE eq "")?"":"-$moisE",($jourE eq "")?"":"-$jourE")
}
my $datePos = "NA";
if ($anneeP ne "") {
	$datePos = sprintf ("%s%s%s",$anneeP,($moisP eq "")?"":"-$moisP",($jourP eq "")?"":"-$jourP")
}

# ---- Position lat/lon: adds minutes and seconds
if ($lon ne "" && $lat ne "") {
	$lat = $lat + $latmin/60 + $latsec/3600;
	if ($latN eq "S") { $lat *= -1; }
	$lon = $lon + $lonmin/60 + $lonsec/3600;
	if ($lonE eq "W") { $lon *= -1; }
	# locale might have replaced decimal point by coma...
	$lat =~ s/,/./g;
	$lon =~ s/,/./g;
}

# ---- parsing dataset contacts
my @creators = split('\|', $creator);

# ---- NODE's validity flag
my $valide = "";
if ( $validite eq "NA" ) { $valide = 1; } else { $valide = 0; }
# ---- 2nd checkbox: M3G avaiability flag
my $m3g_avaiable = "";
if ( $m3g_check eq "NA" ) { $m3g_avaiable = 1; } else { $m3g_avaiable = 0; }
# ---- NODES' Feature Files: "system" always present, and "user" defined
my @FFsys = ('acces.txt', 'info.txt', 'installation.txt', 'type.txt', "$NODEName.clb");
my @FFusr = map { "$NODES{SPATH_FEATURES}/".lc($_).'.txt'} split(/\||,/,$features);
my @FFnew = map { $_ if(! -e "$nodepath/$_") } (@FFsys, @FFusr);
# ---- NODE's documents subdirectories
my @docs  = ($NODES{SPATH_INTERVENTIONS}, $NODES{SPATH_PHOTOS}, $NODES{SPATH_DOCUMENTS}, $NODES{SPATH_SCHEMES});
my @Dnew  = map { $_ if(! -e "$nodepath/$_") } (@docs);
# ---- build the NODE's configuration file. There is no 'true update' of this .cnf,
# ---- each time it is rebuilt from scratch (hum...from query-string parameters)
#my @Ps; my @Vs;
push(@lines,"=key|value\n");
push(@lines,"NAME|\"".u2l($name)."\"\n");
push(@lines,"ALIAS|".u2l($alias)."\n");
push(@lines,"TYPE|".u2l($type)."\n");
push(@lines,"DESCRIPTION|".u2l($desc)."\n");
push(@lines,"VALID|$valide\n");
push(@lines,"TZ|$tz\n");
push(@lines,"LAT_WGS84|$lat\n");
push(@lines,"LON_WGS84|$lon\n");
push(@lines,"ALTITUDE|$alt\n");
push(@lines,"GNSS_9CHAR|$gnss_9char\n");
push(@lines,"M3G_AVAIABLE|$m3g_avaiable\n");
push(@lines,"POS_DATE|$datePos\n");
push(@lines,"POS_TYPE|$typePos\n");
push(@lines,"POS_RAWKML|$rawKML\n");
push(@lines,"INSTALL_DATE|$dateInstall\n");
push(@lines,"END_DATE|$dateEnd\n");
push(@lines,"FILES_FEATURES|".u2l(lc(join(",",map {trim($_)} split(/[,\|]/,$features))))."\n");
push(@lines,"TRANSMISSION|".u2l($typeTrans)."\n");

# ---- procs parameters
if ($GRIDType eq "PROC") {
	push(@lines,"$GRIDType.$GRIDName.FID|".u2l($data)."\n");
	grep { $_ =~ /^FID_/ && (push(@lines,"$GRIDType.$GRIDName.$_|$QryParm->{$_}\n")) } (keys(%$QryParm));
	push(@lines,"$GRIDType.$GRIDName.FDSN_NETWORK_CODE|$fdsn\n");
	push(@lines,"$GRIDType.$GRIDName.RAWFORMAT|".u2l($rawformat)."\n");
	push(@lines,"$GRIDType.$GRIDName.RAWDATA|".u2l($rawdata)."\n");
	push(@lines,"$GRIDType.$GRIDName.UTC_DATA|$utcd\n");
	push(@lines,"$GRIDType.$GRIDName.ACQ_RATE|$acqr\n");
	push(@lines,"$GRIDType.$GRIDName.LAST_DELAY|$ldly\n");
	push(@lines,"$GRIDType.$GRIDName.CHANNEL_LIST|".join(',',@chanlist)."\n");
	push(@lines,"$GRIDType.$GRIDName.DESCRIPTION|".u2l($desc)."\n");
}

# ---- other grid's parameters (not linked to the active grid) are transfered "as is"
for (sort grep { $_ =~ /(VIEW|PROC)\..*\./ } keys(%$QryParm)) {
	push(@lines,"$_|$QryParm->{$_}\n");
}

# ---- for migration >> 1.8.1 : former proc parameters are duplicated to all existing associated procs
foreach my $g (@{$allNodeGrids{$NODEName}}) {
	if ($g =~ /^PROC\./ && $g ne "$GRIDType.$GRIDName") {
		push(@lines,"$g.FDSN_NETWORK_CODE|$QryParm->{FDSN_NETWORK_CODE}\n") if !(defined $QryParm->{"$g.FDSN_NETWORK_CODE"});
		push(@lines,"$g.RAWFORMAT|$QryParm->{RAWFORMAT}\n") if !(defined $QryParm->{"$g.RAWFORMAT"});
		push(@lines,"$g.RAWDATA|$QryParm->{RAWDATA}\n") if !(defined $QryParm->{"$g.RAWDATA"});
		push(@lines,"$g.UTC_DATA|$QryParm->{UTC_DATA}\n") if !(defined $QryParm->{"$g.UTC_DATA"});
		push(@lines,"$g.ACQ_RATE|$QryParm->{ACQ_RATE}\n") if !(defined $QryParm->{"$g.ACQ_RATE"});
		push(@lines,"$g.LAST_DELAY|$QryParm->{LAST_DELAY}\n") if !(defined $QryParm->{"$g.LAST_DELAY"});
		push(@lines,"$g.CHANNEL_LIST|$QryParm->{CHANNEL_LIST}\n") if !(defined $QryParm->{"$g.CHANNEL_LIST"});
		push(@lines,"$g.DESCRIPTION|$QryParm->{DESCRIPTION}\n") if !(defined $QryParm->{"$g.DESCRIPTION"});
		push(@lines,"$g.FID|$QryParm->{FID}\n") if !(defined $QryParm->{"$g.FID"});
		grep { $_ =~ /^FID_/ && !(defined $QryParm->{"$g.$_"}) && (push(@lines,"$g.$_|$QryParm->{$_}\n")) } (keys(%$QryParm));
	}
}


# ---- create NODE's directory if required
umask 0002;
if ( ! -e $nodepath) {
	htmlMsgNotOK("couldn't create ($!) $nodepath") if (! mkdir($nodepath, 0775)) ;
}
# ---- lock-exclusive the target file during all update process
#
if ( sysopen(FILE, "$nodefile", O_RDWR | O_CREAT) ) {
	unless (flock(FILE, LOCK_EX|LOCK_NB)) {
		warn "postNODE waiting for lock on $nodefile...";
		flock(FILE, LOCK_EX);
	}
	# ---- backup conf file (To Be Removed: lifecycle too short)
	if ( -e $nodefile ) {
		qx(cp -a $nodefile $nodefile~ 2>&1);
	}
	# ---- create NODE's features subdirectory if required
	if ( ! -e "$nodepath/$NODES{SPATH_FEATURES}") {
		mkdir("$nodepath/$NODES{SPATH_FEATURES}", 0774) ;
	}
	# ---- create empty features files that have been found missing
	for (@FFnew) {
		qx(/bin/touch "$nodepath/$_");
	}
	# ---- create the empty docs subdirectories that have been found missing
	for (@Dnew) {
		 if ($_) { mkdir("$nodepath/$_", 0775) ;}
	}
	# ---- delete any existing GRIDS to NODE symbolic links
	qx(rm -f $WEBOBS{PATH_GRIDS2NODES}/*.*.$NODEName);

	# ---- create GRIDS to NODE symbolic link(s) if required
	for (@SELs) {
		qx(ln -s $nodepath $WEBOBS{PATH_GRIDS2NODES}/$_.$NODEName);
	}
	#djl-was:?: system("/bin/chmod -R a+rwx $racineDir");
	#djl-was:?:system("/bin/chown -R matlab:users $racineDir");
	#
	# ---- actually create the NODE's configuration file and release lock!
	truncate FILE, 0;
	print FILE @lines;
	close(FILE);

	# ---- legacy: if everything ran OK, erase the old type.txt file
	if (-e "$nodepath/type.txt") {
		qx(rm -f $nodepath/type.txt);
	}

} else { htmlMsgNotOK("$nodefile $!") }

# ---- saving geojson from the .shp file
#

my $geojsonfile = "$nodepath/$NODEName.geojson";

if ($geojson ne "") {
	if ( sysopen(FILE, "$geojsonfile", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postNODE waiting for lock on $geojsonfile...";
			flock(FILE, LOCK_EX);
		}
		
		truncate FILE, 0;
		print FILE $geojson;
		close(FILE);
		
	} else { htmlMsgNotOK("$geojsonfile $!") }
}

if ( isok($theiaAuth) and $saveAuth == 1 ) {
	# --- connecting to the database
	my $driver   = "SQLite";
	my $database = $WEBOBS{SQL_METADATA};
	my $dsn 	 = "DBI:$driver:dbname=$database";
	my $userid 	 = "";
	my $password = "";
		
	# --- station informations, coordinates are saved in WKT format
	my $point;
	if ($alt ne "") {
		$point = "wkt:Point(".$lat.",".$lon.",".$alt.")";
	} else {
		$point = "wkt:Point(".$lat.",".$lon.")";
	}
		
	# --- dataset informations
	my $id  = $producer.'_DAT_'.$GRIDName.'.'.$NODEName;
	my $topics = 'topicCategories:'.join(',',@topics);
	my $subject = $topics.'_inspireTheme:'.$theme;
		
	my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
	   or die $DBI::errstr;
		   
	# inserting creators into contacts table
	my @contacts = map { "(\'$emails[$_]\',\'$firstNames[$_]\',\'$lastNames[$_]\',\'$roles[$_]\',\'$id\')" } 0..$#roles;
	my $stmt = qq(select * from contacts where related_id=\"$id\");
	my $sth = $dbh->prepare( $stmt );
	my $rv = $sth->execute() or die $DBI::errstr;

	if($rv < 0) {
	   print $DBI::errstr;
	}
	while(my @row = $sth->fetchrow_array()) {
		my $email = $row[0];
		if ($email !~ @emails) {
			my $stmt2 = "delete from contacts where email=\"$email\" AND related_id=\"$id\"";
			$dbh->do($stmt2);
		}
	}
		
	my $q = "insert or replace into $WEBOBS{SQL_TABLE_CONTACTS} VALUES ".join(',',@contacts);
	$dbh->do($q);

	my $sth = $dbh->prepare('INSERT OR REPLACE INTO sampling_features (IDENTIFIER, NAME, GEOMETRY) VALUES (?,?,?);');
	$sth->execute($alias,$alias,$point);
	
	if ($spatialcov eq "") {
		$sth = $dbh->prepare('INSERT OR REPLACE INTO datasets (IDENTIFIER, TITLE, DESCRIPTION, SUBJECT, LINEAGE) VALUES (?,?,?,?,?);');
		$sth->execute($id,$name,$desc,$subject,$lineage);
	} else {
		$sth = $dbh->prepare('INSERT OR REPLACE INTO datasets (IDENTIFIER, TITLE, DESCRIPTION, SUBJECT, SPATIALCOVERAGE, LINEAGE) VALUES (?,?,?,?,?,?);');
		$sth->execute($id,$name,$desc,$subject,$spatialcov,$lineage);
	}
		
	$dbh->disconnect();
}

# ---- node2node update: only if there is something to do!
#
if (%n2n) {
	# reads all but current node
	@lines = readFile($NODES{FILE_NODES2NODES},qr/^(?!$NODEName\|)/);
	for my $key (keys(%n2n)) {
		for my $n (split(/,/,$n2n{$key})) {
			push(@lines,"$NODEName|$key|$n\n");
		}
	}
	saveN2N(@lines);
}
htmlMsgOK("$GRIDType.$GRIDName.$NODEName created/updated");

# ---- saving NODE informations in sampling_features tables


# ---- node2node edit: lock-exclusive the file during update process
sub saveN2N {
	if ( sysopen(FILE, "$n2nfile", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postNODE waiting for lock on $n2nfile...";
			flock(FILE, LOCK_EX);
		}
		# ---- backup the file (To Be Removed: lifecycle too short)
		if ( -e $n2nfile ) {
			qx(cp -a $n2nfile $n2nfile~ 2>&1);
		}
		# ---- actually create the NODE's configuration file and release lock!
		truncate FILE, 0;
		print FILE @_;
		close(FILE);

	} else { htmlMsgNotOK("$n2nfile $!") }

}
# --- return information when OK and registering metadata in the metadata database
sub htmlMsgOK {
	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" if (isok($WEBOBS{CGI_CONFIRM_SUCCESSFUL}));
	exit;
}

# --- return information when not OK
sub htmlMsgNotOK {
	close(FILE);
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "(create/)update FAILED !\n $_[0] \n";
	exit;
}

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon, Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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
