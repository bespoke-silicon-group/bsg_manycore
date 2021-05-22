find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

BSG_ELF_DEFAULT_DATA_LOC = SHARED
SPMD_COMMON_OBJECTS =
BSG_NEWLIB = 1
MAX_CYCLES = 1000000000

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master

# Include the benchmark list
include $(BSG_MANYCORE_DIR)/software/spmd/beebs/Makefile.bmarklist

.DEFAULT_GOAL := all

bsg_tiles_X = 1
bsg_tiles_Y = 1

REPEAT_FACTOR = 2 # Number of iterations each benchmark is run

BEEBS_DIR := $(BSG_MANYCORE_DIR)/imports/beebs
RUN_DIR := $(BSG_MANYCORE_DIR)/software/spmd/beebs
BUILD_DIR := $(RUN_DIR)/beebs-build

# Run all benchmarks
# you can do make -j <# number of processors> !
#

all: beebs.configure.touchfile
	$(MAKE) $(foreach bmark, $(BMARK_LIST), $(bmark).beeb_run)

# run a single benchmark
%.single: beebs.configure.touchfile
	$(MAKE) $*.beeb_run

# Set program name for individual benchmark
%.beeb_run:
	mkdir -p $*_run
	make -C  $*_run -f ../Makefile PROG_NAME=$* $*.run MAX_CYCLES=$(MAX_CYCLES) | tee $*_run/$*-run.log

# Just copy the installed binary
%.riscv: $(LINK_SCRIPT)  $(COMMON_SRCS) $(BSG_MANYCORE_LIB) $(wildcard $(BEEBS_DIR)/src/%/*)
	make -C $(BUILD_DIR)/src/$* clean
	make -C $(BUILD_DIR)/src/$* install V=1
	cp $(BUILD_DIR)/bin/$* $@

%.dve:
	make -C $*_run -f ../Makefile dve

$(RUN_DIR)/lfs.c: lfs.c


include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

#########################
# Rule to install beebs
#########################

BEEBS_CC      = "$(RISCV_GCC)"
BEEBS_CFLAGS  = "$(RISCV_GCC_OPTS) -DBOARD_REPEAT_FACTOR=$(REPEAT_FACTOR) -D__bsg_argc=1 -D__bsg_argv=0 -I$(BSG_MANYCORE_DIR)/software/bsg_manycore_lib"
COMMON_SRCS   = $(RUN_DIR)/../common/args.c \
                $(RUN_DIR)/../common/crt.S \
                $(RUN_DIR)/../../bsg_manycore_lib/bsg_newlib_intf.c \
								$(RUN_DIR)/lfs.c
BEEBS_LDFLAGS = "-t -T $(LINK_SCRIPT) -march=$(ARCH_OP) -nostartfiles -ffast-math -lc -lm -lgcc \
								 $(RISCV_LINK_SYMS) \
								 -I$(BEEBS_DIR)/support \
								 $(COMMON_SRCS) \
								 -L$(RUN_DIR) -l:$(BSG_MANYCORE_LIB)"

configure: beebs.configure.touchfile

beebs.configure.touchfile: $(LINK_SCRIPT) $(COMMON_SRCS) $(BSG_MANYCORE_LIB)
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

	$(MAKE) -C $(BUILD_DIR)/support install;
	touch beebs.configure.touchfile

clean-build:
	-rm -f *.a *.o *.log
	-rm -rf $(BUILD_DIR);
	-rm -f beebs.configure.touchfile

clean-runs:
	-rm -rf *_run

clean: clean-build clean-runs

RUN_LOGS = $(addsuffix _run/run.log, $(BMARK_LIST))

check_finish:
	for log in $(RUN_LOGS); do \
		if grep BSG_FINISH $$log; \
		then \
			echo $$log passed; \
		else \
			echo $$log failed; \
			exit 1;	\
		fi	\
	done

LOG_FILES=`ls -t $(shell /usr/bin/find . -maxdepth 2 -iname *-run.log)`

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
	@echo -n "SIMVs running:"; /usr/bin/ps a | /usr/bin/grep simv

watch-summary:
	watch make summary
