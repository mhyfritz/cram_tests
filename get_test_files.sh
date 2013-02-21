#! /usr/bin/env sh

wget --mirror --continue -nH --cut-dirs=5 ftp://ftp.ebi.ac.uk/pub/databases/ena/cram/cramtests/bam
wget --mirror --continue -nH --cut-dirs=5 ftp://ftp.ebi.ac.uk/pub/databases/ena/cram/cramtests/ref
