#~/bin/bash

cd software/spmd/beebs

make clean
make -j 5 > /dev/null 2>&1
make check_finish
