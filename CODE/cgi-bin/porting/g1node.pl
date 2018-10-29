#!/usr/bin/perl
#
use strict;
use warnings;
use Time::Local;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use WebObs::Config;
use WebObs::Grids;
use WebObs::Users;
use WebObs::Utils;
$|=1;

sub aLine {
	# from an array of nodes names and a string to be used as label:
	# node1 -> node2 [label=string]; node2 _> node3 [label=string]; ..... ; 
	my $pending;
	my $ar=$_[0];
	my @array=@$ar;
	my $label=$_[1];
	my $ret;
	for my $Nn (@array) {
		if (!defined($pending)) { $pending="$Nn -> "; }
		else { $ret .= "$pending $Nn [label=\"$label\"];\n"; $pending = "$Nn -> "; }
	}
	return $ret;
}

sub gridsnodes {
	if (scalar(@_)
	my ($gt,$gn) = @_;
	
}



# nodes graph from a VIEW name
my %G;
my %S;
my %GRID;
my %NODE;
my $pending;

print "digraph {\n";
print "rankdir = \"LR\";\n";
	%G = readView($ARGV[0]);
	if (%G) {
		%GRID = %{$G{$ARGV[0]}} ;
		# Main "line" : requested VIEW
		print "subgraph { node [fontsize=10, color=red]; edge [len=2,fontsize=9, color=red];\n";
		my $mainLine= aLine($GRID{NODESLIST}, $ARGV[0]);
		print "$mainLine\n";
		print "}\n";
		for my $Nn (@{$GRID{NODESLIST}}) {
			my %N = readNode($Nn);
			if (%N) {
				my %NODE = %{$N{$Nn}}; 
				# Transmission "lines"
				$NODE{TRANSMISSION} =~ s/(^[0-9][,]?)?//;
				my @tl = split(/\|/,$NODE{TRANSMISSION});
				print "subgraph { node [fontsize=10, color=green]; edge [len=2,fontsize=9, color=green];\n";
				for my $Ntl (@tl) {
					print "$Nn -> $Ntl [label=\"transmission\"]\n";
				}
				print "}\n";
				# nodes2nodes
				my @n2n = qx(grep "$Nn" $WEBOBS{ROOT_CONF}/nodes2nodes.rc);
				print "subgraph { node [fontsize=10, color=gray]; edge [len=2,fontsize=9, color=gray];\n";
				for (@n2n) {
					my($n1,$l,$n2) = split(/\|/,$_);
					print "$n1 -> $n2 [label=\"$l\"];\n";
				}
				print "}\n";
			}
		}
	}
print "}\n";

