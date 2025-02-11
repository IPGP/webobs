package WebObs::Form;

=head1 NAME

Package WebObs : Common perl-cgi variables and functions

=head1 SYNOPSIS

    use WebObs::Form;
    $F = new WebObs::Form('EAUX');

    # Path to FORMSdirectory/thisform
    # eg: /webobs/site/path/to/forms/EAUX
    print $F->path;     

    # full name of FORM's data file
    # eg: /webobs/site/data/EAUX.DAT
    print $F->fnam

    # any parameter from FORM's conf file
    # eg: CGI_SHOW : showEAUX.pl
    print $F->conf(CGI-SHOW)

    # read FORM's data file's record id = 1130  
    ($recs, $ts) = $F->data(1130); @line = @$recs;  

    # read FORM's data file  
    ($recs, $ts) = $F->data; @lines = @$recs;  

    # get list of all procs pointing to this FORM, along with their 'long' name
    %P = $F->procs
    print $P{SOURCES};                 #eg: 'Analyse Sources Thermales'
    map { print "$_ ... " } keys(%P);  #eg: 'TRACAGE2010 ... SOURCES ...' 

    # get all NODEs (and its ALIAS,NAME and FID) of a PROC pointing to this FORM 
    %N = $F->nodes(SOURCES); 
    map {print "$_ ... "} keys(%N);    #eg: GCSGAL1 ... GCSTAR1 ... GCSACQ0 ...  
    print $N{GCSGAL1}{ALIAS};                 #eg: 'GA'

    # dump the FORM object
    print $F->dump; 


=head1 DESCRIPTION

FORM object. See SYNOPSIS examples above. 

=cut

use strict;
use warnings;
use Date::Parse;
use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;
use Locale::TextDomain('webobs');
use CGI::Carp qw(fatalsToBrowser set_message);
use POSIX qw/strftime/;
set_message(\&webobs_cgi_msg);

require Exporter;
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);
@ISA = qw(Exporter);
@EXPORT = qw(datetime2array datetime2maxmin simplify_date date_duration
  extract_formula extract_list extract_type extract_text count_inputs count_columns datetime_input
  connectDbForms);

# FORM constructor
sub new {
    my ( $class, $Name ) = @_;
    my $self  = {};

    die "Missing form name" if !defined($Name);
    $self->{_name} = $Name;

    $self->{_path}  = "$WEBOBS{PATH_FORMS}/$Name";
    die "No configuration found for FORM.$Name" if !(-e $self->{_path}."/$Name.conf");
    $self->{_conf}  = { readCfg($self->{_path}."/$Name.conf") };
    $self->{_fnam}  = "$WEBOBS{PATH_DATA_DB}/".$self->{_conf}{FILE_NAME};

    opendir(DIR, "$WEBOBS{PATH_GRIDS2FORMS}");
    my @Ps = grep { s/\.$Name$//g && s/^PROC\.//g } readdir(DIR) ;
    for my $proc ( @Ps ) {
        my %P = readProc($proc);
        $self->{_procs}{$proc} = $P{$proc}{NAME} ;
    }
    closedir(DIR);

    bless $self, $class;
    return $self;
}

# get path to this FORM's configuration files
sub path {
    my ($self) = @_;
    return $self->{_path};
}

# get configuration parameter
sub conf {
    my ($self, $k) = @_;
    return $self->{_conf}{$k} if (defined($k));
    return %{$self->{_conf}};
}

# get data (all or matching $id) for this FORM using WebObs::xreadFile
sub data {
    my ($self, $id) = @_;
    my $fptr = 0;
    my $fts  = -1;
    if (defined($id)) {
        my $fid = qr/^$id\|/;
        ($fptr,$fts) = xreadFile($self->{_fnam}, $fid);
    } else {
        ($fptr,$fts) = xreadFile($self->{_fnam});
    }
    return ($fptr, $fts);
}

# get PROC(s) of this FORM as a hash of their 'long' name (NAME)
sub procs {
    my ($self) = @_;
    return %{$self->{_procs}};
}

# get nodes of a PROC of this FORM, returned as a hash of their NAME, ALIAS and FID 
sub nodes {
    my ($self, $proc) = @_;
    die "no proc requested" unless defined($proc);
    die "$proc not in ".$self->{_name} unless exists($self->{_procs}{$proc});
    my %L = listGridNodes(grid=>"PROC.$proc", valid=>1);
    return %L;
}

# get a dump of this FORM as a string
# usage, eg: print $F->dump
sub dump {
    my ($self) = @_;
    my $dmp = '';
    $dmp .= sprintf( "Form %s\n", $self->{_name} );
    $dmp .= sprintf( "Form configuration path: %s\n", $self->{_path} );
    for my $k ( keys %{ $self->{_conf} } ) {
        $dmp .= sprintf( " %s => %s\n",$k, $self->{_conf}{$k});
    }
    $dmp .= sprintf( "Form data file is: %s\n", $self->{_fnam} );
    $dmp .= "Related proc(s): ";
    for ( keys(%{$self->{_procs}}) ) {
        $dmp .= sprintf("%s(%s) ", $_, $self->{_procs}{$_});
    }
    $dmp .= "\n";
    return $dmp;
}

1;

# ---- GENFORM sub

# from (date_max,date_min) interval, returns an array of (year,month,day,hour,minute)
sub datetime2array {
    my $date = shift;
    my $date_min = shift;
    my @d  = split(/[-: ]/,$date);
    my @dm = split(/[-: ]/,$date_min);
    if ($date eq $date_min || $date_min eq "") { return @d };
    @d = ($d[0],   "",   "",   "","") if ($d[1] ne $dm[1]);
    @d = ($d[0],$d[1],   "",   "","") if ($d[2] ne $dm[2]);
    @d = ($d[0],$d[1],$d[2],   "","") if ($d[3] ne $dm[3]);
    @d = ($d[0],$d[1],$d[2],$d[3],"") if ($d[4] ne $dm[4]);
    return @d;
}

# from full/partial date string, returns interval array (date_max,date_min)
sub datetime2maxmin {
    my ($y,$m,$d,$hr,$mn) = @_;
    my $date_min = "$y-$m-$d $hr:$mn";
    my $date_max = "$y-$m-$d $hr:$mn";
    if ($m eq "") {
        $date_min = "$y-01-01";
        $date_max = "$y-12-31";
    } elsif ($d eq "") {
        $date_min = qx(date -d "$y-$m-01" "+%Y-%m-%d 00:00");
        chomp($date_min);
        $date_max = qx(date -d "$y-$m-01 1 month 1 day ago" "+%Y-%m-%d 23:59");
        chomp($date_max);
    } elsif ($hr eq "") {
        $date_min = "$y-$m-$d 00:00";
        $date_max = "$y-$m-$d 23:59";
    } elsif ($mn eq "") {
        $date_min = "$y-$m-$d $hr:00";
        $date_max = "$y-$m-$d $hr:59";
    }
    return ("$date_max","$date_min");
}

sub datetime_input {
    my ($form, $arg0, $arg1) = @_;
    my ($sel_y1, $sel_m1, $sel_d1, $sel_hr1, $sel_mn1, $sel_sec1);
    my ($sel_y2, $sel_m2, $sel_d2, $sel_hr2, $sel_mn2, $sel_sec2);

    if ( defined $arg0 && defined $arg1 ) {
        if ( scalar(@$arg0) == 5 && scalar(@$arg1 == 5) ) {
            ($sel_y1, $sel_m1, $sel_d1, $sel_hr1, $sel_mn1) = @$arg0;
            ($sel_y2, $sel_m2, $sel_d2, $sel_hr2, $sel_mn2) = @$arg1;
        } elsif ( scalar(@$arg0) == 6 && scalar(@$arg1 == 6) ) {
            ($sel_y1, $sel_m1, $sel_d1, $sel_hr1, $sel_mn1, $sel_sec1) = @$arg0;
            ($sel_y2, $sel_m2, $sel_d2, $sel_hr2, $sel_mn2, $sel_sec2) = @$arg1;
        } else {
            die("Datetime array must have the same dimensions");
        }
    } elsif ( defined $arg0 ) {
        if ( scalar(@$arg0) == 5 ) {
            ($sel_y2, $sel_m2, $sel_d2, $sel_hr2, $sel_mn2) = @$arg0;
        } elsif ( scalar(@$arg0) == 6 ) {
            ($sel_y2, $sel_m2, $sel_d2, $sel_hr2, $sel_mn2, $sel_sec2) = @$arg0;
        }
    } else {
        die("No datetime array to process");
    }

    my $Ctod = time();
    my @tod = localtime($Ctod);
    my $currentYear = strftime('%Y',@tod);

    my %G = readForm($form);
    my %FORM = %{$G{$form}};
    my @yearList = ($FORM{BANG}..$currentYear);
    my @monthList  = ("","01".."12");
    my @dayList    = ("","01".."31");
    my @hourList   = ("","00".."23");
    my @minuteList = ("","00".."59");
    my @secondList = ("","00".."59");

    if ( defined $arg1 ) {
        print qq(<b>$__{'Start Date'}: </b><select name="year" size="1">);
        for (@yearList) {
            if   ( $_ == $sel_y1 ) { print qq(<option selected value="$_">$_</option>); }
            else                   { print qq(<option value="$_">$_</option>); }
        }
        print qq(</select>);

        print qq(<select name="month" size="1">);
        for (@monthList) {
            if   ( $_ == $sel_m1 ) { print qq(<option selected value="$_">$_</option>); }
            else                   { print qq(<option value="$_">$_</option>); }
        }
        print qq(</select>);

        print qq( <select name=day size="1">);
        for (@dayList) {
            if   ( $_ == $sel_d1 ) { print qq(<option selected value="$_">$_</option>); }
            else                   { print qq(<option value="$_">$_</option>); }
        }
        print "</select>";

        print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name=hr size="1">);
        for (@hourList) {
            if   ( $_ eq $sel_hr1 ) { print qq(<option selected value="$_">$_</option>); }
            else                    { print qq(<option value="$_">$_</option>); }
        }
        print qq(</select>);

        print qq(<select name=mn size="1">);
        for (@minuteList) {
            if   ( $_ eq $sel_mn1 ) { print qq(<option selected value="$_">$_</option>); }
            else                    { print qq(<option value="$_">$_</option>); }
        }
        print qq(</select>);

        if ( scalar(@$arg0) == 6 ) {
            print qq(<select name=sec size="1">);
            for (@secondList) {
                if   ( $_ eq $sel_sec1 ) { print qq(<option selected value="$_">$_</option>); }
                else                     { print qq(<option value="$_">$_</option>); }
            }
            print qq(</select>);
        }
        print qq(<br>);
        print qq(<b>$__{'End Date'}: </b><select name="year" size="1">);
    }
    else {
        print qq(<b>$__{'Date'}: </b><select name="year" size="1">);
    }
    for (@yearList) {
        if   ( $_ == $sel_y2 ) { print qq(<option selected value="$_">$_</option>); }
        else                   { print qq(<option value="$_">$_</option>); }
    }
    print qq(</select>);

    print qq(<select name="month" size="1">);
    for (@monthList) {
        if   ( $_ == $sel_m2 ) { print qq(<option selected value="$_">$_</option>); }
        else                   { print qq(<option value="$_">$_</option>); }
    }
    print qq(</select>);

    print qq( <select name=day size="1">);
    for (@dayList) {
        if   ( $_ == $sel_d2 ) { print qq(<option selected value="$_">$_</option>); }
        else                   { print qq(<option value="$_">$_</option>); }
    }
    print "</select>";

    print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name=hr size="1">);
    for (@hourList) {
        if   ( $_ eq $sel_hr2 ) { print qq(<option selected value="$_">$_</option>); }
        else                    { print qq(<option value="$_">$_</option>); }
    }
    print qq(</select>);

    print qq(<select name=mn size="1">);
    for (@minuteList) {
        if   ( $_ eq $sel_mn2 ) { print qq(<option selected value="$_">$_</option>); }
        else                    { print qq(<option value="$_">$_</option>); }
    }
    print qq(</select>);

    if ( scalar(@$arg0) == 6 ) {
        print qq(<select name=sec size="1">);
        for (@secondList) {
            if   ( $_ eq $sel_sec2 ) { print qq(<option selected value="$_">$_</option>); }
            else                     { print qq(<option value="$_">$_</option>); }
        }
        print qq(</select>);
    }
    print qq(<br>);
}

# from (date_max,date_min) interval, returns a string of full/partial date "yyyy[-mm[-dd[ HH[:MM]]]]"
sub simplify_date {
    my $date0 = shift;
    my $date1 = shift;
    my ($y0,$m0,$d0,$H0,$M0) = split(/[-: ]/,$date0);
    my ($y1,$m1,$d1,$H1,$M1) = split(/[-: ]/,$date1);
    my $date = "$y1-$m1-$d1 $H1:$M1";
    if ($date0 eq $date1 || $date1 eq "") { return $date0; }
    if    ($y1 ne $y0) { $date = "$y0-$y1"; }
    elsif ($m1 ne $m0) { $date = "$y1"; }
    elsif ($d1 ne $d0) { $date = "$y1-$m1"; }
    elsif ($H1 ne $H0) { $date = "$y1-$m1-$d1"; }
    elsif ($M1 ne $M0) { $date = "$y1-$m1-$d1 $H1"; }
    return $date;
}

# from 2 date intervals ($sdate_min, $sdate_max, $edate_min, $edate_max), returns an array of min/max duration in days
sub date_duration {
    my $dur_min = sprintf("%+.1f",(str2time($_[2]) - str2time($_[1]))/86400);
    my $dur_max = sprintf("%+.1f",(str2time($_[3]) - str2time($_[0]))/86400);
    return ($dur_min, $dur_max);
}

# extract_formula ($type) returns $formula and @x an array of used fields (input or output)
sub extract_formula {
    my $type = shift;
    my @x;
    my ($size, $formula) = extract_type($type);
    while ($formula =~ /((IN|OUT)PUT[0-9]{2}|DURATION)/g) {
        push(@x,$1);
    }
    return ($formula, $size, @x);
}

sub extract_list {
    my $list = shift;
    my $form = shift;
    my $filename = (split /\: /, $list)[1];
    my %list = readCfg("$WEBOBS{PATH_FORMS}/$form/$filename");

    return %list;
}

sub extract_type {
    my $type = shift;
    my ($size, $default) = (split /:/, $type);
    if ($type =~ /^list\(multiple\)/) {
        $size = "multiple";
    } elsif ($size =~ /\(\d+\)$/) {
        $size =~ s/^[a-z]+\((\d+)\)/$1/;
    } else {
        $size = 5;
    }
    return ($size, $default);
}

sub extract_text {
    my $text = shift;
    $text =~ s/^text[:]*//;
    return (trim($text));
}

# count_inputs (@keys) returns max index of INPUTnn fields in array @keys
sub count_inputs {
    my $count = 0;
    foreach(@_) {
        if ($_ =~ /INPUT([0-9]{2})_NAME/) {
            $count = $1 if ($count < $1);
        }
    }
    return $count;
}

# count_columns (@keys) returns max index of COLUMNnn fields in array @keys
sub count_columns {
    my $count = 0;
    foreach(@_) {
        if ($_ =~ /COLUMN([0-9]{2})_LIST/) {
            $count = $1 if ($count < $1);
        }
    }
    return $count;
}

# Open an SQLite connection to the forms database
sub connectDbForms {
    return DBI->connect("dbi:SQLite:$WEBOBS{SQL_FORMS}", "", "", {
            'AutoCommit' => 1,
            'PrintError' => 1,
            'RaiseError' => 1,
        }) || die "Error connecting to $WEBOBS{SQL_FORMS}: $DBI::errstr";
}

__END__

=pod

=head1 AUTHOR

Didier Lafon, François Beauducel, Lucas Dassin

=head1 COPYRIGHT

WebObs - 2012-2025 - Institut de Physique du Globe Paris

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
                
