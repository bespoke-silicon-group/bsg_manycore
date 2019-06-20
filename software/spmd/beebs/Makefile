.DEFAULT_GOAL := all

bsg_tiles_X = 1
bsg_tiles_Y = 1
BSG_NEWLIB = 1
LINK_SCRIPT = $(BSG_MANYCORE_DIR)/software/spmd/common/link_dram.ld
REPEAT_FACTOR = 2 # Number of iterations each benchmark is run

# Include the benchmark list
include Makefile.bmarklist
include ../Makefile.include

BEEBS_DIR := $(BSG_MANYCORE_DIR)/imports/beebs
RUN_DIR := $(BSG_MANYCORE_DIR)/software/spmd/beebs
BUILD_DIR := $(RUN_DIR)/beebs-build

RISCV_GCC_OPTS += -DREPEAT_FACTOR=$(REPEAT_FACTOR)

# Run all benchmarks
all: $(foreach bmark, $(BMARK_LIST), $(bmark).run)

%.riscv:
	cp $(BUILD_DIR)/bin/$* $@

include ../../mk/Makefile.tail_rules


#########################
# Rule to install beebs
#########################

BEEBS_CC      = "$(RISCV_GCC)"
BEEBS_CFLAGS  = "$(RISCV_GCC_OPTS)"
COMMON_LIBS   = $(addprefix -l:, $(SPMD_COMMON_OBJECTS) main.o)
BEEBS_LDFLAGS = "-t -T $(LINK_SCRIPT) \
						     -Wl,--defsym,bsg_group_size=$(bsg_group_size) \
						     -Wl,--no-check-sections \
								 $(RISCV_LINK_OPTS) \
								 -L$(RUN_DIR) $(COMMON_LIBS) \
								 -l:$(BSG_MANYCORE_LIB)"

install: $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o main.o
	rm -rf $(BUILD_DIR);
	mkdir -p $(BUILD_DIR);
	cd $(BUILD_DIR) && $(BEEBS_DIR)/configure --prefix=$(BUILD_DIR) \
		                   --host=riscv32 \
											 --with-chip=compare-baseline \
											 --with-board=generic \
											 CC=$(BEEBS_CC) \
											 CFLAGS=$(BEEBS_CFLAGS) \
											 LDFLAGS=$(BEEBS_LDFLAGS) \
											 CHIP_CFLAGS="";
	make -C $(BUILD_DIR);
	make -C $(BUILD_DIR) install;
