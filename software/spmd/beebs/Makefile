find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ATTRIBUTES = NO_RECURSE

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

SPMD_COMMON_OBJECTS =
BSG_NEWLIB = 1

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master

# Include the benchmark list
include $(BSG_MANYCORE_DIR)/software/spmd/beebs/Makefile.bmarklist

.DEFAULT_GOAL := all

bsg_tiles_X = 1
bsg_tiles_Y = 1

LINK_SCRIPT = $(BSG_MANYCORE_DIR)/software/spmd/common/link_dram.ld
REPEAT_FACTOR = 2 # Number of iterations each benchmark is run

BEEBS_DIR := $(BSG_MANYCORE_DIR)/imports/beebs
RUN_DIR := $(BSG_MANYCORE_DIR)/software/spmd/beebs
BUILD_DIR := $(RUN_DIR)/beebs-build

# Run all benchmarks
# you can do make -j <# number of processors> !
#

all: beebs.install.touchfile
	$(MAKE) $(foreach bmark, $(BMARK_LIST), $(bmark).beeb_run)

# Set program name for individual benchmark
%.beeb_run:
	mkdir -p $*_run
	make -C  $*_run -f ../Makefile PROG_NAME=$* $*.run | tee $*_run/run.log

# Just copy the installed binary
%.riscv:
	cp $(BUILD_DIR)/bin/$* $@


$(RUN_DIR)/lfs.c: lfs.c


include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

#########################
# Rule to install beebs
#########################

BEEBS_CC      = "$(RISCV_GCC)"
BEEBS_CFLAGS  = "$(RISCV_GCC_OPTS) -DBOARD_REPEAT_FACTOR=$(REPEAT_FACTOR) -D__bsg_argc=1 -D__bsg_argv=0"
COMMON_SRCS   = $(RUN_DIR)/../common/args.c \
                $(RUN_DIR)/../common/crt.S \
                $(RUN_DIR)/../../bsg_manycore_lib/bsg_newlib_intf.c \
								$(RUN_DIR)/lfs.c
BEEBS_LDFLAGS = "-t -T $(LINK_SCRIPT) -march=$(ARCH_OP) -nostartfiles -ffast-math -lc -lm -lgcc \
						     -Wl,--defsym,bsg_group_size=$(bsg_group_size) \
						     -Wl,--no-check-sections \
								 -I$(BEEBS_DIR)/support \
								 $(COMMON_SRCS) \
								 -L$(RUN_DIR) -l:$(BSG_MANYCORE_LIB)"

beebs.install.touchfile: $(COMMON_SRCS) $(BSG_MANYCORE_LIB)
	rm -rf $(BUILD_DIR);
	mkdir -p $(BUILD_DIR);

  # We provide all compiler and linker flags from this Makefile and 
  # won't use any configuration support inside beebs. So we would choose
  # a generic configuration that almost does nothing. But, beebs repo has 
  # generic configuration only for riscv64 hosts. Hence we choose riscv64
  # as our host. Other than that it has no affect on the compilation
  # process.
	cd $(BUILD_DIR) && $(BEEBS_DIR)/configure --prefix=$(BUILD_DIR) \
		                   --host=riscv64 \
											 --with-chip=generic \
											 CC=$(BEEBS_CC) \
											 CFLAGS=$(BEEBS_CFLAGS) \
											 LDFLAGS=$(BEEBS_LDFLAGS);

	$(MAKE) -C $(BUILD_DIR);
	$(MAKE) -C $(BUILD_DIR) install;
	touch beebs.install.touchfile

summarize:
	-grep -m --color -B 2 finish `find . -iname run.log`
	-grep -m 1 --color "FINISH\|FAIL\|I/O" `find . -iname run.log`
	grep -m 1 -C 2 --color "ERROR\|^[Ee]rror"  `find . -iname run.log`
	-@echo -n "TIMEOUT:"; grep TIMEOUT `find . -iname run.log` | wc -l
	-@echo -n "ERROR:"; grep ERROR `find . -iname run.log` | wc -l
	-@echo -n "FAIL:";grep FAIL `find . -iname run.log` | wc -l
	-@echo -n "Correct:"; grep Correct `find . -iname run.log` | wc -l
	-@echo -n "Passed:"; grep Passed `find . -iname run.log` | wc -l

clean-build:
	-rm *.a *.o *.log
	-rm -rf $(BUILD_DIR);
	-rm beebs.install.touchfile

clean-runs:
	-rm -rf *_run

clean: clean-build clean-runs


