export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)

bsg_tiles_X= 1
bsg_tiles_Y= 1

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules
include $(BSG_MANYCORE_DIR)/software/spmd/interrupt_tests/Makefile.testlist

# Name useful for coverage
CM_NAME ?= csr_test

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles

cov_setup:
ifneq ($(COVERAGE), 0)
	$(shell mkdir -p $(BSG_MANYCORE_DIR)/software/spmd/interrupt_tests/coverage)
endif

%.riscv: $(LINK_SCRIPT)  %.o 
	$(RISCV_LINK)  $*.o -o $@ $(RISCV_LINK_OPTS)

%_run: cov_setup
	mkdir -p $@
	cp $*.S $@/main.S
	$(MAKE) -C $@ -f ../Makefile main.run CM_NAME=$* 2>&1 | /usr/bin/tee $@/$@.log

%_wave:
	$(DVE) -full64 -vpd $*/vcdplus.vpd &

cov:
	$(DVE) -full64 -cov -covdir coverage/simv.vdb &

regress: clean
	$(MAKE) $(foreach test, $(TESTS), $(test)_run)

LOG_FILES=`ls -t $(shell /usr/bin/find . -maxdepth 2 -iname *_run.log)`

check_finish:
	for log in $(LOG_FILES); do \
		if ! grep -q BSG_FINISH $$log; then \
			echo $$log failed; \
			exit 1;	\
		fi;	\
	done


SCRAPE-TAIL=/usr/bin/sed 's@.*/@@g' | /usr/bin/sed 's@_run.log@@g' | /usr/bin/column -c 160

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
	@echo -n "SIMVs running:"; /usr/bin/ps a | /usr/bin/grep simv

watch-summary:
	watch make summary

clean.run:
	rm -rf *run/

clean.build:
	$(MAKE) -C $(BSG_MACHINE_PATH)/.. -f Makefile clean

clean: clean.run
