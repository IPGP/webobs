#!/usr/bin/perl -w

=head1 NAME

postEVENTNODE.pl 

=head1 SYNOPSIS

http://..../postEVENTNODE.pl? 

=head1 DESCRIPTION

Process data from formEVENTNODE.pl 
 
=head1 Query string parameters

delf=

oper=

anneeDepart=

moisDepart=

jourDepart=

heureDepart=

minuteDepart=

node=

titre=

commentaires=

projet=

notify=

file=

subevent=

mv=

cp=

mvcpStation=

version=

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Grids;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# 'guest' client is not authorized ... all others are !
#  could (should?) be changed to checking a specific webobs resource !
if (substr($USERS{$CLIENT}{UID},0,1) eq "?") {
    die "You are not authorized to edit interventions (events) !"
}

# ---- get the form fields (POST)
my @nom     = $cgi->param('oper');
my $annee   = $cgi->param('anneeDepart');
my $mois    = $cgi->param('moisDepart');
my $jour    = $cgi->param('jourDepart');
my $heure   = $cgi->param('heureDepart');
my $min     = $cgi->param('minuteDepart');
my $node    = $cgi->param('node');
my $titre   = $cgi->param('titre');
my $comment = $cgi->param('commentaires');
my $projet  = $cgi->param('projet');
my $notify  = $cgi->param('notify') // '';
my $file    = $cgi->param('file');
my $rmfile  = $cgi->param('delf') // '';
my $subEvent= $cgi->param('subevent');
my $mv      = $cgi->param('mv');
my $cp      = $cgi->param('cp');
my $mvcpStation = $cgi->param('mvcpStation');
my $version = $cgi->param('version');
if ($version ne "") {
    $version = "_$version";
}

# ---- handle special call to delete an event file: 
# ---- querystring has 'delf' parameter pointing to file, filename copied to $rmfile 
# ---- delete is in fact a move to the common (ie. shared by all nodes) EVENTNODE trash directory 
if ($rmfile ne "") {
    my ($node,$rest)=split(/_/,$rmfile);
    my @rc;
    if (-e "$NODES{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS}/$rmfile") {
        @rc = qx(/bin/mkdir -p $NODES{PATH_EVENTNODE_TRASH});
        @rc = qx(/bin/mv $NODES{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS}/$rmfile $NODES{PATH_EVENTNODE_TRASH}/$rmfile);
        if ($? ne 0) {
            htmlMsgNotOK("move $rmfile returned @rc");
            exit;
        }
    } else {
        htmlMsgNotOK("$rmfile not found, ie. not removed");
        exit;
    }
    htmlMsgOK("$rmfile removed successfully");
    exit;
}

# ---- other calls to create event file 
# ----
my $nomPersonnel = join("+",@nom);
my $date = $annee."-".$mois."-".$jour;
my $time = "";
if (($heure =~ /NA/) || ($min =~ /NA/)) {
    $time = "NA";
} else {
    $time = $heure."-".$min;
}

# ---- Set the target filename in $fileInterventions
# ---- from QueryString's node,date,time and subevent
my $fileBasename;

# ---- 1) $fileInterventionsName is 'base' name wether subevent or not
if ($projet ne "") {
    $fileBasename = $node."_Projet";
} else {
    $fileBasename = $node."_".$date."_".$time;
}
my $fileInterventionsName = $fileBasename.$version.".txt";

# ---- 2) $fileInterventions is actual name, subevent included 
my $nodePath = "$NODES{PATH_NODES}/$node/$NODES{SPATH_INTERVENTIONS}";
my $filePath = $nodePath;
if ($subEvent ne "") {
    $filePath .= "/$subEvent";
    if (!(-e $filePath)) {
        qx(mkdir -p $filePath);
    }
}
my $fileInterventions = "$filePath/$fileInterventionsName";

# ---- 3) If a file already exists with this date and time, add "_x" to the name (x = 1...)
if (-e $fileInterventions && "$nodePath/$file" ne $fileInterventions) {
    my (@lst) = qx(ls $filePath/${fileBasename}_*.txt);
    $fileInterventionsName = $fileBasename."_".(@lst+1).".txt";
    $fileInterventions = "$filePath/$fileInterventionsName";
}

# ---- 4) If $file different from $fileInterventionName = date and time have been modified
#      the original file is moved to the new name, so it will be backup normally
#if ($file ne "" && $file ne $fileInterventionsName) {
if ($file ne "" && $file ne $fileInterventions) {
    qx(mv $nodePath/$file $fileInterventions);

    # if sub-events exist, moves the directory too
    my $subPath0 = "$nodePath/$file";
    $subPath0 =~ s/\.txt//;
    my $subPath1 = "$nodePath/$fileInterventions";
    $subPath1 =~ s/\.txt//;
    if (-e $subPath0) {
        qx(mv $subPath0 $subPath1);
    }
}

# ---- lock-exclusive the data file during its update process
#
my @lignes;
if ( sysopen(FILE, "$fileInterventions", O_RDWR | O_CREAT) ) {
    unless (flock(FILE, LOCK_EX|LOCK_NB)) {
        warn "postEVENTNODE waiting for lock on $fileInterventions...";
        flock(FILE, LOCK_EX);
    }

    # ---- backup file (To Be Removed: lifecycle too short to be used ) 
    if (-e $fileInterventions) { qx(cp -a $fileInterventions $fileInterventions~ 2>&1); }
    if ( $?  == 0 ) {
        truncate(FILE, 0);
        seek(FILE, 0, SEEK_SET);
        my $chaine = "$nomPersonnel|$titre\n$comment\n";
        push(@lignes, $chaine);
        print FILE @lignes ;
        close(FILE);
        mvcp();
        htmlMsgOK("$fileInterventions successfully created.");
    } else {
        close(FILE);
        htmlMsgNotOK("postEVENTNODE couldn't backup $fileInterventions");
    }
} else {
    htmlMsgNotOK("postEVENTNODE opening $fileInterventions \n $!");
}

# --- return information when OK 
sub htmlMsgOK {
    my $t = 0;
    if ($notify eq 'OK') { $t = notify(); } else { $t = -1 }
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    if ($t == 0) { print "notify sent\n"; }
    if ($t > 0)  { print "notify failed $t\n"; }
    print "$_[0] \n";
}

# --- return information when not OK
sub htmlMsgNotOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    print "Update FAILED !\n $_[0] \n";
}

# --- Copy or Move to another node 
sub mvcp {
    my $filePath2 = "";
    my $fileBasename2 = "";
    my $fileInterventionsName2 = "";
    my $fileInterventions2 = "";
    if ($mvcpStation ne "" && ($mv ne "" || $cp ne "")) {
        $fileBasename2 = $mvcpStation."_".$date."_".$time;
        $fileInterventionsName2 = $fileBasename2.$version.".txt";
        $filePath2 = "$NODES{PATH_NODES}/$mvcpStation/$NODES{SPATH_INTERVENTIONS}";
        $fileInterventions2 = "$filePath2/$fileInterventionsName2";

# ---- If a file already exists with this date and time, add "_x" to the name (x = 1...)
        if (-e $fileInterventions2 && $file ne $fileInterventionsName2) {
            my (@lst) = qx(ls $filePath2/${fileBasename2}_*.txt);
            $fileInterventionsName2 = $fileBasename2."_".(@lst+1).".txt";
            $fileInterventions2 = "$filePath2/$fileInterventionsName2";
        }

        if ($cp ne "") {
            qx(cp $fileInterventions $fileInterventions2);
        }

        if ($mv ne "") {
            qx(mv $fileInterventions $fileInterventions2);
            $notify = "";
            $node = $mvcpStation;
        }
    }
}

sub notify {

    my $eventname = "eventnode";
    my $senderId  = $USERS{$CLIENT}{UID};

    my %S = readNode($node);
    my %NODE = %{$S{$node}};
    my %allNodeGrids = WebObs::Grids::listNodeGrids(node=>$node);
    my $normNode = WebObs::Grids::normNode(node=>"..$node");

    my $msg = '';
    $msg .= "$__{'New event'} WebObs-$WEBOBS{WEBOBS_ID}.\n\n";
    $msg .= "$__{'Node'}: $NODE{ALIAS}: $NODE{NAME}\n";
    $msg .= "$__{'Grids'}: @{$allNodeGrids{$node}}\n";
    $msg .= "$__{'Date'}: $date $heure:$min\n";
    $msg .= "$__{'Author(s)'}: $nomPersonnel\n";
    $msg .= "$__{'Title'}: $titre\n\n";
    $msg .= "$comment\n\n";
    $msg .= "$__{'WebObs show node'}: $WEBOBS{ROOT_URL}?page=/cgi-bin/$NODES{CGI_SHOW}?node=$normNode";
    $msg .= "\n";

    my $args = substr("$eventname|$senderId|$msg",0,4000); # 4000 fits FIFO atomicity (4096)
    return ( WebObs::Config::notify($args) );

}

__END__

=pod

=head1 AUTHOR(S)

Didier Mallarino, Francois Beauducel, Didier Lafon

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

