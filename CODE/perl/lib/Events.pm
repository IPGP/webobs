package WebObs::Events;

=head1 NAME

Package WebObs : B<Webobs' events> management.

=head1 SYNOPSIS

use WebObs::Events

=head1 DESCRIPTION

B<WebObs' events> are timestamped text files associated to Nodes or Grids. They are
created/updated/deleted by authorized users. They contain a header line and free wiki text lines.
Their filenames reflect both their Node or Grid membership and their timestamp.

Each B<event> may also have attached images and/or B<subevents>: both are collectively referred to as B<event extensions>.
Subevents are themselves events, thus building up a tree structure for each event.

B<WebObs' events> live in B<dedicated directories> of nodes and/or grids:  B<INTERVENTIONS> subdirectories.

    Events base directories (interventions):
        $GRIDS{PATH_GRIDS}/gridtype/gridname/$GRIDS{SPATH_INTERVENTIONS}/
        $NODES{PATH_NODES}/nodename/$NODES{SPATH_INTERVENTIONS}/

    Events 'trash' directories (for deleted events):
        $NODES{PATH_EVENTNODE_TRASH}
        $GRIDS{PATH_EVENTGRID_TRASH}

    Events files and extensions naming conventions:
        event_file       :=  event.txt
        event_extensions :=  event/
        event            :=  name_YYYY-MM-DD_HH-MM{_v}  |  name_YYYY-MM-DD_NA{_v}
        name             :=  { gridname | nodename }
        v                :=  so-called version number (automatically generated to make event name unique)
        NA               :=  "NA" for unknown/undefined HH-MM

    Special event file: the Project; only one allowed per Node or Grid, at the first level
        project_file     :=  name_Projet.txt

    Unfolded example for node NODEA events:
        $NODES{PATH_NODES}/NODEA/$NODES{SPATH_INTERVENTIONS}/
            NODEA_Projet.txt
            NODEA_2001-01-01_20-00.txt         Event 2001-01-01 20:00 file
            NODEA_2001-01-01_20-00/            Event 2001-01-01 20:00 extensions
                PHOTOS/                            Event 2001-01-01 20:00 photos
                    *.[jpg,pdf]
                    THUMBNAILS/
                NODEA_2002-02-02_02-02.txt         subEvent 2002-02-02 02:02
                NODEA_2002-02-02_02-02/            subEvent 2002-02-02 02:02 extensions
                    PHOTOS/                             subEvent 2002-02-02 02:02 photos
                        *.[jpg,pdf]
                        THUMBNAILS
                    NODEA_2003-03-03_03-03.txt          subsubEvent 2003-03-03 03:03
            NODEA_2010-02-02_22-30.txt         Event 2010-02-02 22:30

=cut

use strict;
use warnings;
use Time::Piece;
use File::Basename;
use WebObs::Config;
use WebObs::Wiki;
use WebObs::Utils;
use WebObs::Users;
use WebObs::Grids;
use WebObs::i18n;
use Locale::TextDomain('webobs');

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);

require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(struct eventsShow projectShow eventsTree eventsChrono);
$VERSION    = "1.00";

=pod

=head1 FUNCTIONS

=cut

# -------------------------------------------------------------------------------------------

=pod

=head2 struct

struct(objectname) takes objectname as a normalized grid name OR normalized node name and
returns an array whose elements are:

    [0] = gridtype
    [1] = gridname
    [2] = nodename
    [3] = path-to-event-directory
    [4] = path-to-trash-directory

struct returns 'undef' if 1) objectname is not a well-formed normalized object or 2) it is a grid but
$GRIDS{PATH_GRIDS} is not defined (ie. events for grids are not enabled).

NOTE: nodename will be made equals to gridname for normalized grids.

=cut

sub struct {
    return undef if (@_ != 1);
    my @obj = split(/\./,$_[0]);
    return ($obj[0],$obj[1],$obj[2],"$NODES{PATH_NODES}/$obj[2]/$NODES{SPATH_INTERVENTIONS}","$NODES{PATH_EVENTNODE_TRASH}","N") if ($#obj == 2);
    if (defined($GRIDS{PATH_GRIDS}) && $#obj == 1) {
        return ($obj[0],$obj[1],$obj[1],"$GRIDS{PATH_GRIDS}/$obj[0]/$obj[1]/$GRIDS{SPATH_INTERVENTIONS}","$GRIDS{PATH_EVENTGRID_TRASH}","G");
    }
    return undef;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 eventnameSplit

eventnameSplit(eventname) decodes event name string and returns an array of elements:

    [0] = object (node ID or grid name)
    [1] = date (yyyy-mm-dd)
    [2] = time (HH:MM or void)
    [3] = version

=cut

sub eventnameSplit {

    # grid name might contain '_' so reads date and time by splitting '-' first
    my @pn = split(/-/,$_[0]); # object_year month day_hour minute_version
    my @p1 = split(/_/,$pn[0]);
    my @p2 = split(/_/,$pn[2]);
    my @p3 = split(/_/,$pn[3]);
    my $obj = join('_',$p1[0 .. $#p1-1]);
    my $date = "$p1[$#p1]-$pn[1]-$p2[0]";
    my $time = "$p2[1]:$p3[0]";
    $time =~ s/NA//;
    my $ver = ($#p3 > 0 ? $p3[1]:"");

    return ($obj,$date,$time,$ver);
}

# -------------------------------------------------------------------------------------------

=pod

=head2 headersplit

headersplit(header) decodes header string and returns an array of elements:

    [0] = author UID (array)
    [1] = remote operator UID (array)
    [2] = title
    [3] = end date & time
    [4] = feature
    [5] = channel
    [6] = outcome flag
    [7] = notebook number
    [8] = notebook forward flag

=cut

sub headersplit {
    my ($title,$date2,$time2,$feature,$channel,$outcome,$notebook,$notebookfwd) = "";

# event metadata are stored in the header line of file as pipe-separated fields:
#     UID1[+UID2+...][/RUID1[+RUID2+...]]|title|enddatetime|feature|channel|outcome|notebook|notebookfwd
    my $pipes = $_[0] =~ tr/\|//; # count the number of pipes in header
    my @header = split(/\|/,$_[0]); # splits pipe-separated arguments
    my @people = split(/\//,$header[0]); # splits authors and remotes (forward slash separator)
    my @UIDs = split(/\+/,$people[0]); # array of authors
    my @RUIDs = split(/\+/,$people[1]) if ($#people > 0); # array of remotes
    if ($pipes > 1 && $pipes < 6) {
        $title = join("\|",@header[1..$#header]); # rare case of a former header with unescaped pipe in the title...
    } else {
        $title = $header[1] if ($#header > 0);
        ($date2,$time2) = split(/ /,$header[2]) if ($#header > 1);
        $feature = $header[3] if ($#header > 2);
        $channel = $header[4] if ($#header > 3);
        $outcome = $header[5] if ($#header > 4);
        $notebook = $header[6] if ($#header > 5);
        $notebookfwd = $header[7] if ($#header > 6);
    }
    $title =~ s/\"/\'\'/g;

    return (\@UIDs,\@RUIDs,$title,$date2,$time2,$feature,$channel,$outcome,$notebook,$notebookfwd);
}

# -------------------------------------------------------------------------------------------

=pod

=head2 eventsTree

eventsTree(list, path) appends to list the events filenames tree starting path and
sorted by descending dates.

    list          is a reference to the array of Events filenames (*.txt)
    path          the objectname

    Example:
        my @treeInterventions;
        eventsTree(\@listInterventions, "/webobs/path/DATA/NODES/node/INTERVENTIONS");

=cut

sub eventsTree {
    return if (@_ != 2) ;
    my ($list, $path) = @_;
    return if(ref($list) ne 'ARRAY');
    my @entries = sort {$b cmp $a} glob($path."/*");
    foreach my $entry (@entries) {
        next if ($entry =~ /_Projet\.txt$|.*\.txt~$|.*backup$/);
        next if ($entry =~ /\/PHOTOS\//);

        #DL-err5.10: push($list, $entry) if -f $entry;
        push(@$list, $entry) if -f $entry;
        eventsTree($list, $entry) if -d $entry;
    }
    return;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 eventsChrono

eventsChrono(list, path) appends to list the sorted (dates descending) events filenames in path.

    list         is a reference to the target array of events filenames (*.txt)
    path         path to events directory structure

    Example:
        my @listInterventions;
        eventsChrono(\@listInterventions, "/webobs/path/DATA/NODES/node/INTERVENTIONS");

=cut

sub eventsChrono {
    return if (@_ != 2) ;
    my ($list, $path) = @_;
    return if(ref($list) ne 'ARRAY');
    my @tree;
    eventsTree(\@tree, $path);

 #DL-err5.10: map { push($list,$_) } sort {basename($b) cmp basename($a)} @tree;
    map { push(@$list,$_) } sort {basename($b) cmp basename($a)} @tree;
    return;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 existProject alias countProject

existProject(objectname) takes objectname as a normalized grid or node name and
returns 1 if a Project file exists for this object, 0 otherwise

countProject is an alias for existProject.

=cut

sub existProject {
    return 0 if (@_ != 1);
    my ($gt,$gn,$n,$p,$t) = struct($_[0]);
    if (defined($p)) {
        return 1 if (-e "$p/$n\_Projet.txt");
    }
    return 0;
}
sub countProject { return existProject(@_) }

# -------------------------------------------------------------------------------------------

=pod

=head2 existEvents alias countEvents

existEvents(objectname) takes objectname as a normalized grid or node name and
returns the number of Events for this object [0..n]

countEvents is an alias for existEvents.

=cut

sub existEvents {
    return 0 if (@_ != 1);
    my ($gt,$gn,$n,$p,$t) = struct($_[0]);
    if (defined($p)) {
        return qx(/usr/bin/find $p -name "$n*.txt" 2>/dev/null | wc -l);
    }
    return 0;
}
sub countEvents { return existEvents(@_) }

# -------------------------------------------------------------------------------------------

=pod

=head2 eventsShow

eventsShow(sortedBy, objectname, editYN) returns the html string displaying the sortedBy events of objectname.
editYN indicates wether current viewing client has authorization to edit events (0/1).

    $contents = eventsShow("events", "PROC.PNAME", 0 );

    $contents = eventsShow("date", "VIEW.MYVIEW.NODE1", 1);

=cut

sub eventsShow {
    return undef if (@_ != 3);
    my ($sortedBy, $objectname, $editOK) = @_;
    return undef if ($sortedBy !~ /events|date|feature/i);

    my ($GRIDType, $GRIDName, $NODEName, $path, $trash) = struct($objectname);
    return undef if (!defined($GRIDType));
    my $html = '';
    my @list;

    eventsTree(\@list, $path)   if ($sortedBy =~ /events/i);
    eventsChrono(\@list, $path) if ($sortedBy =~ /date|feature/i);

    $html .= "<UL>\n";
    my $currentIndent = 0;
    for my $evt (@list) {
        (my $relevt = $evt) =~ s/$path\/// ;   # evt = full path to event file; relevt = relative path to event file
        (my $extevt = $evt) =~ s/\.txt//;      # extevt = full path to event extensions directory
        (my $relextevt = $extevt) =~ s/$path\/// ;   # relextevt = relative path to event extensions directory

        #my ($obj,$date,$time,$ver) = split(/_/,basename($extevt));
        # grid name might contain '_' so reads date and time by splitting '-'
        my ($obj,$date,$time,$ver) = eventnameSplit(basename($extevt));

        my @file = readFile($evt);

        #DL-beforeMMD # ignore blank lines and LF
        #DL-beforeMMD @file = grep(!/^$/, @file);
        #DL-beforeMMD chomp(@file);

# first line = usersList|title  with usersList = a + separated list of userIds, and optional |title
        if ($file[0] !~ /\|/) {            # if firstline doesn't look like 'something|someotherthing'
            unshift(@file,"|untitled\n");  # force our own default (add a line)
        }
        my ($author,$remote,$title,$date2,$time2,$feature,$channel,$outcome,$notebook,$notebookfwd) = headersplit($file[0]);
        my @authors = @$author;
        my @remotes = @$remote;
        my $EVTusers = join(", ",WebObs::Users::userName(@authors));
        my $EVTroper = join(", ",WebObs::Users::userName(@remotes));
        if ($EVTusers ne "" || $EVTroper ne "") {
            $EVTusers = "<I>(".($EVTusers ne "" ? $EVTusers:"").($EVTroper ne "" ? " / $EVTroper":"").")</I>";
        }
        my $EVTtitle = "<B>".ucfirst($title)."</B>";
        my $EVTdate = "$date $time".($date eq $date2 ? ($time eq $time2 || $time2 eq "" ? "":" &rarr; $time2"):" &rarr; $date2 $time2");

        #my $EVTver = (defined($ver)) ? " v$ver" : "";
        my $EVToutcome = ($outcome > 0 ? "<IMG src=\"/icons/attention.gif\" border=0 onMouseOut=\"nd()\" onMouseOver=\"overlib('Potential outcome on sensor/data',CAPTION,'Warning')\">":"");
        my $EVTinfo = ucfirst($feature);
        $EVTinfo .= ($channel ne "" ? " • $__{Channel} $channel":"");
        $EVTinfo .= ($notebook > 0 ? " • $__{Notebook} # $notebook".($notebookfwd > 0 ? " ($__{forward})":""):"");

        # remaining lines = event text contents
        shift(@file);

        #DL-beforeMMD my $EVTtext  = wiki2html(join("\n",@file));
        my $EVTtext  = wiki2html(join("",@file));

        # event's photos if any
        my $direvtphotos = $extevt."/PHOTOS";
        my @photos = qx(/usr/bin/find $direvtphotos -maxdepth 1 -type f  2>/dev/null);
        chomp(@photos);
        my $EVTphotos = scalar(@photos) > 0 ? photoStrip(@photos) : "";

        # event's edit icons
        my $EVTedit = "";
        if ($editOK) {
            $EVTedit .= "<a href=\"/cgi-bin/vedit.pl?object=$objectname&event=$relevt&action=upd\"><img src=\"/icons/modif.png\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
            $EVTedit .= "<img src=\"/icons/no.png\" onclick=\"delEvent('/cgi-bin/vedit.pl','$objectname','$relevt')\" style=\"cursor:pointer\" title=\"$__{'Remove...'}\" border=0 alt=\"$__{'Remove...'}\"></a>";
            $EVTedit .= "&nbsp;<a href=\"$WEBOBS{CGI_UPLOAD}?object=$objectname&doc=SPATH_INTERVENTIONS&event=$relextevt\"><img src=\"/icons/camera.png\" title=\"$__{'Manage Photos'}\" border=0 alt=\"$__{'Manage Photos'}\"></a>";
            $EVTedit .= "&nbsp;<a href=\"/cgi-bin/vedit.pl?object=$objectname&event=$relextevt&action=new\"><img src=\"/icons/plus.gif\" title=\"$__{'Add a sub event...'}\" border=0 alt=\"$__{'Add a sub event...'}\"></a>";
        }

        # indent this event in "events" list
        if ($sortedBy =~ /events/i) {
            my $thisLevel = ($relevt =~ tr/\///);  # count "/"s
            if ($thisLevel >  $currentIndent) {
                for (1..($thisLevel-$currentIndent)) { $html .= "<UL style=\"list-style-type:circle\">\n"; $currentIndent++ }
            } elsif ($thisLevel < $currentIndent) {
                for (1..($currentIndent-$thisLevel)) { $html .= "</UL>\n"; $currentIndent-- }
            }
        }

        # event header
        $html .= "<A name=\"$relevt\"></A>";
        $html .= "<LI class=\"Event\"><P class=\"titleEvent\">";
        $html .= "$EVTdate $EVTtitle $EVTusers " if ($sortedBy =~ /date|feature/i);
        $html .= "$EVTtitle $EVTdate $EVTusers " if ($sortedBy =~ /events/i);
        $html .= "$EVToutcome $EVTedit</P>\n";

        # event body
        $html .= "<P class=\"subEvent\">".parents($path,$relextevt)."</P>\n";
        $html .= "<P class=\"subEvent\">$EVTinfo</P>\n" if ($EVTinfo ne "");
        $html .= "<BLOCKQUOTE class=\"contentEvent\">$EVTphotos$EVTtext</BLOCKQUOTE></LI>\n";
    }
    $html .= "</UL>\n";
    return $html;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 projectShow

projectShow(objectname, editYN) returns the html string displaying the Project contents of objectname.
editYN indicates wether current viewing client has authorization to edit Project (0/1).

    $contents = projectShow("PROC.PNAME", 0 );

=cut

sub projectShow {
    return undef if (@_ != 2);
    my ($objectname, $editOK) = @_;

    my ($GRIDType, $GRIDName, $NODEName, $path, $trash) = struct($objectname);
    return undef if (!defined($GRIDType));
    my $projdir  = "$NODEName\_Projet" ;
    my $projphotos  = "$path/$projdir/PHOTOS" ;
    my $projname = "$projdir.txt";
    my $projpath = "$path/$projname";

    my $html = '';
    if (-e $projpath) {
        my $Pts = Time::Piece->strptime((stat($projpath))[9],"%s");
        my @file = readFile($projpath);
        chomp(@file);

# first line = usersList|title  with usersList = a + separated list of userIds, and optional |title
        if ($file[0] !~ /\|/) {            # if firstline doesn't look like 'something|someotherthing'
            unshift(@file,"|untitled\n");  # force our own default (add a line)
        }
        my @firstline = split(/\|/,$file[0]);
        my @users = split(/\+/,$firstline[0]);
        my $Pusers = join(", ",WebObs::Users::userName(@users));
        my $Ptitle = ($#firstline > 0) ? ucfirst($firstline[1]) : "NA" ;

        # remaining lines = event text contents
        shift(@file);
        my $Ptext  = wiki2html(join("\n",@file));

        # event's photos if any
        my @photos = qx(/usr/bin/find $projphotos -maxdepth 1 -type f  2>/dev/null);
        chomp(@photos);
        my $Pphotos = scalar(@photos) > 0 ? photoStrip(@photos) : "";

        my $Pedit = "";
        if ($editOK) {
            $Pedit .= "<a href=\"/cgi-bin/vedit.pl?object=$objectname&event=$projname&action=upd\"><img src=\"/icons/modif.png\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
            $Pedit .= "<img src=\"/icons/no.png\" onclick=\"delEvent('/cgi-bin/vedit.pl','$objectname','$projname')\" style=\"cursor:pointer\" title=\"$__{'Remove...'}\" border=0 alt=\"$__{'Remove...'}\"></a>";
            $Pedit .= "<a href=\"$WEBOBS{CGI_UPLOAD}?object=$objectname&doc=SPATH_INTERVENTIONS&event=$projdir\"><img src=\"/icons/camera.png\" title=\"$__{'Manage Photos'}\" border=0 alt=\"$__{'Manage Photos'}\"></a>";
        }
        my $Pfts = $Pts->strftime("%Y-%m-%d %H:%M");
        $html .= "<BLOCKQUOTE>";
        $html .= "<P class=\"titleEvent\"><B>$Ptitle</B>".($Pusers ne "" ? " <I>($Pusers)</I>":"")." modified:$Pfts  $Pedit</P>\n";
        $html .= "<BLOCKQUOTE class=\"contentEvent\">$Pphotos$Ptext</BLOCKQUOTE>";
        $html .= "</BLOCKQUOTE>";
    }
    return $html;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 photoStrip

photoStrip(photo-files-list) returns the html string displaying thumbnails

=cut

sub photoStrip {
    my $ret = "<DIV style='width: auto; overflow-x: auto; overflow-y: hidden'><TABLE><TR><TD>";
    foreach(@_) {
        my ( $name, $path ) = fileparse ( $_ );
        (my $urnpath  = $path) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
        $urnpath =~ s/$WEBOBS{ROOT_DATA}/$WEBOBS{URN_DATA}/; # second pass for GRIDS...
        my $thumb = makeThumbnail( "$path/$name", "x$NODES{THUMBNAILS_PIXV}", "$path/THUMBNAILS","$NODES{THUMBNAILS_EXT}");
        if ( $thumb ne "" ) {
            (my $turn = $thumb) =~ s/$NODES{PATH_NODES}/$WEBOBS{URN_NODES}/;
            $turn =~ s/$WEBOBS{ROOT_DATA}/$WEBOBS{URN_DATA}/; # second pass for GRIDS...
            my $olmsg = htmlspecialchars(__x("<b>Click to enlarge</B><br><i>Image=</i>{image}",image=>$name));
            $ret .= "<img wolbset=\"EVPHOTOS\" wolbsrc=\"$urnpath/$name\" src=\"$turn\" onMouseOut=\"nd()\" onmouseover=\"overlib('$olmsg')\" border=\"0\" alt=\"".__x('Image {file}',file=>$urnpath."/".$name)."\">\n";
        }
    }
    return $ret."</TD></TR></TABLE></DIV>";
}

# -------------------------------------------------------------------------------------------

=pod

=head2 parents

parents(path, event)
returns an html-tagged string describing all parent events of an event:
path is the events directory 'root' path, as can be obtained via a call to struct routine;
event is the relative (to path) event path.

    $path = "$NODES{PATH_NODES}/$NODEName/$NODES{SPATH_INTERVENTIONS}";
    $html = parents($path, "$NODEName_2000-01-01_01-01/$NODEName_2002-12-11_01-01");

This routine replaces the WebObs::Grids::parentEvents() method to
account for grids events as well as nodes events

=cut

sub parents {
    my $html = "";
    if (@_ == 2) {
        my ($path, $relextevt) = @_;
        my @parents = split(/\//,$relextevt);
        for (my $i=$#parents-1; $i>=0; $i--) {
            my $f = "$path/".join("/",@parents[0..$i]).".txt";
            my ($s,$d,$h) = split(/_/,$parents[$i]);
            $h =~ s/-/:/;
            my $t = "???";
            if (-e $f) {
                my @xx = readFile($f);
                @xx = grep(!/^$/, @xx);
                chomp(@xx);
                my $o;
                ($o,$t) = split(/\|/,$xx[0]);
            }
            $html .= " \@ <B>$t</B> ($d".($h ne "NA" ? " $h":"").")";
        }
    }
    return $html;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 deleteit

deleteit(eventbase,eventtrash,eventpath)

Deletes an event file and its event extensions dir. Delete actually is a 'move' to the shared
TRASH directory (eventtrash).

NOTE: Events in the TRASH directory keep their children (subevents) BUT loose their own parent relationships;
they are saved as 'first level' events. Furthermore, 'versionning' is not used, ie.
a deleted event will overwrite a previously deleted one with the same name.

=cut

sub deleteit {
    if (@_ == 3 && $_[2] =~ /.*\.txt$/) {
        my ($evbase, $evtrash, $evpath) = @_;
        qx(/bin/mkdir -p $evtrash 2>&1); # make sure root trash exists
        qx(/bin/mv "$evbase/$evpath" "$evtrash/" 2>&1);
        return "$__{'Could not move event to trash'} , $?" if ($? != 0);
        $evpath =~ s/\.txt$//;           # event extensions dir
        my $evname = basename($evpath);  # event extensions dir name
        if (-e "$evbase/$evpath/") {
            qx(mkdir -p "$evtrash/$evname/" 2>&1);
            qx(/bin/mv "$evbase/$evpath/" "$evtrash/$evname/" 2>&1);
            if ($? != 0) {

                # extensions dir move failed, try reverting *txt move
                # move $evname.txt -> back to $evbase/.../
                return "$__{'Could not move event extensions to trash'} , $?";
            }
        }
        return "OK";
    }
    return "deleteit: $__{'invalid argument'}";
}

# -------------------------------------------------------------------------------------------

=pod

=head2 versionit

versionit(eventfile)

Appends a version tag (_n), if required, to an event file name.
To be used when creating an event file from an event form's date/time:
if event name already exists, make it unique by appending a 'version' number to its name.

eventfile = reference of the event full path name to be 'versioned' if needed.

=cut

sub versionit {
    if (@_ == 1 && ref($_[0])eq "SCALAR") {
        my $rf = $_[0];
        if (-e $$rf) { # if eventfile already exists
            my ($n,$d,$s) = fileparse($$rf, qr/\.[^.]*/);
            my @nx = split(/_/,$n);
            my $nx = join('_',@nx[0..2]);
            my @lst = qx(ls $d$nx\_*.txt 2>/dev/null);
            $$rf = "$d$nx\_".(scalar(@lst)+1).".txt";
        }
    }
}

# -------------------------------------------------------------------------------------------

# local helper to reverse elements order of a list
# @list = rev( ("a","b","c") ); # @list: ("c","b","a")
sub rev { my @r; push @r, pop @_ while @_ ; return @r }

1;

__END__

=pod

=head1 AUTHOR

Didier Lafon, François Beauducel

=head1 COPYRIGHT

Webobs - 2012-2019 - Institut de Physique du Globe Paris

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
