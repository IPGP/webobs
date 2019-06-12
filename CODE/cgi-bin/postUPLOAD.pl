#!/usr/bin/perl

=head1 NAME

postUPLOAD.pl 

=head1 SYNOPSIS

HTML "multipart/form-data" POSTed form 

=head1 DESCRIPTION

Handle requests to upload files to server (and/or delete files from erver) /PHOTOS, /SCHEMES,
/DOCUMENTS and /INTERVENTIONS subdirectories of a GRID or NODE. Those requests are HTML-POST requests.  
Typically called from formUPLOAD.pl .

Access/execution is under control of Webobs user's authorization policy
for NODES, ie. http-client must have Edit access to the GRID or a GRID that the NODE 
belongs to.  

=head1 HTML-Form fields 

 object= 
 	required fully qualified grid name OR node name, ie. gridtype.gridname[.nodename]
 	Document root path will be derived from object= , either:
		$GRIDS{PATH_GRIDS}/gridtype/gridname  or
		$NODES{PATH_NODES}/nodename

 doc=
 	type of document, ie. target directory for document to be uploaded, within the root path derived from object=  
 	one of: "SPATH_DOCUMENTS", "SPATH_PHOTOS", "SPATH_SCHEMES", "SPATH_INTERVENTIONS" 

 event=
 	only required if doc is SPATH_INTERVENTIONS: filename of Event or Project (intervention)

 nb=
 	required, number of existing files, is used as upper boundary for 'del{X}' below

 uploadFile{N}=  
 	optional, one for each file to be uploaded (ie. saved to  subdirectory 'doc'), indexed with N

 del{X}= 
 	optional, one for each existing file in 'doc' that will be deleted by this request, 
 	indexed with X = {1..nb}
  
=cut

use strict;
use warnings;
use File::Basename; 
use File::Path qw/make_path/;
use CGI::Carp qw(fatalsToBrowser); 
use CGI qw/:standard /; 
my $cgi = new CGI; 
$CGI::POST_MAX = 1024 * 5000; 

# ---- webobs stuff 
#
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- what are we here for ? ------------------------
#
my $progress = "";
my @tod = localtime(); 
my $QryParm = $cgi->Vars;
my $typeDoc = $QryParm->{'doc'}    // "";
my $object  = $QryParm->{'object'} // "";
my $event   = $QryParm->{'event'}  // "";
my $nb      = $QryParm->{'nb'}     // 0;

# ---- validate target subir (doc=) and http-client authorizations
#
my @targets;
my $pathTarget = "";
my $thumbnailsPath = "";
my $editOK = 0;
my %GRID;
my $GRIDName  = my $GRIDType  = my $NODEName = my $RESOURCE = "";
my @NID;
my $pobj;

@NID = split(/[\.\/]/, trim($object));
($GRIDType, $GRIDName, $NODEName) = @NID;
if (defined($GRIDType) || defined($GRIDName)) {
	$editOK = 1 if ( WebObs::Users::clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName"));
	htmlMsgNotOK("$__{'Not authorized'}") if ($editOK == 0);
} else { htmlMsgNotOK("$__{'Invalid object'} '$object'") }

# ---- find out wether object is a grid or a node
#
if (scalar(@NID) == 3) {
	$pobj = \%NODES;
	$pathTarget  = "$pobj->{PATH_NODES}/$NODEName";
}
if (scalar(@NID) == 2) {
	$pobj = \%GRIDS;
	$pathTarget = "$pobj->{PATH_GRIDS}/$GRIDType/$GRIDName";
}

# ---- more checkings on type of document to be uploaded
#
my @allowed = ("SPATH_PHOTOS","SPATH_DOCUMENTS","SPATH_SCHEMES","SPATH_INTERVENTIONS");
htmlMsgNotOK("$__{'Cannot upload to'} $typeDoc") if ( "@allowed" !~ /\b$typeDoc\b/ );

if ($typeDoc ne "SPATH_INTERVENTIONS") {
	$pathTarget  .= "/$pobj->{$typeDoc}";
} else {
	htmlMsgNotOK("$__{'intervention event not specified'}") if ($event eq "");
	$pathTarget  .= "/$pobj->{$typeDoc}/$event/PHOTOS";
}

# ---- at that point $pathTarget is where uploaded documents will be sent to
#
htmlMsgNotOK("$__{'Do not know where to upload'}") if ( $pathTarget eq "" );
$thumbnailsPath = "$pobj->{SPATH_THUMBNAILS}";
make_path("$pathTarget/$thumbnailsPath");  # make sure pathTarget down to PHOTOS/THUMBNAILS exist
(my $urnTarget  = $pathTarget) =~ s/$WEBOBS{ROOT_SITE}/../g;

# ---- take care of files upload if requested --------
#
my $fx = 1;
my $filename = my $upload_filehandle = "";
while($filename = $QryParm->{"uploadFile$fx"}) {
	if ($filename ne "") {
		my $safe_filename_characters = "a-zA-Z0-9_.-"; 
		my $upload_tmp = "$WEBOBS{PATH_TMP_APACHE}"; 
		$filename  = basename($filename); 
		$filename =~ tr/ /_/; 
		if ( $filename =~ /^[^a-zA-Z0-9_.-]+$/ ) {
			htmlMsgNotOK("Uploaded filename contains invalid characters.");
		}
		$upload_filehandle = $cgi->upload("uploadFile$fx"); 
		if (open ( UPLOADFILE, ">$upload_tmp/$filename") ) {
			binmode UPLOADFILE; 
			while ( <$upload_filehandle> ) { 
				print UPLOADFILE; 
			} 
			close UPLOADFILE; 
		} else {
			htmlMsgNotOK("Couldn't open upload stream; $!");
		}
		qx(mv -f "$upload_tmp/$filename" $pathTarget);
		if ($?) {
			htmlMsgNotOK("Couldn't move uploaded file to $pathTarget; $!");
		}
		$progress .= "$filename has been uploaded\n";
	}
	$fx++;
}

# ---- take care of file(s) delete if requested ------
#
my $ix = 1;
$filename = "";
while ($ix <= $nb) { 
	if ( $filename = $QryParm->{"del$ix"} ) {
		qx(rm "$pathTarget/$filename");
		if ($?) { htmlMsgNotOK("Couldn't delete $filename; $!") }
		$progress .= "$filename has been deleted\n"; 
		if (-e "$pathTarget/$thumbnailsPath/$filename.$NODES{THUMBNAILS_EXT}") {
			qx(rm "$pathTarget/$thumbnailsPath/$filename.jpg");
			if ($?) { htmlMsgNotOK("Couldn't delete $filename.$NODES{THUMBNAILS_EXT} thumbnail; $!") }
		}
	}
	$ix++;
}

# ---- getting here if all's OK: we're done -----------
#
htmlMsgOK();
exit;

# --- return information when OK 
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$progress" if ($progress ne "");
	print "Update $typeDoc for $object SUCCESSFUL !\n";
}

# --- return information when not OK
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$progress" if ($progress ne "");
	print "$_[0]\n" if ($_[0]);
 	print "Update $typeDoc for $object FAILED !\n";
	exit;
}

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

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

