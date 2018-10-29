#!/usr/bin/perl
# vi:enc=utf-8:
# Auteur:	Alexis Bosson
# Fonction:	Fusion à la volée de fichiers SUDS (pour MC)
# Créé le:	ven 02 mar 2007 22:35:59 AST
# <2 mar 2007 22:35:59 Alexis Bosson>

use strict;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser);
use readConf;
use Webobs;
use File::Basename;
$| = 1;
my %WEBOBS=readConfFile;

# Traitement des paramètres
my $suds = $cgi->param('f');
my $nb_suds = $cgi->param('n');
my ($dest_dir,$dest) = fusion_suds($suds,$nb_suds);
my ($ext) = reverse(split("\\.",$suds));
my $size = -s $dest;
#FIXME
# print Dumper('Fichier : '.__FILE__,'Ligne : '.__LINE__,'$nb_suds',$nb_suds,'$suds',$suds,'$dest_dir',$dest_dir,'find',qx(find $dest_dir -ls));
# print qx(file -i $dest);
print "Content-Type: application/vnd.ovsg.".lc($ext)."\n";
print "Content-Disposition: inline; filename=".basename($dest).";\n";
print "Content-Description: jointure de $nb_suds fichiers\n";
print "Content-Length: $size\n";
print "\n";
open (FILE, $dest); print <FILE>; close (FILE);

system("rm -rf $dest_dir");
