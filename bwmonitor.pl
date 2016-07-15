#!/usr/bin/perl

# bwmonitor.pl - Attempts to estimate the average bandwidth utilized
#                over a given interface.
#
# Copyright (c) 2010-2012, Patrick T. Rutledge III.
#
# You may distribute under the terms of the GNU General Public License.
#
# v1.00 - Initial Public Release
#
# The author assumes no responsibility over the accuracy of the data provided.
# Use this tool at your own risk.
#

use Getopt::Long;
use Pod::Usage;
my $help = 0;

my $defiterations=5;
my $s=1;

my $result = GetOptions (	"count|c=i" => \$iterations,
				"int|i=s" => \$int,
				"bytes|b" => \$bytes,
				"bits|B" => \$bits,
				"help|?" => \$help) or pod2usage(2);

pod2usage(1) if $help;

if ( ! $int ) {
	print "ERROR: Please provide --int=[interface] or --help.\n";
	exit 1;
} else {
	$inttest=`/bin/cat /proc/net/dev|grep "^[[:space:]]*$int:"`;
	if ( ! $inttest ) {
		print "ERROR: Interface $int is invalid.\n";
		exit 1;
	}
}

if ( $iterations ) {
	undef $s;
} else {
	$iterations=$defiterations;
}

if ( $iterations < 2 ) {
	exit;
}

# Default to bytes, because thats what the kernel reports
if ( ! $bits && ! $bytes ) {
	$bytes=1;
}

my @trend;
my $x=1;
my $lastx;
my $oldin;
my $oldout;
my $curin;
my $curout;
my $curbps;
my $totalxfer;

$SIG{INT} = \&average;

print "Realtime bandwidth monitor for interface [$int]";
if ( $s ) {
	print " CTRL-C to end.\n";
} else {
	print ".\n";
}

# need to add a second to get the diff between first two datapoints
my $runiterations=$iterations+1;

my $x=1;
while ( $x <= $runiterations || $s ) {
	my $procout=`/bin/cat /proc/net/dev|grep "^[[:space:]]*$int:"|/bin/sed -e "s/^[[:space:]]*$int://"|/bin/awk '{print \$1":"\$9}'`;
	my ($in,$out)=split(/:/,$procout);
	chomp($out);
	$trend[$x]=$in+$out;
	if ( $x != 1 ) {
		$lastx=$x-1;
		$curbps=$trend[$x]-$trend[$lastx];
		$curin=$in-$oldin;
		$curout=$out-$oldout;
		$totalxfer=$trend[$x]-$trend[1];
		print &humanize($curbps) . ": " . &humanize($totalxfer,'total') . " total (" . &humanize($curin,'notsec') . " in/" . &humanize($curout,'notsec') . " out)\n";
	}
	$avgsecs=$x;
	$oldin=$in;
	$oldout=$out;
	$x++;
	sleep(1);
}

# this shouldnt happen.. but
if ( $s ) { exit 1; }

average();

sub humanize {
	my ( $in, $flag ) = @_ ;
	my $out;
	my $outbits;
	my $outbytes;
	my $suffix;
	if ( $in <= 1023 ) {
		$outbytes=1;
		$outbits=1;
	} elsif ( $in <= 1048999 ) {
		$suffix="K";
		$outbytes=1024;
		$outbits=1000;
	} elsif ( $in <= 1073999999 ) {
		$suffix="M";
		$outbytes=1049000;
		$outbits=1000000;
	} else {
		$suffix="G";
		$outbytes=1074000000;
		$outbits=1000000000;
	}
	if ( $bits && $flag ne 'total' ) {
		if ( $flag eq 'notsec' ) {
			$suffix.="b";
		} else {
			$suffix.="bps";
		}
		$out=($in*8)/$outbits;
	} else {
		if ( $flag eq 'notsec' || $flag eq 'total' ) {
			$suffix.="B";
		} else {
			$suffix.="B/s";
		}
		$out=$in/$outbytes;
	}
	$out=sprintf("%.2f", $out);
	return "$out $suffix";
}

sub average {
	if ( @trend ) {
		my $total;
		my $diff;
		my $last;
		my $avg;
		my $x=1;
		while ( $x <= $avgsecs ) {
			if ( $x != 1 ) {
				$diff=$trend[$x]-$last;
				$total=$total+$diff;
			}
			$last=$trend[$x];
			$x++;
		}
		# Remove extra datapoint
		my $avgsecs_display=$avgsecs-1;
		if ( $avgsecs_display < 1 ) {
			exit;
		}
		my $avg=$total/$avgsecs_display;
		print "\n--- [$int] realtime bandwidth monitor statistics ---\n";
		print &humanize($avg) . " avg over " . $avgsecs_display . " seconds, " . &humanize($total,'total') . " transferred.\n";
	}
	exit 0;
}

__END__

=head1 NAME

bwmonitor.pl - Display realtime network bandwidth utilization for a given interface.

=head1 SYNOPSIS

bwmonitor.pl [options] --int=[interface]

Required:

	--int=interface	- run test on specified interface

Options:

	--count=num	- run test over num seconds
	--bytes		- produce output in bytes
	--bits		- produce output in bits
	--help		- this help message

=cut
