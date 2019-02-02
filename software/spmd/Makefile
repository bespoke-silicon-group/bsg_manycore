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
test_case_list+=coremark
#test_case_list+=instr_tests/jal_rv32
#test_case_list+=instr_tests/branch_rv32
#test_case_list+=load_dependency
#test_case_list+=bsg_swap
#test_case_list+=bsg_barrier
#test_case_list+=bsg_transpose

include ./Makefile.include

COVERAGE =
###############################################
# VCS Unified Coverage report Generator options
VCS_COV_DBs = $(foreach testcase, $(test_case_list), $(testcase)/simv.vdb)
URG_OPS     = -full64
URG_OPS    += -report coverage/
URG_OPS    += -format both  # report in both text and html
URG_OPS    += -dir $(VCS_COV_DBs)  # merge all coverage dbs


all: main.regress_test
##############################################
#  regression test
%.regress_test:
	@for testcase in $(test_case_list) ; do \
	echo "=====================================================================";\
	echo "running testcase [ $$testcase ]                ";\
	make -C ./$$testcase DVE=0 COVERAGE=$(COVERAGE) &> run.log;     			   \
	grep " FINISH \| FAIL \| I/O \|^[Ee]rror \|Correct" run.log;    	   \
	rm -rf run.log;											\
	done;
ifeq ($(COVERAGE),VCS)
	$(URG) $(URG_OPS)
endif
	@for testcase in $(test_case_list) ; do \
	make -C ./$$testcase clean  &>/dev/null;     		   \
	done;


clean:
	rm -rf run.log coverage/
