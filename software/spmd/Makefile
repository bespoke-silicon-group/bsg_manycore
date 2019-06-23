.DEFAULT_GOAL := all

include ./Makefile.include
include ./Makefile.regress.list

# list of subdirectories that we don't recurse into
NO-RECURSE=specint2000

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

all:
	@echo ""
	@echo "Usage:"
	@echo "  make -j <numthreads> recurse-clean # clean up after regression"
	@echo "  make -j <numthreads> recurse-all   # run tests in all subdirs"
	@echo "  make summarize                     # summarize results of tests"
	@echo ""
	@echo -n " Hyperthreads detected: "; cat /proc/cpuinfo | grep processor | wc -l
	@echo " Run 'top' to see what else is running to decided how many threads to run"

# mbt: saving this code so that bandhav can scavenge the coverage stuff
# uncommented below temporarily


old: main.regress_test
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
	make -C ./$$test_name $$test_target DVE=0 COVERAGE=$(COVERAGE)  \
		bsg_tiles_X=$(bsg_tiles_X) bsg_tiles_Y=$(bsg_tiles_Y) &> run.log; \
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

# reinvokes make after the pre-curse dependencies are done, on each subdirectory
recurse-%: pre-recurse-%
	$(MAKE) $(foreach x,$(filter-out $(NO-RECURSE),$(SUBDIRS-WITH-MAKE)),recurse-iterate@$*@$(x))

# this rule invokes the target rule on each directory that has a Makefile
#	$(MAKE) -C $(firstword($(subst -, ,$*))) $(lastword($(subst -, ,$*)))
recurse-iterate@%:
	-$(MAKE) $(firstword $(subst @, ,$*)) -C $(word 2,$(subst @, ,$*)) | /usr/bin/tee recurse-results/$*

LOG_FILES:=$(shell /usr/bin/find recurse-results -iname all@*) $(shell /usr/bin/find . -iname run.log)
#$(warning $(LOG_FILES))

summarize:
	-grep -m 1 --color -B 2 finish $(LOG_FILES)
	-grep -m 1 --color "FINISH\|FAIL\|I/O"  $(LOG_FILES)
	-grep -m 1 -C 2 --color "ERROR\|^[Ee]rror"  $(LOG_FILES)
	-@echo -n "TIMEOUT:"; grep TIMEOUT  $(LOG_FILES) | wc -l
	-@echo -n "ERROR:"; grep ERROR  $(LOG_FILES) | wc -l
	-@echo -n "FAIL:";grep FAIL  $(LOG_FILES) | wc -l
	-@echo -n "Correct:"; grep Correct  $(LOG_FILES) | wc -l
	-@echo -n "Passed:"; grep Passed  $(LOG_FILES) | wc -l
	-@echo -n "FINISH:"; grep FINISH  $(LOG_FILES) | wc -l

