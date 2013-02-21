#! /usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;

sub main() {
    my $min = 0;
    my $max = undef;
    my $help = 0;

    GetOptions("min=f" => \$min,
               "max=f" => \$max,
               "help" => \$help);

    usage_and_exit() if $help;

    if (defined $max && $min > $max) {
        print STDERR "min size cannot be larger than max size\n";
        exit 1;
    }

    my @fns = glob("bam/*.bam bam/*.sam.gz");
    foreach my $fn(@fns) {
        my $s = (-s $fn) / 2**20; 
        if ($s >= $min && ((!defined $max) || $s <= $max)) {
            print "$fn\n";
        }   
    }
}

sub usage_and_exit() {
    print STDERR "Usage: $0 --min <MB> --max <MB>\n";
    print STDERR "  -- specify minimal and maximal file size in megabytes\n";
    print STDERR "  -- any argument can be omitted, e.g.\n";
    print STDERR "     \"$0\" will list all files\n";
    print STDERR "     \"$0 --max 10\" will list all files smaller than 10 MB\n";
    exit 1;
}

main();
