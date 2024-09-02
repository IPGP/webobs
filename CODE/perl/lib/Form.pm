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
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

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

__END__

=pod

=head1 AUTHOR

Didier Lafon

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
				
