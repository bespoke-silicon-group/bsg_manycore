#~/bin/bash

cd software/spmd/interrupt_tests

make clean
make regress > /dev/null 2>&1
make check_finish
