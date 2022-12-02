package WebObs::Users;
use Carp;
use IPC::Open3;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Users

	$someoneaddr = $USERS{someone}{EMAIL};
	if (clientHasEdit(name=>'HEBDO',type=>'authwikis')) {...}

=head1 DESCRIPTION

Webobs' users management: descriptions (profiles) and resources access rights (authorizations).

WebObs::Users is the interface to the Webobs users profiles defined
in the SQL DataBase $WEBOBS{SQL_DB_USERS}, tables $WEBOBS{SQL_TABLE_USERS},
$WEBOBS{SQL_TABLE_AUTHxxxx} and $WEBOBS{SQL_TABLE_GROUPS}

A 'user' is identified by its 'login' string, as defined in the http authentication file.
A userID (UID) is associated to this login. It is a short (typically user's name initials) identification string,
used as the key to access rights tables and groups table.

The 'client' (global $CLIENT provided by WebObs::Users) is defined
as the currently executing cgi 'user' (as returned by $ENV{REMOTE_USER}):
$CLIENT is the corresponding user's login.

'Special' users are pre-defined to Webobs :
 login 'guest', uid '?' : forced by system when http's remote user not found, OR when http's remote user is not defined to Webobs

A user may also be a member of one or more B<GROUP(S)>. A group is
considered as any other user, except for its userid prefixed with '+',
(eg. +G1) and its additional definition in the $WEBOBS{SQL_TABLE_GROUPS} table.
A user inherits access-rights from the group(s) it belongs to.

Individual user's access rights are given to 'resources' defined/checked by WebObs functionnalities.
A user may be granted Read, Edit (ie. Read+Update) or Admin (ie. Read+Update+Create/Delete) on a given resource.
Resources are represented as 'resourceType.resourceName'.

resourceTypes are pre-defined in WebObs: there are 5 resourceTypes available (at time of writing this document):
authprocs, authviews, authforms, authwikis, and authmisc.

resourceNames are developer-freely-defined strings, with the exception of '*' that WebObs interprets as all/any resource of the given resourceType.
Additionaly, WebObs applications may specify path-like parseable resourceNames, eg. subdir/subdir/file, that the system
will automatically try to match against individual resourceNames; in the previous example, the system will try to check access rights
for resourceNames subdir/ , subdir/subdir/ , and subdir/file.

=head1 GLOBALS VARIABLES

=head2 CONSTANTS

 READAUTH : Read access right value
 EDITAUTH : Edit access right value
 ADMAUTH  : Admin access right value

=head2 %WebObs::USERS

HoH of all users (identified by their 'login' name) and their attributes.

=head2 %webObs::USERIDS

Hash mapping each user 'LOGIN' to its corresponding UID.

=head2 %WebObs::CLIENT

Currently executing web client, as reported by $ENV{REMOTE_USER}.
If $ENV{REMOTE_USER} undefined|""|unknown in users table,
then $CLIENT will default to user 'guest' (UID = '?')

=cut

use strict;
use warnings;
use DBI;
use File::Basename;
use POSIX qw/strftime/;
use WebObs::Utils qw(u2l l2u);
use WebObs::Config qw( %WEBOBS );

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, %USERS, %USERIDS, $USERS_LFN, $CLIENT);
use constant READAUTH => 1;
use constant EDITAUTH => 2;
use constant ADMAUTH  => 4;

require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(%USERS %USERIDS $CLIENT READAUTH EDITAUTH ADMAUTH);
@EXPORT_OK  = qw(refreshUsers allUsers clientHasRead clientHasEdit clientHasAdm clientIsValid listRNames userListGroup htpasswd_update htpasswd_verify htpasswd_display);
$VERSION    = "1.00";

refreshUsers();

if ((!defined($ENV{"REMOTE_USER"})) or ($ENV{"REMOTE_USER"} eq "") or (!defined($USERS{$ENV{"REMOTE_USER"}}))) {
	$CLIENT = "guest";
} else {
	$CLIENT = $ENV{"REMOTE_USER"};
}

our @validtbls = ($WEBOBS{SQL_TABLE_AUTHVIEWS}, $WEBOBS{SQL_TABLE_AUTHPROCS}, $WEBOBS{SQL_TABLE_AUTHFORMS}, $WEBOBS{SQL_TABLE_AUTHMISC}, $WEBOBS{SQL_TABLE_AUTHWIKIS});

=pod

=head1 FUNCTIONS

=head2 refreshUsers

Reloads %USERS and %USERIDS. Needed by WebObs daemons (such as PostBoard) to handle users defintions updated while running.

=cut

sub refreshUsers {
	undef %USERS if (%USERS); undef %USERIDS if (%USERIDS);
	%USERS = %{allUsers()};
	$USERIDS{$USERS{$_}{UID}}=$_  foreach (keys(%USERS)) ;
}

=head2 allUsers

Gets the full profile (all attributes, ie. sql columns) for each user into a HoH.
Attributes names dynamically match the corresponding SQL table column names.

 'juntel' => {
              'UID' => 'JU',
              'FULLNAME' => 'Jean Untel',
              'EMAIL' => 'untel@obs.org',
              'LOGIN' => 'juntel'
            },

=cut

sub allUsers {
	my ($rs, $dbh, $sql, $sth);

	my $dbname    = $WEBOBS{SQL_DB_USERS};
	my $tablename = $WEBOBS{SQL_TABLE_USERS};
	$USERS_LFN = "DB $dbname (".(stat($dbname))[9].") TABLE $tablename";

	$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) or die "DB error connecting to $dbname: ".DBI->errstr;

	$sql = "SELECT * FROM $tablename" ;
	$sth = $dbh->prepare($sql);
	$sth->execute();
	$rs = $sth->fetchall_hashref('LOGIN');

	$dbh->disconnect;
	return $rs;
}

=pod

=head2 listRNames

Gets the list of currently defined resources of a given type.
Returns a reference to the list (or 0).

	$pres = WebObs::Users::listRNames(type=>'authprocs');
	for (@$pres) { print "=>$_\n" };   # ie., all @$pres[]

=cut

sub listRNames {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}));
	my (@rs, $dbh, $sql, $sth, $tmp);

	#if ($KWARGS{type} ~~ @validtbls) {
	if (grep /^$KWARGS{type}$/i , @validtbls) {
		my $dbname    = $WEBOBS{SQL_DB_USERS};

		$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
			'AutoCommit' => 1,
			'PrintError' => 1,
			'RaiseError' => 1,
			}) or die "DB error connecting to $dbname: ".DBI->errstr;

		$sql = "SELECT distinct(resource) FROM $KWARGS{type}" ;
		$sth = $dbh->prepare($sql);
		$sth->execute();
		$tmp = $sth->fetchall_arrayref();
		foreach (@$tmp) {push @rs, @$_}

		$dbh->disconnect;
		return \@rs;
	} else { return 0 }
}

=pod

=head2 userName (was 'nomOperateur')

Given user(s) UID(s) (ie. initials) returns user(s) full-name(s)

=cut

sub userName {
	my @name;
	for (@_) {
		if ( defined($USERIDS{$_}) ) {
			push(@name,$USERS{$USERIDS{$_}}{FULLNAME});
		} else {
			push(@name,$_);
		}
	}
	return @name;
}


=pod

=head2 userListGroup

Given a user 'login' (as defined in 'users' table),returns an array of
all known user's groups:

	@Group = userListGroup('juntel');

=cut

sub userListGroup {
	my (@groups, $dbh, $sql, $sth);

	if (defined($_[0]))  {
		my $dbname    = $WEBOBS{SQL_DB_USERS};
		my $tblgroups = $WEBOBS{SQL_TABLE_GROUPS};

		$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
			'AutoCommit' => 1,
			'PrintError' => 1,
			'RaiseError' => 1,
			}) or die "DB error connecting to $dbname: ".DBI->errstr;

		$sql  = "SELECT GID";
		$sql .= " FROM $tblgroups";
		$sql .= " WHERE UID = '$USERS{$_[0]}{UID}'" ;

		$sth = $dbh->prepare($sql);
		$sth->execute();
		my $tmp = $sth->fetchall_arrayref();
		foreach (@$tmp) {push @groups, @$_}
		$dbh->disconnect;
	}
	return @groups;
}

=pod

=head2 userListAuth

Given a user 'login' (as defined in 'users' table),returns an Hash of arrays of
all known user's authorizations:

	%HoA = userListAuth('juntel');
	$HoA{resource-type} = array of all juntel's authorizations for resource-type

=cut

sub userListAuth {
	my (%rs, $dbh, $sql, $sth);

	if (defined($_[0]))  {
		my $dbname    = $WEBOBS{SQL_DB_USERS};
		my $tblusers  = $WEBOBS{SQL_TABLE_USERS};
		for my $tblauth (@validtbls) {

			$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
				'AutoCommit' => 1,
				'PrintError' => 1,
				'RaiseError' => 1,
				}) or die "DB error connecting to $dbname: ".DBI->errstr;

			$sql  = "SELECT $tblauth.RESOURCE, $tblauth.AUTH";
			$sql .= " FROM $tblusers,$tblauth";
			$sql .= " WHERE $tblusers.UID = '$USERS{$_[0]}{UID}' AND  $tblusers.UID = $tblauth.UID" ;
			$sql .= " ORDER BY 1,2";

			$sth = $dbh->prepare($sql);
			$sth->execute();
			my $tmp = $sth->fetchall_arrayref();
			$rs{$tblauth} = $tmp;
		}
		$dbh->disconnect;
	}
	return %rs;
}

=pod

=head2 userHasAuth

 	print "Yes" if (WebObs::Users::userHasAuth(user=>'juntel', type=>'authprocs', name=>'SISMOBUL',auth=>READAUTH);

returns true (1) if given 'user' login has given 'auth' access right to
to resource-'type' named 'name'.

	'user' has 'xAUTH'-access to resource-type/resource-name when :
    	 1) resource-type has: user / resource-name / auth >= xAUTH
	 OR  2) resource-type has: user / * /auth >= xAUTH
	 OR  3) 'user' belongs to 'group' that verifies 1) OR 2) as above

=cut

sub userHasAuth {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}) || !exists($KWARGS{user}) || !exists($KWARGS{auth}) );

	my ($rs, $dbh, $sql, $sth, $count);
	my $rc = 0;

	#if ($KWARGS{type} ~~ @validtbls)  {
	if (grep /^$KWARGS{type}$/i , @validtbls) {
		$KWARGS{user} = $USERS{$KWARGS{user}}{UID};
		my $dbname    = $WEBOBS{SQL_DB_USERS};
		my $tblusers  = $WEBOBS{SQL_TABLE_USERS};
		my $tblgroups = $WEBOBS{SQL_TABLE_GROUPS};

		$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
			'AutoCommit' => 1,
			'PrintError' => 1,
			'RaiseError' => 1,
			}) or die "DB error connecting to $dbname: ".DBI->errstr;

        my $today = strftime("%Y-%m-%d",localtime(int(time())));
		my $validuser = $dbh->selectrow_array("SELECT VALIDITY FROM $tblusers WHERE UID='$KWARGS{user}' AND ENDDATE<='$today'");
		if ($validuser eq 'Y') {
			my @inl="'*'";
			while ($KWARGS{name} !~ m|^.?/$|) { push(@inl,"\'$KWARGS{name}\'"); $KWARGS{name}=dirname($KWARGS{name})."/"; };
			my $sql  = "SELECT COUNT(*) FROM $KWARGS{type}";
			$sql    .= " WHERE ( $KWARGS{type}.UID in (SELECT GID from $tblgroups WHERE UID='$KWARGS{user}') OR $KWARGS{type}.UID = '$KWARGS{user}') ";
			$sql    .= " AND $KWARGS{type}.RESOURCE in (".join(", ",@inl).") AND $KWARGS{type}.AUTH >= $KWARGS{auth}";

			$count   = $dbh->selectrow_array($sql);
			if ($count > 0) { $rc = 1 }
		}

		$dbh->disconnect;

	}
	return $rc;
}

=pod

=head2 userMaxAuth

returns maximum authorization granted to user on resource type / resource name in name

	$max = WebObs::Users::userMaxAuth(user=>'juntel', type=>'authprocs', name=>"('res1','res2')";

=cut

sub userMaxAuth {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}) || !exists($KWARGS{user}));

	my ($rs, $dbh, $sql, $sth);
	my $rc = 0;

	#if ($KWARGS{type} ~~ @validtbls) {
	if (grep /^$KWARGS{type}$/i , @validtbls) {
		$KWARGS{user} = $USERS{$KWARGS{user}}{UID};
		my $dbname    = $WEBOBS{SQL_DB_USERS};
		my $tblusers  = $WEBOBS{SQL_TABLE_USERS};
		my $tblgroups = $WEBOBS{SQL_TABLE_GROUPS};

		$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
			'AutoCommit' => 1,
			'PrintError' => 1,
			'RaiseError' => 1,
			}) or die "DB error connecting to $dbname: ".DBI->errstr;

        my $today = strftime("%Y-%m-%d",localtime(int(time())));
		my $validuser = $dbh->selectrow_array("SELECT VALIDITY FROM $tblusers WHERE UID='$KWARGS{user}' AND ENDDATE<='$today'");
		if ($validuser eq 'Y') {
			my $sql  = "SELECT MAX(AUTH) FROM $KWARGS{type}";
			$sql    .= " WHERE ( $KWARGS{type}.UID in (SELECT GID from $tblgroups WHERE UID='$KWARGS{user}') OR $KWARGS{type}.UID = '$KWARGS{user}') ";
			$sql    .= " AND ($KWARGS{type}.RESOURCE IN $KWARGS{name} OR $KWARGS{type}.RESOURCE ='*')";

			$rc     = $dbh->selectrow_array($sql);
		}

		$dbh->disconnect;

	}
	return $rc;
}

=pod

=head2 userIsValid

 	print "Yes" if (WebObs::Users::userIsValid(user=>'juntel');

returns true (1) if given 'user' login has a validity status 'Y'

=cut

sub userIsValid {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{user}));

	my $dbh;
	my $rc = 0;

	$KWARGS{user} = $USERS{$KWARGS{user}}{UID};
	my $dbname    = $WEBOBS{SQL_DB_USERS};
	my $tblusers  = $WEBOBS{SQL_TABLE_USERS};

	$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) or die "DB error connecting to $dbname: ".DBI->errstr;

    my $today = strftime("%Y-%m-%d",localtime(int(time())));
	my $validuser = $dbh->selectrow_array("SELECT VALIDITY FROM $tblusers WHERE UID='$KWARGS{user}' AND (ENDDATE='' OR ENDDATE>='$today')");
	if ($validuser eq 'Y') { $rc = 1 }

	$dbh->disconnect;

	return $rc;
}

=pod

=head2 clientHas{Read | Edit | Adm}

wrappers for userHasAuth with user=$CLIENT.

=cut

sub clientHasRead {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}));
	return userHasAuth(type=>$KWARGS{type}, user=>$CLIENT, name=>$KWARGS{name}, auth=>READAUTH);
}

sub clientHasEdit {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}));
	return userHasAuth(type=>$KWARGS{type}, user=>$CLIENT, name=>$KWARGS{name}, auth=>EDITAUTH);
}

sub clientHasAdm {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}));
	return userHasAuth(type=>$KWARGS{type}, user=>$CLIENT, name=>$KWARGS{name}, auth=>ADMAUTH);
}

sub clientMaxAuth {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}));
	return userMaxAuth(type=>$KWARGS{type}, user=>$CLIENT, name=>$KWARGS{name});
}

sub clientIsValid {
	return userIsValid(user=>$CLIENT);
}


=pod

=head2 resListAuth

Given a given resource-type and resource-name (as defined in 'users' table),
returns an Hash of arrays of all UID or GID's for each authorization levels
(1,2,4):

	%HoA = WebObs::Users::resListAuth(type=>'authprocs',name=>'res1');
	$HoA{authlevel} = array of all UID/GID for authlevel

=cut

sub resListAuth {
	my %KWARGS = @_;
	return 0 if (!exists($KWARGS{type}) || !exists($KWARGS{name}));

	my (%rs, $dbh, $sql, $sth);

	my $dbname    = $WEBOBS{SQL_DB_USERS};

	$dbh = DBI->connect("dbi:SQLite:$dbname", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
	}) or die "DB error connecting to $dbname: ".DBI->errstr;

	foreach my $authlevel (READAUTH,EDITAUTH,ADMAUTH) {
		$sql  = "SELECT UID FROM $KWARGS{type} WHERE AUTH = $authlevel AND (RESOURCE = '$KWARGS{name}' OR RESOURCE = '*')";
		$sth = $dbh->prepare($sql);
		$sth->execute();
		my $tmp = $sth->fetchall_arrayref();
		my @users;
		foreach (@$tmp) { push(@users, @$_) }
		$rs{$authlevel} = \@users;
	}
	$dbh->disconnect;

	return %rs;
}

=pod

=head2 htpasswd

Calls the 'htpasswd' command specified by $WEBOBS{PRGM_HTPASSWD} with the
provided arguments (used by htpasswd_update and htpasswd_verify).
Returns the error code of the 'htpasswd' command (0 for success, or a positive
error code otherwise).

=cut

sub htpasswd {
	# Calls the htpasswd command with the provided command line
	# options, login, and password.
	# Arguments: (options, arg1, arg2, ..., password, output_ref)
	# Returns the htpasswd exit code: 0 for success, > 0 otherwise.
	my $htpw_opts = "-i".shift;  # force -i to read the password from stdin
	my $output_ref = pop;  # reference where to store the output
	my $pass = pop;  # the password to pass via stdin (the last argument)
	my @htpw_args = @_;  # other arguments

	# Note: use a list for command arguments to avoid using a shell
	my @cmd = ($WEBOBS{PRGM_HTPASSWD}, $htpw_opts, @htpw_args);
	carp "info: executing command '".join(" ", @cmd)."'\n";

	# Important: use IPC:Open3 to pass the password to stdin to the
	# htpasswd command to avoid it being visible by other users.
	my ($child_in, $child_out, $child_err);
	my $pid = open3($child_in, $child_out, $child_err, @cmd);
	print $child_in $pass;
	close $child_in;  # end the subprocess

	# Read all the output to $$output_ref
	$$output_ref = do { local $/; <$child_out>; };

	# Wait for the child to avoid zombies
	waitpid($pid, 0);
	return $? >> 8;
}


=head2 htpasswd_update

Updates or adds a user password in the $WEBOBS{'HTTP_PASSWORD_FILE'} file used
by the web server for authentication.  Returns 0 for success, or a positive
error code otherwise.

=cut

sub _get_htpasswd_encryption_opt {
	# Auxiliary function that returns the htpasswd option to use according to
	# the encryption format chosen in the configuration.
	if (lc($WEBOBS{'HTPASSWD_ENCRYPTION'}) eq "bcrypt") {
		return "B";
	}
	# $WEBOBS{'HTPASSWD_ENCRYPTION'} is "md5" or anything
	return "m";
}

sub htpasswd_update {
	# Adds or update a login/password in the htpasswd file.
	# Returns 0 if success, non-zero otherwise.
	my $login = shift;  # the login to create
	my $pass = shift;  # the new password to set
	my $htpw_opt = _get_htpasswd_encryption_opt();  # options for htpasswd
	my $output;  # a reference for the output
	# Call htpasswd with the selected option
	return htpasswd($htpw_opt, $WEBOBS{'HTTP_PASSWORD_FILE'}, $login, $pass, \$output);
}


=head2 htpasswd_verify

Verifies the password of a user in the $WEBOBS{'HTTP_PASSWORD_FILE'} file.

=cut

sub htpasswd_verify {
    # Calls the htpasswd command to verify the login/password.
	# Returns 0 if success, non-zero otherwise.
	my $login = shift;
	my $pass = shift;

	my $output;  # a reference for the output
	return htpasswd("v", $WEBOBS{'HTTP_PASSWORD_FILE'}, $login, $pass, \$output);
}


=head2 htpasswd_display

Displays the line that should be added to the $WEBOBS{'HTTP_PASSWORD_FILE'}
file.

=cut

sub htpasswd_display {
	# Calls the htpasswd command to display the line that should be added to
	# the htpasswd file. Returns the output of the command.
	my $login = shift;
	my $pass = shift;

	my $htpw_opts = "n"._get_htpasswd_encryption_opt();
	my $output;  # a reference for the output
	my $rc = htpasswd($htpw_opts, $login, $pass, \$output);
	my @lines = split(/\n/, $output);
	if ($rc != 0 or not @lines) {
		return "[error while executing $WEBOBS{'HTTP_PASSWORD_FILE'}]";
	}
	# Returns the fist line of the output
	return $lines[0];
}


1;

__END__

=pod

=head1 AUTHOR

Francois Beauducel, Didier Lafon, Xavier Béguin

=head1 COPYRIGHT

Webobs - 2012-2022 - Institut de Physique du Globe Paris

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
