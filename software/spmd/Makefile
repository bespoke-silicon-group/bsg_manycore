#####################################################
# This file will run the regression test of bsg_manycore
test_case_list =hello
##test_case_list+=bsg_token_queue
##test_case_list+=bsg_fence
##test_case_list+=bsg_lr_acq
##test_case_list+=bsg_chained_core
##test_case_list+=bsg_outbuf_full
##test_case_list+=mul_div
##test_case_list+=bypass_core
##test_case_list+=bsg_remote_load
##test_case_list+=bsg_remote_congestion
##test_case_list+=instr_tests/jal_rv32
##test_case_list+=instr_tests/branch_rv32
test_case_list+=load_dependency
##test_case_list+=bsg_riscv_tests
#test_case_list+=bsg_swap
#test_case_list+=bsg_barrier
#test_case_list+=bsg_transpose

include ./Makefile.include

# Define this variable on cmd line to run coverage. Currently
# supports VCS coverage, hence run "make COVERAGE=VCS"
COVERAGE = 

###############################################
# VCS Unified Coverage report Generator options
VCS_COV_DBs = $(foreach testcase, $(test_case_list), $(testcase)/*.vdb/)
URG_OPS     = -full64
URG_OPS    += -report coverage/
URG_OPS    += -format both  # report in both text and html
URG_OPS    += -dir $(VCS_COV_DBs)  # merge all coverage dbs
URG_OPS    += -map $(VCS_COV_MAP_MODULE)
URG_OPS    += -log urg.log


all: main.regress_test
##############################################
#  regression test
%.regress_test:
	@for testcase in $(test_case_list) ; do \
	echo "=====================================================================";\
	echo "running testcase [ $$testcase ]                ";\
	make -C ./$$testcase DVE=0 COVERAGE=$(COVERAGE) &> run.log;     			   \
	grep " FINISH \| FAIL \| I/O \|^[Ee]rror" run.log;    	   \
	rm -rf run.log;											\
	done;
ifeq ($(COVERAGE),VCS)
	$(URG) $(URG_OPS)
	$(VCS_BIN)/dve -full64 -dir $(VCS_COV_DBs) &
endif
	@for testcase in $(test_case_list) ; do \
	make -C ./$$testcase clean  &>/dev/null;     		   \
	done;

coverage-debug:
	$(VCS_BIN)/dve -full64 -dir $(VCS_COV_DBs) &

clean:
	rm -rf run.log urg.log coverage/
