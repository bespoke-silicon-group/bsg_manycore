#~/bin/bash

cd software/spmd/hello
make all BSG_PLATFORM=verilator | grep BSG_FINISH

