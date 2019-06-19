.DEFAULT_GOAL := all

include ./Makefile.include
include ./Makefile.regress.list

# Define this variable on cmd line to run coverage analysis. Currently
# supports VCS coverage: run "make COVERAGE=VCS"
COVERAGE = 

ifdef COVERAGE
	bsg_tiles_X = 4
	bsg_tiles_Y = 4
endif

ENABLE_VCACHE=1

export LLVM_DIR=/mnt/bsg/diskbits/neilryan/llvm/llvm-install

###############################################
# VCS Unified Coverage Report Generator options
VCS_COV_DBs  = $(foreach testcase, $(test_case_list), $(testcase)/*.vdb/)
URG_OPS      = -full64
URG_OPS     += -show tests # keep track of tests after merging
URG_OPS     += -format both  # report in text
URG_OPS     += -dir $(VCS_COV_DBs) # individual coverage dbs
URG_OPS     += -dbname coverage # merged db name
URG_OPS     += -map $(VCS_COV_MODULE_MAP)

all: main.regress_test
##############################################
#  regression test
%.regress_test:
ifdef GROUP
	@echo ""
	@echo "#####################################################################"
	@echo "# RUNNING TEST GROUP: $(GROUP)"
	@echo "#####################################################################"
	@echo ""
else ifdef LEVEL
	@echo ""
	@echo "#####################################################################"
	@echo "# RUNNING LEVEL $(LEVEL) REGRESSION"
	@echo "#####################################################################"
	@echo ""
endif

	@for testcase in $(test_case_list) ; do \
	echo "====================================================================="; \
	export test_name=$$(echo $$testcase | awk '{print $$1}')	&&	\
	export test_target=$$(echo $$testcase | awk '{print $$2}')	&&	\
	echo "running testcase [ $$testcase, target=$$test_target ]"; \
	make -C ./$$test_name $$test_target DVE=0 COVERAGE=$(COVERAGE) &> run.log; \
	grep " FINISH \| FAIL \| I/O \|^[Ee]rror \|Correct \|Passed" run.log;    	   \
	done;

ifeq ($(COVERAGE),VCS)
	@$(URG) $(URG_OPS) -report coverage_reports/ -log coverage.log &>/dev/null;
	@echo "====================================================================";
	@echo "Module Level Coverage Report";
	@cat coverage_reports/modlist.txt;
	@echo "See coverage_reports/ for hierarchical coverage and more..."
	@echo
endif

	@for testcase in $(test_case_list) ; do \
	make -C ./$$(echo $$testcase | awk '{print $$1}') clean  &>/dev/null;     		   \
	done;

coverage-debug:
	$(VCS_BIN)/dve -full64 -dir *.vdb &

clean:
	rm -rf run.log cov.log coverage* DVEfiles/ common/crt.o


#
# Recursion support (mbt)
#
# to avoid parallel runs stomping on each other
# we must build shared files ahead of time
#

pre-recurse-all:
	mkdir -p recurse-results
	$(MAKE) common/crt.o

pre-recurse-clean:
	mkdir -p recurse-results
	-rm recurse-results/*

SUBDIRS-WITH-MAKE = $(patsubst %/Makefile,%,$(wildcard */Makefile))

NO-RECURSE=bsg_riscv_tests specint2000

# reinvokes make after the pre-curse dependencies are done, on each subdirectory
recurse-%: pre-recurse-%
	$(MAKE) $(foreach x,$(filter-out $(NO-RECURSE),$(SUBDIRS-WITH-MAKE)),recurse-iterate@$*@$(x))

# this rule invokes the target rule on each directory that has a Makefile
#	$(MAKE) -C $(firstword($(subst -, ,$*))) $(lastword($(subst -, ,$*)))
recurse-iterate@%:
	-$(MAKE) $(firstword $(subst @, ,$*)) -C $(word 2,$(subst @, ,$*)) | /usr/bin/tee recurse-results/$*
