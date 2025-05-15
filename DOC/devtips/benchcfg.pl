#!perl
use strict;
use warnings;

use WebObs::Config;
use Benchmark qw(:all);
use vars qw($scalar);

# -10 =approx. 10 seconds
cmpthese( -10, {
        'base'         => \&cfg,
        'WO'           => \&cfg1,
        'WO comp'      => \&cfg2,
    });

sub cfg {
    my %X = WebObs::Config::readCfg('/home/didier/wobs/CONF/WEBOBS.rc');
    my %Y = WebObs::Config::readCfg('/home/didier/wobs/CONF/NODES.rc');
}
sub cfg1 {
    my %X = WebObs::Config::readCfg1('/home/didier/wobs/CONF/WEBOBS.rc');
    my %Y = WebObs::Config::readCfg1('/home/didier/wobs/CONF/NODES.rc');
}
sub cfg2 {
    my %X = WebObs::Config::readCfg2('/home/didier/wobs/CONF/WEBOBS.rc');
    my %Y = WebObs::Config::readCfg2('/home/didier/wobs/CONF/NODES.rc');
}

