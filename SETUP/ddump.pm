#!/usr/bin/perl

sub ddumpSyms {
	foreach my $entry ( keys %main:: ) {
		print "Name: $entry\n";
		print "\t";
		print "scalar ".\${$entry}." ${$entry}" if defined ${$entry};
		print ",array " if defined @{$entry};
		print ",hash  " if defined %{$entry};
		print ",sub   " if defined &{$entry};
		print "\n";
	}
}
sub Syms {
	my ($pkgName) = @_;
	*stash = *{"${pkgName}::"};
	foreach my $entry ( keys %stash ) {
		print "Name: $entry\n";
		print "\t".\${$entry}." \n" if defined ${$entry};
		print "\t".\@{$entry}." \n" if defined @{$entry};
		print "\t".\%{$entry}." \n" if defined %{$entry};
		print "\t".\&{$entry}." \n" if defined &{$entry};
		$entry =~ s/^_<sub //;
		print "\t".\&{$entry}." \n" if defined &{$entry};
	}
}

sub ddumpSigs {
	grep { defined($SIG{$_}) && print "$_ \t= $SIG{$_}\n" } keys(%SIG)
}


1;
