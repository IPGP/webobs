#!/usr/bin/perl 

=head1 NAME

vedit.pl 

=head1 SYNOPSIS

http://..../vedit.pl?action=action&object={normnode | normgrid}[&event=eventpath]

=head1 DESCRIPTION

Create or update or delete an B<event> file or B<Project> file of a grid or node. 
See WebObs/Events.pm for a description of the events-directories structures.

An B<event> reference is also created/updated/deleted into the WebObs Gazette.
See 'WebObs/Gazette.pm' for a description of the event-category articles.

An B<event> (or subevent) is identified by its B<base-path/event-path>: 
B<base-path/> is derived from the object (ie. grid or node) the event belongs to, 
B<event-path/> is the full subevents hierarchy path to the event file OR to its parent extension directory.

There's only one B<Project> associated to a grid or node: B<base-path/projectName.txt> .

=head1 VEDIT-GAZETTE BEHAVIOR

WebObs::Gazette::setArticle is used by vedit 'new' action, based on the $WEBOBS{EVENTS_TO_GAZETTE} settings. 
WebObs::Gazette::delEventArticle is used by vedit 'del' action, based on $WEBOBS{EVENTS_GAZETTE_DELETE} settings.

	$WEBOBS{EVENTS_TO_GAZETTE}|ALL       # ALL    = insert all created events into Gazette (= default)
                                         # NONE   = events are not inserted into Gazette
								   
	$WEBOBS{EVENTS_GAZETTE_DELETE}|YES   # when deleting Event, try to delete it from Gazette too                              

=head1 Query string parameters

	object = gridType.gridName{.nodeName}
	event  = eventName{.txt} | eventName{/subeventName/...}/subeventName{.txt} | projectName.txt

	object="VIEW.SOURCES.GCSCBM1",
	event="GCSCBM1_2012-01-01_20-10/GCSCBM1_2012-02-01_13-20.txt"
	is: $WEBOBS{ROOT_PATH}/GCSCBM1/$NODES{SPATH_INTERVENTIONS}/GCSCBM1_2012-01-01_20-10/GCSCBM1_2012-02-01_13-20.txt

=over 

=item B<object=normnode|normgrid>

	normnode := gridtype.gridname.nodename
	normgrid := gridtype.gridname

=item B<action=>

	{ upd | del | new | save }

B<save> is 'called' to actually process a previous B<new> or B<upd> or B<del> request from the user.

For B<upd> or B<del>, event must be the targeted event's file (*.txt). For B<new>,
event must be the parent's event (ie. may be "" if event is not a subevent).


=item B<event=eventrelpath> 

	eventrelpath := relative path to event file (.txt) if action is 'upd' or 'del' , 
	                OR relative path to event's parent's extensions dir if action is 'new'

=item B<event=projectName> 

	projectName  := NODEName_Projet.txt  

=back

=head1 Markitup customization

The JQuery plugin 'markitup' is customized for WebObs: 

- CODE/js/markitup/sets/wiki/set.js
contains the markup tags along with their corresponding keys, to be used from the 
markitup editor textarea. 

- CODE/js/markitup/sets/wiki/style.css 
defines the icons used in the markitup editor textarea.

=cut

use strict;
use warnings;
use Time::Piece;
use File::Basename;
use Switch;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
$CGI::POST_MAX = 1024;
$CGI::DISABLE_UPLOADS = 1;

# ---- webobs stuff ----------------------------------
use WebObs::Config;
use WebObs::Events;
use WebObs::Gazette;
use WebObs::Users qw(%USERS $CLIENT clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::Wiki;
use WebObs::i18n;
use Locale::TextDomain('webobs');

set_message(\&webobs_cgi_msg);

# ---- what are we here for ? can we do it ?
#
my $me = $ENV{SCRIPT_NAME};
my $GazetteWhat = (defined($WEBOBS{EVENTS_TO_GAZETTE})) ? $WEBOBS{EVENTS_TO_GAZETTE} : "ALL";
$GazetteWhat = "NONE" if ($GazetteWhat eq "LEVEL1");  # legacy "LEVEL1" now means "NONE" 
my $GazetteDel  = (defined($WEBOBS{EVENTS_GAZETTE_DELETE})) ? $WEBOBS{EVENTS_GAZETTE_DELETE} : "YES";
my $isProject = 0;
my $QryParm   = $cgi->Vars;

my $action      = $QryParm->{'action'} // "";
my $notify      = $QryParm->{'notify'} // "";
my $object      = $QryParm->{'object'} // "";
my ($GRIDType, $GRIDName, $NODEName, $evbase, $evtrash) = WebObs::Events::struct(trim($object));
my $evpath      = $QryParm->{'event'}  // "";
my $s2g         = 0;
my $send2Gazette = $QryParm->{'s2g'} // 0;
my $titre       = $QryParm->{'titre'} // "";
my @oper        = $cgi->param('oper');
my @roper       = $cgi->param('roper');
my $contents    = $QryParm->{'contents'} // "";
my $date        = $QryParm->{'date'} // "";
my $time        = $QryParm->{'time'} // "";
my $date2       = $QryParm->{'date2'} // "";
my $time2       = $QryParm->{'time2'} // "";
my $feature     = $QryParm->{'feature'} // "";
my $channel     = $QryParm->{'channel'} // "";
my $outcome     = $QryParm->{'outcome'} // "0";
my $notebook    = $QryParm->{'notebook'} // "000";
my $notebookfwd = $QryParm->{'notebookfwd'} // "0";
my $metain      = $QryParm->{'meta'} // "";     # add MMD
my $conv        = $cgi->param('conv')  // "0";  # add MMD
$contents = "$metain$contents";            # add MMD
my $meta;                                  # add MMD
my $mmd = $WEBOBS{WIKI_MMD} // 'YES';        # add MMD
my $target = "";

if ($action =~ /upd|new|del|save/i) {
	if (defined($GRIDType)) {
		$isProject = ($evpath =~ /$NODEName\_Projet.txt/);
		if (clientHasEdit(type=>"auth".lc($GRIDType)."s",name=>"$GRIDName")) {
			if ( $isProject && basename($evpath) ne $evpath ) { die $__{'invalid project name'} }
			if ( $action =~ /upd|del/i && $evpath !~ /.*\.txt$/i) { die "\"$evpath\" $__{'invalid for action'} $action" }
			if ( $action =~ /upd|del/i && !-f "$evbase/$evpath") { die "\"$evpath\" $__{'not found'}" }
			if ( $action =~ /new/i && -f "$evbase/$evpath" ) { $action = 'upd' } # new on existing: force upd !
		} else {
			die "$__{'Not authorized'}";
		}
	} else {
		die "$__{'invalid event object'}";
	}
} else {
	die "$__{'No or invalid action'}";
}

my $objectfullname;
my %NODE;
my %GRID;
# object if a node (gridtype.gridname.nodename)
if ($object =~ /^.*\..*\..*$/) {
	my %S = readNode($NODEName);
	%NODE = %{$S{$NODEName}};
	$objectfullname = "<B>$NODE{ALIAS}: $NODE{NAME}</B> <I>($NODE{TYPE})</I>";
# ... or a grid (gridtype.gridname)
} else {
	my %S = readGrid($object);
	%GRID = %{$S{$object}};
	$objectfullname = "<B>$GRID{NAME}</B>";
}

# ---------------------------------------------------------------------------------------
# ---- action 'save' : process submit button of previously displayed event's form
# write event's form elements to event file (object,event,formelements)
# 
if ($action =~ /save/i ) {
	my $logmsg = "";
	my @lines;
	# determine $target which is the full path to the event file we want to 'save'
	# from $evbase which is the events (=interventions) root directory path
	# and  $evpath (event= in querystring) which is the event file name relative to $evbase:
	#      $evpath is: "subpath/evname.txt" OR "subpath" OR ""
	$target = "$evbase/$evpath";
	# extract the event's file name from $evpath and make sure the path exists
	my $evname = ($evpath =~ /.*\.txt$/) ? basename($evpath) : "";

	my $tline = join("+",@oper)."/".join("+",@roper)."|$titre";
	if (!$isProject) {
		$tline .= "|$date2 $time2|$feature|$channel|$outcome|$notebook|$notebookfwd";
		# now build an event's file name from form's elements
		$time =~ s/:/-/;
		my $formname = "$NODEName\_$date\_$time.txt";
		if ($evname eq "") { # no *txt specified, use $formname
			$target = "$evbase/$evpath/$formname";
			WebObs::Events::versionit(\$target);
			my $fp = dirname($target);	qx(mkdir -p "$fp" 2>/dev/null);
		} else {
			if ($evname ne $formname) { # *.txt not == $formname, its a rename
				$target = dirname("$evbase/$evpath")."/$formname";
				WebObs::Events::versionit(\$target);
				my $fp = dirname($target);	qx(mkdir -p "$fp" 2>/dev/null);
				(my $evsrc = $evname) =~ s/.txt//; (my $evtgt = $formname) =~ s/.txt//;
				$logmsg .= "renaming event $evpath\n";
				qx(mv "$evbase/$evpath" $target);           # rename event file
				qx(mv "$evbase/$evsrc/" "$evbase/$evtgt");  # rename event extensions dir
				qx(rm "$evbase/$evpath~" 2>/dev/null);      # delete legacy bkup file
				$logmsg .= "deleting gazette $evpath\n";
				my $rcd = WebObs::Gazette::delEventArticle($object, "$evbase/$evpath");
			}
		} 
	}
	$logmsg .= "saving ".basename($target);
	if ( sysopen(FILE, "$target", O_RDWR | O_CREAT) ) {
		unless (flock(FILE, LOCK_EX|LOCK_NB)) {
			warn "$me waiting for lock on $target...";
			flock(FILE, LOCK_EX);
		}
		truncate(FILE, 0);
		seek(FILE, 0, SEEK_SET);
		if ($conv eq "1") {   # add MMD
			$contents = WebObs::Wiki::wiki2MMD($contents);
			$contents = "WebObs: converted with wiki2MMD\n\n$contents";
		}
		$contents =~ s{\r\n}{\n}g;   # 'cause js-serialize() forces 0d0a
		push(@lines,$tline."\n");
		push(@lines,$contents);
		print FILE @lines;
		close(FILE);
		htmlMsgOK("$logmsg");
	} else { htmlMsgNotOK("$logmsg\nerror $! opening ".basename($target)) }

	exit;
} 

# ---------------------------------------------------------------------------------------
# ---- action 'del' : delete an event file AND its extensions dir
# delete actually is a 'move' to a shared EVENT trash directory
#
if ($action =~ /del/i ) {
	#dbg# $msg .= "deleting \no=$object\nb=$evbase\nt=$evtrash\ne=$evpath\nE=$evp";
	(my $evp = $evpath) =~ s/\.txt$//;
	# list (@tree) all children of event to delete from its eventTree()
	my @tree = ("$evbase/$evpath"); my $msg = ""; my $rc = ""; my $rcd = 0;
	WebObs::Events::eventsTree(\@tree,"$evbase/$evp");
	grep {s/^\Q$evbase\E\///} @tree;
	#dbg# $msg .= "\ntree=\n"; for (@tree) { $msg .= "* $_\n"};
	# delete event and all of its children 
	$msg .= "deleting $evpath and children\n";
	$rc = WebObs::Events::deleteit($evbase, $evtrash, $evpath);
	# if events are gone, remove their reference in Gazette (from @tree)
	if ($rc eq 'OK') {
		if ($GazetteDel eq "YES") {
			for (@tree) { $rcd += WebObs::Gazette::delEventArticle($object,$_); }
			$msg .= " $rcd $__{'article removed from Gazette'}";
		}
		htmlMsgOK($msg);
	} else {
		htmlMsgNotOK("$msg\nError $rc");
	}
	exit;
}

# ---------------------------------------------------------------------------------------
# ---- actions below will display an event's form 
#
my $pagetitle = "";
my @lines;
my $today = new Time::Piece;
my $name = my $version = "";
$date = $time = $titre = $contents = "";
$contents = "";
my $parents = WebObs::Events::parents($evbase, $evpath);

# ---------------------------------------------------------------------------------------
# ---- action 'new' : show user an empty event form, to create an event file
# (object,event)
#
if ($action =~ /new/i ) {
	if (!$isProject) { 
		$date = $today->strftime('%Y-%m-%d');
		$time = $today->strftime('%H:%M');
		$date2 = $date;
		$time2 = $time;
		$pagetitle = "$__{'Create Event'}";
		# fool parents() with a pseudo (xx) evntname if needed 
		$parents = WebObs::Events::parents($evbase, "$evpath/xx") if ($evpath ne "" && $parents eq "");
		$s2g = ( $GazetteWhat eq "ALL" ) ? 1 : 0;
	} else {
		$pagetitle = "$__{'Create Project'}";
	}
	$meta = "WebObs: created by vedit  \n\n" if ($mmd ne 'NO');         # add MMD
}

# ---------------------------------------------------------------------------------------
# ---- action 'upd' : show user an event form to update contents of event file
# (object,event)
#
if ($action =~ /upd/i ) {
	no strict 'refs';

	if (!$isProject) {
		my ($fname,$ft) = split(/\./,basename($evpath));
		($name,$date,$time,$version) = split(/_/,basename($fname));
		$time =~ s/-/:/;
		$time =~ s/NA//;
		$pagetitle = "$__{'Edit Event'} [$date $time $version]";
		$s2g = ( $GazetteWhat eq "ALL" ) ? 1 : 0;
	} else {
		$pagetitle = "$__{'Edit Project'}";
	}

	# event metadata are stored in the header line of file as pipe-separated fields:
	# 	UID1[+UID2+...]|title|enddatetime|feature|channel|outcome|notebook|notebookfwd
	#	event text content
	#	...
	@lines = readFile("$evbase/$evpath");
	chomp(@lines);
	(my $authors,my $remotes,$titre,$date2,$time2,$feature,$channel,$outcome,$notebook,$notebookfwd) = WebObs::Events::headersplit($lines[0]);
	@oper = @$authors;
	@roper = @$remotes;
	shift(@lines);
	$contents = join("\n",@lines);
	($contents, $meta) = WebObs::Wiki::stripMDmetadata($contents);
}

# ---- wodp stuff
my $thismonday    = $today-($today->day_of_week+6)%7*86400;
my $daynames      = join(',',map { l2u(($thismonday+86400*$_)->strftime('%A'))} (0..6)) ;
my $monthnames    = join(',',map { l2u((Time::Piece->strptime("$_",'%m'))->strftime('%B')) } (1..12)) ;
my $wodp_d2 = "[".join(',',map { "'".substr($_,0,2)."'" } split(/,/,$daynames))."]";
my @months = split(/,/,$monthnames); 
my $wodp_m  = "[".join(',',map { "'$_'" } @months)."]";
my @holidaysdef;
open(FILE, "<$WEBOBS{FILE_DAYSOFF}") || die "$__{'failed opening holidays definitions'}\n"; 
while(<FILE>) { push(@holidaysdef,l2u($_)) if ($_ !~/^(#|$)/); }; close(FILE);
chomp(@holidaysdef);
my $wodp_holidays = "[".join(',',map { my ($d,$t)=split(/\|/,$_); "{d: \"$d\", t:\"$t\"}" } @holidaysdef)."]";
# ---- end wodp stuff

# ---- html page 
print "Content-type: text/html; charset=utf-8

<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<HTML>
<HEAD>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">
<TITLE>Event Edit</TITLE>
</HEAD>
<BODY style=\"background-color:#E0E0E0\" onLoad=\"document.theform.contents.focus()\">
<script type=\"text/javascript\" src=\"/js/jquery.js\"></script>
<!-- markitup -->
<script type=\"text/javascript\" src=\"/js/markitup/jquery.markitup.js\"></script>
<script type=\"text/javascript\" src=\"/js/markitup/sets/wiki/set.js\"></script>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/skins/markitup/style.css\" />
";
if (length($meta) > 0) {
	print "<script type=\"text/javascript\" src=\"/js/markitup/sets/markdown/set.js\"></script>
		   <link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/sets/markdown/style.css\" />";
} else {
	print "<script type=\"text/javascript\" src=\"/js/markitup/sets/wiki/set.js\"></script>
		   <link rel=\"stylesheet\" type=\"text/css\" href=\"/js/markitup/sets/wiki/style.css\" />";
}
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/wodp.css\">
<script language=\"javascript\" type=\"text/javascript\" src=\"/js/wodp.js\"></script>";

# javascript for Event form (not Project)
#
if (!$isProject) {
	print "<script language=\"javascript\" type=\"text/javascript\">
\$(document).ready(function() {
	\$(\"#markItUp\").markItUp(mySettings);
	var h = \$(\"textarea#markItUp\").css('line-height').match(/(\\d+)(.*)/);
	\$(\"textarea#markItUp\").css('height',(h[1]*\$(\"textarea#markItUp\").attr('rows'))+h[2]);
	\$('input#date').wodp({
		icon: true,
		//range: {from: min, to: max},
		days: $wodp_d2,
		months: $wodp_m,
		holidays: $wodp_holidays,
		//onpicked: function(i) { \$('input#date').val().replace(/,.*\$/,''); },
	});
	\$('input#date2').wodp({
		icon: true,
		//range: {from: min, to: max},
		days: $wodp_d2,
		months: $wodp_m,
		holidays: $wodp_holidays,
		//onpicked: function(i) { \$('input#date2').val().replace(/,.*\$/,''); },
	});
});

function postform() {
	var form = \$(\"#theform\")[0];
	var bad = false;
	\$('input[type!=\"button\"],select',form).each(function() { \$(this).css('background-color','transparent')});
	if (!form.date.value.match(/^\\d{4}-[0-1]\\d-[0-3]\\d\$/)) {bad=true; form.date.style.background='red';};
	if (form.time.value == '') {form.time.value = 'NA';}
	if (form.date2.value != '' && !form.date2.value.match(/^\\d{4}-[0-1]\\d-[0-3]\\d\$/)) {bad=true; form.date2.style.background='red';};
	if (form.date2.value == '') {form.date2.value = form.date.value;}
	if (form.time2.value == '') {form.time2.value = form.time.value;}
	if (form.oper.value == '' && form.roper.value == '') {
		bad=true;
		form.oper.style.background='red';
		form.roper.style.background='red';
	}
	if (form.titre.value == '') {bad=true; form.titre.style.background='red';}
	form.s2g.value = $s2g;
	if (bad) {
		//\$('html,body').animate({ scrollTop: 0 }, 400);
		return false;
	}
    \$.post(\"$me\", \$(\"#theform\").serialize(), function(data) {
		 if (data != '') alert(\$(\"<div/>\").html(data).text());
       	 location.href = document.referrer;	   
   	});
}
function convert2MMD()
{
	if (confirm(\"Presentation might be affected by conversion,\\nrequiring manual editing.\")) {
		\$(\"#theform\")[0].conv.value = \"1\";
		postform();
	}
}
</script>";
# javascript for Project form 
#
} else {
	print "<script language=\"javascript\" type=\"text/javascript\">
\$(document).ready(function() {
	\$(\"#markItUp\").markItUp(mySettings);
	var h = \$(\"textarea#markItUp\").css('line-height').match(/(\\d+)(.*)/);
	\$(\"textarea#markItUp\").css('height',(h[1]*\$(\"textarea#markItUp\").attr('rows'))+h[2]);
});

function postform() {
	var form = \$(\"#theform\")[0];
	var bad = false;
	\$('input[type!=\"button\"],select',form).each(function() { \$(this).css('background-color','transparent')});
	if (form.oper.value == '') {bad=true; form.oper.style.background='red';}
	if (form.titre.value == '') {bad=true; form.titre.style.background='red';}
	if (bad) {
		//\$('html,body').animate({ scrollTop: 0 }, 400);
		return false;
	}
    \$.post(\"$me\", \$(\"#theform\").serialize(), function(data) {
		 alert(\$(\"<div/>\").html(data).text());
       	 location.href = document.referrer;	   
   	});
}
function convert2MMD()
{
	if (confirm(\"Presentation might be affected by conversion,\\nrequiring manual editing.\")) {
		\$(\"#theform\")[0].conv.value = \"1\";
		postform();
	}
}
</script>";
}
# resume common for Project and Event
#
print "<!-- overLIB (c) Erik Bosrup -->
<script language=\"JavaScript\" src=\"/js/overlib/overlib.js\"></script>
<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>
<DIV ID=\"helpBox\"></DIV>";
print "<A NAME=\"MYTOP\"></A>";
print "\n<H2>$objectfullname</H2><H3>$pagetitle";
print "<br><small>$parents</small>" if ($parents ne "");
print "</H3>";
print "<FORM name=\"theform\" id=\"theform\" action=\"\">";
	print "<TABLE><TR>";
	print "<TD style=\"vertical-align: top; border: none;\">";
	if (!$isProject) {
		print "<LABEL style=\"width:80px\" for=\"date\">$__{'Start date & time'}: </LABEL><INPUT size=\"10\" name=\"date\" id=\"date\" value=\"$date\"> ";
		print "<INPUT size=\"5\" name=\"time\" id=\"time\" value=\"$time\"><br><br>\n";
		print "<LABEL style=\"width:80px\" for=\"date2\">$__{'End date & time'}: </LABEL><INPUT size=\"10\" name=\"date2\" id=\"date2\" value=\"$date2\"> ";
		print "<INPUT size=\"5\" name=\"time2\" id=\"time\" value=\"$time2\"><br><br>\n";
	}
	print "<LABEL style=\"width:80px\" for=\"titre\">$__{'Title'}:</LABEL><INPUT type=\"text\" name=\"titre\" id=\"titre\" value=\"$titre\" size=\"80\"><br><br>\n";
	# only for node's event
	if ($object =~ /^.*\..*\..*$/) {
		print "<LABEL style=\"width:80px\" for=\"feature\">$__{Feature}:</LABEL><SELECT id=\"feature\" name=\"feature\" size=\"0\">";
		my @features = ("",split(/[,\|]/,$NODE{FILES_FEATURES}));
		push(@features,$feature) if !(@features =~ $feature); # adds current feature if not in the list
		foreach (@features) {
			print "<OPTION value=\"$_\" ".($_ eq $feature ? "selected":"").">".ucfirst($_)."</OPTION>\n";
		}
		print "</SELECT><BR><BR>\n";
		# only if node associated to a proc and calibration file defined
		my $clbFile = "$NODES{PATH_NODES}/$NODEName/$NODEName.clb";
		if (-s $clbFile != 0) {
			print "<LABEL style=\"width:80px\" for=\"channel\">$__{'Sensor'}: </LABEL>";
			my @carCLB   = readCfgFile($clbFile);
			# make a list of available channels and label them with last Chan. + Loc. codes
			my %chan;
			for (@carCLB) {
				my (@chpCLB) = split(/\|/,$_);
				$chan{$chpCLB[2]} = "$chpCLB[2]: $chpCLB[3] ($chpCLB[6] $chpCLB[19])";
			}
			print "<SELECT name=\"channel\" size=\"1\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{help_nodeevent_channel}')\" id=\"channel\">";
			for (("",sort(keys(%chan)))) {
				print "<option".($_ eq $channel ? " selected":"")." value=\"$_\">".($_ eq "" ? "":$chan{$_})."</option>\n";
			}
			print "</SELECT><BR><BR>\n";
		} else {
			print "<INPUT type=\"hidden\" name=\"channel\" value=\"$channel\">\n";
		}
		print "<B>$__{'Sensor/data outcome'}: </B><INPUT type=\"checkbox\" name=\"outcome\" value=\"1\"".($outcome ? "checked":"").">";
		if ($NODES{EVENTNODE_NOTEBOOK} eq "YES") {
			print "<B style=\"margin-left:20px\">$__{'Notebook Nb'}: </B><INPUT type=\"text\" size=\"3\" name=\"notebook\" value=\"$notebook\">";
			print "<B style=\"margin-left:20px\">$__{'Forward to notebook'}: </B><INPUT type=\"checkbox\" name=\"notebookfwd\" value=\"1\" ".($notebookfwd ? "checked":"").">";
		} else {
			print "<INPUT type=\"hidden\" name=\"notebook\" value=\"$notebook\">\n";
			print "<INPUT type=\"hidden\" name=\"notebookfwd\" value=\"$notebookfwd\">\n";
		}
	}
	print "</TD>\n<TD style=\"text-align: left; vertical-align: top; border: none;\">";
	print "<B>$__{'Author(s)'}: </B><BR><SELECT id=\"oper\" name=\"oper\" size=\"10\" multiple style=\"vertical-align:text-top\" 
      onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Select names of people involved (hold CTRL key for multiple selections)'}')\">\n";
	# makes a list of active (and inactive) users
	my @alogins;
	my @ilogins;
	foreach (sort keys(%USERS)) {
		my @grp = WebObs::Users::userListGroup($_);
		my %gid = map { $_ => 1 } split(/,/,$WEBOBS{EVENTS_ACTIVE_GID});
		if ((%gid && grep { $gid{$_} } @grp) || (!%gid && $USERS{$_}{VALIDITY} eq "Y")) {
			push(@alogins,$_);
		} else {
			push(@ilogins,$_);
		}
	}
	my @logins = @alogins;
	push(@logins,@ilogins) if (!$action =~ /new/i); # adds inactive users
	for my $ulogin (@logins) {
		my $sel = "";
		if ("@oper" =~ /\Q$USERS{$ulogin}{UID}\E/ || ($action =~ /new/i && $ulogin eq $CLIENT)) {
			$sel = 'selected';
		}
		print "<option $sel value=\"$USERS{$ulogin}{UID}\">$USERS{$ulogin}{FULLNAME} ($USERS{$ulogin}{UID})</option>\n";
	}
	print "</SELECT>\n";
	print "</TD>\n<TD style=\"text-align: left; vertical-align: top; border: none;\">";
	print "<B>$__{'Remote Operator(s)'}: </B><BR><SELECT id=\"roper\" name=\"roper\" size=\"10\" multiple style=\"vertical-align:text-top\" 
      onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Select names of people involved remotely (hold CTRL key for multiple selections)'}')\">\n";
	for my $ulogin (@logins) {
		my $sel = "";
		if ("@roper" =~ /\Q$USERS{$ulogin}{UID}\E/ || ($action =~ /new/i && $ulogin eq $CLIENT)) {
			$sel = 'selected';
		}
		print "<option $sel value=\"$USERS{$ulogin}{UID}\">$USERS{$ulogin}{FULLNAME} ($USERS{$ulogin}{UID})</option>\n";
	}
	print "</SELECT></TR>\n";
	print "<TR><TD style=\"vertical-align: top; border: none;\" colspan=3>";
	print "<P><TEXTAREA id=\"markItUp\" class=\"markItUp\" rows=\"11\" cols=\"80\" name=\"contents\" dataformatas=\"plaintext\">$contents</TEXTAREA></P>";
	print "<P style=\"background-color: #ffffee\">";
		print "<input type=\"button\" name=\"lien\" value=\"$__{'Cancel'}\" onClick=\"history.go(-1)\" style=\"font-weight:normal\">";
		if (length($meta) == 0 && $mmd ne 'NO') {
			print "<input type=\"button\" name=lien value=\"$__{'> MMD'}\" onClick=\"convert2MMD();\" style=\"font-weight:normal\">";
		}
		print "<input type=\"button\" style=\"font-weight:bold\" value=\"$__{'Submit'}\" onClick=\"postform();\">";
		print "<B style=\"margin-left:20px\">$__{Notify} (email)</B><input type=\"checkbox\"".($NODES{EVENTNODE_NOTIFY_DEFAULT} eq "YES" ? " checked":"")." name=\"notify\" value=\"OK\""
			." onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'Send an e-mail to inform Webobs users'}')\">";
		print "<input type=\"hidden\" name=\"action\" value=\"save\">";
		print "<input type=\"hidden\" name=\"object\" value=\"$object\">";
		print "<input type=\"hidden\" name=\"event\" value=\"$evpath\">";
		print "<input type=\"hidden\" name=\"s2g\" value=\"0\">";
		print "<input type=\"hidden\" name=\"conv\" value=\"0\">";
		print "<input type=\"hidden\" name=\"meta\" value=\"$meta\">\n";
	print "</P>";
	print "</TABLE>";
print "</FORM>\n";
		
print "\n</BODY>\n</HTML>\n";


# ---- helpers fns to process Gazette and return 'save' information to client
#
sub htmlMsgOK {
	my $msg = "$_[0]\n";
	my $rcd = 0;
	if ($send2Gazette) {
		if ($GazetteDel eq "YES" && $target ne "") {
			$rcd = WebObs::Gazette::delEventArticle($object,$target);
			$msg .= "\n+ ".basename($target)." $__{'removed from Gazette'}" if ($rcd != 0);
		}
		$rcd = WebObs::Gazette::setEventArticle($object,$target,$titre,join('+',@oper),$date2."_".$time2);
		$msg .= "+ ".basename($target)." $__{'written to Gazette'}\n" if ($rcd =~ /1 row.*/);
	}
	if ( $notify eq 'OK' ) { 
		my $t = notify();
		$msg .= "+ Notify ok"  if ( $t == 0 );
		$msg .= "+ Notify error $t" if ( $t > 0);
	}
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$msg\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
}
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "$_[0]\n$__{'FAILED'} !\n";
}

# ---- notify
#
sub notify { 
	my $eventname = "eventnode";
	my $senderId  = $USERS{$CLIENT}{UID};
	my $names = join(", ",WebObs::Users::userName(@oper));
	my $msg = '';

	if ($object =~ /^.*\..*\..*$/) {
		my %allNodeGrids = WebObs::Grids::listNodeGrids(node=>$NODEName);

		$msg .= "$__{'New event'} WebObs-$WEBOBS{WEBOBS_ID}.\n\n";
		$msg .= "$__{'Node'}: {$NODEName} $NODE{ALIAS}: $NODE{NAME} ($NODE{TYPE})\n";
		$msg .= "$__{'Grids'}: @{$allNodeGrids{$NODEName}}\n";
		$msg .= "$__{'Date'}: $date $time\n";
		$msg .= "$__{'Author(s)'}: $names\n";
		$msg .= "$__{'Title'}: $titre\n\n";
		#$msg .= "$comment\n\n";
		$msg .= "$__{'WebObs show node'}: $WEBOBS{ROOT_URL}?page=/cgi-bin/$NODES{CGI_SHOW}?node=$GRIDType.$GRIDName.$NODEName";
		$msg .= "\n";
	} else {  # act as $etype = "G"
		$msg .= "$__{'New event'} WebObs-$WEBOBS{WEBOBS_ID}.\n\n";
		$msg .= "$__{'Grid'}: {$GRIDType.$GRIDName} $GRID{NAME}\n";
		$msg .= "$__{'Date'}: $date $time\n";
		$msg .= "$__{'Author(s)'}: $names\n";
		$msg .= "$__{'Title'}: $titre\n\n";
		#$msg .= "$comment\n\n";
		$msg .= "$__{'WebObs show grid'}: $WEBOBS{ROOT_URL}?page=/cgi-bin/$GRIDS{CGI_SHOW_GRID}?node=$GRIDType.$GRIDName";
		$msg .= "\n";
	}

	my $args = substr("$eventname|$senderId|$msg",0,4000); # 4000 fits FIFO atomicity (4096)
	return ( WebObs::Config::notify($args) );
}

=pod

=head1 AUTHOR(S)

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2018 - Institut de Physique du Globe Paris

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
