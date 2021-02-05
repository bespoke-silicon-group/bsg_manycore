find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

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

wave:
	$(DVE) -full64 -vpd $@/vcdplus.vpd &

cov:
	$(DVE) -full64 -cov -covdir coverage/simv.vdb &

regress: clean
	$(MAKE) $(foreach test, $(TESTS), $(test)_run)

summary:
	$(foreach test, $(TESTS), grep -H --color -e "BSG_FINISH" -e "BSG_FATAL" -e "Error" -e \
	"BSG_ERROR" $(test)_run/$(test)_run.log;)

clean.run:
	rm -rf *run/

clean.build:
	$(MAKE) -C $(BSG_MACHINE_PATH)/.. -f Makefile clean

clean: clean.build clean.run