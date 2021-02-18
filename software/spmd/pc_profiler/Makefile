export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)

bsg_tiles_X= 4
bsg_tiles_Y= 4
MAX_CYCLES= 10000000

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master

# Amount of space for the histogram
HIST_SPACE ?= 16777216
PROFILE ?= 0

# Function lining is automatic at O2 level, but makes extracting profiled histogram harder (only when simulating smaller histogram array sizes (i.e < 16MB))
RISCV_GCC_OPTS += -DHIST_SPACE=$(HIST_SPACE) -DPROFILE=$(PROFILE)
RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles -mno-relax

OBJECT_FILES = profiler.o main.o

%.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB)
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules