package WebObs::Gazette;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Gazette

=head1 DESCRIPTION

Webobs' Gazette management.

Gazette DB table columns:

	ID,STARTDATE,STARTTIME,ENDDATE,ENDTIME,CATEGORY,UID,OTHERS,PLACE,SUBJECT

=cut

use strict;
use warnings;
use DBI;
use File::Basename;
use Time::Piece;
use WebObs::Config;
use WebObs::Dates;
use WebObs::Utils;
use WebObs::Users;
use WebObs::Grids;
use POSIX qw(ceil);
use WebObs::i18n;
use Locale::TextDomain('webobs');
    
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);

require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(%GAZETTE %GAZETTECAT Show getArticle setArticle delArticle delEventArticle);
$VERSION    = "1.00";

our %GAZETTE    = readCfg("$WEBOBS{GAZETTE_CONF}");
our $dbname     = $GAZETTE{DB_NAME};
our $dbtable    = "gazette";
our %GAZETTECAT = readCfg("$GAZETTE{CATEGORIES_FILE}");
foreach (keys %GAZETTECAT) {
	delete $GAZETTECAT{$_} if (!WebObs::Users::clientHasRead(type=>"authmisc",name=>"GAZETTE$_") && !WebObs::Users::clientHasRead(type=>"authmisc",name=>"GAZETTE")); 
}
our $allCATlist = join(',',keys(%GAZETTECAT));
our @editableCat;
if ( WebObs::Users::clientHasEdit(type=>"authmisc",name=>"GAZETTE")) { @editableCat = grep { !/EVENT/i } split(/,/,$allCATlist) }
else { @editableCat = grep { !/EVENT/i && WebObs::Users::clientHasEdit(type=>"authmisc",name=>"GAZETTE$_") } split(/,/,$allCATlist) }
our $maxdate    = '2038-01-18';
our $calweekn   = (defined($GAZETTE{CALENDAR_WEEKNUMBER})) ? $GAZETTE{CALENDAR_WEEKNUMBER} : "";  # VERTICAL or anything
our $ongoing    = (defined($GAZETTE{SHOW_BYDATE_ONGOING})) ? $GAZETTE{SHOW_BYDATE_ONGOING} : "TEXT";
our $tdtrunc    = (defined($GAZETTE{CALENDAR_TRUNCLENGTH})) ? $GAZETTE{CALENDAR_TRUNCLENGTH} : 25;

use constant { 
	# column indexes for a full DB table row array
	G_ID        => 0,
	G_STARTDATE => 1,
	G_STARTTIME => 2,
	G_ENDDATE   => 3,
	G_ENDTIME   => 4,
	G_CATEGORY  => 5,
	G_UID       => 6,
	G_OTHERS    => 7,
	G_PLACE     => 8,
	G_SUBJECT   => 9,
	G_LASTUPD   => 10,
	G_LASTUPDUID => 11,
};

# -------------------------------------------------------------------------------------------

=pod

=head1 FUNCTIONS

=head2 Show 

Builds html code to display Gazette articles for a given period.

Returns an array of html strings. 

	Show(view=>, from=>, to=>, categories=>, textfilter=>, jseditor=>, jsevent=>)

Arguments:

	Required:
		view=>        { calendar | datelist | categorylist | ical | dump | stats}
		from=>        YYYY-MM-DD start date

	Optional:
		to=>          YYYY-MM-DD end date (defaults to from)
		categories=>  { '' | 'categoryName(,categoryName(,...))' }
		textfilter=>  regexp to keep matching articles
		jseditor=>    a javascript function name to be called when click on article for edition;
		              automatically passed arguments will be (this,article's ID).
		jsevent=>     a javascript function name to be called when click on 'event' article;
		              automatically passed argument will be (objectname), ie: (gridtype.gridname[.nodename]).

=cut

sub Show {
	# parse/check arguments
	my %KWARGS = @_; 
	return undef if ( !exists($KWARGS{view}) || !($KWARGS{view} =~ /calendar|datelist|categorylist|ical|dump|stats/i) );
	return undef if ( !exists($KWARGS{from}) );
	my $dtfrom = eval { Time::Piece->strptime($KWARGS{from},'%Y-%m-%d');} or return undef;
	my $dtto = $dtfrom;
	if ( exists($KWARGS{to}) ) { 
		$dtto = eval { Time::Piece->strptime($KWARGS{to},'%Y-%m-%d');} or return undef;
		if ($KWARGS{view} =~ /calendar/i && $dtfrom == $dtto ) { $KWARGS{view} = "day" } 
	}
	my $filter = (exists($KWARGS{textfilter})) ? quotemeta $KWARGS{textfilter} : "";
	my $jsedit = (exists($KWARGS{jseditor})) ? $KWARGS{jseditor} : "";
	my $jsevent = (exists($KWARGS{jsevent})) ? $KWARGS{jsevent} : "";
	my @html = ();
	# @cat : valid and $CLIENT-readable categories (all or within $KWARGS{categories} subset)
	# $incat : @cat suitable for an sql select IN clause
	my $categories = (!exists($KWARGS{categories}) || $KWARGS{categories} =~ /^$|all/i) ? $allCATlist : $KWARGS{categories};
	my @cat = grep { exists($GAZETTECAT{$_}) && (WebObs::Users::clientHasRead(type=>"authmisc",name=>"GAZETTE$_") || WebObs::Users::clientHasRead(type=>"authmisc",name=>"GAZETTE") ) } split(/,/,$categories);
	return @html if (@cat == 0) ;
	my $incat = join( ',', map { "'$_'" } @cat);
	# build holidays for $dtfrom year and $dtto year
	my @daysoff = (WebObs::Dates::readFeries(conf=>"$WEBOBS{FILE_DAYSOFF}",year=>$dtfrom->year));
	push(@daysoff,WebObs::Dates::readFeries(conf=>"$WEBOBS{FILE_DAYSOFF}",year=>$dtto->year)) if ($dtfrom->year != $dtto->year);
	my $today = new Time::Piece;

	# ---- Show as weekly calendar -----------------------------------------------------------

	if ($KWARGS{view} =~ /calendar/i ) {
		# make sure $dtfrom and $dtto are week boundaries
 	  	$dtfrom = $dtfrom - (($dtfrom->day_of_week+6)%7)*86400;
	  	$dtto   = $dtto + ((0-$dtto->day_of_week)%7)*86400;
		my $articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtto->strftime('%Y-%m-%d'), categories=>$incat, order=> 'startdate,starttime,category');
		if ($filter ne "") { @$articles = grep { (@$_[7..9] =~ /$filter/i) } @$articles }

		# from 'number of weeks displayed' in requested date frame, derive the preceeding and next date frames
			my $wn = ($dtto->epoch - $dtfrom->epoch)/(60*60*24*7); # nb of weeks in requested date frame
			# previous date frame is same nunber of weeks before requested frame's start
			my $prevdtto = $dtfrom-86400 + ((0-($dtfrom-86400)->day_of_week)%7)*86400;
			my $prevdtfrom = $prevdtto-(86400*7*$wn) -((($prevdtto-(86400*7*$wn))->day_of_week+6)%7)*86400;
			# next date frame is same number of weeks after requested frame's end
			my $nextdtfrom = $dtto+86400 -((($dtto+86400)->day_of_week+6)%7)*86400;
			my $nextdtto = $nextdtfrom+(86400*7*$wn) + ((0-($nextdtfrom+(86400*7*$wn))->day_of_week)%7)*86400;
		my $prevrange=$prevdtfrom->strftime('%Y-%m-%d').",".$prevdtto->strftime('%Y-%m-%d');
		my $prevw=sprintf("w%02s",$prevdtfrom->week); if ($prevdtto->week ne $prevdtfrom->week) { $prevw .= sprintf(",w%02s",$prevdtto->week) }; 
		my $nextrange=$nextdtfrom->strftime('%Y-%m-%d').",".$nextdtto->strftime('%Y-%m-%d');
		my $nextw=sprintf("w%02s",$nextdtfrom->week); if ($nextdtto->week ne $nextdtfrom->week) { $nextw .= sprintf(",w%02s",$nextdtto->week) }; 
		my $prevnextbar =  "<span class=\"gzt-pnbar\"><img src=\"/icons/l13.png\"/><a href=\"/cgi-bin/Gazette.pl?gdate=$prevrange&gview=calendar\"><sup>$prevw</sup></a></span>";
		   $prevnextbar .= "<span class=\"gzt-pnbar\" style=\"float: right;\"><a href=\"/cgi-bin/Gazette.pl?gdate=$nextrange&gview=calendar\"><sup>$nextw</sup></a><img src=\"/icons/r13.png\"/></span>";
		my $caltr = "";
		push(@html, "<div width=\"100%\" class=\"gzt-pndiv\">$prevnextbar</div>");
		my $ww;  #  week first day's Time::Piece object
		for ( my $w=$dtfrom, my $cnt=0; $w<=$dtto; $w+=7*86400, $cnt++) {  # for each week starting on $w 
			my $altclass = ($cnt%2 == 0) ? 'even' : 'odd';
			push(@html,"\n<table class='gzt-cal $altclass'>\n");
			# identify week (iso notation)
			if ($calweekn eq "VERTICAL") {
				push(@html,"<tr>\n");
				push(@html,"<th class=\"gzt-calweekvert\">".$w->strftime('%G-w%V')."</th>");
				$caltr = "<tr><td style=\"border: none;\"></td>\n";
			} else {
				push(@html,'<tr><td class="gzt-calweekhead" colspan="7">'.$w->strftime('%G-w%V').'</td></tr>');
				$caltr = "<tr>\n";
				push(@html,$caltr);
			}
			# 1 row to identify each day of week
			for ($ww=$w; $ww<$w+(7*86400); $ww+=86400 ) {
				my $dclass=""; my $tst = $ww->strftime('%Y-%m-%d');
				$dclass .= "\"holidays\"" if (grep(/$tst/,@daysoff));
				$dclass .= " today" if ($tst eq $today->strftime('%Y-%m-%d'));
				$dclass = "class=$dclass" if($dclass ne "");
				push(@html,"<th $dclass>".l2u($ww->strftime('%a %d %b'))."</th>"); 
			}
			my @prehtml = ([(undef)x7]);
			# now 1 row per article occuring this week and identified by its result-set-array index
			my $actualRowsInWeek = 0;
			my @ixs = ixApplicable($articles,$w,$w+(6*86400));  # all articles indexes in result set this week
			for my $ix (@ixs) { # for each article
				my $art = @{$articles}[$ix];
				my $artstart = Time::Piece->strptime($art->[G_STARTDATE],'%Y-%m-%d');
				my $artend = ($art->[G_ENDDATE] eq '') ? Time::Piece->strptime($maxdate,'%Y-%m-%d') : Time::Piece->strptime($art->[G_ENDDATE],'%Y-%m-%d');
				if ($artstart != $artend) { 
					# article spans n-days ==> 1 row per article & 'long' <td>
					push(@html,$caltr);$actualRowsInWeek++;
					my $dur = 1+($artend-$artstart)/86400;
					my $before = (($artstart-$w)/86400); if ($before <= 0) { $dur += $before;  $before = 0; };
					my $item   = ($dur,7-$before)[$dur > 7-$before]; 
					my $after  = 7 - ($before+$item);

					push(@html, "<td class='gzt-emptytd' colspan='$before'></td>") if ($before > 0);

					my $tdtext = calendarTD($w, $art, $artstart, $artend); # td contents
					my $bgcolor = "transparent"; # td 'no-category' color just in case
					if ( $art->[G_CATEGORY] ne "" ) { 
						$bgcolor = defined($GAZETTECAT{$art->[G_CATEGORY]}{RGBlight}) ? $GAZETTECAT{$art->[G_CATEGORY]}{RGBlight} : "lightgrey"; 
					}
					my $tip = articleTip($art);
					my $click = "";
					if ($jsedit ne "") {
						$click = (grep { /$art->[G_CATEGORY]/ } @editableCat) ? "onclick=\"$jsedit(this,$art->[G_ID]);\"" : "";
					}
					if ($click eq "" && $art->[G_CATEGORY] =~ /EVENT/i && $jsevent ne "") {
						$click = "onclick=\"$jsevent('$art->[G_PLACE]')\"";
					}
					my $attr = " colspan='$item' onMouseOver='showtip(event,\"$GAZETTECAT{$art->[G_CATEGORY]}{Name}\",\"$tip\",\"$GAZETTECAT{$art->[G_CATEGORY]}{RGBlight}\")' onMouseOut='hidetip()' style='word-wrap: break-word; background-color: $bgcolor' $click ";
					push(@html, "<td $attr>$tdtext</td>");
					
					push(@html, "<td class='gzt-emptytd' colspan='$after'></td>") if ($after > 0);
				} else { 
					# article spans 1-day ==> optimize placement (less rows) for this single <td>.
					# @prehtml initially represents an empty week row (ie. 7 <td> spots) populated as required with articles;
					# number of rows grows as required (ie. when new articles use already populated spots). 
					my $i = ($artstart-$w)/86400; 
					my $done=0; 
					for my $row (@prehtml) { 
						if (!defined($row->[$i])) { $row->[$i] = [($w,@{$articles}[$ix],$artstart)]; $done=1; last } 
					} 
					if (!$done) { push(@prehtml,[(undef)x7]); $prehtml[-1]->[$i]= [($w,@{$articles}[$ix],$artstart)] }
				}
			}
			# format the @prehtml rows , adding them to calendar
			for my $row (@prehtml) {
				push(@html,$caltr);$actualRowsInWeek++;
				for my $d ($row) {
					for my $i (0..6) {
						if (defined($d->[$i])) {
							my ($w, $art, $artstart) = @{$d->[$i]};
							my $tdtext = calendarTD($w, $art, $artstart, $artstart);
							my $bgcolor = "transparent";
							if ( $art->[G_CATEGORY] ne "" ) { 
								$bgcolor = defined($GAZETTECAT{$art->[G_CATEGORY]}{RGBlight}) ? $GAZETTECAT{$art->[G_CATEGORY]}{RGBlight} : "lightgrey"; 
							}
							my $tip = articleTip($art);
							my $click = "";
							if ($jsedit ne "") {
								$click = (grep { /$art->[G_CATEGORY]/ } @editableCat) ? "onclick=\"$jsedit(this,$art->[G_ID]);\"" : "";
							}
							if ($click eq "" && $art->[G_CATEGORY] =~ /EVENT/i && $jsevent ne "") {
								$click = "onclick=\"$jsevent('$art->[G_PLACE]')\"";
							}
				    		my $attr = " onMouseOver='showtip(event,\"$GAZETTECAT{$art->[G_CATEGORY]}{Name}\",\"$tip\",\"$GAZETTECAT{$art->[G_CATEGORY]}{RGBlight}\")' onMouseOut='hidetip()' style='word-wrap: break-word;background-color: $bgcolor' $click ";
							push(@html, "<td $attr>$tdtext</td>");
						} else {
							push(@html, "<td class='gzt-emptytd'></td>");
						}
					}
				}
			}
			if ($calweekn eq "VERTICAL") {
				push(@html, "<tr><td style=\"border: none;\"></td><td class=\"gzt-emptytd\" colspan=7></td></tr>") for (1..3-$actualRowsInWeek); # make week have 3 rows minimum
				push(@html,"\n</table>\n");
			} else {
				push(@html,"\n</table>\n");
			}
		}
		push(@html, "<div width=\"100%\" class=\"gzt-pndiv\">$prevnextbar</div>");
		return @html;
	}

	# ---- Show one day, calendar like -------------------------------------------------------

	if ($KWARGS{view} =~ /day/i) {
		my $articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtfrom->strftime('%Y-%m-%d'), categories=>$incat, order=> 'startdate,starttime,category');
		if ($filter ne "") { @$articles = grep { (@$_[7..9] =~ /$filter/i) } @$articles }

		my $prevday=($dtfrom-86400)->strftime('%Y-%m-%d');
		my $nextday=($dtfrom+86400)->strftime('%Y-%m-%d');
		my $prevnextbar =  "<span class=\"gzt-pnbar\"><img src=\"/icons/l13.png\"/><a href=\"/cgi-bin/Gazette.pl?gdate=$prevday&gview=calendar\"><sup>$prevday</sup></a></span>";
		   $prevnextbar .= "<span class=\"gzt-pnbar\" style=\"float: right;\"><a href=\"/cgi-bin/Gazette.pl?gdate=$nextday&gview=calendar\"><sup>$nextday</sup></a><img src=\"/icons/r13.png\"/></span>";
		push(@html, "<div width=\"100%\" class=\"gzt-pndiv\">$prevnextbar</div>");
		push(@html,"<table class='gzt-cal'>");
		push(@html,'<tr><td class="gzt-calweekhead">'.l2u($dtfrom->strftime("$__{'gzt_fmt_long_date'}")).'</td></tr>');
		# now 1 row per article
		for my $art (@{$articles}) {
			push(@html,'<tr>');

			my $tdtext = "";
			$tdtext .= articleTimes($art,$art->[G_STARTDATE]);
			$tdtext .= $art->[G_SUBJECT]."&nbsp;";
			$tdtext .= articleWho($art)."&nbsp;";
			my $bgcolor = "transparent"; # td 'no-category' color just in case
			if ( $art->[G_CATEGORY] ne "" ) { 
				$bgcolor = defined($GAZETTECAT{$art->[G_CATEGORY]}{RGBlight}) ? $GAZETTECAT{$art->[G_CATEGORY]}{RGBlight} : "lightgrey"; 
			}
			# TODO: mouseover
			my $tip = articleTip($art);
			my $click = "";
			if ($jsedit ne "") {
				$click = (grep { /$art->[G_CATEGORY]/ } @editableCat) ? "onclick=\"$jsedit(this,$art->[G_ID]);\"" : "";
			}
			if ($click eq "" && $art->[G_CATEGORY] =~ /EVENT/i && $jsevent ne "") {
				$click = "onclick=\"$jsevent('$art->[G_PLACE]')\"";
			}
			my $attr = " onMouseOver='showtip(event,\"$art->[G_CATEGORY]\",\"$tip\",\"$GAZETTECAT{$art->[G_CATEGORY]}{RGBlight}\")' onMouseOut='hidetip()' style='background-color: $bgcolor' $click ";
			push(@html, "<td $attr>$tdtext</td>");
		}
		push(@html,'</table>');
	
		return @html;
	}

	# ---- Show by date --------------------------------------------------------

	if ($KWARGS{view} =~ /datelist/i) { 
		my $articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtto->strftime('%Y-%m-%d'), categories=>$incat, order=> 'startdate,starttime,category');
		if ($filter ne "") { @$articles = grep { (@$_[7..9] =~ /$filter/i) } @$articles }
	
		for ( my $d=$dtfrom, my $cnt=0; $d<=$dtto; $d+=86400, $cnt++) {  # for each day starting on $d 
			my $ymd = $d->strftime('%Y-%m-%d');
			my $dayhtml = "";
			my @ixs = ixApplicable($articles,$d);  # all articles indexes in result set, this day
			for my $ix (@ixs) { # for each article
				my $li = "";
				# find wether article starts or ends on currently processed day
				if ($ymd eq @{$articles}[$ix]->[G_STARTDATE] || $ymd eq @{$articles}[$ix]->[G_ENDDATE]) {
					if ($ymd eq @{$articles}[$ix]->[G_STARTDATE] && $ymd eq @{$articles}[$ix]->[G_ENDDATE]) {
						$li .= '<li style="list-style-image:url(/icons/stop.gif)">'.articleTimes(@{$articles}[$ix],$ymd)."&nbsp;";
					} else {
						if ($ymd eq @{$articles}[$ix]->[G_STARTDATE]) { 
							my $until = @{$articles}[$ix]->[G_ENDDATE] eq '' ? "$__{'from now on'}" : "$__{until} @{$articles}[$ix]->[G_ENDDATE]";
							$li .= '<li style="list-style-image:url(/icons/start.gif)">'."<i><b>$until</b></i>&nbsp;";
						} elsif ($ymd eq @{$articles}[$ix]->[G_ENDDATE]) {
							$li .= '<li style="list-style-image:url(/icons/end.gif)">'."<i><b>$__{since} @{$articles}[$ix]->[G_STARTDATE]</b></i>&nbsp;";
						}
					}
				} else {
					# not starting nor ending this day => report depending on SHOW_BYDATE_ONGOING variable
					if ($ongoing !~ /NO/i) {
						$li .= '<li style="list-style-image:url(/icons/play.gif)">';
						$li .= "<i><b>$__{'on going'}</b></i>&nbsp;" if ($ongoing =~ /TEXT/i);
						$li .= "<i><b>$__{'since'} @{$articles}[$ix]->[G_STARTDATE] $__{until} @{$articles}[$ix]->[G_ENDDATE]</b></i>&nbsp;" if ($ongoing =~ /DATE/i);
					} else { next; } 
				}
				my $rqcat = @{$articles}[$ix]->[G_CATEGORY];
				$li .= "<span style=\"color:$GAZETTECAT{$rqcat}{RGB};\"><b>$GAZETTECAT{$rqcat}{Name}</b></span>&nbsp;";
				$li .= "<i>@{$articles}[$ix]->[G_PLACE]</i>&nbsp;";
				$li .= "- @{$articles}[$ix]->[G_SUBJECT]&nbsp;";
				$li .= "- ".articleWho(@{$articles}[$ix])."&nbsp;" ;
				if ($jsedit ne "") {
					$li .= (grep { /@{$articles}[$ix]->[G_CATEGORY]/ } @editableCat) ? "<img style=\"cursor: pointer\" src=\"/icons/modif.png\" onclick=\"$jsedit(this,@{$articles}[$ix]->[G_ID]);\"" : "" ;
				}
				$li .= "</li>";
				$dayhtml .= $li;
			}
			if ($dayhtml ne "") { # found things to display for this day
				push(@html, "<h3>".l2u($d->strftime("$__{gzt_fmt_date}"))."</h3>"."<ul class=\"gzt-list\">$dayhtml</ul>");
			}

		}
		return @html;
	}

	# ---- Show by category ------------------------------------------------

	if ($KWARGS{view} =~ /categorylist/i) { 
		my $articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtto->strftime('%Y-%m-%d'), categories=>$incat, order=> 'category,startdate,starttime');
		if ($filter ne "") { @$articles = grep { (@$_[7..9] =~ /$filter/i) } @$articles }

		my $currentCat = ""; 
		for my $art (@{$articles}) {  # for each article (ordered by category)
			if ($art->[G_CATEGORY] ne $currentCat) {
				push(@html,"</ul>") if ($currentCat ne ""); 
				$currentCat = $art->[G_CATEGORY];
				push(@html, "<h3>$GAZETTECAT{$currentCat}{Name}</h3><ul>");
			}
			my $htmlDate = "";
			if ($art->[G_STARTDATE] eq $art->[G_ENDDATE]) {
				if ($art->[G_STARTTIME] eq "" && $art->[G_ENDTIME] eq "") { $htmlDate .= $art->[G_STARTDATE]; }
				elsif ($art->[G_STARTTIME] ne "" && $art->[G_ENDTIME] eq "") { $htmlDate .= "$art->[G_STARTDATE] ($art->[G_STARTTIME])" }
				elsif ($art->[G_STARTTIME] eq "" && $art->[G_ENDTIME] ne "") { $htmlDate .= "$art->[G_STARTDATE] (&rArr; $art->[G_ENDTIME])"}
				else { $htmlDate .= "$art->[G_STARTDATE] ($art->[G_STARTTIME] &rArr; $art->[G_ENDTIME])" }
			} else {
				if ($art->[G_STARTTIME] eq "" && $art->[G_ENDTIME] eq "") { $htmlDate .= "$art->[G_STARTDATE] - $art->[G_ENDDATE]" }
				elsif ($art->[G_STARTTIME] ne "" && $art->[G_ENDTIME] eq "") { $htmlDate .= "$art->[G_STARTDATE] ($art->[G_STARTTIME]) " }
				elsif ($art->[G_STARTTIME] eq "" && $art->[G_ENDTIME] ne "") { $htmlDate .= "$art->[G_STARTDATE] - $art->[G_ENDDATE] ($art->[G_ENDTIME])"}
				else { $htmlDate .= "$art->[G_STARTDATE] ($art->[G_STARTTIME]) - $art->[G_ENDDATE] ($art->[G_ENDTIME])" }
			}

			#articleWho() returns : [user1, user2] + others
			my $allNames = articleWho($art);
			my ($htmlNames,$htmlOthers) = split(/ \+ /,$allNames);

			my $htmlLi = "";
			if ($GAZETTECAT{$currentCat}{Format} eq "ndol") {
				$htmlLi .= "<B>$htmlNames</B> - [$htmlDate] - $art->[G_SUBJECT] - <I>$art->[G_PLACE]</I>";
			} 
			elsif ($GAZETTECAT{$currentCat}{Format} eq "ndlo") {
				$htmlLi .= "<B>$htmlNames</B> - [$htmlDate] - <I>$art->[G_PLACE]</I> - $art->[G_SUBJECT]";
			}
			elsif ($GAZETTECAT{$currentCat}{Format} eq "ldon") {
				$htmlLi .= "<B>$art->[G_PLACE]</B> - [$htmlDate] - $art->[G_SUBJECT] - <I>$htmlNames</I>";
			}
			elsif ($GAZETTECAT{$currentCat}{Format} eq "dlon") {
				$htmlLi .= "<B>$htmlDate - $art->[G_PLACE]</B> - $art->[G_SUBJECT] - <I>$htmlNames</I>";
			}
			elsif ($GAZETTECAT{$currentCat}{Format} eq "andol") {
				$htmlLi .= "<B>$htmlOthers".($htmlNames ne "" ? ($htmlOthers ne "" ? ", ":"")."$htmlNames":"")."</B> - [$htmlDate] - $art->[G_SUBJECT] - <I>$art->[G_PLACE]</I>";
			}
			elsif ($GAZETTECAT{$currentCat}{Format} eq "adon") {
				$htmlLi .= "<B>$htmlOthers</B> - [$htmlDate] - $art->[G_SUBJECT] - [$htmlNames]";
			} else {
				$htmlLi .= "<B>$art->[G_PLACE]</B> - [$htmlDate] - $art->[G_SUBJECT] - <I>$htmlNames</I>";
			} 
			my $editicon = "";
			if ($jsedit ne "") {
				$editicon = (grep { /$art->[G_CATEGORY]/ } @editableCat) ? "<img style=\"cursor: pointer\" src=\"/icons/modif.png\" onclick=\"$jsedit(this,$art->[G_ID]);\"" : "" ;
			}
			push(@html, "<LI style=\"color:$GAZETTECAT{$currentCat}{RGB}\"><SPAN style=\"color:black\">$htmlLi</SPAN>&nbsp;$editicon</LI>\n");
		}
		push(@html, "</ul>") if (@html);
		return @html;
	}

	# ---- Show raw selection for admins only------------------------------------------------
	
	if ($KWARGS{view} =~ /dump/i && WebObs::Users::clientHasAdm(type=>"authmisc",name=>"GAZETTE")) {
		my $articles;
		if ($KWARGS{categories} =~ /^$|all/i) { # for dump, 'all' really means 'any' (known or unknown) categories 
			$articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtto->strftime('%Y-%m-%d'), order=> 'startdate,starttime,category');
		} else {
			$articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtto->strftime('%Y-%m-%d'), categories=>$incat, order=> 'startdate,starttime,category');
		}
		if ($filter ne "") { @$articles = grep { (@$_[7..9] =~ /$filter/i) } @$articles }
		push(@html,"<TABLE class=\"gzt-dump\"><tr><th>ID<th>STARTDATE<th>STARTTIME<th>ENDDATE<th>ENDTIME<th>CATEGORY<th>UID<th>OTHERS<th>PLACE<th>SUBJECT<th>Updated<th>UpdID</tr>");
		for my $art (@{$articles}) {  # each article
			push(@html, "<tr><td>".join('<td>', map { "$art->[$_]" } (0..11))."</tr>\n");
		}	
		push(@html, "</TABLE>");
		return @html;
	}

	# ---- Show statistics for admins only------------------------------------------------
	
	if ($KWARGS{view} =~ /stats/i && WebObs::Users::clientHasAdm(type=>"authmisc",name=>"GAZETTE")) {
		my ($dbh, $sql, $sth, $art);

		$dbh = DBI->connect( "dbi:SQLite:".$dbname,"","")
				or die "DB error connecting to ".$dbname.": ".DBI->errstr;
		$dbh->{PrintError} = 1; $dbh->{RaiseError} = 1;

		push(@html,"<p>Figures below apply to full Gazette (ie. selection criteria do NOT apply)</p>");

		$sql =  "select count(*) from $dbtable";
		$sth = $dbh->prepare($sql);
		$sth->execute();
		my $rsCountRows = $sth->fetchall_arrayref();
		push(@html,"<TABLE><tr><th>Total number of articles</th></tr>");
		for $art (@{$rsCountRows}) {  
			push(@html, "<tr><td>$art->[0]</tr>\n");
		}	
		push(@html, "</TABLE>");
		push(@html, "<BR>");

		$sql =  "select category, count(*) from $dbtable where category in (select distinct(category)) group by category order by category";
		$sth = $dbh->prepare($sql);
		$sth->execute();
		my $rsCountCategories = $sth->fetchall_arrayref();
		push(@html,"<TABLE><tr><th>Category<th>in CATEGORIES_FILE<th>Number of articles</tr>");
		for $art (@{$rsCountCategories}) { 
			my $catdef = "undefined";
			$catdef = "defined" if (exists($GAZETTECAT{$art->[0]}));
			push(@html, "<tr><td>$art->[0]</td><td>$catdef</td><td>$art->[1]</td></tr>\n");
		}	
		push(@html, "</TABLE>");

		$dbh->disconnect;
		return @html;
	}

	# ---- Show as iCal ---------------------------------------------------------------------
	
	if ($KWARGS{view} =~ /ical/i) {
		my $articles = getRaw(from=>$dtfrom->strftime('%Y-%m-%d'), to=>$dtto->strftime('%Y-%m-%d'), categories=>$incat, order=> 'startdate,starttime,category');
		if ($filter ne "") { @$articles = grep { (@$_[7..9] =~ /$filter/i) } @$articles }

		push(@html,"BEGIN:VCALENDAR\n");
		push(@html,"PRODID:-//webobs.ipgp.fr/gazette//EN\n");
		push(@html,"VERSION:2.0\n");
		for my $art (@{$articles}) {  # each article
			# if "startdate starttime" can't parse : ignore article
			# if "enddate endtime" can't parse : behave like no enddate specified
			my $ds = eval { Time::Piece->strptime($art->[G_STARTDATE]." ".$art->[G_STARTTIME],'%Y-%m-%d %H:%M') } or next;
			my $de = eval { Time::Piece->strptime($art->[G_ENDDATE]." ".$art->[G_ENDTIME],'%Y-%m-%d %H:%M') } or $art->[G_ENDDATE] = "";
			push(@html, "BEGIN:VEVENT\n");
				push(@html, "SUMMARY:$art->[G_SUBJECT]\n");
				push(@html, "DTSTART:".$ds->datetime."\n");
				if ($art->[G_ENDDATE] eq '') {
					push(@html, "RRULE:FREQ=DAILY\n");
				} else {
					push(@html, "DTEND:".$de->datetime."\n");
				}
				push(@html, "LOCATION:$art->[G_PLACE]\n");
				push(@html, "CATEGORIES:$art->[G_CATEGORY]\n");
				my $id = $art->[G_UID]; $id =~ s/\+.*//; # take first id only
				push(@html, "UID:$USERS{$USERIDS{$id}}{EMAIL}\n");
			push(@html, "END:VEVENT\n");
		}
		push(@html, "END:VCALENDAR");

		my $icsfn = "Gazette_".$WebObs::Users::CLIENT."_".$dtfrom->strftime('%Y-%m-%d')."_".$dtto->strftime('%Y-%m-%d').".ics";
		my $icsrc = "";
		if (open(WRT,">$WEBOBS{PATH_TMP_APACHE}/$icsfn")) {
			print WRT @html;
			close(WRT);
			$icsrc = "$__{'saved as'} $icsfn";
		} else { $icsrc = "$__{'not saved'}" }

		#unshift(@html, "<h3>$icsrc</h3>");
		unshift(@html, "<A href=\"#\" onClick=\"javascript:window.open('/cgi-bin/Gazette.pl?getical=$WEBOBS{PATH_TMP_APACHE}/$icsfn')\" title=\"Download this iCal to your box\">Download</A><br>\n");
		
		s/\n/<br>/ for @html;
		return @html;
	}
}

# -------------------------------------------------------------------------------------------

=pod

=head2 getRaw 

SQL select ordered raw Gazette articles, matching a date range and category.
getRaw returns a reference to resulting array of articles.

NOTE: checkings for valid and user-authorized categories, if desired, must be handled by getRaw caller.  

Arguments: 

	Required: 
		from=>       startdate YYYY-MM-DD 
		to=>         enddate YYYY-MM-DD 

	Optional:
		categories=> sql 'in' clause, ie. if omitted or '' will select all categories  
		order=>      sql 'order by' clause

Example:

	$Gazette = WebObs::Gazette::getRaw(from=>'2014-12-26',to=>'2015-01-20',order=>'STARTDATE,ENDDATE');
	print("Number of articles = ".@{$Gazette}."\n");
	map { print join(", ",@{$_}), "\n" } @{$Gazette};  # print each article with comma-separated fields 

=cut 

sub getRaw {
	my %KWARGS = @_;
	return 0 if ( !exists($KWARGS{from}) || !exists($KWARGS{to}) );
	my ($rs, $dbh, $sql, $sth);

	$dbh = DBI->connect( "dbi:SQLite:".$dbname,"","")
			or die "DB error connecting to ".$dbname.": ".DBI->errstr;
	$dbh->{PrintError} = 1; $dbh->{RaiseError} = 1;

	$sql =  "SELECT ID,STARTDATE,STARTTIME,ENDDATE,ENDTIME,CATEGORY,UID,OTHERS,PLACE,SUBJECT,LASTUPD,LASTUPDUID ";
	$sql .= "FROM $dbtable " ; 
	$sql .= "WHERE STARTDATE <= '".$KWARGS{to}."' AND (ENDDATE = '' OR ENDDATE >= '".$KWARGS{from}."') ";
	$sql .= "AND CATEGORY IN (".$KWARGS{categories}.")" if (exists($KWARGS{categories}) && $KWARGS{categories} ne '');
	$sql .= " ORDER BY $KWARGS{order}" if exists($KWARGS{order});
	$sth = $dbh->prepare($sql);
	$sth->execute();
	$rs = $sth->fetchall_arrayref();
	$dbh->disconnect;
	return $rs;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 setArticle

Insert or replace an article in DB. Required argument is a full article's row (except LASTUPD* columns), 
as a string suitable for an SQL insert 'values' clause.  

=cut

sub setArticle {
	return 0 if (@_ != 1);
	my ($dbh, $sql, $rv);

	my $values = "$_[0],datetime('now'),'$USERS{$CLIENT}{UID}'"; 
	$dbh = DBI->connect( "dbi:SQLite:".$dbname,"","") or die "DB connect to ".$dbname." failed: ".DBI->errstr;
	$sql = "INSERT OR REPLACE INTO $dbtable VALUES( $values )";
	$rv = $dbh->do($sql);
	$rv = 0 if ($rv == 0E0); 
	$rv = sprintf("%d row%s  %s",$rv,($rv<=1)?"":"s",$DBI::errstr);

	$dbh->disconnect;
	return $rv;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 setEventArticle

Insert or replace an 'Event' category article in DB. 
Required arguments are the Event's objectname, filename, title, usernames string and end date_time
to build the article fields.
setEventArticle will then use setArticle().  
Also refer to vedit.pl for Event management considerations.

	objectname: GRIDType.GRIDName[.NODEName]. 
	filename:   NODEName_YYYY-MM-DD_HH-MM[_version].txt  or 
	            GRIDName_YYYY-MM-DD_HH-MM[_version].txt

=cut

sub setEventArticle {
	return 0 if (@_ != 5);
	my ($object, $evname, $titre, $oper,$eve) = @_;
	(my $evp = $evname) =~ s/\.txt//;
	my ($en,$ed,$et,$ev) = split(/_/,basename($evp));
	my ($ed2,$et2) = split(/_/,$eve);
	$et = ($et eq "NA") ? "" : $et;
	$et =~ s/-/:/;
	$titre = "(v$ev) $titre" if (defined($ev));
	$titre =~ s/'/''/g;
	my $values = sprintf("%s,'%s','%s','%s','%s','%s','%s','%s','%s','%s'",
				 "null",
				 $ed,
				 $et,
				 $ed2,
				 $et2,
				 "Event",
				 $oper,
				 '',
				 $object,
				 $titre);
	my $row = setArticle($values);
	return $row;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 delArticle

Delete an article in DB. Required argument is article's ID

=cut

sub delArticle {
	return 0 if (@_ != 1);
	my ($dbh, $sql, $rv);

	$dbh = DBI->connect( "dbi:SQLite:".$dbname,"","") or die "DB connect to ".$dbname." failed: ".DBI->errstr;
	$sql = "DELETE FROM $dbtable WHERE ID= $_[0]";
	$rv = $dbh->do($sql);
	$rv = 0 if ($rv == 0E0); 
	$rv = sprintf("(%d row%s) %s",$rv,($rv<=1)?"":"s",$DBI::errstr);

	$dbh->disconnect;
	return $rv;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 delEventArticle

Delete an 'Event' article in DB. Required arguments are the Event's objectname and filename.
This function identifies the article by contents (ie. date,time,,category,place,[version]), NOT its
internal ID column.
Also refer to vedit.pl for Event management considerations.

	objectname: GRIDType.GRIDName[.NODEName]. 
	filename:   NODEName_YYYY-MM-DD_HH-MM[_version].txt  or 
	            GRIDName_YYYY-MM-DD_HH-MM[_version].txt

Returns 0 or number of rows deleted. 

=cut

sub delEventArticle {
	return 0 if (@_ != 2);
	my ($object,$evname) = @_;
	(my $evp = $evname) =~ s/\.txt//;
	my ($en,$ed,$et,$ev) = split(/_/,basename($evp));
	$et = "" if ($et eq "NA");
	$et =~ s/-/:/;

	my $where .= "STARTDATE = '$ed' ";
	$where .= "AND STARTTIME = '$et' ";
	$where .= "AND CATEGORY = 'Event' ";
	$where .= "AND PLACE = '$object' ";
	$where .= "AND SUBJECT LIKE '(v$ev)%'" if (defined($ev));

	my ($rs, $dbh, $sql, $sth);
	my $rv = 0;

	$dbh = DBI->connect( "dbi:SQLite:".$dbname,"","")
			or die "DB error connecting to ".$dbname.": ".DBI->errstr;
	$dbh->{PrintError} = 1; $dbh->{RaiseError} = 1;

	$sql =  "DELETE FROM $dbtable WHERE $where" ;
	$rv = $dbh->do($sql);
	$rv = 0 if ($rv == 0E0); 

	$dbh->disconnect;
	return $rv;
}

# -------------------------------------------------------------------------------------------

=pod

=head2 getArticle

get one article as a JSON object. Required argument is article's ID.

=cut

sub getArticle {
	return 0 if (@_ != 1);
	my $id = $_[0];
	my ($rs, $dbh, $sql, $sth);
	my $row = "";

	$dbh = DBI->connect( "dbi:SQLite:".$dbname,"","")
			or die "DB error connecting to ".$dbname.": ".DBI->errstr;
	$dbh->{PrintError} = 1; $dbh->{RaiseError} = 1;

	$sql =  "SELECT ID,STARTDATE,STARTTIME,ENDDATE,ENDTIME,CATEGORY,UID,OTHERS,PLACE,SUBJECT ";
	$sql .= "FROM $dbtable WHERE ID=$_[0]" ; 
	$sth = $dbh->prepare($sql);
	$sth->execute();
	while ($rs = $sth->fetchrow_hashref()) {
		while ((my $key, my $value) = each(%$rs)){
			$value =~ s/\Q"\E/&quot;/g;
			$row .= "\"$key\": \"$value\",";
		}
	}
	$row =~ s/,$//;
	$dbh->disconnect;
	return "{ $row }";
}

# -------------------------------------------------------------------------------------------

=pod 

=head2 

articleTimes(articleRef,ymd) returns html string representing an article's start and end times,
intended to only report times on start and end day of a range (suitable for week calendar displays) 
'articleRef' is a reference to the article; 'ymd' is the YYYY-MM-DD display we are currently processing.

=cut 

sub articleTimes {
	return undef if (@_ != 2) ;
	my $ptr = $_[0]; my $ymd = $_[1];
	my $ret = "";
	if ($ptr->[G_STARTDATE] eq $ptr->[G_ENDDATE]) {
		if (($ptr->[G_STARTTIME] ne "") || ($ptr->[G_STARTTIME] ne "")) {
			$ret = "<B>$ptr->[G_STARTTIME]</B>&rArr;<B>$ptr->[G_ENDTIME]</B>&nbsp;";
  		}
	} else {
		if ($ymd eq $ptr->[G_STARTDATE] && $ptr->[G_STARTTIME] ne "") {
  			$ret = "<B>$ptr->[G_STARTTIME]</B>&rArr;&nbsp;";
		}
		if ($ymd eq $ptr->[G_ENDDATE] && $ptr->[G_ENDTIME] ne "") {
  			$ret = "&rArr;<B>$ptr->[G_ENDTIME]</B>&nbsp;";
		}
  	}
	return $ret;
}

# -------------------------------------------------------------------------------------------

=pod 

=head2

articleWho(articleRef) returns the html string "[fullNames of UIDs] + others",
ie. expanded G_UID and G_OTHERS columns of the article referenced by 'articleRef'
eg. [user1, user2] + others

=cut 

sub articleWho {
	return undef if (@_ != 1);
	my $art = $_[0]; my $listFullNames = "";
	if ($art->[G_UID] ne "") {
		$listFullNames = "[".join(', ', map { WebObs::Users::userName($_)} split(/\+/,$art->[G_UID]))."]";
	}
	if ($art->[G_OTHERS] ne "") { 
		#$listFullNames .= " + $art->[G_OTHERS]";
		(my $o = $art->[G_OTHERS]) =~ s/ \+ / , /g; # "+" to commas, because "+" used to split later
		$listFullNames .= " + ".($o); 
	}
	return $listFullNames;
}

# -------------------------------------------------------------------------------------------

=pod 

=head2

calendarTD(w, art, artstart, artend) internal helper to return a calendar td contents 
for article 'art' in week 'w'

=cut 

sub calendarTD {
	return undef if (@_ != 4) ; my ($w, $art, $artstart, $artend) = @_;
	my $tdtext = my $t1 = my $r1 = "";
	if ($artstart == $artend) {
	    $tdtext .= ("$art->[G_STARTTIME]$art->[G_ENDTIME]" ne "") ? "<B>$art->[G_STARTTIME]</B>&rArr;<B>$art->[G_ENDTIME]</B>&nbsp;" : "";
	} else {   
	    $tdtext .= ($artstart >= $w && $artstart <= $w+6*86400 && "$art->[G_STARTTIME]" ne "") ? "<div class='gzt-tleft'><B>$art->[G_STARTTIME]</B>&rArr; </div>" : ""; 
	}
	$t1 = substr($art->[G_SUBJECT],0,$tdtrunc); $t1 =~ s/\Q"\E/&quot;/g; 
	if (length($art->[G_SUBJECT])>$tdtrunc) { $r1 = rindex($t1," "); $t1 = sprintf("%s&#8230;",($r1>0)?substr($t1,0,$r1):$t1) }
	$t1 =~ s/\Q'\E/&apos;/g; $tdtext .= "$t1 ";
	$t1 = substr($art->[G_UID],0,$tdtrunc); $t1 =~ s/\Q"\E/&quot;/g;
	if (length($art->[G_UID])>$tdtrunc) { $r1 = rindex($t1,"+"); $t1 = sprintf("%s&#8230;",($r1>0)?substr($t1,0,$r1):$t1) }
	$t1 =~ s/\Q'\E/&apos;/g; $tdtext .= (length($t1)>0) ? "[$t1] " : " ";
	$t1 = substr($art->[G_OTHERS],0,$tdtrunc); $t1 =~ s/\Q"\E/&quot;/g; 
	if (length($art->[G_OTHERS])>$tdtrunc) { $r1 = rindex($t1," "); $t1 = sprintf("%s&#8230;",($r1>0)?substr($t1,0,$r1):$t1) }
	$t1 =~ s/\Q'\E/&apos;/g; $tdtext .= "$t1 ";

	if ($artstart != $artend) {
	    $tdtext .= ($artend >= $w && $artend <= $w+6*86400 && "$art->[G_ENDTIME]" ne "") ? "<div class='gzt-tright'> &rArr; <B>$art->[G_ENDTIME]</B> </div>" : "";
	}
	return $tdtext;
}

# -------------------------------------------------------------------------------------------

=pod 

=head2

articleTip(article) internal helper to return the tip (popup) contents for article 'art'

=cut 

sub articleTip {
	return undef if (@_ != 1);
	my $art = $_[0]; my $text = ""; my $qq = "";
	$text .= "<b>$__{'Who'}: </b>$art->[G_UID]<br>";
	($qq = $art->[G_SUBJECT]) =~ s/\Q"\E/&Prime;/g; $text .= "<b>$__{'Subject'}: </b>$qq<br>";
	$text .= "<b>$__{'Date'}: </b>$art->[G_STARTDATE] $art->[G_STARTTIME] &rArr; $art->[G_ENDDATE] $art->[G_ENDTIME]<br>";
	($qq = $art->[G_PLACE]) =~ s/\Q"\E/&Prime;/g; $text .= "<b>$__{'Place'}: </b>$qq<br>";
	$text =~ s/\Q'\E/&apos;/g;
	return $text;
}
					
# -------------------------------------------------------------------------------------------

=pod 

=head2 

ixApplicable(rs,from,to) list the articles indexes of a getRaw() result set array corresponding to articles appearing in the [from-to] period.
The list of 'applicable' indexes of 'rs' is returned as an array. 

	Required arguments:
	rs     Reference to a getRaw() result set array
	from   Time::Piece object of the first day of the period as a Time::Piece object
	to     Time::Piece object of the  last day of the period; if omitted, will default to from

	@ix = ixApplicable(\@Gazette, $fromTimePiece, $toTimePiece);
	# printing all corresponding article-IDs ([G_ID]) would then be :
	map { print "@{$Gazette}[$_]->[G_ID]\n" } @ix;
	
=cut 

sub ixApplicable {
	return undef if (@_ < 2) ;
	my ($rs, $dtfrom) = @_ ;
	my $dtto = (@_ == 3) ? $_[2] : $dtfrom;
	my $f = $dtfrom->strftime('%Y-%m-%d'); my $t = $dtto->strftime('%Y-%m-%d');
	return grep { @{$rs}[$_]->[G_STARTDATE] le $t && (@{$rs}[$_]->[G_ENDDATE] ge $f || @{$rs}[$_]->[G_ENDDATE] eq '') } (0..@{$rs}-1);
}

1;

__END__

=pod

=head1 AUTHOR

Didier Lafon, François Beauducel

=head1 COPYRIGHT

Webobs - 2012-2017 - Institut de Physique du Globe Paris

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
				
