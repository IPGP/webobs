#!/usr/bin/perl -w

=head1 NAME

postGRID.pl

=head1 SYNOPSIS

http://..../postGRID.pl?grid=gridtype.gridname,text=<inline-text-to-be-saved>

=head1 DESCRIPTION

This script is called as an ajax action as a target of 'post' form action from
formGRID.pl to complete the edition (ie. save) of the grid-configuration file.

It should return a text/plain content shown to the user in a dialog box.

=head1 Query string parameters

grid=<gridtype.gridname>
 where gridtype either VIEW or PROC.

text=
 inline text to be saved under file= filename

ts0=
 if present, interpreted as being the grid's configuration 'last-modified timestamp' at the time
 the user entered the modification form (formGRID). If the current 'last-modified timestamp'
 is more recent than ts0, abort current update !

domain=
 specifies the DOMAINs (list).

form=
 specifies the FORM (for PROC only).

delete=
 if present and =1, deletes the GRID.

SELs=
 associated NODES list.

=cut

use strict;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
use File::Basename qw(dirname);
use File::Copy qw(copy);
use File::Path qw(rmtree);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff
#
use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');


# ---- local functions
#

# Return information when OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
}

# Return information when not OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

# Print a DB error message to STDERR and show it to the user
sub htmlMsgDBError {
	my ($dbh, $errmsg) = @_;
	print STDERR $errmsg.": ".$dbh->errstr;
	htmlMsgNotOK($errmsg);
}

# Open an SQLite connection to the domains database
sub connectDbDomains {
	return DBI->connect("dbi:SQLite:$WEBOBS{SQL_DOMAINS}", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) || die "Error connecting to $WEBOBS{SQL_DOMAINS}: $DBI::errstr";
}

# Delete any existing GRIDS to NODES symbolic links and creates the required links
sub update_grid2nodes_links {
	my $GRIDType = shift;
	my $GRIDName = shift;
	my $SELs_ref = shift;
	unlink(glob("$WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.*"));
	for my $nodeid (@$SELs_ref) {
		symlink("$NODES{PATH_NODES}/$nodeid",
				"$WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.$nodeid")
	}
}

# Deletes any existing GRIDS to FORMS symbolic links and creates the required link
sub update_grid2forms_links {
	my $GRIDType = shift;
	my $GRIDName = shift;
	my $form = shift;
	if ($GRIDType eq "PROC") {
		unlink(glob("$WEBOBS{PATH_GRIDS2FORMS}/$GRIDType.$GRIDName.*"));
		if ($form ne "") {
			symlink("$WEBOBS{PATH_FORMS}/$form",
					"$WEBOBS{PATH_GRIDS2FORMS}/$GRIDType.$GRIDName.$form");
		}
	}
}

# Update the domains in database
# Note: seems better to delete+insert than update (in case of corrupted DB)
sub update_grid2domains {
	my $GRIDType = shift;
	my $GRIDName = shift;
	my $domains_ref = shift;

   my $dbh = connectDbDomains();
   my ($q, $rows);
   $q = "delete from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = ? and NAME = ?";
   $rows = $dbh->do($q, undef, $GRIDType, $GRIDName);
   if (!$rows) {
	     htmlMsgDBError($dbh, "postGRID: unable to delete grid"
						." $GRIDType.$GRIDName for update into domains");
   exit;
   }
   $q = "insert into $WEBOBS{SQL_TABLE_GRIDS} VALUES(?, ?, ?)";
	for my $domain (@$domains_ref) {
      $rows = $dbh->do($q, undef, $GRIDType, $GRIDName, $domain);
      if (!$rows || $rows == 0) {
	        htmlMsgDBError($dbh, "postGRID: unable to insert grid"
					  ." $GRIDType.$GRIDName into domain $domain");
	      exit;
      }
   }
   $dbh->disconnect();
}


# ---- what are we here for ?
#
set_message(\&webobs_cgi_msg);
my @tod = localtime();

my $GRIDFullName = checkParam($cgi->param('grid'),
			qr{^(VIEW|PROC)(\.|/)|[a-zA-Z0-9]+$}, "grid") // '';
my ($GRIDType, $GRIDName) = split(/[\.\/]/, trim($GRIDFullName));
my $text = scalar($cgi->param('text')) // '';  # used only in print FILE $text;
my @domain = checkParam([$cgi->multi_param('domain')], qr/^[a-zA-Z0-9_-]*$/,
         "domain");
my $form = checkParam($cgi->param('form'), qr/^[a-zA-Z0-9_-]*$/, "form") // '';
my $TS0 = checkParam($cgi->param('ts0'), qr/^[0-9]*$/, "TS0") // 0;
my $delete = checkParam($cgi->param('delete'), qr/^\d?$/, "delete") // 0;
my @SELs = checkParam([$cgi->multi_param('SELs')],
			qr/^[0-9A-Za-z_-]+$/, "SELs");

my $gridConfFile;
if (uc($GRIDType) eq 'VIEW') {
	$gridConfFile = "$WEBOBS{PATH_VIEWS}/$GRIDName/$GRIDName.conf";
}
if (uc($GRIDType) eq 'PROC') {
	$gridConfFile = "$WEBOBS{PATH_PROCS}/$GRIDName/$GRIDName.conf";
}
my $griddir = dirname($gridConfFile);

if (! -e $gridConfFile) {
	# --- Grid creation (config file does not exist)

	if (!-d $griddir and !mkdir($griddir)) {
		htmlMsgNotOK("postGRID: error while creating directory $griddir: $!");
		exit;
	}
	if ( open(FILE,">$gridConfFile") ) {
		print FILE u2l($text);
		close(FILE);
	} else {
		htmlMsgNotOK("postGRID: error creating $gridConfFile: $!");
		exit;
	}
	update_grid2domains($GRIDType, $GRIDName, \@domain);
	update_grid2nodes_links($GRIDType, $GRIDName, \@SELs);
	update_grid2forms_links($GRIDType, $GRIDName, $form);

	htmlMsgOK("postGRID: $GRIDFullName created.");
	exit;
}


# --- Grid delete or update (config file already exists)

# Additional integrity check: abort if file has changed
# (well actually, if its last-modified timestamp has changed!)
# since the client opened it to enter his(her) modification(s)
if ($TS0 != (stat("$gridConfFile"))[9]) {
	htmlMsgNotOK("$gridConfFile has been modified while you were editing ! Please retry later...");
	exit;
}


if ($delete == 1) {
	# --- Delete the grid !

	# delete the dir/file first
	my $dir = dirname($gridConfFile);
	my $rmtree_errors;
	rmtree($dir, {'safe' => 1, 'error' => \$rmtree_errors});
	if ($rmtree_errors  && @$rmtree_errors) {
		htmlMsgNotOK("postGRID couldn't delete directory $dir");
		print STDERR "postGRID.pl: unable to delete directory $dir: "
			.join(", ", @$rmtree_errors)."\n";
		exit;
	}
	# NOTE: this removes the grid from tables,
	# but not in the nodes association conf files...
	unlink(glob("$WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.*"));
	my $dbh = connectDbDomains();
	my $q = "delete from $WEBOBS{SQL_TABLE_GRIDS}"
			." where TYPE = ? and NAME = ?";
	my $rows = $dbh->do($q, undef, $GRIDType, $GRIDName);
	if (!$rows || $rows == 0) {
		htmlMsgDBError($dbh, "postGRID: unable to delete grid"
						  ." $GRIDType.$GRIDName into domains");
		exit;
	}
	$dbh->disconnect();
	htmlMsgOK("$GRIDFullName deleted");
	exit;
}


# --- Update the grid

# Use an exclusive lock on the config file during the process
if (!sysopen(FILE, "$gridConfFile", O_RDWR | O_CREAT)) {
	# Unable to open the configuration file
	htmlMsgNotOK("postGRID: error opening $gridConfFile: $!");
	exit;
}
unless(flock(FILE, LOCK_EX|LOCK_NB)) {
	warn "postGRID: waiting for lock on $gridConfFile...";
	flock(FILE, LOCK_EX);
}

# Backup the configuration file (To Be Removed: lifecycle too short)
if (copy($gridConfFile, "$gridConfFile~") != 1) {
	# Unable to backup of the configuration file
	close(FILE);
	htmlMsgNotOK("postGRID: couldn't backup $gridConfFile");
	exit;
}

# Write the updated configuration to the configuration file
truncate(FILE, 0);
seek(FILE, 0, SEEK_SET);
print FILE u2l($text);
close(FILE);

# Update domains and links to nodes and forms
update_grid2domains($GRIDType, $GRIDName, \@domain);
update_grid2nodes_links($GRIDType, $GRIDName, \@SELs);
update_grid2forms_links($GRIDType, $GRIDName, $form);

htmlMsgOK("postGRID: $GRIDFullName updated");



=pod

=head1 AUTHOR(S)

François Beauducel, Didier Lafon, Xavier Béguin

=head1 COPYRIGHT

Webobs - 2012-2020 - Institut de Physique du Globe Paris

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
