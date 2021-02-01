find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

bsg_tiles_X= 1
bsg_tiles_Y= 1

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

# Test name for writing the correct cm name
TEST_NAME ?= csr_test

TESTS =  csr_test
TESTS += dual_handler_test dual_source_test
TESTS += remote_test remote_fdiv_test remote_float_test remote_handler1_test remote_handler2_test
TESTS += remote_icache_miss_test remote_idiv_test remote_imul_test remote_multiple_test remote_remote_load_loop_test
TESTS += trace_test trace_fdiv_test trace_idiv_test trace_imul_test trace_float_test trace_icache_miss_test
TESTS += trace_countdown_test trace_branch_mispredict_loop_test trace_jump_loop_test trace_jump_loop_icache_test
TESTS += trace_remote_load_loop_test trace_handler1_test trace_handler2_test

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles

%.riscv: $(LINK_SCRIPT)  %.o 
	$(RISCV_LINK)  $*.o -o $@ $(RISCV_LINK_OPTS)

%_run:
	mkdir -p $@
	mkdir -p coverage
	cp $*.S $@/main.S
	$(MAKE) -C $@ -f ../Makefile main.run COVERAGE=1 TEST_NAME=$* 2>&1 | /usr/bin/tee $@/$@.log

wave:
	$(DVE) -full64 -vpd $@/vcdplus.vpd &

cov:
	$(DVE) -full64 -cov -covdir coverage/simv.vdb &

urg:
	urg -full64 -dir coverage/simv.vdb -format both -metric +line+tgl+fsm+cond+branch

regress: clean
	$(MAKE) $(foreach test, $(TESTS), $(test)_run)
	$(MAKE) urg

summary:
	$(foreach test, $(TESTS), grep -H --color -e "BSG_FINISH" -e "BSG_FATAL" -e "Error" -e \
	"BSG_ERROR" $(test)_run/$(test)_run.log;)

clean.run:
	rm -rf *run/

clean.build:
	$(MAKE) -C $(BSG_MACHINE_PATH)/.. -f Makefile clean

clean: clean.build clean.run