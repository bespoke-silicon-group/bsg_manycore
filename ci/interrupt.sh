#/bin/bash

PLATFORM=$1
MACHINE=$2
NUM_CORES=${3:-5}

export BSG_MACHINE=$MACHINE
export BSG_PLATFORM=$PLATFORM

make -j$NUM_CORES -C software/spmd/interrupt_tests regress
make -C software/spmd/interrupt_tests check_finish

