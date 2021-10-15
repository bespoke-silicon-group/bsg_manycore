#~/bin/bash

make -C machines parse
fgrep "[  ERROR] : 0" machines/pod_1x1_4X2Y/parse.log

