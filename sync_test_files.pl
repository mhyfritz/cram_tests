#! /usr/bin/env perl

use warnings;
use strict;
use File::Basename;

system "wget --mirror --continue -nH --cut-dirs=5 ftp://ftp.ebi.ac.uk/pub/databases/ena/cram/cramtests/bam";
system "wget --mirror --continue -nH --cut-dirs=5 ftp://ftp.ebi.ac.uk/pub/databases/ena/cram/cramtests/ref";

my %ftp_files = ();

open IN, "<", "bam/.listing";
while (my $line = <IN>) {
    my ($fn) = $line =~ /.+?(\S+)\s*$/;
    $ftp_files{$fn} = 1;
}
close IN;

open IN, "<", "ref/.listing";
while (my $line = <IN>) {
    my ($fn) = $line =~ /.+?(\S+)\s*$/;
    $ftp_files{$fn} = 1;
}
close IN;

my @local_files = glob("bam/*.bam bam/*.sam.gz ref/*.fa ref/*.fai");
foreach my $fn(@local_files) {
    if (!exists $ftp_files{basename($fn)}) {
        print "removing obsolete file $fn\n";
        unlink $fn;
    }
}
