#/bin/bash

PLATFORM=$1
MACHINE=$2
NUM_CORES=${3:-5}

export BSG_MACHINE=$MACHINE
export BSG_PLATFORM=$PLATFORM

make -j$NUM_CORES -C software/spmd recurse-all
echo ""
echo "=========================================="
echo "Summary of error/fail messages"
echo "=========================================="
make -C software/spmd summarize-bad
echo ""
echo "=========================================="
echo "Regression summary"
echo "=========================================="
make -C software/spmd BSG_FINISH.scrape BSG_FINISH.scrape.i
make -C software/spmd BSG_FAIL.scrape BSG_TIMEOUT.scrape BSG_ERROR.scrape
echo ""
for file in software/spmd/recurse-results/*.log; do
  if grep --quiet BSG_FAIL $file; then
    echo $file failed!
    exit 1
  fi

  if grep --quiet BSG_TIMEOUT $file; then
    echo $file timedout!
    exit 1
  fi
done
make -C software/spmd check_finish
