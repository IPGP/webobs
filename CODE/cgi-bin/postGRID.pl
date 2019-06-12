#!/usr/bin/perl -w

=head1 NAME

postGRID.pl 

=head1 SYNOPSIS

http://..../postGRID.pl?grid=gridtype.gridname,text=<inline-text-to-be-saved>

=head1 DESCRIPTION

target of 'post' form action from formGRID.pl  
to complete edition (ie. save) of the edited grid-configuration file.

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
 specifies the DOMAIN.

form=
 specifies the FORM (for PROC only).

delete=
 if present and =1, deletes the GRID.

SELs=
 associated NODES list.

=cut

use strict;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff 
#
use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- what are we here for ?
# 
set_message(\&webobs_cgi_msg);
my @tod = localtime();

my $QryParm   = $cgi->Vars;
#FB-was: my @GID = split(/[\.\/]/, trim($QryParm->{'grid'})); 
my ($GRIDType,$GRIDName) = split(/[\.\/]/, trim($QryParm->{'grid'})); 
my $text = $cgi->param('text')      // '';
my $domain  = $cgi->param('domain') // '';
my $form  = $cgi->param('form')     // '';
my $TS0 = $cgi->param('ts0')        // 0;
my $delete = $cgi->param('delete')  // 0;
my @SELs = $cgi->param('SELs');

my $file;
if ( uc($GRIDType) eq 'VIEW') { $file = "$WEBOBS{PATH_VIEWS}/$GRIDName/$GRIDName.conf" }
if ( uc($GRIDType) eq 'PROC') { $file = "$WEBOBS{PATH_PROCS}/$GRIDName/$GRIDName.conf" }
my $griddir = qx(dirname $file);
chomp($griddir);

#FB-was: my @lignes;

# ---- additional integrity check: abort if file has changed
#      (well actually, it's last-modified timestamp has changed!) 
#      since the client opened it to enter his(her) modification(s)
#
if (-e $file) {
	if ($TS0 != (stat("$file"))[9]) { 
		htmlMsgNotOK("$file has been modified while you were editing ! Please retry later..."); 
		exit; 
	}

	# ---- delete the grid !
	if ($delete == 1) {
		# delete the dir/file first
		my $dir = dirname($file);
		qx(rm -rf $dir 2>&1);
		if ( $? == 0 ) {
			# NOTE: this removes the grid from tables, but not in the nodes association conf files...
			qx(rm -f $WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.* );
			qx(sqlite3 $WEBOBS{SQL_DOMAINS}  "delete from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = '$GRIDType' and NAME = '$GRIDName';");
		} else {
			htmlMsgNotOK("postGRID couldn't delete directory $file");
			exit;
		}
		htmlMsgOK("$QryParm->{'grid'} deleted");
		exit;
	}

	# ---- lock-exclusive the target file during all update process
	#
	if ( sysopen(FILE, "$file", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "postGRID waiting for lock on $file...";
			flock(FILE, LOCK_EX);
		}
		qx(cp -a $file $file~ 2>&1); # backup file (To Be Removed: lifecycle too short) 
		if ( $?  == 0 ) {            # anyway, if backup's OK do the job 
			truncate(FILE, 0);
			seek(FILE, 0, SEEK_SET);
			#FB-was:push(@lignes,$text);
			#FB-was: print FILE @lignes ;
			print FILE u2l($text);
			close(FILE);
			#FB-was: qx(sqlite3 $WEBOBS{SQL_DOMAINS}  "update $WEBOBS{SQL_TABLE_GRIDS} set DCODE = '$domain' where TYPE = '$GRIDType' and NAME ='$GRIDName';");
			#FB-was: seems better to delete+insert than update (in case of corrupted DB)
			qx(sqlite3 $WEBOBS{SQL_DOMAINS}  "delete from $WEBOBS{SQL_TABLE_GRIDS} where TYPE = '$GRIDType' and NAME = '$GRIDName';");
			qx(sqlite3 $WEBOBS{SQL_DOMAINS}  "insert into $WEBOBS{SQL_TABLE_GRIDS} VALUES('$GRIDType','$GRIDName','$domain');");
		} else {
			close(FILE);
			htmlMsgNotOK("postGRID couldn't backup $file");
			exit;
		}
	} else {
		htmlMsgNotOK("postGRID opening $file - $!");
		exit;
	}
} else {

	#
	qx(mkdir $griddir);
	if ( $? == 0 && open(FILE,">$file") ) {
		print FILE u2l($text);
		close(FILE);
		qx(sqlite3 $WEBOBS{SQL_DOMAINS}  "insert into $WEBOBS{SQL_TABLE_GRIDS} VALUES('$GRIDType','$GRIDName','$domain');");
	} else {
		htmlMsgNotOK("postGRID creating $file - $!");
		exit;
	}
}
# --- if we got here, everythings OK

# --- deletes any existing GRIDS to NODES symbolic links and creates the required links
qx(rm $WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.*);
for (@SELs) { qx(ln -s $NODES{PATH_NODES}/$_ $WEBOBS{PATH_GRIDS2NODES}/$GRIDType.$GRIDName.$_) }

if ($GRIDType eq "PROC") {
	# --- deletes any existing GRIDS to FORMS symbolic links and creates the required link
	qx(rm $WEBOBS{PATH_GRIDS2FORMS}/$GRIDType.$GRIDName.*);
	if ($form ne "") {
		qx(ln -s $WEBOBS{PATH_FORMS}/$form $WEBOBS{PATH_GRIDS2FORMS}/$GRIDType.$GRIDName.$form);
	}
}

htmlMsgOK("postGRID: $QryParm->{'grid'} updated");




# --- return information when OK 
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n";
}

# --- return information when not OK
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

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
