
package WebObs::Wiki;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

use WebObs::Wiki

$htmltxt = WebObs::Wiki::wiki2html($wikitxt);

$newtxt  = WebObs::Wiki::wiki2MMD($wikitxt);

($cleantxt,$metadata) = WebObs::Wiki::stripMDdetadata($txt);

=head1 DESCRIPTION

WebObs::Wiki::wiki2html() converts either a WebObs's legacy wiki string OR
a MultiMarkdown string to an html string.

The input string is considered as the concatenation of lines of a markup file with '\n'
preserved as line delimiter.

WebObs::Wiki::wiki2html() automatically determines wether
input string has to be processed as MultiMarkDown or WebObs legacy markup.
Input string is MMD when it starts with any MultiMarkdown MetaData block of lines:
consecutive lines of 'key:value' pair, ending with a blank line.
See MultiMarkdown MetaData documentation for additional information.

WebObs::Wiki::wiki2MMD() is used to convert legacy WebObs' Wiki to MultiMarkdown syntax.

WebObs::Wiki::stripMDmetadata() extracts mdedata section from text string (the wiki file contents);
returns ($MDtext-without-metadata, $MDmetadata). It is used to tell wether a file may contain MMD markup
( length($MDmetadata) > 0 ) or legacy webobs markup ( length($MDmetadata) = 0 ).

=head1 MMD and WO

- A file will be considered "MMD" (to be parsed for MMD markup) when it contains a MMD-Metadata section ie.:
at top of file, consecutive lines with metadata as key:value pairs, up to and including a blank line.
Note that WebObs::Wiki uses the special 'WebObs:' metadata (whose value has currently no special meaning);

- metadata section follow the syntax as described in http://fletcher.github.io/MultiMarkdown-4/metadata.html ,
with these special considerations:

	- keys are case sensitive
	- keys are NOT 'compressed', ie. embedded blanks are preserved in keys
	- must contain one 'WebObs:' key , otherwise input will be considered has NOT having metadata
	- WO's specific 'TITRE.*|xxx' optional as very first line of $txt is stripped off (ie.
	  ignored, so that MMD parsing/markup is allowed after a TITRE*| )
	- non 'key:value' lines preceeding a valid metadata section will be discarded

- WebObs extra line containing the special tags TITRE and TITRE_HTML (always 1st line) are still recognized,
even for MMD files: WebObs::Wiki ignores it; any associated processing must be handled outside of Wiki processing.

=head1 Converting WO legacy wiki language to MMD

The conversion routine wiki2MMD() (thus the wiki2mmd.pl tool that uses it) may
slightly modify the author original formatting intentions:

- WebObs drawer is not supported, converted as header level 2 + paragraph.

- Underscoring not supported, converted to strong

- First row of table will automatically be considered as the header of table.

- Paragraphs and line breaks differs in MMD. Extracted from Markdown documentation: A paragraph is simply one or more consecutive lines of text,
separated by one or more blank lines [...] The implication of the “one or more consecutive lines of text” rule
is that Markdown supports “hard-wrapped” text paragraphs [...].

Line breaks will not be translated as <br> tag. Inserting a <br>, requires that you
end the line with two or more spaces, then line break.

=cut

use strict;
use warnings;
use WebObs::Utils qw(u2l l2u);
use WebObs::Config qw(%WEBOBS readCfg);
use WebObs::Grids;
use WebObs::Users;
if ($WEBOBS{WIKI_MMD} ne 'NO') {
	require Text::MultiMarkdown;
}

our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);
require Exporter;
@ISA        = qw(Exporter);
@EXPORT     = qw(stripMDmetadata wiki2html wiki2MMD );
$VERSION    = "1.00";

sub wiki2html {
	(my $string = $_[0]) =~ s/^TITRE(_HTML)*\|.*\n//;
	(my $clean, my $meta) = stripMDmetadata($string);
	if (length($meta) == 0) { wiki($clean) } else { markdown($string) };
}

#dl-was:isub stripMDmetadata {
#dl-was:	if (defined($_[0]) && $_[0] ne "") {
#dl-was:		my @tt = split /(?<=\n)/, $_[0];
#dl-was:		$tt[0] =~ /^TITRE(_HTML)*\|.*\n/ and shift(@tt);
#dl-was:		my @meta = ();
#dl-was:		if ($WEBOBS{WIKI_MMD} eq 'NO') { return (join("",@tt),@meta) };
#dl-was:		foreach my $line (@tt) {
#dl-was:			$line =~ /^\s*$/ and (scalar @meta > 0) and push(@meta, $line) and last;
#dl-was:			$line =~ /^([a-zA-Z0-9][0-9a-zA-Z _-]+?):.*$/ and push(@meta, $line) and next;
#dl-was:			if (scalar @meta > 0) { push(@meta, $line) } else { last }
#dl-was:		}
#dl-was:		for (1..scalar(@meta)) { shift(@tt) }
#dl-was:		return (join("",@tt),@meta);
#dl-was:	}
#dl-was:}

sub stripMDmetadata {
	if (defined($_[0]) && $_[0] ne "") {
		(my $txt = $_[0]) =~ s/^TITRE(_HTML)*\|.*\n//;
		return ($txt,"") if (defined($WEBOBS{WIKI_MMD}) && $WEBOBS{WIKI_MMD} eq 'NO');
		return ($txt, "") if ($txt !~ /\n\s*\n/);           # no blank line means no chance for metadata
		(my $head, my $tail) = split /\n\s*\n/ , $txt, 2;   # head up to 1st blank line
		my @head = split /\n(.+):/,"\n$head";               # hashes metadata key:value pairs
		shift @head;                                        # ...
		my %hash = @head;                                   # ...
		return ($txt,"") if (!keys %hash || !$hash{WebObs}); # no keys or no WebObs key = no metadata
		return ($tail, "$head\n\n");
	} else {
		return ('', '');
	}
}

=head2 WebObs Wiki language specifications:

=over

=item  //text//        text italics

=item  **text**        text bold

=item  __text__        text underscored

=item  ""text""        text quoted (citation)

=item  - text          bullet list

=item  # text          numbered list

=item  %%wwname%%      include WebObs WEB/ file wwwname

=item  ~~title:text~~  text into a WebObs drawer named title

=item  ||col1||col2||  table row, two columns

=item  [linktext]{url} hypertext link with its url

=item  {{STATION}}     hypertext link to display STATION

=item  {{{imgname}}}   include imgname img (uri addressed)

=item  ----            horizontal line

=item  ====text====    text as a small heading (h4)

=item  ===text===      text as a medium heading (h3)

=item  ==text==        text as a large heading (h2)

=item +text            text is continuation of previous wiki line text

=item text\            continuation + HTML line break (<BR>)

=item $WEBOBS{var}     replaced with WEBOBS.rc configuration variable 'var'

=back

=cut

sub wiki {

 	my $txt = $_[0];
	$txt.="\n";

	# --- include wiki files
	$txt =~ s[\%\%(.*?)\%\%] { wfcheck($1); }egis;

	# --- remove ending ^M's
	$txt =~ s/\cM\n/\n/g;

	# --- \ ==> <br>
	$txt =~ s/\\\n/<br>/g;

	# --- ----  ==> horizontal line <hr>
	$txt =~ s/----/<HR>/g;

	# --- || ==> <table>
	$txt =~ s/\|\|(.*)\|\|\n/<__row__><TD>$1\n/g;            # all lines ||...||\n are temporary rows
	$txt =~ s/\|\|/<TD>/g;                                   # then all || are <td>
	$txt =~ s/<__row__>(.*?)\n(?!<__row__>)/<TABLE><TR>$1<\/TABLE>\n/sg; # now enclose successive rows in table tags
	$txt =~ s/<__row__>/<TR>/g;                              # take care of leftover temporary rows

	# --- - ==>  <ul></ul>
	$txt =~ s/^-/\n-/;	        # to find start of list
	$txt =~ s/([^\n]$)/$1\n/;	# to find end of list
	$txt =~ s/\n-((?:.|\n)+?)\n([^-]|$)/\n<UL><LI>$1<\/UL>$2/g;
	$txt =~ s/\n-/<li>/g;

	# --- # ==>  <ol></ol>
	$txt =~ s/^#/\n#/;	        # to find start of list
	$txt =~ s/([^\n]$)/$1\n/;	# to find end of list
	$txt =~ s/\n#((?:.|\n)+?)\n([^#]|$)/\n<OL><LI>$1<\/OL>$2/g;
	$txt =~ s/\n#/<LI>/g;

	# --- [linkname]{url} ==> <a href=url>linkname</a>
	$txt =~ s/\[(.*?)]\{(https?:\/\/.*?)\}/<A HREF="$2" target="_blank">$1<\/A>/g;
	$txt =~ s/\[(.*?)]\{(.*?)\}/<A HREF="$2">$1<\/A>/g;

	# --- {{{image}}} ==> <img src=image/>
	$txt =~ s/\{\{\{(.*?)\}\}\}/<IMG SRC=\"$1\"\/>/g;

	# --- {{STATION}} ==> <a href to cgi-displaynode for NODE>
	$txt =~ s/\{\{(.+?)\}\}/<B><A HREF="\/cgi-bin\/$NODES{CGI_SHOW}\?node=$1">$1<\/A><\/B>/g;

	if (WebObs::Users::clientHasAdm(type=>'authmisc',name=>'CONFIG')) {
	# --- automatic links to WEBOBS configuration files
	# --- if not immediately preceeded with a /, some filename-like strings will generate an href
		$txt =~ s/\b(?<!\/)(\w+\.conf\b)/<A HREF="$WEBOBS{ROOT_CONF}\/$1">$1<\/A>/g;
		$txt =~ s/\b(?<!\/)(\w+\.rc\b)/<A HREF="$WEBOBS{ROOT_CONF}\/$1">$1<\/A>/g;
		$txt =~ s/\b(?<!\/)(\w+\.m)\b/<a HREF="$WEBOBS{ROOT_CODE}\/matlab\/$1">$1<\/A>/g;
		$txt =~ s/\b(?<!\/)(\w+\.p[l|m]\b)/<A HREF="$WEBOBS{ROOT_CODE}\/cgi-bin\/$1">$1<\/A>/g;
	}

	# --- + ==> \n+ used as line continuation character (dont want to html break on newline)
	$txt =~ s/\n\+//g;

	# --- cleanup (to allow html coding...)
	$txt =~ s/>\s*</></g;
	$txt =~ s/>\n/>/g;
	$txt =~ s/<BR>\n/\n/ig;

	# --- ====small heading====  ==> <h4>small heading</h4>
	#was: $txt =~ s/\=\=\=\=(.*?)\=\=\=\=\n/<H4>$1<\/H4>/g;
	$txt =~ s/\=\=\=\=(.*?)\=\=\=\=/<H4>$1<\/H4>/g;

	# --- ===medium heading===  ==> <h3>medium heading</h3>
	#was: $txt =~ s/\=\=\=(.*?)\=\=\=\n/<H3>$1<\/H3>/g;
	$txt =~ s/\=\=\=(.*?)\=\=\=/<H3>$1<\/H3>/g;

	# --- ==large heading==  ==> <h2>large heading</h2>
	#was: $txt =~ s/\=\=(.*?)\=\=\n/<\/BLOCKQUOTE><H2>$1<\/H2><BLOCKQUOTE>/g;
	$txt =~ s/\=\=(.*?)\=\=/<H2>$1<\/H2>/g;

	# --- \n ==> <br> (after this substitution, no more \n so syntax applies to multiple lines)
	$txt =~ s/\n/<BR>/g;

	# --- **bold text** ==> <b>bold text</b>
	$txt =~ s/\*\*(.*?)\*\*/<B>$1<\/B>/g;

	# --- //italic// ==> <i>italic</i>
	$txt =~ s/(http|https|ftp|file):\/\//$1:_DoubleSlash_/g;	# temporary substitution of URLs //...
	$txt =~ s/\/\/(.*?)\/\//<I>$1<\/I>/g;
	$txt =~ s/_DoubleSlash_/\/\//g;					            # backup of // ...

	# --- __underscore__ ==> <u>underscore</u>
	$txt =~ s/__(.*?)__/<U>$1<\/U>/g;

	# --- ~~title:contents~~ ==> drawer labelled title and its contents
	$txt =~ s[~~(.*?)\:(.*?)~~] { drawer($1,$2); }egis;

	# --- ""citation"" ==> <blockquote>citation</blockquote>
	$txt =~ s/""(.*?)""/<BLOCKQUOTE class="typewriter">$1<\/BLOCKQUOTE>/g;

	return $txt;

	# --- variables expansion : $WEBOBS{xx}
	#$txt =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g;
}

sub wfcheck{
	my $bfn = $_[0];
	my $ret = "";
	if ($bfn ne "") {
		my $absbfn = "$WEBOBS{PATH_DATA_WEB}/$bfn";
		if ( -f $absbfn ) {
			if ( WebObs::Users::clientHasRead(type=>'authwikis',name=>$bfn) ) {
				if (open(RDR, "<$absbfn")) {
					$ret .= $_ while(<RDR>);
					close RDR;
					return qq[$ret];
				} else { return qq[ couldn't open $bfn ] }
			} else { return qq[ ] } # not authorized ==> ignore include
		} else { return qq[ $bfn not found ] }
	} else { return qq[ invalid include filename ] }
}

sub drawer {
	my ($title,$contents) = @_;
	my $ret = "";
	if (defined($title) && defined($contents)) {
		my ($dID,$junk) = split(/ /,$title);
		$ret .= "<div class=\"drawer\"><div class=\"drawerh2\" >";
		$ret .= "&nbsp;<img src=\"/icons/drawer.png\" onClick=\"toggledrawer('\#$dID');\">&nbsp;&nbsp;$title";
		$ret .= "</div><div style=\"padding-left: 5px;\" id=\"$dID\">";
		$ret .= $contents;
		$ret .= "</div></div>";
		return qq[$ret];
	} else { return qq[ invalid drawer definition ] }
}

sub markdown {
	require Text::MultiMarkdown;
	my $m = Text::MultiMarkdown->new(strip_metadata => 1,);
	my $html = $m->markdown($_[0]);

	# WebObs MMD post-processing:
	# simple replacement of pre-defined WebObs tags with 'operational' strings,
	# NOT modifying the html structure.

	$html =~ s/\$WebObsNode/\/cgi-bin\/showNODE.pl?node/g;

	return $html;
}

=head2 MultiMarkdown specifications:

See "perldoc Text::MultiMarkdown" for Copyright and License.

See "https://github.com/fletcher/MultiMarkdown/wiki/MultiMarkdown-Syntax-Guide" for syntax.

=cut

sub wiki2MMD {

	my $txt = $_[0];
	if ($WEBOBS{WIKI_MMD} ne 'NO') {

		# --- \ ==> forces <br />
		$txt =~ s/\\\n/  \n/g;

		# --- || ==> table, first row will be header row (didn't exist in webobs)
		$txt =~ s[^(\|\|.*\|\|(?!\n\|\|))] { table($1) }emsg;

		# --- horizontal rule, first pass: ---- ==> !+!+!+!
		$txt =~ s/\n----/\n!+!+!+!/g;

		# --- ul, - ==> *
		$txt =~ s/\n-((?:.|\n)+?)\n([^-]|$)/\n\n* $1  \n$2/g;
		$txt =~ s/\n-/\n* /g;

		# --- ol, # ==> 1.
		$txt =~ s/\n#((?:.|\n)+?)\n([^-]|$)/\n\n1. $1  \n$2/g;
		$txt =~ s/\n#/\n1. /g;

		# --- [linkname]{url} ==> <a href=url>linkname</a>
		#$txt =~ s/\[(.*?)]\{(https?:\/\/.*?)\}/<A HREF="$2" target="_blank">$1<\/A>/g;
		$txt =~ s/\[(.*?)]\{(.*?)\}/[$1]($2)/g;

		# --- {{{image}}} ==> <img src=image/>
		$txt =~ s/\{\{\{(.*?)\}\}\}/![]($1)/g;

		# --- {{STATION}} ==> <a href to cgi-displaynode for NODE>
		$txt =~ s/\{\{(.+?)\}\}/[$1](\$WebObsNode=$1)/g;

		# --- automatic links to WEBOBS configuration files
		# --- if not immediately preceeded with a /, some filename-like strings will generate an href
		#	$txt =~ s/\b(?<!\/)(\w+\.conf\b)/<A HREF="$WEBOBS{ROOT_CONF}\/$1">$1<\/A>/g;
		#	$txt =~ s/\b(?<!\/)(\w+\.rc\b)/<A HREF="$WEBOBS{ROOT_CONF}\/$1">$1<\/A>/g;
		#	$txt =~ s/\b(?<!\/)(\w+\.m)\b/<a HREF="$WEBOBS{ROOT_CODE}\/matlab\/$1">$1<\/A>/g;
		#	$txt =~ s/\b(?<!\/)(\w+\.p[l|m]\b)/<A HREF="$WEBOBS{ROOT_CODE}\/cgi-bin\/$1">$1<\/A>/g;

		# --- + ==> not useful anymore
		$txt =~ s/\n\+/\n/g;

		# --- headings 2-4 anywhere on line ==> Atx-style alone on line
		$txt =~ s/\=\=\=\=(.*?)\=\=\=\=/\n#### $1\n/g;
		$txt =~ s/\=\=\=(.*?)\=\=\=/\n### $1\n/g;
		$txt =~ s/\=\=(.*?)\=\=/\n## $1\n/g;

		# --- \n ==> NOT <br> anymore (MMD has “hard-wrapped” text paragraphs)

		# --- MMD supports emphasis+strong with * or _ (and double *, double _)
		# --- **bold text** ==> compatible, leave as is
		# --- __underscore__ ==> leave as is, but will now be <strong> (no more underscore)
		# --- //italic// ==> em (single _)
		# BUT for all above, remove space(s) right after and before markup (eg. ** x ** becomes **x**)
		$txt =~ s/\*\*\s*(.*?)\s*\*\*/**$1**/g;
		$txt =~ s/__\s*(.*?)\s*__/__$1__/g;
		$txt =~ s/\/\/\s*(.*?)\s*\/\//_$1_/g;

		# --- include wiki files => file transclusion {{some_other_file.txt}}
		$txt =~ s/\%\%(.*?)\%\%/{{$1}}/gis;

		# --- ~~title:contents~~ ==> drawer no more supported, changed to h2+paragraph
		$txt =~ s[~~(.*?)\:(.*?)~~] {## $1\n$2  }gis;

		# --- ""citation"" ==> >
		$txt =~ s/""(.*?)""/>$1  \n/g;

		# --- horizontal rule, second pass: !+!+!+! ==> ***
		$txt =~ s/\n!\+!\+!\+!/\n***/g;
	}
	return $txt;

}

# helpers for table syntax conversion
sub table{ (my $xx=$_[0])=~s/\|\|/\|/g; $xx=~s[(\|.*\n)] {hdr($1)}e; qq[$_[0]$xx]};
sub hdr { (my $yy=$_[0])=~s/\|(?!$)/\|---/g; $yy=~s/[^|-]//g; qq[$yy\n]};

1;

__END__

=pod

=head1 AUTHOR

Francois Beauducel, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2016 - Institut de Physique du Globe Paris

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
