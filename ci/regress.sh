#~/bin/bash

NUM_CORES=${CI_NUM_CORES:-5}

cd software/spmd/
make clean
make -j $NUM_CORES recurse-clean > /dev/null 2>&1
make -j $NUM_CORES recurse-all > /dev/null 2>&1
echo ""
echo "=========================================="
echo "Summary of error/fail messages"
echo "=========================================="
make summarize-bad
echo ""
echo "=========================================="
echo "Regression summary"
echo "=========================================="
make BSG_FINISH.scrape BSG_FINISH.scrape.i BSG_FAIL.scrape BSG_TIMEOUT.scrape BSG_ERROR.scrape
echo ""
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
exit 0
