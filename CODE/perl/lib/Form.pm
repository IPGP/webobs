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
use WebObs::Config;
use WebObs::Grids;
use WebObs::Utils;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

require Exporter;
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION);
@ISA = qw(Exporter);
@EXPORT = qw(datetime2array datetime2maxmin
	extract_formula extract_list extract_size extract_text count_inputs);

# FORM constructor
sub new {
    my ( $class, $Name ) = @_;
	my $self  = {};

    die "Missing form name" if !defined($Name);
	$self->{_name} = $Name;

	$self->{_path}  = "$WEBOBS{PATH_FORMS}/$Name";
	die "No configuration found for $Name" if !(-e $self->{_path}."/$Name.conf");
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

sub datetime2array {
	my $date = shift;
	my $date_min = shift;
	my @d  = split(/[-: ]/,$date);
	my @dm = split(/[-: ]/,$date_min);
	if ($date eq $date_min) { return @d };
	@d = ($d[0],   "",   "",   "","") if ($d[1] ne $dm[1]);
	@d = ($d[0],$d[1],   "",   "","") if ($d[2] ne $dm[2]);
	@d = ($d[0],$d[1],$d[2],   "","") if ($d[3] ne $dm[3]);
	@d = ($d[0],$d[1],$d[2],$d[3],"") if ($d[4] ne $dm[4]);
	return @d;
}

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

# extract_formula ($type) returns $formula and @x an array of used fields (input or output)
sub extract_formula {
	my $formula = shift;
	my @x;
	my $size = extract_size($formula);
	$formula = (split /\:/, $formula)[1];
	while ($formula =~ /((IN|OUT)PUT[0-9]{2})/g) {
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

sub extract_size {
	my $type = shift;
	my $size = (split /:/, $type)[0];
	if ($size =~ /\(.+\)$/) {
		$size =~ s/^[a-z]+\((.+)\)/$1/;
	} else {
		$size = 5;
	}
	return $size;
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

__END__

=pod

=head1 AUTHOR

Didier Lafon, François Beauducel, Lucas Dassin

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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
				
