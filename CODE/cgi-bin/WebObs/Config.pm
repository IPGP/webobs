package WebObs::Config;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

	use WebObs::Config;

	$file = $WEBOBS{FILE_MYFILENAME};  # using %WEBOBS definitions
	%myHash = readCfg($file);          # reading a key|value configuration file

	use CGI::Carp qw(fatalsToBrowser set_message);
	set_message(\&webobs_cgi_msg);     # using the dedicated cgi error messages formatter

=head1 DESCRIPTION

Provides the main Webobs configuration hash B<%WEBOBS> 
and subroutine B<readCfg> to read/parse other configuration files.

WebObs::Config also defines the B<"WebObs specific cgi error messages"> that any
script is free to use or not. Aka B<webobs_cgi_msg> (entry-point) it is also
customized thru html definitions residing in the file pointed to by the 
$WEBOBS{CGI_MSG} variable.

B<readCfg> internally uses the base B<readFile> function, also publicly available,
reading any file into an array, providing access control thru Perl's B<flock> locking 
interface. 

Configuration files (usually *.conf; *.cnf or *.rc) typically define one 
functionnal parameter (C<key>) per line, made up of one or more associated values
(C<fields>). When read with B<readCfg>, those lines are subject to the 
following rules for parsing/interpretation:

Rule #1 : any text following a # is considered a comment and discarded 

Rule #2 : blank lines are discarded, leading and trailing blanks too

Rule #3 : fields separator character, within interpreted lines, is | (pipe)

Rule #4 : | and # characters that should belong to a field value may be 
          'escaped' (ie. not interpreted as speparator or comment resp.) 
          by prefixing them with \ 

Rule #5 : a so-called 'definition line' (= in column 1) may be present as the 
          first interpreted line, to further define how each line will be 
          interpreted and fields returned:

            V=readCfg("afile.rc");
            =key|value           : V is a %hash, $V{key} => value
            =key|name1|...|nameN : V is a %HoH, $V{key}{nameI} => value
            no definition line   : V is an @AoA

Rule #6 : field value substitution is allowed in =key|value form: 
          ${key} in a value field will be replaced by the value of the key|value pair of the current file.

            REFKEY|/main/path
            ANOTHERKEY|${REFKEY}/down/to/filename
            will create: $hash{ANOTHERKEY} => /main/path/down/to/filename

Rule #7 : line continuation (ie. field value spanning more than one line), if desired, 
          is specified by a \ (backslash) as the last character of a line.
		  Note: leading and trailing spaces in each line are preserved.
		  Example:

		    LONGLIST|Element1,\
			         Element2,\
			Element3
			is equivalent to: LONGLIST|Element1,         Element2,Element3					 


Rule #8 : configuration files are all considered ISO-8859-15 (latin) encoded

=head1 GLOBAL VARIABLES

=head2 %WebObs::WEBOBS

The main Webobs configuration hash, automatically built from B</etc/webobs.d/WEBOBS.rc>
(/etc/webobs.d is the symbolic link to the actual Webobs-install-time/user-defined directory for configuration files). 
WEBOBS.rc B<must> be of the '=key|value' form (see above).

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Fcntl qw(:flock SEEK_SET SEEK_END O_NONBLOCK O_WRONLY O_RDWR);
use File::Basename;
use WebObs::Utils qw(u2l l2u);
use CGI::Carp qw(fatalsToBrowser);
    
our(@ISA, @EXPORT, $VERSION, %WEBOBS, $WEBOBS_LFN);
require Exporter;
@ISA     = qw(Exporter);
@EXPORT  = qw(%WEBOBS readFile xreadFile readCfgFile readCfg webobs_cgi_msg);
$VERSION = "2.00";
 
my $confF1 = "/etc/webobs.d/WEBOBS.rc";
if (-e $confF1) {
	%WEBOBS   = readCfg($confF1) ;
	$WEBOBS_LFN = "from $confF1 (".(stat($confF1))[9].")";
}

our $cgi_msg_html = "";
if ( defined($WEBOBS{CGI_MSG}) && -e $WEBOBS{CGI_MSG} ) {
	if (open(FILE, "<$WEBOBS{CGI_MSG}")) {
		while(<FILE>) { $cgi_msg_html .= $_ }
		close(FILE);
	}
} else {
	$cgi_msg_html = "<img src='/icons/ipgp/logo_OVS50.png'><b> Webobs error</b>";
}

sub webobs_cgi_msg {                                                                                                                                                   
	my $msg = shift;
	print $cgi_msg_html;
	$msg =~ s/\n/ /g; # \n once found nullifying the following match
	$msg =~ /^(.*)( at.*line.*)/;
	my $p1 = "<b>$1</b><br>";
	my $p2 = "<span style=\"font-size:10pt\">".basename($2)." on ".localtime(time())."<\/span>";
	print "<p style=\"border: 1px solid black; font-size: 12pt; padding: 5px\">$p1</p>$p2";
}


=pod

=head2 readFile

	# reading all lines from filepath/filename into @lines:
	@lines = readFile("filepath/filename");

	# reading all lines starting with 1130| from /filepath/filename into @lines :
	$filter = qr/^1130\|/;
	@lines = readFile("/filepath/filename",$filter);

Reads file contents (optionaly filtered with $filter regex reference) into an array.
All lines are read unfiltered, uninterpreted, unchanged.
Does B<NOT> attempt to convert lines to UTF8, B<NOR> does it chomp lines.
readFile blocks until it acquires a shared lock on the file to be read. 

=cut 

sub readFile
{
	my $File=$_[0];
	my @raw; my @contenu;
	my $line = "";
	if (-f $File) {
		open(FILE, "<$File") || die "couldn't open file $File. $!";
		unless ( flock(FILE, LOCK_SH | LOCK_NB)) {
			warn "waiting for lock on $File...";
			flock(FILE, LOCK_SH);
		}
		seek(FILE, 0, SEEK_SET);
		if (@_ == 2) { while(<FILE>) { push(@raw,$_) if ($_ =~ /$_[1]/) } }
		else         { while(<FILE>) { push(@raw,$_)}  }
		close(FILE); # close automatically releases LOCK
	}
	for (@raw) { $line .= $_; if (m/\\(\r\n|\n)$/) { $line =~ s/\\(\r\n|\n)$// } else { push(@contenu,$line); $line='' } }
	return @contenu;
}

=pod

=head2 xreadFile

eXtended readFile(). Performs same functions as readFile, but returns 
both 1) a reference to the file contents and 2) the 'last-modified-timestamp' of the file 

	# reading all lines from filepath/filename :
	($ptr, $ts) = readFile("filepath/filename");
	print "filepath/filename timestamped ".strftime("%F %T",localtime($ts)).":\n @$ptr";

Follows all other rules of readFile().

Why would you choose xreadFile() ? The last-modified-timestamp caught under flock control at read time
might be used as a check for externally modified data between reading and later updating of the file.
Reference (pointer) to file contents might help perf/storage on huge files.  

=cut 

sub xreadFile
{
	my $File=$_[0];
	my @raw; my @contenu; my $ts='';
	my $line = "";
	if (-f $File) {
		open(FILE, "<$File") || die "couldn't open file $File. $!";
		unless ( flock(FILE, LOCK_SH | LOCK_NB)) {
			warn "waiting for lock on $File...";
			flock(FILE, LOCK_SH);
		}
		$ts = (stat($File))[9];
		seek(FILE, 0, SEEK_SET);
		if (@_ == 2) { while(<FILE>) { push(@raw,$_) if ($_ =~ /$_[1]/) } }
		else         { while(<FILE>) { push(@raw,$_)}  }
		close(FILE); # close automatically releases LOCK
	}
	for (@raw) { $line .= $_; if (m/\\(\r\n|\n)$/) { $line =~ s/\\(\r\n|\n)$// } else { push(@contenu,$line); $line='' } }
	return (\@contenu, $ts);
}

=pod

=head2 readCfgFile

	@lines = readCfgFile("[filepath/]filename");

reads file contents into an array, converting lines to UTF8, 
and removing commented lines (# in col1), blank lines, and all \r (CR).

=cut 

sub readCfgFile
{
	my $configFile = $_[0];
	my $utf8 = $_[1];
	my @raw; my @contenu;
	my $line = "";
	my @fraw = readFile($configFile);
	for (@fraw) {
		$_ =~ s/\r//g;
		chomp($_);
		push(@contenu,($utf8 ? $_:l2u($_)));
	}
	@contenu = grep(!/^#/, @contenu);
	@contenu = grep(!/^$/, @contenu);
	for (@raw) { $line .= $_; if (m/\\(\r\n|\n)$/) { $line =~ s/\\(\r\n|\n)$// } else { push(@contenu,$line); $line='' } }
	return @contenu;
}

=pod

=head2 readCfg

	%lines = readCfg("[filepath]/filename");  # for key|value[|value...] files
	%lines = readCfg("[filepath]/filename",'sorted'); # adds $lines{}{_SO_} (sort order)

	@lines = readCfg("[filepath]/filename");  # other files

reads in a configuration file (defaults to main webobs WEBOBS.conf 
if none is specified). See DESCRIPTION above for a description of readCfg interpretation rules

=cut

sub readCfg
{
	my $fn   = $_[0];
	my $sort = grep( /^sorted$/, @_[1..$#_] );
	my $escape = grep ( /^escape$/, @_[1..$#_] );
	my $nowovsub = grep ( /^nowovsub$/, @_[1..$#_] );
	my $id = 0;
	my (@df, @wrk, $i, $l, %H, @A);
	my @fraw = readFile($fn);
	chomp(@fraw);
	for (@fraw) {
		s/(?<!\\)#.*//g;            # remove comments (everything after unescaped-#)
		s/(^\s+)||(\s+$)//g;        # remove leading & trailing blanks
		s/\r//g;                    # remove all CRs not only in CRLF
		next if /^$/ ;              # ignore empty lines
		if (m/^=([^ ]*)/) {			# got a definition line ?
			@df = split(/\|/);		# save it
			next;					# and forget it
		}
		$l = l2u($_);				# force utf8 !
		@wrk = split(/(?<!\\)\|/,$l);  # parse with unescaped-| as delim 
		if (!$escape) { s/\\//g for(@wrk) };          # remove escape chars (\)
		if (@df == 2) {             # key|value ? build Hash
			$H{$wrk[0]} = $wrk[1];
			next;
		}
		if (@df > 2) {              # key|val1|...|valN ? build an HoH
			for ($i = 1; $i < @df; $i++) {
				$H{$wrk[0]}{$df[$i]} = $wrk[$i];
			}
			$H{$wrk[0]}{_SO_} = sprintf("%03d",++$id) if ($sort);
			next;
		}
		push(@A, [@wrk]);           # otherwise build an AoA
	}
	if (@A) { return @A; }
	if (%H) { 
		no warnings "uninitialized";
		for my $key (keys %H) { $H{$key} =~ s/[\$][\{](.*?)[\}]/$H{$1}/g; }
		# need two passes, last one also handling %WEBOBS substitution  
		for my $key (keys %H) {
			$H{$key} =~ s/[\$][\{](.*?)[\}]/$H{$1}/g; 
			if (!$nowovsub) { $H{$key} =~ s/[\$]WEBOBS[\{](.*?)[\}]/$WEBOBS{$1}/g; }
		}	
		use warnings;
		return %H; 
	}
}

=pod

=head2 notify

Sends an event notification to the WebObs postboard for dispatching to registered users or processes.

Internally sends B<notifications requests> to the B<postboard> named pipe.
This named pipe is defined by the $WEBOBS{POSTBOARD_NPIPE} configuration parameter and the 
postboard.pl process is acting as a daemon waiting for notifications requests to process them asap.

Requests, as sent by processes, are strings representing the 3-tuple 'event-name|sender-id|message' ('|' delimiting
the elements). notify adds the current timestamp (UTC elapsed seconds since Epoch) to this input, 
resulting in the following request
being sent to postboard pipe: B<'timestamp|event-name|sender-id|message'>

See the postboard.pl perldoc for more information on 'timestamp|event-name|sender-id|message' request interpretation. 

Note: notify translates all '\n' to 0x00 in the request being sent over the pipe; postboard will
translate them back after request is pulled out of the pipe.

Return codes from notify:

	96   can't open postboard named pipe (fifo)
	97   no request specified (nothing to send)
	98   postboard named pipe is unknown (no definition in config.) 
	99   notification request has an invalid format 

=cut

sub notify {
	my $rc;

	if (defined($WEBOBS{POSTBOARD_NPIPE})) {
		if ( defined($_[0]) ) {
			my $msg = $_[0];
			my @cmd = (time, split(/\|/, $msg)); 
			if (scalar(@cmd) == 4) {
				if ( sysopen(FIFO, "$WEBOBS{POSTBOARD_NPIPE}", O_NONBLOCK|O_WRONLY) ) {
					$msg = join('|',@cmd);
					$msg =~ tr/\n/\0/;  # avoid \n over the pipe !!
					print (FIFO "$msg\n");
					close(FIFO);
					$rc = 0;
				} else { $rc = 96 } # can't open fifo
			} else { $rc = 99 } # request has invalid format 
		} else { $rc = 97 } # nothing to send
	} else { $rc = 98 }	# fifo not defined

	return $rc;
}

1;

__END__

=pod

=head1 AUTHOR

Didier Mallarino, Francois Beauducel, Alexis Bosson, Didier Lafon

=head1 COPYRIGHT

Webobs - 2012-2014-2014 - Institut de Physique du Globe Paris

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
