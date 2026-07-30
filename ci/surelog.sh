#~/bin/bash

MACHINE=$1
NUM_CORES=${2:-5}

export BSG_MACHINE=$MACHINE

make -C machines parse
make -C machines check_parse

