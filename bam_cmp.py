#! /usr/bin/env python

from __future__ import print_function
import pysam
from optparse import OptionParser
import sys
from itertools import izip

def check_eq(field, val1, val2, nrec):
    if val1 != val2:
        print("{0}: values don't match (read record #{1}: {2})"\
              .format(sys.argv[0], nrec+1, field), file=sys.stderr)
        print('>', val1, file=sys.stderr)
        print('>', val2, file=sys.stderr)
        sys.exit(1)

def tags_to_set(ts):
    s = set()
    for t, v in ts:
        if options.nomd and t in ["MD", "NM"]:
            continue 
        if options.unknownrg and t == "RG" and v == "UNKNOWN":
            continue
        if type(v) is list:
            v = tuple(v)
        s.add((t, v))
    return s

parser = OptionParser()
# {{{ populate OptionParser
parser.add_option("-f", "--file1", dest="fn1",
                  help="SAM/BAM file #1", metavar="FILE")
parser.add_option("-g", "--file2", dest="fn2",
                  help="SAM/BAM file #2", metavar="FILE")
parser.add_option("-q", "--noqual", action="store_true", dest="noqual",
                  default=False, help="do not compare qualities")
parser.add_option("-a", "--noaux", action="store_true", dest="noaux",
                  default=False, help="do not compare auxiliary fields")
parser.add_option("-t", "--notemplate", action="store_true", dest="notemplate",
                  default=False, help="do not compare template/mate info")
parser.add_option("-u", "--unknownrg", action="store_true", dest="unknownrg",
                  default=False, help="skip RG:Z:UNKNOWN tags")
parser.add_option("-m", "--nomd", action="store_true", dest="nomd",
                  default=False, help="do not compare MD/NM fields")
parser.add_option("-r", "--noqname", action="store_true", dest="noqname",
                  default=False, help="do not compare query (read) names")
# }}}
(options, args) = parser.parse_args()

if (not options.fn1) or (not options.fn2):
    print("options --file1 and --file2 are mandatory", file=sys.stderr)
    sys.exit(2)

# TODO we should compare headers as well, allowing for differences in
# RG:Z:UNKNOWN and PG tags... anything else?
mode = "rb" if options.fn1.endswith('.bam') else "r"
sam1 = pysam.Samfile(options.fn1, mode)
h1 = sam1.header
mode = "rb" if options.fn2.endswith('.bam') else "r"
sam2 = pysam.Samfile(options.fn2, mode)
h2 = sam2.header

for i, (r1, r2) in enumerate(izip(sam1.fetch(until_eof=True),
                                  sam2.fetch(until_eof=True))):
    for f in ["flag", "pos", "seq"]:
        check_eq(f, getattr(r1, f), getattr(r2, f), i)

    # need to handle unmapped reads with cigars
    if r1.is_unmapped or r2.is_unmapped:
        pass
        #if r1.tid != -1 or r2.tid != -1 :
        #    print("{0}: record #{1}: only one read unmapped"\
        #          .format(sys.argv[0], i+1), file=sys.stderr)
        #    sys.exit(1)
    else:
        check_eq("rname", sam1.getrname(r1.tid), sam2.getrname(r2.tid), i)
        for f in ["mapq", "cigar"]:
            check_eq(f, getattr(r1, f), getattr(r2, f), i)

    if not options.noqname:
        check_eq("qname", r1.qname, r2.qname, i)

    if not options.noqual:
        check_eq("qual", r1.qual, r2.qual, i)

    if not options.notemplate:
        for f in ["pnext", "tlen"]:
            check_eq(f, getattr(r1, f), getattr(r2, f), i)
        if r1.rnext == -1 or r2.rnext == -1:
            if r1.rnext != r2.rnext:
                print("{0}: record #{1}: only one rnext unmapped"\
                      .format(sys.argv[0], i+1), file=sys.stderr)
                sys.exit(1)
        else:
            check_eq("rnext", sam1.getrname(r1.rnext), sam2.getrname(r2.rnext), i)

    if not options.noaux:
        r1aux = tags_to_set(r1.tags)
        r2aux = tags_to_set(r2.tags)
        check_eq("optional tags", r1aux, r2aux, i)

sam1.close()
sam2.close()
