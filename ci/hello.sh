#/bin/bash

PLATFORM=$1
MACHINE=$2
NUM_CORES=${5:-5}

export BSG_MACHINE=$MACHINE
export BSG_PLATFORM=$PLATFORM

make -C software/spmd/hello all
make -C software/spmd/hello check_finish

