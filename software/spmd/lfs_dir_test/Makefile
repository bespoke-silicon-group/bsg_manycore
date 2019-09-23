BSG_ELF_DEFAULT_DATA_LOC = SHARED
BSG_NEWLIB = 1
bsg_tiles_X = 1
bsg_tiles_Y = 1
MAX_CYCLES=100000000

ifdef SPIKE

all: main.spike

RISCV_GCC_EXTRA_OPTS += -D__spike__
LINK_SCRIPT = $(BSG_MANYCORE_DIR)/software/spmd/common/spike.ld

else

all: main.run

endif

OBJECT_FILES=main.o
IN_FILES=test

include ../Makefile.include

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. -l:$(BSG_MANYCORE_LIB) -o $@ $(RISCV_LINK_OPTS) -l:$(BSG_MANYCORE_LIB)


main.o: Makefile

include ../../mk/Makefile.tail_rules
