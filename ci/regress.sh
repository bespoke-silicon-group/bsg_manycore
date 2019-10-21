#~/bin/bash

NUM_CORES=${CI_NUM_CORES:-16}

cd software/spmd
make -j $NUM_CORES recurse-clean 
make -j $NUM_CORES recurse-all
for file in recurse-results/*.log; do
  if grep --quiet BSG_FAIL $file; then
    echo $file failed!
    exit 1
  fi

  if grep --quiet BSG_TIMEOUT $file; then
    echo $file timedout!
    exit 1
  fi
done
exit `(grep --quiet BSG_PASS recurse-results/*.log)`
