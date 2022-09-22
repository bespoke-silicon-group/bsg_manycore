export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)

# Running tests on full manycore array. Uncomment and modify for a smaller array
# bsg_tiles_X = 2
# bsg_tiles_Y = 2

RISCV_GXX_EXTRA_OPTS += -DITERS=16

all: main.run

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

OBJECT_FILES=main.o


main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile
