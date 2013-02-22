#! /usr/bin/env perl

use warnings;
use strict;

$| = 1;

my $cram_to_sam = "cram_to_sam";
my $java = "java";
my $samtools = "samtools";
my $cmp = "cmp";
my $valgrind = defined $ENV{"CRAM_TEST_VALGRIND"} ? $ENV{"CRAM_TEST_VALGRIND"} : ""; 
#$valgrind = "valgrind --leak-check=full -q";
my $time = defined $ENV{"CRAM_TEST_TIME"} ? $ENV{"CRAM_TEST_TIME"} : "";
#$time = "/usr/bin/time -p"

my $dryrun = 0;
my $force = 1; # force overwriting of exisiting test output
my $instant_clean = 0; # immediately clean up output of successful run
my $outdir = "test_out";

sub main() {
    usage_and_exit() if @ARGV == 0;
    my @fns;
    if ($ARGV[0] eq "-") {
        while (<STDIN>) {
            chomp;
            push @fns, $_;
        }
    } else {
        @fns = @ARGV;
    }

    -d $outdir || mkdir $outdir;

    my $cnt = 0;
    foreach my $fn (@fns) {
        $fn =~ /bam\/([^.]+)/;
        my $ref = "ref/$1.fa";
        $fn =~ /bam\/(.+)\.(bam|sam\.gz)/;
        my $root = "$outdir/$1";
        my $is_sam = $fn =~ /\.sam\.gz$/;

        my $fn_java_slim_cram = "$root.java.slim.cram";
        my $fn_java_full_cram = "$root.java.full.cram";

        # create CRAM
        my $cmd = "java net.sf.cram.CramTools cram -I $fn " . ($is_sam ? "--input-is-sam " : "") .
                  "-O $fn_java_slim_cram -R $ref " .
                  "--max-container-size 10000 --max-slice-size 10000";
        $cmd = "$time $cmd";
        run_cmd($cmd, $fn_java_slim_cram);
        print "# compression ratio: " . ((-s $fn) / (-s $fn_java_slim_cram)) . "\n";

        $cmd = "java net.sf.cram.CramTools cram -I $fn ". ($is_sam ? "--input-is-sam " : "") .
               "-O $fn_java_full_cram -R $ref " .
               "--max-container-size 10000 --max-slice-size 10000 ".
               "--preserve-read-names --capture-all-tags -L m999";
        $cmd = "$time $cmd";
        run_cmd($cmd, $fn_java_full_cram);
        print "# compression ratio: " . ((-s $fn) / (-s $fn_java_full_cram)) . "\n";

        my $fn_c_slim_sam = "$root.c.slim.sam";
        my $fn_c_slim_bam = "$root.c.slim.bam";
        my $fn_c_slim_bam_sam = "$root.c.slim.bam.sam";
        my $fn_c_full_sam = "$root.c.full.sam";
        my $fn_c_full_bam = "$root.c.full.bam";
        my $fn_c_full_bam_sam = "$root.c.full.bam.sam";

        # convert CRAM to SAM via C
        $cmd = "$cram_to_sam $fn_java_slim_cram $ref > $fn_c_slim_sam"; 
        $cmd = "$time $valgrind $cmd";
        run_cmd($cmd, $fn_c_slim_sam);

        $cmd = "$cram_to_sam $fn_java_full_cram $ref > $fn_c_full_sam";
        $cmd = "$time $valgrind $cmd";
        run_cmd($cmd, $fn_c_full_sam);

        # convert CRAM to BAM via C and compare to original BAM
        $cmd = "$cram_to_sam -b $fn_java_slim_cram $ref > $fn_c_slim_bam";
        $cmd = "$time $valgrind $cmd";
        run_cmd($cmd, $fn_c_slim_bam);

        $cmd = "./bam_cmp.py --nomd --noaux --noqual --noqname --file1 $fn --file2 $fn_c_slim_bam";
        $cmd = "$time $cmd";
        run_cmd($cmd, undef);

        $cmd = "$cram_to_sam -b $fn_java_full_cram $ref > $fn_c_full_bam";
        $cmd = "$time $valgrind $cmd";
        run_cmd($cmd, $fn_c_full_bam);

        $cmd = "./bam_cmp.py --nomd --file1 $fn --file2 $fn_c_full_bam";
        $cmd = "$time $cmd";
        run_cmd($cmd, undef);

        # convert C-BAM to SAM via samtools and compare to C-SAM
        $cmd = "$samtools view -h $fn_c_slim_bam > $fn_c_slim_bam_sam";
        $cmd = "$time $cmd";
        run_cmd($cmd, $fn_c_slim_bam_sam);

        $cmd = "$cmp $fn_c_slim_sam $fn_c_slim_bam_sam";
        $cmd = "$time $cmd";
        run_cmd($cmd, undef);

        $cmd = "$samtools view -h $fn_c_full_bam > $fn_c_full_bam_sam";
        $cmd = "$time $cmd";
        run_cmd($cmd, $fn_c_full_bam_sam);

        $cmd = "$cmp $fn_c_full_sam $fn_c_full_bam_sam";
        $cmd = "$time $cmd";
        run_cmd($cmd, undef);

        if ($instant_clean) {
            unlink $fn_java_slim_cram,
                   $fn_java_full_cram,
                   $fn_c_slim_sam,
                   $fn_c_slim_bam,
                   $fn_c_slim_bam_sam,
                   $fn_c_full_sam,
                   $fn_c_full_bam,
                   $fn_c_full_bam_sam;
        }

        $cnt += 1;
    }
    print "all done. processed $cnt files in total.\n";
    rmdir $outdir if $instant_clean;
}
# args: cmd string and outfile name
sub run_cmd() {
    my ($cmd, $out_fn) = @_;
    if (! $dryrun) {
        if ($force || (defined $out_fn && ! -e $out_fn)) {
            print "# running \"$cmd\"\n";
            my $ret = system $cmd;
            if ($ret != 0) {
                print STDERR "\n!!! FAILED RUN !!!\n$cmd\n\n";
                exit 1;
            }
            print "# finished\n";
        } else {
            print "# skipping ($out_fn exists) \"$cmd\"\n";
        }  
    } else {
        print "# dryrun \"$cmd\"\n";
    }
}

sub usage_and_exit() {
    print STDERR "Usage: $0 -\n\tthis will read the file names from STDIN\n";
    print STDERR "Usage: $0 <list of files>\n\tthis will read the file names from ARGV\n";
    exit 1;
}

main();
