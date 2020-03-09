#~/bin/bash

cd software/spmd
make crt.o
mv crt.o common/
cd coremark

make clean
make | tee temp.log

if grep BSG_FINISH temp.log;
then
  echo Coremark Test Passed.
  rm -f temp.log
  exit 0
else
  echo Coremark Failed.
  rm -f temp.log
  exit 1
fi
