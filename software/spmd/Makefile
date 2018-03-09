#####################################################
# This file will run the regression test of bsg_manycore
test_case_list =hello
test_case_list+=bsg_token_queue
test_case_list+=bsg_fence
test_case_list+=bsg_lr_acq
test_case_list+=bsg_chained_core
test_case_list+=bsg_outbuf_full
test_case_list+=mul_div
test_case_list+=bypass_core
test_case_list+=bsg_remote_load
test_case_list+=bsg_remote_congestion
test_case_list+=bsg_swap
test_case_list+=bsg_barrier

all: main.regress_test
##############################################
#  regression test
%.regress_test:
	@for testcase in $(test_case_list) ; do \
	echo "=====================================================================";\
	echo "running testcase [ $$testcase ]                ";\
	make -C ./$$testcase DVE=0  &> run.log;     			   \
	grep " FINISH \| I/O device \|^[Ee]rror"  run.log;    	   \
	make -C ./$$testcase clean  &>/dev/null;     		   \
	rm -rf run.log;											\
	done;
