#!/usr/bin/perl

=head1 NAME

nsearch.pl 

=head1 SYNOPSIS

http://..../nsearch.pl[?....see Query string parameters...]

=head1 DESCRIPTION

Search for word or expression into WebObs files 

=head1 Query String parametres

=over

=item B<searchW=regexp>
    The regexp to be searched for

=item B<grid={*VIEW | *PROC | *ALL | +list}>
    one of the keywords above, selecting all grids by type, OR a list of grids 
    (list of '+' delimited grid names. eg: +VIEW.SISMCEA+VIEW.SISMMAR)

=item B<clbinfo>
    = OK to search into CLB files. Default is "OK"

=item B<evtinfo>
    = OK to search into EVENTS files. Default is "OK"

=item B<stainfo> 
    = OK to search into node's information files (*.txt and FEATURES/*.txt). Default is "OK"

=item B<entireW>    
    = 

=item B<majmin>    
    = case sensitivity

=item B<extend>    
    = for a hit, show immediate context (grep output line), or extend to show all file.

=item B<day1> + B<month1> + B<year1>
    search starting from year1/month1/day1

=item B<day2> + B<month2> + B<year2>
    search ending on year2/month2/day2

=item B<dbg>
    internal developer's switch to turn on debug messages

=back

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my  $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw(clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

# ---- DateTime inits -------------------------------------
#
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $today = strftime('%F',@tod);
my $anneeActuelle = strftime('%Y',@tod);

# ---- querystring and defaults ---------------------------
#
my $QryParm   = $cgi->Vars;
my $hilite = $QryParm->{'searchW'};
$QryParm->{'grid'}    ||= "";
$QryParm->{'entireW'} ||= "";
$QryParm->{'majmin'}  ||= "";
$QryParm->{'extend'}  ||= "0";
$QryParm->{'netinfo'} ||= "";
$QryParm->{'stainfo'} ||= "";
$QryParm->{'clbinfo'} ||= "";
$QryParm->{'evtinfo'} ||= "";
$QryParm->{'year1'}   ||= $WEBOBS{BIG_BANG};
$QryParm->{'month1'}  ||= "01";
$QryParm->{'day1'}    ||= "01";
$QryParm->{'year2'}   ||= $anneeActuelle;
$QryParm->{'month2'}  ||= "01";
$QryParm->{'day2'}    ||= "01";

#$QryParm->{'dbg'}=1; #uncomment for debug messages

# ---- grab or set  some common definitions
#
my $resultOK = 0;
my $scanlist = 1;
my $grepopt  = "-s ";
my %CLBS     = readCfg("$WEBOBS{ROOT_CODE}/etc/clb.conf");
my %fieldCLB = readCfg($CLBS{FIELDS_FILE}, "sorted");
my @clbNote  = readFile($CLBS{NOTES});

# ---- figure out requested grep options
#
if ($QryParm->{'entireW'} eq "OK") { $grepopt .= "-w " }
if ($QryParm->{'majmin'}  ne "OK") { $grepopt .= "-i " }

# ---- build list of grids to be grep'd (all VIEWs or all PROCs or listed GRIDs)
#
my @grids;
if ($QryParm->{'grid'} eq '*VIEW' || $QryParm->{'grid'} eq '*ALL') {
    for (WebObs::Grids::listViewNames()) {
        if ( clientHasRead(type=>"authviews",name=>"$_")) {
            push(@grids,"VIEW.$_");
        }
    }
}
if ($QryParm->{'grid'} eq '*PROC' || $QryParm->{'grid'} eq '*ALL') {
    for (WebObs::Grids::listProcNames()) {
        if ( clientHasRead(type=>"authprocs",name=>"$_")) {
            push(@grids,"PROC.$_");
        }
    }
}
if ($QryParm->{'grid'} =~ /^\+/) {
    my @b4authGrids = split(/\+/, substr($QryParm->{'grid'},1));
    for (@b4authGrids) {
        my ($gt,$gn) = split(/\./, $_);
        if ( clientHasRead(type=>"auth".lc($gt)."s",name=>"$gn")) {
            push(@grids,"$gt.$gn");
        }
    }
}

# ---- build list of valid nodes to be grep'd from list of grids
#
my %nodes;
for my $tg (@grids) {
    my %t = listGridNodes( grid=>$tg ,valid=>1);
    %nodes = (%nodes, %t);
}

# ---- format and dump search request: request then grids and nodes
#
my $request = "<B><I>Your search request</I>: </B>";
for (keys(%$QryParm)) {
    $request .= "<B>$_</B>=$QryParm->{$_}, ";
}
$request .= "<BR\n>";

# ---- dump grids and nodes to be grep'd  
$request .= "<B><I>has scanned grids</I>: </B>";
for (@grids) { $request .= "$_, " }
$request .= "<BR><B><I>and nodes</I>: </B>";
for (keys(%nodes)) { $request .= "$_ "}
$request .= "<BR\n>";

# ---- start HTML page ouput ------------------------------
# ---------------------------------------------------------
my $titrePage = $__{'Search for WEBOBS events/information'};

#print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print "Content-type: text/html\n\n";
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print <<"FIN";
<html><head>
<title>$titrePage</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
</head>
<body>
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>
FIN

if ($scanlist) {
    print "<div style=\"background-color: LemonChiffon\">$request</div>";
}

my $FHits = 0;

# ---- scan requested grids (GRIDS DOCs)
# --------------------------------------------------------

for my $aGrid (@grids) {
    my $HTMLresults = "";
    my ($gt,$gn) = split(/\./,$aGrid);
    my $gridDocs = "$WEBOBS{PATH_GRIDS_DOCS}/$gt.$gn*";
    print "*** grep -l $grepopt \"$QryParm->{'searchW'}\" $gridDocs<BR>" if(defined($QryParm->{'dbg'}));
    my @matchFiles = qx(grep -l $grepopt "$QryParm->{'searchW'}" $gridDocs);
    chomp(@matchFiles);
    for my $matchFile (@matchFiles) {
        my @matchFileContents;
        my ($matchFileName, $matchFileExt) = split(/\./,basename($matchFile));
        $HTMLresults .= "<LI><P class=\"titleEvent\"><b>".uc($matchFileName)."</b> ($__{'Grid doc'}) </P>\n";
        if ( $QryParm->{'extend'} eq "0" ) {
            print "*** grep $grepopt \"$QryParm->{'searchW'}\" $matchFile<BR>" if(defined($QryParm->{'dbg'}));
            @matchFileContents = qx(grep $grepopt "$QryParm->{'searchW'}" $matchFile);
            for (@matchFileContents) {
                $FHits++;
                s/($hilite)/<span class="searchResult">$1<\/span>/gi;
                $HTMLresults .= "<BLOCKQUOTE class=\"contentPartialEvent\">".$_."</BLOCKQUOTE>\n";
            }
        } else {
            $FHits++;
            @matchFileContents = grep(!/^$/, readFile($matchFile));
            $HTMLresults =~ s/($hilite)/<span class="searchResult">$1<\/span>/gi;
            $HTMLresults .= "<BLOCKQUOTE class=\"contentEvent\">".join("\n",@matchFileContents)."</BLOCKQUOTE>\n";
        }
        $HTMLresults .= "</LI>\n";
    }
    if ($HTMLresults ne "") {
        print "<HR><H4>";
        print "<A HREF=\"/cgi-bin/$GRIDS{CGI_SHOW_GRID}?grid=$aGrid\">$aGrid</A>";
        print "</H4>";
        print "<UL>$HTMLresults</UL>";
    }
}

# ---- scan requested nodes
# --------------------------------------------------------

for my $aNode (keys(%nodes)) {

    my $pathNode = "$NODES{PATH_NODES}/$aNode";
    my $HTMLresults = "";

# search info files = node config + [ well-know info *.txt , and features/*.txt ]
# ------
    my $FileList = "$pathNode/$aNode.cnf";

    if ( $QryParm->{'stainfo'} eq "OK" ) {
        my @WellKnownTxt = qw(installation.txt info.txt acces.txt);
        my $pathFeatures = "$pathNode/$NODES{SPATH_FEATURES}";
        for (@WellKnownTxt) {
            if (-e "$pathNode/$_") { $FileList .= " $pathNode/$_" }
        }
        $FileList .= " $pathFeatures/*.txt" ;
    }

    print "*** grep -l $grepopt \"$QryParm->{'searchW'}\" $FileList<BR>" if(defined($QryParm->{'dbg'}));
    my @matchFiles = qx(grep -l $grepopt "$QryParm->{'searchW'}" $FileList);
    chomp(@matchFiles);
    for my $matchFile (@matchFiles) {
        my @matchFileContents;
        my ($matchFileName, $matchFileExt) = split(/\./,basename($matchFile));
        my $explain;
        if ( $matchFileExt =~ /cnf/i ) { $explain = "$__{'configuration'}"}
        else                           { $explain = "$__{'Node info'}"}
        $HTMLresults .= "<LI><P class=\"titleEvent\"><b>".uc($matchFileName)."</b> ($explain) </P>\n";
        if ( $QryParm->{'extend'} eq "0" ) {
            print "*** grep $grepopt \"$QryParm->{'searchW'}\" $matchFile<BR>" if(defined($QryParm->{'dbg'}));
            @matchFileContents = qx(grep $grepopt $QryParm->{'searchW'} $matchFile);
            for (@matchFileContents) {
                $FHits++;
                s/($hilite)/<span class="searchResult">$1<\/span>/gi;
                $HTMLresults .= "<BLOCKQUOTE class=\"contentPartialEvent\">".$_."</BLOCKQUOTE>\n";
            }
        } else {
            $FHits++;
            @matchFileContents = grep(!/^$/, readFile($matchFile));
            $HTMLresults =~ s/($hilite)/<span class="searchResult">$1<\/span>/gi;
            $HTMLresults .= "<BLOCKQUOTE class=\"contentEvent\">".join("\n",@matchFileContents)."</BLOCKQUOTE>\n";
        }
        $HTMLresults .= "</LI>\n";
    }

    # search within CLB file
    # ------
    my @fileCLB = glob "$pathNode/PROC.*.clb";
    my $fileCLB = @fileCLB ? @fileCLB[0] : "$pathNode/$aNode.clb";
    my @params;
    foreach my $k (sort { $fieldCLB{$a}{'_SO_'} <=> $fieldCLB{$b}{'_SO_'} } keys %fieldCLB) { push(@params, $k); }
    if ( $QryParm->{'clbinfo'} eq "OK" && -e $fileCLB) {
        my $CLB;
        my $resultOK = 0;
        my @info;
        if ( $QryParm->{'majmin'} eq "OK" ) {
            @info = grep(/\Q$QryParm->{'searchW'}\E/, readFile($fileCLB));
        } else {
            @info = grep(/\Q$QryParm->{'searchW'}\E/i, readFile($fileCLB));
        }
        chomp(@info);
        ### $modif = "<a href=\"/cgi-bin/$CLBS{CGI_FORM}?node=$aNode\"><img src=\"/icons/modif.png\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
        $CLB .= "<LI><P class=\"titleEvent\"><b>Calibration File</b> (".basename($fileCLB).")</P>\n";
        if ($QryParm->{'extend'} eq "0") {
            print "*** grep $grepopt \"$QryParm->{'searchW'}\" $fileCLB<BR>" if(defined($QryParm->{'dbg'}));
            @info = (qx(grep $grepopt "$QryParm->{'searchW'}" $fileCLB));
            chomp(@info);
            $CLB .= "<BLOCKQUOTE class=\"contentPartialEvent\">";
        } else {
            $CLB .= "<BLOCKQUOTE class=\"contentEvent\">";
        }
        $CLB .= "<TABLE><TR>";
        foreach ( @params ) {
            $CLB .= "<TH>$fieldCLB{$_}{'Name'}</TH>";
        }
        $CLB .= "</TR>\n";

        for (@info) {
            my @clb = split(/\|/, $_, -1);
            shift @clb;
            if ($clb[0] le "$QryParm->{'year2'}-$QryParm->{'month2'}-$QryParm->{'$day2'}" || $QryParm->{'year2'} eq "" ) {
                $CLB .= "<TR>";
                for (@clb) {
                    $CLB .= "<TD>$_</TD>";
                }
                $CLB .= "</TR>\n";
                $resultOK = 1;
            }
        }
        $CLB .= "</TABLE></BLOCKQUOTE></LI>\n";
        if ($resultOK) {
            $FHits++;
            $HTMLresults .= $CLB;
        }
    }

    # search within  events
    # -----
    if ( $QryParm->{'evtinfo'} eq "OK") {
        my $pathInterventions = "$NODES{PATH_NODES}/$aNode/$NODES{SPATH_INTERVENTIONS}";
        my @listFileInterventions = qx(find $pathInterventions -name "$aNode*.txt" | sort -dr 2>/dev/null);
        chomp(@listFileInterventions);

        if ($#listFileInterventions >= 0) {
            my @searchEvent;
            for (@listFileInterventions) {
                print "*** grep -l $grepopt \"$QryParm->{'searchW'}\" $_<BR>" if(defined($QryParm->{'dbg'}));
                my $g = qx(grep -l $grepopt "$QryParm->{'searchW'}" $_);
                chomp($g);
                if ($g ne "") {
                    push (@searchEvent,$g);
                }
            }
            for (reverse @searchEvent) {
                my $file = substr($_,length($pathInterventions)+1);
                chomp($file);
                my @dd = split(/_/,basename($_));
                my $date = ""; my $heure = "";
                if ($dd[1] =~ "Projet") {
                    $date = "Projet";
                } else {
                    $date = $dd[1];
                    if ($dd[2] !~ "NA") {
                        $heure = substr($dd[2],0,2).":".substr($dd[2],3,2);
                    }
                }

                if (($QryParm->{'year1'} eq "" || $date ge "$QryParm->{'year1'}-$QryParm->{'month1'}-$QryParm->{'day1'}") && ($QryParm->{'year2'} eq "" || $date le "$QryParm->{'year2'}-$QryParm->{'month2'}-$QryParm->{'day2'}")) {
                    my $fileInterventions = "$pathInterventions/$file";
                    my @intervention = grep(!/^$/, readFile($fileInterventions));    # lit le fichier et vire les lignes vides
                    chomp(@intervention);
                    my @pLigne = split(/\|/,$intervention[0]);        # ligne de titre/operateurs
                    my @listeNoms = split(/\+/,$pLigne[0]);

                    #my $noms = join(", ",nomOperateur(@listeNoms));
                    my $noms = "";
                    my $titre = $pLigne[1];
                    shift(@intervention);
                    my $modif = "";
                    ##if ($editOK == 1) {
                    ##    $modif = "<a href=\"/cgi-bin/formulaireINTERVENTIONS_STATIONS.pl?file=$file\"><img src=\"/icons-webobs/modif.png\" title=\"$__{'Edit...'}\" border=0 alt=\"$__{'Edit...'}\"></a>";
                    ##}
                    $FHits++;
                    $HTMLresults .= "<LI><P class=\"titleEvent\"><b>$titre</b> $date $heure <I>($noms)</I> $modif</P>\n"
                      ."<P class=\"subEvent\">".parentEvents($file)."</P>\n";
                    if ($QryParm->{'extend'} eq "0") {

                      # lit le fichier sans la première ligne (opérateurs|titre)
                        @intervention = (qx(sed '1d' $fileInterventions | /bin/grep $grepopt "$QryParm->{'searchW'}"));
                        for (@intervention) {
                            s/($hilite)/<span class="searchResult">$1<\/span>/gi;
                            $HTMLresults .= "<BLOCKQUOTE class=\"contentPartialEvent\">".$_."</BLOCKQUOTE>\n";
                        }
                    } else {
                        for (@intervention) {
                            s/($hilite)/<span class="searchResult">$1<\/span>/gi;
                        }
                        $HTMLresults .= "<BLOCKQUOTE class=\"contentEvent\">".join("\n",@intervention)."</BLOCKQUOTE>\n";
                    }
                    $HTMLresults .= "</LI>\n";
                    $resultOK = 1;
                }
            }
        }
    }

    if ($HTMLresults ne "") {
        my $nnn = (m/^.*[\.\/].*[\.\/].*$/)?$_:WebObs::Grids::normNode(node=>"..$aNode");
        print "<HR><H4>";
        print "<A HREF=\"/cgi-bin/$NODES{CGI_SHOW}?node=$nnn\">".getNodeString(node=>$aNode)."</A>";
        my ($gt,$gn,$n) = split(/\./,$nnn);
        if ( clientHasEdit(type=>"auth".lc($gt)."s",name=>"$gn")) {
            print "&nbsp;&nbsp;<A HREF=\"/cgi-bin/$NODES{CGI_FORM}?node=$nnn\"><img src=\"/icons/modif.png\"/></A>";
        }
        print "</H4>";
        print "<UL>$HTMLresults</UL>";
    } #end show 1 node results

} #end for nodes

if ($FHits  == 0) {
    print "<H2 style=\"background-color: LemonChiffon; color: #DD5555\">No hit!</H2>\n";
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

