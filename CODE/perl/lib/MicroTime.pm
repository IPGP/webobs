require "sys/syscall.ph";
my $timecall = &SYS_gettimeofday;


sub gettimeofday {
    my $now;
    eval {
	my $TIMEVAL_T = "LL";
	my $time =  pack( $TIMEVAL_T, () );
	die "not supported" if( syscall( $timecall, $time, 0 ) == -1 );
	@time = unpack( $TIMEVAL_T, $time );
	$now = $time[0] + $time[1]/1000000;
    };
    unless( $now ) {
        undef $timecall;
	return time;
    }
    return $now;
}


sub difftime {
    my( $t1, $t2 ) = @_;

    unless( $t2 ) {
        $t2 = gettimeofday();
    }
    ($t2 += 24*3600) if( $t2 < $t1 );
    return( $t2 - $t1 );
}

1;

