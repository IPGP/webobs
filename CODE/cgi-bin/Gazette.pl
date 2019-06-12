#!/usr/bin/perl

=head1 NAME

Gazette.pl 

=head1 SYNOPSIS

https://.../cgi-bin/Gazette.pl?gview=&gdate=&gcategory=&gfilter=[&getid=][&setid=][&delid=][&create=yes]

https://.../cgi-bin/Gazette.pl?{ getid= | setid= | delid= }

=head1 DESCRIPTION

Build/display a WebObs Gazette Page, ie. displays 'options form' + 'selected contents' area.
Also used to update the Gazette DB.

=head1 Query string parameters

Query String's select/display arguments (match the Display Options Form's fields)

 gview=       [ calendar | datelist | categorylist | iCalendar ]
			  calendar: display week(s) calendar 
			  dateList: display as a list of dates
			  categoryList: display as a list of categories
			  iCalendar: display as iCal

 gdate=       date selection, single day or range, compatible with wodp format (YYYY-MM-DD[,YYYY-MM-DD])

 gcategory=   articles category to display (default to 'all')

 gfilter=     user string (RegExp allowed) to filter articles' contents

 wodpdesc=    optional description of how the date was selected by user with wodp (see wodp.js) :
              [ day | range | init | year | month | week ]
			  wodpdesc will be used to format a title for the gazette's page

Query String's management arguments (optional)

 getid=      specifies an article's id whose DB row will be returned
             as a json object. No select/display performed (g* arguments above are ignored).
			 See Gazette.js

 setid=      specifies an article's id whose DB row will be updated with a
             posted json object (all row's columns) before processing select/display.
			 See Gazette.js

 delid=      specifies an article's id whose DB row will be deleted 
             before processing select/display.
			 See Gazette.js

 getical=    specifies an ical file name (as previously built/saved with a gview=ical)
             to be downloaded 

 create=yes  automatically enters the article creation process, displaying the "create new article" form popup;
             can be used with other view-related arguments. Primarily used in 'menunav' direct links to creation.
			 Note: the creation form keeps popping up once processed, allowing successive creations, until
			 user explicitly dismiss the form (ie. choose its 'cancel' button)

=head1 LOCALIZATION

Date formats and date texts use Locale::TextDomain('webobs') specifications/translations. 

Holidays are defined in $WEBOBS{FILE_DAYSOFF} file, as a collection of <date-expression|name>

	date-expression | name

	date-expression := [ $Y-MM-DD | $P | $P n ]
	name            := string, name of holiday
	$Y              := current year
	$PQ             := Easter Sunday
	$PQ n           := n days from Easter Sunday

=cut

use strict;
use warnings;
use Time::Piece;
use CGI;
use CGI::Carp qw(fatalsToBrowser  set_message);
my $cgi = new CGI;
set_message(\&webobs_cgi_msg);

# ---- webobs stuff 
use WebObs::Config;
use WebObs::Gazette;
use WebObs::Users;
use WebObs::Dates;
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');

my $today = new Time::Piece;

# ---- query management parms with defaults
my $QryParm = $cgi->Vars;
$QryParm->{'getid'}     //= "";
$QryParm->{'setid'}     //= "";
$QryParm->{'delid'}     //= "";

# ------------------------------------------------------------------
# ---- special requests before querying/displaying gazette rows
# ------------------------------------------------------------------
my $setmsg = "";
# ---- download an iCal file; will not return here 
getical($QryParm->{'getical'}) if defined($QryParm->{'getical'}); 
# ---- getId() doesn't format results; will not return here
getId($QryParm->{'getid'}) if ($QryParm->{'getid'}  ne "") ;
# ---- DB update 'setid' (article row 
$setmsg = setId($QryParm->{'setid'}) if ($QryParm->{'setid'}  ne "");
# ---- DB delete 'delid' (article) row 
$setmsg = delId($QryParm->{'delid'}) if ($QryParm->{'delid'}  ne "");
### ---- if no select/display parms, special requests return DB update message only
##if (!defined($QryParm->{'gview'})) { 
##	if ($setmsg ne "") {
## 		print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
## 		print "Gazette update returned: $setmsg \n";
##		exit;
##	}
##}
$setmsg = "<span>".$today->strftime('%Y-%m-%d %H:%M:%S')." $__{'last DB update'}: $setmsg</span>" if ($setmsg ne "");
# ---- end of special requests 
# ------------------------------------------------------------------

# ---- query select/display parms with defaults
$QryParm->{'gview'}     //= $GAZETTE{DEFAULT_VIEW};
$QryParm->{'gdate'}     //= $GAZETTE{DEFAULT_DATE};
$QryParm->{'gcategory'} //= $GAZETTE{DEFAULT_CATEGORY} //= 'ALL';
$QryParm->{'gfilter'}   //= "";
$QryParm->{'wodpdesc'}  //= "";
$QryParm->{'create'}    //= "";

# ---- convert gdate keywords to their wodp-compatible date/range expression
# ---- keywords are a subset of those handled by Gazette.js function shortcuts()
# ---- (only for coherence/documentation ... ie. could differ) 
if ($QryParm->{'gdate'} =~ /today/i) {
	$QryParm->{'gdate'} = $today->strftime('%Y-%m-%d');
}
elsif ($QryParm->{'gdate'} =~ /tomorrow/i) { 
	$QryParm->{'gdate'} = ($today+86400)->strftime('%Y-%m-%d');
}
elsif ($QryParm->{'gdate'} =~ /yesterday/i) { 
	$QryParm->{'gdate'} = ($today-86400)->strftime('%Y-%m-%d');
}
elsif ($QryParm->{'gdate'} =~ /allyear/i) {
	$QryParm->{'gdate'} = $today->year."-01-01,".$today->year."-12-31";
}
elsif ($QryParm->{'gdate'} =~ /currWeek|thisweek/i) {
	my $monday = $today-(($today->_wday+6)%7)*86400;
	my $sunday = $today+(6-($today->_wday+6)%7)*86400;
	$QryParm->{'gdate'} = $monday->strftime("%Y-%m-%d").",".$sunday->strftime("%Y-%m-%d");
}

# ---- some defaults if needed for Gazette configuration
my $titrePage = $GAZETTE{TITLE} // "Gazette";
my $empty = $__{$GAZETTE{EMPTY_SELECTION_MSG}} // $__{"Empty"};
my $mindate = $GAZETTE{BANG};
my $maxdate = ($GAZETTE{FUTURE_YEARS} + $today->year);

# ---- resolve i18n
my $fmt_long_date = $__{'gzt_fmt_long_date'} ;
my $fmt_date      = $__{'gzt_fmt_date'}; 
my $fmt_long_week = $__{'gzt_fmt_long_week'};
my $fmt_long_year = $__{'gzt_fmt_long_year'};
my $thismonday    = $today-($today->day_of_week+6)%7*86400;
my $daynames      = join(',',map { l2u(($thismonday+86400*$_)->strftime('%A'))} (0..6)) ;
my $monthnames    = join(',',map { l2u((Time::Piece->strptime("$_",'%m'))->strftime('%B')) } (1..12)) ;

my %prez = ('calendar' => $__{'Calendar'}, 
			'dateList' => $__{'List by dates'}, 
			'categoryList' => $__{'List by categories'},
			'dump' => 'dump',
			'stats' => 'stats',
			'ical' => 'iCalendar',
			) ;

# ---- ... for wodp javascript
my $wodp_d2 = "[".join(',',map { "'".substr($_,0,2)."'" } split(/,/,$daynames))."]";
my @months = split(/,/,$monthnames); 
my $wodp_m  = "[".join(',',map { "'$_'" } @months)."]";
my @holidaysdef;
open(FILE, "<$WEBOBS{FILE_DAYSOFF}") || die "$__{'failed opening holidays definitions'}\n"; 
while(<FILE>) { push(@holidaysdef,l2u($_)) if ($_ !~/^(#|$)/); }; close(FILE);
chomp(@holidaysdef);
# check/translate holidaysdef quote and accents ?
my $wodp_holidays = "[".join(',',map { my ($d,$t)=split(/\|/,$_); "{d: \"$d\", t:\"$t\"}" } @holidaysdef)."]";

# ---- build the requested display page  
# 
my $reqdate = "";
my @gazette=();

# ---- get date(-range) to display and format its default "verbose" date expression 
# (  [from] format($d1) [to] format($d2)  OR  format($d1)  )  
my ($d1, $d2) = split(/,/,$QryParm->{'gdate'});
my ($d1dt, $d2dt) = '';
if (!$d1) {  
	$d1 = $today->strftime('%Y-%m-%d');
	$d1dt = Time::Piece->strptime($d1,'%Y-%m-%d');
	$d2 = $d1;
	$d2dt = Time::Piece->strptime($d2,'%Y-%m-%d');
	$reqdate = l2u($d1dt->strftime($fmt_long_date));
} else {
	$d1dt = Time::Piece->strptime($d1,'%Y-%m-%d');
	if (!$d2) {
		$d2 = $d1;
		$reqdate = l2u($d1dt->strftime($fmt_long_date));
	} else {
		$d2dt = Time::Piece->strptime($d2,'%Y-%m-%d');
		$reqdate = "$__{'from'} ".l2u($d1dt->strftime($fmt_date))." $__{'to'} ". l2u($d2dt->strftime($fmt_date));
	}
}

# ---- change the default "verbose" date expression based on wodpdesc if it exists
if ($QryParm->{'wodpdesc'} =~ /year/i) { $reqdate = l2u($d1dt->strftime($fmt_long_year)) }
if ($QryParm->{'wodpdesc'} =~ /month/i) { $reqdate = l2u($d1dt->strftime('%B %Y')) }
if ($QryParm->{'wodpdesc'} =~ /week/i) { $reqdate = l2u($d1dt->strftime($fmt_long_week)) }

# ---- now build the article's page !
if (grep /\Q$QryParm->{'gview'}/i , keys(%prez)) {
	#@gazette = WebObs::Gazette::Show(view=>$QryParm->{'gview'},from=>$d1,to=>$d2,categories=>$QryParm->{'gcategory'},textfilter=>$QryParm->{'gfilter'},jseditor=>'openPopup');
	@gazette = WebObs::Gazette::Show(view=>$QryParm->{'gview'},
	                                 from=>$d1,to=>$d2,
									 categories=>$QryParm->{'gcategory'},
									 textfilter=>$QryParm->{'gfilter'},
									 jseditor=>'openPopup',jsevent=>'showobject');
	@gazette = ("<h3>$empty</h3>") if (!@gazette);
}
  
# ---- Start HTML page output
#
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";
print "<html><head><title>$GAZETTE{TITLE}</title>\n",
      "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/$WEBOBS{FILE_HTML_CSS}\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/Gazette.css\">",
      "<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/wodp.css\">",
	  "<script language=\"JavaScript\" src=\"/js/jquery.js\"></script>",
	  "<script language=\"JavaScript\" src=\"/js/wodp.js\"></script>",
	  "<script language=\"JavaScript\" src=\"/js/Gazette.js\"></script>\n",
	  "</head>" ;  
print "<body>\n";

# ---- articles management form
#DL-was: build users dropdown list
#DL-was:my %USERNAMES; $USERNAMES{$USERS{$_}{UID}}=$USERS{$_}{FULLNAME}  foreach (keys(%USERS)) ;
#DL-was:my $selusers = ""; map { $selusers .= "<option value=\"$_\">$USERNAMES{$_}</option>" } sort keys(%USERNAMES);
# build valid and invalid user-names arrays
my %VUSERNAMES;
my %IUSERNAMES;
foreach (keys(%USERS)) {
	my @grp = WebObs::Users::userListGroup($_);
	my %gid = map { $_ => 1 } split(/,/,$GAZETTE{ACTIVE_GID});
	if ((%gid && grep { $gid{$_} } @grp) || (!%gid && $USERS{$_}{VALIDITY} eq "Y")) {
		$VUSERNAMES{$USERS{$_}{UID}} = $USERS{$_}{FULLNAME}
	} else {
		$IUSERNAMES{$USERS{$_}{UID}} = $USERS{$_}{FULLNAME}
	}
}
#DL-was:my $selusers = ""; map { $selusers .= "<option value=\"$_\">$VUSERNAMES{$_}</option>" } sort keys(%VUSERNAMES);
my $selusers = "";

# build categories dropdown list
my %QCAT;
($QCAT{$_}=$GAZETTECAT{$_}{Name}) =~ s/"/\\"/g  foreach (keys(%GAZETTECAT));
my $selcat = "";
grep { if ($GAZETTECAT{$_}{Auto} ne "1") {$selcat .= "<option style=\"color: $GAZETTECAT{$_}{RGB};\" value=\"$_\">$QCAT{$_}</option>\n"} } sort keys(%GAZETTECAT);

# form
print <<"FIN";
	<form id="overlay_form_article" class="overlay_form" style="display:none; width: auto;">
	<input type="hidden" name="setid" value="">
	<p><b><i id="formTitle">$__{'Edit Gazette'}</i></b></p>
	<label for="STARTDATE">$__{'Start date'}:<span class="small">YYYY-MM-DD</span></label><input style="width:70px;" type="text" name="STARTDATE" id="STARTDATE" value=""/>
	<label for="STARTTIME">$__{'Start time'}:<span class="small">HH:MM</span></label><input style="width:70px;" type="text" name="STARTTIME" id="STARTTIME" value=""/><br/>

	<label for="ENDDATE">$__{'End date'}:<span class="small">YYYY-MM-DD</span></label><input style="width:70px;" type="text" name="ENDDATE" id="ENDDATE" value=""/>
	<label for="ENDTIME">$__{'End time'}:<span class="small">HH:MM</span></label><input style="width:70px;" type="text" name="ENDTIME" id="ENDTIME" value=""/><br/>

	<label for="CATEGORY">$__{'category'}:<span class="small">$__{'Choose one'}</span></label><select style="width:auto;" name="CATEGORY" id="CATEGORY" size="5">$selcat</select><br/>

	<label for="UID">$__{'Name(s)'}:<span class="small">$__{'Ctrl for multiple'}</span></label><select style="width:auto;" name="UID" id="UID" size="5" multiple>$selusers</select>
	<label for="OTHERS">$__{'Other(s)'}:<span class="small">$__{'names list'}</span></label><input style="width:200px;" type="text" name="OTHERS" id="OTHERS" value=""><br/>

	<label for="PLACE">$__{'Place'}:<span class="small">$__{'string'}</span></label><input type="text" name="PLACE" id="PLACE" value=""><br/> 
	<label for="SUBJECT">$__{'Subject'}:<span class="small">$__{'string'}</span></label><input type="text" name="SUBJECT" id="SUBJECT" value=""><br/> 

	<p style="margin: 0px; text-align: center">
		<input type="button" id="sendbutton" name="sendbutton" value="$__{'Save'}" onclick="sendPopup(); return false;" />&nbsp;
		<input type="button" value="$__{'Cancel'}" onclick="closePopup(); return false" />
	</p>
	</form>
FIN

# ---- JavaScript inits 
my $jscat   = "{".join(',',map { " \"$_\": \"$QCAT{$_}\"" } keys(%QCAT))."}";
#DL-was:my $jsnames = "{".join(',',map { " \"$_\": \"$USERNAMES{$_}\"" } keys(%USERNAMES))."}";
my $jsnames  = "{".join(',',map { " \"$_\": \"$VUSERNAMES{$_} ($_)\"" } sort keys(%VUSERNAMES))."}";
my $jsnamesI = "{".join(',',map { " \"$_\": \"$IUSERNAMES{$_} ($_)\"" } sort keys(%IUSERNAMES))."}";
my $clickcreate = ($QryParm->{create} =~ /yes/i) ? "\$('input#create').click();" : "";

print <<"FIN";
<script language="JavaScript">
var gazette_cat  = $jscat;
var gazette_usrV = $jsnames;
var gazette_usrI = $jsnamesI;
var gazette_remove_text = '$__{"Remove"}';
var gazette_create_text = '$__{"Create Article"}'; 
\$(document).ready(function() {
	\$('div.thepage').css('margin-bottom', '400px'); // room for form-popup near end of page
	set_wodp($wodp_d2, $wodp_m, $wodp_holidays, $mindate, $maxdate);
	$clickcreate
});
</script>
FIN

# ---- Display selection-form as banner 
#
my $reslist = join (',', map { "'GAZETTE$_'" } keys(%GAZETTECAT));
my $createOK = (WebObs::Users::clientMaxAuth(type=>'authmisc',name=>"($reslist)") >= EDITAUTH );
$createOK = 1 if ( WebObs::Users::clientHasEdit(type=>"authmisc",name=>"GAZETTE") );

print "<A NAME=\"MYTOP\"></A>";
print "<div id=\"banner\" class=\"banner\">\n";
	print "<table width=\"100%\">";
	print "<tr>";
		print "<td style=\"width:15%; border: none; text-align: right; vertical-align: middle\">";
		print "<FORM name=\"gztform\" id=\"gztform\" action=\"/cgi-bin/Gazette.pl\" method=\"get\">";
		print "<label style=\"width:80px;font-weight:bold\" for=\"gdate\">$__{'Date(s)'}:</label> <input class=\"wodp\" size=\"25\" value=\"$QryParm->{'gdate'}\" name=\"gdate\" id=\"gdate\"/></p>";
		# following 'shortcuts' values MUST MATCH those used/processed in Gazette.js,function shortcuts()
		print "<p><select id=\"gcr\" name=\"gcr\" size=\"1\" onchange=\"shortcuts(this.value,'input#gdate');\">";
			print "<option style=\"font-style: italic;\" value=\"dummy\" selected> - $__{'or choose a preset period'} - </option>";
			print "<option value=\"today\">$__{'Today'}</option>";
			print "<option value=\"tomorrow\">$__{'Tomorrow'}</option>";
			print "<option value=\"yesterday\">$__{'Yesterday'}</option>";
			print "<option value=\"currWeek\">$__{'This Week'}</option>";
			print "<option value=\"all\">$__{'All'}</option>";
			print "<option value=\"toEnd\">$__{'From today'}</option>";
			print "<option value=\"fromStart\">$__{'Until today'}</option>";
		print "</select></p></td>\n";
		print "<td style=\"border: none; text-align: center; vertical-align: middle\">";
		print "<label style=\"width:80px;font-weight:bold\" for=\"gview\">$__{'Presentation'}:</label> <select id=\"gview\" name=\"gview\" size=\"1\" >";
		for my $i ('calendar','dateList','categoryList','ical') { # only these and ordered my way, not keys(%prez) perl's way
    		if ("$i" eq "$QryParm->{'gview'}") { print "<option selected value=$i>$prez{$i}</option>"; } 
    		else                              { print "<option value=$i>$prez{$i}</option>"; }
		}
		if (WebObs::Users::clientHasAdm(type=>"authmisc",name=>"GAZETTE_")) {
			if ("dump" eq "$QryParm->{'gview'}") { print "<option selected value=dump>$prez{dump}</option>"; } 
			else                                { print "<option value='dump'>$prez{dump}</option>"; }
			if ("stats" eq "$QryParm->{'gview'}") { print "<option selected value=stats>$prez{stats}</option>"; } 
			else                                { print "<option value='stats'>$prez{stats}</option>"; }
		}
		print "</select></td>\n";
		print "<td style=\"border: none; text-align: center; vertical-align: middle\">";
		print "<label style=\"width:80px;font-weight:bold\" for=\"gcategory\">$__{'Category'}:</label> <select id=\"gcategory\" name=\"gcategory\" size=\"1\">";
		my $selected='';
		for (sort keys %GAZETTECAT) {
			$selected = ("$_" eq "$QryParm->{'gcategory'}" ? "selected" : ""); 
			print "<option $selected value=$_>$GAZETTECAT{$_}{Name}</option>";
		}
		print "</select></td>\n";
		print "<td style=\"border: none; text-align: center; vertical-align: middle\">";
		print "<label style=\"width:80px;font-weight:bold\" for=\"gfilter\">$__{'Filter'}:</label> <input id=\"gfilter\" name=\"gfilter\" size=\"30\" value=\"$QryParm->{'gfilter'}\">";
		print "</FORM>\n";

		if ($createOK) {
			print "<td style=\"border: none; text-align: right; vertical-align: center\">";
			print "<input id=\"create\" type=\"button\" style=\"font-weight:bold\" value=\"$__{'Create New Event'}\" onclick=\"openPopup(this,-1); return false;\" />";
		}

	print "</table>";
print "</div>";


# ---- display Gazette page
#
print "<div class=\"thepage\">\n";
print "<p><i>$setmsg</i></p>" if ($setmsg ne "");
print "<h3>$reqdate</h3>" if ($QryParm->{'gview'} =~ /calendar|dump|category/);
print @gazette;
print "<br>&nbsp;&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";
print "\n</div>";

print "</body></html>";
exit;

# ---- process a 'getical' query: download an iCal file  previously saved by
# ---- a 'gview ical'. Assumes that such files are in a tmp directory that gets
# ---- cleaned up some other housekeeping process 
#
sub getical {
	if (@_ == 1 && -f $_[0]) {
		if (open(IN, "<$_[0]")) { 
			my @in = <IN>;
			close(IN);
			print $cgi->header(-type=>'text/calendar', -attachment=>"$_[0]",-charset=>'utf-8');
			print @in;
		} else { die "$__{'Could not open'} $_[0]" } 
	} else { die "$__{'invalid'} $_[0]" }
	exit;
}

# ---- process a 'getid' query: simply return article #id row as json
#
sub getId {
	print $cgi->header(-type=>'application/json',-charset=>'utf-8');
	print getArticle($_[0]);
	exit;
}

# ---- process a 'setid' query: do the DB update, then back to normal page build processing  
#
sub setId {
	my $id = ($_[0] eq "-1") ? "null" : "$_[0]";
	(my $others  = $QryParm->{'OTHERS'}) =~ s/\Q'\E/''/g; 	
	(my $place   = $QryParm->{'PLACE'}) =~ s/\Q'\E/''/g; 	
	(my $subject = $QryParm->{'SUBJECT'}) =~ s/\Q'\E/''/g; 	
	my $values = sprintf("%s,'%s','%s','%s','%s','%s','%s','%s','%s','%s'",
				 $id,
				 $QryParm->{'STARTDATE'},
				 $QryParm->{'STARTTIME'},
				 $QryParm->{'ENDDATE'},
				 $QryParm->{'ENDTIME'},
				 $QryParm->{'CATEGORY'},
				 $QryParm->{'UID'},
				 $others,#$QryParm->{'OTHERS'},
				 $place,#$QryParm->{'PLACE'},
				 $subject);#$QryParm->{'SUBJECT'});
	my $row = setArticle($values);
	return $row;
}

# ---- process a 'delid' query: delete in DB , then back to normal page build processing  
#
sub delId {
	my $id = ($_[0] eq "-1") ? "null" : "$_[0]"; 
	my $row = delArticle($id);
	return $row;
}

=pod

=head1 AUTHOR(S)

Didier Lafon from HEBDO by Didier Mallarino, Francois Beauducel, Alexis Bosson 

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

