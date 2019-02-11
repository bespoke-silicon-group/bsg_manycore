include ./Makefile.regress.list
include ./Makefile.include

# Define this variable on cmd line to run coverage analysis. Currently
# supports VCS coverage: run "make COVERAGE=VCS"
COVERAGE = 

ifdef COVERAGE
	bsg_tiles_X = 4
	bsg_tiles_Y = 4
endif

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
	@for testcase in $(test_case_list) ; do \
	echo "====================================================================="; \
	export test_name=$$(echo $$testcase | awk '{print $$1}')	&&	\
	export test_target=$$(echo $$testcase | awk '{print $$2}')	&&	\
	echo "running testcase [ $$testcase, target=$$test_target ]"; \
	make -C ./$$test_name $$test_target DVE=0 COVERAGE=$(COVERAGE)  \
		bsg_tiles_X=$(bsg_tiles_X) bsg_tiles_Y=$(bsg_tiles_Y) &> run.log; \
	grep " FINISH \| FAIL \| I/O \|^[Ee]rror \|Correct" run.log;    	   \
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
	rm -rf run.log cov.log coverage* DVEfiles/
