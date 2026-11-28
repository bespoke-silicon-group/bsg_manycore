

.DEFAULT_GOAL := all

include ./Makefile.include
include ./Makefile.regress.list

# list of subdirectories that we don't recurse into
NO-RECURSE = \
	specint2000 bsg_hetero_nodes \
	bsg_loader_suite \
	go_viral \
	bsg_remote_congestion memtest1 deprecated \
	c++ fft memtest16 fhello_malloc striped_vector_sum striped_hello \
	coremark-top \
	deprecated \
	gather_scatter \
	gather_scatter_multi \
	striped_struct_vector	\
	beebs saif \
	interrupt_tests \
	bp_manycore_test \
	energy_loop_test \
	energy_ubenchmark

# Skip hb_mc test series. Use make's wildcard functions so this also works
# with BSD find on macOS.
SPMD_HB_MC_TESTS := $(notdir $(patsubst %/,%,$(wildcard $(BSG_MANYCORE_DIR)/software/spmd/hb_mc_*/)))
NO-RECURSE += $(SPMD_HB_MC_TESTS)

# Define this variable on cmd line to run coverage analysis. Currently
# supports VCS coverage: run "make COVERAGE=VCS"
COVERAGE = 

ifdef COVERAGE
	bsg_tiles_X = 4
	bsg_tiles_Y = 4
endif

ENABLE_VCACHE=1

ifdef CLANG
  export CLANG=1
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

all:
	@echo ""
	@echo "Usage:"
	@echo "  make -j <numthreads> recurse-clean # clean up after regression"
	@echo "  make -j <numthreads> recurse-all   # run tests in all subdirs"
	@echo "  make regress                       # run them with each simulation on cores of its own"
	@echo "  make regress-selftest              # check the verdicts of make regress"
	@echo "  make watch-summary                 # summarize results of tests"
	@echo ""
	@echo -n " Hyperthreads detected: "; cat /proc/cpuinfo | grep processor | wc -l
	@echo " Run 'top' to see what else is running to decided how many threads to run"

# mbt: saving this code so that bandhav can scavenge the coverage stuff
#
#
# all: main.regress_test
# ##############################################
# #  regression test
# %.regress_test:
# ifdef GROUP
# 	@echo ""
# 	@echo "#####################################################################"
# 	@echo "# RUNNING TEST GROUP: $(GROUP)"
# 	@echo "#####################################################################"
# 	@echo ""
# else ifdef LEVEL
# 	@echo ""
# 	@echo "#####################################################################"
# 	@echo "# RUNNING LEVEL $(LEVEL) REGRESSION"
# 	@echo "#####################################################################"
# 	@echo ""
# endif

# 	@for testcase in $(test_case_list) ; do \
# 	echo "====================================================================="; \
# 	export test_name=$$(echo $$testcase | awk '{print $$1}')	&&	\
# 	export test_target=$$(echo $$testcase | awk '{print $$2}')	&&	\
# 	echo "running testcase [ $$testcase, target=$$test_target ]"; \
# 	make -C ./$$test_name $$test_target DVE=0 COVERAGE=$(COVERAGE)  \
# 		bsg_tiles_X=$(bsg_tiles_X) bsg_tiles_Y=$(bsg_tiles_Y) &> run.log; \
# 	grep " FINISH \| FAIL \| I/O \|^[Ee]rror \|Correct \|Passed" run.log;    	   \
# 	done;

# ifeq ($(COVERAGE),VCS)
# 	@$(URG) $(URG_OPS) -report coverage_reports/ -log coverage.log &>/dev/null;
# 	@echo "====================================================================";
# 	@echo "Module Level Coverage Report";
# 	@cat coverage_reports/modlist.txt;
# 	@echo "See coverage_reports/ for hierarchical coverage and more..."
# 	@echo
# endif

# 	@for testcase in $(test_case_list) ; do \
# 	make -C ./$$(echo $$testcase | awk '{print $$1}') clean  &>/dev/null;     		   \
# 	done;

coverage-debug:
	$(VCS_BIN)/dve -full64 -dir *.vdb &

clean: recurse-clean
	rm -rf run.log cov.log coverage* DVEfiles/ common/crt.o
	rm -rf recurse-results $(REGRESS_TIMES)


#
# Recursion support (mbt)
#
# to avoid parallel runs stomping on each other
# we must build shared files ahead of time
#

pre-recurse-all:
	mkdir -p recurse-results
	$(MAKE) common/crt.o
ifeq ($(abspath $(BSG_MACHINE_PATH)/..),$(abspath $(BSG_MANYCORE_DIR)/machines))
	$(MAKE) -C $(BSG_MACHINE_PATH)/.. $(BSG_SIM_EXE)
endif

pre-recurse-clean:
	rm -rf recurse-results
	mkdir -p recurse-results

SUBDIRS-WITH-MAKE = $(patsubst %/Makefile,%,$(wildcard */Makefile))

# reinvokes make after the pre-curse dependencies are done, on each subdirectory
recurse-%: pre-recurse-%
	$(MAKE) $(foreach x,$(filter-out $(NO-RECURSE),$(SUBDIRS-WITH-MAKE)),recurse-iterate@$*@$(x))

# this rule invokes the target rule on each directory that has a Makefile
#	$(MAKE) -C $(firstword($(subst -, ,$*))) $(lastword($(subst -, ,$*)))
# first word is the rule to run and the second is the benchmark
recurse-iterate@%:
	-$(MAKE) $(firstword $(subst @, ,$*)) -C $(word 2,$(subst @, ,$*)) 2>&1 | /usr/bin/tee recurse-results/$(word 2,$(subst @, ,$*))-run.log

#
# make regress: the tests of recurse-all, each simulation on cores of its own
#
# Runs as many tests at once as the host has cores for, giving every
# simulation one core per simulator thread (VERILATOR_SIM_THREADS with
# BSG_PLATFORM=verilator, otherwise one). A simulation's cores are in one
# socket and are taken a last-level cache at a time: a socket of 18 cores
# with one L3 runs two 8-thread simulations, a socket of eight 4-core
# chiplets four, each on two whole chiplets. Every socket is used. On Linux
# each simulator thread is pinned to its core; elsewhere the simulations run
# unpinned. See software/py/sim_cpus.py.
#
# REGRESS_JOBS=n runs at most n tests at once. The tests that took longest in
# the previous make regress start first (their times are in regress-times,
# which recurse-clean keeps).
#
# Every test prints its verdict when it ends, and its output is in
# recurse-results/<test>-run.log as with recurse-all. A test passes only if
# its make exits with status 0, every simulation it runs reaches BSG_FINISH,
# and its output reports no BSG_FAIL, BSG_TIMEOUT or BSG_ERROR and no error
# of the simulator (software/py/regress_verdict.py). make regress fails if a
# test does not pass. make regress-selftest checks these verdicts.

REGRESS_JOBS ?=
REGRESS_TESTS = $(filter-out $(NO-RECURSE),$(SUBDIRS-WITH-MAKE))
# Every test appends "<seconds> <test>" to REGRESS_TIMES; its last time counts.
REGRESS_TIMES = regress-times
REGRESS_LAST_TIMES = awk '{t[$$2] = $$1} END {for (n in t) print t[n], n}' $(REGRESS_TIMES) 2>/dev/null | sort -rn
REGRESS_KNOWN = $(filter $(REGRESS_TESTS),$(shell $(REGRESS_LAST_TIMES) | cut -d' ' -f2))
REGRESS_ORDER = $(filter-out $(REGRESS_KNOWN),$(REGRESS_TESTS)) $(REGRESS_KNOWN)
REGRESS_RESULTS = recurse-results
REGRESS_SLOTS = $(REGRESS_RESULTS)/regress-slots
# A test's name in target and file names: its directory, with "/" written as
# "__", as a pattern rule matches no target name that has a "/".
REGRESS_NAME = $(subst /,__,$(1))

.PHONY: regress regress-tests regress-selftest

regress: pre-recurse-all
	@$(MAKE) --no-print-directory regress-tests

# make regress without building the simulator and crt.o first
regress-tests:
	@mkdir -p $(REGRESS_RESULTS)
	@rm -rf $(REGRESS_RESULTS)/regress-slot-* $(foreach t,$(call REGRESS_NAME,$(REGRESS_TESTS)),$(REGRESS_RESULTS)/$(t)-verdict)
	@python3 $(BSG_MANYCORE_DIR)/software/py/sim_cpus.py slots $(BSG_SIM_THREADS) $(REGRESS_JOBS) > $(REGRESS_SLOTS)
	@echo "make regress: $(words $(REGRESS_TESTS)) tests, $$(grep -c '' $(REGRESS_SLOTS)) at a time, $(BSG_SIM_THREADS) simulator thread(s) each"
	@start=$$(date +%s); \
	$(MAKE) --no-print-directory -j $$(grep -c '' $(REGRESS_SLOTS)) $(addprefix regress-iterate@,$(call REGRESS_NAME,$(REGRESS_ORDER))); \
	$(REGRESS_LAST_TIMES) > $(REGRESS_TIMES).tmp; mv $(REGRESS_TIMES).tmp $(REGRESS_TIMES); \
	failed=$$(for t in $(call REGRESS_NAME,$(REGRESS_TESTS)); do \
	  [ "$$(cat $(REGRESS_RESULTS)/$$t-verdict 2>/dev/null)" = ok ] || echo $$t; done | sed 's@__@/@g'); \
	secs=$$(( $$(date +%s) - start )); \
	if [ -z "$$failed" ]; then echo "make regress: all $(words $(REGRESS_TESTS)) tests passed, $$secs s"; \
	else echo "make regress: $$(echo $$failed | wc -w | tr -d ' ') of $(words $(REGRESS_TESTS)) tests failed, $$secs s:" $$failed; exit 1; fi

# Take the first free slot (line of $(REGRESS_SLOTS)): make -j runs no more
# tests than there are slots. -k runs every subtest even if one fails.
regress-iterate@%:
	@n=1; until mkdir $(REGRESS_RESULTS)/regress-slot-$$n 2>/dev/null; do \
	  n=$$((n + 1)); [ $$n -le $$(grep -c '' $(REGRESS_SLOTS)) ] || { n=1; sleep 1; }; done; \
	cpus=$$(sed -n "$${n}p" $(REGRESS_SLOTS)); start=$$(date +%s); \
	$(MAKE) -j1 -k all -C $(subst __,/,$*) BSG_SIM_CPUS=$$cpus > $(REGRESS_RESULTS)/$*-run.log 2>&1; status=$$?; \
	secs=$$(( $$(date +%s) - start )); rmdir $(REGRESS_RESULTS)/regress-slot-$$n; \
	echo "$$secs $(subst __,/,$*)" >> $(REGRESS_TIMES); \
	python3 $(BSG_MANYCORE_DIR)/software/py/regress_verdict.py $$status $(REGRESS_RESULTS)/$*-run.log > $(REGRESS_RESULTS)/$*-verdict; \
	v=$$(cat $(REGRESS_RESULTS)/$*-verdict); \
	if [ "$$v" = ok ]; then printf '  ok      %5s s  %s\n' $$secs $(subst __,/,$*); \
	else printf '  FAILED  %5s s  %s (%s)\n' $$secs $(subst __,/,$*) "$${v#FAILED: }"; fi

# make regress-selftest: make regress on the tests in regress-selftest/, which
# print the output of passing and failing simulations, simulate nothing and
# exit with some status. Each must get the verdict in its file "expect", and
# make regress must fail; the passing ones alone must pass.
REGRESS_SELFTESTS = $(patsubst %/Makefile,%,$(wildcard regress-selftest/*/Makefile))
REGRESS_SELFTEST_ARGS = REGRESS_RESULTS=recurse-results/regress-selftest REGRESS_TIMES=recurse-results/regress-selftest/times

regress-selftest:
	@mkdir -p recurse-results/regress-selftest
	@$(MAKE) --no-print-directory regress-tests REGRESS_TESTS="$(REGRESS_SELFTESTS)" $(REGRESS_SELFTEST_ARGS) \
	  > recurse-results/regress-selftest/out.log 2>&1; status=$$?; wrong=0; \
	for t in $(REGRESS_SELFTESTS); do \
	  want=$$(cat $$t/expect); got=$$(cut -d: -f1 recurse-results/regress-selftest/$$(echo $$t | sed 's@/@__@g')-verdict 2>/dev/null); \
	  if [ "$$got" = "$$want" ]; then echo "  $$want, as expected: $$t"; \
	  else echo "  WRONG: $$t: $${got:-no verdict}, expected $$want"; wrong=1; fi; \
	done; \
	[ $$status != 0 ] || { echo "  WRONG: make regress passed although tests failed"; wrong=1; }; \
	passing=; for t in $(REGRESS_SELFTESTS); do [ "$$(cat $$t/expect)" = ok ] && passing="$$passing $$t"; done; \
	$(MAKE) --no-print-directory regress-tests REGRESS_TESTS="$$passing" $(REGRESS_SELFTEST_ARGS) \
	  >> recurse-results/regress-selftest/out.log 2>&1 || { echo "  WRONG: make regress failed on the passing tests"; wrong=1; }; \
	if [ $$wrong = 0 ]; then echo "make regress-selftest: passed"; \
	else echo "make regress-selftest: FAILED (recurse-results/regress-selftest/out.log)"; exit 1; fi

LOG_FILES=`ls -t $(shell /usr/bin/find . -maxdepth 2 -iname *-run.log) $(shell /usr/bin/find bsg_riscv_tests -maxdepth 2 -iname *-run.log)`

SCRAPE-TAIL=/usr/bin/sed 's@.*/@@g' | /usr/bin/sed 's@-run.log@@g' | /usr/bin/column -c 160

%.scrape:
	@echo "Logs with $*---------------------------------------------------------------------------------->"
	@-grep -i --files-with-matches --no-messages $* $(LOG_FILES) | $(SCRAPE-TAIL) || true
	@echo;

%.scrape.i:
	@echo "Logs without $*---------------------------------------------------------------------------------->"
	@-grep -i --files-without-match --no-messages $* $(LOG_FILES) | $(SCRAPE-TAIL) || true
	@echo;

summary: BSG_FINISH.scrape BSG_FINISH.scrape.i BSG_TIMEOUT.scrape BSG_FAIL.scrape BSG_ERROR.scrape
	@echo -n "Free disk:"; df .
	@echo  "SIMVs running:"; /usr/bin/ps a | /usr/bin/grep simv

watch-summary:
	watch make summary

summarize-bad:
#	-@grep -m 1 --color "FAIL\|I/O"  $(LOG_FILES)
	-@grep -m 1 -C 2 --color "FAIL\|ERROR\|^[Ee]rror"  $(LOG_FILES)


check_finish:
	for log in `find recurse-results/ -iname *-run.log`; do \
		if ! grep -q BSG_FINISH $$log; then \
			echo $$log failed; \
			exit 1;	\
		fi;	\
	done
