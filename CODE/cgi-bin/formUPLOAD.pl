#!/usr/bin/perl 
#

=head1 NAME

formUPLOAD.pl 

=head1 SYNOPSIS

http://..../formUPLOAD.pl?{grid=|node=}&doc=[&event=]

=head1 DESCRIPTION

User input form to upload new documents for a GRID or a NODE to the WEBOBS server.
A "multipart/form-data" FORM will be submitted to postUPLOAD.pl 

Access/execution is under control of Webobs user's authorization policy
for GRIDS/NODES, ie. http-client must have Edit access to the GRID or a GRID that the NODE belongs to.  

=head1 QUERY-STRING  

    object=
         fully qualified grid name OR node name, ie. gridtype.gridname[.nodename]
        Document root path will be derived from object= , either:
            $GRIDS{PATH_GRIDS}/gridtype/gridname  or
            $NODES{PATH_NODES}/nodename

    doc= 
         type of document, ie. target directory for document to be uploaded, within the root path derived from object=  
         one of: "SPATH_DOCUMENTS", "SPATH_PHOTOS", "SPATH_SCHEMES", "SPATH_INTERVENTIONS" 

    event=
         only required if doc is SPATH_INTERVENTIONS: filename of Event or Project (intervention)

=cut

use strict;
use warnings;
use File::Basename;
use File::Path qw/make_path/;
use CGI;
my $cgi = new CGI;
$CGI::POST_MAX = 1024;
use CGI::Carp qw(fatalsToBrowser);
use Locale::TextDomain('webobs');
use POSIX qw/strftime/;

# ---- webobs stuff 
#
use WebObs::Config;
use WebObs::Users;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- calling stuff 
#
my @tod = localtime();
my $QryParm = $cgi->Vars;
my $typeDoc = $QryParm->{'doc'}     // "";
my $object  = $QryParm->{'object'}  // "";
my $event   = $QryParm->{'event'}   // "";
my $form    = $QryParm->{'form'}    // "";  # name of the form
my $delay   = $QryParm->{'delay'}   // 0;   # delay rate (in seconds)
my $height  = $QryParm->{'height'}  // 0;

$delay = 100 * $delay;  # delay rate (in hundredths of a seconds)

# ---- validate target subir (doc=) and http-client authorizations
#
my @targets;
my $pathTarget = "";
my $thumbnailsPath = my $slidesPath = "";
my $editOK = 0;
my %GRID;
my $GRIDName  = my $GRIDType  = my $NODEName = my $RESOURCE = "";
my @NID;
my $pobj;
my $filetype = "image/*";

my $MAX_UPLOAD_SIZE = $WEBOBS{MAX_UPLOAD_SIZE} || 1;
my $PATH_FORMDOCS = $GRIDS{SPATH_FORMDOCS} || "FORMDOCS";
my $PATH_THUMBNAILS = $GRIDS{SPATH_THUMBNAILS} || "THUMBNAILS";
my $PATH_SLIDES = $GRIDS{SPATH_SLIDES} || "SLIDES";

my $refer = $ENV{HTTP_REFERER};
if ( $refer =~ /formGENFORM.pl/ ) {
    my $clientAuth = WebObs::Users::clientMaxAuth(type=>"authforms",name=>"('$form')");
    die "$__{'Not authorized'}" if ($clientAuth < 1);
} else {
    @NID = split(/[\.\/]/, trim($object));
    ($GRIDType, $GRIDName, $NODEName) = @NID;
    if (defined($GRIDType) || defined($GRIDName)) {
        $editOK = 1 if ( WebObs::Users::clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName"));
        die "$__{'Not authorized'}" if ($editOK == 0);
    } else { die "$__{'Invalid object'} '$object'" }

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
}

# ---- more checkings on type of document to be uploaded
#
my @allowed = ("SPATH_PHOTOS","SPATH_GENFORM_IMAGES","SPATH_DOCUMENTS","SPATH_SCHEMES","SPATH_INTERVENTIONS","SHAPEFILE");
die "$__{'Cannot upload to'} $typeDoc" if ( "@allowed" !~ /\b$typeDoc\b/ );

if ($typeDoc eq "SPATH_GENFORM_IMAGES") {
    $pathTarget = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/$object";
} elsif ($typeDoc eq "SHAPEFILE") {
    $pathTarget = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/$object";
    $filetype = ".json, .geojson, .zip, .shz";
} elsif ($typeDoc ne "SPATH_INTERVENTIONS") {
    $pathTarget  .= "/$pobj->{$typeDoc}";
} else {
    die "$__{'intervention event not specified'}" if ($event eq "");
    $pathTarget  .= "/$pobj->{$typeDoc}/$event/PHOTOS";
}

# ---- at that point $pathTarget is where uploaded documents will be sent to
#
die "$__{'Do not know where to upload'}" if ( $pathTarget eq "" );
make_path($pathTarget);
if ($typeDoc ne "SHAPEFILE") {
    $thumbnailsPath = "$pobj->{SPATH_THUMBNAILS}" || ($typeDoc eq "SPATH_GENFORM_IMAGES" ? $PATH_THUMBNAILS : $NODES{SPATH_THUMBNAILS});
    $slidesPath = $typeDoc eq "SPATH_GENFORM_IMAGES" ? $PATH_SLIDES : $NODES{SPATH_SLIDES};
    make_path("$pathTarget/$thumbnailsPath");  # make sure pathTarget down THUMBNAILS exist
    make_path("$pathTarget/$slidesPath");
}
(my $urnTarget  = $pathTarget) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
my @listeTarget = <$pathTarget/*.*> ;

# ---- start HTML to display/process input form
# 
my $titrePage = "Manage $pobj->{$typeDoc}";

print $cgi->header(-charset=>"utf-8"),
  $cgi->start_html("$titrePage");
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">";
print <<"FIN";
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript">
\$(document).ready(function(){
    \$('#uploadFile',\$('#theform')).change(function() {
        if (this.files.length > 0) {
            var l = "<B>Selected :</B> ";
            \$(this.files).each(function(i) {
                l += this.name + " ("+ this.size +"), ";
                const fileSize = this.size;
                const fileMb = fileSize / 1024 ** 2;
                if (fileMb > $MAX_UPLOAD_SIZE) {
                    l += "<br>Please select a file less than $MAX_UPLOAD_SIZE MB.";
                    \$("#multiloadmsg").css("color", "red");
                    \$("#progress").html('');
                    \$("#save").prop("disabled", true);
                    return false;
                } else {
                    \$("#multiloadmsg").css("color", "green");
                    \$("#progress").html('Click on save to upload.');
                    \$("#save").prop("disabled", false);
                }
            });
            \$('#multiloadmsg').html(l);
            \$('#multiloadmsg').css('visibility','visible');
        } else {
            \$('#multiloadmsg').css('visibility','hidden');
        }
    });

    const deleteAll = document.getElementById("delall");
    if (deleteAll) {
        deleteAll.addEventListener("change", function() {
            document.querySelectorAll("input[type=checkbox][name*='del']").forEach(item => {
                item.checked = deleteAll.checked;
            });
        });
    }
});
function verif_formulaire()
{
    var f      = \$('#theform');
    var fd     = new FormData();
    var fdtext = "\\n";
    // all requested uploads from system's files-selector
    for (var i = 0, len = \$('#uploadFile',f).prop('files').length; i < len; i++) {
        fd.append("uploadFile"+(i+1), \$('#uploadFile',f).prop('files')[i]);
        fdtext += "upload " + \$('#uploadFile',f).prop('files')[i].name + "\\n";
    }
    // all requested deletes from delete checkboxes named 'delX'
    var dels = \$('input[name^="del"]',f);
    dels.each(function() {
        if (this.checked == true) {
            fd.append(this.name, this.value);
            fdtext += 'delete ' + this.value + "\\n";
        }
    });
    // other specifically named inputs
    fd.append("object",\$('input[name="object"],f').val());
    fd.append("doc",\$('input[name="doc"],f').val());
    fd.append("event",\$('input[name="event"],f').val());
    fd.append("nb",\$('input[name="nb"],f').val());

    var yesno = confirm("$__{'Confirm your request'}"+fdtext);
    if (yesno == true) {
        \$('#progress-bar').show();
        \$('#uploadFile').prop("disabled", true);
        \$('#save').prop("disabled", true);
        \$.ajax({
            url: "/cgi-bin/$WEBOBS{CGI_UPLOAD_POST}",
            data: fd,
            cache: false,
            contentType: false,
            processData: false,
            type: 'POST',
            timeout: 2 * 60 * 1000,
            xhr: function() {
                var xhr = new XMLHttpRequest();
                xhr.upload.addEventListener("progress", function(evt) {
                    if (evt.lengthComputable) {
                        var percentComplete = evt.loaded / evt.total;
                        console.log(percentComplete);
                        \$('#progress').html('<b> Uploading ' + (Math.round(percentComplete * 100)) + '% </b>');
                        \$('#progress-bar').val(Math.round(percentComplete * 100));
                    }
                }, false);
                return xhr;
            }
        }).done(function(data) {
            //alert(data);
            \$("#progress").html('<b>Uploaded</b>').css("color", "black");
            window.location.reload();
            setTimeout(function(){ history.go(-1) }, 100);
        }).fail(function(xhr, status, error) {
            \$("#progress").html('<b>Upload failed: ' + (xhr.status >= 100 ? xhr.status + ' ' : '') + error + '</b>').css("color", "red");
        }).always(function(data) {
            \$('#progress-bar').hide();
            \$('#uploadFile').prop("disabled", false);
            \$('#save').prop("disabled", false);
        })
    } else {
        return;
    }    
}
</script>
FIN

print "
 <body>
 <div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
 <script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
 <!-- overLIB (c) Erik Bosrup -->
 <DIV ID=\"helpBox\"></DIV>";
print "\n<H2>$titrePage</H2>";
print "<H3>$__{'for'} [$object] $event</H3>\n";

#was:print "<h2>[$NODEName] ".getNodeString(node=>$NODEName,style=>'short')."</h2>";
#debug: print "target= $pathTarget <br>";

print "<form id=\"theform\" name=\"formulaire\" action=\"\" ENCTYPE=\"multipart/form-data\">";
print "<DIV id='strip' style='width: auto; border: 1px solid gray; overflow-x: auto; overflow-y: hidden'>\n";
print "<TABLE><TR>";
my $i = 0;
foreach (@listeTarget) {
    $i++;
    my ( $name, $path, $extension ) = fileparse ( $_, '\..*' );
    my $image_height = qx($WEBOBS{PRGM_IDENTIFY} -format '%h' $_);
    my $urn  = "$urnTarget/$name$extension";
    my $turn = "$urnTarget/$thumbnailsPath/$name$extension";
    my $file = "$pathTarget/$name$extension";
    print "<TD style='border:none; border-right: 1px solid gray' align=center valign=top>";
    if ($typeDoc eq "SPATH_GENFORM_IMAGES") {
        $urn  =~ s/$WEBOBS{ROOT_DATA}/\/data/;
    }
    print "<A href=\"$urn\">";
    my $hght = $typeDoc eq "SPATH_GENFORM_IMAGES" ? $height : $NODES{THUMBNAILS_PIXV};
    my $slide_height = $GRIDS{GENFORM_SLIDE_HEIGHT} < $image_height ? $GRIDS{GENFORM_SLIDE_HEIGHT} : $image_height;
    my $th = makeThumbnail($file, "x$slide_height" , "$pathTarget/$slidesPath", $NODES{THUMBNAILS_EXT});
    my $th = makeThumbnail($file, "x$hght", "$pathTarget/$thumbnailsPath", $NODES{THUMBNAILS_EXT});
    if ( $th ne "" ) {
        if ($typeDoc eq "SPATH_GENFORM_IMAGES") {
            ($turn = $th) =~ s/$WEBOBS{ROOT_DATA}/\/data/;
        } else {
            ($turn = $th) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
        }
        print "<IMG src=\"$turn\"/>";

    } else {
        print "<IMG src=\"/icons/file.png\"/>";
    }
    print "</A>";
    print "<P>$name$extension<BR/>";
    print "<INPUT type=checkbox name=del$i value=\"$name$extension\"> $__{'Delete'}</TD>";
}
qx(cd "$pathTarget/$thumbnailsPath/" && rm -f $GRIDS{GENFORM_THUMB_ANIM} && $WEBOBS{PRGM_CONVERT} -strip -dispose background -resize x$height -delay $delay -loop 0 *.* $GRIDS{GENFORM_THUMB_ANIM} 2>/dev/null);
print "</TR></TABLE>";
print "</DIV>";

if (@listeTarget) { print "<INPUT type=checkbox id=delall> $__{'Delete all'}"; }
print "<BR><fieldset><legend style=\"color: black; font-size:8pt\">$__{'Upload new file(s)'} <i><small>Note: $__{'Avoid special characters and spaces in filename'}</small></i></legend>
    <INPUT type=\"file\" id=\"uploadFile\" name=\"uploadFile\" multiple accept='$filetype'><BR>
    <div id=\"multiloadmsg\" style=\"visibility: hidden;color: green;\"></div></P>";
print qq(<div id="progress"></div>);
print qq(<progress id="progress-bar" value="0" max="100" hidden></progress>);
print "</fieldset>";

print "<input type=\"hidden\" name=\"object\" value=\"$object\">";
print "<input type=\"hidden\" name=\"doc\" value=\"$typeDoc\">";
print "<input type=\"hidden\" name=\"event\" value=\"$event\">";
print "<input type=\"hidden\" name=\"nb\" value=\"$i\">";

print "<p>";
print "<input type=\"button\" value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
print "<input type=\"button\" value=\"$__{'Save'}\" onClick=\"verif_formulaire();\" style=\"font-weight:bold\" id=\"save\"></p>";
print "</form><BR>&nbsp;<BR>";

# ---- We're done with the page
print "\n</BODY>\n</HTML>\n";

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2015 - Institut de Physique du Globe Paris

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

