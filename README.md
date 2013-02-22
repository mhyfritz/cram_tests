CRAM Testsuite
===
1. set java classpath: `export CLASSPATH=$CLASSPATH:/path-to/cramtools-1.0.jar`
2. synchronize test data: `./sync_test_files.pl`
3. run testsuite, e.g. `./get_fns_by_size.pl --min 1 --max 5 | ./run_tests.pl -` or `./run_tests.pl bam/1756viruses.*`
