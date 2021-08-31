export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)

# Running tests on full manycore array. Uncomment and modify for a smaller array
bsg_tiles_X = 16
bsg_tiles_Y = 8

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

OBJECT_FILES=main.o

all: main.run

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile
